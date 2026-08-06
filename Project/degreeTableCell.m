#import "degreeTableCell.h"

#import "ImageUtilities.h"

// The four subviews, at offset globals 0x34ac64 through 0x34ac70. The names match
// accessoryTableCell's, but these are this class's own ivars at its own offsets.
@interface degreeTableCell () {
    UIImageView *lockIcon;
    UILabel *itemLabel;
    UILabel *pointLabel;
    UIImageView *icon;
}
@end

// The same reuse identifier and lock artwork accessoryTableCell uses, from the CFStrings at
// 0x2db3c0 and 0x2db3e0. The identifier names neither class.
static NSString *const kReuseIdentifier = @"EditorInfoListViewTableCell";
static NSString *const kLockIconImageName = @"edit_icon_key";

// The layout. The item label differs from accessoryTableCell's: it starts at 20 rather than 70 and
// is correspondingly wider, because this list has no per-row artwork on the left.
static const int kLockIconRightInset = 46;
static const int kItemLabelWidthInset = 20;
static const int kPointLabelLeftInset = 50;
static const CGFloat kLockIconTop = 26.0;
static const CGFloat kItemLabelLeft = 20.0;
static const CGFloat kItemLabelTop = 4.0;
static const CGFloat kItemLabelHeight = 30.0;
static const CGFloat kPointLabelTop = 30.0;
static const CGFloat kPointLabelWidth = 50.0;
static const CGFloat kPointLabelHeight = 20.0;
static const CGFloat kIconLeft = 10.0;
static const CGFloat kIconTop = 7.0;
static const CGFloat kIconSize = 40.0;

static const CGFloat kLabelFontSize = 18.0;

// The positional indices -setInfo: reads. Element 0 is never read, and unlike the sibling classes
// element 2 is the format rather than a value.
static const NSUInteger kInfoNameArgumentIndex = 1;
static const NSUInteger kInfoNameFormatIndex = 2;
static const NSUInteger kInfoCostIndex = 3;

static NSString *const kValueFormat = @"%@";

@implementation degreeTableCell

/** @ghidraAddress 0x123770 */
- (instancetype)initWithWidth:(int)width {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kReuseIdentifier];
    if (self != nil) {
        self.accessoryType = UITableViewCellAccessoryNone;
        self.textLabel.text = @"";
        self.detailTextLabel.text = @"";
        self.imageView.image = nil;

        UIImage *lockImage = LoadScaledPngImage(kLockIconImageName);
        lockIcon = [[UIImageView alloc] initWithFrame:CGRectMake(width - kLockIconRightInset,
                                                                 kLockIconTop,
                                                                 lockImage.size.width,
                                                                 lockImage.size.height)];
        lockIcon.image = lockImage;
        lockIcon.alpha = 0.0;
        [self addSubview:lockIcon];

        itemLabel = [[UILabel alloc] initWithFrame:CGRectMake(kItemLabelLeft,
                                                              kItemLabelTop,
                                                              width - kItemLabelWidthInset,
                                                              kItemLabelHeight)];
        itemLabel.font = [UIFont systemFontOfSize:kLabelFontSize];
        [self addSubview:itemLabel];

        pointLabel = [[UILabel alloc] initWithFrame:CGRectMake(width - kPointLabelLeftInset,
                                                               kPointLabelTop,
                                                               kPointLabelWidth,
                                                               kPointLabelHeight)];
        pointLabel.textColor = UIColor.grayColor;
        pointLabel.font = [UIFont systemFontOfSize:kLabelFontSize];
        [self addSubview:pointLabel];

        // Built and added like the others, but nothing ever sets its image: -setInfo: does not
        // touch it. It stays an empty view for the life of the cell.
        icon = [[UIImageView alloc]
            initWithFrame:CGRectMake(kIconLeft, kIconTop, kIconSize, kIconSize)];
        [self addSubview:icon];
    }
    return self;
}

/** @ghidraAddress 0x123b74 */
- (void)setInfo:(NSArray *)info {
    // Element 2 is the format string and element 1 is its argument. Read from the stack setup
    // before the call — the decompile renders a variadic with only its first argument, which here
    // would have hidden that the format comes from the data rather than from a literal.
    itemLabel.text = [NSString stringWithFormat:[info objectAtIndex:kInfoNameFormatIndex],
                                                [info objectAtIndex:kInfoNameArgumentIndex]];

    if ([[info objectAtIndex:kInfoCostIndex] integerValue] != 0) {
        pointLabel.text =
            [NSString stringWithFormat:kValueFormat, [info objectAtIndex:kInfoCostIndex]];
        lockIcon.alpha = 1.0;
    } else {
        pointLabel.text = @"";
        lockIcon.alpha = 0.0;
    }
}

@end
