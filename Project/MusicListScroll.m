#import "MusicListScroll.h"

@implementation MusicListScroll

/** @ghidraAddress 0x3b154 */
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // Only while the gesture is still a candidate tap. Once dragging is set the touch belongs to
    // the scroll and the responder chain is skipped.
    if (!self.dragging) {
        [self.nextResponder touchesBegan:touches withEvent:event];
    }
    // Sent either way, so the scroll view always sees the touch itself.
    [super touchesBegan:touches withEvent:event];
}

/** @ghidraAddress 0x3b234 */
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // The mirror of -touchesBegan:withEvent: above, instruction for instruction.
    if (!self.dragging) {
        [self.nextResponder touchesEnded:touches withEvent:event];
    }
    [super touchesEnded:touches withEvent:event];
}

@end
