#import "SearchPackIDView.h"

#import <QuartzCore/QuartzCore.h>
#import <Social/Social.h>

#import "CJSONSerializer.h"
#import "EditorIDManager.h"
#import "GameNetworkUtil.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "ShadowView.h"
#import "StoreButton.h"
#import "StoreMusicListManager.h"
#import "StoreUtil.h"

// The board is 320 wide and 360 tall on a pad, and 300 square otherwise.
static const CGFloat kBoardWidthPad = 320.0;   // @ghidraAddress 0x28f470
static const CGFloat kBoardWidthPhone = 300.0; // @ghidraAddress 0x28f2d0
static const CGFloat kBoardHeightPad = 360.0;  // @ghidraAddress 0x292918

// The gradient-backed board's own layer styling.
static const CGFloat kBoardCornerRadius = 6.0; // fmov immediate at 0x1147cc
static const CGFloat kBoardBorderWidth = 2.0;  // fmov immediate at 0x1147dc
static const CGFloat kBoardShadowRadius = 4.0; // fmov immediate at 0x114a80
static const float kBoardShadowOpacity = 0.5f; // fmov immediate at 0x114ab0
// The board gradient runs from the top, through a stop this many points down, to the bottom.
static const CGFloat kGradientMidLocationNumerator = 40.0; // @ghidraAddress 0x28f1f8
// The three greys of the board gradient (top to bottom).
static const CGFloat kGradientWhiteTop = 0.961;    // @ghidraAddress 0x292420
static const CGFloat kGradientWhiteMiddle = 0.855; // @ghidraAddress 0x292428
static const CGFloat kGradientWhiteBottom = 0.762; // @ghidraAddress 0x292430

// The shared blue-green fill of the store-style buttons.
static const CGFloat kButtonFillGreen = 0.433;       // @ghidraAddress 0x292440
static const CGFloat kButtonFillBlue = 0.617;        // @ghidraAddress 0x292448
static const CGFloat kStoreButtonCornerRadius = 3.0; // fmov immediate at 0x114484
static const CGFloat kButtonTitleFontSize = 14.0;    // fmov immediate at 0x114c44

// The upload background, framed against the board's own frame at its bottom-right corner.
static const CGFloat kUploadBgXOffset = -106.0; // @ghidraAddress 0x292408 (added to board width)
static const CGFloat kUploadBgYOffset = -62.0;  // @ghidraAddress 0x292920 (added to board height)
static const CGFloat kUploadBgWidth = 106.0;    // @ghidraAddress 0x292928
static const CGFloat kUploadBgHeight = 62.0;    // @ghidraAddress 0x292930

// The message label, whose width tracks the board width.
static const CGFloat kMessageLabelX = 30.0;           // fmov immediate at 0x114bac
static const CGFloat kMessageLabelY = 11.0;           // fmov immediate at 0x114bb0
static const CGFloat kMessageLabelWidthInset = -60.0; // @ghidraAddress 0x291bc8 (added to width)
static const CGFloat kMessageLabelHeight = 20.0;      // fmov immediate at 0x114bb4
static const CGFloat kMessageLabelFontSize = 15.0;    // fmov immediate at 0x114c44

// The inner-shadow overlay, sized from the board. Its x is 16, and its y is the same constant
// that drives the gradient's middle stop.
static const CGFloat kShadowX = 16.0;            // fmov immediate at 0x114d14
static const CGFloat kShadowWidthInset = -32.0;  // @ghidraAddress 0x292938 (added to board width)
static const CGFloat kShadowHeightInset = -88.0; // @ghidraAddress 0x292940 (added to board height)

// The three buttons, anchored to the bottom of the board and split about its centre.
static const CGFloat kButtonHeight = 32.0;            // @ghidraAddress 0x28f458
static const CGFloat kButtonHorizontalPadding = 24.0; // fmov immediate at 0x114f6c; added to fit.
static const CGFloat kCentreRatio = 0.5;              // fmov immediate at 0x114f74
// The bottom margin is boardHeight minus these two, and the centre gap is ten points either way.
static const CGFloat kButtonBottomFirstMargin = -24.0;  // fmov immediate at 0x114f90
static const CGFloat kButtonBottomSecondMargin = -16.0; // fmov immediate at 0x114f98
static const CGFloat kButtonCentreGap = 10.0;           // fmov immediate at 0x114f88 / 0x1151fc

// The activity indicator, centred horizontally and placed a fifth of the way down.
static const CGFloat kIndicatorHalfWidth = 16.0; // fmov immediate at 0x1153e8
static const CGFloat kIndicatorYRatio = 0.2;     // @ghidraAddress 0x28e040

// The progress label added by -startDownload, inset ten points and shrunk twenty each way.
static const CGFloat kProgressLabelInset = 10.0;   // fmov immediate at 0x1158f0
static const CGFloat kProgressLabelMargin = -20.0; // fmov immediate at 0x1158f0

// The upload background asset loaded onto the board.
static NSString *const kUploadBgImageName = @"upload_bg";

// The button title keys, looked up in the default table.
static NSString *const kCancelButtonKey = @"Cancel";
static NSString *const kOKButtonKey = @"OK";
static NSString *const kCloseButtonKey = @"Close";

// The status-string keys, looked up in the default table.
static NSString *const kSearchingKey = @"SearchPackInfo";
static NSString *const kFailedKey = @"PackInfoDownloadFailed";
static NSString *const kNotFoundKey = @"NotFindPackInfo";

// The bundle resource that marks the app as carrying the built-in tunes.
static NSString *const kBundleMusicResource = @"Music";

// The JSON request keys posted to the pack-lookup endpoint.
static NSString *const kRequestKeyTarget = @"target";
static NSString *const kRequestKeyUserID = @"user_id";
static NSString *const kRequestKeyUUID = @"uuid";
static NSString *const kRequestKeyMusicID = @"music_id";

// The JSON response keys read out of the reply.
static NSString *const kResponseKeyID = @"ID";
static NSString *const kResponseKeyMessage = @"Message";

@implementation SearchPackIDView {
    Downloader *packInfoDownloader; // The owned lookup request; started by -startDownload.
    UIView *coverBoard;             // Declared in the metadata; untouched by the compiled methods.
    UILabel *labelMessage;          // The board title label (built but left with no text).
    UIView *shadowView;             // The inner-shadow overlay (built and stored but never added).
    StoreButton *btnCancel;         // The centred, visible button.
    StoreButton *btnOK;             // The move-to-store button, left of centre, transparent.
    StoreButton *btnEnd;            // The end button, right of centre, transparent.
    UIActivityIndicatorView *indicatorView; // The spinner shown while looking up.
    UILabel *textLabel;                     // The progress/result label added by -startDownload.
    __weak id<SearchPackIDViewDelegate> delegate;
    NSString *socialTypeStr; // The social service type, or nil for a plain pack lookup.
    NSNumber *packID;        // The comprised-pack id resolved by a successful lookup.
    NSString *sendMsg;       // The message/recommend string resolved by a successful lookup.
    BOOL bBundle;            // Set by -isBundleMusic: to its own result.
}

#pragma mark - Layer

/** @ghidraAddress 0x114274 */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

#pragma mark - Construction

/** @ghidraAddress 0x114288 */
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

/** @ghidraAddress 0x1143c0 */
- (BOOL)isBundleMusic:(int)musicID {
    bBundle = NO;
    if ([NSBundle.mainBundle pathForResource:kBundleMusicResource ofType:@""]) {
        for (NSNumber *tune in StoreMusicListManager.sharedManager.builtinMusic) {
            if (tune.intValue == musicID) {
                bBundle = YES;
                return YES;
            }
        }
    }
    return bBundle;
}

/** @ghidraAddress 0x1145d4 */
- (instancetype)initWithID:(id)music
                      type:(NSString *)type
                  delegate:(id<SearchPackIDViewDelegate>)delegateArg {
    return [self initWithTuneID:(unsigned int)[music tuneID] type:type delegate:delegateArg];
}

/** @ghidraAddress 0x114684 */
- (instancetype)initWithTuneID:(unsigned int)tuneID
                          type:(NSString *)type
                      delegate:(id<SearchPackIDViewDelegate>)delegateArg {
    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    CGFloat boardWidth = isPad ? kBoardWidthPad : kBoardWidthPhone;
    // The phone board is square, so its height reuses the phone-width constant.
    CGFloat boardHeight = isPad ? kBoardHeightPad : kBoardWidthPhone;
    self = [super initWithFrame:CGRectMake(0, 0, boardWidth, boardHeight)];
    if (self) {
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

        // The inner-shadow overlay is built and stored but, like the sibling modals, never added
        // to the view hierarchy.
        shadowView =
            [[ShadowView alloc] initWithFrame:CGRectMake(kShadowX,
                                                         kGradientMidLocationNumerator,
                                                         boardWidth + kShadowWidthInset,
                                                         boardHeight + kShadowHeightInset)];

        CGFloat buttonY = boardHeight + kButtonBottomFirstMargin + kButtonBottomSecondMargin;

        btnOK = [[StoreButton alloc] initWithFrame:CGRectZero];
        btnOK.buttonColor = [UIColor colorWithRed:0
                                            green:kButtonFillGreen
                                             blue:kButtonFillBlue
                                            alpha:1.0];
        btnOK.cornerRadius = kStoreButtonCornerRadius;
        [btnOK setExclusiveTouch:YES];
        btnOK.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonTitleFontSize];
        // The button is first titled Cancel, then retitled OK below: a faithful quirk of the
        // binary. Its target is -pushMoveStore:, a selector this class does not implement; the
        // button starts transparent and is never revealed by the compiled methods.
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

        btnCancel = [[StoreButton alloc] initWithFrame:CGRectZero];
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

        indicatorView = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        indicatorView.frame = CGRectMake(boardWidth * kCentreRatio - kIndicatorHalfWidth,
                                         boardHeight * kIndicatorYRatio,
                                         kButtonHeight,
                                         kButtonHeight);
        indicatorView.hidesWhenStopped = YES;
        [indicatorView startAnimating];

        [self addSubview:btnOK];
        [self addSubview:btnEnd];
        [self addSubview:btnCancel];
        [self addSubview:indicatorView];

        socialTypeStr = type;

        // A plain pack lookup hits the pack-search endpoint; a social recommend hits the Twitter
        // or Facebook endpoint. The Twitter URL is computed first regardless, so it is a discarded
        // call when the type is nil.
        NSURL *url = [GameNetworkUtil recommendTwitterURL];
        if (socialTypeStr == nil) {
            url = [GameNetworkUtil searchPackIDURL:(int)tuneID];
        } else if ([type isEqualToString:SLServiceTypeFacebook]) {
            url = [GameNetworkUtil recommendFacebookURL];
        }

        NSMutableDictionary *request = [[NSMutableDictionary alloc] init];
        request[kRequestKeyTarget] = [GameNetworkUtil getStoreTarget];
        if (EditorIDManager.isExistEditorID) {
            request[kRequestKeyUserID] =
                [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
        }
        request[kRequestKeyUUID] = JubeatAppDelegate.clientInfo[kRequestKeyUUID];
        request[kRequestKeyMusicID] = @((int)tuneID);
        NSData *body = [[CJSONSerializer serializer] serializeDictionary:request error:nil];

        packInfoDownloader = [[Downloader alloc] initWithURL:url postData:body delegate:self];
    }
    return self;
}

#pragma mark - Actions

/** @ghidraAddress 0x115830 */
- (void)pushCancel:(id)sender {
    if (packInfoDownloader != nil) {
        [packInfoDownloader cancel];
    }
    if ([delegate respondsToSelector:@selector(packIDSearchCancel:)]) {
        [delegate performSelector:@selector(packIDSearchCancel:) withObject:self];
    }
}

#pragma mark - Lookup flow

/** @ghidraAddress 0x1158f0 */
- (void)startDownload {
    textLabel =
        [[UILabel alloc] initWithFrame:CGRectMake(kProgressLabelInset,
                                                  kProgressLabelInset,
                                                  self.frame.size.width + kProgressLabelMargin,
                                                  self.frame.size.height + kProgressLabelMargin)];
    textLabel.backgroundColor = UIColor.clearColor;
    textLabel.textAlignment = NSTextAlignmentCenter;
    textLabel.text = [NSBundle.mainBundle localizedStringForKey:kSearchingKey value:@"" table:nil];
    textLabel.numberOfLines = 0;
    [self addSubview:textLabel];
    [packInfoDownloader startDownloading];
}

/** @ghidraAddress 0x115cd4 */
- (void)searchPackFailed {
    textLabel.text = [NSBundle.mainBundle localizedStringForKey:kFailedKey value:@"" table:nil];
    [indicatorView stopAnimating];
    [btnCancel setTitle:[NSBundle.mainBundle localizedStringForKey:kCloseButtonKey
                                                             value:@""
                                                             table:nil]
               forState:UIControlStateNormal];
}

/** @ghidraAddress 0x115e14 */
- (void)notFindPackID {
    textLabel.text = [NSBundle.mainBundle localizedStringForKey:kNotFoundKey value:@"" table:nil];
    [indicatorView stopAnimating];
    [btnCancel setTitle:[NSBundle.mainBundle localizedStringForKey:kCloseButtonKey
                                                             value:@""
                                                             table:nil]
               forState:UIControlStateNormal];
    if ([delegate respondsToSelector:@selector(packIDSearchFailed:)]) {
        [delegate performSelector:@selector(packIDSearchFailed:) withObject:self];
    }
}

/** @ghidraAddress 0x115fd4 */
- (NSNumber *)getPackID {
    return packID;
}

/** @ghidraAddress 0x115fe4 */
- (NSString *)getRecommendString {
    return sendMsg;
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x115aa0 */
- (void)downloaderError:(Downloader *)downloader {
    [self searchPackFailed];
    packInfoDownloader = nil;
}

/** @ghidraAddress 0x115ad8 */
- (void)downloaderFinished:(Downloader *)downloader {
    if (packInfoDownloader != downloader) {
        return;
    }
    // getDataInJSON is always called; its result is discarded on the plain-lookup path below.
    NSDictionary *response = [downloader getDataInJSON];
    // A plain pack lookup unwraps the store envelope; a social recommend uses the raw JSON body.
    if (socialTypeStr == nil) {
        response = [StoreUtil checkStoreResponse:[downloader getData]];
    }
    if (response != nil) {
        packID = response[kResponseKeyID];
        sendMsg = response[kResponseKeyMessage];
        if (packID != nil || socialTypeStr != nil) {
            if ([delegate respondsToSelector:@selector(packIDSearchEnd:)]) {
                [delegate performSelector:@selector(packIDSearchEnd:) withObject:self];
            }
        } else {
            [self notFindPackID];
        }
    } else {
        [self searchPackFailed];
    }
    packInfoDownloader = nil;
}

@end
