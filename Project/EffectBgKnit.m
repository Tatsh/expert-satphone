#import "EffectBgKnit.h"

#import "neEngineBridge.h"

// The effect type that runs briefly; every other type runs the long duration.
static const int kShortEffectType = 0;
static const int kShortEffectFrames = 10;
static const int kLongEffectFrames = 120;

@implementation EffectBgKnit {
    Texture2D *pDrawTex_;
    int type_;
    int frame_;
    CGPoint drawPos_;
    int totalFrame_;
    int wmin_;
    int wmax_;
    int move_;
    int width_;
}

/** @ghidraAddress 0x194ff4 */
- (void)init:(Texture2D *)texture
     effType:(int)effType
    startPos:(CGPoint)startPos
        wmin:(int)wmin
        wmax:(int)wmax
        move:(int)move {
    pDrawTex_ = texture;
    type_ = effType;
    frame_ = 0;
    drawPos_ = startPos;
    totalFrame_ = effType == kShortEffectType ? kShortEffectFrames : kLongEffectFrames;
    wmin_ = wmin;
    wmax_ = wmax;
    move_ = move;
    // Yes, width_ is left as it was. It is the one ivar this does not touch.
}

/** @ghidraAddress 0x194fb0 */
- (float)expand:(int)frame totalFrame:(int)totalFrame max:(float)max {
    // A triangle wave: up over the first half of the cycle, down over the second. The modulo lets
    // a caller pass a frame counter that has run past the cycle's length.
    int phase = frame % totalFrame;
    int half = totalFrame / 2;
    if (phase >= half) {
        return InterpolateFloatByFrame(max, 0.0f, phase - half, 0, half);
    }
    return InterpolateFloatByFrame(0.0f, max, phase, 0, half);
}

@end
