#import "InfoLabel.h"

// The one inset the label applies, and the only non-zero number in the method. Both fmov
// immediates at 0x1d57e0 and 0x1d57f0 decode to a magnitude of 12.0: imm8 0x28 and 0xA8, which
// differ only in the sign bit. Ghidra prints the second as "-0x3fd8000000000000", which is neither
// the value nor its bit pattern, so it was decoded from the instruction encoding instead.
static const CGFloat kInfoLabelLeftInset = 12.0;

@implementation InfoLabel

/** @ghidraAddress 0x1d57d4 */
- (void)drawTextInRect:(CGRect)rect {
    // A left inset and nothing else: the origin moves right by 12 and the width shrinks by the
    // same 12, so the right edge lands exactly where it started.
    //
    // Two oddities, both faithful. The y coordinate is added to a register the previous instruction
    // has just zeroed, so it is a no-op the compiler emitted anyway. And the height is not touched
    // at all — there is no fourth fadd. A symmetric UIEdgeInsetsInsetRect would have subtracted
    // twice the inset from the width, so this is not that.
    CGRect textRect = CGRectMake(rect.origin.x + kInfoLabelLeftInset,
                                 rect.origin.y + 0.0,
                                 rect.size.width - kInfoLabelLeftInset,
                                 rect.size.height);
    [super drawTextInRect:textRect];
}

@end
