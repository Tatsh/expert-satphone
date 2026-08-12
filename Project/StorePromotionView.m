#import "StorePromotionView.h"

#import "AudioManager.h"
#import "BannerView.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "PagingScrollView.h"
#import "StorePromotion.h"

// The user-defaults key recording that sample playback is switched off.
static NSString *const kSamplePlayOffKey = @"PrefStoreSamplePlayOff";

// The banner-background image (iPad only) and the two sample-toggle button images.
static NSString *const kBannerBgImageName = @"store_sample_bg_1";
static NSString *const kSampleButtonOnImageName = @"store_sample_bg_2";
static NSString *const kSampleButtonOffImageName = @"store_sample_bg_3";

// The HTTP header the thumbnail download tags with the application's user agent.
static NSString *const kUserAgentHeaderField = @"User-Agent";

// The auto-advance interval, in seconds (fmov immediate at 0x1bc340).
static const NSTimeInterval kBannerTimerInterval = 7.0;

// The thumbnail cache holds at most this many downloaded clips.
static const NSUInteger kThumbnailCacheCountLimit = 16;

// The synchronous thumbnail-download request timeout, in seconds (fmov immediate at 0x1bd038).
static const NSTimeInterval kDownloadTimeout = 10.0;

// The audio-manager fade time when starting or stopping a sample, and the dimmed track-label
// alpha, are the same constant. @ghidraAddress 0x28f2c0
static const double kSampleFadeTime = 0.4;
static const CGFloat kDisabledLabelAlpha = 0.4;

// The banner height as a fraction of its width (float in the pool). @ghidraAddress 0x293c88
static const float kBannerHeightRatio = 0.3287671f;

// The iPhone sample-button x is inset from the frame's right by this multiple of the button image
// width (a negative factor). @ghidraAddress 0x293c80
static const double kPhoneSampleButtonXFactor = -1.2;

// The banner-background image's y, placing it partly above the view. @ghidraAddress 0x292938
static const CGFloat kBannerBgY = -32.0;

// The banner corner radius by idiom (fmov immediates at 0x1bbad0 pad, 0x1bbbb0 phone).
static const CGFloat kBannerCornerRadiusPad = 8.0;
static const CGFloat kBannerCornerRadiusPhone = 4.0;

// The banner shadow, applied to the shadow container's layer. Offset and radius are fmov
// immediates (0x1bbaf8, 0x1bbc90); the opacity is a float in the pool. @ghidraAddress 0x28f3c0
static const CGFloat kShadowOffsetHeight = 1.0;
static const float kShadowOpacity = 0.8f;
static const CGFloat kShadowRadius = 1.0;

// The horizontal page inset either side of the scroll view. Pad value is a pool double, phone
// value an fmov immediate at 0x1bb710. @ghidraAddress 0x28f790
static const CGFloat kPageOffsetXPad = 150.0;
static const CGFloat kPageOffsetXPhone = 20.0;

// The height taken off the bottom of the frame for the shadow container. Pad value is a pool
// double, phone value an fmov immediate at 0x1bb59c. @ghidraAddress 0x28f648
static const CGFloat kShadowInsetBottomPad = 34.0;
static const CGFloat kShadowInsetBottomPhone = 22.0;

// Each banner's y within the strip (fmov immediates at 0x1bb71c).
static const CGFloat kBannerYPad = 18.0;
static const CGFloat kBannerYPhone = 7.0;

// The horizontal inset of the first banner, halved either side of a page (fmov at 0x1bb728).
static const CGFloat kBannerInsetXPad = 20.0;
static const CGFloat kBannerInsetXPhone = 10.0;

// The track-label width by idiom (adjacent pool doubles). @ghidraAddress 0x293c98 (pad),
// 0x293c90 (phone)
static const CGFloat kLabelWidthPad = 234.0;
static const CGFloat kLabelWidthPhone = 240.0;

// The track-label height metric by idiom, also driving the font size (metric minus six). The
// values are w-register immediates at 0x1bbefc/0x1bbf00.
static const CGFloat kLabelHeightPad = 22.0;
static const CGFloat kLabelHeightPhone = 18.0;
static const CGFloat kLabelHeightFontDelta = 6.0;
static const CGFloat kLabelBottomGap = 1.0;

// The iPad sample-button origin, used as-is on iPad. @ghidraAddress 0x2924e8 (x), 0x28f5d8 (y)
static const CGFloat kSampleButtonPadX = 590.0;
static const CGFloat kSampleButtonPadY = 170.0;

@implementation StorePromotionView {
    NSUInteger currentIndex;
    __weak NSTimer *bannerTimer;
    BOOL paused;
    NSMutableArray *arrayBannerView;
    PagingScrollView *scrollView;
    double pageWidth;
    double pageOffsetX;
    NSURLSession *session;
    UIView *shadowView;
    BOOL bEnableThumbnailPlay;
    BOOL bThumbnailPlaying;
    BOOL bIsSoundPlaying;
    NSString *currentThumbNail;
    NSString *reserveThumbNail;
    NSCache *thumbCache;
    NSOperationQueue *operationThumbQueue;
    NSMutableArray *downloadingThumbList;
    UILabel *musicNameLabel;
    UIImageView *bannerBgView;
    UIButton *sampleButton;
    UIImage *sampleButtonImageON;
    UIImage *sampleButtonImageOFF;
}

#pragma mark - Initialisation

/** @ghidraAddress 0x1bb4a8 */
- (instancetype)initWithFrame:(CGRect)frame promotions:(NSArray *)promotions {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    const CGFloat width = frame.size.width;
    const CGFloat height = frame.size.height;
    const BOOL isPad = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
    self.multipleTouchEnabled = NO;

    const CGFloat shadowInsetBottom = isPad ? kShadowInsetBottomPad : kShadowInsetBottomPhone;
    if (isPad) {
        UIImage *bgImage = LoadScaledPngImage(kBannerBgImageName);
        bannerBgView =
            [[UIImageView alloc] initWithFrame:CGRectMake((width - bgImage.size.width) * 0.5,
                                                          kBannerBgY,
                                                          bgImage.size.width,
                                                          bgImage.size.height)];
        bannerBgView.image = bgImage;
        [self addSubview:bannerBgView];
    }

    shadowView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height - shadowInsetBottom)];
    [self addSubview:shadowView];

    pageOffsetX = isPad ? kPageOffsetXPad : kPageOffsetXPhone;
    pageWidth = width - pageOffsetX * 2.0;
    const CGFloat bannerY = isPad ? kBannerYPad : kBannerYPhone;
    CGFloat bannerX = isPad ? kBannerInsetXPad : kBannerInsetXPhone;

    scrollView = [[PagingScrollView alloc]
        initWithFrame:CGRectMake(pageOffsetX, 0, pageWidth, shadowView.frame.size.height)];
    scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.delegate = self;
    scrollView.pagingEnabled = YES;
    scrollView.clipsToBounds = NO;
    [shadowView addSubview:scrollView];
    currentIndex = 0;

    // A single promotion is duplicated so the wrap-around strip always has two neighbours.
    if (promotions.count == 1) {
        promotions = @[ promotions[0], promotions[0] ];
    }

    arrayBannerView = [[NSMutableArray alloc] initWithCapacity:promotions.count + 2];
    const int bannerWidth = (int)(pageWidth - (bannerX + bannerX));
    const CGFloat bannerHeight = (CGFloat)((float)bannerWidth * kBannerHeightRatio);
    const CGFloat bannerCornerRadius = isPad ? kBannerCornerRadiusPad : kBannerCornerRadiusPhone;
    for (NSUInteger i = 0; i < promotions.count + 2; ++i) {
        BannerView *banner = [[BannerView alloc]
            initWithFrame:CGRectMake(bannerX, bannerY, (double)bannerWidth, bannerHeight)];
        const NSUInteger count = promotions.count;
        NSUInteger index = i;
        if (count != 0) {
            index = i % count;
        }
        banner.promotion = promotions[index];
        [banner setCornerRadius:bannerCornerRadius];
        // The shadow is (re)applied to the container each iteration, matching the binary.
        shadowView.layer.shadowOffset = CGSizeMake(0, kShadowOffsetHeight);
        shadowView.layer.shadowColor = UIColor.blackColor.CGColor;
        shadowView.layer.shadowOpacity = kShadowOpacity;
        shadowView.layer.shadowRadius = kShadowRadius;
        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bannerTapped:)];
        [banner addGestureRecognizer:tap];
        [scrollView addSubview:banner];
        [arrayBannerView addObject:banner];
        bannerX += pageWidth;
    }

    scrollView.contentSize =
        CGSizeMake(pageWidth * (double)arrayBannerView.count, shadowView.frame.size.height);
    [scrollView setContentOffset:CGPointMake(pageWidth, 0) animated:NO];

    session = [NSURLSession
        sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
    bEnableThumbnailPlay = ![NSUserDefaults.standardUserDefaults boolForKey:kSamplePlayOffKey];
    bThumbnailPlaying = bEnableThumbnailPlay;

    thumbCache = [[NSCache alloc] init];
    thumbCache.countLimit = kThumbnailCacheCountLimit;
    operationThumbQueue = [[NSOperationQueue alloc] init];
    downloadingThumbList = [[NSMutableArray alloc] init];

    const CGFloat labelWidth = isPad ? kLabelWidthPad : kLabelWidthPhone;
    const CGFloat labelHeight = isPad ? kLabelHeightPad : kLabelHeightPhone;
    musicNameLabel =
        [[UILabel alloc] initWithFrame:CGRectMake((width - labelWidth) * 0.5,
                                                  height - labelHeight - kLabelBottomGap,
                                                  labelWidth,
                                                  labelHeight)];
    musicNameLabel.font = [UIFont systemFontOfSize:labelHeight - kLabelHeightFontDelta];
    musicNameLabel.text = @"";
    musicNameLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:musicNameLabel];

    sampleButtonImageON = LoadScaledPngImage(kSampleButtonOnImageName);
    sampleButtonImageOFF = LoadScaledPngImage(kSampleButtonOffImageName);
    LoadScaledPngImage(kSampleButtonOnImageName); // Yes, the binary loads and discards this.

    CGFloat sampleX = kSampleButtonPadX;
    CGFloat sampleY = kSampleButtonPadY;
    if (!isPad) {
        sampleX =
            (CGFloat)(int)(width + sampleButtonImageON.size.width * kPhoneSampleButtonXFactor);
        sampleY = (CGFloat)(int)(height - sampleButtonImageON.size.height);
    }
    sampleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    sampleButton.frame = CGRectMake(
        sampleX, sampleY, sampleButtonImageON.size.width, sampleButtonImageON.size.height);
    [sampleButton addTarget:self
                     action:@selector(tapSampleBtn:)
           forControlEvents:UIControlEventTouchUpInside];
    sampleButton.exclusiveTouch = YES;
    [self setSampleButtonImage];
    [self addSubview:sampleButton];

    return self;
}

/** @ghidraAddress 0x1bcad4 */
- (void)dealloc {
    [self stop];
    [self clearThumbnailCache];
}

#pragma mark - Hit testing

/** @ghidraAddress 0x1bc294 */
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self) {
        return scrollView;
    }
    return hit;
}

#pragma mark - Loop control

/** @ghidraAddress 0x1bc314 */
- (void)beginLoop {
    NSTimer *timer = [NSTimer timerWithTimeInterval:kBannerTimerInterval
                                             target:self
                                           selector:@selector(nextBanner)
                                           userInfo:nil
                                            repeats:YES];
    bannerTimer = timer;
    [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
    const double offsetX = scrollView.contentOffset.x;
    [self playBannerThumbnail:(int)((offsetX + pageWidth - 1.0) / pageWidth)];
}

/** @ghidraAddress 0x1bc418 */
- (void)start {
    for (BannerView *banner in arrayBannerView) {
        [banner loadImageWithSession:session];
    }
    [self beginLoop];
}

/** @ghidraAddress 0x1bc55c */
- (void)pause {
    if (paused) {
        return;
    }
    paused = YES;
    reserveThumbNail = nil;
    [bannerTimer invalidate];
    bannerTimer = nil;
    [self stopThumbnail];
}

/** @ghidraAddress 0x1bc600 */
- (void)resume {
    if (paused) {
        paused = NO;
        [self beginLoop];
    }
}

/** @ghidraAddress 0x1bc624 */
- (void)stop {
    [bannerTimer invalidate];
    bannerTimer = nil;
    [self thumbnailMute:NO];
}

/** @ghidraAddress 0x1bc690 */
- (void)nextBanner {
    const double offsetX = scrollView.contentOffset.x;
    const int index = (int)(offsetX / pageWidth) + 1;
    [scrollView setContentOffset:CGPointMake(pageWidth * (double)index, 0) animated:YES];
    [self playBannerThumbnail:index];
}

#pragma mark - Actions

/** @ghidraAddress 0x1bc710 */
- (void)bannerTapped:(UITapGestureRecognizer *)recognizer {
    BannerView *banner = (BannerView *)recognizer.view;
    StorePromotion *promotion = banner.promotion;
    if (promotion.packInfo) {
        if ([self.delegate respondsToSelector:@selector(storePromotionView:packSelected:)]) {
            [self.delegate storePromotionView:self packSelected:promotion.packInfo];
        }
    } else if (promotion.genreIndex != 0) {
        if ([self.delegate respondsToSelector:@selector(storePromotionView:genreSelected:)]) {
            [self.delegate storePromotionView:self genreSelected:promotion.genreIndex];
        }
    }
}

/** @ghidraAddress 0x1bc8b8 */
- (void)tapSampleBtn:(id)sender {
    const BOOL wasEnabled = bEnableThumbnailPlay;
    bEnableThumbnailPlay = !wasEnabled;
    [self thumbnailMute:!wasEnabled];
    [NSUserDefaults.standardUserDefaults setBool:!bEnableThumbnailPlay forKey:kSamplePlayOffKey];
    [NSUserDefaults.standardUserDefaults synchronize];
    [self setSampleButtonImage];
}

/** @ghidraAddress 0x1bc204 */
- (void)setSampleButtonImage {
    if (bEnableThumbnailPlay) {
        musicNameLabel.alpha = 1.0;
        [sampleButton setImage:sampleButtonImageON forState:UIControlStateNormal];
    } else {
        musicNameLabel.alpha = kDisabledLabelAlpha;
        [sampleButton setImage:sampleButtonImageOFF forState:UIControlStateNormal];
    }
}

#pragma mark - UIScrollViewDelegate

/** @ghidraAddress 0x1bc990 */
- (void)scrollViewWillBeginDragging:(UIScrollView *)aScrollView {
    if (paused) {
        return;
    }
    [bannerTimer invalidate];
    bannerTimer = nil;
}

/** @ghidraAddress 0x1bc9f0 */
- (void)scrollViewDidScroll:(UIScrollView *)aScrollView {
    const CGPoint offset = scrollView.contentOffset;
    const double span = (double)(arrayBannerView.count - 2) * pageWidth;
    const double halfPage = pageWidth * 0.5;
    double newX;
    if (offset.x >= halfPage) {
        if (offset.x < span + halfPage) {
            return;
        }
        newX = offset.x - span;
    } else {
        newX = offset.x + span;
    }
    scrollView.contentOffset = CGPointMake(newX, offset.y);
}

/** @ghidraAddress 0x1bcaac */
- (void)scrollViewDidEndDragging:(UIScrollView *)aScrollView willDecelerate:(BOOL)decelerate {
}

/** @ghidraAddress 0x1bcab0 */
- (void)scrollViewWillBeginDecelerating:(UIScrollView *)aScrollView {
}

/** @ghidraAddress 0x1bcab4 */
- (void)scrollViewDidEndDecelerating:(UIScrollView *)aScrollView {
    if (paused) {
        return;
    }
    [self beginLoop];
}

#pragma mark - Thumbnail playback

/** @ghidraAddress 0x1bcb34 */
- (void)playBannerThumbnail:(int)index {
    BannerView *banner = arrayBannerView[(NSUInteger)index];
    NSString *name = banner.promotion.getSampleName;
    if (name) {
        musicNameLabel.text = name;
    }
    if (bEnableThumbnailPlay) {
        if (banner) {
            NSData *data = [self getThumbnailData:banner.promotion];
            if (data) {
                [self playThumbnail:name data:data];
                reserveThumbNail = nil;
                return;
            }
        }
        reserveThumbNail = name;
    }
}

/** @ghidraAddress 0x1bcc98 */
- (void)thumbnailMute:(BOOL)mute {
    const BOOL shouldPlay = bEnableThumbnailPlay && mute;
    if (bThumbnailPlaying == shouldPlay) {
        return;
    }
    bThumbnailPlaying = shouldPlay;
    if (shouldPlay) {
        const double offsetX = scrollView.contentOffset.x;
        [self playBannerThumbnail:(int)(offsetX / pageWidth)];
    } else {
        [self stopThumbnail];
    }
}

/** @ghidraAddress 0x1bcd48 */
- (NSData *)getThumbnailData:(StorePromotion *)promotion {
    NSString *name = promotion.getSampleName;
    if (!name) {
        return nil;
    }
    NSString *urlString = promotion.getSampleURL;
    NSData *data = [thumbCache objectForKey:name];
    if (!data) {
        const NSUInteger existing = [downloadingThumbList indexOfObject:name];
        if (urlString && existing == NSNotFound) {
            NSURL *url = [NSURL URLWithString:urlString];
            if (url) {
                NSInvocationOperation *operation =
                    [[NSInvocationOperation alloc] initWithTarget:self
                                                         selector:@selector(downloadImageSync:)
                                                           object:@[ url, name ]];
                [downloadingThumbList addObject:name];
                [operationThumbQueue addOperation:operation];
            }
        }
    }
    return data;
}

/** @ghidraAddress 0x1bcf54 */
- (void)clearThumbnailCache {
    [thumbCache removeAllObjects];
    [operationThumbQueue cancelAllOperations];
    [downloadingThumbList removeAllObjects];
}

/** @ghidraAddress 0x1bcfb4 */
- (void)downloadImageSync:(NSArray *)args {
    @autoreleasepool {
        NSURL *url = args[0];
        NSString *key = args[1];
        NSMutableURLRequest *request =
            [NSMutableURLRequest requestWithURL:url
                                    cachePolicy:NSURLRequestUseProtocolCachePolicy
                                timeoutInterval:kDownloadTimeout];
        [request setValue:JubeatAppDelegate.appDelegate.userAgent
            forHTTPHeaderField:kUserAgentHeaderField];
        // The synchronous download deliberately uses the shared session, not this view's own
        // session; the latter is only used for the banner artwork.
        NSURLSessionDataTask *task = [NSURLSession.sharedSession
            dataTaskWithRequest:request
              completionHandler:^(NSData *data,
                                  NSURLResponse *__attribute__((unused)) response,
                                  NSError *__attribute__((unused)) error) {
                /** @ghidraAddress 0x1bd1b4 */
                if (data) {
                    [thumbCache setObject:data forKey:key];
                    dispatch_async(dispatch_get_main_queue(), ^{
                      /** @ghidraAddress 0x1bd274 */
                      NSData *cached = [thumbCache objectForKey:key];
                      if (cached && [key isEqualToString:reserveThumbNail]) {
                          reserveThumbNail = nil;
                          [self playThumbnail:key data:cached];
                      }
                      [downloadingThumbList removeObject:key];
                    });
                }
              }];
        [task resume];
    }
}

/** @ghidraAddress 0x1bd3c8 */
- (void)playThumbnail:(NSString *)name data:(NSData *)data {
    if (bThumbnailPlaying && name && data) {
        if (![currentThumbNail isEqualToString:name]) {
            bIsSoundPlaying = YES;
            [AudioManager.sharedManager fadeoutBgm:kSampleFadeTime];
            [AudioManager.sharedManager loadBgmData:data];
            [AudioManager.sharedManager startBgm:NO fadeTime:kSampleFadeTime];
            currentThumbNail = name;
        }
    }
}

/** @ghidraAddress 0x1bd534 */
- (void)stopThumbnail {
    if (bIsSoundPlaying) {
        currentThumbNail = nil;
        reserveThumbNail = nil;
        [AudioManager.sharedManager fadeoutBgm:kSampleFadeTime];
        bIsSoundPlaying = NO;
    }
}

@end
