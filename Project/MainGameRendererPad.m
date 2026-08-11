#import "MainGameRendererPad.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#import <UIKit/UIKit.h>

#import "AudioManager.h"
#import "BFCodec.h"
#import "HoldMarkerRender.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "MarkerManager.h"
#import "RendererConf.h"
#import "Sequence.h"
#import "Texture2D.h"
#import "TextureLoading.h"
#import "UILabel+RenderImage.h"
#import "cipher_keys.h"
#import "combo_display.h"
#import "neEngineBridge.h"

// Pi as a __const literal-pool slot (not an exported global; the binary loads it inline), used by
// the ready/go mark spin. Keeps the binary's name for the pi literal.
static const double g_dPi = 3.141592653589793; // @ghidraAddress 0x28f278

// Shared float pool slots the result banner reads: the combo-fade base and a 0.7 key time.
static const float g_flComboFadeBase = 0.3f; // @ghidraAddress 0x28e0b0
static const float g_flKeyTime070 = 0.7f;    // @ghidraAddress 0x28f3bc

// -renderImage renders a view into a UIImage. It is a category the binary provides on UIView whose
// declaring class is not established; declared here so the partner-name label can be messaged,
// mirroring the inline UIView categories in RootViewController.m.
// The high-level render states, dispatched on by -draw and -setState:.
static const unsigned int kRenderStatePreStart = 1;
static const unsigned int kRenderStateReadyGo = 2;
static const unsigned int kRenderStatePlay = 3;
static const unsigned int kRenderStateFinish = 4;
static const unsigned int kRenderStateResult = 5;
static const unsigned int kRenderStateResultWait = 6;

// The sub-state that marks the play session as finished.
static const unsigned int kMainGameEndSubState = 99;

// The 4x4 grid: each cell is 0xc0 (192) points on a side, so a row spans four cells.
static const int kGridCellSize = 0xc0;

// The per-panel button-cell corner insets, in points.
static const int kButtonCellOriginX = 0x60;  // 96
static const int kButtonCellOriginY = 0x160; // 352

// The score at which combo counting begins to draw (the counter shows only above four).
static const unsigned int kComboDrawThreshold = 4;

// The panel-grid geometry shared by the marker and button renderers, in points.
enum {
    kPanelMarkerInset = 0x10, // 16, marker inset within a grid cell.
    kPanelGridTop = 0x100,    // 256, the grid's top, below the header region.
};

// The one-letter difficulty code spliced into the "game_diff_%s" and "game_mbar_%s" resource
// names: basic, advanced, extreme, or (for anything else) the fallback code. The binary selects
// this from a run of single-character C strings at 0x280488..0x28048e.
static inline const char *MainGameRendererPadDiffCode(int diff) {
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

// Computes the top-left origin of grid panel index 0..15, insetting each cell and shifting the
// grid down below the header region.
static inline CGPoint MainGameRendererPadPanelOrigin(int panel) {
    double x = (double)(((panel % 4) * kGridCellSize) | kPanelMarkerInset);
    double y = (double)((((panel / 4) * kGridCellSize) | kPanelMarkerInset) + kPanelGridTop);
    return CGPointMake(x, y);
}

// Maps a marker-state (phase, slot) pair to its texMarker sprite index. Returns NO when the panel
// has no live marker (the caller then clears its random direction).
static inline BOOL
MainGameRendererPadMarkerSprite(unsigned int phase, unsigned int slot, int *sprite) {
    // Phase advances a sprite every 10 units; each slot is a band of 16 sprites biased by 4.
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

// Draws one "GO" mark half (sprite 5 or 6) of the ready/go overlay. Each half appears at its own
// start frame, scales up from the key time to 2.0 then settles to 1.0, slides across three x
// keyframes, and fades out from frame 0x5a. Factored from the two near-identical passes at the
// tail of -renderReadyGo.
static inline void MainGameRendererPadRenderGoMark(MainGameRendererPad *self,
                                                   unsigned int frame,
                                                   NSUInteger sprite,
                                                   unsigned int appearStart,
                                                   unsigned int scaleUpEnd,
                                                   int spriteW,
                                                   int spriteH,
                                                   float xKeyStart,
                                                   float xKeyScaleUp,
                                                   float xKeySettle,
                                                   float xKeyFadeOut) {
    static const float kReadyGoKeyTime = 0.4f;       // @ghidraAddress 0x28f3b4
    static const double kReadyGoMarkCenterY = 600.0; // @ghidraAddress 0x291c30
    float alpha;
    if (frame < 0x5a) {
        alpha = InterpolateFloatByFrame(0.0f, 1.0f, frame, appearStart, scaleUpEnd);
    } else {
        alpha = InterpolateFloatByFrame(1.0f, 0.0f, frame, 0x5a, 0x5e);
    }
    if (alpha <= 0.0f) {
        return;
    }
    float scale;
    float centerX;
    if (frame < scaleUpEnd) {
        scale = InterpolateFloatByFrame(kReadyGoKeyTime, 2.0f, frame, appearStart, scaleUpEnd);
        centerX = InterpolateFloatByFrame(xKeyStart, xKeyScaleUp, frame, appearStart, scaleUpEnd);
    } else if (frame < 0x5a) {
        scale = InterpolateFloatByFrame(2.0f, 1.0f, frame, scaleUpEnd, scaleUpEnd + 2);
        centerX =
            InterpolateFloatByFrame(xKeyScaleUp, xKeySettle, frame, scaleUpEnd, scaleUpEnd + 2);
    } else {
        centerX = InterpolateFloatByFrame(xKeySettle, xKeyFadeOut, frame, 0x5a, 0x5e);
        scale = 1.0f;
    }
    double w = (double)spriteW * (double)scale;
    double h = (double)spriteH * (double)scale;
    [self.texReady
        drawSprite:sprite
            inRect:CGRectMake((double)centerX - w * 0.5, kReadyGoMarkCenterY - h * 0.5, w, h)
         transform:0
             alpha:alpha];
}

// Draws the full-width flash beam shared by the cleared and failed result banners: sprite 4 of the
// supplied texture tiled 32 times, its height scaled and its alpha pulsed by the elapsed frame,
// centred vertically on centerY.
static inline void
MainGameRendererPadDrawResultFlashBeam(Texture2D *tex, unsigned int frame, double centerY) {
    static const double kResultBeamHeightScaleMid = 2.8;  // @ghidraAddress 0x292594
    static const double kResultBeamHeightScaleLow = 1.48; // @ghidraAddress 0x292590
    enum {
        kResultBeamSpriteIndex = 4,
        kResultBeamTileCount = 32,
        kResultBeamAlphaRiseEndFrame = 8,
        kResultBeamScaleEndFrame = 45,
        kResultExitStartFrame = 80,
        kResultExitEndFrame = 100,
    };
    CGRect cell = [tex spriteAtIndex:kResultBeamSpriteIndex];
    float alpha;
    float scaleStart;
    float scaleEnd;
    unsigned int scaleStartFrame;
    unsigned int scaleEndFrame;
    if (frame < kResultExitStartFrame) {
        alpha = InterpolateFloatByFrame(0.0f, 0.5f, frame, 0, kResultBeamAlphaRiseEndFrame);
        scaleStart = (float)kResultBeamHeightScaleMid;
        scaleEnd = (float)kResultBeamHeightScaleLow;
        scaleStartFrame = kResultBeamAlphaRiseEndFrame;
        scaleEndFrame = kResultBeamScaleEndFrame;
    } else {
        if (frame > kResultExitEndFrame - 1) {
            return;
        }
        alpha =
            InterpolateFloatByFrame(0.5f, 0.0f, frame, kResultExitStartFrame, kResultExitEndFrame);
        scaleStart = (float)kResultBeamHeightScaleLow;
        scaleEnd = 1.0f;
        scaleStartFrame = kResultExitStartFrame;
        scaleEndFrame = kResultExitEndFrame;
    }
    float heightScale =
        InterpolateFloatByFrame(scaleStart, scaleEnd, frame, scaleStartFrame, scaleEndFrame);
    if (alpha <= 0.0f) {
        return;
    }
    double scaledHeight = cell.size.height * (double)heightScale;
    double y = centerY - scaledHeight * 0.5;
    for (double i = 0.0; i < (double)kResultBeamTileCount; i += 1.0) {
        [tex drawSprite:kResultBeamSpriteIndex
                 inRect:CGRectMake(cell.size.width * i, y, cell.size.width, scaledHeight)
              transform:0
                  alpha:alpha];
    }
}

@implementation MainGameRendererPad

#pragma mark - Lifecycle

/** @ghidraAddress 0x102758 */
- (instancetype)init {
    return [super init];
}

/** @ghidraAddress 0x109ed4 */
- (void)dealloc {
    [self releaseTexture];
    // [super dealloc] is compiler-emitted (ARC).
}

#pragma mark - Textures

/** @ghidraAddress 0x104168 */
- (void)releaseTexture {
    self.texDebugFont = nil;
    self.texBG = nil;
    self.texFront = nil;
    self.texReady = nil;
    self.texRating = nil;
    self.texClear0 = nil;
    self.texClear1 = nil;
    self.texClear2 = nil;
    self.texCombo = nil;
    self.texMarker = nil;
    self.texHoldMarker = nil;
}

/** @ghidraAddress 0x102790 */
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
    /** @ghidraAddress 0x2925b0 */
    static const int kMarkerHoldRowSpriteBase[] = {28, 44, 60, 76};

    // The hold-marker atlas layout: six rows of 16 frames (sprites 0..95), then an eighth-frame
    // final row from sprite 0x60.
    static const int kHoldMarkerRowCount = 6;
    static const int kHoldMarkerLastRowFrameCount = 8;
    static const unsigned int kHoldMarkerLastRowSpriteBase = 0x60;

    // The front atlas sprite slots the difficulty label, music-bar label, level label, start and
    // end marks, jacket artwork, index image, and partner-name label are blitted into.
    static const unsigned int kFrontSpriteDiff = 0x17;
    static const unsigned int kFrontSpriteMusicBar = 0x12;
    static const unsigned int kFrontSpriteLevel = 0x18;
    static const unsigned int kFrontSpriteStartMark = 0x20;
    static const unsigned int kFrontSpriteEndMark = 0x21;
    static const unsigned int kFrontSpriteArtwork = 0x15;
    static const unsigned int kFrontSpriteIndex = 0x16;
    static const unsigned int kFrontSpritePartner = 0x24;

    // The partner-name label's bold system font size.
    static const CGFloat kPartnerNameFontSize = 14.0; // @ghidraAddress fmov 0x402c000000000000

    NSData *cipherKey = CreateTextureCipherKey();
    BFCodec *cipher = [[BFCodec alloc] init];

    const char *diffCode = nullptr;
    @autoreleasepool {
        if (!self.texDebugFont) {
            self.texDebugFont = CreateTexture2DFromPngResource(@"debugfont");
        }
        if (!self.texBG) {
            [cipher cipherInit:cipherKey];
            self.texBG = CreateTexture2DFromEncryptedTexResource(@"game_bg_tex", cipher);
        }
        if (!self.texReady) {
            [cipher cipherInit:cipherKey];
            self.texReady = CreateTexture2DFromEncryptedTexResource(@"game_ready_tex", cipher);
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
        diffCode = MainGameRendererPadDiffCode((int)conf.diff);

        // Build the front atlas: an empty 1024-square texture whose sprite rects come from the
        // plist, then the encrypted image blitted in at the origin.
        self.texFront = [[Texture2D alloc] initWithData:nullptr
                                            pixelFormat:Texture2DPixelFormatRGBA8888
                                              pixelSize:kFrontTexPixelSize];
        NSString *frontPlist = [NSBundle.mainBundle pathForResource:@"game_front_tex"
                                                             ofType:@"plist"];
        self.texFront.sprites = [[NSArray alloc] initWithContentsOfFile:frontPlist];
        [cipher cipherInit:cipherKey];
        LoadTextureSubImageFromEncryptedTex(
            self.texFront, @"game_front_tex", cipher, CGPointMake(0.0, 0.0));
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

    // Blit the difficulty label, music-bar label, level label, start/end marks, jacket artwork,
    // and index image into their front-atlas slots.
    LoadTextureSubImageFromResource(self.texFront,
                                    [NSString stringWithFormat:@"game_diff_%s", diffCode],
                                    [self.texFront spriteAtIndex:kFrontSpriteDiff].origin);
    LoadTextureSubImageFromResource(self.texFront,
                                    [NSString stringWithFormat:@"game_mbar_%s", diffCode],
                                    [self.texFront spriteAtIndex:kFrontSpriteMusicBar].origin);
    LoadTextureSubImageFromResource(self.texFront,
                                    [NSString stringWithFormat:@"game_lv_%d", (int)conf.level],
                                    [self.texFront spriteAtIndex:kFrontSpriteLevel].origin);
    LoadTextureSubImageFromResource(self.texFront,
                                    @"game_start_mark",
                                    [self.texFront spriteAtIndex:kFrontSpriteStartMark].origin);
    LoadTextureSubImageFromResource(
        self.texFront, @"game_end_mark", [self.texFront spriteAtIndex:kFrontSpriteEndMark].origin);
    [self.texFront setSubImage:artwork
                       atPoint:[self.texFront spriteAtIndex:kFrontSpriteArtwork].origin];
    [self.texFront setSubImage:index
                       atPoint:[self.texFront spriteAtIndex:kFrontSpriteIndex].origin];

    // Build the combo atlas from its plist and one encrypted image.
    @autoreleasepool {
        if (self.texCombo) {
            self.texCombo = nil;
        }
        self.texCombo = [[Texture2D alloc] initWithData:nullptr
                                            pixelFormat:Texture2DPixelFormatRGBA8888
                                              pixelSize:kAtlasTexPixelSize];
        NSString *comboPlist = [NSBundle.mainBundle pathForResource:@"game_combo_tex"
                                                             ofType:@"plist"];
        self.texCombo.sprites = [[NSArray alloc] initWithContentsOfFile:comboPlist];
        [cipher cipherInit:cipherKey];
        LoadTextureSubImageFromEncryptedTex(
            self.texCombo, @"game_combo_tex", cipher, CGPointMake(0.0, 0.0));
        [cipher cipherInit:cipherKey]; // Yes, the binary re-keys the cipher here though nothing
                                       // uses it again.
    }

    // When the tune has a partner, render its name into a right-aligned label and blit that into
    // the front atlas's partner slot.
    if (conf.partnerName) {
        UILabel *label =
            [[UILabel alloc] initWithFrame:[self.texFront spriteAtIndex:kFrontSpritePartner]];
        label.opaque = NO;
        label.backgroundColor = UIColor.clearColor;
        label.textColor = UIColor.whiteColor;
        label.textAlignment = NSTextAlignmentRight;
        label.font = [UIFont boldSystemFontOfSize:kPartnerNameFontSize];
        label.text = conf.partnerName;
        UIImage *labelImage = [label renderImage];
        [self.texFront setSubImage:labelImage
                           atPoint:[self.texFront spriteAtIndex:kFrontSpritePartner].origin];
    }

    self.rendererConf = conf;
}

/** @ghidraAddress 0x103e6c */
- (void)loadRatingTex:(short)rank {
    // The eight per-rank judgement resources, indexed by rank tier 0..8. A rank of 9 or above
    // draws no additional judgement graphic.
    static NSString *const kJudgementResources[] = {
        @"res_judgement_e",
        @"res_judgement_d",
        @"res_judgement_c",
        @"res_judgement_b",
        @"res_judgement_a",
        @"res_judgement_s",
        @"res_judgement_ss",
        @"res_judgement_sss",
        @"res_judgement_exc",
    };

    if (self.texRating) {
        self.texRating = nil;
    }
    self.texRating = [[Texture2D alloc] initWithData:nullptr
                                         pixelFormat:Texture2DPixelFormatRGBA8888
                                           pixelSize:0x100];
    NSString *plist = [NSBundle.mainBundle pathForResource:@"game_rating_tex" ofType:@"plist"];
    self.texRating.sprites = [[NSArray alloc] initWithContentsOfFile:plist];

    BFCodec *cipher = [[BFCodec alloc] init];
    NSData *cipherKey = CreateTextureCipherKey();
    [cipher cipherInit:cipherKey];
    LoadTextureSubImageFromEncryptedTex(
        self.texRating, @"game_rating_tex", cipher, CGPointMake(0.0, 0.0));

    if (rank < 9) {
        // Blit the rank's judgement glyph into the atlas from its bundled resource. The binary
        // hoists a 160.0 constant into the point's d2/d3 slots here, but a CGPoint call reads only
        // d0/d1, so the effective point is the origin and the 160.0 is discarded.
        LoadTextureSubImageFromResource(
            self.texRating, kJudgementResources[rank], CGPointMake(0.0, 0.0));
    }
}

#pragma mark - State

/** @ghidraAddress 0x104258 */
- (void)setState:(unsigned int)state {
    switch (state) {
    case 0:
    case kRenderStateReadyGo:
        self->lastCombo = 0;
        self->comboCutFrame = 0;
        self->comboEffectFrame = 0;
        self->scoreDisplay = 0;
        self->shutterOpen = 0.0f;
        break;
    case kRenderStateResult: {
        self.texBG = nil;
        [self loadRatingTex:(short)[self.sequence rank]];
        BFCodec *cipher = [[BFCodec alloc] init];
        NSData *cipherKey = CreateTextureCipherKey();
        if (!self.texClear0) {
            [cipher cipherInit:cipherKey];
            self.texClear0 = CreateTexture2DFromEncryptedTexResource(@"game_clear_0_tex", cipher);
        }
        if (!self.texClear1) {
            [cipher cipherInit:cipherKey];
            self.texClear1 = CreateTexture2DFromEncryptedTexResource(@"game_clear_1_tex", cipher);
        }
        if (!self.texClear2) {
            [cipher cipherInit:cipherKey];
            self.texClear2 = CreateTexture2DFromEncryptedTexResource(@"game_clear_2_tex", cipher);
        }
        [[AudioManager sharedManager] loadBgmResAAC:@"SD_BGM_RESULT" inDirectory:nil];
        [[AudioManager sharedManager] startBgm:YES fadeTime:0.0];
        break;
    }
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

/** @ghidraAddress 0x1045b4 */
- (void)startPlay {
    self.texReady = nil;
    [self setState:kRenderStatePlay];
}

/** @ghidraAddress 0x1045f0 */
- (void)endResult {
    if (self.state == kRenderStateResult) {
        self.subState = kMainGameEndSubState;
    }
}

/** @ghidraAddress 0x109f34 */
- (void)replaySelect {
    if (self.isCustom && self.isDownload && self.hasMusic) {
        self.replayPlaying = YES;
        LoadTextureSubImageFromResource(
            self.texFront, @"game_start_mark", [self.texFront spriteAtIndex:0x20].origin);
        self.isTextureChange = NO;

        /** @ghidraAddress 0x28f260 */
        static const NSTimeInterval kGoodJobFadeDuration = 0.3;
        // A weak reference so the animation does not keep the unowned overlay alive.
        __weak UIImageView *goodJob = self.goodJobImage;
        [UIView animateWithDuration:kGoodJobFadeDuration
                         animations:^{
                           /** @ghidraAddress 0x10a0f0 */
                           [goodJob setAlpha:0.0f];
                         }
                         completion:^(BOOL __attribute__((unused)) finished){
                             /** @ghidraAddress 0x10a13c */
                             // The completion block is the shared empty global block.
                         }];
    }
}

/** @ghidraAddress 0x109f24 */
- (void)replayEnd {
    self.replayPlaying = NO;
}

/** @ghidraAddress 0x106f6c */
- (double)durationOfReadyGo {
    /** @ghidraAddress 0x2924d0 */
    static const double kReadyGoDuration = 3.3333333333333335;
    return kReadyGoDuration;
}

#pragma mark - Layout

/** @ghidraAddress 0x1085f0 */
- (double)buttonAreaOffset {
    if (self.state != kRenderStateResult) {
        return 0.0;
    }
    /** @ghidraAddress 0x28fa00 */
    static const double kButtonAreaResultOffset = 192.0;
    // For the first 20 frames of the result the button area rises from 0 to the full offset.
    if (self->frame < 0x14) {
        return (double)((float)(self->frame * kGridCellSize) / 20.0f);
    }
    return kButtonAreaResultOffset;
}

/** @ghidraAddress 0x10865c */
- (double)gameAreaOffset {
    /** @ghidraAddress 0x28e030 */
    static const double kGameAreaOffset = 256.0;
    return kGameAreaOffset;
}

#pragma mark - Buttons

/** @ghidraAddress 0x108668 */
- (unsigned int)endButtonID {
    return 0xb;
}

/** @ghidraAddress 0x108670 */
- (unsigned int)evaluateButtonID {
    return 10;
}

/** @ghidraAddress 0x108678 */
- (unsigned int)goodJobButtonID {
    return 9;
}

/** @ghidraAddress 0x108680 */
- (CGPoint)goodJobPosition {
    /** @ghidraAddress 0x28fa00 */
    static const double kButtonAreaResultOffset = 192.0;
    unsigned int buttonID = self.goodJobButtonID;
    double x = (double)((buttonID & 3) * kGridCellSize + kButtonCellOriginX);
    double y =
        (double)((buttonID >> 2) * kGridCellSize + kButtonCellOriginY) + kButtonAreaResultOffset;
    return CGPointMake(x, y);
}

/** @ghidraAddress 0x1086fc */
- (unsigned int)twitterSendButtonID {
    return 10;
}

/** @ghidraAddress 0x108704 */
- (CGPoint)twitterBtnPosition {
    /** @ghidraAddress 0x28fa00 */
    static const double kButtonAreaResultOffset = 192.0;
    unsigned int buttonID = self.twitterSendButtonID;
    double x = (double)((buttonID & 3) * kGridCellSize + kButtonCellOriginX);
    double y =
        (double)((buttonID >> 2) * kGridCellSize + kButtonCellOriginY) + kButtonAreaResultOffset;
    return CGPointMake(x, y);
}

/** @ghidraAddress 0x108780 */
- (unsigned int)storeMoveButtonID {
    return 10;
}

/** @ghidraAddress 0x108788 */
- (CGPoint)storeMoveBtnPosition {
    /** @ghidraAddress 0x28fa00 */
    static const double kButtonAreaResultOffset = 192.0;
    unsigned int buttonID = self.storeMoveButtonID;
    double x = (double)((buttonID & 3) * kGridCellSize + kButtonCellOriginX);
    double y =
        (double)((buttonID >> 2) * kGridCellSize + kButtonCellOriginY) + kButtonAreaResultOffset;
    return CGPointMake(x, y);
}

#pragma mark - Drawing

/** @ghidraAddress 0x109938 */
- (void)draw {
    /** @ghidraAddress 0x28f750 (y), 0x28e030 (height/offset) */
    static const double kUpperBGY = 128.0;
    static const double kGameAreaOffset = 256.0;

    switch (self.state) {
    case kRenderStatePreStart:
        [self renderPreStart];
        break;
    case kRenderStateReadyGo:
        [self renderBG];
        [self renderUpperBG:kUpperBGY height:kGameAreaOffset];
        [self renderUpper];
        [self renderStartMark];
        [self renderButtons:kGameAreaOffset];
        [self renderReadyGo];
        break;
    case kRenderStatePlay:
        [self renderBG];
        [self renderCombo:(unsigned int)[self.sequence getScore]->curCombo];
        [self renderUpperBG:kUpperBGY height:kGameAreaOffset];
        [self renderUpper];
        [self renderMarker];
        [self renderButtons:kGameAreaOffset];
        break;
    case kRenderStateFinish:
        [self renderBG];
        [self renderCombo:(unsigned int)[self.sequence getScore]->curCombo];
        [self renderUpperBG:kUpperBGY height:kGameAreaOffset];
        [self renderUpper];
        [self renderMarker];
        [self renderFinish];
        [self renderButtons:kGameAreaOffset];
        break;
    case kRenderStateResult:
    case kRenderStateResultWait:
        [self renderResult];
        break;
    default:
        [self renderBG];
        [self renderUpperBG:kUpperBGY height:kGameAreaOffset];
        [self renderButtons:kGameAreaOffset];
        break;
    }

    [self.texCombo commitDraw];
    [self.texHoldMarker commitDraw];
    [self.texMarker commitDraw];
    [self.texFront commitDraw];
    [self.texReady commitDraw];
    [self.texRating commitDraw];
    [self.texClear0 commitDraw];
    [self.texClear1 commitDraw];
    [self.texClear2 commitDraw];
    ++self->frame;
}

/** @ghidraAddress 0x109d6c */
- (void)drawDebugText:(const char *)text pos:(CGPoint)pos alpha:(float)alpha {
    static const double kDebugGlyphAdvance = 12.0; // fmov 0x4028000000000000
    static const double kDebugLineAdvance = 20.0;  // fmov 0x4034000000000000
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

/** @ghidraAddress 0x106678 */
- (void)renderUpper {
    /** @ghidraAddress 0x28f438 (artworkSize), tune-info point {18, 25} */
    static const double kTuneInfoArtworkSize = 160.0;
    [self renderTuneInfo:CGPointMake(18.0, 25.0) artworkSize:kTuneInfoArtworkSize alpha:1.0];

    BOOL timeline = self.state == kRenderStatePlay;
    /** @ghidraAddress 0x2924b8 (music-bar y) */
    static const double kMusicBarY = 207.0;
    [self renderMusicBar:CGPointMake(0.0, kMusicBarY) timeline:timeline alpha:1.0];

    unsigned int score = 0;
    if (self.sequence) {
        // The live path reads point (+0x20); the replay-backup path below reads totalPoint
        // (+0x28) instead, which is the binary's own asymmetry.
        score = (unsigned int)[self.sequence getScore]->point;
    }
    if (self.scoreBackup) {
        ScoreData backup = self.replayBackupScore;
        score = (unsigned int)backup.totalPoint;
    }

    unsigned int partnerScore = self.partnerScore;
    /** @ghidraAddress 0x2924c0 (x), 0x28fa48 (y) */
    static const double kScoreX = 500.0;
    static const double kScoreY = 135.0;
    [self renderScore:score
         partnerScore:partnerScore
              atPoint:CGPointMake(kScoreX, kScoreY)
               scaleH:1.0
                alpha:1.0];
}

/** @ghidraAddress 0x106b94 */
- (void)renderPreStart {
    /** @ghidraAddress 0x28f750 (y), 0x28e030 (height/offset), 0x28f438 (artworkSize) */
    static const double kUpperBGY = 128.0;
    static const double kGameAreaOffset = 256.0;
    static const double kTuneInfoArtworkSize = 160.0;
    // The per-frame fade slope, applied as (framesLeft * slope) + 1.0. @ghidraAddress 0x292560
    static const float kPreStartFadeSlope = -0.10000000149011612f;

    [self renderBG];
    [self renderUpperBG:kUpperBGY height:kGameAreaOffset];

    // The tune info fades and slides in over frames 12..21.
    unsigned int f = self->frame;
    if (f > 0xb) {
        double artworkSize;
        double alpha;
        if (f < 0x16) {
            float framesLeft = (float)(0x16 - f);
            artworkSize = (double)(framesLeft + framesLeft) + 18.0;
            alpha = (double)(framesLeft * kPreStartFadeSlope) + 1.0;
        } else {
            alpha = 1.0;
            artworkSize = 18.0;
        }
        [self renderTuneInfo:CGPointMake(artworkSize, 25.0)
                 artworkSize:kTuneInfoArtworkSize
                       alpha:alpha];

        // The score fades in over frames 20..32.
        f = self->frame;
        if (f > 0x13) {
            double scoreAlpha = 1.0;
            if (f < 0x21) {
                scoreAlpha = (double)((float)(0x21 - f) * kPreStartFadeSlope) + 1.0;
            }
            /** @ghidraAddress 0x2924c0 (x), 0x28fa48 (y) */
            [self renderScore:0
                 partnerScore:0
                      atPoint:CGPointMake(500.0, 135.0)
                       scaleH:scoreAlpha
                        alpha:1.0];
            f = self->frame;
        }
    }

    // The music bar fades in over frames 5..14.
    if (f > kComboDrawThreshold) {
        double barAlpha = 1.0;
        if (f < 0xf) {
            barAlpha = (double)((float)(0xf - f) * kPreStartFadeSlope) + 1.0;
        }
        /** @ghidraAddress 0x2924b8 (music-bar y) */
        [self renderMusicBar:CGPointMake(0.0, 207.0) timeline:NO alpha:barAlpha];
    }

    [self renderButtons:kGameAreaOffset];

    // Frame 5 cues the "set" voice; frame 45 plays the mute stinger and advances the sub-state.
    if (self->frame == 0x2d) {
        [[AudioManager sharedManager] playSeResFile:@"SD_MUON" inDirectory:nil];
        self.subState = 10;
    } else if (self->frame == 5) {
        [[AudioManager sharedManager] playSeResFile:@"SD_CV_SET" inDirectory:nil];
    }
}

/** @ghidraAddress 0x104bcc */
- (void)renderBG {
    // Grid geometry (768x768 play field with its top at +256).
    static const double kGridTop = 256.0;  // @ghidraAddress 0x28e030
    static const double kGridSize = 768.0; // @ghidraAddress 0x292460
    // Combo-burst scaling is done about the grid centre (384 = kGridSize / 2).
    static const double kComboAnchorOffset = -384.0; // @ghidraAddress 0x292468
    static const double kComboAnchorBase = 384.0;    // @ghidraAddress 0x292470
    static const double kNegPi = -3.141592653589793; // @ghidraAddress 0x292478
    // Shutter/tension maths.
    static const float kTensionScale = 0.0009765625f;  // @ghidraAddress 0x292540 (1/1024)
    static const float kShutterTensionFactor = 435.0f; // @ghidraAddress 0x292544
    static const float kShutterMeasureWidth = 256.0f;  // @ghidraAddress 0x292548
    static const float kShutterMeasureShift = 384.0f;  // @ghidraAddress 0x29254c
    static const double kShutterSpan = 640.0;          // @ghidraAddress 0x291d80
    static const float kComboBaseScale = 0.75f;        // fmov 0x3f400000
    static const float kShutterAmpFactor = 10.0f;      // fmov 0x41200000
    static const float kShutterAmpBase = 15.0f;        // fmov 0x41700000

    // Tension thresholds selecting the combo animation group (0..4).
    enum {
        kTensionTier1 = 0x100,
        kTensionTier2 = 0x200,
        kTensionTier3 = 0x300,
        kTensionTier4 = 0x400,
    };
    // Sprite-table indices.
    enum {
        kBgSpriteBase = 3,        // background sprite index = base + combo group
        kComboBurstSprite = 8,    // combo-burst glyph; also OR'd with the group when drawn
        kShutterRegionSprite = 2, // shutter source region for drawInRect:fromRegion:
        kShutterTopSprite = 1,
        kShutterBottomSprite = 0,
    };

    float haku = 0.0f;
    float measure = 0.0f;
    int tension = 0;
    unsigned int comboGroup = 0;
    if (self.sequence != nil) {
        if (self.scoreBackup) {
            return;
        }
        const ScoreData *score = [self.sequence getScore];
        haku = self.sequence.hakuPhase;
        measure = self.sequence.measurePhase;
        if (score != nil) {
            tension = score->tension;
            if (tension < kTensionTier1) {
                comboGroup = 0;
            } else if (tension < kTensionTier2) {
                comboGroup = 1;
            } else if (tension < kTensionTier3) {
                comboGroup = 2;
            } else if (tension < kTensionTier4) {
                comboGroup = 3;
            } else {
                comboGroup = 4;
            }
        }
    }

    // Pulsing background: the tension tier picks the background sprite.
    [self.texBG drawSprite:(comboGroup + kBgSpriteBase)
                    inRect:CGRectMake(0.0, kGridTop, kGridSize, kGridSize)
                 transform:1
                     alpha:1.0f];

    // Combo-burst effect: one quad per animation frame, scaled about the grid centre.
    double scaleCurve = EvalComboScaleCurve(haku, comboGroup);
    if (GetComboAnimFrameCount(comboGroup) > 0) {
        int i = 0;
        do {
            CGPoint pos = GetComboAnimPosition(comboGroup, i);
            float animScaleNorm = GetComboAnimScale(comboGroup, i) / kComboBaseScale;
            // spriteAtIndex: only sizes the quad here; its origin is unused.
            CGRect burstSprite = [self.texBG spriteAtIndex:kComboBurstSprite];
            int drawW = (int)(scaleCurve * ((double)animScaleNorm * burstSprite.size.width));
            int drawH = (int)(scaleCurve * ((double)animScaleNorm * burstSprite.size.height));
            double centerX = scaleCurve * (pos.x + kComboAnchorOffset) + kComboAnchorBase;
            double centerY = scaleCurve * (pos.y + kComboAnchorOffset) + kComboAnchorBase;
            CGRect rect = CGRectMake(centerX - (double)((float)drawW * 0.5f),
                                     (centerY - (double)((float)drawH * 0.5f)) + kGridTop,
                                     drawW,
                                     drawH);
            float alpha = EvalComboAnimCurve(haku, comboGroup, i);
            [self.texBG drawSprite:(comboGroup | (unsigned int)kComboBurstSprite)
                            inRect:rect
                         transform:0
                             alpha:alpha];
            ++i;
        } while (i < GetComboAnimFrameCount(comboGroup));
    }

    // Shutter tween: the target open amount is driven by tension, then eased halfway each frame.
    float shutterTarget = (float)tension * kShutterTensionFactor * kTensionScale;
    if (shutterTarget > 0.0f) {
        float amp = (float)tension * kShutterAmpFactor * kTensionScale + kShutterAmpBase;
        float wave = (float)sin((double)haku * kNegPi);
        shutterTarget = shutterTarget + amp + amp * wave;
    }
    self->shutterOpen = (shutterTarget + self->shutterOpen) * 0.5f;

    // Two scrolling shutter bars sourced from a shared region.
    CGRect shutterRegion = [self.texBG spriteAtIndex:kShutterRegionSprite];
    double barHeight = (double)(measure * kShutterMeasureWidth);
    double topBarY = (kShutterSpan - (double)self->shutterOpen) - (double)measure * kShutterSpan;
    [self.texBG drawInRect:CGRectMake(0.0, topBarY, kGridSize, barHeight)
                fromRegion:shutterRegion
                 transform:0
                     alpha:1.0f];
    double bottomBarY =
        (double)(measure * kShutterMeasureShift) + (double)self->shutterOpen + kShutterSpan;
    [self.texBG drawInRect:CGRectMake(0.0, bottomBarY, kGridSize, barHeight)
                fromRegion:shutterRegion
                 transform:2
                     alpha:1.0f];

    // Shutter caps: the upper cap, then the mirrored lower cap sized by its own sprite.
    [self.texBG drawSprite:kShutterTopSprite
                   atPoint:CGPointMake(0.0, kShutterSpan - (double)self->shutterOpen)];
    CGRect topCap = [self.texBG spriteAtIndex:kShutterTopSprite];
    [self.texBG
        drawSprite:kShutterTopSprite
           atPoint:CGPointMake(0.0, ((double)self->shutterOpen + kShutterSpan) - topCap.size.height)
         transform:2
             alpha:1.0f];
    [self.texBG drawSprite:kShutterBottomSprite
                   atPoint:CGPointMake(0.0, (double)(kShutterMeasureWidth - self->shutterOpen))];
    [self.texBG drawSprite:kShutterBottomSprite
                   atPoint:CGPointMake(0.0, (double)self->shutterOpen + kShutterSpan)
                 transform:2
                     alpha:1.0f];

    [self.texBG commitDraw];
}

/** @ghidraAddress 0x10478c */
- (void)renderMarker {
    static const float kMarkerFadeDivisor = 100.0f; // @ghidraAddress 0x28f4e0
    static const double kMarkerFrameOffsetX = 20.0; // fmov immediate
    static const double kMarkerFrameOffsetY = 51.0; // @ghidraAddress 0x292458
    // The first-marker highlight fades in over the approach and the highlight sprite.
    static const int kMarkerHighlightSector = 0x96; // 150
    static const int kMarkerFadeClampSectors = 100; // clamp to 1.0 at/after this many sectors
    static const NSUInteger kMarkerHighlightSprite = 0x20;
    static const int kMarkerDirModulo = 4;

    int sectorDelta = (int)[self.sequence firstMarkerSector] - (int)[self.sequence currentSector];
    [self.sequence getMarkerState:self->markerState];

    int fadeSectors = sectorDelta - kMarkerHighlightSector;
    float fade = (float)fadeSectors / kMarkerFadeDivisor;
    double frameAlpha = 1.0;
    float highlightAlpha = 1.0f;
    if (fadeSectors < kMarkerFadeClampSectors) {
        frameAlpha = (double)fade;
        highlightAlpha = fade;
    }

    for (int i = 0; i < kMainGameGridPanelCount; ++i) {
        CGPoint origin = MainGameRendererPadPanelOrigin(i);

        unsigned int stateWord = (unsigned int)self->markerState[i];
        unsigned int phase = stateWord & 0xfff;
        unsigned int slot = (stateWord >> 0xc) & 7;

        int sprite;
        if (MainGameRendererPadMarkerSprite(phase, slot, &sprite)) {
            [self.texMarker drawSprite:(NSUInteger)sprite
                               atPoint:origin
                             transform:(char)self->markerDir[i]
                                 alpha:1.0f];
        } else {
            self->markerDir[i] = 0;
            if ([JubeatAppDelegate.appDelegate isMarkerDirRandom]) {
                self->markerDir[i] = rand() % kMarkerDirModulo;
            }
        }

        if (sectorDelta > kMarkerHighlightSector) {
            if (([self.sequence firstMarker] & (1u << i)) != 0) {
                [self renderMarkFrame:origin alpha:frameAlpha];
                [self.texFront drawSprite:kMarkerHighlightSprite
                                  atPoint:CGPointMake(origin.x + kMarkerFrameOffsetX,
                                                      origin.y + kMarkerFrameOffsetY)
                                transform:0
                                    alpha:highlightAlpha];
            }
        }
    }

    [self.sequence getHoldMarkerState:self->holdState];
    if ([self.rendererConf isStealth]) {
        return;
    }
    // holdState and HoldMarkerInfo are the same 16-byte per-panel record under two subsystem names.
    [self->holdMarkerRender renderHoldMarker:(HoldMarkerInfo *)self->holdState];
}

/** @ghidraAddress 0x10463c */
- (void)renderMarkFrame:(CGPoint)point alpha:(double)alpha {
    static const double kMarkFrameWide = 144.0;  // @ghidraAddress 0x28f660
    static const double kMarkFrameNarrow = 16.0; // fmov immediate
    // The frame's four glyph sprites, in draw order.
    enum {
        kMarkFrameSprite0 = 0xc, // at the cell origin
        kMarkFrameSprite1 = 0xd, // at (+144 x)
        kMarkFrameSprite2 = 0xe, // at (+16 y)
        kMarkFrameSprite3 = 0xf, // at (+16 x, +144 y)
    };

    float a = (float)alpha;
    [self.texFront drawSprite:kMarkFrameSprite0 atPoint:point transform:0 alpha:a];
    [self.texFront drawSprite:kMarkFrameSprite1
                      atPoint:CGPointMake(point.x + kMarkFrameWide, point.y)
                    transform:0
                        alpha:a];
    [self.texFront drawSprite:kMarkFrameSprite2
                      atPoint:CGPointMake(point.x, point.y + kMarkFrameNarrow)
                    transform:0
                        alpha:a];
    [self.texFront drawSprite:kMarkFrameSprite3
                      atPoint:CGPointMake(point.x + kMarkFrameNarrow, point.y + kMarkFrameWide)
                    transform:0
                        alpha:a];
}

/** @ghidraAddress 0x106804 */
- (void)renderButtons:(double)offsetY {
    static const double kButtonEdgeOffset = 160.0;  // @ghidraAddress 0x28f438
    static const double kButtonEdgeInset = 32.0;    // @ghidraAddress 0x28f458
    static const double kButtonLitInnerNear = 54.0; // @ghidraAddress 0x28f640
    static const double kButtonLitInnerFar = 138.0; // @ghidraAddress 0x2924c8
    // texFront sprite indices for the button-panel atlas.
    enum {
        kButtonSpriteUnlitFill = 3,   // unlit centre, drawn at the cell origin
        kButtonSpriteUnlitRight = 4,  // unlit right edge (+160 x)
        kButtonSpriteUnlitBottom = 5, // unlit bottom edge (+32 y)
        kButtonSpriteUnlitCorner = 6, // unlit corner (+32 x, +160 y)
        kButtonSpriteLitBase = 7,     // lit centre, drawn at the cell origin
        kButtonSpriteLitRight = 8,    // lit right edge (+160 x)
        kButtonSpriteLitBottom = 9,   // lit bottom edge (+32 y)
        kButtonSpriteLitCorner = 10,  // lit corner (+32 x, +160 y)
        kButtonSpriteLitFill = 11,    // lit fill, drawn four times with transforms 0..3
    };

    for (int i = 0; i < kMainGameGridPanelCount; ++i) {
        double x = (double)((i % 4) * kGridCellSize);
        double y = (double)((i / 4) * kGridCellSize) + offsetY;
        BOOL lit = ([self btnPress] & (1 << i)) != 0;

        if (lit) {
            [self.texFront drawSprite:kButtonSpriteLitFill atPoint:CGPointMake(x, y)];
            [self.texFront drawSprite:kButtonSpriteLitFill
                              atPoint:CGPointMake(x + kButtonLitInnerNear, y)
                            transform:1
                                alpha:1.0f];
            [self.texFront drawSprite:kButtonSpriteLitFill
                              atPoint:CGPointMake(x + kButtonLitInnerFar, y + kButtonLitInnerNear)
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
    }
}

/** @ghidraAddress 0x1052ac */
- (void)renderCombo:(unsigned int)combo {
    // Burst geometry and the count-glyph baseline come from the __const float/double pool.
    static const float kComboBurstBaseSize = 768.0f; // @ghidraAddress 0x292550
    static const float kComboBurstBaseY = 256.0f;    // @ghidraAddress 0x292548
    static const double kComboCountGlyphY = 746.0;   // @ghidraAddress 0x292480
    // Integer layout / animation-length constants.
    static const int kComboCutAnimFrames = 9;
    static const int kComboEffectResetFrames = 11;
    static const int kComboMaxDigits = 4;
    static const int kComboDigitBufferSize = 5;
    static const int kComboDigitStride = 180;
    static const int kComboRowWidth = 776;
    static const int kComboRowMargin = 10;
    static const int kComboDigitBaseY = 486;
    static const int kComboCountGlyphInset = 168;
    static const NSUInteger kComboBurstSprite = 0;
    static const NSUInteger kComboCountSprite = 1;

    if (self.scoreBackup) {
        return;
    }
    if (comboEffectFrame != 0) {
        --comboEffectFrame;
    }

    // Combo cut-in burst.
    int cutFrame;
    BOOL drawBurst = YES;
    if (combo < lastCombo && lastCombo > kComboDrawThreshold) {
        cutFrame = kComboCutAnimFrames;
        comboCutFrame = kComboCutAnimFrames;
    } else {
        cutFrame = (int)comboCutFrame;
        drawBurst = cutFrame != 0;
    }
    if (drawBurst) {
        if (self.showCombo) {
            unsigned int burstStep = (unsigned int)(kComboCutAnimFrames - cutFrame);
            float burstSize = GetComboScaleFactor(burstStep) * kComboBurstBaseSize;
            float burstX = (kComboBurstBaseSize - burstSize) * 0.5f;
            float burstY = burstX + kComboBurstBaseY;
            [self.texCombo drawSprite:kComboBurstSprite
                               inRect:CGRectMake(burstX, burstY, burstSize, burstSize)
                            transform:0
                                alpha:GetComboFadeFactor(burstStep)];
        }
        --comboCutFrame;
    }

    // Combo counter.
    if (combo > kComboDrawThreshold) {
        if (lastCombo < combo) {
            comboEffectFrame = kComboEffectResetFrames;
        }
        char buf[kComboDigitBufferSize];
        int n = snprintf(buf, kComboDigitBufferSize, "%d", combo);
        if (n >= 1) {
            unsigned int digitCount =
                (n > kComboMaxDigits) ? (unsigned int)kComboMaxDigits : (unsigned int)n;
            // Signed divide by two truncating toward zero, matching the (x + 1) >> 1 fix-up.
            int centerBase = (int)digitCount * -kComboDigitStride + kComboRowWidth;
            if (self.showCombo) {
                int baseX = centerBase / 2 + kComboRowMargin;
                unsigned int step = (unsigned int)kComboEffectResetFrames - comboEffectFrame;
                int x = baseX;
                for (int j = 0; j < (int)digitCount; ++j) {
                    int offset = GetComboDigitOffset(step, digitCount, j);
                    // The per-digit scale factor is passed to the drawSprite alpha argument.
                    float digitAlpha = GetComboScaleByDigit(step, digitCount, j);
                    [self.texCombo drawSprite:(NSUInteger)(buf[j] - '.')
                                      atPoint:CGPointMake(x, offset + kComboDigitBaseY)
                                    transform:0
                                        alpha:digitAlpha];
                    x += kComboDigitStride;
                }
                // The count scale factor is likewise passed as the drawSprite alpha argument.
                float countAlpha = GetComboScaleByCount(step, digitCount);
                [self.texCombo drawSprite:kComboCountSprite
                                  atPoint:CGPointMake(baseX + (int)digitCount * kComboDigitStride -
                                                          kComboCountGlyphInset,
                                                      kComboCountGlyphY)
                                transform:0
                                    alpha:countAlpha];
            }
        }
    }

    lastCombo = combo;
}

/** @ghidraAddress 0x1055cc */
- (void)renderUpdatedScore:(unsigned int)score
                   atPoint:(CGPoint)point
                     alpha:(double)alpha
                     scale:(double)scale
                    boardY:(float)boardY {
    static const double kScoreRightEdge = 768.0;       // @ghidraAddress 0x292460
    static const float kScoreLabelYOffset = -6.0f;     // fmov immediate 0xc0c00000
    static const double kScoreDigitNudge = 1.0;        // fmov immediate 0x3ff0000000000000
    static const int kScoreDigitStride = 16;           // 0x10, per-digit cell stride in points
    static const NSUInteger kScoreLabelSprite = 0x11;  // right-aligned label sprite
    static const NSUInteger kScorePrefixSprite = 0x43; // symbol drawn before the first digit
    static const NSUInteger kScoreCellSprite = 0x44;   // '0' glyph; also the digit cell size
    (void)alpha; // Yes, the binary never reads the alpha argument.
    if (score == 0) {
        return;
    }
    if (self.scoreBackup) {
        return;
    }
    char buf[8];
    snprintf(buf, sizeof(buf), "%7d", score);
    CGRect cellRect = [self.texFront spriteAtIndex:kScoreCellSprite];
    CGRect labelRect = [self.texFront spriteAtIndex:kScoreLabelSprite];
    float labelAlpha = fminf((float)(scale + scale), 1.0f);
    [self.texFront drawSprite:kScoreLabelSprite
                      atPoint:CGPointMake(kScoreRightEdge - labelRect.size.width,
                                          (double)(boardY + kScoreLabelYOffset))
                    transform:0
                        alpha:labelAlpha];
    double digitCellHeight = cellRect.size.height * scale;
    int lastNonDigit = -1;
    int digitX = kScoreDigitStride;
    for (int i = 0; i < 7; ++i) {
        unsigned char c = (unsigned char)buf[i];
        if ((unsigned int)(c - '0') < 10) {
            [self.texFront drawSprite:kScoreCellSprite + (NSUInteger)(buf[i] - '0')
                               inRect:CGRectMake(point.x + (double)digitX + kScoreDigitNudge,
                                                 point.y,
                                                 cellRect.size.width,
                                                 digitCellHeight)
                            transform:0
                                alpha:1.0f];
        } else {
            lastNonDigit = i;
        }
        digitX += kScoreDigitStride;
    }
    [self.texFront
        drawSprite:kScorePrefixSprite
            inRect:CGRectMake(point.x +
                                  (double)(lastNonDigit * kScoreDigitStride + kScoreDigitStride) +
                                  kScoreDigitNudge,
                              point.y,
                              cellRect.size.width,
                              digitCellHeight)
         transform:0
             alpha:1.0f];
}

/** @ghidraAddress 0x10586c */
- (void)renderScore:(unsigned int)score
       partnerScore:(unsigned int)partnerScore
            atPoint:(CGPoint)point
             scaleH:(double)scaleH
              alpha:(double)alpha {
    // Sprite 0x10 is the "SCORE" label; sprite 0x25 sizes the digit cell; sprite 0x24 is the
    // partner-score label. The digit glyphs run from base 0x25 (or 0x2f above the rank threshold).
    static const NSUInteger kScoreLabelSprite = 0x10;
    static const NSUInteger kScoreDigitCellSprite = 0x25;
    static const NSUInteger kPartnerLabelSprite = 0x24;
    static const NSUInteger kScoreGlyphBaseLow = 0x25;
    static const NSUInteger kScoreGlyphBaseHigh = 0x2f;
    static const double kScoreDigitOriginX = 25.0; // fmov 0x4039000000000000
    static const double kScoreDigitOriginY = 17.0; // fmov 0x4031000000000000
    static const int kScoreDigitStride = 0x20;     // 32, seven slots up to 0xe0
    static const int kScoreDigitColumns = 7;
    // The rank threshold above which the glyph base shifts to 0x2f.
    static const unsigned int kScoreRankThreshold = 700000; // 0xaae60
    // The partner row: offset from the player row, half-alpha when disconnected, a 0.7 scale, and
    // its own digit metrics.
    static const double kPartnerOffsetX = 76.0;       // @ghidraAddress 0x292488
    static const double kPartnerOffsetY = -50.0;      // @ghidraAddress 0x28e068
    static const double kPartnerScale = 0.7;          // @ghidraAddress 0x291c98
    static const float kPartnerDigitPitch = 22.4f;    // @ghidraAddress 0x292554
    static const double kPartnerDigitOriginX = 17.5;  // @ghidraAddress 0x28f680
    static const double kPartnerDigitOriginY = 11.9;  // @ghidraAddress 0x292490
    static const double kPartnerLabelOffsetX = -60.0; // @ghidraAddress 0x291bc8
    static const double kPartnerLabelOffsetY = -22.0; // fmov 0xbff6000000000000
    static const double kHalf = 0.5;

    // The label and digit cell dimensions drive every scaled rect below.
    CGRect labelCell = [self.texFront spriteAtIndex:kScoreLabelSprite];
    CGRect digitCell = [self.texFront spriteAtIndex:kScoreDigitCellSprite];

    // Tween the player's shown score halfway toward the target each frame (logical shift, as the
    // binary's LSR #1).
    if (score == 0) {
        scoreDisplay = 0;
    } else if (scoreDisplay != score) {
        unsigned int step = (scoreDisplay < score) ? 1u : (unsigned int)-1;
        scoreDisplay = scoreDisplay + (((score - scoreDisplay) + step) >> 1);
    }

    char buf[8];
    snprintf(buf, sizeof(buf), "%7d", scoreDisplay);
    NSUInteger glyphBase =
        (scoreDisplay > kScoreRankThreshold) ? kScoreGlyphBaseHigh : kScoreGlyphBaseLow;

    if (scaleH == 1.0) {
        [self.texFront drawSprite:kScoreLabelSprite atPoint:point transform:0 alpha:(float)alpha];
        for (int i = 0; i < kScoreDigitColumns; ++i) {
            unsigned char c = (unsigned char)(buf[i] - '0');
            if (c < 10) {
                [self.texFront drawSprite:(glyphBase + c)
                                  atPoint:CGPointMake(point.x + kScoreDigitOriginX +
                                                          (double)(i * kScoreDigitStride),
                                                      point.y + kScoreDigitOriginY)
                                transform:0
                                    alpha:(float)alpha];
            }
        }
    } else {
        double labelH = labelCell.size.height * scaleH;
        [self.texFront drawSprite:kScoreLabelSprite
                           inRect:CGRectMake(point.x,
                                             point.y + (labelCell.size.height - labelH) * kHalf,
                                             labelCell.size.width,
                                             labelH)
                        transform:0
                            alpha:(float)alpha];
        double digitH = digitCell.size.height * scaleH;
        for (int i = 0; i < kScoreDigitColumns; ++i) {
            unsigned char c = (unsigned char)(buf[i] - '0');
            if (c < 10) {
                [self.texFront drawSprite:(glyphBase + c)
                                   inRect:CGRectMake(point.x + kScoreDigitOriginX +
                                                         (double)(i * kScoreDigitStride),
                                                     point.y + kScoreDigitOriginY +
                                                         (digitCell.size.height - digitH) * kHalf,
                                                     digitCell.size.width,
                                                     digitH)
                                transform:0
                                    alpha:(float)alpha];
            }
        }
    }

    if (self.isSession) {
        double partnerAlpha = self.isConnected ? alpha : alpha * kHalf;
        double px = point.x + kPartnerOffsetX;
        double py = point.y + kPartnerOffsetY;

        if (partnerScore == 0) {
            partnerScoreDisplay = 0;
        } else if (partnerScoreDisplay != partnerScore) {
            unsigned int step = (partnerScoreDisplay < partnerScore) ? 1u : (unsigned int)-1;
            partnerScoreDisplay =
                partnerScoreDisplay + (((partnerScore - partnerScoreDisplay) + step) >> 1);
        }

        char pbuf[8];
        snprintf(pbuf, sizeof(pbuf), "%7d", partnerScoreDisplay);
        NSUInteger partnerBase =
            (partnerScoreDisplay > kScoreRankThreshold) ? kScoreGlyphBaseHigh : kScoreGlyphBaseLow;

        // The partner row is drawn at 0.7 scale, then vertically scaled by scaleH.
        double partnerLabelW = labelCell.size.width * kPartnerScale;
        double partnerLabelH = labelCell.size.height * kPartnerScale;
        double partnerDigitW = digitCell.size.width * kPartnerScale;
        double partnerDigitH = digitCell.size.height * kPartnerScale;

        double labelDrawH = partnerLabelH * scaleH;
        [self.texFront
            drawSprite:kScoreLabelSprite
                inRect:CGRectMake(
                           px, py + (partnerLabelH - labelDrawH) * kHalf, partnerLabelW, labelDrawH)
             transform:0
                 alpha:(float)partnerAlpha];

        double digitDrawH = partnerDigitH * scaleH;
        double digitBaseX = px + kPartnerDigitOriginX;
        double digitBaseY = py + kPartnerDigitOriginY;
        for (int i = 0; i < kScoreDigitColumns; ++i) {
            unsigned char c = (unsigned char)(pbuf[i] - '0');
            if (c < 10) {
                [self.texFront
                    drawSprite:(partnerBase + c)
                        inRect:CGRectMake(digitBaseX + (double)((float)i * kPartnerDigitPitch),
                                          digitBaseY + (partnerDigitH - digitDrawH) * kHalf,
                                          partnerDigitW,
                                          digitDrawH)
                     transform:0
                         alpha:(float)partnerAlpha];
            }
        }
        [self.texFront drawSprite:kPartnerLabelSprite
                          atPoint:CGPointMake(px + kPartnerLabelOffsetX, py + kPartnerLabelOffsetY)
                        transform:0
                            alpha:(float)partnerAlpha];
    }
}

/** @ghidraAddress 0x105e20 */
- (void)renderBonus:(unsigned int)bonus atPoint:(CGPoint)point alpha:(double)alpha {
    // Glyph row geometry within the passed anchor point.
    static const double kBonusGlyphOriginX = 25.0; // fmov immediate
    static const double kBonusGlyphOriginY = 17.0; // fmov immediate
    // Column stride and the '+7' field width the format string always produces.
    static const double kBonusGlyphStride = 32.0;
    static const int kBonusGlyphColumns = 7;
    // Atlas glyph for the forced '+' sign and the glyph for '0' (digits are base + value).
    static const NSUInteger kBonusSignSprite = 0x1b;
    static const NSUInteger kBonusDigitBaseSprite = 0x39;
    if (alpha < 0.0) {
        return;
    }
    if (alpha > 1.0) {
        alpha = 1.0;
    }
    float glyphAlpha = (float)alpha;
    char buf[8];
    // bonus is unsigned but the binary formats it signed with a forced sign and width 7.
    snprintf(buf, sizeof(buf), "%+7d", bonus);
    for (int i = 0; i < kBonusGlyphColumns; ++i) {
        char c = buf[i];
        NSUInteger sprite;
        if (c == '+') {
            sprite = kBonusSignSprite;
        } else if ((unsigned char)(c - '0') < 10) {
            sprite = kBonusDigitBaseSprite + (c - '0');
        } else {
            continue; // Width-padding spaces draw nothing.
        }
        [self.texFront drawSprite:sprite
                          atPoint:CGPointMake(point.x + kBonusGlyphOriginX + i * kBonusGlyphStride,
                                              point.y + kBonusGlyphOriginY)
                        transform:0
                            alpha:glyphAlpha];
    }
}

/** @ghidraAddress 0x105f74 */
- (void)renderMusicBar:(CGPoint)pos timeline:(BOOL)timeline alpha:(double)alpha {
    static const double kMusicBarMiddleXOffset = 96.0;            // @ghidraAddress 0x28f908
    static const double kMusicBarMiddleWidth = 576.0;             // @ghidraAddress 0x291d88
    static const double kMusicBarMiddleHeight = 48.0;             // @ghidraAddress 0x28f450
    static const double kMusicBarRightCapXOffset = 672.0;         // @ghidraAddress 0x292498
    static const double kMusicBarCellBaseXOffset = 85.0;          // @ghidraAddress 0x28f760
    static const double kMusicBarCellYOffset = 4.0;               // fmov 0x4010000000000000
    static const float kMusicBarCursorScale = 120.0f;             // @ghidraAddress 0x291be8
    static const float kMusicBarFadeEnd = 1.2999999523162842f;    // @ghidraAddress 0x292558
    static const float kMusicBarFadeStart = 0.30000001192092896f; // @ghidraAddress 0x28e0b0
    static const float kMusicBarPlayHeadScale = 600.0f;           // @ghidraAddress 0x291c3c
    static const float kMusicBarPlayHeadXOffset = 75.0f;          // @ghidraAddress 0x29255c
    static const double kMusicBarPlayHeadY = 199.0;               // @ghidraAddress 0x2924a0
    // texFront sprite indices for the strip and the per-note markers.
    static const NSUInteger kMusicBarSpriteLeftCap = 0x12;
    static const NSUInteger kMusicBarSpriteMiddle = 0x13;
    static const NSUInteger kMusicBarSpriteRightCap = 0x14;
    static const NSUInteger kMusicBarSpritePlayHead = 0x1a;
    static const int kMusicBarNoteBaseIdle = 0x4e;
    static const int kMusicBarNoteBaseCursor = 0x56;
    // Indexed by the per-cell 2-bit grade (XOR 2) to pick the graded note-marker sprite base.
    static const int kMusicBarRatingSpriteBase[] = {0x5e, 0x4e, 0x66, 0x56};
    static const int kMusicBarCellPitch = 5;
    enum { kMusicBarCellCount = 0x78 };

    // The three-piece bar backdrop: left cap, stretched middle strip, right cap.
    [self.texFront drawSprite:kMusicBarSpriteLeftCap
                      atPoint:CGPointMake(pos.x, pos.y)
                    transform:0
                        alpha:(float)alpha];
    [self.texFront drawSprite:kMusicBarSpriteMiddle
                       inRect:CGRectMake(pos.x + kMusicBarMiddleXOffset,
                                         pos.y,
                                         kMusicBarMiddleWidth,
                                         kMusicBarMiddleHeight)
                    transform:0
                        alpha:(float)alpha];
    [self.texFront drawSprite:kMusicBarSpriteRightCap
                      atPoint:CGPointMake(pos.x + kMusicBarRightCapXOffset, pos.y)
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
    double cellY = pos.y + kMusicBarCellYOffset;
    float cursor = playPosition * kMusicBarCursorScale; // The play cursor, in cell units.
    for (int i = 0; i < kMusicBarCellCount; ++i) {
        // Each cell packs a 4-bit note value into a nibble of the bar byte array.
        int byteIndex = i >> 1;
        int nibbleShift = (i & 1) * 4;
        unsigned int note = (unsigned int)(((bar[byteIndex] >> nibbleShift) & 0xf) - 1);
        if (note < 8) {
            int spriteBase;
            float cellF = (float)i;
            if (self.state == kRenderStateFinish || self.state == kRenderStateResult ||
                self.scoreBackup || (cellF + kMusicBarFadeEnd < cursor)) {
                // A finished/result/replay cell (or a cell the cursor has fully passed) shows its
                // graded marker, from the 2-bit grade packed four-per-byte in musicBarResult.
                int gradeByte = score->musicBarResult[i >> 2];
                int gradeShift = (i & 3) * 2;
                int grade = ((gradeByte >> gradeShift) & 3) ^ 2;
                spriteBase = kMusicBarRatingSpriteBase[grade];
            } else {
                // A still-upcoming cell is idle; the cell the cursor currently sits in is lit.
                spriteBase = (cellF + kMusicBarFadeStart < cursor) ? kMusicBarNoteBaseIdle :
                                                                     kMusicBarNoteBaseCursor;
            }
            [self.texFront
                drawSprite:(NSUInteger)((int)note + spriteBase)
                   atPoint:CGPointMake(cellBaseX + (double)(i * kMusicBarCellPitch), cellY)
                 transform:0
                     alpha:(float)alpha];
        }
    }

    if (timeline) {
        // The play-head sprite, tracking the play position.
        [self.texFront drawSprite:kMusicBarSpritePlayHead
                          atPoint:CGPointMake((double)(playPosition * kMusicBarPlayHeadScale +
                                                       kMusicBarPlayHeadXOffset),
                                              kMusicBarPlayHeadY)
                        transform:0
                            alpha:(float)alpha];
    }
}

/** @ghidraAddress 0x1063b0 */
- (void)renderTuneInfo:(CGPoint)pos artworkSize:(double)artworkSize alpha:(double)alpha {
    static const double kTitleChipXOffset = 17.0;     // fmov 0x4031000000000000
    static const double kTitleChipYOffset = -0.28125; // fmov 0xbfd2000000000000
    static const double kDifficultyXOffset = 20.0;    // fmov 0x4034000000000000
    static const double kDifficultyYOffset = 72.0;    // @ghidraAddress 0x291e40
    static const double kLevelXNudgeExtreme = 143.0;  // @ghidraAddress 0x2924a8
    static const double kLevelXNudgeAdvanced = 165.0; // @ghidraAddress 0x2924b0
    static const double kLevelXNudgeBasic = 92.0;     // @ghidraAddress 0x28f748
    static const double kLevelXNudgeDefault = 70.0;   // @ghidraAddress 0x28f6a0
    static const double kLevelYNudge = -1.0;          // fmov 0xbff0000000000000
    // texFront sprite indices for the tune-info block.
    static const NSUInteger kTuneInfoSpriteJacket = 0x15;
    static const NSUInteger kTuneInfoSpriteTitle = 0x16;
    static const NSUInteger kTuneInfoSpriteDifficulty = 0x17;
    static const NSUInteger kTuneInfoSpriteLevel = 0x19;

    // The jacket artwork, drawn stretched into sprite 0x15's frame.
    [self.texFront drawSprite:kTuneInfoSpriteJacket
                       inRect:CGRectMake(pos.x, pos.y, artworkSize, artworkSize)
                    transform:0
                        alpha:(float)alpha];
    double x = pos.x + artworkSize;
    // The tune-name chip.
    [self.texFront drawSprite:kTuneInfoSpriteTitle
                      atPoint:CGPointMake(x + kTitleChipXOffset, pos.y + kTitleChipYOffset)
                    transform:0
                        alpha:(float)alpha];
    x += kDifficultyXOffset;
    double y = pos.y + kDifficultyYOffset;
    // The difficulty word, at its native size.
    [self.texFront drawSprite:kTuneInfoSpriteDifficulty atPoint:CGPointMake(x, y)];
    // The per-difficulty x-nudge for the level word.
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
    x += levelXNudge;
    y += kLevelYNudge;
    // The level word.
    [self.texFront drawSprite:kTuneInfoSpriteLevel
                      atPoint:CGPointMake(x, y)
                    transform:0
                        alpha:(float)alpha];
}

/** @ghidraAddress 0x1065a0 */
- (void)renderUpperBG:(double)y height:(double)height {
    static const double kUpperBGWidth = 768.0; // @ghidraAddress 0x292460

    // The upper band takes sprite 0's texture region, scrolled down by y, and stretches it across
    // the full 768-wide screen from the top.
    CGRect sprite = [self.texFront spriteAtIndex:0];
    [self.texFront
        drawInRect:CGRectMake(0.0, 0.0, kUpperBGWidth, height)
        fromRegion:CGRectMake(sprite.origin.x, sprite.origin.y + y, kUpperBGWidth, height)
         transform:0
             alpha:1.0f];
}

/** @ghidraAddress 0x106e00 */
- (void)renderCircle:(CGPoint)point size:(double)size alpha:(double)alpha {
    // A full ring built from a single quadrant sprite mirrored into four size x size cells around
    // point, with the texture-coordinate orientation flipped per quadrant (0, 4, 5, 2).
    static const NSUInteger kCircleSprite = 7;
    [self.texReady drawSprite:kCircleSprite
                       inRect:CGRectMake(point.x - size, point.y - size, size, size)
                    transform:0
                        alpha:(float)alpha];
    [self.texReady drawSprite:kCircleSprite
                       inRect:CGRectMake(point.x - size, point.y, size, size)
                    transform:4
                        alpha:(float)alpha];
    [self.texReady drawSprite:kCircleSprite
                       inRect:CGRectMake(point.x, point.y - size, size, size)
                    transform:5
                        alpha:(float)alpha];
    [self.texReady drawSprite:kCircleSprite
                       inRect:CGRectMake(point.x, point.y, size, size)
                    transform:2
                        alpha:(float)alpha];
}

/** @ghidraAddress 0x106f78 */
- (void)renderReadyGo {
    static const float kReadyCircleSwell = 1.32f;    // @ghidraAddress 0x292564
    static const double kReadyCircleCenterX = 384.0; // @ghidraAddress 0x292470
    static const double kReadyFieldCenterY = 600.0;  // @ghidraAddress 0x291c30
    static const double kReadyCircleSize = 190.0;    // @ghidraAddress 0x291c88
    static const double kReadyMarkTopX = 218.0;      // @ghidraAddress 0x2924d8
    static const double kReadyMarkTopY = 452.0;      // @ghidraAddress 0x2924e0
    static const double kReadyMarkBottomX = 194.0;   // @ghidraAddress 0x291d10
    static const double kReadyMarkBottomY = 590.0;   // @ghidraAddress 0x2924e8
    static const float kReadyLetterDrop = 40.0f;     // @ghidraAddress 0x292568
    static const float kReadyLetterSpread = 100.0f;  // @ghidraAddress 0x28f4e0
    static const int kReadyFieldWidth = 0x300;       // 768
    static const int kReadyLetterCount = 5;
    CGRect readySprite = [self.texReady spriteAtIndex:0];
    int spriteW = (int)readySprite.size.width;
    int spriteH = (int)readySprite.size.height;
    // The whole overlay fades in over frames 0x14..0x1e and out over 0x50..0x56.
    float overlayAlpha;
    if (frame < 0x50) {
        overlayAlpha = InterpolateFloatByFrame(0.0f, 1.0f, frame, 0x14, 0x1e);
    } else {
        overlayAlpha = InterpolateFloatByFrame(1.0f, 0.0f, frame, 0x50, 0x56);
    }
    if (overlayAlpha > 0.0f) {
        // The soft circle behind the letters swells to 1.32x then settles, and blows up on exit.
        float circleScale;
        if (frame < 0x25) {
            circleScale = InterpolateFloatByFrame(1.0f, kReadyCircleSwell, frame, 0x23, 0x25);
        } else if (frame < 0x50) {
            circleScale = InterpolateFloatByFrame(kReadyCircleSwell, 1.0f, frame, 0x25, 0x29);
        } else {
            circleScale = InterpolateFloatByFrame(1.0f, 2.0f, frame, 0x50, 0x56);
        }
        [self renderCircle:CGPointMake(kReadyCircleCenterX, kReadyFieldCenterY)
                      size:(double)circleScale * kReadyCircleSize
                     alpha:(double)overlayAlpha];
        // Two mark chips (sprites 8 and 9) spin in from the sides, each drawn twice half a turn
        // apart.
        float spin = (float)((double)((float)((int)frame - 0x14) / 30.0f) * g_dPi);
        CGPoint anchor = CGPointMake(kReadyCircleCenterX, kReadyFieldCenterY);
        [self.texReady drawSprite:8
                          atPoint:CGPointMake(kReadyMarkTopX, kReadyMarkTopY)
                            scale:circleScale
                           rotate:spin
                           anchor:anchor
                        transform:0
                            alpha:overlayAlpha];
        [self.texReady drawSprite:8
                          atPoint:CGPointMake(kReadyMarkTopX, kReadyMarkTopY)
                            scale:circleScale
                           rotate:(float)((double)spin + g_dPi)
                           anchor:anchor
                        transform:0
                            alpha:overlayAlpha];
        [self.texReady drawSprite:9
                          atPoint:CGPointMake(kReadyMarkBottomX, kReadyMarkBottomY)
                            scale:circleScale
                           rotate:spin
                           anchor:anchor
                        transform:0
                            alpha:overlayAlpha];
        [self.texReady drawSprite:9
                          atPoint:CGPointMake(kReadyMarkBottomX, kReadyMarkBottomY)
                            scale:circleScale
                           rotate:(float)((double)spin + g_dPi)
                           anchor:anchor
                        transform:0
                            alpha:overlayAlpha];
    }
    // Centre the five "READY" letters across the field, rounding toward zero for a narrow field.
    int lettersNumer = kReadyFieldWidth - spriteW * kReadyLetterCount;
    if (lettersNumer < 0) {
        lettersNumer = (kReadyFieldWidth + 1) - spriteW * kReadyLetterCount;
    }
    double baseX = (double)(lettersNumer >> 1);
    double lettersY = kReadyFieldCenterY - (double)(spriteH >> 1);
    if (frame < 0x45) {
        // Each letter settles in one by one, dropping into place.
        int letterOffsetX = 0;
        for (long letter = 0; letter <= 4; ++letter) {
            unsigned int startFrame = (unsigned int)(0x1b + letter * 2);
            float letterAlpha =
                InterpolateFloatByFrame(0.0f, 1.0f, frame, startFrame, startFrame + 4);
            if (letterAlpha > 0.0f) {
                float drop = InterpolateFloatByFrame(
                    kReadyLetterDrop, 0.0f, frame, startFrame, startFrame + 5);
                [self.texReady
                    drawSprite:(NSUInteger)letter
                       atPoint:CGPointMake(baseX + (double)letterOffsetX, lettersY - (double)drop)
                     transform:0
                         alpha:letterAlpha];
            }
            letterOffsetX += spriteW;
        }
    } else {
        // Once "GO" takes over, the five letters slide apart and fade out together.
        float outAlpha = InterpolateFloatByFrame(1.0f, 0.0f, frame, 0x45, 0x4b);
        float spread = InterpolateFloatByFrame(0.0f, kReadyLetterSpread, frame, 0x45, 0x4b);
        if (outAlpha > 0.0f) {
            double spreadD = (double)spread;
            [self.texReady drawSprite:0
                              atPoint:CGPointMake(baseX + spreadD * -2.0, lettersY)
                            transform:0
                                alpha:outAlpha];
            [self.texReady drawSprite:1
                              atPoint:CGPointMake((baseX + (double)spriteW) - spreadD, lettersY)
                            transform:0
                                alpha:outAlpha];
            [self.texReady drawSprite:2
                              atPoint:CGPointMake(baseX + (double)(spriteW * 2) + spreadD * 0.0,
                                                  lettersY)
                            transform:0
                                alpha:outAlpha]; // The middle letter stays put; the binary still
                                                 // adds spread*0.
            [self.texReady drawSprite:3
                              atPoint:CGPointMake(baseX + (double)(spriteW * 3) + spreadD, lettersY)
                            transform:0
                                alpha:outAlpha];
            [self.texReady
                drawSprite:4
                   atPoint:CGPointMake(baseX + (double)(spriteW * 4) + spreadD + spreadD, lettersY)
                 transform:0
                     alpha:outAlpha];
        }
    }
    // The "GO" halves (sprites 5 and 6) with their own frame windows and x keyframes.
    MainGameRendererPadRenderGoMark(
        self, frame, 5, 0x45, 0x4a, spriteW, spriteH, 340.0f, 254.0f, 298.0f, 184.0f);
    // @ghidraAddress 0x292578, 0x292574, 0x29256c, 0x292570
    MainGameRendererPadRenderGoMark(
        self, frame, 6, 0x47, 0x4c, spriteW, spriteH, 424.0f, 511.0f, 466.0f, 580.0f);
    // @ghidraAddress 0x292588, 0x292584, 0x29257c, 0x292580
    if (frame == 0x1b) {
        [AudioManager.sharedManager playSeResFile:@"SD_CV_READY" inDirectory:nil];
    }
    if (frame == 0x45) {
        [AudioManager.sharedManager playSeResFile:@"SD_CV_GO" inDirectory:nil];
    }
    if (frame >= 100) {
        self.subState = 99;
    }
}

/** @ghidraAddress 0x107904 */
- (void)renderStartMark {
    static const float kStartMarkFadeInFrames = 15.0f; // fmov 0x41700000
    static const double kStartMarkGlyphOffsetX = 20.0; // fmov 0x4034000000000000
    static const double kStartMarkGlyphOffsetY = 51.0; // @ghidraAddress 0x292458
    static const NSUInteger kStartMarkGlyphSprite = 0x20;

    unsigned int firstMarker = self.sequence.firstMarker;
    for (unsigned int panel = 0; panel < kMainGameGridPanelCount; ++panel) {
        if (((1u << panel) & firstMarker) == 0) {
            continue;
        }
        CGPoint origin = MainGameRendererPadPanelOrigin((int)panel);
        // The start mark fades in over the first 15 frames of the state.
        float markAlpha = (frame < 15) ? ((float)frame / kStartMarkFadeInFrames) : 1.0f;
        [self renderMarkFrame:origin alpha:(double)markAlpha];
        [self.texFront drawSprite:kStartMarkGlyphSprite
                          atPoint:CGPointMake(origin.x + kStartMarkGlyphOffsetX,
                                              origin.y + kStartMarkGlyphOffsetY)
                        transform:0
                            alpha:markAlpha];
    }
}

/** @ghidraAddress 0x107a98 */
- (void)renderFinish {
    static const float kFinishWipeRate = 0.06f;         // @ghidraAddress 0x29258c
    static const double kFinishCurtainY = 256.0;        // @ghidraAddress 0x28e030
    static const double kFinishFieldWidth = 768.0;      // @ghidraAddress 0x292460
    static const double kFinishBannerBoxHeight = 192.0; // @ghidraAddress 0x28fa00
    static const int kFinishCurtainWidth = 0x300;       // 768
    static const int kFinishCurtainStep = 0x10;         // 16
    static const NSUInteger kFinishCurtainSprite = 1;
    static const NSUInteger kFinishBannerSprite = 2;
    // The four finish-banner vertical offsets from the banner's centred origin.
    /** @ghidraAddress 0x28e030, 0x2924f0, 0x291d80, 0x2924f8 */
    static const double kFinishBandY[] = {256.0, 448.0, 640.0, 832.0};

    // The whole field wipes to white over ~17 frames (0.06 per frame, capped at 1.0).
    float wipe = (float)frame * kFinishWipeRate;
    if (wipe > 1.0f) {
        wipe = 1.0f;
    }
    // The white curtain: 48 columns drawn across the game area from the field top.
    for (int columnX = 0; columnX < kFinishCurtainWidth; columnX += kFinishCurtainStep) {
        [self.texFront drawSprite:kFinishCurtainSprite
                          atPoint:CGPointMake((double)columnX, kFinishCurtainY)
                        transform:1
                            alpha:wipe];
    }
    // Four finish-message banners (sprite 2), horizontally centred, stacked at four vertical bands.
    CGRect banner = [self.texFront spriteAtIndex:2];
    double centerX = (kFinishFieldWidth - banner.size.width) * 0.5;
    double centerY = (kFinishBannerBoxHeight - banner.size.height) * 0.5;
    for (int band = 0; band < 4; ++band) {
        [self.texFront drawSprite:kFinishBannerSprite
                          atPoint:CGPointMake(centerX, centerY + kFinishBandY[band])
                        transform:0
                            alpha:wipe];
    }
    // On frame 5 (unless a replay score is backed up), play the finish voice once.
    if (frame == 5 && !self.scoreBackup) {
        if (self.sequence.isExcellent) {
            [AudioManager.sharedManager playSeResFile:@"SD_CV_EXCELLENT" inDirectory:nil];
        } else if (self.sequence.isFullcombo) {
            [AudioManager.sharedManager playSeResFile:@"SD_CV_FULLCOMBO" inDirectory:nil];
        } else {
            [AudioManager.sharedManager playSeResFile:@"SD_CV_FINISH" inDirectory:nil];
        }
    }
    // The finish sub-state advances once the wipe has run for 60 frames.
    if (self.subState == 0 && frame == 0x3c) {
        self.subState = 10;
    }
}

/** @ghidraAddress 0x107e44 */
- (BOOL)renderCleared:(unsigned int)animFrame centerY:(double)centerY {
    // Per-letter final centre X positions for "CLEARED".
    /** @ghidraAddress 0x2925c0 */
    static const double kClearedLetterX[] = {68.0, 173.0, 279.0, 385.0, 491.0, 598.0, 702.0};
    // Per-letter atlas sprite index.
    /** @ghidraAddress 0x2925f8 */
    static const unsigned int kClearedLetterSprite[] = {0, 1, 2, 3, 0, 2, 1};
    // X the letters fly out from before sliding to their final positions.
    static const double kClearedLetterSpawnX = 384.0; // @ghidraAddress 0x29254c
    enum {
        kClearedLetterCount = 7,
        kClearedLetterStagger = 2, // frames between successive letters starting
        kClearedLetterDuration = 6,
        kResultExitStartFrame = 80,
    };

    MainGameRendererPadDrawResultFlashBeam(self.texClear0, animFrame, centerY);

    // The letter glyphs all share sprite 0's cell dimensions for centring and scaling.
    CGRect cell = [self.texClear0 spriteAtIndex:0];
    Texture2D *letterTex[] = {
        self.texClear0,
        self.texClear0,
        self.texClear0,
        self.texClear0,
        self.texClear1,
        self.texClear0,
        self.texClear1,
    };
    for (int i = 0; i < kClearedLetterCount; ++i) {
        unsigned int startFrame = (unsigned int)(i * kClearedLetterStagger);
        unsigned int endFrame = startFrame + kClearedLetterDuration;
        float alpha = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, startFrame, endFrame);
        if (alpha <= 0.0f) {
            continue;
        }
        float x = InterpolateFloatByFrame((float)kClearedLetterSpawnX,
                                          (float)kClearedLetterX[i],
                                          animFrame,
                                          startFrame,
                                          endFrame);
        float scale = InterpolateFloatByFrame(2.0f, 1.0f, animFrame, startFrame, endFrame);
        double w = cell.size.width * (double)scale;
        double h = cell.size.height * (double)scale;
        [letterTex[i] drawSprite:kClearedLetterSprite[i]
                          inRect:CGRectMake((double)x - w * 0.5, centerY - h * 0.5, w, h)
                       transform:0
                           alpha:alpha];
    }
    return animFrame > kResultExitStartFrame - 1;
}

/** @ghidraAddress 0x10823c */
- (BOOL)renderFailed:(unsigned int)animFrame centerY:(double)centerY {
    // Per-letter final centre X positions for "FAILED".
    /** @ghidraAddress 0x292660 */
    static const double kFailedLetterX[] = {147.0, 254.0, 333.0, 414.0, 521.0, 628.0};
    // Vertical distance each letter drops from before settling.
    /** @ghidraAddress 0x292630 */
    static const double kFailedLetterFall[] = {56.0, 79.0, 50.0, 74.0, 68.0, 35.0};
    // Per-letter atlas sprite index.
    /** @ghidraAddress 0x292690 */
    static const unsigned int kFailedLetterSprite[] = {2, 3, 0, 1, 2, 3};
    enum {
        kFailedLetterCount = 6,
        kFailedLetterStagger = 3, // frames between successive letters starting
        kFailedLetterDuration = 6,
        kResultExitStartFrame = 80,
    };

    MainGameRendererPadDrawResultFlashBeam(self.texClear1, animFrame, centerY);

    // The letters are drawn at natural size but centred using sprite 2's cell dimensions.
    CGRect cell = [self.texClear1 spriteAtIndex:2];
    double halfWidth = cell.size.width * 0.5;
    double halfHeight = cell.size.height * 0.5;
    Texture2D *letterTex[] = {
        self.texClear1,
        self.texClear1,
        self.texClear2,
        self.texClear2,
        self.texClear2,
        self.texClear2,
    };
    for (int i = 0; i < kFailedLetterCount; ++i) {
        unsigned int startFrame = (unsigned int)(i * kFailedLetterStagger);
        unsigned int endFrame = startFrame + kFailedLetterDuration;
        float alpha = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, startFrame, endFrame);
        if (alpha <= 0.0f) {
            continue;
        }
        float fall = InterpolateFloatByFrame(
            (float)kFailedLetterFall[i], 0.0f, animFrame, startFrame, endFrame);
        [letterTex[i] drawSprite:kFailedLetterSprite[i]
                         atPoint:CGPointMake(kFailedLetterX[i] - halfWidth,
                                             (centerY - (double)fall) - halfHeight)
                       transform:0
                           alpha:alpha];
    }
    return animFrame > kResultExitStartFrame - 1;
}

/** @ghidraAddress 0x108804 */
- (void)renderResult {
    static const double kGameAreaOffset = 256.0;         // @ghidraAddress 0x28e030
    static const double kTuneInfoArtworkSize = 160.0;    // @ghidraAddress 0x28f438
    static const double kMusicBarY = 207.0;              // @ghidraAddress 0x2924b8
    static const double kScoreX = 500.0;                 // @ghidraAddress 0x2924c0
    static const double kScoreY = 135.0;                 // @ghidraAddress 0x28fa48
    static const double kFieldWidth = 768.0;             // @ghidraAddress 0x292460
    static const double kButtonAreaResultOffset = 192.0; // @ghidraAddress 0x28fa00
    // The upper-BG rise: y interpolates from a start value to 16, height from 0 to 192 over 20
    // frames.
    static const float kUpperBGYRate = -112.0f;     // @ghidraAddress 0x292598
    static const float kUpperBGYBase = 128.0f;      // @ghidraAddress 0x29259c
    static const float kUpperBGHeightRate = 192.0f; // @ghidraAddress 0x2925a0
    // The tune-info slide-in over the first ten frames.
    static const double kTuneInfoSettleY = 40.0;     // @ghidraAddress 0x28f1f8
    static const float kTuneInfoSlideRate = 40.0f;   // @ghidraAddress 0x292568
    static const double kTuneInfoSlideBaseY = -40.0; // @ghidraAddress 0x28e078
    // The "result" word rise over the first fifteen frames.
    static const float kResultWordRate = -1600.0f; // @ghidraAddress 0x2925a4
    static const float kResultWordBase = 1620.0f;  // @ghidraAddress 0x2925a8
    // The curtain wipe (frames 0..9) and the four message bands.
    static const int kCurtainWidth = 0x300; // 768
    static const int kCurtainStep = 0x10;   // 16
    /** @ghidraAddress 0x2924f0, 0x291d80, 0x2924f8 */
    static const double kMessageBandY[] = {448.0, 640.0, 832.0};
    // The bonus tally-in (frames 40..59) and the record/rating fade rate.
    static const float kFadeRatePerFrame = -0.07999999821186066f; // @ghidraAddress 0x2925ac
    // The rating draw positions.
    static const double kRatingLabelX = 240.0; // @ghidraAddress 0x291bf0
    static const double kRatingLabelY = 785.0; // @ghidraAddress 0x292500
    static const double kRatingGlyphX = 400.0; // @ghidraAddress 0x28f2e0
    static const double kRatingGlyphY = 658.0; // @ghidraAddress 0x292508
    // The new-record banner and its previous-record score.
    static const double kRecordBannerX = 630.0;     // @ghidraAddress 0x292510
    static const double kRecordScoreX = 618.0;      // @ghidraAddress 0x292518
    static const double kRecordScoreYOffset = 60.0; // @ghidraAddress 0x28f258
    static const double kRecordLabelYOffset = -5.0; // fmov 0xbfec... (-5.0)
    // The result-mark (frames after the sub-state changes) positions.
    static const double kResultMarkTweak = 656.0;       // @ghidraAddress 0x292520
    static const double kResultMarkFrameX = 592.0;      // @ghidraAddress 0x292528
    static const double kResultMarkGlyphYOffset = 52.0; // @ghidraAddress 0x28f220
    static const double kResultMarkGlyphX = 612.0;      // @ghidraAddress 0x292530
    static const double kGoodJobMarkX = 420.0;          // @ghidraAddress 0x292538
    static const double kGoodJobFrameX = 400.0;         // @ghidraAddress 0x28f2e0
    static const double kBonusOffsetX = 500.0;          // @ghidraAddress 0x2924c0
    static const double kBonusLabelOffsetX = -60.0;     // @ghidraAddress 0x291bc8
    static const int kRankThreshold = 700000;
    static const NSUInteger kResultCurtainSprite0 = 0x1d;
    static const NSUInteger kResultCurtainSprite1 = 0x1e;
    static const NSUInteger kResultTuneWordSprite = 0x1c;
    static const NSUInteger kResultBannerSprite = 1;
    static const NSUInteger kResultMessageSprite = 2;
    static const NSUInteger kRecordBannerSprite = 0x23;
    static const NSUInteger kRatingLabelSprite = 1;
    static const NSUInteger kRatingGlyphSprite = 0;
    static const NSUInteger kResultMarkGlyphSprite = 0x21;
    static const NSUInteger kGoodJobGlyphSprite = 0x20;

    AudioManager *audio = AudioManager.sharedManager;
    const ScoreData *score = [self.sequence getScore];
    unsigned int f = self->frame;

    // The upper background rises into place over the first 20 frames.
    double upperY;
    double upperHeight;
    if (f < 0x14) {
        float ff = (float)f;
        upperY = (double)(ff * kUpperBGYRate / 20.0f + kUpperBGYBase);
        upperHeight = (double)(ff * kUpperBGHeightRate / 20.0f);
    } else {
        upperY = 16.0;
        upperHeight = kButtonAreaResultOffset;
    }
    double bandBase = upperHeight + kGameAreaOffset;
    [self renderUpperBG:upperY height:bandBase];

    // The two "result" title-plate halves slide down over the first ten frames.
    double slideY;
    if (f < 10) {
        slideY = (double)(((float)f * kTuneInfoSlideRate) / 10.0f);
    } else {
        slideY = kTuneInfoSettleY;
    }
    double plateY = slideY + kTuneInfoSlideBaseY;
    [self.texFront drawSprite:kResultCurtainSprite0 atPoint:CGPointMake(0.0, plateY)];
    [self.texFront drawSprite:kResultCurtainSprite1
                      atPoint:CGPointMake(384.0, plateY)]; // @ghidraAddress 0x292470 (384)
    [self renderTuneInfo:CGPointMake(18.0, slideY * 0.5 + 25.0)
             artworkSize:kTuneInfoArtworkSize
                   alpha:1.0];

    // The "result" word rises over the first fifteen frames.
    double wordX;
    if (f < 0xf) {
        wordX = (double)(((float)f * kResultWordRate) / 15.0f + kResultWordBase);
    } else {
        wordX = 20.0;
    }
    [self.texFront drawSprite:kResultTuneWordSprite atPoint:CGPointMake(wordX, 6.0)];

    [self renderMusicBar:CGPointMake(0.0, slideY + kMusicBarY) timeline:NO alpha:1.0];

    // The message-band curtain wipes across over the first ten frames.
    f = self->frame;
    double curtainAlpha = 1.0;
    if (f < 10) {
        curtainAlpha = (double)((float)f * kFadeRatePerFrame + 1.0f);
        for (int columnX = 0; columnX < kCurtainWidth; columnX += kCurtainStep) {
            [self.texFront drawSprite:kResultBannerSprite
                              atPoint:CGPointMake((double)columnX, bandBase)
                            transform:1
                                alpha:(float)curtainAlpha];
        }
        // The four message banners at their vertical bands.
        CGRect banner = [self.texFront spriteAtIndex:kResultMessageSprite];
        double centerX = (kFieldWidth - banner.size.width) * 0.5;
        double centerY = (kButtonAreaResultOffset - banner.size.height) * 0.5;
        [self.texFront drawSprite:kResultMessageSprite
                          atPoint:CGPointMake(centerX, slideY + centerY + kGameAreaOffset)
                        transform:2
                            alpha:(float)curtainAlpha];
        for (int band = 0; band < 3; ++band) {
            [self.texFront drawSprite:kResultMessageSprite
                              atPoint:CGPointMake(centerX, slideY + centerY + kMessageBandY[band])
                            transform:2
                                alpha:(float)curtainAlpha];
        }
        f = self->frame;
        curtainAlpha = (double)((float)(10 - f) * kFadeRatePerFrame + 1.0f);
    }

    // The score: the running total until frame 40, then the final total plus any bonus.
    if (f < 0x28 || self.scoreBackup) {
        unsigned int total = (unsigned int)score->point;
        if (self.scoreBackup) {
            ScoreData backup = self.replayBackupScore;
            total = (unsigned int)backup.totalPoint;
        }
        [self renderScore:total
             partnerScore:self.partnerScore
                  atPoint:CGPointMake(kScoreX, slideY + kScoreY)
                   scaleH:1.0
                    alpha:1.0];
    } else {
        [self renderScore:(unsigned int)score->totalPoint
             partnerScore:(self.partnerFinalBonus + self.partnerScore)
                  atPoint:CGPointMake(kScoreX, slideY + kScoreY)
                   scaleH:1.0
                    alpha:1.0];
        if (!(self.isSession && self.isConnected)) {
            f = self->frame;
            if (f < 0x3c) {
                // The bonus number tallies in over frames 40..59.
                double bonusAlpha = (double)((float)(f - 0x28) * kFadeRatePerFrame + 1.5f);
                [self renderBonus:(unsigned int)score->bonusPoint
                          atPoint:CGPointMake(kBonusOffsetX,
                                              (slideY + kScoreY + kBonusLabelOffsetX) -
                                                  (double)(f - 0x28))
                            alpha:bonusAlpha];
            }
        }
    }

    // The cleared/failed graphic from frame 70, gated off during a replay backup.
    f = self->frame;
    BOOL animationDone;
    if (f < 0x46 || self.scoreBackup) {
        animationDone = self.scoreBackup;
    } else {
        double centerY = 260.0; // @ghidraAddress 0x291c80
        if (score->totalPoint > kRankThreshold - 1) {
            animationDone = [self renderCleared:(f - 0x46) centerY:centerY];
        } else {
            animationDone = [self renderFailed:(f - 0x46) centerY:centerY];
        }
    }

    // The rank rating, fading in from frame 80.
    f = self->frame;
    if (0x4f < f) {
        double ratingAlpha;
        if (f < 0x5f) {
            ratingAlpha = (double)((float)(0x5f - f) * kFadeRatePerFrame) + 1.0;
            if (ratingAlpha < 0.0) {
                ratingAlpha = 0.0;
            }
        } else {
            ratingAlpha = 1.0;
        }
        if (!self.scoreBackup) {
            [self.texRating drawSprite:kRatingLabelSprite
                               atPoint:CGPointMake(kRatingLabelX, kRatingLabelY)
                             transform:1
                                 alpha:(float)ratingAlpha];
            [self.texRating drawSprite:kRatingGlyphSprite
                               atPoint:CGPointMake(kRatingGlyphX, kRatingGlyphY)];
        }
    }

    // The new-record banner, from frame 100. The banner sprite is rotated (transform 1), so it
    // grows along its own width, which maps to the screen-vertical direction.
    if (self.isNewRecord && self->frame > 99 && !self.scoreBackup) {
        CGRect banner = [self.texFront spriteAtIndex:kRecordBannerSprite];
        double recordY = slideY + kScoreY + kRecordLabelYOffset;
        f = self->frame;
        double scaledLength = banner.size.width; // The along-width extent that scales in.
        double bannerY = recordY;
        double bannerAlpha = 1.0;
        if (f < 0x6e) {
            // Unrolls over frames 100..109, centred on its final position.
            scaledLength = (banner.size.width / 10.0) * (double)(f - 100);
            bannerY = recordY + (banner.size.width - scaledLength) * 0.5;
        } else if (0x77 < f) {
            // A gentle bob after frame 0x78.
            float bob = cosf((float)((double)((float)(f - 0x78) / 20.0f) * g_dPi));
            bannerAlpha = (double)(bob * g_flComboFadeBase + g_flKeyTime070);
        }
        [self.texFront
            drawSprite:kRecordBannerSprite
                inRect:CGRectMake(kRecordBannerX, bannerY, banner.size.height, scaledLength)
             transform:1
                 alpha:(float)bannerAlpha];
        [self renderUpdatedScore:self.scoreRecord
                         atPoint:CGPointMake(kRecordScoreX, bannerY + kRecordScoreYOffset)
                           alpha:bannerAlpha
                           scale:(scaledLength / banner.size.width)
                          boardY:(float)(recordY + kRecordScoreYOffset)];
    }

    // Once the result reaches its interactive sub-state, draw the good-job / share marks and fade
    // the good-job overlay in.
    if (self.subState != 0) {
        double markBase = slideY + kResultMarkTweak;
        unsigned int elapsed = self->frame - self->subStateChangeFrame;
        float markAlpha = (elapsed > 7) ? 1.0f : (float)elapsed * 0.125f;

        [self renderMarkFrame:CGPointMake(kResultMarkFrameX, markBase) alpha:(double)markAlpha];
        double glyphY = markBase + kResultMarkGlyphYOffset;
        [self.texFront drawSprite:kResultMarkGlyphSprite
                          atPoint:CGPointMake(kResultMarkGlyphX, glyphY)
                        transform:(char)(int)markAlpha
                            alpha:0x21]; // Faithful: the binary's transform/alpha shuffle.

        if (!self.replayPlaying && self.isCustom && self.isDownload && self.hasMusic) {
            if (!self.isTextureChange) {
                self.isTextureChange = YES;
                LoadTextureSubImageFromResource(
                    self.texFront,
                    @"game_level_vote",
                    [self.texFront spriteAtIndex:kGoodJobGlyphSprite].origin);
                if (self.goodJobImage) {
                    __weak UIImageView *goodJob = self.goodJobImage;
                    float alphaMax = self.goodJobAlphaMax;
                    [UIView animateWithDuration:0.3
                                     animations:^{
                                       /** @ghidraAddress 0x109830 */
                                       [goodJob setAlpha:(double)alphaMax];
                                     }
                                     completion:^(BOOL __attribute__((unused)) finished){
                                         /** @ghidraAddress 0x109884 */
                                     }];
                }
            }
            [self renderMarkFrame:CGPointMake(kGoodJobFrameX, markBase) alpha:(double)markAlpha];
            [self.texFront drawSprite:kGoodJobGlyphSprite
                              atPoint:CGPointMake(kGoodJobMarkX, glyphY)
                            transform:(char)(int)markAlpha
                                alpha:0x20];
        }

        if (!self.isCustom && self.hasMusic && self.goodJobImage) {
            __weak UIImageView *goodJob = self.goodJobImage;
            float alphaMax = self.goodJobAlphaMax;
            [UIView animateWithDuration:0.3
                             animations:^{
                               /** @ghidraAddress 0x109888 */
                               [goodJob setAlpha:(double)alphaMax];
                             }
                             completion:^(BOOL __attribute__((unused)) finished){
                                 /** @ghidraAddress 0x1098dc */
                             }];
        }

        if (self.isSession && !self.hasMusic && self.goodJobImage) {
            __weak UIImageView *goodJob = self.goodJobImage;
            float alphaMax = self.goodJobAlphaMax;
            [UIView animateWithDuration:0.3
                             animations:^{
                               /** @ghidraAddress 0x1098e0 */
                               [goodJob setAlpha:(double)alphaMax];
                             }
                             completion:^(BOOL __attribute__((unused)) finished){
                                 /** @ghidraAddress 0x109934 */
                             }];
        }
    }

    [self renderButtons:bandBase];

    // The per-phase sound-effect cues.
    if (!self.scoreBackup) {
        int phase = (int)self->frame;
        if (phase == 0x46) {
            if (score->totalPoint < kRankThreshold) {
                [audio playSeResFile:@"SD_CV_FAILED" inDirectory:nil];
                [audio playSeResFile:@"SD_RESULT_FAILED" inDirectory:nil];
            } else {
                [audio playSeResFile:@"SD_CV_CLEAR" inDirectory:nil];
                [audio playSeResFile:@"SD_RESULT_CLEAR" inDirectory:nil];
            }
        } else if (phase == 0x28) {
            [audio playSeResFile:@"SD_RESULT_SLIDE" inDirectory:nil];
        } else if (phase == 10) {
            [audio playSeResFile:@"SD_CV_RESULT" inDirectory:nil];
        }
    }

    // Once the cleared/failed animation finishes, advance to the interactive sub-state.
    if (animationDone && self.subState == 0) {
        self.subState = 10;
        self->subStateChangeFrame = self->frame;
    }
}

@end
