#import "DetailTextView.h"

@implementation DetailTextView

/** @ghidraAddress 0xea070 */
- (BOOL)canBecomeFirstResponder {
    // The whole body is `mov w0, #0` followed by `ret`.
    return NO;
}

@end
