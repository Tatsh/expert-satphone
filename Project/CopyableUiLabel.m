#import "CopyableUiLabel.h"

@implementation CopyableUiLabel

/** @ghidraAddress 0xcae50 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        // UILabel has this off by default, so it is what makes the whole class work.
        self.userInteractionEnabled = YES;
    }
    return self;
}

/** @ghidraAddress 0xcaeec */
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];

    [self becomeFirstResponder];
    UIMenuController *menuController = UIMenuController.sharedMenuController;
    [menuController setTargetRect:self.bounds inView:self];
    [menuController setMenuVisible:YES animated:YES];
}

/** @ghidraAddress 0xcafcc */
- (BOOL)canBecomeFirstResponder {
    return YES;
}

/** @ghidraAddress 0xcafd4 */
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    // A pointer comparison against the selector constant, not a string match.
    if (action == @selector(copy:)) {
        return YES;
    }
    return [super canPerformAction:action withSender:sender];
}

/** @ghidraAddress 0xcb024 */
- (void)copy:(id)sender {
    // Yes, sender is unused. This is the UIResponderStandardEditActions copy:, not NSObject's
    // -copy.
    UIPasteboard.generalPasteboard.string = self.text;
}

@end
