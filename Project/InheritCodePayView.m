#import "InheritCodePayView.h"

#import <QuartzCore/QuartzCore.h>

#import "AlertViewManager.h"
#import "CopyableUiLabel.h"
#import "EditorIDManager.h"
#import "ImageLoading.h"
#import "ScratchUtil.h"

// The issue-request downloader is not reconstructed as a class yet, so it is reached by name, as in
// PurchaseManager.
static NSString *const kSessionDownloaderClassName = @"SessionDownloader";

// The caution text and the button title are UTF-16 CFStrings in the binary; kept verbatim.
static NSString *const kCautionText =
    @"引き継ぎコード入力後30日間は新しい引き継ぎコードを発行することはできません";
static NSString *const kIssueButtonTitle = @"発行する";
static NSString *const kCodeTitleText = @"引き継ぎコード";
static NSString *const kUserIDTitleText = @"あなたのユーザーID";

@implementation InheritCodePayView {
    UIImageView *bgView;           // +0x08, ivar-offset global 0x349a74
    UILabel *warnText;             // +0x10, ivar-offset global 0x349a78
    CopyableUiLabel *codeLabel;    // +0x18, ivar-offset global 0x349a88
    CopyableUiLabel *codeLabel2;   // +0x20, ivar-offset global 0x349a90
    UILabel *codeTitle;            // +0x28, ivar-offset global 0x349a84
    UILabel *codeTitle2;           // +0x30, ivar-offset global 0x349a8c
    UIView *codeBg;                // +0x38, ivar-offset global 0x349a80
    UILabel *failedText;           // +0x40, ivar-offset global 0x349a98
    UIButton *sendBtn;             // +0x48, ivar-offset global 0x349a7c
    UIViewController *_parentCtrl; // +0x50, ivar-offset global 0x349a94
}

/** @ghidraAddress 0x39714 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // The background is centred vertically only when it is shorter than the frame; otherwise it
        // sits at the top. The width comes from the frame, the height from the image.
        // Verified at 0x39770: LoadScaledPngImage(@"inherit_bg"), fcmp d1,d9 / b.le at 0x3979c.
        UIImage *bgImage = LoadScaledPngImage(@"inherit_bg");
        CGFloat bgY = 0;
        if (frame.size.height > bgImage.size.height) {
            bgY = (frame.size.height - bgImage.size.height) * 0.5;
        }
        bgView = [[UIImageView alloc]
            initWithFrame:CGRectMake(0, bgY, frame.size.width, bgImage.size.height)];
        bgView.image = bgImage;
        bgView.userInteractionEnabled = YES;
        [self addSubview:bgView];

        // Caution label. Its origin x is (width - 300) / 2; the pool constant at 0x28f3e8 is
        // -300.0.
        warnText = [[UILabel alloc]
            initWithFrame:CGRectMake((frame.size.width - 300) * 0.5, 100, 300, 80)];
        warnText.text = kCautionText;
        warnText.numberOfLines = 0;
        [bgView addSubview:warnText];

        // Issue button. Origin x is (width - 100) / 2; the pool constant at 0x28f1d8 is -100.0.
        // Its layer gets an 8-point corner radius, a 2-point grey border, and a black title.
        sendBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [sendBtn setFrame:CGRectMake((frame.size.width - 100) * 0.5, 200, 100, 40)];
        [sendBtn setTitle:kIssueButtonTitle forState:UIControlStateNormal];
        sendBtn.backgroundColor = UIColor.whiteColor;
        [sendBtn addTarget:self
                      action:@selector(tapCodeOutput:)
            forControlEvents:UIControlEventTouchUpInside];
        sendBtn.layer.cornerRadius = 8; // 0x4020000000000000 at 0x39a14
        sendBtn.layer.borderColor = UIColor.grayColor.CGColor;
        sendBtn.layer.borderWidth = 2; // 0x4000000000000000 at 0x39aac
        [sendBtn setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        [bgView addSubview:sendBtn];
    }
    return self;
}

/** @ghidraAddress 0x39b40 */
- (void)tapCodeOutput:(nullable id)sender {
    // Verified at 0x39b40: getInheritOutputURL, then the editor identity keys drive a two-entry
    // POST dictionary {"user_id": id, "pass": passphrase} passed to SessionDownloader.
    NSURL *url = [ScratchUtil getInheritOutputURL];
    NSString *userID = [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
    NSString *pass = [EditorIDManager getKeyString:[EditorIDManager getEditorPassKey]];
    NSDictionary *post = [NSDictionary dictionaryWithObjects:@[ userID, pass ]
                                                     forKeys:@[ @"user_id", @"pass" ]];
    id downloader = [NSClassFromString(kSessionDownloaderClassName) alloc];
    downloader = [downloader initWithURL:url postDictionary:post delegate:self];
    [downloader startDownloading];
}

/** @ghidraAddress 0x39d08 */
- (void)downloaderFinished:(id)downloader {
    // Verified at 0x39d08: getDataInJSON, then status = json["status"].intValue. A non-zero status
    // (or the else arm) shows the server-error alert; a zero status builds the code panel.
    NSDictionary *json = [downloader getDataInJSON];
    NSInteger status = [json[@"status"] intValue];
    if (status != 0) {
        // Prefer the server-supplied err_message when present; otherwise the localized fallback.
        // Verified at 0x39d9c-0x39e58: two objectForKey:@"err_message" reads guard the
        // substitution.
        NSString *msg = json[@"err_message"];
        if (!msg) {
            msg = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg" value:@"" table:nil];
        }
        [self _showAlertWithMessage:msg];
        return;
    }

    NSString *token = json[@"token"];

    // The code panel sits over the button, is 310 wide and 188 tall, and starts fully transparent.
    // Its origin x is (width - 310) / 2; the pool constant at 0x28f408 is -310.0, and its origin y
    // is the button's frame origin y (fcvtzs w20,d1 at 0x39f84 reads frame.origin.y).
    CGFloat btnY = sendBtn.frame.origin.y;
    codeBg = [[UIView alloc]
        initWithFrame:CGRectMake((self.frame.size.width - 310) * 0.5, btnY, 310, 188)];
    codeBg.backgroundColor = UIColor.clearColor;
    codeBg.alpha = 0;
    [bgView addSubview:codeBg];

    // "引き継ぎコード" title over the issued token, both centred.
    codeTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 310, 24)];
    codeTitle.text = kCodeTitleText;
    codeTitle.textAlignment = NSTextAlignmentCenter;
    codeTitle.font = [UIFont fontWithName:@"Helvetica" size:18];
    codeTitle.backgroundColor = UIColor.clearColor;
    [codeBg addSubview:codeTitle];

    codeLabel = [[CopyableUiLabel alloc] initWithFrame:CGRectMake(0, 24, 310, 40)];
    codeLabel.text = token;
    codeLabel.textAlignment = NSTextAlignmentCenter;
    codeLabel.font = [UIFont fontWithName:@"Helvetica" size:24];
    codeLabel.backgroundColor = UIColor.whiteColor;
    codeLabel.layer.borderColor = UIColor.blackColor.CGColor;
    codeLabel.layer.borderWidth = 2;
    [codeBg addSubview:codeLabel];

    // "あなたのユーザーID" title over the current editor identifier, both centred.
    codeTitle2 = [[UILabel alloc] initWithFrame:CGRectMake(0, 94, 310, 24)];
    codeTitle2.text = kUserIDTitleText;
    codeTitle2.textAlignment = NSTextAlignmentCenter;
    codeTitle2.font = [UIFont fontWithName:@"Helvetica" size:18];
    codeTitle2.backgroundColor = UIColor.clearColor;
    [codeBg addSubview:codeTitle2];

    codeLabel2 = [[CopyableUiLabel alloc] initWithFrame:CGRectMake(0, 118, 310, 40)];
    codeLabel2.text = [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
    codeLabel2.textAlignment = NSTextAlignmentCenter;
    codeLabel2.font = [UIFont fontWithName:@"Helvetica" size:24];
    codeLabel2.backgroundColor = UIColor.whiteColor;
    codeLabel2.layer.borderColor = UIColor.blackColor.CGColor;
    codeLabel2.layer.borderWidth = 2;
    [codeBg addSubview:codeLabel2];

    // Cross-fade: the button fades out, is then removed, and the panel fades in — each step 0.2s
    // with a linear curve. Both views are captured weakly. Verified at 0x3a650-0x3a71c: two
    // initWeak stores, animateWithDuration:0.2 delay:0 options:0x30000, blocks at 0x3a7c4 and
    // 0x3a810.
    __weak UIButton *weakSendBtn = sendBtn;
    __weak UIView *weakCodeBg = codeBg;
    [UIView animateWithDuration:0.2
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x3a7c4 */
          weakSendBtn.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x3a810 */
          (void)finished;
          // The button is removed outright, then the panel fades in over 0.2s.
          [weakSendBtn removeFromSuperview];
          [UIView animateWithDuration:0.2
                                delay:0
                              options:UIViewAnimationOptionCurveLinear
                           animations:^{
                             /** @ghidraAddress 0x3a8ec */
                             weakCodeBg.alpha = 1;
                           }
                           completion:^(BOOL innerFinished){
                               /** @ghidraAddress 0x3a938 */
                               // Empty completion block (0x2c9d80).
                           }];
        }];
}

/** @ghidraAddress 0x3a998 */
- (void)downloaderError:(id)downloader {
    // Verified at 0x3a998: the localized server-error message and OK title drive the shared alert.
    NSString *msg = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                         value:@""
                                                         table:nil];
    [self _showAlertWithMessage:msg];
}

#pragma mark - Helpers

// The nine-argument alert call is identical in the error path and the failed-status path. Both send
// makeAlert:delegate:tag:title:msg:cancel:btnText:show:viewController: with a nil delegate, a zero
// tag, an empty title, no button text, and the parent controller. Verified at 0x3aa64 and 0x39f10.
- (void)_showAlertWithMessage:(NSString *)msg {
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:@""
                                            msg:msg
                                         cancel:ok
                                        btnText:nil
                                           show:YES
                                 viewController:self.parentCtrl];
}

@end
