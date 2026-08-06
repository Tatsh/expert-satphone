#import "UnselectableTextView.h"

@implementation UnselectableTextView

/** @ghidraAddress 0xb03b8 */
- (BOOL)canBecomeFirstResponder {
    // The whole body is `mov w0, #0` followed by `ret`.
    return NO;
}

@end
