#import "GradationView.h"

// The two stops sit at the very ends, so the gradient runs the full height with no plateau. Read
// as a pair of doubles rather than guessed from the shape of the call.
static const CGFloat kGradientLocations[] = {0.0, 1.0}; // @ghidraAddress 0x294520

@implementation GradationView

/** @ghidraAddress 0x253cbc */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Direct ivar assignment, so these retain rather than copy despite the property attribute.
        _topColor = UIColor.clearColor;
        _bottomColor = UIColor.clearColor;
    }
    return self;
}

/** @ghidraAddress 0x253ecc */
- (void)dealloc {
    // Redundant: the class also has a compiler-generated .cxx_destruct at 0x253f94, which already
    // releases both ivars. The binary carries both, so the reconstruction does too. The
    // [super dealloc] the binary ends with is ARC's, not the author's, so it is not written here.
    _topColor = nil;
    _bottomColor = nil;
}

/** @ghidraAddress 0x253d7c */
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    const void *colorValues[] = {self.topColor.CGColor, self.bottomColor.CGColor};
    CFArrayRef colors = CFArrayCreate(kCFAllocatorDefault,
                                      colorValues,
                                      sizeof(colorValues) / sizeof(colorValues[0]),
                                      &kCFTypeArrayCallBacks);
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colors, kGradientLocations);

    // Straight down the middle of the rectangle it was asked to draw, so this honours its rect
    // argument rather than reaching for bounds.
    CGPoint start = CGPointMake(rect.origin.x + rect.size.width / 2, rect.origin.y);
    CGPoint end = CGPointMake(start.x, rect.origin.y + rect.size.height);
    CGContextDrawLinearGradient(context, gradient, start, end, 0);

    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    CFRelease(colors);
}

@end
