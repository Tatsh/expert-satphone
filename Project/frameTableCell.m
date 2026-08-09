#import "frameTableCell.h"

#import "ImageLoading.h"

// The four subviews, at offset globals 0x34aa40 through 0x34aa4c.
@interface frameTableCell () {
    UIImageView *lockIcon;
    UILabel *itemLabel;
    UILabel *pointLabel;
    UIImageView *icon;
}
@end

// Shared with both sibling classes, from the CFStrings at 0x2db3c0 and 0x2db3e0.
static NSString *const kReuseIdentifier = @"EditorInfoListViewTableCell";
static NSString *const kLockIconImageName = @"edit_icon_key";

// The user default naming the frame currently in use, from the CFString at 0x2d4480. The same key
// the launch handler validates and clears when the stored frame is no longer available.
static NSString *const kSelectedFramePreferenceKey = @"PrefTwitterBgFrame";

// The layout. The vertical positions are all shifted up relative to degreeTableCell, and the icon's
// is negative.
static const int kLockIconRightInset = 46;
static const int kItemLabelWidthInset = 20;
static const int kPointLabelLeftInset = 50;
static const CGFloat kLockIconTop = 8.0;
static const CGFloat kItemLabelLeft = 20.0;
static const CGFloat kItemLabelTop = 4.0;
static const CGFloat kItemLabelHeight = 30.0;
static const CGFloat kPointLabelTop = 12.0;
static const CGFloat kPointLabelWidth = 50.0;
static const CGFloat kPointLabelHeight = 20.0;
static const CGFloat kIconLeft = 10.0;
// An fmov whose imm8 is 0x80, which decodes to -2.0: the icon deliberately overhangs the cell's
// top edge. Decoded from the encoding rather than taken from the printed form.
static const CGFloat kIconTop = -2.0;
static const CGFloat kIconSize = 40.0;

static const CGFloat kLabelFontSize = 18.0;

// The positional indices -setInfo: reads. Element 0 is never read.
static const NSUInteger kInfoNameIndex = 1;
static const NSUInteger kInfoFrameIDIndex = 2;
static const NSUInteger kInfoCostIndex = 3;

// The lowest cost that counts as locked, compared with `cmp w0, #1` at 0xfde7c. The siblings test
// against zero instead.
static const int kMinimumLockedCost = 1;

static NSString *const kValueFormat = @"%@";

@implementation frameTableCell

/** @ghidraAddress 0xfda00 */
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

        // Built, configured and added — and then never used. -setInfo: writes the name into the
        // inherited textLabel instead, which this initialiser has just blanked.
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

        // Negative y, so it hangs above the cell's own top edge.
        icon = [[UIImageView alloc]
            initWithFrame:CGRectMake(kIconLeft, kIconTop, kIconSize, kIconSize)];
        [self addSubview:icon];
    }
    return self;
}

/** @ghidraAddress 0xfddf8 */
- (void)setInfo:(NSArray *)info {
    id frameID = [info objectAtIndex:kInfoFrameIDIndex];
    id cost = [info objectAtIndex:kInfoCostIndex];

    // -intValue against a lower bound of 1, where both siblings use -integerValue against zero.
    if ([cost intValue] >= kMinimumLockedCost) {
        pointLabel.text = [NSString stringWithFormat:kValueFormat, cost];
        lockIcon.alpha = 1.0;
    } else {
        pointLabel.text = @"";
        lockIcon.alpha = 0.0;
    }

    // Cleared first and set again only on a match, so exactly one row carries the tick.
    NSString *selectedFrameID =
        [NSUserDefaults.standardUserDefaults objectForKey:kSelectedFramePreferenceKey];
    self.accessoryType = UITableViewCellAccessoryNone;
    if ([frameID isEqualToString:selectedFrameID]) {
        self.accessoryType = UITableViewCellAccessoryCheckmark;
    }

    // The inherited label, not the itemLabel the initialiser built, and assigned rather than
    // formatted.
    self.textLabel.text = [info objectAtIndex:kInfoNameIndex];
}

@end
