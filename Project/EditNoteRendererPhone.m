#import "EditNoteRendererPhone.h"

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "AudioManager.h"
#import "BFCodec.h"
#import "EditRendererConf.h"
#import "EditSequence.h"
#import "EffectBgKnit.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "MarkerManager.h"
#import "Texture2D.h"
#import "TextureLoading.h"
#import "cipher_keys.h"
#import "neEngineBridge.h"

// The render-state values the phone renderer dispatches on.
enum {
    EditNotePhoneStatePreStart = 1, // The pre-start intro.
    EditNotePhoneStateReady = 2,    // The ready/go countdown before play.
    EditNotePhoneStatePlaying = 3,  // Active play.
    EditNotePhoneStateFinish = 4,   // The finish transition.
    EditNotePhoneStateResult = 5,   // The result screen.
};

// The sub-state value that marks the play session as finished.
static const unsigned int kEditNotePhoneEndSubState = 99;

// The sub-state the pre-start intro advances to when it completes.
static const unsigned int kEditNotePhonePreStartDoneSubState = 10;

// Sprite indices within the front atlas.
enum {
    kFrontSpriteButton = 2,             // The 4x4 button panel.
    kFrontSpriteJacketFrame = 11,       // The jacket, blitted under sprite 11 in loadTexure:.
    kFrontSpriteFullcombo = 0x1b,       // The full-combo banner.
    kFrontSpriteFullcomboSquash = 0x1c, // The stretched full-combo banner.
};

// The 4x4 grid geometry: sixteen panels on a 0x50-point pitch, below the upper region.
enum {
    kGridPanelCount = 16,
    kGridColumns = 4,
    kGridPitch = 0x50,
    kGridTopOffset = 0xa0,
    kMarkerPixelCentre = 6,
};

// The music-bar cell count.
enum { kMusicBarCellCount = 0x78 };

// The fade window, in cell units, that keeps the cursor's own cell dim.
static const float kMusicBarCellFadeStart = 0.30000001192092896f; // @ghidraAddress 0x10028e0b0
static const float kMusicBarCellFadeEnd = 1.2999999523162842f;    // @ghidraAddress 0x100292558

// The debug-text glyph cap and the atlas index of the first printable glyph (space).
enum { kDebugTextGlyphCap = 0x200, kDebugFontFirstGlyph = 0x20 };

@interface EditNoteRendererPhone ()
@end

// Builds the knit beat-background texture, its sprite table, and its colour variant blits.
// De-inlined from 0x20ec38.
static inline void EditNoteRendererPhoneLoadBeatBgTexture(EditNoteRendererPhone *self,
                                                          BOOL isRetina,
                                                          BFCodec *codec,
                                                          NSData *cipherKey) {
    if (self.texBeatBg) {
        return;
    }
    self.texBeatBg = [[Texture2D alloc] initWithData:nullptr
                                         pixelFormat:Texture2DPixelFormatRGBA8888
                                           pixelSize:0x800];
    NSString *plist = [NSBundle.mainBundle pathForResource:@"game_beatbg_knt_tex_pn2"
                                                    ofType:@"plist"];
    [self.texBeatBg setSprites:[[NSArray alloc] initWithContentsOfFile:plist]];
    LoadTextureSubImageFromEncryptedTex(
        self.texBeatBg, @"game_beatbg_knt_tex_1_pn2", codec, CGPointMake(0.0, 318.0));
    // The knit colour variant is chosen from a user default, clamped to the three shipped colours.
    NSInteger colorKnit = [NSUserDefaults.standardUserDefaults integerForKey:@"PrefColorKnit"];
    if (colorKnit > 3) {
        colorKnit = 0;
    }
    NSString *path1 = [NSBundle.mainBundle
        pathForResource:[NSString stringWithFormat:@"game_bg_knt_%d_1", (int)colorKnit]
                 ofType:@"png"];
    if (path1) {
        UIImage *image = [[UIImage alloc] initWithContentsOfFile:path1];
        [self.texBeatBg setSubImage:image inRect:[self.texBeatBg spriteAtIndex:9]];
    }
    NSString *path2 = [NSBundle.mainBundle
        pathForResource:[NSString stringWithFormat:@"game_bg_knt_%d_2", (int)colorKnit]
                 ofType:@"png"];
    if (path2) {
        UIImage *image = [[UIImage alloc] initWithContentsOfFile:path2];
        [self.texBeatBg setSubImage:image inRect:[self.texBeatBg spriteAtIndex:10]];
    }
    self.texBeatBg.isScale2x = isRetina;
}

// Unzips the note-marker frames from the marker archive and blits them into the marker atlas: two
// banks of twenty-four "ma" frames, then four banks of sixteen "h" hold frames. De-inlined from
// 0x20f7e8.
static inline void EditNoteRendererPhoneLoadMarkersFromArchive(EditNoteRendererPhone *self,
                                                               EditRendererConf *conf,
                                                               BFCodec *codec,
                                                               NSData *cipherKey) {
    // The base sprite index for each of the four "h" hold banks.
    static const int kHoldBankBase[] = {0x18, 0x28, 0x38, 0x48};
    NSString *markerPath = [MarkerManager getMarkerPath:conf.markerID];
    KUnzip *unzip = [[KUnzip alloc] initWithPath:markerPath];
    for (int pass = 0; pass < 2; ++pass) {
        @autoreleasepool {
            for (unsigned int i = 0; i < 0x18; ++i) {
                [codec cipherInit:cipherKey];
                NSString *name = [NSString stringWithFormat:@"ma%02d", i];
                NSMutableData *data = [unzip uncompress:name];
                UIImage *image = CreateImageFromEncryptedData(codec, data);
                if (image) {
                    [self.texMarker setSubImage:image inRect:[self.texMarker spriteAtIndex:i]];
                }
            }
        }
    }
    for (int bank = 0; bank < 4; ++bank) {
        @autoreleasepool {
            for (int i = 0; i < kGridPanelCount; ++i) {
                [codec cipherInit:cipherKey];
                NSString *name = [NSString stringWithFormat:@"h%d%02d", bank, i];
                NSMutableData *data = [unzip uncompress:name];
                UIImage *image = CreateImageFromEncryptedData(codec, data);
                if (image) {
                    unsigned int spriteIndex = (unsigned int)(i + kHoldBankBase[bank]);
                    [self.texMarker setSubImage:image
                                         inRect:[self.texMarker spriteAtIndex:spriteIndex]];
                }
            }
        }
    }
}

// Rebuilds the front atlas: sprite sheet, level and mark blits, the note markers unzipped from the
// marker archive, and the jacket artwork and index images. De-inlined from 0x20f220.
static inline void EditNoteRendererPhoneBuildFrontTexture(EditNoteRendererPhone *self,
                                                          BOOL isRetina,
                                                          EditRendererConf *conf,
                                                          UIImage *artwork,
                                                          UIImage *index,
                                                          BFCodec *codec,
                                                          NSData *cipherKey) {
    if (self.texFront) {
        self.texFront = nil;
    }
    self.texFront = [[Texture2D alloc] initWithData:nullptr
                                        pixelFormat:Texture2DPixelFormatRGBA8888
                                          pixelSize:0x800];
    NSString *plist = [NSBundle.mainBundle pathForResource:@"game_front_knt_tex_pn2"
                                                    ofType:@"plist"];
    [self.texFront setSprites:[[NSArray alloc] initWithContentsOfFile:plist]];
    [codec cipherInit:cipherKey];
    LoadTextureSubImageFromEncryptedTex(
        self.texFront, @"game_front_knt_tex_1_pn2", codec, CGPointMake(0.0, 0.0));
    [codec cipherInit:cipherKey];
    LoadTextureSubImageFromEncryptedTex(
        self.texFront, @"game_front_knt_tex_2_pn2", codec, CGPointMake(0.0, 960.0));
    // The level word, the start mark, and the end mark are blitted at the origin of their sprites.
    NSString *levelName = [NSString stringWithFormat:@"game_lv_%d_knt", conf.level];
    LoadTextureSubImageFromResource(
        self.texFront, levelName, [self.texFront spriteAtIndex:0x12].origin);
    LoadTextureSubImageFromResource(
        self.texFront, @"game_start_mark_knt_pn2", [self.texFront spriteAtIndex:3].origin);
    LoadTextureSubImageFromResource(
        self.texFront, @"game_end_mark_knt_pn2", [self.texFront spriteAtIndex:4].origin);
    EditNoteRendererPhoneLoadMarkersFromArchive(self, conf, codec, cipherKey);
    [self.texFront setSubImage:artwork
                        inRect:[self.texFront spriteAtIndex:kFrontSpriteJacketFrame]];
    if (index) {
        CGRect frame = [self.texFront spriteAtIndex:0xc];
        CGSize size = index.size;
        // Height preserves the index image's aspect ratio within the frame's width.
        [self.texFront setSubImage:index
                            inRect:CGRectMake(frame.origin.x,
                                              frame.origin.y,
                                              frame.size.width,
                                              (frame.size.width * size.height) / size.width)];
    }
    self.texFront.isScale2x = isRetina;
}

// Draws the "READY" letters: a per-letter settle-out during frames 0x15..0x31, or a together
// drop-in during the later frames. De-inlined from 0x211198.
static inline void EditNoteRendererPhoneRenderReadyGoReady(EditNoteRendererPhone *self,
                                                           unsigned int frame) {
    // The spread-out x-positions of the five settle-out letters, in points.
    static const float kReadyLetterX[] = {-88.5f, -45.0f, 0.0f, 48.5f, 91.5f};
    // The drop-in target x-positions of the five letters, in points.
    static const double kReadyDropX[] = {71.5, 115.0, 160.0, 208.5, 251.5};
    CGRect sprite = [self.texReady0 spriteAtIndex:0];
    double halfWidth = sprite.size.width * 0.5;
    if ((unsigned int)(frame - 0x15) < 0x1d) {
        // Settle-out: the five letters slide from their spread-out positions to centre, one at a
        // time, over the frames after 0x14.
        float baseHeight = (float)sprite.size.height;
        for (long letter = 4; letter >= 0; --letter) {
            if (letter <= (long)(int)frame - 0x14) {
                unsigned int startFrame = (unsigned int)letter;
                unsigned int current = (unsigned int)((long)(int)frame - 0x14);
                float slide =
                    InterpolateFloatByFrame(baseHeight, 0.0f, current, startFrame, startFrame + 8);
                float letterAlpha =
                    InterpolateFloatByFrame(0.0f, 1.0f, current, startFrame, startFrame + 8);
                double letterX = (double)(kReadyLetterX[letter] + 160.0f) - halfWidth;
                double letterY = (double)(50.0f - slide);
                [self.texReady0 drawSprite:(NSUInteger)letter
                                   atPoint:CGPointMake(letterX, letterY)
                                 transform:0
                                     alpha:letterAlpha];
            }
        }
    } else {
        // Drop-in: the five letters fall in together over frames 0x32 onward.
        (void)[self.texReady0 spriteAtIndex:0];
        float dropY = InterpolateFloatByFrame(
            0.0f, (float)((sprite.size.height * -2.0) + 335.0), frame - 0x32, 0, 10);
        double letterY = (double)(dropY + 50.0f);
        float letterAlpha = InterpolateFloatByFrame(1.0f, 0.0f, frame - 0x32, 9, 0xf);
        for (NSInteger letter = 4; letter >= 0; --letter) {
            [self.texReady0 drawSprite:(NSUInteger)letter
                               atPoint:CGPointMake(kReadyDropX[letter] - halfWidth, letterY)
                             transform:0
                                 alpha:letterAlpha];
        }
    }
}

// Draws the two "GO" halves: a swell-in during frames 0x38..0x3e, or a shrink-out during frames
// 0x3f..0x4a. De-inlined from 0x2114d0.
static inline void EditNoteRendererPhoneRenderReadyGoGo(EditNoteRendererPhone *self,
                                                        unsigned int frame) {
    unsigned int f = frame;
    if ((unsigned int)(f - 0x38) < 7) {
        CGRect sprite = [self.texReady1 spriteAtIndex:0];
        double halfWidth = sprite.size.width * 0.5;
        double halfHeight = sprite.size.height * 0.5;
        float scaleAlpha = InterpolateFloatByFrame(0.0f, 1.0f, f - 0x37, 0, 4);
        float swellHeight =
            InterpolateFloatByFrame(0.0f, (float)sprite.size.height, f - 0x37, 0, 8);
        double topY = 385.0 - sprite.size.height;
        double topAnchorY = topY + halfHeight;
        double swellY = 385.0 - (double)swellHeight;
        double swellAnchorY = halfHeight + swellY;
        double leftX = 76.0 - halfWidth;
        double rightX = 244.0 - halfWidth;
        [self.texReady1 drawSprite:2
                           atPoint:CGPointMake(leftX, topY)
                             scale:1.0f
                            rotate:0.0f
                            anchor:CGPointMake(halfWidth + leftX, topAnchorY)
                         transform:0
                             alpha:1.0f];
        [self.texReady1 drawSprite:0
                           atPoint:CGPointMake(leftX, swellY)
                             scale:1.0f
                            rotate:0.0f
                            anchor:CGPointMake(halfWidth + leftX, swellAnchorY)
                         transform:0
                             alpha:scaleAlpha];
        [self.texReady1 drawSprite:3
                           atPoint:CGPointMake(rightX, topY)
                             scale:1.0f
                            rotate:0.0f
                            anchor:CGPointMake(halfWidth + rightX, topAnchorY)
                         transform:0
                             alpha:1.0f];
        [self.texReady1 drawSprite:1
                           atPoint:CGPointMake(rightX, swellY)
                             scale:1.0f
                            rotate:0.0f
                            anchor:CGPointMake(halfWidth + rightX, swellAnchorY)
                         transform:0
                             alpha:scaleAlpha];
    } else if (f <= 0x4a) {
        CGRect sprite = [self.texReady1 spriteAtIndex:0];
        double halfWidth = sprite.size.width * 0.5;
        double halfHeight = sprite.size.height * 0.5;
        float outAlpha = InterpolateFloatByFrame(1.0f, 0.0f, f - 0x3f, 0, 8);
        float shrinkHeight =
            InterpolateFloatByFrame((float)sprite.size.height, (float)halfHeight, f - 0x3f, 0, 8);
        double topY = 385.0 - (double)shrinkHeight;
        double anchorY = halfHeight + topY;
        double leftX = 76.0 - halfWidth;
        double rightX = 244.0 - halfWidth;
        [self.texReady1 drawSprite:0
                           atPoint:CGPointMake(leftX, topY)
                             scale:1.0f
                            rotate:0.0f
                            anchor:CGPointMake(halfWidth + leftX, anchorY)
                         transform:0
                             alpha:outAlpha];
        [self.texReady1 drawSprite:1
                           atPoint:CGPointMake(rightX, topY)
                             scale:1.0f
                            rotate:0.0f
                            anchor:CGPointMake(halfWidth + rightX, anchorY)
                         transform:0
                             alpha:outAlpha];
    }
}

// Plays the ready and go sounds on their frames and finishes the countdown sub-state. De-inlined
// from 0x211830.
static inline void EditNoteRendererPhoneRenderReadyGoAudio(EditNoteRendererPhone *self,
                                                           unsigned int frame) {
    if (frame == 0x14) {
        [AudioManager.sharedManager playSeResFile:@"SD_KNT_CV_READY" inDirectory:nil];
    }
    if (frame == 0x3b) {
        [AudioManager.sharedManager playSePlayer:self.sePlayerGo];
        self.sePlayerGo = nil;
    }
    if (frame >= 0x4b) {
        self.subState = kEditNotePhoneEndSubState;
    }
}

// The full-combo slide-in, squash, and lead-in sweep (frames before 0x96). De-inlined from
// 0x211adc.
static inline void EditNoteRendererPhoneRenderFullcomboIn(
    EditNoteRendererPhone *self, unsigned int current, CGRect banner, float restX, float startX) {
    double span = banner.size.height;
    float topX = InterpolateFloatByFrame(120.0f, restX, current, 0, 6);
    float bottomX = InterpolateFloatByFrame(120.0f, startX, current, 0, 0x18);
    // The squash: the banner briefly widens then settles between frames 0x1c and 0x25.
    if ((int)current > 0x1c && (int)(current - 0x1c) < 10) {
        unsigned int squashFrame = current - 0x1c;
        float squash = InterpolateFloatByFrame(1.0f, 1.399999976158142f, squashFrame, 0, 5);
        if ((int)squashFrame > 5) {
            squash = InterpolateFloatByFrame(1.399999976158142f, 1.0f, squashFrame, 5, 10);
        }
        double squashedW = (double)(float)(span * (double)squash);
        float inset = (float)((span - squashedW) * 0.5);
        [self.texFront
            drawSprite:kFrontSpriteFullcomboSquash
                inRect:CGRectMake(4.0, (double)(topX + inset), banner.size.width, squashedW)
             transform:0
                 alpha:0.5f];
        [self.texFront
            drawSprite:kFrontSpriteFullcomboSquash
                inRect:CGRectMake(4.0, (double)(bottomX + inset), banner.size.width, squashedW)
             transform:0
                 alpha:0.5f];
    }
    [self.texFront drawSprite:kFrontSpriteFullcombo atPoint:CGPointMake(4.0, (double)topX)];
    [self.texFront drawSprite:kFrontSpriteFullcombo atPoint:CGPointMake(4.0, (double)bottomX)];
    if ((int)current > 0x17) {
        return;
    }
    // The lead-in banner sweep, with a bounce, over the first 0x18 frames.
    float sweepX = InterpolateFloatByFrame(120.0f, 246.0f, current, 0, 6);
    unsigned int afterSix = current - 6;
    if (afterSix != 0 && (int)current > 5) {
        sweepX = InterpolateFloatByFrame(246.0f, startX, current, 6, 0x18);
    }
    float bounce;
    if ((int)afterSix < 6) {
        bounce = InterpolateFloatByFrame(1.0f, 3.0f, afterSix, 0, 6);
    } else {
        bounce = InterpolateFloatByFrame(3.0f, 1.0f, afterSix, 6, 0x12);
    }
    if ((int)current > 5) {
        double bouncedW = (double)(float)(span * (double)bounce);
        float inset = (float)((span - bouncedW) * 0.5);
        [self.texFront
            drawSprite:kFrontSpriteFullcomboSquash
                inRect:CGRectMake(4.0, (double)(sweepX + inset), banner.size.width, bouncedW)
             transform:0
                 alpha:0.5f];
    } else {
        [self.texFront drawSprite:kFrontSpriteFullcomboSquash
                          atPoint:CGPointMake(4.0, (double)sweepX)
                        transform:0
                            alpha:0.5f];
    }
}

// The full-combo fade-out: the two halves drift apart and fade (frames 0x96 and later). De-inlined
// from 0x211d08.
static inline void EditNoteRendererPhoneRenderFullcomboOut(
    EditNoteRendererPhone *self, unsigned int current, CGRect banner, float restX, float startX) {
    float fade = InterpolateFloatByFrame(1.0f, 0.0f, current - 0x96, 0, 10);
    float drift = InterpolateFloatByFrame(0.0f, 80.0f, current - 0x96, 0, 10);
    [self.texFront drawSprite:kFrontSpriteFullcombo
                      atPoint:CGPointMake(4.0, (double)(restX + drift))
                    transform:0
                        alpha:fade];
    [self.texFront drawSprite:kFrontSpriteFullcombo
                      atPoint:CGPointMake(4.0, (double)(startX - drift))
                    transform:0
                        alpha:fade];
}

@implementation EditNoteRendererPhone

#pragma mark - Lifecycle

/** @ghidraAddress 0x20ea28 */
- (instancetype)init {
    self = [super init];
    if (self) {
        self.arrayBgEff = [[NSMutableArray alloc] init];
        isRetina = JubeatAppDelegate.appDelegate.isPhoneRetina;
    }
    return self;
}

/** @ghidraAddress 0x2122c0 */
- (void)dealloc {
    [self releaseTexture];
    // The superclass dealloc runs after; ARC synthesises .cxx_destruct for the strong ivars.
}

#pragma mark - Textures

/** @ghidraAddress 0x20fdf4 */
- (void)releaseTexture {
    self.texDebugFont = nil;
    self.texReady0 = nil;
    self.texReady1 = nil;
    self.texFront = nil;
    self.texBeatBg = nil;
    // Note: texMarker is deliberately not released here, matching the binary.
}

/** @ghidraAddress 0x20eaf4 */
- (void)loadTexure:(EditRendererConf *)conf artwork:(UIImage *)artwork index:(UIImage *)index {
    NSData *cipherKey = CreateTextureCipherKey();
    BFCodec *codec = [[BFCodec alloc] init];
    if (!self.texDebugFont) {
        self.texDebugFont = CreateTexture2DFromPngResource(@"debugfont");
    }
    [codec cipherInit:cipherKey];
    EditNoteRendererPhoneLoadBeatBgTexture(self, self->isRetina, codec, cipherKey);
    if (!self.texReady0) {
        [codec cipherInit:cipherKey];
        self.texReady0 = CreateTexture2DFromEncryptedTexResource(@"game_ready_knt_0_tex", codec);
        self.texReady0.isScale2x = isRetina;
    }
    if (!self.texReady1) {
        [codec cipherInit:cipherKey];
        self.texReady1 = CreateTexture2DFromEncryptedTexResource(@"game_ready_knt_1_tex", codec);
        self.texReady1.isScale2x = isRetina;
    }
    if (conf.diff > 2) {
        conf.diff = 2;
    }
    if (conf.level > 10) {
        conf.level = 10;
    }
    // The front atlas is rebuilt unless the requested marker, difficulty, level, and tune all
    // match the one already loaded.
    if (self.texFront && [conf.markerID isEqualToString:self.rendererConf.markerID] &&
        conf.diff == self.rendererConf.diff && conf.level == self.rendererConf.level &&
        conf.tuneID == self.rendererConf.tuneID) {
        return;
    }
    EditNoteRendererPhoneBuildFrontTexture(
        self, self->isRetina, conf, artwork, index, codec, cipherKey);
    self.rendererConf = conf;
}

#pragma mark - Play lifecycle

/** @ghidraAddress 0x20fe6c */
- (void)setState:(unsigned int)state {
    switch (state) {
    case 0:
        lastCombo = 0;
        comboCutFrame = 0;
        comboEffectFrame = 0;
        scoreDisplay = 0;
        shutterOpen = 0.0f;
        lastHakuPhase = 0.0f;
        break;
    case EditNotePhoneStateReady:
        lastCombo = 0;
        comboCutFrame = 0;
        comboEffectFrame = 0;
        scoreDisplay = 0;
        shutterOpen = 0.0f;
        if (!self.sePlayerGo) {
            NSString *path = [NSBundle.mainBundle pathForResource:@"SD_KNT_CV_GO" ofType:@"caf"];
            NSError *error = nil;
            self.sePlayerGo =
                [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                       error:&error];
            [self.sePlayerGo prepareToPlay];
        }
        break;
    case EditNotePhoneStatePlaying:
        self.texReady0 = nil;
        self.texReady1 = nil;
        break;
    case EditNotePhoneStateResult:
        [AudioManager.sharedManager loadBgmResAAC:@"SD_KNT_BGM_RESULT" inDirectory:nil];
        [AudioManager.sharedManager startBgm:YES fadeTime:0.0];
        break;
    default:
        break;
    }
    frame = 0;
    [super setState:state];
}

/** @ghidraAddress 0x2101ac */
- (void)startPlay {
    [self setState:EditNotePhoneStatePlaying];
    self.sePlayerGo = nil;
}

/** @ghidraAddress 0x2101e8 */
- (void)endResult {
    if (self.state == EditNotePhoneStateResult) {
        self.subState = kEditNotePhoneEndSubState;
    }
}

#pragma mark - Layout

/** @ghidraAddress 0x211ea4 */
- (double)buttonAreaOffset {
    return 0.0;
}

/** @ghidraAddress 0x211eac */
- (unsigned int)endButtonID {
    return 15;
}

/** @ghidraAddress 0x212310 */
- (CGRect)getTimeLineRect {
    return CGRectMake(40.0, 136.0, 240.0, 19.0);
}

#pragma mark - Drawing

/** @ghidraAddress 0x210234 */
- (void)drawClip:(int)drawIndex
    drawPosition:(CGPoint)drawPosition
        drawArea:(CGRect)drawArea
           alpha:(float)alpha {
    CGRect sprite = [self.texFront spriteAtIndex:(NSUInteger)drawIndex];
    // The chip runs from drawPosition over the sprite's size; the visible portion is the
    // intersection with drawArea. If they do not overlap in either axis, nothing is drawn.
    double areaLeft = (double)(float)drawArea.origin.x;
    double areaTop = (double)(float)drawArea.origin.y;
    double areaRight = (double)(float)(drawArea.size.width + areaLeft);
    double areaBottom = (double)(float)(drawArea.size.height + areaTop);
    double posX = drawPosition.x;
    double posY = drawPosition.y;
    double spriteW = sprite.size.width;
    double spriteH = sprite.size.height;
    double regionX = sprite.origin.x;
    double regionY = sprite.origin.y;
    if (!(areaLeft <= posX + spriteW && posX < areaRight)) {
        return;
    }
    if (!(posY + spriteH > areaTop && posY < areaBottom)) {
        return;
    }
    double destX = posX;
    if (posX < areaLeft) {
        destX = areaLeft;
        spriteW -= (areaLeft - posX);
        regionX += (areaLeft - posX);
    }
    double clippedW = spriteW;
    if (spriteW + destX > areaRight) {
        clippedW = spriteW - ((spriteW + destX) - areaRight);
    }
    double destY = posY;
    if (posY < areaTop) {
        destY = areaTop;
        spriteH -= (areaTop - posY);
        regionY += (areaTop - posY);
    }
    double clippedH = spriteH;
    if (spriteH + destY > areaBottom) {
        clippedH = spriteH - ((spriteH + destY) - areaBottom);
    }
    double regionW = clippedW;
    double regionH = clippedH;
    if (isRetina) {
        // Retina sprites are 2x, so the source region is measured in double-density texels.
        regionH += regionH;
        regionW += regionW;
        regionX += regionX;
        regionY += regionY;
    }
    [self.texFront drawInRect:CGRectMake(destX, destY, clippedW, clippedH)
                   fromRegion:CGRectMake(regionX, regionY, regionW, regionH)
                    transform:0
                        alpha:alpha];
}

/** @ghidraAddress 0x210438 */
- (void)renderMarker {
    [self.sequence getMarkerState:markerState];
    for (int panel = 0; panel < kGridPanelCount; ++panel) {
        unsigned int packed = (unsigned int)markerState[panel];
        unsigned int low = packed & 0xfff;
        unsigned int type = (packed >> 12) & 7;
        int spriteIndex = -1;
        if (type == 0) {
            if (low < 0xf0) {
                spriteIndex = (int)(low / 10);
            }
        } else if (low < 0xa0 && type < 6) {
            spriteIndex = (int)((low / 10 + type * 0x10) - 8);
        }
        if (spriteIndex < 0) {
            continue;
        }
        double x = (double)((panel % kGridColumns) * kGridPitch | kMarkerPixelCentre);
        double y =
            (double)(((panel / kGridColumns) * kGridPitch | kMarkerPixelCentre) + kGridTopOffset);
        [self.texMarker drawSprite:(NSUInteger)spriteIndex atPoint:CGPointMake(x, y)];
    }
}

/** @ghidraAddress 0x210594 */
- (void)renderShutter:(BOOL)animate {
    // The offsets of the five beat-background columns, in points.
    static const int kShutterColumnOffsets[] = {-9, 12, 39, 81, 135};
    if (self.sequence) {
        (void)self.sequence.hakuPhase; // Read for effect; the result is discarded on the phone.
    }
    if (animate) {
        shutterOpen = (shutterOpen + 0.0f) * 0.5f;
    }
    // Sprite 1's height positions the top half so its bottom edge meets the centre line at 320.
    double spriteHeight = [self.texBeatBg spriteAtIndex:1].size.height;
    for (int column = 0; column < 5; ++column) {
        int offset = kShutterColumnOffsets[column];
        // The beat-background atlas has four column sprites; the fifth column reuses sprite 3.
        NSUInteger columnSprite = (column == 4) ? 3 : (NSUInteger)column;
        // The top half slides up from 320 (transform 2 flips it), the bottom half slides down.
        double topY = ((320.0 - spriteHeight) - (double)offset) - (double)shutterOpen;
        [self.texBeatBg drawSprite:columnSprite
                           atPoint:CGPointMake(0.0, topY)
                         transform:2
                             alpha:1.0f];
        double bottomY = ((double)offset + 320.0) + (double)shutterOpen;
        [self.texBeatBg drawSprite:columnSprite
                           atPoint:CGPointMake(0.0, bottomY)
                         transform:0
                             alpha:1.0f];
    }
}

/** @ghidraAddress 0x210788 */
- (void)renderCombo:(unsigned int)combo alpha:(float)alpha {
    lastCombo = combo; // The phone override only records the combo; it draws nothing.
}

/** @ghidraAddress 0x21079c */
- (void)renderMusicBar:(CGPoint)position timeline:(BOOL)timeline alpha:(float)alpha {
    // The leading difficulty chip sits 3 points lower on retina.
    double chipY = position.y;
    if (isRetina) {
        chipY += 3.0;
    }
    NSUInteger diffSprite;
    switch (self.rendererConf.diff) {
    case 0:
        diffSprite = 7;
        break;
    case 1:
        diffSprite = 8;
        break;
    default:
        diffSprite = 9;
        break;
    }
    [self.texFront drawSprite:diffSprite atPoint:CGPointMake(position.x, chipY)];
    if (!self.sequence) {
        return;
    }
    float playPosition = self.sequence.playPosition;
    const char *bar = (const char *)self.sequence.getMusicBar;
    double cellX = position.x + 40.0;
    double cellY = position.y - 2.0;
    float cursor = playPosition * 120.0f; // The play cursor, in cell units.
    for (unsigned int cell = 0; cell < kMusicBarCellCount; ++cell) {
        // Each cell packs a 4-bit note value into a nibble of the bar byte array.
        int byteIndex = (int)cell >> 1;
        int nibbleShift = ((int)cell - (byteIndex << 1)) * 4;
        unsigned int note = (unsigned int)(((bar[byteIndex] >> nibbleShift) & 0xf) - 1);
        if (note < 8) {
            NSUInteger baseSprite;
            if (self.state == EditNotePhoneStateFinish || self.state == EditNotePhoneStateResult) {
                baseSprite = 0x48;
            } else {
                // The one cell the cursor currently sits in is dim (0x40); every other cell is
                // lit (0x48). The cell is dim only while the cursor is inside its
                // [cell + 0.3, cell + 1.3) window.
                float cellF = (float)(int)cell;
                BOOL lit = (cellF + kMusicBarCellFadeStart < cursor) ?
                               (cellF + kMusicBarCellFadeEnd < cursor) :
                               YES;
                baseSprite = lit ? 0x48 : 0x40;
            }
            [self.texFront drawSprite:(note + baseSprite)
                              atPoint:CGPointMake(cellX + (double)(cell * 2), cellY)
                            transform:0
                                alpha:alpha];
        }
    }
    if (timeline) {
        // The timeline cursor sprite, tracking the play position.
        [self.texFront drawSprite:0x14
                          atPoint:CGPointMake((double)(playPosition * 240.0f + 36.0f), 130.0)
                        transform:0
                            alpha:alpha];
    }
}

/** @ghidraAddress 0x210b48 */
- (void)renderTuneInfo:(CGPoint)position artworkSize:(double)artworkSize alpha:(float)alpha {
    // The jacket, drawn under sprite 11's frame.
    [self.texFront drawSprite:kFrontSpriteJacketFrame
                       inRect:CGRectMake(position.x, position.y, artworkSize, artworkSize)
                    transform:0
                        alpha:alpha];
    double x = position.x + artworkSize;
    double y = position.y - 2.0;
    // The title chip.
    [self.texFront drawSprite:0xc atPoint:CGPointMake(x + 5.0, y - 0.875) transform:0 alpha:alpha];
    x += 8.0;
    y += 32.0;
    // The difficulty word and its per-difficulty, per-idiom level-word x-nudge.
    double levelXNudge;
    switch (self.rendererConf.diff) {
    case 0:
        [self.texFront drawSprite:0xd atPoint:CGPointMake(x, y) transform:0 alpha:alpha];
        levelXNudge = isRetina ? 50.0 : 63.0;
        break;
    case 1:
        [self.texFront drawSprite:0xe atPoint:CGPointMake(x, y) transform:0 alpha:alpha];
        levelXNudge = isRetina ? 81.0 : 102.0;
        break;
    default:
        [self.texFront drawSprite:0xf atPoint:CGPointMake(x, y) transform:0 alpha:alpha];
        levelXNudge = isRetina ? 73.0 : 92.0;
        break;
    }
    x += levelXNudge;
    y -= isRetina ? 3.0 : 4.0;
    // The level word.
    [self.texFront drawSprite:0x13 atPoint:CGPointMake(x, y) transform:0 alpha:alpha];
}

/** @ghidraAddress 0x210ddc */
- (void)renderUpperBG:(BOOL)arg {
    // The phone override draws nothing.
}

/** @ghidraAddress 0x210de0 */
- (void)renderUpper {
    [self renderTuneInfo:CGPointMake(8.0, 15.0) artworkSize:80.0 alpha:1.0f];
    [self renderMusicBar:CGPointMake(136.0, 0.0)
                timeline:(self.state == EditNotePhoneStatePlaying)
                   alpha:1.0f];
}

/** @ghidraAddress 0x210e5c */
- (void)renderButtons {
    for (unsigned int panel = 0; panel < kGridPanelCount; ++panel) {
        double panelX = (double)((int)(panel % kGridColumns) * kGridPitch);
        double panelY = (double)((int)(panel / kGridColumns) * kGridPitch + kGridTopOffset);
        BOOL pressed = (self.btnPress & (1 << panel)) != 0;
        if (pressed) {
            [self.texFront drawSprite:kFrontSpriteButton atPoint:CGPointMake(panelX, panelY)];
            [self.texFront drawSprite:kFrontSpriteButton
                              atPoint:CGPointMake(panelX + 40.0, panelY)
                            transform:5
                                alpha:1.0f];
            [self.texFront drawSprite:1 atPoint:CGPointMake(panelX, panelY)];
        } else {
            [self.texFront drawSprite:0 atPoint:CGPointMake(panelX, panelY)];
        }
    }
}

/** @ghidraAddress 0x210fe8 */
- (void)renderPreStart {
    [self renderShutter:YES];
    [self renderUpperBG:NO];
    // The tune information slides in from x=28 to x=8 and fades in over the first 20 frames.
    float alpha = InterpolateFloatByFrame(0.0f, 1.0f, frame, 10, 0x14);
    float slideX = InterpolateFloatByFrame(28.0f, 8.0f, frame, 10, 0x14);
    [self renderTuneInfo:CGPointMake((double)slideX, 15.0) artworkSize:80.0 alpha:alpha];
    float barAlpha = InterpolateFloatByFrame(0.0f, 1.0f, frame, 0, 10);
    [self renderMusicBar:CGPointMake(136.0, 0.0) timeline:NO alpha:barAlpha];
    [self renderButtons];
    if (frame == 0x14) {
        [AudioManager.sharedManager playSeResFile:@"SD_MUON" inDirectory:nil];
        self.subState = kEditNotePhonePreStartDoneSubState;
    }
}

/** @ghidraAddress 0x21114c */
- (void)renderReadyGo {
    EditNoteRendererPhoneRenderReadyGoReady(self, frame);
    EditNoteRendererPhoneRenderReadyGoGo(self, frame);
    EditNoteRendererPhoneRenderReadyGoAudio(self, frame);
}

/** @ghidraAddress 0x211978 */
- (void)renderFullcombo:(int)frameArg isResult:(BOOL)isResult {
    // The result variant runs the animation shifted by the intro length (0x96).
    unsigned int current = (frameArg < 0x97) ? (unsigned int)frameArg : 0x96;
    if (isResult) {
        current = (unsigned int)(frameArg + 0x96);
    }
    if ((int)current > 0xa0) {
        return;
    }
    if (current == 2) {
        [AudioManager.sharedManager playSeResFile:@"SD_KNT_RESULT_FULLCOMBO" inDirectory:nil];
        [AudioManager.sharedManager playSeResFile:@"SD_KNT_CV_FULLCOMBO" inDirectory:nil];
    }
    CGRect banner = [self.texFront spriteAtIndex:kFrontSpriteFullcombo];
    // The banner is drawn sideways: its "height" field is the on-screen width, so half of it
    // centres the two mirrored halves. The banner rests at 200 and starts off-screen at 440.
    double halfSpan = banner.size.height * 0.5;
    float restX = (float)(200.0 - halfSpan);
    float startX = (float)(440.0 - halfSpan);
    if ((int)current < 0x96) {
        EditNoteRendererPhoneRenderFullcomboIn(self, current, banner, restX, startX);
    } else {
        EditNoteRendererPhoneRenderFullcomboOut(self, current, banner, restX, startX);
    }
}

/** @ghidraAddress 0x211ea0 */
- (void)renderFinish {
    // The phone override draws nothing.
}

/** @ghidraAddress 0x211eb4 */
- (void)draw {
    switch (self.state) {
    case EditNotePhoneStatePreStart:
        [self renderPreStart];
        break;
    case EditNotePhoneStateReady:
        [self renderShutter:YES];
        [self renderUpperBG:NO];
        [self renderUpper];
        [self renderButtons];
        [self renderReadyGo];
        break;
    case EditNotePhoneStatePlaying:
        [self renderShutter:YES];
        [self renderUpperBG:NO];
        [self renderUpper];
        [self renderMarker];
        [self renderButtons];
        break;
    case EditNotePhoneStateFinish:
        [self renderShutter:YES];
        [self renderUpperBG:NO];
        [self renderUpper];
        [self renderMarker];
        [self renderButtons];
        [self renderFinish];
        break;
    case EditNotePhoneStateResult:
        break;
    default:
        [self renderShutter:YES];
        [self renderUpperBG:NO];
        [self renderButtons];
        break;
    }
    [self.texBeatBg commitDraw];
    [self.texMarker commitDraw];
    [self.texFront commitDraw];
    [self.texReady0 commitDraw];
    [self.texReady1 commitDraw];
    ++frame;
}

/** @ghidraAddress 0x212158 */
- (void)drawDebugText:(const char *)text pos:(CGPoint)pos alpha:(float)alpha {
    double x = pos.x;
    double y = pos.y;
    int drawn = 0;
    long i = 0;
    while (true) {
        char c = text[i];
        if (c == '\0') {
            break;
        }
        if (c == '\n') {
            y += 20.0;
            ++i;
            x = pos.x;
            continue;
        }
        if (c <= ' ' || c == '\x7f') {
            ++i;
            x += 12.0;
            continue;
        }
        [self.texDebugFont drawSprite:(NSUInteger)((long)c - kDebugFontFirstGlyph)
                              atPoint:CGPointMake(x, y)
                            transform:0
                                alpha:alpha];
        ++drawn;
        ++i;
        x += 12.0;
        if (drawn >= kDebugTextGlyphCap) {
            break;
        }
    }
    if (drawn != 0) {
        [self.texDebugFont commitDraw];
    }
}

@end
