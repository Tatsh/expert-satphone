#import "accessoryTableCell.h"

#import "ImageLoading.h"
#import "ResultTweet.h"

// The four subviews, at offset globals 0x34a868 through 0x34a874. None has an accessor pair, so
// none is a property.
@interface accessoryTableCell () {
    UIImageView *lockIcon;
    UILabel *itemLabel;
    UILabel *pointLabel;
    UIImageView *icon;
}
@end

// The reuse identifier, from the CFString at 0x2db3c0. It names a different class than this one,
// which is the binary's own inconsistency.
static NSString *const kReuseIdentifier = @"EditorInfoListViewTableCell";

// The lock overlay's artwork, from the CFString at 0x2db3e0. Loaded through LoadScaledPngImage, so
// the name carries no extension.
static NSString *const kLockIconImageName = @"edit_icon_key";

// The layout. Every one of these is either a bare immediate subtracted from the width or a pooled
// double; none is computed from the content.
static const int kLockIconRightInset = 46;
static const int kItemLabelWidthInset = 70;
static const int kPointLabelLeftInset = 50;
static const CGFloat kLockIconTop = 26.0;
static const CGFloat kItemLabelLeft = 70.0;
static const CGFloat kItemLabelTop = 10.0;
static const CGFloat kItemLabelHeight = 30.0;
static const CGFloat kPointLabelTop = 30.0;
static const CGFloat kPointLabelWidth = 50.0;
static const CGFloat kPointLabelHeight = 20.0;
static const CGFloat kIconOrigin = 10.0;
static const CGFloat kIconSize = 40.0;

// The label font size, an fmov of 0x4032000000000000 used for both labels.
static const CGFloat kLabelFontSize = 18.0;

// The positional indices -setInfo: reads out of its array. Element 0 is never read.
static const NSUInteger kInfoNameIndex = 1;
static const NSUInteger kInfoIconNameIndex = 2;
static const NSUInteger kInfoCostIndex = 3;

// The format both label texts and the icon's file name are built with.
static NSString *const kValueFormat = @"%@";
static NSString *const kIconFileNameFormat = @"%@.png";

@implementation accessoryTableCell

/** @ghidraAddress 0xe2dac */
- (instancetype)initWithWidth:(int)width {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kReuseIdentifier];
    if (self != nil) {
        // The inherited cell furniture is explicitly emptied rather than left alone, because this
        // class draws everything itself out of its own four subviews.
        self.accessoryType = UITableViewCellAccessoryNone;
        self.textLabel.text = @"";
        self.detailTextLabel.text = @"";
        self.imageView.image = nil;

        // Sized from the artwork rather than to a fixed rectangle, so the overlay matches the image
        // exactly.
        UIImage *lockImage = LoadScaledPngImage(kLockIconImageName);
        lockIcon = [[UIImageView alloc] initWithFrame:CGRectMake(width - kLockIconRightInset,
                                                                 kLockIconTop,
                                                                 lockImage.size.width,
                                                                 lockImage.size.height)];
        lockIcon.image = lockImage;
        // Hidden by transparency rather than by -setHidden:, which is what -setInfo: toggles.
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

        // Square, and the only subview whose position does not depend on the width.
        icon = [[UIImageView alloc]
            initWithFrame:CGRectMake(kIconOrigin, kIconOrigin, kIconSize, kIconSize)];
        [self addSubview:icon];
    }
    return self;
}

/** @ghidraAddress 0xe31b4 */
- (void)setInfo:(NSArray *)info {
    // The icon is loaded from the tweet-decoration directory rather than the bundle, so these share
    // their artwork with the score-sharing images.
    NSString *fileName =
        [NSString stringWithFormat:kIconFileNameFormat, [info objectAtIndex:kInfoIconNameIndex]];
    icon.image = [UIImage imageWithContentsOfFile:[ResultTweet getTwitterImagePath:fileName]];

    // Formatted rather than assigned, so a non-string element still renders.
    itemLabel.text = [NSString stringWithFormat:kValueFormat, [info objectAtIndex:kInfoNameIndex]];

    // A zero cost means the accessory is already owned: the cost is blanked and the lock is hidden.
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
