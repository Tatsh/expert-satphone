#import "LicenseAgreementView.h"

#import <QuartzCore/QuartzCore.h>

#import "AlertViewManager.h"
#import "JubeatAppDelegate.h"
#import "ScratchUtil.h"
#import "SessionDownloader.h"
#import "StoreButton.h"
#import "StoreUtil.h"
#import "jubeatLabAccess.h"

// Defaults keys that select the download flow and the pad-scaled layout.
static NSString *const kPrefAgreeLicenseVersion = @"PrefAgreeLicenseVersion";
static NSString *const kPrefTitleAgreeLicenseVersion = @"PrefTitleAgreeLicenseVersion";
static NSString *const kPrefStoreAgreeLicenseVersion = @"PrefStoreAgreeLicenseVersion";
static NSString *const kPrefAgreeChallengePolicyVersion = @"PrefAgreeChallengePolicyVersion";

// Response dictionary keys.
static NSString *const kKeyStatus = @"Status";
static NSString *const kKeyStatusLower = @"status";
static NSString *const kKeyLastUpdate = @"LastUpdate";
static NSString *const kKeyMsgUser = @"MsgUser";
static NSString *const kKeyPolicyUpper = @"Policy";
static NSString *const kKeyPolicyLower = @"policy";
static NSString *const kKeyRevision = @"revision";
static NSString *const kKeyErrMessage = @"err_message";
static NSString *const kKeyVersion = @"Version";
static NSString *const kKeyPolicyVersion = @"PolicyVersion";
static NSString *const kKeyError = @"Error";
static NSString *const kKeyErrorMsg = @"ErrorMsg";

// Request-body keys for the challenge-policy POST.
static NSString *const kKeyTarget = @"target";
static NSString *const kKeyType = @"type";
static NSString *const kKeyJP = @"JP";

// Localised message keys.
static NSString *const kMsgNetworkError = @"NetworkErrorMsg";
static NSString *const kMsgServerOldVersion = @"ServerOldVersionMsg";
static NSString *const kTitleUsePolicy = @"Use policy";
static NSString *const kTitleAgree = @"Agree";
static NSString *const kTitleCancel = @"Cancel";

static NSString *const kDateFormat = @"YYYY-MM-dd HH:mm:ss";

// The board's frame is fScale times these base metrics (300x360 points on the phone).
static const CGFloat kBaseBoardWidth = 300.0;  // @ghidraAddress 0x28e010
static const CGFloat kBaseBoardHeight = 360.0; // @ghidraAddress 0x292418

// The scale factor applied on a pad; 1.0 elsewhere.
static const float kPadScale = 1.5f;   // fmov immediate at 0x1f5358
static const float kPhoneScale = 1.0f; // fmov immediate at 0x1f5320

// The revision value POSTed for the challenge policy when the server has no stored revision.
static NSString *const kDefaultRevisionString = @"-1"; // "-1" at 0x2e1c40
static const int kChallengeTarget = 3;                 // numberWithInt: at 0x1f5778

// Download tags distinguishing the store and challenge responses.
static const int kStorePolicyTag = 1;
static const int kChallengePolicyTag = 2;

// The status that means the client must be updated before the challenge policy can be shown.
static const int kStatusMustUpdate = 0x186ab; // 100011

// Board layout metrics recovered from __const.
static const CGFloat kBoardInset = 30.0;              // fmov immediate at 0x1f69a8
static const CGFloat kBoardWidthMargin = 60.0;        // 0x291bc8 (-60.0)
static const CGFloat kLabelTop = 11.0;                // fmov immediate at 0x1f69ac
static const CGFloat kLabelHeight = 20.0;             // fmov immediate at 0x1f69b0
static const CGFloat kLicenseViewTop = 40.0;          // 0x28f1f8
static const CGFloat kLicenseViewBottomMargin = 88.0; // 0x28e078 (-40.0) + 0x292438 (-48.0)
static const CGFloat kButtonExtraWidth = 24.0;        // fmov immediate at 0x1f6fd4
static const CGFloat kButtonHeight = 32.0;            // 0x28f458
static const CGFloat kButtonGap = 10.0;               // fmov immediate at 0x1f6ff4
static const CGFloat kButtonBottomMargin = 40.0;      // fmov immediate: -24.0 + -16.0

// Font point sizes; the label and text view scale by fScale, the buttons do not.
static const CGFloat kLabelFontSize = 15.0;   // fmov immediate at 0x1f6a48
static const CGFloat kLicenseFontSize = 12.0; // fmov immediate at 0x1f6c78
static const CGFloat kButtonFontSize = 14.0;  // fmov immediate at 0x1f6eb4

// Gradient and border styling.
static const CGFloat kCornerRadius = 6.0;       // fmov immediate at 0x1f66a0
static const CGFloat kBorderWidth = 2.0;        // fmov immediate at 0x1f66b0
static const CGFloat kButtonCornerRadius = 3.0; // fmov immediate at 0x1f6e68
static const CGFloat kShadowRadius = 4.0;       // fmov immediate at 0x1f6944
static const float kShadowOpacity = 0.5f;       // fmov immediate at 0x1f6974
static const CGFloat kGradientTopStop = 40.0;   // 0x28f1f8

// Gradient greys, white components with full alpha.
static const CGFloat kGradientWhiteTop = 0.961;    // 0x292420
static const CGFloat kGradientWhiteMid = 0.855;    // 0x292428
static const CGFloat kGradientWhiteBottom = 0.762; // 0x292430

// Button fill colour components.
static const CGFloat kButtonGreen = 0.433; // 0x292440
static const CGFloat kButtonBlue = 0.617;  // 0x292448

// The reveal and fade-out animation duration.
static const NSTimeInterval kAnimationDuration = 0.6; // 0x28f288

@implementation LicenseAgreementView {
    jubeatLabAccess *licenseDateDownloader; // +0xfd4
    jubeatLabAccess *licenseMessDownloader; // +0xfe4
    Downloader *storePolicyDownloader;      // +0xfdc
    SessionDownloader *challengeDownloader; // +0xfe0
    __weak id delegate;                     // +0xfcc
    StoreButton *btnAgree;                  // +0xff0
    StoreButton *btnDisAgree;               // +0xff4
    UITextView *licenseView;                // +0xfec
    UILabel *labelMessage;                  // +0xfe8
    NSString *currentLicenseDateString;     // +0xfd8
    NSString *licenseDateKey;               // +0xfd0
    float fScale;                           // +0xfc4
}

#pragma mark - Class configuration

/** @ghidraAddress 0x1f5278 */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

#pragma mark - Initialisation

/** @ghidraAddress 0x1f528c */
- (nullable instancetype)init:(nullable id)aDelegate keyString:(nullable NSString *)keyString {
    BOOL pad = JubeatAppDelegate.appDelegate.isPad;
    fScale = kPhoneScale;
    _weakCoverView = nil;
    if (pad && [self enablePadScale:keyString]) {
        fScale = kPadScale;
    }
    self =
        [super initWithFrame:CGRectMake(0, 0, fScale * kBaseBoardWidth, fScale * kBaseBoardHeight)];
    if (self) {
        delegate = aDelegate;
        licenseDateKey = keyString;
        if ([licenseDateKey isEqualToString:kPrefAgreeLicenseVersion]) {
            licenseDateDownloader = [[jubeatLabAccess alloc] initLicenseVersionApi:self];
            [licenseDateDownloader startAccess];
        } else if ([licenseDateKey isEqualToString:kPrefTitleAgreeLicenseVersion]) {
            NSString *agreedDate =
                [[NSUserDefaults standardUserDefaults] stringForKey:licenseDateKey];
            currentLicenseDateString = [JubeatAppDelegate.appDelegate getCurrentLicenseDate];
            if ([self checkLicenseUpdate:agreedDate currentDate:currentLicenseDateString]) {
                NSString *message = [JubeatAppDelegate.appDelegate getCurrentLicenseMessage];
                [self createLicenseBoard:message];
            } else {
                if ([delegate respondsToSelector:@selector(agreementSuccess:)]) {
                    [delegate performSelector:@selector(agreementSuccess:) withObject:self];
                }
            }
        } else if ([licenseDateKey isEqualToString:kPrefStoreAgreeLicenseVersion]) {
            NSURL *url = [StoreUtil storeUserPolicyURL];
            storePolicyDownloader = [[Downloader alloc] initWithURL:url delegate:self];
            storePolicyDownloader.tag = kStorePolicyTag;
            [storePolicyDownloader startDownloading];
        } else if ([licenseDateKey isEqualToString:kPrefAgreeChallengePolicyVersion]) {
            NSURL *url = [ScratchUtil challengeModePolicyURL];
            NSString *storedRevision =
                [[NSUserDefaults standardUserDefaults] valueForKey:licenseDateKey];
            if (!storedRevision) {
                storedRevision = kDefaultRevisionString;
            }
            NSArray *values = @[ kKeyJP, @(kChallengeTarget) ];
            NSArray *keys = @[ kKeyTarget, kKeyType ];
            NSMutableDictionary *body = [NSMutableDictionary dictionaryWithObjects:values
                                                                           forKeys:keys];
            if (storedRevision) {
                body[kKeyRevision] = @(storedRevision.intValue);
            }
            challengeDownloader = [[SessionDownloader alloc] initWithURL:url
                                                          postDictionary:body
                                                                delegate:self];
            challengeDownloader.tag = kChallengePolicyTag;
            challengeDownloader.apiTag = kChallengePolicyTag;
            [challengeDownloader startDownloading];
        }
    }
    return self;
}

/** @ghidraAddress 0x1f51ec */
- (BOOL)enablePadScale:(nullable NSString *)key {
    if ([key isEqualToString:kPrefTitleAgreeLicenseVersion]) {
        return YES;
    }
    if ([key isEqualToString:kPrefStoreAgreeLicenseVersion]) {
        return YES;
    }
    return [key isEqualToString:kPrefAgreeChallengePolicyVersion];
}

#pragma mark - Licence-date comparison

/** @ghidraAddress 0x1f64c8 */
- (BOOL)checkLicenseUpdate:(nullable NSString *)agreedDate
               currentDate:(nullable NSString *)currentDate {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = kDateFormat;
    NSDate *current = [formatter dateFromString:currentDate];
    if (!agreedDate) {
        return YES;
    }
    NSDate *agreed = [formatter dateFromString:agreedDate];
    return [agreed compare:current] == NSOrderedAscending;
}

#pragma mark - jubeatLabAccess delegate

/**
 * @ghidraAddress 0x1f59d0
 */
- (void)jubeatLabAccessProceed:(nullable id)access {
    // Empty in the shipped binary.
}

/** @ghidraAddress 0x1f59d4 */
- (void)jubeatLabAccessError:(nullable id)access {
    [self sendErrorDelegate:nil];
}

/** @ghidraAddress 0x1f59e4 */
- (void)jubeatLabAccessFinished:(nullable id)access {
    NSDictionary *data = [access getDataInJSON];
    if (!data) {
        [self sendErrorDelegate:nil];
    }
    int status = [data[kKeyStatus] intValue];
    if (licenseDateDownloader == access) {
        licenseDateDownloader = nil;
        if (status == 0) {
            NSString *agreedDate =
                [[NSUserDefaults standardUserDefaults] stringForKey:licenseDateKey];
            currentLicenseDateString = data[kKeyLastUpdate];
            if ([self checkLicenseUpdate:agreedDate currentDate:currentLicenseDateString]) {
                licenseMessDownloader = [[jubeatLabAccess alloc] initLicenseApi:self];
                [licenseMessDownloader startAccess];
                return;
            }
            if ([delegate respondsToSelector:@selector(agreementSuccess:)]) {
                [delegate performSelector:@selector(agreementSuccess:) withObject:self];
            }
            return;
        }
        [self sendErrorDelegate:data[kKeyMsgUser]];
        return;
    }
    if (licenseMessDownloader != access) {
        return;
    }
    licenseMessDownloader = nil;
    if (status == 0) {
        [self createLicenseBoard:data[kKeyPolicyUpper]];
    } else {
        [self sendErrorDelegate:data[kKeyMsgUser]];
    }
}

#pragma mark - Downloader delegate

/**
 * @ghidraAddress 0x1f64c4
 */
- (void)downloaderProceed:(nullable id)downloader {
    // Empty in the shipped binary.
}

/** @ghidraAddress 0x1f64b4 */
- (void)downloaderError:(nullable id)downloader {
    [self sendErrorDelegate:nil];
}

/** @ghidraAddress 0x1f5cd0 */
- (void)downloaderFinished:(nullable id)downloader {
    NSDictionary *data = nil;
    int tag = [downloader tag];
    if (tag == kChallengePolicyTag) {
        data = [downloader getDataInJSON];
    } else if (tag == kStorePolicyTag) {
        data = [StoreUtil checkStoreResponse:[downloader getData]];
    }
    NSString *networkError = [[NSBundle mainBundle] localizedStringForKey:kMsgNetworkError
                                                                    value:@""
                                                                    table:nil];
    if (!data) {
        [self sendErrorDelegate:networkError];
        return;
    }
    if ([downloader tag] == kChallengePolicyTag) {
        if (data[kKeyStatusLower]) {
            int status = [data[kKeyStatusLower] intValue];
            if (status == 0) {
                NSString *revision = data[kKeyRevision];
                NSString *policy = data[kKeyPolicyLower];
                if (policy && ![policy isEqualToString:@""]) {
                    currentLicenseDateString = [NSString stringWithFormat:@"%@", revision];
                    [self createLicenseBoard:policy];
                    return;
                }
                if ([delegate respondsToSelector:@selector(agreementSuccess:)]) {
                    [delegate performSelector:@selector(agreementSuccess:) withObject:self];
                }
                return;
            }
            if (status == kStatusMustUpdate) {
                [[AlertViewManager sharedManager] showUpdateAlert];
                return;
            }
        }
        NSString *message = data[kKeyErrMessage];
        if (!message) {
            message = [[NSBundle mainBundle] localizedStringForKey:kMsgNetworkError
                                                             value:@""
                                                             table:nil];
        }
        [self sendErrorDelegate:message];
    } else if ([downloader tag] == kStorePolicyTag) {
        NSString *version = data[kKeyVersion];
        NSString *policyVersion = data[kKeyPolicyVersion];
        NSString *policy = data[kKeyPolicyUpper];
        BOOL needsUpdate;
        if (!version) {
            needsUpdate = YES;
        } else if (![version isEqualToString:@""]) {
            NSComparisonResult result = [JubeatAppDelegate.appVersion compare:version
                                                                      options:NSNumericSearch];
            needsUpdate = result == NSOrderedAscending;
            if (needsUpdate) {
                // The old-version message is fetched here but the shipped binary discards it;
                // only the needsUpdate flag survives.
                (void)[[NSBundle mainBundle] localizedStringForKey:kMsgServerOldVersion
                                                             value:@""
                                                             table:nil];
            }
        } else {
            needsUpdate = YES;
        }
        if (!policyVersion || [policyVersion isEqualToString:@""]) {
            needsUpdate = YES;
        }
        if (!data[kKeyError]) {
            if (!policy || [policy isEqualToString:@""]) {
                if ([delegate respondsToSelector:@selector(agreementSuccess:)]) {
                    [delegate performSelector:@selector(agreementSuccess:) withObject:self];
                }
            } else if (needsUpdate) {
                NSString *message = data[kKeyErrorMsg];
                if (!message) {
                    message = [[NSBundle mainBundle] localizedStringForKey:kMsgNetworkError
                                                                     value:@""
                                                                     table:nil];
                }
                [self sendErrorDelegate:message];
            } else {
                if ([delegate respondsToSelector:@selector(becomeCoverView)]) {
                    [delegate performSelector:@selector(becomeCoverView)];
                }
                currentLicenseDateString = policyVersion;
                [self createLicenseBoard:policy];
            }
        } else {
            NSString *message = data[kKeyError];
            if (!message) {
                message = [[NSBundle mainBundle] localizedStringForKey:kMsgNetworkError
                                                                 value:@""
                                                                 table:nil];
            }
            [self sendErrorDelegate:message];
        }
    }
}

#pragma mark - Error routing

/** @ghidraAddress 0x1f5928 */
- (void)sendErrorDelegate:(nullable NSString *)msgStr {
    if ([delegate respondsToSelector:@selector(agreementError:msgStr:)]) {
        [delegate performSelector:@selector(agreementError:msgStr:)
                       withObject:self
                       withObject:msgStr];
    }
}

/**
 * @ghidraAddress 0x1f6600
 */
- (void)displayMessage:(nullable NSString *)message {
    // Empty in the shipped binary.
}

#pragma mark - Board construction

/** @ghidraAddress 0x1f6604 */
- (void)createLicenseBoard:(nullable NSString *)message {
    CGRect frame = self.frame;
    CAGradientLayer *layer = (CAGradientLayer *)self.layer;
    layer.cornerRadius = kCornerRadius;
    layer.borderWidth = kBorderWidth;
    layer.borderColor = UIColor.lightGrayColor.CGColor;
    layer.locations = @[ @(0.0f), @(kGradientTopStop / frame.size.height), @(1.0f) ];
    layer.colors = @[
        (id)[UIColor colorWithWhite:kGradientWhiteTop alpha:1.0].CGColor,
        (id)[UIColor colorWithWhite:kGradientWhiteMid alpha:1.0].CGColor,
        (id)[UIColor colorWithWhite:kGradientWhiteBottom alpha:1.0].CGColor
    ];
    // The border colour is set twice: the shipped binary overwrites the light grey with grey.
    layer.borderColor = UIColor.grayColor.CGColor;
    layer.shadowRadius = kShadowRadius;
    layer.shadowOffset = CGSizeZero;
    layer.shadowOpacity = kShadowOpacity;

    labelMessage = [[UILabel alloc] initWithFrame:CGRectMake(kBoardInset,
                                                             kLabelTop,
                                                             frame.size.width - kBoardWidthMargin,
                                                             kLabelHeight)];
    labelMessage.opaque = NO;
    labelMessage.backgroundColor = UIColor.clearColor;
    labelMessage.font = [UIFont boldSystemFontOfSize:fScale * kLabelFontSize];
    labelMessage.textColor = UIColor.blackColor;
    labelMessage.textAlignment = NSTextAlignmentCenter;
    labelMessage.text = [[NSBundle mainBundle] localizedStringForKey:kTitleUsePolicy
                                                               value:@""
                                                               table:nil];
    labelMessage.alpha = 0.0;
    [self addSubview:labelMessage];

    CGFloat licenseHeight = frame.size.height - kLicenseViewBottomMargin;
    licenseView = [[UITextView alloc] initWithFrame:CGRectMake(kBoardInset,
                                                               kLicenseViewTop,
                                                               frame.size.width - kBoardWidthMargin,
                                                               licenseHeight)];
    licenseView.opaque = NO;
    licenseView.backgroundColor = UIColor.whiteColor;
    licenseView.font = [UIFont systemFontOfSize:fScale * kLicenseFontSize];
    licenseView.textColor = UIColor.blackColor;
    licenseView.textAlignment = NSTextAlignmentLeft;
    licenseView.alpha = 0.0;
    licenseView.editable = NO;
    licenseView.bounces = NO;
    // The leading empty argument is faithful to the binary's "%@%@" format.
    licenseView.text = [NSString stringWithFormat:@"%@%@", @"", message];
    licenseView.delegate = self;
    [self addSubview:licenseView];

    UIColor *buttonColor = [UIColor colorWithRed:0 green:kButtonGreen blue:kButtonBlue alpha:1.0];

    btnAgree = [[StoreButton alloc] initWithFrame:CGRectZero];
    btnAgree.buttonColor = buttonColor;
    btnAgree.cornerRadius = kButtonCornerRadius;
    btnAgree.exclusiveTouch = YES;
    btnAgree.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonFontSize];
    [btnAgree setTitle:[[NSBundle mainBundle] localizedStringForKey:kTitleAgree value:@"" table:nil]
              forState:UIControlStateNormal];
    [btnAgree addTarget:self
                  action:@selector(pushAgree:)
        forControlEvents:UIControlEventTouchUpInside];
    [btnAgree sizeToFit];
    CGFloat agreeWidth = btnAgree.frame.size.width + kButtonExtraWidth;
    btnAgree.alpha = 0.0;
    btnAgree.enabled = NO;
    btnAgree.frame = CGRectMake(frame.size.width * 0.5 - agreeWidth - kButtonGap,
                                frame.size.height - kButtonBottomMargin,
                                agreeWidth,
                                kButtonHeight);

    btnDisAgree = [[StoreButton alloc] initWithFrame:CGRectZero];
    btnDisAgree.buttonColor = buttonColor;
    btnDisAgree.cornerRadius = kButtonCornerRadius;
    btnDisAgree.exclusiveTouch = YES;
    btnDisAgree.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonFontSize];
    btnDisAgree.alpha = 0.0;
    [btnDisAgree setTitle:[[NSBundle mainBundle] localizedStringForKey:kTitleCancel
                                                                 value:@""
                                                                 table:nil]
                 forState:UIControlStateNormal];
    [btnDisAgree addTarget:self
                    action:@selector(pushDisAgree:)
          forControlEvents:UIControlEventTouchUpInside];
    [btnDisAgree sizeToFit];
    CGFloat disAgreeWidth = btnDisAgree.frame.size.width + kButtonExtraWidth;
    btnDisAgree.frame = CGRectMake(frame.size.width * 0.5 + kButtonGap,
                                   frame.size.height - kButtonBottomMargin,
                                   disAgreeWidth,
                                   kButtonHeight);

    [self addSubview:btnAgree];
    [self addSubview:btnDisAgree];

    __weak UIView *coverView = self.weakCoverView;
    [UIView animateWithDuration:kAnimationDuration
                     animations:^{
                       /** @ghidraAddress 0x1f73b4 */
                       self->labelMessage.alpha = 1.0;
                       self->licenseView.alpha = 1.0;
                       self->btnAgree.alpha = 1.0;
                       self->btnDisAgree.alpha = 1.0;
                       if (coverView) {
                           coverView.alpha = 1.0;
                       }
                     }];
}

#pragma mark - Scroll handling

/** @ghidraAddress 0x1f74fc */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    int contentHeight = (int)licenseView.contentSize.height;
    int frameHeight = (int)(licenseView.frame.size.height + 2.0);
    if (scrollView.contentOffset.y + frameHeight < contentHeight) {
        return;
    }
    [btnAgree setEnabled:YES];
}

/** @ghidraAddress 0x1f75e0 */
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    int contentHeight = (int)licenseView.contentSize.height;
    int frameHeight = (int)(licenseView.frame.size.height + 2.0);
    if (scrollView.contentOffset.y + frameHeight < contentHeight) {
        return;
    }
    [btnAgree setEnabled:YES];
}

#pragma mark - Button actions

/** @ghidraAddress 0x1f76c4 */
- (void)pushAgree:(nullable id)sender {
    [[NSUserDefaults standardUserDefaults] setValue:currentLicenseDateString forKey:licenseDateKey];
    [UIView animateWithDuration:kAnimationDuration
        animations:^{
          /** @ghidraAddress 0x1f77d4 */
          self.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1f77f8 */
          if ([self->delegate respondsToSelector:@selector(agreementSuccess:)]) {
              [self->delegate performSelector:@selector(agreementSuccess:) withObject:self];
          }
        }];
}

/** @ghidraAddress 0x1f78b0 */
- (void)pushDisAgree:(nullable id)sender {
    if ([delegate respondsToSelector:@selector(agreementFailed:)]) {
        [delegate performSelector:@selector(agreementFailed:) withObject:self];
    }
}

@end
