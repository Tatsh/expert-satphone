#import "MarkerTestView.h"

#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <QuartzCore/QuartzCore.h>

#import "AudioManager.h"
#import "BFCodec.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "Texture2D.h"
#import "TextureLoading.h"
#import "cipher_keys.h"
#import "note_timing_grade.h"

// MarkerManager vends the marker's data-archive path; it is not reconstructed yet.
@interface MarkerManager : NSObject
+ (nullable NSString *)getMarkerPath:(nullable NSString *)markerID;
@end

// The number of sprite-sheet textures the marker animation is packed into: nine animation frames
// plus the up/down press button share a table of ten.
enum {
    kMarkerTextureCount = 10,
    kMarkerAnimationFrameCount = 9,
};

// The shared quad index buffer maps a run of quad vertices to two triangles each, exactly as
// EAGLView builds it: four vertices and six indices per quad.
enum {
    kMaxQuadVertexCount = 4096,
    kQuadVertexStride = 4,
    kQuadIndexStride = 6,
};

// The Retina content scale, and the two texture edge sizes: 256 for the low-resolution phone,
// 512 for the pad or a Retina phone.
static const CGFloat kRetinaScale = 2.0;
static const GLuint kTextureSizeLow = 256;
static const GLuint kTextureSizeHigh = 512;

// Elapsed time is scaled to a frame counter by this factor (frames per second of preview time).
static const double kFrameTimeScale = 300.0; // @ghidraAddress 0x28f2d0

// The animation runs on a 300-frame loop; a hit freezes it into a result state for 200 (perfect/
// good) or 100 (fast/slow/miss) frames, and the note's timing window is centred on frame 160.
enum {
    kLoopFrameCount = 300,
    kResultHoldLong = 200,
    kResultHoldShort = 100,
    kNoteCentreFrame = 160,
    kResultHoldThreshold = 5,
};

// The high-level animation state: 0 is the idle loop; the others are the frozen result the hit
// produced.
enum {
    kMarkerStateIdle = 0,
    kMarkerStatePerfect = 1,
    kMarkerStateGreat = 2,
    kMarkerStateGood = 3,
    kMarkerStatePoor = 4,
    kMarkerStateMiss = 5,
};

// The theme's hit-sound name arrays are ordered perfect, good, fast, slow.
enum {
    kSoundIndexPerfect = 0,
    kSoundIndexGood = 1,
    kSoundIndexFast = 2,
    kSoundIndexSlow = 3,
};

// The archive entries: the nine animation frames are named "ma_%02d" for the first three (indices
// under 24 in the frame-stride counter) and "h_d_%02d" beyond that; the press button is a plain
// PNG resource.
static NSString *const kFrameNameFormatLow = @"ma_%02d";
static NSString *const kFrameNameFormatHigh = @"h_d_%02d";
static NSString *const kButtonUpImageName = @"test_button_up";
static NSString *const kButtonDownImageName = @"test_button_down";

// The default marker restored when textures are released.
static NSString *const kDefaultMarkerID = @"mk0001";

// The per-theme hit-sound resource names.
static NSString *const kSoundPerfect = @"SD_CV_PERFECT";
static NSString *const kSoundGood = @"SD_CV_GOOD";
static NSString *const kSoundFast = @"SD_CV_FAST";
static NSString *const kSoundSlow = @"SD_CV_SLOW";
static NSString *const kSoundRplPerfect = @"SD_RPL_CV_PERFECT";
static NSString *const kSoundRplGood = @"SD_RPL_CV_GOOD";
static NSString *const kSoundRplFast = @"SD_RPL_CV_FAST";
static NSString *const kSoundRplSlow = @"SD_RPL_CV_SLOW";
static NSString *const kSoundKntPerfect = @"SD_KNT_CV_PERFECT";
static NSString *const kSoundKntGood = @"SD_KNT_CV_GOOD";
static NSString *const kSoundKntFast = @"SD_KNT_CV_FAST";
static NSString *const kSoundKntSlow = @"SD_KNT_CV_SLOW";

@implementation MarkerTestView {
    EAGLContext *context;
    GLuint defaultFramebuffer;
    GLuint colorRenderbuffer;
    GLuint elementArrayBuffer;
    Texture2D *texture[kMarkerTextureCount];
    BOOL buttonPress;
    BOOL buttonPressOld;
    CFTimeInterval baseTime;
    unsigned int state;
    BOOL isPad;
    BOOL isRetina;
    NSString *_currentMarker;
    NSArray<NSArray<NSString *> *> *_soundNames;
}

@synthesize currentMarker = _currentMarker;
@synthesize soundNames = _soundNames;

#pragma mark - Layer

/** @ghidraAddress 0x80294 */
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x802a8 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }
    self.multipleTouchEnabled = NO;
    self.backgroundColor = UIColor.clearColor;
    isPad = [JubeatAppDelegate appDelegate].isPad;
    isRetina = [JubeatAppDelegate appDelegate].isPhoneRetina;
    if (isRetina) {
        self.contentScaleFactor = kRetinaScale;
    }

    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = NO;
    eaglLayer.drawableProperties = @{
        kEAGLDrawablePropertyRetainedBacking : @NO,
        kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8
    };
    context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
    if (!context || ![EAGLContext setCurrentContext:context]) {
        self = nil;
        return self;
    }

    [self createFramebuffer];
    // The per-theme hit-sound names, each ordered perfect, good, fast, slow.
    self.soundNames = @[
        @[ kSoundPerfect, kSoundGood, kSoundFast, kSoundSlow ],
        @[ kSoundRplPerfect, kSoundRplGood, kSoundRplFast, kSoundRplSlow ],
        @[ kSoundKntPerfect, kSoundKntGood, kSoundKntFast, kSoundKntSlow ]
    ];
    _currentMarker = kDefaultMarkerID;
    return self;
}

/** @ghidraAddress 0x81740 */
- (void)dealloc {
    [self destroyFramebuffer];
    [self releaseTex];
}

#pragma mark - Framebuffer

/** @ghidraAddress 0x80710 */
- (BOOL)createFramebuffer {
    glGenFramebuffersOES(1, &defaultFramebuffer);
    glGenRenderbuffersOES(1, &colorRenderbuffer);
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, defaultFramebuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
    [context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer *)self.layer];
    glFramebufferRenderbufferOES(
        GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, colorRenderbuffer);
    GLint width = 0;
    GLint height = 0;
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &width);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &height);
    if (glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
        return NO;
    }
    glViewport(0, 0, width, height);
    glScissor(0, 0, width, height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrthof(0, (float)width, -(float)height, 0, -2.0f, 2.0f);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glScalef(1.0f, -1.0f, 1.0f);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);

    const size_t indexBufferSize =
        (kMaxQuadVertexCount / kQuadVertexStride) * kQuadIndexStride * sizeof(GLushort);
    GLushort *indices = (GLushort *)malloc(indexBufferSize);
    GLushort *cursor = indices;
    for (GLushort base = 0; base < kMaxQuadVertexCount; base += kQuadVertexStride) {
        cursor[0] = base;
        cursor[1] = base + 1;
        cursor[2] = base + 2;
        cursor[3] = base + 2;
        cursor[4] = base + 1;
        cursor[5] = base + 3;
        cursor += kQuadIndexStride;
    }
    glGenBuffers(1, &elementArrayBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, elementArrayBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indexBufferSize, indices, GL_STATIC_DRAW);
    free(indices);
    glEnable(GL_TEXTURE_2D);
    return YES;
}

/** @ghidraAddress 0x81620 */
- (void)destroyFramebuffer {
    [EAGLContext setCurrentContext:context];
    if (defaultFramebuffer != 0) {
        glDeleteFramebuffersOES(1, &defaultFramebuffer);
        defaultFramebuffer = 0;
    }
    if (colorRenderbuffer != 0) {
        glDeleteRenderbuffersOES(1, &colorRenderbuffer);
        colorRenderbuffer = 0;
    }
    if (elementArrayBuffer != 0) {
        glDeleteBuffers(1, &elementArrayBuffer);
        elementArrayBuffer = 0;
    }
}

#pragma mark - Textures

/** @ghidraAddress 0x80984 */
- (void)loadMarkerTex:(NSString *)markerID {
    [EAGLContext setCurrentContext:context];
    NSString *path = [MarkerManager getMarkerPath:markerID];
    KUnzip *archive = [[KUnzip alloc] initWithPath:path];
    BFCodec *codec = [[BFCodec alloc] init];
    NSData *key = CreateTextureCipherKey();

    // The atlas is 256 square on a low-resolution phone, 512 on the pad or a Retina phone.
    GLuint pixelSize = (!isPad && !isRetina) ? kTextureSizeLow : kTextureSizeHigh;

    for (int slot = 0; slot < kMarkerTextureCount; ++slot) {
        @autoreleasepool {
            texture[slot] = [[Texture2D alloc] initWithData:nullptr
                                                pixelFormat:Texture2DPixelFormatRGBA8888
                                                  pixelSize:pixelSize];

            // Each texture holds nine sub-images: eight animation frames laid out three per row,
            // then the press button. The frame-stride counter starts at -8 for this slot and steps
            // by ten each sub-image (mirroring the binary's shared counter).
            int strideCounter = slot - kMarkerTextureCount + 2;
            for (int index = 0; index < kMarkerAnimationFrameCount; ++index) {
                // The sub-image column width and x origin depend on the idiom.
                int columnWidth;
                CGFloat originX;
                if (isPad) {
                    columnWidth = 0xa0;
                    originX = (CGFloat)((index % 3) * 0xa0);
                } else if (isRetina) {
                    columnWidth = 0xa0;
                    originX = (CGFloat)((index % 3) * 0xa0);
                } else {
                    columnWidth = 0x50;
                    originX = (CGFloat)((index % 3) * 0x50);
                }

                UIImage *image;
                CGFloat regionWidth;
                int regionHeight;
                if (strideCounter + 8 < 0x58) {
                    // An animation frame: decrypt the named archive entry into an image.
                    NSString *entryName;
                    if (strideCounter + 8 < 0x18) {
                        entryName = [NSString stringWithFormat:kFrameNameFormatLow, index];
                    } else {
                        entryName = [NSString stringWithFormat:kFrameNameFormatHigh, index];
                    }
                    NSData *entry = [archive uncompress:entryName];
                    [codec cipherInit:key];
                    image = CreateImageFromEncryptedData(codec, entry);
                    if (isPad) {
                        regionHeight = 0xa0;
                        regionWidth = 160.0;
                    } else {
                        regionWidth = isRetina ? 136.0 : 68.0;
                        regionHeight = isRetina ? 0x88 : 0x44;
                    }
                } else {
                    // The press button: the up graphic for the first, the down graphic otherwise.
                    NSString *imageName =
                        (strideCounter == 0x50) ? kButtonUpImageName : kButtonDownImageName;
                    image = LoadScaledPngImage([NSString stringWithString:imageName]);
                    if (isPad) {
                        regionHeight = 0xc0;
                        regionWidth = 192.0;
                    } else {
                        regionWidth = isRetina ? 160.0 : 80.0;
                        regionHeight = isRetina ? 0xa0 : 0x50;
                    }
                }

                if (image) {
                    CGRect rect = CGRectMake(
                        originX, (CGFloat)(columnWidth * (index / 3)), regionWidth, regionHeight);
                    [texture[slot] setSubImage:image inRect:rect];
                }
                strideCounter += 10;
            }
        }
    }
    _currentMarker = markerID;
}

/** @ghidraAddress 0x80e58 */
- (void)releaseTex {
    [EAGLContext setCurrentContext:context];
    for (int slot = 0; slot < kMarkerTextureCount; ++slot) {
        if (texture[slot]) {
            texture[slot] = nil;
        }
    }
    _currentMarker = kDefaultMarkerID;
}

#pragma mark - Playback

/** @ghidraAddress 0x80f54 */
- (void)reset {
    buttonPress = NO;
    buttonPressOld = NO;
    state = kMarkerStateIdle;
    baseTime = CFAbsoluteTimeGetCurrent();
}

/** @ghidraAddress 0x80fa4 */
- (void)draw {
    CFTimeInterval now = CFAbsoluteTimeGetCurrent();
    BOOL wasPressed = buttonPressOld;
    BOOL pressed = buttonPress;
    buttonPressOld = pressed;
    unsigned int frame = (unsigned int)((now - baseTime) * kFrameTimeScale);

    if (state != kMarkerStateIdle) {
        // A hit is frozen into a result state: the long grades hold for 200 frames, the rest 100,
        // after which the idle loop resumes.
        unsigned int hold = (state < kResultHoldThreshold) ? kResultHoldLong : kResultHoldShort;
        if (frame >= hold) {
            frame = 0;
            state = kMarkerStateIdle;
            baseTime = now;
        }
    } else {
        if (frame >= (kLoopFrameCount - 1)) {
            baseTime = now;
        }
        // A fresh press (down this frame, up last frame) triggers a hit judged against the note's
        // centre frame.
        if (pressed && !wasPressed) {
            int delta = (int)frame - kNoteCentreFrame;
            unsigned char grade = ClassifyNoteTimingGrade(delta);

            NSArray<NSString *> *themeSounds;
            JubeatTheme theme = [JubeatAppDelegate appDelegate].currentTheme;
            if (theme == JubeatThemeReflecBeatPlus) {
                themeSounds = self.soundNames[1];
            } else if (theme == JubeatThemeKnit) {
                themeSounds = self.soundNames[2];
            } else {
                themeSounds = self.soundNames[0];
            }

            NSString *soundName = nil;
            switch (grade) {
            case 0:
            case 1:
                state = kMarkerStateMiss;
                soundName =
                    (delta < 0) ? themeSounds[kSoundIndexFast] : themeSounds[kSoundIndexSlow];
                break;
            case 2:
                state = kMarkerStatePerfect;
                soundName =
                    (delta < 0) ? themeSounds[kSoundIndexFast] : themeSounds[kSoundIndexSlow];
                break;
            case 3:
                state = kMarkerStateGreat;
                soundName = themeSounds[kSoundIndexGood];
                break;
            case 4:
                state = kMarkerStateGood;
                soundName = themeSounds[kSoundIndexGood];
                break;
            case 5:
                state = kMarkerStatePoor;
                soundName = themeSounds[kSoundIndexPerfect];
                break;
            default:
                soundName = nil;
                break;
            }
            if (soundName) {
                [[AudioManager sharedManager] playSeResFile:soundName inDirectory:nil];
            }
            if (state != kMarkerStateIdle) {
                frame = 0;
                baseTime = now;
            }
        }
    }

    [EAGLContext setCurrentContext:context];
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, defaultFramebuffer);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    // Pick the animation frame to show: while idle, step through frames 0..14 over the first 240
    // frames; while in a result state, offset into the result-specific frame band.
    unsigned int animFrame;
    if (state == kMarkerStateIdle) {
        animFrame = (frame < 0xf0) ? (frame / 10) : 0xffffffff;
    } else if (frame < kNoteCentreFrame && state < kResultHoldThreshold) {
        animFrame = ((state << 4) | 8) + frame / 10;
    } else {
        animFrame = 0xffffffff;
    }

    // The atlas cell stride used to index into a marker texture, and the destination inset and
    // draw size, all per idiom (values decoded from __const / fmov immediates).
    CGFloat cellStride = isPad ? 160.0 : (isRetina ? 160.0 : 80.0);
    if ((int)animFrame >= 0) {
        CGFloat inset = isPad ? 16.0 : (isRetina ? 12.0 : 6.0);
        CGFloat drawSize = isPad ? 160.0 : (isRetina ? 136.0 : 68.0);
        // The frame's cell sits at column (animFrame/10 mod 3), row (animFrame/30) in its atlas.
        CGFloat regionX = (CGFloat)(int)(animFrame / 10 % 3) * cellStride;
        CGFloat regionY = (CGFloat)(animFrame / 0x1e) * cellStride;
        [texture[animFrame % kMarkerTextureCount]
            drawInRect:CGRectMake(inset, inset, drawSize, drawSize)
            fromRegion:CGRectMake(regionX, regionY, drawSize, drawSize)
             transform:0];
        [texture[animFrame % kMarkerTextureCount] commitDraw];
    }

    // The press button: slot 9 (down) when pressed, slot 8 (up) otherwise; its atlas cell sits two
    // strides in on both axes.
    int buttonSlot = buttonPress ? 9 : 8;
    CGFloat buttonSize = isPad ? 192.0 : (isRetina ? 160.0 : 80.0);
    [texture[buttonSlot]
        drawInRect:CGRectMake(0, 0, buttonSize, buttonSize)
        fromRegion:CGRectMake(
                       cellStride + cellStride, cellStride + cellStride, buttonSize, buttonSize)
         transform:0];
    [texture[buttonSlot] commitDraw];

    glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
    [context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

#pragma mark - Touches

/** @ghidraAddress 0x816c8 */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    buttonPress = YES;
}

/** @ghidraAddress 0x816dc */
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
}

/** @ghidraAddress 0x816e0 */
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    buttonPress = NO;
}

/** @ghidraAddress 0x816f0 */
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

@end
