#import "StoreDetailCopyrightCell.h"

// The label's frame. The origin is an fmov of 0x4014000000000000 reused for both coordinates, and
// the width is the pooled double at 0x28f410. The height is a zeroed vector register, so the label
// is laid out at zero height and relies on being sized later.
static const CGFloat kCopyrightLabelInset = 5.0;
static const CGFloat kCopyrightLabelWidth = 310.0;

// The text grey, the pooled double at 0x28f248. Its bit pattern is 0x3FD3333340000000, which is
// 0.3f widened to double rather than the closest double to 0.3, so it is spelled 0.3f here.
static const CGFloat kCopyrightTextWhite = 0.3f;

@implementation StoreDetailCopyrightCell

/** @ghidraAddress 0xfd83c */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _labelCopyright = [[UILabel alloc] initWithFrame:CGRectMake(kCopyrightLabelInset,
                                                                    kCopyrightLabelInset,
                                                                    kCopyrightLabelWidth,
                                                                    0.0)];
        _labelCopyright.backgroundColor = UIColor.clearColor;
        _labelCopyright.textColor = [UIColor colorWithWhite:kCopyrightTextWhite alpha:1.0];
        // Zero means wrap to as many lines as the text needs.
        _labelCopyright.numberOfLines = 0;
        _labelCopyright.lineBreakMode = NSLineBreakByWordWrapping;
        [self.contentView addSubview:_labelCopyright];
    }
    return self;
}

@end
