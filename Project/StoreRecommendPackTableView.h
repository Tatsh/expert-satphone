/** @file
 * The store's recommended-pack table: a self-hosting @c UITableView that lists recommended packs
 * with asynchronously-downloaded artwork.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreRecommendPackTableView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableView, from the @c -initWithFrame:style: chain-up. The view is its
 * own data source and delegate. Cells differ by idiom: on iPhone each row is one @c StorePackCell
 * showing a single pack; on iPad each row is a @c StoreRecommendTableCell carrying two
 * @c StoreRecommendPackView tiles side by side, so a row holds two packs. A trailing "load more"
 * row is a plain @c UITableViewCell that shows either a localised prompt or a spinner.
 *
 * Artwork is fetched off the main thread on an @c NSOperationQueue and kept in an @c NSCache keyed
 * by an @c NSIndexPath whose section carries the owning pack's identifier (a staleness guard) and
 * whose row carries the pack's position. A per-slot in-flight list prevents duplicate downloads.
 */

#import <UIKit/UIKit.h>

#import "StorePackInfo.h"
#import "StoreRecommendPackView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A table of recommended store packs with lazily-downloaded artwork and an infinite-scroll
 * "load more" row.
 *
 * Conforms to the table data-source and delegate protocols, to @c UIScrollViewDelegate, to
 * @c NSCacheDelegate (for the eviction callback), and to @c StoreRecommendPackViewDelegate (each
 * iPad pack tile reports its selection back here).
 */
@interface StoreRecommendPackTableView : UITableView <UITableViewDataSource,
                                                      UITableViewDelegate,
                                                      UIScrollViewDelegate,
                                                      NSCacheDelegate,
                                                      StoreRecommendPackViewDelegate>

/** @brief The packs to display. */
@property(nonatomic, strong, nullable) NSArray *packList;

/**
 * @brief The owner told when a pack is tapped.
 *
 * Weak and untyped in the metadata; the tap is delivered through @c -respondsToSelector: and
 * @c -performSelector:withObject: rather than a declared conformance.
 */
@property(nonatomic, weak, nullable) id parentView;

/**
 * @brief The pack whose recommendations this table lists.
 *
 * Its @c packID seeds each artwork cache key's section, which lets an in-flight download detect
 * that the table has moved on to a different pack before the image arrives.
 */
@property(nonatomic, weak, nullable) StorePackInfo *parentInfo;

/**
 * @brief Designated initialiser: registers the cell classes, builds the download queue, cache and
 * in-flight list, and loads the four resizable pack-background images and the default artwork.
 * @param frame The table's frame.
 * @param style The table style.
 * @return The initialised table.
 * @ghidraAddress 0x212540
 */
- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style;

/**
 * @brief Ends the "load more" spinner state and re-enables selection.
 * @param sender Ignored.
 * @ghidraAddress 0x2129c8
 */
- (void)stopLoadingMore:(nullable id)sender;

/**
 * @brief Empties the artwork cache, cancels every queued download, and clears the in-flight list.
 * @ghidraAddress 0x2129f0
 */
- (void)clearArtworkCache;

/**
 * @brief Downloads one pack's artwork synchronously on the operation queue, then caches and
 * installs it via a completion block.
 * @param arg A two-element array: the artwork @c NSURL followed by the cache-key @c NSIndexPath.
 * @ghidraAddress 0x212a50
 */
- (void)downloadImageSync:(nullable NSArray *)arg;

/**
 * @brief @c StoreRecommendPackViewDelegate callback: opens the tapped tile's pack through
 * @c parentView, if selection is allowed.
 * @param packView The tapped pack tile.
 * @ghidraAddress 0x213150
 */
- (void)storePackViewSelected:(nullable id)packView;

/**
 * @brief The number of pack rows: the pack count on iPhone, or half of it (rounded up) on iPad
 * where each row holds two packs.
 * @return The row count.
 * @ghidraAddress 0x21329c
 */
- (NSInteger)numPackRows;

/**
 * @brief Fills one pack view (a @c StorePackCell or a @c StoreRecommendPackView) from the pack at
 * @p index, installing cached artwork or queueing a download for it.
 * @param view The pack view to configure.
 * @param index The pack's index in @c packList.
 * @ghidraAddress 0x213308
 */
- (void)setupPackView:(nullable id)view index:(NSUInteger)index;

/**
 * @brief Vends the row cell: a pack cell for a pack row, or the "load more" cell past the end.
 * @param tableView The table view.
 * @param indexPath The row's index path.
 * @return The configured cell.
 * @ghidraAddress 0x2136d4
 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief The number of sections. Always one.
 * @param tableView The table view.
 * @return One.
 * @ghidraAddress 0x213de4
 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;

/**
 * @brief The number of rows in a section, which is @c numPackRows.
 * @param tableView The table view.
 * @param section The section index.
 * @return @c numPackRows .
 * @ghidraAddress 0x213dec
 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;

/**
 * @brief The row height: the valid-row height for a pack row, otherwise the "load more" height.
 * The valid-row height differs between idioms.
 * @param tableView The table view.
 * @param indexPath The row's index path.
 * @return The row height.
 * @ghidraAddress 0x213df8
 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief Sets each pack view's alternating background just before display, choosing the extended
 * variant for a pack that has an extend.
 * @param tableView The table view.
 * @param cell The cell about to be shown.
 * @param indexPath The row's index path.
 * @ghidraAddress 0x213e7c
 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief Opens the selected pack through @c parentView (iPhone only), or deselects the "load more"
 * row.
 * @param tableView The table view.
 * @param indexPath The row's index path.
 * @ghidraAddress 0x214268
 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief Empties the artwork cache and reloads the table.
 * @ghidraAddress 0x21440c
 */
- (void)reloadData;

/**
 * @brief Scroll callback. The shipped body is empty (a single @c ret ).
 * @param scrollView The scrolling view.
 * @ghidraAddress 0x214468
 */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;

/**
 * @brief @c NSCacheDelegate eviction callback. The shipped body is empty (a single @c ret ).
 * @param cache The cache evicting an object.
 * @param obj The object being evicted.
 * @ghidraAddress 0x21446c
 */
- (void)cache:(NSCache *)cache willEvictObject:(nullable id)obj;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
