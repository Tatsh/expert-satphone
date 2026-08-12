#import "AdjustTestView.h"

#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <QuartzCore/QuartzCore.h>

#import "AudioManager.h"
#import "BFCodec.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "LabUtilities.h"
#import "Texture2D.h"
#import "TextureLoading.h"
#import "cipher_keys.h"

// MarkerManager vends the marker's data-archive path; it is not reconstructed yet.
@interface MarkerManager : NSObject
+ (NSString *)getMarkerPath:(NSString *)markerID;
@end

// Sequence plays the note chart and reports the per-panel marker state; it is not reconstructed
// yet. Only the members this view messages are declared here.
@interface Sequence : NSObject
- (instancetype)initWithData:(NSData *)data;
- (void)reset;
- (void)seekToTime:(double)time;
- (void)judge:(unsigned int)btnState btnPress:(unsigned int)btnPress;
- (void)getMarkerState:(int *)markerState;
@end

// The number of sprite-sheet textures the marker animation is packed into, and the nine sub-images
// (eight animation frames plus a button) each holds.
enum {
    kMarkerTextureCount = 10,
    kMarkerSubImageCount = 9,
};

// The four jubeat panels this test previews, laid out two per row.
enum {
    kPanelCount = 4,
    kPanelColumns = 2,
};

// The shared quad index buffer maps a run of quad vertices to two triangles each, exactly as
// EAGLView builds it: four vertices and six indices per quad.
enum {
    kMaxQuadVertexCount = 4096,
    kQuadVertexStride = 4,
    kQuadIndexStride = 6,
};

// The Retina content scale.
static const CGFloat kRetinaScale = 2.0;

// The square GL atlas is always 512 texels on every idiom.
static const GLuint kTextureSize = 512;

// The on-screen panel button's edge length: 144 points on a pad, 72 on a phone.
enum {
    kPanelButtonSizePad = 144,
    kPanelButtonSizePhone = 72,
};

// The view's own tag.
static const NSInteger kViewTag = 99;

// The panel buttons press on touch-down and drag-enter, and release on drag-exit and touch-up.
static const UIControlEvents kPanelPressEvents =
    UIControlEventTouchDown | UIControlEventTouchDragEnter;
static const UIControlEvents kPanelReleaseEvents =
    UIControlEventTouchDragExit | UIControlEventTouchUpInside;

// The adjust value is a number of frame sectors, scaled to seconds by the preview frame rate.
static const float kFrameRateScale = 300.0f; // @ghidraAddress 0x28e010

// The fade time used when the pushed background music is restored.
static const double kBgmFadeTime = 0.2; // @ghidraAddress 0x28e040

// The per-slot sub-image code starts eight below the slot index and steps ten per sub-image; the
// button graphics sit at codes at or above the button threshold, and the high animation frames
// above the low-frame threshold.
enum {
    kFrameCodeBias = 8,
    kFrameCodeStep = 10,
    kSubImageButtonThreshold = 0x58,
    kSubImageHighFrameThreshold = 0x18,
    kButtonUpFrameCode = 0x50,
};

// The atlas cell grid is three sub-images wide; a frame cell is 120 texels square and a button cell
// 144, both laid out on a 120-texel stride.
enum {
    kAtlasColumns = 3,
};
static const CGFloat kAtlasCellStride = 120.0;    // @ghidraAddress 0x291be8
static const CGFloat kFrameSubImageSize = 120.0;  // @ghidraAddress 0x28f210
static const CGFloat kButtonSubImageSize = 144.0; // @ghidraAddress 0x28f660

// The high 12 bits of a panel's marker state select the result band; the low 12 are the running
// frame counter, active only below the frame limit.
enum {
    kMarkerFrameMask = 0xfff,
    kMarkerStateShift = 12,
    kMarkerStateMask = 7,
    kMarkerActiveFrameLimit = 0xf0,
    kMarkerFrameDivisor = 10,
    kMarkerBandStride = 0x10,
    kMarkerBandOffset = 8,
    kMarkerLowStateLimit = 1,
    kMarkerCellRowStride = 0x1e,
};

// The on-screen marker inset and draw size, the panel grid stride, and the button draw size and
// atlas origin, all constant across idioms.
static const CGFloat kMarkerInset = 12.0;         // fmov immediate (float 0x41400000)
static const CGFloat kMarkerDrawSize = 120.0;     // @ghidraAddress 0x28f210
static const CGFloat kPanelGridStride = 144.0;    // @ghidraAddress 0x291bec
static const CGFloat kButtonDrawSize = 144.0;     // @ghidraAddress 0x28f660
static const CGFloat kButtonRegionOrigin = 240.0; // @ghidraAddress 0x291bf0

// The atlas slots holding the released (up) and pressed (down) panel button.
enum {
    kReleasedButtonSlot = 8,
    kPressedButtonSlot = 9,
};

// The archive entry name formats and the bundled test archive's members.
static NSString *const kLowFrameNameFormat = @"ma%02d";
static NSString *const kHighFrameNameFormat = @"h%d%02d";
static NSString *const kButtonUpImageName = @"test_button_up";
static NSString *const kButtonDownImageName = @"test_button_down";
static NSString *const kTestArchiveName = @"999999999";
static NSString *const kTestArchiveType = @"jbt";
static NSString *const kSequenceEntryName = @"seq_adv";
static NSString *const kBgmEntryName = @"bgm";
static const NSUInteger kTestArchiveTailSize = 0x10;

// The default marker restored when textures are released, and the user-defaults key holding the
// saved audio-timing offset.
static NSString *const kDefaultMarkerID = @"mk0001";
static NSString *const kAdjustDefaultsKey = @"PrefAdjustSector";

@implementation AdjustTestView {
    EAGLContext *context;
    GLuint defaultFramebuffer;
    GLuint colorRenderbuffer;
    GLuint elementArrayBuffer;
    Texture2D *texture[kMarkerTextureCount];
    unsigned int btnPress;
    unsigned int btnPressOld;
    NSMutableData *bgmData;
    CFTimeInterval baseTime;
    unsigned int state;
    BOOL paused;
    float adjustTime;
    BOOL isPad;
    BOOL isRetina;
    int markerState[16];
    UIButton *panelView[kPanelCount];
    NSString *_currentMarker;
    Sequence *_sequence;
}

@synthesize currentMarker = _currentMarker;
@synthesize sequence = _sequence;

#pragma mark - Layer

/** @ghidraAddress 0x9db78 */
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x9db8c */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }
    self.multipleTouchEnabled = NO;
    self.backgroundColor = UIColor.clearColor;
    self.tag = kViewTag;
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
    const int buttonSize = isPad ? kPanelButtonSizePad : kPanelButtonSizePhone;
    for (int index = 0; index < kPanelCount; ++index) {
        UIButton *button = [[UIButton alloc]
            initWithFrame:CGRectMake((CGFloat)(buttonSize * (index % kPanelColumns)),
                                     (CGFloat)(buttonSize * (index / kPanelColumns)),
                                     (CGFloat)buttonSize,
                                     (CGFloat)buttonSize)];
        self.userInteractionEnabled = YES;
        button.exclusiveTouch = NO;
        button.tag = index;
        [button addTarget:self
                      action:@selector(btnTouchesBegan:)
            forControlEvents:kPanelPressEvents];
        [button addTarget:self
                      action:@selector(btnTouchesEnd:)
            forControlEvents:kPanelReleaseEvents];
        panelView[index] = button;
        [self addSubview:panelView[index]];
    }
    _currentMarker = kDefaultMarkerID;
    return self;
}

/** @ghidraAddress 0x9f4ac */
- (void)dealloc {
    [self destroyFramebuffer];
    [self releaseTex];
    [EAGLContext setCurrentContext:nil];
}

#pragma mark - Framebuffer

/** @ghidraAddress 0x9e014 */
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

/** @ghidraAddress 0x9f308 */
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

/** @ghidraAddress 0x9e288 */
- (void)loadMarkerTex:(NSString *)markerID {
    [EAGLContext setCurrentContext:context];
    NSString *path = [MarkerManager getMarkerPath:markerID];
    KUnzip *archive = [[KUnzip alloc] initWithPath:path];
    BFCodec *codec = [[BFCodec alloc] init];
    NSData *key = CreateTextureCipherKey();

    for (int slot = 0; slot < kMarkerTextureCount; ++slot) {
        @autoreleasepool {
            texture[slot] = [[Texture2D alloc] initWithData:nullptr
                                                pixelFormat:Texture2DPixelFormatRGBA8888
                                                  pixelSize:kTextureSize];

            // Each texture packs eight animation frames and a button; the per-sub-image code steps
            // ten from a base eight below the slot index.
            int frameCode = slot - kFrameCodeBias;
            for (int index = 0; index < kMarkerSubImageCount; ++index) {
                UIImage *image;
                CGFloat subImageSize;
                if (frameCode + kFrameCodeBias < kSubImageButtonThreshold) {
                    // An animation frame: decrypt the named archive entry into an image.
                    NSString *entryName;
                    if (frameCode + kFrameCodeBias < kSubImageHighFrameThreshold) {
                        entryName = [NSString
                            stringWithFormat:kLowFrameNameFormat, frameCode + kFrameCodeBias];
                    } else {
                        entryName = [NSString stringWithFormat:kHighFrameNameFormat,
                                                               frameCode / kMarkerBandStride,
                                                               frameCode % kMarkerBandStride];
                    }
                    NSMutableData *entry = [archive uncompress:entryName];
                    [codec cipherInit:key];
                    image = CreateImageFromEncryptedData(codec, entry);
                    subImageSize = kFrameSubImageSize;
                } else {
                    // The button: the up graphic for its own code, the down graphic otherwise.
                    NSString *imageName = (frameCode == kButtonUpFrameCode) ? kButtonUpImageName :
                                                                              kButtonDownImageName;
                    image = LoadScaledPngImage([NSString stringWithString:imageName]);
                    subImageSize = kButtonSubImageSize;
                }

                if (image) {
                    CGRect rect = CGRectMake((CGFloat)((index % kAtlasColumns) * kAtlasCellStride),
                                             (CGFloat)((index / kAtlasColumns) * kAtlasCellStride),
                                             subImageSize,
                                             subImageSize);
                    [texture[slot] setSubImage:image inRect:rect];
                }
                frameCode += kFrameCodeStep;
            }
        }
    }

    // Load the bundled test archive, decrypt the sequence and its background music, and start
    // paused.
    NSString *testPath = [[NSBundle mainBundle] pathForResource:kTestArchiveName
                                                         ofType:kTestArchiveType];
    KUnzip *testArchive = [[KUnzip alloc] initWithPath:testPath tail:kTestArchiveTailSize];
    if (testArchive) {
        BFCodec *bgmCodec = [[BFCodec alloc] init];
        NSData *bgmKey = GetBgmCipherKey();
        NSMutableData *sequenceData = [testArchive uncompress:kSequenceEntryName];
        [bgmCodec cipherInit:bgmKey];
        [bgmCodec decipher:sequenceData];
        Sequence *seq = [[Sequence alloc] initWithData:sequenceData];
        if (seq) {
            self.sequence = seq;
            [self.sequence reset];
        }
        NSMutableData *bgm = [testArchive uncompress:kBgmEntryName];
        if (bgm) {
            [bgmCodec cipherInit:bgmKey];
            [bgmCodec decipher:bgm];
            bgmData = [NSMutableData dataWithData:bgm];
        }
        paused = YES;
    }

    adjustTime =
        [NSUserDefaults.standardUserDefaults floatForKey:kAdjustDefaultsKey] / kFrameRateScale;
    _currentMarker = markerID;
}

/** @ghidraAddress 0x9e904 */
- (void)releaseTex {
    [EAGLContext setCurrentContext:context];
    for (int slot = 0; slot < kMarkerTextureCount; ++slot) {
        if (texture[slot]) {
            texture[slot] = nil;
        }
    }
    AudioManager *audio = [AudioManager sharedManager];
    if (audio.bgmPlaying) {
        [audio stopBgm];
    }
    [audio releaseBgm:YES];
    self.sequence = nil;
    _currentMarker = kDefaultMarkerID;
}

#pragma mark - Playback

/** @ghidraAddress 0x9ea70 */
- (void)startPreview {
    AudioManager *audio = [AudioManager sharedManager];
    [self reset];
    paused = NO;
    [audio pushBgm];
    [audio loadBgmData:bgmData];
    [audio startBgm:NO fadeTime:0.0];
}

/** @ghidraAddress 0x9eb10 */
- (void)pausePreview {
    if (paused) {
        return;
    }
    AudioManager *audio = [AudioManager sharedManager];
    paused = YES;
    [self reset];
    [audio stopBgm];
    [audio popBgm];
    [audio startBgm:YES fadeTime:kBgmFadeTime];
}

/** @ghidraAddress 0x9ebcc */
- (void)suspendPreview {
    AudioManager *audio = [AudioManager sharedManager];
    paused = YES;
    [self reset];
    [audio stopBgm];
}

/** @ghidraAddress 0x9ec3c */
- (void)resumePreview {
    AudioManager *audio = [AudioManager sharedManager];
    [audio popBgm];
    [audio startBgm:YES fadeTime:kBgmFadeTime];
}

/** @ghidraAddress 0x9eca0 */
- (void)setAdjust:(int)adjust {
    adjustTime = (float)adjust / kFrameRateScale;
}

/** @ghidraAddress 0x9ecc0 */
- (void)reset {
    btnPressOld = 0;
    btnPress = 0;
    state = 0;
    baseTime = CFAbsoluteTimeGetCurrent();
    adjustTime =
        [NSUserDefaults.standardUserDefaults floatForKey:kAdjustDefaultsKey] / kFrameRateScale;
    [self.sequence reset];
    [self.sequence seekToTime:0];
}

#pragma mark - Rendering

/** @ghidraAddress 0x9edd8 */
- (void)drawBtn:(CGPoint)point btnState:(int)btnState {
    Texture2D *tex = texture[btnState % kMarkerTextureCount];
    [tex drawInRect:CGRectMake(kMarkerInset, kMarkerInset, kMarkerDrawSize, kMarkerDrawSize)
         fromRegion:CGRectMake(
                        (CGFloat)((float)((btnState / kMarkerFrameDivisor) % kAtlasColumns) *
                                  kAtlasCellStride),
                        (CGFloat)((float)(btnState / kMarkerCellRowStride) * kAtlasCellStride),
                        kFrameSubImageSize,
                        kFrameSubImageSize)
          transform:0
              alpha:1.0f];
    [tex commitDraw];
}

/** @ghidraAddress 0x9eec8 */
- (void)draw {
    unsigned int pressed = btnPress;
    [self.sequence judge:pressed btnPress:btnPress];
    btnPressOld = btnPress;

    double time = [AudioManager sharedManager].bgmPos - (double)adjustTime;
    if (time <= 0.0) {
        time = 0.0;
    }
    if (paused) {
        time = 0.0;
    }
    [self.sequence seekToTime:time];
    [self.sequence getMarkerState:markerState];

    for (int panel = 0; panel < kPanelCount; ++panel) {
        unsigned int panelBit = 1u << panel;
        int rawState = markerState[panel];
        unsigned int frame = (unsigned int)rawState & kMarkerFrameMask;

        [EAGLContext setCurrentContext:context];
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, defaultFramebuffer);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        CGFloat panelX = (CGFloat)(int)((float)(panel % kPanelColumns) * kPanelGridStride);
        CGFloat panelY = (CGFloat)(int)((float)(panel / kPanelColumns) * kPanelGridStride);

        if (frame < kMarkerActiveFrameLimit) {
            unsigned int band = ((unsigned int)rawState >> kMarkerStateShift) & kMarkerStateMask;
            unsigned int cell;
            if (band <= kMarkerLowStateLimit) {
                cell = frame / kMarkerFrameDivisor;
            } else {
                cell = frame / kMarkerFrameDivisor + band * kMarkerBandStride - kMarkerBandOffset;
            }
            [texture[cell % kMarkerTextureCount]
                drawInRect:CGRectMake(panelX + kMarkerInset,
                                      panelY + kMarkerInset,
                                      kMarkerDrawSize,
                                      kMarkerDrawSize)
                fromRegion:CGRectMake((CGFloat)((cell / kMarkerFrameDivisor % kAtlasColumns) *
                                                kFrameSubImageSize),
                                      (CGFloat)((cell / kMarkerCellRowStride) * kFrameSubImageSize),
                                      kMarkerDrawSize,
                                      kMarkerDrawSize)
                 transform:0
                     alpha:1.0f];
        }

        int buttonSlot =
            ((panelBit & pressed) == panelBit) ? kPressedButtonSlot : kReleasedButtonSlot;
        [texture[buttonSlot] drawInRect:CGRectMake(panelX, panelY, kButtonDrawSize, kButtonDrawSize)
                             fromRegion:CGRectMake(kButtonRegionOrigin,
                                                   kButtonRegionOrigin,
                                                   kButtonDrawSize,
                                                   kButtonDrawSize)
                              transform:0
                                  alpha:1.0f];
    }

    for (int slot = 0; slot < kMarkerTextureCount; ++slot) {
        [texture[slot] commitDraw];
    }

    glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
    [context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

#pragma mark - Touches

/** @ghidraAddress 0x9f3b0 */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
}

/** @ghidraAddress 0x9f3b4 */
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
}

/** @ghidraAddress 0x9f3b8 */
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
}

/** @ghidraAddress 0x9f3bc */
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

/** @ghidraAddress 0x9f40c */
- (void)btnTouchesBegan:(UIButton *)sender {
    btnPress |= 1u << (sender.tag & 0x1f);
}

/** @ghidraAddress 0x9f458 */
- (void)btnTouchesEnd:(UIButton *)sender {
    // The binary masks with 0xff rather than the full complement.
    btnPress = (0xffu - (1u << (sender.tag & 0x1f))) & btnPress;
}

@end
