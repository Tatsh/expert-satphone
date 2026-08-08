#import "InheritCodeInputView.h"

#import <QuartzCore/QuartzCore.h>

#import "EditorIDManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "ScratchUtil.h"
#import "SessionDownloader.h"

// The background art.
static NSString *const kInputBackgroundImageName = @"inherit_bg";

// The caution label's copy, the code field's placeholder-less contents, and the send-button title.
static NSString *const kInputCautionText = @"引き継ぎコードを入力してください\n引き継ぎコードの入力"
                                           @"は通信環境の安定した状態で行ってください";
static NSString *const kInputSendButtonTitle = @"引き継ぎ";

// The post-body key the code is sent under.
static NSString *const kInputTokenKey = @"token";

// The alerts' user-facing copy.
static NSString *const kInputEmptyCodeMessage = @"文字を入力してください";
static NSString *const kInputConfirmFormat = @"このユーザーを引き継ぎます\n%@";
static NSString *const kInputSelfMessage = @"それはあなたです";
static NSString *const kInputInvalidCodeMessage = @"無効な引き継ぎコードです。";
static NSString *const kInputFailedMessage = @"引き継ぎに失敗しました";
static NSString *const kInputReplaceDoneText = @"端末移行が完了しました。";

// The response keys.
static NSString *const kInputKeyStatus = @"status";
static NSString *const kInputKeyUserID = @"user_id";
static NSString *const kInputKeyPassword = @"password";
static NSString *const kInputKeyErrorMessage = @"err_message";

// The two request tags: 0 checks a code, 1 replaces the account with it.
static const int kInputTagCheck = 0;
static const int kInputTagReplace = 1;

// The alert tag for the "replace this account?" confirmation, and its OK button index.
static const int kInputConfirmAlertTag = 1;
static const int kInputConfirmOKButton = 1;

// The status code that means "invalid code": 0x192c3 or 0x192c4 (the binary tests a two-wide
// range).
static const int kInputStatusInvalidFirst = 0x192c3;

// The centred content width and the label/field/button metrics.
static const CGFloat kInputContentWidth = 300.0;   // @ghidraAddress 0x28f2d0
static const CGFloat kInputContentXDelta = -300.0; // @ghidraAddress 0x28f3e8
static const CGFloat kInputFieldHeight = 40.0;     // @ghidraAddress 0x28f1f8
static const CGFloat kInputExpTextY = 150.0;       // @ghidraAddress 0x28f790
static const CGFloat kInputFieldY = 222.0;         // @ghidraAddress 0x291d90
static const CGFloat kInputButtonWidth = 100.0;    // @ghidraAddress 0x28f3f0
static const CGFloat kInputButtonXDelta = -100.0;  // @ghidraAddress 0x28f1d8
static const CGFloat kInputButtonY = 294.0;        // @ghidraAddress 0x28f668
static const CGFloat kInputFieldBorderWidth = 2.0;
static const CGFloat kInputButtonCornerRadius = 8.0;

// The replace-done label's frame (from the ShowReplaceLabel block at 0xd1558).
static const CGFloat kInputReplaceLabelY = 100.0;     // @ghidraAddress 0x28f3f0
static const CGFloat kInputReplaceLabelHeight = 80.0; // @ghidraAddress 0x28f3f8

// The fade duration for the success animation; the pooled double at 0x28f240.
static const NSTimeInterval kInputFadeDuration = 0.2; // @ghidraAddress 0x28f240

// The half-scale used to centre the content columns.
static const CGFloat kInputHalf = 0.5;

@interface InheritCodeInputView () {
    UIImageView *bgView;           // +0x8
    UILabel *expText;              // +0x10
    UITextField *inputText;        // +0x18
    UILabel *replaceText;          // +0x20
    UIButton *sendBtn;             // +0x28
    NSDictionary *repInfo;         // +0x30
    NSMutableDictionary *idBackup; // +0x38
    // _parentCtrl (weak) at +0x40 is synthesised.
}
- (void)showReplaceDoneLabel;
@end

@implementation InheritCodeInputView

@synthesize parentCtrl = _parentCtrl;

#pragma mark - Construction

/** @ghidraAddress 0xd0140 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    CGFloat viewWidth = frame.size.width;
    CGFloat viewHeight = frame.size.height;
    CGFloat contentX = (viewWidth + kInputContentXDelta) * kInputHalf;

    // The background image fills the width and is vertically centred (its top clipped when the
    // image is taller than the view).
    UIImage *bgImage = LoadScaledPngImage(kInputBackgroundImageName);
    CGFloat bgHeight = bgImage.size.height;
    CGFloat bgY = (viewHeight <= bgHeight) ? 0 : (int)((bgHeight - viewHeight) * kInputHalf);
    bgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, bgY, viewWidth, bgHeight)];
    bgView.image = bgImage;
    bgView.userInteractionEnabled = YES;
    [self addSubview:bgView];

    // The caution label.
    expText = [[UILabel alloc]
        initWithFrame:CGRectMake(contentX, kInputExpTextY, kInputContentWidth, kInputFieldHeight)];
    expText.text = kInputCautionText;
    expText.numberOfLines = 0;
    expText.textAlignment = NSTextAlignmentCenter;
    [bgView addSubview:expText];

    // The code input field, white with a black border.
    inputText = [[UITextField alloc]
        initWithFrame:CGRectMake(contentX, kInputFieldY, kInputContentWidth, kInputFieldHeight)];
    inputText.backgroundColor = UIColor.whiteColor;
    inputText.layer.borderColor = UIColor.blackColor.CGColor;
    inputText.layer.borderWidth = kInputFieldBorderWidth;
    inputText.textAlignment = NSTextAlignmentCenter;
    [bgView addSubview:inputText];

    // The send button.
    sendBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    sendBtn.frame = CGRectMake((viewWidth + kInputButtonXDelta) * kInputHalf,
                               kInputButtonY,
                               kInputButtonWidth,
                               kInputFieldHeight);
    [sendBtn setTitle:kInputSendButtonTitle forState:UIControlStateNormal];
    sendBtn.layer.cornerRadius = kInputButtonCornerRadius;
    sendBtn.layer.borderColor = UIColor.grayColor.CGColor;
    sendBtn.layer.borderWidth = kInputFieldBorderWidth;
    [sendBtn setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    sendBtn.backgroundColor = UIColor.whiteColor;
    [sendBtn addTarget:self
                  action:@selector(tapCodeInput:)
        forControlEvents:UIControlEventTouchUpInside];
    [bgView addSubview:sendBtn];
    return self;
}

#pragma mark - Submission

/** @ghidraAddress 0xd06e0 */
- (void)tapCodeInput:(id)sender {
    NSString *code = inputText.text;
    [inputText resignFirstResponder];
    if ([code isEqualToString:@""]) {
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:nil
                                              tag:0
                                            title:@""
                                              msg:kInputEmptyCodeMessage
                                           cancel:ok
                                          btnText:nil
                                             show:YES
                                   viewController:self.parentCtrl];
        return;
    }
    // Submit the code for a check; the response drives -downloaderFinished:.
    NSURL *url = ScratchUtil.getInheritInputURL;
    NSDictionary *body = @{kInputTokenKey : code};
    SessionDownloader *downloader = [[SessionDownloader alloc] initWithURL:url
                                                            postDictionary:body
                                                                  delegate:self];
    downloader.tag = kInputTagCheck;
    [downloader startDownloading];
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0xd0964 */
- (void)alertClose:(NSDictionary *)info {
}

/** @ghidraAddress 0xd0968 */
- (void)alertSelect:(NSDictionary *)info {
    int tag = [info[@"Tag"] intValue];
    int button = [info[@"btnMessage"] intValue];
    if (tag == kInputConfirmAlertTag && button == kInputConfirmOKButton) {
        // The user confirmed the migration: submit the replace request.
        NSURL *url = ScratchUtil.getInheritReplaceURL;
        NSDictionary *body = @{kInputTokenKey : inputText.text};
        SessionDownloader *downloader = [[SessionDownloader alloc] initWithURL:url
                                                                postDictionary:body
                                                                      delegate:self];
        downloader.tag = kInputTagReplace;
        [downloader startDownloading];
        [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    }
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0xd0b90 */
- (void)downloaderFinished:(id)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    int status = [json[kInputKeyStatus] intValue];
    [UIApplication.sharedApplication endIgnoringInteractionEvents];

    if ([downloader tag] == kInputTagReplace) {
        if (status == 0) {
            // The migration succeeded: swap the keychain identity and fade the field out, then
            // reveal the "migration complete" label.
            [EditorIDManager replaceKeyChain:repInfo[kInputKeyUserID]
                                        pass:repInfo[kInputKeyPassword]];
            __weak UILabel *weakExp = expText;
            __weak UITextField *weakInput = inputText;
            __weak UIButton *weakSend = sendBtn;
            __weak InheritCodeInputView *weakSelf = self;
            [UIView animateWithDuration:kInputFadeDuration
                delay:0
                options:UIViewAnimationOptionCurveLinear
                animations:^{
                  /** @ghidraAddress 0xd1460 */
                  weakExp.alpha = 0;
                  weakInput.alpha = 0;
                  weakSend.alpha = 0;
                }
                completion:^(BOOL finished) {
                  /** @ghidraAddress 0xd1558 */
                  [weakSelf showReplaceDoneLabel];
                }];
        } else {
            // A failed migration reports the server's message, or a generic failure.
            NSString *message =
                json[kInputKeyErrorMessage] ? json[kInputKeyErrorMessage] : kInputFailedMessage;
            NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
            [AlertViewManager.sharedManager makeAlert:0
                                             delegate:nil
                                                  tag:0
                                                title:@""
                                                  msg:message
                                               cancel:ok
                                              btnText:nil
                                                 show:YES
                                       viewController:self.parentCtrl];
        }
        return;
    }

    // The check pass (tag 0).
    if (status == 0) {
        repInfo = [json copy];
        NSString *userID = repInfo[kInputKeyUserID];
        NSString *password = repInfo[kInputKeyPassword];
        if (userID && !password) {
            // Its own account: refuse the migration.
            NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
            [AlertViewManager.sharedManager makeAlert:0
                                             delegate:nil
                                                  tag:0
                                                title:@""
                                                  msg:kInputSelfMessage
                                               cancel:ok
                                              btnText:nil
                                                 show:YES
                                       viewController:self.parentCtrl];
            return;
        }
        // A valid other account: confirm the migration.
        NSString *confirm =
            [NSString stringWithFormat:kInputConfirmFormat, repInfo[kInputKeyUserID]];
        NSString *cancel = [NSBundle.mainBundle localizedStringForKey:@"Cancel"
                                                                value:@""
                                                                table:nil];
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:self
                                              tag:kInputConfirmAlertTag
                                            title:@""
                                              msg:confirm
                                           cancel:cancel
                                          btnText:@[ ok ]
                                             show:YES
                                   viewController:self.parentCtrl];
        return;
    }

    // A non-zero check status: an invalid-code message for the 0x192c3/0x192c4 range, else the
    // server's message or the generic server error.
    NSString *message;
    if ((unsigned int)(status - kInputStatusInvalidFirst) < 2) {
        message = kInputInvalidCodeMessage;
    } else if (json[kInputKeyErrorMessage]) {
        message = json[kInputKeyErrorMessage];
    } else {
        message = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg" value:@"" table:nil];
    }
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [AlertViewManager.sharedManager makeAlert:0
                                     delegate:nil
                                          tag:0
                                        title:@""
                                          msg:message
                                       cancel:ok
                                      btnText:nil
                                         show:YES
                               viewController:self.parentCtrl];
}

/** @ghidraAddress 0xd1778 */
- (void)downloaderError:(id)downloader {
    [UIApplication.sharedApplication endIgnoringInteractionEvents];
    NSString *message = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                             value:@""
                                                             table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [AlertViewManager.sharedManager makeAlert:0
                                     delegate:nil
                                          tag:0
                                        title:@""
                                          msg:message
                                       cancel:ok
                                      btnText:nil
                                         show:YES
                               viewController:self.parentCtrl];
}

#pragma mark - Helpers

// De-inlined from the success completion block at 0xd1558: build the "migration complete" label
// inside the background and fade it in. Not a binary selector — the block body reconstructed as a
// helper.
- (void)showReplaceDoneLabel {
    CGFloat labelX = (bgView.frame.size.width + kInputContentXDelta) * kInputHalf;
    replaceText = [[UILabel alloc] initWithFrame:CGRectMake(labelX,
                                                            kInputReplaceLabelY,
                                                            kInputContentWidth,
                                                            kInputReplaceLabelHeight)];
    replaceText.text = kInputReplaceDoneText;
    replaceText.textAlignment = NSTextAlignmentCenter;
    replaceText.alpha = 0;
    [bgView addSubview:replaceText];
    __weak UILabel *weakLabel = replaceText;
    [UIView animateWithDuration:kInputFadeDuration
                          delay:0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                       /** @ghidraAddress 0xd1650 */
                       weakLabel.alpha = 1.0;
                     }
                     completion:nil];
}

@end
