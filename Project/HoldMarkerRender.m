#import "HoldMarkerRender.h"

// The play grid.
enum { kPanelCount = 16 };

// Every metric below has one value per idiom, chosen from the isPad ivar.
enum {
    kLineThicknessPad = 16,
    kLineThicknessPhone = 6,
};
static const float kLineShrinkPad = 1.0f;
static const float kLineShrinkPhone = 0.1f;  // @ghidraAddress 0x28f70c
static const double kPanelPitchPhone = 68.0; // @ghidraAddress 0x291e10
static const double kPanelPitchPad = 160.0;  // @ghidraAddress 0x291e18

// The four directions a tail can run in, in the order of the jump table at 0xe8094.
enum {
    kHoldVectorUp = 0,
    kHoldVectorDown = 1,
    kHoldVectorLeft = 2,
    kHoldVectorRight = 3,
};

@implementation HoldMarkerRender {
    // Weak: the initialiser stores it with objc_storeWeak and the line renderer reads it back with
    // objc_loadWeakRetained. The ivar's encoding does not say so; only the calls do.
    __weak Texture2D *drawTex;
    BOOL isPad;
    int gameAreaDelay;
}

/** @ghidraAddress 0xe7e18 */
- (instancetype)init:(Texture2D *)tex isPad:(BOOL)aIsPad gameAreaDelay:(int)aGameAreaDelay {
    self = [super init];
    if (self) {
        drawTex = tex;
        isPad = aIsPad;
        gameAreaDelay = aGameAreaDelay;
    }
    return self;
}

/** @ghidraAddress 0xe7eb8 */
- (void)renderHoldLine:(CGPoint)endPoint
                 start:(CGPoint)startPoint
                vector:(int)vector
                 trans:(char)trans
                 alpha:(float)alpha
                 frame:(int)frame
             addLength:(int)addLength {
    int thickness = isPad ? kLineThicknessPad : kLineThicknessPhone;
    float shrink = isPad ? kLineShrinkPad : kLineShrinkPhone;
    double pitch = isPad ? kPanelPitchPad : kPanelPitchPhone;

    // Uninitialised on the default path — see below.
    CGRect rect;
    switch (vector) {
    case kHoldVectorUp:
        // Vertical, anchored on the start panel's column.
        rect = CGRectMake(startPoint.x,
                          startPoint.y + pitch - addLength - shrink,
                          pitch,
                          addLength + (endPoint.y - startPoint.y) - thickness - pitch);
        break;
    case kHoldVectorDown:
        // Vertical the other way, anchored on the end panel's column, and one point longer.
        rect = CGRectMake(endPoint.x,
                          endPoint.y + pitch + thickness,
                          pitch,
                          addLength + (startPoint.y - endPoint.y) - pitch - thickness + 1.0);
        break;
    case kHoldVectorLeft:
        // Horizontal, keeping the end panel's row.
        rect = CGRectMake(startPoint.x + pitch - addLength - shrink,
                          endPoint.y,
                          addLength + (endPoint.x - startPoint.x) - thickness - pitch,
                          pitch);
        break;
    case kHoldVectorRight:
        // Horizontal the other way, keeping the start panel's row. The only arm that folds the
        // shrink into the length rather than the origin.
        rect = CGRectMake(endPoint.x + pitch + thickness,
                          startPoint.y,
                          shrink + addLength + (startPoint.x - endPoint.x) - pitch - thickness,
                          pitch);
        break;
    default:
        // The binary has no default arm at all: it branches straight to the draw with the rect's
        // four registers still holding whatever the caller left in them. Reproduced by leaving
        // rect uninitialised. See TYPES_PENDING.md.
        break;
    }

    [drawTex drawSprite:frame inRect:rect transform:trans alpha:alpha];
}

/** @ghidraAddress 0xe8674 */
- (void)renderHoldMarker:(HoldMarkerInfo *)markers {
    for (int i = 0; i < kPanelCount; ++i) {
        [self renderHoldMarker:markers[i] end:i];
    }
}

@end
