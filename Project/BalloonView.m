#import "BalloonView.h"

// Defaults applied by -initWithFrame:. The two sizes and the two border figures are fmov
// immediates at 0x1ba370, 0x1ba374, 0x1ba3f8 and 0x1ba40c; the two fractions are doubles in the
// constant pool, which is why they carry the float32 spelling the original source used.
static const CGFloat kDefaultArrowWidth = 20.0;
static const CGFloat kDefaultArrowHeight = 12.0;
static const CGFloat kDefaultBorderRadius = 8.0;
static const CGFloat kDefaultBorderWidth = 2.0;

static const CGFloat kDefaultArrowPosision = 0.3f; // @ghidraAddress 0x28f248
static const CGFloat kDefaultBalloonAlpha = 0.6f;  // @ghidraAddress 0x28f230

// Extra clearance the right-pointing arrow keeps below the bottom corner arc, from the fmov
// immediate at 0x1ba7a4. No other direction has an equivalent.
static const CGFloat kRightArrowBottomClearance = 4.0;

@implementation BalloonView

/** @ghidraAddress 0x1ba2dc */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.opaque = NO;
        self.backgroundColor = UIColor.clearColor;
        self.arrowSize = CGSizeMake(kDefaultArrowWidth, kDefaultArrowHeight);
        self.arrowDirection = BalloonViewArrowDirectionUp;
        self.arrowPosision = kDefaultArrowPosision;
        self.balloonColor = [UIColor colorWithWhite:0.0 alpha:kDefaultBalloonAlpha];
        self.borderRadius = kDefaultBorderRadius;
        self.borderWidth = kDefaultBorderWidth;
        self.borderColor = UIColor.whiteColor;
    }
    return self;
}

#pragma mark - Geometry

/** @ghidraAddress 0x1ba468 */
- (CGRect)contentRect {
    CGRect rect = self.bounds;
    rect.origin.x += self.borderWidth;
    rect.origin.y += self.borderWidth;
    rect.size.width -= self.borderWidth * 2;
    rect.size.height -= self.borderWidth * 2;

    // Only the two leading edges move the origin; the trailing ones just lose the height. The
    // four cases share tails in the compiled form, which is why the jump table lands mid-block.
    switch (self.arrowDirection) {
    case BalloonViewArrowDirectionUp:
        rect.origin.y += self.arrowSize.height;
        rect.size.height -= self.arrowSize.height;
        break;
    case BalloonViewArrowDirectionDown:
        rect.size.height -= self.arrowSize.height;
        break;
    case BalloonViewArrowDirectionLeft:
        rect.origin.x += self.arrowSize.height;
        rect.size.width -= self.arrowSize.height;
        break;
    case BalloonViewArrowDirectionRight:
        rect.size.width -= self.arrowSize.height;
        break;
    }

    rect.origin.x += self.contentEdgeInsets.left;
    rect.origin.y += self.contentEdgeInsets.top;
    rect.size.width -= self.contentEdgeInsets.left + self.contentEdgeInsets.right;
    rect.size.height -= self.contentEdgeInsets.top + self.contentEdgeInsets.bottom;
    return rect;
}

#pragma mark - Drawing

/** @ghidraAddress 0x1ba5ec */
- (void)drawRect:(CGRect)rect {
    // Yes, rect is ignored. The balloon is always laid out against the full bounds.
    const CGFloat radius = self.borderRadius;
    CGFloat left = self.bounds.origin.x + self.borderWidth / 2;
    CGFloat top = self.bounds.origin.y + self.borderWidth / 2;
    CGFloat right = self.bounds.origin.x + self.bounds.size.width - self.borderWidth / 2;
    CGFloat bottom = self.bounds.origin.y + self.bounds.size.height - self.borderWidth / 2;

    const CGFloat halfArrowWidth = self.arrowSize.width / 2;
    // The arrow may not encroach on a corner arc, so its centre stays this far from either end of
    // whichever edge carries it.
    const CGFloat arrowClearance = radius + halfArrowWidth;
    // arrowPosision is an offset from the edge's leading end, floored at that clearance. The
    // default of 0.3 is below the floor, so it is the floor that applies unless a caller sets one.
    CGFloat arrowOffset = MAX(self.arrowPosision, arrowClearance);

    switch (self.arrowDirection) {
    case BalloonViewArrowDirectionUp:
        top += self.arrowSize.height;
        arrowOffset = MIN(left + arrowOffset, right - arrowClearance);
        break;
    case BalloonViewArrowDirectionDown:
        bottom -= self.arrowSize.height;
        arrowOffset = MIN(left + arrowOffset, right - arrowClearance);
        break;
    case BalloonViewArrowDirectionLeft:
        left += self.arrowSize.height;
        arrowOffset = MIN(top + arrowOffset, bottom - arrowClearance);
        break;
    case BalloonViewArrowDirectionRight:
        right -= self.arrowSize.height;
        // Yes, arrowPosision is discarded on this one edge. A right-pointing arrow is pinned
        // to the bottom of its edge whatever the caller asked for, and given four points of
        // clearance that the other three directions do not get.
        arrowOffset = bottom - (arrowClearance + kRightArrowBottomClearance);
        break;
    }

    // One clockwise outline: each corner arc, with the arrow spliced into the edge that follows.
    UIBezierPath *path = UIBezierPath.bezierPath;
    [path moveToPoint:CGPointMake(left, top + radius)];
    [path addArcWithCenter:CGPointMake(left + radius, top + radius)
                    radius:radius
                startAngle:M_PI
                  endAngle:M_PI * 3 / 2
                 clockwise:YES];

    if (self.arrowDirection == BalloonViewArrowDirectionUp) {
        [path addLineToPoint:CGPointMake(arrowOffset - halfArrowWidth, top)];
        [path addLineToPoint:CGPointMake(arrowOffset, top - self.arrowSize.height)];
        [path addLineToPoint:CGPointMake(arrowOffset + halfArrowWidth, top)];
    }
    [path addLineToPoint:CGPointMake(right - radius, top)];
    [path addArcWithCenter:CGPointMake(right - radius, top + radius)
                    radius:radius
                startAngle:M_PI * 3 / 2
                  endAngle:M_PI * 2
                 clockwise:YES];

    if (self.arrowDirection == BalloonViewArrowDirectionRight) {
        [path addLineToPoint:CGPointMake(right, arrowOffset - halfArrowWidth)];
        [path addLineToPoint:CGPointMake(right + self.arrowSize.height, arrowOffset)];
        [path addLineToPoint:CGPointMake(right, arrowOffset + halfArrowWidth)];
    }
    [path addLineToPoint:CGPointMake(right, bottom - radius)];
    [path addArcWithCenter:CGPointMake(right - radius, bottom - radius)
                    radius:radius
                startAngle:0
                  endAngle:M_PI_2
                 clockwise:YES];

    if (self.arrowDirection == BalloonViewArrowDirectionDown) {
        [path addLineToPoint:CGPointMake(arrowOffset + halfArrowWidth, bottom)];
        [path addLineToPoint:CGPointMake(arrowOffset, bottom + self.arrowSize.height)];
        [path addLineToPoint:CGPointMake(arrowOffset - halfArrowWidth, bottom)];
    }
    [path addLineToPoint:CGPointMake(left + radius, bottom)];
    [path addArcWithCenter:CGPointMake(left + radius, bottom - radius)
                    radius:radius
                startAngle:M_PI_2
                  endAngle:M_PI
                 clockwise:YES];

    if (self.arrowDirection == BalloonViewArrowDirectionLeft) {
        [path addLineToPoint:CGPointMake(left, arrowOffset + halfArrowWidth)];
        [path addLineToPoint:CGPointMake(left - self.arrowSize.height, arrowOffset)];
        [path addLineToPoint:CGPointMake(left, arrowOffset - halfArrowWidth)];
    }
    [path closePath];

    if (self.borderWidth > 0) {
        path.lineWidth = self.borderWidth;
        [self.borderColor setStroke];
    }
    [self.balloonColor setFill];
    [path fill];
    // Yes, unconditionally. With a non-positive borderWidth neither the stroke colour nor the line
    // width was set, and this strokes with whatever the context already had.
    [path stroke];
}

@end
