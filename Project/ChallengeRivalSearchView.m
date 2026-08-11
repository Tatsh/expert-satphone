#import "ChallengeRivalSearchView.h"

#import "AlertViewManager.h"
#import "ChallengeModeRootView.h"
#import "ChallengeStatus.h"
#import "ChallengeTextInputView.h"
#import "CopyableUiLabel.h"
#import "Downloader.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "ScratchUtil.h"
#import "SessionDownloader.h"

// The challenge root view messaged when a session-error alert is dismissed. Not fully reconstructed
// yet; only the accessors this modal reads are declared. See TYPES_PENDING.md.
@protocol ChallengeRootView <NSObject>
- (void)closeChallengeModeSessionError;
@end
// The background, message, and button artwork.
static NSString *const kSearchSheetImageName = @"scratch_sheet_Search";
static NSString *const kSearchButtonImageName = @"scratch_btn_Search";
static NSString *const kBackButtonImageName = @"scratch_btn_back";
static NSString *const kRivalSheetImageName = @"scratch_sheet_rival";
static NSString *const kRivalMessageAskImageName = @"scratch_rival_reg_m01";
static NSString *const kRivalMessageSendingImageName = @"scratch_rival_reg_m02";
static NSString *const kRivalMessageDoneImageName = @"scratch_rival_reg_m03";
static NSString *const kCancelButtonImageName = @"scratch_btn_no";
static NSString *const kAddButtonImageName = @"scratch_btn_yes";
static NSString *const kEndButtonImageName = @"scratch_btn_ok";

// The search field's font.
static NSString *const kFontName = @"Helvetica";

// The search field's size, per idiom (pooled at 0x292a38 / 0x293340 and 0x28f4f8).
static const CGFloat kInputFieldWidthPad = 350.0;
static const CGFloat kInputFieldWidthPhone = 175.0;
static const CGFloat kInputFieldHeightPad = 38.0;
static const CGFloat kInputFieldHeightPhone = 20.0;

// The search field's y origin inside the sheet, per idiom (pooled at 0x291de8 / 0x291de0).
static const CGFloat kInputFieldYPad = 87.0;
static const CGFloat kInputFieldYPhone = 43.0;

// The search field's font size, per idiom (fmov 0x4038… / 0x4028…).
static const CGFloat kInputFontSizePad = 24.0;
static const CGFloat kInputFontSizePhone = 12.0;

// The close button's inset from the sheet's top-left corner, per idiom (fmov 0x4026… / 0x4020… and
// 0x403c… / 0x402c…).
static const CGFloat kCloseButtonInsetXPad = 11.0;
static const CGFloat kCloseButtonInsetXPhone = 8.0;
static const CGFloat kCloseButtonInsetYPad = 28.0;
static const CGFloat kCloseButtonInsetYPhone = 14.0;

// The search-ID label's y offset below the sheet's top, per idiom (pooled at 0x293350 / 0x293348).
static const CGFloat kSearchIDLabelYPad = 330.0;
static const CGFloat kSearchIDLabelYPhone = 164.0;

// The centred rival-add container's size on iPad; on the phone it fills the modal frame instead.
static const int kRivalViewWidthPad = 500;
static const int kRivalViewHeightPad = 800;

// The scale applied to every measurement inside the rival-add container, per idiom (fmov 0x3f800000
// / 0x3f000000).
static const CGFloat kRivalScalePad = 1.0;
static const CGFloat kRivalScalePhone = 0.5;

// The rival-add container's label geometry, before the per-idiom scale (pooled floats).
static const CGFloat kRivalLabelX = 44.0;         // 0x2932d4
static const CGFloat kRivalIDLabelY = 152.0;      // 0x292fbc
static const CGFloat kRivalNameLabelY = 20.0;     // fmov 0x41a00000
static const CGFloat kRivalLabelWidth = 352.0;    // 0x2932d0
static const CGFloat kRivalLabelHeight = 38.0;    // 0x292ae4
static const CGFloat kRivalMessageCenterY = 76.0; // 0x28f8f8
static const CGFloat kRivalLabelFontSize = 24.0;  // fmov 0x41c00000

// The rival-add container's button row, before the per-idiom scale.
static const CGFloat kRivalButtonRowY = 210.0; // 0x291dc8
static const CGFloat kRivalButtonGap = 10.0;   // fmov ±0x4024000000000000

// The half-scale factor applied throughout the centring maths.
static const CGFloat kHalf = 0.5;

// The fade used for every rival-add transition (pooled at 0x28e040), with a linear curve.
static const NSTimeInterval kFadeDuration = 0.2;
static const UIViewAnimationOptions kFadeOptions = UIViewAnimationOptionCurveLinear;

// The post-body keys for the search and the registration requests.
static NSString *const kPostUserIDKey = @"user_id";
static NSString *const kPostRivalIDKey = @"rival_id";
static NSString *const kPostIsAddKey = @"is_add";

// The response keys.
static NSString *const kResponseStatusKey = @"status";
static NSString *const kResponseErrorMessageKey = @"err_message";
static NSString *const kResponseNameKey = @"name";

// The alert-info key carrying the tapped alert's tag.
static NSString *const kAlertInfoTagKey = @"Tag";

// The default alert messages when the server supplies none.
static NSString *const kSelfSearchMessage = @"それはあなたです";
static NSString *const kRivalNotFoundMessage = @"ライバルは見つかりませんでした";
static NSString *const kRegisterFailedMessage = @"ライバルの登録に失敗しました";

// The download tags distinguishing the search lookup from the registration.
static const int kTagSearch = 1;
static const int kTagRegister = 2;

// The API tags for the two request kinds.
static const int kApiTagSearch = 0xe;
static const int kApiTagRegister = 0xf;

// The server status codes handled specially.
static const int kStatusOK = 0;
static const int kStatusServerError = 0x18b53;
static const int kStatusUpdateRequired = 0x186ab;

// The alert tag whose dismissal closes the session with an error.
static const int kSessionErrorAlertTag = 9999;

// The control event the buttons fire on (touch up inside).
static const UIControlEvents kButtonEvent = UIControlEventTouchUpInside;

@interface ChallengeRivalSearchView () <AlertViewManagerDelegate,
                                        ChallengeTextInputViewDelegate,
                                        DownloaderDelegate> {
@public
    ChallengeTextInputView *inputView; // +0x8
    NSString *targetID;                // +0x10
    NSString *targetName;              // +0x18
    CGRect listRect;                   // +0x20 (declared by the class; unused by these routines)
    UIView *searchBox;                 // +0x40
    UIView *rivalView;                 // +0x48
    UIImageView *bgView;               // +0x50
    UIButton *closeBtn;                // +0x58
    CopyableUiLabel *myID;             // +0x60
    UIImageView *addMessage;           // +0x68
    UIView *rivalAddView;              // +0x70
    UIImageView *addBgView;            // +0x78
    UIButton *addBtn;                  // +0x80
    UIButton *cancelBtn;               // +0x88
    UIButton *endBtn;                  // +0x90
    UILabel *rivalID;                  // +0x98
    UILabel *rivalName;                // +0xa0
}
- (void)switchRivalMessageView;
@end

// The registration reply: on success animate to the confirmation state; otherwise show the failure.
static inline void ChallengeRivalSearchViewHandleRegisterResponse(ChallengeRivalSearchView *self,
                                                                  NSDictionary *json,
                                                                  int status) {
    if (status == kStatusOK) {
        [self switchRivalMessageView];
        return;
    }
    NSString *msg = json[kResponseErrorMessageKey];
    if (!msg) {
        msg = kRegisterFailedMessage;
    }
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:self
                                            tag:0
                                          title:@""
                                            msg:msg
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

// The search reply: on success with at least one match, record the rival and cross-fade from the
// search box to the rival-add panel; otherwise show the "not found" message.
static inline void ChallengeRivalSearchViewHandleSearchResponse(ChallengeRivalSearchView *self,
                                                                NSDictionary *json,
                                                                int status) {
    if (status == kStatusOK && [json[kResponseNameKey] count] != 0) {
        (void)self->inputView.inputText; // Read but unused, as in the binary.
        self->targetID = json[kResponseNameKey][0][0];
        self->targetName = json[kResponseNameKey][0][1];
        self->rivalID.text = self->targetID;
        self->rivalName.text = self->targetName;
        self->rivalAddView.alpha = 0;
        [self addSubview:self->rivalAddView];

        __weak UIView *weakSearchBox = self->searchBox;
        __weak UIView *weakRivalAddView = self->rivalAddView;
        [UIView animateWithDuration:kFadeDuration
            delay:0
            options:kFadeOptions
            animations:^{
              /** @ghidraAddress 0x168c90 */
              weakSearchBox.alpha = 0;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x168cdc */
              [UIView animateWithDuration:kFadeDuration
                                    delay:0
                                  options:kFadeOptions
                               animations:^{
                                 /** @ghidraAddress 0x168d8c */
                                 weakRivalAddView.alpha = 1.0;
                               }
                               completion:^(BOOL finished){
                                   /** @ghidraAddress 0x168dd8 */
                               }];
            }];
        return;
    }

    NSString *msg = json[kResponseErrorMessageKey];
    if (!msg) {
        msg = kRivalNotFoundMessage;
    }
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:@""
                                            msg:msg
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

@implementation ChallengeRivalSearchView

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0x167248 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    BOOL isPad = [JubeatAppDelegate appDelegate].isPad;

    // The search box holds the sheet artwork, the entry field, the close button, and the search-ID
    // label; it is centred in the modal frame.
    UIImage *sheetImage = LoadScaledPngImage(kSearchSheetImageName);
    searchBox = [[UIView alloc]
        initWithFrame:CGRectMake(0, 0, sheetImage.size.width, sheetImage.size.height)];
    searchBox.center = CGPointMake(frame.size.width * kHalf, frame.size.height * kHalf);
    [self addSubview:searchBox];

    bgView = [[UIImageView alloc] initWithImage:sheetImage];
    bgView.frame = CGRectMake(0, 0, sheetImage.size.width, sheetImage.size.height);
    [searchBox addSubview:bgView];

    CGRect sheetFrame = bgView.frame;
    inputView = [[ChallengeTextInputView alloc] initWithFrame:sheetFrame];
    inputView.aDelegate = self;

    // The entry field: idiom-sized, centred horizontally over the sheet, centre-aligned text.
    CGFloat fieldWidth = isPad ? kInputFieldWidthPad : kInputFieldWidthPhone;
    CGFloat fieldHeight = isPad ? kInputFieldHeightPad : kInputFieldHeightPhone;
    CGFloat fieldY = isPad ? kInputFieldYPad : kInputFieldYPhone;
    CGFloat fontSize = isPad ? kInputFontSizePad : kInputFontSizePhone;
    inputView.nameBox.frame =
        CGRectMake((sheetFrame.size.width - fieldWidth) * kHalf, fieldY, fieldWidth, fieldHeight);
    inputView.nameBox.textAlignment = NSTextAlignmentCenter;
    inputView.nameBox.font = [UIFont fontWithName:kFontName size:fontSize];

    // The search button sits centred horizontally, half-way down the sheet.
    UIImage *searchImage = LoadScaledPngImage(kSearchButtonImageName);
    [inputView.changeBtn setBackgroundImage:searchImage forState:UIControlStateNormal];
    inputView.changeBtn.frame = CGRectMake((sheetFrame.size.width - searchImage.size.width) * kHalf,
                                           sheetFrame.size.height * kHalf,
                                           searchImage.size.width,
                                           searchImage.size.height);
    [searchBox addSubview:inputView];

    // The close button, inset from the sheet's top-left corner.
    UIImage *closeImage = LoadScaledPngImage(kBackButtonImageName);
    closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    CGFloat closeInsetX = isPad ? kCloseButtonInsetXPad : kCloseButtonInsetXPhone;
    CGFloat closeInsetY = isPad ? kCloseButtonInsetYPad : kCloseButtonInsetYPhone;
    closeBtn.frame = CGRectMake(closeInsetX,
                                closeInsetY - closeImage.size.height * kHalf,
                                closeImage.size.width,
                                closeImage.size.height);
    [closeBtn setBackgroundImage:closeImage forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeSettingMenu:) forControlEvents:kButtonEvent];
    closeBtn.exclusiveTouch = YES;
    [searchBox addSubview:closeBtn];

    // The search-ID label under the entry field, showing the player's own ID.
    CGFloat searchIDLabelY = isPad ? kSearchIDLabelYPad : kSearchIDLabelYPhone;
    myID = [[CopyableUiLabel alloc]
        initWithFrame:CGRectMake((sheetFrame.size.width - fieldWidth) * kHalf,
                                 searchIDLabelY,
                                 fieldWidth,
                                 fieldHeight)];
    myID.textAlignment = NSTextAlignmentCenter;
    myID.font = [UIFont fontWithName:kFontName size:fontSize];
    myID.text = [ChallengeStatus sharedStatus].mySearchID;
    [searchBox addSubview:myID];

    // A centred, initially hidden container sized to the idiom (the phone falls back to the modal
    // frame's own size). The rival-add panel is dropped into the modal over it once a rival is
    // found. The origin is truncated to whole points through integer halving, as in the binary.
    int rivalWidth = isPad ? kRivalViewWidthPad : (int)frame.size.width;
    int rivalHeight = isPad ? kRivalViewHeightPad : (int)frame.size.height;
    rivalView = [[UIView alloc]
        initWithFrame:CGRectMake((CGFloat)(int)(frame.size.width * kHalf - (rivalWidth >> 1)),
                                 (CGFloat)(int)(frame.size.height * kHalf - (rivalHeight >> 1)),
                                 (CGFloat)rivalWidth,
                                 (CGFloat)rivalHeight)];
    rivalView.alpha = 0;
    [self addSubview:rivalView];

    // The rival-add panel: the confirmation prompt shown once a rival is found. It is centred in
    // the modal frame and left hidden until the search succeeds.
    UIImage *rivalSheetImage = LoadScaledPngImage(kRivalSheetImageName);
    rivalAddView = [[UIView alloc]
        initWithFrame:CGRectMake(0, 0, rivalSheetImage.size.width, rivalSheetImage.size.height)];
    rivalAddView.center = CGPointMake(frame.size.width * kHalf, frame.size.height * kHalf);

    addBgView = [[UIImageView alloc] initWithImage:rivalSheetImage];
    [rivalAddView addSubview:addBgView];

    CGFloat scale = isPad ? kRivalScalePad : kRivalScalePhone;

    // The rival-ID label.
    rivalID = [[UILabel alloc] initWithFrame:CGRectMake(kRivalLabelX * scale,
                                                        kRivalIDLabelY * scale,
                                                        kRivalLabelWidth * scale,
                                                        kRivalLabelHeight * scale)];
    rivalID.textAlignment = NSTextAlignmentCenter;
    rivalID.font = [UIFont systemFontOfSize:kRivalLabelFontSize * scale];
    [rivalAddView addSubview:rivalID];

    // The "add this rival?" message, centred horizontally in the panel.
    addMessage = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kRivalMessageAskImageName)];
    addMessage.center =
        CGPointMake(rivalAddView.frame.size.width * kHalf, kRivalMessageCenterY * scale);
    [rivalAddView addSubview:addMessage];

    // The rival-name label.
    rivalName = [[UILabel alloc] initWithFrame:CGRectMake(kRivalLabelX * scale,
                                                          kRivalNameLabelY * scale,
                                                          kRivalLabelWidth * scale,
                                                          kRivalLabelHeight * scale)];
    rivalName.textAlignment = NSTextAlignmentCenter;
    rivalName.font = [UIFont systemFontOfSize:kRivalLabelFontSize * scale];
    [rivalAddView addSubview:rivalName];

    // The cancel button, left of centre.
    UIImage *cancelImage = LoadScaledPngImage(kCancelButtonImageName);
    cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelBtn.frame =
        CGRectMake(rivalAddView.frame.size.width * kHalf - cancelImage.size.width - kRivalButtonGap,
                   kRivalButtonRowY * scale,
                   cancelImage.size.width,
                   cancelImage.size.height);
    [cancelBtn setBackgroundImage:cancelImage forState:UIControlStateNormal];
    [cancelBtn addTarget:self action:@selector(selectRivalCancel:) forControlEvents:kButtonEvent];
    cancelBtn.exclusiveTouch = YES;
    [rivalAddView addSubview:cancelBtn];

    // The add button, right of centre.
    UIImage *addImage = LoadScaledPngImage(kAddButtonImageName);
    addBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    addBtn.frame = CGRectMake(rivalAddView.frame.size.width * kHalf + kRivalButtonGap,
                              kRivalButtonRowY * scale,
                              addImage.size.width,
                              addImage.size.height);
    [addBtn setBackgroundImage:addImage forState:UIControlStateNormal];
    [addBtn addTarget:self action:@selector(selectRivalAdd:) forControlEvents:kButtonEvent];
    addBtn.exclusiveTouch = YES;
    [rivalAddView addSubview:addBtn];

    // The OK button, centred and hidden until the registration is confirmed.
    UIImage *endImage = LoadScaledPngImage(kEndButtonImageName);
    endBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    endBtn.frame = CGRectMake(rivalAddView.frame.size.width * kHalf - endImage.size.width * kHalf,
                              kRivalButtonRowY * scale,
                              endImage.size.width,
                              endImage.size.height);
    [endBtn setBackgroundImage:endImage forState:UIControlStateNormal];
    [endBtn addTarget:self action:@selector(tapClose:) forControlEvents:kButtonEvent];
    endBtn.alpha = 0;
    endBtn.exclusiveTouch = YES;
    [rivalAddView addSubview:endBtn];
    return self;
}

#pragma mark - ChallengeTextInputViewDelegate

/** @ghidraAddress 0x16819c */
- (void)commitText:(ChallengeTextInputView *)sender {
    NSString *text = sender.inputText;
    if (!text) {
        text = @"";
    }
    if ([text isEqualToString:[ChallengeStatus sharedStatus].mySearchID]) {
        // Entering one's own ID is refused with a prompt.
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:nil
                                                tag:0
                                              title:nil
                                                msg:kSelfSearchMessage
                                             cancel:ok
                                            btnText:nil
                                               show:YES];
        return;
    }
    if ([text isEqualToString:@""]) {
        return;
    }
    // Look the rival up by search ID and lock input until the reply lands.
    NSDictionary *post = [NSDictionary dictionaryWithObjects:@[ text ] forKeys:@[ kPostUserIDKey ]];
    SessionDownloader *downloader =
        [[SessionDownloader alloc] initWithURL:[ScratchUtil searchRivalURL]
                                postDictionary:post
                                      delegate:self];
    downloader.tag = kTagSearch;
    downloader.apiTag = kApiTagSearch;
    [downloader startDownloading];
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
}

#pragma mark - Actions

/** @ghidraAddress 0x169e80 */
- (void)tapClose:(id)sender {
    [self.aDelegate closeMenu];
}

/** @ghidraAddress 0x169ec0 */
- (void)closeSettingMenu:(id)sender {
    [self.aDelegate closeMenu];
}

/** @ghidraAddress 0x16952c */
- (void)selectRivalAdd:(id)sender {
    // Fade the prompt (message and both buttons) out, then post the registration and swap in the
    // "sending" artwork, then fade only the message back in while the request is in flight.
    __weak UIImageView *weakAddMessage = addMessage;
    __weak UIButton *weakAddBtn = addBtn;
    __weak UIButton *weakCancelBtn = cancelBtn;
    [UIView animateWithDuration:kFadeDuration
        delay:0
        options:kFadeOptions
        animations:^{
          /** @ghidraAddress 0x169714 */
          weakAddMessage.alpha = 0;
          weakAddBtn.alpha = 0;
          weakCancelBtn.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x16980c */
          NSDictionary *post =
              [NSDictionary dictionaryWithObjects:@[ targetID, @YES ]
                                          forKeys:@[ kPostRivalIDKey, kPostIsAddKey ]];
          SessionDownloader *downloader =
              [[SessionDownloader alloc] initWithURL:[ScratchUtil registRivalURL]
                                      postDictionary:post
                                            delegate:self];
          downloader.tag = kTagRegister;
          downloader.apiTag = kApiTagRegister;
          [downloader startDownloading];
          [UIApplication.sharedApplication beginIgnoringInteractionEvents];
          weakAddMessage.image = LoadScaledPngImage(kRivalMessageSendingImageName);
          [UIView animateWithDuration:kFadeDuration
                                delay:0
                              options:kFadeOptions
                           animations:^{
                             /** @ghidraAddress 0x169aa4 */
                             weakAddMessage.alpha = 1.0;
                           }
                           completion:^(BOOL finished){
                               /** @ghidraAddress 0x169af0 */
                           }];
        }];
}

/** @ghidraAddress 0x169b4c */
- (void)selectRivalCancel:(id)sender {
    // Lock input, fade the rival-add panel out, then unlock and fade the search box back in.
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    __weak UIView *weakSearchBox = searchBox;
    __weak UIView *weakRivalAddView = rivalAddView;
    [UIView animateWithDuration:kFadeDuration
        delay:0
        options:kFadeOptions
        animations:^{
          /** @ghidraAddress 0x169ce0 */
          weakRivalAddView.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x169d2c */
          [UIApplication.sharedApplication endIgnoringInteractionEvents];
          [UIView animateWithDuration:kFadeDuration
                                delay:0
                              options:kFadeOptions
                           animations:^{
                             /** @ghidraAddress 0x169e1c */
                             weakSearchBox.alpha = 1.0;
                           }
                           completion:^(BOOL finished){
                               /** @ghidraAddress 0x169e68 */
                           }];
        }];
}

/** @ghidraAddress 0x169f00 */
- (void)switchRivalMessageView {
    // Registration succeeded: fade the message out, swap in the "registered" artwork, then fade the
    // message and the OK button back in.
    __weak UIImageView *weakAddMessage = addMessage;
    __weak UIButton *weakEndBtn = endBtn;
    [UIView animateWithDuration:kFadeDuration
        delay:0
        options:kFadeOptions
        animations:^{
          /** @ghidraAddress 0x16a06c */
          weakAddMessage.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x16a0b8 */
          weakAddMessage.image = LoadScaledPngImage(kRivalMessageDoneImageName);
          [UIView animateWithDuration:kFadeDuration
                                delay:0
                              options:kFadeOptions
                           animations:^{
                             /** @ghidraAddress 0x16a1e4 */
                             weakAddMessage.alpha = 1.0;
                             weakEndBtn.alpha = 1.0;
                           }
                           completion:^(BOOL finished){
                               /** @ghidraAddress 0x16a2b4 */
                           }];
        }];
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x1684c4 */
- (void)downloaderFinished:(id)downloader {
    [UIApplication.sharedApplication endIgnoringInteractionEvents];
    NSDictionary *json = [downloader getDataInJSON];
    int status = -1;
    if (json[kResponseStatusKey]) {
        status = [json[kResponseStatusKey] intValue];
        if (status == kStatusServerError) {
            NSString *msg = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                                 value:@""
                                                                 table:nil];
            if (json[kResponseErrorMessageKey]) {
                msg = json[kResponseErrorMessageKey];
            }
            NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
            [[AlertViewManager sharedManager] makeAlert:0
                                               delegate:self
                                                    tag:kSessionErrorAlertTag
                                                  title:@""
                                                    msg:msg
                                                 cancel:ok
                                                btnText:nil
                                                   show:YES];
            return;
        }
        if (status == kStatusUpdateRequired) {
            [[AlertViewManager sharedManager] showUpdateAlert];
            return;
        }
    }

    int tag = (int)[downloader tag];
    if (tag == kTagRegister) {
        ChallengeRivalSearchViewHandleRegisterResponse(self, json, status);
    } else if (tag == kTagSearch) {
        ChallengeRivalSearchViewHandleSearchResponse(self, json, status);
    }
}

/** @ghidraAddress 0x168df0 */
- (void)downloaderError:(id)downloader {
    [UIApplication.sharedApplication endIgnoringInteractionEvents];
    NSString *msg = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                         value:@""
                                                         table:nil];
    if ([downloader tag] != kTagRegister) {
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:self
                                                tag:3
                                              title:@""
                                                msg:msg
                                             cancel:ok
                                            btnText:nil
                                               show:YES];
    }
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0x168fac */
- (void)alertSelect:(NSDictionary *)info {
    if ([info[kAlertInfoTagKey] intValue] == kSessionErrorAlertTag) {
        [[[ChallengeStatus sharedStatus] rootView] closeChallengeModeSessionError];
        return;
    }
    // Any other dismissal restores the rival-add prompt: fade the message out, swap the artwork
    // back to "add this rival?", then fade the message and both buttons back in.
    __weak UIImageView *weakAddMessage = addMessage;
    __weak UIButton *weakAddBtn = addBtn;
    __weak UIButton *weakCancelBtn = cancelBtn;
    [UIView animateWithDuration:kFadeDuration
        delay:0
        options:kFadeOptions
        animations:^{
          /** @ghidraAddress 0x169214 */
          weakAddMessage.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x169260 */
          weakAddMessage.image = LoadScaledPngImage(kRivalMessageAskImageName);
          [UIView animateWithDuration:kFadeDuration
                                delay:0
                              options:kFadeOptions
                           animations:^{
                             /** @ghidraAddress 0x1693b4 */
                             weakAddMessage.alpha = 1.0;
                             weakAddBtn.alpha = 1.0;
                             weakCancelBtn.alpha = 1.0;
                           }
                           completion:^(BOOL finished){
                               /** @ghidraAddress 0x1694b8 */
                           }];
        }];
}

@end
