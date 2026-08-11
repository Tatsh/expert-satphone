#import "MainGameRendererPhone.h"

#import <math.h>
#import <stdio.h>

#import <Foundation/Foundation.h>
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
#import "cipher_keys.h"
#import "combo_display.h"
#import "neEngineBridge.h"

// The render-state values this renderer dispatches on.
enum {
    MainGamePhoneStatePreStart = 1, // The pre-start intro.
    MainGamePhoneStateReady = 2,    // The ready/go countdown before play.
    MainGamePhoneStatePlaying = 3,  // Active play.
    MainGamePhoneStateFinish = 4,   // The finish transition.
    MainGamePhoneStateResult = 5,   // The result screen.
    MainGamePhoneStateResult2 = 6,  // The second result sub-screen.
};

// The sub-state value that marks the play session as finished.
static const unsigned int kMainGamePhoneEndSubState = 99;

// The 4x4 grid geometry: sixteen panels on a 0x50-point pitch, below the upper region.
enum {
    kGridColumns = 4,
    kGridPitch = 0x50,
    kGridTopOffset = 0xa0,
    kMarkerPixelCentre = 6,
};

// The extra vertical shift the four-inch phone applies below the game area, added to
// buttonMarginForScreen40 or upperBgHeight40.
enum {
    kFourInchGameTop = 0xa0,        // Game area top on the four-inch phone.
    kFourInchScoreTop = 0x140,      // Score board top on the four-inch phone.
    kFourInchUpperTop = 0x84,       // Upper region top on the four-inch phone.
    kFourInchComboTop = 0xfa,       // Combo top on the four-inch phone.
    kFourInchComboCountTop = 0x17a, // Combo-count top on the four-inch phone.
};

// Combo scale reference: the animation curves are expressed against a 0.75 base scale.
static const float kComboBaseScale = 0.75f;

// The default (non-four-inch) upper-background bottom edge, 160 points. @ghidraAddress 0x28f438
static const double kUpperBGBottomDefault = 160.0;
// The default good-job/twitter/store button-Y bias, 80 points. @ghidraAddress 0x28f3f8
static const double kButtonPositionYBias = 80.0;
// The default game-area offset on the four-inch phone, 160 points. @ghidraAddress 0x28f438
static const double kGameAreaOffsetDefault = 160.0;

// The button-position grid: 0x50-point pitch with a 0x28-point half-cell inset.
enum {
    kButtonGridPitch = 0x50,
    kButtonGridInset = 0x28,
};

// The ready-go countdown duration, 3 1/3 seconds. @ghidraAddress 0x2924d0
static const double kDurationOfReadyGo = 3.3333333333333335;

// The upper-background band is 32 texels wide per tile and 10 tall, tiled across the 0x140-point
// width in 0x20-point steps.
enum {
    kUpperBGTileWidth = 0x20, // The width step per filler tile, in points.
    kUpperBGTileSpan = 0x140, // The total filler span, in points.
};
static const double kUpperBGRegionWidth = 32.0; // @ghidraAddress 0x28f458
static const double kUpperBGRegionHeight = 10.0;

// The result-screen replay-swap animation duration, 0.3 seconds. @ghidraAddress 0x28f260
static const double kReplayFadeDuration = 0.3;

// The result-state replay chip resource swapped into front-atlas sprite 8.
static NSString *const kReplayChipResource = @"game_start_mark_pn2";

// The music-bar cell count and the fade window that keeps the cursor's own cell dim.
enum { kMusicBarCellCount = 0x78 };
static const float kMusicBarCellFadeEnd = 1.2999999523162842f; // @ghidraAddress 0x292558

// The music-bar per-grade base sprite indices, indexed by the two-bit grade (xor 2). Read from
// 0x2927b0.
static const int kMusicBarGradeSprite[] = {82, 66, 90, 74};

// The score-board chip's peak alpha (0.7) and its right-anchored edge (320 points).
static const float kScoreBoardAlphaCap = 0.699999988079071f; // @ghidraAddress 0x28f3bc
static const double kScoreRightEdge = 320.0;                 // @ghidraAddress 0x28f470

// The four-inch phone stretches the score run to 1.3x; the partner run is 0.7 of the player's.
static const double kScoreWidthScale = 1.2999999523162842;  // @ghidraAddress 0x28f718
static const double kPartnerScoreScale = 0.699999988079071; // @ghidraAddress 0x291c98

// The finish curtain wipes in at 0.06 opacity per frame, and its sub-state advances at frame 60.
static const float kFinishWipeRate = 0.05999999865889549f; // @ghidraAddress 0x29258c
static const unsigned int kFinishDoneSubState = 10;

// The pre-start elements ease in by 0.1 of the remaining gap per frame; the intro advances the
// sub-state at frame 0x2d.
static const float kPreStartFadeStep = -0.10000000149011612f; // @ghidraAddress 0x292560
static const unsigned int kPreStartDoneSubState = 10;

// The cleared/failed curtain scales down from 2.8 to 1.48 as it opens.
static const float kClearedCurtainOpen = 2.799999952316284f;   // @ghidraAddress 0x292594
static const float kClearedCurtainClose = 1.4800000190734863f; // @ghidraAddress 0x292590

// The result screen's tune-info slide-out fade step and the new-record bonus fade step.
static const float kResultBonusFadeStep = -0.07999999821186066f; // @ghidraAddress 0x2925ac
// The cleared/failed animation's vertical centre (140 points).
static const double kResultClearCentreY = 140.0; // @ghidraAddress 0x28f6a8
// The clear threshold: 700,000 points separates cleared from failed.
enum { kResultClearThreshold = 700000 };
// The result-state new-record and rating chip layout constants.
static const double kResultRatingX = 88.0;   // @ghidraAddress 0x292400
static const double kResultRatingX2 = 168.0; // @ghidraAddress 0x292710
static const double kResultActionX = 246.0;  // @ghidraAddress 0x292720
static const double kResultVoteX = 166.0;    // @ghidraAddress 0x292728
static const float kResultVoteY = 166.0f;    // @ghidraAddress 0x29275c
static const double kResultRecordX = 316.0;  // @ghidraAddress 0x2927a0
static const double kResultRecordX2 = 309.0; // @ghidraAddress 0x2927a8
// The new-record score-Y bias per idiom.
static const float kResultRecordYBias = 47.0f;  // @ghidraAddress 0x292718
static const float kResultRecordYBias2 = 41.0f; // @ghidraAddress 0x29271c
// The result-state replay chip resources for the level-vote button (sprite 8).
static NSString *const kResultVoteChip = @"game_level_vote_pn2";  // @ghidraAddress 0x2dc240
static NSString *const kResultVoteChipPn = @"game_level_vote_pn"; // @ghidraAddress 0x2dc260
// The good-job overlay fade duration, 0.3 seconds. @ghidraAddress 0x28f260
static const double kResultOverlayFadeDuration = 0.3;

// The result slide-up distance (80 points) and title-chip slide-in start (700 points).
static const float kResultSlideStep = 80.0f;   // @ghidraAddress 0x28e018
static const float kResultTitleSlide = 700.0f; // @ghidraAddress 0x292758

// The new-record banner pulse: cos * 0.3 + 0.7.
// A 0.3 __const literal-pool slot (the same value combo_display uses for its fade base, but a
// distinct local reference here); the binary loads it inline in renderMusicBar: and renderResult.
static const float kComboFadeBase = 0.30000001192092896f; // @ghidraAddress 0x28e0b0
static const float kRecordPulseBias = 0.699999988079071f; // @ghidraAddress 0x28f3bc

// The marker lead-in fade runs over 100 frames after the intro.
static const float kMarkerLeadInFrames = 100.0f; // @ghidraAddress 0x28f4e0

// Pi and the ready/go 0.4 key time, used by the ready/go countdown.
static const double g_dPi = 3.141592653589793;             // @ghidraAddress 0x28f278
static const float kReadyKeyTime040 = 0.4000000059604645f; // @ghidraAddress 0x28f3b4

// The ready circle's swell factor (1.32) and base size (95 points), and its mark positions.
static const float kReadyCircleSwell = 1.3200000524520874f; // @ghidraAddress 0x292564
static const double kReadyCircleSize = 95.0;                // @ghidraAddress 0x292700
static const double kReadyMarkTopOffset = -95.0;            // @ghidraAddress 0x292708
static const double kReadyMarkX = 77.0;                     // @ghidraAddress 0x291be0
static const double kReadyMarkX2 = 65.0;                    // @ghidraAddress 0x291bc0

// The combo cut-in overlay's full size (320 points) and its board top on the non-four-inch phone
// (160 points).
static const float kComboCutInSize = 320.0f; // @ghidraAddress 0x292734
static const float kComboBoardTop = 160.0f;  // @ghidraAddress 0x28e014

// The combo-burst position mapping: (animPos * 320) / 768 - 160.
static const double kComboBurstDenom = 768.0; // @ghidraAddress 0x292460
static const double kComboBurstBias = -160.0; // @ghidraAddress 0x2926d8

// The tension-energy smoothing scales and per-beat wobble frequency.
static const float kTensionEnergyScaleA = 185.0f;           // @ghidraAddress 0x292730
static const float kTensionEnergyScaleB = 0.0009765625f;    // @ghidraAddress 0x292540
static const double kTensionBeatOmega = -3.141592653589793; // @ghidraAddress 0x292478

// The non-four-inch measure-phase slide scale (160 points).
static const float kBgMeasureScale = 160.0f; // @ghidraAddress 0x28e014

// The combo-word chip top: 378 points on the non-four-inch phone, and a +0x17a offset on the
// four-inch phone.
static const double kComboWordTop = 378.0; // @ghidraAddress 0x2926e0
enum { kComboWordTop4Inch = 0x17a };

// The combo digit x-layout tables, indexed by digit count minus one (1..3 digits). Read from
// 0x2928d0 (step) and 0x2928f0 (base).
static const double kComboDigitStepX[] = {90.0, 90.0, 85.0};
static const double kComboDigitBaseX[] = {120.0, 75.0, 35.0};

// The maximum difficulty and level the configuration is clamped to before texture load.
enum {
    kMaxDifficulty = 3, // conf.diff clamp (0x10a5e8, cmp #4).
    kMaxLevel = 10,     // conf.level clamp (0x10a618, cmp #0xb).
};

// Ranks 0..8 have rating overlays; rank >= 9 loads only the base rating texture.
enum { kRatingRankCount = 9 };

// The square texel dimension of each atlas texture.
enum {
    kFrontTexturePixelSize = 0x400, // texFront.
    kAtlasPixelSize = 0x800,        // texMarker, texHoldMarker, texCombo.
};

// Front-atlas sprite indices.
enum {
    kFrontSpriteStartMark = 8,      // "game_start_mark_pn2".
    kFrontSpriteEndMark = 9,        // "game_end_mark_pn2".
    kFrontSpriteMusicBar = 0xe,     // "game_mbar_%s_pn2".
    kFrontSpriteArtwork = 0xf,      // The jacket artwork.
    kFrontSpriteIndex = 0x10,       // The aspect-fitted index image.
    kFrontSpriteDiffWord = 0x11,    // "game_diff_%s".
    kFrontSpriteLevelWord = 0x12,   // "game_lv_%d".
    kFrontSpritePartnerName = 0x18, // The rendered partner-name label.
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

// Retina renders the partner-name label at 20 points, non-retina at 10.
static const double kPartnerFontSizeRetina = 20.0;
static const double kPartnerFontSize = 10.0;

// Selects the one-letter difficulty abbreviation the front-atlas resource names interpolate.
static inline const char *MainGameRendererPhoneDiffAbbreviation(int diff) {
    // The binary's own single-character difficulty tags, indexed by the clamped difficulty.
    // @ghidraAddress 0x280488
    static const char *const kDiffAbbreviations[] = {"b", "a", "e", "o"};
    return kDiffAbbreviations[diff];
}

// Rebuilds the front atlas and blits its difficulty, music-bar, level, start-mark, and end-mark
// words. De-inlined from the front-atlas section of -loadTexure:artwork:index:.
static inline void MainGameRendererPhoneBuildFrontTexture(MainGameRendererPhone *self,
                                                          RendererConf *conf,
                                                          BFCodec *codec,
                                                          NSData *cipherKey) {
    const char *diffAbbrev = MainGameRendererPhoneDiffAbbreviation(conf.diff);
    self->texFront = [[Texture2D alloc] initWithData:nullptr
                                         pixelFormat:Texture2DPixelFormatRGBA8888
                                           pixelSize:kFrontTexturePixelSize];
    NSString *plist = [NSBundle.mainBundle pathForResource:@"game_front_tex_pn2" ofType:@"plist"];
    [self->texFront setSprites:[[NSArray alloc] initWithContentsOfFile:plist]];
    [codec cipherInit:cipherKey];
    LoadTextureSubImageFromEncryptedTex(
        self->texFront, @"game_front_tex_pn2", codec, CGPointMake(0.0, 0.0));
    NSString *diffWord = [NSString stringWithFormat:@"game_diff_%s", diffAbbrev];
    LoadTextureSubImageFromResource(
        self->texFront, diffWord, [self->texFront spriteAtIndex:kFrontSpriteDiffWord].origin);
    NSString *mbarWord = [NSString stringWithFormat:@"game_mbar_%s_pn2", diffAbbrev];
    LoadTextureSubImageFromResource(
        self->texFront, mbarWord, [self->texFront spriteAtIndex:kFrontSpriteMusicBar].origin);
    NSString *levelWord = [NSString stringWithFormat:@"game_lv_%d", conf.level];
    LoadTextureSubImageFromResource(
        self->texFront, levelWord, [self->texFront spriteAtIndex:kFrontSpriteLevelWord].origin);
    LoadTextureSubImageFromResource(self->texFront,
                                    @"game_start_mark_pn2",
                                    [self->texFront spriteAtIndex:kFrontSpriteStartMark].origin);
    LoadTextureSubImageFromResource(self->texFront,
                                    @"game_end_mark_pn2",
                                    [self->texFront spriteAtIndex:kFrontSpriteEndMark].origin);
}

// Unzips the note-marker frames into the marker atlas: one bank of twenty-four "ma" frames, then
// four banks of sixteen "h" hold frames. De-inlined from the marker section of
// -loadTexure:artwork:index:.
static inline void MainGameRendererPhoneLoadMarkerTexture(MainGameRendererPhone *self,
                                                          RendererConf *conf,
                                                          BFCodec *codec,
                                                          NSData *cipherKey) {
    // The base sprite index for each of the four "h" hold banks. @ghidraAddress 0x2927c0
    static const int kHoldBankBase[] = {0x18, 0x28, 0x38, 0x48};
    @autoreleasepool {
        if (self->texMarker) {
            self->texMarker = nil;
        }
        self->texMarker = [[Texture2D alloc] initWithData:nullptr
                                              pixelFormat:Texture2DPixelFormatRGBA8888
                                                pixelSize:kAtlasPixelSize];
        NSString *plist = [NSBundle.mainBundle pathForResource:@"game_marker_tex_pn2"
                                                        ofType:@"plist"];
        [self->texMarker setSprites:[[NSArray alloc] initWithContentsOfFile:plist]];
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
                [self->texMarker setSubImage:image inRect:[self->texMarker spriteAtIndex:i]];
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
                    [self->texMarker setSubImage:image
                                          inRect:[self->texMarker spriteAtIndex:spriteIndex]];
                }
            }
        }
    }
    self->texMarker.isScale2x = self->isRetina;
}

// Builds the hold-marker atlas and its sub-renderer, then unzips the "m" and "m6" hold-marker
// frames from hm0001.zip. De-inlined from the hold-marker section of -loadTexure:artwork:index:.
static inline void MainGameRendererPhoneBuildHoldMarkerTexture(MainGameRendererPhone *self,
                                                               BFCodec *codec,
                                                               NSData *cipherKey) {
    @autoreleasepool {
        if (self->texHoldMarker) {
            self->texHoldMarker = nil;
        }
        self->texHoldMarker = [[Texture2D alloc] initWithData:nullptr
                                                  pixelFormat:Texture2DPixelFormatRGBA8888
                                                    pixelSize:kAtlasPixelSize];
        NSString *plist = [NSBundle.mainBundle pathForResource:@"game_hold_marker_tex"
                                                        ofType:@"plist"];
        [self->texHoldMarker setSprites:[[NSArray alloc] initWithContentsOfFile:plist]];
        [codec cipherInit:cipherKey];
        if (!self->holdMarkerRender) {
            // The game area is delayed on the four-inch idiom by the phone button margin.
            int gameAreaDelay = self->is4Inch ? self.buttonMarginForScreen40 : 0;
            self->holdMarkerRender = [[HoldMarkerRender alloc] init:self->texHoldMarker
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
                [self->texHoldMarker
                    setSubImage:image
                        atPoint:[self->texHoldMarker spriteAtIndex:spriteIndex].origin];
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
            [self->texHoldMarker
                setSubImage:image
                    atPoint:[self->texHoldMarker spriteAtIndex:spriteIndex].origin];
        }
    }
}

// Blits the jacket artwork, the aspect-fitted index image, and the optional partner-name label
// into the front atlas, then marks it scale-2x. De-inlined from the composite section of
// -loadTexure:artwork:index:.
static inline void MainGameRendererPhoneCompositeFront(MainGameRendererPhone *self,
                                                       RendererConf *conf,
                                                       UIImage *artwork,
                                                       UIImage *index) {
    [self->texFront setSubImage:artwork inRect:[self->texFront spriteAtIndex:kFrontSpriteArtwork]];
    if (index) {
        CGRect frame = [self->texFront spriteAtIndex:kFrontSpriteIndex];
        CGSize size = index.size;
        // Height preserves the index image's aspect ratio within the frame's width.
        [self->texFront setSubImage:index
                             inRect:CGRectMake(frame.origin.x,
                                               frame.origin.y,
                                               frame.size.width,
                                               (frame.size.width * size.height) / size.width)];
    }
    if (conf.partnerName) {
        CGRect labelFrame = [self->texFront spriteAtIndex:kFrontSpritePartnerName];
        UILabel *label = [[UILabel alloc] initWithFrame:labelFrame];
        label.opaque = NO;
        label.backgroundColor = UIColor.clearColor; // The original used +clearColor.
        label.textColor = UIColor.whiteColor;       // The original used +whiteColor.
        label.textAlignment = NSTextAlignmentRight; // 2.
        label.font = [UIFont
            boldSystemFontOfSize:(self->isRetina ? kPartnerFontSizeRetina : kPartnerFontSize)];
        label.text = conf.partnerName;
        UIImage *rendered = [label renderImage];
        [self->texFront setSubImage:rendered
                            atPoint:[self->texFront spriteAtIndex:kFrontSpritePartnerName].origin];
    }
    self->texFront.isScale2x = self->isRetina;
}

// Rebuilds the combo atlas from its encrypted texture. De-inlined from the combo section of
// -loadTexure:artwork:index:.
static inline void MainGameRendererPhoneBuildComboTexture(MainGameRendererPhone *self,
                                                          BFCodec *codec,
                                                          NSData *cipherKey) {
    @autoreleasepool {
        if (self->texCombo) {
            self->texCombo = nil;
        }
        self->texCombo = [[Texture2D alloc] initWithData:nullptr
                                             pixelFormat:Texture2DPixelFormatRGBA8888
                                               pixelSize:kAtlasPixelSize];
        NSString *plist = [NSBundle.mainBundle pathForResource:@"game_combo_tex_pn2"
                                                        ofType:@"plist"];
        [self->texCombo setSprites:[[NSArray alloc] initWithContentsOfFile:plist]];
        [codec cipherInit:cipherKey];
        LoadTextureSubImageFromEncryptedTex(
            self->texCombo, @"game_combo_tex_pn2", codec, CGPointMake(0.0, 0.0));
    }
    self->texCombo.isScale2x = self->isRetina;
}

// Draws one right-aligned seven-digit score run into the front atlas: a background board (sprite
// 0xa) then each digit, every rectangle scaled about a shared anchor. De-inlined from the two
// identical digit loops of -renderScore:partnerScore:atPoint:scaleH:alpha:.
static inline void MainGameRendererPhoneDrawScoreRun(MainGameRendererPhone *self,
                                                     const char digits[8],
                                                     unsigned int shown,
                                                     CGPoint origin,
                                                     double scaleH,
                                                     double alpha,
                                                     CGPoint anchor,
                                                     double widthScale,
                                                     double drawAlpha) {
    // The board rectangle spans the whole run at the passed cell size, scaled about the anchor.
    CGRect board = [Texture2D scaledRect:CGRectMake(origin.x, origin.y, scaleH, alpha)
                                   scale:widthScale
                                  anchor:anchor];
    double boardY = board.origin.y;
    double boardHeight = board.size.height;
    if (scaleH != 1.0) {
        boardY += (1.0 - scaleH) * boardHeight * 0.5;
        boardHeight *= scaleH;
    }
    [self->texFront drawSprite:0xa
                        inRect:CGRectMake(board.origin.x, boardY, board.size.width, boardHeight)
                     transform:0
                         alpha:(float)drawAlpha];
    // A comma appears once the score reaches 0xaae61 (700,001), shifting the digit sprite base.
    long spriteBase = (shown > 0xaae60) ? -0xd : -0x17;
    for (int i = 0; i < 7; ++i) {
        if ((unsigned char)(digits[i] - '0') >= 10) {
            continue;
        }
        // Each digit sits on a per-idiom pitch, offset from the run origin; retina packs them
        // tighter.
        double digitDx = self->isRetina ? 12.0 : 9.0;
        int digitPitch = self->isRetina ? 0x10 : 0x12;
        double digitDy = self->isRetina ? 8.0 : 12.0;
        CGRect digit =
            [Texture2D scaledRect:CGRectMake(origin.x + digitDx + (double)(digitPitch * i),
                                             origin.y + digitDy,
                                             scaleH,
                                             alpha)
                            scale:widthScale
                           anchor:anchor];
        double digitY = digit.origin.y;
        double digitHeight = digit.size.height;
        if (scaleH != 1.0) {
            digitY += (1.0 - scaleH) * digitHeight * 0.5;
            digitHeight *= scaleH;
        }
        [self->texFront drawSprite:((long)digits[i] + spriteBase)
                            inRect:CGRectMake(digit.origin.x, digitY, digit.size.width, digitHeight)
                         transform:0
                             alpha:(float)drawAlpha];
    }
}

// Draws one "GO" mark half (sprite 5 or 6): it appears at frame 0x45/0x47, scales from the key
// time to 2.0 then back to 1.0, sliding across per-frame x-positions, and fades out from 0x5a.
// De-inlined from the two identical GO passes of -renderReadyGo.
static inline void MainGameRendererPhoneRenderGoMark(
    MainGameRendererPhone *self, NSUInteger sprite, int spriteW, int spriteH, int centreY) {
    // Each half has a distinct start frame and x-position keyframes.
    unsigned int start = (sprite == 5) ? 0x47 : 0x47;
    // Sprite 5 and 6 differ in their appear window and x keyframes.
    unsigned int appearStart = (sprite == 5) ? 0x45 : 0x47;
    (void)start;
    float alpha;
    if (self->frame < 0x5a) {
        alpha = InterpolateFloatByFrame(0.0f, 1.0f, self->frame, appearStart, appearStart + 5);
    } else {
        alpha = InterpolateFloatByFrame(1.0f, 0.0f, self->frame, 0x5a, 0x5e);
    }
    if (alpha <= 0.0f) {
        return;
    }
    // The x-position keyframes and scale ramp differ per half.
    double scale;
    float x;
    if (sprite == 5) {
        if (self->frame < 0x4a) {
            scale =
                (double)InterpolateFloatByFrame(kReadyKeyTime040, 2.0f, self->frame, 0x45, 0x4a);
            x = InterpolateFloatByFrame(138.0f, 95.0f, self->frame, 0x45, 0x4a);
        } else if (self->frame < 0x5a) {
            scale = (double)InterpolateFloatByFrame(2.0f, 1.0f, self->frame, 0x4a, 0x4c);
            x = InterpolateFloatByFrame(95.0f, 117.0f, self->frame, 0x4a, 0x4c);
        } else {
            scale = 1.0;
            x = InterpolateFloatByFrame(117.0f, 60.0f, self->frame, 0x5a, 0x5e);
        }
    } else {
        if (self->frame < 0x4c) {
            scale =
                (double)InterpolateFloatByFrame(kReadyKeyTime040, 2.0f, self->frame, 0x47, 0x4c);
            x = InterpolateFloatByFrame(180.0f, 224.0f, self->frame, 0x47, 0x4c);
        } else if (self->frame < 0x5a) {
            scale = (double)InterpolateFloatByFrame(2.0f, 1.0f, self->frame, 0x4c, 0x4e);
            x = InterpolateFloatByFrame(224.0f, 201.0f, self->frame, 0x4c, 0x4e);
        } else {
            scale = 1.0;
            x = InterpolateFloatByFrame(201.0f, 258.0f, self->frame, 0x5a, 0x5e);
        }
    }
    [self->texReady drawSprite:sprite
                        inRect:CGRectMake((double)x - (double)spriteW * scale * 0.5,
                                          (double)centreY - (double)spriteH * scale * 0.5,
                                          (double)spriteW * scale,
                                          (double)spriteH * scale)
                     transform:0
                         alpha:alpha];
}

// Draws the result screen's white finish curtain (a 48-column wipe plus four centred message
// banners) during its opening frames. De-inlined from -renderResult.
static inline void
MainGameRendererPhoneRenderResultCurtain(MainGameRendererPhone *self, double slide, float wipe) {
    for (int columnX = 0; columnX < 0x300; columnX += 0x10) {
        int gameTop =
            self->is4Inch ? (self.buttonMarginForScreen40 + kFourInchGameTop) : kFourInchGameTop;
        [self->texFront drawSprite:2
                           atPoint:CGPointMake((double)columnX, slide + (double)gameTop)
                         transform:1
                             alpha:wipe];
    }
    CGRect banner = [self->texFront spriteAtIndex:2];
    double centreX = (kScoreRightEdge - banner.size.width) * 0.5;
    double centreYBias = (kButtonPositionYBias - banner.size.height) * 0.5;
    static const int kBandNonFourInch[] = {0xa0, 0xf0, 0x140, 0x190};
    for (int band = 0; band < 4; ++band) {
        int gameTop = self->is4Inch ? (self.buttonMarginForScreen40 + kBandNonFourInch[band]) :
                                      kBandNonFourInch[band];
        [self->texFront drawSprite:2
                           atPoint:CGPointMake(centreX, slide + centreYBias + (double)gameTop)
                         transform:2
                             alpha:wipe];
    }
}

@implementation MainGameRendererPhone

#pragma mark - Lifecycle

/** @ghidraAddress 0x10a3c0 */
- (instancetype)init {
    self = [super init];
    if (self) {
        isRetina = JubeatAppDelegate.appDelegate.isPhoneRetina;
        is4Inch = JubeatAppDelegate.appDelegate.is4inchAspect;
    }
    return self;
}

/** @ghidraAddress 0x111518 */
- (void)dealloc {
    [self releaseTexture];
    // The superclass dealloc runs after; ARC synthesises .cxx_destruct for the strong ivars.
}

#pragma mark - Textures

/** @ghidraAddress 0x10a490 */
- (void)loadTexure:(RendererConf *)conf artwork:(UIImage *)artwork index:(UIImage *)index {
    NSData *cipherKey = CreateTextureCipherKey();
    BFCodec *codec = [[BFCodec alloc] init];
    if (!texDebugFont) {
        texDebugFont = CreateTexture2DFromPngResource(@"debugfont");
    }
    if (!texReady) {
        [codec cipherInit:cipherKey];
        // Retina uses the bare name; non-retina uses the "_pn" variant.
        NSString *readyName = isRetina ? @"game_ready_tex" : @"game_ready_tex_pn";
        texReady = CreateTexture2DFromEncryptedTexResource(readyName, codec);
        texReady.isScale2x = isRetina;
    }
    if (conf.diff > kMaxDifficulty) {
        conf.diff = kMaxDifficulty;
    }
    if (conf.level > kMaxLevel) {
        conf.level = kMaxLevel;
    }
    // The front atlas is rebuilt unless the requested marker, difficulty, level, and tune all
    // match the one already loaded.
    if (texFront && [conf.markerID isEqualToString:self.rendererConf.markerID] &&
        conf.diff == self.rendererConf.diff && conf.level == self.rendererConf.level &&
        conf.tuneID == self.rendererConf.tuneID) {
        return;
    }
    if (texFront) {
        texFront = nil;
    }
    MainGameRendererPhoneBuildFrontTexture(self, conf, codec, cipherKey);
    MainGameRendererPhoneLoadMarkerTexture(self, conf, codec, cipherKey);
    MainGameRendererPhoneBuildHoldMarkerTexture(self, codec, cipherKey);
    MainGameRendererPhoneCompositeFront(self, conf, artwork, index);
    MainGameRendererPhoneBuildComboTexture(self, codec, cipherKey);
    self.rendererConf = conf;
}

/** @ghidraAddress 0x10b680 */
- (void)loadRatingTex:(short)rank {
    // The rank-specific overlay PNGs, indexed by rank 0..8. Rank >= 9 draws no overlay.
    // @ghidraAddress 0x2dbd00
    static NSString *const kRankOverlayNames[] = {
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
    if (texRating) {
        texRating = nil;
    }
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:CreateTextureCipherKey()];
    NSString *baseName = isRetina ? @"game_rating_tex_pn2" : @"game_rating_tex_pn";
    texRating = CreateTexture2DFromEncryptedTexResource(baseName, codec);
    if (rank < kRatingRankCount) {
        // A 9-way jump table picks the rank overlay name; every arm falls to this common blit.
        NSString *path = [NSBundle.mainBundle pathForResource:kRankOverlayNames[rank]
                                                       ofType:@"png"];
        if (path) {
            UIImage *overlay = [[UIImage alloc] initWithContentsOfFile:path];
            [texRating setSubImage:overlay inRect:[texRating spriteAtIndex:0]];
        }
    }
    texRating.isScale2x = isRetina;
}

/** @ghidraAddress 0x10b8e8 */
- (void)releaseTexture {
    texDebugFont = nil;
    texFront = nil;
    texReady = nil;
    texRating = nil;
    texClear0 = nil;
    texClear1 = nil;
    texClear2 = nil;
    // Note: texMarker, texHoldMarker, and texCombo are deliberately not released here, matching the
    // binary.
}

#pragma mark - Play lifecycle

/** @ghidraAddress 0x10b98c */
- (void)setState:(unsigned int)state {
    if (state == MainGamePhoneStateResult) {
        // Entering the result screen loads the rating and cleared-screen textures and starts the
        // result BGM.
        [self loadRatingTex:(short)self.sequence.rank];
        BFCodec *codec = [[BFCodec alloc] init];
        NSData *cipherKey = CreateTextureCipherKey();
        if (!texClear0) {
            [codec cipherInit:cipherKey];
            NSString *name = isRetina ? @"game_clear_0_tex_pn2" : @"game_clear_0_tex_pn";
            texClear0 = CreateTexture2DFromEncryptedTexResource(name, codec);
            texClear0.isScale2x = isRetina;
        }
        if (!texClear1) {
            [codec cipherInit:cipherKey];
            NSString *name = isRetina ? @"game_clear_1_tex_pn2" : @"game_clear_1_tex_pn";
            texClear1 = CreateTexture2DFromEncryptedTexResource(name, codec);
            texClear1.isScale2x = isRetina;
        }
        if (!texClear2) {
            [codec cipherInit:cipherKey];
            NSString *name = isRetina ? @"game_clear_2_tex_pn2" : @"game_clear_2_tex_pn";
            texClear2 = CreateTexture2DFromEncryptedTexResource(name, codec);
            texClear2.isScale2x = isRetina;
        }
        [AudioManager.sharedManager loadBgmResAAC:@"SD_BGM_RESULT" inDirectory:nil];
        [AudioManager.sharedManager startBgm:YES fadeTime:0.0];
    } else if (state == MainGamePhoneStateReady || state == 0) {
        lastCombo = 0;
        comboCutFrame = 0;
        comboEffectFrame = 0;
        scoreDisplay = 0;
        shutterOpen = 0.0f;
    }
    // The second result sub-screen (6) preserves the frame counter; every other state resets it.
    if (state != MainGamePhoneStateResult2) {
        frame = 0;
    }
    [super setState:state];
}

/** @ghidraAddress 0x10bcf4 */
- (void)startPlay {
    texReady = nil;
    [self setState:MainGamePhoneStatePlaying];
}

/** @ghidraAddress 0x10bd34 */
- (void)endResult {
    if (self.state == MainGamePhoneStateResult) {
        self.subState = kMainGamePhoneEndSubState;
    }
}

/** @ghidraAddress 0x10e798 */
- (double)durationOfReadyGo {
    return kDurationOfReadyGo;
}

/** @ghidraAddress 0x111568 */
- (void)replayEnd {
    self.replayPlaying = NO;
}

/** @ghidraAddress 0x111578 */
- (void)replaySelect {
    if (!self.isCustom || !self.isDownload || !self.hasMusic) {
        return;
    }
    self.replayPlaying = YES;
    // Swap the front atlas's sprite 8 to the replay chip: turn scale-2x off for the blit, then back
    // on.
    texFront.isScale2x = NO;
    LoadTextureSubImageFromResource(
        texFront, kReplayChipResource, [texFront spriteAtIndex:8].origin);
    texFront.isScale2x = YES;
    self.isTextureChange = NO;
    __weak UIImageView *goodJobImage = self.goodJobImage;
    [UIView animateWithDuration:kReplayFadeDuration
                     animations:^{
                       /** @ghidraAddress 0x111724 */
                       goodJobImage.alpha = 0.0;
                     }
                     completion:^(BOOL finished){
                         /** @ghidraAddress 0x111770 */
                     }];
}

#pragma mark - Layout override points

/** @ghidraAddress 0x10fb28 */
- (double)buttonAreaOffset {
    // Only the result state has a button-area offset: it eases up 0x50 points per frame over the
    // first 20 frames, then holds at 80 points thereafter.
    if (self.state != MainGamePhoneStateResult) {
        return 0.0;
    }
    if (frame < 20) {
        return (double)((float)(frame * kButtonGridPitch) / 20.0f);
    }
    return kButtonPositionYBias; // 80.0 @ghidraAddress 0x28f3f8
}

/** @ghidraAddress 0x10fb94 */
- (double)gameAreaOffset {
    if (is4Inch) {
        return (double)(self.buttonMarginForScreen40 + kFourInchGameTop);
    }
    return kGameAreaOffsetDefault;
}

#pragma mark - Button override points

/** @ghidraAddress 0x10fbd4 */
- (unsigned int)endButtonID {
    return 11;
}

/** @ghidraAddress 0x10fbdc */
- (unsigned int)evaluateButtonID {
    return 10;
}

/** @ghidraAddress 0x10fbe4 */
- (unsigned int)goodJobButtonID {
    return 9;
}

/** @ghidraAddress 0x10fbec */
- (CGPoint)goodJobPosition {
    unsigned int button = self.goodJobButtonID;
    int gameTop = is4Inch ? (self.buttonMarginForScreen40 + kFourInchGameTop) : kFourInchGameTop;
    double x = (double)((button & 3) * kButtonGridPitch + kButtonGridInset);
    double y = (double)((button >> 2) * kButtonGridPitch + kButtonGridInset + gameTop) +
               kButtonPositionYBias;
    return CGPointMake(x, y);
}

/** @ghidraAddress 0x10fc98 */
- (unsigned int)twitterSendButtonID {
    return 10;
}

/** @ghidraAddress 0x10fca0 */
- (CGPoint)twitterBtnPosition {
    unsigned int button = self.twitterSendButtonID;
    int gameTop = is4Inch ? (self.buttonMarginForScreen40 + kFourInchGameTop) : kFourInchGameTop;
    double x = (double)((button & 3) * kButtonGridPitch + kButtonGridInset);
    double y = (double)((button >> 2) * kButtonGridPitch + kButtonGridInset + gameTop) +
               kButtonPositionYBias;
    return CGPointMake(x, y);
}

/** @ghidraAddress 0x10fd4c */
- (unsigned int)storeMoveButtonID {
    return 10;
}

/** @ghidraAddress 0x10fd54 */
- (CGPoint)storeMoveBtnPosition {
    unsigned int button = self.storeMoveButtonID;
    int gameTop = is4Inch ? (self.buttonMarginForScreen40 + kFourInchGameTop) : kFourInchGameTop;
    double x = (double)((button & 3) * kButtonGridPitch + kButtonGridInset);
    double y = (double)((button >> 2) * kButtonGridPitch + kButtonGridInset + gameTop) +
               kButtonPositionYBias;
    return CGPointMake(x, y);
}

#pragma mark - Drawing

/** @ghidraAddress 0x10c17c */
- (void)renderBG {
    int tension = 0;
    unsigned int tier = 0;
    float hakuPhase = 0.0f;
    float measurePhase = 0.0f;
    if (self.sequence) {
        if (self.scoreBackup) {
            return;
        }
        const ScoreData *scoreData = self.sequence.getScore;
        hakuPhase = self.sequence.hakuPhase;
        measurePhase = self.sequence.measurePhase;
        if (scoreData) {
            tension = scoreData->tension;
            // The tension tier steps up at 0x100, 0x200, 0x300, and 0x400.
            tier = 3;
            if (tension >= 0x400) {
                tier = 4;
            }
            unsigned int t2 = (tension >= 0x300) ? tier : 2;
            unsigned int t1 = (tension >= 0x200) ? t2 : 1;
            tier = (tension >= 0x100) ? t1 : 0;
        }
    }
    // The tension background, tier-selected, filling the game area from its top.
    double bgTop =
        is4Inch ? (double)(self.buttonMarginForScreen40 + kFourInchGameTop) : kUpperBGBottomDefault;
    [texCombo drawSprite:(tier + 10)
                  inRect:CGRectMake(0.0, bgTop, kScoreRightEdge, kScoreRightEdge)
               transform:0
                   alpha:1.0f];
    // The combo burst animation: each active frame draws the burst sprite (5) at an eased
    // position and scale.
    float burstScale = EvalComboScaleCurve(hakuPhase, tier);
    int frameCount = GetComboAnimFrameCount(tier);
    for (int animFrame = 0; animFrame < frameCount; ++animFrame) {
        CGPoint animPos = GetComboAnimPosition(tier, animFrame);
        float animScale = GetComboAnimScale(tier, animFrame);
        (void)[texCombo spriteAtIndex:5];
        // The burst sprite is centred on its eased position; its size is the curve scale relative
        // to the 0.75 base.
        double sizeW = (double)burstScale * (double)(animScale / kComboBaseScale) * kScoreRightEdge;
        double sizeH = sizeW;
        int gameTop =
            is4Inch ? (self.buttonMarginForScreen40 + kFourInchGameTop) : kFourInchGameTop;
        double posX = (double)burstScale *
                          ((animPos.x * kScoreRightEdge) / kComboBurstDenom + kComboBurstBias) +
                      bgTop - (sizeW * 0.5);
        double posY = (double)burstScale *
                          ((animPos.y * kScoreRightEdge) / kComboBurstDenom + kComboBurstBias) +
                      bgTop - (sizeH * 0.5) + (double)gameTop;
        float burstAlpha = EvalComboAnimCurve(hakuPhase, tier, animFrame);
        [texCombo drawSprite:5
                      inRect:CGRectMake(posX, posY, sizeW, sizeH)
                   transform:0
                       alpha:burstAlpha];
    }
    // The tension shutter energy, smoothed towards the current tension, with a per-beat wobble.
    float energy = (float)tension * kTensionEnergyScaleA * kTensionEnergyScaleB;
    if (energy > 0.0f) {
        float wobbleBase = (float)tension * 5.0f * kTensionEnergyScaleB + 9.0f;
        double beat = sin((double)hakuPhase * kTensionBeatOmega); // @ghidraAddress 0x292478
        energy = energy + wobbleBase + wobbleBase * (float)beat;
    }
    shutterOpen = (energy + shutterOpen) * 0.5f;
    // The two shutter halves slide apart by the measure phase, and the tension bar closes over
    // them by the shutter-open energy.
    double halfSpan;
    double slide;
    if (is4Inch) {
        halfSpan = (double)(self.buttonMarginForScreen40 + kFourInchScoreTop);
        slide = (double)(measurePhase * (float)(self.buttonMarginForScreen40 + kFourInchGameTop));
    } else {
        halfSpan = kUpperBGBottomDefault;
        slide = (double)(measurePhase * kBgMeasureScale); // @ghidraAddress 0x28e014
    }
    [texCombo
        drawSprite:0
            inRect:CGRectMake(0.0,
                              (halfSpan - (double)shutterOpen) - (double)measurePhase * halfSpan,
                              kScoreRightEdge,
                              slide)
         transform:4
             alpha:1.0f];
    [texCombo drawSprite:0
                  inRect:CGRectMake(0.0,
                                    (double)(measurePhase * kBgMeasureScale) + halfSpan +
                                        (double)shutterOpen,
                                    kScoreRightEdge,
                                    slide)
               transform:4
                   alpha:2.0f];
    // The two shutter cap chips (sprite 3) close the gap top and bottom.
    [texCombo drawSprite:0
                 atPoint:CGPointMake(0.0, halfSpan - (double)shutterOpen)
               transform:3
                   alpha:1.0f];
    (void)[texCombo spriteAtIndex:3];
    [texCombo drawSprite:0
                 atPoint:CGPointMake(0.0, (halfSpan + (double)shutterOpen) - slide)
               transform:3
                   alpha:1.0f];
    double capTop =
        is4Inch ? (double)(self.buttonMarginForScreen40 + kFourInchGameTop) : kBgMeasureScale;
    [texCombo drawSprite:0
                 atPoint:CGPointMake(0.0, capTop - (double)shutterOpen)
               transform:2
                   alpha:1.0f];
    [texCombo drawSprite:0
                 atPoint:CGPointMake(0.0, halfSpan + (double)shutterOpen)
               transform:2
                   alpha:1.0f];
}

/** @ghidraAddress 0x10c78c */
- (void)renderCombo:(unsigned int)combo {
    if (self.scoreBackup) {
        return;
    }
    if (comboEffectFrame != 0) {
        --comboEffectFrame;
    }
    // A drop below five combo triggers the nine-frame cut-in.
    int cutFrame;
    if (combo < lastCombo && lastCombo > 4) {
        cutFrame = 9;
        comboCutFrame = 9;
    } else {
        cutFrame = (int)comboCutFrame;
    }
    if (cutFrame != 0) {
        if (self.showCombo) {
            // The cut-in overlay scales in and fades over its nine frames.
            float scale = GetComboScaleFactor((unsigned int)(9 - cutFrame)) * kComboCutInSize;
            float inset = (kComboCutInSize - scale) * 0.5f;
            float boardTop =
                is4Inch ? (float)(self.buttonMarginForScreen40 + kFourInchGameTop) : kComboBoardTop;
            float fade = GetComboFadeFactor((unsigned int)(9 - cutFrame));
            [texCombo drawSprite:0
                          inRect:CGRectMake((double)inset,
                                            (double)(inset + boardTop),
                                            (double)scale,
                                            (double)scale)
                       transform:0
                           alpha:fade];
        }
        --comboCutFrame;
    }
    if (combo >= 5) {
        if (lastCombo < combo) {
            comboEffectFrame = 0xb;
        }
        char digits[5];
        int count = snprintf(digits, sizeof(digits), "%d", combo);
        if (count >= 1) {
            (void)[texCombo spriteAtIndex:1]; // Read for effect; the result is discarded.
            unsigned int digitCount = (count < 5) ? (unsigned int)count : 4;
            double baseX;
            double stepX;
            // The three narrow digit counts have bespoke x layouts; four digits fall back to a
            // fixed step.
            if (digitCount - 1 < 3) {
                stepX = kComboDigitStepX[digitCount - 1]; // @ghidraAddress 0x2928d0
                baseX = kComboDigitBaseX[digitCount - 1]; // @ghidraAddress 0x2928f0
            } else {
                stepX = 0.0;
                baseX = kButtonPositionYBias; // 80.0 @ghidraAddress 0x28f3f8
            }
            int effect = (int)comboEffectFrame;
            if (self.showCombo) {
                unsigned int step = (unsigned int)(0xb - effect);
                for (int i = 0; i < (int)digitCount; ++i) {
                    int gameTop = is4Inch ? self.buttonMarginForScreen40 : 0;
                    int digitOffset = GetComboDigitOffset(step, digitCount, i);
                    // The per-digit scale is passed as the draw alpha, matching the binary.
                    float digitScale = GetComboScaleByDigit(step, digitCount, i);
                    [texCombo drawSprite:((long)digits[i] - 0x21)
                                 atPoint:CGPointMake(baseX + stepX * (double)i,
                                                     (double)((float)(gameTop + 0xfa) +
                                                              (float)digitOffset * 0.5f))
                               transform:0
                                   alpha:digitScale];
                }
                // The trailing "combo" word chip, scaled by the digit count.
                double wordY = is4Inch ?
                                   (double)(self.buttonMarginForScreen40 + kComboWordTop4Inch) :
                                   kComboWordTop;
                float wordScale = GetComboScaleByCount(step, digitCount);
                [texCombo drawSprite:1
                             atPoint:CGPointMake((kScoreRightEdge - baseX), wordY)
                           transform:0
                               alpha:wordScale];
            }
        }
    }
    lastCombo = combo;
}

/** @ghidraAddress 0x10bd80 */
- (void)renderMarker {
    int sectorDelta = (int)self.sequence.firstMarkerSector - (int)self.sequence.currentSector;
    [self.sequence getMarkerState:markerState];
    // The lead-in fade grows from the first marker over the 100 frames after the intro (0x96).
    int leadIn = sectorDelta - 0x96;
    float leadInAlpha = (float)leadIn / kMarkerLeadInFrames; // @ghidraAddress 0x28f4e0
    if (leadIn > 99) {
        leadInAlpha = 1.0f;
    }
    int gameTop = is4Inch ? (self.buttonMarginForScreen40 + kFourInchGameTop) : kFourInchGameTop;
    for (int panel = 0; panel < kMainGameGridPanelCount; ++panel) {
        double x = (double)((float)((panel % kGridColumns) * kGridPitch) + 6.0f);
        double y = (double)((float)((panel / kGridColumns) * kGridPitch) + 6.0f + (float)gameTop);
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
        if (spriteIndex >= 0) {
            [texMarker drawSprite:(NSUInteger)spriteIndex
                          atPoint:CGPointMake(x, y)
                        transform:(char)markerDir[panel]
                            alpha:1.0f];
        } else {
            // No marker: reset the panel's spin direction, choosing a random one when the marker
            // set is configured to spin randomly.
            markerDir[panel] = 0;
            if (JubeatAppDelegate.appDelegate.isMarkerDirRandom) {
                markerDir[panel] = rand() % 4;
            }
        }
        // During the lead-in, the first-marker panels pulse the marker sprite 8 as a hint.
        if (sectorDelta > 0x96 && (self.sequence.firstMarker & (1 << (panel & 0x1f)))) {
            [texFront drawSprite:8 atPoint:CGPointMake(x, y) transform:0 alpha:leadInAlpha];
        }
    }
    [self.sequence getHoldMarkerState:holdState];
    if (self.rendererConf.isStealth) {
        return;
    }
    [holdMarkerRender renderHoldMarker:holdState];
}

/** @ghidraAddress 0x10cb34 */
- (void)renderUpdatedScore:(unsigned int)score
                   atPoint:(CGPoint)point
                     alpha:(double)alpha
                     scale:(double)scale
                    boardY:(float)boardY {
    if (score == 0 || self.scoreBackup) {
        return;
    }
    char digits[8];
    snprintf(digits, sizeof(digits), "%7d", score);
    (void)[texFront spriteAtIndex:0x38]; // Read for effect; the result is discarded.
    (void)[texFront spriteAtIndex:0xb];
    // The board chip's alpha ramps to a 0.7 cap at twice the passed alpha.
    float boardAlpha = (float)(alpha + alpha);
    if (boardAlpha > kScoreBoardAlphaCap) {
        boardAlpha = kScoreBoardAlphaCap;
    }
    [texFront drawSprite:0xb
                 atPoint:CGPointMake(kScoreRightEdge - scale, (double)(boardY - 4.0f))
               transform:0
                   alpha:boardAlpha];
    // Each of the seven right-aligned digits is drawn 9 points apart, tracking the last drawn one
    // so the trailing suffix chip follows it.
    long lastDigit = -1;
    for (long i = 0; i < 7; ++i) {
        if ((unsigned char)(digits[i] - '0') < 10) {
            [texFront drawSprite:((long)digits[i] + 8)
                          inRect:CGRectMake(
                                     point.x + (double)(i * 9) + 1.0, point.y, scale, alpha * scale)
                       transform:0
                           alpha:1.0f];
        } else {
            lastDigit = i;
        }
    }
    [texFront drawSprite:0x37
                  inRect:CGRectMake(point.x + (double)((int)lastDigit * 9 + 9) + 1.0,
                                    point.y,
                                    scale,
                                    alpha * scale)
               transform:0
                   alpha:1.0f];
}

/** @ghidraAddress 0x10cd38 */
- (void)renderScore:(unsigned int)score
       partnerScore:(unsigned int)partnerScore
            atPoint:(CGPoint)point
             scaleH:(double)scaleH
              alpha:(double)alpha {
    (void)[texFront spriteAtIndex:10]; // Read for effect; the result is discarded.
    (void)[texFront spriteAtIndex:0x19];
    CGPoint anchor = CGPointMake(point.x + scaleH, point.y + alpha);
    // The whole run is stretched to 1.3x on the four-inch phone.
    double widthScale = is4Inch ? kScoreWidthScale : 1.0;
    // The shown score eases half the remaining gap towards the target each frame.
    if (score == 0) {
        scoreDisplay = 0;
    } else if (scoreDisplay != score) {
        int step = (scoreDisplay < score) ? 1 : -1;
        scoreDisplay = scoreDisplay + ((int)(score - scoreDisplay) + step >> 1);
    }
    char digits[8];
    snprintf(digits, sizeof(digits), "%7d", scoreDisplay);
    MainGameRendererPhoneDrawScoreRun(
        self, digits, scoreDisplay, point, scaleH, alpha, anchor, widthScale, alpha);
    if (!self.isSession) {
        return;
    }
    // The partner score dims to half alpha when the partner is not connected.
    double partnerAlpha = self.isConnected ? alpha : (alpha * 0.5);
    if (partnerScore == 0) {
        partnerScoreDisplay = 0;
    } else if (partnerScoreDisplay != partnerScore) {
        int step = (partnerScoreDisplay < partnerScore) ? 1 : -1;
        partnerScoreDisplay =
            partnerScoreDisplay + ((int)(partnerScore - partnerScoreDisplay) + step >> 1);
    }
    char partnerDigits[8];
    snprintf(partnerDigits, sizeof(partnerDigits), "%7d", partnerScoreDisplay);
    // The partner run is 0.7 of the player run's scale, above the player board by a per-idiom gap.
    double partnerScale = widthScale * kPartnerScoreScale; // @ghidraAddress 0x291c98
    double partnerGap;
    if (isRetina) {
        partnerGap = is4Inch ? 44.0 : 35.0; // @ghidraAddress 0x292768, 0x292760
    } else {
        partnerGap = 39.0; // @ghidraAddress 0x28f608
    }
    // The partner origin is shifted up and left of the player anchor by one cell.
    CGPoint partnerOrigin =
        CGPointMake((point.x + scaleH) - scaleH, ((point.y + alpha) - partnerGap) - alpha);
    MainGameRendererPhoneDrawScoreRun(self,
                                      partnerDigits,
                                      partnerScoreDisplay,
                                      partnerOrigin,
                                      scaleH,
                                      alpha,
                                      anchor,
                                      partnerScale,
                                      partnerAlpha);
    // The partner-name chip (sprite 0x18) sits above the partner run by a per-idiom gap.
    (void)[texFront spriteAtIndex:0x18];
    double nameGap;
    if (isRetina) {
        nameGap = is4Inch ? 30.0 : 22.0; // @ghidraAddress (fmov 0x403e / 0x4036)
    } else {
        nameGap = 25.0; // @ghidraAddress (fmov 0x4039)
    }
    [texFront drawSprite:0x18
                 atPoint:CGPointMake(anchor.x - scaleH, partnerOrigin.y - nameGap)
               transform:0
                   alpha:(float)partnerAlpha];
}

/** @ghidraAddress 0x10d418 */
- (void)renderBonus:(unsigned int)bonus atPoint:(CGPoint)point alpha:(double)alpha {
    if (alpha < 0.0) {
        return;
    }
    if (alpha > 1.0) {
        alpha = 1.0;
    }
    char digits[8];
    snprintf(digits, sizeof(digits), "%+7d", bonus);
    for (long i = 0; i < 7; ++i) {
        char c = digits[i];
        long sprite;
        if (c == '+') {
            sprite = 0x15;
        } else if ((unsigned char)(c - '0') < 10) {
            sprite = (long)c - 3; // '0'..'9' map to sprites 0x2d..0x36.
        } else {
            continue;
        }
        // The digit pitch and vertical bias differ between retina and non-retina.
        BOOL nonRetina = !isRetina;
        double dx = nonRetina ? 9.0 : 12.0;
        int pitch = nonRetina ? 0x12 : 0x10;
        double dy = nonRetina ? 12.0 : 8.0;
        [texFront drawSprite:sprite
                     atPoint:CGPointMake(point.x + dx + (double)(pitch * (int)i), point.y + dy)
                   transform:0
                       alpha:(float)alpha];
    }
}

/** @ghidraAddress 0x10d578 */
- (void)renderMusicBar:(CGPoint)position timeline:(BOOL)timeline alpha:(double)alpha {
    [texFront drawSprite:0xe
                 atPoint:CGPointMake(position.x, position.y)
               transform:0
                   alpha:(float)alpha];
    if (!self.sequence) {
        return;
    }
    float playPosition = self.sequence.playPosition;
    const char *bar = self.sequence.getMusicBar;
    const ScoreData *scoreData = self.sequence.getScore;
    ScoreData backup;
    if (self.scoreBackup) {
        backup = self.replayBackupScore;
        scoreData = &backup;
    }
    double cellX = position.x + 40.0;     // @ghidraAddress 0x28f1f8
    float cursor = playPosition * 120.0f; // @ghidraAddress 0x291be8, the play cursor in cells.
    for (unsigned int cell = 0; cell < kMusicBarCellCount; ++cell) {
        // Each cell packs a 4-bit note value into a nibble of the bar byte array.
        int byteIndex = (int)cell >> 1;
        int nibbleShift = ((int)cell - (byteIndex << 1)) * 4;
        unsigned int note = (unsigned int)(((bar[byteIndex] >> nibbleShift) & 0xf) - 1);
        if (note >= 8) {
            continue;
        }
        int baseSprite;
        if (self.state == MainGamePhoneStateFinish || self.state == MainGamePhoneStateResult ||
            self.scoreBackup || ((float)(int)cell + kMusicBarCellFadeEnd < cursor)) {
            // The per-bar grade colour, read from the two-bit grade packed in musicBarResult.
            int gradeByte = (int)scoreData->musicBarResult[(int)cell >> 2];
            int gradeShift = ((int)cell - ((int)cell & 0x7ffffffc)) * 2;
            unsigned int grade = ((unsigned int)(gradeByte >> gradeShift) & 3) ^ 2;
            baseSprite = kMusicBarGradeSprite[grade];
        } else {
            // The cell the cursor currently sits in is dim (0x42); a passed cell is lit (0x4a).
            baseSprite = 0x42;
            if ((float)(int)cell + kComboFadeBase < cursor) {
                baseSprite = 0x4a;
            }
        }
        [texFront drawSprite:(note + (unsigned int)baseSprite)
                     atPoint:CGPointMake(cellX + (double)(cell * 2), position.y - 1.0)
                   transform:0
                       alpha:(float)alpha];
    }
    if (timeline) {
        // The timeline cursor sprite, tracking the play position.
        double cursorY = is4Inch ? (double)(self.upperBgHeight40 + 0x7d) : 129.0;
        [texFront drawSprite:0x14
                     atPoint:CGPointMake((double)(playPosition * 240.0f + 33.0f), cursorY)
                   transform:0
                       alpha:(float)alpha];
    }
}

/** @ghidraAddress 0x10d8e8 */
- (void)renderTuneInfo:(CGPoint)position artworkSize:(double)artworkSize alpha:(double)alpha {
    // The jacket, stretched into sprite 0xf's frame at the passed size.
    [texFront drawSprite:0xf
                  inRect:CGRectMake(position.x, position.y, artworkSize, artworkSize)
               transform:0
                   alpha:(float)alpha];
    (void)[texFront spriteAtIndex:0x10]; // Read for effect; the result is discarded.
    double x = position.x + artworkSize + 8.0;
    double y = position.y - 4.0;
    // The title/index chip.
    [texFront drawSprite:0x10 atPoint:CGPointMake(x, y) transform:0 alpha:(float)alpha];
    y += artworkSize;
    // The difficulty word (sprite 0x11).
    [texFront drawSprite:0x11 atPoint:CGPointMake(x, y) transform:0 alpha:(float)alpha];
    // The level word (sprite 0x13), nudged right by a per-difficulty amount.
    double levelXNudge;
    switch (self.rendererConf.diff) {
    case 2:
        levelXNudge = 75.0; // @ghidraAddress 0x28f788
        break;
    case 1:
        levelXNudge = 82.0; // @ghidraAddress 0x28fa40
        break;
    case 0:
        levelXNudge = 52.0; // @ghidraAddress 0x28f220
        break;
    default:
        levelXNudge = 36.0; // @ghidraAddress 0x28f530
        break;
    }
    [texFront drawSprite:0x13
                 atPoint:CGPointMake(x + levelXNudge, y)
               transform:0
                   alpha:(float)alpha];
}

/** @ghidraAddress 0x10da6c */
- (void)renderUpperBG:(double)y {
    CGRect sprite = [texFront spriteAtIndex:0];
    // The band's height is half the gap between its bottom edge y and the sprite's own height,
    // clamped so the band never exceeds y.
    double bandHeight = (y - sprite.size.height) * 0.5;
    double bandBottom = sprite.size.height + bandHeight;
    if (bandBottom > y) {
        bandBottom = y;
        bandHeight = y - sprite.size.height;
    }
    // The source region is measured in double-density texels on retina.
    double regionScale = isRetina ? 2.0 : 1.0;
    [texFront
        drawInRect:CGRectMake(0.0, 0.0, sprite.size.width, bandHeight)
        fromRegion:CGRectMake(0.0, 0.0, sprite.size.width * regionScale, bandHeight * regionScale)
         transform:0
             alpha:1.0f];
    if (!is4Inch) {
        return;
    }
    // The four-inch phone tiles a filler strip (sprite 0x20, 32 wide, 10 tall) across the width
    // above the band, and a mirrored strip below it.
    for (int tileX = 0; tileX < kUpperBGTileSpan; tileX += kUpperBGTileWidth) {
        [texFront
            drawSprite:0x20
                inRect:CGRectMake(
                           (double)tileX, bandHeight, kUpperBGRegionWidth, kUpperBGRegionHeight)
             transform:0
                 alpha:1.0f];
    }
    double bottomY = bandBottom - 0.625; // @ghidraAddress 0x10db8c (fmov immediate)
    for (int tileX = 0; tileX < kUpperBGTileSpan; tileX += kUpperBGTileWidth) {
        [texFront
            drawSprite:0x20
                inRect:CGRectMake((double)tileX, bottomY, kUpperBGRegionWidth, kUpperBGRegionHeight)
             transform:4
                 alpha:1.0f];
    }
}

/** @ghidraAddress 0x10de28 */
- (void)renderButtons:(double)offset {
    // The sixteen panels of the 4x4 grid, drawn on a 0x50-point pitch below the offset.
    for (unsigned int panel = 0; panel < kMainGameGridPanelCount; ++panel) {
        double panelX = (double)((int)(panel % kGridColumns) * kGridPitch);
        double panelY = (double)((int)(panel / kGridColumns) * kGridPitch) + offset;
        BOOL pressed = (self.btnPress & (1 << panel)) != 0;
        if (pressed) {
            // A pressed panel draws sprite 7 under the down-state sprite 6.
            [texFront drawSprite:7 atPoint:CGPointMake(panelX, panelY)];
            [texFront drawSprite:6 atPoint:CGPointMake(panelX, panelY)];
        } else {
            [texFront drawSprite:5 atPoint:CGPointMake(panelX, panelY)];
        }
    }
    if (!is4Inch) {
        return;
    }
    // The four-inch phone fills the letterbox bands above and below the grid with sprite 0. The
    // top band spans the gap between the game-area top and the score board.
    double bandHeight = (double)(self.buttonMarginForScreen40 - self.upperBgHeight40);
    double topY = offset - bandHeight;
    // The ten x-positions of the filler tiles, on a 0x20-point pitch.
    static const double kFillerX[] = {
        0.0, 32.0, 64.0, 96.0, 128.0, 160.0, 192.0, 224.0, 256.0, 288.0};
    for (int tile = 0; tile < 10; ++tile) {
        [texFront drawSprite:0
                      inRect:CGRectMake(kFillerX[tile], topY, kUpperBGRegionWidth, bandHeight)];
    }
    double bottomBandY = offset + kScoreRightEdge; // 320.0 below the offset.
    for (int tile = 0; tile < 10; ++tile) {
        [texFront
            drawSprite:0
                inRect:CGRectMake(kFillerX[tile], bottomBandY, kUpperBGRegionWidth, bandHeight)];
    }
    // A tiled strip fills the remaining band below the buttons: one solid pass, then a mirrored
    // half-height overlay.
    int bandBase = self.buttonMarginForScreen40 + 0x1e0;
    for (int tileX = 0; tileX < kUpperBGTileSpan; tileX += kUpperBGTileWidth) {
        [texFront drawSprite:0
                      inRect:CGRectMake((double)tileX,
                                        (double)(int)(bandHeight * 0.5) + (double)bandBase,
                                        kUpperBGRegionWidth,
                                        bandHeight)];
    }
    for (int tileX = 0; tileX < kUpperBGTileSpan; tileX += kUpperBGTileWidth) {
        [texFront drawSprite:0
                      inRect:CGRectMake((double)tileX,
                                        (double)bandBase,
                                        kUpperBGRegionWidth,
                                        (double)(int)(bandHeight * 0.5))
                   transform:4
                       alpha:1.0f];
    }
}

/** @ghidraAddress 0x10dbf8 */
- (void)renderUpper {
    double tuneY;
    double artworkSize;
    if (is4Inch) {
        // The tune-info block drops by a quarter of the upper-background height, and the jacket is
        // slightly larger on the four-inch phone.
        tuneY = (double)((self.upperBgHeight40 >> 2) + 11);
        artworkSize = 88.0; // @ghidraAddress 0x292778
    } else {
        tuneY = 11.0;
        artworkSize = kButtonPositionYBias; // 80.0 @ghidraAddress 0x28f3f8
    }
    [self renderTuneInfo:CGPointMake(8.0, tuneY) artworkSize:artworkSize alpha:1.0];
    // The music bar's point passes as (0, barY): x is zero, the computed value is the y.
    double barY = is4Inch ? (double)(self.upperBgHeight40 + kFourInchUpperTop) : 136.0;
    [self renderMusicBar:CGPointMake(0.0, barY)
                timeline:(self.state == MainGamePhoneStatePlaying)
                   alpha:1.0];
    unsigned int score = 0;
    if (self.sequence) {
        score = (unsigned int)self.sequence.getScore->point;
    }
    if (self.scoreBackup) {
        // The live path shows `point`, but the replay-backup path reads `totalPoint`; the binary
        // reads the two different fields.
        score = (unsigned int)self.replayBackupScore.totalPoint;
    }
    unsigned int partnerScore = self.partnerScore;
    // The score board sits at x=178 (non-retina) / 184 (retina), and y=94 (non-retina) or a
    // per-idiom retina value.
    double scoreX = isRetina ? 184.0 : 178.0; // @ghidraAddress 0x292788, 0x292780
    double scoreY;
    if (isRetina) {
        scoreY = is4Inch ? 160.0 : 102.0; // @ghidraAddress 0x292798, 0x292790
    } else {
        scoreY = 94.0; // @ghidraAddress 0x28f420
    }
    [self renderScore:score
         partnerScore:partnerScore
              atPoint:CGPointMake(scoreX, scoreY)
               scaleH:1.0
                alpha:1.0];
}

/** @ghidraAddress 0x10e340 */
- (void)renderPreStart {
    [self renderBG];
    double upperY =
        is4Inch ? (double)(self.upperBgHeight40 + kFourInchGameTop) : kUpperBGBottomDefault;
    [self renderUpperBG:upperY];
    if (frame > 0xb) {
        // The tune information slides in from the right and fades in over frames 0xc..0x15.
        double tuneX;
        double tuneAlpha;
        if (frame < 0x16) {
            float remain = (float)(0x16 - frame);
            tuneX = (double)(remain + remain) + 8.0;
            tuneAlpha = (double)(remain * kPreStartFadeStep) + 1.0;
        } else {
            tuneAlpha = 1.0;
            tuneX = 8.0;
        }
        double tuneY;
        double artworkSize;
        if (is4Inch) {
            tuneY = (double)((self.upperBgHeight40 >> 2) + 11);
            artworkSize = 88.0; // @ghidraAddress 0x292778
        } else {
            tuneY = 11.0;
            artworkSize = kButtonPositionYBias; // 80.0 @ghidraAddress 0x28f3f8
        }
        [self renderTuneInfo:CGPointMake(tuneX, tuneY) artworkSize:artworkSize alpha:tuneAlpha];
        if (frame > 0x13) {
            // The score board fades in over frames 0x14..0x20.
            double scoreAlpha =
                (frame < 0x21) ? ((double)((float)(0x21 - frame) * kPreStartFadeStep) + 1.0) : 1.0;
            double scoreX = isRetina ? 184.0 : 178.0; // @ghidraAddress 0x292788, 0x292780
            double scoreY;
            if (isRetina) {
                scoreY = is4Inch ? 160.0 : 102.0; // @ghidraAddress 0x292798, 0x292790
            } else {
                scoreY = 94.0; // @ghidraAddress 0x28f420
            }
            [self renderScore:0
                 partnerScore:0
                      atPoint:CGPointMake(scoreX, scoreY)
                       scaleH:scoreAlpha
                        alpha:1.0];
        }
    }
    if (frame > 4) {
        // The music bar fades in over frames 5..0xe.
        double barAlpha =
            (frame < 0xf) ? ((double)((float)(0xf - frame) * kPreStartFadeStep) + 1.0) : 1.0;
        double barY = is4Inch ? (double)(self.upperBgHeight40 + kFourInchUpperTop) : 136.0;
        [self renderMusicBar:CGPointMake(0.0, barY) timeline:NO alpha:barAlpha];
    }
    double buttonsY =
        is4Inch ? (double)(self.buttonMarginForScreen40 + kFourInchGameTop) : kUpperBGBottomDefault;
    [self renderButtons:buttonsY];
    if (frame == 0x2d) {
        [AudioManager.sharedManager playSeResFile:@"SD_MUON" inDirectory:nil];
        self.subState = kPreStartDoneSubState;
    } else if (frame == 5) {
        [AudioManager.sharedManager playSeResFile:@"SD_CV_SET" inDirectory:nil];
    }
}

/** @ghidraAddress 0x10e7a4 */
- (void)renderReadyGo {
    int centreY = is4Inch ? 0x140 : 300;
    CGRect readySprite = [texReady spriteAtIndex:0];
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
        // The soft circle behind the letters swells then settles.
        float circleScale;
        if (frame < 0x25) {
            circleScale = InterpolateFloatByFrame(1.0f, kReadyCircleSwell, frame, 0x23, 0x25);
        } else if (frame < 0x50) {
            circleScale = InterpolateFloatByFrame(kReadyCircleSwell, 1.0f, frame, 0x25, 0x29);
        } else {
            circleScale = InterpolateFloatByFrame(1.0f, 2.0f, frame, 0x50, 0x56);
        }
        [self renderCircle:CGPointMake(kUpperBGBottomDefault, (double)centreY)
                      size:(double)circleScale * kReadyCircleSize
                     alpha:(double)overlayAlpha];
        // The "READY" and "GO" mark chips spin in from the sides.
        float spin = (float)((double)((float)((int)frame - 0x14) / 30.0f) * g_dPi);
        double markTopY = (double)centreY + kReadyMarkTopOffset + 21.0;
        [texReady drawSprite:8
                     atPoint:CGPointMake(kReadyMarkX, markTopY)
                       scale:circleScale
                      rotate:spin
                      anchor:CGPointMake(kUpperBGBottomDefault, (double)centreY)
                   transform:0
                       alpha:overlayAlpha];
        [texReady drawSprite:8
                     atPoint:CGPointMake(kReadyMarkX, markTopY)
                       scale:circleScale
                      rotate:(float)((double)spin + g_dPi)
                      anchor:CGPointMake(kUpperBGBottomDefault, (double)centreY)
                   transform:0
                       alpha:overlayAlpha];
        double markBottomY = (double)centreY + kReadyMarkTopOffset + 90.0;
        [texReady drawSprite:9
                     atPoint:CGPointMake(kReadyMarkX2, markBottomY)
                       scale:circleScale
                      rotate:spin
                      anchor:CGPointMake(kUpperBGBottomDefault, (double)centreY)
                   transform:0
                       alpha:overlayAlpha];
        [texReady drawSprite:9
                     atPoint:CGPointMake(kReadyMarkX2, markBottomY)
                       scale:circleScale
                      rotate:(float)((double)spin + g_dPi)
                      anchor:CGPointMake(kUpperBGBottomDefault, (double)centreY)
                   transform:0
                       alpha:overlayAlpha];
    }
    // The five "READY" letters settle in one by one (frames < 0x45), then slide out together.
    double lettersY = (double)(centreY - (spriteH >> 1));
    if (frame < 0x45) {
        for (long letter = 0; letter <= 4; ++letter) {
            unsigned int startFrame = (unsigned int)(0x1b + letter * 2);
            float letterAlpha =
                InterpolateFloatByFrame(0.0f, 1.0f, frame, startFrame, startFrame + 4);
            if (letterAlpha > 0.0f) {
                float drop =
                    InterpolateFloatByFrame(30.0f, 0.0f, frame, startFrame, startFrame + 5);
                [texReady
                    drawSprite:(NSUInteger)letter
                       atPoint:CGPointMake(kUpperBGBottomDefault + (double)((int)letter * spriteW),
                                           lettersY - (double)drop)
                     transform:0
                         alpha:letterAlpha];
            }
        }
    } else {
        float outAlpha = InterpolateFloatByFrame(1.0f, 0.0f, frame, 0x45, 0x4b);
        if (outAlpha > 0.0f) {
            float spread = InterpolateFloatByFrame(0.0f, 70.0f, frame, 0x45, 0x4b);
            double spreadD = (double)spread;
            [texReady drawSprite:0
                         atPoint:CGPointMake(kUpperBGBottomDefault + spreadD * -2.0, lettersY)
                       transform:0
                           alpha:outAlpha];
            [texReady drawSprite:1
                         atPoint:CGPointMake((kUpperBGBottomDefault + (double)spriteW) - spreadD,
                                             lettersY)
                       transform:0
                           alpha:outAlpha];
            [texReady
                drawSprite:2
                   atPoint:CGPointMake(kUpperBGBottomDefault + (double)(spriteW * 2), lettersY)
                 transform:0
                     alpha:outAlpha];
            [texReady
                drawSprite:3
                   atPoint:CGPointMake(kUpperBGBottomDefault + (double)(spriteW * 3) + spreadD,
                                       lettersY)
                 transform:0
                     alpha:outAlpha];
            double letterEX = kUpperBGBottomDefault + (double)(spriteW * 4) + spreadD + spreadD;
            [texReady drawSprite:4
                         atPoint:CGPointMake(letterEX, lettersY)
                       transform:0
                           alpha:outAlpha];
        }
    }
    MainGameRendererPhoneRenderGoMark(self, 5, spriteW, spriteH, centreY);
    MainGameRendererPhoneRenderGoMark(self, 6, spriteW, spriteH, centreY);
    if (frame == 0x1b) {
        [AudioManager.sharedManager playSeResFile:@"SD_CV_READY" inDirectory:nil];
    }
    if (frame == 0x45) {
        [AudioManager.sharedManager playSeResFile:@"SD_CV_GO" inDirectory:nil];
    }
    if (frame >= 100) {
        self.subState = kMainGamePhoneEndSubState;
    }
}

/** @ghidraAddress 0x10e69c */
- (void)renderCircle:(CGPoint)center size:(double)size alpha:(double)alpha {
    // Four quadrant blits of the soft-circle sprite (7) tiled about the centre, each transform
    // mirroring it into its quadrant.
    [texReady drawSprite:7
                  inRect:CGRectMake(center.x - size, center.y - size, size, size)
               transform:7
                   alpha:(float)alpha];
    [texReady drawSprite:7
                  inRect:CGRectMake(center.x - size, center.y, size, size)
               transform:4
                   alpha:(float)alpha];
    [texReady drawSprite:7
                  inRect:CGRectMake(center.x, center.y - size, size, size)
               transform:5
                   alpha:(float)alpha];
    [texReady drawSprite:7
                  inRect:CGRectMake(center.x, center.y, size, size)
               transform:2
                   alpha:(float)alpha];
}

/** @ghidraAddress 0x10efd4 */
- (void)renderStartMark {
    unsigned int firstMarker = self.sequence.firstMarker;
    int gameTop = is4Inch ? (self.buttonMarginForScreen40 + kFourInchGameTop) : kFourInchGameTop;
    for (unsigned int panel = 0; panel < kMainGameGridPanelCount; ++panel) {
        if ((1u << (panel & 0x1f) & firstMarker) == 0) {
            continue;
        }
        // The start mark (sprite 8) fades in over the first 15 frames.
        float alpha = (frame < 15) ? ((float)frame / 15.0f) : 1.0f;
        double x = (double)((float)((int)(panel % kGridColumns) * kGridPitch) + 6.0f);
        double y =
            (double)((float)((int)(panel / kGridColumns) * kGridPitch) + 6.0f + (float)gameTop);
        [texFront drawSprite:8 atPoint:CGPointMake(x, y) transform:0 alpha:alpha];
    }
}

/** @ghidraAddress 0x10f13c */
- (void)renderFinish {
    // The whole field wipes to white over ~17 frames (0.06 per frame, capped at 1.0).
    float wipe = (float)frame * kFinishWipeRate; // @ghidraAddress 0x29258c
    if (wipe > 1.0f) {
        wipe = 1.0f;
    }
    CGRect banner = [texFront spriteAtIndex:2];
    // The white curtain: 48 columns (0x300 / 0x10) drawn from the game-area top.
    for (int columnX = 0; columnX < 0x300; columnX += 0x10) {
        int gameTop =
            is4Inch ? (self.buttonMarginForScreen40 + kFourInchGameTop) : kFourInchGameTop;
        [texFront drawSprite:2
                     atPoint:CGPointMake((double)columnX, (double)gameTop)
                   transform:1
                       alpha:wipe];
    }
    // The four finish-message banners (sprite 2) are centred horizontally and stacked at four
    // vertical bands. Non-four-inch uses fixed y bands; four-inch offsets them by the button
    // margin.
    double centerX = (kScoreRightEdge - banner.size.width) * 0.5;       // @ghidraAddress 0x28f470
    double centerY = (kButtonPositionYBias - banner.size.height) * 0.5; // @ghidraAddress 0x28f3f8
    // The four band base y-values.
    static const double kFinishBandY[] = {160.0, 240.0, 320.0, 400.0};
    // @ghidraAddress 0x28f438, 0x291bf0, 0x28f470, 0x28f2e0
    static const int kFinishBandFourInch[] = {0xa0, 0xf0, 0x140, 0x190};
    for (int band = 0; band < 4; ++band) {
        double bandY = is4Inch ?
                           (double)(self.buttonMarginForScreen40 + kFinishBandFourInch[band]) :
                           kFinishBandY[band];
        [texFront drawSprite:2
                     atPoint:CGPointMake(centerX, centerY + bandY)
                   transform:2
                       alpha:wipe];
    }
    // On the result state, play the finish voice once (unless the score is backed up for replay).
    if (self.state == MainGamePhoneStateResult && !self.scoreBackup) {
        if (self.sequence.isExcellent) {
            [AudioManager.sharedManager playSeResFile:@"SD_CV_EXCELLENT" inDirectory:nil];
        } else if (self.sequence.isFullcombo) {
            [AudioManager.sharedManager playSeResFile:@"SD_CV_FULLCOMBO" inDirectory:nil];
        } else {
            [AudioManager.sharedManager playSeResFile:@"SD_CV_FINISH" inDirectory:nil];
        }
    }
    // The finish sub-state advances once the wipe has run for 60 frames.
    if (self.subState == 0 && frame == 60) {
        self.subState = kFinishDoneSubState;
    }
}

/** @ghidraAddress 0x10f4e4 */
- (BOOL)renderCleared:(unsigned int)rank centerY:(double)centerY {
    // The seven "CLEARED" letters, drawn from the two cleared atlases; the x-positions and per-
    // letter sprite indices come from the shipped tables.
    static const double kClearedLetterX[] = {28.0, 72.0, 116.0, 160.0, 205.0, 250.0, 293.0};
    // @ghidraAddress 0x2927d0
    static const long kClearedLetterSprite[] = {0, 1, 2, 3, 0, 2, 1}; // @ghidraAddress 0x292808
    // The seven letters alternate between the two atlases: 0,1,2,3 from texClear0 and the last
    // three from texClear1.
    Texture2D *atlases[] = {
        texClear0, texClear0, texClear0, texClear0, texClear0, texClear1, texClear1};
    CGRect letter = [texClear0 spriteAtIndex:4];
    double letterW = letter.size.width;
    double letterH = letter.size.height;
    // The white curtain opens over the first eight frames to half alpha, then closes from 0x50.
    if (rank < 0x50) {
        float curtainAlpha = InterpolateFloatByFrame(0.0f, 0.5f, rank, 0, 8);
        float scale =
            InterpolateFloatByFrame(kClearedCurtainOpen, kClearedCurtainClose, rank, 8, 0x2d);
        if (curtainAlpha > 0.0f) {
            double h = letterH * (double)scale;
            for (int i = 0; i < 0x10; ++i) {
                [texClear0
                    drawSprite:4
                        inRect:CGRectMake(letterW * (double)i, centerY + h * -0.5, letterW, h)
                     transform:0
                         alpha:curtainAlpha];
            }
        }
    } else if (rank < 100) {
        float curtainAlpha = InterpolateFloatByFrame(0.5f, 0.0f, rank, 0x50, 100);
        float scale = InterpolateFloatByFrame(kClearedCurtainClose, 1.0f, rank, 0x50, 100);
        if (curtainAlpha > 0.0f) {
            double h = letterH * (double)scale;
            for (int i = 0; i < 0x10; ++i) {
                [texClear0
                    drawSprite:4
                        inRect:CGRectMake(letterW * (double)i, centerY + h * -0.5, letterW, h)
                     transform:0
                         alpha:curtainAlpha];
            }
        }
    }
    (void)[texClear0 spriteAtIndex:0];
    for (int i = 0; i < 7; ++i) {
        unsigned int start = (unsigned int)(i * 2);
        float letterAlpha = InterpolateFloatByFrame(0.0f, 1.0f, rank, start, start + 6);
        if (letterAlpha > 0.0f) {
            float slideX = InterpolateFloatByFrame(
                kBgMeasureScale, (float)kClearedLetterX[i], rank, start, start + 6);
            float scale = InterpolateFloatByFrame(2.0f, 1.0f, rank, start, start + 6);
            double w = letterW * (double)scale;
            double h = letterH * (double)scale;
            [atlases[i] drawSprite:(NSUInteger)kClearedLetterSprite[i]
                            inRect:CGRectMake((double)slideX - w * 0.5, centerY - h * 0.5, w, h)
                         transform:0
                             alpha:letterAlpha];
        }
    }
    return rank > 0x4f;
}

/** @ghidraAddress 0x10f82c */
- (BOOL)renderFailed:(unsigned int)rank centerY:(double)centerY {
    // The six "FAILED" letters, drawn from the second and third cleared atlases.
    static const double kFailedLetterDrop[] = {28.0, 40.0, 25.0, 37.0, 34.0, 18.0};   // @0x292840
    static const double kFailedLetterX[] = {62.0, 107.0, 140.0, 174.0, 219.0, 264.0}; // @0x292870
    static const long kFailedLetterSprite[] = {2, 3, 0, 1, 2, 3}; // @ghidraAddress 0x2928a0
    Texture2D *atlases[] = {texClear1, texClear1, texClear2, texClear2, texClear2, texClear2};
    CGRect letter = [texClear1 spriteAtIndex:4];
    double letterW = letter.size.width;
    double letterH = letter.size.height;
    if (rank < 0x50) {
        float curtainAlpha = InterpolateFloatByFrame(0.0f, 0.5f, rank, 0, 8);
        float scale =
            InterpolateFloatByFrame(kClearedCurtainOpen, kClearedCurtainClose, rank, 8, 0x2d);
        if (curtainAlpha > 0.0f) {
            double h = letterH * (double)scale;
            for (int i = 0; i < 0x10; ++i) {
                [texClear1
                    drawSprite:4
                        inRect:CGRectMake(letterW * (double)i, centerY + h * -0.5, letterW, h)
                     transform:0
                         alpha:curtainAlpha];
            }
        }
    } else if (rank < 100) {
        float curtainAlpha = InterpolateFloatByFrame(0.5f, 0.0f, rank, 0x50, 100);
        float scale = InterpolateFloatByFrame(kClearedCurtainClose, 1.0f, rank, 0x50, 100);
        if (curtainAlpha > 0.0f) {
            double h = letterH * (double)scale;
            for (int i = 0; i < 0x10; ++i) {
                [texClear1
                    drawSprite:4
                        inRect:CGRectMake(letterW * (double)i, centerY + h * -0.5, letterW, h)
                     transform:0
                         alpha:curtainAlpha];
            }
        }
    }
    (void)[texClear1 spriteAtIndex:2];
    for (int i = 0; i < 6; ++i) {
        unsigned int start = (unsigned int)(i * 3);
        float letterAlpha = InterpolateFloatByFrame(0.0f, 1.0f, rank, start, start + 6);
        if (letterAlpha > 0.0f) {
            // Each letter drops into place from above.
            float drop =
                InterpolateFloatByFrame((float)kFailedLetterDrop[i], 0.0f, rank, start, start + 6);
            [atlases[i] drawSprite:(NSUInteger)kFailedLetterSprite[i]
                           atPoint:CGPointMake(kFailedLetterX[i] - letterW * 0.5,
                                               (centerY - (double)drop) - letterH * 0.5)
                         transform:0
                             alpha:letterAlpha];
        }
    }
    return rank > 0x4f;
}

/** @ghidraAddress 0x10fe00 */
- (void)renderResult {
    const ScoreData *scoreData = self.sequence.getScore;
    // The whole screen slides up over the first 20 frames.
    double slide =
        (frame < 0x14) ? (double)(((float)frame * kResultSlideStep) / 20.0f) : kButtonPositionYBias;
    int upperTop = is4Inch ? self.upperBgHeight40 : 0;
    [self renderUpperBG:(double)(upperTop + kFourInchGameTop) + self.buttonAreaOffset];
    // The header chip (sprite 0xd) drops in over the first ten frames.
    double headerY = (frame < 10) ? (double)(((float)frame * 24.0f) / 10.0f) : 24.0;
    [texFront drawSprite:0xd atPoint:CGPointMake(0.0, headerY - 24.0)];
    // The tune information, dropped by a quarter of the header offset on the four-inch phone.
    int tuneTop = is4Inch ? self.upperBgHeight40 : 0;
    double tuneY = headerY * 0.25 + (double)((tuneTop >> 2) + 11);
    double artworkSize = is4Inch ? 88.0 : 80.0; // @ghidraAddress 0x292778, 0x292770
    [self renderTuneInfo:CGPointMake(8.0, tuneY) artworkSize:artworkSize alpha:1.0];
    // The title chip (sprite 0xc) slides in from the right over the first 15 frames.
    CGPoint titlePos =
        (frame < 0xf) ?
            CGPointMake((double)(((float)frame * kResultTitleSlide) / -15.0f + kResultTitleSlide),
                        0.0) :
            CGPointZero;
    [texFront drawSprite:0xc atPoint:titlePos];
    int barTop = is4Inch ? (self.upperBgHeight40 - 4) : 0;
    [self renderMusicBar:CGPointMake(0.0, slide + (double)(barTop + 0x88)) timeline:NO alpha:1.0];
    // The finish curtain replays over the first ten frames of the result screen.
    if (frame < 10) {
        double curtainScale = (double)((float)frame * kPreStartFadeStep + 1.0f);
        MainGameRendererPhoneRenderResultCurtain(self, slide, (float)curtainScale);
    }
    // The player (and partner) score, then the bonus, appear after the curtain.
    BOOL preBonus = frame < 0x28 || self.scoreBackup;
    if (preBonus) {
        unsigned int shownScore = (unsigned int)scoreData->point;
        if (self.scoreBackup) {
            shownScore = (unsigned int)self.replayBackupScore.totalPoint;
        }
        unsigned int partner = self.partnerScore;
        double scoreX = isRetina ? 184.0 : 178.0; // @ghidraAddress 0x292780
        int scoreYOff = isRetina ? (is4Inch ? 0xa0 : 0x66) : 0x5e;
        [self renderScore:shownScore
             partnerScore:partner
                  atPoint:CGPointMake(scoreX, slide + (double)scoreYOff)
                   scaleH:1.0
                    alpha:1.0];
    } else {
        unsigned int shownScore = (unsigned int)scoreData->totalPoint;
        unsigned int partner = self.partnerScore;
        unsigned int partnerBonus = self.partnerFinalBonus;
        double scoreX = isRetina ? 184.0 : 178.0;
        int scoreYOff = isRetina ? (is4Inch ? 0xa0 : 0x66) : 0x5e;
        [self renderScore:shownScore
             partnerScore:(partnerBonus + partner)
                  atPoint:CGPointMake(scoreX, slide + (double)scoreYOff)
                   scaleH:1.0
                    alpha:1.0];
        // The final bonus counts up between frames 0x28 and 0x3c, unless a connected session.
        BOOL connectedSession = self.isSession && self.isConnected;
        if (!connectedSession && frame < 0x3c) {
            int scoreYOff2 = isRetina ? (is4Inch ? 0xa0 : 0x66) : 0x5e;
            double bonusY = (slide + (double)scoreYOff2 - 30.0) - (double)(frame - 0x28);
            double bonusAlpha = (double)((float)(frame - 0x28) * kResultBonusFadeStep + 1.5f);
            [self renderBonus:(unsigned int)scoreData->bonusPoint
                      atPoint:CGPointMake(scoreX, bonusY)
                        alpha:bonusAlpha];
        }
    }
    // The cleared or failed animation runs from frame 0x46 (skipped on replay backup).
    BOOL clearedFinished = self.scoreBackup;
    if (frame >= 0x46 && !self.scoreBackup) {
        if (scoreData->totalPoint > kResultClearThreshold - 1) {
            clearedFinished = [self renderCleared:(frame - 0x46) centerY:kResultClearCentreY];
        } else {
            clearedFinished = [self renderFailed:(frame - 0x46) centerY:kResultClearCentreY];
        }
    }
    // The rating chips appear after frame 0x4f, easing in over frames 0x50..0x5e.
    if (frame > 0x4f) {
        double ratingAlpha =
            (frame < 0x5f) ? (double)((float)(0x5f - frame) * kResultBonusFadeStep + 1.0f) : 1.0;
        if (ratingAlpha < 0.0) {
            ratingAlpha = 0.0;
        }
        if (!self.scoreBackup) {
            int ratingTop = is4Inch ? self.buttonMarginForScreen40 : 0;
            [texRating drawSprite:1
                          atPoint:CGPointMake(kResultRatingX, (double)(ratingTop + 0x17c))
                        transform:0
                            alpha:(float)ratingAlpha];
            [texRating drawSprite:0
                          atPoint:CGPointMake(kResultRatingX2, (double)(ratingTop + 0x148))
                        transform:0
                            alpha:(float)ratingAlpha];
        }
    }
    // The new-record banner and the record score appear once the screen is fully in (frame > 99).
    if (self.isNewRecord && frame > 99 && !self.scoreBackup) {
        (void)[texFront spriteAtIndex:0x17];
        double recordX = isRetina ? kResultRecordX2 : kResultRecordX; // @0x2927a8 / 0x2927a0
        int recordYOff = isRetina ? (is4Inch ? 0xa0 : 0x66) : 0x5e;
        int recordYBias = isRetina ? (is4Inch ? -1 : 7) : 0xd;
        double bannerBaseY = (slide + (double)(recordYBias + recordYOff)) - 1.0;
        double bannerY = bannerBaseY;
        double bannerH = 1.0;
        double recordAlpha = 1.0;
        if (frame < 0x6e) {
            bannerH = (1.0 / 10.0) * (double)(frame - 100);
            bannerY = bannerBaseY + (1.0 - bannerH) * 0.5;
        } else if (frame > 0x77) {
            float pulse = cosf((float)((double)((float)(frame - 0x78) / 20.0f) * g_dPi));
            recordAlpha = (double)(pulse * kComboFadeBase + kRecordPulseBias);
        }
        [texFront drawSprite:0x17
                      inRect:CGRectMake(recordX - 1.0, bannerY, 1.0, bannerH)
                   transform:0
                       alpha:(float)recordAlpha];
        // The record score digits, tweened up.
        float recordScoreY = isRetina ? kResultRecordYBias2 : kResultRecordYBias;
        float recordScoreX = isRetina ? 0.0f : -11.5f;
        unsigned int record = self.scoreRecord;
        double digitDx = isRetina ? -13.0 : 16.0;
        double digitDy = is4Inch ? -2.0 : 0.0;
        double recordDigitX = (recordX - 1.0) + digitDx + digitDy;
        double recordDigitY = bannerY + (double)(recordScoreY + recordScoreX);
        [self renderUpdatedScore:record
                         atPoint:CGPointMake(recordDigitX, recordDigitY)
                           alpha:recordAlpha
                           scale:bannerH
                          boardY:(float)bannerBaseY + recordScoreY + recordScoreX];
    }
    // The action buttons and the good-job overlay appear once the sub-state advances.
    if (self.subState != 0) {
        int actionTop = is4Inch ? self.buttonMarginForScreen40 : 0;
        double actionY = slide + (double)((float)(actionTop + 0xa0) + kResultVoteY);
        unsigned int elapsed = frame - subStateChangeFrame;
        float actionAlpha = (elapsed < 8) ? ((float)elapsed * 0.125f) : 1.0f;
        [texFront drawSprite:0
                     atPoint:CGPointMake(kResultActionX, actionY)
                   transform:9
                       alpha:actionAlpha];
        // A downloaded custom tune with music offers a level-vote button; the first time through it
        // blits the vote chip and fades the good-job overlay in.
        if (!self.replayPlaying && self.isCustom && self.isDownload && self.hasMusic) {
            if (!self.isTextureChange) {
                self.isTextureChange = YES;
                if (isRetina) {
                    texFront.isScale2x = NO;
                    LoadTextureSubImageFromResource(
                        texFront, kResultVoteChip, [texFront spriteAtIndex:8].origin);
                    texFront.isScale2x = YES;
                } else {
                    LoadTextureSubImageFromResource(
                        texFront, kResultVoteChipPn, [texFront spriteAtIndex:8].origin);
                }
                if (self.goodJobImage) {
                    __weak UIImageView *overlay = self.goodJobImage;
                    float alphaMax = self.goodJobAlphaMax;
                    [UIView animateWithDuration:kResultOverlayFadeDuration
                                     animations:^{
                                       /** @ghidraAddress 0x110ed4 */
                                       overlay.alpha = alphaMax;
                                     }
                                     completion:^(BOOL finished){
                                         /** @ghidraAddress 0x110f28 */
                                     }];
                }
            }
            int voteTop = is4Inch ? self.buttonMarginForScreen40 : 0;
            [texFront
                drawSprite:0
                   atPoint:CGPointMake(kResultVoteX,
                                       slide + (double)((float)(voteTop + 0xa0) + kResultVoteY))
                 transform:8
                     alpha:actionAlpha];
        }
        // A non-custom tune with music fades the good-job overlay in immediately.
        if (!self.isCustom && self.hasMusic && self.goodJobImage) {
            __weak UIImageView *overlay = self.goodJobImage;
            float alphaMax = self.goodJobAlphaMax;
            [UIView animateWithDuration:kResultOverlayFadeDuration
                             animations:^{
                               /** @ghidraAddress 0x110f2c */
                               overlay.alpha = alphaMax;
                             }
                             completion:^(BOOL finished){
                                 /** @ghidraAddress 0x110f80 */
                             }];
        }
        // A session tune without music likewise fades the overlay in.
        if (self.isSession && !self.hasMusic && self.goodJobImage) {
            __weak UIImageView *overlay = self.goodJobImage;
            float alphaMax = self.goodJobAlphaMax;
            [UIView animateWithDuration:kResultOverlayFadeDuration
                             animations:^{
                               /** @ghidraAddress 0x110f84 */
                               overlay.alpha = alphaMax;
                             }
                             completion:^(BOOL finished){
                                 /** @ghidraAddress 0x110fd8 */
                             }];
        }
    }
    double buttonsY =
        is4Inch ? (double)(self.buttonMarginForScreen40 + kFourInchGameTop) : kUpperBGBottomDefault;
    [self renderButtons:slide + buttonsY];
    // The result voices and jingles play on their trigger frames.
    if (!self.scoreBackup) {
        if (frame == 0x46) {
            if (scoreData->totalPoint < kResultClearThreshold) {
                [AudioManager.sharedManager playSeResFile:@"SD_CV_FAILED" inDirectory:nil];
                [AudioManager.sharedManager playSeResFile:@"SD_RESULT_FAILED" inDirectory:nil];
            } else {
                [AudioManager.sharedManager playSeResFile:@"SD_CV_CLEAR" inDirectory:nil];
                [AudioManager.sharedManager playSeResFile:@"SD_RESULT_CLEAR" inDirectory:nil];
            }
        } else if (frame == 0x28) {
            [AudioManager.sharedManager playSeResFile:@"SD_RESULT_SLIDE" inDirectory:nil];
        } else if (frame == 10) {
            [AudioManager.sharedManager playSeResFile:@"SD_CV_RESULT" inDirectory:nil];
        }
    }
    // Once the cleared/failed animation has finished, advance the sub-state and record the frame.
    if (clearedFinished && self.subState == 0) {
        self.subState = 10;
        subStateChangeFrame = frame;
    }
}

/** @ghidraAddress 0x110fdc */
- (void)draw {
    switch (self.state) {
    case MainGamePhoneStatePreStart:
        [self renderPreStart];
        break;
    case MainGamePhoneStateReady: {
        [self renderBG];
        double upperY =
            is4Inch ? (double)(self.upperBgHeight40 + kFourInchGameTop) : kUpperBGBottomDefault;
        [self renderUpperBG:upperY];
        [self renderUpper];
        [self renderStartMark];
        double buttonsY = is4Inch ? (double)(self.buttonMarginForScreen40 + kFourInchGameTop) :
                                    kUpperBGBottomDefault;
        [self renderButtons:buttonsY];
        [self renderReadyGo];
        break;
    }
    case MainGamePhoneStatePlaying: {
        [self renderBG];
        [self renderCombo:(unsigned int)self.sequence.getScore->curCombo];
        double upperY =
            is4Inch ? (double)(self.upperBgHeight40 + kFourInchGameTop) : kUpperBGBottomDefault;
        [self renderUpperBG:upperY];
        [self renderUpper];
        [self renderMarker];
        double buttonsY = is4Inch ? (double)(self.buttonMarginForScreen40 + kFourInchGameTop) :
                                    kUpperBGBottomDefault;
        [self renderButtons:buttonsY];
        break;
    }
    case MainGamePhoneStateFinish: {
        [self renderBG];
        [self renderCombo:(unsigned int)self.sequence.getScore->curCombo];
        double upperY =
            is4Inch ? (double)(self.upperBgHeight40 + kFourInchGameTop) : kUpperBGBottomDefault;
        [self renderUpperBG:upperY];
        [self renderUpper];
        [self renderMarker];
        [self renderFinish];
        double buttonsY = is4Inch ? (double)(self.buttonMarginForScreen40 + kFourInchGameTop) :
                                    kUpperBGBottomDefault;
        [self renderButtons:buttonsY];
        break;
    }
    case MainGamePhoneStateResult:
    case MainGamePhoneStateResult2:
        [self renderResult];
        break;
    default: {
        [self renderBG];
        double upperY =
            is4Inch ? (double)(self.upperBgHeight40 + kFourInchGameTop) : kUpperBGBottomDefault;
        [self renderUpperBG:upperY];
        double buttonsY = is4Inch ? (double)(self.buttonMarginForScreen40 + kFourInchGameTop) :
                                    kUpperBGBottomDefault;
        [self renderButtons:buttonsY];
        break;
    }
    }
    [texCombo commitDraw];
    [texHoldMarker commitDraw];
    [texMarker commitDraw];
    [texFront commitDraw];
    [texReady commitDraw];
    [texRating commitDraw];
    [texClear0 commitDraw];
    [texClear1 commitDraw];
    [texClear2 commitDraw];
    ++frame;
}

/** @ghidraAddress 0x1113f0 */
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
        [texDebugFont drawSprite:(NSUInteger)((long)c - 0x20)
                         atPoint:CGPointMake(x, y)
                       transform:0
                           alpha:alpha];
        ++drawn;
        ++i;
        x += 12.0;
        if (drawn >= 0x200) {
            break;
        }
    }
    if (drawn != 0) {
        [texDebugFont commitDraw];
    }
}

@end
