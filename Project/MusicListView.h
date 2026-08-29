/**
 * @file
 * The music-select song-list view: a paged, horizontally-scrolling grid of song tiles.
 *
 * Reconstructed from Ghidra program Jubeat (class MusicListView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The superclass is @c UIView, from
 * the @c initWithFrame: chain-up at 0x3b37c.
 *
 * The view hosts a paging @c UICollectionView of @c collectionCell cells, each wrapping a
 * @c MusicView tile. It owns the scale-up/scale-down column-size buttons, the page label and left/
 * right page arrows, a page slider and an alpha slider, a "no music" overlay, and an explanatory
 * @c BalloonView. Artwork is loaded asynchronously through @c ArtworkLoader operations on an
 * @c NSOperationQueue and cached in an @c NSCache, so the view is both the collection view's data
 * source and delegate and the artwork loader's and cache's delegate.
 */

#import <UIKit/UIKit.h>

#import "ArtworkLoader.h"

@class MusicView;
@class TuneInfo;
@class BalloonView;
@class MusicListCollectionLayout;

NS_ASSUME_NONNULL_BEGIN

/**
 * What the song list asks of, and reports to, its hosting controller.
 *
 * The protocol's name is the binary's own, taken from the @c _delegate ivar encoding
 * @c \@"<MusicListViewDelegate>" . The controller providing these is @c MusicSelectViewController .
 */
@protocol MusicListViewDelegate <NSObject>

@optional

/**
 * The number of tunes in the list.
 * @return The tune count.
 */
- (unsigned int)numberOfMusic;

/**
 * The tune for a list index.
 * @param index The list index.
 * @return The tune, or @c nil.
 */
- (nullable TuneInfo *)musicInfoForIndex:(NSUInteger)index;

/**
 * The advertised-extend tune for a music identifier.
 * @param musicID The music identifier.
 * @return The extend tune, or @c nil.
 */
- (nullable TuneInfo *)extendMusicInfoForMusicID:(unsigned int)musicID;

/**
 * The index paths to delete on the next batch reload.
 * @return An array of @c NSIndexPath.
 */
- (nullable NSArray<NSIndexPath *> *)removeMusicArray;

/**
 * The index paths to insert on the next batch reload.
 * @return An array of @c NSIndexPath.
 */
- (nullable NSArray<NSIndexPath *> *)addMusicArray;

/**
 * The list scrolled to a page.
 * @param pageNum The page scrolled to.
 * @param bAnim Whether the scroll animated.
 */
- (void)scrollFromPageNum:(int)pageNum bAnim:(BOOL)bAnim;

/**
 * The list began scrolling.
 */
- (void)musicListScrollBegin;

/**
 * A tile was chosen.
 * @param index The tile's list index.
 * @param musicID The chosen tune's identifier.
 */
- (void)changeMusicListView:(NSInteger)index musicID:(NSUInteger)musicID;

/**
 * A tile was chosen, noting whether it is the first change.
 * @param index The tile's list index.
 * @param musicID The chosen tune's identifier.
 * @param isFirst Whether this is the first selection.
 */
- (void)changeMusicListView:(NSInteger)index musicID:(NSUInteger)musicID isFirst:(BOOL)isFirst;

/**
 * Present a cover view hosting the given controls and gesture.
 * @param views The control views to host.
 * @param gesture The dismissing gesture recogniser.
 */
- (void)showCoverView:(nonnull NSArray *)views addGesture:(nonnull UIGestureRecognizer *)gesture;

/**
 * Dismiss the cover view.
 */
- (void)hiddenCoverView;

/**
 * A control's touch began.
 * @param sender The control.
 */
- (void)btnTouchesBegan:(nullable id)sender;

/**
 * A control's touch was cancelled or ended.
 * @param sender The control.
 */
- (void)btnTouchesCancel:(nullable id)sender;

@end

/**
 * A paged, scrolling grid of song tiles with column-size, paging, and alpha controls.
 */
@interface MusicListView : UIView <UICollectionViewDataSource,
                                   UICollectionViewDelegateFlowLayout,
                                   ArtworkLoaderDelegate,
                                   NSCacheDelegate>

/**
 * Builds the list, its controls, the artwork cache, and the operation queue.
 * @param frame The list's frame.
 * @return The initialised list view.
 * @ghidraAddress 0x3b314
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * The centre of a tile in a page for a list index.
 * @param page The page.
 * @param index The list index.
 * @return The tile centre in the list's coordinate space.
 * @ghidraAddress 0x3cec4
 */
- (CGPoint)centerOfMusicViewInPage:(NSUInteger)page forIndex:(NSUInteger)index;

/**
 * Hides the playlist add/remove button on every visible tile.
 * @ghidraAddress 0x3cfa4
 */
- (void)hideAllPlaylistAction;

/**
 * The tile artwork edge length for the current device idiom.
 * @return The artwork size.
 * @ghidraAddress 0x3d0fc
 */
- (CGFloat)artworkSize;

/**
 * Clears and hides every visible tile.
 * @ghidraAddress 0x3d118
 */
- (void)clearAllPage;

/**
 * Loads a tile's artwork concurrently.
 * @param musicView The tile to load artwork for.
 * @ghidraAddress 0x3d2a8
 */
- (void)loadArtworkForInfo:(nonnull MusicView *)musicView;

/**
 * Loads a tune's artwork into an image view, from the cache or an operation.
 * @param info The tune whose artwork to load.
 * @param imageView The image view to fill.
 * @param concurrent Whether to load off the main thread.
 * @param index The requesting row index.
 * @ghidraAddress 0x3d368
 */
- (void)loadArtworkForInfo:(nullable TuneInfo *)info
              forImageView:(nullable UIImageView *)imageView
                concurrent:(BOOL)concurrent
                     index:(int)index;

/**
 * Reloads the page containing a tune, animating the delete/insert if small enough.
 * @param musicIndex The tune's list index.
 * @param playlistIndex The playlist index, or negative for none.
 * @ghidraAddress 0x3d67c
 */
- (void)reloadPageContainsMusicForIndex:(NSUInteger)musicIndex
                          playlistIndex:(NSInteger)playlistIndex;

/**
 * Deletes the tile whose tune matches, adjusting the current page.
 * @param musicView The tile whose tune identifies the one to remove.
 * @ghidraAddress 0x3dad4
 */
- (void)removeMusicView:(nonnull MusicView *)musicView;

/**
 * Sets the delegate passed on to each tile's music view.
 * @param mvDelegate The music-view delegate.
 * @ghidraAddress 0x3ddd0
 */
- (void)setMusicViewDelegate:(nullable id)mvDelegate;

/**
 * Scrolls to a page's content offset without animation.
 * @param page The page to align to.
 * @ghidraAddress 0x3dde4
 */
- (void)alignPage:(int)page;

/**
 * Scrolls to the current page's content offset.
 * @param page Ignored.
 * @param center Ignored.
 * @return Always @c YES.
 * @ghidraAddress 0x3de3c
 */
- (BOOL)layoutPage:(int)page center:(int)center;

/**
 * Reloads the collection view.
 * @ghidraAddress 0x3dea0
 */
- (void)updateViews;

/**
 * The artwork finished loading; installs and caches it on the main thread.
 * @param loader The finished loader.
 * @ghidraAddress 0x3deb8
 */
- (void)imageDataLoaded:(nonnull ArtworkLoader *)loader;

/**
 * Cancels operations and clears the artwork cache and loader dictionary.
 * @ghidraAddress 0x3e298
 */
- (void)releaseArtworks;

/**
 * The tile count per page for the current column type.
 * @return The tiles per page.
 * @ghidraAddress 0x3e32c
 */
- (int)currentViewsPerPage;

/**
 * The tile count per page for a column type.
 * @param colType The column type.
 * @return The tiles per page.
 * @ghidraAddress 0x3e344
 */
- (int)musicInPage:(int)colType;

/**
 * The number of pages.
 * @return The page count.
 * @ghidraAddress 0x3e34c
 */
- (int)numPage;

/**
 * The current page index.
 * @return The current page.
 * @ghidraAddress 0x3e3b8
 */
- (int)getCurrentPage;

/**
 * Refreshes the page label, arrows, and page slider for the current page.
 * @ghidraAddress 0x3e3c8
 */
- (void)updatePageDisplay;

/**
 * Reveals the download mark on the visible tile whose tune matches.
 * @param index The tune identifier to match.
 * @ghidraAddress 0x3ebb8
 */
- (void)addDownloadMark:(int)index;

/**
 * The visible music view whose tune identifier matches.
 * @param index The tune identifier to match.
 * @return The matching music view, or @c nil.
 * @ghidraAddress 0x3ed68
 */
- (nullable MusicView *)getMusicView:(int)index;

/**
 * Rescales the grid to a new column type, animating the tiles across the change.
 * @param colType The column type to switch to.
 * @ghidraAddress 0x3fe34
 */
- (void)changeLayout:(int)colType;

/**
 * Steps the grid to a smaller tile / more columns.
 * @param sender The scale-down button.
 * @ghidraAddress 0x407cc
 */
- (void)pushScaleDown:(nullable id)sender;

/**
 * Steps the grid to a larger tile / fewer columns.
 * @param sender The scale-up button.
 * @ghidraAddress 0x40990
 */
- (void)pushScaleUp:(nullable id)sender;

/**
 * Forwards a control's touch-began to the delegate.
 * @param touches The control.
 * @ghidraAddress 0x40bd8
 */
- (void)btnTouchesBegan:(nullable id)touches;

/**
 * Forwards a control's touch-cancel to the delegate.
 * @param touches The control.
 * @ghidraAddress 0x40c90
 */
- (void)btnTouchesCancel:(nullable id)touches;

/**
 * The page-slider cover gesture fired; dismisses the cover view.
 * @param sender The gesture recogniser.
 * @ghidraAddress 0x40d48
 */
- (void)pageSliderHidden:(nullable id)sender;

/**
 * Long-press handler that presents the page and alpha sliders in a cover view.
 * @param gesture the long-press recogniser.
 * @ghidraAddress 0x40d88
 */
- (void)showPageSelector:(nullable UIGestureRecognizer *)gesture;

/**
 * Resets the page slider's range and value to the current page.
 * @ghidraAddress 0x40ef4
 */
- (void)sliderValueChange;

/**
 * The page slider moved; scrolls to the chosen page and refreshes the display.
 * @param sender The page slider.
 * @ghidraAddress 0x40f78
 */
- (void)sliderChange:(nullable id)sender;

/**
 * The page slider was released; snaps to the nearest page.
 * @param sender The page slider.
 * @ghidraAddress 0x411c0
 */
- (void)sliderEnd:(nullable id)sender;

/**
 * Hides the explanatory balloon.
 * @ghidraAddress 0x412a0
 */
- (void)hideExplainBalloon;

/**
 * The alpha slider moved; fades the list and toggles the balloon.
 * @param sender The alpha slider.
 * @ghidraAddress 0x414a8
 */
- (void)alphaSliderChange:(nullable id)sender;

/**
 * The alpha slider was released; commits the list alpha.
 * @param sender The alpha slider.
 * @ghidraAddress 0x41638
 */
- (void)alphaSliderEnd:(nullable id)sender;

/**
 * The current list alpha.
 * @return The list alpha.
 * @ghidraAddress 0x41690
 */
- (float)getMusicListAlpha;

/**
 * Refreshes every visible tile's label colour.
 * @ghidraAddress 0x416bc
 */
- (void)refreshTextColor;

/**
 * Refreshes every visible tile's rating chips from the preference.
 * @ghidraAddress 0x41814
 */
- (void)refreshRatingChip;

#pragma mark - Properties

/** The hosting controller. */
@property(nonatomic, weak, nullable) id<MusicListViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
