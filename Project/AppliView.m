#import "AppliView.h"

// All six flexible bits: the raw mask is 0x3f.
static const UIViewAutoresizing kFullyFlexibleMask =
    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

@implementation AppliView

/** @ghidraAddress 0x226fd0 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = YES;
        self.autoresizingMask = kFullyFlexibleMask;
        self.contentMode = UIViewContentModeScaleAspectFit;
    }
    return self;
}

/** @ghidraAddress 0x227068 */
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    // Yes, a debug log shipped in the release build, and no [super touchesEnded:withEvent:].
    NSLog(@"AppliView touchesEnded");
    // Both arguments are unused. The delegate call is a tail call in the binary.
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(toucheEnded)]) {
        [self.delegate toucheEnded];
    }
}

@end
