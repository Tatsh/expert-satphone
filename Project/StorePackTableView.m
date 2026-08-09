#import "StorePackTableView.h"

#import "ImageCache.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "StorePackCell.h"
#import "StorePackInfo.h"
#import "StorePackListGenre.h"
#import "StorePackView.h"
#import "StoreTableCell.h"

// Reuse identifiers, one pack-cell class per idiom plus the shared "load more" row.
static NSString *const kPacklistCellPadReuseID = @"StorePacklistCellPad";
static NSString *const kPacklistCellPhoneReuseID = @"StorePacklistCellPhone";
static NSString *const kPacklistMoreCellReuseID = @"StorePacklistMoreCell";

// The four resizable pack-background images: plain and extended, alternating by row parity.
static NSString *const kPackBgImage0Name = @"store_pack_bg_0";
static NSString *const kPackBgImage1Name = @"store_pack_bg_1";
static NSString *const kPackBgImage0AddName = @"store_pack_bg_0_2";
static NSString *const kPackBgImage1AddName = @"store_pack_bg_1_2";
static NSString *const kDefaultArtworkName = @"store_jacket_128";

// The user-defaults key that suppresses the drag/deceleration "list scrolled" notification.
static NSString *const kNavigationTapPrefKey = @"PrefStoreNavigationTap";

// The pack-background images are stretched with a uniform four-point cap inset (fmov immediate at
// 0x1b1254).
static const CGFloat kPackBgCapInset = 4.0;

// The artwork cache keeps at most this many decoded images (mov immediate at 0x1b121c).
static const NSUInteger kArtworkCacheCountLimit = 128;

// The artwork request timeout (fmov immediate at 0x1b1650).
static const NSTimeInterval kDownloadTimeout = 10.0;

// The "load more" prompt font size, larger on iPad (fmov immediates at 0x1b2550 and 0x1b254c).
static const CGFloat kMoreCellFontSizePad = 18.0;
static const CGFloat kMoreCellFontSizePhone = 15.0;

// The grey of the "Loading..." prompt while a page is downloading. @ghidraAddress 0x28f2c0
static const CGFloat kLoadingTextWhite = 0.4;

// The "load more" spinner is a square accessory view (fmov immediate at 0x1b304c/0x1b25f0).
static const CGFloat kSpinnerSize = 24.0;

// The opaque backdrop the table paints behind its clear cells (@ghidraAddress 0x291d20), and the
// iPad-only decorations: a one-point border in a lighter grey (@ghidraAddress 0x28f240), a
// one-point border width (fmov immediate at 0x1b1254), a ten-point vertical scroll-indicator inset
// (fmov immediate at 0x1b1158), the per-cell grey backdrop (fmov immediate at 0x1b2b34), and the
// grey of the "load more" cell (@ghidraAddress 0x28f230).
static const CGFloat kTableBackgroundWhite = 0.45;
static const CGFloat kPadBorderWhite = 0.2;
static const CGFloat kPadBorderWidth = 1.0;
static const CGFloat kPadScrollIndicatorInset = 10.0;
static const CGFloat kPadCellBackgroundWhite = 0.5;
static const CGFloat kMoreCellBackgroundWhite = 0.6;

// Row heights, selected by idiom and by whether the row is a pack row or the "load more" row. The
// placeholder ("load more") height is shared by both idioms; the valid-row height differs.
// @ghidraAddress 0x292e30 (pad table), 0x292e40 (phone table).
static const CGFloat kRowHeightPlaceholder = 60.0;
static const CGFloat kRowHeightValidPad = 124.0;
static const CGFloat kRowHeightValidPhone = 80.0;

@implementation StorePackTableView {
    UIImage *packBgImage0;
    UIImage *packBgImage1;
    UIImage *packBgImage0Add;
    UIImage *packBgImage1Add;
    UIImage *defaultArtwork;
    NSOperationQueue *operationQueue;
    NSCache *artworkCache;
    NSMutableArray *downloadingList;
    BOOL isLoadingMoreList;
    BOOL isPad;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x1b0eb8 */
- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style {
    self = [super initWithFrame:frame style:style];
    if (self) {
        isPad = JubeatAppDelegate.appDelegate.isPad;
        self.opaque = YES;
        // The binary builds this with colorWithWhite:0.45 alpha:1.0.
        self.backgroundColor = [UIColor colorWithWhite:kTableBackgroundWhite alpha:1.0];
        self.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.dataSource = self;
        self.delegate = self;
        self.scrollsToTop = YES;
        // The registerClass: guard is an old-iOS availability check kept from the binary.
        if ([self respondsToSelector:@selector(registerClass:forCellReuseIdentifier:)]) {
            if (isPad) {
                [self registerClass:[StoreTableCell class]
                    forCellReuseIdentifier:kPacklistCellPadReuseID];
            } else {
                [self registerClass:[StorePackCell class]
                    forCellReuseIdentifier:kPacklistCellPhoneReuseID];
            }
            [self registerClass:[UITableViewCell class]
                forCellReuseIdentifier:kPacklistMoreCellReuseID];
        }
        if (isPad) {
            // The binary builds this border with colorWithWhite:0.2 alpha:1.0.
            self.layer.borderColor = [UIColor colorWithWhite:kPadBorderWhite alpha:1.0].CGColor;
            self.layer.borderWidth = kPadBorderWidth;
            self.scrollIndicatorInsets =
                UIEdgeInsetsMake(kPadScrollIndicatorInset, 0, kPadScrollIndicatorInset, 0);
        }
        operationQueue = [[NSOperationQueue alloc] init];
        downloadingList = [[NSMutableArray alloc] init];
        artworkCache = [[NSCache alloc] init];
        artworkCache.countLimit = kArtworkCacheCountLimit;
        artworkCache.delegate = self;
        const UIEdgeInsets caps =
            UIEdgeInsetsMake(kPackBgCapInset, kPackBgCapInset, kPackBgCapInset, kPackBgCapInset);
        packBgImage0 = [LoadScaledPngImage(kPackBgImage0Name) resizableImageWithCapInsets:caps];
        packBgImage1 = [LoadScaledPngImage(kPackBgImage1Name) resizableImageWithCapInsets:caps];
        packBgImage0Add =
            [LoadScaledPngImage(kPackBgImage0AddName) resizableImageWithCapInsets:caps];
        packBgImage1Add =
            [LoadScaledPngImage(kPackBgImage1AddName) resizableImageWithCapInsets:caps];
        defaultArtwork = [ImageCache.sharedCache getResPNG:kDefaultArtworkName];
    }
    return self;
}

/** @ghidraAddress 0x1b3618 */
- (void)dealloc {
    [self clearArtworkCache];
    artworkCache.delegate = nil;
    // ARC emits the [super dealloc] the binary performs here.
}

#pragma mark - Loading state

/** @ghidraAddress 0x1b1420 */
- (void)stopLoadingMore:(BOOL)reload {
    if (isLoadingMoreList) {
        isLoadingMoreList = NO;
        self.allowsSelection = YES;
        if (reload && self.currentGenre.packlistContinued) {
            // Refresh the "load more" row, which sits just past the last pack row, so it shows the
            // prompt again in place of the spinner.
            NSIndexPath *moreRow = [NSIndexPath indexPathForRow:[self numPackRows] inSection:0];
            [self reloadRowsAtIndexPaths:@[ moreRow ] withRowAnimation:UITableViewRowAnimationNone];
        }
    }
}

/** @ghidraAddress 0x1b1570 */
- (void)clearArtworkCache {
    [artworkCache removeAllObjects];
    [operationQueue cancelAllOperations];
    [downloadingList removeAllObjects];
}

#pragma mark - Artwork download

/** @ghidraAddress 0x1b15d0 */
- (void)downloadImageSync:(NSArray *)arg {
    @autoreleasepool {
        NSURL *url = arg[0];
        NSIndexPath *slot = arg[1];
        NSMutableURLRequest *request =
            [NSMutableURLRequest requestWithURL:url
                                    cachePolicy:NSURLRequestUseProtocolCachePolicy
                                timeoutInterval:kDownloadTimeout];
        [request setValue:JubeatAppDelegate.appDelegate.userAgent forHTTPHeaderField:@"User-Agent"];
        NSURLSessionDataTask *task = [NSURLSession.sharedSession
            dataTaskWithRequest:request
              completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                /** @ghidraAddress 0x1b17d0 */
                // The response and error are unused: a transport failure is detected only via nil
                // data, and a nil data leaves the slot in downloadingList (no main-queue hop).
                if (data == nil) {
                    return;
                }
                UIImage *image = [[UIImage alloc] initWithData:data];
                if (image != nil && UIScreen.mainScreen.scale != 1.0) {
                    image = [UIImage imageWithCGImage:image.CGImage
                                                scale:UIScreen.mainScreen.scale
                                          orientation:UIImageOrientationUp];
                }
                if (image != nil) {
                    [artworkCache setObject:image forKey:slot];
                }
                // The main-queue hop runs even when the decode failed, so the slot is always
                // removed from downloadingList and a failed download does not wedge it.
                dispatch_async(dispatch_get_main_queue(), ^{
                  /** @ghidraAddress 0x1b19b8 */
                  // Staleness guard: the slot's section carries the genre this download began for.
                  // If the table has since moved to a different genre, leave the image cached and
                  // the slot in flight (the removal below is inside this guard).
                  if (slot.section != (NSInteger)self.currentGenre.genreID) {
                      return;
                  }
                  UIImage *cached = [artworkCache objectForKey:slot];
                  if (cached != nil) {
                      if (isPad) {
                          // Two packs per row: an even slot is the left tile, an odd one the
                          // right. Round the row toward zero for the pairing.
                          NSInteger packRow = slot.row;
                          if (packRow < 0) {
                              packRow += 1;
                          }
                          NSIndexPath *ip = [NSIndexPath indexPathForRow:packRow >> 1 inSection:0];
                          StoreTableCell *cell = (StoreTableCell *)[self cellForRowAtIndexPath:ip];
                          if (cell != nil) {
                              StorePackView *tile =
                                  (slot.row & 1) == 0 ? cell.leftPackView : cell.rightPackView;
                              tile.artworkView.image = cached;
                          }
                      } else {
                          NSIndexPath *ip = [NSIndexPath indexPathForRow:slot.row inSection:0];
                          StorePackCell *cell = (StorePackCell *)[self cellForRowAtIndexPath:ip];
                          if (cell != nil) {
                              cell.artworkView.image = cached;
                          }
                      }
                  }
                  [downloadingList removeObject:slot];
                });
              }];
        [task resume];
    }
}

#pragma mark - Data

/** @ghidraAddress 0x1b1e04 */
- (NSInteger)numPackRows {
    NSInteger count = self.currentGenre.packCount;
    if (isPad) {
        // Two packs per row on iPad, rounded up.
        count = (count + 1) >> 1;
    }
    return count;
}

/** @ghidraAddress 0x1b1e70 */
- (void)setupPackView:(id)view index:(NSUInteger)index {
    StorePackInfo *pack = (StorePackInfo *)[self.currentGenre packInfoForIndex:index];
    NSIndexPath *key = [NSIndexPath indexPathForRow:index inSection:self.currentGenre.genreID];
    UIImage *artwork = [artworkCache objectForKey:key];
    if (artwork == nil) {
        artwork = defaultArtwork;
        if ([downloadingList indexOfObject:key] == NSNotFound && pack.artworkURL != nil) {
            NSURL *url = [NSURL URLWithString:pack.artworkURL];
            if (url != nil) {
                NSArray *args = @[ url, key ];
                NSInvocationOperation *op =
                    [[NSInvocationOperation alloc] initWithTarget:self
                                                         selector:@selector(downloadImageSync:)
                                                           object:args];
                [downloadingList addObject:key];
                [operationQueue addOperation:op];
            }
        }
    }
    if ([view isKindOfClass:[StorePackView class]]) {
        StorePackView *tile = view;
        [tile loadPackInfo:pack index:index];
        tile.artworkView.image = artwork;
    } else if ([view isKindOfClass:[StorePackCell class]]) {
        StorePackCell *cell = view;
        [cell loadPackInfo:pack];
        cell.artworkView.image = artwork;
    }
}

/** @ghidraAddress 0x1b294c */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0x1b2954 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // A further catalogue page adds the trailing "load more" row.
    return [self numPackRows] + (self.currentGenre.packlistContinued ? 1 : 0);
}

/** @ghidraAddress 0x1b29b8 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    const BOOL isPackRow = indexPath.row < [self numPackRows];
    if (isPad) {
        return isPackRow ? kRowHeightValidPad : kRowHeightPlaceholder;
    }
    return isPackRow ? kRowHeightValidPhone : kRowHeightPlaceholder;
}

/** @ghidraAddress 0x1b223c */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    if (indexPath.row < [self numPackRows]) {
        if (isPad) {
            StoreTableCell *packCell = (StoreTableCell *)[tableView
                dequeueReusableCellWithIdentifier:kPacklistCellPadReuseID];
            if (packCell == nil) {
                packCell = [[StoreTableCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                 reuseIdentifier:kPacklistCellPadReuseID];
            }
            packCell.leftPackView.delegate = self;
            packCell.rightPackView.delegate = self;
            [self setupPackView:packCell.leftPackView index:indexPath.row << 1];
            if ((indexPath.row << 1 | 1) < (NSInteger)self.currentGenre.packCount) {
                packCell.rightPackView.hidden = NO;
                [self setupPackView:packCell.rightPackView index:indexPath.row << 1 | 1];
            } else {
                packCell.rightPackView.hidden = YES;
            }
            cell = packCell;
        } else {
            StorePackCell *packCell = (StorePackCell *)[tableView
                dequeueReusableCellWithIdentifier:kPacklistCellPhoneReuseID];
            if (packCell == nil) {
                packCell = [[StorePackCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                reuseIdentifier:kPacklistCellPhoneReuseID];
            }
            [self setupPackView:packCell index:indexPath.row];
            cell = packCell;
        }
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:kPacklistMoreCellReuseID];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:kPacklistMoreCellReuseID];
        }
        cell.textLabel.font =
            [UIFont boldSystemFontOfSize:isPad ? kMoreCellFontSizePad : kMoreCellFontSizePhone];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        if (isLoadingMoreList) {
            UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
                initWithFrame:CGRectMake(0, 0, kSpinnerSize, kSpinnerSize)];
            spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
            cell.accessoryView = spinner;
            [spinner startAnimating];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.textColor = [UIColor colorWithWhite:kLoadingTextWhite alpha:1.0];
            cell.textLabel.text = NSLocalizedString(@"Loading...", @"");
        } else {
            cell.accessoryView = nil;
            cell.textLabel.textColor = UIColor.blackColor;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.textLabel.text = NSLocalizedString(@"ShowMore", @"");
        }
    }
    return cell;
}

#pragma mark - Display

/** @ghidraAddress 0x1b2a3c */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < [self numPackRows]) {
        UIImage *bgImage = (indexPath.row & 1) ? packBgImage1 : packBgImage0;
        UIImage *bgImageAdd = (indexPath.row & 1) ? packBgImage1Add : packBgImage0Add;
        if (isPad) {
            // The binary builds this backdrop with colorWithWhite:0.5 alpha:1.0.
            cell.backgroundColor = [UIColor colorWithWhite:kPadCellBackgroundWhite alpha:1.0];
            StoreTableCell *packCell = (StoreTableCell *)cell;
            StorePackInfo *leftPack =
                (StorePackInfo *)[self.currentGenre packInfoForIndex:indexPath.row << 1];
            [packCell.leftPackView setBgImage:leftPack.hasExtend ? bgImageAdd : bgImage];
            StorePackInfo *rightPack =
                (StorePackInfo *)[self.currentGenre packInfoForIndex:indexPath.row << 1 | 1];
            [packCell.rightPackView setBgImage:rightPack.hasExtend ? bgImageAdd : bgImage];
        } else {
            StorePackInfo *pack =
                (StorePackInfo *)[self.currentGenre packInfoForIndex:indexPath.row];
            StorePackCell *packCell = (StorePackCell *)cell;
            [packCell setBgImage:pack.hasExtend ? bgImageAdd : bgImage];
        }
    } else {
        // The binary builds this backdrop with colorWithWhite:0.6 alpha:1.0.
        cell.backgroundColor = [UIColor colorWithWhite:kMoreCellBackgroundWhite alpha:1.0];
    }
}

#pragma mark - Selection

/** @ghidraAddress 0x1b1cd0 */
- (void)storePackViewSelected:(id)packView {
    if (self.allowsSelection) {
        NSNumber *pack = [self.currentGenre packInfoForIndex:[packView index]];
        if (pack != nil &&
            [self.viewController respondsToSelector:@selector(storePackTableViewShowDetail:)]) {
            [self.viewController performSelector:@selector(storePackTableViewShowDetail:)
                                      withObject:pack];
        }
    }
}

/** @ghidraAddress 0x1b2e00 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == [self numPackRows]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self selectLoadMoreCell:[tableView cellForRowAtIndexPath:indexPath]];
    } else if (!isPad) {
        // iPad rows report their taps through the tile delegate instead.
        if ([self.viewController respondsToSelector:@selector(storePackTableViewShowDetail:)]) {
            NSNumber *pack = [self.currentGenre packInfoForIndex:indexPath.row];
            [self.viewController performSelector:@selector(storePackTableViewShowDetail:)
                                      withObject:pack];
        }
    }
}

/** @ghidraAddress 0x1b2fc8 */
- (void)selectLoadMoreCell:(UITableViewCell *)cell {
    if (isLoadingMoreList) {
        return;
    }
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithFrame:CGRectZero];
    spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
    cell.accessoryView = spinner;
    [spinner startAnimating];
    cell.textLabel.textColor = [UIColor colorWithWhite:kLoadingTextWhite alpha:1.0];
    cell.textLabel.text = NSLocalizedString(@"Loading...", @"");
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    isLoadingMoreList = YES;
    if ([self.viewController respondsToSelector:@selector(storePackTableViewLoadMore)]) {
        [self.viewController performSelector:@selector(storePackTableViewLoadMore)];
    }
}

#pragma mark - Scrolling

/** @ghidraAddress 0x1b3250 */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (!self.currentGenre.packlistContinued) {
        return;
    }
    if (!isLoadingMoreList) {
        // Trigger the fetch once the content is scrolled to its bottom edge: offset.y is at or
        // past the content height minus the frame height.
        if (self.contentOffset.y >= self.contentSize.height - self.frame.size.height) {
            NSIndexPath *moreRow = [NSIndexPath indexPathForRow:[self numPackRows] inSection:0];
            [self selectLoadMoreCell:[self cellForRowAtIndexPath:moreRow]];
        }
    }
}

/** @ghidraAddress 0x1b3390 */
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (isPad) {
        return;
    }
    if ([NSUserDefaults.standardUserDefaults boolForKey:kNavigationTapPrefKey]) {
        return;
    }
    // A downward drag past the frame height reports the list scrolled.
    if (self.contentOffset.y > self.frame.size.height) {
        if ([self.viewController respondsToSelector:@selector(packListScrolled)]) {
            [self.viewController performSelector:@selector(packListScrolled)];
        }
    }
}

/** @ghidraAddress 0x1b34d0 */
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (isPad || decelerate) {
        return;
    }
    if ([NSUserDefaults.standardUserDefaults boolForKey:kNavigationTapPrefKey]) {
        return;
    }
    if (self.contentOffset.y > self.frame.size.height) {
        if ([self.viewController respondsToSelector:@selector(packListScrolled)]) {
            [self.viewController performSelector:@selector(packListScrolled)];
        }
    }
}

#pragma mark - NSCacheDelegate

/** @ghidraAddress 0x1b3614 */
- (void)cache:(NSCache *)cache willEvictObject:(id)obj {
}

@end
