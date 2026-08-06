#import "ShadowView.h"

#include <math.h>

// The default spread, an fmov of 0x4010000000000000 at 0xe3fec.
static const double kDefaultShadowBlurRadius = 4.0;

// The margin the outer path is grown by beyond the shadow's own spread, so the fill has somewhere
// to come from. An fmov whose imm8 is 0xF0, which decodes to -1.0 — Ghidra prints it as
// "-0x4010000000000000", which is neither the value nor its bit pattern.
static const double kOuterPathMargin = 1.0;

// The shadow offset. The vertical component is the pooled double at 0x291e00; the horizontal one is
// computed from the outer path's width. The pooled -0.0 at 0x291df8 is the x argument of the
// CGRectOffset below, where it is a sign-preserving zero rather than a displacement.
static const double kShadowOffsetHeight = 1.1;
static const double kShadowOffsetNudge = 0.1;

@implementation ShadowView

/** @ghidraAddress 0xe3f20 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.clipsToBounds = YES;
        self.opaque = NO;
        self.backgroundColor = UIColor.clearColor;
        // Purely decorative, so it never takes a touch.
        self.userInteractionEnabled = NO;
        self.cornerRadius = 0.0;
        self.shadowBlurRadius = kDefaultShadowBlurRadius;
    }
    return self;
}

/** @ghidraAddress 0xe400c */
- (void)drawRect:(CGRect)rect {
    // The argument is never read: the shape always comes from -bounds, so a partial redraw still
    // rebuilds the whole path.
    UIBezierPath *shape;
    if (self.cornerRadius > 0.0) {
        shape = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.cornerRadius];
    } else {
        shape = [UIBezierPath bezierPathWithRect:self.bounds];
    }

    CGColorRef shadowColor = UIColor.blackColor.CGColor;

    // Grow the shape's bounds by the blur, nudge it up by one point, union it back with the
    // original, then grow it by one more point. -shadowBlurRadius is sent twice here, once for each
    // inset argument.
    CGRect outer = CGRectInset(shape.bounds, -self.shadowBlurRadius, -self.shadowBlurRadius);
    outer = CGRectOffset(outer, -0.0, -kOuterPathMargin);
    outer = CGRectUnion(outer, shape.bounds);
    outer = CGRectInset(outer, -kOuterPathMargin, -kOuterPathMargin);

    // The shadow is shifted sideways by the whole width of the outer path, so the shape sits well
    // outside its own shadow and only the spill lands inside. The path is translated back by the
    // same amount before filling, which is what puts the shadow where the shape is.
    double shift = round(CGRectGetWidth(outer));

    UIBezierPath *outerPath = [UIBezierPath bezierPathWithRect:outer];
    [outerPath appendPath:shape];
    // The even-odd rule is what turns the appended shape into a hole rather than more fill.
    outerPath.usesEvenOddFillRule = YES;

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);

    // copysign, spelled as a BIT of a negated zero mask: the nudge takes the sign of the shift, so
    // the offset never lands exactly on the shift and the shadow cannot be clipped away.
    double offsetWidth = shift + copysign(kShadowOffsetNudge, shift);
    CGContextSetShadowWithColor(
        context, CGSizeMake(offsetWidth, kShadowOffsetHeight), self.shadowBlurRadius, shadowColor);

    [shape addClip];
    [outerPath applyTransform:CGAffineTransformMakeTranslation(-shift, 0.0)];

    // Grey rather than the shadow's own black; only the shadow it casts is visible through the
    // clip, so the fill colour matters mainly for the edge.
    CGContextSetFillColorWithColor(context, UIColor.grayColor.CGColor);
    [outerPath fill];

    CGContextRestoreGState(context);
}

@end
