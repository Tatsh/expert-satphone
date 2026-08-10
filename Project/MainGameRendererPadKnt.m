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

@end
