#import "ChallengePrevRankingListView.h"

#import "ChallengePrevRankingListViewCell.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "ScratchUtil.h"

// The background, title, and close-button art.
static NSString *const kBackgroundImageName = @"scratch_list_bg";
static NSString *const kTitleImageName = @"scratch_list_title_prevrank";
static NSString *const kPlateImage0Name = @"scratch_list_plate_01";
static NSString *const kPlateImage1Name = @"scratch_list_plate_02";
static NSString *const kCloseButtonImageName = @"scratch_btn_back";

// The reuse identifier for the list cells.
static NSString *const kCellReuseIdentifier = @"LineupCell";

// The per-record keys.
static NSString *const kRecordMusicIDKey = @"music_id";
static NSString *const kRecordNameKey = @"name";

// The dimmed-overlay background alpha (white 0).
static const CGFloat kOverlayAlpha = 0.4;

// The fade-in duration and its animation options.
static const NSTimeInterval kFadeInDuration = 0.2;
static const UIViewAnimationOptions kFadeInOptions =
    UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction;

// The title's phone-only top inset (the pad title sits at the origin).
static const CGFloat kTitleYPhone = 4.0;

// The close button's inset from the background's top-left corner, per idiom.
static const CGFloat kCloseButtonXPad = 16.0;
static const CGFloat kCloseButtonXPhone = 8.0;
static const CGFloat kCloseButtonYPad = 28.0;
static const CGFloat kCloseButtonYPhone = 18.0;

// The table's frame, per idiom: its x origin, y origin, width, and the amount trimmed off the
// close-button's y to give its height.
static const CGFloat kTableXPad = 12.0;
static const CGFloat kTableXPhone = 5.0;
static const CGFloat kTableYPad = 50.0;
static const CGFloat kTableYPhone = 30.0;
static const CGFloat kTableWidthPad = 460.0;
static const CGFloat kTableWidthPhone = 309.0;
static const CGFloat kTableHeightTrimPad = 12.0;
static const CGFloat kTableHeightTrimPhone = 6.0;

// The half-scale factor used in the centring maths.
static const CGFloat kHalf = 0.5;

@implementation ChallengePrevRankingListView {
    UIView *bgView;            // +0x8
    UIImageView *bgImageView;  // +0x10
    UIImageView *titleView;    // +0x18
    UIImageView *listLineView; // +0x20
    UITableView *listView;     // +0x28
    int cellHeight;            // +0x30
    UIButton *closeBtn;        // +0x38
    UIImage *plateBgImage0;    // +0x40
    UIImage *plateBgImage1;    // +0x48
    NSArray *listArray;        // +0x50
}

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0x72ee8 */
- (instancetype)initWithFrame:(CGRect)frame lineup:(NSArray *)lineup {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }
    BOOL isPad = [JubeatAppDelegate appDelegate].isPad;
    self.opaque = NO;
    self.layer.doubleSided = NO;
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:kOverlayAlpha];
    listArray = lineup;

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
    cellHeight = (int)plateBgImage0.size.height;

    // The close button, inset from the background's top-left and vertically centred on its inset.
    UIImage *closeImage = LoadScaledPngImage(kCloseButtonImageName);
    closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    CGFloat closeX = isPad ? kCloseButtonXPad : kCloseButtonXPhone;
    CGFloat closeBaseY = isPad ? kCloseButtonYPad : kCloseButtonYPhone;
    CGFloat closeY = closeBaseY - closeImage.size.height * kHalf;
    closeBtn.frame = CGRectMake(closeX, closeY, closeImage.size.width, closeImage.size.height);
    [closeBtn setBackgroundImage:closeImage forState:UIControlStateNormal];
    [closeBtn addTarget:self
                  action:@selector(closeLineup:)
        forControlEvents:UIControlEventTouchUpInside];
    closeBtn.exclusiveTouch = YES;
    [bgView addSubview:closeBtn];

    // The table sits below the title; its height fills to the close button's y less the trim.
    CGFloat tableX = isPad ? kTableXPad : kTableXPhone;
    CGFloat tableY = isPad ? kTableYPad : kTableYPhone;
    CGFloat tableWidth = isPad ? kTableWidthPad : kTableWidthPhone;
    CGFloat tableHeightTrim = isPad ? kTableHeightTrimPad : kTableHeightTrimPhone;
    int tableHeight =
        (int)((closeBaseY - closeImage.size.height * kHalf) - tableY - tableHeightTrim);
    listView = [[UITableView alloc]
        initWithFrame:CGRectMake(tableX, tableY, tableWidth, (CGFloat)tableHeight)
                style:UITableViewStylePlain];
    listView.delegate = self;
    listView.dataSource = self;
    listView.backgroundColor = UIColor.clearColor;
    [bgView addSubview:listView];

    self.alpha = 0;
    return self;
}

#pragma mark - Presentation

/** @ghidraAddress 0x73570 */
- (void)refreshList {
    [listView reloadData];
}

/** @ghidraAddress 0x73588 */
- (void)closeLineup:(id)sender {
    if ([self.aDelegate respondsToSelector:@selector(closeLineupView)]) {
        [self.aDelegate performSelector:@selector(closeLineupView)];
    }
}

/** @ghidraAddress 0x73638 */
- (void)showLineup {
    __weak ChallengePrevRankingListView *weakSelf = self;
    [UIView animateWithDuration:kFadeInDuration
                          delay:0
                        options:kFadeInOptions
                     animations:^{
                       /** @ghidraAddress 0x73708 */
                       weakSelf.alpha = 1.0;
                     }
                     completion:^(BOOL __attribute__((unused)) finished){
                         /** @ghidraAddress 0x73754 */
                     }];
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0x73758 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"%@", kCellReuseIdentifier];
    ChallengePrevRankingListViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[ChallengePrevRankingListViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:identifier];
    }
    cell.tag = indexPath.row;
    return cell;
}

/** @ghidraAddress 0x73ae4 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0x73aec */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (listArray != nil) {
        return listArray.count;
    }
    return 0;
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0x73860 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Odd rows use the second plate, even rows the first; the row shows the tune's artwork and
    // name.
    UIImage *plate = (indexPath.row & 1) ? plateBgImage1 : plateBgImage0;
    NSDictionary *record = listArray[cell.tag];
    NSString *artworkPath =
        [ScratchUtil imagePathForMusicID:(unsigned int)[record[kRecordMusicIDKey] intValue]];
    UIImage *artwork = [UIImage imageWithContentsOfFile:artworkPath];
    [(ChallengePrevRankingListViewCell *)cell setLineupCell:artwork
                                                       name:record[kRecordNameKey]
                                                      bgImg:plate];
}

/** @ghidraAddress 0x73acc */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return (CGFloat)cellHeight;
}

/** @ghidraAddress 0x73a14 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.aDelegate respondsToSelector:@selector(selectListCell:)]) {
        [self.aDelegate performSelector:@selector(selectListCell:) withObject:indexPath];
    }
}

@end
