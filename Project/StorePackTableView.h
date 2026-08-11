/** @file
 * The store's per-genre pack table: a self-hosting @c UITableView that lists the downloadable
 * packs of one genre with asynchronously-downloaded pack artwork and a "load more" paging row.
 *
 * Reconstructed from Ghidra program Jubeat (class StorePackTableView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableView, from the @c -initWithFrame:style: chain-up. The view is its
 * own data source and delegate. Cells differ by idiom: on iPhone each row is one @c StorePackCell
 * showing a single pack; on iPad each row is a @c StoreTableCell carrying two @c StorePackView
 * tiles side by side, so a row holds two packs (the right tile is hidden on an odd count). A
 * trailing "load more" row is a plain @c UITableViewCell that shows either a localised prompt or a
 * spinner, and appears while the genre reports a further catalogue page.
 *
 * Artwork is fetched off the main thread on an @c NSOperationQueue and kept in an @c NSCache keyed
 * by an @c NSIndexPath whose section carries the owning genre's identifier (a staleness guard) and
 * whose row carries the pack's position. A per-slot in-flight list prevents duplicate downloads.
 */

#import <UIKit/UIKit.h>

#import "StorePackListGenre.h"
#import "StorePackView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A table of one genre's store packs with lazily-downloaded artwork and an infinite-scroll
 * "load more" row.
 *
 * Conforms to the table data-source and delegate protocols, to @c UIScrollViewDelegate, to
 * @c NSCacheDelegate (for the eviction callback), and to @c StorePackViewDelegate (each iPad pack
 * tile reports its selection back here).
 */
@interface StorePackTableView : UITableView <UITableViewDataSource,
                                             UITableViewDelegate,
                                             UIScrollViewDelegate,
                                             NSCacheDelegate,
                                             StorePackViewDelegate>

/**
 * @brief The genre whose packs this table lists.
 *
 * Its @c genreID seeds each artwork cache key's section, which lets an in-flight download detect
 * that the table has moved on to a different genre before the image arrives.
 */
@property(nonatomic, strong, nullable) StorePackListGenre *currentGenre;

/**
 * @brief The owning controller told when a pack is tapped, a page must be fetched, or the list has
 * scrolled.
 *
 * Weak in the metadata; every message is delivered through @c -respondsToSelector: and
 * @c -performSelector: rather than a declared conformance.
 */
@property(nonatomic, weak, nullable) UIViewController *viewController;

/**
 * @brief Designated initialiser: registers the cell classes, builds the download queue, cache and
 * in-flight list, and loads the four resizable pack-background images and the default artwork. On
 * iPad it also gives the table a thin bordered layer and inset scroll indicators.
 * @param frame The table's frame.
 * @param style The table style.
 * @return The initialised table.
 * @ghidraAddress 0x1b0eb8
 */
- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style;

/**
 * @brief Ends the "load more" spinner state, re-enables selection, and optionally reloads the
 * "load more" row so it shows the prompt again when a further page remains.
 * @param reload Whether to reload the "load more" row.
 * @ghidraAddress 0x1b1420
 */
- (void)stopLoadingMore:(BOOL)reload;

/**
 * @brief Empties the artwork cache, cancels every queued download, and clears the in-flight list.
 * @ghidraAddress 0x1b1570
 */
- (void)clearArtworkCache;

/**
 * @brief Downloads one pack's artwork synchronously on the operation queue, then caches and
 * installs it via a completion block.
 * @param arg A two-element array: the artwork @c NSURL followed by the cache-key @c NSIndexPath.
 * @ghidraAddress 0x1b15d0
 */
- (void)downloadImageSync:(nullable NSArray *)arg;

/**
 * @brief @c StorePackViewDelegate callback: opens the tapped tile's pack through
 * @c viewController, if selection is allowed.
 * @param packView The tapped pack tile.
 * @ghidraAddress 0x1b1cd0
 */
- (void)storePackViewSelected:(nullable id)packView;

/**
 * @brief The number of pack rows: the genre's pack count on iPhone, or half of it (rounded up) on
 * iPad where each row holds two packs.
 * @return The row count.
 * @ghidraAddress 0x1b1e04
 */
- (NSInteger)numPackRows;

/**
 * @brief Fills one pack view (a @c StorePackCell or a @c StorePackView) from the pack at @p index,
 * installing cached artwork or queueing a download for it.
 * @param view The pack view to configure.
 * @param index The pack's index in the genre.
 * @ghidraAddress 0x1b1e70
 */
- (void)setupPackView:(nullable id)view index:(NSUInteger)index;

/**
 * @brief Vends the row cell: a pack cell for a pack row, or the "load more" cell past the end.
 * @param tableView The table view.
 * @param indexPath The row's index path.
 * @return The configured cell.
 * @ghidraAddress 0x1b223c
 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief The number of sections. Always one.
 * @param tableView The table view.
 * @return One.
 * @ghidraAddress 0x1b294c
 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;

/**
 * @brief The number of rows in a section: @c numPackRows plus one when the genre reports a further
 * page.
 * @param tableView The table view.
 * @param section The section index.
 * @return The row count.
 * @ghidraAddress 0x1b2954
 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;

/**
 * @brief The row height: the valid-row height for a pack row, otherwise the "load more" height.
 * The valid-row height differs between idioms.
 * @param tableView The table view.
 * @param indexPath The row's index path.
 * @return The row height.
 * @ghidraAddress 0x1b29b8
 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief Sets each pack view's alternating background just before display, choosing the extended
 * variant for a pack that has an extend. On iPad the cell also gets a grey backdrop.
 * @param tableView The table view.
 * @param cell The cell about to be shown.
 * @param indexPath The row's index path.
 * @ghidraAddress 0x1b2a3c
 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief Opens the selected pack through @c viewController (iPhone only), or begins a page fetch
 * on the "load more" row.
 * @param tableView The table view.
 * @param indexPath The row's index path.
 * @ghidraAddress 0x1b2e00
 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief Enters the "load more" state: shows the spinner and prompt in the given cell, disables
 * its selection, and asks @c viewController to fetch the next page. A no-op while already loading.
 * @param cell The "load more" cell.
 * @ghidraAddress 0x1b2fc8
 */
- (void)selectLoadMoreCell:(nullable UITableViewCell *)cell;

/**
 * @brief Scroll callback: begins a page fetch once the list is scrolled to its bottom, unless one
 * is already in flight or the genre has no further page.
 * @param scrollView The scrolling view.
 * @ghidraAddress 0x1b3250
 */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;

/**
 * @brief Deceleration-ended callback (iPhone, tap-navigation preference off): tells
 * @c viewController the list scrolled once the content is dragged past the frame height.
 * @param scrollView The scrolling view.
 * @ghidraAddress 0x1b3390
 */
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;

/**
 * @brief Drag-ended callback (iPhone, tap-navigation preference off, no further deceleration): the
 * same "list scrolled" notification as @c -scrollViewDidEndDecelerating: .
 * @param scrollView The scrolling view.
 * @param decelerate Whether scrolling will continue to decelerate.
 * @ghidraAddress 0x1b34d0
 */
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;

/**
 * @brief @c NSCacheDelegate eviction callback. The shipped body is empty (a single @c ret ).
 * @param cache The cache evicting an object.
 * @param obj The object being evicted.
 * @ghidraAddress 0x1b3614
 */
- (void)cache:(NSCache *)cache willEvictObject:(nullable id)obj;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
