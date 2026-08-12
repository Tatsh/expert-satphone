#import "TitleViewController.h"

#import <SafariServices/SafariServices.h>

#import "AlertViewManager.h"
#import "Downloader.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "LabUtilities.h"
#import "MessageTextView.h"
#import "ScratchUtil.h"
#import "StoreUtil.h"
#import "jubeatLabAccess.h"

// The "send" POST body sent with the payment-services policy request, verified from the stack
// setup at 0x1e304–0x1e3a0: keys {"target", "type", "revision"} to values {"JP", @4, @-1}.
static NSString *const kExplainSendTarget = @"JP";
static NSString *const kExplainSendKeyTarget = @"target";
static NSString *const kExplainSendKeyType = @"type";
static NSString *const kExplainSendKeyRevision = @"revision";

// The payment-services board title, a UTF-16 CFString at 0x1002d51e0 -> 0x1002c0572.
static NSString *const kExplainTitle = @"資金決済法について";

// The Konami corporate site opened by the corporate button, a CFString at 0x1002d5220.
static NSString *const kKonamiURLString = @"https://www.konami.com/ja";

// NSUserDefaults keys, from the cf_* references in the two download callbacks.
static NSString *const kPrefjubeatLabURL = @"PrefjubeatLabURL";
static NSString *const kPrefInfoListURL = @"PrefInfoListURL";
static NSString *const kPrefInfoUpdateTime = @"PrefInfoUpdateTime";

// JSON keys read from the two server responses.
static NSString *const kJSONKeyStatus = @"Status";
static NSString *const kJSONKeyURL = @"URL";
static NSString *const kJSONKeySvTime = @"SvTime";
static NSString *const kJSONKeyAnotherURL = @"AnotherURL";
static NSString *const kJSONKeyUpdateTime = @"UpdateTime";

// Date formats used to parse the server time and the info update time.
static NSString *const kSvTimeDateFormat = @"YYYYMMddHHmmss";
static NSString *const kUpdateTimeDateFormat = @"YYYYMMddHHmm";

// The themed corporate-button image base names, chosen by JubeatAppDelegate.currentTheme.
static NSString *const kCorporateImageWhite = @"co_info_w";
static NSString *const kCorporateImageBlack = @"co_info_b";

// Layout constants for the corporate button, read from the fmov immediates at 0x1f21c and 0x1f24c.
static const CGFloat kCorporateButtonMargin = 10.0; // The button's top inset and right gutter.

// The overlay backdrop alpha, from the fmov d8,0x3fe0000000000000 at 0x1e284.
static const CGFloat kOverlayBackdropAlpha = 0.5;

// The overlay fade-in duration, a double at 0x10028e040.
static const NSTimeInterval kOverlayFadeDuration = 0.2;

// The status value that marks a healthy top-page licence response.
static const int kLabStatusOK = 0;

// The values sent in the payment-services "send" dictionary.
static const int kExplainSendTypeValue = 4;
static const int kExplainSendRevisionValue = -1;

// The April-Fools trigger date (April 1) parsed from the server time.
static const NSInteger kAprilFoolsMonth = 4;
static const NSInteger kAprilFoolsDay = 1;

// The NSCalendarUnit mask passed to -components:fromDate: (0x1c = month | day | hour).
static const NSCalendarUnit kSvTimeCalendarUnits =
    NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour;

@implementation TitleViewController

/** @ghidraAddress 0x1e0f0 */
- (instancetype)init {
    self = [super init];
    if (self) {
        // bEnableTap is a BOOL pointer used as a flag; the binary stores the literal 1 here.
        bEnableTap = (BOOL *)YES;
    }
    return self;
}

#pragma mark - View lifecycle

/** @ghidraAddress 0x1e13c */
- (void)loadView {
    [super loadView];
    [self setCorporateButton];
}

#pragma mark - Corporate button

/** @ghidraAddress 0x1f0f8 */
- (void)setCorporateButton {
    // The button image follows the theme: the white variant on theme 0, the black variant
    // otherwise. Verified at 0x1f150: cbz w21 (currentTheme) selects co_info_w vs co_info_b.
    JubeatTheme theme = JubeatAppDelegate.appDelegate.currentTheme;
    NSString *imageName =
        (theme == JubeatThemeOriginal) ? kCorporateImageWhite : kCorporateImageBlack;
    UIImage *image = LoadScaledPngImage(imageName);
    coBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [coBtn setBackgroundImage:image forState:UIControlStateNormal];
    // The button hugs the top-right corner: x = view.width - image.width - 10, y = 10, sized to
    // the image. Verified at 0x1f1fc–0x1f25c: bounds.width (v8) - image.size.width (d0) - 10.0,
    // constant y = 10.0, then image.size.width/height for the size.
    CGRect bounds = self.view.bounds;
    CGSize imageSize = image.size;
    coBtn.frame = CGRectMake(bounds.size.width - imageSize.width - kCorporateButtonMargin,
                             kCorporateButtonMargin,
                             imageSize.width,
                             imageSize.height);
    [coBtn addTarget:self
                  action:@selector(tapCorporateButton:)
        forControlEvents:UIControlEventTouchUpInside];
    coBtn.exclusiveTouch = YES;
}

/** @ghidraAddress 0x1e6dc */
- (void)tapCorporateButton:(id)sender {
    bEnableTap = (BOOL *)NO;
    // Only presents a Safari view controller when the class is available (iOS 9+).
    // Verified at 0x1e6f0: NSClassFromString(@"SFSafariViewController") guards the whole body.
    if (NSClassFromString(@"SFSafariViewController")) {
        SFSafariViewController *safari =
            [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:kKonamiURLString]];
        safari.modalPresentationCapturesStatusBarAppearance = YES;
        [self presentViewController:safari
                           animated:YES
                         completion:^{
                             /** @ghidraAddress 0x1e7c0 */
                         }];
    }
    bEnableTap = (BOOL *)YES;
}

#pragma mark - Payment-services message overlay

/** @ghidraAddress 0x1e190 */
- (void)tapExplain:(id)sender {
    bEnableTap = (BOOL *)NO;
    // A dimming backdrop over the whole view, half-transparent black, faded in from alpha 0.
    coverView = [[UIView alloc] initWithFrame:self.view.bounds];
    coverView.opaque = NO;
    coverView.backgroundColor = [UIColor colorWithWhite:0 alpha:kOverlayBackdropAlpha];
    coverView.alpha = 0.0;
    [self.view addSubview:coverView];

    // The POST body: {target: "JP", type: 4, revision: -1}. Built from the stack list at
    // 0x1e304–0x1e3a0 via dictionaryWithObjects:forKeys:count:3.
    NSDictionary *send = @{
        kExplainSendKeyTarget : kExplainSendTarget,
        kExplainSendKeyType : @(kExplainSendTypeValue),
        kExplainSendKeyRevision : @(kExplainSendRevisionValue)
    };
    textView = [[MessageTextView alloc] init:self
                                       title:kExplainTitle
                                         url:[ScratchUtil challengeModePolicyURL]
                                        send:send];
    // Centre the board on the view's bounds. Verified at 0x1e45c/0x1e480: bounds.width * 0.5,
    // bounds.height * 0.5 (d8 = 0.5).
    CGRect bounds = self.view.bounds;
    textView.center = CGPointMake(bounds.size.width * 0.5, bounds.size.height * 0.5);
    [self.view addSubview:textView];

    // Fade the backdrop and board to full opacity over 0.2 s.
    __weak UIView *weakCover = coverView;
    __weak MessageTextView *weakText = textView;
    [UIView animateWithDuration:kOverlayFadeDuration
                     animations:^{
                       /** @ghidraAddress 0x1e604 */
                       // The backdrop is restored before the board; see the block at 0x1e604
                       // (pWeakViewB, the cover, is set before pWeakViewA, the text view).
                       weakCover.alpha = 1.0;
                       weakText.alpha = 1.0;
                     }
                     completion:^(BOOL __attribute__((unused)) finished){
                         /** @ghidraAddress 0x1e6d8 */
                     }];
}

/** @ghidraAddress 0x1e7c4 */
- (void)closeMessage:(id)sender {
    [coverView removeFromSuperview];
    coverView = nil;
    [textView removeFromSuperview];
    textView = nil;
    bEnableTap = (BOOL *)YES;
}

/** @ghidraAddress 0x1e840 */
- (void)messageDownloadError:(id)sender msgStr:(NSString *)msgStr {
    // The alert always uses the localized "OK" as its only button. The msgStr argument is the
    // message body, with an empty title. Verified at 0x1e840: makeAlert:0 delegate:0 tag:0
    // title:@"" (CFString at 0x1002d42e0) msg:msgStr cancel:localized(@"OK") btnText:0 show:YES.
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:@""
                                            msg:msgStr
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
    [coverView removeFromSuperview];
    coverView = nil;
    [textView removeFromSuperview];
    textView = nil;
    bEnableTap = (BOOL *)YES;
}

#pragma mark - Title network work

/** @ghidraAddress 0x1e9a8 */
- (void)start {
    labAccess = [[jubeatLabAccess alloc] initTopPageApi:self];
    [labAccess startAccess];
    infoDownloader = [[Downloader alloc] initWithURL:[StoreUtil startNewsURL] delegate:self];
    [infoDownloader startDownloading];
}

/** @ghidraAddress 0x1ea8c */
- (void)showLogo {
    // Empty in the base class; the themed subclasses fade the logo in here.
}

/** @ghidraAddress 0x1ea90 */
- (void)stopAnimation {
    if (labAccess) {
        [labAccess cancel];
        labAccess = nil;
    }
    if (infoDownloader) {
        [infoDownloader cancel];
        infoDownloader = nil;
    }
}

/** @ghidraAddress 0x1f0f4 */
- (void)switchController {
    // Empty in the base class; the themed subclasses advance to the game here.
}

#pragma mark - Lab access callbacks

/** @ghidraAddress 0x1eb04 */
- (void)jubeatLabAccessError:(id)access {
    labAccess = nil;
}

/** @ghidraAddress 0x1eb1c */
- (void)jubeatLabAccessFinished:(id)access {
    // Ignore a stale callback from a request we no longer hold.
    if (labAccess != access) {
        return;
    }
    NSDictionary *json = [access getDataInJSON];
    labAccess = nil;
    if (!json) {
        return;
    }
    if ([json[kJSONKeyStatus] intValue] == kLabStatusOK) {
        NSMutableData *encrypted = CreateLabEncryptedData(json[kJSONKeyURL]);
        if (encrypted) {
            [NSUserDefaults.standardUserDefaults setObject:encrypted forKey:kPrefjubeatLabURL];
        }
    }
}

/** @ghidraAddress 0x1ec5c */
- (void)downloaderFinished:(id)downloader {
    // Ignore a stale callback from a request we no longer hold.
    if (infoDownloader != downloader) {
        return;
    }
    NSDictionary *json = [downloader getDataInJSON];
    if (!json) {
        return;
    }
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;

    // The server time gates the hidden April-Fools flags: on April 1 (month 4, day 1) the game
    // turns on the rectangle-wave, random marker direction, and auto-play flags.
    NSString *svTime = json[kJSONKeySvTime];
    if (svTime) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = kSvTimeDateFormat;
        NSDate *date = [formatter dateFromString:svTime];
        NSDateComponents *components = [NSCalendar.currentCalendar components:kSvTimeCalendarUnits
                                                                     fromDate:date];
        if (components.month == kAprilFoolsMonth && components.day == kAprilFoolsDay) {
            JubeatAppDelegate.appDelegate.isRectangleWave = YES;
            JubeatAppDelegate.appDelegate.isMarkerDirRandom = YES;
            JubeatAppDelegate.appDelegate.bEnableAutoPlay = YES;
        }
    }

    // Store the encrypted info-list URL.
    NSMutableData *encrypted = CreateLabEncryptedData(json[kJSONKeyAnotherURL]);
    if (encrypted) {
        [defaults setObject:encrypted forKey:kPrefInfoListURL];
    }

    // Adopt the notification-page URL unless the stored update time is already newer.
    NSString *updateTime = json[kJSONKeyUpdateTime];
    NSString *storedUpdateTime = [defaults stringForKey:kPrefInfoUpdateTime];
    NSDateFormatter *updateFormatter = [[NSDateFormatter alloc] init];
    updateFormatter.dateFormat = kUpdateTimeDateFormat;
    if (storedUpdateTime) {
        NSDate *storedDate = [updateFormatter dateFromString:storedUpdateTime];
        NSDate *newDate = [updateFormatter dateFromString:updateTime];
        // -[NSDate compare:] returns NSOrderedAscending (-1) when the stored date is older; only
        // then is the new page adopted. Any other result skips the update. Verified at 0x1f000
        // (compare:) and 0x1f01c (cmn x23,#1 => == -1).
        if ([storedDate compare:newDate] != NSOrderedAscending) {
            infoDownloader = nil;
            return;
        }
    }
    [JubeatAppDelegate.appDelegate setNotificationPageURL:json[kJSONKeyURL] updateTime:updateTime];
    infoDownloader = nil;
}

@end
