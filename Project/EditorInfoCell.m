#import "EditorInfoCell.h"

#import "ImageUtilities.h"

// Shared with the three lower-case cell classes, from the CFStrings at 0x2db3c0 and 0x2db3e0.
static NSString *const kReuseIdentifier = @"EditorInfoListViewTableCell";
static NSString *const kLockIconImageName = @"edit_icon_key";

// The badge artwork, from the three-entry table at 0x2d1480. Their order is the tag's own
// numbering.
static NSString *const kUserBadgeImageNames[] = {
    @"list_icon_user_blank",
    @"list_icon_user_staff",
    @"list_icon_user_artist",
};

// The highest tag the table covers, compared with `cmp w19, #2` at 0x1f8c5c.
static const int kMaximumUserTag = 2;

// How far left of the cell's right edge the lock sits, beyond the overlay's own width. An fmov
// whose imm8 is 0xBA, decoding to -26.0; the printed form is "-0x3fc6000000000000", which is
// neither the value nor its bit pattern.
static const CGFloat kLockViewRightMargin = 26.0;

// The lock's vertical position, an fmov of 0x401c000000000000.
static const CGFloat kLockViewTop = 7.0;

@implementation EditorInfoCell

/** @ghidraAddress 0x1f89f0 */
- (instancetype)init {
    // Style 1 is the value style, so the cell keeps its inherited text and detail labels.
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kReuseIdentifier];
    if (self != nil) {
        // Placed from the cell's own frame rather than a passed-in width, unlike the three
        // lower-case cell classes. -frame is read once, so the cell must already be its final size.
        UIImage *lockImage = LoadScaledPngImage(kLockIconImageName);
        CGFloat lockLeft = self.frame.size.width - lockImage.size.width - kLockViewRightMargin;
        self.lockView = [[UIImageView alloc]
            initWithFrame:CGRectMake(
                              lockLeft, kLockViewTop, lockImage.size.width, lockImage.size.height)];
        self.lockView.image = lockImage;
        // Added to the cell itself rather than to its contentView.
        [self addSubview:self.lockView];

        // Starts on the blank badge; -setUserTag: replaces it.
        self.imageView.image = LoadScaledPngImage(kUserBadgeImageNames[0]);
    }
    return self;
}

/** @ghidraAddress 0x1f8bec */
- (void)setUserTag:(int)userTag {
    // Cleared first, then set again from a second -imageView send rather than reusing the first.
    self.imageView.image = nil;

    // The guard is one-sided: only tags above the table's last index fall back to the blank badge.
    // A negative tag is sign-extended and indexes off the front of the table. Reproduced as
    // compiled; every caller reached so far passes 0, 1, or 2.
    NSInteger index = (userTag > kMaximumUserTag) ? 0 : userTag;
    self.imageView.image = LoadScaledPngImage(kUserBadgeImageNames[index]);
}

@end
