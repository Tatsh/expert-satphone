// A reconstruction of Sam Vermette's third-party SVSegmentedControl (MIT licence,
// https://github.com/samvermette/SVSegmentedControl). The shipped binary is an early-2012 fork
// with Konami additions (an accessibility layer, a retained delegate, and modern text drawing
// APIs) layered over the upstream design.

#import "SVSegmentedControl.h"

#import <QuartzCore/QuartzCore.h>

#import "SVSegmentedThumb.h"

// The animated snap and settle durations, the drag detent, and the drawing alphas the control
// reads from the constant pool.
static const NSTimeInterval kSVSegmentedControlActivateDuration = 0.1;
static const NSTimeInterval kSVSegmentedControlMoveDuration = 0.2;
static const double kSVSegmentedControlDragBuffer = 2.0;
static const double kSVSegmentedControlDragThreshold = 10.0;
static const double kSVSegmentedControlGlossAlpha = 0.1;
static const double kSVSegmentedControlInnerShadowAlpha = 0.6;
static const double kSVSegmentedControlStrokeAlpha = 0.9;

@interface SVSegmentedControl ()

@property(nonatomic, strong) NSMutableArray *titlesArray;
@property(nonatomic, strong) NSMutableArray *thumbRects;
@property(nonatomic, strong) NSMutableArray *accessibilityElements;

@property(nonatomic, assign) NSUInteger snapToIndex;
@property(nonatomic, assign) BOOL trackingThumb;
@property(nonatomic, assign) BOOL moved;
@property(nonatomic, assign) BOOL activated;

@property(nonatomic, assign) double halfSize;
@property(nonatomic, assign) double dragOffset;
@property(nonatomic, assign) double segmentWidth;
@property(nonatomic, assign) double thumbHeight;

- (void)setupAccessibility;
- (void)snap:(BOOL)animated;
- (void)updateTitles;
- (void)activate;
- (void)toggle;

@end

@implementation SVSegmentedControl

// The backing ivars carry the property names verbatim (no leading underscore), so every property
// is synthesised onto its own binary ivar.
@synthesize changeHandler = changeHandler;
@synthesize selectedSegmentChangedHandler = selectedSegmentChangedHandler;
@synthesize delegate = delegate;
@synthesize thumb = thumb;
@synthesize selectedIndex = selectedIndex;
@synthesize animateToInitialSelection = animateToInitialSelection;
@synthesize crossFadeLabelsOnDrag = crossFadeLabelsOnDrag;
@synthesize tintColor = tintColor;
@synthesize backgroundImage = backgroundImage;
@synthesize height = height;
@synthesize thumbEdgeInset = thumbEdgeInset;
@synthesize titleEdgeInsets = titleEdgeInsets;
@synthesize cornerRadius = cornerRadius;
@synthesize font = font;
@synthesize textColor = textColor;
@synthesize textShadowColor = textShadowColor;
@synthesize textShadowOffset = textShadowOffset;
@synthesize shadowColor = shadowColor;
@synthesize shadowOffset = shadowOffset;
@synthesize segmentPadding = segmentPadding;
@synthesize titlesArray = titlesArray;
@synthesize thumbRects = thumbRects;
@synthesize accessibilityElements = accessibilityElements;
@synthesize snapToIndex = snapToIndex;
@synthesize trackingThumb = trackingThumb;
@synthesize moved = moved;
@synthesize activated = activated;
@synthesize halfSize = halfSize;
@synthesize dragOffset = dragOffset;
@synthesize segmentWidth = segmentWidth;
@synthesize thumbHeight = thumbHeight;

#pragma mark - Life Cycle

/** @ghidraAddress 0x16a4b0 */
- (instancetype)initWithSectionTitles:(NSArray<NSString *> *)titlesArray {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.titlesArray = [NSMutableArray arrayWithArray:titlesArray];
        self.thumbRects = [NSMutableArray arrayWithCapacity:titlesArray.count];
        self.accessibilityElements = [NSMutableArray arrayWithCapacity:self.titlesArray.count];

        self.backgroundColor = UIColor.clearColor;
        self.tintColor = UIColor.grayColor;
        self.clipsToBounds = YES;
        self.userInteractionEnabled = YES;
        self.animateToInitialSelection = NO;
        self.clipsToBounds = NO;

        self.font = [UIFont boldSystemFontOfSize:15];
        self.textColor = UIColor.grayColor;
        self.textShadowColor = UIColor.blackColor;
        self.textShadowOffset = CGSizeMake(0, -1);

        self.titleEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 10);
        self.thumbEdgeInset = UIEdgeInsetsMake(2, 2, 3, 2);
        self.height = 32.0;
        self.cornerRadius = 4.0;

        self.selectedIndex = 0;
        self.thumb.segmentedControl = self;
    }
    return self;
}

/** @ghidraAddress 0x16a874 */
- (SVSegmentedThumb *)thumb {
    if (thumb == nil) {
        thumb = [[SVSegmentedThumb alloc] initWithFrame:CGRectZero];
    }
    return thumb;
}

/** @ghidraAddress 0x16a8e4 */
- (void)willMoveToSuperview:(nullable UIView *)newSuperview {
    if (newSuperview == nil) {
        return;
    }

    int c = (int)self.titlesArray.count;

    self.segmentWidth = 0;

    for (NSString *titleString in self.titlesArray) {
        CGSize titleSize = [titleString sizeWithAttributes:@{NSFontAttributeName : self.font}];
        double stringWidth =
            titleSize.width + (self.titleEdgeInsets.left + self.titleEdgeInsets.right +
                               self.thumbEdgeInset.left + self.thumbEdgeInset.right);
        self.segmentWidth = MAX(stringWidth, self.segmentWidth);
    }

    // Round the segment width up to an even number so the thumb can be positioned by its centre.
    self.segmentWidth = ceil(self.segmentWidth / 2.0) * 2.0;
    self.bounds = CGRectMake(0, 0, self.segmentWidth * c, self.height);
    self.thumbHeight = self.thumb.backgroundImage ?
                           self.thumb.backgroundImage.size.height :
                           self.height - (self.thumbEdgeInset.top + self.thumbEdgeInset.bottom);

    int i = 0;
    for (NSString *titleString in self.titlesArray) {
        (void)titleString;
        CGRect thumbRect = CGRectMake(self.segmentWidth * i + self.thumbEdgeInset.left,
                                      self.thumbEdgeInset.top,
                                      self.segmentWidth - (self.thumbEdgeInset.left * 2),
                                      self.thumbHeight);
        [self.thumbRects addObject:[NSValue valueWithCGRect:thumbRect]];
        ++i;
    }

    self.thumb.frame = [self.thumbRects[0] CGRectValue];
    self.thumb.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.thumb.bounds cornerRadius:2].CGPath;
    self.thumb.label.text = self.titlesArray[0];
    self.thumb.font = self.font;

    [self insertSubview:self.thumb atIndex:0];

    BOOL animateInitial = self.animateToInitialSelection;
    if (self.selectedIndex == 0) {
        animateInitial = NO;
    }

    [self moveThumbToIndex:self.selectedIndex animate:animateInitial];
}

#pragma mark - Drawing code

/** @ghidraAddress 0x16b190 */
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();

    if (self.backgroundImage) {
        [self.backgroundImage drawInRect:rect];
    } else {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();

        // Bottom gloss.
        CGContextSetFillColorWithColor(
            context, [UIColor colorWithWhite:1 alpha:kSVSegmentedControlGlossAlpha].CGColor);
        CGPathRef bottomGlossRect =
            [UIBezierPath
                bezierPathWithRoundedRect:CGRectMake(0, 0, rect.size.width, rect.size.height)
                             cornerRadius:self.cornerRadius]
                .CGPath;
        CGContextAddPath(context, bottomGlossRect);
        CGContextFillPath(context);

        CGPathRef roundedRect =
            [UIBezierPath
                bezierPathWithRoundedRect:CGRectMake(0, 0, rect.size.width, rect.size.height - 1)
                             cornerRadius:self.cornerRadius]
                .CGPath;
        CGContextAddPath(context, roundedRect);
        CGContextClip(context);

        // Background tint gradient.
        /** @ghidraAddress 0x100293358 */
        CGFloat components[] = {0.10, 1, 0.12, 1};
        CGGradientRef gradient =
            CGGradientCreateWithColorComponents(colorSpace, components, NULL, 2);
        CGContextDrawLinearGradient(
            context, gradient, CGPointMake(0, 0), CGPointMake(0, CGRectGetHeight(rect) - 1), 0);
        CGGradientRelease(gradient);

        [self.tintColor set];
        UIRectFillUsingBlendMode(rect, kCGBlendModeOverlay);

        // Inner shadow.
        CGContextAddPath(context, roundedRect);
        CGContextSetShadowWithColor(
            UIGraphicsGetCurrentContext(),
            CGSizeMake(0, 1),
            1,
            [UIColor colorWithWhite:0 alpha:kSVSegmentedControlInnerShadowAlpha].CGColor);
        CGContextSetStrokeColorWithColor(
            context, [UIColor colorWithWhite:0 alpha:kSVSegmentedControlStrokeAlpha].CGColor);
        CGContextStrokePath(context);

        CGColorSpaceRelease(colorSpace);
    }

    CGContextSetShadowWithColor(context, self.textShadowOffset, 0, self.textShadowColor.CGColor);
    [self.textColor set];

    double posY = ceil((CGRectGetHeight(rect) - self.font.pointSize + self.font.descender) / 2) +
                  self.titleEdgeInsets.top - self.titleEdgeInsets.bottom;
    int pointSize = (int)self.font.pointSize;

    if (pointSize % 2 != 0) {
        posY--;
    }

    int i = 0;
    for (NSString *titleString in self.titlesArray) {
        CGRect labelRect =
            CGRectMake(self.segmentWidth * i, posY, self.segmentWidth, self.font.pointSize);
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.lineBreakMode = NSLineBreakByClipping;
        paragraphStyle.alignment = NSTextAlignmentCenter;
        [titleString drawInRect:labelRect
                 withAttributes:@{
                     NSForegroundColorAttributeName : self.textColor,
                     NSFontAttributeName : self.font,
                     NSParagraphStyleAttributeName : paragraphStyle
                 }];
        ++i;
    }
}

#pragma mark - Bounds and centre overrides

/** @ghidraAddress 0x16b990 */
- (void)setBounds:(CGRect)bounds {
    [super setBounds:bounds];
    [self setupAccessibility];
}

/** @ghidraAddress 0x16b9e4 */
- (void)setCenter:(CGPoint)center {
    [super setCenter:center];
    [self setupAccessibility];
}

#pragma mark - Accessibility

/** @ghidraAddress 0x16ba38 */
- (void)setupAccessibility {
    [self.accessibilityElements removeAllObjects];

    int i = 0;
    for (NSString *titleString in self.titlesArray) {
        UIAccessibilityElement *element =
            [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
        element.isAccessibilityElement = YES;

        NSString *labelFormat = [NSBundle.mainBundle localizedStringForKey:@"%@ tab"
                                                                     value:@""
                                                                     table:nil];
        element.accessibilityLabel = [NSString stringWithFormat:labelFormat, titleString];

        NSString *hintFormat = [NSBundle.mainBundle localizedStringForKey:@"Tab %d of %d"
                                                                    value:@""
                                                                    table:nil];
        element.accessibilityHint =
            [NSString stringWithFormat:hintFormat, i + 1, (int)self.titlesArray.count];

        [self.accessibilityElements addObject:element];
        ++i;
    }
}

/** @ghidraAddress 0x16bde8 */
- (NSInteger)accessibilityElementCount {
    return self.accessibilityElements.count;
}

/** @ghidraAddress 0x16be34 */
- (nullable id)accessibilityElementAtIndex:(NSInteger)index {
    UIAccessibilityElement *element = self.accessibilityElements[index];

    double posY =
        ceil((CGRectGetHeight(self.bounds) - self.font.pointSize + self.font.descender) / 2) +
        self.titleEdgeInsets.top - self.titleEdgeInsets.bottom;
    CGRect segmentRect =
        CGRectMake(self.segmentWidth * index, posY, self.segmentWidth, self.font.pointSize);
    element.accessibilityFrame = [self.window convertRect:segmentRect fromView:self];
    element.accessibilityTraits = UIAccessibilityTraitNone;

    if (self.selectedIndex == index) {
        element.accessibilityTraits = element.accessibilityTraits | UIAccessibilityTraitSelected;
    } else if (!self.isEnabled) {
        element.accessibilityTraits = element.accessibilityTraits | UIAccessibilityTraitNotEnabled;
    }

    return element;
}

/** @ghidraAddress 0x16c0b4 */
- (NSInteger)indexOfAccessibilityElement:(id)element {
    NSString *label = [[element accessibilityLabel] componentsSeparatedByString:@" "][0];
    return [self.titlesArray indexOfObject:label];
}

#pragma mark - Tracking

/** @ghidraAddress 0x16c184 */
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [super beginTrackingWithTouch:touch withEvent:event];

    CGPoint cPos = [touch locationInView:self.thumb];
    self.activated = NO;

    self.snapToIndex = (NSUInteger)floor(self.thumb.center.x / self.segmentWidth);

    if (CGRectContainsPoint(self.thumb.bounds, cPos)) {
        self.trackingThumb = YES;
        [self.thumb deactivate];
        self.dragOffset = (self.thumb.frame.size.width / 2) - cPos.x;
    }

    return YES;
}

/** @ghidraAddress 0x16c388 */
- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [super continueTrackingWithTouch:touch withEvent:event];

    CGPoint cPos = [touch locationInView:self];
    double newPos = cPos.x + self.dragOffset;
    double newMaxX = newPos + (CGRectGetWidth(self.thumb.frame) / 2);
    double newMinX = newPos - (CGRectGetWidth(self.thumb.frame) / 2);

    double buffer = kSVSegmentedControlDragBuffer;
    double pMaxX = CGRectGetMaxX(self.bounds) - buffer;
    double pMinX = CGRectGetMinX(self.bounds) + buffer;

    if ((newMaxX > pMaxX || newMinX < pMinX) && self.trackingThumb) {
        self.snapToIndex = (NSUInteger)floor(self.thumb.center.x / self.segmentWidth);

        if (newMaxX - pMaxX > kSVSegmentedControlDragThreshold ||
            pMinX - newMinX > kSVSegmentedControlDragThreshold) {
            self.moved = YES;
        }

        [self snap:NO];
    } else {
        if (!self.trackingThumb) {
            return YES;
        }
        self.thumb.center = CGPointMake(cPos.x + self.dragOffset, self.thumb.center.y);
        self.moved = YES;
    }

    if (self.crossFadeLabelsOnDrag) {
        [self updateTitles];
    }

    return YES;
}

/** @ghidraAddress 0x16c674 */
- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [super endTrackingWithTouch:touch withEvent:event];

    CGPoint cPos = [touch locationInView:self];
    double pMaxX = CGRectGetMaxX(self.bounds);
    double pMinX = CGRectGetMinX(self.bounds);

    if (!self.moved && self.trackingThumb && self.titlesArray.count == 2) {
        [self toggle];
        return;
    }

    if (!self.activated && cPos.x > pMinX && cPos.x < pMaxX) {
        self.snapToIndex = (NSUInteger)floor(cPos.x / self.segmentWidth);
        [self snap:YES];
    } else {
        double posX = cPos.x;

        if (posX < pMinX) {
            posX = pMinX;
        }

        if (posX >= pMaxX) {
            posX = pMaxX - 1;
        }

        self.snapToIndex = (NSUInteger)floor(posX / self.segmentWidth);
        [self snap:YES];
    }
}

/** @ghidraAddress 0x16c82c */
- (void)cancelTrackingWithEvent:(nullable UIEvent *)event {
    [super cancelTrackingWithEvent:event];

    if (self.trackingThumb) {
        [self snap:NO];
    }
}

#pragma mark - Snapping and title cross-fade

/** @ghidraAddress 0x16c898 */
- (void)snap:(BOOL)animated {
    [self.thumb deactivate];

    if (self.crossFadeLabelsOnDrag) {
        self.thumb.secondLabel.alpha = 0;
    }

    NSInteger index;
    if (self.snapToIndex != (NSUInteger)-1) {
        index = (NSInteger)self.snapToIndex;
    } else {
        index = (NSInteger)floor(self.thumb.center.x / self.segmentWidth);
    }

    self.thumb.label.text = self.titlesArray[index];

    if (self.changeHandler && self.snapToIndex != self.selectedIndex && !self.isTracking) {
        self.changeHandler(self.snapToIndex);
    }

    if (animated) {
        [self moveThumbToIndex:index animate:YES];
    } else {
        self.thumb.frame = [self.thumbRects[index] CGRectValue];
    }
}

/** @ghidraAddress 0x16cbf4 */
- (void)updateTitles {
    int hoverIndex = (int)(self.thumb.center.x / self.segmentWidth);

    BOOL secondTitleOnLeft = ((self.thumb.center.x / self.segmentWidth) - hoverIndex) < 0.5;

    if (secondTitleOnLeft && hoverIndex > 0) {
        self.thumb.label.alpha = 0.5 + ((self.thumb.center.x / self.segmentWidth) - hoverIndex);
        self.thumb.secondLabel.text = self.titlesArray[hoverIndex - 1];
        self.thumb.secondLabel.alpha =
            0.5 - ((self.thumb.center.x / self.segmentWidth) - hoverIndex);
    } else if (hoverIndex + 1 < self.titlesArray.count) {
        self.thumb.label.alpha =
            0.5 + (1 - ((self.thumb.center.x / self.segmentWidth) - hoverIndex));
        self.thumb.secondLabel.text = self.titlesArray[hoverIndex + 1];
        self.thumb.secondLabel.alpha =
            ((self.thumb.center.x / self.segmentWidth) - hoverIndex) - 0.5;
    } else {
        self.thumb.secondLabel.text = nil;
        self.thumb.label.alpha = 1.0;
    }

    self.thumb.label.text = self.titlesArray[hoverIndex];
}

#pragma mark - Selection

/** @ghidraAddress 0x16d24c */
- (void)activate {
    self.moved = NO;
    self.trackingThumb = NO;

    self.thumb.label.text = self.titlesArray[self.selectedIndex];

    // Read the deprecated members through KVC to avoid the deprecation diagnostics.
    void (^oldChangeHandler)(id sender) = [self valueForKey:@"selectedSegmentChangedHandler"];
    if (oldChangeHandler) {
        oldChangeHandler(self);
    }

    if ([self valueForKey:@"delegate"]) {
        id<SVSegmentedControlDelegate> controlDelegate = [self valueForKey:@"delegate"];
        if ([controlDelegate respondsToSelector:@selector(segmentedControl:didSelectIndex:)]) {
            [controlDelegate segmentedControl:self didSelectIndex:self.selectedIndex];
        }
    }

    [UIView animateWithDuration:kSVSegmentedControlActivateDuration
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                       /** @ghidraAddress 0x16d47c */
                       self.activated = YES;
                       [self.thumb activate];
                     }
                     completion:NULL];
}

/** @ghidraAddress 0x16d4d8 */
- (void)toggle {
    self.snapToIndex = (self.snapToIndex == 0) ? 1 : 0;
    [self snap:YES];
}

/** @ghidraAddress 0x16d534 */
- (void)moveThumbToIndex:(NSUInteger)segmentIndex animate:(BOOL)animate {
    self.selectedIndex = segmentIndex;
    [self sendActionsForControlEvents:UIControlEventValueChanged];

    if (animate) {
        [self.thumb deactivate];

        [UIView animateWithDuration:kSVSegmentedControlMoveDuration
            delay:0
            options:UIViewAnimationOptionCurveEaseOut
            animations:^{
              /** @ghidraAddress 0x16d6e4 */
              self.thumb.frame = [self.thumbRects[segmentIndex] CGRectValue];

              if (self.crossFadeLabelsOnDrag) {
                  [self updateTitles];
              }
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x16d7d0 */
              if (finished) {
                  [self activate];
              }
            }];
    } else {
        self.thumb.frame = [self.thumbRects[segmentIndex] CGRectValue];
        [self activate];
    }
}

#pragma mark - Custom setters

/** @ghidraAddress 0x16d7e8 */
- (void)setBackgroundImage:(nullable UIImage *)newImage {
    if (backgroundImage) {
        backgroundImage = nil;
    }

    if (newImage) {
        backgroundImage = newImage;
        self.height = backgroundImage.size.height;
    }
}

#pragma mark - Support for deprecated methods

/** @ghidraAddress 0x16d870 */
- (void)setSegmentPadding:(double)newPadding {
    self.titleEdgeInsets = UIEdgeInsetsMake(0, newPadding, 0, newPadding);
}

/** @ghidraAddress 0x16d88c */
- (void)setShadowOffset:(CGSize)newOffset {
    self.textShadowOffset = newOffset;
}

/** @ghidraAddress 0x16d898 */
- (void)setShadowColor:(nullable UIColor *)newColor {
    self.textShadowColor = newColor;
}

@end
