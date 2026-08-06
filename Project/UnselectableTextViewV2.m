#import "UnselectableTextViewV2.h"

@implementation UnselectableTextViewV2

/** @ghidraAddress 0x1dbf68 */
- (BOOL)canBecomeFirstResponder {
    // The whole body is `mov w0, #0` followed by `ret`.
    return NO;
}

@end
