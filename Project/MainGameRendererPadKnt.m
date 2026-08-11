#import "MainGameRendererPadKnt.h"

#import "RendererConf.h"
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
