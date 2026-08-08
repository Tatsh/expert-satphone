#import "MessageTextView.h"

#import <QuartzCore/QuartzCore.h>

#import "AlertViewManager.h"
#import "JubeatAppDelegate.h"
#import "SessionDownloader.h"
#import "StoreButton.h"

// The board's overall size before scaling, pooled as floats at 0x28e010 (width) and 0x292418
// (height).
static const CGFloat kBoardBaseWidth = 300.0;
static const CGFloat kBoardBaseHeight = 360.0;

// The board grows by 1.5x on a pad (fmov 0x3fc00000) and stays 1.0x otherwise (fmov 0x3f800000).
static const CGFloat kBoardScalePad = 1.5f;
static const CGFloat kBoardScalePhone = 1.0f;

// The gradient paper's border and corner (fmov immediates in -createMessageBoard:).
static const CGFloat kBoardCornerRadius = 6.0;
static const CGFloat kBoardBorderWidth = 2.0;
static const CGFloat kBoardShadowRadius = 4.0;
static const CGFloat kBoardShadowOpacity = 0.5f;

// The paper gradient's three white stops (pooled floats at 0x292420, 0x292428, and 0x292430).
static const CGFloat kGradientWhiteTop = 0.9610000252723694f;
static const CGFloat kGradientWhiteMiddle = 0.8550000190734863f;
static const CGFloat kGradientWhiteBottom = 0.7620000243186951f;

// The gradient's middle stop location is 40 / boardHeight; 40 is pooled at 0x28f1f8.
static const CGFloat kGradientMidLocationNumerator = 40.0;

// The title label's frame, pooled/fmov constants in -createMessageBoard:. Its width is the board's
// width less the 30-point margin on each side (frame.size.width - 60; the -60 is pooled at
// 0x291bc8), and its height is 20 (fmov 0x4034…) starting at y 11 (fmov 0x4026…).
static const CGFloat kSideMargin = 30.0;
static const CGFloat kTitleMarginTotal = 60.0;
static const CGFloat kTitleY = 11.0;
static const CGFloat kTitleHeight = 20.0;
static const CGFloat kTitleFontSize = 15.0;

// The body text view sits below the title. Its height is (boardHeight - 40 - 48), where 40 is
// pooled at 0x28e078 and 48 at 0x292438; its font is 12pt. Its y equals the title's height run.
static const CGFloat kBodyTopInset = 40.0;
static const CGFloat kBodyBottomInset = 48.0;
static const CGFloat kBodyFontSize = 12.0;

// The Agree button. Its title font is 14pt (fmov 0x402c…), its corner radius 3 (fmov 0x4008…), and
// its fill is a green-blue (colorWithRed:0 green:0.433 blue:0.617 alpha:1). It is centred
// horizontally and parked 24 + 16 points above the board's bottom (fmov -24.0 then -16.0); its
// height is 32 (pooled at 0x28f458).
static const CGFloat kAgreeFontSize = 14.0;
static const CGFloat kAgreeCornerRadius = 3.0;
static const CGFloat kAgreeGreen = 0.43299999833106995f;
static const CGFloat kAgreeBlue = 0.6169999837875366f;
static const CGFloat kAgreeBottomOffset = 24.0;
static const CGFloat kAgreeExtraOffset = 16.0;
static const CGFloat kAgreeHeight = 32.0;

// The stale-client status code that closes the board and shows the update alert (0x186ab).
static const int kStatusClientTooOld = 100011;

// The fade duration for both the reveal and the exit (pooled double at 0x28f288).
static const NSTimeInterval kFadeDuration = 0.6;

@implementation MessageTextView {
    SessionDownloader *messageDownloader;        // +0x08
    __weak id<MessageTextViewDelegate> delegate; // +0x10
    StoreButton *btnClose;                       // +0x18
    UITextView *licenseView;                     // +0x20
    UILabel *labelMessage;                       // +0x28
    NSString *titleString;                       // +0x30
    float fScale;                                // +0x38
}

/** @ghidraAddress 0xfab64 */
+ (Class)layerClass {
    // Never consulted: nothing reads this board's layer as a CAGradientLayer, but the class still
    // returns one so -createMessageBoard: can fill self.layer with a gradient.
    return CAGradientLayer.class;
}

/** @ghidraAddress 0xfab78 */
- (nullable instancetype)init:(nullable id<MessageTextViewDelegate>)delegateArg
                        title:(nullable NSString *)title
                          url:(nullable NSURL *)url
                         send:(nullable NSDictionary *)send {
    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    fScale = kBoardScalePhone;
    titleString = title;
    if (isPad) {
        fScale = kBoardScalePad;
    }
    self =
        [super initWithFrame:CGRectMake(0, 0, fScale * kBoardBaseWidth, fScale * kBoardBaseHeight)];
    if (self) {
        delegate = delegateArg;
        messageDownloader = [[SessionDownloader alloc] initWithURL:url
                                                    postDictionary:send
                                                          delegate:self];
        [messageDownloader startDownloading];
    }
    return self;
}

/** @ghidraAddress 0xfad40 */
- (nullable instancetype)init:(nullable id<MessageTextViewDelegate>)delegateArg
                        title:(nullable NSString *)title
                      message:(nullable id)message {
    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    fScale = kBoardScalePhone;
    titleString = title;
    if (isPad) {
        fScale = kBoardScalePad;
    }
    self =
        [super initWithFrame:CGRectMake(0, 0, fScale * kBoardBaseWidth, fScale * kBoardBaseHeight)];
    if (self) {
        delegate = delegateArg;
        [self createMessageBoard:message];
    }
    return self;
}

/** @ghidraAddress 0xfaeb0 */
- (void)sendErrorDelegate:(nullable NSString *)msgStr {
    if ([delegate respondsToSelector:@selector(messageDownloadError:msgStr:)]) {
        [delegate performSelector:@selector(messageDownloadError:msgStr:)
                       withObject:self
                       withObject:msgStr];
    }
}

/** @ghidraAddress 0xfaf58 */
- (void)downloaderFinished:(nullable id)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    NSString *errorMessage = [NSBundle.mainBundle localizedStringForKey:@"NetworkErrorMsg"
                                                                  value:@""
                                                                  table:nil];
    if (json[@"status"]) {
        int status = [json[@"status"] intValue];
        if (status == 0) {
            [self createMessageBoard:json[@"policy"]];
            return;
        }
        if (status == kStatusClientTooOld) {
            if ([delegate respondsToSelector:@selector(closeMessage:)]) {
                [delegate performSelector:@selector(closeMessage:) withObject:self];
            }
            [[AlertViewManager sharedManager] showUpdateAlert];
            return;
        }
    }
    if (json[@"err_message"]) {
        errorMessage = json[@"err_message"];
    }
    [self sendErrorDelegate:errorMessage];
}

/** @ghidraAddress 0xfb1c8 */
- (void)downloaderError:(nullable id)downloader {
    [self sendErrorDelegate:nil];
}

/** @ghidraAddress 0xfb1d8 */
- (void)downloaderProceed:(nullable id)downloader {
}

/** @ghidraAddress 0xfb1dc */
- (void)displayMessage:(nullable id)message {
}

/** @ghidraAddress 0xfb1e0 */
- (void)createMessageBoard:(nullable id)message {
    CGFloat boardWidth = self.frame.size.width;
    CGFloat boardHeight = self.frame.size.height;

    CAGradientLayer *gradient = (CAGradientLayer *)self.layer;
    gradient.cornerRadius = kBoardCornerRadius;
    gradient.borderWidth = kBoardBorderWidth;
    gradient.borderColor = UIColor.lightGrayColor.CGColor;
    gradient.locations = @[ @(0.0f), @(kGradientMidLocationNumerator / boardHeight), @(1.0f) ];
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

    // The title label spans the board width less a 30-point margin on each side.
    labelMessage = [[UILabel alloc]
        initWithFrame:CGRectMake(
                          kSideMargin, kTitleY, boardWidth - kTitleMarginTotal, kTitleHeight)];
    labelMessage.opaque = NO;
    labelMessage.backgroundColor = UIColor.clearColor;
    labelMessage.font = [UIFont boldSystemFontOfSize:fScale * kTitleFontSize];
    labelMessage.textColor = UIColor.blackColor;
    labelMessage.textAlignment = NSTextAlignmentCenter;
    labelMessage.text = titleString;
    labelMessage.alpha = 0;
    [self addSubview:labelMessage];

    // The body text view sits below the title and fills the space above the button.
    CGFloat bodyHeight = boardHeight - kBodyTopInset - kBodyBottomInset;
    licenseView = [[UITextView alloc] initWithFrame:CGRectMake(kSideMargin,
                                                               kGradientMidLocationNumerator,
                                                               boardWidth - kTitleMarginTotal,
                                                               bodyHeight)];
    licenseView.opaque = NO;
    licenseView.backgroundColor = UIColor.whiteColor;
    licenseView.font = [UIFont systemFontOfSize:fScale * kBodyFontSize];
    licenseView.textColor = UIColor.blackColor;
    licenseView.textAlignment = NSTextAlignmentLeft;
    licenseView.alpha = 0;
    licenseView.editable = NO;
    licenseView.bounces = NO;
    // The prefix argument is an empty CFString, so the body text is just the message.
    licenseView.text = [NSString stringWithFormat:@"%@%@", @"", message];
    [self addSubview:licenseView];

    // The Agree button, coloured a green-blue and centred horizontally.
    btnClose = [[StoreButton alloc] initWithFrame:CGRectZero];
    // The original used the full colorWithRed:green:blue:alpha: call.
    btnClose.buttonColor = [UIColor colorWithRed:0 green:kAgreeGreen blue:kAgreeBlue alpha:1.0];
    btnClose.cornerRadius = kAgreeCornerRadius;
    btnClose.exclusiveTouch = YES;
    btnClose.titleLabel.font = [UIFont boldSystemFontOfSize:kAgreeFontSize];
    [btnClose setTitle:[NSBundle.mainBundle localizedStringForKey:@"Close" value:@"" table:nil]
              forState:UIControlStateNormal];
    [btnClose addTarget:self
                  action:@selector(pushAgree:)
        forControlEvents:UIControlEventTouchUpInside];
    [btnClose sizeToFit];
    CGFloat buttonWidth = btnClose.frame.size.width * 2;
    btnClose.alpha = 0;
    // Centre the button and park it above the board's bottom edge.
    CGFloat buttonX = boardWidth * 0.5 - (buttonWidth * 0.5);
    [btnClose setFrame:CGRectMake(buttonX,
                                  boardHeight - kAgreeBottomOffset - kAgreeExtraOffset,
                                  buttonWidth,
                                  kAgreeHeight)];
    [self addSubview:btnClose];

    [UIView animateWithDuration:kFadeDuration
                     animations:^{
                       /** @ghidraAddress 0xfbc08 */
                       self->labelMessage.alpha = 1.0;
                       self->licenseView.alpha = 1.0;
                       self->btnClose.alpha = 1.0;
                     }];
}

/** @ghidraAddress 0xfbc98 */
- (void)pushAgree:(nullable id)sender {
    [UIView animateWithDuration:kFadeDuration
        animations:^{
          /** @ghidraAddress 0xfbd54 */
          self.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xfbd78 */
          // The finished flag is ignored, so the delegate is notified even if the fade was cut
          // short.
          if ([self->delegate respondsToSelector:@selector(closeMessage:)]) {
              [self->delegate performSelector:@selector(closeMessage:) withObject:self];
          }
        }];
}

@end
