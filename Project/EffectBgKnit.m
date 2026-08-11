#import "EffectBgKnit.h"

#import "Texture2D.h"
#import "neEngineBridge.h"

// The effect type that runs briefly; every other type runs the long duration.
static const int kShortEffectType = 0;
static const int kShortEffectFrames = 10;
static const int kLongEffectFrames = 120;

// The six effects, indexed by type_. The names are this tree's, from what each case draws.
enum {
    kEffectTypeSpin = 0,
    kEffectTypePairDrop = 1,
    kEffectTypeDoubleDrop = 2,
    kEffectTypeBand = 3,
    kEffectTypeWideningBand = 4,
    kEffectTypeNarrowingBand = 5,
};

// Sprite indices within the effect texture.
enum {
    kSpinFirstSprite = 11,
    kPairDropFirstSprite = 4,
    kPairDropSecondSprite = 5,
    kDoubleDropSprite = 6,
    kBandSprite = 7,
};

// The band effects fade with a triangle wave clamped to one and scaled right down.
static const float kBandWaveMax = 1.5f;
static const float kBandWaveClamp = 1.0f;
static const float kBandAlphaScale = 0.15f; // @ghidraAddress 0x293a88

// The scale argument is a percentage, and the rotation argument is in half-turns.
static const float kScalePercent = 100.0f;       // @ghidraAddress 0x28f4e0
static const float kDegreesPerHalfTurn = 180.0f; // @ghidraAddress 0x28f538

static const float kSpinAlpha = 0.3f;       // @ghidraAddress 0x28e0b0
static const float kPairDropAlpha = 0.2f;   // @ghidraAddress 0x28f3c8
static const float kDoubleDropAlpha = 0.3f; // @ghidraAddress 0x28e0b0

// Where the two halves of the double drop start, above the top of the frame.
static const float kDoubleDropFirstStartY = -50.0f; // @ghidraAddress 0x293a8c
static const float kDoubleDropSecondStartY = -20.0f;
// And how far past move_ each of the trailing sprites travels.
static const int kPairDropSecondExtra = 100;
static const int kDoubleDropSecondExtra = 180;

// Neither drawing selector is declared anywhere in this tree yet, so they are declared here
// against Texture2D rather than left to a bare id. Both encodings are from the runtime metadata.
@interface Texture2D (EffectBgKnitDrawing)
/** @ghidraAddress 0xeb28 */
- (void)drawSprite:(NSUInteger)sprite
           atPoint:(CGPoint)point
             scale:(float)scale
            rotate:(float)rotate
            anchor:(CGPoint)anchor
         transform:(char)transform
             alpha:(float)alpha;
/** @ghidraAddress 0xee48 */
- (void)drawSprite:(NSUInteger)sprite
            inRect:(CGRect)rect
         transform:(char)transform
             alpha:(float)alpha;
@end

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

/** @ghidraAddress 0x1950c0 */
- (BOOL)renderEffect {
    // Computed for every type, but only the three band effects below read it. The other three
    // ignore it entirely and use their own fixed alphas.
    float wave = [self expand:frame_ totalFrame:totalFrame_ max:kBandWaveMax];
    float bandAlpha = MIN(wave, kBandWaveClamp) * kBandAlphaScale;

    // A type outside the six falls straight through to the tail, so it draws nothing but still
    // ages towards completion. The binary's comparison is unsigned, so a negative type does too.
    switch (type_) {
    case kEffectTypeSpin: {
        // An animation strip walked by the frame counter, spun and scaled in place.
        [pDrawTex_ drawSprite:frame_ % totalFrame_ + kSpinFirstSprite
                      atPoint:drawPos_
                        scale:wmax_ / kScalePercent
                       rotate:(float)(move_ / kDegreesPerHalfTurn * M_PI)
                       anchor:drawPos_
                    transform:0
                        alpha:kSpinAlpha];
        break;
    }
    case kEffectTypePairDrop: {
        // Two sprites falling from the origin, the second travelling further.
        float firstY = InterpolateFloatByFrame(0.0f, move_, frame_, 0, totalFrame_);
        [pDrawTex_ drawSprite:kPairDropFirstSprite
                      atPoint:CGPointMake(drawPos_.x, firstY)
                        scale:wmax_ / kScalePercent
                       rotate:0
                       anchor:CGPointMake(drawPos_.x, firstY)
                    transform:0
                        alpha:kPairDropAlpha];
        float secondY =
            InterpolateFloatByFrame(0.0f, move_ + kPairDropSecondExtra, frame_, 0, totalFrame_);
        [pDrawTex_ drawSprite:kPairDropSecondSprite
                      atPoint:CGPointMake(drawPos_.x, secondY)
                        scale:wmax_ / kScalePercent
                       rotate:0
                       anchor:CGPointMake(drawPos_.x, secondY)
                    transform:0
                        alpha:kPairDropAlpha];
        break;
    }
    case kEffectTypeDoubleDrop: {
        // The same sprite twice, both starting above the frame rather than at the origin.
        float firstY =
            InterpolateFloatByFrame(kDoubleDropFirstStartY, move_, frame_, 0, totalFrame_);
        [pDrawTex_ drawSprite:kDoubleDropSprite
                      atPoint:CGPointMake(drawPos_.x, firstY)
                        scale:wmax_ / kScalePercent
                       rotate:0
                       anchor:CGPointMake(drawPos_.x, firstY)
                    transform:0
                        alpha:kDoubleDropAlpha];
        float secondY = InterpolateFloatByFrame(
            kDoubleDropSecondStartY, move_ + kDoubleDropSecondExtra, frame_, 0, totalFrame_);
        [pDrawTex_ drawSprite:kDoubleDropSprite
                      atPoint:CGPointMake(drawPos_.x, secondY)
                        scale:wmax_ / kScalePercent
                       rotate:0
                       anchor:CGPointMake(drawPos_.x, secondY)
                    transform:0
                        alpha:kDoubleDropAlpha];
        break;
    }
    case kEffectTypeBand: {
        // A vertical band from the top of the frame down to the sprite's own y, sliding
        // sideways. Narrowed to float and widened again, which the binary does explicitly.
        float bandX = drawPos_.x + InterpolateFloatByFrame(0.0f, move_, frame_, 0, totalFrame_);
        [pDrawTex_ drawSprite:kBandSprite
                       inRect:CGRectMake(bandX, 0, wmax_, drawPos_.y)
                    transform:0
                        alpha:bandAlpha];
        break;
    }
    case kEffectTypeWideningBand: {
        // The same band, but its width grows from wmin_ to wmax_ across the second half of
        // the cycle only — note the start frame is the midpoint, not zero.
        float width = InterpolateFloatByFrame(wmin_, wmax_, frame_, totalFrame_ / 2, totalFrame_);
        float bandX = drawPos_.x + InterpolateFloatByFrame(0.0f, move_, frame_, 0, totalFrame_);
        [pDrawTex_ drawSprite:kBandSprite
                       inRect:CGRectMake(bandX, 0, width, drawPos_.y)
                    transform:0
                        alpha:bandAlpha];
        break;
    }
    case kEffectTypeNarrowingBand: {
        // And the reverse: wmax_ down to wmin_, across the whole cycle rather than half.
        float bandX = drawPos_.x + InterpolateFloatByFrame(0.0f, move_, frame_, 0, totalFrame_);
        float width = InterpolateFloatByFrame(wmax_, wmin_, frame_, 0, totalFrame_);
        [pDrawTex_ drawSprite:kBandSprite
                       inRect:CGRectMake(bandX, 0, width, drawPos_.y)
                    transform:0
                        alpha:bandAlpha];
        break;
    }
    }

    ++frame_;
    return frame_ >= totalFrame_;
}

@end
