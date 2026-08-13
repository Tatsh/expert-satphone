#import "StoreViewController.h"

#import <StoreKit/StoreKit.h>

#import "ChallengeMissionAchieve.h"
#import "ChallengeMissionSheet.h"
#import "ChallengeMissionTerms.h"
#import "ChallengeStatus.h"
#import "JubeatAppDelegate.h"
#import "LicenseAgreementView.h"
#import "NSDictionary+TypedLookupExtension.h"
#import "RootViewController.h"
#import "RotatableNavigationController.h"
#import "ScratchUtil.h"
#import "SessionDownloader.h"
#import "StoreCampaignViewController.h"
#import "StoreDetailViewControllerV2.h"
#import "StoreDownloadTask.h"
#import "StoreMainViewController.h"
#import "StoreManageViewController.h"
#import "StoreMusicInfo.h"
#import "StoreMusicListManager.h"
#import "StorePackInfo.h"
#import "StorePurchasedViewController.h"
#import "StoreUtil.h"

// The four store tabs, in the order the tab bar installs them.
enum {
    StoreTabIndexMain = 0,
    StoreTabIndexPurchased = 1,
    StoreTabIndexManage = 2,
    StoreTabIndexCampaign = 3,
};

// The alert type: the makeAlert: first argument, a plain alert with no text-input field.
static const int kAlertTypePlain = 0;

// The alert tags echoed back to -alertSelect:.
static const int kAlertTagRedownload = 1;
static const int kAlertTagRestore = 2;
static const int kAlertTagRestoreComplete = 3;
static const int kAlertTagAgeRegister = 4;
static const int kAlertTagMissionCheck = 5;

// The button index a confirmation alert reports for its accept action.
static const int kAlertButtonAccept = 1;

// The session-downloader API tags, echoed back to -downloaderFinished:.
static const int kSessionTagTotalPurchase = 0;
static const int kSessionTagUserAge = 1;
static const int kSessionTagAgeThenPurchase = 2;
static const int kSessionTagMissionCheck = 3;

// The purchase-limit type stored under PrefPurchaseLimitType and the per-type monthly yen ceilings
// (a negative ceiling means "unlimited"). Type 0 is the age-unset state.
static const NSInteger kPurchaseLimitTypeAgeUnset = 0;
static const int kPurchaseLimitYenCeilings[] = {5000, 5000, 20000};

// The one deep-linked mission type checked by -createStoreMissionDownloader.
static const int kMissionTypePurchaseUnlock = 5;

// The mission-achieve states that mark a mission already cleared.
static const int kMissionStateCleared0 = 2;
static const int kMissionStateCleared1 = 3;

// The status field of a signed server response; kStatusOK means success.
static const int kServerStatusOK = 0;
static const int kServerStatusUpdateRequired = 0x186ab;
static const int kServerStatusMissionError = 0x186aa;

// The device-idiom modal-dialog sizes and their message-font point sizes.
static const CGFloat kDialogWidthPhone = 300.0;
static const CGFloat kDialogHeightPhone = 270.0;
static const CGFloat kDialogWidthPad = 400.0;
static const CGFloat kDialogHeightPad = 300.0;
static const CGFloat kDialogFontSizePhone = 16.0;
static const CGFloat kDialogFontSizePad = 18.0;

// The dimming cover's black-tint alpha. @ghidraAddress 0x28f2c0
static const CGFloat kCoverAlpha = 0.4;

// The show/hide dialog fade duration. @ghidraAddress 0x28f260
static const NSTimeInterval kDialogFadeDuration = 0.3;

// The cover fade-in and fade-out durations; the latter is a negative value in the binary, applied
// as shipped. @ghidraAddress 0x28e040 @ghidraAddress 0x28e050
static const NSTimeInterval kCoverFadeInDuration = 0.2;
static const NSTimeInterval kCoverFadeOutDuration = -0.2;

// The licence agreement board's width fraction and its bottom margin below the navigation bar.
static const CGFloat kAgreementBoardWidthFraction = 0.5;

// The centred error label's inset and its vertical-centre lift.
static const CGFloat kErrorLabelBottomInset = 20.0;
static const int kErrorLabelCentreLift = 20;

// The error label's font size.
static const CGFloat kErrorLabelFontSize = 18.0;

// The user-defaults key recording the agreed challenge-policy version, handed to the agreement
// view.
static NSString *const kPrefAgreeChallengePolicyVersion = @"PrefAgreeChallengePolicyVersion";

// The user-defaults keys for the running purchase limit and total.
static NSString *const kPrefPurchaseLimitType = @"PrefPurchaseLimitType";
static NSString *const kPrefTotalPurchase = @"PrefTotalPurchase";

// The deep-link startup-parameter keys.
static NSString *const kStartupKeyGenre = @"genre";
static NSString *const kStartupKeyPack = @"pack";
static NSString *const kStartupKeyCampaign = @"campaign";

// The alert-result dictionary keys.
static NSString *const kAlertKeyButtonMessage = @"btnMessage";
static NSString *const kAlertKeyTag = @"Tag";

// The signed-request POST keys.
static NSString *const kPostKeyAge = @"age";
static NSString *const kPostKeySum = @"sum";
static NSString *const kPostKeyTermID = @"term_id";

// The download-name-list entry keys (the second element flags an extend item).
static const NSInteger kDownloadNameKindRegular = 0;
static const NSInteger kDownloadNameKindExtend = 1;

// The server-response dictionary keys.
static NSString *const kResponseKeyStatus = @"status";
static NSString *const kResponseKeySum = @"sum";
static NSString *const kResponseKeyErrorMessage = @"err_message";

// The initial-total seeded when the player agrees to the age gate at the unset limit.
static const int kInitialTotalPurchase = 100;

// The purchase-manager error domain and its per-code messages.
static NSString *const kPurchaseErrorDomain = @"jp.konami.PurchaseManagerErrorDomain";

// The localised-string keys this container raises.
static NSString *const kLocKeyOK = @"OK";
static NSString *const kLocKeyCancel = @"Cancel";
static NSString *const kLocKeyDownload = @"DOWNLOAD";
static NSString *const kLocKeyError = @"Error";
static NSString *const kLocKeyProcessing = @"Processing...";
static NSString *const kLocKeyNetworkErrorMessage = @"NetworkErrorMsg";
static NSString *const kLocKeyServerErrorMessage = @"ServerErrorMsg";
static NSString *const kLocKeyReceiptVerifyErrorMessage = @"ReceiptVerifyErrorMsg";
static NSString *const kLocKeyDownloadErrorMessage = @"DownloadErrorMsg";
static NSString *const kLocKeyCannotPurchaseMessage = @"CannotPurchaseMsg";
static NSString *const kLocKeyAlreadyPurchasedMessage = @"AlreadyPurchasedMsg";
static NSString *const kLocKeyPurchaseCancelMessage = @"PurchaseCancelMsg(%@)";
static NSString *const kLocKeyRestoreCancelMessage = @"RestoreCancelMsg(%@)";
static NSString *const kLocKeyRestorePurchases = @"Restorepurchases";
static NSString *const kLocKeyRestoreMessage = @"RestoreMessage";
static NSString *const kLocKeyRestoreCompleteTitle = @"RestoreCompleteTitle";
static NSString *const kLocKeyRestoreCompleteMessage = @"RestoreCompleteMsg";
static NSString *const kLocKeyRestoreNothingTitle = @"RestoreNothingTitle";
static NSString *const kLocKeyRestoreNothingMessage = @"RestoreNothingMsg";
static NSString *const kLocKeyDownloading = @"Downloading %@ ...";
static NSString *const kLocKeyDownloadingAddition = @"Downloading %@ (addition item) ...";
static NSString *const kEmptyValue = @"";

// The wrapping "%@\n(%@)" applied to a localised message and the error's description.
static NSString *const kMessageDescriptionFormat = @"%@\n(%@)";

// The literal alert strings shipped in the binary (not localised-string keys).
static NSString *const kAgeConfirmTitle = @"年齢確認";
static NSString *const kAgeConfirmMessage =
    @"有料サービスのご利用にあたり、\n年齢の確認をお願いしております。";
static NSString *const kAgeOption15AndUnder = @"15歳以下(5000円/月)";
static NSString *const kAgeOption20AndUnder = @"20歳未満(20000円/月)";
static NSString *const kAgeOption20AndOver = @"20歳以上(無制限)";
static NSString *const kLimitReachedTitle = @"制限超過";
static NSString *const kLimitReachedMessage =
    @"今月はこれ以上購入できません。月が変わってからストアに入り直すと購入が可能になります。";
static NSString *const kNetworkErrorTitle = @"通信エラー";
static NSString *const kCommRetryMessage = @"通信に失敗しました\n再度通信を行います";
static NSString *const kMissionCheckFailedMessage = @"通信に失敗しました\n再度通信を行います";
static NSString *const kAgeRegisterFailedMessage =
    @"年齢登録の通信に失敗しました。再度購入処理から行ってください";

// The affiliate fall-back URL opened when the mission-error alert's link button is tapped.
static NSString *const kKonamiURL = @"http://www.konami.jp/";

@implementation StoreViewController {
    StoreMainViewController *storeMainViewCtrl;
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

@synthesize startupParameters = _startupParameters;
@synthesize modalDialog = _modalDialog;

#pragma mark - Init and initial load

/** @ghidraAddress 0x89460 */
- (instancetype)init {
    self = [super init];
    if (self) {
        storeMainViewCtrl = [[StoreMainViewController alloc] initWithParent:self];
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

        self.viewControllers =
            @[ storeMainNavCtrl, purchasedNavCtrl, manageNavCtrl, campaignNavCtrl ];
    }
    return self;
}

/** @ghidraAddress 0x89848 */
- (void)firstStoreItemLoad {
    NSString *genre = [self.startupParameters stringForKey:kStartupKeyGenre];
    if (genre) {
        [storeMainViewCtrl loadInitialPacklistWithGenre:genre.integerValue];
    } else {
        NSString *pack = [self.startupParameters stringForKey:kStartupKeyPack];
        [storeMainViewCtrl loadInitialPacklist:pack.integerValue];
    }
    NSString *campaign = [self.startupParameters stringForKey:kStartupKeyCampaign];
    if (campaign) {
        [campaignViewCtrl initialCampaignID:campaign.integerValue];
        self.selectedViewController = self.viewControllers[StoreTabIndexCampaign];
    }
}

/** @ghidraAddress 0x899ec */
- (void)loadInitialStoreInfo {
    [UIApplication.sharedApplication endIgnoringInteractionEvents];
    if (![EditorIDManager isExistEditorID]) {
        idManager = [[EditorIDManager alloc] initWithDelegate:self];
        return;
    }
    CGRect screen = UIScreen.mainScreen.bounds;
    CGFloat navHeight = storeMainNavCtrl.navigationBar.bounds.size.height;
    CGFloat tabHeight = self.tabBar.bounds.size.height;

#ifdef ENABLE_PATCHES
    // Preservation patch, not in the binary. This cover runs from the navigation bar to the bottom
    // of the screen, so it lies over the tab bar too, and the server-error label is added to it.
    // The store's servers are gone, so that error path is now the normal one: the cover comes up,
    // dims the whole store and takes every touch, and the tabs can no longer be tapped
    // (screenshots/IMG_0201.PNG). Stop it short of the tab bar so the tabs stay reachable. The
    // routine already computes this same inset for the agreement board's centre just below.
    usrPolicyView =
        [[UIView alloc] initWithFrame:CGRectMake(screen.origin.x,
                                                 navHeight,
                                                 screen.size.width,
                                                 (screen.size.height - navHeight) - tabHeight)];
#else
    usrPolicyView = [[UIView alloc] initWithFrame:CGRectMake(screen.origin.x,
                                                             navHeight,
                                                             screen.size.width,
                                                             screen.size.height - navHeight)];
#endif
    [usrPolicyView setOpaque:NO];
    // The original used colorWithWhite:alpha: with black (white 0).
    usrPolicyView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kCoverAlpha];
    [usrPolicyView setAlpha:0.0];

    CGFloat boardHeight = (screen.size.height - navHeight) - tabHeight;
    LicenseAgreementView *board =
        [[LicenseAgreementView alloc] init:self keyString:kPrefAgreeChallengePolicyVersion];
    board.center = CGPointMake(screen.size.width * 0.5, boardHeight * 0.5);
    board.weakCoverView = usrPolicyView;
    [usrPolicyView addSubview:board];
    [self.view addSubview:usrPolicyView];
}

/** @ghidraAddress 0x8a188 */
- (void)loadView {
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    [super loadView];
    self.view.contentScaleFactor = UIScreen.mainScreen.scale;
    CGRect screen = UIScreen.mainScreen.bounds;

    coverView = [[UIView alloc] initWithFrame:screen];
    [coverView setOpaque:NO];
    // The original used colorWithWhite:alpha: with black (white 0).
    coverView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kCoverAlpha];

    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    if (isPad) {
        _modalDialog = [[StoreDialogView alloc]
            initWithFrame:CGRectMake(0.0, 0.0, kDialogWidthPad, kDialogHeightPad)];
        self.modalDialog.labelMessage.font = [UIFont systemFontOfSize:kDialogFontSizePad];
    } else {
        _modalDialog = [[StoreDialogView alloc]
            initWithFrame:CGRectMake(0.0, 0.0, kDialogWidthPhone, kDialogHeightPhone)];
        self.modalDialog.labelMessage.font = [UIFont systemFontOfSize:kDialogFontSizePhone];
    }
    self.modalDialog.center = CGPointMake(screen.size.width * 0.5, screen.size.height * 0.5);
    [coverView addSubview:self.modalDialog];
}

#pragma mark - Store end

/** @ghidraAddress 0x8a584 */
- (void)storeEnd:(id)sender {
    [storeMainViewCtrl storeClose];
    [JubeatAppDelegate.appDelegate.rootViewCtrl endStore];
}

#pragma mark - Modal dialog

/** @ghidraAddress 0x8a604 */
- (void)showModalDialog:(id<StoreDialogViewDelegate>)delegate {
    [coverView setAlpha:0.0];
    [self.view addSubview:coverView];
    [self.modalDialog.indicatorView startAnimating];
    [self.modalDialog.buttonAbort setEnabled:NO];
    self.modalDialog.delegate = delegate;

    __weak UIView *weakCover = coverView;
    __weak StoreDialogView *weakDialog = self.modalDialog;
    [UIView animateWithDuration:kDialogFadeDuration
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          /** @ghidraAddress 0x8a8a0 */
          [weakCover setAlpha:1.0];
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x8a8ec */
          [weakDialog.buttonAbort setEnabled:YES];
        }];
}

/** @ghidraAddress 0x8a958 */
- (void)hideModalDialog {
    [self.modalDialog.buttonAbort setEnabled:NO];
    self.modalDialog.delegate = nil;

    __weak UIView *weakCover = coverView;
    __weak StoreDialogView *weakDialog = self.modalDialog;
    [UIView animateWithDuration:kDialogFadeDuration
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          /** @ghidraAddress 0x8ab68 */
          [weakCover setAlpha:0.0];
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x8abb4 */
          [weakDialog.indicatorView stopAnimating];
          [weakCover removeFromSuperview];
        }];
}

#pragma mark - Download queue

/** @ghidraAddress 0x8ac90 */
- (void)startDownloadMusics:(int)packID {
    NSArray *musicInfos = purchasingPackInfo.musicInfos;
    for (StoreMusicInfo *music in musicInfos) {
        [StoreMusicListManager.sharedManager addMusic:music];
        if (music) {
            [StoreMusicListManager.sharedManager addMusic:music];
        }
        if (music.extendMusicID != 0) {
            [StoreMusicListManager.sharedManager addMusic:music.getExtendInfo];
        }
    }
    [StoreMusicListManager.sharedManager saveMusicList];

    if (self.selectedViewController == storeMainNavCtrl) {
        [storeMainViewCtrl updatePurchaseStateForPackID:packID];
    } else if (self.selectedViewController == purchasedNavCtrl) {
        [purchasedViewCtrl updatePurchaseStateForPackID:packID];
    }

    NSMutableArray *tasks = [NSMutableArray arrayWithCapacity:musicInfos.count];
    downloadNameList = [NSMutableArray arrayWithCapacity:musicInfos.count];
    for (StoreMusicInfo *music in musicInfos) {
        NSString *path = [StoreUtil filePathForMusicID:(unsigned int)music.musicID];
        BOOL isDirectory = NO;
        if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] ||
            isDirectory) {
            [tasks addObject:[[StoreDownloadTask alloc] initWithURL:music.itemURL path:path]];
            [downloadNameList addObject:@[ music.name, @(kDownloadNameKindRegular) ]];
        }
        if (music.extendMusicID != 0) {
            NSString *extendPath = [StoreUtil filePathForMusicID:(unsigned int)music.extendMusicID];
            if ((![NSFileManager.defaultManager fileExistsAtPath:extendPath
                                                     isDirectory:&isDirectory] ||
                 isDirectory) &&
                music.extendItemURL) {
                [tasks addObject:[[StoreDownloadTask alloc] initWithURL:music.extendItemURL
                                                                   path:extendPath]];
                [downloadNameList addObject:@[ music.name, @(kDownloadNameKindExtend) ]];
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

/** @ghidraAddress 0x8b5cc */
- (void)startDownloadExtendMusics:(int)packID {
    NSArray *musicInfos = purchasingPackInfo.musicInfos;
    for (StoreMusicInfo *music in musicInfos) {
        if (music) {
            [StoreMusicListManager.sharedManager addMusic:music];
        }
        if (music.extendMusicID != 0) {
            [StoreMusicListManager.sharedManager addMusic:music.getExtendInfo];
        }
    }
    [StoreMusicListManager.sharedManager saveMusicList];

    NSMutableArray *tasks = [NSMutableArray arrayWithCapacity:musicInfos.count];
    downloadNameList = [NSMutableArray arrayWithCapacity:musicInfos.count];
    for (StoreMusicInfo *music in musicInfos) {
        NSString *path = [StoreUtil filePathForMusicID:(unsigned int)music.musicID];
        if (music.extendMusicID != 0) {
            BOOL isDirectory = NO;
            if ([NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] &&
                !isDirectory) {
                NSString *extendPath =
                    [StoreUtil filePathForMusicID:(unsigned int)music.extendMusicID];
                if ((![NSFileManager.defaultManager fileExistsAtPath:extendPath
                                                         isDirectory:&isDirectory] ||
                     isDirectory) &&
                    music.extendItemURL) {
                    [tasks addObject:[[StoreDownloadTask alloc] initWithURL:music.extendItemURL
                                                                       path:extendPath]];
                    [downloadNameList addObject:@[ music.name, @(kDownloadNameKindExtend) ]];
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

#pragma mark - Purchase entry points

/** @ghidraAddress 0x8bd3c */
- (void)performRestore:(id)sender {
    NSString *title = [NSBundle.mainBundle localizedStringForKey:kLocKeyRestorePurchases
                                                           value:kEmptyValue
                                                           table:nil];
    NSString *message = [NSBundle.mainBundle localizedStringForKey:kLocKeyRestoreMessage
                                                             value:kEmptyValue
                                                             table:nil];
    NSString *cancel = [NSBundle.mainBundle localizedStringForKey:kLocKeyCancel
                                                            value:kEmptyValue
                                                            table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                        value:kEmptyValue
                                                        table:nil];
    [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                     delegate:self
                                          tag:kAlertTagRestore
                                        title:title
                                          msg:message
                                       cancel:cancel
                                      btnText:@[ ok ]
                                         show:YES];
}

/** @ghidraAddress 0x8bf88 */
- (void)detailViewStartRedownload:(StoreDetailViewControllerV2 *)packInfo {
    purchasingPackInfo = (StorePackInfo *)packInfo;
    addPurchasePackInfo = nil;
    NSString *message = [NSBundle.mainBundle localizedStringForKey:kLocKeyAlreadyPurchasedMessage
                                                             value:kEmptyValue
                                                             table:nil];
    NSString *title = [NSBundle.mainBundle localizedStringForKey:kLocKeyDownload
                                                           value:kEmptyValue
                                                           table:nil];
    NSString *cancel = [NSBundle.mainBundle localizedStringForKey:kLocKeyCancel
                                                            value:kEmptyValue
                                                            table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                        value:kEmptyValue
                                                        table:nil];
    [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                     delegate:self
                                          tag:kAlertTagRedownload
                                        title:title
                                          msg:message
                                       cancel:cancel
                                      btnText:@[ ok ]
                                         show:YES];
}

/** @ghidraAddress 0x8c218 */
- (BOOL)checkAttainLimitPurchase:(SKProduct *)product {
    int total = JubeatAppDelegate.appDelegate.totalPurchaseAmount;
    NSInteger limitType =
        [NSUserDefaults.standardUserDefaults integerForKey:kPrefPurchaseLimitType];
    int ceiling;
    if ((NSUInteger)limitType < 3) {
        ceiling = kPurchaseLimitYenCeilings[limitType];
    } else {
        ceiling = -1;
    }

    NSString *currency = [product.priceLocale objectForKey:NSLocaleCurrencyCode];
    if ([currency isEqualToString:@"JPY"]) {
        total += (int)product.price.integerValue;
    }

    BOOL alerted = NO;
    if (ceiling >= 0 && ceiling < total) {
        if (limitType == kPurchaseLimitTypeAgeUnset) {
            NSString *cancel = [NSBundle.mainBundle localizedStringForKey:kLocKeyCancel
                                                                    value:kEmptyValue
                                                                    table:nil];
            [AlertViewManager.sharedManager
                makeAlert:kAlertTypePlain
                 delegate:self
                      tag:kAlertTagAgeRegister
                    title:kAgeConfirmTitle
                      msg:kAgeConfirmMessage
                   cancel:cancel
                  btnText:@[ kAgeOption15AndUnder, kAgeOption20AndUnder, kAgeOption20AndOver ]
                     show:YES];
        } else {
            NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                                value:kEmptyValue
                                                                table:nil];
            [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                             delegate:nil
                                                  tag:0
                                                title:kLimitReachedTitle
                                                  msg:kLimitReachedMessage
                                               cancel:ok
                                              btnText:nil
                                                 show:YES];
        }
        alerted = YES;
    }
    return alerted;
}

/** @ghidraAddress 0x8c594 */
- (void)detailViewStartPurchase:(StoreDetailViewControllerV2 *)packInfo {
    if (!PurchaseManager.isPurchasable || !((StorePackInfo *)packInfo).product) {
        NSString *message = [NSBundle.mainBundle localizedStringForKey:kLocKeyCannotPurchaseMessage
                                                                 value:kEmptyValue
                                                                 table:nil];
        NSString *title = [NSBundle.mainBundle localizedStringForKey:kLocKeyError
                                                               value:kEmptyValue
                                                               table:nil];
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                            value:kEmptyValue
                                                            table:nil];
        [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                         delegate:nil
                                              tag:0
                                            title:title
                                              msg:message
                                           cancel:ok
                                          btnText:nil
                                             show:YES];
        return;
    }

    purchasingPackInfo = (StorePackInfo *)packInfo;
    addPurchasePackInfo = (StorePackInfo *)packInfo;
    if ([self checkAttainLimitPurchase:((StorePackInfo *)packInfo).product]) {
        return;
    }
    [self.modalDialog layout:YES];
    NSString *processing = [NSBundle.mainBundle localizedStringForKey:kLocKeyProcessing
                                                                value:kEmptyValue
                                                                table:nil];
    [self.modalDialog.labelMessage setText:processing];
    [self showModalDialog:self];
    PurchaseManager.sharedManager.delegate = self;
    [PurchaseManager.sharedManager beginPurchase:((StorePackInfo *)packInfo).product];
}

/** @ghidraAddress 0x8c974 */
- (void)detailViewStartExtendDownload:(StorePackInfo *)packInfo {
    purchasingPackInfo = packInfo;
    [self showModalDialog:self];
    [self startDownloadExtendMusics:(int)purchasingPackInfo.packID];
}

#pragma mark - PurchaseManagerDelegate

/** @ghidraAddress 0x8c9fc */
- (void)purchaseSucceeded:(NSString *)productID {
    PurchaseManager.sharedManager.delegate = nil;
    if (self.selectedViewController == storeMainNavCtrl) {
        [purchasedViewCtrl resetPurchasedList];
    }
    int packID = [StoreUtil packIDForProductID:productID];
    [self startDownloadMusics:packID];
    [campaignViewCtrl refreshUnlockTable];
    addPurchasePackInfo = nil;
}

/** @ghidraAddress 0x8cb0c */
- (void)purchaseFailed:(NSString *)productID error:(NSError *)error {
    [self hideModalDialog];
    NSString *message;
    if (![error.domain isEqualToString:kPurchaseErrorDomain]) {
        NSString *cancel = [NSBundle.mainBundle localizedStringForKey:kLocKeyPurchaseCancelMessage
                                                                value:kEmptyValue
                                                                table:nil];
        message = [NSString stringWithFormat:cancel, error.localizedDescription];
    } else {
        NSString *title;
        NSInteger code = error.code;
        if (code == 2) {
            message = [NSBundle.mainBundle localizedStringForKey:kLocKeyServerErrorMessage
                                                           value:kEmptyValue
                                                           table:nil];
            title = [NSBundle.mainBundle localizedStringForKey:kLocKeyError
                                                         value:kEmptyValue
                                                         table:nil];
        } else if (code == 3) {
            message = [NSBundle.mainBundle localizedStringForKey:kLocKeyReceiptVerifyErrorMessage
                                                           value:kEmptyValue
                                                           table:nil];
            int packID = [StoreUtil packIDForProductID:productID];
            if (self.selectedViewController == storeMainNavCtrl) {
                [storeMainViewCtrl updatePurchaseStateForPackID:packID];
            } else if (self.selectedViewController == purchasedNavCtrl) {
                [purchasedViewCtrl updatePurchaseStateForPackID:packID];
            }
            title = [NSBundle.mainBundle localizedStringForKey:kLocKeyError
                                                         value:kEmptyValue
                                                         table:nil];
        } else {
            // Code 1 and any other code use the network-error message.
            message = [NSBundle.mainBundle localizedStringForKey:kLocKeyNetworkErrorMessage
                                                           value:kEmptyValue
                                                           table:nil];
            title = [NSBundle.mainBundle localizedStringForKey:kLocKeyError
                                                         value:kEmptyValue
                                                         table:nil];
        }
        message = [NSString
            stringWithFormat:kMessageDescriptionFormat, message, error.localizedDescription];
        (void)title; // Yes, the binary computes this per-branch error title and then discards it.
    }

    PurchaseManager.sharedManager.delegate = nil;
    purchasingPackInfo = nil;
    addPurchasePackInfo = nil;
    NSString *alertTitle = [NSBundle.mainBundle localizedStringForKey:kLocKeyError
                                                                value:kEmptyValue
                                                                table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                        value:kEmptyValue
                                                        table:nil];
    [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                     delegate:nil
                                          tag:0
                                        title:alertTitle
                                          msg:message
                                       cancel:ok
                                      btnText:nil
                                         show:YES];
}

/** @ghidraAddress 0x8d08c */
- (void)restoreSucceeded {
    PurchaseManager.sharedManager.delegate = nil;
    [self hideModalDialog];
    NSString *title = [NSBundle.mainBundle localizedStringForKey:kLocKeyRestoreCompleteTitle
                                                           value:kEmptyValue
                                                           table:nil];
    NSString *message = [NSBundle.mainBundle localizedStringForKey:kLocKeyRestoreCompleteMessage
                                                             value:kEmptyValue
                                                             table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                        value:kEmptyValue
                                                        table:nil];
    [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                     delegate:self
                                          tag:kAlertTagRestoreComplete
                                        title:title
                                          msg:message
                                       cancel:ok
                                      btnText:nil
                                         show:YES];
    [campaignViewCtrl refreshUnlockTable];
}

/** @ghidraAddress 0x8d288 */
- (void)restoreFailed:(NSError *)error {
    PurchaseManager.sharedManager.delegate = nil;
    [self hideModalDialog];
    NSString *cancel = [NSBundle.mainBundle localizedStringForKey:kLocKeyRestoreCancelMessage
                                                            value:kEmptyValue
                                                            table:nil];
    NSString *message = [NSString stringWithFormat:cancel, error.localizedDescription];
    NSString *title = [NSBundle.mainBundle localizedStringForKey:kLocKeyError
                                                           value:kEmptyValue
                                                           table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                        value:kEmptyValue
                                                        table:nil];
    [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                     delegate:nil
                                          tag:0
                                        title:title
                                          msg:message
                                       cancel:ok
                                      btnText:nil
                                         show:YES];
}

/** @ghidraAddress 0x8d4e4 */
- (void)restoreNothing {
    PurchaseManager.sharedManager.delegate = nil;
    [self hideModalDialog];
    NSString *title = [NSBundle.mainBundle localizedStringForKey:kLocKeyRestoreNothingTitle
                                                           value:kEmptyValue
                                                           table:nil];
    NSString *message = [NSBundle.mainBundle localizedStringForKey:kLocKeyRestoreNothingMessage
                                                             value:kEmptyValue
                                                             table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                        value:kEmptyValue
                                                        table:nil];
    [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                     delegate:nil
                                          tag:0
                                        title:title
                                          msg:message
                                       cancel:ok
                                      btnText:nil
                                         show:YES];
}

/** @ghidraAddress 0x8d6c8 */
- (void)firstRestore {
    [self.modalDialog layout:YES];
    NSString *processing = [NSBundle.mainBundle localizedStringForKey:kLocKeyProcessing
                                                                value:kEmptyValue
                                                                table:nil];
    [self.modalDialog.labelMessage setText:processing];
    [self showModalDialog:self];
    PurchaseManager.sharedManager.delegate = self;
    [PurchaseManager.sharedManager beginRestore];
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0x8d850 */
- (void)alertSelect:(NSDictionary *)info {
    int button = [info[kAlertKeyButtonMessage] intValue];
    int tag = [info[kAlertKeyTag] intValue];

    if (tag == kAlertTagRestoreComplete) {
        [storeMainViewCtrl refresh];
        [purchasedViewCtrl reloadPurchasedList];
        return;
    }
    if (tag == kAlertTagRestore) {
        if (button == kAlertButtonAccept) {
            [self.modalDialog layout:YES];
            NSString *processing = [NSBundle.mainBundle localizedStringForKey:kLocKeyProcessing
                                                                        value:kEmptyValue
                                                                        table:nil];
            [self.modalDialog.labelMessage setText:processing];
            [self showModalDialog:self];
            PurchaseManager.sharedManager.delegate = self;
            [PurchaseManager.sharedManager beginRestore];
        }
        return;
    }
    if (tag == kAlertTagRedownload) {
        if (button == kAlertButtonAccept && purchasingPackInfo) {
            NSString *productID = [StoreUtil productIDForPackID:(int)purchasingPackInfo.packID];
            if (![PurchaseManager.sharedManager isPending:productID]) {
                [self showModalDialog:self];
                [self startDownloadMusics:(int)purchasingPackInfo.packID];
            } else {
                [self.modalDialog layout:YES];
                NSString *processing = [NSBundle.mainBundle localizedStringForKey:kLocKeyProcessing
                                                                            value:kEmptyValue
                                                                            table:nil];
                [self.modalDialog.labelMessage setText:processing];
                [self showModalDialog:self];
                PurchaseManager.sharedManager.delegate = self;
                [PurchaseManager.sharedManager beginPurchase:purchasingPackInfo.product];
            }
        }
        return;
    }
    if (tag == kAlertTagMissionCheck) {
        [missionCheckDownloader startDownloading];
        return;
    }
    if (tag == kAlertTagAgeRegister && button != 0) {
        if (button > 3) {
            NSURL *url = [NSURL URLWithString:kKonamiURL];
            [UIApplication.sharedApplication openURL:url];
            return;
        }
        selectedPurchaseAgeType = button;
        NSDictionary *post = @{kPostKeyAge : @(button - 1)};
        sessionDownloader = [[SessionDownloader alloc] initWithURL:[ScratchUtil registUserAgeURL]
                                                    postDictionary:post
                                                          delegate:self];
        [sessionDownloader setTag:kSessionTagAgeThenPurchase];
        [sessionDownloader startDownloading];
    }
}

#pragma mark - StoreDialogViewDelegate

/** @ghidraAddress 0x8dfa8 */
- (void)storeDialogCancel:(id)dialogView {
    [dlManager cancel];
    dlManager = nil;
    [self hideModalDialog];
    int packID = (int)purchasingPackInfo.packID;
    if (self.selectedViewController == storeMainNavCtrl) {
        [storeMainViewCtrl updatePurchaseStateForPackID:packID];
    } else if (self.selectedViewController == purchasedNavCtrl) {
        [purchasedViewCtrl updatePurchaseStateForPackID:packID];
    }
}

#pragma mark - StoreDownloadManagerDelegate

/** @ghidraAddress 0x8e0c4 */
- (void)downloadManagerStartTask:(StoreDownloadManager *)manager {
    NSArray *entry = downloadNameList[dlManager.currentIndex];
    NSString *format = [NSBundle.mainBundle localizedStringForKey:kLocKeyDownloading
                                                            value:kEmptyValue
                                                            table:nil];
    NSString *text = [NSString stringWithFormat:format, entry[0]];
    if ([entry[1] intValue] == kDownloadNameKindExtend) {
        format = [NSBundle.mainBundle localizedStringForKey:kLocKeyDownloadingAddition
                                                      value:kEmptyValue
                                                      table:nil];
        text = [NSString stringWithFormat:format, entry[0]];
    }
    [self.modalDialog.labelMessage setText:text];
}

/** @ghidraAddress 0x8e350 */
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager {
    dlManager = nil;
    [self hideModalDialog];
}

/** @ghidraAddress 0x8e38c */
- (void)downloadManagerFailed:(StoreDownloadManager *)manager {
    dlManager = nil;
    int packID = (int)purchasingPackInfo.packID;
    if (self.selectedViewController == storeMainNavCtrl) {
        [storeMainViewCtrl updatePurchaseStateForPackID:packID];
    } else if (self.selectedViewController == purchasedNavCtrl) {
        [purchasedViewCtrl updatePurchaseStateForPackID:packID];
    }
    [self hideModalDialog];
    NSString *title = [NSBundle.mainBundle localizedStringForKey:kLocKeyError
                                                           value:kEmptyValue
                                                           table:nil];
    NSString *message = [NSBundle.mainBundle localizedStringForKey:kLocKeyDownloadErrorMessage
                                                             value:kEmptyValue
                                                             table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                        value:kEmptyValue
                                                        table:nil];
    [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                     delegate:nil
                                          tag:0
                                        title:title
                                          msg:message
                                       cancel:ok
                                      btnText:nil
                                         show:YES];
}

/** @ghidraAddress 0x8e5f8 */
- (void)downloadManagerProceed:(StoreDownloadManager *)manager {
    [self.modalDialog.progressView setProgress:dlManager.overallProgress];
}

#pragma mark - Deep-link detail opening

/** @ghidraAddress 0x8e680 */
- (void)openDetail:(NSNumber *)packID {
    [AlertViewManager.sharedManager closeAlert];
    [storeMainViewCtrl addOpenDetail:packID.integerValue];
    if (self.selectedViewController != storeMainNavCtrl) {
        self.selectedViewController = self.viewControllers[StoreTabIndexMain];
    }
}

/** @ghidraAddress 0x8e7cc */
- (void)openCampaignDetail:(NSNumber *)campaignID {
    [AlertViewManager.sharedManager closeAlert];
    [campaignViewCtrl addOpenDetail:campaignID.integerValue];
    if (self.selectedViewController != campaignNavCtrl) {
        self.selectedViewController = self.viewControllers[StoreTabIndexCampaign];
    }
}

/** @ghidraAddress 0x8e918 */
- (void)storeClose {
    [storeMainViewCtrl storeClose];
    [purchasedViewCtrl storeClose];
    [manageViewCtrl storeClose];
    [campaignViewCtrl storeClose];
    [AlertViewManager.sharedManager closeAlert];
}

#pragma mark - Cover view and agreement gate

/** @ghidraAddress 0x8e9bc */
- (void)becomeCoverView {
    __weak UIView *weakCover = usrPolicyView;
    [usrPolicyView setAlpha:0.0];
    [UIView animateWithDuration:kCoverFadeInDuration
                     animations:^{
                       /** @ghidraAddress 0x8eab8 */
                       [weakCover setAlpha:1.0];
                     }
                     completion:^(BOOL __attribute__((unused)) finished){
                         /** @ghidraAddress 0x8eb04 */
                     }];
}

/** @ghidraAddress 0x8eb08 */
- (void)resignCoverView {
    __weak UIView *weakCover = usrPolicyView;
    [UIView animateWithDuration:kCoverFadeOutDuration
                     animations:^{
                       /** @ghidraAddress 0x8ebd4 */
                       [weakCover setAlpha:0.0];
                     }
                     completion:^(BOOL __attribute__((unused)) finished){
                         /** @ghidraAddress 0x8ec20 */
                     }];
}

/** @ghidraAddress 0x8ec24 */
- (void)dispErrorLabel:(NSString *)msg {
    CGRect frame = usrPolicyView.frame;
    CGFloat labelHeight = frame.size.height - kErrorLabelBottomInset;
    UILabel *label =
        [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, frame.size.width, labelHeight)];
    label.backgroundColor = UIColor.clearColor;
    label.font = [UIFont boldSystemFontOfSize:kErrorLabelFontSize];
    label.textColor = UIColor.blackColor;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.center = CGPointMake(
        usrPolicyView.frame.size.width * 0.5,
        (CGFloat)((int)(usrPolicyView.frame.size.height * 0.5) - kErrorLabelCentreLift));
    if (!msg) {
        msg = [NSBundle.mainBundle localizedStringForKey:kLocKeyNetworkErrorMessage
                                                   value:kEmptyValue
                                                   table:nil];
    }
    label.text = msg;
    [usrPolicyView addSubview:label];
    [self becomeCoverView];
}

/** @ghidraAddress 0x8ee9c */
- (void)agreementSuccess:(id)sender {
    NSInteger limitType =
        [NSUserDefaults.standardUserDefaults integerForKey:kPrefPurchaseLimitType];
    // The binary reads PrefTotalPurchase here and discards it.
    (void)[NSUserDefaults.standardUserDefaults integerForKey:kPrefTotalPurchase];
    if (limitType == kPurchaseLimitTypeAgeUnset) {
        NSDictionary *post = @{kPostKeySum : @(kInitialTotalPurchase)};
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
    [sessionDownloader setTag:(limitType != kPurchaseLimitTypeAgeUnset)];
    [sessionDownloader startDownloading];
}

/** @ghidraAddress 0x8fda4 */
- (void)agreementFailed:(id)sender {
    __weak UIView *weakSender = sender;
    [sender setAlpha:1.0];
    [UIView animateWithDuration:kCoverFadeOutDuration
        animations:^{
          /** @ghidraAddress 0x8feec */
          [weakSender setAlpha:0.0];
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x8ff38 */
          [self storeEnd:nil];
        }];
}

/** @ghidraAddress 0x8ff5c */
- (void)becomePolicyAgreement:(id)sender {
    [self becomeCoverView];
}

/** @ghidraAddress 0x8ff68 */
- (void)agreementError:(id)sender msgStr:(NSString *)msg {
    CGRect frame = usrPolicyView.frame;
    CGFloat labelHeight = frame.size.height - kErrorLabelBottomInset;
    UILabel *label =
        [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, frame.size.width, labelHeight)];
    label.backgroundColor = UIColor.clearColor;
    label.font = [UIFont boldSystemFontOfSize:kErrorLabelFontSize];
    label.textColor = UIColor.blackColor;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.center = CGPointMake(
        usrPolicyView.frame.size.width * 0.5,
        (CGFloat)((int)(usrPolicyView.frame.size.height * 0.5) - kErrorLabelCentreLift));
    if (!msg) {
        msg = [NSBundle.mainBundle localizedStringForKey:kLocKeyNetworkErrorMessage
                                                   value:kEmptyValue
                                                   table:nil];
    }
    label.text = msg;
    [usrPolicyView addSubview:label];
    [self becomeCoverView];
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x8f170 */
- (void)downloaderFinished:(id)downloader {
    NSDictionary *json = [(Downloader *)downloader getDataInJSON];
    int status;
    if (!json[kResponseKeyStatus]) {
        status = -1;
    } else {
        status = [json[kResponseKeyStatus] intValue];
        if (status == kServerStatusUpdateRequired) {
            [AlertViewManager.sharedManager showUpdateAlert];
        }
    }

    switch ([(Downloader *)downloader tag]) {
    case kSessionTagTotalPurchase:
        if (status == kServerStatusOK) {
            [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefTotalPurchase];
            [JubeatAppDelegate.appDelegate setTotalAmount:[json[kResponseKeySum] intValue]];
            [self createStoreMissionDownloader];
            if (missionCheckDownloader) {
                [missionCheckDownloader setTag:kSessionTagMissionCheck];
                [missionCheckDownloader startDownloading];
            } else {
                [self resignCoverView];
                [self firstStoreItemLoad];
            }
        } else {
            NSString *message = [NSBundle.mainBundle localizedStringForKey:kLocKeyServerErrorMessage
                                                                     value:kEmptyValue
                                                                     table:nil];
            if (json[kResponseKeyErrorMessage]) {
                message = json[kResponseKeyErrorMessage];
            }
            [self dispErrorLabel:message];
        }
        sessionDownloader = nil;
        break;
    case kSessionTagUserAge:
        if (status == kServerStatusOK) {
            sessionDownloader = nil;
            NSInteger total =
                [NSUserDefaults.standardUserDefaults integerForKey:kPrefTotalPurchase];
            NSDictionary *post = @{kPostKeySum : @(total)};
            sessionDownloader =
                [[SessionDownloader alloc] initWithURL:[ScratchUtil registTotalPurchaseURL]
                                        postDictionary:post
                                              delegate:self];
            [sessionDownloader setTag:kSessionTagTotalPurchase];
            [sessionDownloader startDownloading];
        } else {
            NSString *message = [NSBundle.mainBundle localizedStringForKey:kLocKeyServerErrorMessage
                                                                     value:kEmptyValue
                                                                     table:nil];
            if (json[kResponseKeyErrorMessage]) {
                message = json[kResponseKeyErrorMessage];
            }
            [self dispErrorLabel:message];
            sessionDownloader = nil;
        }
        break;
    case kSessionTagAgeThenPurchase:
        [NSUserDefaults.standardUserDefaults setInteger:selectedPurchaseAgeType
                                                 forKey:kPrefPurchaseLimitType];
        [self detailViewStartPurchase:(StoreDetailViewControllerV2 *)purchasingPackInfo];
        break;
    case kSessionTagMissionCheck:
        if (status == kServerStatusMissionError) {
            NSString *message = json[kResponseKeyErrorMessage];
            if (!message) {
                message = kMissionCheckFailedMessage;
            }
            NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                                value:kEmptyValue
                                                                table:nil];
            [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                             delegate:self
                                                  tag:kAlertTagMissionCheck
                                                title:kEmptyValue
                                                  msg:message
                                               cancel:ok
                                              btnText:nil
                                                 show:YES];
        } else if (status == kServerStatusOK) {
            [self resignCoverView];
            [self firstStoreItemLoad];
        }
        break;
    }
}

/** @ghidraAddress 0x8f8b8 */
- (void)downloaderError:(id)downloader {
    if ([(Downloader *)downloader tag] == kSessionTagMissionCheck) {
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                            value:kEmptyValue
                                                            table:nil];
        [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                         delegate:self
                                              tag:kAlertTagMissionCheck
                                            title:kEmptyValue
                                              msg:kMissionCheckFailedMessage
                                           cancel:ok
                                          btnText:nil
                                             show:YES];
    } else if ([(Downloader *)downloader tag] == kSessionTagAgeThenPurchase) {
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                            value:kEmptyValue
                                                            table:nil];
        [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                         delegate:nil
                                              tag:0
                                            title:kNetworkErrorTitle
                                              msg:kAgeRegisterFailedMessage
                                           cancel:ok
                                          btnText:nil
                                             show:YES];
    } else {
        NSDictionary *json = [(Downloader *)downloader getDataInJSON];
        NSString *message = [NSBundle.mainBundle localizedStringForKey:kLocKeyNetworkErrorMessage
                                                                 value:kEmptyValue
                                                                 table:nil];
        if (json[kResponseKeyErrorMessage]) {
            message = json[kResponseKeyErrorMessage];
        }
        CGRect frame = usrPolicyView.frame;
        CGFloat labelHeight = frame.size.height - kErrorLabelBottomInset;
        UILabel *label =
            [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, frame.size.width, labelHeight)];
        label.backgroundColor = UIColor.clearColor;
        label.font = [UIFont boldSystemFontOfSize:kErrorLabelFontSize];
        label.textColor = UIColor.blackColor;
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 0;
        label.center = CGPointMake(
            usrPolicyView.frame.size.width * 0.5,
            (CGFloat)((int)(usrPolicyView.frame.size.height * 0.5) - kErrorLabelCentreLift));
        if (!message) {
            message = [NSBundle.mainBundle localizedStringForKey:kLocKeyNetworkErrorMessage
                                                           value:kEmptyValue
                                                           table:nil];
        }
        label.text = message;
        [usrPolicyView addSubview:label];
        [self becomeCoverView];
    }
}

#pragma mark - EditorIDManagerDelegate

/** @ghidraAddress 0x89f10 */
- (void)successIDDownload:(id)manager {
    idManager = nil;
    CGRect screen = UIScreen.mainScreen.bounds;
    CGFloat navHeight = storeMainNavCtrl.navigationBar.bounds.size.height;
    CGFloat tabHeight = self.tabBar.bounds.size.height;

    usrPolicyView = [[UIView alloc] initWithFrame:CGRectMake(screen.origin.x,
                                                             navHeight,
                                                             screen.size.width,
                                                             screen.size.height - navHeight)];
    [usrPolicyView setOpaque:NO];
    [usrPolicyView setAlpha:0.0];
    // The original used colorWithWhite:alpha: with black (white 0).
    usrPolicyView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kCoverAlpha];

    CGFloat boardHeight = (screen.size.height - navHeight) - tabHeight;
    LicenseAgreementView *board =
        [[LicenseAgreementView alloc] init:self keyString:kPrefAgreeChallengePolicyVersion];
    board.center = CGPointMake(screen.size.width * kAgreementBoardWidthFraction, boardHeight * 0.5);
    board.weakCoverView = usrPolicyView;
    [usrPolicyView addSubview:board];
    [self.view addSubview:usrPolicyView];
}

/** @ghidraAddress 0x89cd4 */
- (void)errorIDDownload:(id)manager msgStr:(NSString *)msg {
    if (!msg || [msg isEqualToString:kEmptyValue]) {
        msg = [NSBundle.mainBundle localizedStringForKey:kLocKeyNetworkErrorMessage
                                                   value:kEmptyValue
                                                   table:nil];
    }
    CGRect screen = UIScreen.mainScreen.bounds;
    CGFloat navHeight = storeMainNavCtrl.navigationBar.bounds.size.height;
    usrPolicyView = [[UIView alloc] initWithFrame:CGRectMake(screen.origin.x,
                                                             navHeight,
                                                             screen.size.width,
                                                             screen.size.height - navHeight)];
    [usrPolicyView setOpaque:NO];
    // The original used colorWithWhite:alpha: with black (white 0).
    usrPolicyView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kCoverAlpha];
    [self.view addSubview:usrPolicyView];
    [self dispErrorLabel:msg];
}

#pragma mark - Mission achievement

/** @ghidraAddress 0x901e0 */
- (void)createStoreMissionDownloader {
    ChallengeMissionSheet *sheet = ChallengeStatus.sharedStatus.getSelectedMissionSheet;
    NSMutableArray *missions = [[NSMutableArray alloc] init];
    missionCheckDownloader = nil;
    // The loop bound is read from the freshly-created empty array, so the body never runs; kept
    // faithful to the binary.
    for (NSUInteger i = 0; i < missions.count; ++i) {
        ChallengeMissionTerms *terms = sheet.missionTable[i];
        if (terms.missionType == kMissionTypePurchaseUnlock) {
            ChallengeMissionAchieve *achieve = sheet.missionAchieveTable[i];
            if (achieve.missionState != kMissionStateCleared0 &&
                achieve.missionState != kMissionStateCleared1) {
                if (JubeatAppDelegate.appDelegate.bChallengeMode) {
                    [missions addObject:terms];
                }
            }
        }
    }

    if (missions.count != 0) {
        NSMutableArray *missionIDs = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < missions.count; ++i) {
            ChallengeMissionTerms *terms = missions[i];
            [missionIDs addObject:@(terms.missionID)];
        }
        NSDictionary *post = @{kPostKeyTermID : missionIDs};
        missionCheckDownloader =
            [[SessionDownloader alloc] initWithURL:[ScratchUtil getMissionAchieveCheckURL]
                                    postDictionary:post
                                          delegate:self];
    }
}

#pragma mark - View lifecycle

/** @ghidraAddress 0x90634 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x9066c */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x906a4 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x906dc */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x90714 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0x9074c */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation - 1 < 2;
}

/** @ghidraAddress 0x9075c */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

/** @ghidraAddress 0x90764 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
