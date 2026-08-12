#import "StorePurchasedViewController.h"

#import <StoreKit/StoreKit.h>

#import "AlertViewManager.h"
#import "Downloader.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "PurchaseManager.h"
#import "StoreButton.h"
#import "StoreDetailViewController.h"
#import "StoreLoadingView.h"
#import "StorePackDetailView.h"
#import "StorePackInfo.h"
#import "StorePackListGenre.h"
#import "StorePackTableView.h"
#import "StoreUtil.h"
#import "StoreViewController.h"

// The tab image and the restore-button image.
static NSString *const kTabImageName = @"tab_restore";
static NSString *const kRestoreImageName = @"store_restore";

// The display name of the synthetic genre that holds the resolved purchased packs.
static NSString *const kPurchasedGenreName = @"purchased";

// The catalogue-response dictionary keys read out of a store response.
static NSString *const kResponseKeyPackList = @"PackList";
static NSString *const kResponseKeyVersion = @"Version";
static NSString *const kResponseKeyError = @"Error";
static NSString *const kEntryKeyID = @"ID";

// The synthetic purchased genre's identifier.
static const NSUInteger kPurchasedGenreID = 99999;

// The number of packs resolved per catalogue page.
static const NSUInteger kPackFetchPageSize = 16;

// The animation options for the iPad detail overlay fade: begin from the current state and keep
// user interaction enabled. The binary passes the raw 0x30000.
static const UIViewAnimationOptions kOverlayAnimationOptions =
    UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction;

@implementation StorePurchasedViewController {
    BOOL isPad;
    __weak id<StoreParentViewController> storeViewCtrl;
    StorePackListGenre *purchasedPackList;
    NSMutableArray<NSNumber *> *arrayUnresolvedPackID;
    StorePackTableView *packTableView;
    UIView *coverViewPad;
    StorePackDetailView *packDetailViewPad;
    NSDictionary *tmpPackDict;
    Downloader *packlistDownloader;
    SKProductsRequest *productsRequest;
    StoreLoadingView *loadingView;
    StoreButton *btnRestore;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x1b4324 */
- (instancetype)initWithParent:(id<StoreParentViewController>)parent {
    self = [super init];
    if (self) {
        storeViewCtrl = parent;
        self.navigationItem.title = [NSBundle.mainBundle localizedStringForKey:@"Purchased"
                                                                         value:@""
                                                                         table:nil];
        self.tabBarItem.title = [NSBundle.mainBundle localizedStringForKey:@"Purchased"
                                                                     value:@""
                                                                     table:nil];
        self.tabBarItem.image = LoadScaledPngImage(kTabImageName);
        if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
            [self performSelector:@selector(setExtendedLayoutIncludesOpaqueBars:) withObject:nil];
        }
        isPad = JubeatAppDelegate.appDelegate.isPad;

        UIBarButtonItem *backItem = [[UIBarButtonItem alloc]
            initWithTitle:[NSBundle.mainBundle localizedStringForKey:@"Back" value:@"" table:nil]
                    style:UIBarButtonItemStyleDone
                   target:storeViewCtrl
                   action:@selector(storeEnd:)];
        self.navigationItem.leftBarButtonItem = backItem;

        // The restore button: a red rounded StoreButton in the right bar-button slot.
        btnRestore = [[StoreButton alloc] initWithFrame:CGRectZero];
        btnRestore.buttonColor = UIColor.redColor;
        // fmov immediate at 0x1b46bc.
        btnRestore.cornerRadius = 6.0;
        // fmov immediate at 0x1b46f4.
        btnRestore.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
        // Insets {top, left, bottom, right}; fmov immediates at 0x1b4738/0x1b473c.
        btnRestore.contentEdgeInsets = UIEdgeInsetsMake(3.0, 4.0, 3.0, 6.0);
        /** @ghidraAddress 0x10028f230 */
        [btnRestore setTitleColor:[UIColor colorWithWhite:0.6 alpha:1.0]
                         forState:UIControlStateHighlighted];
        [btnRestore setImage:LoadScaledPngImage(kRestoreImageName) forState:UIControlStateNormal];
        [btnRestore setTitle:[NSBundle.mainBundle localizedStringForKey:@"Restore"
                                                                  value:@""
                                                                  table:nil]
                    forState:UIControlStateNormal];
        [btnRestore sizeToFit];
        [btnRestore addTarget:storeViewCtrl
                       action:@selector(performRestore:)
             forControlEvents:UIControlEventTouchUpInside];
        btnRestore.exclusiveTouch = YES;

        UIBarButtonItem *restoreItem = [[UIBarButtonItem alloc] initWithCustomView:btnRestore];
        restoreItem.enabled = NO;
        self.navigationItem.rightBarButtonItem = restoreItem;
    }
    return self;
}

/** @ghidraAddress 0x1b7374 */
- (void)dealloc {
    // The binary's -dealloc only chains to super: it cancels nothing and removes no observers.
    // The strong ivars and the weak storeViewCtrl are torn down by the compiler-generated
    // .cxx_destruct (0x1b73ac), which is not authored here. [super dealloc] is compiler-emitted
    // (ARC).
}

#pragma mark - Purchased list

/** @ghidraAddress 0x1b4948 */
- (void)resetPurchasedList {
    arrayUnresolvedPackID = nil;
    purchasedPackList = nil;
    packTableView.currentGenre = nil;
    [packTableView clearArtworkCache];
}

/** @ghidraAddress 0x1b49b4 */
- (void)startLoadPurchasedList {
    if (!arrayUnresolvedPackID) {
        arrayUnresolvedPackID = [[NSMutableArray alloc] init];
        [arrayUnresolvedPackID addObjectsFromArray:PurchaseManager.sharedManager.purchasedPackIDs];
        for (NSNumber *pending in PurchaseManager.sharedManager.pendingPackIDs) {
            if ([arrayUnresolvedPackID indexOfObject:pending] == NSNotFound) {
                [arrayUnresolvedPackID addObject:pending];
            }
        }
        // Sort largest identifier first.
        [arrayUnresolvedPackID
            sortUsingComparator:^NSComparisonResult(NSNumber *left, NSNumber *right) {
              /** @ghidraAddress 0x1b4d0c */
              // The polarity is inverted from an ascending comparator, which makes the sort
              // descending. -intValue is a 32-bit comparison.
              int a = left.intValue;
              int b = right.intValue;
              if (a < b) {
                  return NSOrderedDescending;
              }
              if (a > b) {
                  return NSOrderedAscending;
              }
              return NSOrderedSame;
            }];
    }
    [packTableView removeFromSuperview];
    if (arrayUnresolvedPackID.count == 0) {
        [loadingView showError:[NSBundle.mainBundle localizedStringForKey:@"NoPurchasedPacksMsg"
                                                                    value:@""
                                                                    table:nil]];
        btnRestore.enabled = YES;
    } else {
        [loadingView startLoading];
        btnRestore.enabled = NO;
        [self startFetch];
    }
}

/** @ghidraAddress 0x1b4d8c */
- (void)reloadPurchasedList {
    [self resetPurchasedList];
    [self startLoadPurchasedList];
}

#pragma mark - View

/** @ghidraAddress 0x1b4dc0 */
- (void)loadView {
    [super loadView];
    self.view.opaque = YES;
    CGRect bounds = self.view.bounds;

    // A vertical grey gradient filling the whole view.
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = bounds;
    gradient.opaque = YES;
    /** @ghidraAddress 0x10028fad8 */
    UIColor *topColor = [UIColor colorWithRed:0.725 green:0.731 blue:0.737 alpha:1.0];
    /** @ghidraAddress 0x10028faf0 */
    UIColor *bottomColor = [UIColor colorWithRed:0.467 green:0.489 blue:0.511 alpha:1.0];
    gradient.colors = @[ (__bridge id)topColor.CGColor, (__bridge id)bottomColor.CGColor ];
    [self.view.layer addSublayer:gradient];

    CGFloat headerHeight = [StoreUtil storeTabHeaderHeight];
    CGFloat footerHeight = [StoreUtil storeTabFooterHeight];
    CGFloat contentHeight = bounds.size.height - headerHeight - footerHeight;

    // The table frame differs by idiom: the pad inset by 20 on the left/top and 40 on width/height
    // to make room for the in-place detail overlay; the phone fills the content area exactly.
    CGRect tableFrame;
    if (isPad) {
        /** @ghidraAddress 0x10028e078 */
        const CGFloat kPadInset = -40.0;
        // fmov immediate 20.0 at 0x1b5074.
        tableFrame = CGRectMake(bounds.origin.x + 20.0,
                                bounds.origin.y + 20.0,
                                bounds.size.width + kPadInset,
                                contentHeight + kPadInset);

        // The dimming cover fills the whole view and dismisses the overlay on tap.
        coverViewPad = [[UIView alloc] initWithFrame:bounds];
        coverViewPad.opaque = NO;
        // colorWithWhite:0 alpha:0.5 (fmov immediates at 0x1b5128).
        coverViewPad.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        coverViewPad.userInteractionEnabled = YES;
        coverViewPad.exclusiveTouch = YES;
        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self
                                                    action:@selector(handleTapCoverView:)];
        [coverViewPad addGestureRecognizer:tap];

        // The detail overlay: a fixed 600x600 view centred in the content area.
        /** @ghidraAddress 0x100291c30 */
        packDetailViewPad =
            [[StorePackDetailView alloc] initWithFrame:CGRectMake(0.0, 0.0, 600.0, 600.0)];
        // The centre is truncated to whole points, matching the binary's fcvtzs/scvtf pair.
        packDetailViewPad.center =
            CGPointMake((double)(int)(bounds.origin.x + bounds.size.width * 0.5),
                        (double)(int)(bounds.origin.y + contentHeight * 0.5));
        packDetailViewPad.delegate = storeViewCtrl;
        packDetailViewPad.viewController = self;
    } else {
        tableFrame = CGRectMake(bounds.origin.x, bounds.origin.y, bounds.size.width, contentHeight);
    }

    packTableView = [[StorePackTableView alloc] initWithFrame:tableFrame
                                                        style:UITableViewStylePlain];
    packTableView.viewController = self;
    packTableView.currentGenre = purchasedPackList;

    // The loading view is centred in the content area; its own size differs by idiom.
    CGFloat loadingWidth;
    CGFloat loadingHeight;
    if (isPad) {
        /** @ghidraAddress 0x100291d30 */
        loadingWidth = 600.0;
        /** @ghidraAddress 0x100291c50 */
        loadingHeight = 140.0;
    } else {
        /** @ghidraAddress 0x100291d38 */
        loadingWidth = 300.0;
        /** @ghidraAddress 0x100291c58 */
        loadingHeight = 200.0;
    }
    loadingView =
        [[StoreLoadingView alloc] initWithFrame:CGRectMake(0.0, 0.0, loadingWidth, loadingHeight)];
    // Centre truncated to whole points against the full view width and content height.
    loadingView.center =
        CGPointMake((double)((int)bounds.size.width / 2), (double)((int)contentHeight / 2));
    loadingView.hidden = YES;
    [self.view addSubview:loadingView];
}

#pragma mark - Purchase state

/** @ghidraAddress 0x1b546c */
- (void)updatePurchaseStateForPackID:(int)packID {
    if (!isPad) {
        UIViewController *top = self.navigationController.topViewController;
        if ([top isKindOfClass:[StoreDetailViewController class]]) {
            [(StoreDetailViewController *)top updatePurchaseState];
        }
        return;
    }
    [packDetailViewPad updatePurchaseState];
    NSUInteger count = packTableView.currentGenre.packCount;
    for (NSUInteger index = 0; index < count; ++index) {
        StorePackInfo *info = (StorePackInfo *)[packTableView.currentGenre packInfoForIndex:index];
        if (info.packID == packID) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
            [packTableView reloadRowsAtIndexPaths:@[ indexPath ]
                                 withRowAnimation:UITableViewRowAnimationNone];
            break;
        }
        count = packTableView.currentGenre.packCount;
    }
}

#pragma mark - iPad overlay

/** @ghidraAddress 0x1b5738 */
- (void)handleTapCoverView:(UITapGestureRecognizer *)recognizer {
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    [packDetailViewPad cancelLoading];
    [packDetailViewPad stopSample];
    btnRestore.enabled = YES;

    __weak UIView *weakCover = coverViewPad;
    __weak StorePackDetailView *weakDetail = packDetailViewPad;
    // duration 0.3, delay 0 (both at 0x10028f260 / fixed zero).
    [UIView animateWithDuration:0.3
        delay:0
        options:kOverlayAnimationOptions
        animations:^{
          /** @ghidraAddress 0x1b599c */
          weakCover.alpha = 0.0;
          weakDetail.alpha = 0.0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x1b5a60 */
          [weakCover removeFromSuperview];
          [weakDetail removeFromSuperview];
          [weakDetail removePackInfo];
        }];
    // Re-enable input 0.4s later (delay at 0x10028f268).
    [UIApplication.sharedApplication performSelector:@selector(endIgnoringInteractionEvents)
                                          withObject:nil
                                          afterDelay:0.4];
}

#pragma mark - Fetching

/** @ghidraAddress 0x1b5b40 */
- (void)startFetch {
    if (arrayUnresolvedPackID.count == 0) {
        return;
    }
    NSArray *batch;
    if (arrayUnresolvedPackID.count < kPackFetchPageSize) {
        batch = [[NSArray alloc] initWithArray:arrayUnresolvedPackID copyItems:NO];
    } else {
        batch = [arrayUnresolvedPackID subarrayWithRange:NSMakeRange(0, kPackFetchPageSize)];
    }
    NSURL *url = [StoreUtil selectivePackListURL:batch];
    packlistDownloader = [[Downloader alloc] initWithURL:url delegate:self];
    [packlistDownloader startDownloading];
}

/** @ghidraAddress 0x1b5c84 */
- (void)cancelFetching {
    if (packlistDownloader) {
        [packlistDownloader cancel];
        packlistDownloader = nil;
    }
    if (productsRequest) {
        [productsRequest cancel];
        productsRequest = nil;
    }
}

/** @ghidraAddress 0x1b5cf8 */
- (void)showError:(NSString *)message {
    if (!message) {
        message = [NSBundle.mainBundle localizedStringForKey:@"NetworkErrorMsg"
                                                       value:@""
                                                       table:nil];
    }
    if (!packTableView.superview) {
        [packTableView removeFromSuperview];
        [loadingView showError:message];
    } else {
        [AlertViewManager.sharedManager
            makeAlert:0
             delegate:nil
                  tag:0
                title:[NSBundle.mainBundle localizedStringForKey:@"Error" value:@"" table:nil]
                  msg:message
               cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
              btnText:nil
                 show:YES];
        [packTableView stopLoadingMore:YES];
    }
}

#pragma mark - StorePackTableView delegate

/** @ghidraAddress 0x1b5f44 */
- (void)storePackTableViewLoadMore {
    [self startFetch];
}

/** @ghidraAddress 0x1b5f50 */
- (void)storePackTableViewShowDetail:(StorePackInfo *)packInfo {
    if (!packInfo) {
        return;
    }
    if (!isPad) {
        StoreDetailViewController *detail = [[StoreDetailViewController alloc] init];
        detail.delegate = storeViewCtrl;
        detail.bRestore = YES;
        detail.packInfo = packInfo;
        [self.navigationController pushViewController:detail animated:YES];
        return;
    }
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    coverViewPad.alpha = 0.0;
    packDetailViewPad.alpha = 0.0;
    [self.view addSubview:coverViewPad];
    [self.view addSubview:packDetailViewPad];
    btnRestore.enabled = NO;
    packDetailViewPad.packInfo = packInfo;

    __weak UIView *weakCover = coverViewPad;
    __weak StorePackDetailView *weakDetail = packDetailViewPad;
    [UIView animateWithDuration:0.3
        delay:0
        options:kOverlayAnimationOptions
        animations:^{
          /** @ghidraAddress 0x1b62ec */
          weakCover.alpha = 1.0;
          weakDetail.alpha = 1.0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x1b63bc */
          [weakDetail loadRestoreInfo];
        }];
    [UIApplication.sharedApplication performSelector:@selector(endIgnoringInteractionEvents)
                                          withObject:nil
                                          afterDelay:0.4];
}

/** @ghidraAddress 0x1b6404 */
- (void)storePackDetailViewClose {
    [self handleTapCoverView:nil];
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x1b6414 */
- (void)downloaderFinished:(id)downloader {
    NSDictionary *response = [StoreUtil checkStoreResponse:[downloader getData]];
    NSArray *packList = response[kResponseKeyPackList];
    NSString *serverVersion = response[kResponseKeyVersion];
    NSString *appVersion = JubeatAppDelegate.appVersion;
    if (!appVersion ||
        (serverVersion && [appVersion compare:serverVersion
                                      options:NSNumericSearch] == NSOrderedAscending)) {
        btnRestore.enabled = YES;
        // The binary passes the localised string itself as the format with no varargs.
        NSString *message = [NSString
            stringWithFormat:[NSBundle.mainBundle localizedStringForKey:@"ServerOldVersionMsg"
                                                                  value:@""
                                                                  table:nil]];
        [self showError:message];
    } else if (packList.count != 0) {
        NSMutableSet *productIDs = [[NSMutableSet alloc] init];
        for (NSDictionary *entry in packList) {
            NSNumber *packID = entry[kEntryKeyID];
            if (packID) {
                [productIDs addObject:[StoreUtil productIDForPackID:packID.intValue]];
            }
        }
        if (productIDs.count == 0) {
            btnRestore.enabled = YES;
            [self showError:[NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                                 value:@""
                                                                 table:nil]];
        } else {
            tmpPackDict = [[NSDictionary alloc] initWithDictionary:response];
            productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIDs];
            productsRequest.delegate = self;
            [productsRequest start];
        }
    } else {
        btnRestore.enabled = YES;
        NSString *message = response[kResponseKeyError];
        if (!message) {
            message = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                           value:@""
                                                           table:nil];
        }
        [self showError:message];
    }
    packlistDownloader = nil;
}

/** @ghidraAddress 0x1b69c8 */
- (void)downloaderError:(id)downloader {
    [self showError:[NSBundle.mainBundle localizedStringForKey:@"NetworkErrorMsg"
                                                         value:@""
                                                         table:nil]];
    btnRestore.enabled = YES;
    packlistDownloader = nil;
}

/** @ghidraAddress 0x1b6a88 */
- (void)downloaderProceed:(id)downloader {
}

#pragma mark - SKProductsRequestDelegate

/** @ghidraAddress 0x1b6a8c */
- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response {
    NSMutableArray<StorePackInfo *> *resolvedPacks = [[NSMutableArray alloc] init];
    for (NSDictionary *entry in tmpPackDict[kResponseKeyPackList]) {
        for (SKProduct *product in response.products) {
            if ([StoreUtil packIDForProductID:product.productIdentifier] ==
                [entry[kEntryKeyID] intValue]) {
                StorePackInfo *built = [[StorePackInfo alloc] initWithDictionary:entry
                                                                         product:product];
                if (built) {
                    [resolvedPacks addObject:built];
                }
                break;
            }
        }
    }
    tmpPackDict = nil;

    // Drop the packs just resolved (a whole page) off the front of the unresolved queue.
    if (arrayUnresolvedPackID.count < kPackFetchPageSize + 1) {
        [arrayUnresolvedPackID removeAllObjects];
    } else {
        [arrayUnresolvedPackID removeObjectsInRange:NSMakeRange(0, kPackFetchPageSize)];
    }
    btnRestore.enabled = YES;

    if (resolvedPacks.count != 0) {
        if (!purchasedPackList) {
            purchasedPackList = [[StorePackListGenre alloc] initWithName:kPurchasedGenreName
                                                                 genreID:kPurchasedGenreID];
            packTableView.currentGenre = purchasedPackList;
        }
        [purchasedPackList updateList:resolvedPacks
                                 step:kPackFetchPageSize
                              hasNext:arrayUnresolvedPackID.count != 0];
        [loadingView stopLoading];
        if (!packTableView.superview) {
            [self.view addSubview:packTableView];
        } else {
            [packTableView stopLoadingMore:NO];
        }
        [packTableView reloadData];
    }
}

/** @ghidraAddress 0x1b6f80 */
- (void)requestDidFinish:(SKRequest *)request {
    productsRequest = nil;
}

/** @ghidraAddress 0x1b6f98 */
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    btnRestore.enabled = YES;
    productsRequest = nil;
    tmpPackDict = nil;
}

#pragma mark - Lifecycle callbacks

/** @ghidraAddress 0x1b6ff4 */
- (void)viewDidUnload {
    [super viewDidUnload];
}

/** @ghidraAddress 0x1b702c */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!isPad) {
        NSIndexPath *selected;
        if (packTableView.superview && (selected = packTableView.indexPathForSelectedRow)) {
            [packTableView reloadRowsAtIndexPaths:@[ selected ]
                                 withRowAnimation:UITableViewRowAnimationNone];
            [packTableView deselectRowAtIndexPath:selected animated:animated];
        }
    } else {
        if (packDetailViewPad) {
            [packDetailViewPad updatePurchaseState];
        }
    }
}

/** @ghidraAddress 0x1b71a8 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!purchasedPackList) {
        [self startLoadPurchasedList];
    }
}

/** @ghidraAddress 0x1b720c */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (isPad) {
        [packDetailViewPad cancelLoading];
        [packDetailViewPad stopSample];
    }
    if (packlistDownloader || productsRequest) {
        [packTableView stopLoadingMore:YES];
    }
    [self cancelFetching];
}

/** @ghidraAddress 0x1b72d4 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Alert dismissal

/** @ghidraAddress 0x1b730c */
- (void)storeClose {
    [AlertViewManager.sharedManager closeAlert];
}

#pragma mark - Rotation

/** @ghidraAddress 0x1b7354 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Compiled to the unsigned range test (orientation - 1) < 2: the two portrait orientations.
    return UIInterfaceOrientationIsPortrait(interfaceOrientation);
}

/** @ghidraAddress 0x1b7364 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x1b736c */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
