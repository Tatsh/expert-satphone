#import "CubePurchaseView.h"

#import "AudioManager.h"
#import "ChallengeStatus.h"
#import "CubePurchaseInfo.h"
#import "EditorIDManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "MessageTextView.h"
#import "ScratchUtil.h"
#import "SessionDownloader.h"

// The close sound played when the purchase menu is dismissed.
static NSString *const kCloseSoundName = @"SD_CHALLENGE_CANCEL";

// The background plate and the three button images.
static NSString *const kBackgroundImageName = @"cube_pur_bg";
static NSString *const kCloseButtonImageName = @"scratch_btn_cancel";
static NSString *const kSptlButtonImageName = @"cube_pur_btn_SPTL";
static NSString *const kCubePolicyButtonImageName = @"cube_pur_btn_policy";

// The overlay URLs.
static NSString *const kSptlURLString = @"https://license.konami.com/TOKUSHO/license/index.html";
static NSString *const kKonamiURLString = @"http://www.konami.jp/";

// Request dictionary keys and values.
static NSString *const kRequestKeyUserID = @"user_id";
static NSString *const kRequestKeyTarget = @"target";
static NSString *const kRequestValueTargetJP = @"JP";
static NSString *const kPolicyKeyType = @"type";
static NSString *const kPolicyKeyRevision = @"revision";
static NSString *const kAgeKey = @"age";

// The cube-policy overlay board title.
static NSString *const kCubePolicyTitle = @"ゲーム内通貨利用規約";

// Response JSON keys.
static NSString *const kResponseKeyStatus = @"status";
static NSString *const kResponseKeyErrorMessage = @"err_message";
static NSString *const kResponseKeySum = @"sum";
static NSString *const kResponseKeyItem = @"item";

// StoreKit / currency keys.
static NSString *const kCurrencyCodeJPY = @"JPY";
static NSString *const kPrefPurchaseLimitType = @"PrefPurchaseLimitType";

// Localizable keys and the empty-value / empty-title placeholders.
static NSString *const kLocalizableKeyOK = @"OK";
static NSString *const kLocalizableKeyCancel = @"Cancel";
static NSString *const kLocalizableKeyServerErrorMsg = @"ServerErrorMsg";
static NSString *const kEmptyString = @"";

// Alert titles, messages, and buttons (Japanese).
static NSString *const kAgeConfirmTitle = @"年齢確認";
static NSString *const kAgeConfirmMessage =
    @"有料サービスのご利用にあたり、\n年齢の確認をお願いしております。";
static NSString *const kAgeButton15OrUnder = @"15歳以下(5000円/月)";
static NSString *const kAgeButtonUnder20 = @"20歳未満(20000円/月)";
static NSString *const kAgeButton20OrOver = @"20歳以上(無制限)";
static NSString *const kLimitExceededTitle = @"制限超過";
static NSString *const kLimitExceededMessage =
    @"今月はこれ以上購入できません。月が変わってからストアに入り直すと購入が可能になります。";
static NSString *const kProcessingMessage = @"処理中...";
static NSString *const kPurchaseCompleteMessage = @"購入処理が完了しました";
static NSString *const kJcubeFetchFailedMessage = @"jCubeリストの取得に失敗しました";
static NSString *const kNoItemsMessage = @"現在表示できるアイテムはありません";

// The one-character fallback the list error label is set to when the server sends no err_message.
static NSString *const kFallbackErrorText = @"j";

// The API tag attached to the cube-product-list request.
static const int kCubeListApiTag = 0x12;

// The downloader tags: 0 is the cube-product-list fetch, 1 is the age-registration submit.
static const int kDownloaderTagCubeList = 0;
static const int kDownloaderTagRegisterAge = 1;

// The keys of the info dictionary passed to -alertSelect:.
static NSString *const kAlertInfoKeyButton = @"btnMessage";
static NSString *const kAlertInfoKeyTag = @"Tag";

// The alert tags echoed back through -alertSelect:.
static const int kAlertTagPurchaseComplete = 1;
static const int kAlertTagAgeConfirm = 2;
static const int kAlertTagSessionError = 9999;

// The server status that signals a stale client / server error for this flow.
static const int kStatusServerError = 0x18b53;

// The monthly-spend limits, in yen, indexed by PrefPurchaseLimitType (0, 1, 2). A type of 3 or more
// yields no limit. From __const at 0x293cb8.
/** @ghidraAddress 0x293cb8 */
static const int kPurchaseLimitByType[] = {5000, 5000, 20000};
static const int kPurchaseLimitCount = 3;

// The age-confirmation dialog reports the chosen band as 1, 2, or 3; a value above 3 opens the
// Konami site instead. The registered age is the band minus one.
static const int kMaxAgeBand = 3;

// The fade-in used once StoreKit returns the product list. The binary passes 0x30000.
static const UIViewAnimationOptions kListFadeOptions = UIViewAnimationOptionCurveLinear;

// The product-list frame, per idiom. The x offset arrives as an fmov immediate; the other three
// components load from the __const pool.
static const CGFloat kListXPad = 12.0;         // fmov immediate at 0x1c0740
static const CGFloat kListXPhone = 6.0;        // fmov immediate at 0x1c073c
static const CGFloat kListYPad = 65.0;         // @ghidraAddress 0x291bc0
static const CGFloat kListYPhone = 32.0;       // @ghidraAddress 0x28f458
static const CGFloat kListWidthPad = 546.0;    // @ghidraAddress 0x292a20
static const CGFloat kListWidthPhone = 273.0;  // @ghidraAddress 0x28f770
static const CGFloat kListHeightPad = 395.0;   // @ghidraAddress 0x291c90
static const CGFloat kListHeightPhone = 198.0; // @ghidraAddress 0x293ca8

// The shared y of the SPTL and cube-policy buttons, per idiom, from the __const pool.
static const CGFloat kButtonYPad = 473.0;   // @ghidraAddress 0x293cb0
static const CGFloat kButtonYPhone = 236.0; // @ghidraAddress 0x293320

@implementation CubePurchaseView {
    UIView *_rootView;                       // +0x8
    UIImageView *_bgView;                    // +0x10
    UIImageView *_titleView;                 // +0x18
    NSMutableArray *_cubeList;               // +0x20
    CubePurchaseListView *_purchaseListView; // +0x28
    SKProductsRequest *_productsRequest;     // +0x30
    UIButton *_closeBtn;                     // +0x38
    UILabel *_errorLabel;                    // +0x40
    SessionDownloader *_infoDownloader;      // +0x48
    UIButton *_sptlBtn;                      // +0x50
    UIButton *_cubePolicyBtn;                // +0x58
    SKProduct *_selectedProduct;             // +0x60
    int _selectedIndex;                      // +0x68
    int _selectedPurchaseAge;                // +0x6c
    MessageTextView *_textView;              // +0x70
    // _aDelegate is the synthesized backing for the weak aDelegate property, at +0x78.
}

#pragma mark - Initialisation

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;

        // The background plate. Its image size sets the root view's frame, and the same image backs
        // the visible plate.
        UIImage *bgImage = LoadScaledPngImage(kBackgroundImageName);
        _rootView = [[UIView alloc]
            initWithFrame:CGRectMake(0, 0, bgImage.size.width, bgImage.size.height)];
        _rootView.center = CGPointMake(frame.size.width * 0.5, frame.size.height * 0.5);
        [self addSubview:_rootView];
        _bgView = [[UIImageView alloc] initWithImage:bgImage];
        [_rootView addSubview:_bgView];

        // The close button, vertically centred on its own image height near the top corner.
        UIImage *closeImage = LoadScaledPngImage(kCloseButtonImageName);
        _closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        // fmov immediates at 0x1c0710 (8), 0x1c0714 (16); 0x1c071c (14), 0x1c0720 (28); 0.5 fmov
        // immediate at 0x1c0600.
        CGFloat closeX = isPad ? 16.0 : 8.0;
        CGFloat closeTop = isPad ? 28.0 : 14.0;
        _closeBtn.frame = CGRectMake(closeX,
                                     closeTop - closeImage.size.height * 0.5,
                                     closeImage.size.width,
                                     closeImage.size.height);
        [_closeBtn setBackgroundImage:closeImage forState:UIControlStateNormal];
        [_closeBtn addTarget:self
                      action:@selector(closePurchaseMenu:)
            forControlEvents:UIControlEventTouchUpInside];
        _closeBtn.exclusiveTouch = YES;
        [_rootView addSubview:_closeBtn];

        // The product list, laid out inside the plate and initially transparent. Its per-idiom
        // frame reads from __const.
        _purchaseListView = [[CubePurchaseListView alloc]
            initWithFrame:CGRectMake(isPad ? kListXPad : kListXPhone,
                                     isPad ? kListYPad : kListYPhone,
                                     isPad ? kListWidthPad : kListWidthPhone,
                                     isPad ? kListHeightPad : kListHeightPhone)];
        _purchaseListView.alpha = 0.0;
        _purchaseListView.aDelegate = self;
        [_rootView addSubview:_purchaseListView];

        // The SPTL button, its integer x centred at a quarter of the root width.
        UIImage *sptlImage = LoadScaledPngImage(kSptlButtonImageName);
        // fmov immediates at 0x1c0784 (2), 0x1c0788 (4); 0.25 at 0x1c08c4; 3.0 at 0x1c09e4.
        CGFloat buttonBase = isPad ? 4.0 : 2.0;
        _sptlBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        int sptlX =
            (int)(buttonBase + (_rootView.frame.size.width * 0.25 - sptlImage.size.width * 0.5));
        _sptlBtn.frame = CGRectMake(sptlX,
                                    isPad ? kButtonYPad : kButtonYPhone,
                                    sptlImage.size.width,
                                    sptlImage.size.height);
        [_sptlBtn setBackgroundImage:sptlImage forState:UIControlStateNormal];
        [_sptlBtn addTarget:self
                      action:@selector(tapSptl:)
            forControlEvents:UIControlEventTouchUpInside];
        _sptlBtn.exclusiveTouch = YES;
        [_rootView addSubview:_sptlBtn];

        // The cube-policy button, its integer x centred at three quarters of the root width.
        UIImage *policyImage = LoadScaledPngImage(kCubePolicyButtonImageName);
        _cubePolicyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        int policyX = (int)(buttonBase + (_rootView.frame.size.width * 3.0 * 0.25 -
                                          policyImage.size.width * 0.5));
        _cubePolicyBtn.frame = CGRectMake(policyX,
                                          isPad ? kButtonYPad : kButtonYPhone,
                                          policyImage.size.width,
                                          policyImage.size.height);
        [_cubePolicyBtn setBackgroundImage:policyImage forState:UIControlStateNormal];
        [_cubePolicyBtn addTarget:self
                           action:@selector(tapCubePolicy:)
                 forControlEvents:UIControlEventTouchUpInside];
        _cubePolicyBtn.exclusiveTouch = YES;
        [_rootView addSubview:_cubePolicyBtn];

        // Kick off the signed fetch of the cube product list.
        NSString *editorID = [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
        NSArray *objects = @[ editorID, kRequestValueTargetJP ];
        NSArray *keys = @[ kRequestKeyUserID, kRequestKeyTarget ];
        NSDictionary *post = [NSMutableDictionary dictionaryWithObjects:objects forKeys:keys];
        _infoDownloader = [[SessionDownloader alloc] initWithURL:ScratchUtil.cubePurchaseListURL
                                                  postDictionary:post
                                                        delegate:self];
        _infoDownloader.tag = kDownloaderTagCubeList;
        _infoDownloader.apiTag = kCubeListApiTag;
        [_infoDownloader startDownloading];

        _cubeList = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark - Dismissal and overlays

- (void)closePurchaseMenu:(id)sender {
    [[AudioManager sharedManager] playSeResFile:kCloseSoundName inDirectory:nil];
    if (_productsRequest) {
        [_productsRequest cancel];
        _productsRequest = nil;
    }
    [self.aDelegate closeCubePurchase];
}

- (void)tapSptl:(id)sender {
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:kSptlURLString]];
}

- (void)tapCubePolicy:(id)sender {
    NSArray *objects = @[ kRequestValueTargetJP, @2, @(-1) ];
    NSArray *keys = @[ kRequestKeyTarget, kPolicyKeyType, kPolicyKeyRevision ];
    NSDictionary *send = [NSDictionary dictionaryWithObjects:objects forKeys:keys];
    _textView = [[MessageTextView alloc] init:self
                                        title:kCubePolicyTitle
                                          url:ScratchUtil.challengeModePolicyURL
                                         send:send];
    _textView.center = CGPointMake(self.frame.size.width * 0.5, self.frame.size.height * 0.5);
    [self addSubview:_textView];
    _rootView.userInteractionEnabled = NO;
}

- (void)closeMessage:(id)sender {
    [_textView removeFromSuperview];
    _textView = nil;
    _rootView.userInteractionEnabled = YES;
}

#pragma mark - Purchase gate

- (BOOL)checkAttainLimitPurchase:(SKProduct *)product {
    int total = JubeatAppDelegate.appDelegate.totalPurchaseAmount;
    NSInteger limitType =
        [NSUserDefaults.standardUserDefaults integerForKey:kPrefPurchaseLimitType];
    int limit;
    if ((NSUInteger)limitType < kPurchaseLimitCount) {
        limit = kPurchaseLimitByType[limitType];
    } else {
        limit = -1;
    }

    BOOL isJPY =
        [[product.priceLocale objectForKey:NSLocaleCurrencyCode] isEqualToString:kCurrencyCodeJPY];
    if (isJPY) {
        total += (int)product.price.integerValue;
    }

    BOOL blocked = NO;
    if (limit >= 0 && limit < total) {
        AlertViewManager *manager = [AlertViewManager sharedManager];
        if (limitType == 0) {
            NSString *cancel = [NSBundle.mainBundle localizedStringForKey:kLocalizableKeyCancel
                                                                    value:kEmptyString
                                                                    table:nil];
            [manager makeAlert:0
                      delegate:self
                           tag:kAlertTagAgeConfirm
                         title:kAgeConfirmTitle
                           msg:kAgeConfirmMessage
                        cancel:cancel
                       btnText:@[ kAgeButton15OrUnder, kAgeButtonUnder20, kAgeButton20OrOver ]
                          show:YES];
        } else {
            NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocalizableKeyOK
                                                                value:kEmptyString
                                                                table:nil];
            [manager makeAlert:0
                      delegate:nil
                           tag:0
                         title:kLimitExceededTitle
                           msg:kLimitExceededMessage
                        cancel:ok
                       btnText:nil
                          show:YES];
        }
        blocked = YES;
    }
    return blocked;
}

- (void)purchaseStart:(SKProduct *)product {
    [PurchaseManager sharedManager].delegate = self;
    [[PurchaseManager sharedManager] beginConsumePurchase:product];
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    [self.aDelegate showPurchaseDialog:kProcessingMessage];
}

- (void)selectListCell:(NSIndexPath *)indexPath {
    if (indexPath.row < (NSInteger)_cubeList.count) {
        _selectedIndex = (int)indexPath.row;
        SKProduct *product = [_cubeList[_selectedIndex] getProduct];
        if (![self checkAttainLimitPurchase:product]) {
            [self purchaseStart:product];
        }
    }
}

#pragma mark - Signed download callbacks

- (void)downloaderFinished:(id)downloader {
    NSDictionary *data = [downloader getDataInJSON];
    int status = data[kResponseKeyStatus] ? (int)[data[kResponseKeyStatus] intValue] : -1;

    if (status == kStatusServerError) {
        NSString *msg = [NSBundle.mainBundle localizedStringForKey:kLocalizableKeyServerErrorMsg
                                                             value:kEmptyString
                                                             table:nil];
        if (data[kResponseKeyErrorMessage]) {
            msg = data[kResponseKeyErrorMessage];
        }
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocalizableKeyOK
                                                            value:kEmptyString
                                                            table:nil];
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:self
                                                tag:kAlertTagSessionError
                                              title:kEmptyString
                                                msg:msg
                                             cancel:ok
                                            btnText:nil
                                               show:YES];
        return;
    }

    int tag = (int)[(Downloader *)downloader tag];
    if (tag == kDownloaderTagRegisterAge) {
        NSString *msg = [NSBundle.mainBundle localizedStringForKey:kLocalizableKeyServerErrorMsg
                                                             value:kEmptyString
                                                             table:nil];
        if (status == 0) {
            [NSUserDefaults.standardUserDefaults setInteger:_selectedPurchaseAge
                                                     forKey:kPrefPurchaseLimitType];
        } else {
            if (data[kResponseKeyErrorMessage]) {
                msg = data[kResponseKeyErrorMessage];
            }
            _errorLabel.text = msg;
        }
        _infoDownloader = nil;
        return;
    }
    if (tag != kDownloaderTagCubeList) {
        return;
    }

    if (status == 0) {
        if (data[kResponseKeySum]) {
            [JubeatAppDelegate.appDelegate setTotalAmount:(int)[data[kResponseKeySum] intValue]];
        }
        if ([data[kResponseKeyItem] count] == 0) {
            _errorLabel.text = data[kResponseKeyErrorMessage] ? data[kResponseKeyErrorMessage] :
                                                                kFallbackErrorText;
        } else {
            NSMutableSet *productIDs = [[NSMutableSet alloc] init];
            for (NSDictionary *itemDict in data[kResponseKeyItem]) {
                CubePurchaseInfo *info = [[CubePurchaseInfo alloc] init];
                [info initWithDictionary:itemDict];
                [_cubeList addObject:info];
                [productIDs addObject:[info getProductID]];
            }
            _productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIDs];
            _productsRequest.delegate = self;
            [_productsRequest start];
        }
    } else {
        _errorLabel.text =
            data[kResponseKeyErrorMessage] ? data[kResponseKeyErrorMessage] : kFallbackErrorText;
    }
    _infoDownloader = nil;
}

- (void)downloaderError:(id)downloader {
    int tag = (int)[(Downloader *)downloader tag];
    if (tag == kDownloaderTagRegisterAge) {
        NSString *msg = [NSBundle.mainBundle localizedStringForKey:kLocalizableKeyServerErrorMsg
                                                             value:kEmptyString
                                                             table:nil];
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocalizableKeyOK
                                                            value:kEmptyString
                                                            table:nil];
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:nil
                                                tag:0
                                              title:kEmptyString
                                                msg:msg
                                             cancel:ok
                                            btnText:nil
                                               show:YES];
        return;
    }
    if (tag == kDownloaderTagCubeList) {
        _errorLabel.text = kFallbackErrorText;
    }
}

#pragma mark - Alert delegate

- (void)alertSelect:(NSDictionary *)info {
    int button = (int)[info[kAlertInfoKeyButton] intValue];
    int tag = (int)[info[kAlertInfoKeyTag] intValue];
    if (tag == kAlertTagPurchaseComplete) {
        [self.aDelegate closeCubePurchase];
        [self.aDelegate hidePurchaseDialog];
        [PurchaseManager sharedManager].delegate = nil;
        return;
    }
    if (tag == kAlertTagAgeConfirm) {
        if (button != 0) {
            if (button > kMaxAgeBand) {
                [UIApplication.sharedApplication openURL:[NSURL URLWithString:kKonamiURLString]];
                return;
            }
            _selectedPurchaseAge = button;
            NSDictionary *post = [NSDictionary dictionaryWithObjects:@[ @(button - 1) ]
                                                             forKeys:@[ kAgeKey ]];
            _infoDownloader = [[SessionDownloader alloc] initWithURL:ScratchUtil.registUserAgeURL
                                                      postDictionary:post
                                                            delegate:self];
            _infoDownloader.tag = kDownloaderTagRegisterAge;
            [_infoDownloader startDownloading];
        }
    } else if (tag == kAlertTagSessionError) {
        // ChallengeStatus vends the challenge-mode root view (ChallengeModeRootView, not yet
        // reconstructed); both messages are dispatched dynamically through id.
        id rootView = [[ChallengeStatus sharedStatus] performSelector:@selector(rootView)];
        [rootView performSelector:@selector(closeChallengeModeSessionError)];
    }
}

#pragma mark - PurchaseManager callbacks

- (void)purchaseSucceeded:(NSString *)productID {
    [UIApplication.sharedApplication endIgnoringInteractionEvents];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocalizableKeyOK
                                                        value:kEmptyString
                                                        table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:self
                                            tag:kAlertTagPurchaseComplete
                                          title:kEmptyString
                                            msg:kPurchaseCompleteMessage
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
    if ([self.aDelegate respondsToSelector:@selector(refreshStatus)]) {
        [self.aDelegate performSelector:@selector(refreshStatus)];
    }
}

- (void)purchaseFailed:(NSString *)productID error:(NSError *)error {
    [UIApplication.sharedApplication endIgnoringInteractionEvents];
    (void)error.code; // Yes, the binary reads the error code and discards it.
    NSString *msg = [NSBundle.mainBundle localizedStringForKey:kLocalizableKeyServerErrorMsg
                                                         value:kEmptyString
                                                         table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocalizableKeyOK
                                                        value:kEmptyString
                                                        table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:self
                                            tag:kAlertTagPurchaseComplete
                                          title:kEmptyString
                                            msg:msg
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response {
    if (response.products.count == 0) {
        _errorLabel.text = kNoItemsMessage;
        return;
    }

    // Yes, the binary reads the last product's country code and discards it.
    (void)[response.products.lastObject.priceLocale objectForKey:NSLocaleCountryCode];

    for (SKProduct *product in response.products) {
        for (CubePurchaseInfo *info in _cubeList) {
            if ([product.productIdentifier isEqual:[info getProductID]]) {
                [info updateProduct:product];
                break;
            }
        }
    }

    [_purchaseListView setListArray:_cubeList];

    __weak CubePurchaseListView *weakList = _purchaseListView;
    // Animation durations from __const at 0x28f240 (0.2) and 0x28f2b8 (0.1).
    [UIView animateWithDuration:0.2
                          delay:0.1
                        options:kListFadeOptions
                     animations:^{
                       /** @ghidraAddress 0x1c2af0 */
                       weakList.alpha = 1.0;
                     }
                     completion:^(BOOL finished){
                         /** @ghidraAddress 0x1c2b3c */
                         // A global no-op completion block.
                     }];
}

- (void)requestDidFinish:(SKRequest *)request {
    _productsRequest = nil;
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    _productsRequest = nil;
    _errorLabel.text = kNoItemsMessage;
}

@end
