#import "JcfDownloadView.h"

#import <QuartzCore/QuartzCore.h>

#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "ShadowView.h"
#import "StoreButton.h"

// The board width is chosen by device idiom; the height is the same on both.
static const CGFloat kBoardWidthPad = 320.0;   // @ghidraAddress 0x28f470
static const CGFloat kBoardWidthPhone = 300.0; // @ghidraAddress 0x28f2d0
static const CGFloat kBoardHeight = 360.0;     // @ghidraAddress 0x292918

// The gradient-backed board's own layer styling.
static const CGFloat kBoardCornerRadius = 6.0; // fmov immediate at 0x1eb77c
static const CGFloat kBoardBorderWidth = 2.0;  // fmov immediate at 0x1eb78c
static const CGFloat kBoardShadowRadius = 4.0; // fmov immediate at 0x1eba34
static const float kBoardShadowOpacity = 0.5f; // fmov immediate at 0x1eba64
// The board gradient runs from the top, through a stop this many points down, to the bottom.
static const CGFloat kGradientMidLocationNumerator = 40.0; // @ghidraAddress 0x28f1f8
// The three greys of the board gradient (top to bottom).
static const CGFloat kGradientWhiteTop = 0.961;    // @ghidraAddress 0x292420
static const CGFloat kGradientWhiteMiddle = 0.855; // @ghidraAddress 0x292428
static const CGFloat kGradientWhiteBottom = 0.762; // @ghidraAddress 0x292430

// The shared blue-green fill of the store-style buttons.
static const CGFloat kButtonFillGreen = 0.433;       // @ghidraAddress 0x292440
static const CGFloat kButtonFillBlue = 0.617;        // @ghidraAddress 0x292448
static const CGFloat kStoreButtonCornerRadius = 3.0; // fmov immediate at 0x1ebe40
static const CGFloat kButtonTitleFontSize = 14.0;    // fmov immediate at 0x1ebe90

// The download icon, at the board's top-left corner.
static const CGFloat kIconX = 16.0;      // fmov immediate at 0x1ebad0
static const CGFloat kIconY = 9.0;       // fmov immediate at 0x1ebad4
static const CGFloat kIconWidth = 26.0;  // fmov immediate at 0x1ebad8
static const CGFloat kIconHeight = 24.0; // fmov immediate at 0x1ebadc

// The upload background, framed against the board's own frame at its bottom-right corner.
static const CGFloat kUploadBgXOffset = -106.0; // @ghidraAddress 0x292408 (added to board width)
static const CGFloat kUploadBgYOffset = -62.0;  // @ghidraAddress 0x292920 (added to board height)
static const CGFloat kUploadBgWidth = 106.0;    // @ghidraAddress 0x292928
static const CGFloat kUploadBgHeight = 62.0;    // @ghidraAddress 0x292930

// The message label, whose width tracks the board width.
static const CGFloat kMessageLabelX = 30.0;           // fmov immediate at 0x1ebbe0
static const CGFloat kMessageLabelY = 11.0;           // fmov immediate at 0x1ebbe4
static const CGFloat kMessageLabelWidthInset = -60.0; // @ghidraAddress 0x291bc8 (added to width)
static const CGFloat kMessageLabelHeight = 20.0;      // fmov immediate at 0x1ebbe8
static const CGFloat kMessageLabelFontSize = 15.0;    // fmov immediate at 0x1ebc7c

// The inner-shadow overlay, sized from the board. Its x is the icon's x, and its y is the same
// constant that drives the gradient's middle stop.
static const CGFloat kShadowWidthInset = -32.0;  // @ghidraAddress 0x292938 (added to board width)
static const CGFloat kShadowHeightInset = -88.0; // @ghidraAddress 0x292940 (added to board height)

// The three buttons, anchored to the bottom of the board and split about its centre.
static const CGFloat kButtonHeight = 32.0;            // @ghidraAddress 0x28f458
static const CGFloat kButtonHorizontalPadding = 24.0; // fmov immediate at 0x1ebf9c; added to fit.
static const CGFloat kCentreRatio = 0.5;              // fmov immediate at 0x1ebfa4
// The bottom margin is boardHeight minus these two, and the centre gap is ten points either way.
static const CGFloat kButtonBottomFirstMargin = -24.0;  // fmov immediate at 0x1ebfb4
static const CGFloat kButtonBottomSecondMargin = -16.0; // fmov immediate at 0x1ebfbc
static const CGFloat kButtonCentreGap = 10.0;           // fmov immediate at 0x1ec1b8 / 0x1ec3f8

// The activity indicator, centred horizontally and placed a fifth of the way down.
static const CGFloat kIndicatorHalfWidth = 16.0; // fmov immediate at 0x1ec418
static const CGFloat kIndicatorYRatio = 0.2;     // @ghidraAddress 0x28e040

// The progress label added by -startDownload, inset ten points and shrunk twenty each way.
static const CGFloat kProgressLabelInset = 10.0;   // fmov immediate at 0x1ec6bc
static const CGFloat kProgressLabelMargin = -20.0; // fmov immediate at 0x1ec69c

// The reveal-buttons fade after a missing-pack outcome.
static const NSTimeInterval kEndButtonsFadeDuration = 0.6; // @ghidraAddress 0x28f288

// The two icon assets loaded onto the board.
static NSString *const kIconImageName = @"menu_icon_download";
static NSString *const kUploadBgImageName = @"upload_bg";

// The button title keys, looked up in the default table.
static NSString *const kCancelButtonKey = @"Cancel";
static NSString *const kOKButtonKey = @"OK";

// The status strings, from the UTF-16 CFStrings in __cfstring.
static NSString *const kDownloadingText = @"ダウンロード中"; // 0x2e16c0
// The default failure message when the downloader supplies none.
static NSString *const kDefaultFailureText = @"ダウンロードに失敗しました。"; // 0x2e16e0
static NSString *const kOverCapText =
    @"スロットに空きがなかったので保存できませんでした。"; // 0x2e1700
static NSString *const kNotExistPackText =
    @"曲を持っていません。ストアに移動しますか？";                     // 0x2e1720
static NSString *const kCompletedText = @"ダウンロードが終了しました"; // 0x2e1740

// The sentinel meaning no tune has been resolved yet.
static const int kNoMusicID = -1;

@implementation JcfDownloadView {
    UIView *coverBoard;     // Declared in the metadata; untouched by the compiled methods here.
    UILabel *labelMessage;  // The board title label (built but left with no text).
    UIView *shadowView;     // The inner-shadow overlay (built and stored but never added).
    StoreButton *btnCancel; // The centred button shown while the download runs.
    StoreButton *btnOK;     // The move-to-store button, left of centre, hidden until revealed.
    StoreButton *btnEnd;    // The end button, right of centre, hidden until revealed.
    UIActivityIndicatorView *indicatorView; // The spinner shown while downloading.
    NSURL *requestURL; // Declared in the metadata; untouched by the compiled methods here.
    JcfDownloader *jcfDownloader; // The owned downloader, started at construction.
    unsigned int sequenceID; // Declared in the metadata; untouched by the compiled methods here.
    BOOL bEnableSocialFrameWork; // Declared in the metadata; untouched here.
    NSString *packID;            // The comprised-pack id resolved by a missing-pack outcome.
    int musicID;                 // The tune id resolved by a successful download, or kNoMusicID.
    UILabel *textLabel;          // The progress label added by -startDownload.
    __weak id<JcfDownloadViewDelegate> delegate;
}

#pragma mark - Layer

/** @ghidraAddress 0x1eb4ec */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

#pragma mark - Construction

/** @ghidraAddress 0x1eb500 */
- (void)createStoreBtn:(id)sender {
    // The button is built but neither stored nor added: the binary discards it, and the sender
    // argument is ignored.
    StoreButton *button = [[StoreButton alloc] initWithFrame:CGRectZero];
    // The original used the full component call; green and blue are non-standard components.
    button.buttonColor = [UIColor colorWithRed:0
                                         green:kButtonFillGreen
                                          blue:kButtonFillBlue
                                         alpha:1.0];
    button.cornerRadius = kStoreButtonCornerRadius;
    [button setExclusiveTouch:YES];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonTitleFontSize];
}

/** @ghidraAddress 0x1eb638 */
- (instancetype)initWithID:(NSString *)customID delegate:(id<JcfDownloadViewDelegate>)delegateArg {
    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    CGFloat boardWidth = isPad ? kBoardWidthPad : kBoardWidthPhone;
    self = [super initWithFrame:CGRectMake(0, 0, boardWidth, kBoardHeight)];
    if (self) {
        musicID = kNoMusicID;
        delegate = delegateArg;

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

        // The inner-shadow overlay is built and stored but, unlike the sibling modals, never
        // added to the view hierarchy.
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
        btnCancel.frame = CGRectMake(boardWidth * kCentreRatio - cancelWidth * kCentreRatio,
                                     buttonY,
                                     cancelWidth,
                                     kButtonHeight);

        btnOK = [[StoreButton alloc] initWithFrame:CGRectZero];
        btnOK.buttonColor = [UIColor colorWithRed:0
                                            green:kButtonFillGreen
                                             blue:kButtonFillBlue
                                            alpha:1.0];
        btnOK.cornerRadius = kStoreButtonCornerRadius;
        [btnOK setExclusiveTouch:YES];
        btnOK.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonTitleFontSize];
        // The button is first titled Cancel, then retitled OK below: a faithful quirk of the
        // binary.
        [btnOK setTitle:[NSBundle.mainBundle localizedStringForKey:kCancelButtonKey
                                                             value:@""
                                                             table:nil]
               forState:UIControlStateNormal];
        [btnOK addTarget:self
                      action:@selector(pushMoveStore:)
            forControlEvents:UIControlEventTouchUpInside];
        [btnOK sizeToFit];
        [btnOK setAlpha:0];
        CGFloat okWidth = btnOK.frame.size.width + kButtonHorizontalPadding;
        btnOK.frame = CGRectMake(boardWidth * kCentreRatio - okWidth - kButtonCentreGap,
                                 buttonY,
                                 okWidth,
                                 kButtonHeight);
        [btnOK setTitle:[NSBundle.mainBundle localizedStringForKey:kOKButtonKey value:@"" table:nil]
               forState:UIControlStateNormal];

        btnEnd = [[StoreButton alloc] initWithFrame:CGRectZero];
        btnEnd.buttonColor = [UIColor colorWithRed:0
                                             green:kButtonFillGreen
                                              blue:kButtonFillBlue
                                             alpha:1.0];
        btnEnd.cornerRadius = kStoreButtonCornerRadius;
        [btnEnd setExclusiveTouch:YES];
        btnEnd.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonTitleFontSize];
        [btnEnd setTitle:[NSBundle.mainBundle localizedStringForKey:kCancelButtonKey
                                                              value:@""
                                                              table:nil]
                forState:UIControlStateNormal];
        [btnEnd addTarget:self
                      action:@selector(pushCancel:)
            forControlEvents:UIControlEventTouchUpInside];
        [btnEnd sizeToFit];
        [btnEnd setAlpha:0];
        CGFloat endWidth = btnEnd.frame.size.width + kButtonHorizontalPadding;
        btnEnd.frame = CGRectMake(
            boardWidth * kCentreRatio + kButtonCentreGap, buttonY, endWidth, kButtonHeight);

        indicatorView = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        indicatorView.frame = CGRectMake(boardWidth * kCentreRatio - kIndicatorHalfWidth,
                                         kBoardHeight * kIndicatorYRatio,
                                         kButtonHeight,
                                         kButtonHeight);
        indicatorView.hidesWhenStopped = YES;
        [indicatorView startAnimating];

        [self addSubview:btnCancel];
        [self addSubview:btnOK];
        [self addSubview:btnEnd];
        [self addSubview:indicatorView];

        jcfDownloader = [[JcfDownloader alloc] initWithCustomID:customID delegate:self];
    }
    return self;
}

#pragma mark - Actions

/** @ghidraAddress 0x1ec59c */
- (void)pushCancel:(id)sender {
    [self downloadEnd];
}

/** @ghidraAddress 0x1ec5a8 */
- (void)pushMoveStore:(id)sender {
    // The binary passes the delegate itself (not self) as the first object argument.
    id<JcfDownloadViewDelegate> theDelegate = delegate;
    if ([theDelegate respondsToSelector:@selector(jcfDownloadMoveStore:packID:)]) {
        [theDelegate performSelector:@selector(jcfDownloadMoveStore:packID:)
                          withObject:theDelegate
                          withObject:packID];
    }
}

#pragma mark - Download flow

/** @ghidraAddress 0x1ec658 */
- (void)startDownload {
    // The download was already begun by the JcfDownloader built in -initWithID:delegate:; this
    // only overlays the status label.
    textLabel =
        [[UILabel alloc] initWithFrame:CGRectMake(kProgressLabelInset,
                                                  kProgressLabelInset,
                                                  self.frame.size.width + kProgressLabelMargin,
                                                  self.frame.size.height + kProgressLabelMargin)];
    textLabel.backgroundColor = UIColor.clearColor;
    textLabel.textAlignment = NSTextAlignmentCenter;
    textLabel.text = kDownloadingText;
    textLabel.numberOfLines = 0;
    [self addSubview:textLabel];
}

/** @ghidraAddress 0x1ec78c */
- (void)downloadEnd {
    // The binary passes the delegate itself (not self) as the object argument.
    id<JcfDownloadViewDelegate> theDelegate = delegate;
    if ([theDelegate respondsToSelector:@selector(jcfDownloadEnd:)]) {
        [theDelegate performSelector:@selector(jcfDownloadEnd:) withObject:theDelegate];
    }
}

/** @ghidraAddress 0x1eccbc */
- (int)getDownloadMusicID {
    return musicID;
}

#pragma mark - JcfDownloaderDelegate

/** @ghidraAddress 0x1ec830 */
- (void)errorSequenceDownload:(JcfDownloader *)downloader msgStr:(NSString *)msg {
    textLabel.text = msg ?: kDefaultFailureText;
    [btnCancel setTitle:[NSBundle.mainBundle localizedStringForKey:kOKButtonKey value:@"" table:nil]
               forState:UIControlStateNormal];
    [indicatorView stopAnimating];
}

/** @ghidraAddress 0x1ec914 */
- (void)finishedSequenceOverCap:(JcfDownloader *)downloader {
    textLabel.text = kOverCapText;
    jcfDownloader = nil;
    [btnCancel setTitle:[NSBundle.mainBundle localizedStringForKey:kOKButtonKey value:@"" table:nil]
               forState:UIControlStateNormal];
    [indicatorView stopAnimating];
}

/** @ghidraAddress 0x1eca00 */
- (void)finishedSequenceNotExistPack:(JcfDownloader *)downloader packID:(NSString *)packIDArg {
    packID = [NSString stringWithString:packIDArg];
    textLabel.text = kNotExistPackText;
    [indicatorView stopAnimating];
    [UIView animateWithDuration:kEndButtonsFadeDuration
                     animations:^{
                       /** @ghidraAddress 0x1ecaf8 */
                       // Swap the centred Cancel button out for the End and OK buttons.
                       [self->btnEnd setAlpha:1.0];
                       [self->btnOK setAlpha:1.0];
                       [self->btnCancel setAlpha:0];
                     }];
}

/** @ghidraAddress 0x1ecb88 */
- (void)finishedSequenceDownload:(JcfDownloader *)downloader tuneID:(NSString *)tuneID {
    musicID = (int)tuneID.integerValue;
    [indicatorView stopAnimating];
    // The binary builds the completed message with stringWithFormat: on a plain literal.
    textLabel.text = [NSString stringWithFormat:kCompletedText];
    jcfDownloader = nil;
    [btnCancel setTitle:[NSBundle.mainBundle localizedStringForKey:kOKButtonKey value:@"" table:nil]
               forState:UIControlStateNormal];
}

@end
