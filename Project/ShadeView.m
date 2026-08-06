#import "ShadeView.h"

// A flat dark grey at 80% alpha. Not one of the predefined class colours: darkGrayColor is a third
// white, so this is kept as the component call the binary makes.
static const CGFloat kShadeComponent = 0.2f; // @ghidraAddress 0x28f240
static const CGFloat kShadeAlpha = 0.8f;     // @ghidraAddress 0x28e080

@implementation ShadeView

/** @ghidraAddress 0x25d674 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = YES;
        self.backgroundColor = [UIColor colorWithRed:kShadeComponent
                                               green:kShadeComponent
                                                blue:kShadeComponent
                                               alpha:kShadeAlpha];
    }
    return self;
}

/** @ghidraAddress 0x25d738 */
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    // Yes, both arguments are unused, and there is no [super touchesEnded:withEvent:]. Any tap
    // anywhere on the shade is the same event.
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(closeShadeView)]) {
        [self.delegate closeShadeView];
    }
}

@end
