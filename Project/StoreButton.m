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

/** @ghidraAddress 0x171624 */
- (void)dealloc {
    // Through the setters rather than the ivars, so each one calls -setNeedsDisplay on a view that
    // is going away.
    self.buttonColor = nil;
    self.disabledColor = nil;
}

@end
