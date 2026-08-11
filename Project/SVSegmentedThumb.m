#import "SVSegmentedThumb.h"

#import <math.h>

#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

// The owning control, not reconstructed in this tree yet. Declared here as a partial stub of the
// selectors the thumb messages on it. See TYPES_PENDING.md.
@interface SVSegmentedControl : UIControl
- (CGFloat)height;
- (CGFloat)cornerRadius;
- (CGFloat)thumbEdgeInset;
- (UIEdgeInsets)titleEdgeInsets;
- (BOOL)crossFadeLabelsOnDrag;
@end

// The two device-gray gradient tiers that give the default pill its banded look, and their
// selected-state overrides. Each pair is {gray, alpha} in a device-gray colour space; the two
// pairs are the top and bottom stops. The base values live in the __const pool at 0x293380
// (outer) and 0x2933a0 (inner); the selected overrides arrive as fmov/movk immediates in the code.
static const size_t kThumbGradientStopCount = 2;
static const CGFloat kThumbOuterGrayTop = 0.55;    // @ghidraAddress 0x293380
static const CGFloat kThumbOuterAlphaTop = 1.0;    // @ghidraAddress 0x293388
static const CGFloat kThumbOuterGrayBottom = 0.4;  // @ghidraAddress 0x293390
static const CGFloat kThumbOuterAlphaBottom = 1.0; // @ghidraAddress 0x293398
static const CGFloat kThumbOuterGrayTopSelected = 0.45;
static const CGFloat kThumbOuterGrayBottomSelected = 0.3;
static const CGFloat kThumbInnerGrayTop = 0.5;     // @ghidraAddress 0x2933a0
static const CGFloat kThumbInnerAlphaTop = 1.0;    // @ghidraAddress 0x2933a8
static const CGFloat kThumbInnerGrayBottom = 0.35; // @ghidraAddress 0x2933b0
static const CGFloat kThumbInnerAlphaBottom = 1.0; // @ghidraAddress 0x2933b8
static const CGFloat kThumbInnerGrayTopSelected = 0.4;
static const CGFloat kThumbInnerGrayBottomSelected = 0.25;

// The selected thumb dims to 80% opacity when it has neither a crossfade nor a highlight image.
// Read from the __const pool at 0x28e060.
static const CGFloat kThumbSelectedAlpha = 0.8; // @ghidraAddress 0x28e060

@implementation SVSegmentedThumb

@synthesize segmentedControl = segmentedControl;
@synthesize backgroundImage = backgroundImage;
@synthesize highlightedBackgroundImage = highlightedBackgroundImage;
@synthesize tintColor = tintColor;
@dynamic textColor;
@dynamic textShadowColor;
@dynamic textShadowOffset;
@dynamic shouldCastShadow;
@synthesize selected = selected;
@dynamic shadowColor;
@dynamic shadowOffset;
@dynamic castsShadow;
@dynamic font;
@synthesize label = label;
@synthesize secondLabel = secondLabel;

#pragma mark - Lifecycle

/** @ghidraAddress 0x16f508 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = UIColor.clearColor;
        self.textColor = UIColor.whiteColor;
        self.textShadowColor = UIColor.blackColor;
        self.textShadowOffset = CGSizeMake(0, -1);
        self.tintColor = UIColor.grayColor;
        self.shouldCastShadow = YES;
    }
    return self;
}

#pragma mark - Labels

/** @ghidraAddress 0x16f680 */
- (UILabel *)label {
    if (label == nil) {
        label = [[UILabel alloc] initWithFrame:self.bounds];
        label.textAlignment = NSTextAlignmentCenter;
        label.font = self.font;
        label.backgroundColor = UIColor.clearColor;
        [self addSubview:label];
    }
    return label;
}

/** @ghidraAddress 0x16f7a4 */
- (UILabel *)secondLabel {
    if (secondLabel == nil) {
        secondLabel = [[UILabel alloc] initWithFrame:self.bounds];
        secondLabel.textAlignment = NSTextAlignmentCenter;
        secondLabel.font = self.font;
        secondLabel.backgroundColor = UIColor.clearColor;
        [self addSubview:secondLabel];
    }
    return secondLabel;
}

#pragma mark - Appearance setters

/** @ghidraAddress 0x16f8c8 */
- (UIFont *)font {
    return self.label.font;
}

/** @ghidraAddress 0x16fe84 */
- (void)setFont:(UIFont *)aFont {
    [self.secondLabel setFont:aFont];
    [self.label setFont:aFont];
}

/** @ghidraAddress 0x16fd84 */
- (void)setBackgroundImage:(UIImage *)image {
    self->backgroundImage = image;
    // The shadow casts only when there is no custom background image.
    self.shouldCastShadow = (image == nil);
}

/** @ghidraAddress 0x16fe10 */
- (void)setTintColor:(UIColor *)color {
    self->tintColor = color;
    [self setNeedsDisplay];
}

/** @ghidraAddress 0x16ff28 */
- (void)setTextColor:(UIColor *)color {
    // The library pushes the colour onto the labels and never stores the textColor ivar, so the
    // getter always reports the value seeded at init.
    [self.secondLabel setTextColor:color];
    [self.label setTextColor:color];
}

/** @ghidraAddress 0x16ffcc */
- (void)setTextShadowColor:(UIColor *)color {
    // Pushed onto both labels' shadowColor; the textShadowColor ivar itself is not stored.
    [self.secondLabel setShadowColor:color];
    [self.label setShadowColor:color];
}

/** @ghidraAddress 0x170070 */
- (void)setTextShadowOffset:(CGSize)offset {
    // Pushed onto both labels' shadowOffset; the textShadowOffset ivar itself is not stored.
    [self.secondLabel setShadowOffset:offset];
    [self.label setShadowOffset:offset];
}

/** @ghidraAddress 0x170110 */
- (void)setShouldCastShadow:(BOOL)cast {
    // Drives the layer's shadow opacity directly; the shouldCastShadow ivar itself is not stored.
    self.layer.shadowOpacity = (float)cast;
}

#pragma mark - Shadow aliases

/** @ghidraAddress 0x170818 */
- (void)setShadowColor:(UIColor *)color {
    [self setTextShadowColor:color];
}

/** @ghidraAddress 0x17080c */
- (void)setShadowOffset:(CGSize)offset {
    [self setTextShadowOffset:offset];
}

/** @ghidraAddress 0x170824 */
- (void)setCastsShadow:(BOOL)cast {
    [self setShouldCastShadow:cast];
}

#pragma mark - Selection

/** @ghidraAddress 0x1705ec */
- (void)setSelected:(BOOL)flag {
    self->selected = flag;
    CGFloat alpha = 1.0;
    if (flag && !self.segmentedControl.crossFadeLabelsOnDrag &&
        self.highlightedBackgroundImage == nil) {
        alpha = kThumbSelectedAlpha;
    }
    self.alpha = alpha;
    [self setNeedsDisplay];
}

/** @ghidraAddress 0x1706b4 */
- (void)activate {
    [self setSelected:NO];
    if (self.segmentedControl.crossFadeLabelsOnDrag) {
        return;
    }
    self.label.alpha = 1.0;
}

/** @ghidraAddress 0x170760 */
- (void)deactivate {
    [self setSelected:YES];
    if (self.segmentedControl.crossFadeLabelsOnDrag) {
        return;
    }
    self.label.alpha = 0.0;
}

#pragma mark - Layout

/** @ghidraAddress 0x170158 */
- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];

    CGFloat labelOriginY = self.segmentedControl.height - self.font.pointSize;
    labelOriginY = ceil((labelOriginY + self.font.descender) * 0.5);
    UIEdgeInsets titleInsets = self.segmentedControl.titleEdgeInsets;
    labelOriginY += titleInsets.top;
    labelOriginY -= titleInsets.bottom;
    labelOriginY -= self.segmentedControl.thumbEdgeInset;
    labelOriginY += 2.0;
    // Nudge the labels up a point when the font's point size is odd.
    if (((int)self.font.pointSize) & 1) {
        labelOriginY -= 1.0;
    }

    CGRect labelFrame = CGRectMake(0, labelOriginY, frame.size.width, self.font.pointSize);
    [self.secondLabel setFrame:labelFrame];
    [self.label setFrame:labelFrame];

    self.layer.shadowOffset = CGSizeZero;
    self.layer.shadowRadius = 1.0;
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                   cornerRadius:self.segmentedControl.cornerRadius - 1.0]
            .CGPath;
    self.layer.shouldRasterize = YES;
}

#pragma mark - Drawing

/** @ghidraAddress 0x16f91c */
- (void)drawRect:(CGRect)rect {
    UIImage *bg = self.backgroundImage;
    if (bg == nil || self.selected) {
        UIImage *highlighted = self.highlightedBackgroundImage;
        if (highlighted == nil || !self.selected) {
            CGFloat cornerRadius = self.segmentedControl.cornerRadius;
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();

            UIBezierPath *outerPath = [UIBezierPath bezierPathWithRoundedRect:rect
                                                                 cornerRadius:cornerRadius - 1.5];
            CGContextAddPath(context, outerPath.CGPath);
            CGContextClip(context);
            CGContextSaveGState(context);

            CGFloat outerComponents[] = {kThumbOuterGrayTop,
                                         kThumbOuterAlphaTop,
                                         kThumbOuterGrayBottom,
                                         kThumbOuterAlphaBottom};
            if (self.selected) {
                outerComponents[0] = kThumbOuterGrayTopSelected;
                outerComponents[2] = kThumbOuterGrayBottomSelected;
            }
            CGGradientRef outerGradient = CGGradientCreateWithColorComponents(
                colorSpace, outerComponents, nullptr, kThumbGradientStopCount);
            CGContextDrawLinearGradient(
                context, outerGradient, CGPointZero, CGPointMake(0, CGRectGetHeight(rect)), 0);
            CGGradientRelease(outerGradient);

            UIBezierPath *innerPath =
                [UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect, 1, 1)
                                           cornerRadius:cornerRadius - 2.5];
            CGContextAddPath(context, innerPath.CGPath);
            CGContextClip(context);

            CGFloat innerComponents[] = {kThumbInnerGrayTop,
                                         kThumbInnerAlphaTop,
                                         kThumbInnerGrayBottom,
                                         kThumbInnerAlphaBottom};
            if (self.selected) {
                innerComponents[0] = kThumbInnerGrayTopSelected;
                innerComponents[2] = kThumbInnerGrayBottomSelected;
            }
            CGGradientRef innerGradient = CGGradientCreateWithColorComponents(
                colorSpace, innerComponents, nullptr, kThumbGradientStopCount);
            CGContextDrawLinearGradient(
                context, innerGradient, CGPointZero, CGPointMake(0, CGRectGetHeight(rect)), 0);
            CGGradientRelease(innerGradient);
            CGColorSpaceRelease(colorSpace);
            CGContextRestoreGState(context);

            [self.tintColor set];
            UIRectFillUsingBlendMode(rect, kCGBlendModeOverlay);
            return;
        }
        [highlighted drawInRect:rect];
    } else {
        [bg drawInRect:rect];
    }
}

@end
