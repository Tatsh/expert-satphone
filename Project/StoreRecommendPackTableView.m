#import "StoreRecommendPackTableView.h"

#import "ImageCache.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "StorePackCell.h"
#import "StorePackInfo.h"
#import "StoreRecommendPackView.h"
#import "StoreRecommendTableCell.h"

// Reuse identifiers, one pack-cell class per idiom plus the shared "load more" row.
static NSString *const kPacklistCellPhoneReuseID = @"StoreRecommendPacklistCellPhone";
static NSString *const kPacklistCellPadReuseID = @"StoreRecommendPacklistCellPad";
static NSString *const kPacklistMoreCellReuseID = @"StoreRecommendPacklistMoreCell";

// The four resizable pack-background images: plain and extended, alternating by row parity.
static NSString *const kPackBgImage0Name = @"store_pack_bg_0";
static NSString *const kPackBgImage1Name = @"store_pack_bg_1";
static NSString *const kPackBgImage0AddName = @"store_pack_bg_0_2";
static NSString *const kPackBgImage1AddName = @"store_pack_bg_1_2";
static NSString *const kDefaultArtworkName = @"store_jacket_128";

// The pack-background images are stretched with a uniform four-point cap inset (fmov immediate at
// 0x212804).
static const CGFloat kPackBgCapInset = 4.0;

// The artwork cache keeps at most this many decoded images.
static const NSUInteger kArtworkCacheCountLimit = 128;

// The artwork request timeout (fmov immediate at 0x212ad4).
static const NSTimeInterval kDownloadTimeout = 10.0;

// The "load more" prompt font size, larger on iPad (fmov immediates at 0x2139e8 and 0x2139e4).
static const CGFloat kMoreCellFontSizePad = 18.0;
static const CGFloat kMoreCellFontSizePhone = 15.0;

// The grey of the "Loading..." prompt while a page is downloading.
static const CGFloat kLoadingTextWhite = 0.4; // @ghidraAddress 0x28f2c0

// The "load more" spinner is a square accessory view (fmov immediate at 0x213a88).
static const CGFloat kSpinnerSize = 24.0;

// Row heights, selected by idiom and by whether the row is a pack row or the "load more" row. The
// placeholder ("load more") height is shared by both idioms; the valid-row height differs.
// @ghidraAddress 0x292e30 (pad table), 0x292e40 (phone table).
static const CGFloat kRowHeightPlaceholder = 60.0;
static const CGFloat kRowHeightValidPad = 124.0;
static const CGFloat kRowHeightValidPhone = 80.0;

@implementation StoreRecommendPackTableView {
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

/** @ghidraAddress 0x212540 */
- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style {
    self = [super initWithFrame:frame style:style];
    if (self) {
        isPad = JubeatAppDelegate.appDelegate.isPad;
        self.opaque = YES;
        self.backgroundColor = UIColor.clearColor;
        self.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.dataSource = self;
        self.delegate = self;
        self.scrollsToTop = YES;
        self.bounces = YES;
        // The registerClass: guard is an old-iOS availability check kept from the binary.
        if ([self respondsToSelector:@selector(registerClass:forCellReuseIdentifier:)]) {
            if (isPad) {
                [self registerClass:[StoreRecommendTableCell class]
                    forCellReuseIdentifier:kPacklistCellPadReuseID];
            } else {
                [self registerClass:[StorePackCell class]
                    forCellReuseIdentifier:kPacklistCellPhoneReuseID];
            }
            [self registerClass:[UITableViewCell class]
                forCellReuseIdentifier:kPacklistMoreCellReuseID];
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

/** @ghidraAddress 0x214470 */
- (void)dealloc {
    [self clearArtworkCache];
    artworkCache.delegate = nil;
    // ARC emits the [super dealloc] the binary performs here.
}

#pragma mark - Loading state

/** @ghidraAddress 0x2129c8 */
- (void)stopLoadingMore:(id)sender {
    if (isLoadingMoreList) {
        isLoadingMoreList = NO;
        self.allowsSelection = YES;
    }
}

/** @ghidraAddress 0x2129f0 */
- (void)clearArtworkCache {
    [artworkCache removeAllObjects];
    [operationQueue cancelAllOperations];
    [downloadingList removeAllObjects];
}

#pragma mark - Artwork download

/** @ghidraAddress 0x212a50 */
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
              completionHandler:^(NSData *data,
                                  NSURLResponse *__attribute__((unused)) response,
                                  NSError *__attribute__((unused)) error) {
                /** @ghidraAddress 0x212c50 */
                // The response and error are unused: a transport failure is detected only via
                // nil data.
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
                  /** @ghidraAddress 0x212e38 */
                  // Staleness guard: the slot's section carries the pack this download began
                  // for. If the table has since moved to a different pack, leave the image
                  // cached and the slot in flight.
                  if (slot.section != self.parentInfo.packID) {
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
                          StoreRecommendTableCell *cell =
                              (StoreRecommendTableCell *)[self cellForRowAtIndexPath:ip];
                          if (cell != nil) {
                              StoreRecommendPackView *tile =
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

/** @ghidraAddress 0x21329c */
- (NSInteger)numPackRows {
    NSInteger count = self.packList.count;
    if (isPad) {
        // Two packs per row on iPad, rounded up.
        count = (count + 1) >> 1;
    }
    return count;
}

/** @ghidraAddress 0x213308 */
- (void)setupPackView:(id)view index:(NSUInteger)index {
    StorePackInfo *pack = self.packList[index];
    NSIndexPath *key = [NSIndexPath indexPathForRow:index inSection:self.parentInfo.packID];
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
    if ([view isKindOfClass:[StoreRecommendPackView class]]) {
        StoreRecommendPackView *tile = view;
        [tile loadPackInfo:pack index:index];
        tile.artworkView.image = artwork;
    } else if ([view isKindOfClass:[StorePackCell class]]) {
        StorePackCell *cell = view;
        [cell loadPackInfo:pack];
        cell.artworkView.image = artwork;
    }
}

/** @ghidraAddress 0x213de4 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0x213dec */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self numPackRows];
}

/** @ghidraAddress 0x213df8 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    const BOOL isPackRow = indexPath.row < [self numPackRows];
    if (isPad) {
        return isPackRow ? kRowHeightValidPad : kRowHeightPlaceholder;
    }
    return isPackRow ? kRowHeightValidPhone : kRowHeightPlaceholder;
}

/** @ghidraAddress 0x2136d4 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    if (indexPath.row < [self numPackRows]) {
        if (isPad) {
            StoreRecommendTableCell *packCell = (StoreRecommendTableCell *)[tableView
                dequeueReusableCellWithIdentifier:kPacklistCellPadReuseID];
            if (packCell == nil) {
                packCell =
                    [[StoreRecommendTableCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:kPacklistCellPadReuseID];
            }
            packCell.leftPackView.delegate = self;
            packCell.rightPackView.delegate = self;
            [self setupPackView:packCell.leftPackView index:indexPath.row << 1];
            if ((indexPath.row << 1 | 1) < (NSInteger)self.packList.count) {
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

/** @ghidraAddress 0x213e7c */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < [self numPackRows]) {
        UIImage *bgImage = (indexPath.row & 1) ? packBgImage1 : packBgImage0;
        UIImage *bgImageAdd = (indexPath.row & 1) ? packBgImage1Add : packBgImage0Add;
        if (isPad) {
            cell.backgroundColor = UIColor.clearColor;
            StoreRecommendTableCell *packCell = (StoreRecommendTableCell *)cell;
            StorePackInfo *leftPack = self.packList[indexPath.row << 1];
            [packCell.leftPackView setBgImage:leftPack.hasExtend ? bgImageAdd : bgImage];
            const NSInteger rightIndex = indexPath.row << 1 | 1;
            if (rightIndex < (NSInteger)self.packList.count) {
                StorePackInfo *rightPack = self.packList[rightIndex];
                [packCell.rightPackView setBgImage:rightPack.hasExtend ? bgImageAdd : bgImage];
            }
        } else {
            StorePackInfo *pack = self.packList[indexPath.row];
            StorePackCell *packCell = (StorePackCell *)cell;
            [packCell setBgImage:pack.hasExtend ? bgImageAdd : bgImage];
        }
    } else {
        cell.backgroundColor = UIColor.clearColor;
    }
}

#pragma mark - Selection

/** @ghidraAddress 0x213150 */
- (void)storePackViewSelected:(id)packView {
    if (self.allowsSelection) {
        StorePackInfo *pack = self.packList[[packView index]];
        if (pack != nil && [self.parentView respondsToSelector:@selector(tapReccommendPack:)]) {
            // The result is a follow-on view the owner may return, or nil to ask for a reload.
            id result = [self.parentView performSelector:@selector(tapReccommendPack:)
                                              withObject:pack];
            if (result == nil) {
                [self reloadData];
            }
        }
    }
}

/** @ghidraAddress 0x214268 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == [self numPackRows]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    } else if (!isPad) {
        // iPad rows report their taps through the tile delegate instead.
        if ([self.parentView respondsToSelector:@selector(tapReccommendPack:)]) {
            StorePackInfo *pack = self.packList[indexPath.row];
            id result = [self.parentView performSelector:@selector(tapReccommendPack:)
                                              withObject:pack];
            if (result == nil) {
                [self reloadData];
            }
        }
    }
}

#pragma mark - Reload and scroll

/** @ghidraAddress 0x21440c */
- (void)reloadData {
    [artworkCache removeAllObjects];
    [super reloadData];
}

/** @ghidraAddress 0x214468 */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
}

#pragma mark - NSCacheDelegate

/** @ghidraAddress 0x21446c */
- (void)cache:(NSCache *)cache willEvictObject:(id)obj {
}

@end
