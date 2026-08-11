#import "ChallengeMenuView.h"

#import "AlertViewManager.h"
#import "ChallengeMenuViewCell.h"
#import "ChallengeStatus.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "PurchaseManager.h"
#import "StoreDialogView.h"
// The background plate, close-button, and first-row artwork.
static NSString *const kBackgroundImageName = @"challenge_menu_bg";
static NSString *const kCloseButtonImageName = @"scratch_btn_cancel";
static NSString *const kRowHeightImageName = @"challenge_menu_btn_01";

// The per-digit badge artwork, indexed 0 to 9, and the per-row button artwork.
static NSString *const kDigitImageFormat = @"challenge_pre_num_%d";
static NSString *const kRowImageFormat = @"challenge_menu_btn_%02d";

// The reuse identifier for the menu rows, verbatim from the binary (shared with the rival list).
static NSString *const kCellReuseIdentifier = @"RivalListCell";

// The localised-string keys for the alert titles and buttons.
static NSString *const kCancelKey = @"Cancel";
static NSString *const kOKKey = @"OK";
static NSString *const kRestoreCompleteKey = @"RestoreCompleteTitle";
static NSString *const kNetworkErrorKey = @"NetworkErrorMsg";

// The messages shown by the store row's confirmation alerts.
static NSString *const kLinkPurchaseMessage =
    @"他端末で購入したパック情報をユーザーに紐付けますか？";
static NSString *const kPurchaseCompleteMessage =
    @"購入処理が完了しました。つづけて他端末で購入したパック情報をユーザーに紐付けますか？";

// The progress-dialog status lines.
static NSString *const kVerifyProcessingMessage = @"処理中...";
static NSString *const kVerifyRestoringMessage = @"復元中...";

enum {
    // The fixed row count and the store row's tag.
    kMenuRowCount = 7,
    kStoreRowTag = 6,
    // The digit-artwork cache holds ten glyphs.
    kDigitImageCount = 10,
    // The badge never shows more than three digits.
    kMaxBadgeNumber = 999,
    kTwoDigitFloor = 10,
    kThreeDigitFloor = 100,
    // A single digit sits in the middle of the three-wide row.
    kThreeDigitCentreSlot = 1,
    // Alert tags echoed back through -alertSelect:.
    kLinkPurchaseAlertTag = 1,
    kRestoreCompleteAlertTag = 2,
    // The alert-button index that confirms the link-purchases prompt.
    kConfirmButtonIndex = 1,
    // The purchase-failure code that shows the network-error alert.
    kNetworkErrorCode = 1,
};

// Half, used to centre the plate, the table, and the dialog.
static const CGFloat kHalf = 0.5;

// The close button: a per-idiom top-left inset, plus padding baked into its tappable frame.
static const CGFloat kCloseButtonXPhone = 10.0;
static const CGFloat kCloseButtonXPad = 19.0;
static const CGFloat kCloseButtonYPhone = 19.0;
static const CGFloat kCloseButtonYPad = 38.0; // @ghidraAddress 0x28f4f8
static const CGFloat kCloseButtonWidthPadding = 16.0;
static const CGFloat kCloseButtonHeightPadding = 4.0;

// The menu table's per-idiom width (an integer point count) and height.
static const int kMenuWidthPhone = 310;
static const int kMenuWidthPad = 460;
static const CGFloat kMenuHeightPhone = 430.0; // @ghidraAddress 0x28f500
static const CGFloat kMenuHeightPad = 674.0;   // @ghidraAddress 0x28f508

// The progress dialog's per-idiom size and message font.
static const CGFloat kDialogWidthPhone = 300.0;  // @ghidraAddress 0x28f2d0
static const CGFloat kDialogHeightPhone = 270.0; // @ghidraAddress 0x28f2d8
static const CGFloat kDialogWidthPad = 400.0;    // @ghidraAddress 0x28f2e0
static const CGFloat kDialogHeightPad =
    300.0; // @ghidraAddress 0x28f2d0 (same pool slot as phone width)
static const CGFloat kDialogFontSizePhone = 16.0;
static const CGFloat kDialogFontSizePad = 18.0;

// The dialog's fade-in.
static const NSTimeInterval kVerifyFadeDuration = 0.3; // @ghidraAddress 0x28f260
static const UIViewAnimationOptions kVerifyFadeOptions = UIViewAnimationOptionCurveLinear;

@implementation ChallengeMenuView {
    UITableView *menuView;
    UIView *baseView;
    UIImageView *bgImgView;
    NSArray *menuTable;
    NSArray *menuTypeTable;
    UIButton *menuBtn[kMenuRowCount];
    int selectedMenu;
    UIButton *closeBtn;
    StoreDialogView *verifyDialog;
    int verifyPurchaseType;
    UIImageView *presentMark;
    UIImageView *presentNum2[2];
    UIImageView *presentNum3[3];
    UIImage *numImage[kDigitImageCount];
    NSArray *numImageArray;
    int listCellHeight;
}

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0x426d4 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }
    BOOL isPad = [JubeatAppDelegate appDelegate].isPad;

    // The background plate, sized to its (integer-truncated) art and centred in the view.
    UIImage *bgImage = LoadScaledPngImage(kBackgroundImageName);
    CGFloat plateWidth = (int)bgImage.size.width;
    CGFloat plateHeight = (int)bgImage.size.height;
    baseView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, plateWidth, plateHeight)];
    baseView.center = CGPointMake(frame.size.width * kHalf, frame.size.height * kHalf);
    [self addSubview:baseView];

    bgImgView = [[UIImageView alloc] initWithImage:bgImage];
    bgImgView.frame = CGRectMake(0, 0, plateWidth, plateHeight);
    [baseView addSubview:bgImgView];

    // The close button, inset from the plate's top-left. Its tappable frame is the artwork plus a
    // little padding, and its y is the per-idiom baseline lifted by half the artwork's height.
    UIImage *closeImage = LoadScaledPngImage(kCloseButtonImageName);
    closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    CGFloat closeX = isPad ? kCloseButtonXPad : kCloseButtonXPhone;
    CGFloat closeY =
        (isPad ? kCloseButtonYPad : kCloseButtonYPhone) - closeImage.size.height * kHalf;
    closeBtn.frame = CGRectMake(closeX,
                                closeY,
                                closeImage.size.width + kCloseButtonWidthPadding,
                                closeImage.size.height + kCloseButtonHeightPadding);
    [closeBtn setImage:closeImage forState:UIControlStateNormal];
    [closeBtn addTarget:self
                  action:@selector(closeSettingMenu:)
        forControlEvents:UIControlEventTouchUpInside];
    closeBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    closeBtn.exclusiveTouch = YES;
    [baseView addSubview:closeBtn];

    // The rows are a fixed height taken from the first row's artwork.
    UIImage *rowImage = LoadScaledPngImage(kRowHeightImageName);
    listCellHeight = (int)rowImage.size.height;
    (void)closeBtn.frame; // Yes, the binary sends -frame here and discards it.

    // The badge-digit artwork cache, built once and copied immutable.
    NSMutableArray *digits = [[NSMutableArray alloc] initWithCapacity:kDigitImageCount];
    for (int i = 0; i < kDigitImageCount; ++i) {
        NSString *name = [NSString stringWithFormat:kDigitImageFormat, i];
        [digits addObject:LoadScaledPngImage(name)];
    }
    numImageArray = [digits copy];
    (void)closeBtn.frame; // A second discarded -frame send.

    // The table sits below the close button, centred horizontally in the plate. Its width is a
    // per-idiom integer point count and its x is truncated toward zero.
    int menuWidth = isPad ? kMenuWidthPad : kMenuWidthPhone;
    CGFloat menuHeight = isPad ? kMenuHeightPad : kMenuHeightPhone;
    CGFloat menuX = ((int)plateWidth - menuWidth) / 2;
    CGFloat menuY = closeBtn.frame.origin.y + closeBtn.frame.size.height;
    menuView = [[UITableView alloc] initWithFrame:CGRectMake(menuX, menuY, menuWidth, menuHeight)
                                            style:UITableViewStylePlain];
    menuView.delegate = self;
    menuView.dataSource = self;
    menuView.bounces = NO;
    menuView.separatorStyle = UITableViewCellSeparatorStyleNone;
    menuView.rowHeight = listCellHeight;
    menuView.backgroundColor = UIColor.clearColor;
    [baseView addSubview:menuView];

    return self;
}

#pragma mark - Actions

/** @ghidraAddress 0x42cc4 */
- (void)closeSettingMenu:(id)sender {
    [self.aDelegate closeRootMenu];
}

/** @ghidraAddress 0x42d04 */
- (void)tapMenu:(id)sender {
    if ([sender tag] == kStoreRowTag) {
        if ([[PurchaseManager sharedManager] verifyPendingConsumeReceipt]) {
            // A consume receipt is already pending: skip the prompt and refresh it directly.
            verifyPurchaseType = 0;
            [PurchaseManager sharedManager].delegate = self;
            [self showVerifyDialog:kVerifyProcessingMessage];
        } else {
            NSString *cancel = [NSBundle.mainBundle localizedStringForKey:kCancelKey
                                                                    value:@""
                                                                    table:nil];
            NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
            [[AlertViewManager sharedManager] makeAlert:0
                                               delegate:self
                                                    tag:kLinkPurchaseAlertTag
                                                  title:@""
                                                    msg:kLinkPurchaseMessage
                                                 cancel:cancel
                                                btnText:@[ ok ]
                                                   show:YES];
        }
    } else {
        selectedMenu = (int)[sender tag];
        [self.aDelegate selectMenu:@(selectedMenu)];
    }
}

/** @ghidraAddress 0x42ff0 */
- (void)alertSelect:(NSDictionary *)info {
    int tag = [info[@"Tag"] intValue];
    int btnMessage = [info[@"btnMessage"] intValue];
    if (tag != kLinkPurchaseAlertTag || btnMessage != kConfirmButtonIndex) {
        return;
    }
    [self showVerifyDialog:kVerifyRestoringMessage];
    [PurchaseManager sharedManager].delegate = self;
    [[PurchaseManager sharedManager] beginRestore];
}

#pragma mark - Verify dialog

/** @ghidraAddress 0x43158 */
- (void)showVerifyDialog:(NSString *)message {
    self.userInteractionEnabled = NO;
    BOOL isPad = [JubeatAppDelegate appDelegate].isPad;

    CGRect dialogFrame = isPad ? CGRectMake(0, 0, kDialogWidthPad, kDialogHeightPad) :
                                 CGRectMake(0, 0, kDialogWidthPhone, kDialogHeightPhone);
    verifyDialog = [[StoreDialogView alloc] initWithFrame:dialogFrame];
    verifyDialog.labelMessage.font =
        [UIFont systemFontOfSize:isPad ? kDialogFontSizePad : kDialogFontSizePhone];
    verifyDialog.center =
        CGPointMake(self.frame.size.width * kHalf, self.frame.size.height * kHalf);
    [verifyDialog.progressView setProgress:0.0];
    verifyDialog.labelMessage.text = message;
    verifyDialog.buttonAbort.hidden = YES;
    [verifyDialog layout:YES];
    [self addSubview:verifyDialog];
    verifyDialog.alpha = 0.0;

    __weak StoreDialogView *weakDialog = verifyDialog;
    [UIView animateWithDuration:kVerifyFadeDuration
                          delay:0
                        options:kVerifyFadeOptions
                     animations:^{
                       /** @ghidraAddress 0x434dc */
                       weakDialog.alpha = 1.0;
                     }
                     completion:^(BOOL finished){
                         /** @ghidraAddress 0x43528 */
                     }];
}

/** @ghidraAddress 0x4352c */
- (void)hideVerifyDialog {
    self.userInteractionEnabled = YES;
    [verifyDialog removeFromSuperview];
    verifyDialog = nil;
}

#pragma mark - PurchaseManagerDelegate

/** @ghidraAddress 0x43578 */
- (void)restoreFailed:(NSError *)error {
    [PurchaseManager sharedManager].delegate = nil;
    [self hideVerifyDialog];
}

/** @ghidraAddress 0x435d8 */
- (void)restoreNothing {
    [PurchaseManager sharedManager].delegate = nil;
    [self hideVerifyDialog];
    NSString *title = [NSBundle.mainBundle localizedStringForKey:kRestoreCompleteKey
                                                           value:@""
                                                           table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:self
                                            tag:kRestoreCompleteAlertTag
                                          title:@""
                                            msg:title
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

/** @ghidraAddress 0x43768 */
- (void)restoreSucceeded {
    // Byte-for-byte identical to -restoreNothing in the binary.
    [PurchaseManager sharedManager].delegate = nil;
    [self hideVerifyDialog];
    NSString *title = [NSBundle.mainBundle localizedStringForKey:kRestoreCompleteKey
                                                           value:@""
                                                           table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:self
                                            tag:kRestoreCompleteAlertTag
                                          title:@""
                                            msg:title
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

/** @ghidraAddress 0x438f8 */
- (void)purchaseSucceeded:(NSString *)productID {
    [PurchaseManager sharedManager].delegate = nil;
    NSString *cancel = [NSBundle.mainBundle localizedStringForKey:kCancelKey value:@"" table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:self
                                            tag:kLinkPurchaseAlertTag
                                          title:@""
                                            msg:kPurchaseCompleteMessage
                                         cancel:cancel
                                        btnText:@[ ok ]
                                           show:YES];
}

/** @ghidraAddress 0x43ae8 */
- (void)purchaseFailed:(NSString *)productID error:(NSError *)error {
    [PurchaseManager sharedManager].delegate = nil;
    if (error.code == kNetworkErrorCode) {
        NSString *msg = [NSBundle.mainBundle localizedStringForKey:kNetworkErrorKey
                                                             value:@""
                                                             table:nil];
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:nil
                                                tag:0
                                              title:@""
                                                msg:msg
                                             cancel:ok
                                            btnText:nil
                                               show:YES];
    }
    [self hideVerifyDialog];
}

#pragma mark - Present badge

/** @ghidraAddress 0x43cb0 */
- (void)refreshView {
    [self setPresentMark];
}

/** @ghidraAddress 0x43cbc */
- (void)setPresentNum:(int)num {
    // Every slot in both rows is cleared first, so the row not in use draws nothing.
    for (int slot = 0; slot < 3; ++slot) {
        presentNum3[slot].image = nil;
    }
    for (int slot = 0; slot < 2; ++slot) {
        presentNum2[slot].image = nil;
    }

    int shown = num < 1000 ? num : kMaxBadgeNumber;
    if (shown < kTwoDigitFloor) {
        // Yes, the three-wide row, not the two-wide one — a single digit sits in its centre.
        presentNum3[kThreeDigitCentreSlot].image = numImage[shown];
    } else if (shown < kThreeDigitFloor) {
        presentNum2[0].image = numImage[shown / 10];
        presentNum2[1].image = numImage[shown % 10];
    } else {
        presentNum3[2].image = numImage[shown % 10];
        presentNum3[1].image = numImage[shown / 10 % 10];
        presentNum3[0].image = numImage[shown / 100 % 10];
    }
}

/** @ghidraAddress 0x43e64 */
- (void)setPresentMark {
    int num = [ChallengeStatus sharedStatus].presentNum;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    ChallengeMenuViewCell *cell = [menuView cellForRowAtIndexPath:indexPath];
    [cell setNumber:num];
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0x43f2c */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"%@", kCellReuseIdentifier];
    ChallengeMenuViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[ChallengeMenuViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                            reuseIdentifier:identifier];
    }
    cell.tag = indexPath.row;
    cell.aDelegate = self;
    UIImage *rowImage =
        LoadScaledPngImage([NSString stringWithFormat:kRowImageFormat, (int)indexPath.row]);
    [cell setBgImage:rowImage numImage:numImageArray];
    if (indexPath.row == 0) {
        [cell setNumber:[ChallengeStatus sharedStatus].presentNum];
    }
    return cell;
}

/** @ghidraAddress 0x44174 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return kMenuRowCount;
}

/** @ghidraAddress 0x4416c */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0x44154 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return listCellHeight;
}

/** @ghidraAddress 0x44150 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Empty in the binary.
}

/** @ghidraAddress 0x4417c */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Empty in the binary.
}

@end
