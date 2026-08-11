#import "MainGameRendererPadKnt.h"

#import <UIKit/UIKit.h>

#import "AudioManager.h"
#import "EAGLView.h"
#import "HoldMarkerRender.h"
#import "JubeatAppDelegate.h"
#import "RendererConf.h"
#import "Sequence.h"
#import "Texture2D.h"
#import "TextureLoading.h"
#import "UpperBGKnit.h"
#import "neEngineBridge.h"

// The ready/go countdown runs for two and a half seconds on the Knit pad renderer.
static const double kReadyGoDuration = 2.5; // fmov 0x4004000000000000

// The game area is offset 256 points down on the Knit pad renderer.
static const double kGameAreaOffset = 256.0; // @ghidraAddress 0x28e030

// The 0.8 combo-cut key time float pool slot, and the excellent panel draw size.
static const float g_flKeyTime080 = 0.8f;    // @ghidraAddress 0x28f3c0
static const double kExcPanelSpread = 192.0; // @ghidraAddress 0x28fa00

// The result-screen button grid identities: the good-job, evaluate/tweet/store, and end buttons.
enum {
    kGoodJobButtonID = 13,
    kEvaluateButtonID = 14,
    kEndButtonID = 15,
};

// The live score is drawn right-to-left as seven "%7d" cells sixteen points apart, each glyph a
// sprite keyed by its ASCII code, nudged one point right; the leading blanks are capped by a '/'.
static const int kScoreDigitStride = 16;    // 0x10, per-digit cell stride in points
static const double kScoreDigitNudge = 1.0; // fmov 0x3ff0000000000000
static const int kScoreDigitCount = 7;
static const NSUInteger kScoreSlashSprite = '/'; // 0x2f, drawn after the leading blanks

// The result score tweens the displayed value halfway to the target each frame and draws its two
// panel sprites plus seven digit glyphs one hundred points apart (a wider six-figure layout), the
// glyph set switching above 700000 so seven-figure scores use narrower digits.
static const NSUInteger kScorePanelSprite = 9;
static const NSUInteger kScorePanelLabelSprite = 10;
static const int kResultScoreDigitStride = 50;                 // 0x32
static const unsigned int kScoreSevenFigureThreshold = 700000; // 0xaae60
static const int kScoreDigitBaseSmall = -0x15; // '0' maps to sprite 0x1b below the threshold
static const int kScoreDigitBaseLarge = -0xb;  // '0' maps to sprite 0x25 at/above the threshold

// The tune-info panel: the square artwork sprite, then a title and level plate to its right, and a
// difficulty badge whose horizontal offset depends on the chart difficulty.
static const NSUInteger kTuneArtworkSprite = 0xe;
static const NSUInteger kTuneTitleSprite = 0xf;
static const NSUInteger kTuneLevelPlateSprite = 0x10;
static const NSUInteger kTuneDifficultyBadgeSprite = 0x12;
static const double kTuneTitleXOffset = 17.0;           // fmov 17.0
static const double kTuneTitleYOffset = -15.0;          // fmov -15.0
static const double kTuneLevelPlateXOffset = 20.0;      // fmov 20.0
static const double kTuneLevelPlateYOffset = 58.0;      // @ghidraAddress 0x2929d8
static const double kTuneDifficultyBadgeYOffset = -6.0; // fmov -6.0
// The difficulty badge x-offset from the level plate, chosen by RendererConf.diff.
static const double kTuneDifficultyBadgeOffsetBasic = 96.0;     // @ghidraAddress 0x28f908 (diff 0)
static const double kTuneDifficultyBadgeOffsetAdvanced = 160.0; // @ghidraAddress 0x28f438 (diff 1)
static const double kTuneDifficultyBadgeOffsetExtreme = 143.0;  // @ghidraAddress 0x2924a8 (diff 2)
static const double kTuneDifficultyBadgeOffsetOther = 70.0;     // @ghidraAddress 0x28f6a0 (other)

// The partner's score is drawn only in a session, at half alpha until the partner connects, with a
// "partner" badge above it. The panels and digits are scaled by their sprite sizes times the scale.
static const NSUInteger kPartnerSizeSampleSprite = 0xa; // panel size reference
static const NSUInteger kPartnerDigitSizeSprite = 0x1b; // digit size reference
static const NSUInteger kPartnerBadgeSprite = 0x1a;
static const double kPartnerUnconnectedAlphaScale = 0.5; // fmov 0.5
static const double kPartnerBadgeXOffset = 2.0;          // fmov 2.0
static const double kPartnerBadgeYOffset = -25.0;        // fmov -25.0

// The result-screen render states: a finished chart, the result screen, and the result wait.
static const unsigned int kRenderStatePlay = 3;
static const unsigned int kRenderStateFinish = 4;
static const unsigned int kRenderStateResult = 5;

// The sub-state -endResult parks the result screen in once it is dismissed.
static const unsigned int kResultEndSubState = 99;

// The result-screen button grid: a button's centre is derived from its 4-wide index at a 192-point
// pitch, inset 96 horizontally and dropped 352 vertically.
static const unsigned int kButtonGridPitch = 0xc0;
static const unsigned int kButtonGridInsetX = 0x60;
static const unsigned int kButtonGridTopY = 0x160;

// The debug-text overlay lays glyphs out on a 12-point advance and a 20-point line height, capped
// at 0x200 glyphs; each printable character maps to the font sprite at its ASCII code minus space.
static const double kDebugGlyphAdvance = 12.0;
static const double kDebugLineHeight = 20.0;
enum { kDebugMaxGlyphs = 0x200 };

// The Excellent (perfect-million) result banner. Its final flourish, from frame 0x7c, scatters
// twenty sparkle particles from four parallel tables: the sprite index, the base x and y, and the
// per-particle scale (drawn at a shared -0.4746 rotation). Each of the first fifteen particles is
// also drawn four times as an offset shadow trail.
static const int kExcParticleSprite[] = { // @ghidraAddress 0x2942ac
    18, 18, 18, 19, 20, 20, 20, 21, 21, 18, 20, 18, 18, 20, 21, 4, 4, 4, 4, 4};
static const float kExcParticleX[] = { // @ghidraAddress 0x2942fc
    -33.0f, -35.0f, -15.0f, -25.0f, -4.0f,  -20.0f, 7.0f,   153.0f, 153.0f, 364.0f,
    115.0f, 352.0f, 370.0f, 364.0f, 329.0f, 207.0f, 399.0f, 591.0f, 208.0f, 16.0f};
static const float kExcParticleY[] = { // @ghidraAddress 0x29434c
    360.0f,  467.0f,  316.0f,  436.0f,  301.0f,  512.0f, 1019.0f, 1025.0f, 1033.0f, 1017.0f,
    1064.0f, 1067.0f, 1150.0f, 1135.0f, 1028.0f, 955.0f, 955.0f,  965.0f,  357.0f,  360.0f};
static const float kExcParticleScale[] = { // @ghidraAddress 0x29439c
    2.18f, 1.53f, 0.98f, 1.0f, 0.66f, 1.25f, 1.9f,  1.59f, 1.59f, 1.14f,
    1.59f, 2.0f,  1.23f, 1.0f, 1.07f, 0.18f, 0.18f, 0.18f, 0.18f, 0.18f};
static const int kExcParticleCount = 20;
static const int kExcSweepParticleFirst = 15; // particles 15..19 sweep out; 0..14 are static+trail
static const float kExcParticleRotate = -0.47459015f; // @ghidraAddress 0x2934c4
// The eight excellent panels fill the grid rows in this reflow order (a 16-entry table read every
// other frame), drawn inset 16 into a 192-point grid pitch, dropped 256 points, minus a 16-point
// half.
static const int kExcPanelOrder[] = { // @ghidraAddress 0x29426c
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
static const int kExcPanelPitch = 0xc0;     // 192
static const int kExcPanelInset = 0x10;     // 16
static const int kExcPanelGridTopY = 0x100; // 256
static const double kExcPanelHalf = -16.0;  // fmov, -16.0
static const NSUInteger kExcTitleSprite = 0xd;
static const NSUInteger kExcPanelSprite = 0xf;
static const NSUInteger kExcWordSprite = 4;
static const double kExcTitleLeftBaseX = 288.0; // @ghidraAddress 0x2926f8
static const double kExcTitleXOffset = -48.0;   // @ghidraAddress 0x292438
static const double kExcTitleLeftY = 544.0;     // @ghidraAddress 0x292a68
static const double kExcTitleRightBaseX = 96.0; // @ghidraAddress 0x28f908
static const double kExcTitleRightY = 736.0;    // @ghidraAddress 0x292a60
static const float kExcTitleSlideFrom = 96.0f;  // @ghidraAddress 0x293e64
// The Excellent word (texResult sprite 4) flies in as four glyph pairs over frames 0x60..0x74, each
// pair sliding from an off-screen x/y to its slot with a fade; the constants below are the per-pair
// slide-from and target values.
static const float kExcWordScatterY = 864.0f;     // @ghidraAddress 0x293e68
static const float kExcWord1XTo = -150.0f;        // @ghidraAddress 0x293e6c
static const float kExcWord1YFrom = 736.0f;       // @ghidraAddress 0x293e70
static const float kExcWord1YTo = 61.0f;          // @ghidraAddress 0x293e74
static const float kExcWord1XFrom = 352.0f;       // @ghidraAddress 0x2932d0
static const float kExcWordScale = 1.3333334f;    // @ghidraAddress 0x293e78
static const float kExcWord2XTo = 480.0f;         // @ghidraAddress 0x293e7c
static const float kExcWord2XFrom = 544.0f;       // @ghidraAddress 0x293e80
static const float kExcWord3XTo = -672.0f;        // @ghidraAddress 0x293e84
static const float kExcWord3XOffset = -93.0f;     // @ghidraAddress 0x293e88
static const float kExcWord3YFrom = 928.0f;       // @ghidraAddress 0x293e8c
static const float kExcWord3Scale = 0.65f;        // @ghidraAddress 0x293e90
static const float kExcWord3XFrom2 = -288.0f;     // @ghidraAddress 0x293e94
static const float kExcWord4YFrom = 160.0f;       // @ghidraAddress 0x28e014
static const float kExcWord4XTo = -39.0f;         // @ghidraAddress 0x293e98
static const float kExcWord4YTo = 63.0f;          // @ghidraAddress 0x293e9c
static const float kExcFlourishXFrom = -198.0f;   // @ghidraAddress 0x293ea0
static const float kExcFlourishXSpread = 1536.0f; // @ghidraAddress 0x293ea4
static const float kExcSweepThreshold = 640.0f;   // @ghidraAddress 0x2934ec
static const float kExcParticleSpread = 192.0f;   // @ghidraAddress 0x2925a0
static const double kExcWordFive = 5.0;           // fmov, 5.0

// The excellent title glyphs fill the 4x4 grid rows; sound cues fire at set frames.
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

// The result screen composes the sub-renderers and lays out the score, tune info, music bar,
// partner score, combo, and the win/clear/fail banner, then the new-record stamp and the
// good-job/vote overlay. The shutter closes over its own frames; a perfect million shows Excellent,
// 700000+ shows Cleared, else Failed.
static const float kShutterCloseThreshold = 43.5f;        // @ghidraAddress 0x292b58
static const float kShutterCloseStep = -43.5f;            // @ghidraAddress 0x292b54
static const double kResultArtworkX = 18.0;               // fmov, 18.0
static const double kResultArtworkY = 25.0;               // fmov, 25.0
static const double kResultArtworkSize = 160.0;           // @ghidraAddress 0x28f438
static const double kResultMusicBarX = 8.0;               // fmov, 8.0
static const double kResultMusicBarY = 208.0;             // @ghidraAddress 0x2929f0
static const double kResultScoreX = 412.0;                // @ghidraAddress 0x2929f8
static const double kResultScoreY = 138.0;                // @ghidraAddress 0x2924c8
static const double kResultPartnerX = 516.0;              // @ghidraAddress 0x292a00
static const double kResultPartnerY = 80.0;               // @ghidraAddress 0x28f3f8
static const double kResultPartnerScale = 0.7;            // @ghidraAddress 0x291c98
static const unsigned int kResultBannerStartFrame = 0x1e; // 30
static const unsigned int kClearedScoreThreshold = 699999;
static const int kMillionScore = 1000000;
// The new-record stamp slides in over frames 0x41..0x49 and its updated-score readout trails it.
static const unsigned int kNewRecordStartFrame = 0x41; // 65
static const unsigned int kNewRecordEndFrame = 0x49;   // 73
static const unsigned int kNewRecordGateFrame = 0x40;  // shown once past frame 64
static const float kNewRecordSlideFrom = 168.0f;       // @ghidraAddress 0x292fc0
static const float kNewRecordSlideTo = 226.0f;         // @ghidraAddress 0x293ea8
static const float kNewRecordXBase = 412.0f;           // @ghidraAddress 0x292b64
static const double kNewRecordStampY = 185.0;          // @ghidraAddress 0x293e48
static const double kNewRecordScoreXOffset = -128.0;   // @ghidraAddress 0x292e80
static const double kNewRecordScoreY = 187.0;          // @ghidraAddress 0x293e50
static const NSUInteger kNewRecordStampSprite = 0x19;
static const double kNewRecordXNudge = 1.0;   // fmov, 1.0
static const double kResultEightNudge = -8.0; // fmov, -8.0
// The retry/vote overlay: the replay-tag sprite, the vote strip swapped in from a resource, and the
// good-job image fading to its configured maximum.
static const double kResultTagScale = 0.125; // 1/8, fmov
static const NSUInteger kResultReplayTagSprite = 0x11;
static const double kResultReplayTagX = 584.0; // @ghidraAddress 0x292a78
static const double kResultOverlayY = 852.0;   // @ghidraAddress 0x292a80
static const NSUInteger kResultVoteSprite = 0x14;
static const double kResultVoteX = 392.0;                            // @ghidraAddress 0x292a88
static NSString *const kResultVoteResource = @"game_level_vote_knt"; // @ghidraAddress 0x2e1fc0
static const NSTimeInterval kGoodJobFadeDuration = 0.3;              // @ghidraAddress 0x28f260
static NSString *const kSeVoiceResult = @"SD_KNT_CV_RESULT";         // @ghidraAddress 0x2dfa00
static const unsigned int kResultSubStateComplete = 10;

// The Knit music bar is a single backdrop sprite with 0x78 note cells five points apart, each a
// marker sprite chosen by the note value plus a state-dependent base: idle, cursor-lit, or one of
// four graded bases (indexed by the 2-bit per-cell grade XOR 2). A cell shows its graded marker
// once finished/result/replay or once the play cursor has passed its fade-out point.
static const NSUInteger kMusicBarBackdropSprite = 0xb;
static const NSUInteger kMusicBarPlayHeadSprite = 0x13;
static const double kMusicBarBackdropXOffset = -8.0; // fmov -8.0
static const double kMusicBarCellBaseXOffset = 0.0;  // @ghidraAddress 0x292488
static const double kMusicBarCellYOffset = 1.0;      // fmov 1.0
static const int kMusicBarCellPitch = 5;
static const int kMusicBarNoteBaseIdle = 0x3a;
static const int kMusicBarNoteBaseCursor = 0x42;
// Indexed by the per-cell 2-bit grade (XOR 2) to pick the graded note-marker sprite base.
static const int kMusicBarRatingSpriteBase[] = {0x4a, 0x3a, 0x52, 0x42}; // @ghidraAddress 0x293ec0
static const float kMusicBarCursorScale = 120.0f;                        // @ghidraAddress 0x291be8
static const float kMusicBarFadeStart = 0.3f;                            // @ghidraAddress 0x28e0b0
static const float kMusicBarFadeEnd = 1.2999999523162842f;               // @ghidraAddress 0x292558
static const float kMusicBarPlayHeadScale = 600.0f;                      // @ghidraAddress 0x291c3c
static const float kMusicBarPlayHeadXOffset = 74.0f;                     // @ghidraAddress 0x28fa28
static const double kMusicBarPlayHeadY = 197.0;                          // @ghidraAddress 0x28f6b0
enum { kMusicBarCellCount = 0x78 };

// The 4x4 marker grid: each panel sits on a 192-point pitch inset 16 points, the rows pushed 256
// points down. A marker's animation word packs a phase (low 12 bits) and a slot (next 3 bits); the
// slot and phase pick a marker sprite. The first-marker start highlight fades in over the last
// hundred sectors of its 150-sector approach; random mode reshuffles the marker's facing.
static const int kMarkerPanelPitch = 0xc0;     // 192, per-panel grid pitch
static const int kMarkerPanelInset = 0x10;     // 16, grid inset within each cell
static const int kMarkerGridTopOffset = 0x100; // 256, rows pushed down
static const int kMarkerGridColumns = 4;
static const unsigned int kMarkerPhaseMask = 0xfff;
static const unsigned int kMarkerSlotShift = 0xc;
static const unsigned int kMarkerSlotMask = 7;
static const unsigned int kMarkerPhaseSlot0Limit = 0xef;
static const unsigned int kMarkerPhaseLimit = 0xa0;
static const unsigned int kMarkerSlotLimit = 6;
static const int kMarkerSpritePhaseDivisor = 10;
static const int kMarkerSpriteSlot0Base = 4;
static const int kMarkerSpriteSlotStride = 0x10;
static const int kMarkerSpriteSlotBias = -4;
static const int kMarkerDirModulo = 4;
static const int kMarkerHighlightSector = 0x96; // 150
static const int kMarkerFadeClampSectors = 100; // clamp to 1.0 at/after this many sectors
static const float kMarkerFadeDivisor = 100.0f; // @ghidraAddress 0x28f4e0

// The start-mark intro burst on each first-marker panel: three clipped burst glyphs plus the
// rising centre glyph. The rise and fade-in run over frames 4..8; the pulse runs up over the first
// fifty of each 120-frame cycle then down over the next thirty; the sweep runs -100..100 over the
// first eighty frames.
static const NSUInteger kStartMarkBurstMidSprite = 0x16;
static const NSUInteger kStartMarkBurstTopSprite = 0x17;
static const NSUInteger kStartMarkBurstBottomSprite = 0x15;
static const NSUInteger kStartMarkCentreSprite = 0x14;
static const double kStartMarkClipInset = -11.0;     // fmov -11.0
static const double kStartMarkClipSize = 178.0;      // @ghidraAddress 0x291cf8
static const double kStartMarkTopYOffset = 15.0;     // fmov 15.0
static const double kStartMarkBottomYOffset = 120.0; // @ghidraAddress 0x28f210
static const double kStartMarkAnchorSize = 80.0;     // @ghidraAddress 0x28f3f8
static const float kStartMarkSweepDivisor = 5.0f;    // fmov 5.0
static const float kStartMarkRiseFrom = 8.0f;        // fmov 8.0
static const unsigned int kStartMarkRiseStartFrame = 4;
static const unsigned int kStartMarkRiseEndFrame = 8;
static const unsigned int kStartMarkCycleLength = 0x78; // 120
static const unsigned int kStartMarkPulsePeak = 0x32;   // 50
static const unsigned int kStartMarkPulseEnd = 0x50;    // 80
static const float kStartMarkSweepFrom = -100.0f;       // @ghidraAddress 0x2934a4
static const float kStartMarkSweepTo = 100.0f;          // @ghidraAddress 0x28f4e0

// The combo display: a combo-cut flash sprite that shrinks from 1.2 and fades in over eight frames
// when the combo drops, then the combo digits (up to four) with a downward-rippling bounce driven
// by the combo-effect frame, and a trailing "combo" word sprite. The digit glyph is its ASCII code
// minus 0x2c; digits sit 0xba apart, the word 0xa2 past the last digit.
static const unsigned int kComboMinToShow = 4; // the combo cut and digits need more than four
static const unsigned int kComboCutFrames = 8;
static const float kComboCutScaleFrom = 1.2000000476837158f; // @ghidraAddress 0x292aa8
static const double kComboCutCentreX = 384.0;                // @ghidraAddress 0x292470
static const float kComboCutY = 486.0f;                      // @ghidraAddress 0x293e5c
static const double kComboCutAnchorY = 486.0;                // @ghidraAddress 0x2929c8
static const NSUInteger kComboCutSprite = 1;
static const unsigned int kComboEffectFrames = 10;
static const unsigned int kComboMaxDigits = 4;
static const int kComboDigitStride = 0xba; // 186
static const int kComboDigitStartXBase = 0x300;
static const double kComboDigitY = 486.0;          // @ghidraAddress 0x2929c8
static const int kComboDigitYBase = 0x1e6;         // 486
static const int kComboGlyphBias = -0x2c;          // ASCII digit to combo glyph sprite
static const int kComboWordTrailingOffset = -0xa2; // -162, the word's x past the last digit
static const double kComboWordY = 720.0;           // @ghidraAddress 0x2929d0
static const NSUInteger kComboWordSprite = 0;

// The result-screen rating: a rating-label sprite slides up into place and fades in, then the rank
// sprite pops (overshooting and settling), both timings shortening for the top ranks. The rank
// sprite is centre-anchored and scaled about its centre.
static const NSUInteger kRatingLabelSprite = 0xe;
static const NSUInteger kRatingRankSprite = 0x10;
static const double kRatingLabelX = 218.0;        // @ghidraAddress 0x2924d8
static const double kRatingLabelBaseY = 656.0;    // @ghidraAddress 0x292520
static const double kRatingLabelSlideY = 120.0;   // @ghidraAddress 0x28f210
static const double kRatingRankAnchorX = 480.0;   // @ghidraAddress 0x28e020
static const double kRatingRankAnchorY = 746.0;   // @ghidraAddress 0x292480
static const float kRatingLabelSlideFrom = 25.0f; // fmov 25.0
static const float kRatingScaleLow = 1.16f;       // @ghidraAddress 0x292b34
static const float kRatingScaleBig = 1.6f;        // @ghidraAddress 0x292b30
static const float kRatingScaleSmall = 0.2f;      // @ghidraAddress 0x28f3c8
static const float kRatingScaleMid = 0.9f;        // @ghidraAddress 0x28f3b0

// The origin of grid panel @p index within the Knit marker grid.
static inline CGPoint MainGameRendererPadKntPanelOrigin(int index) {
    int x = (index % kMarkerGridColumns) * kMarkerPanelPitch | kMarkerPanelInset;
    int y = ((index / kMarkerGridColumns) * kMarkerPanelPitch | kMarkerPanelInset) +
            kMarkerGridTopOffset;
    return CGPointMake((double)x, (double)y);
}

// Resolves a marker animation word into a texMarker sprite index, or returns NO when the panel has
// no active marker to draw.
static inline BOOL
MainGameRendererPadKntMarkerSprite(unsigned int phase, unsigned int slot, int *sprite) {
    if (slot == 0) {
        if (phase > kMarkerPhaseSlot0Limit) {
            return NO;
        }
        *sprite = (int)(phase / kMarkerSpritePhaseDivisor) + kMarkerSpriteSlot0Base;
        return YES;
    }
    if (phase < kMarkerPhaseLimit && slot < kMarkerSlotLimit) {
        int candidate = (int)(phase / kMarkerSpritePhaseDivisor) +
                        (int)slot * kMarkerSpriteSlotStride + kMarkerSpriteSlotBias;
        if (candidate >= 0) {
            *sprite = candidate;
            return YES;
        }
    }
    return NO;
}

// The Excellent banner's final sparkle burst (frame >= 0x7c): twenty particles from the parallel
// tables. Particles 6..17 rise by the flourish offset, others fall by it; particles 15..19 sweep
// outward (away from the 640-point centre line) and, from frame 0x8d, ripple on a 48-frame cycle,
// each drawn as a five-step offset trail (skipping the zero step) plus the particle itself.
static inline void MainGameRendererPadKntRenderExcellentBurst(MainGameRendererPadKnt *self,
                                                              unsigned int animFrame) {
    float rise = InterpolateFloatByFrame(kExcFlourishXFrom, 0.0f, animFrame, 0x7c, 0x80) + 6.0f;
    if (animFrame > 0x7f) {
        rise -= (float)((int)(animFrame * 2) - 0x100);
        if (rise < 0.0f) {
            rise = 0.0f;
        }
    }
    float sweep = InterpolateFloatByFrame(kExcFlourishXSpread, 0.0f, animFrame, 0x7c, 0x86);
    for (int i = 0; i < kExcParticleCount; ++i) {
        float x = kExcParticleX[i];
        float y = kExcParticleY[i];
        // Particles 6..17 rise; the rest fall.
        float shifted =
            ((unsigned int)(i - 6) < 0xc) ? rise + kExcParticleY[i] : kExcParticleY[i] - rise;
        if (i < kExcSweepParticleFirst) {
            y = shifted;
        }
        if ((unsigned int)(i - kExcSweepParticleFirst) < 5) {
            // The last five particles sweep away from the centre line and ripple after frame 0x8d.
            float dir = (y >= kExcSweepThreshold) ? -1.0f : 1.0f;
            x = x + sweep * dir;
            y = y - sweep * 0.5f * dir;
            int ripple = ((((i << 3) ^ -1) & 8) - 4) * ((int)(animFrame - 0x8c) % 0x30);
            if (animFrame > 0x8c) {
                y = y - (float)ripple;
                x = (float)(ripple * 2) + x;
            }
            for (int step = -4; step <= 4; ++step) {
                if (step == 0) {
                    continue;
                }
                double sx = (double)(x + (float)step * kExcParticleSpread);
                double sy = (double)(y + (float)step * kExcParticleSpread * -0.5f);
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

@implementation MainGameRendererPadKnt

/** @ghidraAddress 0x1fdf14 */
- (instancetype)init {
    self = [super init];
    if (self) {
        self.arrayBgEff = [[NSMutableArray alloc] init];
        self.upperBgKnt = [[UpperBGKnit alloc] init];
        [self.upperBgKnt initBg:CGRectMake(0.0, 0.0, 768.0, 256.0)
                     waveBottom:150.0f
                        waveTop:20.0f
                    pulseHeight:30.0f
                          isPad:YES];
        self->effFrame = 0;
    }
    return self;
}

/** @ghidraAddress 0x20036c */
- (void)releaseTexture {
    self.texDebugFont = nil;
    self.texReady0 = nil;
    self.texReady1 = nil;
    self.texFront = nil;
    self.texResult = nil;
    self.texResultBg = nil;
    self.texBeatBg = nil;
    if (self.texWaveAr != nil) {
        [self.texWaveAr removeAllObjects];
        self.texWaveAr = nil;
    }
}

/** @ghidraAddress 0x206d7c */
- (void)dealloc {
    [self releaseTexture];
    // [super dealloc] is compiler-emitted (ARC).
}

/** @ghidraAddress 0x20048c */
- (void)setState:(unsigned int)state {
    switch (state) {
    case 0:
        self->lastCombo = 0;
        self->comboCutFrame = 0;
        self->comboEffectFrame = 0;
        self->scoreDisplay = 0;
        self->shutterOpen = 0;
        self->lastHakuPhase = 0;
        self->bounceEnergy = 0;
        self.scoreRecord = nil;
        break;
    case 2:
        self->lastCombo = 0;
        self->comboCutFrame = 0;
        self->comboEffectFrame = 0;
        self->scoreDisplay = 0;
        self->shutterOpen = 0;
        self->startMarkFrame = 0;
        self.scoreRecord = nil;
        if (self.sePlayerGo == nil) {
            NSString *path = [NSBundle.mainBundle pathForResource:@"SD_KNT_CV_GO" ofType:@"caf"];
            self.sePlayerGo =
                [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                       error:nil];
            [self.sePlayerGo prepareToPlay];
        }
        break;
    case 5:
        [[AudioManager sharedManager] loadBgmResAAC:@"SD_KNT_BGM_RESULT" inDirectory:nil];
        [[AudioManager sharedManager] startBgm:YES fadeTime:0.0];
        break;
    case 6:
        // The frame counter is left running for state 6; every other state resets it below.
        [super setState:state];
        return;
    default:
        break;
    }
    self->frame = 0;
    [super setState:state];
}

/** @ghidraAddress 0x2007e4 */
- (void)startPlay {
    [self setState:kRenderStatePlay];
    self.sePlayerGo = nil;
}

/** @ghidraAddress 0x200820 */
- (void)endResult {
    if (self.state == kRenderStateResult) {
        self.subState = kResultEndSubState;
    }
}

/** @ghidraAddress 0x206c14 */
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

/** @ghidraAddress 0x206ddc */
- (void)replaySelect {
    if (self.isCustom && self.isDownload && self.hasMusic) {
        self.replayPlaying = YES;
        // spriteAtIndex: is called only for its side effect on the shared draw scratch; the point
        // then read is the atlas origin, so the start mark reloads at (0, 0).
        [self.texFront spriteAtIndex:20];
        LoadTextureSubImageFromResource(
            self.texFront, @"game_start_mark_knt", CGPointMake(0.0, 0.0));
        self.isTextureChange = NO;

        /** @ghidraAddress 0x28f260 */
        static const NSTimeInterval kGoodJobFadeDuration = 0.3;
        __weak UIImageView *goodJob = self.goodJobImage;
        [UIView animateWithDuration:kGoodJobFadeDuration
                         animations:^{
                           /** @ghidraAddress 0x206f98 */
                           [goodJob setAlpha:0.0f];
                         }
                         completion:^(BOOL finished){
                             /** @ghidraAddress 0x206fe4 */
                             // The completion block is the shared empty global block.
                         }];
    }
}

/** @ghidraAddress 0x206dcc */
- (void)replayEnd {
    self.replayPlaying = NO;
}

/** @ghidraAddress 0x203238 */
- (double)durationOfReadyGo {
    return kReadyGoDuration;
}

/** @ghidraAddress 0x205a98 */
- (double)buttonAreaOffset {
    return 0.0;
}

/** @ghidraAddress 0x205aa0 */
- (double)gameAreaOffset {
    return kGameAreaOffset;
}

/** @ghidraAddress 0x205aac */
- (unsigned int)endButtonID {
    return kEndButtonID;
}

/** @ghidraAddress 0x205ab4 */
- (unsigned int)evaluateButtonID {
    return kEvaluateButtonID;
}

/** @ghidraAddress 0x205abc */
- (unsigned int)goodJobButtonID {
    return kGoodJobButtonID;
}

/** @ghidraAddress 0x205b34 */
- (unsigned int)twitterSendButtonID {
    return kEvaluateButtonID;
}

/** @ghidraAddress 0x205bac */
- (unsigned int)storeMoveButtonID {
    return kEvaluateButtonID;
}

/** @ghidraAddress 0x205ac4 */
- (CGPoint)goodJobPosition {
    unsigned int buttonID = self.goodJobButtonID;
    return CGPointMake((double)((buttonID & 3) * kButtonGridPitch + kButtonGridInsetX),
                       (double)((buttonID >> 2) * kButtonGridPitch + kButtonGridTopY));
}

/** @ghidraAddress 0x205b3c */
- (CGPoint)twitterBtnPosition {
    unsigned int buttonID = self.twitterSendButtonID;
    return CGPointMake((double)((buttonID & 3) * kButtonGridPitch + kButtonGridInsetX),
                       (double)((buttonID >> 2) * kButtonGridPitch + kButtonGridTopY));
}

/** @ghidraAddress 0x205bb4 */
- (CGPoint)storeMoveBtnPosition {
    unsigned int buttonID = self.storeMoveButtonID;
    return CGPointMake((double)((buttonID & 3) * kButtonGridPitch + kButtonGridInsetX),
                       (double)((buttonID >> 2) * kButtonGridPitch + kButtonGridTopY));
}

/** @ghidraAddress 0x202390 */
- (CGRect)getMusicBarRect {
    return musicBarRect;
}

/** @ghidraAddress 0x204dd0 */
- (void)renderRating:(unsigned int)animFrame {
    int rank = (int)self.sequence.rank;
    float rankScale;
    float rankAlpha;
    if (rank < 5) {
        // The rating label slides up and fades in over a rank-dependent window; the rank sprite
        // overshoots to 2.0 then settles.
        unsigned int popEnd = (rank < 3) ? 4 : 3;
        unsigned int settleEnd = (rank < 3) ? 0xe : 7;
        float labelSlide =
            InterpolateFloatByFrame(kRatingLabelSlideFrom, 0.0f, animFrame, 0, settleEnd);
        float labelAlpha = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 0, settleEnd);
        [self.texResult
            drawSprite:kRatingLabelSprite
               atPoint:CGPointMake(kRatingLabelX,
                                   (double)labelSlide + kRatingLabelBaseY + kRatingLabelSlideY)
             transform:0
                 alpha:labelAlpha];
        CGSize rankSize = [self.texResult spriteAtIndex:kRatingRankSprite].size;
        if (animFrame < popEnd) {
            rankScale = InterpolateFloatByFrame(2.0f, kRatingScaleLow, animFrame, 0, popEnd);
        } else {
            rankScale =
                InterpolateFloatByFrame(kRatingScaleLow, 1.0f, animFrame, popEnd, settleEnd);
        }
        rankAlpha = labelAlpha;
        [self.texResult drawSprite:kRatingRankSprite
                           atPoint:CGPointMake(kRatingRankAnchorX - rankSize.width * 0.5,
                                               kRatingRankAnchorY - rankSize.height * 0.5)
                             scale:rankScale
                            rotate:0
                            anchor:CGPointMake(kRatingRankAnchorX, kRatingRankAnchorY)
                         transform:0
                             alpha:rankAlpha];
        return;
    }
    // The top ranks (rank >= 5): the label slides in over a fixed window and the rank sprite pops
    // through several frame windows before settling.
    float labelSlide = InterpolateFloatByFrame(kRatingLabelSlideFrom, 0.0f, animFrame, 0, 0xd);
    float labelAlpha = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 0, 0xd);
    [self.texResult
        drawSprite:kRatingLabelSprite
           atPoint:CGPointMake(kRatingLabelX,
                               (double)labelSlide + kRatingLabelBaseY + kRatingLabelSlideY)
         transform:0
             alpha:labelAlpha];
    CGSize rankSize = [self.texResult spriteAtIndex:kRatingRankSprite].size;
    if (animFrame < 8) {
        rankScale = InterpolateFloatByFrame(2.0f, kRatingScaleBig, animFrame, 0, 8);
        rankAlpha = InterpolateFloatByFrame(kRatingScaleSmall, 0.0f, animFrame, 8, 0xd);
    } else if (animFrame < 0xe) {
        rankScale = InterpolateFloatByFrame(kRatingScaleBig, kRatingScaleMid, animFrame, 8, 0xe);
        rankAlpha = InterpolateFloatByFrame(kRatingScaleSmall, 0.0f, animFrame, 8, 0xd);
    } else if (animFrame < 0x10) {
        rankScale = InterpolateFloatByFrame(kRatingScaleMid, 1.0f, animFrame, 0xe, 0x10);
        rankAlpha = InterpolateFloatByFrame(kRatingScaleSmall, 0.0f, animFrame, 8, 0xd);
    } else {
        rankScale = 1.0f;
        rankAlpha = InterpolateFloatByFrame(kRatingScaleMid, 1.0f, animFrame, 8, 0xd);
    }
    [self.texResult drawSprite:kRatingRankSprite
                       atPoint:CGPointMake(kRatingRankAnchorX - rankSize.width * 0.5,
                                           kRatingRankAnchorY - rankSize.height * 0.5)
                         scale:rankScale
                        rotate:0
                        anchor:CGPointMake(kRatingRankAnchorX, kRatingRankAnchorY)
                     transform:0
                         alpha:rankAlpha];
}

/** @ghidraAddress 0x2042e4 */
- (BOOL)renderExcellent:(unsigned int)animFrame {
    // Sound cues at set frames: the rating voice, the panel hit, the excellent-string cue (three
    // times), and, on the final flourish, the result sting plus the excellent voice.
    switch (animFrame) {
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

    // The two title glyphs slide in from the sides and fade in over frames 0..8, fading back out
    // after frame 40.
    float titleSlide = InterpolateFloatByFrame(kExcTitleSlideFrom, 0.0f, animFrame, 0, 8);
    float titleAlpha = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 0, 8);
    if (animFrame > kExcPanelFrame) {
        titleAlpha = InterpolateFloatByFrame(1.0f, 0.0f, animFrame, 0x28, 0x32);
    }
    double titleH = [self.texResultBg spriteAtIndex:kExcTitleSprite].size.height;
    [self.texResultBg
        drawSprite:kExcTitleSprite
           atPoint:CGPointMake((double)titleSlide + kExcTitleLeftBaseX + kExcTitleXOffset,
                               kExcTitleLeftY - titleH * 0.5)
         transform:0
             alpha:titleAlpha];
    [self.texResultBg
        drawSprite:kExcTitleSprite
           atPoint:CGPointMake((kExcTitleRightBaseX - (double)titleSlide) + kExcTitleXOffset,
                               kExcTitleRightY - titleH * 0.5)
         transform:0
             alpha:titleAlpha];

    // The eight excellent panels fill the grid's top and bottom rows as the frame passes each.
    for (int i = 0; i < 16; i += 2) {
        if (i / 2 > (int)(animFrame - kExcPanelFrame)) {
            continue;
        }
        int panel = kExcPanelOrder[i / 2];
        double px = (double)((panel % 4) * kExcPanelPitch | kExcPanelInset) + kExcPanelHalf;
        double py = (double)(((panel >> 2) * kExcPanelPitch | kExcPanelInset) + kExcPanelGridTopY) +
                    kExcPanelHalf;
        [self.texResultBg drawSprite:kExcPanelSprite
                              inRect:CGRectMake(px, py, kExcPanelSpread, kExcPanelSpread)];
    }

    // The Excellent word flies in as glyph pairs across frames 0x60..0x74; each pair slides from
    // off-screen to its slot with a fade.
    if (animFrame >= kExcStringFrame0) {
        float g1x =
            InterpolateFloatByFrame(kExcWordScatterY, kExcTitleSlideFrom, animFrame, 0x60, 0x67) +
            kExcWord1XTo;
        float g1y = InterpolateFloatByFrame(kExcWord1XFrom, kExcWord1YFrom, animFrame, 0x60, 0x67) +
                    kExcWord1YTo;
        [self.texResult drawSprite:kExcWordSprite
                           atPoint:CGPointMake((double)g1x, (double)g1y)
                             scale:kExcWordScale
                            rotate:kExcParticleRotate
                            anchor:CGPointMake((double)g1x, (double)g1y)
                         transform:0
                             alpha:1.0f];
        float g2x =
            InterpolateFloatByFrame(kExcWord2XTo, kExcTitleSlideFrom, animFrame, 0x60, 0x67) +
            kExcWord1XTo;
        float g2y = InterpolateFloatByFrame(kExcWord2XFrom, kExcWord1YFrom, animFrame, 0x60, 0x67) +
                    kExcWord1YTo;
        float g2a = InterpolateFloatByFrame(0.0f, 0.5f, animFrame - 0x60, 0, 4);
        [self.texResult drawSprite:kExcWordSprite
                           atPoint:CGPointMake((double)g2x, (double)g2y)
                             scale:kExcWordScale
                            rotate:kExcParticleRotate
                            anchor:CGPointMake((double)g2x, (double)g2y)
                         transform:0
                             alpha:g2a];
        if (animFrame > kExcStringFrame1) {
            float g3x =
                InterpolateFloatByFrame(kExcWord3XTo, kExcTitleSlideFrom, animFrame, 0x67, 0x6e) +
                kExcWord3XOffset;
            float g3y =
                InterpolateFloatByFrame(kExcWord3YFrom, kExcWord2XFrom, animFrame, 0x67, 0x6e);
            [self.texResult drawSprite:kExcWordSprite
                               atPoint:CGPointMake((double)g3x, (double)(g3y + kExcWordFive))
                                 scale:kExcWord3Scale
                                rotate:kExcParticleRotate
                                anchor:CGPointMake((double)g3x, (double)(g3y + kExcWordFive))
                             transform:0
                                 alpha:1.0f];
            float g4x = InterpolateFloatByFrame(
                            kExcWord3XFrom2, kExcTitleSlideFrom, animFrame, 0x67, 0x6e) +
                        kExcWord3XOffset;
            float g4y =
                InterpolateFloatByFrame(kExcWord1YFrom, kExcWord2XFrom, animFrame, 0x67, 0x6e);
            float g4a = InterpolateFloatByFrame(0.0f, 0.5f, animFrame - 0x67, 0, 4);
            [self.texResult drawSprite:kExcWordSprite
                               atPoint:CGPointMake((double)g4x, (double)(g4y + kExcWordFive))
                                 scale:kExcWord3Scale
                                rotate:kExcParticleRotate
                                anchor:CGPointMake((double)g4x, (double)(g4y + kExcWordFive))
                             transform:0
                                 alpha:g4a];
            if (animFrame > kExcStringFrame2) {
                float g5x = InterpolateFloatByFrame(
                                kExcWord1XTo, kExcTitleSlideFrom, animFrame, 0x6e, 0x75) +
                            kExcWord4XTo;
                float g5y =
                    InterpolateFloatByFrame(kExcWord4YFrom, kExcWord2XFrom, animFrame, 0x6e, 0x75) +
                    kExcWord4YTo;
                [self.texResult drawSprite:kExcWordSprite
                                   atPoint:CGPointMake((double)g5x, (double)g5y)
                                     scale:1.0f
                                    rotate:kExcParticleRotate
                                    anchor:CGPointMake((double)g5x, (double)g5y)
                                 transform:0
                                     alpha:1.0f];
                float g6x = InterpolateFloatByFrame(
                                kExcWord2XTo, kExcTitleSlideFrom, animFrame, 0x6e, 0x75) +
                            kExcWord4XTo;
                float g6y =
                    InterpolateFloatByFrame(kExcWord1XFrom, kExcWord2XFrom, animFrame, 0x6e, 0x75) +
                    kExcWord4YTo;
                float g6a = InterpolateFloatByFrame(0.0f, 0.5f, animFrame - 0x6e, 0, 4);
                [self.texResult drawSprite:kExcWordSprite
                                   atPoint:CGPointMake((double)g6x, (double)g6y)
                                     scale:1.0f
                                    rotate:kExcParticleRotate
                                    anchor:CGPointMake((double)g6x, (double)g6y)
                                 transform:0
                                     alpha:g6a];
                if (animFrame > 0x7b) {
                    MainGameRendererPadKntRenderExcellentBurst(self, animFrame);
                }
            }
        }
    }
    return animFrame > 0x95;
}

/** @ghidraAddress 0x2051b8 */
- (BOOL)renderCleared:(unsigned int)animFrame {
    static const float kBannerSlideFrom = 544.0f;                   // @ghidraAddress 0x293e80
    static const float kBannerTopTo = 352.0f;                       // @ghidraAddress 0x2932d0
    static const float kBannerMidTo = 928.0f;                       // @ghidraAddress 0x293e8c
    static const double kFieldWidth = 768.0;                        // @ghidraAddress 0x292460
    static const double kBannerMidWidth = 576.0;                    // @ghidraAddress 0x291d88
    static const double kBannerBoxWidth = 192.0;                    // @ghidraAddress 0x28fa00
    static const double kWordCentreX = 384.0;                       // @ghidraAddress 0x292470
    static const double kWordCentreY = 544.0;                       // @ghidraAddress 0x292a68
    static const float kWordScaleFrom = 0.3f;                       // @ghidraAddress 0x28e0b0
    static const int kPanelPitch = 0xc0;                            // 192, per-panel grid pitch
    static const int kPanelInsetX = 0x60;                           // 96, grid horizontal inset
    static const int kPanelGridTopY = 0x160;                        // 352, rows pushed down
    static const int kPanelReflowStride = 0xc;                      // 12, the 4x4 reflow multiplier
    static NSString *const kSeResultClear = @"SD_KNT_RESULT_CLEAR"; // @ghidraAddress 0x2df940
    static NSString *const kSeVoiceClear = @"SD_KNT_CV_CLEAR";      // @ghidraAddress 0x2df960

    float fadeIn = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 0, 8);

    // The banner strips sample sprite 6 only for its height, then draw the wider sprite 7
    // stretched.
    double plateH = [self.texResultBg spriteAtIndex:6].size.height;
    float topY = InterpolateFloatByFrame(kBannerSlideFrom, kBannerTopTo, animFrame, 0, 0x10);
    [self.texResultBg drawSprite:7
                          inRect:CGRectMake(0.0, (double)topY - plateH * 0.5, kFieldWidth, plateH)];

    double midY =
        (double)InterpolateFloatByFrame(kBannerSlideFrom, kBannerMidTo, animFrame, 0, 0x10) -
        plateH * 0.5;
    [self.texResultBg drawSprite:7 inRect:CGRectMake(0.0, midY, kBannerMidWidth, plateH)];
    [self.texResultBg drawSprite:7
                          inRect:CGRectMake(kBannerMidWidth, midY, kBannerBoxWidth, plateH)
                       transform:0
                           alpha:1.0f];

    // The eight clear panels fill the grid's top and bottom rows; the last is drawn full opacity.
    CGSize panelSize = [self.texResultBg spriteAtIndex:5].size;
    for (int i = 0; i < 8; ++i) {
        float cellAlpha = (i == 7) ? 1.0f : fadeIn;
        int reflowed = i % 4 + (i >> 2) * kPanelReflowStride;
        double px = (double)((reflowed % 4) * kPanelPitch + kPanelInsetX);
        double py = (double)((reflowed >> 2) * kPanelPitch + kPanelGridTopY);
        [self.texResultBg
            drawSprite:5
               atPoint:CGPointMake(px - panelSize.width * 0.5, py - panelSize.height * 0.5)
                 scale:1.0f
                rotate:0
                anchor:CGPointMake(px, py)
             transform:0
                 alpha:cellAlpha];
    }

    // The "cleared" word (texResult sprite 0) scales up from 0.3 and fades in over frames 0..6,
    // anchored at the field centre.
    float wordAlpha = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 0, 6);
    float wordScale = InterpolateFloatByFrame(kWordScaleFrom, 1.0f, animFrame, 0, 6);
    CGSize wordSize = [self.texResult spriteAtIndex:0].size;
    [self.texResult drawSprite:0
                       atPoint:CGPointMake(kWordCentreX - wordSize.width * 0.5,
                                           kWordCentreY - wordSize.height * 0.5)
                         scale:wordScale
                        rotate:0
                        anchor:CGPointMake(kWordCentreX, kWordCentreY)
                     transform:0
                         alpha:wordAlpha];

    // The clear jingle and voice play once; from frame 10 the rating tally counts up.
    if (animFrame < 10) {
        if (animFrame == 0) {
            [[AudioManager sharedManager] playSeResFile:kSeResultClear inDirectory:nil];
            [[AudioManager sharedManager] playSeResFile:kSeVoiceClear inDirectory:nil];
        }
    } else {
        [self renderRating:animFrame - 10];
    }

    return animFrame > 0x3b;
}

/** @ghidraAddress 0x205628 */
- (BOOL)renderFailed:(unsigned int)animFrame {
    static const double kBannerTopY = 352.0;           // @ghidraAddress 0x292a50
    static const double kBannerMidY = 928.0;           // @ghidraAddress 0x293e40
    static const double kFieldWidth = 768.0;           // @ghidraAddress 0x292460
    static const double kBannerMidWidth = 576.0;       // @ghidraAddress 0x291d88
    static const double kBannerBoxWidth = 192.0;       // @ghidraAddress 0x28fa00
    static const double kWordCentreX = 384.0;          // @ghidraAddress 0x292470
    static const double kWordBaseY = 544.0;            // @ghidraAddress 0x292a68
    static const float kWordScaleFrom = 0.76f;         // @ghidraAddress 0x292b4c
    static const float kWordDropFrom = 46.0f;          // @ghidraAddress 0x292b50
    static const float kBannerSlideOffscreen = -20.0f; // fmov, -20.0
    static const float kBannerSlideSettle = 10.0f;     // fmov, 10.0
    static const int kPanelPitch = 0xc0;               // 192, per-panel grid pitch
    static const int kPanelInsetX = 0x60;              // 96, grid horizontal inset
    static const int kPanelGridTopY = 0x160;           // 352, rows pushed down
    static const int kPanelReflowStride = 0xc;         // 12, the 4x4 reflow multiplier
    static NSString *const kSeResultFailed = @"SD_KNT_RESULT_FAILED"; // @ghidraAddress 0x2df980
    static NSString *const kSeVoiceFailed = @"SD_KNT_CV_FAILED";      // @ghidraAddress 0x2df9a0

    float fadeIn = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 0, 0x10);
    // The binary computes a banner slide offset here but discards it; the banner is drawn at a
    // fixed position. Reproduced for fidelity.
    if (animFrame < 0x10) {
        (void)InterpolateFloatByFrame(kBannerSlideOffscreen, 0.0f, animFrame, 0, 0x10);
    } else {
        (void)InterpolateFloatByFrame(0.0f, kBannerSlideSettle, animFrame, 0x10, 0x32);
    }

    // The failed banner: sprite 9 sampled only for its height, then the wider sprite 10 drawn.
    double plateH = [self.texResultBg spriteAtIndex:9].size.height;
    [self.texResultBg drawSprite:10
                          inRect:CGRectMake(0.0, kBannerTopY - plateH * 0.5, kFieldWidth, plateH)];
    double midY = kBannerMidY - plateH * 0.5;
    [self.texResultBg drawSprite:10 inRect:CGRectMake(0.0, midY, kBannerMidWidth, plateH)];
    [self.texResultBg drawSprite:10
                          inRect:CGRectMake(kBannerMidWidth, midY, kBannerBoxWidth, plateH)
                       transform:0
                           alpha:1.0f];

    // The eight fail panels fill the grid's top and bottom rows; the last is drawn full opacity.
    CGSize panelSize = [self.texResultBg spriteAtIndex:8].size;
    for (int i = 0; i < 8; ++i) {
        float cellAlpha = (i == 7) ? 1.0f : fadeIn;
        int reflowed = i % 4 + (i >> 2) * kPanelReflowStride;
        double px = (double)((reflowed % 4) * kPanelPitch + kPanelInsetX);
        double py = (double)((reflowed >> 2) * kPanelPitch + kPanelGridTopY);
        [self.texResultBg
            drawSprite:8
               atPoint:CGPointMake(px - panelSize.width * 0.5, py - panelSize.height * 0.5)
                 scale:1.0f
                rotate:0
                anchor:CGPointMake(px, py)
             transform:0
                 alpha:cellAlpha];
    }

    // The "failed" word (texResult sprite 1) scales up from 0.76 and drops from 46 points above,
    // fading in over frames 0..16, anchored at the field centre.
    float wordScale = InterpolateFloatByFrame(kWordScaleFrom, 1.0f, animFrame, 0, 0x10);
    double wordY =
        (double)InterpolateFloatByFrame(kWordDropFrom, 0.0f, animFrame, 0, 0x10) + kWordBaseY;
    CGSize wordSize = [self.texResult spriteAtIndex:1].size;
    [self.texResult
        drawSprite:1
           atPoint:CGPointMake(kWordCentreX - wordSize.width * 0.5, wordY - wordSize.height * 0.5)
             scale:wordScale
            rotate:0
            anchor:CGPointMake(kWordCentreX, wordY)
         transform:0
             alpha:fadeIn];

    // The fail jingle and voice play once; from frame 10 the rating tally counts up.
    if (animFrame < 10) {
        if (animFrame == 0) {
            [[AudioManager sharedManager] playSeResFile:kSeResultFailed inDirectory:nil];
            [[AudioManager sharedManager] playSeResFile:kSeVoiceFailed inDirectory:nil];
        }
    } else {
        [self renderRating:animFrame - 10];
    }

    return animFrame > 0x3b;
}

/** @ghidraAddress 0x203240 */
- (void)renderReadyGo {
    // The five "READY" letters cascade in from a per-letter x offset added to the field centre; the
    // settle then parks them at five fixed x positions.
    static const float kReadyLetterX[] = {
        -177.0f, -90.0f, 0.0f, 97.0f, 183.0f};        // @ghidraAddress 0x294258
    static const float kReadyLetterCentreX = 384.0f;  // @ghidraAddress 0x29254c
    static const float kReadyLetterBaseY = 110.0f;    // @ghidraAddress 0x293330
    static const double kReadySettleDropBase = 665.0; // @ghidraAddress 0x293e10
    // The settle x positions, indexed by the letter sprite (0..4).
    static const double kReadySettleX0 = 207.0; // @ghidraAddress 0x2924b8
    static const double kReadySettleX1 = 294.0; // @ghidraAddress 0x28f668
    static const double kReadySettleX2 = 384.0; // @ghidraAddress 0x292470
    static const double kReadySettleX3 = 481.0; // @ghidraAddress 0x293e20
    static const double kReadySettleX4 = 567.0; // @ghidraAddress 0x293e18
    // The "GO" burst on texReady1: a left and a right glyph pair, centre-anchored and scaled 1.25.
    static const double kGoCentreY = 775.0;                    // @ghidraAddress 0x293e28
    static const double kGoLeftX = 174.0;                      // @ghidraAddress 0x293e30
    static const double kGoRightX = 594.0;                     // @ghidraAddress 0x293e38
    static const float kGoScale = 1.25f;                       // fmov 0x3fa00000
    static NSString *const kSeVoiceReady = @"SD_KNT_CV_READY"; // @ghidraAddress 0x2df840
    static const unsigned int kReadyGoCompleteSubState = 99;

    if (frame - 0x15 < 0x1d) {
        // Phase 1: the READY cascade (frames 0x15..0x31). Each letter rises into place and fades in
        // over an eight-frame window opening at its own index; the phase clock is offset by 0x14.
        CGSize letterSize = [self.texReady0 spriteAtIndex:0].size;
        double halfW = letterSize.width * 0.5;
        unsigned int phaseFrame = frame - 0x14;
        for (int i = 4; i >= 0; --i) {
            if (i > (int)phaseFrame) {
                continue;
            }
            float rise =
                InterpolateFloatByFrame((float)letterSize.height, 0.0f, phaseFrame, i, i + 8);
            float fadeIn = InterpolateFloatByFrame(0.0f, 1.0f, phaseFrame, i, i + 8);
            [self.texReady0
                drawSprite:(NSUInteger)i
                   atPoint:CGPointMake((double)(kReadyLetterX[i] + kReadyLetterCentreX) - halfW,
                                       (double)(kReadyLetterBaseY - rise))
                 transform:0
                     alpha:fadeIn];
        }
    } else {
        // Phase 1b: the settle. The five letters drop into place from above and fade out, each
        // parked at a fixed x minus half the sprite width. This arm also covers the frames before
        // the cascade, where the interpolations clamp to a fully faded-out state.
        CGSize letterSize = [self.texReady0 spriteAtIndex:0].size;
        double halfW = letterSize.width * 0.5;
        float drop = InterpolateFloatByFrame(
            0.0f, (float)(letterSize.height * -2.0 + kReadySettleDropBase), frame - 0x32, 0, 10);
        double settleY = (double)(drop + kReadyLetterBaseY);
        float settleAlpha = InterpolateFloatByFrame(1.0f, 0.0f, frame - 0x32, 9, 0xf);
        const double settleX[] = {
            kReadySettleX0, kReadySettleX1, kReadySettleX2, kReadySettleX3, kReadySettleX4};
        for (int i = 4; i >= 0; --i) {
            [self.texReady0 drawSprite:(NSUInteger)i
                               atPoint:CGPointMake(settleX[i] - halfW, settleY)
                             transform:0
                                 alpha:settleAlpha];
        }
    }

    if (frame - 0x38 < 7) {
        // Phase 2a: the GO burst appears (frames 0x38..0x3e). A static base glyph on each side plus
        // a copy that rises up into place and fades in.
        CGSize goSize = [self.texReady1 spriteAtIndex:0].size;
        double halfW = goSize.width * 0.5;
        double halfH = goSize.height * 0.5;
        float appearAlpha = InterpolateFloatByFrame(0.0f, 1.0f, frame - 0x37, 0, 4);
        float rise = InterpolateFloatByFrame(0.0f, (float)goSize.height, frame - 0x37, 0, 8);
        double baseY = kGoCentreY - goSize.height;
        double riseY = kGoCentreY - (double)rise;
        double leftX = kGoLeftX - halfW;
        double rightX = kGoRightX - halfW;
        [self.texReady1 drawSprite:2
                           atPoint:CGPointMake(leftX, baseY)
                             scale:kGoScale
                            rotate:0
                            anchor:CGPointMake(kGoLeftX, baseY + halfH)
                         transform:0
                             alpha:1.0f];
        [self.texReady1 drawSprite:0
                           atPoint:CGPointMake(leftX, riseY)
                             scale:kGoScale
                            rotate:0
                            anchor:CGPointMake(kGoLeftX, riseY + halfH)
                         transform:0
                             alpha:appearAlpha];
        [self.texReady1 drawSprite:3
                           atPoint:CGPointMake(rightX, baseY)
                             scale:kGoScale
                            rotate:0
                            anchor:CGPointMake(kGoRightX, baseY + halfH)
                         transform:0
                             alpha:1.0f];
        [self.texReady1 drawSprite:1
                           atPoint:CGPointMake(rightX, riseY)
                             scale:kGoScale
                            rotate:0
                            anchor:CGPointMake(kGoRightX, riseY + halfH)
                         transform:0
                             alpha:appearAlpha];
    } else if (frame <= 0x4a) {
        // Phase 2b: the GO settle (frames 0x3f..0x4a). The two rising glyphs drop back down while
        // fading out. This arm also covers the frames before the burst, where the interpolations
        // clamp to a fully faded-out state.
        CGSize goSize = [self.texReady1 spriteAtIndex:0].size;
        double halfW = goSize.width * 0.5;
        double halfH = goSize.height * 0.5;
        float fadeOut = InterpolateFloatByFrame(1.0f, 0.0f, frame - 0x3f, 0, 8);
        float shrink =
            InterpolateFloatByFrame((float)goSize.height, (float)halfH, frame - 0x3f, 0, 8);
        double settleY = kGoCentreY - (double)shrink;
        [self.texReady1 drawSprite:0
                           atPoint:CGPointMake(kGoLeftX - halfW, settleY)
                             scale:kGoScale
                            rotate:0
                            anchor:CGPointMake(kGoLeftX, settleY + halfH)
                         transform:0
                             alpha:fadeOut];
        [self.texReady1 drawSprite:1
                           atPoint:CGPointMake(kGoRightX - halfW, settleY)
                             scale:kGoScale
                            rotate:0
                            anchor:CGPointMake(kGoRightX, settleY + halfH)
                         transform:0
                             alpha:fadeOut];
    }

    if (frame == 0x14) {
        [[AudioManager sharedManager] playSeResFile:kSeVoiceReady inDirectory:nil];
    }
    if (frame == 0x3b) {
        [[AudioManager sharedManager] playSePlayer:self.sePlayerGo];
        self.sePlayerGo = nil;
    }
    if (frame >= 0x4b) {
        self.subState = kReadyGoCompleteSubState;
    }
}

/** @ghidraAddress 0x203a70 */
- (void)renderFullcombo:(int)animFrame isResult:(BOOL)isResult {
    static const NSUInteger kFullcomboWordSprite = 2;
    static const NSUInteger kFullcomboGlowSprite = 3;
    static const double kFullcomboX = 8.0;            // fmov, 8.0
    static const float kFullcomboStartY = 160.0f;     // @ghidraAddress 0x28e014
    static const float kFullcomboTopTargetY = 352.0f; // @ghidraAddress 0x292a50
    static const float kFullcomboMidTargetY = 928.0f; // @ghidraAddress 0x293e40
    static const float kFullcomboBounceScale = 1.4f;  // @ghidraAddress 0x292af0
    static const float kFullcomboThirdBaseY = 464.0f; // @ghidraAddress 0x293e60
    static const float kFullcomboExitSlide = 192.0f;  // @ghidraAddress 0x2925a0
    static const float kFullcomboGlowAlpha = 0.5f;    // fmov, 0.5
    static NSString *const kSeResultFullcombo =
        @"SD_KNT_RESULT_FULLCOMBO";                                    // @ghidraAddress 0x2df860
    static NSString *const kSeVoiceFullcombo = @"SD_KNT_CV_FULLCOMBO"; // @ghidraAddress 0x2df880

    if (self.scoreBackup) {
        return;
    }
    // On the result screen the animation is offset 150 frames past its in-game phase; in game it is
    // clamped to that 150-frame window.
    unsigned int clamped = ((int)animFrame < 0x97) ? (unsigned int)frame : 0x96;
    unsigned int f = isResult ? (unsigned int)animFrame + 0x96 : clamped;
    if ((int)f >= 0xa1) {
        return;
    }
    if (f == 2) {
        [[AudioManager sharedManager] playSeResFile:kSeResultFullcombo inDirectory:nil];
        [[AudioManager sharedManager] playSeResFile:kSeVoiceFullcombo inDirectory:nil];
    }
    CGSize wordSize = [self.texCombo spriteAtIndex:kFullcomboWordSprite].size;
    float topTargetY = (float)((double)kFullcomboTopTargetY - wordSize.height * 0.5);
    float midTargetY = (float)((double)kFullcomboMidTargetY - wordSize.height * 0.5);
    if ((int)f < 0x96) {
        // The slide-in phase: the top copy slides to its target over six frames, the mid copy over
        // twenty-four, with a scale bounce on frames 28..37.
        float topY = InterpolateFloatByFrame(kFullcomboStartY, topTargetY, f, 0, 6);
        float midY = InterpolateFloatByFrame(kFullcomboStartY, midTargetY, f, 0, 0x18);
        if ((int)f > 0x1c && (int)(f - 0x1c) < 10) {
            unsigned int b = f - 0x1c;
            float bounce = InterpolateFloatByFrame(1.0f, kFullcomboBounceScale, b, 0, 5);
            if ((int)b > 5) {
                bounce = InterpolateFloatByFrame(kFullcomboBounceScale, 1.0f, b, 5, 10);
            }
            double scaledH = (float)(wordSize.height * (double)bounce);
            float centre = (float)((wordSize.height - scaledH) * 0.5);
            [self.texCombo
                drawSprite:kFullcomboGlowSprite
                    inRect:CGRectMake(kFullcomboX, (double)(topY + centre), wordSize.width, scaledH)
                 transform:0
                     alpha:kFullcomboGlowAlpha];
            [self.texCombo
                drawSprite:kFullcomboGlowSprite
                    inRect:CGRectMake(kFullcomboX, (double)(midY + centre), wordSize.width, scaledH)
                 transform:0
                     alpha:kFullcomboGlowAlpha];
        }
        [self.texCombo drawSprite:kFullcomboWordSprite
                          atPoint:CGPointMake(kFullcomboX, (double)topY)];
        [self.texCombo drawSprite:kFullcomboWordSprite
                          atPoint:CGPointMake(kFullcomboX, (double)midY)];
        if ((int)f > 0x17) {
            return;
        }
        // A third copy slides up from the start position through the base Y to the mid target over
        // frames 0..24, with its own scale bounce.
        float thirdY = InterpolateFloatByFrame(kFullcomboStartY, kFullcomboThirdBaseY, f, 0, 6);
        unsigned int b = f - 6;
        if (b != 0 && (int)f > 5) {
            thirdY = InterpolateFloatByFrame(kFullcomboThirdBaseY, midTargetY, f, 6, 0x18);
        }
        float scaleFrom = ((int)b < 6) ? 1.0f : 3.0f;
        float scaleTo = ((int)b < 6) ? 3.0f : 1.0f;
        unsigned int scaleStart = ((int)b < 6) ? 0 : 6;
        unsigned int scaleEnd = ((int)b < 6) ? 6 : 0x12;
        float thirdScale = InterpolateFloatByFrame(scaleFrom, scaleTo, b, scaleStart, scaleEnd);
        if ((int)f > 5) {
            double scaledH = (float)(wordSize.height * (double)thirdScale);
            float centre = (float)((wordSize.height - scaledH) * 0.5);
            [self.texCombo
                drawSprite:kFullcomboGlowSprite
                    inRect:CGRectMake(
                               kFullcomboX, (double)(thirdY + centre), wordSize.width, scaledH)
                 transform:0
                     alpha:kFullcomboGlowAlpha];
            return;
        }
        // Frames 0..5: the third copy is drawn as a plain glow at its slide position.
        [self.texCombo drawSprite:kFullcomboGlowSprite
                          atPoint:CGPointMake(kFullcomboX, (double)thirdY)
                        transform:0
                            alpha:kFullcomboGlowAlpha];
        return;
    }
    // The result exit (frames 150..160): the copies fade out and slide apart by up to 192 points.
    float exitAlpha = InterpolateFloatByFrame(1.0f, 0.0f, f - 0x96, 0, 10);
    float slide = InterpolateFloatByFrame(0.0f, kFullcomboExitSlide, f - 0x96, 0, 10);
    [self.texCombo drawSprite:kFullcomboWordSprite
                      atPoint:CGPointMake(kFullcomboX, (double)(topTargetY + slide))
                    transform:0
                        alpha:exitAlpha];
    [self.texCombo drawSprite:kFullcomboWordSprite
                      atPoint:CGPointMake(kFullcomboX, (double)(midTargetY - slide))
                    transform:0
                        alpha:exitAlpha];
}

/** @ghidraAddress 0x205c24 */
- (void)renderResult {
    const ScoreData *score = self.sequence.getScore;
    ScoreData backup;
    if (self.scoreBackup) {
        backup = self.replayBackupScore;
        score = &backup;
    }
    // The shutter, if still open, closes in one 43.5-point step per frame down to zero.
    if (shutterOpen > 0.0f) {
        shutterOpen =
            (shutterOpen >= kShutterCloseThreshold) ? shutterOpen + kShutterCloseStep : 0.0f;
    }
    [self renderShutter:NO];
    if (self.sequence.isFullcombo && !self.scoreBackup) {
        [self renderFullcombo:(int)frame isResult:YES];
    }
    [self renderUpperBG:YES];
    [self renderTuneInfo:CGPointMake(kResultArtworkX, kResultArtworkY)
             artworkSize:kResultArtworkSize
                   alpha:1.0];
    [self renderMusicBar:CGPointMake(kResultMusicBarX, kResultMusicBarY) timeline:NO alpha:1.0];
    [self renderScore:(unsigned int)score->totalPoint
              atPoint:CGPointMake(kResultScoreX, kResultScoreY)
                alpha:1.0];
    [self renderPartnerScore:self.partnerScore + self.partnerFinalBonus
                     atPoint:CGPointMake(kResultPartnerX, kResultPartnerY)
                       scale:kResultPartnerScale
                       alpha:1.0];
    float comboAlpha = InterpolateFloatByFrame(1.0f, 0.0f, frame, 0, 10);
    [self renderCombo:(unsigned int)self.sequence.getScore->curCombo alpha:comboAlpha];

    // Once the result has settled (frame >= 30, live play only), the win/clear/fail banner runs and
    // reports when it has finished animating.
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

    // A new record slides its stamp in over frames 65..73 and reads out the recorded score.
    if (self.isNewRecord && frame > kNewRecordGateFrame && !self.scoreBackup) {
        float stampAlpha =
            InterpolateFloatByFrame(0.0f, 1.0f, frame, kNewRecordStartFrame, kNewRecordEndFrame);
        float stampX = InterpolateFloatByFrame(kNewRecordSlideFrom,
                                               kNewRecordSlideTo,
                                               frame,
                                               kNewRecordStartFrame,
                                               kNewRecordEndFrame);
        double x = (double)(stampX + kNewRecordXBase + (float)kNewRecordXNudge);
        [self.texFront drawSprite:kNewRecordStampSprite
                          atPoint:CGPointMake(x, kNewRecordStampY)
                        transform:0
                            alpha:stampAlpha];
        [self renderUpdatedScore:self.scoreRecord
                         atPoint:CGPointMake(x + kNewRecordScoreXOffset + kResultEightNudge,
                                             kNewRecordScoreY)
                           alpha:(double)stampAlpha];
    }

    // The retry/vote overlay appears with the result sub-state, sliding its tag and score in.
    if (self.subState != 0) {
        unsigned int elapsed = frame - subStateChangeFrame;
        float slideIn = (elapsed > 7) ? 1.0f : (float)elapsed * (float)kResultTagScale;
        [self.texResult drawSprite:kResultReplayTagSprite
                           atPoint:CGPointMake(kResultReplayTagX, kResultOverlayY)
                         transform:0
                             alpha:slideIn];
        if (!self.replayPlaying && self.isCustom && self.isDownload && self.hasMusic) {
            // A downloaded custom tune swaps the vote strip in from a resource once, then fades the
            // good-job image up.
            if (!self.isTextureChange) {
                self.isTextureChange = YES;
                CGPoint votePoint = [self.texFront spriteAtIndex:kResultVoteSprite].origin;
                LoadTextureSubImageFromResource(self.texFront, kResultVoteResource, votePoint);
                if (self.goodJobImage != nil) {
                    __weak UIImageView *weakGoodJob = self.goodJobImage;
                    float goodJobAlpha = self.goodJobAlphaMax;
                    [UIView animateWithDuration:kGoodJobFadeDuration
                                     animations:^{
                                       /** @ghidraAddress 0x20663c */
                                       weakGoodJob.alpha = goodJobAlpha;
                                     }
                                     completion:^(BOOL finished){
                                         /** @ghidraAddress 0x206690 */
                                     }];
                }
            }
            [self.texFront drawSprite:kResultVoteSprite
                              atPoint:CGPointMake(kResultVoteX, kResultOverlayY)
                            transform:0
                                alpha:slideIn];
        }
        if (!self.isCustom && self.hasMusic && self.goodJobImage != nil) {
            __weak UIImageView *weakGoodJob = self.goodJobImage;
            float goodJobAlpha = self.goodJobAlphaMax;
            [UIView animateWithDuration:kGoodJobFadeDuration
                             animations:^{
                               /** @ghidraAddress 0x206694 */
                               weakGoodJob.alpha = goodJobAlpha;
                             }
                             completion:^(BOOL finished){
                                 /** @ghidraAddress 0x2066e8 */
                             }];
        }
        if (self.isSession && !self.hasMusic && self.goodJobImage != nil) {
            __weak UIImageView *weakGoodJob = self.goodJobImage;
            float goodJobAlpha = self.goodJobAlphaMax;
            [UIView animateWithDuration:kGoodJobFadeDuration
                             animations:^{
                               /** @ghidraAddress 0x2066ec */
                               weakGoodJob.alpha = goodJobAlpha;
                             }
                             completion:^(BOOL finished){
                                 /** @ghidraAddress 0x206740 */
                             }];
        }
    }
    [self renderButtons];
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

/** @ghidraAddress 0x20186c */
- (void)renderCombo:(unsigned int)combo alpha:(float)alpha {
    if (self.scoreBackup) {
        return;
    }
    if (comboEffectFrame != 0) {
        comboEffectFrame = comboEffectFrame - 1;
    }
    // A drop from a combo above four triggers the combo-cut flash.
    if (combo < lastCombo && lastCombo > kComboMinToShow) {
        comboCutFrame = kComboCutFrames;
    } else if (comboCutFrame == 0) {
        goto digits;
    }
    if (self.showCombo) {
        CGSize cutSize = [self.texCombo spriteAtIndex:kComboCutSprite].size;
        float scale =
            InterpolateFloatByFrame(kComboCutScaleFrom, 1.0f, comboCutFrame, 0, kComboCutFrames);
        float cutAlpha =
            InterpolateFloatByFrame(0.0f, g_flKeyTime080, comboCutFrame, 0, kComboCutFrames);
        double centreX = kComboCutCentreX - cutSize.width * 0.5;
        [self.texCombo
            drawSprite:kComboCutSprite
               atPoint:CGPointMake(centreX - (cutSize.width * (double)scale - cutSize.width) * 0.5,
                                   (double)kComboCutY -
                                       (cutSize.height * (double)scale - cutSize.height) * 0.5)
                 scale:scale
                rotate:0
                anchor:CGPointMake(centreX, kComboCutAnchorY)
             transform:1
                 alpha:cutAlpha];
    }
    comboCutFrame = comboCutFrame - 1;
digits:
    if (combo <= kComboMinToShow) {
        lastCombo = combo;
        return;
    }
    if (lastCombo < combo) {
        comboEffectFrame = kComboEffectFrames;
    }
    char buf[5];
    int length = snprintf(buf, sizeof(buf), "%d", combo);
    if (length > 0) {
        unsigned int digitCount = (unsigned int)(length < 5 ? length : kComboMaxDigits + 1);
        if (digitCount > kComboMaxDigits) {
            digitCount = kComboMaxDigits;
        }
        int startX = digitCount * -kComboDigitStride + kComboDigitStartXBase;
        if (startX < 0) {
            startX = (digitCount * -kComboDigitStride + kComboDigitStartXBase + 1) >> 1;
        } else {
            startX = startX >> 1;
        }
        int effectFrame = comboEffectFrame;
        if (self.showCombo) {
            if (digitCount - 1 < kComboMaxDigits) {
                // A short combo: the digits ripple downward as the combo-effect frame passes them.
                int clampedLen = (int)~combo;
                clampedLen = (clampedLen > -5) ? clampedLen : -5;
                int rippleHead = effectFrame - clampedLen;
                int digitX = startX;
                for (unsigned int i = 0; i < digitCount; ++i) {
                    int bounce = 0;
                    if (rippleHead - 0xb == (int)i) {
                        bounce = -5;
                    } else if (rippleHead - 0xc == (int)i) {
                        bounce = -10;
                    } else if (rippleHead - 0xd == (int)i) {
                        bounce = -15;
                    }
                    if (i + 1 > digitCount) {
                        bounce = 0;
                    }
                    [self.texCombo
                        drawSprite:(NSUInteger)(buf[i] + kComboGlyphBias)
                           atPoint:CGPointMake((double)digitX, (double)(bounce + kComboDigitYBase))
                         transform:0
                             alpha:alpha];
                    digitX += kComboDigitStride;
                }
            } else {
                int digitX = startX;
                for (unsigned int i = 0; i < digitCount; ++i) {
                    [self.texCombo drawSprite:(NSUInteger)(buf[i] + kComboGlyphBias)
                                      atPoint:CGPointMake((double)digitX, kComboDigitY)
                                    transform:0
                                        alpha:alpha];
                    digitX += kComboDigitStride;
                }
            }
            [self.texCombo
                drawSprite:kComboWordSprite
                   atPoint:CGPointMake((double)((int)(startX + digitCount * kComboDigitStride) +
                                                kComboWordTrailingOffset),
                                       kComboWordY)
                 transform:0
                     alpha:alpha];
        }
    }
    lastCombo = combo;
}

/** @ghidraAddress 0x200a40 */
- (void)renderStartMark:(float)alpha {
    unsigned int startMarkFrameValue = (unsigned int)startMarkFrame;
    // The rise offset (8 -> 0 over frames 4..8) and the fade-in alpha (0 -> 1 over frames 4..8).
    float rise = InterpolateFloatByFrame(kStartMarkRiseFrom,
                                         0.0f,
                                         startMarkFrameValue,
                                         kStartMarkRiseStartFrame,
                                         kStartMarkRiseEndFrame);
    float fadeIn =
        InterpolateFloatByFrame(
            0.0f, 1.0f, startMarkFrameValue, kStartMarkRiseStartFrame, kStartMarkRiseEndFrame) *
        alpha;
    // The pulse, cycling every 120 frames: up over 0..50, then down over 50..80.
    unsigned int cyc = (unsigned int)(float)((int)startMarkFrameValue % (int)kStartMarkCycleLength);
    float pulse = InterpolateFloatByFrame(0.0f, 1.0f, cyc, 0, kStartMarkPulsePeak);
    if ((int)startMarkFrameValue > (int)kStartMarkPulsePeak) {
        pulse = InterpolateFloatByFrame(1.0f, 0.0f, cyc, kStartMarkPulsePeak, kStartMarkPulseEnd);
    }
    // The horizontal sweep, -100 -> 100 over frames 0..80.
    float sweep =
        InterpolateFloatByFrame(kStartMarkSweepFrom, kStartMarkSweepTo, cyc, 0, kStartMarkPulseEnd);
    for (unsigned int i = 0; i < kMainGameGridPanelCount; ++i) {
        if (([self.sequence firstMarker] & (1u << (i & 0x1f))) == 0) {
            continue;
        }
        CGPoint cell = MainGameRendererPadKntPanelOrigin((int)i);
        double cellX = cell.x;
        double cellY = cell.y;
        CGRect area = CGRectMake(cellX + kStartMarkClipInset,
                                 cellY + kStartMarkClipInset,
                                 kStartMarkClipSize,
                                 kStartMarkClipSize);
        [self drawClip:kStartMarkBurstMidSprite
            drawPosition:CGPointMake(cellX, cellY + kStartMarkTopYOffset)
                drawArea:area
                   alpha:fadeIn];
        [self drawClip:kStartMarkBurstTopSprite
            drawPosition:CGPointMake((double)sweep + cellX, cellY + kStartMarkTopYOffset)
                drawArea:area
                   alpha:pulse * alpha];
        [self drawClip:kStartMarkBurstBottomSprite
            drawPosition:CGPointMake(cellX, cellY + kStartMarkBottomYOffset)
                drawArea:area
                   alpha:fadeIn];
        [self drawClip:kStartMarkBurstMidSprite
            drawPosition:CGPointMake(cellX - (double)(sweep / kStartMarkSweepDivisor),
                                     cellY + kStartMarkBottomYOffset)
                drawArea:area
                   alpha:pulse * alpha];
        [self.texFront
            drawSprite:kStartMarkCentreSprite
               atPoint:CGPointMake(cellX, cellY - (double)rise)
                 scale:1.0f
                rotate:0
                anchor:CGPointMake(cellX + kStartMarkAnchorSize, cellY + kStartMarkAnchorSize)
             transform:0
                 alpha:fadeIn];
    }
    startMarkFrame = startMarkFrame + 1;
}

/** @ghidraAddress 0x200db4 */
- (void)renderMarker {
    int sectorDelta = (int)[self.sequence firstMarkerSector] - (int)[self.sequence currentSector];
    [self.sequence getMarkerState:self->markerState];
    for (int i = 0; i < kMainGameGridPanelCount; ++i) {
        unsigned int stateWord = (unsigned int)self->markerState[i];
        unsigned int phase = stateWord & kMarkerPhaseMask;
        unsigned int slot = (stateWord >> kMarkerSlotShift) & kMarkerSlotMask;
        int sprite;
        if (MainGameRendererPadKntMarkerSprite(phase, slot, &sprite)) {
            CGPoint origin = MainGameRendererPadKntPanelOrigin(i);
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
    }
    [self.sequence getHoldMarkerState:self->holdState];
    if (![self.rendererConf isStealth]) {
        [self->holdMarkerRender renderHoldMarker:self->holdState];
    }
    if (sectorDelta > kMarkerHighlightSector) {
        // The start marker fades in over the last hundred sectors of the approach.
        int fadeSectors = sectorDelta - kMarkerHighlightSector;
        float fade = 1.0f;
        if (fadeSectors < kMarkerFadeClampSectors) {
            fade = (float)fadeSectors / kMarkerFadeDivisor;
        }
        [self renderStartMark:fade];
    }
}

/** @ghidraAddress 0x2023a8 */
- (void)renderMusicBar:(CGPoint)pos timeline:(BOOL)timeline alpha:(double)alpha {
    [self.texFront drawSprite:kMusicBarBackdropSprite
                      atPoint:CGPointMake(pos.x + kMusicBarBackdropXOffset, pos.y)
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
    float cursor = playPosition * kMusicBarCursorScale; // The play cursor, in cell units.
    int cellX = 0;
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
                   atPoint:CGPointMake(cellBaseX + (double)cellX, pos.y + kMusicBarCellYOffset)
                 transform:0
                     alpha:(float)alpha];
        }
        cellX += kMusicBarCellPitch;
    }
    if (timeline) {
        // The play-head sprite, tracking the play position.
        [self.texFront drawSprite:kMusicBarPlayHeadSprite
                          atPoint:CGPointMake((double)(playPosition * kMusicBarPlayHeadScale +
                                                       kMusicBarPlayHeadXOffset),
                                              kMusicBarPlayHeadY)
                        transform:0
                            alpha:(float)alpha];
    }
}

/** @ghidraAddress 0x202060 */
- (void)renderPartnerScore:(unsigned int)score
                   atPoint:(CGPoint)point
                     scale:(double)scale
                     alpha:(double)alpha {
    if (!self.isSession) {
        return;
    }
    double effectiveAlpha = self.isConnected ? alpha : alpha * kPartnerUnconnectedAlphaScale;
    CGSize panelSize = [self.texFront spriteAtIndex:kPartnerSizeSampleSprite].size;
    CGSize digitSize = [self.texFront spriteAtIndex:kPartnerDigitSizeSprite].size;
    if (score == 0) {
        partnerScoreDisplay = 0;
    } else if (partnerScoreDisplay != score) {
        int step = (partnerScoreDisplay < score) ? 1 : -1;
        partnerScoreDisplay =
            partnerScoreDisplay + (((int)(score - partnerScoreDisplay) + step) >> 1);
    }
    char buf[8];
    snprintf(buf, sizeof(buf), "%7d", partnerScoreDisplay);
    unsigned int display = partnerScoreDisplay;
    CGRect panelRect =
        CGRectMake(point.x, point.y, panelSize.width * scale, panelSize.height * scale);
    [self.texFront drawSprite:kScorePanelSprite
                       inRect:panelRect
                    transform:0
                        alpha:(float)effectiveAlpha];
    [self.texFront drawSprite:kScorePanelLabelSprite
                       inRect:panelRect
                    transform:0
                        alpha:(float)effectiveAlpha];
    int digitBase =
        (display > kScoreSevenFigureThreshold) ? kScoreDigitBaseLarge : kScoreDigitBaseSmall;
    int digitX = 0;
    for (int i = 0; i < kScoreDigitCount; ++i) {
        unsigned char c = (unsigned char)buf[i];
        if ((unsigned int)(c - '0') < 10) {
            [self.texFront
                drawSprite:(NSUInteger)(digitBase + (char)buf[i])
                    inRect:CGRectMake(point.x + (double)digitX * scale + kScoreDigitNudge,
                                      point.y,
                                      digitSize.width * scale,
                                      digitSize.height * scale)
                 transform:0
                     alpha:(float)effectiveAlpha];
        }
        digitX += kResultScoreDigitStride;
    }
    [self.texFront
        drawSprite:kPartnerBadgeSprite
           atPoint:CGPointMake(point.x + kPartnerBadgeXOffset, point.y + kPartnerBadgeYOffset)
         transform:0
             alpha:(float)effectiveAlpha];
}

/** @ghidraAddress 0x202748 */
- (void)renderTuneInfo:(CGPoint)pos artworkSize:(double)artworkSize alpha:(double)alpha {
    [self.texFront drawSprite:kTuneArtworkSprite
                       inRect:CGRectMake(pos.x, pos.y, artworkSize, artworkSize)
                    transform:0
                        alpha:(float)alpha];
    double plateX = pos.x + artworkSize;
    [self.texFront drawSprite:kTuneTitleSprite
                      atPoint:CGPointMake(plateX + kTuneTitleXOffset, pos.y + kTuneTitleYOffset)
                    transform:0
                        alpha:(float)alpha];
    plateX += kTuneLevelPlateXOffset;
    double plateY = pos.y + kTuneLevelPlateYOffset;
    [self.texFront drawSprite:kTuneLevelPlateSprite
                      atPoint:CGPointMake(plateX, plateY)
                    transform:0
                        alpha:(float)alpha];
    double badgeOffset;
    switch (self.rendererConf.diff) {
    case 2:
        badgeOffset = kTuneDifficultyBadgeOffsetExtreme;
        break;
    case 1:
        badgeOffset = kTuneDifficultyBadgeOffsetAdvanced;
        break;
    case 0:
        badgeOffset = kTuneDifficultyBadgeOffsetBasic;
        break;
    default:
        badgeOffset = kTuneDifficultyBadgeOffsetOther;
        break;
    }
    [self.texFront
        drawSprite:kTuneDifficultyBadgeSprite
           atPoint:CGPointMake(plateX + badgeOffset, plateY + kTuneDifficultyBadgeYOffset)
         transform:0
             alpha:(float)alpha];
}

/** @ghidraAddress 0x201e60 */
- (void)renderScore:(unsigned int)score atPoint:(CGPoint)point alpha:(double)alpha {
    if (score == 0) {
        scoreDisplay = 0;
    } else if (scoreDisplay != score) {
        // Tween the displayed value halfway to the target, rounding away from the current value.
        int step = (scoreDisplay < score) ? 1 : -1;
        scoreDisplay = scoreDisplay + (((int)(score - scoreDisplay) + step) >> 1);
    }
    char buf[8];
    snprintf(buf, sizeof(buf), "%7d", scoreDisplay);
    unsigned int display = scoreDisplay;
    [self.texFront drawSprite:kScorePanelSprite atPoint:point transform:0 alpha:(float)alpha];
    [self.texFront drawSprite:kScorePanelLabelSprite atPoint:point transform:0 alpha:(float)alpha];
    int digitBase =
        (display > kScoreSevenFigureThreshold) ? kScoreDigitBaseLarge : kScoreDigitBaseSmall;
    int digitX = 0;
    for (int i = 0; i < kScoreDigitCount; ++i) {
        unsigned char c = (unsigned char)buf[i];
        if ((unsigned int)(c - '0') < 10) {
            [self.texFront
                drawSprite:(NSUInteger)(digitBase + (char)buf[i])
                   atPoint:CGPointMake(point.x + (double)digitX + kScoreDigitNudge, point.y)
                 transform:0
                     alpha:(float)alpha];
        }
        digitX += kResultScoreDigitStride;
    }
}

/** @ghidraAddress 0x201cc0 */
- (void)renderUpdatedScore:(unsigned int)score atPoint:(CGPoint)point alpha:(double)alpha {
    if (score == 0) {
        return;
    }
    if (self.scoreBackup) {
        return;
    }
    char buf[8];
    snprintf(buf, sizeof(buf), "%7d", score);
    int lastBlank = -1;
    int digitX = kScoreDigitStride;
    for (int i = 0; i < kScoreDigitCount; ++i) {
        unsigned char c = (unsigned char)buf[i];
        if ((unsigned int)(c - '0') < 10) {
            [self.texFront
                drawSprite:(NSUInteger)(signed char)buf[i]
                   atPoint:CGPointMake(point.x + (double)digitX + kScoreDigitNudge, point.y)
                 transform:0
                     alpha:(float)alpha];
        } else {
            lastBlank = i;
        }
        digitX += kScoreDigitStride;
    }
    [self.texFront
        drawSprite:kScoreSlashSprite
           atPoint:CGPointMake(point.x +
                                   (double)(lastBlank * kScoreDigitStride + kScoreDigitStride) +
                                   kScoreDigitNudge,
                               point.y)
         transform:0
             alpha:(float)alpha];
}

/** @ghidraAddress 0x203fb0 */
- (void)renderFinish {
    __weak MainGameRendererPadKnt *weakSelf = self;
    // Load the result texture on the render's background context, then enter the result sub-state
    // on the main queue.
    void (^loadResult)(void) = ^{
      /** @ghidraAddress 0x20419c */
      [weakSelf loadResultTex:(short)[weakSelf.sequence rank]];
      dispatch_async(dispatch_get_main_queue(), ^{
        /** @ghidraAddress 0x204284 */
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

@end
