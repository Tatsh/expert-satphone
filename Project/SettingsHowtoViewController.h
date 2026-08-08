/** @file
 * The settings-screen "how to play" view controller.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsHowtoViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. It presents a
 * horizontally paging @c UIScrollView holding five help images (@c howtoplay01 through
 * @c howtoplay05) over a black background, with a non-interactive @c UIPageControl tracking the
 * current page.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A view controller presenting the "how to play" help pages in the settings screen.
 */
@interface SettingsHowtoViewController : UIViewController <UIScrollViewDelegate>

/** @brief The paging scroll view holding the help images.
 *  @ghidraAddress 0xe902c (getter), 0xe903c (setter) */
@property(nonatomic, strong, nullable) UIScrollView *scrView;

/** @brief The page indicator tracking the current help page.
 *  @ghidraAddress 0xe9050 (getter), 0xe9060 (setter) */
@property(nonatomic, strong, nullable) UIPageControl *pageCtrl;

/**
 * @brief Sets the navigation title and, on iOS 7 and later, opts the layout into extending under
 *        opaque bars.
 * @return The initialised controller.
 * @ghidraAddress 0xe86dc
 */
- (nullable instancetype)init;

/**
 * @brief Builds the paging scroll view, its five help images, and the page indicator.
 * @ghidraAddress 0xe8798
 */
- (void)loadView;

/**
 * @brief Updates the page indicator to the page nearest the scroll view's content offset.
 * @param scrollView The scroll view that scrolled.
 * @ghidraAddress 0xe8d74
 */
- (void)scrollViewDidScroll:(nonnull UIScrollView *)scrollView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
