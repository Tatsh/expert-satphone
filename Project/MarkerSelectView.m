#import "MarkerSelectView.h"

#import "AudioManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "MarkerManager.h"

// The persisted marker identifier, keyed in NSUserDefaults.
static NSString *const kPrefCurrentMarkerIDKey = @"PrefCurrentMarkerID";

// The banner-list marker dictionary keys.
static NSString *const kBannerNameKey = @"bannerName";
static NSString *const kMarkerIDKey = @"markerID";

// The marker button title font.
static NSString *const kMarkerButtonFontName = @"Helvetica-Bold";

// The preview sound base name passed to -soundName:.
static NSString *const kMarkerSelectSoundName = @"MUSIC_SELECT";

// The number of copies of the marker list tiled into the scroll content, giving the wrap-around
// paging effect.
static const int kTiledCopies = 3;

// The banner-list scroll view is 1.5 points shorter than the view.
static const CGFloat kBannerScrollHeightInset = 1.5;

// The marker-button shadow radius and vertical shadow offset.
static const CGFloat kMarkerButtonShadowRadius = 3.0;
static const CGFloat kMarkerButtonShadowOffsetY = 1.0;

// The loading label height and the loading label's vertical offset from the view centre.
static const CGFloat kLoadingLabelWidth = 140.0;
static const CGFloat kLoadingLabelHeight = 30.0;
static const CGFloat kLoadingLabelFontSize = 22.0;
static const CGFloat kLoadingOverlayLabelOffsetY = 20.0;

@implementation MarkerSelectView {
    // The per-page scroll span (one marker banner's height). Encodes as `d`.
    double banner_span;
    // Whether the preview is paused. Encodes as `B`.
    BOOL paused;
}

#pragma mark - Initialisation

/** @ghidraAddress 0x98afc */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    self.opaque = NO;
    self.backgroundColor = UIColor.clearColor;
    JubeatTheme theme = JubeatAppDelegate.appDelegate.currentTheme;
    UIImage *bgImage = nil;
    if (theme == JubeatThemeRipples) {
        bgImage = LoadScaledPngImage(@"marker_sel_back_rpl");
    } else if (theme == JubeatThemeKnit) {
        bgImage = LoadScaledPngImage(@"marker_sel_back_knt");
    } else {
        bgImage = LoadScaledPngImage(@"marker_sel_back");
    }
    self.bgView = [[UIImageView alloc] initWithImage:bgImage];
    [self addSubview:self.bgView];

    // The preview frame, the per-page banner span, and the banner column width all switch on the
    // idiom (fcsel chain at 0x98d58-0x98da8). On iPad the preview is a 192x192 square at
    // (180, 154), the span is 100, and the column is 154 wide; on the phone the preview is an
    // 80x80 square at (100, 85), the span is 50, and the column is 77 wide. The preview height is
    // a copy of its width (`mov v3.16B,v2.16B`).
    // @ghidraAddress 0x291bd0 (180.0), 0x291bd8 (154.0), 0x28fa00 (192.0), 0x28f3f0 (100.0),
    // @ghidraAddress 0x28f760 (85.0), 0x28f3f8 (80.0), 0x28f2c8 (50.0), 0x291be0 (77.0)
    CGRect previewFrame;
    CGFloat columnWidth;
    if (isPad) {
        previewFrame = CGRectMake(180.0, 154.0, 192.0, 192.0);
        banner_span = 100.0;
        columnWidth = 154.0;
    } else {
        previewFrame = CGRectMake(100.0, 85.0, 80.0, 80.0);
        banner_span = 50.0;
        columnWidth = 77.0;
    }
    self.markerTestView = [[MarkerTestView alloc] initWithFrame:previewFrame];
    [self addSubview:self.markerTestView];

    NSArray *markerList = [NSArray arrayWithArray:[MarkerManager getCurrentMarkerList]];
    NSUInteger markerCount = markerList.count;
    self.arrayMarkerBtn = [NSMutableArray arrayWithCapacity:markerCount];

    // The banner scroll view is the width of the banner column and 1.5 points shorter than the
    // view (fmov immediate -1.5 at 0x98ee0). Its content is three tiled copies of the marker list
    // stacked vertically for the wrap-around paging effect.
    self.bannerScrollView = [[UIScrollView alloc]
        initWithFrame:CGRectMake(
                          0.0, 0.0, columnWidth, frame.size.height - kBannerScrollHeightInset)];
    [self.bannerScrollView
        setContentSize:CGSizeMake(columnWidth,
                                  banner_span * (double)markerCount * (double)kTiledCopies)];
    self.bannerScrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.bannerScrollView.opaque = NO;
    self.bannerScrollView.backgroundColor = UIColor.clearColor;
    self.bannerScrollView.showsVerticalScrollIndicator = NO;

    // The marker button size and title font size switch on the idiom: 128x40 with a 22pt title on
    // iPad, 64x40 with a 15pt title on the phone.
    // @ghidraAddress 0x28f750 (128.0), 0x28f3f8 (80.0), 0x28f1f0 (64.0), 0x28f1f8 (40.0)
    CGFloat buttonWidth = isPad ? 128.0 : 64.0;  // @ghidraAddress 0x28f750, 0x28f1f0
    CGFloat buttonHeight = isPad ? 80.0 : 40.0;  // @ghidraAddress 0x28f3f8, 0x28f1f8
    CGFloat titleFontSize = isPad ? 22.0 : 15.0; // fmov immediates at 0x99108, 0x99104
    // The title-label shadow opacity, loaded as a single-precision float (0.9f).
    float shadowOpacity = 0.9f; // @ghidraAddress 0x28f3b0
    NSUInteger index = 0;
    for (index = 0; index < markerCount; ++index) {
        NSDictionary *info = markerList[index];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(0.0, 0.0, buttonWidth, buttonHeight);
        NSString *bannerPath = [MarkerManager getMarkerBannerPath:info[kBannerNameKey]];
        [button setBackgroundImage:[UIImage imageWithContentsOfFile:bannerPath]
                          forState:UIControlStateNormal];
        [button addTarget:self
                      action:@selector(btnMarker:)
            forControlEvents:UIControlEventTouchUpInside];
        button.titleLabel.clipsToBounds = NO;
        button.titleLabel.font = [UIFont fontWithName:kMarkerButtonFontName size:titleFontSize];
        button.titleLabel.layer.shadowRadius = kMarkerButtonShadowRadius;
        button.titleLabel.layer.shadowOpacity = shadowOpacity;
        button.titleLabel.layer.shadowOffset = CGSizeMake(0.0, kMarkerButtonShadowOffsetY);
        [button setTitle:@"" forState:UIControlStateNormal];
        [button setTitle:@"Selected" forState:UIControlStateSelected];
        button.exclusiveTouch = YES;
        [self.arrayMarkerBtn addObject:button];
        [self.bannerScrollView addSubview:button];
    }
    double placedCount = (double)(int)index;

    // Every button starts stacked at the same centre (span*count + placedCount*span + span*0.5);
    // the y term is loop-invariant in the binary, so this is the initial collapsed placement and
    // scrollViewDidScroll: fans the buttons out as the list scrolls. The x centre is read from the
    // scroll view's own frame width on each pass.
    double startBase = banner_span * (double)markerCount;
    double centerY = startBase + placedCount * banner_span + banner_span * 0.5;
    for (UIButton *button in self.arrayMarkerBtn) {
        button.center = CGPointMake(self.bannerScrollView.frame.size.width * 0.5, centerY);
    }

    self.bannerScrollView.delegate = self;
    [self addSubview:self.bannerScrollView];

    self.buttonImgView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(@"test_button_up")];
    self.buttonImgView.center = self.markerTestView.center;
    self.buttonImgView.opaque = NO;
    self.buttonImgView.backgroundColor = UIColor.clearColor;
    [self addSubview:self.buttonImgView];

    self.loadingView =
        [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, frame.size.width, frame.size.height)];
    self.loadingView.opaque = NO;
    // The loading overlay dims to 40% black. The binary uses colorWithWhite:0 alpha:0.4.
    self.loadingView.backgroundColor = [UIColor colorWithWhite:0.0
                                                         alpha:0.4]; // @ghidraAddress 0x28f2c0

    self.labelLoading = [[UILabel alloc]
        initWithFrame:CGRectMake(0.0, 0.0, kLoadingLabelWidth, kLoadingLabelHeight)];
    self.labelLoading.opaque = NO;
    self.labelLoading.backgroundColor = UIColor.clearColor;
    self.labelLoading.textColor = UIColor.whiteColor;
    self.labelLoading.font = [UIFont boldSystemFontOfSize:kLoadingLabelFontSize];
    self.labelLoading.text = [NSBundle.mainBundle localizedStringForKey:@"Loading..."
                                                                  value:@""
                                                                  table:nil];
    self.labelLoading.center =
        CGPointMake(frame.size.width * 0.5, frame.size.height * 0.5 + kLoadingOverlayLabelOffsetY);
    [self.loadingView addSubview:self.labelLoading];

    self.indicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.indicator.center =
        CGPointMake(frame.size.width * 0.5, frame.size.height * 0.5 - kLoadingOverlayLabelOffsetY);
    [self.loadingView addSubview:self.indicator];
    [self addSubview:self.loadingView];
    self.loadingView.hidden = YES;

    paused = NO;
    return self;
}

#pragma mark - Sounds

/** @ghidraAddress 0x99d30 */
- (NSString *)soundName:(NSString *)name {
    JubeatTheme theme = JubeatAppDelegate.appDelegate.currentTheme;
    if (theme == JubeatThemeRipples) {
        return [NSString stringWithFormat:@"SD_RPL_%@", name];
    }
    if (theme == JubeatThemeKnit) {
        return [NSString stringWithFormat:@"SD_KNT_%@", name];
    }
    return [NSString stringWithFormat:@"SD_%@", name];
}

#pragma mark - Current banner

/** @ghidraAddress 0x99e20 */
- (UIImage *)getCurrentBanner {
    NSString *markerID = [NSUserDefaults.standardUserDefaults objectForKey:kPrefCurrentMarkerIDKey];
    int currentIndex = [MarkerManager getMarkerIndex:markerID];
    return [self.arrayMarkerBtn[currentIndex] backgroundImageForState:UIControlStateNormal];
}

#pragma mark - Display link lifecycle

/** @ghidraAddress 0x99f20 */
- (void)loop:(CADisplayLink *)sender {
    if (!paused) {
        [self.markerTestView draw];
    }
    if (!self.buttonImgView.hidden) {
        [self.indicator stopAnimating];
        self.buttonImgView.hidden = YES;
    }
}

/** @ghidraAddress 0x9a038 */
- (void)startAnimation {
    if (self.displayLink) {
        return;
    }
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(loop:)];
    self.displayLink.frameInterval = 2;
    [self.displayLink addToRunLoop:NSRunLoop.currentRunLoop forMode:NSRunLoopCommonModes];
    [self.markerTestView reset];
}

/** @ghidraAddress 0x9a19c */
- (void)pauseAnimation {
    paused = YES;
    if (self.displayLink) {
        self.displayLink.paused = YES;
    }
}

/** @ghidraAddress 0x9a230 */
- (void)resumeAnimation {
    paused = NO;
    if (self.displayLink) {
        self.displayLink.paused = NO;
    }
}

/** @ghidraAddress 0x9a2c0 */
- (void)stopAnimation {
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

#pragma mark - Marker loading

/** @ghidraAddress 0x9a354 */
- (void)startLoadMarker:(BOOL)scroll {
    NSUInteger count = self.arrayMarkerBtn.count;
    NSString *markerID = [NSUserDefaults.standardUserDefaults objectForKey:kPrefCurrentMarkerIDKey];
    int currentIndex = [MarkerManager getMarkerIndex:markerID];
    self.arrayMarkerBtn[currentIndex].enabled = NO;
    if (scroll) {
        // Scroll the banner list so the current marker sits in the middle copy, clamped to at
        // least the middle-copy start (dVar8) so paging never drops below the wrap window.
        double base = (double)count * banner_span;
        double target = (base + (double)currentIndex * banner_span + banner_span * 0.5) -
                        self.bannerScrollView.frame.size.height * 0.5;
        if (target < base) {
            target = base;
        }
        [self.bannerScrollView setContentOffset:CGPointMake(0.0, target)];
    }
    self.markerTestView.hidden = YES;
    self.buttonImgView.hidden = NO;
    self.loadingView.hidden = NO;
    [self.indicator startAnimating];
    [self stopAnimation];
    [self.markerTestView releaseTex];
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];

    __weak MarkerSelectView *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      /** @ghidraAddress 0x9a710 */
      // Load the current marker's textures off the main thread inside its own autorelease pool,
      // then hop to the main queue to reveal the result.
      @autoreleasepool {
          NSString *loadID =
              [NSUserDefaults.standardUserDefaults objectForKey:kPrefCurrentMarkerIDKey];
          [weakSelf.markerTestView loadMarkerTex:loadID];
      }
      dispatch_async(dispatch_get_main_queue(), ^{
        /** @ghidraAddress 0x9a848 */
        // Reveal the preview once the marker actually loaded, and always re-enable input so a
        // failed load cannot leave the app unresponsive.
        if (weakSelf.markerTestView.currentMarker) {
            weakSelf.markerTestView.hidden = NO;
            weakSelf.loadingView.hidden = YES;
            [weakSelf startAnimation];
        }
        [UIApplication.sharedApplication endIgnoringInteractionEvents];
      });
    });
}

#pragma mark - Selection

/** @ghidraAddress 0x9a9c8 */
- (void)btnMarker:(UIButton *)sender {
    NSUInteger count = self.arrayMarkerBtn.count;
    int selectedIndex = 0;
    for (NSUInteger i = 0; i < count; ++i) {
        UIButton *button = self.arrayMarkerBtn[i];
        if (button == sender) {
            selectedIndex = (int)i;
        }
        button.enabled = YES;
    }
    [[AudioManager sharedManager] playSeResFile:[self soundName:kMarkerSelectSoundName]
                                    inDirectory:nil];
    NSDictionary *info = [MarkerManager getMarkerInfo:selectedIndex];
    [NSUserDefaults.standardUserDefaults setObject:info[kMarkerIDKey]
                                            forKey:kPrefCurrentMarkerIDKey];
    if ([self.delegate respondsToSelector:@selector(markerSelectChanged:)]) {
        [self.delegate performSelector:@selector(markerSelectChanged:) withObject:self];
    }
    [self startLoadMarker:NO];
}

#pragma mark - Teardown

/** @ghidraAddress 0x9aca4 */
- (void)close {
    [self stopAnimation];
    MarkerTestView *preview = self.markerTestView;
    @synchronized(preview) {
        [self.markerTestView releaseTex];
    }
}

#pragma mark - UIScrollViewDelegate

/** @ghidraAddress 0x9ad44 */
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
}

/** @ghidraAddress 0x9ad48 */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSUInteger count = self.arrayMarkerBtn.count;
    CGPoint offset = self.bannerScrollView.contentOffset;
    double window = (double)count * banner_span;
    // Wrap the offset back into the middle tile: if it drifts above the top copy, add one window;
    // if past the bottom copy, subtract one window.
    double y = offset.y;
    if (y <= window) {
        if (window + window <= y) {
            y -= window;
            [self.bannerScrollView setContentOffset:CGPointMake(offset.x, y)];
        }
    } else {
        y += window;
        [self.bannerScrollView setContentOffset:CGPointMake(offset.x, y)];
    }

    CGRect scrollFrame = scrollView.frame;
    // The first half of the buttons re-centre from a base one window down, unless the offset is
    // still within the upper 7/4-window band, in which case they hold at the single window.
    double upperBand = window * 7.0 * 0.25;
    double base = window + window;
    if (y <= upperBand) {
        base = window;
    }
    NSUInteger half = (count >> 1) & 0x7fffffff;
    NSUInteger i = 0;
    for (i = 0; i < half; ++i) {
        UIButton *button = self.arrayMarkerBtn[i];
        button.center = CGPointMake(scrollFrame.size.width * 0.5, base + banner_span * 0.5);
        base += banner_span;
    }
    // The second half re-centre from a base pulled back by one window when the offset sits between
    // the 5/4-window and 7/4-window bands.
    if (i < count) {
        double lowerBand = window * 5.0 * 0.25;
        BOOL pullBack = YES;
        if (y <= upperBand) {
            pullBack = (y < lowerBand);
        }
        double secondBase = pullBack ? base - window : base;
        for (; i < count; ++i) {
            UIButton *button = self.arrayMarkerBtn[i];
            button.center =
                CGPointMake(scrollFrame.size.width * 0.5, secondBase + banner_span * 0.5);
            secondBase += banner_span;
        }
    }
}

/** @ghidraAddress 0x9b04c */
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
}

/** @ghidraAddress 0x9b050 */
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
}

#pragma mark - List rebuild

/** @ghidraAddress 0x9b0a4 */
- (void)updateMarkerList {
    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    CGRect oldFrame = self.bannerScrollView.frame;
    [self.bannerScrollView removeFromSuperview];
    self.bannerScrollView = nil;

    NSArray *markerList = [NSArray arrayWithArray:[MarkerManager getCurrentMarkerList]];
    NSUInteger markerCount = markerList.count;
    double contentBase = (double)markerCount * banner_span;
    self.arrayMarkerBtn = [NSMutableArray arrayWithCapacity:markerCount];

    self.bannerScrollView = [[UIScrollView alloc] initWithFrame:oldFrame];
    [self.bannerScrollView
        setContentSize:CGSizeMake(oldFrame.size.width, contentBase * (double)kTiledCopies)];
    self.bannerScrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.bannerScrollView.opaque = NO;
    self.bannerScrollView.backgroundColor = UIColor.clearColor;
    self.bannerScrollView.showsVerticalScrollIndicator = NO;

    CGFloat buttonWidth = isPad ? 128.0 : 64.0;  // @ghidraAddress 0x28f750, 0x28f1f0
    CGFloat buttonHeight = isPad ? 80.0 : 40.0;  // @ghidraAddress 0x28f3f8, 0x28f1f8
    CGFloat titleFontSize = isPad ? 22.0 : 15.0; // fmov immediates at 0x9b490, 0x9b48c
    float shadowOpacity = 0.9f;                  // @ghidraAddress 0x28f3b0
    NSUInteger index = 0;
    for (index = 0; index < markerCount; ++index) {
        NSDictionary *info = markerList[index];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(0.0, 0.0, buttonWidth, buttonHeight);
        NSString *bannerPath = [MarkerManager getMarkerBannerPath:info[kBannerNameKey]];
        [button setBackgroundImage:[UIImage imageWithContentsOfFile:bannerPath]
                          forState:UIControlStateNormal];
        [button addTarget:self
                      action:@selector(btnMarker:)
            forControlEvents:UIControlEventTouchUpInside];
        button.titleLabel.clipsToBounds = NO;
        button.titleLabel.font = [UIFont fontWithName:kMarkerButtonFontName size:titleFontSize];
        button.titleLabel.layer.shadowRadius = kMarkerButtonShadowRadius;
        button.titleLabel.layer.shadowOpacity = shadowOpacity;
        button.titleLabel.layer.shadowOffset = CGSizeMake(0.0, kMarkerButtonShadowOffsetY);
        [button setTitle:@"" forState:UIControlStateNormal];
        [button setTitle:@"Selected" forState:UIControlStateSelected];
        button.exclusiveTouch = YES;
        [self.arrayMarkerBtn addObject:button];
        [self.bannerScrollView addSubview:button];
    }
    double placedCount = (double)(int)index;

    double centerY = contentBase + placedCount * banner_span + banner_span * 0.5;
    for (UIButton *button in self.arrayMarkerBtn) {
        button.center = CGPointMake(self.bannerScrollView.frame.size.width * 0.5, centerY);
    }

    self.bannerScrollView.delegate = self;
    [self addSubview:self.bannerScrollView];
}

#pragma mark - dealloc

/** @ghidraAddress 0x9b054 */
- (void)dealloc {
    [self stopAnimation];
}

@end
