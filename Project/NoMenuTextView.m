#import "NoMenuTextView.h"

@implementation NoMenuTextView

/** @ghidraAddress 0xd1a04 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        // Walks the recognisers UITextView installs for itself and disables only the long press,
        // which is the one that raises the selection menu. Everything else keeps working.
        for (UIGestureRecognizer *recognizer in self.gestureRecognizers) {
            if ([recognizer isKindOfClass:UILongPressGestureRecognizer.class]) {
                recognizer.enabled = NO;
            }
        }
    }
    return self;
}

/** @ghidraAddress 0xd1b94 */
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    // Neither argument is read: the answer is NO for every action, so this is a blanket refusal
    // rather than a filter.
    //
    // The side effect is the point. Being asked at all means the menu is coming up, so the menu is
    // dismissed on the way past. The shared controller is fetched twice — once to test and once to
    // use — and the first fetch is released before the nil test, which tests the raw pointer.
    if (UIMenuController.sharedMenuController != nil) {
        UIMenuController.sharedMenuController.menuVisible = NO;
    }
    return NO;
}

@end
