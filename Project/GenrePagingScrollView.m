#import "GenrePagingScrollView.h"

@implementation GenrePagingScrollView

/** @ghidraAddress 0x1db384 */
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    // Identical to -[PagingScrollView hitTest:withEvent:], down to the instruction sequence.
    for (UIView *page in self.subviews) {
        if (CGRectContainsPoint(page.frame, point)) {
            return page;
        }
    }
    return self;
}

@end
