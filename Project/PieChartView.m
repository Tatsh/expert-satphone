#import "PieChartView.h"

// The animation timer's tick interval, its minimum per-tick step, and the settle epsilon.
static const NSTimeInterval kAnimTickInterval = 0.01;
static const float kAnimMinStep = 0.04f;
static const float kAnimSettleEpsilon = 0.001f;

// The eased fraction of the remaining distance advanced per tick.
static const float kAnimEaseFactor = 0.125f;

// The maximum fill fraction.
static const float kMaxPercent = 1.0f;

// The default inner and outer border widths.
static const float kDefaultBorderWidth = 1.0f;

// The ring is drawn from the top: the arcs start at -pi/2 and sweep a full turn (or the filled
// fraction of one).
static const CGFloat kStartAngle = -M_PI_2;
static const CGFloat kTwoPi = 2.0 * M_PI;

// A one-point gap kept between the outer border and the ring.
static const float kOuterGap = 1.0f;

@implementation PieChartView {
    float lineWidth;        // +0x8
    float borderInWidth;    // +0xc
    float borderOutWidth;   // +0x10
    UIColor *lineColor;     // +0x18
    UIColor *borderColor;   // +0x20
    UIColor *baseLineColor; // +0x28
    UIColor *bgColor;       // +0x30
    float targetPercent;    // +0x38
    float currentPercent;   // +0x3c
    NSTimer *animTimer;     // +0x40
}

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0x9f8e0 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }
    _aDelegate = nil;
    self.backgroundColor = UIColor.clearColor;
    lineWidth = 0;
    borderInWidth = kDefaultBorderWidth;
    borderOutWidth = kDefaultBorderWidth;
    lineColor = UIColor.clearColor;
    baseLineColor = UIColor.grayColor;
    borderColor = UIColor.blackColor;
    bgColor = UIColor.clearColor;
    currentPercent = 0;
    return self;
}

#pragma mark - Configuration

/** @ghidraAddress 0x9fa74 */
- (void)setChartColor:(UIColor *)chartColor
            baseColor:(UIColor *)baseColor
          borderColor:(UIColor *)borderColor_ {
    lineColor = chartColor;
    baseLineColor = baseColor;
    borderColor = borderColor_;
}

/** @ghidraAddress 0x9fb34 */
- (void)setBgColor:(UIColor *)bgColor_ {
    bgColor = bgColor_;
}

/** @ghidraAddress 0x9fb48 */
- (void)setLineWidth:(float)lineWidth_
        borderInside:(float)borderInside
       borderOutsize:(float)borderOutsize {
    lineWidth = lineWidth_;
    borderInWidth = borderInside;
    borderOutWidth = borderOutsize;
}

#pragma mark - Percentage

/** @ghidraAddress 0x9fb70 */
- (void)setPercent:(float)percent {
    if (percent > kMaxPercent) {
        percent = kMaxPercent;
    }
    currentPercent = percent;
    [self setNeedsDisplay];
}

/** @ghidraAddress 0x9fb90 */
- (void)startNextPercent:(float)percent {
    if (animTimer != nil) {
        return;
    }
    if (percent > kMaxPercent) {
        percent = kMaxPercent;
    }
    targetPercent = percent;
    animTimer = [NSTimer scheduledTimerWithTimeInterval:kAnimTickInterval
                                                 target:self
                                               selector:@selector(timerRefresh:)
                                               userInfo:nil
                                                repeats:YES];
}

/** @ghidraAddress 0x9fc20 */
- (void)timerRefresh:(NSTimer *)timer {
    // Advance the current fraction by an eased step, floored to the minimum, and clamp to target.
    float step = (targetPercent - currentPercent) * kAnimEaseFactor;
    if (step <= kAnimMinStep) {
        step = kAnimMinStep;
    }
    currentPercent = currentPercent + step;
    if (currentPercent > targetPercent) {
        currentPercent = targetPercent;
    }
    [self setNeedsDisplay];
    if (fabsf(currentPercent - targetPercent) < kAnimSettleEpsilon) {
        currentPercent = targetPercent;
        [animTimer invalidate];
        animTimer = nil;
        if (self.aDelegate != nil &&
            [self.aDelegate respondsToSelector:@selector(chartAnimationEnd)]) {
            [self.aDelegate performSelector:@selector(chartAnimationEnd) withObject:self];
        }
    }
}

/** @ghidraAddress 0x9fd98 */
- (void)refreshDisplay {
    [self setNeedsDisplay];
}

#pragma mark - Drawing

/** @ghidraAddress 0x9fda4 */
- (void)drawRect:(CGRect)rect {
    // The ring radius leaves room for the line and a full outer-border-plus-gap on each side, and
    // the centre is the view's own centre.
    CGFloat centerX = self.frame.size.width * 0.5;
    CGFloat centerY = self.frame.size.height * 0.5;
    float radius = (float)((self.frame.size.width - (double)lineWidth) * 0.5 -
                           (double)(borderOutWidth + borderOutWidth + kOuterGap));
    // The background disc is inscribed in the square that the diameter (2·radius) spans, centred.
    CGFloat discSize = (double)(int)(radius + radius);
    CGFloat discOrigin = (double)(int)((self.frame.size.width - discSize) * 0.5);
    UIBezierPath *disc = [UIBezierPath
        bezierPathWithOvalInRect:CGRectMake(discOrigin, discOrigin, discSize, discSize)];
    [bgColor setFill];
    [disc fill];

    // The outer border: a stroke just outside the ring, drawn only when the outer width is set.
    if (borderOutWidth > 0.0f) {
        UIBezierPath *outer = [UIBezierPath
            bezierPathWithArcCenter:CGPointMake(centerX, centerY)
                             radius:(double)((borderOutWidth + borderOutWidth) + radius)
                         startAngle:0
                           endAngle:kTwoPi
                          clockwise:YES];
        outer.lineWidth = (double)((borderOutWidth + borderOutWidth) + lineWidth);
        [borderColor setStroke];
        [outer stroke];
    }

    // The inner border: a stroke just inside the ring, drawn only when the inner width is set.
    if (borderInWidth > 0.0f) {
        float innerWidth = borderInWidth + borderInWidth;
        UIBezierPath *inner = [UIBezierPath bezierPathWithArcCenter:CGPointMake(centerX, centerY)
                                                             radius:(double)(radius - innerWidth)
                                                         startAngle:0
                                                           endAngle:kTwoPi
                                                          clockwise:YES];
        inner.lineWidth = (double)(innerWidth + lineWidth);
        [borderColor setStroke];
        [inner stroke];
    }

    // The base ring: the full unfilled track.
    UIBezierPath *base = [UIBezierPath bezierPathWithArcCenter:CGPointMake(centerX, centerY)
                                                        radius:(double)radius
                                                    startAngle:0
                                                      endAngle:kTwoPi
                                                     clockwise:YES];
    base.lineWidth = (double)lineWidth;
    [baseLineColor setStroke];
    [base stroke];

    // The filled arc: from the top, clockwise, spanning the current fraction of a full turn.
    if (currentPercent > 0.0f) {
        UIBezierPath *fill = [UIBezierPath
            bezierPathWithArcCenter:CGPointMake(centerX, centerY)
                             radius:(double)radius
                         startAngle:kStartAngle
                           endAngle:(double)(float)((double)currentPercent * kTwoPi + kStartAngle)
                          clockwise:YES];
        fill.lineWidth = (double)lineWidth;
        [lineColor setStroke];
        [fill stroke];
    }
}

@end
