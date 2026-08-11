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

// The grid is four panels wide, so a vertical step is four panel indices and a horizontal one is
// one.
enum {
    kPanelsPerRow = 4,
    kVerticalStride = 4,
    kHorizontalStride = 1,
};

// Where each panel sits. The pitch here is the panel *spacing*, which is not the pitch the sprites
// are drawn at.
enum {
    kPanelSpacingPad = 192,
    kPanelSpacingPhone = 80,
    kPanelMarginPad = 16,
    kPanelMarginPhone = 6,
    kGridTopPad = 256,
    // The phone offsets the grid by the play area's delay instead of using a constant.
    kGridTopPhoneBase = 160,
};

// Sprite-sheet rows. Each is OR'd with the animation frame in its low four bits, except in the
// released state, where the two indices are used bare.
enum {
    kSpriteRowMarker = 0x20,
    kSpriteRowHeldGlow = 0x10,
    kSpriteRowActiveTail = 0x30,
    kSpriteRowFarEnd = 0x40,
    kSpriteRowReleaseFade = 0x50,
    // The retracting tail's far end changes sprite run once enough frames have passed. The later
    // run is the lower row, not the higher one.
    kSpriteRowRetractLate = 0x50,
    kSpriteRowRetractEarly = 0x60,
    kSpriteFrameMask = 0xf,
};

// The marker's own state, in field zero. Zero draws nothing at all.
enum {
    kHoldStateNone = 0,
    kHoldStatePressed = 1,
    kHoldStateRetracting = 2,
    kHoldStateReleased = 3,
};

// Ten frames per animation step, and the animation runs sixteen frames.
enum {
    kFramesPerStep = 10,
    kMaxFrame = 15,
};

// Above this elapsed count the retracting tail switches to its second sprite run.
enum {
    kRetractLateThreshold = 0x4f,
    kRetractFrameBias = 8,
    kRetractRunLength = 16,
    kRetractAddLengthPad = 0x60,
    kRetractAddLengthPhone = 0x28,
};

@interface HoldMarkerRender () {
@public
    // Weak: the initialiser stores it with objc_storeWeak and the line renderer reads it back with
    // objc_loadWeakRetained. The ivar's encoding does not say so; only the calls do.
    __weak Texture2D *drawTex;
    BOOL isPad;
    int gameAreaDelay;
}
@end

// Where a panel's top-left corner sits. Written out six times in the binary; folded here because
// every copy is instruction-for-instruction the same.
static inline CGPoint HoldMarkerRenderPanelOrigin(HoldMarkerRender *self, int panel) {
    // The division is signed and rounds towards zero, which is what the +3-then-mask does. A
    // negative panel index cannot arise from the caller, but the arithmetic allows for one.
    int rounded = (panel < 0) ? panel + (kPanelsPerRow - 1) : panel;
    int column = panel - (rounded & ~(kPanelsPerRow - 1));
    int row = rounded >> 2;

    int spacing = self->isPad ? kPanelSpacingPad : kPanelSpacingPhone;
    int margin = self->isPad ? kPanelMarginPad : kPanelMarginPhone;
    // The pad's grid starts at a constant; the phone's is pushed down by the play area's delay.
    int top = self->isPad ? kGridTopPad : self->gameAreaDelay + kGridTopPhoneBase;

    return CGPointMake(spacing * column + margin, spacing * row + margin + top);
}

@implementation HoldMarkerRender

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

/** @ghidraAddress 0xe80a4 */
- (void)renderHoldMarker:(HoldMarkerInfo)marker end:(int)end {
    if (marker.direction == kHoldStateNone) {
        return;
    }

    // The low two bits of field one are the direction; the next two are how many panels away the
    // far end is. Vertical directions step a whole row, horizontal ones a single panel, and each
    // direction carries its own texture transform.
    int vector = (marker.start >> 0) & 3;
    int step = (marker.start >> 2) & 3;
    int panelDelta;
    char trans;
    switch (vector) {
    case kHoldVectorUp:
        panelDelta = -(step * kVerticalStride);
        trans = 0;
        break;
    case kHoldVectorDown:
        panelDelta = step * kVerticalStride;
        trans = 2;
        break;
    case kHoldVectorLeft:
        panelDelta = -(step * kHorizontalStride);
        trans = 3;
        break;
    default:
        panelDelta = step * kHorizontalStride;
        trans = 1;
        break;
    }

    float progress = (float)marker.end / (float)marker.state;
    int frame = marker.end / kFramesPerStep;

    CGPoint markerOrigin = HoldMarkerRenderPanelOrigin(self, end);
    double spriteSize = isPad ? kPanelPitchPad : kPanelPitchPhone;
    CGRect markerRect = CGRectMake(markerOrigin.x, markerOrigin.y, spriteSize, spriteSize);

    // Field zero doubles as the state. Only three values draw anything.
    if (marker.direction == kHoldStateReleased) {
        // Nothing but the marker itself, fading out. Both sprite indices are used bare here, with
        // no frame in their low bits.
        float fade = 1.0f - progress;
        [drawTex drawSprite:kSpriteRowMarker atPoint:markerOrigin transform:trans alpha:fade];
        [drawTex drawSprite:kSpriteRowReleaseFade atPoint:markerOrigin transform:trans alpha:fade];
        return;
    }

    CGPoint farOrigin = HoldMarkerRenderPanelOrigin(self, end + panelDelta);

    if (marker.direction == kHoldStatePressed) {
        int tailFrame = (frame > kMaxFrame) ? kMaxFrame : frame;
        [self renderHoldLine:markerOrigin
                       start:farOrigin
                      vector:vector
                       trans:trans
                       alpha:1.0f
                       frame:tailFrame
                   addLength:0];

        [drawTex drawSprite:kSpriteRowMarker | (frame & kSpriteFrameMask)
                     inRect:markerRect
                  transform:trans
                      alpha:1.0f];
        [drawTex drawSprite:kSpriteRowHeldGlow | (frame & kSpriteFrameMask)
                     inRect:markerRect
                  transform:trans
                      alpha:1.0f];
        [drawTex drawSprite:tailFrame | kSpriteRowFarEnd
                     inRect:CGRectMake(farOrigin.x, farOrigin.y, spriteSize, spriteSize)
                  transform:trans
                      alpha:1.0f];
        return;
    }

    // kHoldStateRetracting. The tail's far end walks back towards the marker as progress runs from
    // zero to one, and the sprite run changes once enough frames have passed.
    int retractSprite;
    int addLength;
    if (marker.end > kRetractLateThreshold) {
        // A signed remainder, which is what the +7-then-mask in the binary implements.
        retractSprite = (frame - kRetractFrameBias) % kRetractRunLength + kSpriteRowRetractLate;
        addLength = isPad ? kRetractAddLengthPad : kRetractAddLengthPhone;
    } else {
        retractSprite = frame + kSpriteRowRetractEarly;
        addLength = 0;
    }

    double remaining = 1.0f - progress;
    CGPoint retracted = CGPointMake(markerOrigin.x - remaining * (markerOrigin.x - farOrigin.x),
                                    markerOrigin.y - remaining * (markerOrigin.y - farOrigin.y));

    [self renderHoldLine:markerOrigin
                   start:retracted
                  vector:vector
                   trans:trans
                   alpha:1.0f
                   frame:frame & kSpriteFrameMask
               addLength:addLength];

    [drawTex drawSprite:kSpriteRowMarker | (frame & kSpriteFrameMask)
                 inRect:markerRect
              transform:trans
                  alpha:1.0f];
    [drawTex drawSprite:kSpriteRowActiveTail | (frame & kSpriteFrameMask)
                 inRect:markerRect
              transform:trans
                  alpha:1.0f];
    [drawTex drawSprite:retractSprite
                 inRect:CGRectMake(retracted.x, retracted.y, spriteSize, spriteSize)
              transform:trans
                  alpha:1.0f];
}

@end
