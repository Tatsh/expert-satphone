#import "MainGameRendererPhoneKnt.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#import <UIKit/UIKit.h>

#import "AudioManager.h"
#import "BFCodec.h"
#import "EffectBgKnit.h"
#import "HoldMarkerRender.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "MarkerManager.h"
#import "RendererConf.h"
#import "Sequence.h"
#import "Texture2D.h"
#import "TextureLoading.h"
#import "UpperBGKnit.h"
#import "cipher_keys.h"
#import "combo_display.h"
#import "neEngineBridge.h"

// ==== CONSTANTS ====

// The knit renderer enters the playing state (3) from -startPlay and marks the result state (5)
// finished from -endResult with the end sub-state (99). Shared with the classic phone renderer.
enum {
    MainGamePhoneKntStatePlaying = 3, // Active play.
    MainGamePhoneKntStateResult = 5,  // The result screen.
};

// The sub-state value that marks the play session as finished.
static const unsigned int kMainGamePhoneKntEndSubState = 99;

// The button-position grid: 0x50-point pitch with a 0x28-point half-cell inset.
enum {
    kButtonGridPitch = 0x50,
    kButtonGridInset = 0x28,
};

// The game area top on the four-inch phone, added to buttonMarginForScreen40.
enum { kFourInchGameTop = 0xa0 };

// The default (non-four-inch) game-area offset, 160 points. @ghidraAddress 0x28f438
static const double kGameAreaOffsetDefault = 160.0;

// The knit upper-background construction constants passed to -[UpperBGKnit initBg:...]. The bg
// rectangle spans the full 320-point width with a per-idiom height; the wave-top and pulse-height
// reach initBg as fmov immediates (prose-only). The wave baseline is 110 points by default and
// (upperBgHeight40 / 3 + 110) on the four-inch phone.
static const double kUpperBGKnitWidth = 320.0;         // @ghidraAddress 0x28f470
static const double kUpperBGKnitHeightDefault = 160.0; // @ghidraAddress 0x28f438
static const float kUpperBGKnitWaveTop = 20.0f;        // fmov 0x41a00000
static const float kUpperBGKnitPulseHeight = 15.0f;    // fmov 0x41700000
// The default wave baseline float, 110.0 (0x42dc0000). @ghidraAddress 0x293330
static const float kUpperBGKnitBaselineDefault = 110.0f;

// The four-inch resting-baseline bias added to (upperBgHeight40 / 3).
enum { kFourInchBaselineBias = 0x6e };

// The replay-swap animation duration, 0.3 seconds. @ghidraAddress 0x28f260
static const double kReplayFadeDuration = 0.3;

// The knit start-mark replay chip resource swapped into front-atlas sprite 3.
static NSString *const kReplayChipResource = @"game_start_mark_knt_pn2";

// ==== HELPERS ====

// (none)

// ==== METHOD ====

// ==== CONSTANTS ====

// The render-state values this renderer dispatches on.
enum {
    MainGamePhoneKntStatePreStart = 1, // The pre-start intro.
    MainGamePhoneKntStateReady = 2,    // The ready/go countdown before play.
    MainGamePhoneKntStatePlay = 3,     // Active play.
    MainGamePhoneKntStateFinish = 4,   // The finish transition.
    MainGamePhoneKntStateResultA = 5,  // The result screen.
    MainGamePhoneKntStateResultB = 6,  // The second result sub-screen.
};

// The reset sub-state that resets the per-state combo, shutter, and beat counters.
enum {
    MainGamePhoneKntResetStateZero = 0, // The idle reset state.
    MainGamePhoneKntResetStateTwo = 2,  // The pre-ready reset state.
};

// The result screen loads the knit result BGM and starts it without a fade.
static NSString *const kResultBgmResource = @"SD_KNT_BGM_RESULT";

// The player's "go" voice, loaded on the ready state and played on the countdown frame.
static NSString *const kPlayerGoResource = @"SD_KNT_CV_GO";

// The 4x4 grid geometry: sixteen panels on a 0x50-point pitch, below the upper region.
enum {
    kGridColumns = 4,
    kGridPitch = 0x50,
    kFourInchGameTopE = 0xa0, // The game-area top on the four-inch phone.
};

// The result-background atlas pixel sizes: retina is 0x400, non-retina 0x200.
enum {
    kResultBgPixelSizeRetina = 0x400,
    kResultBgPixelSize = 0x200,
};

// The ranks that carry a rating overlay blitted into the result-background atlas (sprite 0). A rank
// of 8 or more loads only the base texture.
enum { kRatingRankCount = 8 };

// The debug-font glyph advance and newline drop, in points.
static const double kDebugGlyphAdvance = 12.0;

static const double kDebugLineHeight = 20.0;

enum { kDebugMaxGlyphs = 0x200 };

// The button-highlight sprite x-nudge (40 points) for the pressed overlay.
static const double kButtonHighlightNudge = 40.0; // @ghidraAddress 0x28f1f8

// ==== HELPERS ====

// Draws one 4x4 button-grid panel column pass. De-inlined from the grid loop of -renderButtons: a
// pressed panel draws the down overlay (sprite 2 twice, once nudged), then every panel draws its
// base state sprite (0 up / 1 down). The four-inch phone offsets the grid by the button margin.
static inline void MainGameRendererPhoneKntDrawButtonGrid(MainGameRendererPhoneKnt *self,
                                                          BOOL is4Inch) {
    for (unsigned int panel = 0; panel < kMainGameGridPanelCount; ++panel) {
        double panelX = (double)((int)(panel % kGridColumns) * kGridPitch);
        int gameTop = is4Inch ? self.buttonMarginForScreen40 : 0;
        double panelY =
            (double)((int)(panel / kGridColumns) * kGridPitch + gameTop + kFourInchGameTopE);
        BOOL pressed = (self.btnPress & (1 << panel)) != 0;
        if (pressed) {
            [self.texFront drawSprite:2 atPoint:CGPointMake(panelX, panelY)];
            // The pressed highlight is drawn 40 points to the right with transform 5.
            [self.texFront drawSprite:2
                              atPoint:CGPointMake(panelX + kButtonHighlightNudge, panelY)
                            transform:5
                                alpha:1.0f];
        }
        [self.texFront drawSprite:(NSUInteger)pressed atPoint:CGPointMake(panelX, panelY)];
    }
}

// ==== METHODS ====

// ==== CONSTANTS ====

// The maximum difficulty and level the configuration is clamped to before texture load.
// (0x18a2b0 cmp #4, 0x18a2e0 cmp #0xb.)
enum {
    kMaxDifficulty = 3,
    kMaxLevel = 10,
};

// The square texel dimension of each atlas texture.
enum {
    kWaveTexturePixelSize = 0x40,   // Each of the six knit-wave layers.
    kFrontTexturePixelSize = 0x400, // texFront, and the non-retina beat background.
    kAtlasPixelSize = 0x800,        // texMarker, texHoldMarker, texCombo, and the retina beat bg.
};

// The knit renderer builds six stacked wave layers, all sharing one sprite table.
enum { kWaveTextureCount = 6 };

// The user-default the knit colour theme is read from, clamped to the four packaged variants.
static NSString *const kPrefColorKnitKey = @"PrefColorKnit";

enum { kPrefColorKnitMax = 3 };

// Beat-background atlas sprite indices for the two packaged theme layers.
enum {
    kBeatBgSpriteLayer1 = 9,  // "game_bg_knt_%d_1".
    kBeatBgSpriteLayer2 = 10, // "game_bg_knt_%d_2".
};

// Front-atlas sprite indices for the knit theme.
enum {
    kFrontSpriteArtwork = 0xb,      // The jacket artwork.
    kFrontSpriteIndex = 0xc,        // The aspect-fitted index image.
    kFrontSpriteLevelWord = 0x12,   // "game_lv_%d_knt".
    kFrontSpriteStartMark = 3,      // "game_start_mark_knt_pn2".
    kFrontSpriteEndMark = 4,        // "game_end_mark_knt_pn2".
    kFrontSpritePartnerName = 0x20, // The rendered partner-name label.
};

// The note-marker and hold-marker archive frame counts and bank geometry.
enum {
    kMarkerFrameCount = 0x18,      // "ma%02d", 24 frames.
    kHoldBankCount = 4,            // Four "h" hold banks.
    kHoldBankFrameCount = 0x10,    // 16 frames per bank.
    kHoldMarkerRowCount = 6,       // "m%d%02d", 6 rows.
    kHoldMarkerColumnCount = 0x10, // 16 columns.
    kHoldMarkerTailCount = 8,      // "m6%02d", 8 frames.
    kHoldMarkerTailBase = 0x60,    // "m6" sprites start at index 96.
};

// Retina renders the partner-name label at 20 points, non-retina at 10. Both arrive as fmov
// immediates (0x4034000000000000 / 0x4026000000000000), so they carry no data address.
static const double kPartnerFontSizeRetina = 20.0;

static const double kPartnerFontSize = 10.0;

// ==== HELPERS ====

// Builds the six knit-wave texture layers, all sharing the one wave sprite table, then blits the
// encrypted wave image into each. De-inlined from the wave section of -loadTexure:artwork:index:.
static inline void MainGameRendererPhoneKntBuildWaveTextures(MainGameRendererPhoneKnt *self,
                                                             BFCodec *codec,
                                                             NSData *cipherKey) {
    self.texWaveAr = [[NSMutableArray alloc] init];
    NSString *plist = [NSBundle.mainBundle pathForResource:@"game_wave_knt_0_tex" ofType:@"plist"];
    NSArray *sprites = [[NSArray alloc] initWithContentsOfFile:plist];
    for (int i = 0; i < kWaveTextureCount; ++i) {
        Texture2D *layer = [[Texture2D alloc] initWithData:nullptr
                                               pixelFormat:Texture2DPixelFormatRGBA8888
                                                 pixelSize:kWaveTexturePixelSize];
        [layer setSprites:sprites];
        [self.texWaveAr addObject:layer];
    }
    // The cipher is keyed once and the six layers decode from the running stream, matching the
    // binary; it is not re-initialised per layer.
    [codec cipherInit:cipherKey];
    for (int i = 0; i < kWaveTextureCount; ++i) {
        LoadTextureSubImageFromEncryptedTex(
            self.texWaveAr[i], @"game_wave_knt_0_tex", codec, CGPointMake(0.0, 0.0));
    }
}

// Builds the beat-background atlas and blits its base layer, then composites the two theme layers
// selected by the packaged colour preference. De-inlined from the beat-background section of
// -loadTexure:artwork:index:.
static inline void MainGameRendererPhoneKntBuildBeatBgTexture(MainGameRendererPhoneKnt *self,
                                                              BOOL isRetina,
                                                              BFCodec *codec,
                                                              NSData *cipherKey) {
    NSString *plist;
    NSString *baseLayer;
    if (isRetina) {
        self.texBeatBg = [[Texture2D alloc] initWithData:nullptr
                                             pixelFormat:Texture2DPixelFormatRGBA8888
                                               pixelSize:kAtlasPixelSize];
        plist = @"game_beatbg_knt_tex_pn2";
        baseLayer = @"game_beatbg_knt_tex_1_pn2";
    } else {
        self.texBeatBg = [[Texture2D alloc] initWithData:nullptr
                                             pixelFormat:Texture2DPixelFormatRGBA8888
                                               pixelSize:kFrontTexturePixelSize];
        plist = @"game_beatbg_knt_tex_pn";
        baseLayer = @"game_beatbg_knt_tex_1_pn";
    }
    NSString *plistPath = [NSBundle.mainBundle pathForResource:plist ofType:@"plist"];
    [self.texBeatBg setSprites:[[NSArray alloc] initWithContentsOfFile:plistPath]];
    LoadTextureSubImageFromEncryptedTex(self.texBeatBg, baseLayer, codec, CGPointMake(0.0, 0.0));
    // The knit colour theme selects the two overlay layers; it is clamped to the four packaged
    // variants, an out-of-range value falling back to variant 0.
    NSInteger colorKnit = [NSUserDefaults.standardUserDefaults integerForKey:kPrefColorKnitKey];
    if ((NSUInteger)colorKnit > kPrefColorKnitMax) {
        colorKnit = 0;
    }
    NSString *layer1Name = [NSString stringWithFormat:@"game_bg_knt_%d_1", (int)colorKnit];
    NSString *layer1Path = [NSBundle.mainBundle pathForResource:layer1Name ofType:@"png"];
    if (layer1Path) {
        UIImage *layer1 = [[UIImage alloc] initWithContentsOfFile:layer1Path];
        [self.texBeatBg setSubImage:layer1
                             inRect:[self.texBeatBg spriteAtIndex:kBeatBgSpriteLayer1]];
    }
    NSString *layer2Name = [NSString stringWithFormat:@"game_bg_knt_%d_2", (int)colorKnit];
    NSString *layer2Path = [NSBundle.mainBundle pathForResource:layer2Name ofType:@"png"];
    if (layer2Path) {
        UIImage *layer2 = [[UIImage alloc] initWithContentsOfFile:layer2Path];
        [self.texBeatBg setSubImage:layer2
                             inRect:[self.texBeatBg spriteAtIndex:kBeatBgSpriteLayer2]];
    }
    self.texBeatBg.isScale2x = isRetina;
}

// Rebuilds the front atlas and blits its level word, start-mark, and end-mark chips. Unlike the
// classic phone renderer, the knit front carries no difficulty or music-bar word. De-inlined from
// the front-atlas section of -loadTexure:artwork:index:.
static inline void MainGameRendererPhoneKntBuildFrontTexture(MainGameRendererPhoneKnt *self,
                                                             RendererConf *conf,
                                                             BFCodec *codec,
                                                             NSData *cipherKey) {
    self.texFront = [[Texture2D alloc] initWithData:nullptr
                                        pixelFormat:Texture2DPixelFormatRGBA8888
                                          pixelSize:kFrontTexturePixelSize];
    NSString *plist = [NSBundle.mainBundle pathForResource:@"game_front_knt_tex_pn2"
                                                    ofType:@"plist"];
    [self.texFront setSprites:[[NSArray alloc] initWithContentsOfFile:plist]];
    [codec cipherInit:cipherKey];
    LoadTextureSubImageFromEncryptedTex(
        self.texFront, @"game_front_knt_tex_pn2", codec, CGPointMake(0.0, 0.0));
    NSString *levelWord = [NSString stringWithFormat:@"game_lv_%d_knt", conf.level];
    LoadTextureSubImageFromResource(
        self.texFront, levelWord, [self.texFront spriteAtIndex:kFrontSpriteLevelWord].origin);
    LoadTextureSubImageFromResource(self.texFront,
                                    @"game_start_mark_knt_pn2",
                                    [self.texFront spriteAtIndex:kFrontSpriteStartMark].origin);
    LoadTextureSubImageFromResource(self.texFront,
                                    @"game_end_mark_knt_pn2",
                                    [self.texFront spriteAtIndex:kFrontSpriteEndMark].origin);
}

// Unzips the note-marker frames into the marker atlas: one bank of twenty-four "ma" frames, then
// four banks of sixteen "h" hold frames. De-inlined from the marker section of
// -loadTexure:artwork:index:.
static inline void MainGameRendererPhoneKntLoadMarkerTexture(MainGameRendererPhoneKnt *self,
                                                             BOOL isRetina,
                                                             RendererConf *conf,
                                                             BFCodec *codec,
                                                             NSData *cipherKey) {
    // The base sprite index for each of the four "h" hold banks. @ghidraAddress 0x2935b0
    static const int kHoldBankBase[] = {0x18, 0x28, 0x38, 0x48};
    @autoreleasepool {
        if (self.texMarker) {
            self.texMarker = nil;
        }
        self.texMarker = [[Texture2D alloc] initWithData:nullptr
                                             pixelFormat:Texture2DPixelFormatRGBA8888
                                               pixelSize:kAtlasPixelSize];
        NSString *plist = [NSBundle.mainBundle pathForResource:@"game_marker_tex_pn2"
                                                        ofType:@"plist"];
        [self.texMarker setSprites:[[NSArray alloc] initWithContentsOfFile:plist]];
    }
    NSString *markerPath = [MarkerManager getMarkerPath:conf.markerID];
    KUnzip *unzip = [[KUnzip alloc] initWithPath:markerPath];
    @autoreleasepool {
        for (unsigned int i = 0; i < kMarkerFrameCount; ++i) {
            [codec cipherInit:cipherKey];
            NSString *name = [NSString stringWithFormat:@"ma%02d", i];
            NSMutableData *data = [unzip uncompress:name];
            UIImage *image = CreateImageFromEncryptedData(codec, data);
            if (image) {
                [self.texMarker setSubImage:image inRect:[self.texMarker spriteAtIndex:i]];
            }
        }
    }
    for (int bank = 0; bank < kHoldBankCount; ++bank) {
        @autoreleasepool {
            for (int i = 0; i < kHoldBankFrameCount; ++i) {
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
    self.texMarker.isScale2x = isRetina;
}

// Builds the hold-marker atlas and its sub-renderer, then unzips the "m" and "m6" hold-marker
// frames from hm0001.zip. De-inlined from the hold-marker section of -loadTexure:artwork:index:.
static inline void
MainGameRendererPhoneKntBuildHoldMarkerTexture(MainGameRendererPhoneKnt *self,
                                               HoldMarkerRender *__strong *holdMarkerRender,
                                               BOOL is4Inch,
                                               BFCodec *codec,
                                               NSData *cipherKey) {
    @autoreleasepool {
        if (self.texHoldMarker) {
            self.texHoldMarker = nil;
        }
        self.texHoldMarker = [[Texture2D alloc] initWithData:nullptr
                                                 pixelFormat:Texture2DPixelFormatRGBA8888
                                                   pixelSize:kAtlasPixelSize];
        NSString *plist = [NSBundle.mainBundle pathForResource:@"game_hold_marker_tex"
                                                        ofType:@"plist"];
        [self.texHoldMarker setSprites:[[NSArray alloc] initWithContentsOfFile:plist]];
        if (!*holdMarkerRender) {
            // The game area is delayed on the four-inch idiom by the phone button margin.
            int gameAreaDelay = is4Inch ? self.buttonMarginForScreen40 : 0;
            *holdMarkerRender = [[HoldMarkerRender alloc] init:self.texHoldMarker
                                                         isPad:NO
                                                 gameAreaDelay:gameAreaDelay];
        }
    }
    // The hold-marker frame loops deliberately run outside any autorelease pool, matching the
    // binary.
    NSString *zipPath = [NSBundle.mainBundle pathForResource:@"hm0001" ofType:@"zip"];
    KUnzip *unzip = [[KUnzip alloc] initWithPath:zipPath];
    for (int row = 0; row < kHoldMarkerRowCount; ++row) {
        for (int col = 0; col < kHoldMarkerColumnCount; ++col) {
            [codec cipherInit:cipherKey];
            NSString *name = [NSString stringWithFormat:@"m%d%02d", row, col];
            NSMutableData *data = [unzip uncompress:name];
            UIImage *image = CreateImageFromEncryptedData(codec, data);
            if (image) {
                unsigned int spriteIndex = (unsigned int)(row * kHoldMarkerColumnCount + col);
                [self.texHoldMarker
                    setSubImage:image
                        atPoint:[self.texHoldMarker spriteAtIndex:spriteIndex].origin];
            }
        }
    }
    for (int i = 0; i < kHoldMarkerTailCount; ++i) {
        [codec cipherInit:cipherKey];
        NSString *name = [NSString stringWithFormat:@"m6%02d", i];
        NSMutableData *data = [unzip uncompress:name];
        UIImage *image = CreateImageFromEncryptedData(codec, data);
        if (image) {
            unsigned int spriteIndex = (unsigned int)(i + kHoldMarkerTailBase);
            [self.texHoldMarker setSubImage:image
                                    atPoint:[self.texHoldMarker spriteAtIndex:spriteIndex].origin];
        }
    }
}

// Blits the jacket artwork, the aspect-fitted index image, and the optional partner-name label
// into the front atlas, then marks it scale-2x. De-inlined from the composite section of
// -loadTexure:artwork:index:.
static inline void MainGameRendererPhoneKntCompositeFront(MainGameRendererPhoneKnt *self,
                                                          BOOL isRetina,
                                                          RendererConf *conf,
                                                          UIImage *artwork,
                                                          UIImage *index) {
    [self.texFront setSubImage:artwork inRect:[self.texFront spriteAtIndex:kFrontSpriteArtwork]];
    if (index) {
        CGRect frame = [self.texFront spriteAtIndex:kFrontSpriteIndex];
        CGSize size = index.size;
        // Height preserves the index image's aspect ratio within the frame's width.
        [self.texFront setSubImage:index
                            inRect:CGRectMake(frame.origin.x,
                                              frame.origin.y,
                                              frame.size.width,
                                              (frame.size.width * size.height) / size.width)];
    }
    if (conf.partnerName) {
        CGRect labelFrame = [self.texFront spriteAtIndex:kFrontSpritePartnerName];
        UILabel *label = [[UILabel alloc] initWithFrame:labelFrame];
        label.opaque = NO;
        label.backgroundColor = UIColor.clearColor; // The original used +clearColor.
        label.textColor = UIColor.blackColor;       // The original used +blackColor.
        label.textAlignment = NSTextAlignmentRight; // 2.
        label.font =
            [UIFont boldSystemFontOfSize:(isRetina ? kPartnerFontSizeRetina : kPartnerFontSize)];
        label.text = conf.partnerName;
        UIImage *rendered = [label renderImage];
        [self.texFront setSubImage:rendered
                           atPoint:[self.texFront spriteAtIndex:kFrontSpritePartnerName].origin];
    }
    self.texFront.isScale2x = isRetina;
}

// Rebuilds the combo atlas from its encrypted texture. De-inlined from the combo section of
// -loadTexure:artwork:index:.
static inline void MainGameRendererPhoneKntBuildComboTexture(MainGameRendererPhoneKnt *self,
                                                             BOOL isRetina,
                                                             BFCodec *codec,
                                                             NSData *cipherKey) {
    @autoreleasepool {
        if (self.texCombo) {
            self.texCombo = nil;
        }
        self.texCombo = [[Texture2D alloc] initWithData:nullptr
                                            pixelFormat:Texture2DPixelFormatRGBA8888
                                              pixelSize:kAtlasPixelSize];
        NSString *plist = [NSBundle.mainBundle pathForResource:@"game_combo_knt_tex_pn2"
                                                        ofType:@"plist"];
        [self.texCombo setSprites:[[NSArray alloc] initWithContentsOfFile:plist]];
        [codec cipherInit:cipherKey];
        LoadTextureSubImageFromEncryptedTex(
            self.texCombo, @"game_combo_knt_tex_pn2", codec, CGPointMake(0.0, 0.0));
    }
    self.texCombo.isScale2x = isRetina;
}

// The Excellent (perfect-million) result banner's final sparkle burst (frame >= 0x7c): twenty
// particles from four parallel tables (sprite, base x, base y, scale), drawn at a shared -0.4746
// rotation. Particles 0..14 rise or fall relative to the 320-point centre line (offset by the
// four-inch button margin); the last five sweep outward and, from frame 0x8d, ripple on a 20-frame
// cycle, each drawn as an eight-step offset trail plus itself.
static const int kExcParticleSprite[] = { // @ghidraAddress 0x293938
    14, 14, 14, 15, 16, 16, 16, 17, 17, 14, 16, 15, 14, 16, 17, 0, 0, 0, 0, 0};
static const float kExcParticleX[] = { // @ghidraAddress 0x293988
    -19.7f, -20.6f, -12.2f, -11.4f, -7.7f,  -14.3f, -4.9f,  46.6f,  57.6f, 100.4f,
    41.8f,  140.4f, 147.9f, 145.4f, 108.6f, 76.1f,  158.0f, 235.9f, 74.5f, -4.7f};
static const float kExcParticleY[] = { // @ghidraAddress 0x2939d8
    40.1f,  78.6f,  18.8f,  66.7f,  11.6f,  104.4f, 308.3f, 315.1f, 313.8f, 352.4f,
    326.0f, 312.2f, 361.8f, 354.5f, 326.0f, 284.6f, 282.6f, 288.8f, 38.9f,  42.1f};
static const float kExcParticleScale[] = { // @ghidraAddress 0x293a28
    1.58f, 1.53f, 0.84f, 0.68f, 0.66f, 1.25f, 1.9f, 1.59f, 1.59f, 1.2f,
    1.59f, 1.84f, 1.23f, 1.0f,  1.07f, 1.0f,  1.0f, 1.0f,  1.0f,  1.0f};
static const int kExcParticleCount = 20;
static const int kExcSweepParticleFirst = 15;
static const float kExcParticleRotate = -0.47459015f; // @ghidraAddress 0x2934c4
static const float kExcParticleYBias = 6.0f;          // fmov, 6.0
static const float kExcParticleTrailStep = 80.0f;     // @ghidraAddress 0x28e018
static const float kExcParticleTrailYScale = 1.02f;   // @ghidraAddress 0x2934f4

// The Excellent panels fill the grid rows in this reflow order (a 16-entry table read every other
// frame), on the phone's 80-point grid pitch inset 6, dropped 160 (plus the four-inch margin),
// minus a 6-point half.
static const int kExcPanelOrder[] = { // @ghidraAddress 0x2938f8
    0,
    4,
    8,
    12,
    13,
    14,
    15,
    11,
    7,
    3,
    2,
    1,
    5,
    9,
    10,
    6};
static const int kExcPanelPitch = 0x50; // 80
static const int kExcPanelInset = 6;
static const int kExcPanelGridTopY = 0xa0;       // 160
static const double kExcPanelHalf = -6.0;        // fmov, -6.0
static const double kExcPanelSpread = 80.0;      // @ghidraAddress 0x28f3f8
static const int kExcSweepThresholdBase = 0x140; // 320, before the four-inch margin

// The two Excellent title glyphs (texResultBg sprite 9) slide in from the sides; their Y is the
// four-inch button margin plus a per-side offset, else a fixed default.
static const NSUInteger kExcTitleSprite = 9;
static const float kExcTitleSlideFrom = 48.0f;      // @ghidraAddress 0x28f8f4
static const double kExcTitleXOffset = 120.0;       // @ghidraAddress 0x28f210
static const double kExcTitleGlyphNudge = -24.0;    // fmov, -24.0
static const double kExcTitleLeftYDefault = 280.0;  // @ghidraAddress 0x28f658
static const double kExcTitleRightYDefault = 360.0; // @ghidraAddress 0x292918
static const int kExcTitleLeftY4Inch = 0x118;       // 280
static const int kExcTitleRightY4Inch = 0x168;      // 360
static const double kExcTitleRightBaseX = 40.0;     // @ghidraAddress 0x28f1f8
static const NSUInteger kExcPanelSprite = 0xb;
static const NSUInteger kExcWordSprite = 0x1a;
static const float kExcWordScale = 1.04f; // @ghidraAddress 0x292b38
// The Excellent word (texFront sprite 0x1a) flies in as four glyph pairs over frames 0x60..0x74.
static const float kExcWordScatterY = -160.0f;      // @ghidraAddress 0x2926d8
static const float kExcWord1Target = 40.0f;         // @ghidraAddress 0x292568
static const float kExcWord1From = 360.0f;          // @ghidraAddress 0x292418
static const float kExcWord1XOffset = -62.4f;       // @ghidraAddress 0x2934bc
static const float kExcWord1YOffset = 25.7f;        // @ghidraAddress 0x2934c0
static const float kExcWord2From = 200.0f;          // @ghidraAddress 0x292b24
static const float kExcWord2YFrom = -80.0f;         // @ghidraAddress 0x28f468
static const float kExcWord3YFrom = 160.0f;         // @ghidraAddress 0x28f438
static const float kExcWord3XOffset = -38.7f;       // @ghidraAddress 0x2934cc
static const float kExcWord3YOffset = 2.4f;         // @ghidraAddress 0x2934d0
static const float kExcWord3Scale = 0.507f;         // @ghidraAddress 0x2934d4
static const float kExcWord4From = -120.0f;         // @ghidraAddress 0x2934d8
static const float kExcWord5XOffset = -16.2f;       // @ghidraAddress 0x2934dc
static const float kExcWord5YOffset = 26.6f;        // @ghidraAddress 0x2934e0
static const float kExcWord5Scale = 0.78f;          // @ghidraAddress 0x2934e4
static const float kExcWord3XFrom = -280.0f;        // @ghidraAddress 0x2934c8
static const double kExcWordTitleXOffset = -24.0;   // fmov, -24.0
static const double kExcTitleGlyphSpacing = 166.0;  // @ghidraAddress 0x29275c
static const int kExcTitleGlyphSpacing4Inch = 0xa6; // 166
static const NSUInteger kExcRatingFrame = 0x14;
static const NSUInteger kExcPanelFrame = 0x28;
static const NSUInteger kExcStringFrame0 = 0x60;
static const NSUInteger kExcStringFrame1 = 0x67;
static const NSUInteger kExcStringFrame2 = 0x6e;
static const NSUInteger kExcVoiceFrame = 0x7c;
static NSString *const kSeExcRating = @"SD_KNT_CV_RATING";   // @ghidraAddress 0x2df8a0
static NSString *const kSeExcPanel = @"SD_KNT_EXC_PANEL";    // @ghidraAddress 0x2df8c0
static NSString *const kSeExcString = @"SD_KNT_EXC_STRING";  // @ghidraAddress 0x2df8e0
static NSString *const kSeExcResult = @"SD_KNT_RESULT_EXC";  // @ghidraAddress 0x2df900
static NSString *const kSeExcVoice = @"SD_KNT_CV_EXCELLENT"; // @ghidraAddress 0x2df920

// The Excellent burst: twenty particles, the last five sweeping outward with an offset trail.
static inline void MainGameRendererPhoneKntRenderExcellentBurst(MainGameRendererPhoneKnt *self,
                                                                BOOL is4Inch,
                                                                unsigned int frame) {
    static const float kExcFlourishRiseFrom = -86.0f; // @ghidraAddress 0x2934e8
    static const float kExcFlourishSweep = 640.0f;    // @ghidraAddress 0x2934ec
    static const float kExcTrailXScale = -1.02f;      // @ghidraAddress 0x2934f0
    int margin = is4Inch ? [self buttonMarginForScreen40] : 0;
    float titleSpacing = is4Inch ?
                             (float)([self buttonMarginForScreen40] + kExcTitleGlyphSpacing4Inch) :
                             (float)kExcTitleGlyphSpacing;
    float rise =
        InterpolateFloatByFrame(kExcFlourishRiseFrom, 0.0f, frame, 0x7c, 0x80) + kExcParticleYBias;
    if (frame > 0x7f) {
        rise -= (float)((int)(frame * 2) - 0x100);
        if (rise < 0.0f) {
            rise = 0.0f;
        }
    }
    float sweep = InterpolateFloatByFrame(kExcFlourishSweep, 0.0f, frame, 0x7c, 0x86);
    float threshold = (float)(margin + kExcSweepThresholdBase);
    for (int i = 0; i < kExcParticleCount; ++i) {
        float x = kExcParticleX[i];
        float y = titleSpacing + kExcParticleY[i];
        if (i < kExcSweepParticleFirst) {
            y = (y >= threshold) ? y - rise : rise + y;
        }
        x = x + kExcParticleYBias; // Yes, the binary adds the 6.0 bias to x here.
        if ((unsigned int)(i - kExcSweepParticleFirst) < 5) {
            float dir = (y >= threshold) ? -1.0f : 1.0f;
            x = x + sweep * dir;
            y = y - sweep * 0.5f * dir;
            if (frame > 0x8c) {
                int ripple = ((((i << 2) ^ -1) & 4) - 2) * ((int)(frame - 0x8c) % 0x14);
                x = (float)(ripple * 2) + x;
                y = y + (float)ripple * kExcTrailXScale;
            }
            for (int step = -4; step <= 4; ++step) {
                if (step == 0) {
                    continue;
                }
                double sx = (double)(x + (float)step * kExcParticleTrailStep);
                double sy = (double)(y + (float)step * kExcParticleTrailStep * -0.5f *
                                             kExcParticleTrailYScale);
                [self.texResultBg drawSprite:(NSUInteger)kExcParticleSprite[i]
                                     atPoint:CGPointMake(sx, sy)
                                       scale:kExcParticleScale[i]
                                      rotate:kExcParticleRotate
                                      anchor:CGPointMake(sx, sy)
                                   transform:0
                                       alpha:1.0f];
            }
        }
        [self.texResultBg drawSprite:(NSUInteger)kExcParticleSprite[i]
                             atPoint:CGPointMake((double)x, (double)y)
                               scale:kExcParticleScale[i]
                              rotate:kExcParticleRotate
                              anchor:CGPointMake((double)x, (double)y)
                           transform:0
                               alpha:1.0f];
    }
}

@implementation MainGameRendererPhoneKnt

/** @ghidraAddress 0x189460 */
- (instancetype)init {
    self = [super init];
    if (self) {
        isRetina = JubeatAppDelegate.appDelegate.isPhoneRetina;
        is4Inch = JubeatAppDelegate.appDelegate.is4inchAspect;
        self.arrayBgEff = [[NSMutableArray alloc] init];
        self.upperBgKnt = [[UpperBGKnit alloc] init];
        // The knit background fills the 320-point width; its height and resting wave baseline are
        // pushed down on the four-inch phone. The wave top and pulse height are fixed.
        double bgHeight = kUpperBGKnitHeightDefault;
        float baseline = kUpperBGKnitBaselineDefault;
        if (is4Inch) {
            bgHeight = (double)(int)(self.buttonMarginForScreen40 + kFourInchGameTop);
            if (is4Inch) {
                baseline = (float)((int)(self.upperBgHeight40 / 3) + kFourInchBaselineBias);
            }
        }
        [self.upperBgKnt initBg:CGRectMake(0.0, 0.0, kUpperBGKnitWidth, bgHeight)
                     waveBottom:baseline
                        waveTop:kUpperBGKnitWaveTop
                    pulseHeight:kUpperBGKnitPulseHeight
                          isPad:NO];
    }
    return self;
}

/** @ghidraAddress 0x18c118 */
- (void)startPlay {
    [self setState:MainGamePhoneKntStatePlaying];
    self.sePlayerGo = nil;
}

/** @ghidraAddress 0x18c154 */
- (void)endResult {
    if (self.state == MainGamePhoneKntStateResult) {
        self.subState = kMainGamePhoneKntEndSubState;
    }
}

/** @ghidraAddress 0x193854 */
- (void)replayEnd {
    self.replayPlaying = NO;
}

/** @ghidraAddress 0x193864 */
- (void)replaySelect {
    if (!self.isCustom || !self.isDownload || !self.hasMusic) {
        return;
    }
    self.replayPlaying = YES;
    // Swap the front atlas's sprite 3 to the knit replay chip: turn scale-2x off for the blit, then
    // back on.
    self.texFront.isScale2x = NO;
    LoadTextureSubImageFromResource(
        self.texFront, kReplayChipResource, [self.texFront spriteAtIndex:3].origin);
    self.texFront.isScale2x = YES;
    self.isTextureChange = NO;
    __weak UIImageView *goodJobImage = self.goodJobImage;
    [UIView animateWithDuration:kReplayFadeDuration
                     animations:^{
                       /** @ghidraAddress 0x193a88 */
                       goodJobImage.alpha = 0.0;
                     }
                     completion:^(BOOL finished){
                         /** @ghidraAddress 0x193ad4 */
                     }];
}

#pragma mark - Layout override points

/** @ghidraAddress 0x1922a8 */
- (double)buttonAreaOffset {
    return 0.0;
}

/** @ghidraAddress 0x1922b0 */
- (double)gameAreaOffset {
    if (is4Inch) {
        return (double)(self.buttonMarginForScreen40 + kFourInchGameTop);
    }
    return kGameAreaOffsetDefault;
}

#pragma mark - Button override points

/** @ghidraAddress 0x1922f0 */
- (unsigned int)endButtonID {
    return 15;
}

/** @ghidraAddress 0x1922f8 */
- (unsigned int)evaluateButtonID {
    return 14;
}

/** @ghidraAddress 0x192300 */
- (unsigned int)goodJobButtonID {
    return 13;
}

/** @ghidraAddress 0x192308 */
- (CGPoint)goodJobPosition {
    unsigned int button = self.goodJobButtonID;
    int gameTop = is4Inch ? (self.buttonMarginForScreen40 + kFourInchGameTop) : kFourInchGameTop;
    double x = (double)((button & 3) * kButtonGridPitch + kButtonGridInset);
    double y = (double)((button >> 2) * kButtonGridPitch + kButtonGridInset + gameTop);
    return CGPointMake(x, y);
}

/** @ghidraAddress 0x1923a8 */
- (unsigned int)twitterSendButtonID {
    return 14;
}

/** @ghidraAddress 0x1923b0 */
- (CGPoint)twitterBtnPosition {
    unsigned int button = self.twitterSendButtonID;
    int gameTop = is4Inch ? (self.buttonMarginForScreen40 + kFourInchGameTop) : kFourInchGameTop;
    double x = (double)((button & 3) * kButtonGridPitch + kButtonGridInset);
    double y = (double)((button >> 2) * kButtonGridPitch + kButtonGridInset + gameTop);
    return CGPointMake(x, y);
}

/** @ghidraAddress 0x192450 */
- (unsigned int)storeMoveButtonID {
    return 14;
}

/** @ghidraAddress 0x192458 */
- (CGPoint)storeMoveBtnPosition {
    unsigned int button = self.storeMoveButtonID;
    int gameTop = is4Inch ? (self.buttonMarginForScreen40 + kFourInchGameTop) : kFourInchGameTop;
    double x = (double)((button & 3) * kButtonGridPitch + kButtonGridInset);
    double y = (double)((button >> 2) * kButtonGridPitch + kButtonGridInset + gameTop);
    return CGPointMake(x, y);
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x18f3cc */
- (double)durationOfReadyGo {
    return 2.5;
}

/** @ghidraAddress 0x193804 */
- (void)dealloc {
    [self releaseTexture];
    // The superclass dealloc runs after; ARC synthesises .cxx_destruct for the strong properties.
}

/** @ghidraAddress 0x18bdf4 */
- (void)setState:(unsigned int)state {
    if (state == MainGamePhoneKntResetStateZero) {
        lastCombo = 0;
        comboCutFrame = 0;
        comboEffectFrame = 0;
        scoreDisplay = 0;
        shutterOpen = 0.0f;
        lastHakuPhase = 0.0f;
    } else if (state == MainGamePhoneKntResetStateTwo) {
        lastCombo = 0;
        comboCutFrame = 0;
        comboEffectFrame = 0;
        scoreDisplay = 0;
        shutterOpen = 0.0f;
        startMarkFrame = 0;
        // The ready state primes the player "go" voice so it can be triggered mid-countdown.
        if (!self.sePlayerGo) {
            NSString *path = [NSBundle.mainBundle pathForResource:kPlayerGoResource ofType:@"caf"];
            AVAudioPlayer *player =
                [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                       error:nil];
            self.sePlayerGo = player;
            [self.sePlayerGo prepareToPlay];
        }
    } else if (state == MainGamePhoneKntStateResultA) {
        [AudioManager.sharedManager loadBgmResAAC:kResultBgmResource inDirectory:nil];
        [AudioManager.sharedManager startBgm:YES fadeTime:0.0];
    }
    // The second result sub-screen (6) preserves the frame counter; every other state resets it.
    if (state != MainGamePhoneKntStateResultB) {
        frame = 0;
    }
    [super setState:state];
}

/** @ghidraAddress 0x18b76c */
- (void)loadResultTex:(short)rank {
    // The rank rating overlays blitted into the result-background atlas, indexed by rank 0..7. A
    // rank of 8 or more draws no overlay. @ghidraAddress 0x2df700
    static NSString *const kRankOverlayNames[] = {
        @"res_rtg_e_knt",
        @"res_rtg_d_knt",
        @"res_rtg_c_knt",
        @"res_rtg_b_knt",
        @"res_rtg_a_knt",
        @"res_rtg_s_knt",
        @"res_rtg_ss_knt",
        @"res_rtg_sss_knt",
    };
    if (self.texResultBg) {
        self.texResultBg = nil;
    }
    BFCodec *codec = [[BFCodec alloc] init];
    NSData *cipherKey = CreateTextureCipherKey();
    if (isRetina) {
        self.texResultBg = [[Texture2D alloc] initWithData:nullptr
                                               pixelFormat:Texture2DPixelFormatRGBA8888
                                                 pixelSize:kResultBgPixelSizeRetina];
        NSString *plist = [NSBundle.mainBundle pathForResource:@"game_result_knt_tex_pn2"
                                                        ofType:@"plist"];
        [self.texResultBg setSprites:[[NSArray alloc] initWithContentsOfFile:plist]];
        [codec cipherInit:cipherKey];
        LoadTextureSubImageFromEncryptedTex(
            self.texResultBg, @"game_result_knt_tex_1_pn2", codec, CGPointMake(0.0, 0.0));
        self.texResultBg.isScale2x = isRetina;
    } else {
        self.texResultBg = [[Texture2D alloc] initWithData:nullptr
                                               pixelFormat:Texture2DPixelFormatRGBA8888
                                                 pixelSize:kResultBgPixelSize];
        NSString *plist = [NSBundle.mainBundle pathForResource:@"game_result_knt_tex_pn"
                                                        ofType:@"plist"];
        [self.texResultBg setSprites:[[NSArray alloc] initWithContentsOfFile:plist]];
        [codec cipherInit:cipherKey];
        LoadTextureSubImageFromEncryptedTex(
            self.texResultBg, @"game_result_knt_tex_1_pn", codec, CGPointMake(0.0, 0.0));
    }
    if (rank < kRatingRankCount) {
        // An 8-way jump table picks the rank overlay name; every arm falls to this common blit.
        NSString *path = [NSBundle.mainBundle pathForResource:kRankOverlayNames[rank]
                                                       ofType:@"png"];
        if (path) {
            UIImage *overlay = [[UIImage alloc] initWithContentsOfFile:path];
            [self.texResultBg setSubImage:overlay inRect:[self.texResultBg spriteAtIndex:0]];
        }
    }
}

/** @ghidraAddress 0x18bce8 */
- (void)releaseTexture {
    self.texDebugFont = nil;
    self.texReady0 = nil;
    self.texReady1 = nil;
    self.texFront = nil;
    self.texResultBg = nil;
    self.texBeatBg = nil;
    if (self.texWaveAr) {
        [self.texWaveAr removeAllObjects];
        self.texWaveAr = nil;
    }
    // Note: texMarker, texHoldMarker, and texCombo are deliberately not released here, matching the
    // binary.
}

/** @ghidraAddress 0x18ef18 */
- (void)renderButtons {
    MainGameRendererPhoneKntDrawButtonGrid(self, self->is4Inch);
}

/** @ghidraAddress 0x193214 */
- (void)draw {
    switch (self.state) {
    case MainGamePhoneKntStatePreStart:
        [self renderPreStart];
        break;
    case MainGamePhoneKntStateReady:
        [self renderBG];
        [self renderShutter:YES];
        [self renderUpperBG:NO];
        [self renderUpper];
        [self renderStartMark:1.0f];
        [self renderButtons];
        [self renderReadyGo];
        break;
    case MainGamePhoneKntStatePlay:
        [self renderBG];
        [self renderShutter:YES];
        [self renderCombo:(unsigned int)self.sequence.getScore->curCombo alpha:1.0f];
        [self renderUpperBG:NO];
        [self renderUpper];
        [self renderMarker];
        [self renderButtons];
        break;
    case MainGamePhoneKntStateFinish:
        [self renderBG];
        [self renderShutter:YES];
        [self renderCombo:(unsigned int)self.sequence.getScore->curCombo alpha:1.0f];
        [self renderUpperBG:NO];
        [self renderUpper];
        [self renderMarker];
        [self renderButtons];
        [self renderFinish];
        break;
    case MainGamePhoneKntStateResultA:
    case MainGamePhoneKntStateResultB:
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
    [self.texBeatBg commitDraw];
    [self.texResultBg commitDraw];
    [self.upperBgKnt commitBg:self.texWaveAr];
    [self.texCombo commitDraw];
    [self.texHoldMarker commitDraw];
    [self.texMarker commitDraw];
    [self.texFront commitDraw];
    [self.texReady0 commitDraw];
    [self.texReady1 commitDraw];
    ++frame;
}

/** @ghidraAddress 0x19369c */
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
            y += kDebugLineHeight;
            ++i;
            x = pos.x;
            continue;
        }
        if (c <= ' ' || c == '\x7f') {
            ++i;
            x += kDebugGlyphAdvance;
            continue;
        }
        [self.texDebugFont drawSprite:(NSUInteger)((long)c - 0x20)
                              atPoint:CGPointMake(x, y)
                            transform:0
                                alpha:alpha];
        ++drawn;
        ++i;
        x += kDebugGlyphAdvance;
        if (drawn >= kDebugMaxGlyphs) {
            break;
        }
    }
    if (drawn != 0) {
        [self.texDebugFont commitDraw];
    }
}

/** @ghidraAddress 0x189680 */
- (void)loadTexure:(RendererConf *)conf artwork:(UIImage *)artwork index:(UIImage *)index {
    NSData *cipherKey = CreateTextureCipherKey();
    BFCodec *codec = [[BFCodec alloc] init];
    if (!self.texDebugFont) {
        self.texDebugFont = CreateTexture2DFromPngResource(@"debugfont");
    }
    if (!self.texWaveAr) {
        MainGameRendererPhoneKntBuildWaveTextures(self, codec, cipherKey);
    }
    if (!self.texBeatBg) {
        MainGameRendererPhoneKntBuildBeatBgTexture(self, self->isRetina, codec, cipherKey);
    }
    if (!self.texReady0) {
        [codec cipherInit:cipherKey];
        // Retina uses the bare name; non-retina uses the "_pn" variant.
        NSString *name = self->isRetina ? @"game_ready_knt_0_tex" : @"game_ready_knt_0_tex_pn";
        self.texReady0 = CreateTexture2DFromEncryptedTexResource(name, codec);
        self.texReady0.isScale2x = self->isRetina;
    }
    if (!self.texReady1) {
        [codec cipherInit:cipherKey];
        NSString *name = self->isRetina ? @"game_ready_knt_1_tex" : @"game_ready_knt_1_tex_pn";
        self.texReady1 = CreateTexture2DFromEncryptedTexResource(name, codec);
        self.texReady1.isScale2x = self->isRetina;
    }
    if (conf.diff > kMaxDifficulty) {
        conf.diff = kMaxDifficulty;
    }
    if (conf.level > kMaxLevel) {
        conf.level = kMaxLevel;
    }
    // The front atlas is rebuilt unless the requested marker, difficulty, level, and tune all
    // match the one already loaded.
    if (self.texFront && [conf.markerID isEqualToString:self.rendererConf.markerID] &&
        conf.diff == self.rendererConf.diff && conf.level == self.rendererConf.level &&
        conf.tuneID == self.rendererConf.tuneID) {
        return;
    }
    if (self.texFront) {
        self.texFront = nil;
    }
    MainGameRendererPhoneKntBuildFrontTexture(self, conf, codec, cipherKey);
    MainGameRendererPhoneKntLoadMarkerTexture(self, self->isRetina, conf, codec, cipherKey);
    MainGameRendererPhoneKntBuildHoldMarkerTexture(
        self, &self->holdMarkerRender, self->is4Inch, codec, cipherKey);
    MainGameRendererPhoneKntCompositeFront(self, self->isRetina, conf, artwork, index);
    MainGameRendererPhoneKntBuildComboTexture(self, self->isRetina, codec, cipherKey);
    self.rendererConf = conf;
}

/** @ghidraAddress 0x18c1a0 */
- (void)drawClip:(int)clip
    drawPosition:(CGPoint)drawPosition
        drawArea:(CGRect)drawArea
           alpha:(float)alpha {
    // The full sprite rectangle in texels: its origin is the source texel origin, its size the
    // drawn size on screen at drawPosition.
    CGRect sprite = [self.texFront spriteAtIndex:(unsigned int)clip];
    double spriteU = sprite.origin.x;
    double spriteV = sprite.origin.y;
    double spriteW = sprite.size.width;
    double spriteH = sprite.size.height;

    double posX = drawPosition.x;
    double posY = drawPosition.y;

    // The clip area is compared at single precision (the binary rounds it through floats).
    double areaX = (double)(float)drawArea.origin.x;
    double areaY = (double)(float)drawArea.origin.y;
    double areaRight = (double)(float)(drawArea.size.width + areaX);
    double areaBottom = (double)(float)(drawArea.size.height + areaY);

    // Reject unless the sprite drawn at drawPosition overlaps the clip area on both axes.
    if (!(posX + spriteW >= areaX && posX <= areaRight && posY + spriteH >= areaY &&
          posY <= areaBottom)) {
        return;
    }

    // Trim the horizontal axis: when the draw origin is left of the area, advance the destination
    // origin, shrink the width, and slide the source U to match; then clamp the right edge.
    double destX = posX;
    double srcU = spriteU;
    double horizWidth = spriteW;
    if (posX < areaX) {
        destX = areaX;
        horizWidth = spriteW - (areaX - posX);
        srcU = spriteU + (areaX - posX);
    }
    double finalWidth = horizWidth;
    if (horizWidth + destX > areaRight) {
        finalWidth = horizWidth - ((horizWidth + destX) - areaRight);
    }

    // Trim the vertical axis. As in the edit renderer, the binary subtracts the top-clip amount
    // from the *width*, not the height, and starts the height from the full sprite height.
    double destY = posY;
    double srcV = spriteV;
    double width = finalWidth;
    if (posY < areaY) {
        destY = areaY;
        width = finalWidth - (areaY - posY); // Yes, the binary trims width by the vertical clip.
        srcV = spriteV + (areaY - posY);
    }
    double height = spriteH;
    if (spriteH + destY > areaBottom) {
        height = spriteH - ((spriteH + destY) - areaBottom);
    }

    // The knit renderer's atlas is stored at 2x on a retina phone, so the source region is doubled
    // to address the high-resolution texels.
    double srcX = srcU;
    double srcY = srcV;
    double srcW = width;
    double srcH = height;
    if (isRetina) {
        srcX = srcU + srcU;
        srcY = srcV + srcV;
        srcW = width + width;
        srcH = height + height;
    }

    [self.texFront drawInRect:CGRectMake(destX, destY, width, height)
                   fromRegion:CGRectMake(srcX, srcY, srcW, srcH)
                    transform:0
                        alpha:alpha];
}

/** @ghidraAddress 0x18caf0 */
- (void)renderBG {
    static const MainGamePhoneKntBgEffectSpec kBgEffectSchedule[] = {
        {0, 0, 8, 86, 0, 100, 20},
        {0, 5, 158, 480, 15, 50, 0},
        // The remaining schedule entries are read live from the pool at 0x2935c0.
    };
    static const double kFieldWidth = 320.0;           // @ghidraAddress 0x28f470
    static const float kFillMirror = -320.0f;          // @ghidraAddress 0x2934a8
    static const float kTensionPosLo = 0.6060606f;     // @ghidraAddress 0x292ab4
    static const float kTensionPosHi = 1.1f;           // @ghidraAddress 0x292ab8
    static const float kBeatScale = 320.0f;            // @ghidraAddress 0x292734
    static const float kBeatScaleUnit = 1.0f / 256.0f; // @ghidraAddress 0x292a90
    static const double kBeatY = 192.0;                // @ghidraAddress 0x28fa00
    static const float kBeatY4Inch = 32.0f;            // @ghidraAddress 0x292f90
    static const double kBeatAnchorX = 32.0;           // @ghidraAddress 0x28f458
    static const double kBeatAnchorY = 160.0;          // @ghidraAddress 0x28f438
    static const float kTensionRate = 1.0f / 1024.0f;  // @ghidraAddress 0x292540
    static const int kFieldBottom = 0x238;             // 568
    static const int kGridTopOffset = 0xa0;            // 160
    static const int kBgEffectSlotCount = 0x1b;        // 27

    // On the four-inch screen the field is taller, so the header/footer gap is filled with the
    // background sprite (sprite 0x17) twice, mirrored.
    if (self.is4Inch) {
        int gap = [self buttonMarginForScreen40] - [self upperBgHeight40];
        [self.texFront
            drawSprite:0x17
                inRect:CGRectMake((double)(kFieldBottom - gap), kFieldWidth, (double)gap, 0.0)];
        [self.texFront drawSprite:0x17
                           inRect:CGRectMake((double)(((float)(kFieldBottom - gap) - (float)gap) +
                                                      kFillMirror),
                                             kFieldWidth,
                                             (double)gap,
                                             0.0)];
    }

    const ScoreData *score = nil;
    float tensionPos = 0.0f;
    if (self.sequence != nil) {
        if (self.scoreBackup) {
            return;
        }
        score = self.sequence.getScore;
        tensionPos = self.sequence.hakuPhase;
    }
    // A position-interpolated pulse: the beat energy ramps once the phase passes 0.606.
    float pulse;
    if (tensionPos >= kTensionPosLo) {
        pulse = InterpolateFloatByPosition(tensionPos, kTensionPosLo, 1.0f, kTensionPosHi, 1.0f);
    } else {
        pulse = InterpolateFloatByPosition(tensionPos, 0.0f, kTensionPosLo, kTensionPosHi, 1.0f);
    }

    // The two beat-background layers (sprites 9 and 10), pulsed on the beat.
    float beatScale = pulse * kBeatScale * kBeatScaleUnit;
    double beatY = kBeatY;
    double anchorY = kFieldWidth;
    if (self.is4Inch) {
        beatY = (double)((float)([self buttonMarginForScreen40] + kGridTopOffset) + kBeatY4Inch);
        anchorY = (double)([self buttonMarginForScreen40] + 0x140);
    }
    [self.texBeatBg drawSprite:9
                       atPoint:CGPointMake(kBeatAnchorX, beatY)
                         scale:beatScale
                        rotate:0
                        anchor:CGPointMake(kBeatAnchorY, anchorY)
                     transform:1
                         alpha:1.0f];

    float tensionFrame = 0.0f;
    if (score != nil) {
        tensionFrame = (float)score->tension * 10.0f * kTensionRate;
    }
    float layer2Alpha = InterpolateFloatByFrame(0.0f, 1.0f, (int)tensionFrame, 7, 10);
    [self.texBeatBg drawSprite:10
                       atPoint:CGPointMake(kBeatAnchorX, beatY)
                         scale:beatScale
                        rotate:0
                        anchor:CGPointMake(kBeatAnchorY, anchorY)
                     transform:layer2Alpha
                         alpha:10];

    // Spawn and advance the knit background effects while the beat energy is high.
    if (tensionFrame <= 9.0f) {
        effFrame = 0;
    } else {
        int topOffset =
            self.is4Inch ? [self buttonMarginForScreen40] + kGridTopOffset : kGridTopOffset;
        const MainGamePhoneKntBgEffectSpec *spec = &kBgEffectSchedule[effSlot];
        if ((unsigned int)spec->threshold < effFrame) {
            EffectBgKnit *eff = [[EffectBgKnit alloc] init];
            [eff init:self.texBeatBg
                 effType:spec->effType
                startPos:CGPointMake((double)spec->startX, (double)(spec->startY + topOffset))
                    wmin:spec->wmin
                    wmax:spec->wmax
                    move:spec->move];
            [self.arrayBgEff addObject:eff];
            ++effSlot;
            if (effSlot > (unsigned int)kBgEffectSlotCount) {
                effSlot = 0;
                effFrame = 0;
            }
        }
        ++effFrame;
    }

    // Render every live effect, culling those that report themselves finished.
    NSInteger count = self.arrayBgEff.count;
    for (int i = 0; i < count; ++i) {
        if ([[self.arrayBgEff objectAtIndex:i] renderEffect] != 0) {
            [self.arrayBgEff removeObjectAtIndex:i];
            --i;
            --count;
        }
    }
}

/** @ghidraAddress 0x190674 */
- (BOOL)renderExcellent:(unsigned int)frame {
    switch (frame) {
    case kExcRatingFrame:
        [[AudioManager sharedManager] playSeResFile:kSeExcRating inDirectory:nil];
        break;
    case kExcPanelFrame:
        [[AudioManager sharedManager] playSeResFile:kSeExcPanel inDirectory:nil];
        break;
    case kExcStringFrame0:
    case kExcStringFrame1:
    case kExcStringFrame2:
        [[AudioManager sharedManager] playSeResFile:kSeExcString inDirectory:nil];
        break;
    case kExcVoiceFrame:
        [[AudioManager sharedManager] playSeResFile:kSeExcResult inDirectory:nil];
        [[AudioManager sharedManager] playSeResFile:kSeExcVoice inDirectory:nil];
        break;
    default:
        break;
    }

    // The two title glyphs slide in from the sides and fade in over frames 0..8, fading out after
    // frame 40. Each side's Y is the four-inch button margin plus an offset, else a default.
    float titleSlide = InterpolateFloatByFrame(kExcTitleSlideFrom, 0.0f, frame, 0, 8);
    float titleAlpha = InterpolateFloatByFrame(0.0f, 1.0f, frame, 0, 8);
    if (frame > kExcPanelFrame) {
        titleAlpha = InterpolateFloatByFrame(1.0f, 0.0f, frame, 0x28, 0x32);
    }
    double titleH = [self.texResultBg spriteAtIndex:kExcTitleSprite].size.height;
    double leftY = self->is4Inch ? (double)([self buttonMarginForScreen40] + kExcTitleLeftY4Inch) :
                                   kExcTitleLeftYDefault;
    [self.texResultBg
        drawSprite:kExcTitleSprite
           atPoint:CGPointMake((double)titleSlide + kExcTitleXOffset + kExcTitleGlyphNudge,
                               leftY - titleH * 0.5)
         transform:0
             alpha:titleAlpha];
    double rightY = self->is4Inch ?
                        (double)([self buttonMarginForScreen40] + kExcTitleRightY4Inch) :
                        kExcTitleRightYDefault;
    [self.texResultBg
        drawSprite:kExcTitleSprite
           atPoint:CGPointMake((kExcTitleRightBaseX - (double)titleSlide) + kExcTitleGlyphNudge,
                               rightY - titleH * 0.5)
         transform:0
             alpha:titleAlpha];

    // The eight excellent panels fill the grid rows as the frame passes each.
    for (int i = 0; i < 16; i += 2) {
        if (i / 2 > (int)(frame - kExcPanelFrame)) {
            continue;
        }
        int panel = kExcPanelOrder[i / 2];
        int margin = self->is4Inch ? [self buttonMarginForScreen40] : 0;
        double px = (double)((panel % 4) * kExcPanelPitch | kExcPanelInset) + kExcPanelHalf;
        double py = (double)(((panel >> 2) * kExcPanelPitch | kExcPanelInset) + margin +
                             kExcPanelGridTopY) +
                    kExcPanelHalf;
        [self.texResultBg drawSprite:kExcPanelSprite
                              inRect:CGRectMake(px, py, kExcPanelSpread, kExcPanelSpread)];
    }

    // The Excellent word flies in as glyph pairs across frames 0x60..0x74.
    if (frame >= kExcStringFrame0) {
        double base1 = self->is4Inch ?
                           (double)([self buttonMarginForScreen40] + kExcTitleRightY4Inch) :
                           kExcTitleRightYDefault;
        float g1x = InterpolateFloatByFrame(kExcWord1From, kExcWord1Target, frame, 0x60, 0x67) +
                    kExcWord1XOffset;
        float g1y = InterpolateFloatByFrame(
                        (float)(base1 + kExcWordScatterY), (float)base1, frame, 0x60, 0x67) +
                    kExcWord1YOffset;
        [self.texFront drawSprite:kExcWordSprite
                          atPoint:CGPointMake((double)g1x, (double)g1y)
                            scale:kExcWordScale
                           rotate:kExcParticleRotate
                           anchor:CGPointMake((double)g1x, (double)g1y)
                        transform:0
                            alpha:1.0f];
        float g2x = InterpolateFloatByFrame(kExcWord2From, kExcWord1Target, frame, 0x60, 0x67) +
                    kExcWord1XOffset;
        float g2y = InterpolateFloatByFrame(
                        (float)(base1 + kExcWord2YFrom), (float)base1, frame, 0x60, 0x67) +
                    kExcWord1YOffset;
        float g2a = InterpolateFloatByFrame(0.0f, 0.5f, frame - 0x60, 0, 4);
        [self.texFront drawSprite:kExcWordSprite
                          atPoint:CGPointMake((double)g2x, (double)g2y)
                            scale:kExcWordScale
                           rotate:kExcParticleRotate
                           anchor:CGPointMake((double)g2x, (double)g2y)
                        transform:0
                            alpha:g2a];
        if (frame > kExcStringFrame1) {
            double base2 = self->is4Inch ?
                               (double)([self buttonMarginForScreen40] + kExcTitleLeftY4Inch) :
                               kExcTitleLeftYDefault;
            float g3x =
                InterpolateFloatByFrame(kExcWord3XFrom, kExcWord1Target, frame, 0x67, 0x6e) +
                kExcWord3XOffset;
            float g3y = InterpolateFloatByFrame(
                            (float)(base2 + kExcWord3YFrom), (float)base2, frame, 0x67, 0x6e) +
                        kExcWord3YOffset;
            [self.texFront drawSprite:kExcWordSprite
                              atPoint:CGPointMake((double)g3x, (double)g3y)
                                scale:kExcWord3Scale
                               rotate:kExcParticleRotate
                               anchor:CGPointMake((double)g3x, (double)g3y)
                            transform:0
                                alpha:1.0f];
            float g4x = InterpolateFloatByFrame(kExcWord4From, kExcWord1Target, frame, 0x67, 0x6e) +
                        kExcWord3XOffset;
            float g4y = InterpolateFloatByFrame(
                            (float)(base2 + kExcTitleXOffset), (float)base2, frame, 0x67, 0x6e) +
                        kExcWord3YOffset;
            float g4a = InterpolateFloatByFrame(0.0f, 0.5f, frame - 0x67, 0, 4);
            [self.texFront drawSprite:kExcWordSprite
                              atPoint:CGPointMake((double)g4x, (double)g4y)
                                scale:kExcWord3Scale
                               rotate:kExcParticleRotate
                               anchor:CGPointMake((double)g4x, (double)g4y)
                            transform:0
                                alpha:g4a];
            if (frame > kExcStringFrame2) {
                double base3 = self->is4Inch ?
                                   (double)([self buttonMarginForScreen40] + kExcTitleLeftY4Inch) :
                                   kExcTitleLeftYDefault;
                float g5x =
                    InterpolateFloatByFrame(kExcWord1From, kExcWord1Target, frame, 0x6e, 0x75) +
                    kExcWord5XOffset;
                float g5y =
                    InterpolateFloatByFrame(
                        (float)(base3 + kExcWordScatterY), (float)base3, frame, 0x6e, 0x75) +
                    kExcWord5YOffset;
                [self.texFront drawSprite:kExcWordSprite
                                  atPoint:CGPointMake((double)g5x, (double)g5y)
                                    scale:kExcWord5Scale
                                   rotate:kExcParticleRotate
                                   anchor:CGPointMake((double)g5x, (double)g5y)
                                transform:0
                                    alpha:1.0f];
                float g6x =
                    InterpolateFloatByFrame(kExcWord2From, kExcWord1Target, frame, 0x6e, 0x75) +
                    kExcWord5XOffset;
                float g6y = InterpolateFloatByFrame(
                                (float)(base3 + kExcWord2YFrom), (float)base3, frame, 0x6e, 0x75) +
                            kExcWord5YOffset;
                float g6a = InterpolateFloatByFrame(0.0f, 0.5f, frame - 0x6e, 0, 4);
                [self.texFront drawSprite:kExcWordSprite
                                  atPoint:CGPointMake((double)g6x, (double)g6y)
                                    scale:kExcWord5Scale
                                   rotate:kExcParticleRotate
                                   anchor:CGPointMake((double)g6x, (double)g6y)
                                transform:0
                                    alpha:g6a];
            }
        }
    }
    if (frame > 0x7b) {
        MainGameRendererPhoneKntRenderExcellentBurst(self, self->is4Inch, frame);
    }
    return frame > 0x95;
}

/** @ghidraAddress 0x1917fc */
- (BOOL)renderCleared:(unsigned int)frame {
    static const float kBannerTopFrom = 280.0f; // @ghidraAddress 0x2934f8
    static const float kBannerTopTo = 200.0f;   // @ghidraAddress 0x292b24
    static const float kBannerMidTo = 440.0f;   // @ghidraAddress 0x292b2c
    static const double kFieldWidth = 768.0;    // @ghidraAddress 0x292460
    static const double kBannerMidW = 576.0;    // @ghidraAddress 0x291d88
    static const double kBannerBoxW = 192.0;    // @ghidraAddress 0x28fa00
    static const double kWordBaseY = 280.0;     // @ghidraAddress 0x28f658
    static const double kWordAnchorX = 160.0;   // @ghidraAddress 0x28f438
    static const int kPanelPitch = 0x50;
    static const int kPanelInset = 0x28;
    static const int kGridTop = 200;
    static const NSString *const kSeResultClear = @"SD_KNT_RESULT_CLEAR"; // @ghidraAddress 0x2df940
    static const NSString *const kSeVoiceClear = @"SD_KNT_CV_CLEAR";      // @ghidraAddress 0x2df960

    float fadeIn = InterpolateFloatByFrame(0.0f, 1.0f, frame, 0, 8);

    // The cleared-background plate slides in, centred on the field.
    CGRect plate = [self.texResultBg spriteAtIndex:2];
    double plateH = plate.size.height;
    float topFrom = kBannerTopFrom;
    float topTo = kBannerTopTo;
    if (self.is4Inch) {
        topFrom = (float)([self buttonMarginForScreen40] + 0x118);
        topTo = (float)([self buttonMarginForScreen40] + 200);
    }
    float topY = InterpolateFloatByFrame(topFrom, topTo, frame, 0, 0x10);
    [self.texResultBg drawSprite:0
                          inRect:CGRectMake((double)topY - plateH * 0.5, kFieldWidth, plateH, 3)];

    float midFrom = kBannerTopFrom;
    float midTo = kBannerMidTo;
    if (self.is4Inch) {
        midFrom = (float)([self buttonMarginForScreen40] + 0x118);
        midTo = (float)([self buttonMarginForScreen40] + 0x1b8);
    }
    double midY = (double)InterpolateFloatByFrame(midFrom, midTo, frame, 0, 0x10) - plateH * 0.5;
    [self.texResultBg drawSprite:0 inRect:CGRectMake(midY, kBannerMidW, plateH, 3)];
    [self.texResultBg drawSprite:0
                          inRect:CGRectMake(midY, kBannerBoxW, plateH, 3)
                       transform:0
                           alpha:1.0f];

    // The 4x4 clear panels fade/scale in; the eighth is drawn full.
    (void)[self.texResultBg spriteAtIndex:1];
    for (int i = 0; i < 8; ++i) {
        float cellAlpha = (i == 7) ? 1.0f : fadeIn;
        int reflowed = i % 4 + (i >> 2) * 0xc;
        double px = (double)((reflowed % 4) * kPanelPitch + kPanelInset);
        int margin = self.is4Inch ? [self buttonMarginForScreen40] : 0;
        double py = (double)((reflowed >> 2) * kPanelPitch + margin + kGridTop);
        [self.texResultBg drawSprite:1
                             atPoint:CGPointMake(px, py)
                               scale:1.0f
                              rotate:0
                              anchor:CGPointMake(px, py)
                           transform:(char)cellAlpha
                               alpha:cellAlpha];
    }

    // The "cleared" word (texFront sprite 0x18) scales and fades in over frames 0..6.
    float wordAlpha = InterpolateFloatByFrame(0.0f, 1.0f, frame, 0, 6);
    float wordScale = InterpolateFloatByFrame(kComboFadeBase, 1.0f, frame, 0, 6);
    double wordY = kWordBaseY;
    if (self.is4Inch) {
        wordY = (double)([self buttonMarginForScreen40] + 0x118);
    }
    (void)[self.texFront spriteAtIndex:0x18];
    [self.texFront drawSprite:0x18
                      atPoint:CGPointMake(kWordAnchorX, wordY)
                        scale:wordScale
                       rotate:0
                       anchor:CGPointMake(kWordAnchorX, wordY)
                    transform:0
                        alpha:wordAlpha];

    // The clear jingle plays once; from frame 10 the rating tallies count up.
    if (frame < 10) {
        if (frame == 0) {
            [[AudioManager sharedManager] playSeResFile:(NSString *)kSeResultClear inDirectory:nil];
            [[AudioManager sharedManager] playSeResFile:(NSString *)kSeVoiceClear inDirectory:nil];
        }
    } else {
        [self renderRating:frame - 10];
    }

    return frame > 0x3b;
}

/** @ghidraAddress 0x18d470 */
- (void)renderCombo:(unsigned int)combo alpha:(float)alpha {
    static const double kComboBaseY = 260.0;        // @ghidraAddress 0x292f98
    static const double kComboBurstCentre = 160.0;  // @ghidraAddress 0x28f438
    static const float kComboBurstScaleFrom = 1.2f; // @ghidraAddress 0x292aa8
    static const int kComboCutAnimFrames = 8;
    static const int kComboEffectResetFrames = 10;
    static const int kComboDrawThreshold = 4;
    static const int kComboMaxDigits = 4;
    static const int kComboDigitBufferSize = 5;
    static const int kComboDigitStride = 0x4e;     // 78: per-digit X advance
    static const int kComboRowWidth = 0x140;       // 320
    static const char kComboDigitAsciiBase = 0x2e; // '.'; '0' maps to sprite 2
    static const NSUInteger kComboBurstSprite = 1;

    if (self.scoreBackup) {
        return;
    }

    // The combo cut-in burst sits at the horizontal centre, nudged down on the four-inch screen.
    float burstY = (float)kComboBaseY;
    if (self.is4Inch) {
        burstY = (float)[self buttonMarginForScreen40] + (float)kComboBaseY;
    }

    if (self->comboEffectFrame != 0) {
        --self->comboEffectFrame;
    }

    // Arm the cut-in burst when the combo drops from a meaningful streak; run it down otherwise.
    if (combo < self->lastCombo && self->lastCombo > (unsigned int)kComboDrawThreshold) {
        self->comboCutFrame = kComboCutAnimFrames;
    } else if (self->comboCutFrame == 0) {
        goto drawDigits;
    }

    if (self.showCombo) {
        [self.texCombo spriteAtIndex:kComboBurstSprite];
        float scale =
            InterpolateFloatByFrame(kComboBurstScaleFrom, 1.0f, self->comboCutFrame, 0, 8);
        float rotate = InterpolateFloatByFrame(0.0f, g_flKeyTime080, self->comboCutFrame, 0, 8);
        double centreX = (double)(float)(kComboBurstCentre - alpha * 0.5);
        double spriteW = [self.texCombo spriteAtIndex:kComboBurstSprite].size.width;
        double drawX = centreX - (double)(float)((spriteW * (double)scale - spriteW) * 0.5);
        double drawY = (double)burstY -
                       (double)(float)(((double)burstY * (double)scale - (double)burstY) * 0.5);
        [self.texCombo drawSprite:kComboBurstSprite
                          atPoint:CGPointMake(drawX, drawY)
                            scale:scale
                           rotate:0
                           anchor:CGPointMake(centreX, (double)burstY)
                        transform:(char)rotate
                            alpha:alpha];
    }
    --self->comboCutFrame;

drawDigits:
    if (combo <= (unsigned int)kComboDrawThreshold) {
        return;
    }
    if (self->lastCombo < combo) {
        self->comboEffectFrame = kComboEffectResetFrames;
    }
    char digits[kComboDigitBufferSize];
    int len = snprintf(digits, kComboDigitBufferSize, "%d", combo);
    if (len <= 0) {
        return;
    }
    int count = len < kComboMaxDigits + 1 ? len : kComboMaxDigits;
    int startX = count * -kComboDigitStride + kComboRowWidth;
    if (startX < 0) {
        startX += 1;
    }
    int effectFrame = self->comboEffectFrame;
    if (!self.showCombo) {
        return;
    }
    startX >>= 1;

    if ((unsigned int)(count - 1) >= 4) {
        // The plain path: no per-digit bounce.
        int glyphX = startX;
        for (int i = 0; i < count; ++i) {
            unsigned int sprite = (unsigned int)(digits[i] - kComboDigitAsciiBase);
            [self.texCombo drawSprite:sprite
                              atPoint:CGPointMake((double)glyphX, (double)burstY)
                            transform:0
                                alpha:alpha];
            glyphX += kComboDigitStride;
        }
        return;
    }

    // The bounce path: the three digits nearest the effect front are lifted -5, -10, -15.
    int frontIndex = (int)(~(unsigned int)len < -5 ? ~(unsigned int)len : -5);
    frontIndex = effectFrame - frontIndex;
    int glyphX = startX;
    for (int i = 0; i < count; ++i) {
        int lift = 0;
        if (frontIndex - 0xb == i) {
            lift = -5;
        }
        if (frontIndex - 0xc == i) {
            lift = -10;
        }
        if (frontIndex - 0xd == i) {
            lift = -0xf;
        }
        unsigned int sprite = (unsigned int)(digits[i] - kComboDigitAsciiBase);
        [self.texCombo drawSprite:sprite
                          atPoint:CGPointMake((double)glyphX, (double)(burstY + (float)lift))
                        transform:0
                            alpha:alpha];
        glyphX += kComboDigitStride;
    }
}

/** @ghidraAddress 0x191d6c */
- (BOOL)renderFailed:(unsigned int)frame {
    static const double kBannerTopY = 200.0;   // @ghidraAddress 0x28f400
    static const double kFieldWidth = 768.0;   // @ghidraAddress 0x292460
    static const double kBannerMidY = 440.0;   // @ghidraAddress 0x292f50
    static const double kBannerMidW = 576.0;   // @ghidraAddress 0x291d88
    static const double kBannerBoxW = 192.0;   // @ghidraAddress 0x28fa00
    static const float kWordScaleFrom = 0.76f; // @ghidraAddress 0x292b4c
    static const float kWordSlideFrom = 46.0f; // @ghidraAddress 0x292b50
    static const double kWordX = 280.0;        // @ghidraAddress 0x28f658
    static const double kWordAnchorX = 160.0;  // @ghidraAddress 0x28f438
    static const int kPanelPitch = 0x50;       // 80
    static const int kPanelInset = 0x28;       // 40
    static const int kGridTop = 200;
    static const NSString *const kSeResultFailed =
        @"SD_KNT_RESULT_FAILED";                                       // @ghidraAddress 0x2df980
    static const NSString *const kSeVoiceFailed = @"SD_KNT_CV_FAILED"; // @ghidraAddress 0x2df9a0

    float fadeIn = InterpolateFloatByFrame(0.0f, 1.0f, frame, 0, 0x10);

    // The result-background plate slides in over the field, centred horizontally.
    double plateY = kBannerTopY;
    if (self.is4Inch) {
        plateY = (double)([self buttonMarginForScreen40] + 200);
    }
    CGRect plate = [self.texResultBg spriteAtIndex:5];
    double plateH = plate.size.height;
    [self.texResultBg drawSprite:0
                          inRect:CGRectMake(plateY - plateH * 0.5, kFieldWidth, plateH, 6)];

    double midY = kBannerMidY;
    if (self.is4Inch) {
        midY = (double)([self buttonMarginForScreen40] + 0x1b8);
    }
    midY = midY - plateH * 0.5;
    [self.texResultBg drawSprite:0 inRect:CGRectMake(midY, kBannerMidW, plateH, 6)];
    [self.texResultBg drawSprite:0
                          inRect:CGRectMake(midY, kBannerBoxW, plateH, 6)
                       transform:0
                           alpha:1.0f];

    // The 4x4 fail panels fade/scale in; the eighth is drawn full.
    (void)[self.texResultBg spriteAtIndex:4];
    for (int i = 0; i < 8; ++i) {
        float cellAlpha = (i == 7) ? 1.0f : fadeIn;
        int reflowed = i % 4 + (i >> 2) * 0xc;
        double px = (double)((reflowed % 4) * kPanelPitch + kPanelInset);
        int margin = self.is4Inch ? [self buttonMarginForScreen40] : 0;
        double py = (double)((reflowed >> 2) * kPanelPitch + margin + kGridTop);
        [self.texResultBg drawSprite:4
                             atPoint:CGPointMake(px, py)
                               scale:1.0f
                              rotate:0
                              anchor:CGPointMake(px, py)
                           transform:(char)cellAlpha
                               alpha:cellAlpha];
    }

    // The "failed" word (texFront sprite 0x19) scales and slides down into place.
    float wordScale = InterpolateFloatByFrame(kWordScaleFrom, 1.0f, frame, 0, 0x10);
    float wordSlide = InterpolateFloatByFrame(kWordSlideFrom, 0.0f, frame, 0, 0x10);
    double wordY = kWordX;
    if (self.is4Inch) {
        wordY = (double)([self buttonMarginForScreen40] + 0x118);
    }
    (void)[self.texFront spriteAtIndex:0x19];
    [self.texFront drawSprite:0x19
                      atPoint:CGPointMake(kWordAnchorX, wordY + (double)wordSlide)
                        scale:wordScale
                       rotate:0
                       anchor:CGPointMake(kWordAnchorX, wordY + (double)wordSlide)
                    transform:0
                        alpha:fadeIn];

    // The failure jingle plays once at the start; from frame 10 the rating tallies count up.
    if (frame < 10) {
        if (frame == 0) {
            [[AudioManager sharedManager] playSeResFile:(NSString *)kSeResultFailed
                                            inDirectory:nil];
            [[AudioManager sharedManager] playSeResFile:(NSString *)kSeVoiceFailed inDirectory:nil];
        }
    } else {
        [self renderRating:frame - 10];
    }

    return frame > 0x3b;
}

/** @ghidraAddress 0x190340 */
- (void)renderFinish {
    __weak MainGameRendererPhoneKnt *weakSelf = self;
    // Load the result texture on the render's background context, then enter the result sub-state
    // on the main queue.
    void (^loadResult)(void) = ^{
      /** @ghidraAddress 0x19052c */
      [weakSelf loadResultTex:(short)[weakSelf.sequence rank]];
      dispatch_async(dispatch_get_main_queue(), ^{
        /** @ghidraAddress 0x190614 */
        [weakSelf setSubState:10];
      });
    };

    if (self.sequence.isFullcombo) {
        // A full combo shows the flourish first, then advances after 100 frames.
        [self renderFullcombo:(int)frame isResult:NO];
        if (self.subState == 0 && frame > 99) {
            self.subState = 1;
            [self.eaglView performBlockInBackground:loadResult];
        }
    } else {
        if (self.subState == 0 && frame > 0x13) {
            self.subState = 1;
            [self.eaglView performBlockInBackground:loadResult];
        }
    }
}

/** @ghidraAddress 0x18fc64 */
- (void)renderFullcombo:(int)frame isResult:(BOOL)isResult {
    static const double kBannerX = 4.0;        // fixed origin.x of every full-combo quad
    static const double kTopRestY = 200.0;     // @ghidraAddress 0x28f400
    static const double kBottomRestY = 440.0;  // @ghidraAddress 0x292f50
    static const double kWordStartY = 280.0;   // @ghidraAddress 0x28f658
    static const float kWordSettleY = 246.0f;  // @ghidraAddress 0x2934b8
    static const float kBurstPeakScale = 1.4f; // @ghidraAddress 0x292af0
    static const NSString *const kSeResultFullcombo =
        @"SD_KNT_RESULT_FULLCOMBO"; // @ghidraAddress 0x2df860
    static const NSString *const kSeVoiceFullcombo =
        @"SD_KNT_CV_FULLCOMBO"; // @ghidraAddress 0x2df880
    static const NSUInteger kBannerSprite = 27;
    static const NSUInteger kWordSprite = 28;
    static const float kBannerAlpha = 0.5f;

    // The full-combo flourish is skipped entirely when the score is being backed up.
    if (self.scoreBackup) {
        return;
    }

    // On the result screen the animation is offset 150 frames past the play-time entry, so the two
    // callers share one timeline; the play-time path clamps at frame 150.
    int nFrame = isResult ? (frame + 150) : (frame > 150 ? 150 : frame);
    if (nFrame > 160) {
        return;
    }

    // The full-combo jingle and voice play once, two frames in.
    if (nFrame == 2) {
        [[AudioManager sharedManager] playSeResFile:(NSString *)kSeResultFullcombo inDirectory:nil];
        [[AudioManager sharedManager] playSeResFile:(NSString *)kSeVoiceFullcombo inDirectory:nil];
    }

    // Both banner halves and the word overlay are cut from front-atlas sprite 27.
    CGRect banner = [self.texFront spriteAtIndex:kBannerSprite];
    double bannerW = banner.size.width;
    double bannerH = banner.size.height;

    // The resting positions all shift down by the four-inch game-area margin on a four-inch phone.
    double topRestY = kTopRestY;
    double bottomRestY = kBottomRestY;
    double wordStartY = kWordStartY;
    float wordSettleY = kWordSettleY;
    if (self.is4Inch) {
        int margin = [self buttonMarginForScreen40];
        topRestY = (double)(margin + 200);
        bottomRestY = (double)(margin + 440);
        wordStartY = (double)(margin + 280);
        wordSettleY = (float)(margin + 246);
    }
    int wordTravel = (int)(wordStartY - topRestY); // always 80
    float topInitY = (float)(topRestY - bannerH * 0.5);
    float bottomInitY = (float)(bottomRestY - bannerH * 0.5);

    if (nFrame >= 150) {
        // The result-screen exit: the two halves fade out and slide together over 10 frames.
        int exitFrame = nFrame - 150;
        float fade = InterpolateFloatByFrame(1.0f, 0.0f, exitFrame, 0, 10);
        float slide = InterpolateFloatByFrame(0.0f, (float)wordTravel, exitFrame, 0, 10);
        [self.texFront drawSprite:kBannerSprite
                          atPoint:CGPointMake(kBannerX, (double)(topInitY + slide))
                        transform:0
                            alpha:fade];
        [self.texFront drawSprite:kBannerSprite
                          atPoint:CGPointMake(kBannerX, (double)(bottomInitY - slide))
                        transform:0
                            alpha:fade];
        return;
    }

    // The play-time flourish: both halves start together one travel below the top rest, then slide
    // to their own rest positions over their windows.
    float slideFrom = (float)(topRestY - (double)wordTravel);
    float topHalfY = InterpolateFloatByFrame(slideFrom, topInitY, nFrame, 0, 6);
    float bottomHalfY = InterpolateFloatByFrame(slideFrom, bottomInitY, nFrame, 0, 24);

    // Frames 29..37 punch a scaling ghost of each half in behind them.
    if (nFrame > 28 && nFrame - 28 < 10) {
        unsigned int burst = nFrame - 28;
        float burstScale = InterpolateFloatByFrame(1.0f, kBurstPeakScale, burst, 0, 5);
        if (burst >= 6) {
            burstScale = InterpolateFloatByFrame(kBurstPeakScale, 1.0f, burst, 5, 10);
        }
        double scaledH = (double)(float)(bannerH * (double)burstScale);
        float inset = (float)((bannerH - scaledH) * 0.5);
        [self.texFront drawSprite:kWordSprite
                           inRect:CGRectMake(kBannerX, (double)(topHalfY + inset), bannerW, scaledH)
                        transform:0
                            alpha:kBannerAlpha];
        [self.texFront
            drawSprite:kWordSprite
                inRect:CGRectMake(kBannerX, (double)(bottomHalfY + inset), bannerW, scaledH)
             transform:0
                 alpha:kBannerAlpha];
    }

    [self.texFront drawSprite:kBannerSprite atPoint:CGPointMake(kBannerX, (double)topHalfY)];
    [self.texFront drawSprite:kBannerSprite atPoint:CGPointMake(kBannerX, (double)bottomHalfY)];

    // Past frame 23 only the halves show; up to it the word overlay bounce-scales in over them.
    if (nFrame > 23) {
        return;
    }
    float wordY = InterpolateFloatByFrame(slideFrom, wordSettleY, nFrame, 0, 6);
    if (nFrame > 6) {
        wordY = InterpolateFloatByFrame(wordSettleY, bottomInitY, nFrame, 6, 24);
    }

    float wordScale;
    if (nFrame - 6 < 6) {
        wordScale = InterpolateFloatByFrame(1.0f, 3.0f, nFrame - 6, 0, 6);
    } else {
        wordScale = InterpolateFloatByFrame(3.0f, 1.0f, nFrame - 6, 6, 18);
    }

    if (nFrame > 5) {
        double scaledH = (double)(float)(bannerH * (double)wordScale);
        float inset = (float)((bannerH - scaledH) * 0.5);
        [self.texFront drawSprite:kWordSprite
                           inRect:CGRectMake(kBannerX, (double)(wordY + inset), bannerW, scaledH)
                        transform:0
                            alpha:kBannerAlpha];
    } else {
        [self.texFront drawSprite:kWordSprite
                          atPoint:CGPointMake(kBannerX, (double)wordY)
                        transform:0
                            alpha:kBannerAlpha];
    }
}

/** @ghidraAddress 0x18f3d4 */
- (void)renderReadyGo {
    /** @ghidraAddress 0x2938e4 */
    static const float kReadyGlyphX[] = {-88.5f, -45.0f, 0.0f, 48.5f, 91.5f};
    static const float kReadyCentreX = 160.0f; // @ghidraAddress 0x28e014
    static const float kReadyYDefault = 50.6f; // @ghidraAddress 0x2934b0
    static const float kGoYDefault = 385.0f;   // @ghidraAddress 0x2934b4
    // The READY exit X positions, indexed by glyph sprite: 71.5, 115.0, 160.0, 208.5, 251.5, from
    // @ghidraAddress 0x293540, 0x293538, 0x28f438, 0x293530, 0x293528.
    static const double kReadyExitX[] = {71.5, 115.0, 160.0, 208.5, 251.5};
    static const double kGoLeftX = 76.0;                        // @ghidraAddress 0x292488
    static const double kGoRightX = 244.0;                      // @ghidraAddress 0x28fab0
    static const NSString *const kSeReady = @"SD_KNT_CV_READY"; // @ghidraAddress 0x2df840
    static const NSUInteger kProbeSprite = 0;
    enum { kReadyGlyphCount = 5 };

    // The READY line's Y and the GO line's Y both shift down by the four-inch game-area margin.
    int readyY;
    int goY;
    if (self.is4Inch) {
        readyY = (int)((float)[self buttonMarginForScreen40] + kReadyYDefault);
        goY = (int)((float)[self buttonMarginForScreen40] + kGoYDefault);
    } else {
        readyY = (int)kReadyYDefault;
        goY = (int)kGoYDefault;
    }

    // "READY?" is five glyph sprites (texReady0 sprites 0..4); sprite 0 sizes them all.
    int f = (int)frame;
    CGRect readyGlyph = [self.texReady0 spriteAtIndex:kProbeSprite];
    double readyHalfW = readyGlyph.size.width * 0.5;
    float readyGlyphH = (float)readyGlyph.size.height;
    if ((unsigned int)(f - 21) < 29) {
        // The entrance (frames 21..49): each glyph drops in and fades in over its own 8-frame
        // window, staggered by its index, drawn last-to-first so earlier glyphs sit on top.
        int stagger = f - 20;
        for (int i = kReadyGlyphCount - 1; i >= 0; --i) {
            if (stagger < i) {
                continue;
            }
            float rise = InterpolateFloatByFrame(readyGlyphH, 0.0f, stagger, i, i + 8);
            float alpha = InterpolateFloatByFrame(0.0f, 1.0f, stagger, i, i + 8);
            double x = (double)(kReadyGlyphX[i] + kReadyCentreX) - readyHalfW;
            [self.texReady0 drawSprite:(NSUInteger)i
                               atPoint:CGPointMake(x, (double)((float)readyY - rise))
                             transform:0
                                 alpha:alpha];
        }
    } else {
        // The exit (frames 50..): the whole line rises towards the GO line, overshooting by twice
        // the glyph height, and fades out over frames 59..65.
        float rise = InterpolateFloatByFrame(
            0.0f, (float)((double)(goY - readyY) + (double)readyGlyphH * -2.0), f - 50, 0, 10);
        double y = (double)((float)readyY + rise);
        float alpha = InterpolateFloatByFrame(1.0f, 0.0f, f - 50, 9, 15);
        for (int i = kReadyGlyphCount - 1; i >= 0; --i) {
            [self.texReady0 drawSprite:(NSUInteger)i
                               atPoint:CGPointMake(kReadyExitX[i] - readyHalfW, y)
                             transform:0
                                 alpha:alpha];
        }
    }

    // "GO!" is four glyph sprites in texReady1 (a static top pair 2,3 and a rising pair 0,1);
    // sprite 0 sizes them all. Each glyph rotates about its own centre.
    unsigned int gf = frame;
    CGRect goGlyph = [self.texReady1 spriteAtIndex:kProbeSprite];
    double goHalfW = goGlyph.size.width * 0.5;
    float goGlyphH = (float)goGlyph.size.height;
    double goHalfH = (double)goGlyphH * 0.5;
    if (gf - 56 < 7) {
        // The entrance (frames 56..62): the top pair holds while the rising pair drops in from the
        // top line and fades in.
        float alpha = InterpolateFloatByFrame(0.0f, 1.0f, gf - 55, 0, 4);
        float spread = InterpolateFloatByFrame(0.0f, goGlyphH, gf - 55, 0, 8);
        double topY = (double)goY - (double)goGlyphH;
        double riseY = (double)goY - (double)spread;
        double leftX = kGoLeftX - goHalfW;
        double rightX = kGoRightX - goHalfW;
        [self.texReady1 drawSprite:2
                           atPoint:CGPointMake(leftX, topY)
                             scale:1.0f
                            rotate:0.0f
                            anchor:CGPointMake(goHalfW + leftX, topY + goHalfH)
                         transform:0
                             alpha:1.0f];
        [self.texReady1 drawSprite:0
                           atPoint:CGPointMake(leftX, riseY)
                             scale:1.0f
                            rotate:0.0f
                            anchor:CGPointMake(goHalfW + leftX, riseY + goHalfH)
                         transform:0
                             alpha:alpha];
        [self.texReady1 drawSprite:3
                           atPoint:CGPointMake(rightX, topY)
                             scale:1.0f
                            rotate:0.0f
                            anchor:CGPointMake(goHalfW + rightX, topY + goHalfH)
                         transform:0
                             alpha:1.0f];
        [self.texReady1 drawSprite:1
                           atPoint:CGPointMake(rightX, riseY)
                             scale:1.0f
                            rotate:0.0f
                            anchor:CGPointMake(goHalfW + rightX, riseY + goHalfH)
                         transform:0
                             alpha:alpha];
    } else if (gf <= 74) {
        // The exit (frames 63..74): the remaining pair shrinks towards half height and fades out.
        float alpha = InterpolateFloatByFrame(1.0f, 0.0f, gf - 63, 0, 8);
        float shrink = InterpolateFloatByFrame(goGlyphH, goGlyphH * 0.5f, gf - 63, 0, 8);
        double y = (double)goY - (double)shrink;
        double leftX = kGoLeftX - goHalfW;
        double rightX = kGoRightX - goHalfW;
        [self.texReady1 drawSprite:0
                           atPoint:CGPointMake(leftX, y)
                             scale:1.0f
                            rotate:0.0f
                            anchor:CGPointMake(goHalfW + leftX, y + goHalfH)
                         transform:0
                             alpha:alpha];
        [self.texReady1 drawSprite:1
                           atPoint:CGPointMake(rightX, y)
                             scale:1.0f
                            rotate:0.0f
                            anchor:CGPointMake(goHalfW + rightX, y + goHalfH)
                         transform:0
                             alpha:alpha];
    }

    // The ready cue plays at frame 20; at frame 59 the go voice fires and is cleared. Past frame 74
    // the countdown finishes and the play sub-state begins.
    if (frame == 20) {
        [[AudioManager sharedManager] playSeResFile:(NSString *)kSeReady inDirectory:nil];
    }
    if (frame == 59) {
        [[AudioManager sharedManager] playSePlayer:self.sePlayerGo];
        self.sePlayerGo = nil;
    }
    if (frame >= 75) {
        [self setSubState:kMainGamePhoneKntEndSubState];
    }
}

/** @ghidraAddress 0x18c74c */
- (void)renderMarker {
    static const int kCellPitch = 0x50;            // 80
    static const int kCellCentre = 6;              // the |6 pixel centre
    static const int kGridTopOffset = 0xa0;        // 160
    static const float kStartMarkFadeDiv = 100.0f; // @ghidraAddress 0x28f4e0

    unsigned int firstSector = [self.sequence firstMarkerSector];
    unsigned int currentSector = [self.sequence currentSector];
    [self.sequence getMarkerState:markerState];

    for (int i = 0; i < 16; ++i) {
        int margin = self.is4Inch ? [self buttonMarginForScreen40] : 0;
        unsigned int state = (unsigned int)markerState[i];
        unsigned int frameCount = state & 0xfff;
        unsigned int bank = (state >> 0xc) & 7;

        BOOL draw = NO;
        unsigned int sprite = 0;
        if (bank == 0) {
            if (frameCount < 0xf0) {
                sprite = frameCount / 10;
                draw = YES;
            }
        } else if (frameCount < 0xa0 && bank < 6) {
            unsigned int idx = (frameCount / 10 + bank * 0x10) - 8;
            if ((int)idx >= 0) {
                sprite = idx;
                draw = YES;
            }
        }

        if (draw) {
            double cellX = (double)((i % 4) * kCellPitch | kCellCentre);
            double cellY =
                (double)(((i >> 2) * kCellPitch | kCellCentre) + margin + kGridTopOffset);
            [self.texMarker drawSprite:sprite
                               atPoint:CGPointMake(cellX, cellY)
                             transform:(char)markerDir[i]
                                 alpha:1.0f];
        } else {
            // The panel finished animating: reset its spin, re-randomising it when the setting
            // asks.
            markerDir[i] = 0;
            if (JubeatAppDelegate.appDelegate.isMarkerDirRandom) {
                markerDir[i] = rand() % 4;
            }
        }
    }

    // The hold markers, unless stealth mode hides them.
    [self.sequence getHoldMarkerState:holdState];
    if (!self.rendererConf.isStealth) {
        [holdMarkerRender renderHoldMarker:holdState];
    }

    // Within the last 150 sectors before the first marker, run the start-mark burst, fading it in
    // over its final 100 sectors.
    int lead = (int)firstSector - (int)currentSector;
    if (lead > 0x96) {
        int f = lead - 0x96;
        float fade = 1.0f;
        if (f < 100) {
            fade = (float)f / kStartMarkFadeDiv;
        }
        [self renderStartMark:fade];
    }
}

/** @ghidraAddress 0x18e34c */
- (void)renderMusicBar:(CGPoint)pos timeline:(BOOL)timeline alpha:(double)alpha {
    static const double kMusicBarCellBaseXOffset = 40.0; // @ghidraAddress 0x28f1f8
    static const double kMusicBarCellYOffset = -2.0;
    static const float kMusicBarCursorScale = 120.0f; // @ghidraAddress 0x291be8
    static const float kMusicBarFadeEnd = 1.3f;       // @ghidraAddress 0x292558
    static const int kMusicBarNoteBaseIdle = 0x48;
    static const int kMusicBarNoteBaseCursor = 0x40;
    /** @ghidraAddress 0x2935a0 */
    static const int kMusicBarRatingSpriteBase[] = {80, 72, 88, 64};
    static const int kMusicBarCellPitch = 2;
    static const float kMusicBarPlayHeadScale = 240.0f; // @ghidraAddress 0x292738
    static const float kMusicBarPlayHeadX = 36.0f;      // @ghidraAddress 0x28f53c
    static const double kMusicBarPlayHeadY = 130.0;     // @ghidraAddress 0x28fa38
    static const NSUInteger kMusicBarSpritePlayHead = 0x14;
    enum { kMusicBarCellCount = 0x78 };

    float a = (float)alpha;

    // The difficulty-coloured bar backdrop, nudged down a little on a retina phone.
    double barY = isRetina ? pos.y + 3.0 : pos.y;
    NSUInteger barSprite;
    switch ((int)self.rendererConf.diff) {
    case 2:
        barSprite = 9;
        break;
    case 1:
        barSprite = 8;
        break;
    case 0:
        barSprite = 7;
        break;
    default:
        barSprite = 10;
        break;
    }
    [self.texFront drawSprite:barSprite atPoint:CGPointMake(pos.x, barY) transform:0 alpha:a];

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
            if (self.state == 4 || self.state == 5 || self.scoreBackup ||
                ((float)i + kMusicBarFadeEnd < cursor)) {
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
                     alpha:a];
        }
        drawX += kMusicBarCellPitch;
    }

    // The play-head cursor over the bar, when a timeline is shown.
    if (timeline) {
        double headY = kMusicBarPlayHeadY;
        if (self.is4Inch) {
            headY = (double)([self upperBgHeight40] + 0x7d);
        }
        float headX = playPosition * kMusicBarPlayHeadScale + kMusicBarPlayHeadX;
        [self.texFront drawSprite:kMusicBarSpritePlayHead
                          atPoint:CGPointMake((double)headX, headY)
                        transform:0
                            alpha:a];
    }
}

/** @ghidraAddress 0x18dfb8 */
- (void)renderPartnerScore:(unsigned int)score
                   atPoint:(CGPoint)point
                     scale:(double)scale
                     alpha:(double)alpha {
    static const double kPartnerFourInchYFactor = 1.4;  // @ghidraAddress 0x293518
    static const double kPartnerFourInchXShift = -52.0; // @ghidraAddress 0x28f228
    static const NSUInteger kPartnerPlateLo = 5;
    static const NSUInteger kPartnerPlateHi = 6;
    static const NSUInteger kPartnerFrameSprite = 0x20;
    static const int kPartnerDigitStride = 0x19; // 25
    static const char kPartnerDigitAsciiBase = 0x30;
    static const unsigned int kPartnerSixDigitThreshold = 0xaae61; // 700001

    if (!self.isSession) {
        return;
    }
    // A partner who is not connected is drawn at half opacity.
    if (!self.isConnected) {
        alpha = alpha * 0.5;
    }

    (void)[self.texFront spriteAtIndex:6];
    (void)[self.texFront spriteAtIndex:0x21];

    double drawX = point.x;
    double drawY = point.y;
    double scaleX = scale;
    // On the taller four-inch screen the panel slides and is drawn unscaled.
    if (self.is4Inch) {
        drawY = point.y -
                ((float)(alpha - alpha * scale) + (float)(alpha * kPartnerFourInchYFactor - alpha));
        scaleX = 1.0;
        drawX = point.x + kPartnerFourInchXShift;
    }

    // Tween the shown score toward the target by half the remaining gap each frame.
    if (score == 0) {
        partnerScoreDisplay = 0;
    } else if (partnerScoreDisplay != score) {
        int sign = partnerScoreDisplay < score ? 1 : -1;
        partnerScoreDisplay = partnerScoreDisplay + (((score - partnerScoreDisplay) + sign) >> 1);
    }

    char digits[8];
    snprintf(digits, 8, "%7d", partnerScoreDisplay);
    unsigned int shown = partnerScoreDisplay;

    float a = (float)alpha;
    // The two score-plate halves.
    [self.texFront drawSprite:kPartnerPlateLo
                       inRect:CGRectMake(drawX, drawY, scale * scaleX, alpha * scaleX)
                    transform:0
                        alpha:a];
    [self.texFront drawSprite:kPartnerPlateHi
                       inRect:CGRectMake(drawX, drawY, scale * scaleX, alpha * scaleX)
                    transform:0
                        alpha:a];

    // The seven digits; a six-digit score uses a tighter glyph base.
    int glyphBase = (shown < kPartnerSixDigitThreshold) ? -0xf : -5;
    int i = 0;
    for (int step = 0; step != 0xaf; step += kPartnerDigitStride) {
        if ((unsigned char)(digits[i] - kPartnerDigitAsciiBase) < 10) {
            [self.texFront drawSprite:(NSUInteger)(glyphBase + (int)digits[i])
                               inRect:CGRectMake(drawX + scaleX * (double)i + 1.0,
                                                 drawY,
                                                 scale * scaleX,
                                                 alpha * scaleX)
                            transform:0
                                alpha:a];
        }
        ++i;
    }

    // The partner frame.
    [self.texFront drawSprite:kPartnerFrameSprite
                      atPoint:CGPointMake((double)((float)point.x + 1.0f), drawY - 14.0)
                    transform:0
                        alpha:a];
}

/** @ghidraAddress 0x18f0e0 */
- (void)renderPreStart {
    static const double kArtworkSize[] = {80.0, 88.0}; // @ghidraAddress 0x292770
    static const double kTuneInfoYDefault = 10.0;
    static const double kScoreX = 140.0;                        // @ghidraAddress 0x28f6a8
    static const double kScoreYDefault = 101.0;                 // @ghidraAddress 0x293520
    static const double kPartnerX = 192.0;                      // @ghidraAddress 0x28fa00
    static const double kPartnerYDefault = 75.0;                // @ghidraAddress 0x28f788
    static const double kPartnerScale = 0.7;                    // @ghidraAddress 0x291c98
    static const double kMusicBarYDefault = 136.0;              // @ghidraAddress 0x28f768
    static const float kSlideDistance = 40.0f;                  // @ghidraAddress 0x292568
    static const NSString *const kReadySeResource = @"SD_MUON"; // @ghidraAddress 0x2dbec0

    [self renderBG];
    [self renderShutter:YES];
    [self renderUpperBG:NO];

    unsigned int f = (unsigned int)frame;

    // The tune info fades in and slides its jacket X from 28 to 8 over frames 10..20.
    float tuneFade = InterpolateFloatByFrame(0.0f, 1.0f, f, 10, 0x14);
    float tuneX = InterpolateFloatByFrame(28.0f, 8.0f, f, 10, 0x14);
    double tuneY = kTuneInfoYDefault;
    double artworkSize = kArtworkSize[0];
    if (self.is4Inch) {
        tuneY = (double)((self.upperBgHeight40 >> 2) + 10);
        artworkSize = kArtworkSize[self.is4Inch];
    }
    [self renderTuneInfo:CGPointMake((double)tuneX, tuneY) artworkSize:artworkSize alpha:tuneFade];

    // The score and partner score fade in over frames 4..14 while sliding down into place.
    float uiFade = InterpolateFloatByFrame(0.0f, 1.0f, f, 4, 0xe);
    float slide = InterpolateFloatByFrame(kSlideDistance, 0.0f, f, 4, 0xe);
    double scoreY = kScoreYDefault;
    if (self.is4Inch) {
        scoreY = (double)(self.upperBgHeight40 + 0x60);
    }
    [self renderScore:0 atPoint:CGPointMake(kScoreX - (double)slide, scoreY) alpha:uiFade];

    double partnerY = kPartnerYDefault;
    if (self.is4Inch) {
        partnerY = (double)(self.upperBgHeight40 + 0x46);
    }
    [self renderPartnerScore:0
                     atPoint:CGPointMake(kPartnerX - (double)slide, partnerY)
                       scale:kPartnerScale
                       alpha:uiFade];

    // The music bar fades in over frames 0..10.
    float barFade = InterpolateFloatByFrame(0.0f, 1.0f, f, 0, 10);
    double musicBarY = kMusicBarYDefault;
    if (self.is4Inch) {
        musicBarY = (double)(self.upperBgHeight40 + 0x83);
    }
    [self renderMusicBar:CGPointMake(0.0, musicBarY) timeline:NO alpha:barFade];

    [self renderButtons];

    // On the last intro frame, cue the ready sound and advance the sub-state.
    if (frame == 0x14) {
        [[AudioManager sharedManager] playSeResFile:(NSString *)kReadySeResource inDirectory:nil];
        [self setSubState:10];
    }
}

/** @ghidraAddress 0x19134c */
- (void)renderRating:(unsigned int)frame {
    static const double kRatingLabelBaseY = 326.0; // @ghidraAddress 0x292f70
    static const double kRatingLabelSlideY = 47.0; // @ghidraAddress 0x28f600
    static const double kRatingLabelX = 90.0;      // @ghidraAddress 0x28f440
    static const double kRankBaseY = 361.0;        // @ghidraAddress 0x293548
    static const double kRankAnchorX = 200.0;      // @ghidraAddress 0x28f400
    static const float kRankScaleLow = 1.16f;      // @ghidraAddress 0x292b34
    static const float kRankScaleBig = 1.6f;       // @ghidraAddress 0x292b30
    static const float kRankScaleSmall = 0.2f;     // @ghidraAddress 0x28f3c8
    static const float kRankScaleMid = 0.9f;       // @ghidraAddress 0x28f3b0
    static const NSUInteger kRatingLabelSprite = 10;
    static const NSUInteger kRankSprite = 0xc;

    int rank = (int)self.sequence.rank;

    // The rating-label slides up into place and fades in; its animation window and the rank-sprite
    // pop timing both shorten for the top ranks (rank < 3).
    unsigned int slideEnd = (rank < 3) ? 0xe : 7;
    double labelY = kRatingLabelBaseY;
    if (self.is4Inch) {
        labelY = (double)([self buttonMarginForScreen40] + 0x146);
    }
    float labelSlide = InterpolateFloatByFrame(10.0f, 0.0f, frame, 0, slideEnd);
    float labelAlpha = InterpolateFloatByFrame(0.0f, 1.0f, frame, 0, slideEnd);
    [self.texResultBg
        drawSprite:kRatingLabelSprite
           atPoint:CGPointMake(kRatingLabelX, labelY + (double)labelSlide + kRatingLabelSlideY)
         transform:0
             alpha:labelAlpha];

    double rankY = kRankBaseY;
    if (self.is4Inch) {
        rankY = (double)([self buttonMarginForScreen40] + 0x168) + 1.0;
    }
    (void)[self.texResultBg spriteAtIndex:kRankSprite];

    // The rank sprite pops: it overshoots and settles, with a few frame windows differing between
    // the high (rank < 5) and standard tiers.
    float rankScale;
    float rankAlpha;
    if (rank < 5) {
        unsigned int popStart = (rank < 3) ? 0 : 3;
        unsigned int popEnd = (rank < 3) ? 4 : 3;
        float from = (frame < popEnd) ? 2.0f : kRankScaleLow;
        float to = (frame < popEnd) ? kRankScaleLow : 1.0f;
        rankScale = InterpolateFloatByFrame(from, to, frame, popStart, popEnd);
        rankAlpha = InterpolateFloatByFrame(0.0f, 1.0f, frame, 0, popEnd);
    } else {
        if (frame < 8) {
            rankScale = InterpolateFloatByFrame(2.0f, kRankScaleBig, frame, 0, 8);
            rankAlpha = InterpolateFloatByFrame(kRankScaleSmall, 0.0f, frame, 8, 0xd);
        } else if (frame < 0xe) {
            rankScale = InterpolateFloatByFrame(kRankScaleBig, kRankScaleMid, frame, 8, 0xe);
            rankAlpha = InterpolateFloatByFrame(kRankScaleSmall, 0.0f, frame, 8, 0xd);
        } else if (frame < 0x10) {
            rankScale = InterpolateFloatByFrame(kRankScaleMid, 1.0f, frame, 0xe, 0x10);
            rankAlpha = InterpolateFloatByFrame(kRankScaleSmall, 0.0f, frame, 8, 0xd);
        } else {
            rankScale = 1.0f;
            rankAlpha = InterpolateFloatByFrame(kRankScaleMid, 1.0f, frame, 8, 0xd);
        }
    }

    [self.texResultBg drawSprite:kRankSprite
                         atPoint:CGPointMake(kRankAnchorX - (double)rankScale * 0.5, rankY)
                           scale:rankScale
                          rotate:0
                          anchor:CGPointMake(kRankAnchorX, rankY)
                       transform:0
                           alpha:rankAlpha];
}

/** @ghidraAddress 0x1924f8 */
- (void)renderResult {
    // The tune-info and upper-region layout, shared with -renderUpper: the jacket sits at x=8 and
    // its square size is 80 points (88 on the shorter idiom). The score, partner score, and music
    // bar all slide down by the four-inch upper-background height.
    static const double kArtworkSize[] = {80.0, 88.0}; // @ghidraAddress 0x292770
    static const double kTuneInfoX = 8.0;              // fmov, 8.0
    static const double kTuneInfoYDefault = 10.0;
    static const double kScoreX = 140.0;           // @ghidraAddress 0x28f6a8
    static const double kScoreYDefault = 101.0;    // 0x65
    static const double kPartnerX = 192.0;         // @ghidraAddress 0x28fa00
    static const double kPartnerYDefault = 75.0;   // 0x4b
    static const double kPartnerScale = 0.7;       // @ghidraAddress 0x291c98
    static const double kMusicBarYDefault = 136.0; // 0x88

    // The shutter, if still open, closes in one 18.1-point step per frame down to zero.
    static const float kShutterCloseThreshold = 18.100000381469727f; // @ghidraAddress 0x293500
    static const float kShutterCloseStep = -18.100000381469727f;     // @ghidraAddress 0x2934fc

    // Once the result has settled (frame >= 30, live play only), the win/clear/fail banner runs.
    static const unsigned int kResultBannerStartFrame = 0x1e; // 30
    static const int kMillionScore = 1000000;
    static const unsigned int kClearedScoreThreshold = 699999;

    // The new-record stamp slides in over frames 65..73 and its updated-score readout trails it.
    static const unsigned int kNewRecordGateFrame = 0x40;  // shown once past frame 64
    static const unsigned int kNewRecordStartFrame = 0x41; // 65
    static const unsigned int kNewRecordEndFrame = 0x49;   // 73
    static const float kNewRecordSlideFrom = 80.0f;        // @ghidraAddress 0x28e018
    static const float kNewRecordSlideTo = 111.0f;         // @ghidraAddress 0x293504
    static const float kNewRecordXBase = 140.0f;           // @ghidraAddress 0x292b5c
    static const float kNewRecordXNudge = 2.0f;            // fmov, 2.0
    static const int kNewRecordYRetina = 0x19;             // 25, the retina stamp-Y bias
    static const int kNewRecordYNonRetina = 0x17;          // 23, the non-retina stamp-Y bias
    static const int kNewRecordYBase = 0x65;               // 101
    static const double kNewRecordScoreXOffset = -72.0;    // @ghidraAddress 0x293550
    static const double kNewRecordEightNudge = -8.0;       // fmov, -8.0
    static const NSUInteger kNewRecordStampSprite = 0x15;

    // The retry/vote overlay: the replay-tag sprite, the vote strip swapped in from a resource, and
    // the good-job image fading to its configured maximum.
    static const float kResultTagScale = 0.125f; // 1/8, fmov 0x3e000000
    static const NSUInteger kResultReplayTagSprite = 4;
    static const double kResultReplayTagX = 242.0; // @ghidraAddress 0x292f80
    static const int kResultOverlayYBase = 0x196;  // 406, the overlay Y before the +1 nudge
    static const NSUInteger kResultVoteSprite = 3;
    static const double kResultVoteX = 162.0; // @ghidraAddress 0x28fa30
    static NSString *const kResultVoteResourceRetina =
        @"game_level_vote_knt_pn2"; // @ghidraAddress 0x2df9c0
    static NSString *const kResultVoteResource =
        @"game_level_vote_knt_pn";                               // @ghidraAddress 0x2df9e0
    static const NSTimeInterval kGoodJobFadeDuration = 0.3;      // @ghidraAddress 0x28f260
    static NSString *const kSeVoiceResult = @"SD_KNT_CV_RESULT"; // @ghidraAddress 0x2dfa00
    static const unsigned int kResultSubStateComplete = 10;

    const ScoreData *score = self.sequence.getScore;
    ScoreData backup;
    if (self.scoreBackup) {
        backup = self.replayBackupScore;
        score = &backup;
    }
    if (shutterOpen > 0.0f) {
        shutterOpen =
            (shutterOpen >= kShutterCloseThreshold) ? shutterOpen + kShutterCloseStep : 0.0f;
    }
    [self renderShutter:NO];
    if (self.sequence.isFullcombo && !self.scoreBackup) {
        [self renderFullcombo:(int)frame isResult:YES];
    }
    [self renderUpperBG:YES];

    double tuneY = kTuneInfoYDefault;
    double artworkSize = kArtworkSize[0];
    if (self.is4Inch) {
        tuneY = (double)((self.upperBgHeight40 >> 2) + 10);
        artworkSize = kArtworkSize[self.is4Inch];
    }
    [self renderTuneInfo:CGPointMake(kTuneInfoX, tuneY) artworkSize:artworkSize alpha:1.0];

    double musicBarY = kMusicBarYDefault;
    if (self.is4Inch) {
        musicBarY = (double)(self.upperBgHeight40 + 0x83);
    }
    [self renderMusicBar:CGPointMake(0.0, musicBarY) timeline:NO alpha:1.0];

    double scoreY = kScoreYDefault;
    if (self.is4Inch) {
        scoreY = (double)(self.upperBgHeight40 + 0x60);
    }
    [self renderScore:(unsigned int)score->totalPoint
              atPoint:CGPointMake(kScoreX, scoreY)
                alpha:1.0];

    double partnerY = kPartnerYDefault;
    if (self.is4Inch) {
        partnerY = (double)(self.upperBgHeight40 + 0x46);
    }
    [self renderPartnerScore:self.partnerScore + self.partnerFinalBonus
                     atPoint:CGPointMake(kPartnerX, partnerY)
                       scale:kPartnerScale
                       alpha:1.0];

    float comboAlpha = InterpolateFloatByFrame(1.0f, 0.0f, frame, 0, 10);
    [self renderCombo:(unsigned int)self.sequence.getScore->curCombo alpha:comboAlpha];
    [self renderButtons];

    BOOL bannerDone;
    if (frame < kResultBannerStartFrame || self.scoreBackup) {
        bannerDone = self.scoreBackup;
    } else if (score->totalPoint == kMillionScore) {
        bannerDone = [self renderExcellent:frame - kResultBannerStartFrame];
    } else if (score->totalPoint > (int)kClearedScoreThreshold) {
        bannerDone = [self renderCleared:frame - kResultBannerStartFrame];
    } else {
        bannerDone = [self renderFailed:frame - kResultBannerStartFrame];
    }

    // A new record slides its stamp in over frames 65..73 and reads out the recorded score. The
    // stamp Y follows the score Y (offset by the upper-background height on the four-inch phone)
    // and carries an extra bias that widens on a retina phone.
    if (self.isNewRecord && frame > kNewRecordGateFrame && !self.scoreBackup) {
        float stampAlpha =
            InterpolateFloatByFrame(0.0f, 1.0f, frame, kNewRecordStartFrame, kNewRecordEndFrame);
        int heightBase = self.is4Inch ? (self.upperBgHeight40 - 5) : 0;
        int retinaBias = isRetina ? kNewRecordYRetina : kNewRecordYNonRetina;
        double stampY = (double)(heightBase + retinaBias + kNewRecordYBase);
        float stampSlide = InterpolateFloatByFrame(kNewRecordSlideFrom,
                                                   kNewRecordSlideTo,
                                                   frame,
                                                   kNewRecordStartFrame,
                                                   kNewRecordEndFrame);
        double stampX = (double)(stampSlide + kNewRecordXBase + kNewRecordXNudge);
        [self.texFront drawSprite:kNewRecordStampSprite
                          atPoint:CGPointMake(stampX, stampY)
                        transform:0
                            alpha:stampAlpha];
        [self renderUpdatedScore:self.scoreRecord
                         atPoint:CGPointMake(stampX + kNewRecordScoreXOffset + kNewRecordEightNudge,
                                             stampY)
                           alpha:(double)stampAlpha];
    }

    // The retry/vote overlay appears with the result sub-state, sliding its tag and score in.
    if (self.subState != 0) {
        int margin = self.is4Inch ? [self buttonMarginForScreen40] : 0;
        double overlayY = (double)(margin + kResultOverlayYBase) + 1.0;
        unsigned int elapsed = frame - subStateChangeFrame;
        float slideIn = (elapsed > 7) ? 1.0f : (float)elapsed * kResultTagScale;
        [self.texFront drawSprite:kResultReplayTagSprite
                          atPoint:CGPointMake(kResultReplayTagX, overlayY)
                        transform:0
                            alpha:slideIn];
        if (!self.replayPlaying && self.isCustom && self.isDownload && self.hasMusic) {
            // A downloaded custom tune swaps the vote strip in from a resource once, then fades the
            // good-job image up. Retina loads the "_pn2" strip with scale-2x toggled off for the
            // blit; non-retina loads the "_pn" strip without the toggle.
            if (!self.isTextureChange) {
                self.isTextureChange = YES;
                if (isRetina) {
                    self.texFront.isScale2x = NO;
                    LoadTextureSubImageFromResource(self.texFront,
                                                    kResultVoteResourceRetina,
                                                    [self.texFront spriteAtIndex:3].origin);
                    self.texFront.isScale2x = YES;
                } else {
                    LoadTextureSubImageFromResource(
                        self.texFront, kResultVoteResource, [self.texFront spriteAtIndex:3].origin);
                }
                if (self.goodJobImage != nil) {
                    __weak UIImageView *weakGoodJob = self.goodJobImage;
                    float goodJobAlpha = self.goodJobAlphaMax;
                    [UIView animateWithDuration:kGoodJobFadeDuration
                                     animations:^{
                                       /** @ghidraAddress 0x19310c */
                                       weakGoodJob.alpha = goodJobAlpha;
                                     }
                                     completion:^(BOOL finished){
                                         /** @ghidraAddress 0x193160 */
                                     }];
                }
            }
            [self.texFront drawSprite:kResultVoteSprite
                              atPoint:CGPointMake(kResultVoteX, overlayY)
                            transform:0
                                alpha:slideIn];
        }
        if (!self.isCustom && self.hasMusic && self.goodJobImage != nil) {
            __weak UIImageView *weakGoodJob = self.goodJobImage;
            float goodJobAlpha = self.goodJobAlphaMax;
            [UIView animateWithDuration:kGoodJobFadeDuration
                             animations:^{
                               /** @ghidraAddress 0x193164 */
                               weakGoodJob.alpha = goodJobAlpha;
                             }
                             completion:^(BOOL finished){
                                 /** @ghidraAddress 0x1931b8 */
                             }];
        }
        if (self.isSession && !self.hasMusic && self.goodJobImage != nil) {
            __weak UIImageView *weakGoodJob = self.goodJobImage;
            float goodJobAlpha = self.goodJobAlphaMax;
            [UIView animateWithDuration:kGoodJobFadeDuration
                             animations:^{
                               /** @ghidraAddress 0x1931bc */
                               weakGoodJob.alpha = goodJobAlpha;
                             }
                             completion:^(BOOL finished){
                                 /** @ghidraAddress 0x193210 */
                             }];
        }
    }
    if (frame == 0) {
        [[AudioManager sharedManager] playSeResFile:kSeVoiceResult inDirectory:nil];
    }
    // Once the banner finishes and the sub-state has not yet advanced, enter the result-complete
    // sub-state and record the frame it changed on.
    if (bannerDone && self.subState == 0) {
        self.subState = kResultSubStateComplete;
        subStateChangeFrame = frame;
    }
}

/** @ghidraAddress 0x18dbc8 */
- (void)renderScore:(unsigned int)score atPoint:(CGPoint)point alpha:(double)alpha {
    static const int kScoreDigitStride = 0x19;   // 25
    static const float kScoreDigitScale = 1.3f;  // @ghidraAddress 0x292558 (four-inch width scale)
    static const double kScoreDigitNudge = -0.3; // @ghidraAddress 0x293510
    static const char kScoreDigitAsciiBase = 0x30;
    static const unsigned int kScoreSixDigitThreshold = 0xaae61; // 700001
    static const NSUInteger kScorePlateLo = 5;
    static const NSUInteger kScorePlateHi = 6;

    // Tween the shown score toward the target by half the remaining gap each frame.
    if (score == 0) {
        scoreDisplay = 0;
    } else if (scoreDisplay != score) {
        int sign = scoreDisplay < score ? 1 : -1;
        scoreDisplay = scoreDisplay + (((score - scoreDisplay) + sign) >> 1);
    }

    char digits[8];
    snprintf(digits, 8, "%7d", scoreDisplay);

    // A six-digit-or-fewer score uses the tighter glyph base (0x21); a seven-digit one uses 0x2b.
    // The digit sprite is then that base's low nibble plus the ASCII digit.
    unsigned int baseSprite = (scoreDisplay < kScoreSixDigitThreshold) ? 0x21 : 0x2b;
    float a = (float)alpha;

    if (!self.is4Inch) {
        [self.texFront drawSprite:kScorePlateLo atPoint:point transform:0 alpha:a];
        [self.texFront drawSprite:kScorePlateHi atPoint:point transform:0 alpha:a];
        int glyphX = 0;
        for (int i = 0; i < 7; ++i) {
            if ((unsigned char)(digits[i] - kScoreDigitAsciiBase) < 10) {
                NSUInteger sprite = (NSUInteger)(((int)(baseSprite | 0xffffffd0)) + (int)digits[i]);
                [self.texFront drawSprite:sprite
                                  atPoint:CGPointMake(point.x + (double)glyphX, point.y)
                                transform:0
                                    alpha:a];
            }
            glyphX += kScoreDigitStride;
        }
        return;
    }

    // The four-inch screen draws the score at 1.3x with an anchored scale.
    (void)[self.texFront spriteAtIndex:5];
    double anchorX = point.x + alpha;
    [self.texFront drawSprite:kScorePlateLo
                      atPoint:point
                        scale:(float)kScoreDigitScale
                       rotate:0
                       anchor:CGPointMake(anchorX, point.y)
                    transform:5
                        alpha:a];
    [self.texFront drawSprite:kScorePlateHi
                      atPoint:point
                        scale:(float)kScoreDigitScale
                       rotate:0
                       anchor:CGPointMake(anchorX, point.y)
                    transform:6
                        alpha:a];
    (void)[self.texFront spriteAtIndex:baseSprite];
    float glyphX0 = (float)(point.x + alpha * kScoreDigitNudge + 6.0);
    for (int i = 0; i < 7; ++i) {
        if ((unsigned char)(digits[i] - kScoreDigitAsciiBase) < 10) {
            float gx = (float)(i * kScoreDigitStride) * kScoreDigitScale;
            NSUInteger sprite = (NSUInteger)(((int)(baseSprite | 0xffffffd0)) + (int)digits[i]);
            [self.texFront
                drawSprite:sprite
                   atPoint:CGPointMake((double)(glyphX0 + gx), point.y)
                     scale:(float)kScoreDigitScale
                    rotate:0
                    anchor:CGPointMake((double)glyphX0 + (double)kScoreDigitScale + (double)gx,
                                       point.y)
                 transform:0
                     alpha:a];
        }
    }
}

/** @ghidraAddress 0x18d194 */
- (void)renderShutter:(BOOL)drive {
    // The five shutter-bar column offsets from the screen centre.
    static const int kShutterOffset[] = {-9, 12, 39, 81, 135}; // @ghidraAddress 0x2938d0
    static const float kShutterTensionGain = 181.0f;           // @ghidraAddress 0x2934ac
    static const float kShutterTensionScale = 1.0f / 1024.0f;  // @ghidraAddress 0x292540
    static const double kShutterCentre = 320.0;                // @ghidraAddress 0x28f470

    // The shutter opens with the score's tension, oscillating on the beat (haku) phase. A replay
    // backup does not drive it.
    float tension = 0.0f;
    double phase = 0.0;
    if (self.sequence != nil) {
        if (self.scoreBackup) {
            return;
        }
        const ScoreData *score = [self.sequence getScore];
        phase = (double)self.sequence.hakuPhase * g_dPi;
        if (score != nullptr) {
            tension = (float)score->tension;
        }
    }

    if (drive) {
        float open = tension * kShutterTensionGain * kShutterTensionScale;
        if (open > 0.0f) {
            float bounce = tension * 10.0f * kShutterTensionScale + 15.0f;
            open = open + (bounce - bounce * (float)sin(phase));
        }
        // A one-pole low-pass toward the target so the bars ease rather than snap.
        shutterOpen = (open + shutterOpen) * 0.5f;
    }

    // The bars sweep out from the centre (nudged down on the taller four-inch screen).
    double centre = kShutterCentre;
    if (self.is4Inch) {
        centre = (double)([self buttonMarginForScreen40] + 0x140);
    }

    // Sprite 1's width sets how far each bar starts inset from the centre.
    double barWidth = [self.texBeatBg spriteAtIndex:1].size.width;
    double left = centre - barWidth;
    for (int i = 0; i < 5; ++i) {
        int sprite = (i == 4) ? 3 : i;
        // The left half, mirrored (transform 2), pulled in by the column offset and the shutter.
        [self.texBeatBg drawSprite:(NSUInteger)sprite
                           atPoint:CGPointMake(0.0,
                                               (double)(float)(left - (double)kShutterOffset[i] -
                                                               (double)shutterOpen))
                         transform:2
                             alpha:1.0f];
        // The right half, pushed out by the same amount.
        [self.texBeatBg drawSprite:(NSUInteger)sprite
                           atPoint:CGPointMake(0.0,
                                               (double)(float)(centre + (double)kShutterOffset[i] +
                                                               (double)shutterOpen))
                         transform:0
                             alpha:1.0f];
    }
}

/** @ghidraAddress 0x18c3a4 */
- (void)renderStartMark:(float)alpha {
    static const double kCellPitch = 0x50;     // 80: the 4x4 panel grid pitch
    static const double kCellCentre = 6;       // the |6 pixel centre within a cell
    static const double kGridTopOffset = 0xa0; // 160: the grid's top offset below the upper region
    static const double kClipInset = 5.0;      // the -5 clip-area inset
    static const double kClipSize = 75.0;      // @ghidraAddress 0x28f788: the 75x75 clip area
    static const double kMarkYOffset = 46.0;   // @ghidraAddress 0x28f740: the lower-mark Y offset
    static const double kMarkerSpriteSize = 80.0; // @ghidraAddress 0x28f3f8
    static const float kSweepFrom = -100.0f;      // @ghidraAddress 0x2934a4
    static const float kSweepTo = 100.0f;         // @ghidraAddress 0x28f4e0
    // The clipped-sprite atlas indices for the start-mark burst.
    enum { kSpriteBurstMid = 0x1e, kSpriteBurstTop = 0x1f, kSpriteBurstBottom = 0x1d };

    unsigned int frame = (unsigned int)startMarkFrame;
    // The rise offset (8 -> 0 over frames 4..8) and the fade-in alpha (0 -> 1 over frames 4..8).
    float rise = InterpolateFloatByFrame(8.0f, 0.0f, frame, 4, 8);
    float fadeIn = InterpolateFloatByFrame(0.0f, 1.0f, frame, 4, 8) * alpha;
    // The pulse, cycling every 120 frames: up over 0..50, then down over 50..80.
    unsigned int cyc = (unsigned int)(float)((int)frame % 0x78);
    float pulse = InterpolateFloatByFrame(0.0f, 1.0f, cyc, 0, 0x32);
    if ((int)frame > 0x32) {
        pulse = InterpolateFloatByFrame(1.0f, 0.0f, cyc, 0x32, 0x50);
    }
    // The horizontal sweep, -100 -> 100 over frames 0..80.
    float sweep = InterpolateFloatByFrame(kSweepFrom, kSweepTo, cyc, 0, 0x50);

    for (unsigned int i = 0; i < 16; ++i) {
        if (([self.sequence firstMarker] & (1 << (i & 0x1f))) == 0) {
            continue;
        }
        double cellX = (double)((int)((i % 4) * (int)kCellPitch) | (int)kCellCentre);
        int margin = self.is4Inch ? [self buttonMarginForScreen40] : 0;
        double cellY = (double)((((int)(i >> 2) * (int)kCellPitch) | (int)kCellCentre) + margin +
                                (int)kGridTopOffset);
        double areaX = cellX - kClipInset;
        double areaY = cellY - kClipInset;
        CGRect area = CGRectMake(areaX, areaY, kClipSize, kClipSize);

        // The rising burst behind the marker.
        [self drawClip:kSpriteBurstMid
            drawPosition:CGPointMake(cellX, cellY + 15.0)
                drawArea:area
                   alpha:fadeIn];
        [self drawClip:kSpriteBurstTop
            drawPosition:CGPointMake((double)sweep + cellX, cellY + 15.0)
                drawArea:area
                   alpha:pulse * alpha];
        [self drawClip:kSpriteBurstBottom
            drawPosition:CGPointMake(cellX, cellY + kMarkYOffset)
                drawArea:area
                   alpha:fadeIn];
        [self drawClip:kSpriteBurstMid
            drawPosition:CGPointMake(cellX - (double)(sweep / 5.0f), cellY + kMarkYOffset)
                drawArea:area
                   alpha:pulse * alpha];

        // The first-marker sprite itself, rising into place; the anchor is the cell's far corner.
        [self.texFront drawSprite:3
                          atPoint:CGPointMake(cellX, cellY - (double)rise)
                            scale:1.0f
                           rotate:0
                           anchor:CGPointMake(cellX + kMarkerSpriteSize, cellY + kMarkerSpriteSize)
                        transform:3
                            alpha:fadeIn];
    }
    startMarkFrame = startMarkFrame + 1;
}

/** @ghidraAddress 0x18e810 */
- (void)renderTuneInfo:(CGPoint)point artworkSize:(double)artworkSize alpha:(double)alpha {
    // The per-difficulty level-digit x-nudge, indexed by isRetina: extreme, advanced, basic, and
    // the default fallback.
    static const double kLevelNudgeExtreme[] = {92.0, 73.0};   // @ghidraAddress 0x293560
    static const double kLevelNudgeAdvanced[] = {102.0, 81.0}; // @ghidraAddress 0x293570
    static const double kLevelNudgeBasic[] = {63.0, 50.0};     // @ghidraAddress 0x293580
    static const double kLevelNudgeDefault[] = {46.0, 36.0};   // @ghidraAddress 0x293590
    static const double kDiffWordDrop = 32.0;                  // @ghidraAddress 0x28f458
    static const NSUInteger kSpriteJacket = 0xb;
    static const NSUInteger kSpriteJacketFrame = 0xc;
    static const NSUInteger kSpriteLevelDigit = 0x13;

    float a = (float)alpha;

    // The jacket, sized to artworkSize.
    [self.texFront drawSprite:kSpriteJacket
                       inRect:CGRectMake(point.x, point.y, artworkSize, artworkSize)
                    transform:0
                        alpha:a];

    // The jacket frame, inset a few points.
    double frameX = point.x + artworkSize;
    double frameY = point.y + 4.0;
    [self.texFront drawSprite:kSpriteJacketFrame
                      atPoint:CGPointMake(frameX + 5.0, frameY - 5.0)
                    transform:0
                        alpha:a];

    // The difficulty word, chosen by the chart difficulty, and the level digits.
    double wordX = frameX + 8.0;
    double wordY = frameY + kDiffWordDrop;
    int diff = (int)self.rendererConf.diff;
    NSUInteger wordSprite;
    const double *nudge;
    if (diff == 2) {
        wordSprite = 0xf;
        nudge = kLevelNudgeExtreme;
    } else if (diff == 1) {
        wordSprite = 0xe;
        nudge = kLevelNudgeAdvanced;
    } else if (diff == 0) {
        wordSprite = 0xd;
        nudge = kLevelNudgeBasic;
    } else {
        wordSprite = 0x10;
        nudge = kLevelNudgeDefault;
    }
    [self.texFront drawSprite:wordSprite atPoint:CGPointMake(wordX, wordY) transform:0 alpha:a];

    double levelX = nudge[isRetina ? 1 : 0];
    double levelYLift = isRetina ? 3.0 : 4.0;
    [self.texFront drawSprite:kSpriteLevelDigit
                      atPoint:CGPointMake(wordX + levelX, wordY - levelYLift)
                    transform:0
                        alpha:a];
}

/** @ghidraAddress 0x18d92c */
- (void)renderUpdatedScore:(unsigned int)score atPoint:(CGPoint)point alpha:(double)alpha {
    static const double kScoreDigitScale = 1.2; // @ghidraAddress 0x292f38
    static const int kScoreDigitCount = 7;
    static const NSUInteger kScoreLeadSprite = 0x36;  // 54: the leading plate
    static const NSUInteger kScoreTrailSprite = 0x35; // 53: the trailing plate
    static const char kScoreDigitAsciiBase = 0x30;    // '0'; sprite = digit + 6

    if (score == 0) {
        return;
    }
    if (self.scoreBackup) {
        return;
    }

    // The digit spacing scales with the passed alpha; the glyphs and plates are drawn at 1.2x.
    double spacing = alpha * kScoreDigitScale;
    (void)[self.texFront spriteAtIndex:kScoreLeadSprite];

    char digits[8];
    snprintf(digits, 8, "%7d", score);

    int lastDigitIndex = -1;
    for (int i = 0; i < kScoreDigitCount; ++i) {
        if ((unsigned char)(digits[i] - kScoreDigitAsciiBase) < 10) {
            NSUInteger sprite = (NSUInteger)((int)digits[i] + 6);
            CGRect s = [self.texFront spriteAtIndex:sprite];
            [self.texFront drawSprite:sprite
                               inRect:CGRectMake(point.x + spacing * (double)(i + 1) + 1.0,
                                                 point.y,
                                                 s.size.width * kScoreDigitScale,
                                                 s.size.height * kScoreDigitScale)
                            transform:0
                                alpha:(float)alpha];
        } else {
            lastDigitIndex = i;
        }
    }

    // The trailing plate at the position of the last leading blank.
    (void)[self.texFront spriteAtIndex:kScoreTrailSprite];
    CGRect trail = [self.texFront spriteAtIndex:kScoreTrailSprite];
    [self.texFront drawSprite:kScoreTrailSprite
                       inRect:CGRectMake(point.x + spacing * (double)(lastDigitIndex + 1) + 1.0,
                                         point.y,
                                         trail.size.width * kScoreDigitScale,
                                         trail.size.height * kScoreDigitScale)
                    transform:0
                        alpha:(float)alpha];
}

/** @ghidraAddress 0x18ec9c */
- (void)renderUpper {
    // The artwork size per 4-inch idiom: 80 points on the tall screen, 88 on the standard one.
    static const double kArtworkSize[] = {80.0, 88.0}; // @ghidraAddress 0x292770
    static const double kTuneInfoX = 8.0;
    static const double kTuneInfoYDefault = 10.0;
    static const double kScoreX = 140.0;           // @ghidraAddress 0x28f6a8
    static const double kScoreYDefault = 101.0;    // @ghidraAddress 0x293520
    static const double kMusicBarYDefault = 136.0; // @ghidraAddress 0x28f768
    static const double kPartnerX = 192.0;         // @ghidraAddress 0x28fa00
    static const double kPartnerYDefault = 75.0;   // @ghidraAddress 0x28f788
    static const double kPartnerScale = 0.7;       // @ghidraAddress 0x291c98
    // On the 4-inch screen the upper region is taller, so each element is nudged down by a
    // fraction of the extra height (upperBgHeight40).

    // The tune info (jacket, title, difficulty).
    double tuneInfoY = kTuneInfoYDefault;
    double artworkSize = kArtworkSize[0];
    if (self.is4Inch) {
        tuneInfoY = (double)((self.upperBgHeight40 >> 2) + 10);
        artworkSize = kArtworkSize[self.is4Inch];
    }
    [self renderTuneInfo:CGPointMake(kTuneInfoX, tuneInfoY) artworkSize:artworkSize alpha:1.0];

    // The music bar at x=0, y=136 (nudged down on the 4-inch screen); the timeline flag is set
    // only in the play state.
    double musicBarY = kMusicBarYDefault;
    if (self.is4Inch) {
        musicBarY = (double)(self.upperBgHeight40 + 0x83);
    }
    [self renderMusicBar:CGPointMake(0.0, musicBarY) timeline:(self.state == 3) alpha:1.0];

    // The score: the live score, or the replay backup's total when a backup is active.
    unsigned int score = 0;
    if (self.sequence != nil) {
        score = (unsigned int)[self.sequence getScore]->point;
    }
    if (self.scoreBackup) {
        score = (unsigned int)[self replayBackupScore].totalPoint;
    }
    double scoreY = kScoreYDefault;
    if (self.is4Inch) {
        scoreY = (double)(self.upperBgHeight40 + 0x60);
    }
    [self renderScore:score atPoint:CGPointMake(kScoreX, scoreY) alpha:1.0];

    // The partner's score in versus play.
    unsigned int partnerScore = self.partnerScore;
    double partnerY = kPartnerYDefault;
    if (self.is4Inch) {
        partnerY = (double)(self.upperBgHeight40 + 0x46);
    }
    [self renderPartnerScore:partnerScore
                     atPoint:CGPointMake(kPartnerX, partnerY)
                       scale:kPartnerScale
                       alpha:1.0];
}

/** @ghidraAddress 0x18eb04 */
- (void)renderUpperBG:(BOOL)isResult {
    // For each of the sixteen panels currently pressed (the btnDown bitmask), ripple the knit
    // upper background up at that panel's grid cell (row = i >> 2, column = i % 4).
    int pressed = [self btnDown];
    for (unsigned int i = 0; i < 16; ++i) {
        if ((pressed & (1 << (i & 0x1f))) != 0) {
            [self.upperBgKnt riseUp:(int)i >> 2 riseColumn:(int)i % 4];
        }
    }

    // The tension drives the background's intensity; it is read from the live score unless a
    // replay backup is active, in which case it holds at zero.
    int tension = 0;
    if (self.sequence != nil) {
        const ScoreData *score = [self.sequence getScore];
        if (score != nullptr) {
            tension = score->tension;
        }
    }
    if (self.scoreBackup) {
        tension = 0;
    }

    [self.upperBgKnt renderUpperBg:self.texWaveAr tension:tension isResult:isResult];
}

@end
