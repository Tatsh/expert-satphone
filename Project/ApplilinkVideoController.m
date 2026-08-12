#import "ApplilinkVideoController.h"

#import "AnalysisNetworkCore.h"
#import "AppliView.h"
#import "ApplilinkCore.h"
#import "ApplilinkIndicator.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkParameters.h"
#import "ApplilinkViewManager.h"
#import "ApplilinkWebView.h"
#import "NSStringURLEncoding.h"
#import "RecommendCore.h"
#import "VideoView.h"

// The query separator and the recognised key prefixes, exactly as the binary stores them as
// CFString constants in __cfstring.
static NSString *const kApplilinkQuerySeparator = @"&";
static NSString *const kApplilinkQueryKeyMovieUrl = @"movie_url=";
static NSString *const kApplilinkQueryKeyPosterUrlRect = @"poster_url_rect=";
static NSString *const kApplilinkQueryKeyStoreUrl = @"store_url=";
static NSString *const kApplilinkQueryKeyStoreId = @"store_id=";
static NSString *const kApplilinkQueryKeyMovieVoiceFlg = @"movie_voice_flg=";
static NSString *const kApplilinkQueryKeyAdType = @"ad_type=";
static NSString *const kApplilinkQueryKeyAdModel = @"ad_model=";
static NSString *const kApplilinkQueryKeyAdLocation = @"ad_location=";
static NSString *const kApplilinkQueryKeyImpressionId = @"impression_id=";
static NSString *const kApplilinkQueryKeyAppliIdTo = @"appli_id_to=";
static NSString *const kApplilinkQueryKeyAdIdFrom = @"ad_id_from=";
static NSString *const kApplilinkQueryKeyAdIdTo = @"ad_id_to=";
static NSString *const kApplilinkQueryKeyCreativeId = @"creative_id=";
static NSString *const kApplilinkQueryKeyDisplayNumber = @"display_number=";
static NSString *const kApplilinkQueryKeyIncentiveType = @"incentive_type=";
static NSString *const kApplilinkQueryKeyInstallFlg = @"install_flg=";

// The movie-status codes posted to the analysis click endpoint.
static const int kApplilinkMovieStatusStart = 1;
static const int kApplilinkMovieStatusEnd = 2;
static const int kApplilinkMovieStatusStoreFromVideo = 3;
static const int kApplilinkMovieStatusStoreFromEndCard = 4;

// The applilink error code raised when the movie cannot auto-start.
static const NSInteger kApplilinkErrorCodeMovieAutoStartFailed = 0x410;

// The iOS system version below which the SDK compensates the layout for the status bar, and the
// version at/above which the Xcode-6 layout compensation applies. Both are read as fmov immediates
// in the binary (7.0 at 0x40e00000, 8.0 at 0x41000000).
static const float kApplilinkStatusBarCompensateBelowVersion = 7.0f;
static const float kApplilinkXcode6LayoutVersion = 8.0f;

@implementation ApplilinkVideoController

@synthesize sdkDelegate = _sdkDelegate;
@synthesize appliView = _appliView;
@synthesize videoView = _videoView;
@synthesize webView = _webView;
@synthesize baseView = _baseView;
@synthesize indicator = _indicator;
@synthesize applilinkDelegate = _applilinkDelegate;
@synthesize applilinkParams = _applilinkParams;
@synthesize videoBaseView = _videoBaseView;
@synthesize movieUrl = _movieUrl;
@synthesize posterUrlRect = _posterUrlRect;
@synthesize storeUrl = _storeUrl;
@synthesize storeId = _storeId;
@synthesize endUrl = _endUrl;
@synthesize movieVoiceFlg = _movieVoiceFlg;
@synthesize adType = _adType;
@synthesize adModel = _adModel;
@synthesize adLocation = _adLocation;
@synthesize impressionId = _impressionId;
@synthesize appliIdTo = _appliIdTo;
@synthesize adIdFrom = _adIdFrom;
@synthesize adIdTo = _adIdTo;
@synthesize creativeId = _creativeId;
@synthesize displayNumber = _displayNumber;
@synthesize incentiveType = _incentiveType;
@synthesize installFlg = _installFlg;
@synthesize requestCode = _requestCode;
@synthesize movieEndViewReadyFlg = _movieEndViewReadyFlg;
@synthesize parentWindowFlag = _parentWindowFlag;

#pragma mark - View lifecycle

/** @ghidraAddress 0x223b08 */
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    [self setViewSizeWithDuration:0.0];
}

/** @ghidraAddress 0x223bdc */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Setup

/** @ghidraAddress 0x223c80 */
- (void)parentWindowFlag:(BOOL)parentWindowFlag {
    _parentWindowFlag = parentWindowFlag;
}

/** @ghidraAddress 0x223c90 */
- (BOOL)setQuery:(NSString *)query
           autoPlay:(BOOL)autoPlay
    applilinkParams:(ApplilinkParameters *)applilinkParams
           delegate:(id)delegate {
    // The parameters and delegate are stored straight into their backing ivars (the params are
    // retained despite the copy attribute, and the delegate through the weak store).
    _applilinkParams = applilinkParams;
    _applilinkDelegate = delegate;

    if (autoPlay) {
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x224790 */
          [self indicatorDealloc];
        });
    }

    if (query == nil) {
        return NO;
    }

    // Clear every parsed parameter before re-parsing.
    self.movieUrl = nil;
    self.posterUrlRect = nil;
    self.storeUrl = nil;
    self.adType = nil;
    self.adModel = nil;
    self.adLocation = nil;
    self.impressionId = nil;
    self.appliIdTo = nil;
    self.adIdFrom = nil;
    self.adIdTo = nil;
    self.creativeId = nil;
    self.displayNumber = nil;
    self.incentiveType = nil;
    self.installFlg = nil;
    self.movieVoiceFlg = nil;

    for (NSString *pair in [query componentsSeparatedByString:kApplilinkQuerySeparator]) {
        if ([pair rangeOfString:kApplilinkQueryKeyMovieUrl].location != NSNotFound) {
            NSString *value = [pair substringFromIndex:kApplilinkQueryKeyMovieUrl.length];
            self.movieUrl = [NSStringURLEncoding URLDecodedString:value];
        } else if ([pair rangeOfString:kApplilinkQueryKeyPosterUrlRect].location != NSNotFound) {
            NSString *value = [pair substringFromIndex:kApplilinkQueryKeyPosterUrlRect.length];
            self.posterUrlRect = [NSStringURLEncoding URLDecodedString:value];
        } else if ([pair rangeOfString:kApplilinkQueryKeyStoreUrl].location != NSNotFound) {
            NSString *value = [pair substringFromIndex:kApplilinkQueryKeyStoreUrl.length];
            self.storeUrl = [NSStringURLEncoding URLDecodedString:value];
        } else if ([pair rangeOfString:kApplilinkQueryKeyStoreId].location != NSNotFound) {
            NSString *value = [pair substringFromIndex:kApplilinkQueryKeyStoreId.length];
            self.storeId = [NSStringURLEncoding URLDecodedString:value];
        } else if ([pair rangeOfString:kApplilinkQueryKeyMovieVoiceFlg].location != NSNotFound) {
            NSString *value = [pair substringFromIndex:kApplilinkQueryKeyMovieVoiceFlg.length];
            self.movieVoiceFlg = [NSStringURLEncoding URLDecodedString:value];
        } else if ([pair rangeOfString:kApplilinkQueryKeyAdType].location != NSNotFound) {
            NSString *value = [pair substringFromIndex:kApplilinkQueryKeyAdType.length];
            self.adType = [NSStringURLEncoding URLDecodedString:value];
        } else if ([pair rangeOfString:kApplilinkQueryKeyAdModel].location != NSNotFound) {
            NSString *value = [pair substringFromIndex:kApplilinkQueryKeyAdModel.length];
            self.adModel = [NSStringURLEncoding URLDecodedString:value];
        } else if ([pair rangeOfString:kApplilinkQueryKeyAdLocation].location != NSNotFound) {
            NSString *value = [pair substringFromIndex:kApplilinkQueryKeyAdLocation.length];
            self.adLocation = [NSStringURLEncoding URLDecodedString:value];
        } else if ([pair rangeOfString:kApplilinkQueryKeyImpressionId].location != NSNotFound) {
            NSString *value = [pair substringFromIndex:kApplilinkQueryKeyImpressionId.length];
            self.impressionId = [NSStringURLEncoding URLDecodedString:value];
        } else if ([pair rangeOfString:kApplilinkQueryKeyAppliIdTo].location != NSNotFound) {
            NSString *value = [pair substringFromIndex:kApplilinkQueryKeyAppliIdTo.length];
            self.appliIdTo = [NSStringURLEncoding URLDecodedString:value];
        } else if ([pair rangeOfString:kApplilinkQueryKeyAdIdFrom].location != NSNotFound) {
            NSString *value = [pair substringFromIndex:kApplilinkQueryKeyAdIdFrom.length];
            self.adIdFrom = [NSStringURLEncoding URLDecodedString:value];
        } else if ([pair rangeOfString:kApplilinkQueryKeyAdIdTo].location != NSNotFound) {
            NSString *value = [pair substringFromIndex:kApplilinkQueryKeyAdIdTo.length];
            self.adIdTo = [NSStringURLEncoding URLDecodedString:value];
        } else if ([pair rangeOfString:kApplilinkQueryKeyCreativeId].location != NSNotFound) {
            NSString *value = [pair substringFromIndex:kApplilinkQueryKeyCreativeId.length];
            self.creativeId = [NSStringURLEncoding URLDecodedString:value];
        } else if ([pair rangeOfString:kApplilinkQueryKeyDisplayNumber].location != NSNotFound) {
            NSString *value = [pair substringFromIndex:kApplilinkQueryKeyDisplayNumber.length];
            self.displayNumber = [NSStringURLEncoding URLDecodedString:value];
        } else if ([pair rangeOfString:kApplilinkQueryKeyIncentiveType].location != NSNotFound) {
            NSString *value = [pair substringFromIndex:kApplilinkQueryKeyIncentiveType.length];
            self.incentiveType = [NSStringURLEncoding URLDecodedString:value];
        } else if ([pair rangeOfString:kApplilinkQueryKeyInstallFlg].location != NSNotFound) {
            NSString *value = [pair substringFromIndex:kApplilinkQueryKeyInstallFlg.length];
            self.installFlg = [NSStringURLEncoding URLDecodedString:value];
        }
    }

    [self setUpMovieView:autoPlay];
    return YES;
}

/** @ghidraAddress 0x2247b4 */
- (void)setUpMovieView:(BOOL)autoPlay {
    // The bounds and status-bar orientation are fetched purely for effect here (their results are
    // discarded); the real layout happens on the main queue inside the block.
    (void)UIScreen.mainScreen.bounds;
    (void)UIApplication.sharedApplication.statusBarOrientation;
    (void)self.view.frame;
    dispatch_async(dispatch_get_main_queue(), ^{
      /** @ghidraAddress 0x2248e4 */
      if (autoPlay) {
          [self.videoView setAutoPlay];
      }
      [self.videoView setDelegate:self];
      [self.appliView addSubview:self.videoView];
      [self.videoView setMovieUrl:self.movieUrl
                        posterUrl:self.posterUrlRect
                    movieVoiceFlg:self.movieVoiceFlg];
      if (self.indicator != nil) {
          [self.indicator setUserInteractionEnabled:NO];
      }
    });
}

/** @ghidraAddress 0x2249e8 */
- (void)setViewSizeWithDuration:(NSTimeInterval)duration {
    UIInterfaceOrientation orientation = UIApplication.sharedApplication.statusBarOrientation;
    CGRect screenBounds = UIScreen.mainScreen.bounds;
    // The status-bar thickness is the thinner of the status-bar frame's two dimensions.
    CGRect statusBarFrame = UIApplication.sharedApplication.statusBarFrame;
    CGFloat statusBarThickness = statusBarFrame.size.height;
    if (statusBarFrame.size.width < statusBarThickness) {
        statusBarThickness = UIApplication.sharedApplication.statusBarFrame.size.width;
    }
    BOOL isBuildXcode6 = [ApplilinkCore isBuildXcode6];

    // In a portrait idiom the width and height are used as read; in a landscape orientation
    // (LandscapeLeft or LandscapeRight) they are swapped, unless the running OS is at least 8.0 and
    // the build is an Xcode-6 build (the "modern" layout, where UIKit already reports rotated
    // bounds).
    BOOL landscape = (orientation == UIInterfaceOrientationLandscapeLeft ||
                      orientation == UIInterfaceOrientationLandscapeRight);
    BOOL modernLandscapeLayout =
        (UIDevice.currentDevice.systemVersion.floatValue >= kApplilinkXcode6LayoutVersion &&
         isBuildXcode6);
    CGFloat width = screenBounds.size.width;
    CGFloat height = screenBounds.size.height;
    if (landscape && !modernLandscapeLayout) {
        width = screenBounds.size.height;
        height = screenBounds.size.width;
    }

    // The status-bar compensation applies on iOS 7.0 or newer that is not the modern (8.0 plus
    // Xcode-6) layout, and only when the controller is hosted directly in the parent window.
    BOOL compensate =
        (UIDevice.currentDevice.systemVersion.floatValue >=
             kApplilinkStatusBarCompensateBelowVersion &&
         (UIDevice.currentDevice.systemVersion.floatValue < kApplilinkXcode6LayoutVersion ||
          !isBuildXcode6) &&
         self.parentWindowFlag);
    // The controller-view origin offset: the status-bar thickness only when upside-down.
    CGFloat viewOffset = 0.0;
    if (compensate && orientation == UIInterfaceOrientationPortraitUpsideDown) {
        viewOffset = statusBarThickness;
    }
    // The advert-surface origin offset: the view offset shifted by the thickness for the two
    // landscape-adjacent orientations.
    CGFloat surfaceOffset = viewOffset;
    if (compensate) {
        if (orientation == UIInterfaceOrientationLandscapeRight) {
            surfaceOffset = viewOffset + statusBarThickness;
        } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
            surfaceOffset = viewOffset - statusBarThickness;
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      /** @ghidraAddress 0x224e98 */
      // Size the controller's own view.
      self.view.frame = CGRectMake(0.0, viewOffset, width, height);

      // When hosted in a window, rotate the root view to match the orientation and animate the
      // transform and bounds.
      if ([self.view.superview isKindOfClass:[UIWindow class]]) {
          CGAffineTransform transform;
          CGFloat centerWidth;
          CGFloat centerHeight;
          switch (orientation) {
          case UIInterfaceOrientationPortraitUpsideDown:
              // Rotate by pi (g_dPi).
              transform = CGAffineTransformMakeRotation(M_PI);
              centerWidth = width;
              centerHeight = height;
              break;
          case UIInterfaceOrientationLandscapeRight:
              // pi/2, from the __const pool at 0x28f460.
              transform = CGAffineTransformMakeRotation(M_PI_2);
              centerWidth = height;
              centerHeight = width;
              break;
          case UIInterfaceOrientationLandscapeLeft:
              // -pi/2, from the __const pool at 0x291c00.
              transform = CGAffineTransformMakeRotation(-M_PI_2);
              centerWidth = height;
              centerHeight = width;
              break;
          default:
              transform = CGAffineTransformMakeRotation(0.0);
              centerWidth = width;
              centerHeight = height;
              break;
          }
          self.view.center = CGPointMake(centerWidth * 0.5, centerHeight * 0.5);
          [UIView animateWithDuration:duration
                           animations:^{
                             /** @ghidraAddress 0x225574 */
                             self.view.transform = transform;
                             self.view.bounds = CGRectMake(0.0, viewOffset, width, height);
                           }];
      }

      BOOL preIOS7 = UIDevice.currentDevice.systemVersion.floatValue <
                     kApplilinkStatusBarCompensateBelowVersion;

      // Build the black advert surface the first time; otherwise re-frame it (insetting the top by
      // the status-bar thickness on iOS below 7.0).
      if (self.appliView == nil) {
          self.appliView =
              [[AppliView alloc] initWithFrame:CGRectMake(0.0, surfaceOffset, width, height)];
          self.appliView.backgroundColor = UIColor.blackColor;
          [self.appliView setDelegate:self];
          [self.appliView setHidden:YES];
          [self.view addSubview:self.appliView];
          if (self.indicator == nil) {
              self.indicator = [[ApplilinkIndicator alloc]
                  initWithFrame:CGRectMake(0.0, surfaceOffset, width, height)];
              [self.view addSubview:self.indicator];
              [self.indicator show];
          }
      } else {
          CGFloat surfaceY = surfaceOffset;
          CGFloat surfaceHeight = height;
          if (preIOS7) {
              surfaceY = surfaceOffset + statusBarThickness;
              surfaceHeight = height - statusBarThickness;
          }
          self.appliView.frame = CGRectMake(0.0, surfaceY, width, surfaceHeight);
          if (self.indicator != nil) {
              self.indicator.frame = CGRectMake(0.0, surfaceY, width, surfaceHeight);
          }
      }

      // Size (or build) the player, then the end-card web view if present. The player is inset
      // from the top by the status-bar thickness on iOS below 7.0.
      CGFloat playerHeight = preIOS7 ? height - statusBarThickness : height;
      CGFloat playerY = 0.0;
      if (self.videoView == nil) {
          playerY = preIOS7 ? statusBarThickness : 0.0;
          self.videoView =
              [[VideoView alloc] initWithFrame:CGRectMake(0.0, playerY, width, playerHeight)];
      } else {
          // An already-built player is re-framed to the origin, leaving the shared web-view origin
          // at zero.
          [self.videoView setFrame:CGRectMake(0.0, 0.0, width, playerHeight)];
      }
      if (self.webView != nil) {
          [self.webView setFrame:CGRectMake(0.0, playerY, width, playerHeight)];
      }
    });
}

/** @ghidraAddress 0x225888 */
- (void)loadWebView {
    if (self.webView != nil) {
        return;
    }
    NSString *endUrl = [RecommendCore.sharedInstance getMovideEndUrlWithAdIdFrom:self.adIdFrom
                                                                          adIdTo:self.adIdTo
                                                                         adModel:self.adModel
                                                                      adLocation:self.adLocation
                                                                    impressionId:self.impressionId
                                                                      creativeId:self.creativeId
                                                                   displayNumber:self.displayNumber
                                                                      installFlg:self.installFlg];
    if (endUrl == nil) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      /** @ghidraAddress 0x2259e0 */
      CGRect viewFrame = self.view.frame;
      self.webView = [[ApplilinkWebView alloc]
          initWithFrame:CGRectMake(0.0, 0.0, viewFrame.size.width, viewFrame.size.height)];
      [self.webView setSdkDelegate:self];
      self.webView.center =
          CGPointMake(self.view.frame.size.width * 0.5, self.view.frame.size.height * 0.5);
      [self.webView setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin |
                                        UIViewAutoresizingFlexibleWidth |
                                        UIViewAutoresizingFlexibleRightMargin |
                                        UIViewAutoresizingFlexibleTopMargin |
                                        UIViewAutoresizingFlexibleHeight |
                                        UIViewAutoresizingFlexibleBottomMargin];
      [self.webView setContentMode:UIViewContentModeScaleAspectFit];
      NSMutableURLRequest *request =
          [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endUrl]];
      [self.webView loadRequest:request];
    });
}

#pragma mark - Indicator

/** @ghidraAddress 0x223c18 */
- (void)indicatorDealloc {
    if (self.indicator != nil) {
        [self.indicator close];
        [self.indicator removeFromSuperview];
    }
    self.indicator = nil;
}

#pragma mark - Rotation

/** @ghidraAddress 0x225650 */
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                         duration:(NSTimeInterval)duration {
    [self setViewSizeWithDuration:duration];
}

/** @ghidraAddress 0x225660 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

/** @ghidraAddress 0x225668 */
- (BOOL)shouldAutorotate {
    return YES;
}

/** @ghidraAddress 0x225670 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // The binary returns the raw mask 0x1e = UIInterfaceOrientationMaskAll.
    return UIInterfaceOrientationMaskAll;
}

#pragma mark - Touch

/** @ghidraAddress 0x225678 */
- (void)toucheEnded {
    [self closeView];
}

#pragma mark - Analysis

/** @ghidraAddress 0x225688 */
- (void)analysisWithStatus:(int)movieStatus callback:(void (^)(NSError *error))callback {
    [AnalysisNetworkCore postAnalysisClickMovieWithAdType:self.adType
                                                  adModel:self.adModel
                                               adLocation:self.adLocation
                                             impressionId:self.impressionId
                                                appliIdTo:self.appliIdTo
                                               creativeId:self.creativeId
                                            displayNumber:self.displayNumber
                                            incentiveType:self.incentiveType
                                               installFlg:self.installFlg
                                              movieStatus:movieStatus
                                                 callback:callback];
}

#pragma mark - VideoView / SdkView delegate: movie lifecycle

/** @ghidraAddress 0x225740 */
- (void)movieStart {
    [self analysisWithStatus:kApplilinkMovieStatusStart
                    callback:^(NSError *__attribute__((unused)) error){
                        /** @ghidraAddress 0x22575c */
                        // Empty error handler; failures are swallowed.
                    }];
}

/** @ghidraAddress 0x225760 */
- (void)movieEnd {
    [ApplilinkCore toDelegateMovieFinish:self.applilinkDelegate];
    [self analysisWithStatus:kApplilinkMovieStatusEnd
                    callback:^(NSError *__attribute__((unused)) error) {
                      /** @ghidraAddress 0x225820 */
                      // Once the movie has ended, either show the ready end card or pin the player
                      // on its finished frame.
                      if (self.movieEndViewReadyFlg) {
                          [self.appliView addSubview:self.webView];
                      } else {
                          [self.videoView finish];
                      }
                    }];
}

/** @ghidraAddress 0x225f14 */
- (void)movieSoundUse {
    [ApplilinkCore toDelegateSoundUseStart:self.applilinkDelegate];
}

/** @ghidraAddress 0x225f64 */
- (void)movieReady {
    [self indicatorDealloc];
}

/** @ghidraAddress 0x225f74 */
- (void)movieError {
    [self indicatorDealloc];
}

/** @ghidraAddress 0x225f84 */
- (void)movieAutoStartError {
    [self indicatorDealloc];
    NSError *error = [ApplilinkNetworkError
        localizedApplilinkErrorWithCode:kApplilinkErrorCodeMovieAutoStartFailed];
    [ApplilinkCore toDelegateFailOpenWithError:error
                                      appParam:self.applilinkParams
                                      delegate:self.applilinkDelegate];
    self.applilinkDelegate = nil;
    [[ApplilinkViewManager sharedInstance] closeNotice:self];
}

/** @ghidraAddress 0x22608c */
- (void)movieCacheEnd {
    [self loadWebView];
}

#pragma mark - VideoView / SdkView delegate: ready and store

/** @ghidraAddress 0x225dec */
- (void)viewReady:(id)view {
    if (self.videoView == view) {
        [self.appliView setHidden:NO];
    }
    if (self.webView == view) {
        self.movieEndViewReadyFlg = YES;
    }
    if (self.videoView == view) {
        if (self.sdkDelegate != nil &&
            [self.sdkDelegate respondsToSelector:@selector(viewReady:)]) {
            [self.sdkDelegate viewReady:self];
        }
    }
}

/** @ghidraAddress 0x22609c */
- (void)storeNotice:(id)view {
    if (self.videoView == view) {
        [self analysisWithStatus:kApplilinkMovieStatusStoreFromVideo
                        callback:^(NSError *__attribute__((unused)) error) {
                          /** @ghidraAddress 0x2261b0 */
                          [self toStore];
                        }];
    }
    if (self.webView == view) {
        [self analysisWithStatus:kApplilinkMovieStatusStoreFromEndCard
                        callback:^(NSError *__attribute__((unused)) error) {
                          /** @ghidraAddress 0x2261d4 */
                          [self toStore];
                        }];
    }
}

/** @ghidraAddress 0x2261f8 */
- (void)closeNotice:(id)view {
    if (self.webView != view && self.videoView != view) {
        return;
    }
    [self closeView];
}

/** @ghidraAddress 0x226234 */
- (void)repeatNotice:(id)view {
    if (self.webView != view) {
        return;
    }
    [view removeFromSuperview];
    [self.videoView repeat];
}

/** @ghidraAddress 0x22629c */
- (void)linkErrorNotice:(id)view error:(NSError *)error {
    if (self.webView != view) {
        return;
    }
    [ApplilinkCore toDelegateFailLinkWithError:error
                                      appParam:self.applilinkParams
                                      delegate:self.applilinkDelegate];
}

/** @ghidraAddress 0x22635c */
- (void)appStoreFailLoadNoticeWithError:(NSError *)error {
    // Empty in the binary.
}

#pragma mark - Store transition

/** @ghidraAddress 0x225c74 */
- (void)toStore {
    if (self.indicator == nil && self.storeUrl != nil) {
        [RecommendCore.sharedInstance linkActionWithURL:self.storeUrl delegate:self];
    }
}

/** @ghidraAddress 0x225d08 */
- (void)appListDidAppear {
    if (self.storeUrl == nil) {
        return;
    }
    NSURL *url = [NSURL URLWithString:self.storeUrl];
    // The binary sends -setURL: to nil here, so the result is discarded.
    [(id)nil setURL:url]; // Yes, the binary messages nil with the parsed URL.
    if (url != nil) {
        if ([UIApplication.sharedApplication canOpenURL:url]) {
            [self closeView];
        }
    }
}

#pragma mark - Close and teardown

/** @ghidraAddress 0x226360 */
- (void)closeView {
    if (self.sdkDelegate != nil && [self.sdkDelegate respondsToSelector:@selector(closeNotice:)]) {
        [self.sdkDelegate closeNotice:self];
    }
}

/** @ghidraAddress 0x226418 */
- (void)viewDealloc {
    [self indicatorDealloc];
    if (self.webView != nil) {
        [self.webView setDelegate:nil];
        if (self.webView != nil) {
            [self.webView removeFromSuperview];
        }
    }
    if (self.videoView != nil) {
        [self.videoView deallocPlayer];
        [self.videoView clearDelegate];
        [self.videoView removeFromSuperview];
    }
    self.webView = nil;
    self.videoView = nil;
    self.sdkDelegate = nil;
    self.movieUrl = nil;
    self.posterUrlRect = nil;
    self.storeUrl = nil;
    self.adType = nil;
    self.adModel = nil;
    self.adLocation = nil;
    self.impressionId = nil;
    self.appliIdTo = nil;
    self.adIdFrom = nil;
    self.adIdTo = nil;
    self.creativeId = nil;
    self.displayNumber = nil;
    self.incentiveType = nil;
    self.installFlg = nil;
    [self.view removeFromSuperview];
}

@end
