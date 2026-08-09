/** @file
 * The marker (note-skin) selection screen.
 *
 * Reconstructed from Ghidra program Jubeat (class MarkerSelectView, image base 0x100000000); all
 * @ghidraAddress values are offsets relative to that image base. This class has no embedded
 * @c __FILE__ path, so it stays at the @c Project/ root.
 *
 * A @c UIView holding a horizontally-paged banner @c UIScrollView of marker options, a
 * @c CADisplayLink -driven @c MarkerTestView that previews the currently loaded marker, a press
 * button image, and a loading overlay with an activity indicator. The banner buttons tile the
 * scroll content into three repeated copies of the marker list so the scroll wraps seamlessly, and
 * selecting a marker persists it, notifies the delegate, and kicks off an asynchronous marker load.
 */

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#import "MarkerTestView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The object notified when the selected marker changes.
 */
@protocol MarkerSelectViewDelegate <NSObject>
@optional
/**
 * @brief Sent after the user picks a different marker.
 * @param sender The marker selection view whose selection changed.
 */
- (void)markerSelectChanged:(nonnull id)sender;
@end

/**
 * @brief The marker selection screen: a paged banner list with a live marker preview.
 */
@interface MarkerSelectView : UIView <UIScrollViewDelegate>

/**
 * @brief Initialises the view, its background, preview, banner scroll view, marker buttons, and
 *        loading overlay.
 * @param frame The view's frame.
 * @return The initialised view.
 * @ghidraAddress 0x98afc
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Builds the per-theme preview sound name for @p name.
 * @param name The base sound name (for example @c MUSIC_SELECT ).
 * @return @c SD_RPL_<name> , @c SD_KNT_<name> , or @c SD_<name> for the current theme.
 * @ghidraAddress 0x99d30
 */
- (nullable NSString *)soundName:(nullable NSString *)name;

/**
 * @brief The background image of the button for the currently persisted marker.
 * @return The current marker button's normal-state background image.
 * @ghidraAddress 0x99e20
 */
- (nullable UIImage *)getCurrentBanner;

/**
 * @brief The @c CADisplayLink callback: advances the preview and hides the press button once its
 *        load has finished.
 * @param sender The display link.
 * @ghidraAddress 0x99f20
 */
- (void)loop:(nullable CADisplayLink *)sender;

/**
 * @brief Creates the display link targeting @c -loop: , adds it to the run loop, and resets the
 *        preview.
 * @ghidraAddress 0x9a038
 */
- (void)startAnimation;

/**
 * @brief Pauses the preview and the display link.
 * @ghidraAddress 0x9a19c
 */
- (void)pauseAnimation;

/**
 * @brief Resumes the preview and the display link.
 * @ghidraAddress 0x9a230
 */
- (void)resumeAnimation;

/**
 * @brief Invalidates and releases the display link.
 * @ghidraAddress 0x9a2c0
 */
- (void)stopAnimation;

/**
 * @brief Shows the loading overlay and asynchronously loads the current marker's textures.
 * @param scroll @c YES to also scroll the banner list to the current marker.
 * @ghidraAddress 0x9a354
 */
- (void)startLoadMarker:(BOOL)scroll;

/**
 * @brief Marker button action: selects the tapped marker, plays a sound, persists it, notifies the
 *        delegate, and reloads the preview.
 * @param sender The tapped marker button.
 * @ghidraAddress 0x9a9c8
 */
- (void)btnMarker:(nullable UIButton *)sender;

/**
 * @brief Stops the preview and releases the preview's textures.
 * @ghidraAddress 0x9aca4
 */
- (void)close;

/**
 * @brief Scroll delegate stub called when dragging begins.
 * @param scrollView The banner scroll view.
 * @ghidraAddress 0x9ad44
 */
- (void)scrollViewWillBeginDragging:(nonnull UIScrollView *)scrollView;

/**
 * @brief Wraps the paged scroll offset into the middle copy of the tiled content and re-centres the
 *        banner buttons.
 * @param scrollView The banner scroll view.
 * @ghidraAddress 0x9ad48
 */
- (void)scrollViewDidScroll:(nonnull UIScrollView *)scrollView;

/**
 * @brief Scroll delegate stub called when deceleration ends.
 * @param scrollView The banner scroll view.
 * @ghidraAddress 0x9b04c
 */
- (void)scrollViewDidEndDecelerating:(nonnull UIScrollView *)scrollView;

/**
 * @brief Scroll delegate stub called when dragging ends.
 * @param scrollView The banner scroll view.
 * @param decelerate Whether the scroll view will continue to decelerate.
 * @ghidraAddress 0x9b050
 */
- (void)scrollViewDidEndDragging:(nonnull UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;

/**
 * @brief Rebuilds the banner scroll view and its marker buttons from the current marker list.
 * @ghidraAddress 0x9b0a4
 */
- (void)updateMarkerList;

/**
 * @brief The object notified when the selected marker changes; held weakly.
 * @ghidraAddress 0x9ba3c (getter), 0x9ba5c (setter)
 */
@property(nonatomic, weak, nullable) id<MarkerSelectViewDelegate> delegate;

/**
 * @brief The OpenGL preview of the currently loaded marker.
 * @ghidraAddress 0x9ba70 (getter), 0x9ba80 (setter)
 */
@property(nonatomic, strong, nullable) MarkerTestView *markerTestView;

/**
 * @brief The horizontally-paged banner scroll view of marker options.
 * @ghidraAddress 0x9ba94 (getter), 0x9baa4 (setter)
 */
@property(nonatomic, strong, nullable) UIScrollView *bannerScrollView;

/**
 * @brief The marker banner buttons tiled into the scroll content.
 * @ghidraAddress 0x9bab8 (getter), 0x9bac8 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray<UIButton *> *arrayMarkerBtn;

/**
 * @brief The press button graphic shown over the preview.
 * @ghidraAddress 0x9badc (getter), 0x9baec (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *buttonImgView;

/**
 * @brief The screen background image.
 * @ghidraAddress 0x9bb00 (getter), 0x9bb10 (setter)
 */
@property(nonatomic, strong, nullable) UIImageView *bgView;

/**
 * @brief The dimming overlay shown while a marker loads.
 * @ghidraAddress 0x9bb24 (getter), 0x9bb34 (setter)
 */
@property(nonatomic, strong, nullable) UIView *loadingView;

/**
 * @brief The activity indicator inside the loading overlay.
 * @ghidraAddress 0x9bb48 (getter), 0x9bb58 (setter)
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicator;

/**
 * @brief The "Loading..." label inside the loading overlay.
 * @ghidraAddress 0x9bb6c (getter), 0x9bb7c (setter)
 */
@property(nonatomic, strong, nullable) UILabel *labelLoading;

/**
 * @brief The display link that drives the preview and press-button lifecycle.
 * @ghidraAddress 0x9bb90 (getter), 0x9bba0 (setter)
 */
@property(nonatomic, strong, nullable) CADisplayLink *displayLink;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
