#import "MainGameRendererPadRpl.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import "AudioManager.h"
#import "BFCodec.h"
#import "BGRipple.h"
#import "EAGLView.h"
#import "HoldMarkerRender.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "MarkerManager.h"
#import "RendererConf.h"
#import "Sequence.h"
#import "Texture2D.h"
#import "TextureLoading.h"
#import "UILabel+RenderImage.h"
#import "UpperBGRipple.h"
#import "cipher_keys.h"
#import "combo_display.h"
#import "neEngineBridge.h"

// Pi as a __const literal-pool slot (not an exported global; the binary loads it inline).
static const double g_dPi = 3.141592653589793; // @ghidraAddress 0x28f278

// The animation key-time literals shared across the render family, loaded from __const.
static const float g_flKeyTime040 = 0.4f; // @ghidraAddress 0x28f3b4
static const float g_flKeyTime060 = 0.6f; // @ghidraAddress 0x28f3b8
static const float g_flKeyTime070 = 0.7f; // @ghidraAddress 0x28f3bc
static const float g_flKeyTime080 = 0.8f; // @ghidraAddress 0x28f3c0
static const float kComboFadeBase = 0.3f; // An fmov immediate.

// -renderImage renders a view into a UIImage. It is a category the binary provides on UIView whose
// declaring class is not established; declared here so the partner-name label can be messaged.
// The high-level render states, dispatched on by -draw and -setState:.
static const unsigned int kRenderStatePreStart = 1;
static const unsigned int kRenderStateReadyGo = 2;
static const unsigned int kRenderStatePlay = 3;
static const unsigned int kRenderStateFinish = 4;
static const unsigned int kRenderStateResult = 5;
static const unsigned int kRenderStateResultWait = 6;

// The sub-state that marks the play session as finished.
static const unsigned int kMainGameEndSubState = 99;

// The 4x4 grid: each cell is 0xc0 (192) points on a side.
static const int kGridCellSize = 0xc0;

// The per-panel button-cell corner insets, in points.
static const int kButtonCellOriginX = 0x60;  // 96
static const int kButtonCellOriginY = 0x160; // 352

// The score above which combo counting begins to draw (the counter shows only above four).
static const unsigned int kComboDrawThreshold = 4;

// The panel-grid geometry shared by the marker and button renderers, in points.
enum {
    kPanelMarkerInset = 0x10, // 16, marker inset within a grid cell.
    kPanelGridTop = 0x100,    // 256, the grid's top, below the header region.
};

// The one-letter difficulty code spliced into the "game_diff_%s_rpl", "game_mbar_%s_rpl", and
// "game_upper_bg_up_%s" resource names: basic, advanced, extreme, or (for anything else) the
// fallback code. The binary selects this from single-character C strings at 0x280488..0x28048e.
static inline const char *MainGameRendererPadRplDiffCode(int diff) {
    switch (diff) {
    case 0:
        return "b"; // @ghidraAddress 0x280488
    case 1:
        return "a"; // @ghidraAddress 0x28048a
    case 2:
        return "e"; // @ghidraAddress 0x28048c
    default:
        return "o"; // @ghidraAddress 0x28048e
    }
}

// Computes the top-left origin of grid panel index 0..15 (marker/start-mark placement): insets each
// cell and shifts the grid down below the header region.
static inline CGPoint MainGameRendererPadRplPanelOrigin(int panel) {
    double x = (double)(((panel % 4) * kGridCellSize) | kPanelMarkerInset);
    double y = (double)((((panel / 4) * kGridCellSize) | kPanelMarkerInset) + kPanelGridTop);
    return CGPointMake(x, y);
}

// Maps a marker-state (phase, slot) pair to its texMarker sprite index. Returns NO when the panel
// has no live marker.
static inline BOOL
MainGameRendererPadRplMarkerSprite(unsigned int phase, unsigned int slot, int *sprite) {
    if (slot == 0) {
        if (phase >= 0xf0) {
            return NO;
        }
        *sprite = (int)(phase / 10) + 4;
        return YES;
    }
    if (phase < 0xa0 && slot < 6) {
        int candidate = (int)(phase / 10) + (int)slot * 0x10 - 4;
        if (candidate >= 0) {
            *sprite = candidate;
            return YES;
        }
    }
    return NO;
}

@implementation MainGameRendererPadRpl

#pragma mark - Lifecycle

/** @ghidraAddress 0x119430 */
- (instancetype)init {
    if ((self = [super init])) {
        // The background ripple pool (up to 64) and the upper-background ripple pool (up to 40).
        self.arrayBgRip = [[NSMutableArray alloc] initWithCapacity:0x40];
        self.arrayUpperBgRip = [[NSMutableArray alloc] initWithCapacity:0x28];
    }
    return self;
}

/** @ghidraAddress 0x121a08 */
- (void)dealloc {
    [self releaseTexture];
    // [super dealloc] is compiler-emitted (ARC).
}

#pragma mark - Textures

/** @ghidraAddress 0x11ab94 */
- (void)releaseTexture {
    self.texDebugFont = nil;
    self.texReady0 = nil;
    self.texReady1 = nil;
    self.texFront = nil;
    self.texResult = nil;
}

/** @ghidraAddress 0x1194f8 */
- (void)loadTexure:(RendererConf *)conf artwork:(UIImage *)artwork index:(UIImage *)index {
    // The square atlas dimensions: the front atlas is 1024, every other atlas 2048 texels.
    static const unsigned int kFrontTexPixelSize = 0x400;
    static const unsigned int kAtlasTexPixelSize = 0x800;

    // The clamp bounds for the configuration: difficulty 0..3, level 0..10.
    static const unsigned int kMaxDiff = 3;
    static const unsigned int kMaxLevel = 10;

    // The marker atlas layout: 24 hit frames from sprite 4 up, then four hold-direction rows of 16
    // frames each into the sprite bands the base table names.
    static const int kMarkerFrameCount = 0x18;
    static const unsigned int kMarkerSpriteBase = 4;
    static const int kMarkerHoldRowCount = 4;
    static const int kHoldFramesPerRow = 0x10;
    /** @ghidraAddress 0x292c70 */
    static const int kMarkerHoldRowSpriteBase[] = {28, 44, 60, 76};

    // The hold-marker atlas layout: six rows of 16 frames (sprites 0..95), then an eight-frame
    // final row from sprite 0x60.
    static const int kHoldMarkerRowCount = 6;
    static const int kHoldMarkerLastRowFrameCount = 8;
    static const unsigned int kHoldMarkerLastRowSpriteBase = 0x60;

    // The front atlas sprite slots the background art, difficulty, music-bar, level, start/end
    // marks, jacket artwork, index image, and partner-name label are blitted into.
    static const unsigned int kFrontSpriteBackground = 0x18;
    static const unsigned int kFrontSpriteDiff = 0x19;
    static const unsigned int kFrontSpriteMusicBar = 0x16;
    static const unsigned int kFrontSpriteLevel = 0x1a;
    static const unsigned int kFrontSpriteUpper = 0;
    static const unsigned int kFrontSpriteStartMark = 0x1d;
    static const unsigned int kFrontSpriteEndMark = 0x20;
    static const unsigned int kFrontSpriteArtwork = 0x17;
    static const unsigned int kFrontSpriteIndex = 0x18;
    static const unsigned int kFrontSpritePartner = 0x27;

    // The partner-name label's bold system font size.
    static const CGFloat kPartnerNameFontSize = 16.0; // @ghidraAddress fmov 0x4030000000000000

    // The upper-background ripple pool: 60 bouncing sprites, seeded from arc4random.
    static const int kUpperBgRippleCount = 0x3c;
    static const unsigned int kUpperBgSpriteMod = 4;
    static const unsigned int kUpperBgSpriteBase = 5;
    static const unsigned int kUpperBgXBase = 0x300; // 768, the field width
    static const unsigned int kUpperBgYBias = 0xb4;  // 180
    static const unsigned int kUpperBgYMod = 100;
    static const float kUpperBgYPeriodDiv = 30.0f;     // An fmov immediate.
    static const float kUpperBgMagScale = 0.00390625f; // @ghidraAddress 0x292a90 (1/256)

    NSData *cipherKey = CreateTextureCipherKey();
    BFCodec *cipher = [[BFCodec alloc] init];

    const char *diffCode = nullptr;
    @autoreleasepool {
        if (!self.texDebugFont) {
            self.texDebugFont = CreateTexture2DFromPngResource(@"debugfont");
        }
        if (!self.texReady0) {
            [cipher cipherInit:cipherKey];
            self.texReady0 =
                CreateTexture2DFromEncryptedTexResource(@"game_ready_rpl_0_tex", cipher);
        }
        if (!self.texReady1) {
            [cipher cipherInit:cipherKey];
            self.texReady1 =
                CreateTexture2DFromEncryptedTexResource(@"game_ready_rpl_1_tex", cipher);
        }

        // Clamp the configuration into the range the atlases cover.
        if ((unsigned int)conf.diff > kMaxDiff) {
            conf.diff = kMaxDiff;
        }
        if ((unsigned int)conf.level > kMaxLevel) {
            conf.level = kMaxLevel;
        }

        // If the front atlas is already loaded for this exact marker, difficulty, level, and tune,
        // there is nothing to reload.
        if (self.texFront && [conf.markerID isEqualToString:self.rendererConf.markerID] &&
            conf.diff == self.rendererConf.diff && conf.level == self.rendererConf.level &&
            conf.tuneID == self.rendererConf.tuneID) {
            return;
        }

        if (self.texFront) {
            self.texFront = nil;
        }
        // The binary reads conf.diff three times here to decide the code, discarding the first two
        // reads; keep a single decode.
        diffCode = MainGameRendererPadRplDiffCode((int)conf.diff);

        // Build the front atlas: an empty 1024-square texture whose sprite rects come from the
        // plist, then the encrypted image blitted in at the origin.
        self.texFront = [[Texture2D alloc] initWithData:nullptr
                                            pixelFormat:Texture2DPixelFormatRGBA8888
                                              pixelSize:kFrontTexPixelSize];
        NSString *frontPlist = [NSBundle.mainBundle pathForResource:@"game_front_rpl_tex"
                                                             ofType:@"plist"];
        self.texFront.sprites = [[NSArray alloc] initWithContentsOfFile:frontPlist];
        [cipher cipherInit:cipherKey];
        LoadTextureSubImageFromEncryptedTex(
            self.texFront, @"game_front_rpl_tex", cipher, CGPointMake(0.0, 0.0));
    }

    // Build the combo atlas from its plist and one encrypted image, then re-key the cipher.
    @autoreleasepool {
        if (self.texCombo) {
            self.texCombo = nil;
        }
        self.texCombo = [[Texture2D alloc] initWithData:nullptr
                                            pixelFormat:Texture2DPixelFormatRGBA8888
                                              pixelSize:kAtlasTexPixelSize];
        NSString *comboPlist = [NSBundle.mainBundle pathForResource:@"game_combo_rpl_tex"
                                                             ofType:@"plist"];
        self.texCombo.sprites = [[NSArray alloc] initWithContentsOfFile:comboPlist];
        [cipher cipherInit:cipherKey];
        LoadTextureSubImageFromEncryptedTex(
            self.texCombo, @"game_combo_rpl_tex", cipher, CGPointMake(0.0, 0.0));
        [cipher cipherInit:cipherKey]; // Yes, the binary re-keys the cipher here though nothing
                                       // uses it before the next explicit re-key.
    }

    // Build the marker atlas: a 2048-square texture from its own plist.
    @autoreleasepool {
        if (self.texMarker) {
            self.texMarker = nil;
        }
        self.texMarker = [[Texture2D alloc] initWithData:nullptr
                                             pixelFormat:Texture2DPixelFormatRGBA8888
                                               pixelSize:kAtlasTexPixelSize];
        NSString *markerPlist = [NSBundle.mainBundle pathForResource:@"game_marker_tex"
                                                              ofType:@"plist"];
        self.texMarker.sprites = [[NSArray alloc] initWithContentsOfFile:markerPlist];
    }

    // Blit the background art from the tension-tier-0 background resource into the combo atlas.
    NSString *bgPath =
        [NSBundle.mainBundle pathForResource:[NSString stringWithFormat:@"game_bg_rpl_%d", 0]
                                      ofType:@"png"];
    if (bgPath) {
        UIImage *bgImage = [[UIImage alloc] initWithContentsOfFile:bgPath];
        [self.texCombo setSubImage:bgImage
                            inRect:[self.texCombo spriteAtIndex:kFrontSpriteBackground]];
    }

    // Blit the 24 marker hit frames (ma00..ma23) into sprites 4 upward from the marker archive.
    NSString *markerPath = [MarkerManager getMarkerPath:conf.markerID];
    KUnzip *markerZip = [[KUnzip alloc] initWithPath:markerPath];
    @autoreleasepool {
        for (int i = 0; i < kMarkerFrameCount; ++i) {
            [cipher cipherInit:cipherKey];
            NSString *entry = [NSString stringWithFormat:@"ma%02d", i];
            NSMutableData *bytes = [markerZip uncompress:entry];
            UIImage *image = CreateImageFromEncryptedData(cipher, bytes);
            if (image) {
                unsigned int idx = (unsigned int)(i + kMarkerSpriteBase);
                [self.texMarker setSubImage:image
                                    atPoint:[self.texMarker spriteAtIndex:idx].origin];
            }
        }
    }

    // Blit the four hold-direction rows (h0..h3), each 16 frames, into the marker atlas.
    for (int row = 0; row < kMarkerHoldRowCount; ++row) {
        @autoreleasepool {
            for (int i = 0; i < kHoldFramesPerRow; ++i) {
                [cipher cipherInit:cipherKey];
                NSString *entry = [NSString stringWithFormat:@"h%d%02d", row, i];
                NSMutableData *bytes = [markerZip uncompress:entry];
                UIImage *image = CreateImageFromEncryptedData(cipher, bytes);
                if (image) {
                    unsigned int idx = (unsigned int)(i + kMarkerHoldRowSpriteBase[row]);
                    [self.texMarker setSubImage:image
                                        atPoint:[self.texMarker spriteAtIndex:idx].origin];
                }
            }
        }
    }

    // Build the hold-marker atlas and its sub-renderer.
    @autoreleasepool {
        if (self.texHoldMarker) {
            self.texHoldMarker = nil;
        }
        self.texHoldMarker = [[Texture2D alloc] initWithData:nullptr
                                                 pixelFormat:Texture2DPixelFormatRGBA8888
                                                   pixelSize:kAtlasTexPixelSize];
        NSString *holdPlist = [NSBundle.mainBundle pathForResource:@"game_hold_marker_tex"
                                                            ofType:@"plist"];
        self.texHoldMarker.sprites = [[NSArray alloc] initWithContentsOfFile:holdPlist];

        if (!self->holdMarkerRender) {
            self->holdMarkerRender = [[HoldMarkerRender alloc] init:self.texHoldMarker
                                                              isPad:YES
                                                      gameAreaDelay:0];
        }
    }

    // Blit the hold-marker frames from hm0001.zip: six rows of 16 (m0..m5, sprites 0..95) then the
    // eight-frame final row (m6, sprites 0x60 upward).
    NSString *holdMarkerPath = [NSBundle.mainBundle pathForResource:@"hm0001" ofType:@"zip"];
    KUnzip *holdMarkerZip = [[KUnzip alloc] initWithPath:holdMarkerPath];
    for (int row = 0; row < kHoldMarkerRowCount; ++row) {
        for (int i = 0; i < kHoldFramesPerRow; ++i) {
            [cipher cipherInit:cipherKey];
            NSString *entry = [NSString stringWithFormat:@"m%d%02d", row, i];
            NSMutableData *bytes = [holdMarkerZip uncompress:entry];
            UIImage *image = CreateImageFromEncryptedData(cipher, bytes);
            if (image) {
                unsigned int idx = (unsigned int)(row * kHoldFramesPerRow + i);
                [self.texHoldMarker setSubImage:image
                                        atPoint:[self.texHoldMarker spriteAtIndex:idx].origin];
            }
        }
    }
    for (int i = 0; i < kHoldMarkerLastRowFrameCount; ++i) {
        [cipher cipherInit:cipherKey];
        NSString *entry = [NSString stringWithFormat:@"m6%02d", i];
        NSMutableData *bytes = [holdMarkerZip uncompress:entry];
        UIImage *image = CreateImageFromEncryptedData(cipher, bytes);
        if (image) {
            unsigned int idx = (unsigned int)(i + kHoldMarkerLastRowSpriteBase);
            [self.texHoldMarker setSubImage:image
                                    atPoint:[self.texHoldMarker spriteAtIndex:idx].origin];
        }
    }

    // Blit the difficulty label, music-bar label, level label, upper-background band, start/end
    // marks, jacket artwork, and index image into their front-atlas slots.
    LoadTextureSubImageFromResource(self.texFront,
                                    [NSString stringWithFormat:@"game_diff_%s_rpl", diffCode],
                                    [self.texFront spriteAtIndex:kFrontSpriteDiff].origin);
    LoadTextureSubImageFromResource(self.texFront,
                                    [NSString stringWithFormat:@"game_mbar_%s_rpl", diffCode],
                                    [self.texFront spriteAtIndex:kFrontSpriteMusicBar].origin);
    LoadTextureSubImageFromResource(self.texFront,
                                    [NSString stringWithFormat:@"game_lv_%d_rpl", (int)conf.level],
                                    [self.texFront spriteAtIndex:kFrontSpriteLevel].origin);
    LoadTextureSubImageFromResource(self.texFront,
                                    [NSString stringWithFormat:@"game_upper_bg_up_%s", diffCode],
                                    [self.texFront spriteAtIndex:kFrontSpriteUpper].origin);
    LoadTextureSubImageFromResource(self.texFront,
                                    @"game_start_mark_rpl",
                                    [self.texFront spriteAtIndex:kFrontSpriteStartMark].origin);
    LoadTextureSubImageFromResource(self.texFront,
                                    @"game_end_mark_rpl",
                                    [self.texFront spriteAtIndex:kFrontSpriteEndMark].origin);
    [self.texFront setSubImage:artwork
                       atPoint:[self.texFront spriteAtIndex:kFrontSpriteArtwork].origin];
    [self.texFront setSubImage:index
                       atPoint:[self.texFront spriteAtIndex:kFrontSpriteIndex].origin];

    // When the tune has a partner, render its name into a right-aligned label and blit that into
    // the front atlas's partner slot.
    if (conf.partnerName) {
        UILabel *label =
            [[UILabel alloc] initWithFrame:[self.texFront spriteAtIndex:kFrontSpritePartner]];
        label.opaque = NO;
        label.backgroundColor = UIColor.clearColor;
        label.textColor = UIColor.blackColor;
        label.textAlignment = NSTextAlignmentRight;
        label.font = [UIFont boldSystemFontOfSize:kPartnerNameFontSize];
        label.text = conf.partnerName;
        UIImage *labelImage = [label renderImage];
        [self.texFront setSubImage:labelImage
                           atPoint:[self.texFront spriteAtIndex:kFrontSpritePartner].origin];
    }

    self.rendererConf = conf;

    // Rebuild the upper-background ripple pool: 60 bouncing sprites with randomised motion, then
    // depth-sorted; the background ripple pool is cleared.
    [self.arrayUpperBgRip removeAllObjects];
    for (int i = 0; i < kUpperBgRippleCount; ++i) {
        unsigned int yPeriod = (arc4random() % 10) * 0x1e + 0x96;
        NSUInteger sprite = (arc4random() % kUpperBgSpriteMod) + kUpperBgSpriteBase;
        float xSpeed = (float)(arc4random() % 0x18 + 6) / kUpperBgYPeriodDiv;
        float yGround = (float)(arc4random() % 0x19 + 0xaf);
        float yAmp = (float)(arc4random() % 0x14 + 10);
        unsigned int yPhaseRaw = arc4random() % 0x78 + 0x1e;
        unsigned int atX = arc4random() % kUpperBgXBase;
        unsigned int atY = arc4random() % kUpperBgYMod + kUpperBgYBias;
        unsigned int yCenterRaw = arc4random();
        unsigned int phase = (yPeriod != 0) ? (yCenterRaw % yPeriod) : 0;
        float mag = (float)((arc4random() & 0x7f) + 0x60) * kUpperBgMagScale;
        UpperBGRipple *ripple =
            [[UpperBGRipple alloc] initWithSprite:sprite
                                          atPoint:CGPointMake((double)atX, (double)atY)
                                           xSpeed:(float)yPeriod
                                          yGround:yGround
                                             yAmp:xSpeed
                                          yCenter:yAmp
                                          yPeriod:yPhaseRaw
                                           yPhase:phase
                                              mag:mag];
        [self.arrayUpperBgRip addObject:ripple];
    }
    [self.arrayUpperBgRip sortUsingSelector:@selector(compZ:)];
    [self.arrayBgRip removeAllObjects];
}

/** @ghidraAddress 0x11aa04 */
- (void)loadResultTex:(short)rank {
    // The eight per-rank judgement resources, indexed by rank tier 0..7. A rank of 8 or above
    // draws no additional judgement graphic.
    static NSString *const kJudgementResources[] = {
        @"res_judgement_e_rpl",
        @"res_judgement_d_rpl",
        @"res_judgement_c_rpl",
        @"res_judgement_b_rpl",
        @"res_judgement_a_rpl",
        @"res_judgement_s_rpl",
        @"res_judgement_ss_rpl",
        @"res_judgement_sss_rpl",
    };

    if (self.texResult) {
        self.texResult = nil;
    }
    BFCodec *cipher = [[BFCodec alloc] init];
    NSData *cipherKey = CreateTextureCipherKey();
    [cipher cipherInit:cipherKey];
    self.texResult = CreateTexture2DFromEncryptedTexResource(@"game_result_rpl_tex", cipher);

    if (rank < 8) {
        // Blit the rank's judgement glyph into the result atlas from its bundled resource. The
        // binary passes CGPointZero here.
        LoadTextureSubImageFromResource(
            self.texResult, kJudgementResources[rank], CGPointMake(0.0, 0.0));
    }
}

#pragma mark - State

/** @ghidraAddress 0x11ac10 */
- (void)setState:(unsigned int)state {
    switch (state) {
    case 0:
        self->lastCombo = 0;
        self->comboCutFrame = 0;
        self->comboEffectFrame = 0;
        self->scoreDisplay = 0;
        self->shutterOpen = 0.0f;
        self->lastHakuPhase = 0.0f;
        self->bounceEnergy = 0.0f;
        break;
    case kRenderStateReadyGo:
        self->lastCombo = 0;
        self->comboCutFrame = 0;
        self->comboEffectFrame = 0;
        self->scoreDisplay = 0;
        self->shutterOpen = 0.0f;
        self->startMarkFrame = 0;
        if (!self.sePlayerGo) {
            NSString *path = [NSBundle.mainBundle pathForResource:@"SD_RPL_CV_GO" ofType:@"caf"];
            NSURL *url = [NSURL fileURLWithPath:path];
            self.sePlayerGo = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
            [self.sePlayerGo prepareToPlay];
        }
        break;
    case kRenderStateResult:
        [[AudioManager sharedManager] loadBgmResAAC:@"SD_RPL_BGM_RESULT" inDirectory:nil];
        [[AudioManager sharedManager] startBgm:YES fadeTime:0.0];
        break;
    case kRenderStateResultWait:
        // The result-wait state leaves every counter untouched and does not reset the frame.
        [super setState:state];
        return;
    default:
        break;
    }
    self->frame = 0;
    [super setState:state];
}

#pragma mark - Play lifecycle

/** @ghidraAddress 0x11aef8 */
- (void)startPlay {
    [self setState:kRenderStatePlay];
    self.sePlayerGo = nil;
}

/** @ghidraAddress 0x11af34 */
- (void)endResult {
    if (self.state == kRenderStateResult) {
        self.subState = kMainGameEndSubState;
    }
}

/** @ghidraAddress 0x121a68 */
- (void)replaySelect {
    if (self.isCustom && self.isDownload && self.hasMusic) {
        self.replayPlaying = YES;
        // spriteAtIndex: is called only for its side effect on the shared draw scratch; the point
        // then read is the atlas origin, so the start mark reloads at (0, 0).
        [self.texFront spriteAtIndex:0x1d];
        LoadTextureSubImageFromResource(
            self.texFront, @"game_start_mark_rpl", CGPointMake(0.0, 0.0));
        self.isTextureChange = NO;

        /** @ghidraAddress 0x28f260 */
        static const NSTimeInterval kGoodJobFadeDuration = 0.3;
        __weak UIImageView *goodJob = self.goodJobImage;
        [UIView animateWithDuration:kGoodJobFadeDuration
                         animations:^{
                           /** @ghidraAddress 0x121be4 */
                           [goodJob setAlpha:0.0f];
                         }
                         completion:^(BOOL finished){
                             /** @ghidraAddress 0x121c30 */
                             // The completion block is the shared empty global block.
                         }];
    }
}

/** @ghidraAddress 0x121a58 */
- (void)replayEnd {
    self.replayPlaying = NO;
}

/** @ghidraAddress 0x11e2f8 */
- (double)durationOfReadyGo {
    /** @ghidraAddress 0x292a08 */
    static const double kReadyGoDuration = 2.8333333333333335;
    return kReadyGoDuration;
}

#pragma mark - Layout

/** @ghidraAddress 0x1208cc */
- (double)buttonAreaOffset {
    return 0.0;
}

/** @ghidraAddress 0x1208d4 */
- (double)gameAreaOffset {
    /** @ghidraAddress 0x28e030 */
    static const double kGameAreaOffset = 256.0;
    return kGameAreaOffset;
}

#pragma mark - Buttons

/** @ghidraAddress 0x1208e0 */
- (unsigned int)endButtonID {
    return 0xf;
}

/** @ghidraAddress 0x1208e8 */
- (unsigned int)evaluateButtonID {
    return 0xe;
}

/** @ghidraAddress 0x1208f0 */
- (unsigned int)goodJobButtonID {
    return 0xd;
}

/** @ghidraAddress 0x1208f8 */
- (CGPoint)goodJobPosition {
    unsigned int buttonID = self.goodJobButtonID;
    double x = (double)((buttonID & 3) * kGridCellSize + kButtonCellOriginX);
    double y = (double)((buttonID >> 2) * kGridCellSize + kButtonCellOriginY);
    return CGPointMake(x, y);
}

/** @ghidraAddress 0x120968 */
- (unsigned int)twitterSendButtonID {
    return 0xe;
}

/** @ghidraAddress 0x120970 */
- (CGPoint)twitterBtnPosition {
    unsigned int buttonID = self.twitterSendButtonID;
    double x = (double)((buttonID & 3) * kGridCellSize + kButtonCellOriginX);
    double y = (double)((buttonID >> 2) * kGridCellSize + kButtonCellOriginY);
    return CGPointMake(x, y);
}

/** @ghidraAddress 0x1209e0 */
- (unsigned int)storeMoveButtonID {
    return 0xe;
}

/** @ghidraAddress 0x1209e8 */
- (CGPoint)storeMoveBtnPosition {
    unsigned int buttonID = self.storeMoveButtonID;
    double x = (double)((buttonID & 3) * kGridCellSize + kButtonCellOriginX);
    double y = (double)((buttonID >> 2) * kGridCellSize + kButtonCellOriginY);
    return CGPointMake(x, y);
}

#pragma mark - Drawing

/** @ghidraAddress 0x121590 */
- (void)draw {
    switch (self.state) {
    case kRenderStatePreStart:
        [self renderPreStart];
        break;
    case kRenderStateReadyGo:
        [self renderBG];
        [self renderShutter:YES];
        [self renderUpperBG:NO];
        [self renderUpper];
        [self renderStartMark:1.0f];
        [self renderButtons];
        [self renderReadyGo];
        break;
    case kRenderStatePlay:
        [self renderBG];
        [self renderShutter:YES];
        [self renderCombo:(unsigned int)[self.sequence getScore]->curCombo alpha:1.0f];
        [self renderUpperBG:NO];
        [self renderUpper];
        [self renderMarker];
        [self renderButtons];
        break;
    case kRenderStateFinish:
        [self renderBG];
        [self renderShutter:YES];
        [self renderCombo:(unsigned int)[self.sequence getScore]->curCombo alpha:1.0f];
        [self renderUpperBG:NO];
        [self renderUpper];
        [self renderMarker];
        [self renderButtons];
        [self renderFinish];
        break;
    case kRenderStateResult:
    case kRenderStateResultWait:
        [self renderBG];
        [self renderResult];
        break;
    default:
        [self renderBG];
        [self renderShutter:YES];
        [self renderUpperBG:NO];
        [self renderButtons];
        break;
    }

    [self.texCombo commitDraw];
    [self.texHoldMarker commitDraw];
    [self.texMarker commitDraw];
    [self.texFront commitDraw];
    [self.texReady0 commitDraw];
    [self.texReady1 commitDraw];
    [self.texResult commitDraw];
    ++self->frame;
}

/** @ghidraAddress 0x1218e0 */
- (void)drawDebugText:(const char *)text pos:(CGPoint)pos alpha:(float)alpha {
    static const double kDebugGlyphAdvance = 12.0;
    static const double kDebugLineAdvance = 20.0;
    static const int kDebugGlyphLimit = 0x200;
    static const NSUInteger kDebugGlyphBase = 0x20; // the sprite for a leading space

    double y = pos.y;
    double x = pos.x;
    int drawn = 0;
    for (long i = 0; text[i] != '\0'; ++i) {
        char c = text[i];
        if (c == '\n') {
            // A newline resets to the left margin and steps down one line.
            y += kDebugLineAdvance;
            x = pos.x;
            continue;
        }
        if (c > ' ' && c != '\x7f') {
            [self.texDebugFont drawSprite:(NSUInteger)(c - kDebugGlyphBase)
                                  atPoint:CGPointMake(x, y)
                                transform:0
                                    alpha:alpha];
            ++drawn;
            if (drawn >= kDebugGlyphLimit) {
                break;
            }
        }
        x += kDebugGlyphAdvance;
    }
    if (drawn != 0) {
        [self.texDebugFont commitDraw];
    }
}

/** @ghidraAddress 0x11b770 */
- (void)renderBG {
    // Base-plate geometry.
    static const double kBasePlateY = 128.0;              // @ghidraAddress 0x28f750
    static const float kBaseScaleNorm = 768.0f;           // @ghidraAddress 0x292550
    static const float kBaseScaleMag = 0.001953125f;      // @ghidraAddress 0x292abc (1/512)
    static const float kBgAppearThreshold = 0.606060624f; // @ghidraAddress 0x292ab4
    static const float kBgAppearHigh = 1.1f;              // @ghidraAddress 0x292ab8
    static const float kBgRippleMag = 0.00390625f;        // @ghidraAddress 0x292a90 (1/256)
    static const float kBgRippleAlphaDiv = 100.0f;        // @ghidraAddress 0x28f4e0
    // Tension thresholds selecting the ripple animation group and its spawn parameters.
    enum {
        kTensionTier1 = 0x100,
        kTensionTier2 = 0x200,
        kTensionTier3 = 0x300,
        kTensionTier4 = 0x400,
    };
    static const NSUInteger kBasePlateSprite = 0x18;

    // The tension picks the base-plate scale curve input; when there is no live sequence, or a
    // replay backup is active, the plate draws at the resting group.
    int tension = 0;
    float haku = 0.0f;
    if (self.sequence != nil) {
        if (self.scoreBackup) {
            return;
        }
        const ScoreData *score = [self.sequence getScore];
        haku = self.sequence.hakuPhase;
        if (score != nil) {
            tension = score->tension;
        }
    }

    // Map the beat phase into a plate scale via InterpolateFloatByPosition: below the threshold the
    // plate is quiet, above it it pulses.
    float scaleInput;
    float scaleFrom;
    float scaleToLow;
    float scaleToHigh;
    if (self.sequence != nil && !self.scoreBackup && haku >= kBgAppearThreshold) {
        scaleInput = haku;
        scaleFrom = kBgAppearThreshold;
        scaleToLow = 1.0f;
        scaleToHigh = kBgAppearHigh;
    } else {
        scaleInput = 0.0f;
        scaleFrom = 0.0f;
        scaleToLow = kBgAppearHigh;
        scaleToHigh = 1.0f;
    }
    float plateScale =
        InterpolateFloatByPosition(scaleInput, 0.0f, scaleFrom, scaleToLow, scaleToHigh);
    float rippleMag = plateScale * kBaseScaleNorm * kBaseScaleMag;

    // The base plate: sprite 0x18 drawn at the plate's top, scaled by the beat pulse.
    [self.texCombo drawSprite:kBasePlateSprite
                      atPoint:CGPointMake(0.0, kBasePlateY)
                        scale:rippleMag
                       rotate:0.0f
                       anchor:CGPointMake(0.0, 0.0)
                    transform:0
                        alpha:1.0f];

    // Step every background ripple and drop the ones that report themselves finished, then render
    // the survivors. The binary builds a to-remove array by messaging -step on each ripple.
    NSMutableArray *toRemove = [NSMutableArray array];
    for (BGRipple *ripple in self.arrayBgRip) {
        if ([ripple step]) {
            [toRemove addObject:ripple];
        } else {
            [ripple renderWithTexture:self.texCombo];
        }
    }
    [self.arrayBgRip removeObjectsInArray:toRemove];

    // On a beat frame (odd frame counter), maybe spawn a new ripple whose spawn parameters come
    // from the tension tier.
    if ((self->frame & 1) != 0) {
        unsigned int spriteBits;
        int lifetime;
        unsigned int spawnChance;
        unsigned int xRange;
        unsigned int yRange;
        if (tension < kTensionTier1) {
            spriteBits = arc4random() & 3;
            lifetime = (int)(arc4random() % 6 + 0x1a);
            spawnChance = 0x80;
            xRange = 300;
            yRange = 300;
        } else if (tension < kTensionTier2) {
            spriteBits = (arc4random() & 3) | 4;
            lifetime = (int)(arc4random() % 0x11 + 0x13);
            spawnChance = 200;
            xRange = 400;
            yRange = 400;
        } else if (tension < kTensionTier3) {
            spriteBits = (arc4random() & 3) | 8;
            lifetime = (int)(arc4random() % 0x16 + 0xc);
            spawnChance = 0xe6;
            xRange = 600;
            yRange = 600;
        } else if (tension < kTensionTier4) {
            spriteBits = (arc4random() & 3) | 0xc;
            lifetime = (int)(arc4random() % 0x12 + 0x1a);
            spawnChance = 0x118;
            xRange = 0x28a;
            yRange = 800;
        } else {
            spriteBits = (arc4random() & 7) | 0x10;
            lifetime = (int)(arc4random() % 0x32 + 0x14);
            spawnChance = 0x154;
            xRange = 500;
            yRange = 800;
        }

        // The spawn-chance selects roughly one in 80, weighted by the tier's chance value.
        if (arc4random() % 0x50 < (unsigned int)(spawnChance & 0x3f)) {
            (void)spawnChance;
        }
        // Faithful: the binary compares arc4random() % 0x50 against the tier's chance value stored
        // in the same register as the tier bits, spawning only sometimes.
        if (arc4random() % 0x50 < (spawnChance)) {
            unsigned int xr = arc4random();
            unsigned int cx = (xr % xRange);
            unsigned int yr = arc4random();
            unsigned int cy = (yr % yRange);
            float baseSize = (float)(int)((arc4random() % spawnChance) + 0x80);
            float xSpeed = baseSize * kBgRippleMag;
            unsigned int life2 = arc4random() % 0x14 + 0x82;
            [self.texCombo spriteAtIndex:spriteBits];
            CGPoint at = CGPointMake((double)((xr + 0x1bc) - (cx + (xRange >> 1))),
                                     (double)((yr + 0x280) - (cy + (yRange >> 1))));
            BGRipple *ripple =
                [[BGRipple alloc] initWithSprite:spriteBits
                                         atPoint:at
                                          xSpeed:xSpeed
                                        lifetime:life2
                                        basesize:rippleMag
                                             mag:baseSize * kBgRippleMag
                                           alpha:(float)lifetime / kBgRippleAlphaDiv];
            [self.arrayBgRip addObject:ripple];
        }
    }
}

/** @ghidraAddress 0x11bd24 */
- (void)renderShutter:(BOOL)drive {
    static const float kTensionScale = 0.0009765625f;  // @ghidraAddress 0x292540 (1/1024)
    static const float kShutterTensionFactor = 435.0f; // @ghidraAddress 0x292544
    static const float kShutterAmpFactor = 10.0f;      // fmov immediate
    static const float kShutterAmpBase = 15.0f;        // fmov immediate
    static const float kShutterHalf = 0.5f;
    static const float kShutterInterpHigh = 2.79999995f; // @ghidraAddress 0x292594
    static const float kBgAppearHigh = 1.1f;             // @ghidraAddress 0x292ab8
    static const double kShutterXNudge = 288.0;          // An fmov immediate.
    static const double kShutterCapY = 384.0;            // An fmov immediate.
    // The shutter-bar and cap sprite index bases in texCombo.
    static const int kShutterBarSpriteBias = 0x19;
    static const NSUInteger kShutterCapSprite0 = 0x1c;
    static const NSUInteger kShutterCapSprite1 = 0x1d;
    // The two shutter-bar layout tables: an index list and a per-bar {x0, y0, x1, y1} float table.
    /** @ghidraAddress 0x292c80 */
    static const int kShutterBarIndex0[] = {2, 0, 0, 0};
    /** @ghidraAddress 0x292c90 */
    static const float kShutterBar0[] = {455.6f,
                                         583.8f,
                                         805.9f,
                                         1031.1f,
                                         342.0f,
                                         595.0f,
                                         25.0f,
                                         1049.0f,
                                         430.1f,
                                         159.2f,
                                         502.3f,
                                         -305.4f,
                                         236.1f,
                                         165.2f,
                                         -45.7f,
                                         -259.4f};
    /** @ghidraAddress 0x292cd0 */
    static const int kShutterBarIndex1[] = {0, 1, 0, 2, 0, 1, 2, 2, 0, 2, 1, 1, 0, 0};
    /** @ghidraAddress 0x292d08 */
    static const float kShutterBar1[] = {
        431.0f,  510.0f,  632.0f,  936.0f, 386.0f,  232.0f, 376.0f, -170.0f, 519.0f,  394.0f,
        942.0f,  406.0f,  502.0f,  326.2f, 942.0f,  117.4f, 271.0f, 418.0f,  -174.5f, 717.4f,
        353.4f,  521.2f,  296.0f,  939.4f, 461.6f,  371.8f, 939.9f, 225.1f,  457.0f,  263.0f,
        724.0f,  -168.0f, 275.0f,  321.1f, -168.9f, 161.2f, 277.6f, 475.8f,  -170.1f, 815.1f,
        326.4f,  356.0f,  -168.1f, 23.1f,  497.4f,  461.0f, 941.9f, 681.1f,  244.0f,  375.0f,
        -172.5f, 491.4f,  308.1f,  257.2f, 26.3f,   -167.4f};

    // The beat phase drives the sinusoidal ripple applied to each bar corner.
    float haku = 0.0f;
    double sinArg = 0.0;
    float tension = 0.0f;
    if (self.sequence != nil) {
        if (self.scoreBackup) {
            return;
        }
        const ScoreData *score = [self.sequence getScore];
        haku = self.sequence.hakuPhase;
        sinArg = (double)haku * g_dPi;
        if (score != nil) {
            tension = (float)score->tension;
        }
    }

    // The shutter-open amount is either advanced from the tension and beat, or held.
    float shutterOpenValue;
    if (drive) {
        float target = tension * kShutterTensionFactor * kTensionScale;
        if (target > 0.0f) {
            float amp = tension * kShutterAmpFactor * kTensionScale + kShutterAmpBase;
            float wave = (float)sin(sinArg);
            target = target + (amp - amp * wave);
        }
        shutterOpenValue = (target + self->shutterOpen) * kShutterHalf;
        self->shutterOpen = shutterOpenValue;
    } else {
        shutterOpenValue = self->shutterOpen;
    }

    float openInterp = InterpolateFloatByPosition(
        shutterOpenValue, 0.0f, kShutterTensionFactor, kBgAppearHigh, 2.79999995f);
    (void)openInterp;

    // First bar group: each of four rows draws its ripple pair from the shared table, offset by the
    // sinusoid.
    double sinOffset = kShutterXNudge; // The x/y sin nudge, 288 at rest.
    (void)sinOffset;
    for (int i = 0; i < 4; ++i) {
        float x0 = InterpolateFloatByPosition(self->shutterOpen,
                                              0.0f,
                                              kShutterTensionFactor,
                                              kShutterBar0[i * 4],
                                              kShutterBar0[i * 4 + 2]);
        float y0 = InterpolateFloatByPosition(self->shutterOpen,
                                              0.0f,
                                              kShutterTensionFactor,
                                              kShutterBar0[i * 4 + 1],
                                              kShutterBar0[i * 4 + 3]);
        double bx = (double)x0;
        double by = (double)y0 + kShutterHalf;
        NSUInteger sprite = (NSUInteger)(kShutterBarIndex0[i] + kShutterBarSpriteBias);
        [self.texCombo drawSprite:sprite
                          atPoint:CGPointMake(bx + sinArg, by + sinArg)
                            scale:openInterp
                           rotate:0.0f
                           anchor:CGPointMake(bx, by)
                        transform:0
                            alpha:1.0f];
        [self.texCombo drawSprite:sprite
                          atPoint:CGPointMake(bx + sinArg, by)
                            scale:openInterp
                           rotate:0.0f
                           anchor:CGPointMake(bx, by)
                        transform:4
                            alpha:1.0f];
    }

    // The four shutter caps, sized by the field, at fixed vertical bands.
    float capInterp = InterpolateFloatByPosition(
        self->shutterOpen, 0.0f, kShutterTensionFactor, 1.0f, kShutterInterpHigh);
    [self.texCombo drawSprite:kShutterCapSprite0
                      atPoint:CGPointMake(kShutterCapY, 256.0)
                        scale:capInterp
                       rotate:0.0f
                       anchor:CGPointMake(kShutterCapY, 576.0)
                    transform:0
                        alpha:1.0f];
    [self.texCombo drawSprite:kShutterCapSprite1
                      atPoint:CGPointMake(536.0, 488.0)
                        scale:capInterp
                       rotate:0.0f
                       anchor:CGPointMake(kShutterCapY, 576.0)
                    transform:0
                        alpha:1.0f];

    // Second bar group: fourteen rows, sinusoid-offset pairs from the larger table.
    for (int i = 0; i < 14; ++i) {
        float x0 = InterpolateFloatByPosition(self->shutterOpen,
                                              0.0f,
                                              kShutterTensionFactor,
                                              kShutterBar1[i * 4],
                                              kShutterBar1[i * 4 + 2]);
        float y0 = InterpolateFloatByPosition(self->shutterOpen,
                                              0.0f,
                                              kShutterTensionFactor,
                                              kShutterBar1[i * 4 + 1],
                                              kShutterBar1[i * 4 + 3]);
        double bx = (double)x0;
        double by = (double)y0 + kShutterHalf;
        NSUInteger sprite = (NSUInteger)(kShutterBarIndex1[i] + kShutterBarSpriteBias);
        [self.texCombo drawSprite:sprite
                          atPoint:CGPointMake(bx + sinArg, by + sinArg)
                            scale:openInterp
                           rotate:0.0f
                           anchor:CGPointMake(bx, by)
                        transform:0
                            alpha:1.0f];
        [self.texCombo drawSprite:sprite
                          atPoint:CGPointMake(bx + sinArg, by)
                            scale:openInterp
                           rotate:0.0f
                           anchor:CGPointMake(bx, by)
                        transform:4
                            alpha:1.0f];
    }
}

/** @ghidraAddress 0x11b434 */
- (void)renderMarker {
    static const float kMarkerFadeDivisor = 100.0f; // @ghidraAddress 0x28f4e0
    static const int kMarkerHighlightSector = 0x96; // 150
    static const int kMarkerFadeClampSectors = 100;
    static const int kMarkerDirModulo = 4;

    int sectorDelta = (int)[self.sequence firstMarkerSector] - (int)[self.sequence currentSector];
    [self.sequence getMarkerState:self->markerState];

    for (int i = 0; i < kMainGameGridPanelCount; ++i) {
        CGPoint origin = MainGameRendererPadRplPanelOrigin(i);
        double x = origin.x;
        double y = origin.y;

        unsigned int stateWord = (unsigned int)self->markerState[i];
        unsigned int phase = stateWord & 0xfff;
        unsigned int slot = (stateWord >> 0xc) & 7;

        int sprite;
        if (MainGameRendererPadRplMarkerSprite(phase, slot, &sprite)) {
            [self.texMarker drawSprite:(NSUInteger)sprite
                               atPoint:CGPointMake(x, y)
                             transform:(char)self->markerDir[i]
                                 alpha:1.0f];
        } else {
            self->markerDir[i] = 0;
            if ([JubeatAppDelegate.appDelegate isMarkerDirRandom]) {
                self->markerDir[i] = rand() % kMarkerDirModulo;
            }
        }
    }

    [self.sequence getHoldMarkerState:self->holdState];
    if (![self.rendererConf isStealth]) {
        // holdState and HoldMarkerInfo are the same 16-byte per-panel record under two names.
        [self->holdMarkerRender renderHoldMarker:(HoldMarkerInfo *)self->holdState];
    }

    // Once the first marker approaches within the highlight window, cue the start mark, fading it
    // in over the approach.
    if (sectorDelta > kMarkerHighlightSector) {
        int fadeSectors = sectorDelta - kMarkerHighlightSector;
        float alpha = 1.0f;
        if (fadeSectors < kMarkerFadeClampSectors) {
            alpha = (float)fadeSectors / kMarkerFadeDivisor;
        }
        [self renderStartMark:alpha];
    }
}

/** @ghidraAddress 0x11af80 */
- (void)renderStartMark:(float)alpha {
    static const double kStartMarkInset = 0.9f; // @ghidraAddress 0x28f3b0-area (used as pad offset)
    static const NSUInteger kStartMarkGlyphInner = 0x1f;
    static const NSUInteger kStartMarkGlyphMid = 0x1e;
    static const NSUInteger kStartMarkGlyphOuter = 0x1d;
    static const double kStartMarkGlyphNudge = 80.0; // @ghidraAddress 0x28f3f8

    // The four layered start-mark glyph scales/alphas animate through phases keyed on
    // startMarkFrame; each glyph is a scaled/rotated draw of texFront sprites 0x1d..0x1f.
    unsigned int f = self->startMarkFrame;
    float scaleInner = 0.0f;
    float scaleMid = 0.0f;
    float scaleOuter = 0.0f;
    float alphaInner = 1.0f;
    float alphaMid = 1.0f;
    float alphaOuter = 1.0f;
    if ((int)f < 0) {
        // Faithful: a negative frame counter zeroes every scale and holds full alpha.
        scaleInner = scaleMid = scaleOuter = 0.0f;
    } else if ((int)f < 8) {
        alphaMid = 1.0f;
        alphaInner = InterpolateFloatByFrame(1.32f, 1.0f, f, 0, 8);
        float from;
        float to;
        unsigned int start;
        unsigned int end;
        if ((int)f < 4) {
            start = 0;
            end = 4;
            from = 0.0f;
            to = 0.22f; // @ghidraAddress 0x292ab0
        } else {
            start = 4;
            end = 8;
            from = 0.22f;
            to = 1.32f; // @ghidraAddress 0x292a98
        }
        scaleOuter = InterpolateFloatByFrame(from, to, f, start, end);
        scaleMid = 0.0f;
        scaleInner = InterpolateFloatByFrame(0.0f, g_flKeyTime080, f, 0, 8);
        alphaInner = InterpolateFloatByFrame(0.07f, 1.0f, f, 4, 8); // @ghidraAddress 0x292aa8
        scaleOuter = InterpolateFloatByFrame(0.0f, 1.0f, f, 4, 8);
    } else {
        // The steady-state pulse loops every 30 frames.
        unsigned int p = (f - 8) % 0x1e;
        if ((int)p < 0xf) {
            scaleOuter = InterpolateFloatByFrame(1.32f, 0.89f, p, 0, 0xf);
            scaleInner = InterpolateFloatByFrame(g_flKeyTime080, 0.9f, p, 0, 0xf);
            if ((int)p < 0xb) {
                alphaInner = InterpolateFloatByFrame(1.0f, 0.07f, p, 0, 0xb);
                scaleMid = InterpolateFloatByFrame(0.33f, 1.32f, p, 0, 0xb);
            } else {
                alphaInner = InterpolateFloatByFrame(0.07f, 0.89f, p, 0xb, 0x12);
                scaleMid = InterpolateFloatByFrame(0.33f, 0.33f, p, 0xb, 0x12);
            }
        } else {
            scaleOuter = InterpolateFloatByFrame(0.89f, 1.32f, p, 0xf, 0x1e);
            scaleInner = InterpolateFloatByFrame(0.9f, g_flKeyTime080, p, 0xf, 0x1e);
            if ((int)p < 0x12) {
                alphaInner = InterpolateFloatByFrame(0.07f, 0.89f, p, 0xb, 0x12);
                scaleMid = InterpolateFloatByFrame(0.33f, 0.33f, p, 0xb, 0x12);
            } else {
                alphaInner = InterpolateFloatByFrame(0.89f, 1.0f, p, 0x12, 0x1e);
                scaleMid = InterpolateFloatByFrame(0.33f, 1.32f, p, 0x12, 0x1e);
            }
        }
        scaleOuter = 1.0f;
        alphaOuter = 1.0f;
        alphaMid = 1.0f;
    }

    unsigned int firstMarker = self.sequence.firstMarker;
    for (unsigned int panel = 0; panel < kMainGameGridPanelCount; ++panel) {
        if (((1u << panel) & firstMarker) == 0) {
            continue;
        }
        int p4 = (int)panel;
        int pY = (p4 >= 0) ? p4 : (p4 + 3);
        double x = (double)(((p4 % 4) * kGridCellSize) | kPanelMarkerInset);
        double y = (double)((((pY >> 2) * kGridCellSize) | kPanelMarkerInset) + kPanelGridTop);
        CGPoint anchor = CGPointMake(x + kStartMarkGlyphNudge, y + kStartMarkGlyphNudge);
        [self.texFront drawSprite:kStartMarkGlyphInner
                          atPoint:CGPointMake(x, y)
                            scale:alphaMid
                           rotate:0.0f
                           anchor:anchor
                        transform:0
                            alpha:scaleInner * alpha];
        [self.texFront drawSprite:kStartMarkGlyphMid
                          atPoint:CGPointMake(x, y)
                        transform:0
                            alpha:scaleMid * alpha];
        [self.texFront drawSprite:kStartMarkGlyphInner
                          atPoint:CGPointMake(x, y)
                            scale:alphaInner
                           rotate:0.0f
                           anchor:anchor
                        transform:0
                            alpha:scaleOuter * alpha];
        [self.texFront drawSprite:kStartMarkGlyphOuter
                          atPoint:CGPointMake(x, y)
                            scale:alphaOuter
                           rotate:0.0f
                           anchor:anchor
                        transform:0
                            alpha:alphaMid * alpha];
    }
    (void)kStartMarkInset;
    ++self->startMarkFrame;
}

/** @ghidraAddress 0x11c2b8 */
- (void)renderCombo:(unsigned int)combo alpha:(float)alpha {
    static const double kComboBurstX = 384.0;       // @ghidraAddress 0x292470
    static const double kComboBurstY = 486.0;       // @ghidraAddress 0x2929c8
    static const float kComboBurstMirrorX = 384.0f; // @ghidraAddress 0x29254c
    static const double kComboCountGlyphY = 720.0;  // @ghidraAddress 0x2929d0
    static const int kComboCutAnimFrames = 8;
    static const int kComboEffectResetFrames = 10;
    static const int kComboMaxDigits = 4;
    static const int kComboDigitBufferSize = 5;
    static const int kComboDigitStride = 0xba; // 186
    static const int kComboRowWidth = 0x300;   // 768
    static const int kComboDigitBaseY = 0x1e6; // 486
    static const int kComboCountGlyphInset = 0xa2;
    static const NSUInteger kComboCountSprite = 0x1e;
    static const NSUInteger kComboBurstSprite = 0x1f;

    if (self.scoreBackup) {
        return;
    }
    if (self->comboEffectFrame != 0) {
        --self->comboEffectFrame;
    }

    // Combo cut-in burst.
    BOOL drawBurst = YES;
    if (combo < self->lastCombo && self->lastCombo > kComboDrawThreshold) {
        self->comboCutFrame = kComboCutAnimFrames;
    } else if (self->comboCutFrame == 0) {
        drawBurst = NO;
    }
    if (drawBurst) {
        if (self.showCombo) {
            [self.texCombo spriteAtIndex:kComboBurstSprite];
            float scale = InterpolateFloatByFrame(2.5f, 1.0f, self->comboCutFrame, 0, 8);
            float from;
            float to;
            unsigned int start;
            unsigned int end;
            if (self->comboCutFrame < 5) {
                start = 0;
                end = 5;
                from = 0.0f;
                to = 0.13f; // @ghidraAddress 0x292a98
            } else {
                start = 5;
                end = 8;
                from = 0.13f;
                to = 0.13f; // @ghidraAddress 0x292ad4-area
            }
            float alpha2 = InterpolateFloatByFrame(from, to, self->comboCutFrame, start, end);
            [self.texCombo drawSprite:kComboBurstSprite
                               inRect:CGRectMake(kComboBurstX, kComboBurstY, (double)scale, 0.0)
                            transform:0
                                alpha:alpha2];
            [self.texCombo drawSprite:kComboBurstSprite
                               inRect:CGRectMake((double)(kComboBurstMirrorX - scale),
                                                 kComboBurstY,
                                                 (double)scale,
                                                 0.0)
                            transform:5
                                alpha:alpha2];
        }
        --self->comboCutFrame;
    }

    // Combo counter.
    if (combo > kComboDrawThreshold) {
        if (self->lastCombo < combo) {
            self->comboEffectFrame = kComboEffectResetFrames;
        }
        char buf[kComboDigitBufferSize];
        int n = snprintf(buf, kComboDigitBufferSize, "%d", combo);
        if (n >= 1) {
            unsigned int digitCount =
                (n > kComboMaxDigits) ? (unsigned int)kComboMaxDigits : (unsigned int)n;
            int centerBase = (int)digitCount * -kComboDigitStride + kComboRowWidth;
            int step = self->comboEffectFrame;
            if (self.showCombo) {
                int baseX = centerBase / 2;
                if (digitCount - 1 < 4) {
                    int span = step - ((~(unsigned int)n < (unsigned int)-5) ? 0xfffffffb : ~n);
                    int x = baseX;
                    for (int j = 0; j < (int)digitCount; ++j) {
                        int offset = 0;
                        if (span - 0xb == j) {
                            offset = -5;
                        } else if (span - 0xc == j) {
                            offset = -10;
                        } else if (span - 0xd == j) {
                            offset = -0xf;
                        }
                        if ((unsigned int)(j + 1) > digitCount) {
                            offset = 0;
                        }
                        [self.texCombo
                            drawSprite:(NSUInteger)(buf[j] - '.')
                               atPoint:CGPointMake((double)x, (double)(offset + kComboDigitBaseY))
                             transform:0
                                 alpha:alpha];
                        x += kComboDigitStride;
                    }
                } else {
                    int x = baseX;
                    for (int j = 0; j < (int)digitCount; ++j) {
                        [self.texCombo drawSprite:(NSUInteger)(buf[j] - '.')
                                          atPoint:CGPointMake((double)x, kComboBurstY)
                                        transform:0
                                            alpha:alpha];
                        x += kComboDigitStride;
                    }
                }
                [self.texCombo
                    drawSprite:kComboCountSprite
                       atPoint:CGPointMake((double)(baseX + (int)digitCount * kComboDigitStride -
                                                    kComboCountGlyphInset),
                                           kComboCountGlyphY)
                     transform:1
                         alpha:alpha];
            }
        }
    }

    self->lastCombo = combo;
}

/** @ghidraAddress 0x11c680 */
- (void)renderUpdatedScore:(unsigned int)score atPoint:(CGPoint)point alpha:(double)alpha {
    static const int kScoreDigitStride = 0x12; // 18
    static const double kScoreDigitNudge = 1.0;
    static const NSUInteger kScoreGlyphBase = 0xd; // '0' glyph relative to '0' code
    static const NSUInteger kScorePrefixSprite = 0x3c;

    if (score == 0) {
        return;
    }
    if (self.scoreBackup) {
        return;
    }
    char buf[8];
    snprintf(buf, sizeof(buf), "%7d", score);
    int lastNonDigit = -1;
    int digitX = kScoreDigitStride;
    for (int i = 0; i < 7; ++i) {
        if ((unsigned char)(buf[i] - '0') < 10) {
            [self.texFront
                drawSprite:(NSUInteger)(buf[i] + kScoreGlyphBase)
                   atPoint:CGPointMake(point.x + (double)digitX + kScoreDigitNudge, point.y)
                 transform:(char)(int)(float)alpha
                     alpha:0];
        } else {
            lastNonDigit = i;
        }
        digitX += kScoreDigitStride;
    }
    [self.texFront
        drawSprite:kScorePrefixSprite
           atPoint:CGPointMake(point.x +
                                   (double)(lastNonDigit * kScoreDigitStride + kScoreDigitStride) +
                                   kScoreDigitNudge,
                               point.y)
         transform:(char)(int)(float)alpha
             alpha:0];
}

/** @ghidraAddress 0x11c7f4 */
- (void)renderScore:(unsigned int)score atPoint:(CGPoint)point alpha:(double)alpha {
    static const NSUInteger kScoreLabelSprite = 0x12;
    static const NSUInteger kScoreBoardSprite = 0x13;
    static const NSUInteger kScoreDigitCellSprite = 0x14;
    static const NSUInteger kScoreDigitCellSpriteHigh = 0x15;
    static const NSUInteger kScoreLabelInnerSprite = 0x13;
    static const unsigned int kScoreRankThreshold = 700000; // 0xaae60
    static const int kScoreDigitStride = 0x32;              // 50
    static const double kScoreDigitNudge = 1.0;
    static const int kScoreRollupDivisor = 1000000;

    // Prime the label board sprite; its result only sizes the draw scratch.
    [self.texFront spriteAtIndex:kScoreBoardSprite];

    if (score == 0) {
        self->scoreDisplay = 0;
    } else if (self->scoreDisplay != score) {
        int step = (self->scoreDisplay < score) ? 1 : -1;
        self->scoreDisplay = self->scoreDisplay + (((score - self->scoreDisplay) + step) >> 1);
    }

    char buf[8];
    snprintf(buf, sizeof(buf), "%7d", self->scoreDisplay);

    // The glyph base and rollup-region source depend on whether the score has crossed 700000.
    NSUInteger digitCellSprite;
    long glyphBias;
    if (self->scoreDisplay <= kScoreRankThreshold) {
        [self.texFront spriteAtIndex:kScoreDigitCellSprite];
        digitCellSprite = kScoreDigitCellSprite;
        glyphBias = -8;
    } else {
        [self.texFront spriteAtIndex:kScoreDigitCellSpriteHigh];
        digitCellSprite = kScoreDigitCellSpriteHigh;
        glyphBias = 2;
    }
    (void)digitCellSprite;

    // The six-figure rollup fills the board region proportionally to the shown score.
    unsigned int rollupNumer = self->scoreDisplay * ((int)alpha + 3);
    double rollupWidth = (double)(rollupNumer / kScoreRollupDivisor);
    if (alpha < rollupWidth) {
        rollupWidth = alpha;
    }

    // The "SCORE" label and the board, then (when full) the rollup region.
    [self.texFront drawSprite:kScoreLabelSprite
                      atPoint:CGPointMake(point.x, point.y)
                    transform:(char)(int)(float)alpha
                        alpha:0];
    if (rollupNumer >= (unsigned int)kScoreRollupDivisor) {
        [self.texFront drawInRect:CGRectMake(point.x, point.y, rollupWidth, 0.0)
                       fromRegion:CGRectMake(alpha - rollupWidth, point.y, rollupWidth, 0.0)
                        transform:0
                            alpha:0.0f];
    }
    [self.texFront drawSprite:kScoreLabelInnerSprite
                      atPoint:CGPointMake(point.x, point.y)
                    transform:(char)(int)(float)alpha
                        alpha:0];

    int digitX = 0;
    for (int i = 0; i < 7; ++i) {
        if ((unsigned char)(buf[i] - '0') < 10) {
            [self.texFront
                drawSprite:(NSUInteger)(buf[i] + glyphBias)
                   atPoint:CGPointMake(point.x + (double)digitX + kScoreDigitNudge, point.y)
                 transform:(char)(int)(float)alpha
                     alpha:0];
        }
        digitX += kScoreDigitStride;
    }
}

/** @ghidraAddress 0x11ca7c */
- (void)renderPartnerScore:(unsigned int)score
                   atPoint:(CGPoint)point
                     scale:(double)scale
                     alpha:(double)alpha {
    static const NSUInteger kScoreLabelSprite = 0x12;
    static const NSUInteger kScoreBoardSprite = 0x13;
    static const NSUInteger kPartnerLabelSprite = 0x27;
    static const unsigned int kScoreRankThreshold = 700000;
    static const int kScoreDigitStride = 0x32; // 50
    static const double kScoreDigitNudge = 1.0;
    static const double kPartnerLabelOffsetX = 2.0;
    static const double kPartnerLabelOffsetY = -25.0;
    static const double kHalf = 0.5;

    if (!self.isSession) {
        return;
    }
    double drawAlpha = self.isConnected ? alpha : alpha * kHalf;

    [self.texFront spriteAtIndex:kScoreBoardSprite];
    [self.texFront spriteAtIndex:0x28];

    if (score == 0) {
        self->partnerScoreDisplay = 0;
    } else if (self->partnerScoreDisplay != score) {
        int step = (self->partnerScoreDisplay < score) ? 1 : -1;
        self->partnerScoreDisplay =
            self->partnerScoreDisplay + (((score - self->partnerScoreDisplay) + step) >> 1);
    }

    char buf[8];
    snprintf(buf, sizeof(buf), "%7d", self->partnerScoreDisplay);
    long glyphBias = (self->partnerScoreDisplay < kScoreRankThreshold) ? -8 : 2;

    // The label and board are scaled about the anchor point; the partner row uses the passed scale
    // for both the cell width and height.
    [self.texFront drawSprite:kScoreLabelSprite
                       inRect:CGRectMake(point.x, point.y, scale * scale, scale * scale)
                    transform:(char)(int)(float)drawAlpha
                        alpha:0];
    [self.texFront drawSprite:kScoreBoardSprite
                       inRect:CGRectMake(point.x, point.y, scale * scale, scale * scale)
                    transform:(char)(int)(float)drawAlpha
                        alpha:0];

    int digitX = 0;
    for (int i = 0; i < 7; ++i) {
        if ((unsigned char)(buf[i] - '0') < 10) {
            [self.texFront
                drawSprite:(NSUInteger)(buf[i] + glyphBias)
                    inRect:CGRectMake(point.x + (double)digitX * scale + kScoreDigitNudge,
                                      point.y,
                                      scale * scale,
                                      scale * scale)
                 transform:(char)(int)(float)drawAlpha
                     alpha:0];
        }
        digitX += kScoreDigitStride;
    }
    [self.texFront
        drawSprite:kPartnerLabelSprite
           atPoint:CGPointMake(point.x + kPartnerLabelOffsetX, point.y + kPartnerLabelOffsetY)
         transform:(char)(int)(float)drawAlpha
             alpha:0];
}

/** @ghidraAddress 0x11ccfc */
- (void)renderMusicBar:(CGPoint)pos timeline:(BOOL)timeline alpha:(double)alpha {
    static const double kMusicBarCellBaseXOffset = 76.0; // @ghidraAddress 0x292488
    static const double kMusicBarCellYOffset = 1.0;
    static const float kMusicBarCursorScale = 120.0f;   // @ghidraAddress 0x291be8
    static const float kMusicBarFadeEnd = 1.29999995f;  // @ghidraAddress 0x292558
    static const float kMusicBarPlayHeadScale = 600.0f; // @ghidraAddress 0x291c3c
    static const double kMusicBarPlayHeadX = 74.0;      // @ghidraAddress 0x28fa28-area
    static const double kMusicBarPlayHeadY = 197.0;     // @ghidraAddress 0x28f6b0
    static const NSUInteger kMusicBarSpriteBackdrop = 0x16;
    static const NSUInteger kMusicBarSpritePlayHead = 0x1c;
    static const int kMusicBarNoteBaseIdle = 0x47;
    static const int kMusicBarNoteBaseCursor = 0x4f;
    /** @ghidraAddress 0x292c60 */
    static const int kMusicBarRatingSpriteBase[] = {0x57, 0x47, 0x5f, 0x4f};
    static const int kMusicBarCellPitch = 5;
    enum { kMusicBarCellCount = 0x78 };

    // The one-piece backdrop.
    [self.texFront drawSprite:kMusicBarSpriteBackdrop
                      atPoint:CGPointMake(pos.x, pos.y)
                    transform:0
                        alpha:(float)alpha];
    if (!self.sequence) {
        return;
    }

    float playPosition = self.sequence.playPosition;
    const char *bar = self.sequence.getMusicBar;
    const ScoreData *score = self.sequence.getScore;
    ScoreData backup;
    if (self.scoreBackup) {
        backup = self.replayBackupScore;
        score = &backup;
    }

    double cellBaseX = pos.x + kMusicBarCellBaseXOffset;
    float cursor = playPosition * kMusicBarCursorScale;
    int drawX = 0;
    for (int i = 0; i < kMusicBarCellCount; ++i) {
        int byteIndex = (i >= 0) ? (i >> 1) : ((i + 1) >> 1);
        int nibbleShift = (i - (byteIndex << 1)) * 4;
        unsigned int note = (unsigned int)(((bar[byteIndex] >> nibbleShift) & 0xf) - 1);
        if (note < 8) {
            int spriteBase;
            if (self.state == kRenderStateFinish || self.state == kRenderStateResult ||
                self.scoreBackup || ((float)i + kMusicBarFadeEnd < cursor)) {
                int gradeIdx = (i >= 0) ? (i >> 2) : ((i + 3) >> 2);
                int gradeShift = (i - (gradeIdx << 2)) * 2;
                int grade = ((score->musicBarResult[gradeIdx] >> gradeShift) & 3) ^ 2;
                spriteBase = kMusicBarRatingSpriteBase[grade];
            } else {
                spriteBase = ((float)i + kComboFadeBase < cursor) ? kMusicBarNoteBaseIdle :
                                                                    kMusicBarNoteBaseCursor;
            }
            [self.texFront
                drawSprite:(NSUInteger)((int)note + spriteBase)
                   atPoint:CGPointMake(cellBaseX + (double)drawX, pos.y + kMusicBarCellYOffset)
                 transform:0
                     alpha:(float)alpha];
        }
        drawX += kMusicBarCellPitch;
    }

    if (timeline) {
        [self.texFront drawSprite:kMusicBarSpritePlayHead
                          atPoint:CGPointMake((double)(playPosition * kMusicBarPlayHeadScale +
                                                       (float)kMusicBarPlayHeadX),
                                              kMusicBarPlayHeadY)
                        transform:0
                            alpha:(float)alpha];
    }
}

/** @ghidraAddress 0x11d038 */
- (void)renderTuneInfo:(CGPoint)pos artworkSize:(double)artworkSize alpha:(double)alpha {
    static const double kTitleChipXOffset = 17.0;
    static const double kTitleChipYOffset = -15.0;
    static const double kDifficultyXOffset = 20.0;
    static const double kDifficultyYOffset = -0.28125; // An fmov immediate.
    static const double kLevelXNudgeExtreme = 143.0;   // @ghidraAddress 0x2924a8
    static const double kLevelXNudgeAdvanced = 162.0;  // @ghidraAddress 0x28fa30
    static const double kLevelXNudgeBasic = 64.0;      // @ghidraAddress 0x28f1f0
    static const double kLevelXNudgeDefault = 92.0;    // @ghidraAddress 0x28f748
    static const double kLevelYNudge = -6.0;
    static const NSUInteger kTuneInfoSpriteJacket = 0x17;
    static const NSUInteger kTuneInfoSpriteTitle = 0x18;
    static const NSUInteger kTuneInfoSpriteDifficulty = 0x19;
    static const NSUInteger kTuneInfoSpriteLevel = 0x1b;

    // The jacket artwork, drawn stretched into sprite 0x17's frame.
    [self.texFront drawSprite:kTuneInfoSpriteJacket
                       inRect:CGRectMake(pos.x, pos.y, artworkSize, artworkSize)
                    transform:(char)(int)(float)alpha
                        alpha:0];
    double x = pos.x + artworkSize;
    [self.texFront drawSprite:kTuneInfoSpriteTitle
                      atPoint:CGPointMake(x + kTitleChipXOffset, pos.y + kTitleChipYOffset)
                    transform:(char)(int)(float)alpha
                        alpha:0];
    x += kDifficultyXOffset;
    double y = pos.y + kDifficultyYOffset;
    [self.texFront drawSprite:kTuneInfoSpriteDifficulty atPoint:CGPointMake(x, y)];
    double levelXNudge;
    switch ((int)self.rendererConf.diff) {
    case 2:
        levelXNudge = kLevelXNudgeExtreme;
        break;
    case 1:
        levelXNudge = kLevelXNudgeAdvanced;
        break;
    case 0:
        levelXNudge = kLevelXNudgeBasic;
        break;
    default:
        levelXNudge = kLevelXNudgeDefault;
        break;
    }
    [self.texFront drawSprite:kTuneInfoSpriteLevel
                      atPoint:CGPointMake(x + levelXNudge, y + kLevelYNudge)
                    transform:(char)(int)(float)alpha
                        alpha:0];
}

/** @ghidraAddress 0x11d1a4 */
- (void)renderUpperBG:(BOOL)wipe {
    // The upper plate is a grid of sprite-2 tiles filling the header, then sprite 0 and 1 bands.
    static const double kColX[] = {
        64.0, 128.0, 192.0, 256.0, 320.0, 384.0, 448.0, 512.0, 576.0, 640.0, 704.0, 768.0};
    static const double kUpperBeamX0 = 300.0; // @ghidraAddress 0x28f2d0
    static const double kUpperBeamY = 256.0;  // @ghidraAddress 0x28e030
    static const float kBounceDecay = 0.99f;  // @ghidraAddress 0x292ad8
    static const float kBouncePress = 15.0f;
    static const float kBounceCap = 120.0f;    // @ghidraAddress 0x291be8
    static const float kUpperBgGravity = 5.0f; // via 0x40a00000
    static const int kUpperTileStep = 0x20;    // 32
    static const int kUpperTileEnd = 0x300;    // 768
    static const NSUInteger kUpperTileSprite = 2;
    static const NSUInteger kUpperBandSprite0 = 0;
    static const NSUInteger kUpperBandSprite1 = 1;
    static const NSUInteger kUpperBeamSprite0 = 3;
    static const NSUInteger kUpperBeamSprite1 = 4;

    // The tiled upper plate: sprite 2 laid out in a 12-column grid across the header.
    for (int col = 0; col < 12; ++col) {
        [self.texFront drawSprite:kUpperTileSprite
                          atPoint:CGPointMake(kColX[col], kUpperTileSprite)];
    }
    // Two further plate rows, at the column origin and one tile down.
    for (int col = 0; col < 12; ++col) {
        [self.texFront drawSprite:kUpperTileSprite atPoint:CGPointMake(kColX[col], 64.0)];
    }
    for (int col = 0; col < 12; ++col) {
        [self.texFront drawSprite:kUpperTileSprite atPoint:CGPointMake(kColX[col], 96.0)];
    }

    // The two full-width bands: sprite 0 across the top, then sprite 1 at the game-area line.
    for (int x = 0; x < kUpperTileEnd; x += kUpperTileStep) {
        [self.texFront drawSprite:kUpperBandSprite0 atPoint:CGPointMake((double)x, 0.0)];
    }
    [self.texFront spriteAtIndex:kUpperBandSprite1];
    double bandY = kUpperBeamY;
    for (int x = 0; x < kUpperTileEnd; x += kUpperTileStep) {
        [self.texFront drawSprite:kUpperBandSprite1 atPoint:CGPointMake((double)x, bandY)];
    }

    // The beam wipe animates in over the first ten frames when requested.
    if (wipe) {
        [self.texFront spriteAtIndex:kUpperBeamSprite0];
        float h0 = InterpolateFloatByFrame(0.0f, (float)kUpperBeamY, self->frame, 0, 10);
        [self.texFront drawInRect:CGRectMake(kUpperBeamX0, bandY - (double)h0, 0.0, (double)h0)
                       fromRegion:CGRectMake(0.0, bandY, 0.0, (double)h0)
                        transform:0
                            alpha:0.0f];
        [self.texFront spriteAtIndex:kUpperBeamSprite1];
        float h1 = InterpolateFloatByFrame(0.0f, (float)h0, self->frame, 0, 10);
        [self.texFront
            drawInRect:CGRectMake(kUpperBeamX0, bandY, 0.0, (double)h1)
            fromRegion:CGRectMake(
                           0.0, (bandY - (double)h0) + ((double)h0 - (double)h1), 0.0, (double)h1)
             transform:0
                 alpha:0.0f];
    }

    // Outside the pre-play states, the upper background sprites bounce under button presses and the
    // beat, then all upper ripples are stepped and rendered against the front atlas.
    float gravity = kComboFadeBase;
    float bounce = g_flKeyTime040;
    if (self.state != 0 && self.state != kRenderStatePreStart &&
        self.state != kRenderStateReadyGo) {
        self->bounceEnergy = self->bounceEnergy * kBounceDecay;
        if (self.btnDown != 0) {
            self->bounceEnergy = self->bounceEnergy + kBouncePress;
        }
        if (self->bounceEnergy > kBounceCap) {
            self->bounceEnergy = kBounceCap;
        }
        if (!self.sequence) {
            self->lastHakuPhase = 0.0f;
            gravity = 0.0f;
            bounce = kUpperBgGravity;
        } else {
            float prevHaku = self->lastHakuPhase;
            float haku = self.sequence.hakuPhase;
            self->lastHakuPhase = haku;
            gravity = 0.0f;
            bounce = kUpperBgGravity;
            // A beat wrap (the phase dropping) triggers a jump of every ripple.
            if (haku < prevHaku) {
                for (UpperBGRipple *ripple in self.arrayUpperBgRip) {
                    [ripple triggerJump:self->bounceEnergy + 20.0f];
                }
            }
        }
    }

    for (UpperBGRipple *ripple in self.arrayUpperBgRip) {
        [ripple stepFall:kUpperBgGravity gravity:bounce bounce:gravity];
        [ripple renderWithTexture:self.texFront yLimit:(float)kUpperBeamY];
    }
    (void)kUpperBeamX0;
}

/** @ghidraAddress 0x11dcdc */
- (void)renderUpper {
    static const double kMusicBarY = 208.0;           // @ghidraAddress 0x2929f0
    static const double kScoreX = 412.0;              // @ghidraAddress 0x2929f8
    static const double kScoreY = 138.0;              // @ghidraAddress 0x2924c8
    static const double kPartnerX = 516.0;            // @ghidraAddress 0x292a00
    static const double kPartnerY = 80.0;             // @ghidraAddress 0x28f3f8
    static const double kPartnerScale = 0.7;          // @ghidraAddress 0x291c98
    static const double kTuneInfoArtworkSize = 160.0; // @ghidraAddress 0x28f438

    [self renderTuneInfo:CGPointMake(18.0, 25.0) artworkSize:kTuneInfoArtworkSize alpha:1.0];
    BOOL timeline = self.state == kRenderStatePlay;
    [self renderMusicBar:CGPointMake(8.0, kMusicBarY) timeline:timeline alpha:1.0];

    unsigned int score = 0;
    if (self.sequence) {
        score = (unsigned int)[self.sequence getScore]->point;
    }
    if (self.scoreBackup) {
        ScoreData backup = self.replayBackupScore;
        score = (unsigned int)backup.totalPoint;
    }
    [self renderScore:score atPoint:CGPointMake(kScoreX, kScoreY) alpha:1.0];
    [self renderPartnerScore:self.partnerScore
                     atPoint:CGPointMake(kPartnerX, kPartnerY)
                       scale:kPartnerScale
                       alpha:1.0];
}

/** @ghidraAddress 0x11de94 */
- (void)renderButtons {
    static const double kButtonEdgeOffset = 160.0;  // @ghidraAddress 0x28f438
    static const double kButtonEdgeInset = 32.0;    // @ghidraAddress 0x28f458
    static const double kButtonLitInnerNear = 54.0; // @ghidraAddress 0x28f640
    static const double kButtonLitInnerFar = 138.0; // @ghidraAddress 0x2924c8
    enum {
        kButtonSpriteUnlitFill = 9,
        kButtonSpriteUnlitRight = 10,
        kButtonSpriteUnlitBottom = 11,
        kButtonSpriteUnlitCorner = 12,
        kButtonSpriteLitFill = 0x11,
        kButtonSpriteLitBase = 0xd,
        kButtonSpriteLitRight = 0xe,
        kButtonSpriteLitBottom = 0xf,
        kButtonSpriteLitCorner = 0x10,
    };

    for (int i = 0; i < kMainGameGridPanelCount; ++i) {
        int panelForY = (i >= 0) ? i : (i + 3);
        double x = (double)((i % 4) * kGridCellSize);
        double y = (double)((panelForY >> 2) * kGridCellSize + kPanelGridTop);
        BOOL lit = ([self btnPress] & (1 << i)) != 0;

        if (lit) {
            [self.texFront drawSprite:kButtonSpriteLitFill atPoint:CGPointMake(x, y)];
            [self.texFront drawSprite:kButtonSpriteLitFill
                              atPoint:CGPointMake(x + kButtonEdgeOffset, y)
                            transform:1
                                alpha:1.0f];
            [self.texFront drawSprite:kButtonSpriteLitFill
                              atPoint:CGPointMake(x + kButtonLitInnerFar, y + kButtonEdgeOffset)
                            transform:2
                                alpha:1.0f];
            [self.texFront drawSprite:kButtonSpriteLitFill
                              atPoint:CGPointMake(x, y + kButtonLitInnerFar)
                            transform:3
                                alpha:1.0f];
            [self.texFront drawSprite:kButtonSpriteLitBase atPoint:CGPointMake(x, y)];
            [self.texFront drawSprite:kButtonSpriteLitRight
                              atPoint:CGPointMake(x + kButtonEdgeOffset, y)
                            transform:1
                                alpha:1.0f];
            [self.texFront drawSprite:kButtonSpriteLitBottom
                              atPoint:CGPointMake(x, y + kButtonEdgeInset)
                            transform:1
                                alpha:1.0f];
            [self.texFront drawSprite:kButtonSpriteLitCorner
                              atPoint:CGPointMake(x + kButtonEdgeInset, y + kButtonEdgeOffset)];
        } else {
            [self.texFront drawSprite:kButtonSpriteUnlitFill atPoint:CGPointMake(x, y)];
            [self.texFront drawSprite:kButtonSpriteUnlitRight
                              atPoint:CGPointMake(x + kButtonEdgeOffset, y)
                            transform:1
                                alpha:1.0f];
            [self.texFront drawSprite:kButtonSpriteUnlitBottom
                              atPoint:CGPointMake(x, y + kButtonEdgeInset)
                            transform:1
                                alpha:1.0f];
            [self.texFront drawSprite:kButtonSpriteUnlitCorner
                              atPoint:CGPointMake(x + kButtonEdgeInset, y + kButtonEdgeOffset)];
        }
        (void)kButtonLitInnerNear;
    }
}

/** @ghidraAddress 0x11e0d8 */
- (void)renderPreStart {
    static const double kScoreX = 412.0;              // @ghidraAddress 0x2929f8
    static const double kScoreY = 138.0;              // @ghidraAddress 0x2924c8
    static const double kPartnerX = 516.0;            // @ghidraAddress 0x292a00
    static const double kPartnerY = 80.0;             // @ghidraAddress 0x28f3f8
    static const double kMusicBarY = 208.0;           // @ghidraAddress 0x2929f0
    static const double kPartnerScale = 0.7;          // @ghidraAddress 0x291c98
    static const double kTuneInfoArtworkSize = 160.0; // @ghidraAddress 0x28f438
    static const float kTuneInfoSlideBase = 40.0f;    // @ghidraAddress 0x292568

    [self renderBG];
    [self renderShutter:YES];
    [self renderUpperBG:NO];

    // The tune info fades and slides in over frames 10..20.
    float infoAlpha = InterpolateFloatByFrame(0.0f, 1.0f, self->frame, 10, 0x14);
    float infoX = InterpolateFloatByFrame(kTuneInfoSlideBase, 18.0f, self->frame, 10, 0x14);
    [self renderTuneInfo:CGPointMake((double)infoX, 25.0)
             artworkSize:kTuneInfoArtworkSize
                   alpha:(double)infoAlpha];

    // The score and partner score fade and slide in over frames 4..14.
    float scoreAlpha = InterpolateFloatByFrame(0.0f, 1.0f, self->frame, 4, 0xe);
    float slide = InterpolateFloatByFrame(kTuneInfoSlideBase, 0.0f, self->frame, 4, 0xe);
    [self renderScore:0
              atPoint:CGPointMake(kScoreX - (double)slide, kScoreY)
                alpha:(double)scoreAlpha];
    [self renderPartnerScore:0
                     atPoint:CGPointMake(kPartnerX - (double)slide, kPartnerY)
                       scale:kPartnerScale
                       alpha:(double)scoreAlpha];

    // The music bar fades in over frames 0..10.
    float barAlpha = InterpolateFloatByFrame(0.0f, 1.0f, self->frame, 0, 10);
    [self renderMusicBar:CGPointMake(8.0, kMusicBarY) timeline:NO alpha:(double)barAlpha];

    [self renderButtons];

    // Frame 20 plays the mute stinger and advances the sub-state.
    if (self->frame == 0x14) {
        [[AudioManager sharedManager] playSeResFile:@"SD_MUON" inDirectory:nil];
        self.subState = 10;
    }
}

/** @ghidraAddress 0x11e304 */
- (void)renderReadyGo {
    static const double kFieldCenterX = 384.0;       // @ghidraAddress 0x292470
    static const double kFieldCenterY = 640.0;       // @ghidraAddress 0x291d80
    static const double kReadyDiscBase = 768.0;      // @ghidraAddress 0x292460
    static const double kReadyDiscSize = 540.0;      // @ghidraAddress 0x28f900-area
    static const float kReadyDiscScale = 540.0f;     // An fmov immediate.
    static const float kReadyLetterMirrorX = 384.0f; // @ghidraAddress 0x29254c
    static const NSUInteger kReadyDiscSprite = 0;
    static const NSUInteger kReadyLetterSprite = 1;
    static const NSUInteger kGoLeftSprite = 0;
    static const NSUInteger kGoRightSprite = 1;
    // The "GO" chip positions (texReady1) and the ready-letter spread table.
    static const double kGoCenterX0 = 222.0; // @ghidraAddress 0x291d90
    static const double kGoCenterX1 = 299.0; // @ghidraAddress 0x292a10
    static const double kGoCenterX2 = 471.0; // @ghidraAddress 0x292a18
    static const double kGoCenterX3 = 546.0; // @ghidraAddress 0x292a20
    static const double kGoY0 = 214.0;       // @ghidraAddress 0x292a28
    static const double kGoY1 = 554.0;       // @ghidraAddress 0x292a30
    /** @ghidraAddress 0x292df8 */
    static const float kReadyLetterSpread[] = {162.0f, 0.0f, 0.2f, 0.1f, 0.3f, 0.2f, 0.4f, 0.3f};
    static const float kGoSpin = 320.0f; // @ghidraAddress 0x292734

    unsigned int f = self->frame;

    // Phase 1 (frames 0..19): the ready disc swells in from the field centre.
    if (f < 0x14) {
        float discAlpha = InterpolateFloatByFrame(0.0f, 1.0f, f, 5, 0xf);
        double h = (double)(discAlpha * kReadyDiscScale);
        [self.texReady0
            drawSprite:kReadyDiscSprite
                inRect:CGRectMake(kFieldCenterY, h * -0.5 + kFieldCenterY, kReadyDiscBase, h)
             transform:0
                 alpha:1.0f];
    } else if (f < 0x32) {
        // Phase 2 (frames 20..49): the disc holds and the "READY" letters settle in one by one.
        unsigned int p = f - 0x14;
        float discAlpha = InterpolateFloatByFrame(1.0f, 0.0f, p, 0, 0xe);
        float discScale = InterpolateFloatByFrame(1.0f, g_flKeyTime080, p, 0, 0xe);
        double w = (double)(discScale * (float)kReadyDiscScale);
        float discH = InterpolateFloatByFrame(1.0f, kReadyDiscScale, p, 0, 0xe);
        double h = (double)(discH * kReadyDiscScale);
        [self.texReady0
            drawSprite:kReadyDiscSprite
                inRect:CGRectMake(kFieldCenterX - w * 0.5, kFieldCenterY - h * 0.5, w, h)
             transform:0
                 alpha:discAlpha];
        [self.texReady0 spriteAtIndex:kReadyLetterSprite];
        double halfW = w * 0.5;
        double halfH = h * 0.5;
        double baseY = kFieldCenterY - halfH;
        for (long j = 0; j <= (long)p; ++j) {
            long lv = (long)p - j;
            if (lv + 4 <= (long)p) {
                float spr = kReadyLetterSpread[lv];
                unsigned int end = (unsigned int)(lv + 0xc);
                float slide = InterpolateFloatByFrame(0.0f, spr, p, (unsigned int)(lv + 4), end);
                [self.texReady0
                    drawSprite:(NSUInteger)(lv + 5)
                       atPoint:CGPointMake((double)(slide + kReadyLetterMirrorX) - halfW, baseY)
                     transform:0
                         alpha:1.0f];
                (void)halfW;
            }
        }
    } else if (f < 0x36) {
        // Phase 3 (frames 50..53): the disc blows up and the letters spread out.
        [self.texReady0 spriteAtIndex:kReadyLetterSprite];
        float scale = InterpolateFloatByFrame(1.0f, g_flKeyTime080, self->frame, 0x32, 0x36);
        float alpha = InterpolateFloatByFrame(1.0f, 0.0f, self->frame, 0x32, 0x36);
        double s = (double)scale;
        double cy = kFieldCenterY;
        [self.texReady0 drawSprite:kReadyDiscSprite
                           atPoint:CGPointMake(kGoCenterX0 - s * 0.5, cy)
                             scale:scale
                            rotate:0.0f
                            anchor:CGPointMake(kFieldCenterX, kFieldCenterY)
                         transform:1
                             alpha:alpha];
        [self.texReady0 drawSprite:kReadyDiscSprite
                           atPoint:CGPointMake(kGoCenterX1 - s * 0.5, cy)
                             scale:scale
                            rotate:0.0f
                            anchor:CGPointMake(kFieldCenterX, kFieldCenterY)
                         transform:2
                             alpha:alpha];
        [self.texReady0 drawSprite:kReadyDiscSprite
                           atPoint:CGPointMake(kFieldCenterX - s * 0.5, cy)
                             scale:scale
                            rotate:0.0f
                            anchor:CGPointMake(kFieldCenterX, kFieldCenterY)
                         transform:3
                             alpha:alpha];
        [self.texReady0 drawSprite:kReadyDiscSprite
                           atPoint:CGPointMake(kGoCenterX2 - s * 0.5, cy)
                             scale:scale
                            rotate:0.0f
                            anchor:CGPointMake(kFieldCenterX, kFieldCenterY)
                         transform:4
                             alpha:alpha];
        [self.texReady0 drawSprite:kReadyDiscSprite
                           atPoint:CGPointMake(kGoCenterX3 - s * 0.5, cy)
                             scale:scale
                            rotate:0.0f
                            anchor:CGPointMake(kFieldCenterX, kFieldCenterY)
                         transform:5
                             alpha:alpha];
    }

    // The "GO" chips (texReady1) spin and fade through frames 52..82.
    [self.texReady1 spriteAtIndex:kReadyDiscSprite];
    unsigned int gf = self->frame;
    if (gf >= 0x34 && gf < 0x3a) {
        float scale = InterpolateFloatByFrame(g_flKeyTime040, 1.0f, gf, 0x34, 0x3a);
        float spin = scale * kGoSpin * 0.00390625f;
        float alpha = InterpolateFloatByFrame(0.0f, 1.0f, gf, 0x34, 0x3a);
        [self.texReady1 drawSprite:kGoLeftSprite
                           atPoint:CGPointMake(kGoY0, kFieldCenterY)
                             scale:spin
                            rotate:0.0f
                            anchor:CGPointMake(kFieldCenterX, kFieldCenterY)
                         transform:0
                             alpha:alpha];
        float scale2 = InterpolateFloatByFrame(g_flKeyTime040, 1.0f, gf, 0x34, 0x3a);
        float spin2 = scale2 * kGoSpin * 0.00390625f;
        float alpha2 = InterpolateFloatByFrame(0.0f, 1.0f, gf, 0x34, 0x3a);
        [self.texReady1 drawSprite:kGoRightSprite
                           atPoint:CGPointMake(kGoY1, kFieldCenterY)
                             scale:spin2
                            rotate:0.0f
                            anchor:CGPointMake(kFieldCenterX, kFieldCenterY)
                         transform:1
                             alpha:alpha2];
    } else if (gf >= 0x3a && gf < 0x53) {
        float scale = InterpolateFloatByFrame(1.0f, g_flKeyTime040, gf, 0x3a, 0x53);
        float spin = scale * kGoSpin * 0.00390625f;
        float alpha = InterpolateFloatByFrame(g_flKeyTime070, 0.0f, gf, 0x3a, 0x53);
        [self.texReady1 drawSprite:kGoLeftSprite
                           atPoint:CGPointMake(kGoY0, kFieldCenterY)
                             scale:spin
                            rotate:0.0f
                            anchor:CGPointMake(kFieldCenterX, kFieldCenterY)
                         transform:2
                             alpha:alpha];
        float s2 = InterpolateFloatByFrame(1.0f, g_flKeyTime040, gf, 0x3a, 0x51);
        float a2 = InterpolateFloatByFrame(1.0f, 0.0f, gf, 0x3a, 0x51);
        [self.texReady1 drawSprite:kGoLeftSprite
                           atPoint:CGPointMake(kGoY0, kFieldCenterY)
                             scale:s2 * kGoSpin * 0.00390625f
                            rotate:0.0f
                            anchor:CGPointMake(kFieldCenterX, kFieldCenterY)
                         transform:0
                             alpha:a2];
        float s3 = InterpolateFloatByFrame(1.0f, g_flKeyTime040, gf, 0x3a, 0x53);
        float a3 = InterpolateFloatByFrame(g_flKeyTime070, 0.0f, gf, 0x3a, 0x53);
        [self.texReady1 drawSprite:kGoRightSprite
                           atPoint:CGPointMake(kGoY1, kFieldCenterY)
                             scale:s3 * kGoSpin * 0.00390625f
                            rotate:0.0f
                            anchor:CGPointMake(kFieldCenterX, kFieldCenterY)
                         transform:3
                             alpha:a3];
        float s4 = InterpolateFloatByFrame(1.0f, g_flKeyTime040, gf, 0x3a, 0x51);
        float a4 = InterpolateFloatByFrame(1.0f, 0.0f, gf, 0x3a, 0x51);
        [self.texReady1 drawSprite:kGoRightSprite
                           atPoint:CGPointMake(kGoY1, kFieldCenterY)
                             scale:s4 * kGoSpin * 0.00390625f
                            rotate:0.0f
                            anchor:CGPointMake(kFieldCenterX, kFieldCenterY)
                         transform:1
                             alpha:a4];
    }

    // The voice cues: "ready" on frame 20 and the "GO" sample-player on frame 58.
    if (self->frame == 0x14) {
        [[AudioManager sharedManager] playSeResFile:@"SD_RPL_CV_READY" inDirectory:nil];
    }
    if (self->frame == 0x3a) {
        [[AudioManager sharedManager] playSePlayer:self.sePlayerGo];
        self.sePlayerGo = nil;
    }
    if (self->frame >= 0x55) {
        self.subState = kMainGameEndSubState;
    }
    (void)kReadyDiscSize;
    (void)kReadyLetterMirrorX;
}

/** @ghidraAddress 0x11ec14 */
- (void)renderFullcombo:(int)animFrame {
    static const double kCornerBaseX = 0x60; // 96, first corner x
    static const NSUInteger kFullcomboCornerSprite = 0x22;
    static const NSUInteger kFullcomboWordSprite0 = 0x24;
    static const NSUInteger kFullcomboWordSprite1 = 0x26;
    static const NSUInteger kFullcomboWordSprite2 = 0x23;
    static const NSUInteger kFullcomboWordSprite3 = 0x25;
    static const float kFullcomboScaleMid = 0.9f; // @ghidraAddress 0x28f3b0
    static const double kWord0X = 350.0;          // @ghidraAddress 0x292a38
    static const double kWord1X = 944.0;          // @ghidraAddress 0x292a40
    static const double kWord2X = 166.0;          // @ghidraAddress 0x292728
    static const double kWord3X = 548.0;          // @ghidraAddress 0x292a48

    if (self.scoreBackup) {
        return;
    }
    // On frame 2, cue the full-combo voice and sound effect.
    if (animFrame == 2) {
        [[AudioManager sharedManager] playSeResFile:@"SD_RPL_RESULT_CLEAR" inDirectory:nil];
        [[AudioManager sharedManager] playSeResFile:@"SD_RPL_CV_FULLCOMBO" inDirectory:nil];
    }

    // Prime the corner and word sprite cells.
    [self.texFront spriteAtIndex:kFullcomboCornerSprite];
    [self.texFront spriteAtIndex:kFullcomboWordSprite1];
    [self.texFront spriteAtIndex:kFullcomboWordSprite3];

    // Eight corner glyphs sweep in staggered by 6 frames each; the loop draws two mirrored corners
    // per iteration over four grid rows.
    int cornerY = (int)kCornerBaseX;
    int rowFromTop = 0xf;
    for (int row = 0; row < 4; ++row) {
        if (animFrame >= 0) {
            float scale;
            unsigned int scaleStart;
            unsigned int scaleEnd;
            float scaleFrom;
            float scaleTo;
            float baseAlpha;
            if (animFrame < 4) {
                baseAlpha = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 0, 4);
                if (animFrame < 2) {
                    scaleStart = 0;
                    scaleEnd = 2;
                    scaleFrom = 1.0f;
                    scaleTo = kFullcomboScaleMid;
                } else {
                    scaleStart = 2;
                    scaleEnd = 0xc;
                    scaleFrom = kFullcomboScaleMid;
                    scaleTo = 1.6f; // @ghidraAddress 0x292af0
                }
            } else {
                baseAlpha = InterpolateFloatByFrame(1.0f, 0.0f, animFrame, 4, 0xc);
                scaleStart = 2;
                scaleEnd = 0xc;
                scaleFrom = kFullcomboScaleMid;
                scaleTo = 1.6f;
            }
            scale = InterpolateFloatByFrame(scaleFrom, scaleTo, animFrame, scaleStart, scaleEnd);

            int topRow = (rowFromTop >= 0) ? rowFromTop : (rowFromTop + 3);
            double cornerYTop = (double)((topRow >> 2) * kGridCellSize + kButtonCellOriginY);
            [self.texFront drawSprite:kFullcomboCornerSprite
                              atPoint:CGPointMake((double)cornerY, cornerYTop)
                                scale:scale
                               rotate:0.0f
                               anchor:CGPointMake((double)cornerY, cornerYTop)
                            transform:0
                                alpha:baseAlpha];
            int mirrorX = (rowFromTop % 4) * kGridCellSize + kButtonCellOriginX;
            double mirrorYTop = (double)((topRow >> 2) * kGridCellSize + kButtonCellOriginY);
            [self.texFront drawSprite:kFullcomboCornerSprite
                              atPoint:CGPointMake((double)mirrorX, mirrorYTop)
                                scale:scale
                               rotate:0.0f
                               anchor:CGPointMake((double)mirrorX, mirrorYTop)
                            transform:0
                                alpha:baseAlpha];
        }
        cornerY += 0xc0;
        rowFromTop -= 1;
        animFrame -= 6;
    }

    // The four "FULLCOMBO" word plates fly in, hold, and fly out with their own frame windows.
    float wordAlpha0 = (animFrame < 4) ? InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 4, 4) :
                                         InterpolateFloatByFrame(1.0f, 0.0f, animFrame, 0x55, 0x5a);
    [self.texFront drawSprite:kFullcomboWordSprite0
                      atPoint:CGPointMake(kWord0X, kWord2X)
                    transform:0
                        alpha:wordAlpha0];
    [self.texFront drawSprite:kFullcomboWordSprite1
                      atPoint:CGPointMake(kWord1X, kWord3X)
                    transform:0
                        alpha:wordAlpha0];
    // The two remaining word plates and their scaled variants are drawn with the same easing set;
    // the binary shares alpha across the pair.
    [self.texFront drawSprite:kFullcomboWordSprite2
                      atPoint:CGPointMake(kWord2X, kWord0X)
                    transform:0
                        alpha:wordAlpha0];
    [self.texFront drawSprite:kFullcomboWordSprite3
                      atPoint:CGPointMake(kWord3X, kWord1X)
                    transform:0
                        alpha:wordAlpha0];
}

/** @ghidraAddress 0x11f43c */
- (void)renderFinish {
    // On finish, load the result texture in the background once the wipe has run; a full combo
    // shows the full-combo flourish first.
    __weak MainGameRendererPadRpl *weakSelf = self;
    void (^loadResult)(void) = ^{
      /** @ghidraAddress 0x11f640 */
      [weakSelf loadResultTex:(short)[weakSelf.sequence rank]];
      dispatch_async(dispatch_get_main_queue(), ^{
        /** @ghidraAddress 0x11f728 */
        [weakSelf setSubState:10];
      });
    };

    if (self.sequence.isFullcombo && !self.scoreBackup) {
        [self renderFullcombo:(int)self->frame];
        if (self.subState == 0 && self->frame > 99) {
            self.subState = 1;
            [self.eaglView performBlockInBackground:loadResult];
        }
    } else {
        if (self.subState == 0 && self->frame > 0x13) {
            self.subState = 1;
            [self.eaglView performBlockInBackground:loadResult];
        }
    }
}

/** @ghidraAddress 0x11f788 */
- (BOOL)renderExcellent:(unsigned int)animFrame {
    static const double kFieldCenterX = 384.0; // @ghidraAddress 0x292470
    static const double kFieldCenterY = 640.0; // @ghidraAddress 0x291d80
    static const float kExcellentPeak = 0.9f;  // An fmov immediate.
    static const double kBeamWipeX = 288.0;    // @ghidraAddress 0x2926f8
    static const double kDiscY = 352.0;        // @ghidraAddress 0x292a50
    static const double kWordY = 660.0;        // @ghidraAddress 0x292a58
    static const NSUInteger kExcellentBeamSprite = 3;
    static const NSUInteger kExcellentChipSprite = 7;
    static const NSUInteger kExcellentWordSprite = 2;
    static const NSUInteger kExcellentDiscSprite = 0;
    // The chip ring positions swept in over the animation, as {x, y} double pairs.
    /** @ghidraAddress 0x292b78 */
    static const double kChipRing[] = {352.0, 480.0, 352.0, 96.0,  544.0, 96.0,  736.0, 288.0,
                                       928.0, 480.0, 928.0, 96.0,  352.0, 672.0, 352.0, 288.0,
                                       544.0, 480.0, 544.0, 288.0, 736.0, 480.0, 736.0, 96.0,
                                       928.0, 672.0, 928.0, 288.0, 640.0};

    // The main disc scale ramps up over the first 20 frames, holds, then blows out.
    float discScale;
    if (animFrame < 0x14) {
        InterpolateFloatByFrame(0.0f, kExcellentPeak, animFrame, 10, 0x14);
        discScale = InterpolateFloatByFrame(g_flKeyTime080, 1.0f, animFrame, 10, 0x14);
    } else if (animFrame > 0x2e) {
        unsigned int p = animFrame - 0x2f;
        if ((int)p < 2) {
            InterpolateFloatByFrame(kExcellentPeak, g_flKeyTime040, p, 0, 2);
            discScale = InterpolateFloatByFrame(1.0f, g_flKeyTime080, p, 0, 2);
        } else if ((int)p < 10) {
            InterpolateFloatByFrame(g_flKeyTime040, g_flKeyTime060, p, 2, 10);
            discScale = InterpolateFloatByFrame(g_flKeyTime080, 1.0f, p, 2, 10);
        } else {
            InterpolateFloatByFrame(g_flKeyTime060, 0.2f, p, 10, 0x28);
            discScale = InterpolateFloatByFrame(g_flKeyTime080, 1.0f, p, 2, 10);
        }
    } else {
        unsigned int p = animFrame - 0x26;
        if (animFrame < 0x26) {
            p = animFrame - 0x1d;
        }
        if (animFrame < 0x1d) {
            p = animFrame - 0x14;
        }
        if ((int)p < 3) {
            discScale = InterpolateFloatByFrame(1.0f, g_flKeyTime080, p, 0, 3);
        } else {
            discScale = InterpolateFloatByFrame(g_flKeyTime080, 1.0f, p, 3, 8);
        }
    }

    // The four-quadrant disc, mirrored (transforms 0, 5, 4, 2) about the field centre.
    [self.texResult spriteAtIndex:kExcellentBeamSprite];
    double half = (double)discScale * 0.5;
    (void)half;
    [self.texResult drawSprite:kExcellentBeamSprite
                       atPoint:CGPointMake(kFieldCenterX, kFieldCenterY)
                         scale:discScale
                        rotate:0.0f
                        anchor:CGPointMake(kFieldCenterX, kFieldCenterY)
                     transform:3
                         alpha:0.0f];

    // The chip ring: nine chips sweeping into the ring positions over frames 20..46.
    unsigned int cf = animFrame - 0x14;
    if (cf < 0x1b) {
        int count = 9;
        double firstX = 197.0;
        if (animFrame < 0x1d) {
            count = 9;
        } else if (animFrame < 0x26) {
            count = 8;
            cf = animFrame - 0x1d;
        } else {
            count = 6;
            cf = animFrame - 0x26;
            firstX = 288.0;
        }
        float chipScale = (cf < 4) ? InterpolateFloatByFrame(0.0f, 1.0f, cf, 0, 4) :
                                     InterpolateFloatByFrame(1.0f, 0.0f, cf, 4, 8);
        float ringAlpha = InterpolateFloatByFrame(0.07f, 1.0f, cf, 0, 4);
        [self.texResult spriteAtIndex:kExcellentChipSprite];
        double cx = firstX;
        double cy = 352.0; // @ghidraAddress 0x292a50
        for (int j = 0; j < count; ++j) {
            [self.texResult
                drawSprite:kExcellentChipSprite
                   atPoint:CGPointMake(cx - (double)discScale * 0.5, cy - (double)ringAlpha * 0.5)
                     scale:ringAlpha
                    rotate:0.0f
                    anchor:CGPointMake(cx, cy)
                 transform:7
                     alpha:chipScale];
            cx = kChipRing[j * 2];
            cy = kChipRing[j * 2 + 1];
        }
    }

    // The "EXCELLENT" word plate scales/wipes in from frame 49.
    if (animFrame > 0x30) {
        unsigned int p = animFrame - 0x31;
        float wordScale;
        if ((int)p < 8) {
            wordScale = InterpolateFloatByFrame(2.0f, g_flKeyTime080, p, 0, 8);
        } else {
            wordScale = InterpolateFloatByFrame(g_flKeyTime080, 1.0f, animFrame, 8, 10);
        }
        [self.texResult spriteAtIndex:kExcellentWordSprite];
        [self.texResult drawSprite:kExcellentWordSprite
                           atPoint:CGPointMake(kFieldCenterX, kWordY)
                             scale:wordScale
                            rotate:0.0f
                            anchor:CGPointMake(kFieldCenterX, kWordY)
                         transform:2
                             alpha:0.0f];
    }

    // The per-phase voice/sound cues.
    switch (animFrame) {
    case 0x18:
    case 0x21:
    case 0x2a:
        [[AudioManager sharedManager] playSeResFile:@"SD_RPL_RESULT_EXC_0" inDirectory:nil];
        break;
    case 0x39:
        [[AudioManager sharedManager] playSeResFile:@"SD_RPL_RESULT_EXC" inDirectory:nil];
        [[AudioManager sharedManager] playSeResFile:@"SD_RPL_CV_EXCELLENT" inDirectory:nil];
        break;
    default:
        break;
    }
    (void)kBeamWipeX;
    (void)kDiscY;
    (void)kExcellentDiscSprite;
    return animFrame > 0x77;
}

/** @ghidraAddress 0x11ffbc */
- (void)renderRating:(unsigned int)animFrame {
    static const double kRatingLabelX = 208.0;  // @ghidraAddress 0x2929f0
    static const double kRatingLabelY = 656.0;  // @ghidraAddress 0x292520
    static const double kRatingGlyphX = 480.0;  // @ghidraAddress 0x28e020
    static const double kRatingGlyphY = 736.0;  // @ghidraAddress 0x292a60
    static const float kRatingScaleMid = 1.16f; // @ghidraAddress 0x292b34
    static const float kRatingScaleLow = 1.6f;  // @ghidraAddress 0x292b30
    static const NSUInteger kRatingLabelSprite = 9;
    static const NSUInteger kRatingGlyphSprite = 10;

    int rank = (int)[self.sequence rank];
    if (rank < 5) {
        unsigned int labelEnd = (rank > 2) ? 7 : 0xe;
        unsigned int scaleEnd = (rank < 3) ? 4 : 3;
        float labelSlide = InterpolateFloatByFrame(25.0f, 0.0f, animFrame, 0, labelEnd);
        float labelAlpha = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 0, labelEnd);
        [self.texResult drawSprite:kRatingLabelSprite
                           atPoint:CGPointMake((double)labelSlide + kRatingLabelX, kRatingLabelY)
                         transform:(char)(int)labelAlpha
                             alpha:0];
        [self.texResult spriteAtIndex:kRatingGlyphSprite];
        float glyphScale;
        if (animFrame < scaleEnd) {
            glyphScale = InterpolateFloatByFrame(2.0f, kRatingScaleMid, animFrame, 0, scaleEnd);
        } else {
            glyphScale =
                InterpolateFloatByFrame(kRatingScaleMid, 1.0f, animFrame, scaleEnd, scaleEnd);
        }
        [self.texResult drawSprite:kRatingGlyphSprite
                           atPoint:CGPointMake(kRatingGlyphX - (double)labelAlpha * 0.5,
                                               kRatingGlyphY - (double)glyphScale * 0.5)
                             scale:glyphScale
                            rotate:0.0f
                            anchor:CGPointMake(kRatingGlyphX, kRatingGlyphY)
                         transform:10
                             alpha:0.0f];
    } else {
        float labelSlide = InterpolateFloatByFrame(25.0f, 0.0f, animFrame, 0, 0xd);
        float labelAlpha = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 0, 0xd);
        [self.texResult drawSprite:kRatingLabelSprite
                           atPoint:CGPointMake((double)labelSlide + kRatingLabelX, kRatingLabelY)
                         transform:(char)(int)labelAlpha
                             alpha:0];
        [self.texResult spriteAtIndex:kRatingGlyphSprite];
        float glyphScale;
        if (animFrame < 8) {
            glyphScale = InterpolateFloatByFrame(2.0f, kRatingScaleLow, animFrame, 0, 8);
        } else if (animFrame < 0xe) {
            glyphScale =
                InterpolateFloatByFrame(kRatingScaleLow, kRatingScaleMid, animFrame, 8, 0xe);
        } else if (animFrame < 0x10) {
            glyphScale = InterpolateFloatByFrame(kRatingScaleMid, 1.0f, animFrame, 0xe, 0x10);
        } else {
            glyphScale = InterpolateFloatByFrame(0.2f, 1.0f, animFrame, 8, 0xd);
        }
        [self.texResult drawSprite:kRatingGlyphSprite
                           atPoint:CGPointMake(kRatingGlyphX - (double)labelAlpha * 0.5,
                                               kRatingGlyphY - (double)glyphScale * 0.5)
                             scale:glyphScale
                            rotate:0.0f
                            anchor:CGPointMake(kRatingGlyphX, kRatingGlyphY)
                         transform:10
                             alpha:0.0f];
    }
}

/** @ghidraAddress 0x1202e0 */
- (BOOL)renderCleared:(unsigned int)animFrame {
    static const double kFieldCenterX = 384.0;    // @ghidraAddress 0x292470
    static const double kFieldCenterY = 640.0;    // @ghidraAddress 0x291d80
    static const double kWordY = 544.0;           // @ghidraAddress 0x292a68
    static const float kClearedScaleMid = 1.04f;  // @ghidraAddress 0x292b38
    static const float kClearedScaleLow = 0.43f;  // @ghidraAddress 0x292b3c
    static const float kClearedScaleHigh = 0.38f; // @ghidraAddress 0x292b40
    static const NSUInteger kClearedDiscSprite = 4;
    static const NSUInteger kClearedWordSprite = 0;

    // The disc pulses in, then loops a gentle beat scale.
    float scale;
    unsigned int p;
    if (animFrame < 0x28) {
        float from;
        float to;
        unsigned int start;
        unsigned int end;
        if (animFrame < 6) {
            start = 0;
            end = 6;
            from = 0.0f;
            to = kClearedScaleLow;
        } else {
            start = 6;
            end = 0x28;
            from = 0.13f;
            to = kClearedScaleLow;
        }
        float base = InterpolateFloatByFrame(from, to, animFrame, start, end);
        scale = InterpolateFloatByFrame(kClearedScaleHigh, kClearedScaleMid, animFrame, 0, 6);
        (void)base;
        p = animFrame;
    } else {
        p = (animFrame - 0x28) % 0x1e;
        if (p < 5) {
            InterpolateFloatByFrame(0.13f, g_flKeyTime040, p, 0, 5);
            scale = InterpolateFloatByFrame(kClearedScaleHigh, 1.0f, p, 0, 5);
        } else {
            InterpolateFloatByFrame(g_flKeyTime040, 0.13f, p, 6, 0x1e);
            scale = InterpolateFloatByFrame(1.0f, kClearedScaleHigh, p, 6, 0x1e);
        }
    }

    // The four-quadrant disc, mirrored (transforms via the shutter angle table) about the centre.
    [self.texResult drawSprite:kClearedDiscSprite
                       atPoint:CGPointMake(kFieldCenterX, kFieldCenterY)
                         scale:scale
                        rotate:0.0f
                        anchor:CGPointMake(kFieldCenterX, kFieldCenterY)
                     transform:4
                         alpha:0.0f];
    [self.texResult drawSprite:kClearedDiscSprite
                       atPoint:CGPointMake(kFieldCenterX, kFieldCenterY)
                         scale:scale
                        rotate:0.0f
                        anchor:CGPointMake(kFieldCenterX, kFieldCenterY)
                     transform:4
                         alpha:0.0f];
    [self.texResult drawSprite:kClearedDiscSprite
                       atPoint:CGPointMake(kFieldCenterX, kFieldCenterY)
                         scale:scale
                        rotate:0.0f
                        anchor:CGPointMake(kFieldCenterX, kFieldCenterY)
                     transform:4
                         alpha:0.0f];
    [self.texResult drawSprite:kClearedDiscSprite
                       atPoint:CGPointMake(kFieldCenterX, kFieldCenterY)
                         scale:scale
                        rotate:0.0f
                        anchor:CGPointMake(kFieldCenterX, kFieldCenterY)
                     transform:4
                         alpha:0.0f];

    // The "CLEARED" word plate wipes in over the first six frames.
    float wordAlpha = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 0, 6);
    float wordScale = InterpolateFloatByFrame(kComboFadeBase, 1.0f, animFrame, 0, 6);
    [self.texResult spriteAtIndex:kClearedWordSprite];
    [self.texResult drawSprite:kClearedWordSprite
                       atPoint:CGPointMake(kFieldCenterX - (double)scale * 0.5, kWordY)
                         scale:wordScale
                        rotate:0.0f
                        anchor:CGPointMake(kFieldCenterX, kWordY)
                     transform:0
                         alpha:wordAlpha];

    // The clear voice/sound on frame 0, then the rating from frame 10.
    if (animFrame < 10) {
        if (animFrame == 0) {
            [[AudioManager sharedManager] playSeResFile:@"SD_RPL_RESULT_CLEAR" inDirectory:nil];
            [[AudioManager sharedManager] playSeResFile:@"SD_RPL_CV_CLEAR" inDirectory:nil];
        }
    } else {
        [self renderRating:animFrame - 10];
    }
    (void)p;
    return animFrame > 0x3b;
}

/** @ghidraAddress 0x120658 */
- (BOOL)renderFailed:(unsigned int)animFrame {
    static const double kFieldCenterX = 384.0;       // @ghidraAddress 0x292470
    static const double kFieldCenterY = 640.0;       // @ghidraAddress 0x291d80
    static const double kWordY = 544.0;              // @ghidraAddress 0x292a68
    static const float kFailedScaleFrom = 1.63f;     // @ghidraAddress 0x292b44
    static const float kFailedScaleTo = 2.07f;       // @ghidraAddress 0x292b48
    static const float kFailedWordScaleFrom = 0.76f; // @ghidraAddress 0x292b4c
    static const float kFailedWordDrop = 46.0f;      // @ghidraAddress 0x292b50
    static const NSUInteger kFailedDiscSprite = 5;
    static const NSUInteger kFailedWordSprite = 1;

    // The disc scales in and slides down.
    float discAlpha = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 0, 0x10);
    float discScale = InterpolateFloatByFrame(kFailedScaleFrom, kFailedScaleTo, animFrame, 0, 0x10);
    float slide;
    if (animFrame < 0x10) {
        slide = InterpolateFloatByFrame(-20.0f, 0.0f, animFrame, 0, 0x10);
    } else {
        slide = InterpolateFloatByFrame(0.0f, 10.0f, animFrame, 0x10, 0x32);
    }
    double discY = (double)slide + kFieldCenterY;
    [self.texResult spriteAtIndex:kFailedDiscSprite];
    [self.texResult drawSprite:kFailedDiscSprite
                       atPoint:CGPointMake(kFieldCenterX - (double)discScale * 0.5,
                                           discY - (double)discScale * 0.5)
                         scale:discScale
                        rotate:0.0f
                        anchor:CGPointMake(kFieldCenterX, discY)
                     transform:5
                         alpha:discAlpha];

    // The "FAILED" word plate scales in and drops.
    float wordScale = InterpolateFloatByFrame(kFailedWordScaleFrom, 1.0f, animFrame, 0, 0x10);
    float wordDrop = InterpolateFloatByFrame(kFailedWordDrop, 0.0f, animFrame, 0, 0x10);
    double wordY = (double)wordDrop + kWordY;
    [self.texResult spriteAtIndex:kFailedWordSprite];
    [self.texResult drawSprite:kFailedWordSprite
                       atPoint:CGPointMake(kFieldCenterX - (double)discScale * 0.5,
                                           wordY - (double)discScale * 0.5)
                         scale:wordScale
                        rotate:0.0f
                        anchor:CGPointMake(kFieldCenterX, wordY)
                     transform:1
                         alpha:discAlpha];

    // The failed voice/sound on frame 0, then the rating from frame 10.
    if (animFrame < 10) {
        if (animFrame == 0) {
            [[AudioManager sharedManager] playSeResFile:@"SD_RPL_RESULT_FAILED" inDirectory:nil];
            [[AudioManager sharedManager] playSeResFile:@"SD_RPL_CV_FAILED" inDirectory:nil];
        }
    } else {
        [self renderRating:animFrame - 10];
    }
    return animFrame > 0x3b;
}

/** @ghidraAddress 0x120a58 */
- (void)renderResult {
    static const double kMusicBarY = 208.0;           // @ghidraAddress 0x2929f0
    static const double kScoreX = 412.0;              // @ghidraAddress 0x2929f8
    static const double kScoreY = 138.0;              // @ghidraAddress 0x2924c8
    static const double kPartnerX = 516.0;            // @ghidraAddress 0x292a00
    static const double kPartnerY = 80.0;             // @ghidraAddress 0x28f3f8
    static const double kPartnerScale = 0.7;          // @ghidraAddress 0x291c98
    static const double kTuneInfoArtworkSize = 160.0; // @ghidraAddress 0x28f438
    static const int kRankThreshold = 700000;
    static const int kExcellentScore = 1000000;
    static const float kShutterFadeThreshold = 43.5f; // @ghidraAddress 0x292b58
    static const float kShutterFadeRate = -43.5f;     // @ghidraAddress 0x292b54
    static const double kRecordBannerY = 186.0;       // @ghidraAddress 0x292a70
    static const double kRecordScoreY = 186.0;        // @ghidraAddress 0x292a70
    static const float kRecordBannerBaseX = 140.0;    // @ghidraAddress 0x292b5c
    static const float kRecordBannerRangeX = 196.0;   // @ghidraAddress 0x292b60
    static const float kRecordBannerBiasX = 412.0;    // @ghidraAddress 0x292b64
    static const float kRecordScoreDX = -146.0;       // @ghidraAddress 0x292b68
    static const double kMarkGlyphX = 584.0;          // @ghidraAddress 0x292a78
    static const double kMarkGlyphY = 852.0;          // @ghidraAddress 0x292a80
    static const double kGoodJobMarkX = 392.0;        // @ghidraAddress 0x292a88
    static const NSUInteger kRecordBannerSprite = 0x21;
    static const NSUInteger kMarkGlyphSprite = 0x20;
    static const NSUInteger kGoodJobGlyphSprite = 0x1d;

    const ScoreData *score = [self.sequence getScore];
    ScoreData backup;
    if (self.scoreBackup) {
        backup = self.replayBackupScore;
        score = &backup;
    }

    unsigned int f = self->frame;

    // The shutter closes: its open amount decays each frame while above the fade threshold.
    if (self->shutterOpen > 0.0f) {
        self->shutterOpen = (self->shutterOpen >= kShutterFadeThreshold) ?
                                (self->shutterOpen + kShutterFadeRate) :
                                0.0f;
    }
    [self renderShutter:NO];
    [self renderUpperBG:YES];
    [self renderTuneInfo:CGPointMake(18.0, 25.0) artworkSize:kTuneInfoArtworkSize alpha:1.0];
    [self renderMusicBar:CGPointMake(8.0, kMusicBarY) timeline:NO alpha:1.0];
    [self renderScore:(unsigned int)score->totalPoint
              atPoint:CGPointMake(kScoreX, kScoreY)
                alpha:1.0];
    [self renderPartnerScore:(self.partnerFinalBonus + self.partnerScore)
                     atPoint:CGPointMake(kPartnerX, kPartnerY)
                       scale:kPartnerScale
                       alpha:1.0];

    // The combo counter fades out over the first ten frames.
    float comboAlpha = InterpolateFloatByFrame(1.0f, 0.0f, self->frame, 0, 10);
    [self renderCombo:(unsigned int)[self.sequence getScore]->curCombo alpha:comboAlpha];

    // The cleared/failed/excellent graphic from frame 30, gated off during a replay backup.
    BOOL animationDone;
    if (f < 0x1e || self.scoreBackup) {
        animationDone = self.scoreBackup;
    } else if (score->totalPoint == kExcellentScore) {
        animationDone = [self renderExcellent:self->frame - 0x1e];
    } else if (score->totalPoint > kRankThreshold - 1) {
        animationDone = [self renderCleared:self->frame - 0x1e];
    } else {
        animationDone = [self renderFailed:self->frame - 0x1e];
    }

    // The new-record banner, from frame 65, scaling and bobbing in.
    if (self.isNewRecord && self->frame > 0x40 && !self.scoreBackup) {
        float bannerAlpha = InterpolateFloatByFrame(0.0f, 1.0f, self->frame, 0x41, 0x49);
        float bannerX = InterpolateFloatByFrame(
            kRecordBannerBaseX, kRecordBannerRangeX, self->frame, 0x41, 0x49);
        double x = (double)(bannerX + kRecordBannerBiasX);
        [self.texFront drawSprite:kRecordBannerSprite
                          atPoint:CGPointMake(x, kRecordBannerY)
                        transform:(char)(int)bannerAlpha
                            alpha:1];
        [self renderUpdatedScore:self.scoreRecord
                         atPoint:CGPointMake(x + (double)kRecordScoreDX, kRecordScoreY)
                           alpha:(double)bannerAlpha];
    }

    // Once the result reaches its interactive sub-state, draw the good-job / share marks and fade
    // the good-job overlay in.
    if (self.subState != 0) {
        unsigned int elapsed = self->frame - self->subStateChangeFrame;
        float markAlpha = (elapsed > 7) ? 1.0f : (float)elapsed * 0.125f;

        [self.texFront drawSprite:kMarkGlyphSprite
                          atPoint:CGPointMake(kMarkGlyphX, kMarkGlyphY)
                        transform:(char)(int)markAlpha
                            alpha:0];

        if (!self.replayPlaying && self.isCustom && self.isDownload && self.hasMusic) {
            if (!self.isTextureChange) {
                self.isTextureChange = YES;
                [self.texFront spriteAtIndex:0x1d];
                LoadTextureSubImageFromResource(
                    self.texFront, @"game_level_vote_rpl", CGPointMake(0.0, 0.0));
                if (self.goodJobImage) {
                    __weak UIImageView *goodJob = self.goodJobImage;
                    [UIView animateWithDuration:0.3
                                     animations:^{
                                       /** @ghidraAddress 0x121438 */
                                       [goodJob setAlpha:1.0f];
                                     }
                                     completion:^(BOOL finished){
                                         /** @ghidraAddress 0x121484 */
                                     }];
                }
                if (self.goodJobImage) {
                    __weak UIImageView *goodJob = self.goodJobImage;
                    float alphaMax = self.goodJobAlphaMax;
                    [UIView animateWithDuration:0.3
                                     animations:^{
                                       /** @ghidraAddress 0x121488 */
                                       [goodJob setAlpha:(double)alphaMax];
                                     }
                                     completion:^(BOOL finished){
                                         /** @ghidraAddress 0x1214dc */
                                     }];
                }
            }
            [self.texFront drawSprite:kGoodJobGlyphSprite
                              atPoint:CGPointMake(kGoodJobMarkX, kMarkGlyphY)
                            transform:(char)(int)markAlpha
                                alpha:0];
        }

        if (!self.isCustom && self.hasMusic && self.goodJobImage) {
            __weak UIImageView *goodJob = self.goodJobImage;
            float alphaMax = self.goodJobAlphaMax;
            [UIView animateWithDuration:0.3
                             animations:^{
                               /** @ghidraAddress 0x1214e0 */
                               [goodJob setAlpha:(double)alphaMax];
                             }
                             completion:^(BOOL finished){
                                 /** @ghidraAddress 0x121534 */
                             }];
        }

        if (self.isSession && !self.hasMusic && self.goodJobImage) {
            __weak UIImageView *goodJob = self.goodJobImage;
            float alphaMax = self.goodJobAlphaMax;
            [UIView animateWithDuration:0.3
                             animations:^{
                               /** @ghidraAddress 0x121538 */
                               [goodJob setAlpha:(double)alphaMax];
                             }
                             completion:^(BOOL finished){
                                 /** @ghidraAddress 0x12158c */
                             }];
        }
    }

    [self renderButtons];

    // The result BGM cue on frame 0.
    if (self->frame == 0) {
        [[AudioManager sharedManager] playSeResFile:@"SD_RPL_CV_RESULT" inDirectory:nil];
    }

    // Once the cleared/failed animation finishes, advance to the interactive sub-state.
    if (animationDone && self.subState == 0) {
        self.subState = 10;
        self->subStateChangeFrame = self->frame;
    }
}

@end
