#import "StoreGenreSelectView.h"

#import "GenrePagingScrollView.h"
#import "JubeatAppDelegate.h"
#import "StoreGenreBannerView.h"

// The width of one paging step, in points. Also the scroll view's fixed bounds width.
static const int kPageWidth = 168;

// One genre banner's size within a page.
static const CGFloat kBannerWidth = 158.0;
static const CGFloat kBannerHeight = 68.0;

// Extra wrap-around banner copies appended past the real genres so paging loops seamlessly. The
// binary's loop runs for banner index 0 through genreSize + 4 inclusive, i.e. genreSize + 5
// banners.
static const NSInteger kExtraWrapBanners = 5;

// The number of pages in from the far edge at which the wrap-around jump is anchored.
static const NSInteger kPageWrapOffset = 5;

// The paging offset, in pages, within which the content is wrapped to the opposite end.
static const NSInteger kEdgeWrapPages = 2;

// The view's translucent white backing and its darker rounded border.
static const CGFloat kBackgroundWhite = 1.0;
static const CGFloat kBackgroundAlpha = 0.7;
static const CGFloat kBorderWhite = 0.2;
static const CGFloat kBorderAlpha = 1.0;
static const CGFloat kBorderWidth = 1.0;

@implementation StoreGenreSelectView {
    BOOL isPad;
    NSArray<StoreGenreBannerView *> *genreBannerTable;
    GenrePagingScrollView *scrollBg;
    UIView *bgView;
    int pageWidth;
    int genreSize;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x1db4fc */
- (instancetype)initWithFrame:(CGRect)frame genreList:(nullable NSArray *)genreList {
    self = [super initWithFrame:frame];
    if (self) {
        isPad = JubeatAppDelegate.appDelegate.isPad;
        self.backgroundColor = [UIColor colorWithWhite:kBackgroundWhite alpha:kBackgroundAlpha];
        self.layer.borderColor = [UIColor colorWithWhite:kBorderWhite alpha:kBorderAlpha].CGColor;
        self.layer.borderWidth = kBorderWidth;
        self.clipsToBounds = YES;

        scrollBg = [[GenrePagingScrollView alloc]
            initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        scrollBg.backgroundColor = UIColor.clearColor;
        scrollBg.decelerationRate = UIScrollViewDecelerationRateFast;
        scrollBg.showsHorizontalScrollIndicator = NO;
        scrollBg.showsVerticalScrollIndicator = NO;
        scrollBg.delegate = self;
        scrollBg.pagingEnabled = YES;
        scrollBg.clipsToBounds = NO;
        scrollBg.userInteractionEnabled = YES;
        scrollBg.bounds = CGRectMake(0, 0, kPageWidth, frame.size.height);

        pageWidth = kPageWidth;
        genreSize = (int)genreList.count;

        const CGFloat frameHeight = frame.size.height;
        if (genreSize >= 1) {
            NSMutableArray<StoreGenreBannerView *> *banners = [NSMutableArray array];
            const CGFloat bannerY = (CGFloat)(int)((frameHeight - kBannerHeight) * 0.5);
            CGFloat x = 0;
            const NSInteger bannerCount = genreSize + kExtraWrapBanners;
            for (NSInteger i = 0; i < bannerCount; ++i) {
                StoreGenreBannerView *banner = [[StoreGenreBannerView alloc]
                    initWithFrame:CGRectMake(x, bannerY, kBannerWidth, kBannerHeight)];
                banner.delegate = self;
                const NSInteger idx = i % genreSize;
                banner.tag = idx;
                [banner setGenreInfo:genreList[idx]];
                [banners addObject:banner];
                x += pageWidth;
            }
            genreBannerTable = [banners copy];
        }

        const NSUInteger count = genreBannerTable.count;
        scrollBg.contentSize = CGSizeMake((CGFloat)(pageWidth * count), frameHeight);
        [scrollBg
            setContentOffset:CGPointMake(
                                 (CGFloat)(pageWidth * ((NSInteger)count - kPageWrapOffset)), 0)
                    animated:NO];
        [self addSubview:scrollBg];

        for (StoreGenreBannerView *banner in genreBannerTable) {
            banner.userInteractionEnabled = YES;
            [scrollBg addSubview:banner];
        }
        [self setSelectedBanner:0];
    }
    return self;
}

#pragma mark - Scroll view delegate

/** @ghidraAddress 0x1dbb58 */
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    // Inert in the shipped binary.
}

/** @ghidraAddress 0x1dbb5c */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    const CGPoint offset = scrollBg.contentOffset;
    const NSUInteger count = genreBannerTable.count;
    const CGFloat base = (CGFloat)(pageWidth * ((NSInteger)count - kPageWrapOffset));
    // The binary derives the edge margin as a single-precision doubling of the page width.
    const CGFloat edgeMargin = (CGFloat)(pageWidth * kEdgeWrapPages);
    CGFloat newX;
    if (offset.x < edgeMargin) {
        newX = offset.x + base;
    } else if (offset.x >= base + edgeMargin) {
        newX = offset.x - base;
    } else {
        return;
    }
    scrollBg.contentOffset = CGPointMake(newX, offset.y);
}

/** @ghidraAddress 0x1dbc1c */
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    // Inert in the shipped binary.
}

/** @ghidraAddress 0x1dbc20 */
- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
    // Inert in the shipped binary.
}

/** @ghidraAddress 0x1dbc24 */
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    // Inert in the shipped binary.
}

#pragma mark - Selection

/** @ghidraAddress 0x1dbc60 */
- (void)tapGenreBtn:(id)sender {
    const NSInteger tag = [sender tag];
    const NSInteger index = genreSize != 0 ? tag % genreSize : tag;
    [self setSelectedBanner:index];
    [self.delegate StoreGenreSelectViewDelegateGenreSelected:index];
}

/** @ghidraAddress 0x1dbce8 */
- (void)setSelectedGenreIndex:(NSInteger)index {
    // The binary's guard only returns when the index is negative and the genre count is no greater
    // than it, so a plain negative index still falls through and is used.
    if (index < 0 && genreSize <= index) {
        return;
    }
    [self setSelectedBanner:index];
    [scrollBg setContentOffset:CGPointMake((CGFloat)(pageWidth * index), 0) animated:YES];
}

/** @ghidraAddress 0x1dbd70 */
- (void)setSelectedBanner:(NSInteger)index {
    for (StoreGenreBannerView *banner in genreBannerTable) {
        const NSInteger tag = banner.tag;
        const NSInteger reduced = genreSize != 0 ? tag % genreSize : tag;
        [banner setSelectColor:(reduced == index)];
    }
}

@end
