#import "PagingScrollView.h"

@implementation PagingScrollView

/** @ghidraAddress 0x1bad14 */
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    // Fast enumeration over the direct subviews, in order, returning the first whose frame contains
    // the point. The test is CGRectContainsPoint against -frame, so it is done in this view's own
    // coordinate space and needs no conversion.
    for (UIView *page in self.subviews) {
        if (CGRectContainsPoint(page.frame, point)) {
            return page;
        }
    }
    // Nothing matched, so the scroll view itself takes the touch.
    return self;
}

@end
