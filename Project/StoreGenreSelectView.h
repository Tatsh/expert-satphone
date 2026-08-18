/** @file
 * A horizontally-scrolling store genre picker: a row of tappable genre banners inside a paging
 * scroll view, with a selected index. The picker pads its banner list with wrap-around copies so
 * that paging past either end loops seamlessly.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreGenreSelectView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c StoreGenreSelectView tells its owner when the selection changes.
 */
@protocol StoreGenreSelectViewDelegate <NSObject>

/**
 * @brief Sent when a genre banner is tapped, carrying the genre index within the genre list.
 * @param index The selected genre index, already reduced into the genre list's range.
 */
- (void)StoreGenreSelectViewDelegateGenreSelected:(NSUInteger)index;

@end

/**
 * @brief A paging, wrap-around row of genre banners with a delegate-reported selection.
 */
@interface StoreGenreSelectView : UIView <UIScrollViewDelegate>

/**
 * @brief The object told when the selected genre changes.
 */
@property(nonatomic, weak, nullable) id<StoreGenreSelectViewDelegate> delegate;

/**
 * @brief Builds the scroll view, one banner per genre plus wrap-around copies, and selects the
 * first genre.
 * @param frame The picker's frame.
 * @param genreList The genres to show, each a @c StorePackListGenre.
 * @return The initialised picker.
 * @ghidraAddress 0x1db4fc
 */
- (instancetype)initWithFrame:(CGRect)frame genreList:(nullable NSArray *)genreList;

/**
 * @brief Scroll delegate hook invoked as dragging begins. Inert in the shipped binary.
 * @param scrollView The scrolling view.
 * @ghidraAddress 0x1dbb58
 */
- (void)scrollViewWillBeginDragging:(nonnull UIScrollView *)scrollView;

/**
 * @brief Keeps the paging offset inside the real banners by looping it when it drifts into a
 * wrap-around pad.
 * @param scrollView The scrolling view.
 * @ghidraAddress 0x1dbb5c
 */
- (void)scrollViewDidScroll:(nonnull UIScrollView *)scrollView;

/**
 * @brief Scroll delegate hook invoked when dragging ends. Inert in the shipped binary.
 * @param scrollView The scrolling view.
 * @param decelerate Whether the view will keep scrolling.
 * @ghidraAddress 0x1dbc1c
 */
- (void)scrollViewDidEndDragging:(nonnull UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;

/**
 * @brief Scroll delegate hook invoked as deceleration begins. Inert in the shipped binary.
 * @param scrollView The scrolling view.
 * @ghidraAddress 0x1dbc20
 */
- (void)scrollViewWillBeginDecelerating:(nonnull UIScrollView *)scrollView;

/**
 * @brief Scroll delegate hook invoked when deceleration ends. Inert in the shipped binary.
 * @param scrollView The scrolling view.
 * @ghidraAddress 0x1dbc24
 */
- (void)scrollViewDidEndDecelerating:(nonnull UIScrollView *)scrollView;

/**
 * @brief Banner tap handler: selects the tapped genre and notifies the delegate.
 * @param sender The tapped banner, whose tag encodes its position in the padded banner row.
 * @ghidraAddress 0x1dbc60
 */
- (void)tapGenreBtn:(nonnull id)sender;

/**
 * @brief Selects a genre by index, highlighting its banner and animating the scroll to it.
 * @param index The genre index to select.
 * @ghidraAddress 0x1dbce8
 */
- (void)setSelectedGenreIndex:(NSInteger)index;

/**
 * @brief Marks the banner for the given genre index as selected and every other as not.
 * @param index The genre index whose banners are selected.
 * @ghidraAddress 0x1dbd70
 */
- (void)setSelectedBanner:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
