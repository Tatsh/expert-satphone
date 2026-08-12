#import "ChallengeNameSettingView.h"

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

// The three background/button images.
static NSString *const kBackgroundImageName = @"scratch_sheet_name";
static NSString *const kChangeButtonImageName = @"scratch_btn_name";
static NSString *const kCloseButtonImageName = @"scratch_btn_back";

// The name field's size, per idiom.
static const int kNameBoxWidthPad = 350;
static const int kNameBoxWidthPhone = 175;
static const int kNameBoxHeightPad = 38;
static const int kNameBoxHeightPhone = 20;

// The name field's y origin inside the sheet, per idiom (pooled at 0x291de8 / 0x291de0).
static const CGFloat kNameBoxYPad = 87.0;
static const CGFloat kNameBoxYPhone = 43.0;

// The name field's font size, per idiom (fmov 0x4038… / 0x4028…).
static const CGFloat kNameFontSizePad = 24.0;
static const CGFloat kNameFontSizePhone = 12.0;

// The close button's inset from the background's top-left corner, per idiom.
static const int kCloseButtonInsetXPad = 11;
static const int kCloseButtonInsetXPhone = 8;
static const int kCloseButtonInsetYPad = 28;
static const int kCloseButtonInsetYPhone = 14;

// The search-ID label's y offset below the background's top, per idiom.
static const int kSearchIDLabelOffsetYPad = 330;
static const int kSearchIDLabelOffsetYPhone = 164;

// The half-scale factor applied throughout the centring maths.
static const CGFloat kHalf = 0.5;

// The name-entry font.
static NSString *const kNameFontName = @"Helvetica";

// The post-body key carrying the new name, and the JSON keys read from the response.
static NSString *const kPostNameKey = @"name";
static NSString *const kResponseStatusKey = @"status";
static NSString *const kResponseErrorMessageKey = @"err_message";

// The alert-info key carrying the tapped alert's tag.
static NSString *const kAlertInfoTagKey = @"Tag";

// The name-change request's API tag.
static const int kNameChangeApiTag = 0xb;

// The server status codes handled specially.
static const int kStatusOK = 0;
static const int kStatusServerError = 0x18b53;
static const int kStatusUpdateRequired = 0x186ab;

// The alert tag used to route the session-error dismissal.
static const int kSessionErrorAlertTag = 9999;

@interface ChallengeNameSettingView () <AlertViewManagerDelegate,
                                        ChallengeTextInputViewDelegate,
                                        DownloaderDelegate>
@end

@implementation ChallengeNameSettingView {
    ChallengeTextInputView *inputView; // +0x8
    UIImageView *bgView;               // +0x10
    UIButton *closeBtn;                // +0x18
    CopyableUiLabel *myID;             // +0x20
    BOOL enableBackBtn;                // +0x28
}

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0xdb214 */
- (instancetype)initWithFrame:(CGRect)frame backEnable:(BOOL)backEnable {
    enableBackBtn = backEnable;
    return [self initWithFrame:frame];
}

/** @ghidraAddress 0xdb22c */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    BOOL isPad = [JubeatAppDelegate appDelegate].isPad;
    self.opaque = NO;
    self.layer.doubleSided = NO;

    // The background art is centred in the sheet.
    UIImage *bgImage = LoadScaledPngImage(kBackgroundImageName);
    bgView = [[UIImageView alloc] initWithImage:bgImage];
    bgView.frame = CGRectMake(frame.size.width * kHalf - bgImage.size.width * kHalf,
                              frame.size.height * kHalf - bgImage.size.height * kHalf,
                              bgImage.size.width,
                              bgImage.size.height);
    [self addSubview:bgView];

    // The name-entry view fills the same frame as the background art.
    CGRect bgFrame = bgView.frame;
    inputView = [[ChallengeTextInputView alloc] initWithFrame:bgFrame];

    // The name field: idiom-sized, centred horizontally over the background, centre-aligned text.
    int nameBoxWidth = isPad ? kNameBoxWidthPad : kNameBoxWidthPhone;
    int nameBoxHeight = isPad ? kNameBoxHeightPad : kNameBoxHeightPhone;
    CGFloat nameBoxY = isPad ? kNameBoxYPad : kNameBoxYPhone;
    CGFloat fontSize = isPad ? kNameFontSizePad : kNameFontSizePhone;
    inputView.nameBox.frame = CGRectMake(
        (bgFrame.size.width - nameBoxWidth) * kHalf, nameBoxY, nameBoxWidth, nameBoxHeight);
    inputView.nameBox.textAlignment = NSTextAlignmentCenter;
    inputView.nameBox.font = [UIFont fontWithName:kNameFontName size:fontSize];
    [inputView setDefaultText:[ChallengeStatus sharedStatus].myName];
    inputView.aDelegate = self;

    // The change button sits centred horizontally, half-way down the background.
    UIImage *changeImage = LoadScaledPngImage(kChangeButtonImageName);
    [inputView.changeBtn setBackgroundImage:changeImage forState:UIControlStateNormal];
    inputView.changeBtn.frame = CGRectMake((bgFrame.size.width - changeImage.size.width) * kHalf,
                                           bgFrame.size.height * kHalf,
                                           changeImage.size.width,
                                           changeImage.size.height);
    [self addSubview:inputView];

    // The close button, only when a back button is wanted; it inset from the background's corner.
    int bgOriginX = (int)bgFrame.origin.x;
    int bgOriginY = (int)bgFrame.origin.y;
    if (enableBackBtn) {
        UIImage *closeImage = LoadScaledPngImage(kCloseButtonImageName);
        closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        int insetX = isPad ? kCloseButtonInsetXPad : kCloseButtonInsetXPhone;
        int insetY = isPad ? kCloseButtonInsetYPad : kCloseButtonInsetYPhone;
        closeBtn.frame = CGRectMake((CGFloat)(bgOriginX + insetX),
                                    (CGFloat)(bgOriginY + insetY) - closeImage.size.height * kHalf,
                                    closeImage.size.width,
                                    closeImage.size.height);
        [closeBtn setBackgroundImage:closeImage forState:UIControlStateNormal];
        [closeBtn addTarget:self
                      action:@selector(closeSettingMenu:)
            forControlEvents:UIControlEventTouchUpInside];
        closeBtn.exclusiveTouch = YES;
        [self addSubview:closeBtn];
    }

    // The search-ID label under the name field.
    int searchIDOffsetY = isPad ? kSearchIDLabelOffsetYPad : kSearchIDLabelOffsetYPhone;
    myID = [[CopyableUiLabel alloc]
        initWithFrame:CGRectMake((CGFloat)bgOriginX +
                                     (bgFrame.size.width - (nameBoxWidth >> 1)) * kHalf,
                                 (CGFloat)(bgOriginY + searchIDOffsetY),
                                 nameBoxWidth >> 1,
                                 nameBoxHeight - 2)];
    myID.textAlignment = NSTextAlignmentCenter;
    myID.font = [UIFont fontWithName:kNameFontName size:fontSize];
    myID.text = [ChallengeStatus sharedStatus].mySearchID;
    [self addSubview:myID];
    return self;
}

#pragma mark - Actions

/** @ghidraAddress 0xdba30 */
- (void)commitText:(ChallengeTextInputView *)sender {
    NSString *text = [sender inputText];
    NSString *trimmed =
        [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([trimmed isEqualToString:@""]) {
        // An empty name shows a prompt and does nothing else.
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:nil
                                                tag:0
                                              title:@""
                                                msg:@"何か文字を入力してください"
                                             cancel:ok
                                            btnText:nil
                                               show:YES];
        return;
    }
    NSDictionary *post = [NSDictionary dictionaryWithObjects:@[ text ] forKeys:@[ kPostNameKey ]];
    [inputView.nameBox resignFirstResponder];
    SessionDownloader *downloader =
        [[SessionDownloader alloc] initWithURL:[ScratchUtil getUserNameURL]
                                postDictionary:post
                                      delegate:self];
    downloader.apiTag = kNameChangeApiTag;
    [downloader startDownloading];
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
}

/** @ghidraAddress 0xdbd18 */
- (void)closeSettingMenu:(id)sender {
    [inputView.nameBox resignFirstResponder];
    [self.aDelegate closeMenu];
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0xdbd98 */
- (void)downloaderFinished:(id)downloader {
    [UIApplication.sharedApplication endIgnoringInteractionEvents];
    NSDictionary *json = [downloader getDataInJSON];
    if (json[kResponseStatusKey]) {
        int status = [json[kResponseStatusKey] intValue];
        if (status == kStatusOK) {
            // The name took: record it and confirm. The confirmation copy differs by whether a back
            // button is shown (a re-registration versus a first registration).
            [[ChallengeStatus sharedStatus] updateName:[inputView inputText]];
            NSString *msg = enableBackBtn ? @"名前は変更されました" : @"名前を登録しました";
            NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
            [[AlertViewManager sharedManager] makeAlert:0
                                               delegate:self
                                                    tag:0
                                                  title:@""
                                                    msg:msg
                                                 cancel:ok
                                                btnText:nil
                                                   show:YES];
            return;
        }
        if (status == kStatusServerError) {
            // A server error: prefer the response's err_message, else the localised fallback. The
            // alert is tagged so its dismissal closes the session with an error.
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

    // Any other outcome: the response's err_message, else the localised network-error fallback.
    NSString *msg = json[kResponseErrorMessageKey];
    if (!msg) {
        msg = [NSBundle.mainBundle localizedStringForKey:@"NetworkErrorMsg" value:@"" table:nil];
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

/** @ghidraAddress 0xdc324 */
- (void)downloaderError:(id)downloader {
    NSString *msg = [NSBundle.mainBundle localizedStringForKey:@"NetworkErrorMsg"
                                                         value:@""
                                                         table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:@""
                                            msg:msg
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
    [UIApplication.sharedApplication endIgnoringInteractionEvents];
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0xdc49c */
- (void)alertSelect:(NSDictionary *)info {
    if ([info[kAlertInfoTagKey] intValue] == kSessionErrorAlertTag) {
        [[[ChallengeStatus sharedStatus] rootView] closeChallengeModeSessionError];
    } else {
        [self.aDelegate closeMenu];
    }
}

@end
