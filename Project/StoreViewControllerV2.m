#import "StoreViewControllerV2.h"

#import <StoreKit/StoreKit.h>

#import "AlertViewManager.h"
#import "ChallengeMissionAchieve.h"
#import "ChallengeMissionSheet.h"
#import "ChallengeMissionTerms.h"
#import "ChallengeStatus.h"
#import "EditorIDManager.h"
#import "JubeatAppDelegate.h"
#import "LicenseAgreementView.h"
#import "PurchaseManager.h"
#import "RotatableNavigationController.h"
#import "ScratchUtil.h"
#import "SessionDownloader.h"
#import "StoreCampaignViewController.h"
#import "StoreDialogView.h"
#import "StoreDownloadManager.h"
#import "StoreDownloadTask.h"
#import "StoreMainViewControllerV2.h"
#import "StoreManageViewController.h"
#import "StoreMusicInfo.h"
#import "StoreMusicListManager.h"
#import "StorePackInfo.h"
#import "StorePurchasedViewController.h"
#import "StoreUtil.h"

// The typed-accessor category the startup-parameter dictionary is read through; a category on
// NSDictionary not reconstructed as its own file yet. See TYPES_PENDING.md.
@interface NSDictionary (TypedAccessors)
- (nullable NSString *)stringForKey:(nonnull id)key;
@end

// The tab indices of the four navigation controllers, in the order they are set on the tab bar.
enum {
    kStoreTabMain = 0,
    kStoreTabPurchased = 1,
    kStoreTabManage = 2,
    kStoreTabCampaign = 3,
};

// The alert type: a plain alert with no text-input field (the makeAlert: first argument).
static const int kAlertTypePlain = 0;

// The alert tags echoed back to -alertSelect: and used to route the dismissed alert.
static const int kAlertTagRedownload = 1;
static const int kAlertTagRestore = 2;
static const int kAlertTagRestoreComplete = 3;
static const int kAlertTagAgeSelect = 4;
static const int kAlertTagMissionCheck = 5;

// The tapped-button index the "confirm" action reports in an -alertSelect: dictionary.
static const int kAlertButtonConfirm = 1;

// The purchase-limit type stored under PrefPurchaseLimitType: 15-and-under, under-20, or 20-plus.
enum {
    kPurchaseLimitTypeUnder15 = 0,
    kPurchaseLimitTypeUnder20 = 1,
    kPurchaseLimitTypeAdult = 2,
};

// The monthly spend caps, in yen, indexed by the purchase-limit type (@ghidraAddress 0x2923f0).
static const int kPurchaseLimitAmounts[] = {5000, 5000, 20000};

// The session-download API tags echoed by -downloaderFinished:/-downloaderError:.
static const int kSessionTagTotalPurchase = 0;
static const int kSessionTagUserAge = 1;
static const int kSessionTagRestoreAge = 2;
static const int kSessionTagMissionCheck = 3;

// The response-status code signalling a forced app update, and the mission-check "no data" status.
static const int kStatusForceUpdate = 0x186ab;
static const int kStatusMissionNoData = 0x186aa;

// The challenge mission type whose achievement is checked before the store loads.
static const int kMissionTypeChallenge = 5;

// The mission states that count as already claimed.
enum {
    kMissionStateClaimed = 2,
    kMissionStateExpired = 3,
};

// The sum registered with the server when the user selects the 15-and-under age band.
static const int kUnder15RegisteredSum = 100;

// The defaults key recording the agreed store-policy licence version.
static NSString *const kPrefStoreAgreeLicenseVersion = @"PrefStoreAgreeLicenseVersion";

// The user-defaults keys read and written by the age and total-purchase flows.
static NSString *const kPrefPurchaseLimitType = @"PrefPurchaseLimitType";
static NSString *const kPrefTotalPurchase = @"PrefTotalPurchase";

// The startup-parameter keys naming the pack, genre, or campaign to open first.
static NSString *const kStartupKeyGenre = @"genre";
static NSString *const kStartupKeyPack = @"pack";
static NSString *const kStartupKeyCampaign = @"campaign";

// The session-download POST body keys.
static NSString *const kPostKeyAge = @"age";
static NSString *const kPostKeySum = @"sum";
static NSString *const kPostKeyTermID = @"term_id";

// The alert-result dictionary keys and the response-body keys.
static NSString *const kAlertKeyButtonMessage = @"btnMessage";
static NSString *const kAlertKeyTag = @"Tag";
static NSString *const kJSONKeyStatus = @"status";
static NSString *const kJSONKeySum = @"sum";
static NSString *const kJSONKeyErrorMessage = @"err_message";

// The pack-detail download-name-list entry index that marks an extension file.
static const int kDownloadNameKindExtension = 1;

// The empty string used as the localised-string fallback value.
static NSString *const kEmptyValue = @"";

// The localised-string keys this screen raises.
static NSString *const kLocKeyOK = @"OK";
static NSString *const kLocKeyCancel = @"Cancel";
static NSString *const kLocKeyDownload = @"DOWNLOAD";
static NSString *const kLocKeyError = @"Error";
static NSString *const kLocKeyProcessing = @"Processing...";
static NSString *const kLocKeyNetworkErrorMsg = @"NetworkErrorMsg";
static NSString *const kLocKeyServerErrorMsg = @"ServerErrorMsg";
static NSString *const kLocKeyReceiptVerifyErrorMsg = @"ReceiptVerifyErrorMsg";
static NSString *const kLocKeyDownloadErrorMsg = @"DownloadErrorMsg";
static NSString *const kLocKeyDownloading = @"Downloading...%@";
static NSString *const kLocKeyDownloadingAdditionItem = @"Downloading...additionitem...%@";
static NSString *const kLocKeyRestorePurchases = @"Restore purchases";
static NSString *const kLocKeyRestoreMessage = @"RestoreMessage";
static NSString *const kLocKeyAlreadyPurchasedMsg = @"AlreadyPurchasedMsg";
static NSString *const kLocKeyCannotPurchaseMsg = @"CannotPurchaseMsg";
static NSString *const kLocKeyPurchaseCancelMsg = @"PurchaseCancelMsg(%@)";
static NSString *const kLocKeyRestoreCancelMsg = @"RestoreCancelMsg(%@)";
static NSString *const kLocKeyRestoreCompleteTitle = @"RestoreCompleteTitle";
static NSString *const kLocKeyRestoreCompleteMsg = @"RestoreCompleteMsg";
static NSString *const kLocKeyRestoreNothingTitle = @"RestoreNothingTitle";
static NSString *const kLocKeyRestoreNothingMsg = @"RestoreNothingMsg";

// The currency code that counts towards the monthly spend limit.
static NSString *const kCurrencyCodeJPY = @"JPY";

// The URL opened when the user declines the age-verification alert.
static NSString *const kKonamiURL = @"http://www.konami.jp/";

// The store-policy overlay's dimming background alpha, its start alpha, and the board's centre
// fraction of the free height.
static const CGFloat kOverlayBackgroundAlpha = 0.4; // 0x10028f2c0
static const CGFloat kOverlayInitialAlpha = 0.1;    // 0x10028f2b8
static const CGFloat kHalf = 0.5;                   // fmov 0x3fe0000000000000
static const CGFloat kAgreementBoardWidthFraction = 0.5;

// The store dialog's fixed size, phone and pad, and its message-label font sizes.
static const CGFloat kDialogWidthPhone = 270.0;   // 0x10028f2d8
static const CGFloat kDialogWidthPad = 400.0;     // 0x10028f2e0
static const CGFloat kDialogHeight = 300.0;       // 0x10028f2d0
static const CGFloat kDialogFontSizePhone = 16.0; // fmov 0x4030000000000000
static const CGFloat kDialogFontSizePad = 18.0;   // fmov 0x4032000000000000

// The error-label font size and its inset above the overlay's vertical centre.
static const CGFloat kErrorLabelFontSize = 18.0;       // fmov 0x4032000000000000
static const CGFloat kErrorLabelBottomInset = 0.21875; // fmov -0x3fcc000000000000
static const int kErrorLabelCentreInset = 20;

// The modal-cover and overlay fade durations. The cover uses a longer 0.3 s fade; the overlay
// fades in at 0.2 s and out at -0.2 s (the binary passes a negative duration, kept faithfully).
static const NSTimeInterval kModalFadeDuration = 0.3;     // 0x10028f260
static const NSTimeInterval kCoverFadeInDuration = 0.2;   // 0x10028e040
static const NSTimeInterval kCoverFadeOutDuration = -0.2; // 0x10028e050

@implementation StoreViewControllerV2 {
    StoreMainViewControllerV2 *storeMainViewCtrl;
    StorePurchasedViewController *purchasedViewCtrl;
    StoreManageViewController *manageViewCtrl;
    RotatableNavigationController *storeMainNavCtrl;
    RotatableNavigationController *purchasedNavCtrl;
    RotatableNavigationController *manageNavCtrl;
    StoreCampaignViewController *campaignViewCtrl;
    RotatableNavigationController *campaignNavCtrl;
    NSMutableArray *downloadNameList;
    UIView *coverView;
    StoreDownloadManager *dlManager;
    StorePackInfo *purchasingPackInfo;
    StorePackInfo *addPurchasePackInfo;
    UIView *usrPolicyView;
    SessionDownloader *sessionDownloader;
    int selectedPurchaseAgeType;
    EditorIDManager *idManager;
    SessionDownloader *missionCheckDownloader;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0xf1ba0 */
- (nullable instancetype)init {
    self = [super init];
    if (self) {
        storeMainViewCtrl = [[StoreMainViewControllerV2 alloc] initWithParent:self];
        storeMainNavCtrl =
            [[RotatableNavigationController alloc] initWithRootViewController:storeMainViewCtrl];
        [storeMainNavCtrl.navigationBar setTranslucent:NO];
        purchasedViewCtrl = [[StorePurchasedViewController alloc] initWithParent:self];
        purchasedNavCtrl =
            [[RotatableNavigationController alloc] initWithRootViewController:purchasedViewCtrl];
        [purchasedNavCtrl.navigationBar setTranslucent:NO];
        manageViewCtrl = [[StoreManageViewController alloc] initWithParent:self];
        manageNavCtrl =
            [[RotatableNavigationController alloc] initWithRootViewController:manageViewCtrl];
        [manageNavCtrl.navigationBar setTranslucent:NO];
        campaignViewCtrl = [[StoreCampaignViewController alloc] initWithParent:self];
        campaignNavCtrl =
            [[RotatableNavigationController alloc] initWithRootViewController:campaignViewCtrl];
        [campaignNavCtrl.navigationBar setTranslucent:NO];
        if ([self.tabBar respondsToSelector:@selector(setTranslucent:)]) {
            [self.tabBar performSelector:@selector(setTranslucent:) withObject:nil];
        }
        [self setViewControllers:@[
            storeMainNavCtrl,
            purchasedNavCtrl,
            manageNavCtrl,
            campaignNavCtrl
        ]];
    }
    return self;
}

/** @ghidraAddress 0xf28a8 */
- (void)loadView {
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [super loadView];
    self.view.contentScaleFactor = [UIScreen mainScreen].scale;
    CGRect screen = [UIScreen mainScreen].bounds;
    coverView = [[UIView alloc] initWithFrame:screen];
    [coverView setOpaque:NO];
    // The binary builds this with colorWithWhite:0.0 alpha:0.4.
    coverView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kOverlayBackgroundAlpha];
    BOOL isPad = [JubeatAppDelegate appDelegate].isPad;
    CGRect dialogFrame;
    CGFloat fontSize;
    if (isPad) {
        dialogFrame = CGRectMake(0.0, 0.0, kDialogWidthPad, kDialogHeight);
        fontSize = kDialogFontSizePad;
    } else {
        dialogFrame = CGRectMake(0.0, 0.0, kDialogWidthPhone, kDialogHeight);
        fontSize = kDialogFontSizePhone;
    }
    _modalDialog = [[StoreDialogView alloc] initWithFrame:dialogFrame];
    self.modalDialog.labelMessage.font = [UIFont systemFontOfSize:fontSize];
    self.modalDialog.center = CGPointMake(screen.size.width * kHalf, screen.size.height * kHalf);
    [coverView addSubview:self.modalDialog];
}

/** @ghidraAddress 0xf8d3c */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0xf8d74 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0xf8dac */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0xf8de4 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0xf8e1c */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0xf8e54 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation - 1 < 2;
}

/** @ghidraAddress 0xf8e64 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0xf8e6c */
- (BOOL)shouldAutorotate {
    return YES;
}

/** @ghidraAddress 0xf8e74 */
- (void)dealloc {
    [super dealloc];
}

#pragma mark - Startup

/** @ghidraAddress 0xf1f88 */
- (void)firstStoreItemLoad {
    NSString *genre = [_startupParameters stringForKey:kStartupKeyGenre];
    if (genre) {
        [storeMainViewCtrl loadInitialPacklistWithGenre:genre.integerValue];
    } else {
        NSString *pack = [_startupParameters stringForKey:kStartupKeyPack];
        [storeMainViewCtrl loadInitialPacklist:pack.integerValue];
    }
    NSString *campaign = [_startupParameters stringForKey:kStartupKeyCampaign];
    if (campaign) {
        [campaignViewCtrl initialCampaignID:campaign.integerValue];
        self.selectedViewController = self.viewControllers[kStoreTabCampaign];
    }
}

/** @ghidraAddress 0xf212c */
- (void)loadInitialStoreInfo {
    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
    if (!EditorIDManager.isExistEditorID) {
        idManager = [[EditorIDManager alloc] initWithDelegate:self];
    } else {
        CGRect screen = [UIScreen mainScreen].bounds;
        CGRect navFrame = storeMainNavCtrl.navigationBar.bounds;
        CGRect tabFrame = self.tabBar.bounds;
        CGFloat freeHeight = screen.size.height - navFrame.size.height;
        usrPolicyView = [[UIView alloc] initWithFrame:CGRectMake(screen.origin.x,
                                                                 navFrame.size.height,
                                                                 screen.size.width,
                                                                 freeHeight)];
        [usrPolicyView setOpaque:NO];
        usrPolicyView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kOverlayBackgroundAlpha];
        CGFloat boardHeight = freeHeight - tabFrame.size.height;
        LicenseAgreementView *board =
            [[LicenseAgreementView alloc] init:self keyString:kPrefStoreAgreeLicenseVersion];
        board.center = CGPointMake(screen.size.width * kAgreementBoardWidthFraction,
                                   boardHeight * kAgreementBoardWidthFraction);
        usrPolicyView.alpha = kOverlayInitialAlpha;
        [usrPolicyView addSubview:board];
        [self.view addSubview:usrPolicyView];
    }
}

#pragma mark - EditorIDManagerDelegate

/** @ghidraAddress 0xf2640 */
- (void)successIDDownload:(nullable id)manager {
    idManager = nil;
    CGRect screen = [UIScreen mainScreen].bounds;
    CGRect navFrame = storeMainNavCtrl.navigationBar.bounds;
    CGRect tabFrame = self.tabBar.bounds;
    CGFloat freeHeight = screen.size.height - navFrame.size.height;
    usrPolicyView = [[UIView alloc]
        initWithFrame:CGRectMake(
                          screen.origin.x, navFrame.size.height, screen.size.width, freeHeight)];
    [usrPolicyView setOpaque:NO];
    usrPolicyView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kOverlayBackgroundAlpha];
    CGFloat boardHeight = freeHeight - tabFrame.size.height;
    LicenseAgreementView *board = [[LicenseAgreementView alloc] init:self
                                                           keyString:kPrefStoreAgreeLicenseVersion];
    board.center = CGPointMake(screen.size.width * kAgreementBoardWidthFraction,
                               boardHeight * kAgreementBoardWidthFraction);
    usrPolicyView.alpha = kOverlayInitialAlpha;
    [usrPolicyView addSubview:board];
    [self.view addSubview:usrPolicyView];
}

/** @ghidraAddress 0xf2404 */
- (void)errorIDDownload:(nullable id)manager msgStr:(nullable NSString *)msgStr {
    if (!msgStr || [msgStr isEqualToString:kEmptyValue]) {
        msgStr = [[NSBundle mainBundle] localizedStringForKey:kLocKeyNetworkErrorMsg
                                                        value:kEmptyValue
                                                        table:nil];
    }
    CGRect screen = [UIScreen mainScreen].bounds;
    CGRect navFrame = storeMainNavCtrl.navigationBar.bounds;
    CGFloat freeHeight = screen.size.height - navFrame.size.height;
    usrPolicyView = [[UIView alloc]
        initWithFrame:CGRectMake(
                          screen.origin.x, navFrame.size.height, screen.size.width, freeHeight)];
    [usrPolicyView setOpaque:NO];
    usrPolicyView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kOverlayBackgroundAlpha];
    [self.view addSubview:usrPolicyView];
    [self dispErrorLabel:msgStr];
}

#pragma mark - Modal dialog

/** @ghidraAddress 0xf2d0c */
- (void)showModalDialog:(nullable id)delegate {
    coverView.alpha = 0.0;
    [self.view addSubview:coverView];
    [self.modalDialog.indicatorView startAnimating];
    [self.modalDialog.buttonAbort setEnabled:NO];
    self.modalDialog.delegate = delegate;
    __weak UIView *weakCover = coverView;
    __weak StoreDialogView *weakDialog = self.modalDialog;
    [UIView animateWithDuration:kModalFadeDuration
        delay:0.0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0xf2fa8 */
          weakCover.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xf2ff4 */
          [weakDialog.buttonAbort setEnabled:YES];
        }];
}

/** @ghidraAddress 0xf3060 */
- (void)hideModalDialog {
    [self.modalDialog.buttonAbort setEnabled:NO];
    self.modalDialog.delegate = nil;
    __weak UIView *weakCover = coverView;
    __weak StoreDialogView *weakDialog = self.modalDialog;
    [UIView animateWithDuration:kModalFadeDuration
        delay:0.0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0xf3270 */
          weakCover.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xf32bc */
          [weakDialog.indicatorView stopAnimating];
          [weakCover removeFromSuperview];
        }];
}

#pragma mark - Downloads

/** @ghidraAddress 0xf3398 */
- (void)startDownloadMusics:(int)packID {
    NSArray *musicInfos = purchasingPackInfo.musicInfos;
    for (StoreMusicInfo *info in musicInfos) {
        [[StoreMusicListManager sharedManager] addMusic:(NSDictionary *)info];
        if (info) {
            [[StoreMusicListManager sharedManager] addMusic:(NSDictionary *)info];
        }
        if (info.extendMusicID != 0) {
            [[StoreMusicListManager sharedManager] addMusic:(NSDictionary *)[info getExtendInfo]];
        }
    }
    [[StoreMusicListManager sharedManager] saveMusicList];
    if (self.selectedViewController == storeMainNavCtrl) {
        [storeMainViewCtrl updatePurchaseStateForPackID:packID];
    } else if (self.selectedViewController == purchasedNavCtrl) {
        [purchasedViewCtrl updatePurchaseStateForPackID:packID];
    }
    NSMutableArray *tasks = [NSMutableArray arrayWithCapacity:musicInfos.count];
    downloadNameList = [NSMutableArray arrayWithCapacity:musicInfos.count];
    for (StoreMusicInfo *info in musicInfos) {
        NSString *path = [StoreUtil filePathForMusicID:info.musicID];
        BOOL isDirectory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] ||
            isDirectory) {
            [tasks addObject:[[StoreDownloadTask alloc] initWithURL:info.itemURL path:path]];
            [downloadNameList addObject:@[ info.name, @(0) ]];
        }
        if (info.extendMusicID != 0) {
            NSString *extendPath = [StoreUtil filePathForMusicID:info.extendMusicID];
            BOOL extendIsDirectory = NO;
            if ((![[NSFileManager defaultManager] fileExistsAtPath:extendPath
                                                       isDirectory:&extendIsDirectory] ||
                 extendIsDirectory) &&
                info.extendItemURL) {
                [tasks addObject:[[StoreDownloadTask alloc] initWithURL:info.extendItemURL
                                                                   path:extendPath]];
                [downloadNameList addObject:@[ info.name, @(kDownloadNameKindExtension) ]];
            }
        }
    }
    if (tasks.count != 0) {
        dlManager = [[StoreDownloadManager alloc] initWithTasks:tasks delegate:self];
        [self.modalDialog layout:NO];
        [self.modalDialog.labelMessage setText:kEmptyValue];
        [self.modalDialog.progressView setProgress:0.0];
        [dlManager start];
    } else {
        [self hideModalDialog];
    }
}

/** @ghidraAddress 0xf3cd4 */
- (void)startDownloadExtendMusics:(int)packID {
    NSArray *musicInfos = purchasingPackInfo.musicInfos;
    for (StoreMusicInfo *info in musicInfos) {
        if (info) {
            [[StoreMusicListManager sharedManager] addMusic:(NSDictionary *)info];
        }
        if (info.extendMusicID != 0) {
            [[StoreMusicListManager sharedManager] addMusic:(NSDictionary *)[info getExtendInfo]];
        }
    }
    [[StoreMusicListManager sharedManager] saveMusicList];
    NSMutableArray *tasks = [NSMutableArray arrayWithCapacity:musicInfos.count];
    downloadNameList = [NSMutableArray arrayWithCapacity:musicInfos.count];
    for (StoreMusicInfo *info in musicInfos) {
        NSString *path = [StoreUtil filePathForMusicID:info.musicID];
        if (info.extendMusicID != 0) {
            BOOL isDirectory = NO;
            if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] &&
                !isDirectory) {
                NSString *extendPath = [StoreUtil filePathForMusicID:info.extendMusicID];
                BOOL extendIsDirectory = NO;
                if ((![[NSFileManager defaultManager] fileExistsAtPath:extendPath
                                                           isDirectory:&extendIsDirectory] ||
                     extendIsDirectory) &&
                    info.extendItemURL) {
                    [tasks addObject:[[StoreDownloadTask alloc] initWithURL:info.extendItemURL
                                                                       path:extendPath]];
                    [downloadNameList addObject:@[ info.name, @(kDownloadNameKindExtension) ]];
                }
            }
        }
    }
    if (tasks.count != 0) {
        dlManager = [[StoreDownloadManager alloc] initWithTasks:tasks delegate:self];
        [self.modalDialog layout:NO];
        [self.modalDialog.labelMessage setText:kEmptyValue];
        [self.modalDialog.progressView setProgress:0.0];
        [dlManager start];
    } else {
        [self hideModalDialog];
    }
}

#pragma mark - Purchase / restore

/** @ghidraAddress 0xf4444 */
- (void)performRestore:(nullable id)sender {
    NSString *title = [[NSBundle mainBundle] localizedStringForKey:kLocKeyRestorePurchases
                                                             value:kEmptyValue
                                                             table:nil];
    NSString *msg = [[NSBundle mainBundle] localizedStringForKey:kLocKeyRestoreMessage
                                                           value:kEmptyValue
                                                           table:nil];
    NSString *cancel = [[NSBundle mainBundle] localizedStringForKey:kLocKeyCancel
                                                              value:kEmptyValue
                                                              table:nil];
    NSString *ok = [[NSBundle mainBundle] localizedStringForKey:kLocKeyOK
                                                          value:kEmptyValue
                                                          table:nil];
    [[AlertViewManager sharedManager] makeAlert:kAlertTypePlain
                                       delegate:self
                                            tag:kAlertTagRestore
                                          title:title
                                            msg:msg
                                         cancel:cancel
                                        btnText:@[ ok ]
                                           show:YES];
}

/** @ghidraAddress 0xf4690 */
- (void)detailViewStartRedownload:(nullable StorePackInfo *)packInfo {
    purchasingPackInfo = packInfo;
    addPurchasePackInfo = nil;
    NSString *msg = [[NSBundle mainBundle] localizedStringForKey:kLocKeyAlreadyPurchasedMsg
                                                           value:kEmptyValue
                                                           table:nil];
    NSString *title = [[NSBundle mainBundle] localizedStringForKey:kLocKeyDownload
                                                             value:kEmptyValue
                                                             table:nil];
    NSString *cancel = [[NSBundle mainBundle] localizedStringForKey:kLocKeyCancel
                                                              value:kEmptyValue
                                                              table:nil];
    NSString *ok = [[NSBundle mainBundle] localizedStringForKey:kLocKeyOK
                                                          value:kEmptyValue
                                                          table:nil];
    [[AlertViewManager sharedManager] makeAlert:kAlertTypePlain
                                       delegate:self
                                            tag:kAlertTagRedownload
                                          title:title
                                            msg:msg
                                         cancel:cancel
                                        btnText:@[ ok ]
                                           show:YES];
}

/** @ghidraAddress 0xf4920 */
- (BOOL)checkAttainLimitPurchase:(nullable SKProduct *)product {
    int total = [JubeatAppDelegate appDelegate].totalPurchaseAmount;
    NSInteger limitType =
        [[NSUserDefaults standardUserDefaults] integerForKey:kPrefPurchaseLimitType];
    int limitAmount;
    if ((NSUInteger)limitType < 3) {
        limitAmount = kPurchaseLimitAmounts[limitType];
    } else {
        limitAmount = -1;
    }
    if ([[product.priceLocale objectForKey:NSLocaleCurrencyCode]
            isEqualToString:kCurrencyCodeJPY]) {
        total += product.price.integerValue;
    }
    BOOL blocked = NO;
    if (limitAmount >= 0 && limitAmount < total) {
        if (limitType == kPurchaseLimitTypeUnder15) {
            NSString *cancel = [[NSBundle mainBundle] localizedStringForKey:kLocKeyCancel
                                                                      value:kEmptyValue
                                                                      table:nil];
            [[AlertViewManager sharedManager]
                makeAlert:kAlertTypePlain
                 delegate:self
                      tag:kAlertTagAgeSelect
                    title:@"年齢確認"
                      msg:@"有料サービスのご利用にあたり、\n年齢の確認をお願いしております。"
                   cancel:cancel
                  btnText:@[ @"15歳以下(5000円/月)", @"20歳未満(20000円/月)", @"20歳以上(無制限)" ]
                     show:YES];
        } else {
            NSString *ok = [[NSBundle mainBundle] localizedStringForKey:kLocKeyOK
                                                                  value:kEmptyValue
                                                                  table:nil];
            [[AlertViewManager sharedManager]
                makeAlert:kAlertTypePlain
                 delegate:nil
                      tag:0
                    title:@"制限超過"
                      msg:@"今月はこれ以上購入できません。月が変わってからストアに入り直すと購入が"
                          @"可能になります。"
                   cancel:ok
                  btnText:nil
                     show:YES];
        }
        blocked = YES;
    }
    return blocked;
}

/** @ghidraAddress 0xf4c9c */
- (void)detailViewStartPurchase:(nullable StorePackInfo *)packInfo {
    if (!PurchaseManager.isPurchasable || !packInfo.product) {
        NSString *msg = [[NSBundle mainBundle] localizedStringForKey:kLocKeyCannotPurchaseMsg
                                                               value:kEmptyValue
                                                               table:nil];
        NSString *title = [[NSBundle mainBundle] localizedStringForKey:kLocKeyError
                                                                 value:kEmptyValue
                                                                 table:nil];
        NSString *ok = [[NSBundle mainBundle] localizedStringForKey:kLocKeyOK
                                                              value:kEmptyValue
                                                              table:nil];
        [[AlertViewManager sharedManager] makeAlert:kAlertTypePlain
                                           delegate:nil
                                                tag:0
                                              title:title
                                                msg:msg
                                             cancel:ok
                                            btnText:nil
                                               show:YES];
    } else {
        purchasingPackInfo = packInfo;
        addPurchasePackInfo = packInfo;
        if (![self checkAttainLimitPurchase:packInfo.product]) {
            [self.modalDialog layout:YES];
            NSString *processing = [[NSBundle mainBundle] localizedStringForKey:kLocKeyProcessing
                                                                          value:kEmptyValue
                                                                          table:nil];
            [self.modalDialog.labelMessage setText:processing];
            [self showModalDialog:self];
            [PurchaseManager sharedManager].delegate = self;
            [[PurchaseManager sharedManager] beginPurchase:packInfo.product];
        }
    }
}

/** @ghidraAddress 0xf507c */
- (void)detailViewStartExtendDownload:(nullable StorePackInfo *)packInfo {
    purchasingPackInfo = packInfo;
    [self showModalDialog:self];
    [self startDownloadExtendMusics:purchasingPackInfo.packID];
}

#pragma mark - PurchaseManagerDelegate

/** @ghidraAddress 0xf5104 */
- (void)purchaseSucceeded:(nullable NSString *)productID {
    [PurchaseManager sharedManager].delegate = nil;
    if (self.selectedViewController == storeMainNavCtrl) {
        [purchasedViewCtrl resetPurchasedList];
    }
    int packID = [StoreUtil packIDForProductID:productID];
    [self startDownloadMusics:packID];
    [campaignViewCtrl refreshUnlockTable];
    addPurchasePackInfo = nil;
}

/** @ghidraAddress 0xf5214 */
- (void)purchaseFailed:(nullable NSString *)productID error:(nullable NSError *)error {
    [self hideModalDialog];
    NSString *msg;
    if (![error.domain isEqualToString:@"jp.konami.PurchaseManagerErrorDomain"]) {
        NSString *cancelFormat =
            [[NSBundle mainBundle] localizedStringForKey:kLocKeyPurchaseCancelMsg
                                                   value:kEmptyValue
                                                   table:nil];
        msg = [NSString stringWithFormat:cancelFormat, error.localizedDescription];
    } else {
        NSString *reason;
        switch (error.code) {
        case 1:
            // The binary computes NetworkErrorMsg here and discards it, showing "Error".
            (void)[[NSBundle mainBundle] localizedStringForKey:kLocKeyNetworkErrorMsg
                                                         value:kEmptyValue
                                                         table:nil];
            reason = [[NSBundle mainBundle] localizedStringForKey:kLocKeyError
                                                            value:kEmptyValue
                                                            table:nil];
            break;
        case 2:
            reason = [[NSBundle mainBundle] localizedStringForKey:kLocKeyServerErrorMsg
                                                            value:kEmptyValue
                                                            table:nil];
            break;
        case 3: {
            reason = [[NSBundle mainBundle] localizedStringForKey:kLocKeyReceiptVerifyErrorMsg
                                                            value:kEmptyValue
                                                            table:nil];
            int packID = [StoreUtil packIDForProductID:productID];
            if (self.selectedViewController == storeMainNavCtrl) {
                [storeMainViewCtrl updatePurchaseStateForPackID:packID];
            } else if (self.selectedViewController == purchasedNavCtrl) {
                [purchasedViewCtrl updatePurchaseStateForPackID:packID];
            }
            break;
        }
        default:
            reason = [[NSBundle mainBundle] localizedStringForKey:kLocKeyError
                                                            value:kEmptyValue
                                                            table:nil];
            break;
        }
        msg = [NSString stringWithFormat:@"%@\n(%@)", reason, error.localizedDescription];
    }
    [PurchaseManager sharedManager].delegate = nil;
    purchasingPackInfo = nil;
    addPurchasePackInfo = nil;
    NSString *title = [[NSBundle mainBundle] localizedStringForKey:kLocKeyError
                                                             value:kEmptyValue
                                                             table:nil];
    NSString *ok = [[NSBundle mainBundle] localizedStringForKey:kLocKeyOK
                                                          value:kEmptyValue
                                                          table:nil];
    [[AlertViewManager sharedManager] makeAlert:kAlertTypePlain
                                       delegate:nil
                                            tag:0
                                          title:title
                                            msg:msg
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

/** @ghidraAddress 0xf5794 */
- (void)restoreSucceeded {
    [PurchaseManager sharedManager].delegate = nil;
    [self hideModalDialog];
    NSString *title = [[NSBundle mainBundle] localizedStringForKey:kLocKeyRestoreCompleteTitle
                                                             value:kEmptyValue
                                                             table:nil];
    NSString *msg = [[NSBundle mainBundle] localizedStringForKey:kLocKeyRestoreCompleteMsg
                                                           value:kEmptyValue
                                                           table:nil];
    NSString *ok = [[NSBundle mainBundle] localizedStringForKey:kLocKeyOK
                                                          value:kEmptyValue
                                                          table:nil];
    [[AlertViewManager sharedManager] makeAlert:kAlertTypePlain
                                       delegate:self
                                            tag:kAlertTagRestoreComplete
                                          title:title
                                            msg:msg
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
    [campaignViewCtrl refreshUnlockTable];
}

/** @ghidraAddress 0xf5990 */
- (void)restoreFailed:(nullable NSError *)error {
    [PurchaseManager sharedManager].delegate = nil;
    [self hideModalDialog];
    NSString *cancelMsg = [[NSBundle mainBundle] localizedStringForKey:kLocKeyRestoreCancelMsg
                                                                 value:kEmptyValue
                                                                 table:nil];
    NSString *msg = [NSString stringWithFormat:cancelMsg, error.localizedDescription];
    NSString *title = [[NSBundle mainBundle] localizedStringForKey:kLocKeyError
                                                             value:kEmptyValue
                                                             table:nil];
    NSString *ok = [[NSBundle mainBundle] localizedStringForKey:kLocKeyOK
                                                          value:kEmptyValue
                                                          table:nil];
    [[AlertViewManager sharedManager] makeAlert:kAlertTypePlain
                                       delegate:nil
                                            tag:0
                                          title:title
                                            msg:msg
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

/** @ghidraAddress 0xf5bec */
- (void)restoreNothing {
    [PurchaseManager sharedManager].delegate = nil;
    [self hideModalDialog];
    NSString *title = [[NSBundle mainBundle] localizedStringForKey:kLocKeyRestoreNothingTitle
                                                             value:kEmptyValue
                                                             table:nil];
    NSString *msg = [[NSBundle mainBundle] localizedStringForKey:kLocKeyRestoreNothingMsg
                                                           value:kEmptyValue
                                                           table:nil];
    NSString *ok = [[NSBundle mainBundle] localizedStringForKey:kLocKeyOK
                                                          value:kEmptyValue
                                                          table:nil];
    [[AlertViewManager sharedManager] makeAlert:kAlertTypePlain
                                       delegate:nil
                                            tag:0
                                          title:title
                                            msg:msg
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

/** @ghidraAddress 0xf5dd0 */
- (void)firstRestore {
    [self.modalDialog layout:YES];
    NSString *processing = [[NSBundle mainBundle] localizedStringForKey:kLocKeyProcessing
                                                                  value:kEmptyValue
                                                                  table:nil];
    [self.modalDialog.labelMessage setText:processing];
    [self showModalDialog:self];
    [PurchaseManager sharedManager].delegate = self;
    [[PurchaseManager sharedManager] beginRestore];
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0xf5f58 */
- (void)alertSelect:(nonnull NSDictionary *)info {
    int button = [info[kAlertKeyButtonMessage] intValue];
    int tag = [info[kAlertKeyTag] intValue];
    if (tag == kAlertTagRestoreComplete) {
        [storeMainViewCtrl refresh];
        [purchasedViewCtrl reloadPurchasedList];
        return;
    }
    if (tag == kAlertTagRestore) {
        if (button == kAlertButtonConfirm) {
            [self.modalDialog layout:YES];
            NSString *processing = [[NSBundle mainBundle] localizedStringForKey:kLocKeyProcessing
                                                                          value:kEmptyValue
                                                                          table:nil];
            [self.modalDialog.labelMessage setText:processing];
            [self showModalDialog:self];
            [PurchaseManager sharedManager].delegate = self;
            [[PurchaseManager sharedManager] beginRestore];
        }
    } else if (tag == kAlertTagRedownload) {
        if (button == kAlertButtonConfirm && purchasingPackInfo) {
            NSString *productID = [StoreUtil productIDForPackID:purchasingPackInfo.packID];
            if (![[PurchaseManager sharedManager] isPending:productID]) {
                [self showModalDialog:self];
                [self startDownloadMusics:purchasingPackInfo.packID];
            } else {
                [self.modalDialog layout:YES];
                NSString *processing =
                    [[NSBundle mainBundle] localizedStringForKey:kLocKeyProcessing
                                                           value:kEmptyValue
                                                           table:nil];
                [self.modalDialog.labelMessage setText:processing];
                [self showModalDialog:self];
                [PurchaseManager sharedManager].delegate = self;
                [[PurchaseManager sharedManager] beginPurchase:purchasingPackInfo.product];
            }
        }
    } else if (tag == kAlertTagAgeSelect) {
        if (button != 0) {
            if (button > 3) {
                NSURL *url = [NSURL URLWithString:kKonamiURL];
                [[UIApplication sharedApplication] openURL:url];
            } else {
                selectedPurchaseAgeType = button;
                NSDictionary *post = @{kPostKeyAge : @(button - 1)};
                sessionDownloader =
                    [[SessionDownloader alloc] initWithURL:[ScratchUtil registUserAgeURL]
                                            postDictionary:post
                                                  delegate:self];
                sessionDownloader.tag = kSessionTagRestoreAge;
                [sessionDownloader startDownloading];
            }
        }
    } else if (tag == kAlertTagMissionCheck) {
        [missionCheckDownloader startDownloading];
    }
}

#pragma mark - StoreDialogViewDelegate

/** @ghidraAddress 0xf66b0 */
- (void)storeDialogCancel:(nullable id)dialogView {
    [dlManager cancel];
    dlManager = nil;
    [self hideModalDialog];
    int packID = purchasingPackInfo.packID;
    if (self.selectedViewController == storeMainNavCtrl) {
        [storeMainViewCtrl updatePurchaseStateForPackID:packID];
    } else if (self.selectedViewController == purchasedNavCtrl) {
        [purchasedViewCtrl updatePurchaseStateForPackID:packID];
    }
}

#pragma mark - StoreDownloadManagerDelegate

/** @ghidraAddress 0xf67cc */
- (void)downloadManagerStartTask:(nullable id)manager {
    NSArray *entry = downloadNameList[dlManager.currentIndex];
    NSString *format = [[NSBundle mainBundle] localizedStringForKey:kLocKeyDownloading
                                                              value:kEmptyValue
                                                              table:nil];
    NSString *message = [NSString stringWithFormat:format, entry[0]];
    if ([entry[1] intValue] == kDownloadNameKindExtension) {
        NSString *additionFormat =
            [[NSBundle mainBundle] localizedStringForKey:kLocKeyDownloadingAdditionItem
                                                   value:kEmptyValue
                                                   table:nil];
        message = [NSString stringWithFormat:additionFormat, entry[0]];
    }
    [self.modalDialog.labelMessage setText:message];
}

/** @ghidraAddress 0xf6a58 */
- (void)downloadManagerCompleted:(nullable id)manager {
    dlManager = nil;
    [self hideModalDialog];
}

/** @ghidraAddress 0xf6a94 */
- (void)downloadManagerFailed:(nullable id)manager {
    dlManager = nil;
    int packID = purchasingPackInfo.packID;
    if (self.selectedViewController == storeMainNavCtrl) {
        [storeMainViewCtrl updatePurchaseStateForPackID:packID];
    } else if (self.selectedViewController == purchasedNavCtrl) {
        [purchasedViewCtrl updatePurchaseStateForPackID:packID];
    }
    [self hideModalDialog];
    NSString *title = [[NSBundle mainBundle] localizedStringForKey:kLocKeyError
                                                             value:kEmptyValue
                                                             table:nil];
    NSString *msg = [[NSBundle mainBundle] localizedStringForKey:kLocKeyDownloadErrorMsg
                                                           value:kEmptyValue
                                                           table:nil];
    NSString *ok = [[NSBundle mainBundle] localizedStringForKey:kLocKeyOK
                                                          value:kEmptyValue
                                                          table:nil];
    [[AlertViewManager sharedManager] makeAlert:kAlertTypePlain
                                       delegate:nil
                                            tag:0
                                          title:title
                                            msg:msg
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

/** @ghidraAddress 0xf6d00 */
- (void)downloadManagerProceed:(nullable id)manager {
    [self.modalDialog.progressView setProgress:dlManager.overallProgress];
}

#pragma mark - Detail routing

/** @ghidraAddress 0xf6d88 */
- (void)openDetail:(nullable NSNumber *)packID {
    [[AlertViewManager sharedManager] closeAlert];
    [storeMainViewCtrl addOpenDetail:packID.integerValue];
    if (self.selectedViewController != storeMainNavCtrl) {
        self.selectedViewController = self.viewControllers[kStoreTabMain];
    }
}

/** @ghidraAddress 0xf6ed4 */
- (void)openCampaignDetail:(nullable NSNumber *)campaignID {
    [[AlertViewManager sharedManager] closeAlert];
    [campaignViewCtrl addOpenDetail:campaignID.integerValue];
    if (self.selectedViewController != campaignNavCtrl) {
        self.selectedViewController = self.viewControllers[kStoreTabCampaign];
    }
}

/** @ghidraAddress 0xf7020 */
- (void)storeClose {
    [storeMainViewCtrl storeClose];
    [purchasedViewCtrl storeClose];
    [manageViewCtrl storeClose];
    [campaignViewCtrl storeClose];
    [[AlertViewManager sharedManager] closeAlert];
}

/** @ghidraAddress 0xf2ca4 */
- (void)storeEnd:(nullable id)sender {
    [[JubeatAppDelegate appDelegate].rootViewCtrl endStore];
}

#pragma mark - Policy overlay

/** @ghidraAddress 0xf70c4 */
- (void)becomeCoverView {
    __weak UIView *weakPolicy = usrPolicyView;
    usrPolicyView.alpha = 0.0;
    [UIView animateWithDuration:kCoverFadeInDuration
                     animations:^{
                       /** @ghidraAddress 0xf71c0 */
                       weakPolicy.alpha = 1.0;
                     }
                     completion:^(BOOL finished){
                     }];
}

/** @ghidraAddress 0xf7210 */
- (void)resignCoverView {
    __weak UIView *weakPolicy = usrPolicyView;
    [UIView animateWithDuration:kCoverFadeOutDuration
                     animations:^{
                       /** @ghidraAddress 0xf72dc */
                       weakPolicy.alpha = 0.0;
                     }
                     completion:^(BOOL finished){
                     }];
}

/** @ghidraAddress 0xf732c */
- (void)dispErrorLabel:(nullable NSString *)message {
    CGFloat width = usrPolicyView.frame.size.width;
    CGFloat height = usrPolicyView.frame.size.height - kErrorLabelBottomInset;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, width, height)];
    label.backgroundColor = UIColor.clearColor;
    label.font = [UIFont boldSystemFontOfSize:kErrorLabelFontSize];
    label.textColor = UIColor.blackColor;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.center =
        CGPointMake(usrPolicyView.frame.size.width * kHalf,
                    (int)(usrPolicyView.frame.size.height * kHalf) - kErrorLabelCentreInset);
    if (!message) {
        message = [[NSBundle mainBundle] localizedStringForKey:kLocKeyNetworkErrorMsg
                                                         value:kEmptyValue
                                                         table:nil];
    }
    label.text = message;
    [usrPolicyView addSubview:label];
    [self becomeCoverView];
}

#pragma mark - LicenseAgreementView callbacks

/** @ghidraAddress 0xf75a4 */
- (void)agreementSuccess:(nullable id)agreement {
    NSInteger limitType =
        [[NSUserDefaults standardUserDefaults] integerForKey:kPrefPurchaseLimitType];
    (void)[[NSUserDefaults standardUserDefaults] integerForKey:kPrefTotalPurchase];
    if (limitType == kPurchaseLimitTypeUnder15) {
        NSDictionary *post = @{kPostKeySum : @(kUnder15RegisteredSum)};
        sessionDownloader =
            [[SessionDownloader alloc] initWithURL:[ScratchUtil registTotalPurchaseURL]
                                    postDictionary:post
                                          delegate:self];
    } else {
        NSDictionary *post = @{kPostKeyAge : @(limitType - 1)};
        sessionDownloader = [[SessionDownloader alloc] initWithURL:[ScratchUtil registUserAgeURL]
                                                    postDictionary:post
                                                          delegate:self];
    }
    sessionDownloader.tag = (limitType != 0);
    [sessionDownloader startDownloading];
}

/** @ghidraAddress 0xf84ac */
- (void)agreementFailed:(nullable id)agreement {
    __weak UIView *weakAgreement = agreement;
    [(UIView *)agreement setAlpha:1.0];
    [UIView animateWithDuration:kCoverFadeOutDuration
        animations:^{
          /** @ghidraAddress 0xf85f4 */
          weakAgreement.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xf8640 */
          [self storeEnd:nil];
        }];
}

/** @ghidraAddress 0xf8664 */
- (void)becomePolicyAgreement:(nullable id)agreement {
    [self becomeCoverView];
}

/** @ghidraAddress 0xf8670 */
- (void)agreementError:(nullable id)agreement msgStr:(nullable NSString *)msgStr {
    CGFloat width = usrPolicyView.frame.size.width;
    CGFloat height = usrPolicyView.frame.size.height - kErrorLabelBottomInset;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, width, height)];
    label.backgroundColor = UIColor.clearColor;
    label.font = [UIFont boldSystemFontOfSize:kErrorLabelFontSize];
    label.textColor = UIColor.blackColor;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.center =
        CGPointMake(usrPolicyView.frame.size.width * kHalf,
                    (int)(usrPolicyView.frame.size.height * kHalf) - kErrorLabelCentreInset);
    if (!msgStr) {
        msgStr = [[NSBundle mainBundle] localizedStringForKey:kLocKeyNetworkErrorMsg
                                                        value:kEmptyValue
                                                        table:nil];
    }
    label.text = msgStr;
    [usrPolicyView addSubview:label];
    [self becomeCoverView];
}

#pragma mark - SessionDownloader / DownloaderDelegate

/** @ghidraAddress 0xf7878 */
- (void)downloaderFinished:(nullable id)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    int status;
    if (!json[kJSONKeyStatus]) {
        status = -1;
    } else {
        status = [json[kJSONKeyStatus] intValue];
        if (status == kStatusForceUpdate) {
            [[AlertViewManager sharedManager] showUpdateAlert];
        }
    }
    switch ([downloader tag]) {
    case kSessionTagTotalPurchase:
        if (status == 0) {
            [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kPrefTotalPurchase];
            [[JubeatAppDelegate appDelegate] setTotalAmount:[json[kJSONKeySum] intValue]];
            [self createStoreMissionDownloader];
            if (!missionCheckDownloader) {
                [self resignCoverView];
                [self firstStoreItemLoad];
            } else {
                missionCheckDownloader.tag = kSessionTagMissionCheck;
                [missionCheckDownloader startDownloading];
            }
        } else {
            NSString *msg = [[NSBundle mainBundle] localizedStringForKey:kLocKeyServerErrorMsg
                                                                   value:kEmptyValue
                                                                   table:nil];
            if (json[kJSONKeyErrorMessage]) {
                msg = json[kJSONKeyErrorMessage];
            }
            [self dispErrorLabel:msg];
        }
        sessionDownloader = nil;
        break;
    case kSessionTagUserAge:
        if (status == 0) {
            sessionDownloader = nil;
            NSInteger total =
                [[NSUserDefaults standardUserDefaults] integerForKey:kPrefTotalPurchase];
            NSDictionary *post = @{kPostKeySum : @(total)};
            sessionDownloader =
                [[SessionDownloader alloc] initWithURL:[ScratchUtil registTotalPurchaseURL]
                                        postDictionary:post
                                              delegate:self];
            sessionDownloader.tag = kSessionTagTotalPurchase;
            [sessionDownloader startDownloading];
        } else {
            NSString *msg = [[NSBundle mainBundle] localizedStringForKey:kLocKeyServerErrorMsg
                                                                   value:kEmptyValue
                                                                   table:nil];
            if (json[kJSONKeyErrorMessage]) {
                msg = json[kJSONKeyErrorMessage];
            }
            [self dispErrorLabel:msg];
            sessionDownloader = nil;
        }
        break;
    case kSessionTagRestoreAge:
        [[NSUserDefaults standardUserDefaults] setInteger:selectedPurchaseAgeType
                                                   forKey:kPrefPurchaseLimitType];
        [self detailViewStartPurchase:purchasingPackInfo];
        break;
    case kSessionTagMissionCheck:
        if (status == kStatusMissionNoData) {
            NSString *msg = json[kJSONKeyErrorMessage];
            if (!msg) {
                msg = @"Ok01YWeW0~0W0_0";
            }
            NSString *ok = [[NSBundle mainBundle] localizedStringForKey:kLocKeyOK
                                                                  value:kEmptyValue
                                                                  table:nil];
            [[AlertViewManager sharedManager] makeAlert:kAlertTypePlain
                                               delegate:self
                                                    tag:kAlertTagMissionCheck
                                                  title:kEmptyValue
                                                    msg:msg
                                                 cancel:ok
                                                btnText:nil
                                                   show:YES];
        } else if (status == 0) {
            [self resignCoverView];
            [self firstStoreItemLoad];
        }
        break;
    }
}

/** @ghidraAddress 0xf7fc0 */
- (void)downloaderError:(nullable id)downloader {
    if ([downloader tag] == kSessionTagMissionCheck) {
        NSString *ok = [[NSBundle mainBundle] localizedStringForKey:kLocKeyOK
                                                              value:kEmptyValue
                                                              table:nil];
        [[AlertViewManager sharedManager] makeAlert:kAlertTypePlain
                                           delegate:self
                                                tag:kAlertTagMissionCheck
                                              title:kEmptyValue
                                                msg:@"通信に失敗しました\n再度通信を行います"
                                             cancel:ok
                                            btnText:nil
                                               show:YES];
    } else if ([downloader tag] == kSessionTagRestoreAge) {
        NSString *ok = [[NSBundle mainBundle] localizedStringForKey:kLocKeyOK
                                                              value:kEmptyValue
                                                              table:nil];
        [[AlertViewManager sharedManager] makeAlert:kAlertTypePlain
                                           delegate:nil
                                                tag:0
                                              title:@"通信エラー"
                                                msg:@"マーカーをダウンロードしています"
                                             cancel:ok
                                            btnText:nil
                                               show:YES];
    } else {
        NSDictionary *json = [downloader getDataInJSON];
        NSString *msg = [[NSBundle mainBundle] localizedStringForKey:kLocKeyNetworkErrorMsg
                                                               value:kEmptyValue
                                                               table:nil];
        if (json[kJSONKeyErrorMessage]) {
            msg = json[kJSONKeyErrorMessage];
        }
        CGFloat width = usrPolicyView.frame.size.width;
        CGFloat height = usrPolicyView.frame.size.height - kErrorLabelBottomInset;
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, width, height)];
        label.backgroundColor = UIColor.clearColor;
        label.font = [UIFont boldSystemFontOfSize:kErrorLabelFontSize];
        label.textColor = UIColor.blackColor;
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 0;
        label.center =
            CGPointMake(usrPolicyView.frame.size.width * kHalf,
                        (int)(usrPolicyView.frame.size.height * kHalf) - kErrorLabelCentreInset);
        if (!msg) {
            msg = [[NSBundle mainBundle] localizedStringForKey:kLocKeyNetworkErrorMsg
                                                         value:kEmptyValue
                                                         table:nil];
        }
        label.text = msg;
        [usrPolicyView addSubview:label];
        [self becomeCoverView];
    }
}

#pragma mark - Mission check

/** @ghidraAddress 0xf88e8 */
- (void)createStoreMissionDownloader {
    ChallengeMissionSheet *sheet = [[ChallengeStatus sharedStatus] getSelectedMissionSheet];
    NSMutableArray *unclaimed = [[NSMutableArray alloc] init];
    missionCheckDownloader = nil;
    // The binary bounds this loop by unclaimed.count, which is zero on entry, so it never runs.
    for (NSUInteger i = 0; i < unclaimed.count; ++i) {
        ChallengeMissionTerms *mission = sheet.missionTable[i];
        if (mission.missionType == kMissionTypeChallenge) {
            ChallengeMissionAchieve *achieve = sheet.missionAchieveTable[i];
            if (achieve.missionState != kMissionStateClaimed &&
                achieve.missionState != kMissionStateExpired) {
                if ([JubeatAppDelegate appDelegate].bChallengeMode) {
                    [unclaimed addObject:mission];
                }
            }
        }
    }
    if (unclaimed.count != 0) {
        NSMutableArray *ids = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < unclaimed.count; ++i) {
            ChallengeMissionTerms *mission = unclaimed[i];
            [ids addObject:@(mission.missionID)];
        }
        NSDictionary *post = @{kPostKeyTermID : ids};
        missionCheckDownloader =
            [[SessionDownloader alloc] initWithURL:[ScratchUtil getMissionAchieveCheckURL]
                                    postDictionary:post
                                          delegate:self];
    }
}

#pragma mark - Accessors

/** @ghidraAddress 0xf8eac (getter), 0xf8ebc (setter) */
@synthesize startupParameters = _startupParameters;

/** @ghidraAddress 0xf8ed0 (getter) */
@synthesize modalDialog = _modalDialog;

@end
