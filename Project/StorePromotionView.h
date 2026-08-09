/** @file
 * The store's promotion-banner carousel.
 *
 * Reconstructed from Ghidra program Jubeat (class StorePromotionView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, from the @c -initWithFrame:promotions: chain-up to
 * @c -[UIView initWithFrame:] and the @c hitTest:withEvent: override. The view is a paging
 * @c UIScrollView (a @c PagingScrollView, so neighbouring pages stay touchable) of banner views
 * that auto-advances on a repeating timer. Each centred banner plays a downloaded video-thumbnail
 * sound clip; a sample-play toggle button mutes or restores that playback.
 *
 * The whole class branches only on @c UIDevice.currentDevice.userInterfaceIdiom (pad versus phone,
 * checked at 0x1bb56c). There is no @c thema theme branch anywhere in the class.
 *
 * The banner strip is a wrap-around carousel: the initialiser lays out @c count+2 banners (the real
 * promotions followed by two duplicates) and @c -scrollViewDidScroll: teleports the offset across
 * the seam so the strip appears infinite.
 */

#import <UIKit/UIKit.h>

#import "StorePackInfo.h"

@class StorePromotionView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Receives the carousel's banner-tap selections.
 *
 * A tapped banner reports either a pack or a genre, never both, mirroring the two kinds of
 * @c StorePromotion. Both methods are optional; the view guards each with @c respondsToSelector: .
 */
@protocol StorePromotionViewDelegate <NSObject>

@optional

/**
 * @brief A pack promotion's banner was tapped.
 * @param view The carousel that sent the message.
 * @param packInfo The tapped banner's pack.
 */
- (void)storePromotionView:(StorePromotionView *)view packSelected:(StorePackInfo *)packInfo;

/**
 * @brief A genre promotion's banner was tapped.
 * @param view The carousel that sent the message.
 * @param genreIndex The tapped banner's genre index.
 */
- (void)storePromotionView:(StorePromotionView *)view genreSelected:(NSUInteger)genreIndex;

@end

/**
 * @brief A paging carousel of promotion banners with auto-advance and per-banner sample playback.
 */
@interface StorePromotionView : UIView <UIScrollViewDelegate>

/**
 * @brief The tap-selection delegate.
 * @ghidraAddress 0x1bd5d0 (getter), 0x1bd5f0 (setter)
 */
@property(nonatomic, weak, nullable) id<StorePromotionViewDelegate> delegate;

/**
 * @brief Builds the carousel from a list of promotions and lays out every banner.
 * @param frame The view's frame.
 * @param promotions The promotions to show, each a @c StorePromotion .
 * @return The initialised view.
 * @ghidraAddress 0x1bb4a8
 */
- (nullable instancetype)initWithFrame:(CGRect)frame promotions:(nullable NSArray *)promotions;

/**
 * @brief Updates the sample button's image and the track label's opacity for the current mode.
 * @ghidraAddress 0x1bc204
 */
- (void)setSampleButtonImage;

/**
 * @brief Redirects a touch that lands on the view itself down to the scroll view.
 * @param point The touch point.
 * @param event The touch event.
 * @return The hit view, or the scroll view when the view itself was hit.
 * @ghidraAddress 0x1bc294
 */
- (nullable UIView *)hitTest:(CGPoint)point withEvent:(nullable UIEvent *)event;

/**
 * @brief Arms the auto-advance timer and plays the centred banner's thumbnail.
 * @ghidraAddress 0x1bc314
 */
- (void)beginLoop;

/**
 * @brief Starts fetching every banner's artwork, then begins the auto-advance loop.
 * @ghidraAddress 0x1bc418
 */
- (void)start;

/**
 * @brief Pauses the carousel: stops the timer and the thumbnail playback.
 * @ghidraAddress 0x1bc55c
 */
- (void)pause;

/**
 * @brief Resumes a paused carousel.
 * @ghidraAddress 0x1bc600
 */
- (void)resume;

/**
 * @brief Stops the carousel: invalidates the timer and mutes the thumbnail.
 * @ghidraAddress 0x1bc624
 */
- (void)stop;

/**
 * @brief Scrolls to the next banner and plays its thumbnail. The timer's action.
 * @ghidraAddress 0x1bc690
 */
- (void)nextBanner;

/**
 * @brief Handles a banner tap, reporting the pack or genre to the delegate.
 * @param recognizer The tap gesture recogniser.
 * @ghidraAddress 0x1bc710
 */
- (void)bannerTapped:(nonnull UITapGestureRecognizer *)recognizer;

/**
 * @brief Toggles the sample-play mode, persists it, and refreshes the button.
 * @param sender The sample button.
 * @ghidraAddress 0x1bc8b8
 */
- (void)tapSampleBtn:(nullable id)sender;

/**
 * @brief Cancels the auto-advance timer while the user drags.
 * @param scrollView The scroll view.
 * @ghidraAddress 0x1bc990
 */
- (void)scrollViewWillBeginDragging:(nonnull UIScrollView *)scrollView;

/**
 * @brief Teleports the offset across the wrap-around seam to fake an infinite strip.
 * @param scrollView The scroll view.
 * @ghidraAddress 0x1bc9f0
 */
- (void)scrollViewDidScroll:(nonnull UIScrollView *)scrollView;

/**
 * @brief Empty in the binary.
 * @param scrollView The scroll view.
 * @param decelerate Whether the scroll view will decelerate.
 * @ghidraAddress 0x1bcaac
 */
- (void)scrollViewDidEndDragging:(nonnull UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;

/**
 * @brief Empty in the binary.
 * @param scrollView The scroll view.
 * @ghidraAddress 0x1bcab0
 */
- (void)scrollViewWillBeginDecelerating:(nonnull UIScrollView *)scrollView;

/**
 * @brief Re-arms the auto-advance timer once a decelerating scroll settles.
 * @param scrollView The scroll view.
 * @ghidraAddress 0x1bcab4
 */
- (void)scrollViewDidEndDecelerating:(nonnull UIScrollView *)scrollView;

/**
 * @brief Plays the thumbnail of the banner at @p index, updating the track label.
 * @param index The banner index, taken modulo the banner count internally by the geometry.
 * @ghidraAddress 0x1bcb34
 */
- (void)playBannerThumbnail:(int)index;

/**
 * @brief Enables or disables thumbnail playback, playing or muting the centred banner.
 * @param mute Whether playback should be active (subject to the sample-play mode).
 * @ghidraAddress 0x1bcc98
 */
- (void)thumbnailMute:(BOOL)mute;

/**
 * @brief Returns a promotion's cached thumbnail data, enqueuing a download on a miss.
 * @param promotion The promotion whose sample thumbnail is wanted.
 * @return The cached bytes, or nil while a download is in flight or none is possible.
 * @ghidraAddress 0x1bcd48
 */
- (nullable NSData *)getThumbnailData:(nullable StorePromotion *)promotion;

/**
 * @brief Empties the thumbnail cache and cancels all pending downloads.
 * @ghidraAddress 0x1bcf54
 */
- (void)clearThumbnailCache;

/**
 * @brief Downloads one thumbnail on the operation queue and caches its bytes.
 * @param args A two-element array of the @c NSURL and its cache key (the sample name).
 * @ghidraAddress 0x1bcfb4
 */
- (void)downloadImageSync:(nonnull NSArray *)args;

/**
 * @brief Loads and plays a thumbnail's sound clip through the audio manager.
 * @param name The sample name, used as the currently-playing latch.
 * @param data The clip bytes.
 * @ghidraAddress 0x1bd3c8
 */
- (void)playThumbnail:(nullable NSString *)name data:(nullable NSData *)data;

/**
 * @brief Fades out and clears the currently-playing thumbnail clip.
 * @ghidraAddress 0x1bd534
 */
- (void)stopThumbnail;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
