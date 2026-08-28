#import "SettingsTwSelectViewController.h"

#import "AlertViewManager.h"
#import "EditorIDManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "ResultTweet.h"
#import "RewardCheck.h"
#import "SettingsRewardViewController.h"
#import "TweetResourceManager.h"
#import "UIDevice+SystemVersionCheck.h"

// A frame row is a positional array; only element 1 (its identifier / file name) is read here.
static const NSUInteger kFrameRowIdentifierIndex = 1;

// The keys of a TweetResourceManager catalogue entry read while building the working table.
static NSString *const kResourceItemTypeKey = @"itemType";     // 0x2d4720
static NSString *const kResourceTermTypeKey = @"termType";     // 0x2d8220
static NSString *const kResourceFileNameKey = @"fileName";     // 0x2d71e0
static NSString *const kResourceTermsTableKey = @"termsTable"; // 0x2d47a0

// The itemType value that marks a frame the gallery lists (zero), and the termType values it
// accepts (0 or 1, i.e. (termType | 1) == 1).
static const int kFrameItemType = 0;

// The user-defaults key holding the currently selected Twitter frame identifier.
static NSString *const kSelectedFrameDefaultsKey = @"PrefTwitterBgFrame"; // 0x2d4480

// The empty accessory identifier passed while composing each page (the CFString wrapping "").
static NSString *const kInitialAccessoryIdentifier = @""; // 0x2d42e0

// The navigation title, from the CFString at 0x2d8460.
static NSString *const kNavigationTitle = @"TWITTER CUSTOMIZE";

// The header label text, from the UTF-16 CFString at 0x2d8500.
static NSString *const kHeaderLabelText = @"Twitter投稿用";

// The minimum system version guarding the page-control tint colours.
static NSString *const kPageControlTintVersion = @"6.0"; // 0x2d8520

// The gallery image base names, chosen by device.
static NSString *const kBackgroundImageName = @"tw_setting_bg";               // 0x2d8480
static NSString *const kBackgroundImageName4Inch = @"tw_setting_bg_4inch";    // 0x2d84a0
static NSString *const kBackgroundImageName6 = @"tw_setting_bg_6";            // 0x2d84c0
static NSString *const kBackgroundImageName6Plus = @"tw_setting_bg_6p";       // 0x2d84e0
static NSString *const kSelectionMarkerImageName = @"tw_setting_frame";       // 0x2d8560
static NSString *const kScrollArrowLeftImageName = @"btn_edit_scroll_l_knt";  // 0x2d8540
static NSString *const kScrollArrowRightImageName = @"btn_edit_scroll_r_knt"; // 0x2d6b40

// The number of gallery pages, selection markers, and scroll arrows.
static const int kPageCount = 4;
static const int kMarkerCount = 4;

// The scale applied on iPad: the layout is shown at its native size.
static const float kPadScale = 1.0f; // fmov immediate at 0x7bf5c (0x3f800000).

// The reference width the phone scale divides the screen width by.
static const CGFloat kScaleReferenceWidth = 540.0; // @ghidraAddress 0x28f900

// The half-window width used to anchor the page control, on iPad and on phones.
static const CGFloat kPadHalfWindowWidth = 270.0; // @ghidraAddress 0x28f2d8
static const CGFloat kHalfMultiplier = 0.5;       // fmov immediate at 0x7bfc4 (0.5).

// The unscaled per-page frame-sample rect size {520, 365.9259}.
static const CGFloat kFrameSampleWidth = 520.0;              // @ghidraAddress 0x28f920
static const CGFloat kFrameSampleHeight = 365.9259338378906; // @ghidraAddress 0x28f928

// The unscaled accessory rect, composited over each frame sample: {21.185, 21.185, 125.185,
// 125.185}.
static const CGFloat kAccessoryOrigin = 21.1851863861084; // @ghidraAddress 0x28f930
static const CGFloat kAccessorySize = 125.18518829345703; // @ghidraAddress 0x28f938

static const CGFloat kContentPageWidth = 540.0;  // low half of @ghidraAddress 0x28f960
static const CGFloat kContentPageHeight = 380.0; // low half of @ghidraAddress 0x28f964
static const CGFloat kPageHeight = 380.0;        // @ghidraAddress 0x28f918
static const CGFloat kFrameCenterHeight = 380.0; // low half of @ghidraAddress 0x28f964

// The header label / scrollView top: the same three-way branch by idiom (pad, four-inch phone,
// other phone). The binary reuses one value (register d10) for the header base and the scroll top.
static const CGFloat kHeaderBase4Inch = 124.0; // @ghidraAddress 0x28f6b8
static const CGFloat kHeaderBase = 94.0;       // @ghidraAddress 0x28f420
static const CGFloat kHeaderBasePad = 70.0;    // @ghidraAddress 0x28f6a0
static const CGFloat kHeaderWidth = 96.0;      // @ghidraAddress 0x28f908
static const int kHeaderFontSizePad = 20;      // mov immediate at 0x7c200 (0x14).
static const int kHeaderFontSize = 12;         // orr immediate at 0x7c1fc (0xc).
static const CGFloat kHeaderX = 10.0;          // fmov immediate at 0x7c250 (0x4024000000000000).
static const int kHeaderHeightPadding = 4;     // add immediate at 0x7c208.
static const CGFloat kHeaderWidthPad = 146.0;  // @ghidraAddress 0x28f910

// The reward-check button's square side, per idiom.
static const CGFloat kRewardButtonSidePad = 120.0; // @ghidraAddress 0x28f210
static const CGFloat kRewardButtonSide = 100.0;    // @ghidraAddress 0x28f3f0

// The page-control frame components, per idiom and four-inch aspect.
static const CGFloat kPageControlYPad = 434.0;     // @ghidraAddress 0x28f958
static const CGFloat kPageControlY4Inch = 344.0;   // @ghidraAddress 0x28f948
static const CGFloat kPageControlY = 314.0;        // @ghidraAddress 0x28f940
static const CGFloat kPageControlXInsetPad = 86.0; // @ghidraAddress 0x28f950
static const CGFloat kPageControlXInset = 56.0;    // @ghidraAddress 0x28f878
static const int kPageControlXBiasPad = 36;        // mov immediate at 0x7cb0c (0x24).
static const int kPageControlXBias = 26;           // mov immediate at 0x7cb08 (0x1a).
static const CGFloat kPageControlWidthPad = 100.0; // @ghidraAddress 0x28f3f0
static const CGFloat kPageControlWidth = 60.0;     // @ghidraAddress 0x28f258
static const CGFloat kPageControlHeightPad = 66.0; // @ghidraAddress 0x28f638
static const CGFloat kPageControlHeight = 40.0;    // @ghidraAddress 0x28f1f8

// The scroll-arrow size, and the horizontal step between the two arrows.
static const CGFloat kArrowSizePad = 32.0; // @ghidraAddress 0x28f458
static const CGFloat kArrowSize = 24.0;    // fmov immediate at 0x7ccc8 (0x4038000000000000).
static const int kArrowStepPad = 140;      // mov immediate at 0x7cd18 (0x8c).
static const int kArrowStep = 88;          // mov immediate at 0x7cd14 (0x58).

// The selection-marker angular geometry: a 90-degree unit split over 180, times pi.
static const float kMarkerAngleUnit = 90.0f;     // low half of @ghidraAddress 0x28f968
static const float kMarkerAngleDivisor = 180.0f; // low half of @ghidraAddress 0x28f538
// The marker base is inset one point inside the sample corner, and each marker steps a sample-span
// plus eight points minus the marker's own size.
static const CGFloat kMarkerBaseInset = 1.0; // fmov immediate at 0x7caa0 (-1.0).
static const CGFloat kMarkerSpanGap = 8.0;   // fmov immediate at 0x7caa8 (8.0).

// The selection-cursor alpha and translation constants used by -scrollCursorControll.
static const float kMarkerCursorAlphaScale = 2.0999999046325684f;        // @ghidraAddress 0x28f96c
static const float kMarkerCursorSettleThreshold = 0.009999999776482582f; // @ghidraAddress 0x28f970
static const float kMarkerCursorTranslation = 10.0f; // fmov immediate at 0x7d2a0 (0x41200000).

// The fade-in animation duration for -itemDisp:.
static const NSTimeInterval kFadeInDuration = 0.2; // @ghidraAddress 0x28e040

@implementation SettingsTwSelectViewController {
    UIImageView *frameImage;                // +0x8
    UIImageView *accImage;                  // +0x10
    UIImageView *selFrameImgTable[4];       // +0x18
    UIImageView *selFrameLockImgTable[4];   // +0x38
    NSMutableArray *frameTable;             // +0x58
    UIScrollView *scrollView;               // +0x60
    UIPageControl *pageCtrl;                // +0x68
    NSMutableArray *frameImgTable;          // +0x70
    NSMutableArray *accImgTable;            // +0x78
    NSMutableArray *lockViewTable;          // +0x80
    NSMutableArray *scrlBtn;                // +0x88
    UIButton *scrlArrow[2];                 // +0x90
    int windowWidth;                        // +0xa0
    float fScale;                           // +0xa4
    int itemPage;                           // +0xa8
    UIActivityIndicatorView *indicatorView; // +0xb0
    EditorIDManager *idManager;             // +0xb8
}

#pragma mark - Construction

/** @ghidraAddress 0x7b890 */
- (instancetype)init {
    self = [super init];
    if (self) {
        self.navigationItem.title = kNavigationTitle;
        // Build the working table from the frame catalogue: every selectable frame (itemType zero,
        // termType 0 or 1) becomes a row of {sequentialIndex, fileName, termType, termsTable}.
        NSArray *resourceList = [TweetResourceManager.sharedManager getResourceList];
        NSMutableArray *rows = [[NSMutableArray alloc] init];
        int rowIndex = 0;
        for (NSDictionary *entry in resourceList) {
            int itemType = [entry[kResourceItemTypeKey] intValue];
            int termType = [entry[kResourceTermTypeKey] intValue];
            if (itemType == kFrameItemType && ((unsigned int)termType | 1) == 1) {
                NSArray *row = @[
                    @(rowIndex),
                    entry[kResourceFileNameKey],
                    entry[kResourceTermTypeKey],
                    entry[kResourceTermsTableKey]
                ];
                [rows addObject:row];
                ++rowIndex;
            }
        }
        frameTable = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < rows.count; ++i) {
            [frameTable addObject:[NSMutableArray arrayWithArray:rows[i]]];
        }
        NSString *stored =
            [NSUserDefaults.standardUserDefaults objectForKey:kSelectedFrameDefaultsKey];
        itemPage = 0;
        if (stored) {
            // Start on the page of the stored frame, taken from element 0 of its matched row.
            itemPage = [[self getSelectedFrame][0] intValue];
        } else {
            // No stored frame: seed the default with the first row's identifier (element 1).
            [NSUserDefaults.standardUserDefaults setObject:frameTable[0][kFrameRowIdentifierIndex]
                                                    forKey:kSelectedFrameDefaultsKey];
        }
    }
    return self;
}

#pragma mark - Geometry

/** @ghidraAddress 0x7b86c */
- (CGRect)makeRect:(CGRect)rect {
    CGFloat scale = fScale;
    return CGRectMake(rect.origin.x * scale,
                      rect.origin.y * scale,
                      rect.size.width * scale,
                      rect.size.height * scale);
}

#pragma mark - View lifecycle

/** @ghidraAddress 0x7be5c */
- (void)loadView {
    [super loadView];

    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    BOOL is4Inch = JubeatAppDelegate.appDelegate.is4inchAspect;
    JubeatDeviceType deviceType = JubeatAppDelegate.appDelegate.deviceType;

    CGFloat halfWindowWidth;
    if (isPad) {
        fScale = kPadScale;
        halfWindowWidth = kPadHalfWindowWidth;
    } else {
        CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
        fScale = (float)(screenWidth / kScaleReferenceWidth);
        halfWindowWidth = screenWidth * kHalfMultiplier;
    }

    // The navigation bar frame is fetched only for effect; the result is discarded.
    (void)self.navigationController.navigationBar.frame; // Yes, the binary discards this.

    // The background image is chosen by device idiom, then by device type.
    UIImage *backgroundImage = LoadScaledPngImage(kBackgroundImageName);
    if (is4Inch) {
        backgroundImage = LoadScaledPngImage(kBackgroundImageName4Inch);
    }
    if ((unsigned int)(deviceType - JubeatDeviceTypePhoneRetina47Inch) < 2) {
        backgroundImage = LoadScaledPngImage(kBackgroundImageName6);
    } else if (deviceType == JubeatDeviceTypePhoneRetinaHD) {
        backgroundImage = LoadScaledPngImage(kBackgroundImageName6Plus);
    }
    UIImageView *background = [[UIImageView alloc]
        initWithFrame:CGRectMake(0, 0, backgroundImage.size.width, backgroundImage.size.height)];
    background.opaque = NO;
    background.hidden = NO;
    background.image = backgroundImage;
    [self.view addSubview:background];

    // The header label sits over the background image.
    CGFloat headerBase = is4Inch ? kHeaderBase4Inch : kHeaderBase;
    if (isPad) {
        headerBase = kHeaderBasePad;
    }
    int fontSize = isPad ? kHeaderFontSizePad : kHeaderFontSize;
    CGFloat headerWidth = isPad ? kHeaderWidthPad : kHeaderWidth;
    int headerHeight = fontSize + kHeaderHeightPadding;
    UILabel *headerLabel = [[UILabel alloc]
        initWithFrame:CGRectMake(kHeaderX, headerBase - headerHeight, headerWidth, headerHeight)];
    headerLabel.text = kHeaderLabelText;
    headerLabel.font = [UIFont systemFontOfSize:fontSize];
    headerLabel.textColor = UIColor.whiteColor;
    headerLabel.backgroundColor = UIColor.blackColor;
    headerLabel.textAlignment = NSTextAlignmentCenter;
    [background addSubview:headerLabel];

    // The reward-check button covers the background image's bottom-right corner.
    UIButton *rewardButton = [UIButton buttonWithType:UIButtonTypeCustom];
    rewardButton.exclusiveTouch = YES;
    CGRect backgroundFrame = background.frame;
    CGFloat rewardSide = isPad ? kRewardButtonSidePad : kRewardButtonSide;
    rewardButton.frame = CGRectMake(backgroundFrame.size.width - rewardSide,
                                    backgroundFrame.size.height - rewardSide,
                                    rewardSide,
                                    rewardSide);
    [rewardButton addTarget:self
                     action:@selector(pushBtnRewardCheck:)
           forControlEvents:UIControlEventTouchUpInside];
    rewardButton.backgroundColor = UIColor.clearColor;
    [self.view addSubview:rewardButton];

    // The paged scroll view of frame samples fills the gallery band. Its top is the same three-way
    // value as the header base.
    NSInteger pageCount = frameTable.count;
    CGFloat scrollTop = headerBase;
    CGRect scrollFrame =
        [self makeRect:CGRectMake(0, scrollTop, kScaleReferenceWidth, kPageHeight)];
    scrollView = [[UIScrollView alloc] initWithFrame:scrollFrame];
    scrollView.delegate = self;
    scrollView.contentSize =
        CGSizeMake((float)pageCount * fScale * kContentPageWidth, fScale * kContentPageHeight);
    CGFloat pageWidth = scrollView.contentSize.width / (CGFloat)frameTable.count;
    int pageStep = (int)pageWidth;
    scrollView.contentOffset = CGPointMake(pageStep * itemPage, 0);
    scrollView.pagingEnabled = YES;
    scrollView.bounces = NO;
    scrollView.showsHorizontalScrollIndicator = NO;
    [self.view addSubview:scrollView];

    // The frame-sample size and its centre band, recovered from the scaled scroll frame.
    CGRect sampleRect = [self makeRect:CGRectMake(0, 0, kFrameSampleWidth, kFrameSampleHeight)];
    CGFloat sampleWidth = sampleRect.size.width;
    CGFloat sampleHeight = sampleRect.size.height;
    CGFloat halfScrollWidth = scrollView.frame.size.width * kHalfMultiplier;
    CGFloat halfSampleWidth = sampleWidth * kHalfMultiplier;
    // The binary adds the *unscaled* scroll top (the header base) to the scaled half-height here,
    // not the scaled origin, so the marker band is anchored from the unscaled value.
    CGFloat scrollMidY = scrollTop + scrollView.frame.size.height * kHalfMultiplier;
    CGFloat halfSampleHeight = sampleHeight * kHalfMultiplier;

    frameImgTable = [[NSMutableArray alloc] initWithCapacity:pageCount];
    accImgTable = [[NSMutableArray alloc] initWithCapacity:pageCount];
    lockViewTable = [[NSMutableArray alloc] initWithCapacity:pageCount];

    int sampleCenterX = pageStep / 2;
    for (NSInteger page = 0; page < pageCount; ++page) {
        NSString *fileName = frameTable[page][kFrameRowIdentifierIndex];
        UIImage *sampleImage = [ResultTweet getSampleImage:fileName];
        CGRect frame = [self makeRect:CGRectMake(0, 0, kFrameSampleWidth, kFrameSampleHeight)];
        UIImageView *sample = [[UIImageView alloc] initWithImage:sampleImage];
        sample.frame = frame;
        sample.center = CGPointMake(sampleCenterX, fScale * kFrameCenterHeight * kHalfMultiplier);
        sample.userInteractionEnabled = YES;
        [scrollView addSubview:sample];

        UIImage *accessoryImage = [ResultTweet getAccessoryImage:kInitialAccessoryIdentifier];
        CGRect accessoryFrame =
            [self makeRect:CGRectMake(
                               kAccessoryOrigin, kAccessoryOrigin, kAccessorySize, kAccessorySize)];
        UIImageView *accessory = [[UIImageView alloc] initWithImage:accessoryImage];
        accessory.frame = accessoryFrame;
        [sample addSubview:accessory];

        [frameImgTable addObject:sample];
        [accImgTable addObject:accessory];
        sampleCenterX += pageStep;
    }

    // The base corner offsets for the selection markers, one point inside the sample corners.
    CGFloat markerBaseX = (halfScrollWidth - halfSampleWidth) - kMarkerBaseInset;
    CGFloat markerBaseY = (scrollMidY - halfSampleHeight) - kMarkerBaseInset;

    // The page control.
    CGFloat pageControlY = is4Inch ? kPageControlY4Inch : kPageControlY;
    if (isPad) {
        pageControlY = kPageControlYPad;
    }
    int pageControlX =
        (isPad ? kPageControlXBiasPad : kPageControlXBias) +
        (int)(halfWindowWidth - (isPad ? kPageControlXInsetPad : kPageControlXInset));
    CGFloat pageControlWidth = isPad ? kPageControlWidthPad : kPageControlWidth;
    CGFloat pageControlHeight = isPad ? kPageControlHeightPad : kPageControlHeight;
    pageCtrl = [[UIPageControl alloc]
        initWithFrame:CGRectMake(pageControlX, pageControlY, pageControlWidth, pageControlHeight)];
    pageCtrl.numberOfPages = kPageCount;
    pageCtrl.currentPage = 0;
    pageCtrl.autoresizingMask = UIViewAutoresizingNone;
    pageCtrl.userInteractionEnabled = NO;
    if ([UIDevice.currentDevice systemVersionGreaterEqual:kPageControlTintVersion]) {
        pageCtrl.pageIndicatorTintColor = UIColor.grayColor;
        pageCtrl.currentPageIndicatorTintColor = UIColor.blackColor;
    }
    [self.view addSubview:pageCtrl];

    // The two scroll arrows flank the page control at its vertical band.
    CGFloat arrowSize = isPad ? kArrowSizePad : kArrowSize;
    int arrowX = (int)(halfWindowWidth - (isPad ? kPageControlXInsetPad : kPageControlXInset));
    int arrowStep = isPad ? kArrowStepPad : kArrowStep;
    NSString *arrowImageName = kScrollArrowLeftImageName;
    for (NSInteger i = 0; i < 2; ++i) {
        UIImage *arrowImage = LoadScaledPngImage(arrowImageName);
        UIButton *arrow = [UIButton buttonWithType:UIButtonTypeCustom];
        scrlArrow[i] = arrow;
        arrow.frame = CGRectMake(arrowX, pageControlY, arrowSize, pageControlHeight);
        arrow.tag = i;
        [arrow setImage:arrowImage forState:UIControlStateNormal];
        arrow.exclusiveTouch = YES;
        arrow.adjustsImageWhenHighlighted = YES;
        arrow.adjustsImageWhenDisabled = YES;
        [arrow addTarget:self
                      action:@selector(scrollChange:)
            forControlEvents:UIControlEventTouchUpInside];
        arrow.hidden = YES;
        [self.view addSubview:arrow];
        if (i == 1) {
            break;
        }
        arrowImageName = kScrollArrowRightImageName;
        arrowX += arrowStep;
    }
    [self scrollBtnAlphaControll];

    // The four selection markers, positioned at the sample corners and rotated per slot.
    UIImage *markerImage = LoadScaledPngImage(kSelectionMarkerImageName);
    for (NSInteger i = 0; i < kMarkerCount; ++i) {
        UIImageView *marker = [[UIImageView alloc] initWithImage:markerImage];
        selFrameImgTable[i] = marker;
        int column = (int)i % 2;
        int row = (int)i >> 1;
        CGFloat markerX =
            markerBaseX + column * ((sampleWidth + kMarkerSpanGap) - markerImage.size.width);
        CGFloat markerY =
            markerBaseY + row * ((sampleHeight + kMarkerSpanGap) - markerImage.size.height);
        // The rotation grows by a 90-degree unit per column and per row over 180 degrees, positive
        // only for slot 1.
        float angle = ((float)row * kMarkerAngleUnit + (float)column * kMarkerAngleUnit) /
                      kMarkerAngleDivisor;
        if (i != 1) {
            angle = -angle;
        }
        marker.frame =
            CGRectMake(markerX, markerY, markerImage.size.width, markerImage.size.height);
        marker.transform = CGAffineTransformMakeRotation(angle * M_PI);
        [self.view addSubview:marker];
    }
}

/** @ghidraAddress 0x7de48 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x7de80 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x7deb8 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // Persist the current page's frame only when it is unlocked.
    NSString *currentIdentifier = frameTable[itemPage][kFrameRowIdentifierIndex];
    if ([self isUnlockFrame:currentIdentifier]) {
        [NSUserDefaults.standardUserDefaults
            setObject:frameTable[itemPage][kFrameRowIdentifierIndex]
               forKey:kSelectedFrameDefaultsKey];
    }
    [[AlertViewManager sharedManager] closeAlert];
    [NSUserDefaults.standardUserDefaults synchronize];
}

/** @ghidraAddress 0x7e088 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Paging

/** @ghidraAddress 0x7d0c0 */
- (void)scrollBtnAlphaControll {
    float pageWidth = (float)scrollView.contentSize.width / (float)frameTable.count;
    float offset = (float)scrollView.contentOffset.x;

    float leftAlpha = offset / pageWidth;
    if (1.0f < leftAlpha) {
        leftAlpha = 1.0f;
    }
    scrlArrow[0].alpha = leftAlpha;

    float rightAlpha = ((float)scrollView.contentSize.width - offset) / pageWidth - 1.0f;
    if (1.0f < rightAlpha) {
        rightAlpha = 1.0f;
    }
    scrlArrow[1].alpha = rightAlpha;
}

/** @ghidraAddress 0x7d18c */
- (void)scrollCursorControll {
    (void)JubeatAppDelegate.appDelegate.isPad; // Fetched for effect; the result is discarded.

    float pageWidth = (float)scrollView.contentSize.width / (float)frameTable.count;
    int offset = (int)(float)scrollView.contentOffset.x;
    int pageStep = (int)pageWidth;
    int withinPage = (pageStep != 0) ? (offset - (offset / pageStep) * pageStep) : offset;
    int halfPage = (int)(pageWidth * 0.5f);
    int distance = halfPage - withinPage;
    if (distance < 0) {
        distance = -distance;
    }
    distance -= halfPage / 2;
    if (distance < 0) {
        distance = 0;
    }
    float alpha = ((float)distance * kMarkerCursorAlphaScale) / (float)halfPage;
    if (1.0f < alpha) {
        alpha = 1.0f;
    }
    float translationMagnitude = (1.0f - alpha) * kMarkerCursorTranslation;

    BOOL settled = (alpha < kMarkerCursorSettleThreshold);
    BOOL slotUnlocked = NO;
    if (settled) {
        slotUnlocked = [self isUnlockFrameWithSlot:itemPage];
    }
    for (NSInteger i = 0; i < kMarkerCount; ++i) {
        selFrameImgTable[i].alpha = alpha;
        selFrameLockImgTable[i].alpha = alpha;

        int column = (int)i % 2;
        int row = (int)i >> 1;
        float rotation = ((float)row * kMarkerAngleUnit + (float)column * kMarkerAngleUnit) /
                         kMarkerAngleDivisor;
        if (i != 1) {
            rotation = -rotation;
        }
        // The per-slot translation direction flips by column and by the slot's half.
        float translationX = (column == 0) ? -1.0f : 1.0f;
        float translationY = (i + 1 < 3) ? -1.0f : 1.0f;
        CGAffineTransform translate = CGAffineTransformMakeTranslation(
            translationMagnitude * translationX, translationMagnitude * translationY);
        CGAffineTransform transform = CGAffineTransformRotate(translate, rotation * M_PI);
        selFrameImgTable[i].transform = transform;
        selFrameLockImgTable[i].transform = transform;

        if (settled) {
            selFrameImgTable[i].hidden = !slotUnlocked;
            selFrameLockImgTable[i].hidden = slotUnlocked;
        }
    }
}

/** @ghidraAddress 0x7d8fc */
- (void)scrollChange:(id)sender {
    CGFloat contentWidth = scrollView.contentSize.width;
    NSInteger pageCount = frameTable.count;
    if ([(UIView *)sender tag] == 0) {
        --itemPage;
    }
    int page = itemPage;
    if ([(UIView *)sender tag] == 1) {
        ++itemPage;
        page = itemPage;
    }
    if (page < 0) {
        page = 0;
        itemPage = 0;
    }
    CGFloat pageWidth = contentWidth / (CGFloat)pageCount;
    if ((NSUInteger)(frameTable.count - 1) < (NSUInteger)page) {
        page = (int)frameTable.count - 1;
        itemPage = page;
    } else {
        page = itemPage;
    }
    [scrollView setContentOffset:CGPointMake(page * (int)pageWidth, 0) animated:YES];
}

/** @ghidraAddress 0x7e0c0 */
- (void)scrollViewDidScroll:(UIScrollView *)aScrollView {
    CGFloat contentWidth = scrollView.contentSize.width;
    NSInteger pageCount = frameTable.count;
    CGFloat offset = scrollView.contentOffset.x;
    CGFloat pageWidth = contentWidth / (CGFloat)pageCount;
    int page = (int)((double)(long)((offset - pageWidth * 0.5) / pageWidth) + 1.0);
    itemPage = page;
    pageCtrl.currentPage = page;
    [self scrollBtnAlphaControll];
    [self scrollCursorControll];
}

#pragma mark - Frame selection and lock state

/** @ghidraAddress 0x7d668 */
- (NSMutableArray *)getSelectedFrame {
    NSString *stored = [NSUserDefaults.standardUserDefaults objectForKey:kSelectedFrameDefaultsKey];
    for (NSMutableArray *row in frameTable) {
        if ([stored isEqualToString:row[kFrameRowIdentifierIndex]]) {
            return row;
        }
    }
    return nil;
}

/** @ghidraAddress 0x7d840 */
- (void)refreshLockImage {
    // The shipped implementation is empty.
}

/** @ghidraAddress 0x7da58 */
- (BOOL)isUnlockFrame:(NSString *)identifier {
    for (NSUInteger i = 0; i < frameTable.count; ++i) {
        NSString *rowIdentifier = frameTable[i][kFrameRowIdentifierIndex];
        if ([identifier isEqualToString:rowIdentifier]) {
            return [self isUnlockFrameWithSlot:(int)i];
        }
    }
    return NO;
}

/** @ghidraAddress 0x7db74 */
- (BOOL)isUnlockFrameWithSlot:(int)slot {
    return YES;
}

#pragma mark - Reward flow

/** @ghidraAddress 0x7d844 */
- (void)pushBtnReward:(id)sender {
    if (self.navigationController) {
        SettingsRewardViewController *reward = [[SettingsRewardViewController alloc] init];
        [self.navigationController pushViewController:reward animated:YES];
    }
}

/** @ghidraAddress 0x7d8f8 */
- (void)pushBtnRewardCheck:(id)sender {
    // The shipped implementation is empty.
}

/** @ghidraAddress 0x7db7c */
- (void)rewardCheckEnd:(id)rewardCheck {
    // The shipped implementation is empty.
}

/** @ghidraAddress 0x7db80 */
- (void)successIDDownload:(id)manager {
    idManager = nil;
}

/** @ghidraAddress 0x7db98 */
- (void)errorIDDownload:(id)manager msgStr:(NSString *)msgStr {
    idManager = nil;
}

#pragma mark - Item display

/** @ghidraAddress 0x7dbb0 */
- (void)itemDisp:(BOOL)animated {
    if (indicatorView) {
        [indicatorView stopAnimating];
        [indicatorView removeFromSuperview];
        indicatorView = nil;
    }
    __weak UIScrollView *weakScrollView = scrollView;
    [UIView animateWithDuration:kFadeInDuration
                     animations:^{
                       /** @ghidraAddress 0x7dcd4 */
                       // Fade every selection marker and its lock image, plus the scroll view, back
                       // to full opacity.
                       weakScrollView.alpha = 1.0;
                       for (NSInteger i = 0; i < kMarkerCount; ++i) {
                           self->selFrameImgTable[i].alpha = 1.0;
                           self->selFrameLockImgTable[i].alpha = 1.0;
                       }
                     }
                     completion:^(BOOL __attribute__((unused)) finished){
                         /** @ghidraAddress 0x7de44 */
                         // The completion is empty.
                     }];
}

#pragma mark - Orientation

/** @ghidraAddress 0x7e194 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait (1) and portrait-upside-down (2): the unsigned (orientation - 1) < 2 test.
    return (NSUInteger)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x7e1a4 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x7e1ac */
- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - Teardown

/** @ghidraAddress 0x7e1b4 */
- (void)dealloc {
    // [super dealloc] is compiler-emitted (ARC). The strong ivars, including idManager and the
    // scroll view whose delegate is self, are released by the compiler-generated .cxx_destruct.
}

@end
