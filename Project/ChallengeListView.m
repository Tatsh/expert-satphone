#import "ChallengeListView.h"

#import "ChallengeListViewCell.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The background, title, and close-button art.
static NSString *const kBackgroundImageName = @"scratch_list_bg";
static NSString *const kTitleImageName = @"scratch_list_title_lineup";
static NSString *const kPlateImage0Name = @"scratch_list_plate_slim_01";
static NSString *const kPlateImage1Name = @"scratch_list_plate_slim_02";
static NSString *const kPlatePickupImageName = @"scratch_list_plate_slim_03";
static NSString *const kCloseButtonImageName = @"scratch_btn_back";

// The reuse identifier for the list cells.
static NSString *const kCellReuseIdentifier = @"RivalListCell";

// The pickup slot's sentinel value meaning "no row picked up".
static const int kNoPickup = -1;

// The row height, per idiom.
static const int kCellHeightPad = 32;
static const int kCellHeightPhone = 20;

// The title's phone-only top inset (the pad title sits at the origin).
static const CGFloat kTitleYPhone = 4.0;

// The close button's inset from the background's top-left corner, per idiom.
static const CGFloat kCloseButtonXPad = 16.0;
static const CGFloat kCloseButtonXPhone = 8.0;
static const CGFloat kCloseButtonYPad = 28.0;
static const CGFloat kCloseButtonYPhone = 18.0;

// The table's frame, per idiom: its x origin (also the height trim off the background art), its
// width, and the base y offset the caller's listPosY is added to.
static const CGFloat kTableXPad = 12.0;
static const CGFloat kTableXPhone = 6.0;
static const CGFloat kTableWidthPad = 460.0;
static const CGFloat kTableWidthPhone = 309.0;
static const int kTableYBasePad = 4;
static const int kTableYBasePhone = 2;

// The half-scale factor used in the centring maths.
static const CGFloat kHalf = 0.5;

@implementation ChallengeListView {
    UIView *bgView;            // +0x8
    UIImageView *bgImageView;  // +0x10
    UIImageView *titleView;    // +0x18
    UIButton *closeBtn;        // +0x20
    UIImageView *listLineView; // +0x28
    UITableView *listView;     // +0x30
    NSArray *subListArray;     // +0x38
    NSArray *listArray;        // +0x40
    UIImage *plateBgImage0;    // +0x48
    UIImage *plateBgImage1;    // +0x50
    UIImage *plateBgPickup;    // +0x58
    int cellHeight;            // +0x60
    int listWidth;             // +0x64
    int pickupSlot;            // +0x68
}

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0x208b30 */
- (instancetype)initWithFrame:(CGRect)frame listPosY:(int)listPosY {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }
    BOOL isPad = [JubeatAppDelegate appDelegate].isPad;

    // The background plate, sized to its art and centred in the view.
    UIImage *bgImage = LoadScaledPngImage(kBackgroundImageName);
    bgView =
        [[UIView alloc] initWithFrame:CGRectMake(0, 0, bgImage.size.width, bgImage.size.height)];
    bgView.center = CGPointMake(frame.size.width * kHalf, frame.size.height * kHalf);
    [self addSubview:bgView];

    bgImageView = [[UIImageView alloc] initWithImage:bgImage];
    [bgView addSubview:bgImageView];

    // The title art: centred horizontally on the phone (with a small top inset), pinned to the
    // origin on the pad.
    UIImage *titleImage = LoadScaledPngImage(kTitleImageName);
    CGFloat titleX = 0.0;
    CGFloat titleY = 0.0;
    if (!isPad) {
        titleX = (CGFloat)(int)((bgView.frame.size.width - titleImage.size.width) * kHalf);
        titleY = kTitleYPhone;
    }
    titleView = [[UIImageView alloc] initWithImage:titleImage];
    titleView.frame = CGRectMake(titleX, titleY, titleImage.size.width, titleImage.size.height);
    [bgView addSubview:titleView];

    plateBgImage0 = LoadScaledPngImage(kPlateImage0Name);
    plateBgImage1 = LoadScaledPngImage(kPlateImage1Name);
    plateBgPickup = LoadScaledPngImage(kPlatePickupImageName);
    cellHeight = isPad ? kCellHeightPad : kCellHeightPhone;

    // The close button, inset from the background's top-left and vertically centred on its inset.
    UIImage *closeImage = LoadScaledPngImage(kCloseButtonImageName);
    closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    CGFloat closeX = isPad ? kCloseButtonXPad : kCloseButtonXPhone;
    CGFloat closeY =
        (isPad ? kCloseButtonYPad : kCloseButtonYPhone) - closeImage.size.height * kHalf;
    closeBtn.frame = CGRectMake(closeX, closeY, closeImage.size.width, closeImage.size.height);
    [closeBtn setBackgroundImage:closeImage forState:UIControlStateNormal];
    [closeBtn addTarget:self
                  action:@selector(tapCloseBtn:)
        forControlEvents:UIControlEventTouchUpInside];
    closeBtn.exclusiveTouch = YES;
    [bgView addSubview:closeBtn];

    // The table sits below the title (at the base y offset plus the caller's listPosY) and its
    // height fills to the close button's y, less the trim.
    CGFloat tableX = isPad ? kTableXPad : kTableXPhone;
    CGFloat tableWidth = isPad ? kTableWidthPad : kTableWidthPhone;
    int tableY = (isPad ? kTableYBasePad : kTableYBasePhone) + listPosY;
    int tableHeight = (int)(bgImageView.image.size.height - (CGFloat)tableY - tableX);
    listView = [[UITableView alloc]
        initWithFrame:CGRectMake(tableX, (CGFloat)tableY, tableWidth, (CGFloat)tableHeight)
                style:UITableViewStylePlain];
    listView.backgroundColor = UIColor.clearColor;
    listView.delegate = self;
    listView.dataSource = self;
    listView.rowHeight = (CGFloat)cellHeight;
    [bgView addSubview:listView];
    return self;
}

#pragma mark - Data

/** @ghidraAddress 0x209118 */
- (void)setTitleImage:(UIImage *)image animation:(BOOL)animation {
    [titleView setImage:image];
}

/** @ghidraAddress 0x209130 */
- (void)setSubListArray:(NSArray *)subListArray_ {
    subListArray = subListArray_;
}

/** @ghidraAddress 0x209144 */
- (void)setListArray:(NSArray *)listArray_ {
    listArray = listArray_;
    pickupSlot = kNoPickup;
    [listView reloadData];
}

/** @ghidraAddress 0x209268 */
- (void)pickUpCell:(int)slot {
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:slot inSection:0];
    pickupSlot = slot;
    [listView cellForRowAtIndexPath:indexPath];
}

#pragma mark - Actions

/** @ghidraAddress 0x2091b0 */
- (void)tapCloseBtn:(id)sender {
    if ([self.aDelegate respondsToSelector:@selector(tapClose:)]) {
        [self.aDelegate performSelector:@selector(tapClose:) withObject:sender];
    }
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0x2092f0 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"%@", kCellReuseIdentifier];
    ChallengeListViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        // A sub-list present selects the two-line (subtitle) cell style.
        cell = [[ChallengeListViewCell alloc]
              initWithStyle:(subListArray != nil) ? UITableViewCellStyleSubtitle :
                                                    UITableViewCellStyleDefault
            reuseIdentifier:identifier];
    }
    cell.tag = indexPath.row;
    (void)listArray[cell.tag]; // The main-list row is read for effect, as in the binary.
    if (subListArray && subListArray[cell.tag]) {
        cell.detailTextLabel.text = subListArray[cell.tag];
    }
    return cell;
}

/** @ghidraAddress 0x209664 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0x20966c */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return listArray.count;
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0x209508 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Odd rows use the second plate, even rows the first, and the picked-up row the pickup plate.
    UIImage *plate = (indexPath.row & 1) ? plateBgImage1 : plateBgImage0;
    if (indexPath.row == pickupSlot) {
        plate = plateBgPickup;
    }
    NSString *text = listArray[cell.tag];
    [(ChallengeListViewCell *)cell setBgImage:plate text:text];
}

/** @ghidraAddress 0x20964c */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return (CGFloat)cellHeight;
}

/** @ghidraAddress 0x209684 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [listView deselectRowAtIndexPath:indexPath animated:YES];
    if ([self.aDelegate respondsToSelector:@selector(selectListCell:)]) {
        [self.aDelegate performSelector:@selector(selectListCell:) withObject:indexPath];
    }
}

@end
