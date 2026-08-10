#import "MusicListView.h"

#import <QuartzCore/QuartzCore.h>

#import "ArtworkLoader.h"
#import "AudioManager.h"
#import "BalloonView.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "MusicListCollectionLayout.h"
#import "MusicView.h"
#import "ScoreRecord.h"
#import "ScoreRecordManager.h"
#import "TuneInfo.h"
#import "collectionCell.h"
#import "music_grid_layout.h"

// The music-select grid is three tiles wide.
enum {
    kMusicListColumnsPerRow = 3,
};

// The reuse identifier the binary registers and dequeues with. It genuinely contains a space.
static NSString *const kCollectionCellReuseIdentifier = @"collection cell";

// Column-size preference key and rating-chip preference key.
static NSString *const kPrefArtworkColumnSizeKey = @"PrefArtworkColumnSize";
static NSString *const kPrefRatingChipTypeKey = @"PrefRatingChipType";

// The column-size step sound.
static NSString *const kColumnStepSoundName = @"SD_LABO_MENU";

// The scale buttons' images.
static NSString *const kScaleDownImageName = @"scale_down_btn";
static NSString *const kScaleUpImageName = @"scale_up_btn";
static NSString *const kPageLeftImageName = @"page_left";
static NSString *const kPageRightImageName = @"page_right";

// Per-idiom layout tables, indexed by the isPad flag (index 0 phone, index 1 iPad) unless noted.
static const double kListHeightInsetByIsPad[] = {32.0, 44.0};     // 0x28f480
static const double kItemWidthByIsPad[] = {100.0, 220.0};         // 0x28f310
static const double kItemHeightPhoneByIs4Inch[] = {106.0, 101.0}; // 0x28f320
static const double kItemHeightPad = 210.0;                       // 0x28f200
static const double kScaleDownInsetXByIsPad[] = {40.0, 52.0};     // 0x28f490
static const double kScaleUpExtraInsetXByIsPad[] = {40.0, 60.0};  // 0x28f4a0
static const double kPageLabelWidthPhone = 90.0;                  // 0x28f440
static const double kPageLabelWidthPad = 100.0;                   // 0x28f3f0
static const double kPageArrowXInsetByIsPad[] = {40.0, 48.0};   // 0x28f1f8 (phone), 0x28f450 (pad)
static const double kPageArrowHeightPad = 32.0;                 // 0x28f458
static const double kAlphaSliderInsetXByIsPad[] = {45.0, 50.0}; // 0x28f4b0
static const double kNoMusicBoundWidthByIsPad[] = {240.0, 320.0};  // 0x28f4c0
static const double kNoMusicBoundHeightByIsPad[] = {400.0, 600.0}; // 0x28f4d0
static const double kBalloonWidthByIsPad[] = {200.0, 280.0};       // 0x28f350
static const double kPageLabelHeightByIsPad[] = {32.0, 44.0};      // 0x28f480

// Scalar layout constants read from the pool.
static const double kScaleDownInsetY = 26.0;                   // 0x3b8d4 (fmov)
static const double kPageLabelShadowOpacity = 0.6;             // 0x28f3b0 (float)
static const double kPageLabelTextWhite = 0.9;                 // 0x28f448
static const double kBalloonOriginY = -80.0;                   // 0x28f468
static const double kBalloonHeight = 80.0;                     // 0x28f3f8
static const double kAlphaSliderRotation = 1.5707963267948966; // 0x28f460 (M_PI_2)
static const float kAlphaSliderMax = 100.0f;                   // 0x28f4e0
static const float kAlphaSliderDivisor = 100.0f;               // 0x28f4e0

// The scale-button base edge before the image size is added.
static const int kScaleButtonBaseSizePad = 30;
static const int kScaleButtonBaseSizePhone = 10;

// Fixed metrics materialised as fmov immediates in the initialiser.
static const CGFloat kPageArrowXGap = 12.0;
static const CGFloat kPageArrowYGapPad = 6.0;
static const CGFloat kPageArrowYGapPhone = 2.0;
static const CGFloat kPageArrowWidthPad = 48.0;
static const CGFloat kPageArrowWidthPhone = 40.0;
static const CGFloat kPageArrowHeightPhone = 28.0;
static const CGFloat kPageRightXGap = -12.0;
static const CGFloat kLabelShadowRadius = 3.0;
static const CGFloat kBalloonArrowWidth = 16.0;
static const CGFloat kBalloonArrowHeight = 12.0;
static const CGFloat kBalloonContentInset = 12.0;
static const CGFloat kNoMusicCornerRadius = 5.0;
static const CGFloat kNoMusicPadding = 12.0;
static const CGFloat kNoMusicLabelOrigin = 6.0;
static const CGFloat kFontSizeNoMusicPad = 16.0;
static const CGFloat kFontSizeNoMusicPhone = 14.0;
static const CGFloat kFontSizePageLabelPad = 17.0;
static const CGFloat kFontSizePageLabelPhone = 15.0;
static const CGFloat kFontSizeBalloon = 16.0;
static const NSInteger kArtworkCacheCountLimit = 150;
static const NSInteger kLayoutTableCapacity = 3;

// Page-slider vertical metrics.
static const int kPageSliderThicknessPad = 100;
static const int kPageSliderThicknessPhone = 90;
static const int kPageSliderHeightPad = 44;
static const int kPageSliderHeightPhone = 32;
static const float kPageSliderYFactor = -1.5f;

// Animation durations.
static const NSTimeInterval kLayoutFadeDuration = 0.2;  // 0x28e040
static const NSTimeInterval kBalloonFadeDuration = 0.3; // 0x28f260
static const NSTimeInterval kIgnoreInteractionDelay = 0.2;

// The largest delete+insert batch that still animates rather than reloading.
enum {
    kMaxAnimatedBatchCount = 201,
};

@interface MusicListView () <UIGestureRecognizerDelegate> {
    UICollectionViewFlowLayout *flowLayout;
    NSMutableArray *flowLayoutTable;
    UICollectionView *listView;
    __weak id mvDelegate;
    UIButton *scaleUp;
    UIButton *scaleDown;
    int drawColumnType;   // +0x38
    int backColumnType;   // +0x3c
    int musicNumInPage;   // +0x40
    BOOL bScaleAnimation; // +0x44
    UILabel *labelPage;
    UIButton *btnPageRight;
    UIButton *btnPageLeft;
    UIGestureRecognizer *pageSliderCancel;
    UISlider *pageSlider;
    UISlider *alphaSlider;
    BalloonView *balloonView;
    BOOL bBalloonDisp; // +0x80
    UIView *viewNoMusicMessage;
    UILabel *labelNoMusicMessage;
    int currentPage;   // +0x98
    BOOL pageChanging; // +0x9c
    CGPoint newPageOffset;
    NSCache *artworkCache;
    NSMutableDictionary *dictLoader;
    NSOperationQueue *operationQueue;
    BOOL isPad;
    BOOL is4Inch;
    int marginX;
    int marginY;
}
@end

// The following build* helpers de-inline the one large shipped initialiser body; they carry no
// @ghidraAddress of their own because they are all part of 0x3b314.

static inline void MusicListViewBuildFlowLayout(MusicListView *self) {
    self->flowLayout = [[UICollectionViewFlowLayout alloc] init];
    const double itemHeight =
        self->isPad ? kItemHeightPad : kItemHeightPhoneByIs4Inch[self->is4Inch ? 1 : 0];
    self->flowLayout.itemSize = CGSizeMake(kItemWidthByIsPad[self->isPad ? 1 : 0], itemHeight);
    self->flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;

    self->flowLayoutTable = [[NSMutableArray alloc] initWithCapacity:kLayoutTableCapacity];
    for (int colType = 0; colType < kLayoutTableCapacity; ++colType) {
        MusicListCollectionLayout *layout = [[MusicListCollectionLayout alloc] init];
        [layout setColumnType:colType];
        [self->flowLayoutTable addObject:layout];
    }
}

static inline void MusicListViewBuildListView(MusicListView *self, double width, double height) {
    self->listView =
        [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, width, height)
                           collectionViewLayout:self->flowLayoutTable[self->drawColumnType]];
    self->listView.delegate = self;
    self->listView.multipleTouchEnabled = NO;
    self->listView.bouncesZoom = YES;
    self->listView.backgroundColor = UIColor.clearColor;
    self->listView.autoresizesSubviews = YES;
    self->listView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; // 0x12
    self->listView.pagingEnabled = YES;
    self->listView.showsHorizontalScrollIndicator = NO;
    [self->listView registerClass:[collectionCell class]
        forCellWithReuseIdentifier:kCollectionCellReuseIdentifier];
    self->listView.dataSource = self;
}

static inline void MusicListViewBuildScaleButtons(MusicListView *self, CGRect frame) {
    const int baseSize = self->isPad ? kScaleButtonBaseSizePad : kScaleButtonBaseSizePhone;

    UIImage *downImage = LoadScaledPngImage(kScaleDownImageName);
    self->scaleDown = [UIButton buttonWithType:UIButtonTypeCustom];
    [self->scaleDown setImage:downImage forState:UIControlStateNormal];
    const double downX =
        (frame.size.width - kScaleDownInsetXByIsPad[self->isPad ? 1 : 0]) - (double)(baseSize >> 1);
    const double downY = (frame.size.height - kScaleDownInsetY) - (double)(baseSize >> 1);
    const double downW = (double)baseSize + downImage.size.width;
    const double downH = (double)baseSize + downImage.size.height;
    self->scaleDown.frame = CGRectMake(downX, downY, downW, downH);
    self->scaleDown.imageEdgeInsets = UIEdgeInsetsZero;
    [self->scaleDown addTarget:self
                        action:@selector(pushScaleDown:)
              forControlEvents:UIControlEventTouchUpInside];
    [self->scaleDown addTarget:self
                        action:@selector(btnTouchesBegan:)
              forControlEvents:UIControlEventTouchDown];
    [self->scaleDown addTarget:self
                        action:@selector(btnTouchesCancel:)
              forControlEvents:UIControlEventTouchCancel];
    self->scaleDown.exclusiveTouch = YES;

    UIImage *upImage = LoadScaledPngImage(kScaleUpImageName);
    self->scaleUp = [UIButton buttonWithType:UIButtonTypeCustom];
    [self->scaleUp setImage:upImage forState:UIControlStateNormal];
    const double upX = downX - kScaleUpExtraInsetXByIsPad[self->isPad ? 1 : 0];
    self->scaleUp.frame = CGRectMake(upX, downY, downW, downH);
    self->scaleUp.imageEdgeInsets = UIEdgeInsetsZero;
    [self->scaleUp addTarget:self
                      action:@selector(pushScaleUp:)
            forControlEvents:UIControlEventTouchUpInside];
    [self->scaleUp addTarget:self
                      action:@selector(btnTouchesBegan:)
            forControlEvents:UIControlEventTouchDown];
    [self->scaleUp addTarget:self
                      action:@selector(btnTouchesCancel:)
            forControlEvents:UIControlEventTouchCancel];
    self->scaleUp.exclusiveTouch = YES;

    if (self->drawColumnType == 2) {
        self->scaleDown.alpha = 0.0;
    }
    if (self->drawColumnType == 0) {
        self->scaleUp.alpha = 0.0;
    }
}

static inline void MusicListViewBuildPageLabelAndArrows(MusicListView *self) {
    CGColorRef shadowColor = UIColor.blackColor.CGColor;

    const double labelWidth = self->isPad ? kPageLabelWidthPad : kPageLabelWidthPhone;
    const double labelHeight = kPageLabelHeightByIsPad[self->isPad ? 1 : 0];
    const double listWidth = self->listView.frame.size.width;
    self->labelPage = [[UILabel alloc]
        initWithFrame:CGRectMake((listWidth - labelWidth) * 0.5, 0, labelWidth, labelHeight)];
    self->labelPage.font = [UIFont
        boldSystemFontOfSize:(self->isPad ? kFontSizePageLabelPad : kFontSizePageLabelPhone)];
    self->labelPage.textAlignment = NSTextAlignmentCenter;
    self->labelPage.textColor = [UIColor colorWithWhite:kPageLabelTextWhite alpha:1.0];
    self->labelPage.backgroundColor = UIColor.clearColor;
    self->labelPage.layer.shadowColor = shadowColor;
    self->labelPage.layer.shadowRadius = kLabelShadowRadius;
    self->labelPage.layer.shadowOpacity = kPageLabelShadowOpacity;
    self->labelPage.layer.shadowOffset = CGSizeMake(0, 1.0);
    self->labelPage.userInteractionEnabled = YES;
    UILongPressGestureRecognizer *press =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(showPageSelector:)];
    [self->labelPage addGestureRecognizer:press];

    const double arrowWidth = self->isPad ? kPageArrowWidthPad : kPageArrowWidthPhone;
    const double arrowHeight = self->isPad ? kPageArrowHeightPad : kPageArrowHeightPhone;
    const double arrowYGap = self->isPad ? kPageArrowYGapPad : kPageArrowYGapPhone;

    self->btnPageLeft = [UIButton buttonWithType:UIButtonTypeCustom];
    const double leftX =
        (self->labelPage.frame.origin.x - kPageArrowXInsetByIsPad[self->isPad ? 1 : 0]) +
        kPageArrowXGap;
    self->btnPageLeft.frame =
        CGRectMake(leftX, kPageArrowXGap + arrowYGap, arrowWidth, arrowHeight);
    self->btnPageLeft.backgroundColor = UIColor.clearColor;
    [self->btnPageLeft setImage:LoadScaledPngImage(kPageLeftImageName)
                       forState:UIControlStateNormal];
    self->btnPageLeft.contentMode = UIViewContentModeScaleAspectFit;
    self->btnPageLeft.layer.shadowColor = shadowColor;
    self->btnPageLeft.layer.shadowRadius = kLabelShadowRadius;
    self->btnPageLeft.layer.shadowOpacity = g_flKeyTime060;
    self->btnPageLeft.layer.shadowOffset = CGSizeZero;
    [self->btnPageLeft addTarget:self
                          action:@selector(pushPageArrow:)
                forControlEvents:UIControlEventTouchUpInside];
    [self->btnPageLeft addTarget:self
                          action:@selector(btnTouchesBegan:)
                forControlEvents:UIControlEventTouchDown];
    [self->btnPageLeft addTarget:self
                          action:@selector(btnTouchesCancel:)
                forControlEvents:UIControlEventTouchCancel];
    self->btnPageLeft.exclusiveTouch = YES;

    self->btnPageRight = [UIButton buttonWithType:UIButtonTypeCustom];
    const double rightX =
        (self->labelPage.frame.origin.x + self->labelPage.frame.size.width) + kPageRightXGap;
    self->btnPageRight.frame =
        CGRectMake(rightX, kPageRightXGap + arrowYGap, arrowWidth, arrowHeight);
    self->btnPageRight.backgroundColor = UIColor.clearColor;
    [self->btnPageRight setImage:LoadScaledPngImage(kPageRightImageName)
                        forState:UIControlStateNormal];
    self->btnPageRight.contentMode = UIViewContentModeScaleAspectFit;
    self->btnPageRight.layer.shadowColor = shadowColor;
    self->btnPageRight.layer.shadowRadius = kLabelShadowRadius;
    self->btnPageRight.layer.shadowOpacity = g_flKeyTime060;
    self->btnPageRight.layer.shadowOffset = CGSizeZero;
    [self->btnPageRight addTarget:self
                           action:@selector(pushPageArrow:)
                 forControlEvents:UIControlEventTouchUpInside];
    [self->btnPageRight addTarget:self
                           action:@selector(btnTouchesBegan:)
                 forControlEvents:UIControlEventTouchDown];
    [self->btnPageRight addTarget:self
                           action:@selector(btnTouchesCancel:)
                 forControlEvents:UIControlEventTouchCancel];
    self->btnPageRight.exclusiveTouch = YES;
}

static inline void MusicListViewBuildSliders(MusicListView *self) {
    self->pageSliderCancel =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pageSliderHidden:)];

    CGRect bounds = UIScreen.mainScreen.bounds;
    const int sliderThickness = self->isPad ? kPageSliderThicknessPad : kPageSliderThicknessPhone;
    const int sliderHeight = self->isPad ? kPageSliderHeightPad : kPageSliderHeightPhone;

    self->pageSlider = [[UISlider alloc]
        initWithFrame:CGRectMake((double)(sliderThickness >> 1),
                                 bounds.size.height + ((float)sliderHeight * kPageSliderYFactor),
                                 bounds.size.width - (double)sliderThickness,
                                 (double)sliderHeight)];
    [self->pageSlider addTarget:self
                         action:@selector(sliderChange:)
               forControlEvents:UIControlEventValueChanged];
    [self->pageSlider addTarget:self
                         action:@selector(sliderEnd:)
               forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                                UIControlEventTouchCancel];

    int half = (int)(bounds.size.width * 0.5);
    if (half < 0) {
        ++half;
    }
    self->alphaSlider = [[UISlider alloc]
        initWithFrame:CGRectMake((bounds.size.width - (double)(half >> 1)) -
                                     kAlphaSliderInsetXByIsPad[self->isPad ? 1 : 0],
                                 bounds.size.width * 0.25 + (double)(sliderHeight << 1),
                                 bounds.size.width * 0.5,
                                 (double)sliderHeight)];
    self->alphaSlider.transform = CGAffineTransformMakeRotation(kAlphaSliderRotation);
    self->alphaSlider.minimumValue = 1.0f;
    self->alphaSlider.maximumValue = kAlphaSliderMax;
    self->alphaSlider.value = kAlphaSliderMax;
    [self->alphaSlider addTarget:self
                          action:@selector(alphaSliderChange:)
                forControlEvents:UIControlEventValueChanged];
    [self->alphaSlider addTarget:self
                          action:@selector(alphaSliderEnd:)
                forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                                 UIControlEventTouchCancel];
}

static inline void MusicListViewBuildNoMusicView(MusicListView *self) {
    self->labelNoMusicMessage = [[UILabel alloc] initWithFrame:CGRectZero];
    self->labelNoMusicMessage.numberOfLines = 0;
    self->labelNoMusicMessage.lineBreakMode = NSLineBreakByWordWrapping;
    self->labelNoMusicMessage.textAlignment = NSTextAlignmentLeft;
    self->labelNoMusicMessage.userInteractionEnabled = NO;
    self->labelNoMusicMessage.font =
        [UIFont fontWithName:@"Helvetica-Bold"
                        size:(self->isPad ? kFontSizeNoMusicPad : kFontSizeNoMusicPhone)];
    self->labelNoMusicMessage.textColor = UIColor.whiteColor;
    self->labelNoMusicMessage.opaque = NO;
    self->labelNoMusicMessage.backgroundColor = UIColor.clearColor;

    NSString *message = [NSBundle.mainBundle localizedStringForKey:@"NewPlaylistMessage"
                                                             value:@""
                                                             table:nil];
    const CGSize boundSize = CGSizeMake(kNoMusicBoundWidthByIsPad[self->isPad ? 1 : 0],
                                        kNoMusicBoundHeightByIsPad[self->isPad ? 1 : 0]);
    CGRect textRect =
        [message boundingRectWithSize:boundSize
                              options:(NSStringDrawingUsesLineFragmentOrigin |
                                       NSStringDrawingUsesFontLeading)
                           attributes:@{NSFontAttributeName : self->labelNoMusicMessage.font}
                              context:nil];
    self->labelNoMusicMessage.frame = CGRectMake(
        kNoMusicLabelOrigin, kNoMusicLabelOrigin, textRect.size.width, textRect.size.height);
    self->labelNoMusicMessage.text = message;

    self->viewNoMusicMessage =
        [[UIView alloc] initWithFrame:CGRectMake(0,
                                                 0,
                                                 textRect.size.width + kNoMusicPadding,
                                                 textRect.size.height + kNoMusicPadding)];
    self->viewNoMusicMessage.opaque = NO;
    self->viewNoMusicMessage.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    self->viewNoMusicMessage.layer.cornerRadius = kNoMusicCornerRadius;
    self->viewNoMusicMessage.center =
        CGPointMake(self->listView.frame.size.width * 0.5, self->listView.frame.size.height * 0.5);
    [self->viewNoMusicMessage addSubview:self->labelNoMusicMessage];
}

static inline void MusicListViewBuildBalloonView(MusicListView *self) {
    const double balloonWidth = kBalloonWidthByIsPad[self->isPad ? 1 : 0];
    const double arrowPosition = balloonWidth * 0.5;
    self->bBalloonDisp = YES;

    self->balloonView =
        [[BalloonView alloc] initWithFrame:CGRectMake((kBalloonArrowWidth - arrowPosition),
                                                      kBalloonOriginY,
                                                      balloonWidth,
                                                      kBalloonHeight)];
    self->balloonView.layer.shadowColor = UIColor.blackColor.CGColor;
    self->balloonView.layer.shadowRadius = kLabelShadowRadius;
    self->balloonView.layer.shadowOpacity = kPageLabelShadowOpacity;
    self->balloonView.layer.shadowOffset = CGSizeMake(0, 1.0);
    [self->balloonView setArrowDirection:1];
    [self->balloonView setArrowSize:CGSizeMake(kBalloonArrowWidth, kBalloonArrowHeight)];
    [self->balloonView setArrowPosision:arrowPosition];
    [self->balloonView setContentEdgeInsets:UIEdgeInsetsMake(kBalloonContentInset,
                                                             kBalloonContentInset,
                                                             kBalloonContentInset,
                                                             kBalloonContentInset)];
    self->balloonView.hidden = YES;
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideExplainBalloon)];
    [self->balloonView addGestureRecognizer:tap];

    UILabel *balloonLabel = [[UILabel alloc] initWithFrame:[self->balloonView contentRect]];
    balloonLabel.opaque = NO;
    balloonLabel.backgroundColor = UIColor.clearColor;
    balloonLabel.textColor = UIColor.whiteColor;
    balloonLabel.font = [UIFont boldSystemFontOfSize:kFontSizeBalloon];
    balloonLabel.textAlignment = NSTextAlignmentCenter;
    balloonLabel.numberOfLines = 0;
    balloonLabel.text = @"ボタンでページ移動が可能です。";
    [self->balloonView addSubview:balloonLabel];
}

@implementation MusicListView

#pragma mark - Lifecycle

/** @ghidraAddress 0x3b314 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        JubeatAppDelegate *app = JubeatAppDelegate.appDelegate;
        isPad = app.isPad;
        is4Inch = JubeatAppDelegate.appDelegate.deviceType == JubeatDeviceTypePhoneRetina4Inch;
        self.backgroundColor = UIColor.clearColor;

        const double listHeight = frame.size.height - kListHeightInsetByIsPad[isPad ? 1 : 0];
        backColumnType =
            (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefArtworkColumnSizeKey];
        drawColumnType = backColumnType;
        musicNumInPage = [self musicInPage:drawColumnType];

        MusicListViewBuildFlowLayout(self);
        MusicListViewBuildListView(self, frame.size.width, listHeight);
        MusicListViewBuildScaleButtons(self, frame);
        MusicListViewBuildPageLabelAndArrows(self);
        MusicListViewBuildSliders(self);
        MusicListViewBuildNoMusicView(self);

        artworkCache = [[NSCache alloc] init];
        [artworkCache setCountLimit:kArtworkCacheCountLimit];
        artworkCache.delegate = self;
        dictLoader = [[NSMutableDictionary alloc] init];

        [self addSubview:listView];
        [self addSubview:scaleDown];
        [self addSubview:scaleUp];
        [self addSubview:labelPage];
        [self addSubview:btnPageLeft];
        [self addSubview:btnPageRight];

        operationQueue = [[NSOperationQueue alloc] init];

        MusicListViewBuildBalloonView(self);
    }
    return self;
}

/** @ghidraAddress 0x3ef10 */
- (void)dealloc {
    [self releaseArtworks];
    artworkCache.delegate = nil;
}

#pragma mark - Geometry

/** @ghidraAddress 0x3cec4 */
- (CGPoint)centerOfMusicViewInPage:(NSUInteger)page forIndex:(NSUInteger)index {
    CGRect frame = listView.frame;
    const NSInteger columnStep = isPad ? 240 : 105;
    NSInteger rowStep;
    if (isPad) {
        rowStep = 215;
    } else {
        rowStep = is4Inch ? 110 : 115;
    }
    CGPoint center;
    center.x = marginX + page * frame.size.width + columnStep * (index % kMusicListColumnsPerRow);
    center.y = marginY + rowStep * (index / kMusicListColumnsPerRow);
    return center;
}

/** @ghidraAddress 0x3d0fc */
- (CGFloat)artworkSize {
    // The original indexes a two-element double table by the isPad flag rather than branching.
    static const double kArtworkSizes[] = {80.0, 160.0}; // 0x28f330
    return kArtworkSizes[isPad ? 1 : 0];
}

#pragma mark - Page tiles

/** @ghidraAddress 0x3cfa4 */
- (void)hideAllPlaylistAction {
    for (collectionCell *cell in listView.visibleCells) {
        [[cell getMusicView] hidePlaylistActionButton];
    }
}

/** @ghidraAddress 0x3d118 */
- (void)clearAllPage {
    [self releaseArtworks];
    [self hideAllPlaylistAction];
    for (collectionCell *cell in listView.visibleCells) {
        MusicView *musicView = [cell getMusicView];
        [musicView clearInfo];
        musicView.hidden = YES;
    }
}

/** @ghidraAddress 0x3ebb8 */
- (void)addDownloadMark:(int)index {
    if (index < 0) {
        return;
    }
    for (collectionCell *cell in listView.visibleCells) {
        MusicView *musicView = [cell getMusicView];
        if ((int)musicView.tuneInfo.tuneID == index) {
            [musicView addDownloadNotice];
            break;
        }
    }
}

/** @ghidraAddress 0x3ed68 */
- (MusicView *)getMusicView:(int)index {
    if (index < 0) {
        return nil;
    }
    for (collectionCell *cell in listView.visibleCells) {
        MusicView *musicView = [cell getMusicView];
        if ((int)musicView.tuneInfo.tuneID == index) {
            return musicView;
        }
    }
    return nil;
}

#pragma mark - Artwork loading

/** @ghidraAddress 0x3d2a8 */
- (void)loadArtworkForInfo:(MusicView *)musicView {
    [self loadArtworkForInfo:musicView.tuneInfo
                forImageView:musicView.imgView
                  concurrent:YES
                       index:(int)musicView.tag];
}

/** @ghidraAddress 0x3d368 */
- (void)loadArtworkForInfo:(TuneInfo *)info
              forImageView:(UIImageView *)imageView
                concurrent:(BOOL)concurrent
                     index:(int)index {
    if (info == nil) {
        return;
    }
    NSNumber *key = [[NSNumber alloc] initWithUnsignedInt:info.tuneID];
    UIImage *cached = [artworkCache objectForKey:key];
    if (cached != nil) {
        [imageView setImage:cached];
        return;
    }
    if ([dictLoader objectForKey:key] != nil) {
        return;
    }
    CGFloat size;
    BOOL bigArtwork;
    JubeatAppDelegate *app = JubeatAppDelegate.appDelegate;
    if (isPad) {
        BOOL retina = app.isPadRetina;
        bigArtwork = retina;
        size = retina ? 320.0 : 160.0; // 0x28f470, 0x28f438
    } else {
        BOOL retina = app.isPhoneRetina;
        bigArtwork = NO;
        size = retina ? 160.0 : 80.0; // 0x28f438, 0x28f3f8
    }
    ArtworkLoader *loader = [[ArtworkLoader alloc] initWithPath:info.filePath
                                                         tuneID:info.tuneID
                                                       indexRow:index
                                                           size:CGSizeMake(size, size)
                                                     bigArtwork:bigArtwork];
    loader.delegate = self;
    [dictLoader setObject:loader forKey:key];
    if (concurrent) {
        NSInvocationOperation *operation =
            [[NSInvocationOperation alloc] initWithTarget:loader
                                                 selector:@selector(loadArtwork)
                                                   object:nil];
        [operationQueue addOperation:operation];
    } else {
        [loader loadArtwork];
    }
}

/** @ghidraAddress 0x3d67c */
- (void)reloadPageContainsMusicForIndex:(NSUInteger)musicIndex
                          playlistIndex:(NSInteger)playlistIndex {
    CGFloat pageWidth = listView.frame.size.width;
    NSArray *removeArray = [self.delegate removeMusicArray];
    NSArray *addArray = [self.delegate addMusicArray];
    if (removeArray.count + addArray.count < kMaxAnimatedBatchCount) {
        [listView
            performBatchUpdates:^{
              /** @ghidraAddress 0x3d9a0 */
              [listView deleteItemsAtIndexPaths:removeArray];
              [listView insertItemsAtIndexPaths:addArray];
              int perPage = [self musicInPage:drawColumnType];
              // Hardware udiv yields 0 for a zero divisor; reproduce that rather than trap.
              currentPage = perPage != 0 ? (unsigned int)musicIndex / (unsigned int)perPage : 0;
              [listView setContentOffset:CGPointMake((double)currentPage * pageWidth, 0)];
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x3dab4 */
              [self updatePageDisplay];
            }];
    } else {
        int perPage = [self musicInPage:drawColumnType];
        currentPage = perPage != 0 ? (unsigned int)musicIndex / (unsigned int)perPage : 0;
        [listView reloadData];
    }
    if (playlistIndex >= 0) {
        if ([self.delegate numberOfMusic] == 0) {
            viewNoMusicMessage.alpha = 1.0;
            [self addSubview:viewNoMusicMessage];
            return;
        }
    }
    CGPoint offset = listView.contentOffset;
    currentPage = (int)floor((pageWidth * 0.5 + offset.x) / pageWidth);
    [self updatePageDisplay];
    if (viewNoMusicMessage.superview == self) {
        [viewNoMusicMessage removeFromSuperview];
    }
}

/** @ghidraAddress 0x3dad4 */
- (void)removeMusicView:(MusicView *)musicView {
    for (collectionCell *cell in listView.visibleCells) {
        MusicView *cellMusicView = [cell getMusicView];
        if ((int)musicView.tuneInfo.tuneID == (int)cellMusicView.tuneInfo.tuneID) {
            NSIndexPath *indexPath = [listView indexPathForCell:cell];
            [listView deleteItemsAtIndexPaths:@[ indexPath ]];
            NSInteger numItems = [listView numberOfItemsInSection:0];
            int perPage = [self musicInPage:drawColumnType];
            NSInteger page = perPage != 0 ? numItems / perPage : 0;
            if (page < currentPage) {
                --currentPage;
                CGRect frame = listView.frame;
                [listView setContentOffset:CGPointMake((double)currentPage * frame.size.width, 0)];
            }
            break;
        }
    }
}

/** @ghidraAddress 0x3ddd0 */
- (void)setMusicViewDelegate:(id)aDelegate {
    mvDelegate = aDelegate;
}

/** @ghidraAddress 0x3deb8 */
- (void)imageDataLoaded:(ArtworkLoader *)loader {
    if (loader.image != nil) {
        __weak NSMutableDictionary *weakLoaderDict = dictLoader;
        __weak NSCache *weakCache = artworkCache;
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x3dfe8 */
          NSNumber *key = [[NSNumber alloc] initWithUnsignedInt:loader.tuneID];
          NSIndexPath *indexPath = [NSIndexPath indexPathForRow:loader.indexRow inSection:0];
          collectionCell *cell = (collectionCell *)[listView cellForItemAtIndexPath:indexPath];
          if (cell != nil) {
              MusicView *musicView = [cell getMusicView];
              if ((int)musicView.tuneInfo.tuneID == (int)loader.tuneID) {
                  [musicView.imgView setImage:loader.image];
                  [weakCache setObject:loader.image forKey:key];
              }
          }
          [weakLoaderDict removeObjectForKey:key];
        });
    }
}

/** @ghidraAddress 0x3e294 */
- (void)cache:(NSCache *)cache willEvictObject:(id)obj {
}

/** @ghidraAddress 0x3e298 */
- (void)releaseArtworks {
    [artworkCache removeAllObjects];
    [operationQueue cancelAllOperations];
    [dictLoader enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
      /** @ghidraAddress 0x3e318 */
      [obj setDelegate:nil];
    }];
    [dictLoader removeAllObjects];
}

#pragma mark - Paging

/** @ghidraAddress 0x3e32c */
- (int)currentViewsPerPage {
    return [self musicInPage:drawColumnType];
}

/** @ghidraAddress 0x3e344 */
- (int)musicInPage:(int)colType {
    return GetMusicGridCellsPerPage(colType);
}

/** @ghidraAddress 0x3e34c */
- (int)numPage {
    int total = (int)[self.delegate numberOfMusic];
    // Ceiling division with no divide-by-zero guard: the binary emits a bare sdiv.
    return (total + musicNumInPage - 1) / musicNumInPage;
}

/** @ghidraAddress 0x3e3b8 */
- (int)getCurrentPage {
    return currentPage;
}

/** @ghidraAddress 0x3e3c8 */
- (void)updatePageDisplay {
    int pages = [self numPage];
    if (pages != 0) {
        btnPageRight.hidden = (currentPage == pages - 1);
        btnPageLeft.hidden = (currentPage == 0);
        labelPage.hidden = NO;
        // stringWithFormat: args recovered from the stack setup at 0x3e484: currentPage + 1, pages.
        labelPage.text = [NSString stringWithFormat:@"%d / %d", currentPage + 1, pages];
        pageSlider.minimumValue = 0;
        CGFloat contentWidth = listView.contentSize.width;
        CGFloat frameWidth = listView.frame.size.width;
        pageSlider.maximumValue = (float)(contentWidth - frameWidth);
        pageSlider.value = (float)listView.contentOffset.x;
    } else {
        btnPageLeft.hidden = YES;
        btnPageRight.hidden = YES;
        labelPage.hidden = YES;
    }
    // The common tail runs for both arms; it re-reads the live listView geometry.
    CGFloat offsetX = listView.contentOffset.x;
    CGFloat pageWidth = listView.frame.size.width;
    [self.delegate scrollFromPageNum:(int)(offsetX / pageWidth) bAnim:YES];
}

/** @ghidraAddress 0x3dde4 */
- (void)alignPage:(int)page {
    CGRect frame = listView.frame;
    [listView setContentOffset:CGPointMake(page * frame.size.width, 0) animated:NO];
}

/** @ghidraAddress 0x3de3c */
- (BOOL)layoutPage:(int)page center:(int)center {
    CGRect frame = listView.frame;
    // Both parameters are ignored; the offset is derived from the currentPage ivar.
    listView.contentOffset = CGPointMake(frame.size.width * currentPage, 0);
    return YES;
}

/** @ghidraAddress 0x3dea0 */
- (void)updateViews {
    [listView reloadData];
}

#pragma mark - Scroll view delegate

/** @ghidraAddress 0x3e634 */
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if ([self.delegate respondsToSelector:@selector(musicListScrollBegin)]) {
        [self.delegate musicListScrollBegin];
    }
}

/** @ghidraAddress 0x3e6e4 */
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    pageChanging = NO;
    if ([self.delegate respondsToSelector:@selector(musicListScrollBegin)]) {
        [self.delegate musicListScrollBegin];
    }
}

/** @ghidraAddress 0x3e7a0 */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat pageWidth = scrollView.frame.size.width;
    [self hideAllPlaylistAction];
    if (pageChanging && scrollView.contentOffset.x == newPageOffset.x) {
        CGFloat offsetX = scrollView.contentOffset.x;
        // fcvtms floors; the offset is non-negative here so it equals truncation.
        currentPage = (int)floor((offsetX + pageWidth * 0.5) / pageWidth);
        [self updatePageDisplay];
        pageChanging = NO;
    }
}

/** @ghidraAddress 0x3e874 */
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    CGFloat pageWidth = scrollView.frame.size.width;
    CGFloat offsetX = scrollView.contentOffset.x;
    currentPage = (int)floor((offsetX + pageWidth * 0.5) / pageWidth);
    [self updatePageDisplay];
}

/** @ghidraAddress 0x3e910 */
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (decelerate) {
        return;
    }
    CGFloat pageWidth = scrollView.frame.size.width;
    CGFloat offsetX = scrollView.contentOffset.x;
    currentPage = (int)floor((offsetX + pageWidth * 0.5) / pageWidth);
    [self updatePageDisplay];
}

/** @ghidraAddress 0x3e9c4 */
- (void)pushPageArrow:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(btnTouchesCancel:)]) {
        [self.delegate btnTouchesCancel:sender];
    }
    if (!pageChanging && !listView.isTracking && !listView.isDecelerating) {
        BOOL move = NO;
        int page = 0;
        if (btnPageLeft == sender && currentPage > 0) {
            pageChanging = YES;
            page = --currentPage;
            move = YES;
        } else if (btnPageRight == sender && currentPage < [self numPage] - 1) {
            pageChanging = YES;
            page = ++currentPage;
            move = YES;
        }
        if (move) {
            CGFloat pageWidth = listView.bounds.size.width;
            newPageOffset = CGPointMake(page * pageWidth, 0);
            [listView setContentOffset:CGPointMake(page * pageWidth, 0) animated:YES];
        }
    }
    [self hideExplainBalloon];
}

#pragma mark - Collection view data source and layout

/** @ghidraAddress 0x3ef7c */
- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView
                        layout:(UICollectionViewLayout *)collectionViewLayout
        insetForSectionAtIndex:(NSInteger)section {
    // Only the left inset is non-zero: 20.0.
    return UIEdgeInsetsMake(0, 20, 0, 0);
}

/** @ghidraAddress 0x3ef90 */
- (CGFloat)collectionView:(UICollectionView *)collectionView
                                      layout:(UICollectionViewLayout *)collectionViewLayout
    minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 0.0;
}

/** @ghidraAddress 0x3ef98 */
- (CGFloat)collectionView:(UICollectionView *)collectionView
                                 layout:(UICollectionViewLayout *)collectionViewLayout
    minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    // Line spacing per column type, loaded as 32-bit ints and converted to double. 0x28f4e4
    static const int kMusicListLineSpacing[] = {36, 22, 18};
    return (double)kMusicListLineSpacing[drawColumnType];
}

/** @ghidraAddress 0x3efbc */
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

/** @ghidraAddress 0x3efc4 */
- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return [self.delegate numberOfMusic];
}

/** @ghidraAddress 0x3f010 */
- (BOOL)checkFullCombo:(NSData *)data {
    char bytes[30] = {0};
    [data getBytes:bytes length:30];
    // Each byte holds four 2-bit fields; bit 1 of every field across all 120 notes must be set.
    for (int i = 0; i <= 0x77; ++i) {
        char b = bytes[i >> 2];
        if ((((b >> ((i & 3) * 2)) >> 1) & 1) == 0) {
            return NO;
        }
    }
    return YES;
}

/** @ghidraAddress 0x3f0cc */
- (void)reviseScoreData:(int)tuneID {
    ScoreRecord *record = [ScoreRecord recordForTuneID:tuneID];
    if (![ScoreRecord checkScore:record]) {
        return;
    }

    BOOL fcBas = record.fcBas.boolValue;
    BOOL fcAdv = record.fcAdv.boolValue;
    BOOL fcExt = record.fcExt.boolValue;
    BOOL fcCheck = record.fcCheck.boolValue;
    BOOL changed = NO;

    // First pass: if the record was never full-combo-checked, derive each difficulty's combo from
    // its mailbox note data. A difficulty that is not a full combo gets its perfect-count sentinel
    // (99999) written and its local combo flag cleared.
    if (!fcCheck) {
        NSData *basData = [record.mbBas subdataWithRange:NSMakeRange(0, 30)];
        if (![self checkFullCombo:basData]) {
            [record setPmBas:@(99999)];
            fcBas = NO;
            changed = YES;
        }
        NSData *advData = [record.mbAdv subdataWithRange:NSMakeRange(0, 30)];
        if (![self checkFullCombo:advData]) {
            [record setPmAdv:@(99999)];
            fcAdv = NO;
            changed = YES;
        }
        NSData *extData = [record.mbExt subdataWithRange:NSMakeRange(0, 30)];
        if (![self checkFullCombo:extData]) {
            [record setPmExt:@(99999)];
            fcExt = NO;
            changed = YES;
        }
        [record setFcCheck:@(YES)];
    }

    // Second pass: a difficulty already flagged full combo stays set; otherwise it is a full combo
    // exactly when its perfect count is zero. Only the Basic and Advanced results feed the
    // "changed" flag; Extreme's zero-check instead gates the write directly.
    BOOL rBas;
    if (fcBas) {
        rBas = YES;
    } else {
        rBas = (record.pmBas.intValue == 0);
        changed |= rBas;
    }

    BOOL rAdv;
    if (fcAdv) {
        rAdv = YES;
    } else {
        rAdv = (record.pmAdv.intValue == 0);
        changed |= rAdv;
    }

    BOOL rExt;
    BOOL pmExtZero = NO;
    if (fcExt) {
        rExt = YES;
    } else {
        pmExtZero = (record.pmExt.intValue == 0);
        rExt = pmExtZero;
    }

    if (changed || pmExtZero) {
        [record setFcBas:@(rBas)];
        [record setFcAdv:@(rAdv)];
        [record setFcExt:@(rExt)];
        record.chksco = [ScoreRecord hashScore:record];

        NSManagedObjectContext *context = ScoreRecordManager.sharedManager.managedObjectContext;
        NSError *error = nil;
        if (![context save:&error]) {
            id detailedErrors = error.userInfo[NSDetailedErrorsKey];
            if (detailedErrors && [detailedErrors count] != 0) {
                // The binary enumerates the detailed errors but does nothing with them.
                for (id detail in detailedErrors) {
                    (void)detail;
                }
            }
        }
    }
}

/** @ghidraAddress 0x3f820 */
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    collectionCell *cell =
        [collectionView dequeueReusableCellWithReuseIdentifier:kCollectionCellReuseIdentifier
                                                  forIndexPath:indexPath];
    if (!cell) {
        // dequeueReusableCellWithReuseIdentifier:forIndexPath: never returns nil, but the binary
        // keeps this fallback.
        cell = [[collectionCell alloc] init];
    }

    int viewType = bScaleAnimation ? backColumnType : drawColumnType;
    // The cell is initialised with the list view itself as its "info" argument.
    [cell initCell:self parentDelegate:mvDelegate viewType:viewType labelDisp:!bScaleAnimation];

    TuneInfo *info = [self.delegate musicInfoForIndex:indexPath.row];
    [cell setInfo:info index:(int)indexPath.row];

    ScoreRecord *record = [ScoreRecord recordForTuneID:info.tuneID];
    [self reviseScoreData:info.tuneID];
    if (record) {
        [[cell getMusicView] setScore:record];
    }

    if (info.extendID != 0) {
        TuneInfo *extendInfo = [self.delegate extendMusicInfoForMusicID:info.extendID];
        ScoreRecord *extendRecord = [ScoreRecord recordForTuneID:extendInfo.tuneID];
        [self reviseScoreData:extendInfo.tuneID];
        [[cell getMusicView] setExtendInfo:extendInfo];
        [[cell getMusicView] setExtendScore:extendRecord];
    } else {
        [[cell getMusicView] setExtendInfo:nil];
        [[cell getMusicView] setExtendScore:nil];
    }

    NSInteger chipType = [NSUserDefaults.standardUserDefaults integerForKey:kPrefRatingChipTypeKey];
    [[cell getMusicView] setRatingChipHidden:(int)chipType];

    if (backColumnType != drawColumnType) {
        [[cell getMusicView] fadeoutLabel];
    }
    return cell;
}

/** @ghidraAddress 0x3fcf8 */
- (void)collectionView:(UICollectionView *)collectionView
       willDisplayCell:(UICollectionViewCell *)cell
    forItemAtIndexPath:(NSIndexPath *)indexPath {
    MusicView *musicView = [(collectionCell *)cell getMusicView];
    if (musicView.imgView.image == nil) {
        NSNumber *key = @(musicView.tuneInfo.tuneID);
        if (dictLoader[key] == nil) {
            [self loadArtworkForInfo:musicView];
        }
    }
}

#pragma mark - Column-size scaling

/** @ghidraAddress 0x3fe34 */
- (void)changeLayout:(int)colType {
    if ([self.delegate respondsToSelector:@selector(btnTouchesCancel:)]) {
        [self.delegate btnTouchesCancel:nil];
    }
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    MusicListCollectionLayout *layout = flowLayoutTable[colType];
    bScaleAnimation = YES;
    __weak UICollectionView *weakListView = listView;
    // The proposed offset's x is truncated to an integer before being re-widened.
    [layout ignoreContentOffsetForProposedContentOffset:CGPointMake(
                                                            (CGFloat)(int)listView.contentOffset.x,
                                                            0.0)];
    for (collectionCell *cell in listView.visibleCells) {
        [[cell getMusicView] fadeoutLabel];
    }
    [weakListView setCollectionViewLayout:layout
                                 animated:YES
                               completion:^(BOOL finished) {
                                 /** @ghidraAddress 0x403d4 */
                                 for (collectionCell *cell in listView.visibleCells) {
                                     [[cell getMusicView] switchLabel:drawColumnType];
                                 }
                                 bScaleAnimation = NO;
                                 backColumnType = drawColumnType;
                                 [layout cancelIgnoreOffset];
                                 [UIApplication.sharedApplication
                                     performSelector:@selector(endIgnoringInteractionEvents)
                                          withObject:nil
                                          afterDelay:kIgnoreInteractionDelay];
                                 CGRect frame = listView.frame;
                                 CGPoint offset = listView.contentOffset;
                                 currentPage = (int)floor((frame.size.width * 0.5 + offset.x) /
                                                          frame.size.width);
                                 [self updatePageDisplay];
                               }];
    if (backColumnType == 2) {
        __weak UIButton *weakScaleDown = scaleDown;
        [UIView animateWithDuration:kLayoutFadeDuration
                         animations:^{
                           /** @ghidraAddress 0x4068c */
                           weakScaleDown.alpha = 1.0;
                         }
                         completion:^(BOOL finished){
                         }];
    }
    if (backColumnType == 0) {
        __weak UIButton *weakScaleUp = scaleUp;
        [UIView animateWithDuration:kLayoutFadeDuration
                         animations:^{
                           /** @ghidraAddress 0x406dc */
                           weakScaleUp.alpha = 1.0;
                         }
                         completion:^(BOOL finished){
                         }];
    }
    if (colType == 0) {
        __weak UIButton *weakScaleUp = scaleUp;
        [UIView animateWithDuration:kLayoutFadeDuration
                         animations:^{
                           /** @ghidraAddress 0x4077c */
                           weakScaleUp.alpha = 0.0;
                         }
                         completion:^(BOOL finished){
                         }];
    } else if (colType == 2) {
        __weak UIButton *weakScaleDown = scaleDown;
        [UIView animateWithDuration:kLayoutFadeDuration
                         animations:^{
                           /** @ghidraAddress 0x4072c */
                           weakScaleDown.alpha = 0.0;
                         }
                         completion:^(BOOL finished){
                         }];
    }
}

/** @ghidraAddress 0x407cc */
- (void)pushScaleDown:(id)sender {
    int oldMusicNumInPage = musicNumInPage;
    backColumnType = drawColumnType;
    int newColumnType = drawColumnType < 2 ? drawColumnType + 1 : 2;
    drawColumnType = newColumnType;
    musicNumInPage = [self musicInPage:newColumnType];
    if (backColumnType == drawColumnType) {
        return;
    }
    [AudioManager.sharedManager playSeResFile:kColumnStepSoundName inDirectory:nil];
    // No divide-by-zero guard in the binary: musicNumInPage was just set from musicInPage:.
    int page = (currentPage * oldMusicNumInPage + oldMusicNumInPage / 2) / musicNumInPage;
    CGRect frame = listView.frame;
    [listView setContentOffset:CGPointMake((double)page * frame.size.width, 0.0)];
    currentPage = page;
    [self changeLayout:drawColumnType];
    [NSUserDefaults.standardUserDefaults setInteger:drawColumnType
                                             forKey:kPrefArtworkColumnSizeKey];
    [NSUserDefaults.standardUserDefaults synchronize];
}

/** @ghidraAddress 0x40990 */
- (void)pushScaleUp:(id)sender {
    int oldMusicNumInPage = musicNumInPage;
    backColumnType = drawColumnType;
    int newColumnType = drawColumnType > 0 ? drawColumnType - 1 : 0;
    drawColumnType = newColumnType;
    musicNumInPage = [self musicInPage:newColumnType];
    if (backColumnType == drawColumnType) {
        return;
    }
    [AudioManager.sharedManager playSeResFile:kColumnStepSoundName inDirectory:nil];
    unsigned int target = (unsigned int)(currentPage * oldMusicNumInPage + oldMusicNumInPage / 2);
    // Unsigned comparison; numberOfMusic is queried twice.
    if (target >= (unsigned int)[self.delegate numberOfMusic]) {
        target = (unsigned int)[self.delegate numberOfMusic] - 1;
    }
    // No divide-by-zero guard in the binary.
    int page = (int)target / musicNumInPage;
    CGRect frame = listView.frame;
    [listView setContentOffset:CGPointMake((double)page * frame.size.width, 0.0)];
    currentPage = page;
    [self changeLayout:drawColumnType];
    [NSUserDefaults.standardUserDefaults setInteger:drawColumnType
                                             forKey:kPrefArtworkColumnSizeKey];
    [NSUserDefaults.standardUserDefaults synchronize];
}

#pragma mark - Button forwarding

/** @ghidraAddress 0x40bd8 */
- (void)btnTouchesBegan:(id)touches {
    if ([self.delegate respondsToSelector:@selector(btnTouchesBegan:)]) {
        [self.delegate btnTouchesBegan:touches];
    }
}

/** @ghidraAddress 0x40c90 */
- (void)btnTouchesCancel:(id)touches {
    if ([self.delegate respondsToSelector:@selector(btnTouchesCancel:)]) {
        [self.delegate btnTouchesCancel:touches];
    }
}

#pragma mark - Page and alpha sliders

/** @ghidraAddress 0x40d48 */
- (void)pageSliderHidden:(id)sender {
    [self.delegate hiddenCoverView];
}

/** @ghidraAddress 0x40d88 */
- (void)showPageSelector:(UIGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        NSArray *sliders;
        if ([JubeatAppDelegate.appDelegate isHinabitaMode]) {
            sliders = [NSArray arrayWithObjects:(id[]){pageSlider, alphaSlider} count:2];
        } else {
            sliders = [NSArray arrayWithObjects:(id[]){pageSlider} count:1];
        }
        [self.delegate showCoverView:sliders addGesture:pageSliderCancel];
    }
}

/** @ghidraAddress 0x40ef4 */
- (void)sliderValueChange {
    pageSlider.minimumValue = 0.0f;
    pageSlider.maximumValue = (float)[self numPage];
    pageSlider.value = (float)currentPage;
}

/** @ghidraAddress 0x40f78 */
- (void)sliderChange:(id)sender {
    CGRect frame = listView.frame;
    // Quirk: the content-offset x is set to the raw slider value (a page number), not value*width.
    [listView setContentOffset:CGPointMake((double)[pageSlider value], 0.0)];
    CGPoint offset = listView.contentOffset;
    currentPage = (int)floor((frame.size.width * 0.5 + offset.x) / frame.size.width);
    int pages = [self numPage];
    if (pages == 0) {
        btnPageLeft.hidden = YES;
        btnPageRight.hidden = YES;
        labelPage.hidden = YES;
    } else {
        btnPageRight.hidden = (currentPage == pages - 1);
        btnPageLeft.hidden = (currentPage == 0);
        labelPage.hidden = NO;
        labelPage.text = [NSString stringWithFormat:@"%d / %d", currentPage + 1, pages];
    }
    id<MusicListViewDelegate> delegate = self.delegate;
    CGPoint scrollOffset = listView.contentOffset;
    CGRect scrollFrame = listView.frame;
    [delegate scrollFromPageNum:(int)(scrollOffset.x / scrollFrame.size.width) bAnim:NO];
}

/** @ghidraAddress 0x411c0 */
- (void)sliderEnd:(id)sender {
    CGRect frame = listView.frame;
    [listView setContentOffset:CGPointMake((double)[pageSlider value], 0.0)];
    CGPoint offset = listView.contentOffset;
    int page = (int)floor((frame.size.width * 0.5 + offset.x) / frame.size.width);
    currentPage = page;
    double snappedX = frame.size.width * page;
    [listView setContentOffset:CGPointMake(snappedX, 0.0) animated:YES];
    pageSlider.value = (float)snappedX;
}

/** @ghidraAddress 0x412a0 */
- (void)hideExplainBalloon {
    bBalloonDisp = NO;
    if (balloonView != nil && !balloonView.isHidden) {
        balloonView.userInteractionEnabled = NO;
        __weak BalloonView *weakBalloon = balloonView;
        [UIView animateWithDuration:kBalloonFadeDuration
            animations:^{
              /** @ghidraAddress 0x413e8 */
              weakBalloon.alpha = 0.0;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x41434 */
              // Alpha is reset to 1.0 only after setHidden:YES, so the reset is never
              // seen; the ivar is not nil'ed, the balloon object is reused.
              balloonView.hidden = YES;
              balloonView.alpha = 1.0;
              [balloonView removeFromSuperview];
            }];
    }
}

/** @ghidraAddress 0x414a8 */
- (void)alphaSliderChange:(id)sender {
    listView.alpha = [alphaSlider value] / kAlphaSliderDivisor;
    if ((int)[alphaSlider value] == (int)[alphaSlider minimumValue]) {
        if (bBalloonDisp) {
            UIButton *anchor = btnPageLeft;
            if (anchor.isHidden) {
                anchor = btnPageRight;
            }
            if (!anchor.isHidden) {
                [anchor addSubview:balloonView];
                balloonView.hidden = NO;
            }
        }
    } else {
        if (!balloonView.isHidden) {
            balloonView.hidden = YES;
            [balloonView removeFromSuperview];
        }
    }
}

/** @ghidraAddress 0x41638 */
- (void)alphaSliderEnd:(id)sender {
    listView.alpha = [alphaSlider value] / kAlphaSliderDivisor;
}

/** @ghidraAddress 0x41690 */
- (float)getMusicListAlpha {
    return (float)listView.alpha;
}

#pragma mark - Tile refresh

/** @ghidraAddress 0x416bc */
- (void)refreshTextColor {
    for (collectionCell *cell in listView.visibleCells) {
        [[cell getMusicView] refreshTextColor];
    }
}

/** @ghidraAddress 0x41814 */
- (void)refreshRatingChip {
    NSInteger ratingChipType =
        [NSUserDefaults.standardUserDefaults integerForKey:kPrefRatingChipTypeKey];
    for (collectionCell *cell in listView.visibleCells) {
        [[cell getMusicView] setRatingChipHidden:(int)ratingChipType];
    }
}

// The delegate getter (0x419b4) and setter (0x419d4) are the ARC-synthesised weak accessors for the
// delegate property; they are not spelled out here.

@end
