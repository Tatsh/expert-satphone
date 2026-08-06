#import "StoreButton.h"

// -highlightColor:factor: reads four components in this order.
enum {
    kComponentRed = 0,
    kComponentGreen = 1,
    kComponentBlue = 2,
    kComponentAlpha = 3,
};

// Where the title shadow stops being worth half a point.
static const CGFloat kRetinaScale = 2.0; // fmov immediate at 0x170a3c

// The shadow sits one device pixel above the text on either kind of screen, so the offset halves
// when the scale doubles. Both are fmov immediates, so neither has a constant pool address: -0.5 is
// encoded 0xe0 at 0x170a50 and -1.0 is encoded 0xf0 at 0x170a48.
static const CGFloat kRetinaShadowOffsetY = -0.5;
static const CGFloat kStandardShadowOffsetY = -1.0;

// Three pool slots, each serving two roles rather than one.
static const CGFloat kNormalShadowAlpha = 0.7f;     // @ghidraAddress 0x291c98
static const CGFloat kHighlightedTitleWhite = 0.8f; // @ghidraAddress 0x28e080
static const CGFloat kDisabledShadowAlpha = 0.6f;   // @ghidraAddress 0x28f230

// How far the fill is darkened before the gradient is built. Pressing the button darkens it.
static const CGFloat kNormalShade = 0.8;      // @ghidraAddress 0x2933e0
static const CGFloat kHighlightedShade = 0.6; // @ghidraAddress 0x2933e8

// The four gradient stops, lightening towards the top of the button. The first factor is a literal
// zero, so only three of the four come from the pool.
static const CGFloat kGradientFactorFirst = 0.0;
static const CGFloat kGradientFactorSecond = 0.16f; // @ghidraAddress 0x2933c0
static const CGFloat kGradientFactorThird = 0.32f;  // @ghidraAddress 0x2933c8
static const CGFloat kGradientFactorFourth = 0.48f; // @ghidraAddress 0x2933d0

// Where each of those four sits along the gradient. The middle pair straddles the midpoint, so the
// band between them is the narrow bright strip across the button's waist.
static const CGFloat kGradientLocationFirst = 0.0;   // @ghidraAddress 0x2933f0
static const CGFloat kGradientLocationSecond = 0.45; // @ghidraAddress 0x2933f8
static const CGFloat kGradientLocationThird = 0.55;  // @ghidraAddress 0x293400
static const CGFloat kGradientLocationFourth = 1.0;  // @ghidraAddress 0x293408

// Added to both halves of the shadow offset, carrying the sign of the value it is added to.
static const CGFloat kShadowNudge = 0.1; // @ghidraAddress 0x28f290

// The horizontal term of -CGRectOffset. It is negative zero in the pool rather than a zeroed
// register, which is a distinction without a numeric difference.
static const CGFloat kNoHorizontalOffset = -0.0; // @ghidraAddress 0x291df8

// The depth and blur the shadow is drawn with. Only the highlighted state differs; the disabled
// state shares the normal one. All six are fmov immediates, so none has a pool address.
static const CGFloat kNormalShadowDepth = 1.0;
static const CGFloat kHighlightedShadowDepth = 2.0;
static const CGFloat kNormalShadowBlur = 2.0;
static const CGFloat kHighlightedShadowBlur = 3.0;

// The final outward inset applied to the shadow's bounding rect.
static const CGFloat kOuterInset = -1.0;

enum {
    kGradientStopCount = 4,
    // A colour with this many components is RGBA; anything else is treated as greyscale.
    kRGBAComponentCount = 4,
};

@implementation StoreButton

// Both accessors are hand-written for these two, which suppresses auto-synthesis of the ivars the
// binary does have.
@synthesize buttonColor = _buttonColor;
@synthesize disabledColor = _disabledColor;

/** @ghidraAddress 0x170998 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        CGFloat scale = UIScreen.mainScreen.scale;
        self.titleLabel.shadowOffset =
            CGSizeMake(0.0, scale >= kRetinaScale ? kRetinaShadowOffsetY : kStandardShadowOffsetY);

        [self setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [self setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:kNormalShadowAlpha]
                         forState:UIControlStateNormal];

        [self setTitleColor:[UIColor colorWithWhite:kHighlightedTitleWhite alpha:1.0]
                   forState:UIControlStateHighlighted];
        // The same 0.8 is the title's whiteness above and the shadow's alpha here.
        [self setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:kHighlightedTitleWhite]
                         forState:UIControlStateHighlighted];

        // Likewise the 0.7 that was the normal shadow's alpha is the disabled title's alpha.
        [self setTitleColor:[UIColor colorWithWhite:1.0 alpha:kNormalShadowAlpha]
                   forState:UIControlStateDisabled];
        [self setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:kDisabledShadowAlpha]
                         forState:UIControlStateDisabled];

        self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        self.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    }
    return self;
}

/** @ghidraAddress 0x170c4c */
- (UIColor *)buttonColor {
    // Built on first read, not in the initialiser, so a button that is never drawn never makes one.
    if (!_buttonColor) {
        _buttonColor = UIColor.blueColor;
    }
    return _buttonColor;
}

/** @ghidraAddress 0x170ca8 */
- (void)setButtonColor:(UIColor *)buttonColor {
    _buttonColor = buttonColor;
    // The button draws its own fill, so changing the colour has to invalidate it.
    [self setNeedsDisplay];
}

/** @ghidraAddress 0x170cfc */
- (UIColor *)disabledColor {
    if (!_disabledColor) {
        _disabledColor = UIColor.grayColor;
    }
    return _disabledColor;
}

/** @ghidraAddress 0x170d58 */
- (void)setDisabledColor:(UIColor *)disabledColor {
    _disabledColor = disabledColor;
    [self setNeedsDisplay];
}

/** @ghidraAddress 0x170dd4 */
- (UIColor *)highlightColor:(double *)components factor:(double)factor {
    double keep = 1.0 - factor;
    // Alpha is blended along with the three colour components, so lightening also makes the colour
    // more opaque.
    return [UIColor colorWithRed:components[kComponentRed] * keep + factor
                           green:components[kComponentGreen] * keep + factor
                            blue:components[kComponentBlue] * keep + factor
                           alpha:components[kComponentAlpha] * keep + factor];
}

/** @ghidraAddress 0x170e1c */
- (void)setHighlighted:(BOOL)highlighted {
    // The old state is read from super before super is told the new one.
    BOOL changed = super.highlighted ^ highlighted;
    [super setHighlighted:highlighted];

    // Compared against 1 rather than tested for non-zero, so a caller passing anything but 0 or 1
    // would suppress the redraw.
    if (changed == 1) {
        [self setNeedsDisplay];
    }
}

/** @ghidraAddress 0x170ea8 */
- (void)setSelected:(BOOL)selected {
    BOOL changed = super.selected ^ selected;
    [super setSelected:selected];

    if (changed == 1) {
        [self setNeedsDisplay];
    }
}

/** @ghidraAddress 0x170f34 */
- (void)drawRect:(CGRect)rect {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClearRect(context, rect);

    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect
                                                    cornerRadius:self.cornerRadius];
    CGContextSaveGState(context);

    CGFloat shadowDepth;
    CGFloat shadowBlur;
    if (self.state == UIControlStateDisabled) {
        // No gradient when disabled: one flat fill, and the shadow below is drawn as for normal.
        [self.disabledColor setFill];
        [path fill];
        shadowDepth = kNormalShadowDepth;
        shadowBlur = kNormalShadowBlur;
    } else {
        BOOL highlighted = (self.state == UIControlStateHighlighted);
        CGFloat shade = highlighted ? kHighlightedShade : kNormalShade;
        shadowDepth = highlighted ? kHighlightedShadowDepth : kNormalShadowDepth;
        shadowBlur = highlighted ? kHighlightedShadowBlur : kNormalShadowBlur;

        double components[kRGBAComponentCount];
        // -getRed:green:blue:alpha: only arrived in iOS 5, hence the check rather than a plain
        // call.
        if ([UIColor instancesRespondToSelector:@selector(getRed:green:blue:alpha:)]) {
            [self.buttonColor getRed:&components[kComponentRed]
                               green:&components[kComponentGreen]
                                blue:&components[kComponentBlue]
                               alpha:&components[kComponentAlpha]];
        } else {
            const CGFloat *raw = CGColorGetComponents(self.buttonColor.CGColor);
            // Yes, buttonColor is fetched a second time for the count.
            if (CGColorGetNumberOfComponents(self.buttonColor.CGColor) == kRGBAComponentCount) {
                components[kComponentRed] = raw[0];
                components[kComponentGreen] = raw[1];
                components[kComponentBlue] = raw[2];
                components[kComponentAlpha] = raw[3];
            } else {
                // Greyscale: one value across all three channels, and the second is the alpha.
                components[kComponentRed] = raw[0];
                components[kComponentGreen] = raw[0];
                components[kComponentBlue] = raw[0];
                components[kComponentAlpha] = raw[1];
            }
        }

        // Darken the colour, but move the alpha towards opaque rather than scaling it down.
        double shaded[kRGBAComponentCount];
        shaded[kComponentRed] = shade * components[kComponentRed];
        shaded[kComponentGreen] = shade * components[kComponentGreen];
        shaded[kComponentBlue] = shade * components[kComponentBlue];
        shaded[kComponentAlpha] = (1.0 - shade) + shade * components[kComponentAlpha];

        UIColor *first = [self highlightColor:shaded factor:kGradientFactorFirst];
        UIColor *second = [self highlightColor:shaded factor:kGradientFactorSecond];
        UIColor *third = [self highlightColor:shaded factor:kGradientFactorThird];
        UIColor *fourth = [self highlightColor:shaded factor:kGradientFactorFourth];

        CGColorRef stops[] = {first.CGColor, second.CGColor, third.CGColor, fourth.CGColor};
        NSArray *colors = [NSArray arrayWithObjects:(__unsafe_unretained const id *)stops
                                              count:kGradientStopCount];
        CGFloat locations[] = {kGradientLocationFirst,
                               kGradientLocationSecond,
                               kGradientLocationThird,
                               kGradientLocationFourth};
        CGGradientRef gradient =
            CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, locations);

        [path addClip];
        // Bottom to top, so the lightest stop lands along the top edge.
        CGContextDrawLinearGradient(
            context, gradient, CGPointMake(0.0, rect.size.height), CGPointZero, 0);
        CGGradientRelease(gradient);
    }
    CGContextRestoreGState(context);

    CGColorRef shadowColor = UIColor.blackColor.CGColor;

    // Grow the path's bounds by the blur, lift it by the depth, union it back with the bounds it
    // came from, then grow the result by one more point.
    CGRect grown = CGRectInset(path.bounds, -shadowBlur, -shadowBlur);
    CGRect lifted = CGRectOffset(grown, kNoHorizontalOffset, -shadowDepth);
    CGRect outer = CGRectInset(CGRectUnion(lifted, path.bounds), kOuterInset, kOuterInset);

    // The rounded path punched out of that rect, so filling it covers everything except the button.
    UIBezierPath *mask = [UIBezierPath bezierPathWithRect:outer];
    [mask appendPath:path];
    mask.usesEvenOddFillRule = YES;

    CGContextSaveGState(context);

    // This is how the inner shadow is drawn without a dedicated API. The shadow is thrown a whole
    // button-width to the right and the mask is then translated the same distance to the left, so
    // the mask itself lands outside the clip and only the shadow it casts is visible.
    CGFloat slide = round(outer.size.width);
    // The binary adds a literal zero to the rounded width before the nudge.
    CGContextSetShadowWithColor(context,
                                CGSizeMake(slide + copysign(kShadowNudge, slide),
                                           shadowDepth + copysign(kShadowNudge, shadowDepth)),
                                shadowBlur,
                                shadowColor);

    [path addClip];
    [mask applyTransform:CGAffineTransformMakeTranslation(-slide, 0.0)];
    // The fill colour never shows; only the shadow cast by this fill does.
    [UIColor.grayColor setFill];
    [mask fill];

    CGContextRestoreGState(context);
    CGColorSpaceRelease(space);
}

/** @ghidraAddress 0x171624 */
- (void)dealloc {
    // Through the setters rather than the ivars, so each one calls -setNeedsDisplay on a view that
    // is going away.
    self.buttonColor = nil;
    self.disabledColor = nil;
}

@end
