#import "ApplilinkIndicator.h"

// The spinner's own frame, which nothing else depends on: -layoutSubviews positions it by centre.
static const CGFloat kIndicatorSize = 80.0; // @ghidraAddress 0x28f3f8

// How far the sheet dims what is behind it.
static const CGFloat kSheetAlpha = 0.5;

static const CGFloat kHalf = 0.5;

@implementation ApplilinkIndicator

/** @ghidraAddress 0x250048 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.indicator = [[UIActivityIndicatorView alloc]
            initWithFrame:CGRectMake(0, 0, kIndicatorSize, kIndicatorSize)];
        self.indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;

        self.backgroundColor = UIColor.blackColor;
        self.alpha = kSheetAlpha;

        [self addSubview:self.indicator];
    }
    return self;
}

/** @ghidraAddress 0x25017c */
- (void)layoutSubviews {
    [super layoutSubviews];

    // Guarded, because -close clears the reference while leaving the subview in place.
    if (self.indicator) {
        self.indicator.center =
            CGPointMake(self.bounds.size.width * kHalf, self.bounds.size.height * kHalf);
    }
}

/** @ghidraAddress 0x25022c */
- (void)show {
    self.hidden = NO;
    if (self.indicator) {
        [self.indicator startAnimating];
    }
}

/** @ghidraAddress 0x250284 */
- (void)close {
    self.hidden = YES;
    if (self.indicator) {
        [self.indicator stopAnimating];
        // Cleared without being removed from the hierarchy, so the spinner stays a subview that
        // nothing can reach.
        self.indicator = nil;
    }
}

/** @ghidraAddress 0x2502e8 */
- (void)touchEventActived {
    // The name reads as enabling something; what it does is stop this view intercepting touches, so
    // that whatever is behind it becomes reachable again.
    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = NO;
}

/** @ghidraAddress 0x25035c */
- (void)dealloc {
    // Empty in the binary too: the only instruction is the super call, and the class has a
    // .cxx_destruct (0x2503e0), so that call is what ARC emits.
}

@end
