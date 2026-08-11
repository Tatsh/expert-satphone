#import "MainGameRendererPadKnt.h"

#import "HoldMarkerRender.h"
#import "JubeatAppDelegate.h"
#import "RendererConf.h"
#import "Sequence.h"
#import "Texture2D.h"

// The ready/go countdown runs for two and a half seconds on the Knit pad renderer.
static const double kReadyGoDuration = 2.5; // fmov 0x4004000000000000

// The game area is offset 256 points down on the Knit pad renderer.
static const double kGameAreaOffset = 256.0; // @ghidraAddress 0x28e030

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
static const unsigned int kRenderStateFinish = 4;
static const unsigned int kRenderStateResult = 5;

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

@implementation MainGameRendererPadKnt

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

/** @ghidraAddress 0x202390 */
- (CGRect)getMusicBarRect {
    return musicBarRect;
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

@end
