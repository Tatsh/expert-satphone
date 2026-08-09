#import "ChallengeLineupView.h"

#import "AlertViewManager.h"
#import "AudioManager.h"
#import "ChallengeLineupViewCell.h"
#import "ChallengeStatus.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "StoreMusicListManager.h"
// The background, title, and close-button art.
static NSString *const kBackgroundImageName = @"scratch_list_bg";
static NSString *const kTitleImageName = @"scratch_list_title_lineup";
static NSString *const kPlateImage0Name = @"scratch_list_plate_01";
static NSString *const kPlateImage1Name = @"scratch_list_plate_02";
static NSString *const kCloseButtonImageName = @"scratch_btn_cancel";

// The reuse identifier for the list cells.
static NSString *const kCellReuseIdentifier = @"LineupCell";

// The sound played when the close button is tapped.
static NSString *const kCloseSoundName = @"SD_CHALLENGE_CANCEL";

// The per-record keys.
static NSString *const kRecordMusicIDKey = @"music_id";
static NSString *const kRecordPackIDKey = @"pack_id";
static NSString *const kRecordNameKey = @"name";

// The store alerts' messages, shown on the phone when a row is tapped.
static NSString *const kStoreShowMessage = @"この曲を含んだパックをjubeat storeで表示します";
static NSString *const kAlreadyOwnedMessage = @"この曲は既に所持しています";
static NSString *const kNoPackMessage = @"この曲を含んだパックは存在しません";

// The localised-string keys for the alert buttons.
static NSString *const kOKKey = @"OK";
static NSString *const kYesKey = @"YES";
static NSString *const kNoKey = @"NO";

// The store type passed to the cell when a row has no pack: outside the cell's two named values,
// this hides the store button.
static const int kStoreTypeNoPack = 2;

// The row count used before the line-up has loaded.
static const NSInteger kDefaultRowCount = 16;

// The alert tag shared by every store alert this view raises.
static const int kStoreAlertTag = 0;

// The tapped-button index that means "confirmed".
static const int kConfirmButtonIndex = 1;

// The alert-info key carrying the tapped button's index.
static NSString *const kAlertInfoButtonMessageKey = @"btnMessage";

// The fade duration and its animation options, shared by the show and close paths.
static const NSTimeInterval kFadeDuration = 0.2;
static const UIViewAnimationOptions kFadeOptions =
    UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction;

// The title's phone-only top inset (the pad title sits at the origin).
static const CGFloat kTitleYPhone = 4.0;

// The close button's inset from the background's top-left corner, per idiom.
static const CGFloat kCloseButtonXPad = 16.0;
static const CGFloat kCloseButtonXPhone = 8.0;
static const CGFloat kCloseButtonYPad = 28.0;
static const CGFloat kCloseButtonYPhone = 18.0;

// The table's frame, per idiom: its origin, width, and the amount trimmed off the background
// image's height (together with the table's y) to give its height.
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

@interface ChallengeLineupView () <AlertViewManagerDelegate, ChallengeLineupViewCellDelegate>
@end

@implementation ChallengeLineupView {
    NSInteger selectPackID;    // +0x8
    UIView *bgView;            // +0x10
    UIImageView *bgImageView;  // +0x18
    UIImageView *titleView;    // +0x20
    UIImageView *listLineView; // +0x28 (declared in the metadata; never assigned)
    UITableView *listView;     // +0x30
    int cellHeight;            // +0x38
    UIButton *closeBtn;        // +0x40
    UIImage *plateBgImage0;    // +0x48
    UIImage *plateBgImage1;    // +0x50
}

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0x146128 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }
    BOOL isPad = [JubeatAppDelegate appDelegate].isPad;
    self.opaque = NO;
    self.layer.doubleSided = NO;

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

    // The table sits below the title; its height fills to the background art's height less the
    // table's y and an idiom-specific trim.
    CGFloat tableX = isPad ? kTableXPad : kTableXPhone;
    CGFloat tableY = isPad ? kTableYPad : kTableYPhone;
    CGFloat tableWidth = isPad ? kTableWidthPad : kTableWidthPhone;
    CGFloat tableHeightTrim = isPad ? kTableHeightTrimPad : kTableHeightTrimPhone;
    int tableHeight = (int)(bgImageView.image.size.height - tableY - tableHeightTrim);
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

/** @ghidraAddress 0x146720 */
- (void)refreshList {
    [listView reloadData];
}

/** @ghidraAddress 0x146738 */
- (void)closeLineup:(id)sender {
    [[AudioManager sharedManager] playSeResFile:kCloseSoundName inDirectory:nil];
    __weak ChallengeLineupView *weakSelf = self;
    // The panel itself is faded out (held weakly), then the delegate is told once the fade is
    // done (held strongly, so an interrupted close still notifies).
    [UIView animateWithDuration:kFadeDuration
        delay:0
        options:kFadeOptions
        animations:^{
          /** @ghidraAddress 0x14689c */
          weakSelf.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1468e8 */
          [self.aDelegate closeLineupView];
        }];
}

/** @ghidraAddress 0x14693c */
- (void)showLineup {
    __weak ChallengeLineupView *weakSelf = self;
    [UIView animateWithDuration:kFadeDuration
                          delay:0
                        options:kFadeOptions
                     animations:^{
                       /** @ghidraAddress 0x146a0c */
                       weakSelf.alpha = 1.0;
                     }
                     completion:nil];
}

#pragma mark - Actions

/** @ghidraAddress 0x147428 */
- (void)tapStoreBtn:(ChallengeLineupViewCell *)cell {
    NSArray *lineup = [ChallengeStatus sharedStatus].scratchLineUp;
    NSDictionary *record = lineup[cell.tag];
    selectPackID = [record[kRecordPackIDKey] longValue];
    [self.aDelegate openJubeatStore:[record[kRecordPackIDKey] longValue]];
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0x146a5c */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"%@", kCellReuseIdentifier];
    ChallengeLineupViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[ChallengeLineupViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                              reuseIdentifier:identifier];
        cell.aDelegate = self;
    }
    cell.tag = indexPath.row;
    return cell;
}

/** @ghidraAddress 0x146e2c */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0x146e34 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *lineup = [ChallengeStatus sharedStatus].scratchLineUp;
    if (lineup == nil) {
        return kDefaultRowCount; // Placeholder count until the line-up loads, as in the binary.
    }
    return lineup.count;
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0x146b84 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Odd rows use the second plate, even rows the first.
    UIImage *plate = (indexPath.row & 1) ? plateBgImage1 : plateBgImage0;
    NSDictionary *record = [ChallengeStatus sharedStatus].scratchLineUp[indexPath.row];
    UIImage *artwork = [[ChallengeStatus sharedStatus] getLineupImage:record[kRecordMusicIDKey]];

    // No pack hides the store button; otherwise it is disabled when the tune is already owned.
    int storeType;
    if (record[kRecordPackIDKey] == nil) {
        storeType = kStoreTypeNoPack;
    } else {
        BOOL owned =
            [[StoreMusicListManager sharedManager] hasMusic:[record[kRecordMusicIDKey] intValue]];
        storeType = owned ? ChallengeLineupStoreTypeOwned : ChallengeLineupStoreTypeAvailable;
    }
    [(ChallengeLineupViewCell *)cell setLineupCell:artwork
                                              name:record[kRecordNameKey]
                                             bgImg:plate
                                         storeType:storeType];
}

/** @ghidraAddress 0x146e14 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return (CGFloat)cellHeight;
}

/** @ghidraAddress 0x146f04 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // The pad drives the store from the cell's own button, so only the phone acts on a row tap.
    if ([JubeatAppDelegate appDelegate].isPad) {
        return;
    }
    NSDictionary *record = [ChallengeStatus sharedStatus].scratchLineUp[indexPath.row];
    NSInteger packID = [record[kRecordPackIDKey] longValue];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
    if (record[kRecordPackIDKey] == nil) {
        NSString *msg = [NSString stringWithFormat:@"%@", kNoPackMessage];
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:self
                                                tag:kStoreAlertTag
                                              title:@""
                                                msg:msg
                                             cancel:ok
                                            btnText:nil
                                               show:YES];
        return;
    }
    if ([[StoreMusicListManager sharedManager] hasMusic:[record[kRecordMusicIDKey] intValue]]) {
        NSString *msg = [NSString stringWithFormat:@"%@", kAlreadyOwnedMessage];
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:self
                                                tag:kStoreAlertTag
                                              title:@""
                                                msg:msg
                                             cancel:ok
                                            btnText:nil
                                               show:YES];
        return;
    }
    // The tune is purchasable: remember the pack and confirm the store jump.
    selectPackID = packID;
    NSString *msg = [NSString stringWithFormat:@"%@", kStoreShowMessage];
    NSString *no = [NSBundle.mainBundle localizedStringForKey:kNoKey value:@"" table:nil];
    NSString *yes = [NSBundle.mainBundle localizedStringForKey:kYesKey value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:self
                                            tag:kStoreAlertTag
                                          title:@""
                                            msg:msg
                                         cancel:no
                                        btnText:@[ yes ]
                                           show:YES];
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0x1475a8 */
- (void)alertSelect:(NSDictionary *)info {
    if ([info[kAlertInfoButtonMessageKey] intValue] == kConfirmButtonIndex) {
        [self.aDelegate openJubeatStore:selectPackID];
    }
}

@end
