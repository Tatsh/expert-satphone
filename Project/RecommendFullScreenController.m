//
//  RecommendFullScreenController.m
//  jubeat plus
//
//  Reconstructed from Ghidra program Jubeat (image base 0x100000000). See
//  RecommendFullScreenController.h for the class overview. The layout maths in -setViewSize and the
//  rotation transform in -rotateWebViewWithDuration: were recovered from the arm64 disassembly,
//  whose soft-float register shuffle the decompiler folds into pseudo-variables. This is a plain
//  Objective-C file: the class is a UIViewController subclass that reaches its collaborators
//  through ordinary message sends, with no C++.
//

#import "RecommendFullScreenController.h"

#import <UIKit/UIKit.h>

#import "ApplilinkCore.h"
#import "ApplilinkFile.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkParameters.h"
#import "ApplilinkUtilities.h"
#import "ApplilinkViewManager.h"
#import "NSStringURLEncoding.h"
#import "RecommendAdAreaView.h"
#import "RecommendAdCache.h"
#import "ShadeView.h"

// The advert-type identifier and view tag the interstitial always opens its advert area with. Both
// are the literal 5 in the binary, the value that marks the interstitial advert model elsewhere in
// RecommendCore.
static const int kRecommendInterstitialAdType = 5;
static const NSInteger kRecommendInterstitialViewTag = 5;

// The applilink error code reported when the advert HTML body could not be created on disk.
static const NSInteger kApplilinkErrorHtmlFileCreate = 0x40b;

// Below this screen edge length (in points) the interstitial base view uses half-size factors. Read
// from the __const pool at 0x28f470.
static const CGFloat kRecommendNarrowScreenThreshold = 320.0;

// The base-view sizing factors, indexed by whether the interface orientation is landscape. Each
// pair is {portrait, landscape}. The width and height factors are read from the __const pools at
// 0x294530 and 0x294538; the margins are fmov immediates.
static const CGFloat kRecommendBaseWidthFactor[] = {608.0, 632.0};
static const CGFloat kRecommendBaseHeightFactor[] = {844.0, 784.0};
static const CGFloat kRecommendBaseMargin1[] = {24.0, 4.0};
static const CGFloat kRecommendBaseMargin2[] = {8.0, 4.0};

// The system version at and above which the SDK trusts the Xcode 6 orientation-aware bounds, and
// the version below which the status bar height insets the shade origin. Both are fmov immediates
// in the binary (8.0 at 0x41000000, 7.0 at 0x40e00000).
static const CGFloat kRecommendXcode6SystemVersion = 8.0;
static const CGFloat kRecommendStatusBarInsetSystemVersion = 7.0;

// The interstitial base view fades into place a tenth of a second after the advert appears.
static const int64_t kRecommendShowBaseViewDelayNanoseconds = 100000000;

// The prefix stripped from a movie link before its query is appended and forwarded to the player.
static NSString *const kRecommendMovieLinkPrefix = @"applilink://ext-app:80/movie?";

// The movie-query dictionary keys and the appended query-parameter formats, exactly as the binary
// stores them as CFString constants.
static NSString *const kRecommendMovieQueryKeyMovieUrlList = @"movie_url_list";
static NSString *const kRecommendMovieQueryKeyMovieUrl = @"movie_url";
static NSString *const kRecommendMovieQueryKeyCreativeId = @"creative_id";
static NSString *const kRecommendMovieQueryKeyInstallFlg = @"install_flg";
static NSString *const kRecommendMovieQueryFormatImpressionId = @"&impression_id=%@";
static NSString *const kRecommendMovieQueryFormatAdModel = @"&ad_model=%d";
static NSString *const kRecommendMovieQueryFormatAdLocation = @"&ad_location=%@";
static NSString *const kRecommendMovieQueryFormatCreativeId = @"&creative_id=%@";
static NSString *const kRecommendMovieQueryFormatDisplayNumber = @"&display_number=1";
static NSString *const kRecommendMovieQueryFormatInstallFlg = @"&install_flg=%@";

// The user-info entry attached to the missing-HTML error: {"Error": "html file create error"}.
static NSString *const kRecommendHtmlFileCreateErrorKey = @"Error";
static NSString *const kRecommendHtmlFileCreateErrorValue = @"html file create error";

// The class metadata declares conformance to the closed-SDK ShadeViewDelegate,
// ApplilinkViewDelegate, and SdkViewDelegate protocols. ApplilinkViewDelegate is only
// forward-declared in the reconstructed tree, so its callbacks are implemented here and dispatched
// dynamically; ShadeViewDelegate is defined in ShadeView.h and adopted formally.
@interface RecommendFullScreenController () <ApplilinkViewManagerSdkDelegate, ShadeViewDelegate>

// The advert base view that hosts the advert area, sized for the current orientation.
@property(nonatomic, strong, nullable) UIView *baseView;
// The full-screen shade view that dims the screen behind the advert.
@property(nonatomic, strong, nullable) ShadeView *shadeView;
// The large loading spinner shown while the advert area loads.
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicator;
// The advert request parameters the interstitial was opened with.
@property(copy, nonatomic, nullable) ApplilinkParameters *applilinkParams;
// The applilink delegate notified of the advert lifecycle and failures.
@property(nonatomic, weak, nullable) id applilinkDelegate;
// The full-view delegate (the presenting RecommendCore) asked to release this controller on close.
@property(nonatomic, weak, nullable) id applilinkFullViewDelegate;
// Set while the advert is on screen, so -closeShadeView reports the disappearance only once.
@property(nonatomic) BOOL appearFlg;

@end

@implementation RecommendFullScreenController

#pragma mark - Lifecycle

/** @ghidraAddress 0x279c78 */
- (instancetype)init {
    return [super init];
}

/** @ghidraAddress 0x279cb4 */
- (void)loadView {
    [super loadView];
    self.view.userInteractionEnabled = YES;
    self.view.backgroundColor = UIColor.clearColor;
    self.appearFlg = NO;
}

/** @ghidraAddress 0x279db4 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x27be8c */
- (void)dealloc {
    if (self.indicator) {
        [self.indicator stopAnimating];
        [self.indicator removeFromSuperview];
    }
    self.indicator = nil;
    self.baseView = nil;
    self.shadeView = nil;
    self.applilinkDelegate = nil;
    self.applilinkFullViewDelegate = nil;
}

#pragma mark - Presentation

/** @ghidraAddress 0x279df0 */
- (void)openAdViewWithAdModel:(int)adModel
                   adLocation:(NSString *)adLocation
                verticalAlign:(int)verticalAlign
              applilinkParams:(ApplilinkParameters *)applilinkParams
                     delegate:(id)delegate
                closeDelegate:(id)closeDelegate {
    self.applilinkParams = applilinkParams;
    self.isVisible = NO;
    [self rotateWebViewWithDuration:0.0];
    (void)self.baseView.frame; // Yes, the binary reads and discards this frame.
    self.applilinkDelegate = delegate;
    self.applilinkFullViewDelegate = closeDelegate;

    NSString *impressionId = [ApplilinkUtilities getImpressionId];
    NSError *createError = [RecommendAdCache createHtmlWithAdModel:adModel
                                                        adLocation:adLocation
                                                     verticalAlign:verticalAlign
                                                      impressionId:impressionId];
    if (createError) {
        [ApplilinkCore toDelegateFailOpenWithError:createError
                                          appParam:self.applilinkParams
                                          delegate:delegate];
        [self releaseInterstitialView];
        return;
    }

    NSString *templatePath = [ApplilinkFile getTemplatePathWithAdModel:adModel
                                                            adLocation:adLocation];
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:templatePath isDirectory:&isDirectory]) {
        NSError *missingError =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorHtmlFileCreate
                                                          userInfo:@{
                                                              kRecommendHtmlFileCreateErrorKey :
                                                                  kRecommendHtmlFileCreateErrorValue
                                                          }];
        [ApplilinkCore toDelegateFailOpenWithError:missingError
                                          appParam:applilinkParams
                                          delegate:self.applilinkDelegate];
        [self releaseInterstitialView];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      /** @ghidraAddress 0x27a1e0 */
      RecommendAdAreaView *adView = [[RecommendAdAreaView alloc] initWithFrame:self.baseView.frame];
      adView.tag = kRecommendInterstitialViewTag;
      [adView setAdModel:adModel
              adLocation:adLocation
                  adType:kRecommendInterstitialAdType
             requestCode:self.applilinkParams.requestCode
                delegate:self];
      [adView setImpressionId:impressionId];
      [adView startPath:templatePath];
      [self.baseView addSubview:adView];
      [self webViewDidStartLoad];
    });
}

/** @ghidraAddress 0x27a394 */
- (void)openMovieWithAdModel:(int)adModel
                  adLocation:(NSString *)adLocation
               verticalAlign:(int)verticalAlign
             applilinkParams:(ApplilinkParameters *)applilinkParams
                    delegate:(id)delegate
               closeDelegate:(id)closeDelegate {
    self.applilinkParams = applilinkParams;
    self.isVisible = NO;
    [self rotateWebViewWithDuration:0.0];
    (void)self.baseView.frame; // Yes, the binary reads and discards this frame.
    self.applilinkDelegate = delegate;
    self.applilinkFullViewDelegate = closeDelegate;

    NSString *impressionId = [ApplilinkUtilities getImpressionId];
    NSError *queryError = nil;
    NSDictionary *movieQuery = [RecommendAdCache getMoviewQuaryWithAdModel:adModel
                                                                adLocation:adLocation
                                                             verticalAlign:verticalAlign
                                                              impressionId:impressionId
                                                                  errorObj:&queryError];
    if (movieQuery == nil) {
        [ApplilinkCore toDelegateFailOpenWithError:queryError
                                          appParam:self.applilinkParams
                                          delegate:delegate];
        self.applilinkDelegate = nil;
        [self releaseInterstitialView];
        return;
    }

    // Pick the movie URL: a random entry from the list when it is non-empty, otherwise the lone
    // movie_url value.
    NSArray *movieUrlList = movieQuery[kRecommendMovieQueryKeyMovieUrlList];
    NSString *movieUrl = movieQuery[kRecommendMovieQueryKeyMovieUrl];
    if (movieUrlList.count != 0) {
        // The binary reinterprets arc4random()'s result as a signed int and takes a signed modulo.
        int index = (int)arc4random() % (int)movieUrlList.count;
        movieUrl = movieUrlList[index];
    }

    // Strip the movie-link prefix, leaving the bare query, then append the tracking parameters.
    if ([movieUrl rangeOfString:kRecommendMovieLinkPrefix].location != NSNotFound) {
        movieUrl = [movieUrl substringFromIndex:kRecommendMovieLinkPrefix.length];
    }
    NSString *query = movieUrl;
    query = [query stringByAppendingFormat:kRecommendMovieQueryFormatImpressionId,
                                           [NSStringURLEncoding URLEncodedString:impressionId]];
    query = [query stringByAppendingFormat:kRecommendMovieQueryFormatAdModel, adModel];
    query = [query stringByAppendingFormat:kRecommendMovieQueryFormatAdLocation,
                                           [NSStringURLEncoding URLEncodedString:adLocation]];
    query = [query
        stringByAppendingFormat:
            kRecommendMovieQueryFormatCreativeId,
            [NSStringURLEncoding URLEncodedString:movieQuery[kRecommendMovieQueryKeyCreativeId]]];
    query = [query stringByAppendingFormat:kRecommendMovieQueryFormatDisplayNumber];
    query = [query stringByAppendingFormat:kRecommendMovieQueryFormatInstallFlg,
                                           movieQuery[kRecommendMovieQueryKeyInstallFlg]];

    dispatch_async(dispatch_get_main_queue(), ^{
      /** @ghidraAddress 0x27a980 */
      [self showVideoViewWithQuery:query];
    });
}

/** @ghidraAddress 0x27a9e8 */
- (void)showVideoViewWithQuery:(NSString *)query {
    [[ApplilinkViewManager sharedInstance] showVideoViewWithUIView:self.view
                                                  parentWindowFlag:YES
                                                             query:query
                                                          autoPlay:YES
                                                   applilinkParams:self.applilinkParams
                                                          delegate:self.applilinkDelegate];
    [[ApplilinkViewManager sharedInstance] setSdkDelegate:self];
}

#pragma mark - Layout

/**
 * @ghidraAddress 0x27ab90
 */
- (void)setViewSize {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    (void)[UIScreen mainScreen].bounds; // Yes, the binary reads and discards these bounds.
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGFloat screenWidth = screenBounds.size.width;
    CGFloat screenHeight = screenBounds.size.height;

    // The status bar thickness is the smaller of its reported frame's height and width, so it is
    // correct in either orientation.
    CGFloat statusBar = [UIApplication sharedApplication].statusBarFrame.size.height;
    CGFloat statusBarWidth = [UIApplication sharedApplication].statusBarFrame.size.width;
    if (statusBar > statusBarWidth) {
        statusBar = [UIApplication sharedApplication].statusBarFrame.size.width;
    }

    BOOL isLandscape = (orientation == UIInterfaceOrientationLandscapeLeft ||
                        orientation == UIInterfaceOrientationLandscapeRight);
    NSUInteger factor = isLandscape ? 1 : 0;
    CGFloat baseWidthFactor = kRecommendBaseWidthFactor[factor];
    CGFloat baseHeightFactor = kRecommendBaseHeightFactor[factor];
    CGFloat margin1 = kRecommendBaseMargin1[factor];
    CGFloat margin2 = kRecommendBaseMargin2[factor];
    if (screenWidth <= kRecommendNarrowScreenThreshold ||
        screenHeight <= kRecommendNarrowScreenThreshold) {
        baseWidthFactor *= 0.5;
        baseHeightFactor *= 0.5;
        margin1 *= 0.5;
        margin2 *= 0.5;
    }

    BOOL isXcode6 = [ApplilinkCore isBuildXcode6];

    CGRect shadeFrame =
        CGRectMake(screenBounds.origin.x, screenBounds.origin.y, screenWidth, screenHeight);
    CGRect baseFrame;
    if (isLandscape) {
        CGFloat systemVersion = [[UIDevice currentDevice].systemVersion floatValue];
        if (isXcode6 && systemVersion >= kRecommendXcode6SystemVersion) {
            // The Xcode 6 SDK reports orientation-aware bounds, so the height spans the long edge.
            CGFloat scale =
                (float)(((screenHeight - statusBar) - margin1 - margin2) / baseWidthFactor);
            CGFloat baseW = (float)(baseHeightFactor * scale);
            CGFloat baseH = (float)(baseWidthFactor * scale);
            CGFloat baseX = (screenWidth - baseW) * 0.5;
            CGFloat baseY = statusBar + ((screenHeight - baseH) - statusBar) * 0.5;
            baseFrame = CGRectMake(baseX, baseY, baseW, baseH);
        } else {
            // The legacy SDK reports portrait bounds, so the width and height roles are swapped.
            CGFloat scale =
                (float)(((screenWidth - statusBar) - margin1 - margin2) / baseWidthFactor);
            CGFloat baseW = (float)(baseHeightFactor * scale);
            CGFloat baseH = (float)(baseWidthFactor * scale);
            CGFloat baseX = (screenHeight - baseW) * 0.5;
            CGFloat baseY = statusBar + ((screenWidth - baseH) - statusBar) * 0.5;
            baseFrame = CGRectMake(baseX, baseY, baseW, baseH);
            // The shade fills the reported (portrait) bounds, rotated by the transform later.
            shadeFrame.size = CGSizeMake(screenHeight, screenWidth);
            CGFloat legacyVersion = [[UIDevice currentDevice].systemVersion floatValue];
            if (legacyVersion < kRecommendStatusBarInsetSystemVersion) {
                shadeFrame.origin.y = statusBar;
            }
        }
    } else {
        CGFloat scale = (float)(((screenWidth - statusBar) - margin1 - margin2) / baseWidthFactor);
        CGFloat baseW = (float)(baseWidthFactor * scale);
        CGFloat baseH = (float)(baseHeightFactor * scale);
        CGFloat baseX = (screenWidth - baseW) * 0.5;
        CGFloat baseY = statusBar + ((screenHeight - baseH) - statusBar) * 0.5;
        baseFrame = CGRectMake(baseX, baseY, baseW, baseH);
        CGFloat portraitVersion = [[UIDevice currentDevice].systemVersion floatValue];
        if (portraitVersion < kRecommendStatusBarInsetSystemVersion) {
            shadeFrame.origin.y = statusBar;
        }
    }

    if (self.shadeView == nil) {
        self.shadeView = [[ShadeView alloc] initWithFrame:shadeFrame];
        self.shadeView.delegate = self;
        self.shadeView.hidden = YES;
        self.shadeView.userInteractionEnabled = NO;
        [self.view addSubview:self.shadeView];
    } else {
        [self.shadeView setFrame:shadeFrame];
    }

    if (self.baseView != nil) {
        [self.baseView setFrame:baseFrame];
        return;
    }
    self.baseView = [[UIView alloc] initWithFrame:baseFrame];
    self.baseView.backgroundColor = UIColor.clearColor;
    self.baseView.hidden = YES;
    [self.shadeView addSubview:self.baseView];
}

/**
 * @ghidraAddress 0x27b248
 */
- (void)rotateWebViewWithDuration:(double)duration {
    [self setViewSize];
    BOOL isXcode6 = [ApplilinkCore isBuildXcode6];
    CGFloat systemVersion = [[UIDevice currentDevice].systemVersion floatValue];
    if (systemVersion >= kRecommendXcode6SystemVersion && isXcode6) {
        // The Xcode 6 SDK lays the shade out in the reported orientation; no transform is needed.
        return;
    }

    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    CGFloat statusBarInset = 0.0;
    CGFloat legacyVersion = [[UIDevice currentDevice].systemVersion floatValue];
    if (legacyVersion < kRecommendStatusBarInsetSystemVersion) {
        CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
        BOOL isLandscape = (orientation == UIInterfaceOrientationLandscapeLeft ||
                            orientation == UIInterfaceOrientationLandscapeRight);
        statusBarInset = isLandscape ? statusBarFrame.size.width : statusBarFrame.size.height;
    }

    CGRect shadeFrame = self.shadeView.frame;
    CGAffineTransform transform;
    switch (orientation) {
    case UIInterfaceOrientationPortraitUpsideDown:
        // Rotate by pi (g_dPi at 0x28f278).
        transform = CGAffineTransformMakeRotation((CGFloat)M_PI);
        break;
    case UIInterfaceOrientationLandscapeLeft:
        // pi/2, from the __const pool at 0x28f460.
        transform = CGAffineTransformMakeRotation((CGFloat)M_PI_2);
        break;
    case UIInterfaceOrientationLandscapeRight:
        // -pi/2, from the __const pool at 0x291c00.
        transform = CGAffineTransformMakeRotation((CGFloat)(-M_PI_2));
        break;
    default:
        transform = CGAffineTransformMakeRotation(0.0);
        break;
    }

    [UIView animateWithDuration:duration
                     animations:^{
                       /** @ghidraAddress 0x27b5a0 */
                       self.view.transform = transform;
                       [self.view setBounds:CGRectMake(shadeFrame.origin.x,
                                                       statusBarInset,
                                                       shadeFrame.size.width,
                                                       shadeFrame.size.height)];
                     }];
}

/** @ghidraAddress 0x27b66c */
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                         duration:(NSTimeInterval)duration {
    [self rotateWebViewWithDuration:duration];
}

#pragma mark - Rotation

/** @ghidraAddress 0x27ab10 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    if (![self shouldAutorotate]) {
        return NO;
    }
    // The binary indexes a table of masks (2, 4, 8, 0x10 at 0x294540) by orientation - 1. Those are
    // the same values the named masks hold, since each mask is 1 << its orientation.
    NSUInteger bit;
    switch (orientation) {
    case UIInterfaceOrientationPortrait:
        bit = UIInterfaceOrientationMaskPortrait;
        break;
    case UIInterfaceOrientationPortraitUpsideDown:
        bit = UIInterfaceOrientationMaskPortraitUpsideDown;
        break;
    case UIInterfaceOrientationLandscapeLeft:
        bit = UIInterfaceOrientationMaskLandscapeLeft;
        break;
    case UIInterfaceOrientationLandscapeRight:
        bit = UIInterfaceOrientationMaskLandscapeRight;
        break;
    default:
        return NO;
    }
    return ([self supportedInterfaceOrientations] & bit) != 0;
}

/** @ghidraAddress 0x27ab80 */
- (BOOL)shouldAutorotate {
    return YES;
}

/** @ghidraAddress 0x27ab88 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // The binary returns the raw mask 0x1e: portrait, upside down, and both landscapes.
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown |
           UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight;
}

#pragma mark - ApplilinkViewDelegate

/** @ghidraAddress 0x27b67c */
- (void)webViewDidStartLoad {
    self.shadeView.hidden = NO;
    [RecommendFullScreenController cancelPreviousPerformRequestsWithTarget:self];
    [[ApplilinkCore mainWindow] addSubview:self.view];
    self.isVisible = YES;
    [ApplilinkCore toDelegateDidStart:self.applilinkParams delegate:self.applilinkDelegate];
    self.appearFlg = YES;
}

/** @ghidraAddress 0x27b7b4 */
- (void)appListDidAppear {
    [ApplilinkCore toDelegateDidAppear:self.applilinkParams delegate:self.applilinkDelegate];
    if (self.indicator) {
        [self.indicator stopAnimating];
        [self.indicator removeFromSuperview];
    }
    self.indicator = nil;
    [RecommendFullScreenController cancelPreviousPerformRequestsWithTarget:self];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kRecommendShowBaseViewDelayNanoseconds),
                   dispatch_get_main_queue(),
                   ^{
                     /** @ghidraAddress 0x27b8fc */
                     // The shade is unhidden and made interactive before the base view, so for one
                     // frame the shade is visible over a still-hidden base view.
                     self.shadeView.userInteractionEnabled = YES;
                     self.shadeView.hidden = NO;
                     self.baseView.hidden = NO;
                   });
}

/** @ghidraAddress 0x27b984 */
- (void)appListDidDisappear {
    [self closeShadeView];
}

/** @ghidraAddress 0x27b994 */
- (void)appListFailLoadWithError:(NSError *)error {
    [ApplilinkCore toDelegateFailLoadWithError:error
                                      appParam:self.applilinkParams
                                      delegate:self.applilinkDelegate];
    self.applilinkDelegate = nil;
    [self releaseInterstitialView];
}

/** @ghidraAddress 0x27ba44 */
- (void)appListFailLinkWithError:(NSError *)error {
    [ApplilinkCore toDelegateFailLinkWithError:error
                                      appParam:self.applilinkParams
                                      delegate:self.applilinkDelegate];
}

/** @ghidraAddress 0x27bac8 */
- (void)appListSoundUseStart {
    [ApplilinkCore toDelegateSoundUseStart:self.applilinkDelegate];
}

/** @ghidraAddress 0x27bb18 */
- (void)appListSoundUseFinish {
    [ApplilinkCore toDelegateSoundUseFinish:self.applilinkDelegate];
}

#pragma mark - SdkViewDelegate

/** @ghidraAddress 0x27bb68 */
- (void)openedNotice {
    [self appListDidAppear];
}

/** @ghidraAddress 0x27bb78 */
- (void)closeNotice {
    [self appListDidDisappear];
}

/** @ghidraAddress 0x27bb88 */
- (void)closeNotice:(nullable id)view {
    [ApplilinkCore toDelegateSoundUseFinish:self.applilinkDelegate];
    [self appListDidDisappear];
}

/** @ghidraAddress 0x27bbf8 */
- (void)viewReady:(nullable id)view {
    [self webViewDidStartLoad];
}

/** @ghidraAddress 0x27bc08 */
- (void)failOpenNoticeWithError:(NSError *)error {
    [ApplilinkCore toDelegateFailLoadWithError:error
                                      appParam:self.applilinkParams
                                      delegate:self.applilinkDelegate];
    self.applilinkDelegate = nil;
}

/** @ghidraAddress 0x27bca0 */
- (void)failLinkNoticeWithError:(NSError *)error {
    [ApplilinkCore toDelegateFailLinkWithError:error
                                      appParam:self.applilinkParams
                                      delegate:self.applilinkDelegate];
}

#pragma mark - Teardown

/** @ghidraAddress 0x27bd24 */
- (void)closeShadeView {
    if (self.appearFlg) {
        self.appearFlg = NO;
        [ApplilinkCore toDelegateDidDisappear:self.applilinkParams delegate:self.applilinkDelegate];
    }
    self.applilinkDelegate = nil;
    [self releaseInterstitialView];
}

/** @ghidraAddress 0x27bdcc */
- (void)releaseInterstitialView {
    if (self.applilinkFullViewDelegate) {
        if ([self.applilinkFullViewDelegate
                respondsToSelector:@selector(releaseInterstitialViewController)]) {
            [self.applilinkFullViewDelegate
                performSelector:@selector(releaseInterstitialViewController)];
            self.applilinkFullViewDelegate = nil;
        }
    }
    self.isVisible = NO;
}

@end
