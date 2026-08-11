#import "MainGameRendererPadKnt.h"

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
