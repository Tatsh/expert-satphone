#import "StoreMainViewControllerV2.h"

#import "EditorIDManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "RotatableNavigationController.h"
#import "StoreDetailViewControllerV2.h"
#import "StoreGenreSelectView.h"
#import "StoreGenreTableViewController.h"
#import "StoreGenreTitleView.h"
#import "StoreLoadingView.h"
#import "StorePackDetailViewV2.h"
#import "StorePackInfo.h"
#import "StorePackListController.h"
#import "StorePackListGenre.h"
#import "StorePackTableView.h"
#import "StorePromotionView.h"
#import "StoreUtil.h"
#import "StoreViewControllerV2.h"

// The maximum number of pack-detail overlays (pad) or recommend pushes (phone) open at once.
static const NSInteger kMaxOpenDetail = 10;

// The screen title, tab-bar image, and cell-background artwork names.
static NSString *const kStoreTitle = @"jubeat store";
static NSString *const kTabImageName = @"tab_store";
static NSString *const kCellBackgroundImage0Name = @"store_pack_bg_0";
static NSString *const kCellBackgroundImage1Name = @"store_pack_bg_1";

// The reuse identifier of the genre-list rows.
static NSString *const kGenreCellReuseIdentifier = @"StoreGenreTableCell";

// The alert-result dictionary key carrying the tapped button index.
static NSString *const kAlertKeyButtonMessage = @"btnMessage";

// The user-defaults flag that suppresses the one-time restore prompt after its first showing.
static NSString *const kPrefFirstRestoreEndKey = @"PrefFirstRestoreEnd";

// The product-list marker file whose presence also suppresses the restore prompt.
static NSString *const kProductListFileName = @"prodlist";

// The localised-string keys this screen raises.
static NSString *const kLocKeyOK = @"OK";
static NSString *const kLocKeyCategory = @"Category";
static NSString *const kLocKeyError = @"Error";
static NSString *const kLocKeyNetworkErrorMessage = @"NetworkErrorMsg";
static NSString *const kLocKeyServerErrorMessage = @"ServerErrorMsg";
static NSString *const kLocKeyRestoreCheck = @"Restore Check";
static NSString *const kLocKeyDoRestore = @"Do Restore";
static NSString *const kLocKeyDoAfter = @"Do After";
static NSString *const kEmptyValue = @"";

// The message shown when the pack-detail cap is reached.
static NSString *const kDetailCapMessage = @"これ以上開く事はできません";

// The alert type (the makeAlert: first argument): a plain alert with no text-input field.
static const int kAlertTypePlain = 0;

// The alert tag used for the one-time restore prompt.
static const int kAlertTagRestore = 1;

// The button index the restore prompt reports for its "Do Restore" action.
static const int kAlertButtonRestore = 1;

// The tab index the "First Restore" flow switches to.
static const NSUInteger kLibraryTabIndex = 1;

// The spacer bar-button width separating the back button from the title.
static const CGFloat kBarSpacerWidth = 20.0;

// The store title-label font size (phone) and the genre-row label size.
static const CGFloat kTitleLabelFontSize = 16.0;
static const CGFloat kGenreRowFontSize = 19.0;

// The pad pack-list container's rounded-corner radius and border width.
static const CGFloat kPadContainerCornerRadius = 8.0;
static const CGFloat kPadContainerBorderWidth = 1.0;

// The cell-background resizable-image cap inset.
static const CGFloat kCellBackgroundCapInset = 4.0;

// The alpha of the translucent white pack-list backgrounds.
static const CGFloat kListBackgroundAlpha = 0.3;

// The white level of the pad container's grey border.
static const CGFloat kPadBorderWhite = 0.2;

// The dimming cover's black alpha on the pad.
static const CGFloat kCoverAlpha = 0.5;

// The fixed side of the pad pack-detail overlay square. @ghidraAddress 0x291c10
static const CGFloat kPadDetailSide = 650.0;

// The pad loading-view size. @ghidraAddress 0x291c40 / 0x291c50
static const CGFloat kPadLoadingWidth = 650.0;
static const CGFloat kPadLoadingHeight = 140.0;

// The phone loading-view size. @ghidraAddress 0x291c48 / 0x291c58
static const CGFloat kPhoneLoadingWidth = 300.0;
static const CGFloat kPhoneLoadingHeight = 200.0;

// The pad genre-popover preferred width. @ghidraAddress 0x28f470
static const CGFloat kGenrePopoverWidth = 320.0;

// The pad genre-popover per-row height and clamp for its preferred content height.
// @ghidraAddress 0x291c38 / 0x291c3c / 0x291c30
static const CGFloat kGenrePopoverRowHeight = 50.0;
static const CGFloat kGenrePopoverMaxHeight = 600.0;

// The pad pack-list container's left inset and width reduction. @ghidraAddress 0x4034... / 0x28e078
static const CGFloat kPadListLeftInset = 20.0;
static const CGFloat kPadPromotionInset = -40.0;

// The pad promotion carousel's reserved height when a carousel is present. @ghidraAddress 0x291c20
static const CGFloat kPadPromotionReserved = -250.0;

// The pad promotion carousel's top offset. @ghidraAddress 0x28f200 region uses a literal 10.
static const CGFloat kPadPromotionTop = 10.0;

// The pad pack-list top offset when no carousel is present.
static const CGFloat kPadListTopNoPromotion = 20.0;

// The pad promotion carousel's placement offsets. @ghidraAddress 0x28f200 / 0x28f670
static const CGFloat kPadPromotionHeight = 210.0;
static const CGFloat kPadPromotionAdvance = 230.0;

// The phone promotion carousel's aspect scaling: width * (280 / 730).
// @ghidraAddress 0x28f658 / 0x291c28
static const CGFloat kPhonePromotionAspectNumerator = 280.0;
static const CGFloat kPhonePromotionAspectDenominator = 730.0;

// The animation duration shared by the fade and slide transitions. @ghidraAddress 0x28f260
static const NSTimeInterval kDetailAnimationDuration = 0.3;

// The delay before re-enabling interaction after a fade/slide. @ghidraAddress 0x28f268
static const NSTimeInterval kInteractionUnlockDelay = 0.4;

// The horizontal drift factors of the neighbouring windows during a push/pop slide.
// @ghidraAddress 0x3fe0000000000000 / 0x3fd0000000000000
static const double kNeighbourDriftHalf = 0.5;
static const double kNeighbourDriftQuarter = 0.25;

@implementation StoreMainViewControllerV2 {
    BOOL lockFetch;
    BOOL isPad;
    BOOL bAlreadyBack;
    EditorIDManager *idManager;
    __weak StoreViewControllerV2 *storeViewCtrl;
    StorePackListController *packListCtrl;
    StorePromotionView *promotionView;
    StorePackTableView *packTableView;
    StoreGenreTableViewController *genreTableViewCtrl;
    RotatableNavigationController *genreNavCtrl;
    SKStoreProductViewController *itunesViewCtrl;
    StorePackDetailViewV2 *packDetailViewPad;
    UIView *coverViewPad;
    NSMutableArray *detailWindowArray;
    StoreLoadingView *loadingView;
    UIBarButtonItem *backBarButton;
    UIBarButtonItem *barSpacer;
    UIImage *cellBgImage0;
    UIImage *cellBgImage1;
    BOOL isOpenPackDetail;
    NSInteger fetchGenreID;
    StorePackDetailViewV2 *currentPurchaseViewPad;
    StoreDetailViewControllerV2 *currentPurchaseViewPhone;
    int recommendCnt;
    BOOL recommendPushFlg;
    UIView *packListView;
    StoreGenreTitleView *categoryTitleView;
    StoreGenreSelectView *categoryListView;
    UIView *storeHeaderView;
    int phoneHeaderBaseHeight;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x17b488 */
- (instancetype)initWithParent:(StoreViewControllerV2 *)parent {
    self = [super init];
    if (self) {
        storeViewCtrl = parent;
        if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
            [self performSelector:@selector(setExtendedLayoutIncludesOpaqueBars:) withObject:nil];
        }
        if ([self respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)]) {
            [self performSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)
                       withObject:self];
        }
        isPad = JubeatAppDelegate.appDelegate.isPad;
        if (isPad) {
            self.navigationItem.title = kStoreTitle;
        } else {
            // On the phone the title is a tappable label that scrolls the table to the top.
            UITapGestureRecognizer *tap =
                [[UITapGestureRecognizer alloc] initWithTarget:self
                                                        action:@selector(tapNavigation)];
            UILabel *titleLabel = [[UILabel alloc]
                initWithFrame:CGRectMake(100.0, 0.0, 0.0, [StoreUtil storeTabHeaderHeight])];
            titleLabel.textAlignment = NSTextAlignmentCenter;
            titleLabel.text = kStoreTitle;
            titleLabel.font = [UIFont boldSystemFontOfSize:kTitleLabelFontSize];
            [titleLabel sizeToFit];
            [titleLabel addGestureRecognizer:tap];
            titleLabel.userInteractionEnabled = YES;
            self.navigationItem.titleView = titleLabel;
        }
        self.tabBarItem.title = kStoreTitle;
        self.tabBarItem.image = LoadScaledPngImage(kTabImageName);
        backBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                                         style:UIBarButtonItemStyleDone
                                                        target:self
                                                        action:@selector(handleBackButton:)];
        barSpacer =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                          target:nil
                                                          action:nil];
        barSpacer.width = kBarSpacerWidth;
        self.navigationItem.leftBarButtonItems = @[ backBarButton ];
        packListCtrl = [[StorePackListController alloc] init];
        packListCtrl.delegate = self;
        lockFetch = YES;
        bAlreadyBack = NO;
        fetchGenreID = -1;
    }
    return self;
}

/** @ghidraAddress 0x17ba14 */
- (void)loadView {
    [super loadView];
    self.view.opaque = YES;
    CGRect bounds = self.view.bounds;

    // A vertical grey gradient filling the whole view.
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = bounds;
    gradient.opaque = YES;
    UIColor *topColor = [UIColor colorWithRed:0.725 green:0.731 blue:0.737 alpha:1.0];
    UIColor *bottomColor = [UIColor colorWithRed:0.467 green:0.489 blue:0.511 alpha:1.0];
    gradient.colors = @[ (__bridge id)topColor.CGColor, (__bridge id)bottomColor.CGColor ];
    [self.view.layer addSublayer:gradient];

    CGFloat headerHeight = [StoreUtil storeTabHeaderHeight];
    CGFloat footerHeight = [StoreUtil storeTabFooterHeight];
    CGFloat listHeight = bounds.size.height - headerHeight - footerHeight;

    packListView = [[UIView alloc]
        initWithFrame:CGRectMake(bounds.origin.x, bounds.origin.y, bounds.size.width, listHeight)];
    packListView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:kListBackgroundAlpha];
    if (isPad) {
        packListView.layer.cornerRadius = kPadContainerCornerRadius;
        packListView.layer.borderColor = [UIColor colorWithWhite:kPadBorderWhite alpha:1.0].CGColor;
        packListView.layer.borderWidth = kPadContainerBorderWidth;
        packListView.clipsToBounds = YES;
    }

    packTableView = [[StorePackTableView alloc]
        initWithFrame:CGRectMake(bounds.origin.x, bounds.origin.y, bounds.size.width, listHeight)
                style:UITableViewStylePlain];
    packTableView.viewController = self;
    packTableView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:kListBackgroundAlpha];

    if (isPad) {
        coverViewPad = [[UIView alloc] initWithFrame:self.view.bounds];
        coverViewPad.opaque = NO;
        coverViewPad.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kCoverAlpha];
        coverViewPad.userInteractionEnabled = YES;
        coverViewPad.exclusiveTouch = YES;
        UITapGestureRecognizer *coverTap =
            [[UITapGestureRecognizer alloc] initWithTarget:self
                                                    action:@selector(handleTapCoverView:)];
        [coverViewPad addGestureRecognizer:coverTap];

        packDetailViewPad = [[StorePackDetailViewV2 alloc]
            initWithFrame:CGRectMake(0.0, 0.0, kPadDetailSide, kPadDetailSide)];
        packDetailViewPad.center =
            CGPointMake((CGFloat)(int)(bounds.origin.x + bounds.size.width * 0.5),
                        (CGFloat)(int)(bounds.origin.y + listHeight * 0.5));
        packDetailViewPad.delegate = self;
        packDetailViewPad.viewController = self;
        detailWindowArray = [[NSMutableArray alloc] init];
        [detailWindowArray addObject:packDetailViewPad];
    }

    CGFloat loadingWidth = isPad ? kPadLoadingWidth : kPhoneLoadingWidth;
    CGFloat loadingHeight = isPad ? kPadLoadingHeight : kPhoneLoadingHeight;
    loadingView =
        [[StoreLoadingView alloc] initWithFrame:CGRectMake(0.0, 0.0, loadingWidth, loadingHeight)];
    loadingView.center =
        CGPointMake((CGFloat)((int)bounds.size.width >> 1), (CGFloat)((int)listHeight >> 1));
    loadingView.hidden = YES;
    [self.view addSubview:loadingView];

    UIEdgeInsets caps = UIEdgeInsetsMake(kCellBackgroundCapInset,
                                         kCellBackgroundCapInset,
                                         kCellBackgroundCapInset,
                                         kCellBackgroundCapInset);
    cellBgImage0 = [LoadScaledPngImage(kCellBackgroundImage0Name) resizableImageWithCapInsets:caps];
    cellBgImage1 = [LoadScaledPngImage(kCellBackgroundImage1Name) resizableImageWithCapInsets:caps];
}

/** @ghidraAddress 0x17f7f0 */
- (void)viewDidLoad {
    [super viewDidLoad];
    // Let each navigation-bar subview claim its own touches so a tap cannot fall through.
    for (UIView *barSubview in self.navigationController.navigationBar.subviews) {
        barSubview.exclusiveTouch = YES;
    }
}

/** @ghidraAddress 0x17f2c0 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!isPad) {
        NSIndexPath *selected = packTableView.indexPathForSelectedRow;
        if (selected) {
            [packTableView reloadRowsAtIndexPaths:@[ selected ]
                                 withRowAnimation:UITableViewRowAnimationNone];
            [packTableView deselectRowAtIndexPath:selected animated:animated];
        }
    } else if (packDetailViewPad) {
        [packDetailViewPad updatePurchaseState];
    }
    if (promotionView) {
        [promotionView thumbnailMute:YES];
    }
}

/** @ghidraAddress 0x17f438 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!lockFetch) {
        if ([packTableView.currentGenre packCount] == 0) {
            [loadingView startLoading];
            NSNumber *storePackID = JubeatAppDelegate.appDelegate.storePackID;
            if (storePackID) {
                int packID = storePackID.intValue;
                [JubeatAppDelegate.appDelegate resetDownloadPackID];
                if (packID > 0) {
                    packListCtrl.additionalPackID = @(packID);
                }
            }
            if (EditorIDManager.isExistEditorID) {
                [packListCtrl startFetchGenre:packTableView.currentGenre];
            } else {
                idManager = [[EditorIDManager alloc] initWithDelegate:self];
            }
        }
        [promotionView resume];
    }
}

/** @ghidraAddress 0x17f68c */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (packListView.superview) {
        [packTableView stopLoadingMore:YES];
    }
    if (isPad) {
        [packDetailViewPad cancelLoading];
        [packDetailViewPad stopSample];
    }
    [promotionView pause];
    [packListCtrl cancelFetching];
}

/** @ghidraAddress 0x17f780 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0x17f7b8 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x17f980 */
- (void)viewDidUnload {
    [super viewDidUnload];
    packTableView = nil;
    coverViewPad = nil;
    packDetailViewPad = nil;
    loadingView = nil;
}

/** @ghidraAddress 0x1800b8 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x1800c8 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

/** @ghidraAddress 0x1800d0 */
- (BOOL)shouldAutorotate {
    return YES;
}

/** @ghidraAddress 0x1800d8 */
- (void)dealloc {
    packTableView.currentGenre = nil;
    if (idManager) {
        [idManager cancel];
        idManager = nil;
    }
    // [super dealloc] is compiler-emitted (ARC — .cxx_destruct at 0x18027c).
}

#pragma mark - Pack-list loading

/** @ghidraAddress 0x17c310 */
- (void)loadInitialPacklist:(NSInteger)packID {
    lockFetch = NO;
    [loadingView startLoading];
    if (packID > 0) {
        packListCtrl.additionalPackID = @(packID);
    }
    packTableView.currentGenre = [packListCtrl packListForGenreIndex:0];
    if (EditorIDManager.isExistEditorID) {
        [packListCtrl startFetchForGenreIndex:0];
    } else {
        idManager = [[EditorIDManager alloc] initWithDelegate:self];
    }
}

/** @ghidraAddress 0x17c464 */
- (void)loadInitialPacklistWithGenre:(NSInteger)genreID {
    lockFetch = NO;
    fetchGenreID = genreID;
    [loadingView startLoading];
    packTableView.currentGenre = [packListCtrl packListForGenreIndex:0];
    [packListCtrl startFetchForGenreID:genreID];
}

/** @ghidraAddress 0x17c828 */
- (void)refresh {
    if ([packTableView.currentGenre packCount]) {
        [packTableView reloadData];
    }
}

/** @ghidraAddress 0x180250 */
- (void)tapNavigation {
    if (packTableView) {
        [packTableView setContentOffset:CGPointZero animated:YES];
    }
}

/** @ghidraAddress 0x17c524 */
- (void)updatePurchaseStateForPackID:(int)packID {
    if (!isPad) {
        [currentPurchaseViewPhone updatePurchaseState];
        return;
    }
    for (StorePackDetailViewV2 *detailView in detailWindowArray) {
        [detailView updatePurchaseState];
    }
    NSUInteger packCount = [packTableView.currentGenre packCount];
    if (packCount) {
        for (NSUInteger i = 0; i < [packTableView.currentGenre packCount]; ++i) {
            StorePackInfo *info = (StorePackInfo *)[packTableView.currentGenre packInfoForIndex:i];
            if (info.packID == packID) {
                // The binary reloads row i >> 1 (a signed arithmetic shift), not row i.
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(NSInteger)((int)i >> 1)
                                                            inSection:0];
                [packTableView reloadRowsAtIndexPaths:@[ indexPath ]
                                     withRowAnimation:UITableViewRowAnimationNone];
                break;
            }
        }
    }
}

#pragma mark - Detail presentation

/** @ghidraAddress 0x17c994 */
- (void)showDetailForPackInfo:(StorePackInfo *)packInfo {
    [promotionView thumbnailMute:NO];
    ++recommendCnt;
    if (!isPad) {
        isOpenPackDetail = YES;
        StoreDetailViewControllerV2 *detail = [[StoreDetailViewControllerV2 alloc] init];
        detail.delegate = self;
        detail.closeDelegate = self;
        detail.bRestore = NO;
        detail.packInfo = packInfo;
        [self.navigationController pushViewController:detail animated:YES];
    } else {
        [UIApplication.sharedApplication beginIgnoringInteractionEvents];
        isOpenPackDetail = YES;
        coverViewPad.alpha = 0.0;
        packDetailViewPad.alpha = 0.0;
        [self.view addSubview:coverViewPad];
        [self.view addSubview:packDetailViewPad];
        packDetailViewPad.packInfo = packInfo;
        __weak UIView *weakCover = coverViewPad;
        __weak StorePackDetailViewV2 *weakDetail = packDetailViewPad;
        [UIView animateWithDuration:kDetailAnimationDuration
            delay:0.0
            options:UIViewAnimationOptionCurveEaseInOut
            animations:^{
              /** @ghidraAddress 0x17cd54 */
              weakCover.alpha = 1.0;
              weakDetail.alpha = 1.0;
            }
            completion:^(BOOL __attribute__((unused)) finished) {
              /** @ghidraAddress 0x17ce24 */
              [weakDetail loadInfo];
            }];
        [UIApplication.sharedApplication performSelector:@selector(endIgnoringInteractionEvents)
                                              withObject:nil
                                              afterDelay:kInteractionUnlockDelay];
    }
}

/** @ghidraAddress 0x17ce6c */
- (void)switchToGenre:(NSUInteger)genreIndex {
    if (packDetailViewPad.superview) {
        [self handleTapCoverView:nil];
    }
    StorePackListGenre *genre = [packListCtrl packListForGenreIndex:genreIndex];
    if (packTableView.currentGenre == genre) {
        // Same genre: fetch on demand when empty, otherwise there is nothing to do.
        if ([packTableView.currentGenre packCount] == 0 && !packListCtrl.isFetching) {
            [loadingView startLoading];
            [packListCtrl startFetchGenre:packTableView.currentGenre];
        }
        return;
    }

    [packTableView stopLoadingMore:NO];
    [packListCtrl cancelFetching];
    packTableView.currentGenre = genre;
    if ([packTableView.currentGenre packCount]) {
        [loadingView stopLoading];
        CGRect tableFrame = packTableView.frame;
        [packTableView scrollRectToVisible:CGRectMake(0.0, 0.0, tableFrame.size.width, 0.0)
                                  animated:NO];
    } else {
        [loadingView startLoading];
        [packListCtrl startFetchGenre:packTableView.currentGenre];
    }

    int titleHeight = [categoryTitleView setGenreTitleInfo:packTableView.currentGenre];
    if (!isPad) {
        // Resize the table header to fit the freshly-titled genre header (phone only).
        CGRect titleFrame = categoryTitleView.frame;
        categoryTitleView.frame = CGRectMake(
            titleFrame.origin.x, titleFrame.origin.y, titleFrame.size.width, titleHeight);
        storeHeaderView.frame = CGRectMake(titleFrame.origin.x,
                                           titleFrame.origin.y,
                                           titleFrame.size.width,
                                           phoneHeaderBaseHeight + titleHeight);
        packTableView.tableHeaderView = nil;
        packTableView.tableHeaderView = storeHeaderView;
    }
    [packTableView reloadData];
    if (!isPad) {
        // The navigation title label tracks the selected genre name (phone only).
        UILabel *titleLabel = (UILabel *)self.navigationItem.titleView;
        CGRect labelFrame = titleLabel.frame;
        titleLabel.frame = CGRectMake(labelFrame.origin.x,
                                      labelFrame.origin.y,
                                      self.view.bounds.size.width,
                                      labelFrame.size.height);
        if (genreIndex != 0) {
            titleLabel.text = packTableView.currentGenre.genreName;
        } else {
            titleLabel.text = kStoreTitle;
        }
        [titleLabel sizeToFit];
    }
}

/** @ghidraAddress 0x179dd4 */
- (BOOL)tapReccommendPack:(StorePackInfo *)packInfo {
    if (isPad) {
        if (detailWindowArray.count < kMaxOpenDetail) {
            StorePackDetailViewV2 *detailView = [[StorePackDetailViewV2 alloc]
                initWithFrame:CGRectMake(0.0, 0.0, kPadDetailSide, kPadDetailSide)];
            detailView.center = packDetailViewPad.center;
            detailView.delegate = self;
            detailView.viewController = self;
            detailView.packInfo = packInfo;
            [self.view addSubview:detailView];
            [self pushDetailList:detailView];
            return YES;
        }
    } else {
        if (recommendCnt < kMaxOpenDetail) {
            ++recommendCnt;
            recommendPushFlg = YES;
            StoreDetailViewControllerV2 *detail = [[StoreDetailViewControllerV2 alloc] init];
            detail.delegate = self;
            detail.closeDelegate = self;
            detail.bRestore = NO;
            detail.packInfo = packInfo;
            [self.navigationController pushViewController:detail animated:YES];
            return YES;
        }
    }
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                        value:kEmptyValue
                                                        table:nil];
    [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                     delegate:nil
                                          tag:0
                                        title:kEmptyValue
                                          msg:kDetailCapMessage
                                       cancel:ok
                                      btnText:nil
                                         show:YES];
    return NO;
}

#pragma mark - Pad detail-window stack

/** @ghidraAddress 0x17a154 */
- (void)pushDetailList:(StorePackDetailViewV2 *)detailView {
    NSInteger count = (NSInteger)detailWindowArray.count;
    if (count - 1 < 0) {
        return;
    }
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];

    UIView *grandparent = nil;
    if (count - 2 >= 0) {
        grandparent = detailWindowArray[count - 2];
    }
    StorePackDetailViewV2 *topWindow = detailWindowArray[count - 1];
    __weak StorePackDetailViewV2 *weakTop = topWindow;
    __weak UIView *weakNew = detailView;

    // Reset the outgoing front to identity, then park the newcomer off to the right.
    topWindow.transform = CGAffineTransformMakeTranslation(0.0, 0.0);
    [topWindow stopSample];

    int fullWidth = (int)self.view.frame.size.width;
    int halfWidth = fullWidth / 2;
    CGFloat newWidth = detailView.frame.size.width;
    int startDx = (int)((double)halfWidth + newWidth * kNeighbourDriftHalf);
    detailView.transform = CGAffineTransformMakeTranslation((CGFloat)startDx, 0.0);
    [detailView loadInfo];

    int grandparentDx = (int)((double)halfWidth + detailView.frame.size.width);
    int topSlideDx =
        (int)((double)(-startDx) + ((double)fullWidth - newWidth) * kNeighbourDriftQuarter);

    __weak UIView *weakGrandparent = grandparent;
    [UIView animateWithDuration:kDetailAnimationDuration
        delay:0.0
        options:UIViewAnimationOptionCurveEaseInOut
        animations:^{
          /** @ghidraAddress 0x17a5a4 */
          if (weakGrandparent) {
              weakGrandparent.transform =
                  CGAffineTransformMakeTranslation((CGFloat)(-grandparentDx), 0.0);
          }
          weakTop.transform = CGAffineTransformMakeTranslation((CGFloat)topSlideDx, 0.0);
          weakNew.transform = CGAffineTransformMakeTranslation(0.0, 0.0);
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x17a75c */
          [weakTop setInactive];
          [detailWindowArray addObject:detailView];
          [UIApplication.sharedApplication endIgnoringInteractionEvents];
        }];
}

/** @ghidraAddress 0x17a848 */
- (void)popDetailList {
    NSInteger count = (NSInteger)detailWindowArray.count;
    if (count - 2 < 0) {
        return;
    }
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];

    StorePackDetailViewV2 *poppedWindow = detailWindowArray[count - 1];
    __weak StorePackDetailViewV2 *weakPopped = poppedWindow;
    StorePackDetailViewV2 *newTopWindow = detailWindowArray[count - 2];
    __weak StorePackDetailViewV2 *weakNewTop = newTopWindow;
    UIView *deeperWindow = nil;
    if (count - 3 >= 0) {
        deeperWindow = detailWindowArray[count - 3];
    }

    int halfWidth = (int)self.view.frame.size.width >> 1;
    CGFloat newTopWidth = newTopWindow.frame.size.width;
    [poppedWindow stopSample];

    int poppedDx = (int)((double)halfWidth + newTopWidth);
    int deeperDx =
        (int)((double)(-(int)((double)halfWidth + newTopWidth * kNeighbourDriftHalf)) +
              ((double)(int)self.view.frame.size.width - newTopWidth) * kNeighbourDriftQuarter);

    [UIView animateWithDuration:kDetailAnimationDuration
        delay:0.0
        options:UIViewAnimationOptionCurveEaseInOut
        animations:^{
          /** @ghidraAddress 0x17ac2c */
          weakPopped.transform = CGAffineTransformMakeTranslation((CGFloat)poppedDx, 0.0);
          weakNewTop.transform = CGAffineTransformMakeTranslation(0.0, 0.0);
          if (deeperWindow) {
              deeperWindow.transform = CGAffineTransformMakeTranslation((CGFloat)deeperDx, 0.0);
          }
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x17addc */
          [weakNewTop setActive];
          [weakPopped removeFromSuperview];
          [detailWindowArray removeObject:poppedWindow];
          [UIApplication.sharedApplication endIgnoringInteractionEvents];
        }];
}

/** @ghidraAddress 0x17af18 */
- (void)allReleaseDetail {
    // The shipped body is empty.
}

/** @ghidraAddress 0x17af1c */
- (void)clearDetailWindow {
    NSInteger count = (NSInteger)detailWindowArray.count;
    if (count - 1 < 0) {
        return;
    }
    UIView *topWindow = detailWindowArray[count - 1];
    __weak UIView *weakTop = topWindow;
    UIView *secondWindow = nil;
    if (count != 1) {
        secondWindow = detailWindowArray[count - 2];
    }
    __weak UIView *weakCover = coverViewPad;

    [UIView animateWithDuration:kDetailAnimationDuration
        delay:0.0
        options:UIViewAnimationOptionCurveEaseInOut
        animations:^{
          /** @ghidraAddress 0x17b1b4 */
          weakCover.alpha = 0.0;
          weakTop.alpha = 0.0;
          if (count > 1) {
              secondWindow.alpha = 0.0;
          }
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x17b2c8 */
          [weakCover removeFromSuperview];
          for (NSInteger index = count - 1; index >= 0; --index) {
              UIView *window = detailWindowArray[index];
              if (index == 0) {
                  // The root overlay is reset in place and reused on the next open.
                  [(StorePackDetailViewV2 *)window setActive];
                  window.transform = CGAffineTransformMakeTranslation(0.0, 0.0);
                  [window removeFromSuperview];
                  [(StorePackDetailViewV2 *)window removePackInfo];
                  return;
              }
              [window removeFromSuperview];
              [(StorePackDetailViewV2 *)window removePackInfo];
              [detailWindowArray removeObject:window];
          }
        }];
    [UIApplication.sharedApplication performSelector:@selector(endIgnoringInteractionEvents)
                                          withObject:nil
                                          afterDelay:kInteractionUnlockDelay];
}

/** @ghidraAddress 0x17fe98 */
- (void)addOpenDetail:(NSInteger)genreID {
    if ([packTableView.currentGenre packCount]) {
        [packListCtrl startFetchAdditionalPack:@(genreID)];
        [JubeatAppDelegate.appDelegate resetDownloadPackID];
    }
    if (isOpenPackDetail) {
        isOpenPackDetail = NO;
        if (!isPad) {
            [self.navigationController popViewControllerAnimated:NO];
        } else {
            [packDetailViewPad detailClose];
            [packDetailViewPad cancelLoading];
            [packDetailViewPad stopSample];
            coverViewPad.alpha = 0.0;
            packDetailViewPad.alpha = 0.0;
            [coverViewPad removeFromSuperview];
            [packDetailViewPad removeFromSuperview];
            [packDetailViewPad removePackInfo];
        }
    }
    [self dismissViewControllerAnimated:isPad completion:nil];
}

/** @ghidraAddress 0x17c8d4 */
- (void)handleTapCoverView:(UITapGestureRecognizer *)recognizer {
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    [packDetailViewPad cancelLoading];
    [packDetailViewPad stopSample];
    isOpenPackDetail = NO;
    [promotionView thumbnailMute:YES];
    [self clearDetailWindow];
}

/** @ghidraAddress 0x17c980 */
- (void)hideGenreSelect:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

/** @ghidraAddress 0x17d324 */
- (void)handleBackButton:(id)sender {
    bAlreadyBack = YES;
    [promotionView stop];
    [storeViewCtrl storeEnd:sender];
    if (isPad) {
        [packDetailViewPad cancelLoading];
        [packDetailViewPad stopSample];
    }
}

/** @ghidraAddress 0x17fa14 */
- (void)storeClose {
    if (isOpenPackDetail) {
        isOpenPackDetail = NO;
        if (!isPad) {
            UIViewController *top = self.navigationController.topViewController;
            if ([top isKindOfClass:[StoreDetailViewControllerV2 class]]) {
                [(StoreDetailViewControllerV2 *)top detailClose];
            }
        } else {
            [packDetailViewPad detailClose];
            [packDetailViewPad cancelLoading];
            [packDetailViewPad stopSample];
            __weak UIView *weakCover = coverViewPad;
            __weak StorePackDetailViewV2 *weakDetail = packDetailViewPad;
            [UIView animateWithDuration:kDetailAnimationDuration
                delay:0.0
                options:UIViewAnimationOptionCurveEaseInOut
                animations:^{
                  /** @ghidraAddress 0x17fcf4 */
                  weakCover.alpha = 0.0;
                  weakDetail.alpha = 0.0;
                }
                completion:^(BOOL __attribute__((unused)) finished) {
                  /** @ghidraAddress 0x17fdb8 */
                  [weakCover removeFromSuperview];
                  [weakDetail removeFromSuperview];
                  [weakDetail removePackInfo];
                }];
        }
    }
    [AlertViewManager.sharedManager closeAlert];
    [self dismissViewControllerAnimated:isPad completion:nil];
}

#pragma mark - StorePackListDelegate

/** @ghidraAddress 0x17d3fc */
- (void)packListDownloadSuccess:(StorePackListController *)controller
                      isInitial:(BOOL)isInitial
                       showPack:(StorePackInfo *)showPack {
    if (isInitial) {
        CGFloat listHeight = [StoreUtil storeCategoryListHeight];
        CGFloat titleHeight = [StoreUtil storeCategoryTitleHeight];
        if (!isPad) {
            NSArray *genres = packListCtrl.genreInfos;
            NSArray *promotions = packListCtrl.promotions;
            CGFloat viewWidth = self.view.frame.size.width;
            storeHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, viewWidth, 0.0)];
            CGFloat headerWidth = storeHeaderView.frame.size.width;
            CGFloat headerHeight = storeHeaderView.frame.size.height;
            phoneHeaderBaseHeight = 0;
            if (promotions.count) {
                CGFloat promotionHeight =
                    floorf((float)(self.view.frame.size.width * kPhonePromotionAspectNumerator /
                                   kPhonePromotionAspectDenominator));
                promotionView = [[StorePromotionView alloc]
                    initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width, promotionHeight)
                       promotions:promotions];
                promotionView.delegate = self;
                [storeHeaderView addSubview:promotionView];
                loadingView.center =
                    CGPointMake(loadingView.center.x,
                                floorf((float)(promotionHeight * 0.5 + loadingView.center.y)));
                headerHeight += promotionView.frame.size.height;
                storeHeaderView.frame = CGRectMake(0.0, 0.0, headerWidth, headerHeight);
                phoneHeaderBaseHeight =
                    (int)((double)phoneHeaderBaseHeight + promotionView.frame.size.height);
            }
            if (genres.count) {
                categoryListView = [[StoreGenreSelectView alloc]
                    initWithFrame:CGRectMake(0.0, headerHeight, headerWidth, listHeight)
                        genreList:genres];
                headerHeight += listHeight;
                phoneHeaderBaseHeight += (int)listHeight;
                storeHeaderView.frame = CGRectMake(0.0, 0.0, headerWidth, headerHeight);
                categoryListView.delegate = self;
                [storeHeaderView addSubview:categoryListView];

                categoryTitleView = [[StoreGenreTitleView alloc]
                    initWithFrame:CGRectMake(0.0, headerHeight, headerWidth, titleHeight)];
                categoryTitleView.layer.borderColor =
                    [UIColor colorWithWhite:kPadBorderWhite alpha:1.0].CGColor;
                categoryTitleView.layer.borderWidth = kPadContainerBorderWidth;
                [storeHeaderView addSubview:categoryTitleView];
                storeHeaderView.frame =
                    CGRectMake(0.0, 0.0, headerWidth, headerHeight + titleHeight);
            }
            packTableView.tableHeaderView = storeHeaderView;
            [promotionView start];
        } else {
            CGRect tableFrame = packTableView.frame;
            CGFloat listX = tableFrame.origin.x + kPadListLeftInset;
            CGFloat listWidth = tableFrame.size.width + kPadPromotionInset;
            CGFloat listY = tableFrame.origin.y;
            CGFloat packListHeight = tableFrame.size.height;
            NSArray *promotions = packListCtrl.promotions;
            if (promotions.count) {
                promotionView =
                    [[StorePromotionView alloc] initWithFrame:CGRectMake(0.0,
                                                                         kPadPromotionTop,
                                                                         self.view.frame.size.width,
                                                                         kPadPromotionHeight)
                                                   promotions:promotions];
                promotionView.delegate = self;
                [self.view addSubview:promotionView];
                [promotionView start];
                listY += kPadPromotionAdvance;
                packListHeight += kPadPromotionReserved;
            } else {
                listY += kPadListTopNoPromotion;
                packListHeight += kPadPromotionInset;
            }
            NSArray *genres = packListCtrl.genreInfos;
            packListView.frame = CGRectMake(listX, listY, listWidth, packListHeight);
            [self.view addSubview:packListView];
            CGFloat subY = 0.0;
            if (genres.count) {
                categoryListView = [[StoreGenreSelectView alloc]
                    initWithFrame:CGRectMake(0.0, 0.0, listWidth, listHeight)
                        genreList:genres];
                categoryListView.delegate = self;
                [packListView addSubview:categoryListView];
                subY = listHeight;
                packListHeight -= listHeight;

                categoryTitleView = [[StoreGenreTitleView alloc]
                    initWithFrame:CGRectMake(0.0, subY, listWidth, titleHeight)];
                [packListView addSubview:categoryTitleView];
                subY += titleHeight;
                packListHeight -= titleHeight;
            }
            packTableView.frame = CGRectMake(0.0, subY, listWidth, packListHeight);
            loadingView.center = packListView.center;
        }

        packTableView.currentGenre = [packListCtrl packListForGenreIndex:0];
        if (fetchGenreID > 0) {
            packTableView.currentGenre = [packListCtrl packListForGenreID:fetchGenreID];
        }
        (void)packTableView.currentGenre; // Yes, the binary reads this and discards it.
        if ([packListCtrl numGenres] > 1) {
            genreTableViewCtrl =
                [[StoreGenreTableViewController alloc] initWithStyle:UITableViewStylePlain];
            genreTableViewCtrl.tableView.dataSource = self;
            genreTableViewCtrl.tableView.delegate = self;
            genreTableViewCtrl.tableView.rowHeight = kGenrePopoverRowHeight;
            CGFloat popoverHeight = kGenrePopoverMaxHeight;
            if ([packListCtrl numGenres] * kGenrePopoverRowHeight <= kGenrePopoverMaxHeight) {
                popoverHeight = [packListCtrl numGenres] * kGenrePopoverRowHeight;
            }
            genreTableViewCtrl.preferredContentSize = CGSizeMake(kGenrePopoverWidth, popoverHeight);
            genreNavCtrl = [[RotatableNavigationController alloc]
                initWithRootViewController:genreTableViewCtrl];
            genreTableViewCtrl.navigationItem.title =
                [NSBundle.mainBundle localizedStringForKey:kLocKeyCategory
                                                     value:kEmptyValue
                                                     table:nil];
            if (!isPad) {
                for (UIView *barSubview in self.navigationController.navigationBar.subviews) {
                    barSubview.exclusiveTouch = YES;
                }
            }
        }

        BOOL firstRestoreEnd =
            [NSUserDefaults.standardUserDefaults boolForKey:kPrefFirstRestoreEndKey];
        if (!firstRestoreEnd && !bAlreadyBack) {
            [NSUserDefaults.standardUserDefaults setBool:YES forKey:kPrefFirstRestoreEndKey];
            NSString *prodListPath = [JubeatAppDelegate.appDocumentsDirectory
                stringByAppendingPathComponent:kProductListFileName];
            if (![NSFileManager.defaultManager fileExistsAtPath:prodListPath isDirectory:nil]) {
                NSString *message = [NSBundle.mainBundle localizedStringForKey:kLocKeyRestoreCheck
                                                                         value:kEmptyValue
                                                                         table:nil];
                NSString *doRestore = [NSBundle.mainBundle localizedStringForKey:kLocKeyDoRestore
                                                                           value:kEmptyValue
                                                                           table:nil];
                NSString *doAfter = [NSBundle.mainBundle localizedStringForKey:kLocKeyDoAfter
                                                                         value:kEmptyValue
                                                                         table:nil];
                [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                                 delegate:self
                                                      tag:kAlertTagRestore
                                                    title:nil
                                                      msg:message
                                                   cancel:doAfter
                                                  btnText:@[ doRestore ]
                                                     show:YES];
            }
        }
    }

    if (packTableView.superview) {
        [packTableView stopLoadingMore:NO];
    } else {
        [packListView addSubview:packTableView];
        [self.view insertSubview:packListView belowSubview:loadingView];
    }

    int titleHeight = [categoryTitleView setGenreTitleInfo:packTableView.currentGenre];
    if (!isPad) {
        CGRect titleFrame = categoryTitleView.frame;
        categoryTitleView.frame = CGRectMake(
            titleFrame.origin.x, titleFrame.origin.y, titleFrame.size.width, titleHeight);
        storeHeaderView.frame = CGRectMake(titleFrame.origin.x,
                                           titleFrame.origin.y,
                                           titleFrame.size.width,
                                           phoneHeaderBaseHeight + titleHeight);
        packTableView.tableHeaderView = nil;
        packTableView.tableHeaderView = storeHeaderView;
    }
    [packTableView reloadData];
    [loadingView stopLoading];

    if (isPad) {
        __weak StorePackTableView *weakTable = packTableView;
        packTableView.alpha = 0.0;
        [UIView animateWithDuration:kDetailAnimationDuration
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                           /** @ghidraAddress 0x17e7a4 */
                           weakTable.alpha = 1.0;
                         }
                         completion:^(BOOL __attribute__((unused)) finished){
                             /** @ghidraAddress 0x17e7f0 */
                         }];
    }
    if (showPack) {
        [self showDetailForPackInfo:showPack];
    }
}

/** @ghidraAddress 0x17e7f4 */
- (void)additionPackInfoDownloadSuccess:(StorePackListController *)controller
                               showPack:(StorePackInfo *)showPack {
    if (showPack) {
        [self showDetailForPackInfo:showPack];
    }
}

/** @ghidraAddress 0x17e8e0 */
- (void)packListDownloadError:(StorePackListController *)controller
                 errorMessage:(NSString *)errorMessage {
    if (!errorMessage) {
        errorMessage = [NSBundle.mainBundle localizedStringForKey:kLocKeyNetworkErrorMessage
                                                            value:kEmptyValue
                                                            table:nil];
    }
    if (packListView.superview && [packTableView.currentGenre packCount]) {
        NSString *title = [NSBundle.mainBundle localizedStringForKey:kLocKeyError
                                                               value:kEmptyValue
                                                               table:nil];
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                            value:kEmptyValue
                                                            table:nil];
        [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                         delegate:nil
                                              tag:0
                                            title:title
                                              msg:errorMessage
                                           cancel:ok
                                          btnText:nil
                                             show:YES];
        [packTableView stopLoadingMore:YES];
        return;
    }
    [loadingView showError:errorMessage];
}

/** @ghidraAddress 0x17eb68 */
- (void)packListDownloadNothing:(StorePackListController *)controller {
    if (packListView.superview) {
        [packTableView stopLoadingMore:YES];
        return;
    }
    NSString *message = [NSBundle.mainBundle localizedStringForKey:kLocKeyServerErrorMessage
                                                             value:kEmptyValue
                                                             table:nil];
    [loadingView showError:message];
}

#pragma mark - StorePromotionViewDelegate

/** @ghidraAddress 0x17ec58 */
- (void)storePromotionView:(StorePromotionView *)view packSelected:(StorePackInfo *)packInfo {
    if (packInfo) {
        [self showDetailForPackInfo:packInfo];
    }
}

/** @ghidraAddress 0x17ec70 */
- (void)storePromotionView:(StorePromotionView *)view genreSelected:(NSUInteger)genreIndex {
    [self switchToGenre:genreIndex];
}

#pragma mark - StoreGenreSelectViewDelegate

/** @ghidraAddress 0x17ec80 */
- (void)StoreGenreSelectViewDelegateGenreSelected:(NSUInteger)index {
    [self switchToGenre:index];
}

#pragma mark - Pack table / pack detail callbacks

/** @ghidraAddress 0x17ec8c */
- (void)storePackTableViewLoadMore {
    [packListCtrl startFetchGenre:packTableView.currentGenre];
}

/** @ghidraAddress 0x17ecec */
- (void)storePackTableViewShowDetail:(StorePackInfo *)packInfo {
    if (packInfo) {
        [self showDetailForPackInfo:packInfo];
    }
}

/** @ghidraAddress 0x17ed00 */
- (void)storePackDetailViewClose {
    [self handleTapCoverView:nil];
}

/** @ghidraAddress 0x17ed10 */
- (void)storePackDetailViewOpenItunesWithURL:(NSURL *)url {
    if (!url) {
        return;
    }
    NSDictionary *parameters = [StoreUtil affiliateParametersFromURL:url];
    if (!parameters) {
        [UIApplication.sharedApplication openURL:url];
    } else {
        itunesViewCtrl = [[SKStoreProductViewController alloc] init];
        itunesViewCtrl.delegate = self;
        [self presentViewController:itunesViewCtrl
                           animated:YES
                         completion:^{
                           /** @ghidraAddress 0x17ee80 */
                           [itunesViewCtrl loadProductWithParameters:parameters
                                                     completionBlock:nil];
                         }];
    }
}

#pragma mark - Detail-close / recommend tracking

/** @ghidraAddress 0x17c8a8 */
- (void)detailViewCloseNavigation {
    if (!recommendPushFlg) {
        --recommendCnt;
    }
    recommendPushFlg = NO;
}

/** @ghidraAddress 0x179b8c */
- (void)detailViewStartPurchase:(StoreDetailViewControllerV2 *)packInfo {
    StorePackInfo *info = nil;
    if (!isPad) {
        currentPurchaseViewPhone = packInfo;
        info = currentPurchaseViewPhone.packInfo;
    } else {
        currentPurchaseViewPad = (StorePackDetailViewV2 *)packInfo;
        info = currentPurchaseViewPad.packInfo;
    }
    if ([storeViewCtrl respondsToSelector:@selector(detailViewStartPurchase:)]) {
        [storeViewCtrl performSelector:@selector(detailViewStartPurchase:) withObject:info];
    }
}

/** @ghidraAddress 0x179cb0 */
- (void)detailViewStartRedownload:(StoreDetailViewControllerV2 *)packInfo {
    StorePackInfo *info = nil;
    if (!isPad) {
        currentPurchaseViewPhone = packInfo;
        info = currentPurchaseViewPhone.packInfo;
    } else {
        currentPurchaseViewPad = (StorePackDetailViewV2 *)packInfo;
        info = currentPurchaseViewPad.packInfo;
    }
    if ([storeViewCtrl respondsToSelector:@selector(detailViewStartRedownload:)]) {
        [storeViewCtrl performSelector:@selector(detailViewStartRedownload:) withObject:info];
    }
}

#pragma mark - EditorIDManagerDelegate

/** @ghidraAddress 0x180160 */
- (void)successIDDownload:(id)manager {
    idManager = nil;
    [packListCtrl startFetchGenre:packTableView.currentGenre];
}

/** @ghidraAddress 0x1801d8 */
- (void)errorIDDownload:(id)manager msgStr:(NSString *)msgStr {
    idManager = nil;
    [packListCtrl startFetchGenre:packTableView.currentGenre];
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0x17e80c */
- (void)alertSelect:(NSDictionary *)info {
    if ([info[kAlertKeyButtonMessage] intValue] == kAlertButtonRestore) {
        [storeViewCtrl firstRestore];
        self.tabBarController.selectedIndex = kLibraryTabIndex;
    }
}

#pragma mark - SKStoreProductViewControllerDelegate

/** @ghidraAddress 0x17eef0 */
- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    [self dismissViewControllerAnimated:YES
                             completion:^{
                               /** @ghidraAddress 0x17ef58 */
                               itunesViewCtrl = nil;
                             }];
}

#pragma mark - UITableViewDataSource / UITableViewDelegate

/** @ghidraAddress 0x17f1e0 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0x17f1e8 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [packListCtrl numGenres];
}

/** @ghidraAddress 0x17ef80 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kGenreCellReuseIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:kGenreCellReuseIdentifier];
    }
    cell.textLabel.opaque = NO;
    cell.textLabel.backgroundColor = UIColor.clearColor;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:kGenreRowFontSize];
    cell.textLabel.text = [packListCtrl packListForGenreIndex:indexPath.row].genreName;
    return cell;
}

/** @ghidraAddress 0x17f204 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kGenrePopoverRowHeight;
}

/** @ghidraAddress 0x17f200 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
}

/** @ghidraAddress 0x17f210 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self switchToGenre:indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}

// The compiler synthesises .cxx_destruct (0x18027c) to release the strong ivars and destroy the
// weak storeViewCtrl reference; ARC emits it, so no hand-written body appears here.

@end
