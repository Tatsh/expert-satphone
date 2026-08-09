#import "JcfUpLoadView.h"

#import <QuartzCore/QuartzCore.h>
#import <Social/Social.h>

#import "ImageLoading.h"
#import "JcfUploader.h"
#import "JubeatAppDelegate.h"
#import "ShadowView.h"
#import "StoreButton.h"

// LicenseAgreementView is reconstructed in LicenseAgreementView.h, but that header declares its
// initialiser as -initWithKeyString:, whereas the binary calls the two-argument selector
// init:keyString: (delegate first, then the preference key). Forward-declare the real selector here
// rather than editing that file.
@interface LicenseAgreementView : UIView
- (instancetype)init:(nullable id)delegate keyString:(nullable NSString *)keyString;
@end

// The board width is chosen by device idiom; the height is the same on both.
static const CGFloat kBoardWidthPad = 320.0;   // @ghidraAddress 0x28f470
static const CGFloat kBoardWidthPhone = 300.0; // @ghidraAddress 0x28f2d0
static const CGFloat kBoardHeight = 360.0;     // @ghidraAddress 0x292918

// The gradient-backed board's own layer styling.
static const CGFloat kBoardCornerRadius = 6.0; // fmov immediate at 0x1f330c
static const CGFloat kBoardBorderWidth = 2.0;  // fmov immediate at 0x1f331c
static const CGFloat kBoardShadowRadius = 4.0; // fmov immediate at 0x1f35c0
static const float kBoardShadowOpacity = 0.5f; // fmov immediate at 0x1f35f0
// The board gradient runs from the top, through a stop this many points down, to the bottom.
static const CGFloat kGradientMidLocationNumerator = 40.0; // @ghidraAddress 0x28f1f8
// The three greys of the board gradient (top to bottom).
static const CGFloat kGradientWhiteTop = 0.961;    // @ghidraAddress 0x292420
static const CGFloat kGradientWhiteMiddle = 0.855; // @ghidraAddress 0x292428
static const CGFloat kGradientWhiteBottom = 0.762; // @ghidraAddress 0x292430

// The shared blue-green fill of the store-style buttons.
static const CGFloat kButtonFillGreen = 0.433;       // @ghidraAddress 0x292440
static const CGFloat kButtonFillBlue = 0.617;        // @ghidraAddress 0x292448
static const CGFloat kStoreButtonCornerRadius = 3.0; // fmov immediate at 0x1f3a74
static const CGFloat kButtonTitleFontSize = 14.0;    // fmov immediate at 0x1f3ac8

// The upload icon, at the board's top-left corner.
static const CGFloat kIconX = 16.0;      // fmov immediate at 0x1f3660
static const CGFloat kIconY = 9.0;       // fmov immediate at 0x1f3664
static const CGFloat kIconWidth = 26.0;  // fmov immediate at 0x1f3668
static const CGFloat kIconHeight = 24.0; // fmov immediate at 0x1f366c

// The upload background, framed against the board's own frame at its bottom-right corner.
static const CGFloat kUploadBgXOffset = -106.0; // @ghidraAddress 0x292408 (added to board width)
static const CGFloat kUploadBgYOffset = -62.0;  // @ghidraAddress 0x292920 (added to board height)
static const CGFloat kUploadBgWidth = 106.0;    // @ghidraAddress 0x292928
static const CGFloat kUploadBgHeight = 62.0;    // @ghidraAddress 0x292930

// The message label, whose width tracks the board width.
static const CGFloat kMessageLabelX = 30.0;           // fmov immediate at 0x1f3810
static const CGFloat kMessageLabelY = 11.0;           // fmov immediate at 0x1f3814
static const CGFloat kMessageLabelWidthInset = -60.0; // @ghidraAddress 0x291bc8 (added to width)
static const CGFloat kMessageLabelHeight = 20.0;      // fmov immediate at 0x1f3818
static const CGFloat kMessageLabelFontSize = 15.0;    // fmov immediate at 0x1f38b0

// The inner-shadow overlay, sized from the board. Its x is the icon's x, and its y is the same
// constant that drives the gradient's middle stop.
static const CGFloat kShadowWidthInset = -32.0;  // @ghidraAddress 0x292938 (added to board width)
static const CGFloat kShadowHeightInset = -88.0; // @ghidraAddress 0x292940 (added to board height)

// The three store-style buttons, anchored to the bottom of the board and split about its centre.
static const CGFloat kButtonHeight = 32.0;            // @ghidraAddress 0x28f458
static const CGFloat kButtonHorizontalPadding = 24.0; // fmov immediate at 0x1f3bd4; added to fit.
static const CGFloat kCentreRatio = 0.5;              // fmov immediate at 0x1f37b4
// The bottom margin is boardHeight minus these two, and the centre gap is ten points either way.
static const CGFloat kButtonBottomFirstMargin = -24.0;  // fmov immediate at 0x1f3be8
static const CGFloat kButtonBottomSecondMargin = -16.0; // fmov immediate at 0x1f3bf0
static const CGFloat kButtonCentreGap = 10.0;           // fmov immediate at 0x1f3df8 / 0x1f3fcc

// The first (grey-styled) activity indicator, centred horizontally and placed a fifth of the way
// down. The binary loads this ratio as a single-precision literal here.
static const CGFloat kIndicatorHalfWidth = 16.0;  // fmov immediate at 0x1f4058
static const float kIndicatorCenterYRatio = 0.2f; // @ghidraAddress 0x28f240
// The second (grey) indicator uses the double-precision copy of the same ratio.
static const CGFloat kIndicatorYRatio = 0.2; // @ghidraAddress 0x28e040

// The progress label, inset ten points and shrunk twenty each way.
static const CGFloat kProgressLabelInset = 10.0;   // fmov immediate at 0x1f417c
static const CGFloat kProgressLabelMargin = -20.0; // fmov immediate at 0x1f415c

// The swap-buttons fade shown when the upload is confirmed.
static const NSTimeInterval kSwapButtonsFadeDuration = 0.6; // @ghidraAddress 0x28f288

// The share buttons, anchored to the board's bottom-right corner from the icon sizes.
static const CGFloat kShareButtonRightInset = -10.0;  // fmov immediate at 0x1f4ae0
static const CGFloat kShareButtonBottomInset = -50.0; // @ghidraAddress 0x28e068 (added to height)
static const int kFacebookButtonGap = 5;              // add immediate at 0x1f4be8

// The icon assets loaded onto the board and share buttons.
static NSString *const kIconImageName = @"menu_icon_upload";
static NSString *const kUploadBgImageName = @"upload_bg";
static NSString *const kTwitterImageName = @"icon_twitter";
static NSString *const kFacebookImageName = @"icon_facebook";

// The button title keys, looked up in the default table.
static NSString *const kCancelButtonKey = @"Cancel";
static NSString *const kOKButtonKey = @"OK";

// The preference key handed to the licence-agreement overlay.
static NSString *const kLicenseVersionKey = @"PrefAgreeLicenseVersion";

// The upload-info dictionary keys returned by the server.
static NSString *const kSeqIDKey = @"SeqID";
static NSString *const kSNSMesKey = @"SNSMes";

// The status strings, from the UTF-16 CFStrings in __cfstring.
static NSString *const kConfirmText = @"アップロードを開始します。\nよろしいですか？"; // 0x2c19c6
static NSString *const kPreparingText = @"アップロード準備中";                         // 0x2c19f4
static NSString *const kUploadingText = @"アップロード中";                             // 0x2c1a08
// The default failure message when the uploader supplies none.
static NSString *const kDefaultUploadFailureText = @"アップロードできませんでした。"; // 0x2c1a18
// The NG-word rejection message, whose three placeholders take the offending words.
static NSString *const kNGWordsFormat = @"不適切な単語が含まれているので、アップロードを受け付ける"
                                        @"事ができませんでした。変更してください。\n\n%@"
                                        @"\n\n%@\n\n%@\n\n\n"; // 0x2c1a38
// The success message, whose placeholder takes the resolved sequence id.
static NSString *const kUploadSuccessFormat = @"アップロード成功\n譜面IDは%@"; // 0x2c1ab8
// The default failure message when the agreement step supplies none.
static NSString *const kDefaultAgreementFailureText = @"アップロードに失敗しました。"; // 0x2c1ade

@implementation JcfUpLoadView {
    UIView *coverBoard;       // Declared in the metadata; untouched by the compiled methods here.
    UIView *shadowView;       // The inner-shadow overlay (built and stored but never added).
    UILabel *labelMessage;    // The board title label (built and added but left with no text).
    UILabel *textLabel;       // The status label.
    StoreButton *btnCancel;   // The post-result button, centred, hidden until the outcome is shown.
    StoreButton *btnUpCancel; // The confirmation Cancel button, right of centre.
    StoreButton *btnUpOK;     // The confirmation OK button, left of centre.
    UIButton *btnTwitter;     // The Twitter share button, revealed on success.
    UIButton *btnFaceBook;    // The Facebook share button, revealed on success when available.
    UIActivityIndicatorView *indicatorView; // The spinner shown while uploading.
    NSURL *requestURL;        // Declared in the metadata; untouched by the compiled methods here.
    JcfUploader *seqUploader; // The owned uploader, armed at construction and started later.
    unsigned int sequenceID;  // Declared in the metadata; untouched by the compiled methods here.
    BOOL bEnableSocialFrameWork;  // Whether the Social framework (SLComposeViewController) exists.
    UIViewController *controller; // The controller used to present the share sheet.
    LicenseAgreementView *licenseAgree; // The licence-agreement overlay shown before uploading.
    NSString *packID;    // Reused here to hold the SeqID string resolved by a successful upload.
    NSString *socialStr; // The SNSMes share text resolved by a successful upload.
    __weak id<JcfUpLoadViewDelegate> delegate;
}

#pragma mark - Layer

/** @ghidraAddress 0x1f319c */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

#pragma mark - Construction

/** @ghidraAddress 0x1f31b0 */
- (instancetype)initWithData:(NSData *)data
                    delegate:(id<JcfUpLoadViewDelegate>)delegateArg
                        ctrl:(UIViewController *)ctrl {
    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    CGFloat boardWidth = isPad ? kBoardWidthPad : kBoardWidthPhone;
    self = [super initWithFrame:CGRectMake(0, 0, boardWidth, kBoardHeight)];
    if (self) {
        delegate = delegateArg;
        controller = ctrl;

        CAGradientLayer *gradient = (CAGradientLayer *)self.layer;
        gradient.cornerRadius = kBoardCornerRadius;
        gradient.borderWidth = kBoardBorderWidth;
        gradient.borderColor = UIColor.lightGrayColor.CGColor;
        gradient.locations =
            @[ @(0.0f), @(kGradientMidLocationNumerator / self.frame.size.height), @(1.0f) ];
        gradient.colors = @[
            (__bridge id)[UIColor colorWithWhite:kGradientWhiteTop alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithWhite:kGradientWhiteMiddle alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithWhite:kGradientWhiteBottom alpha:1.0].CGColor
        ];
        // The light-grey border set above is immediately replaced with grey.
        gradient.borderColor = UIColor.grayColor.CGColor;
        gradient.shadowRadius = kBoardShadowRadius;
        gradient.shadowOffset = CGSizeZero;
        gradient.shadowOpacity = kBoardShadowOpacity;

        UIImageView *icon = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kIconImageName)];
        icon.frame = CGRectMake(kIconX, kIconY, kIconWidth, kIconHeight);
        [self addSubview:icon];

        // The upload background is loaded, framed against the board's own frame, and added.
        UIImageView *background =
            [[UIImageView alloc] initWithImage:LoadScaledPngImage(kUploadBgImageName)];
        background.frame = CGRectMake(self.frame.size.width + kUploadBgXOffset,
                                      self.frame.size.height + kUploadBgYOffset,
                                      kUploadBgWidth,
                                      kUploadBgHeight);
        [self addSubview:background];

        CGFloat centreX = boardWidth * kCentreRatio;

        // The first (white-large) spinner is created, centred, and added, then immediately
        // orphaned: the ivar is overwritten below with the grey spinner that the board keeps.
        indicatorView = [[UIActivityIndicatorView alloc]
            initWithFrame:CGRectMake(
                              0, 0, kGradientMidLocationNumerator, kGradientMidLocationNumerator)];
        indicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
        indicatorView.center = CGPointMake(centreX, (int)(kBoardHeight * kIndicatorCenterYRatio));
        [self addSubview:indicatorView];

        labelMessage =
            [[UILabel alloc] initWithFrame:CGRectMake(kMessageLabelX,
                                                      kMessageLabelY,
                                                      boardWidth + kMessageLabelWidthInset,
                                                      kMessageLabelHeight)];
        [labelMessage setOpaque:NO];
        labelMessage.backgroundColor = UIColor.clearColor;
        labelMessage.font = [UIFont boldSystemFontOfSize:kMessageLabelFontSize];
        labelMessage.textColor = UIColor.blackColor;
        labelMessage.textAlignment = NSTextAlignmentCenter;
        [self addSubview:labelMessage];

        // The inner-shadow overlay is built and stored but, like the sibling modal, never added.
        shadowView =
            [[ShadowView alloc] initWithFrame:CGRectMake(kIconX,
                                                         kGradientMidLocationNumerator,
                                                         boardWidth + kShadowWidthInset,
                                                         kBoardHeight + kShadowHeightInset)];

        CGFloat buttonY = kBoardHeight + kButtonBottomFirstMargin + kButtonBottomSecondMargin;

        btnCancel = [[StoreButton alloc] initWithFrame:CGRectZero];
        // The original used the full component call; green and blue are non-standard components.
        btnCancel.buttonColor = [UIColor colorWithRed:0
                                                green:kButtonFillGreen
                                                 blue:kButtonFillBlue
                                                alpha:1.0];
        btnCancel.cornerRadius = kStoreButtonCornerRadius;
        [btnCancel setExclusiveTouch:YES];
        btnCancel.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonTitleFontSize];
        [btnCancel setTitle:[NSBundle.mainBundle localizedStringForKey:kCancelButtonKey
                                                                 value:@""
                                                                 table:nil]
                   forState:UIControlStateNormal];
        [btnCancel addTarget:self
                      action:@selector(pushCancel:)
            forControlEvents:UIControlEventTouchUpInside];
        [btnCancel sizeToFit];
        CGFloat cancelWidth = btnCancel.frame.size.width + kButtonHorizontalPadding;
        btnCancel.frame =
            CGRectMake(centreX - cancelWidth * kCentreRatio, buttonY, cancelWidth, kButtonHeight);
        // The post-result button starts hidden; the confirmation buttons carry the initial state.
        [btnCancel setAlpha:0];

        btnUpCancel = [[StoreButton alloc] initWithFrame:CGRectZero];
        btnUpCancel.buttonColor = [UIColor colorWithRed:0
                                                  green:kButtonFillGreen
                                                   blue:kButtonFillBlue
                                                  alpha:1.0];
        btnUpCancel.cornerRadius = kStoreButtonCornerRadius;
        [btnUpCancel setExclusiveTouch:YES];
        btnUpCancel.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonTitleFontSize];
        [btnUpCancel setTitle:[NSBundle.mainBundle localizedStringForKey:kCancelButtonKey
                                                                   value:@""
                                                                   table:nil]
                     forState:UIControlStateNormal];
        [btnUpCancel addTarget:self
                        action:@selector(pushCancel:)
              forControlEvents:UIControlEventTouchUpInside];
        [btnUpCancel sizeToFit];
        CGFloat upCancelWidth = btnUpCancel.frame.size.width + kButtonHorizontalPadding;
        btnUpCancel.frame =
            CGRectMake(centreX + kButtonCentreGap, buttonY, upCancelWidth, kButtonHeight);

        btnUpOK = [[StoreButton alloc] initWithFrame:CGRectZero];
        btnUpOK.buttonColor = [UIColor colorWithRed:0
                                              green:kButtonFillGreen
                                               blue:kButtonFillBlue
                                              alpha:1.0];
        btnUpOK.cornerRadius = kStoreButtonCornerRadius;
        [btnUpOK setExclusiveTouch:YES];
        btnUpOK.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonTitleFontSize];
        // The button is first titled Cancel, then retitled OK below: a faithful quirk of the
        // binary.
        [btnUpOK setTitle:[NSBundle.mainBundle localizedStringForKey:kCancelButtonKey
                                                               value:@""
                                                               table:nil]
                 forState:UIControlStateNormal];
        [btnUpOK addTarget:self
                      action:@selector(pushUploadOK:)
            forControlEvents:UIControlEventTouchUpInside];
        [btnUpOK sizeToFit];
        CGFloat upOKWidth = btnUpOK.frame.size.width + kButtonHorizontalPadding;
        btnUpOK.frame =
            CGRectMake(centreX - upOKWidth - kButtonCentreGap, buttonY, upOKWidth, kButtonHeight);
        [btnUpOK setTitle:[NSBundle.mainBundle localizedStringForKey:kOKButtonKey
                                                               value:@""
                                                               table:nil]
                 forState:UIControlStateNormal];

        // The retained grey spinner replaces the orphaned white-large one; it is hidden and
        // stopped.
        indicatorView = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        indicatorView.frame = CGRectMake(centreX - kIndicatorHalfWidth,
                                         kBoardHeight * kIndicatorYRatio,
                                         kButtonHeight,
                                         kButtonHeight);
        indicatorView.hidesWhenStopped = YES;
        [indicatorView stopAnimating];

        [self addSubview:btnCancel];
        [self addSubview:btnUpCancel];
        [self addSubview:btnUpOK];
        [self addSubview:indicatorView];

        CGRect textFrame = CGRectMake(kProgressLabelInset,
                                      kProgressLabelInset,
                                      self.frame.size.width + kProgressLabelMargin,
                                      self.frame.size.height + kProgressLabelMargin);
        textLabel = [[UILabel alloc] initWithFrame:textFrame];
        textLabel.backgroundColor = UIColor.clearColor;
        textLabel.textAlignment = NSTextAlignmentCenter;
        textLabel.text = kConfirmText;
        textLabel.numberOfLines = 0;
        [self addSubview:textLabel];

        // The uploader is armed but not started here: -uploadStart begins it after the licence
        // step.
        seqUploader = [[JcfUploader alloc] initWithData:data delegate:self];

        bEnableSocialFrameWork = NO;
        if (NSClassFromString(@"SLComposeViewController")) {
            bEnableSocialFrameWork = YES;
        }
    }
    return self;
}

#pragma mark - Actions

/** @ghidraAddress 0x1f4304 */
- (void)pushCancel:(id)sender {
    [self uploadEnd];
}

/** @ghidraAddress 0x1f4310 */
- (void)pushUploadOK:(id)sender {
    [indicatorView startAnimating];
    textLabel.text = kPreparingText;
    [UIView animateWithDuration:kSwapButtonsFadeDuration
                     animations:^{
                       /** @ghidraAddress 0x1f43e4 */
                       // Swap the confirmation buttons out for the single post-result button.
                       [self->btnUpOK setAlpha:0];
                       [self->btnUpCancel setAlpha:0];
                       [self->btnCancel setAlpha:1.0];
                     }];
    [self licenseStart];
}

#pragma mark - Licence step

/** @ghidraAddress 0x1f4468 */
- (void)licenseStart {
    licenseAgree = [[LicenseAgreementView alloc] init:self keyString:kLicenseVersionKey];
    [self addSubview:licenseAgree];
}

#pragma mark - Upload flow

/** @ghidraAddress 0x1f44d8 */
- (void)uploadStart {
    textLabel.text = kUploadingText;
    [seqUploader start];
}

/** @ghidraAddress 0x1f4528 */
- (void)startUpload {
    // The binary's body is empty.
}

/** @ghidraAddress 0x1f452c */
- (void)uploadEnd {
    // The binary passes the delegate itself (not self) as the object argument.
    id<JcfUpLoadViewDelegate> theDelegate = delegate;
    if ([theDelegate respondsToSelector:@selector(uploadEnd:)]) {
        [theDelegate performSelector:@selector(uploadEnd:) withObject:theDelegate];
    }
}

#pragma mark - JcfUploaderDelegate

/** @ghidraAddress 0x1f45d0 */
- (void)uploadError:(JcfUploader *)uploader msgStr:(NSString *)msg {
    [indicatorView stopAnimating];
    textLabel.text = msg ?: kDefaultUploadFailureText;
    [btnCancel setTitle:[NSBundle.mainBundle localizedStringForKey:kOKButtonKey value:@"" table:nil]
               forState:UIControlStateNormal];
}

/** @ghidraAddress 0x1f46d8 */
- (void)uploadNG:(JcfUploader *)uploader ngWords:(NSArray *)ngWords {
    [indicatorView stopAnimating];
    textLabel.text = [NSString stringWithFormat:kNGWordsFormat, ngWords[0], ngWords[1], ngWords[2]];
    seqUploader = nil;
    [btnCancel setTitle:[NSBundle.mainBundle localizedStringForKey:kOKButtonKey value:@"" table:nil]
               forState:UIControlStateNormal];
}

/** @ghidraAddress 0x1f48ac */
- (void)uploadSuccess:(JcfUploader *)uploader uploadInfo:(NSDictionary *)uploadInfo {
    [indicatorView stopAnimating];
    NSString *seqID = uploadInfo[kSeqIDKey];
    socialStr = uploadInfo[kSNSMesKey];
    packID = [NSString stringWithString:seqID];
    textLabel.text = [NSString stringWithFormat:kUploadSuccessFormat, seqID];
    seqUploader = nil;
    [btnCancel setTitle:[NSBundle.mainBundle localizedStringForKey:kOKButtonKey value:@"" table:nil]
               forState:UIControlStateNormal];

    UIImage *twitterImage = LoadScaledPngImage(kTwitterImageName);
    int twitterWidth = (int)twitterImage.size.width;
    int twitterHeight = (int)twitterImage.size.height;
    CGFloat twitterX = self.frame.size.width - twitterWidth + kShareButtonRightInset;
    CGFloat twitterY = self.frame.size.height - twitterHeight + kShareButtonBottomInset;

    btnTwitter = [UIButton buttonWithType:UIButtonTypeCustom];
    btnTwitter.frame = CGRectMake(twitterX, twitterY, twitterWidth, twitterHeight);
    [btnTwitter setImage:twitterImage forState:UIControlStateNormal];
    [btnTwitter setExclusiveTouch:YES];
    [btnTwitter addTarget:self
                   action:@selector(uploadSendTwitter:)
         forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:btnTwitter];

    if (bEnableSocialFrameWork) {
        CGFloat facebookX = twitterX - (twitterWidth + kFacebookButtonGap);
        UIImage *facebookImage = LoadScaledPngImage(kFacebookImageName);
        btnFaceBook = [UIButton buttonWithType:UIButtonTypeCustom];
        btnFaceBook.frame =
            CGRectMake(facebookX, twitterY, facebookImage.size.width, facebookImage.size.height);
        [btnFaceBook setImage:facebookImage forState:UIControlStateNormal];
        [btnFaceBook setExclusiveTouch:YES];
        [btnFaceBook addTarget:self
                        action:@selector(uploadSendFacebook:)
              forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btnFaceBook];
    }
}

#pragma mark - LicenseAgreementView callbacks

/** @ghidraAddress 0x1f4d2c */
- (void)agreementError:(id)sender msgStr:(NSString *)msg {
    [indicatorView stopAnimating];
    textLabel.text = msg ?: kDefaultAgreementFailureText;
    [btnCancel setTitle:[NSBundle.mainBundle localizedStringForKey:kOKButtonKey value:@"" table:nil]
               forState:UIControlStateNormal];
    [licenseAgree removeFromSuperview];
    licenseAgree = nil;
}

/** @ghidraAddress 0x1f4e60 */
- (void)agreementSuccess:(id)sender {
    [self uploadStart];
    [licenseAgree removeFromSuperview];
    licenseAgree = nil;
}

/** @ghidraAddress 0x1f4ea8 */
- (void)agreementFailed:(id)sender {
    [self uploadEnd];
}

#pragma mark - Sharing

/** @ghidraAddress 0x1f4eb4 */
- (void)socialSend:(NSString *)serviceType {
    SLComposeViewController *composer =
        [SLComposeViewController composeViewControllerForServiceType:serviceType];
    NSString *text = socialStr;
    if (!text) {
        // The share text falls back to the stored sequence id when no message was returned.
        text = [NSString stringWithFormat:@"%@", packID];
    }
    [composer setInitialText:text];
    [composer setCompletionHandler:^(SLComposeViewControllerResult result) {
      /** @ghidraAddress 0x1f4ffc */
      // Dismiss the composer whether it was cancelled or sent.
      if (result == SLComposeViewControllerResultCancelled ||
          result == SLComposeViewControllerResultDone) {
          [self->controller dismissViewControllerAnimated:YES completion:nil];
      }
    }];
    [controller presentViewController:composer animated:YES completion:nil];
}

/** @ghidraAddress 0x1f5040 */
- (void)uploadSendTwitter:(id)sender {
    [self socialSend:SLServiceTypeTwitter];
}

/** @ghidraAddress 0x1f5058 */
- (void)uploadSendFacebook:(id)sender {
    if (bEnableSocialFrameWork) {
        [self socialSend:SLServiceTypeFacebook];
    }
}

@end
