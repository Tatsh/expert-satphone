#import "StoreManageTableViewCell.h"

// The two button font sizes, chosen by an fcsel rather than a branch. Both are fmov immediates:
// 0x4030000000000000 and 0x402C000000000000.
static const CGFloat kButtonFontSizePad = 16.0;
static const CGFloat kButtonFontSizePhone = 14.0;

// The autoresizing mask, the bare immediate 0x29 at 0x90b08. It pins the button to the right edge
// and vertically centres it: left margin, top margin, and bottom margin all flexible, with the
// width and height fixed.
static const UIViewAutoresizing kButtonAutoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                                          UIViewAutoresizingFlexibleTopMargin |
                                                          UIViewAutoresizingFlexibleBottomMargin;

@implementation StoreManageTableViewCell

/** @ghidraAddress 0x9096c */
- (instancetype)initWithPad:(BOOL)isPad reuseIdentifier:(NSString *)reuseIdentifier {
    // Style 3, the subtitle style, is a bare immediate rather than a parameter.
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    if (self != nil) {
        // Type 1. On the SDK this was built against that is UIButtonTypeRoundedRect, which later
        // became UIButtonTypeSystem under the same value.
        self.btn = [UIButton buttonWithType:UIButtonTypeSystem];
        // The size is selected with an fcsel, so both fonts are computed and one is discarded.
        self.btn.titleLabel.font =
            [UIFont boldSystemFontOfSize:(isPad ? kButtonFontSizePad : kButtonFontSizePhone)];
        [self.btn setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        self.btn.autoresizingMask = kButtonAutoresizingMask;
        self.btn.exclusiveTouch = YES;
#ifdef ENABLE_PATCHES
        // Preservation patch, not in the binary: the button goes in the contentView, because a
        // sibling added straight to the cell (0x90b68) is drawn but not hit-tested on modern iOS.
        [self.contentView addSubview:self.btn];
#else
        // Added to the cell itself rather than to its contentView, which is not what a table cell
        // is normally built to do. Reproduced as compiled.
        [self addSubview:self.btn];
#endif
    }
    return self;
}

@end
