#import "MissionAchieveDownloadPageView.h"

#import "AlertViewManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The two downloader ivars are only ever held, never messaged here, so a forward declaration of
// each is enough to type them.
@class SessionDownloader;
@class Downloader;

// The background, title, plate, and close-button art. This is the wide-plate variant of the
// scratch list idiom.
static NSString *const kBackgroundImageName = @"scratch_list_bg";
static NSString *const kTitleImageName = @"scratch_list_title_present";
static NSString *const kPlateImage0Name = @"scratch_list_plate_wide_01";
static NSString *const kPlateImage1Name = @"scratch_list_plate_wide_02";
static NSString *const kCloseButtonImageName = @"scratch_btn_back";

// The reuse identifier for the list cells.
static NSString *const kCellReuseIdentifier = @"AchieveListCell";

// The per-record keys of a mission entry.
static NSString *const kRecordTitleKey = @"title";
static NSString *const kRecordItemKey = @"item";
static NSString *const kRecordClearKey = @"clear";

// The download-confirmation and refusal alert strings, and their buttons.
static NSString *const kConfirmDownloadMessage = @"ダウンロードすんの？";
static NSString *const kCannotDownloadMessage = @"ダウンロードできないよ";
static NSString *const kConfirmCancelTitle = @"NO";
static NSString *const kConfirmOtherTitle = @"YES";
static NSString *const kRefuseCancelTitle = @"YES";

// The alert type: a plain notice with no text field.
static const int kAlertTypePlain = 0;
// No tag is echoed back; these alerts have no delegate.
static const int kAlertNoTag = 0;

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

// The table's frame, per idiom: its x origin, y origin, width, and the amount trimmed off the
// plate's own height to give the table height.
static const CGFloat kTableXPad = 12.0;
static const CGFloat kTableXPhone = 5.0;
static const CGFloat kTableYPad = 50.0; // @ghidraAddress 0x28f2c8
static const CGFloat kTableYPhone = 25.0;
static const CGFloat kTableWidthPad = 460.0;   // @ghidraAddress 0x28f4f0
static const CGFloat kTableWidthPhone = 309.0; // @ghidraAddress 0x28f8e8
static const CGFloat kTableHeightTrimPad = 12.0;
static const CGFloat kTableHeightTrimPhone = 6.0;

// The half-scale factor used in the centring maths.
static const CGFloat kHalf = 0.5;

@implementation MissionAchieveDownloadPageView {
    UIView *bgView;                // +0x8
    UIImageView *bgImageView;      // +0x10
    UIImageView *titleView;        // +0x18
    UILabel *titleLabel;           // +0x20
    UIButton *closeBtn;            // +0x28
    UIImage *plateBgImage0;        // +0x30
    UIImage *plateBgImage1;        // +0x38
    int cellHeight;                // +0x40
    UITableView *listView;         // +0x48
    NSArray *missionList;          // +0x50
    SessionDownloader *downloader; // +0x58
    Downloader *itemDownloader;    // +0x60
    int selectedIndex;             // +0x68
}

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0x1ed354 */
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
                  action:@selector(tapClose:)
        forControlEvents:UIControlEventTouchUpInside];
    closeBtn.exclusiveTouch = YES;
    [bgView addSubview:closeBtn];

    missionList = nil;

    // The table sits below the title; its height fills the plate less the trim.
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

    // Load the initial list; the downloader argument is unused.
    [self downloaderFinished:nil];
    return self;
}

#pragma mark - Actions

/** @ghidraAddress 0x1ed918 */
- (void)tapClose:(id)sender {
    [self.aDelegate closeMenu];
}

/** @ghidraAddress 0x1ed958 */
- (void)closeSettingMenu:(id)sender {
    [self.aDelegate closeMenu];
}

/** @ghidraAddress 0x1edd74 */
- (void)tapDownloadBtn:(id)cell {
    NSInteger row = [cell tag];
    BOOL clear = [missionList[row][kRecordClearKey] boolValue];
    AlertViewManager *alertManager = [AlertViewManager sharedManager];
    if (!clear) {
        [alertManager makeAlert:kAlertTypePlain
                       delegate:nil
                            tag:kAlertNoTag
                          title:nil
                            msg:kCannotDownloadMessage
                         cancel:kRefuseCancelTitle
                        btnText:nil
                           show:YES];
    } else {
        [alertManager makeAlert:kAlertTypePlain
                       delegate:nil
                            tag:kAlertNoTag
                          title:nil
                            msg:kConfirmDownloadMessage
                         cancel:kConfirmCancelTitle
                        btnText:@[ kConfirmOtherTitle ]
                           show:YES];
    }
}

#pragma mark - Downloader

/** @ghidraAddress 0x1ed998 */
- (void)downloaderFinished:(SessionDownloader *)downloader_ {
    // The list is fixed placeholder data: six bonus sheets, each carrying its title, its item
    // name, and whether it may be downloaded.
    missionList = @[
        @{kRecordTitleKey : @"シート1", kRecordItemKey : @"特典", kRecordClearKey : @YES},
        @{kRecordTitleKey : @"シート2", kRecordItemKey : @"特典", kRecordClearKey : @YES},
        @{kRecordTitleKey : @"シート3", kRecordItemKey : @"特典", kRecordClearKey : @NO},
        @{kRecordTitleKey : @"シート4", kRecordItemKey : @"特典", kRecordClearKey : @YES},
        @{kRecordTitleKey : @"シート5", kRecordItemKey : @"特典", kRecordClearKey : @NO},
        @{kRecordTitleKey : @"シート6", kRecordItemKey : @"特典", kRecordClearKey : @NO},
    ];
    [listView reloadData];
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0x1edf2c */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"%@", kCellReuseIdentifier];
    MissionAchieveDownloadPageViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[MissionAchieveDownloadPageViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                         reuseIdentifier:identifier];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.tag = indexPath.row;
    return cell;
}

/** @ghidraAddress 0x1ee1c0 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0x1ee1c8 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (missionList != nil) {
        return missionList.count;
    }
    return 0;
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0x1ee05c */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Odd rows use the second plate, even rows the first.
    UIImage *plate = (indexPath.row & 1) ? plateBgImage1 : plateBgImage0;
    NSDictionary *record = missionList[cell.tag];
    BOOL btnEnable = [record[kRecordClearKey] boolValue];
    NSString *text = record[kRecordTitleKey];
    [(MissionAchieveDownloadPageViewCell *)cell setBgImage:plate text:text btnEnable:btnEnable];
}

/** @ghidraAddress 0x1ee1a8 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return (CGFloat)cellHeight;
}

/** @ghidraAddress 0x1ee1e8 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Yes, this is empty in the binary; row selection does nothing.
}

@end
