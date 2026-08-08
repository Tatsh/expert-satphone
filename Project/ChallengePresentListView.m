#import "ChallengePresentListView.h"

#import "ChallengePresentListViewCell.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The background, title, and close-button art.
static NSString *const kBackgroundImageName = @"scratch_list_bg";
static NSString *const kTitleImageName = @"scratch_list_title_present";
static NSString *const kPlateImage0Name = @"scratch_list_plate_wide_01";
static NSString *const kPlateImage1Name = @"scratch_list_plate_wide_02";
static NSString *const kCloseButtonImageName = @"scratch_btn_back";

// The reuse identifier for the list cells.
static NSString *const kCellReuseIdentifier = @"RivalListCell";

// The per-present record key holding the row's descriptive text.
static NSString *const kPresentDescriptionKey = @"description";

// The row height, per idiom.
static const int kCellHeightPad = 96;
static const int kCellHeightPhone = 60;

// The title's phone-only top inset (the pad title sits at the origin).
static const CGFloat kTitleYPhone = 4.0;

// The close button's inset from the background's top-left corner, per idiom.
static const CGFloat kCloseButtonXPad = 16.0;
static const CGFloat kCloseButtonXPhone = 8.0;
static const CGFloat kCloseButtonYPad = 28.0;
static const CGFloat kCloseButtonYPhone = 19.0;

// The table's frame, per idiom: its origin, width, and the two amounts trimmed off the background
// image's height to give its height.
static const CGFloat kTableXPad = 12.0;
static const CGFloat kTableXPhone = 5.0;
static const CGFloat kTableYPad = 50.0;
static const CGFloat kTableYPhone = 25.0;
static const CGFloat kTableWidthPad = 460.0;
static const CGFloat kTableWidthPhone = 309.0;
static const CGFloat kTableHeightTrimPad = 12.0;
static const CGFloat kTableHeightTrimPhone = 6.0;

// The half-scale factor used in the centring maths.
static const CGFloat kHalf = 0.5;

@implementation ChallengePresentListView {
    UIView *bgView;           // +0x8
    UIImageView *bgImageView; // +0x10
    UIImageView *titleView;   // +0x18
    UILabel *titleLabel;      // +0x20
    UIButton *closeBtn;       // +0x28
    UITableView *listView;    // +0x30
    NSArray *listArray;       // +0x38
    UIImage *plateBgImage0;   // +0x40
    UIImage *plateBgImage1;   // +0x48
    int cellHeight;           // +0x50
    int listWidth;            // +0x54
}

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0x1fc548 */
- (instancetype)initWithFrame:(CGRect)frame {
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

    // The table fills the plate below the title, its height the background art's height less two
    // idiom-specific insets.
    CGFloat tableX = isPad ? kTableXPad : kTableXPhone;
    CGFloat tableY = isPad ? kTableYPad : kTableYPhone;
    CGFloat tableWidth = isPad ? kTableWidthPad : kTableWidthPhone;
    CGFloat tableHeightTrim = isPad ? kTableHeightTrimPad : kTableHeightTrimPhone;
    int tableHeight = (int)(bgImageView.image.size.height - tableY - tableHeightTrim);
    listView = [[UITableView alloc]
        initWithFrame:CGRectMake(tableX, tableY, tableWidth, (CGFloat)tableHeight)
                style:UITableViewStylePlain];
    listView.backgroundColor = UIColor.clearColor;
    listView.delegate = self;
    listView.dataSource = self;
    [bgView addSubview:listView];
    return self;
}

#pragma mark - Data

/** @ghidraAddress 0x1fcae4 */
- (void)setListArray:(NSArray *)listArray_ {
    listArray = listArray_;
    [listView reloadData];
}

#pragma mark - Actions

/** @ghidraAddress 0x1fcb40 */
- (void)tapCloseBtn:(id)sender {
    if ([self.aDelegate respondsToSelector:@selector(tapClose:)]) {
        [self.aDelegate performSelector:@selector(tapClose:) withObject:sender];
    }
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0x1fcbf8 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"%@", kCellReuseIdentifier];
    ChallengePresentListViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[ChallengePresentListViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:identifier];
    }
    cell.tag = indexPath.row;
    return cell;
}

/** @ghidraAddress 0x1fce24 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0x1fce2c */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return listArray.count;
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0x1fcd00 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Odd rows use the second plate image, even rows the first.
    UIImage *plate = (indexPath.row & 1) ? plateBgImage1 : plateBgImage0;
    NSString *text = listArray[cell.tag][kPresentDescriptionKey];
    [(ChallengePresentListViewCell *)cell setBgImage:plate text:text];
}

/** @ghidraAddress 0x1fce0c */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return (CGFloat)cellHeight;
}

/** @ghidraAddress 0x1fce44 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [listView deselectRowAtIndexPath:indexPath animated:YES];
    if ([self.aDelegate respondsToSelector:@selector(selectListCell:)]) {
        [self.aDelegate performSelector:@selector(selectListCell:) withObject:indexPath];
    }
}

@end
