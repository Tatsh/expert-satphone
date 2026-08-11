/** @file
 * The edit-mode "how to" help view controller.
 *
 * Reconstructed from Ghidra program Jubeat (class EditHowtoViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. It presents a
 * horizontally paging @c UIScrollView holding two help images (@c edithelp01 and @c edithelp02)
 * over a black background, with a non-interactive @c UIPageControl tracking the current page.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A view controller presenting the "how to" help pages for edit mode.
 */
@interface EditHowtoViewController : UIViewController <UIScrollViewDelegate>

/** @brief The paging scroll view holding the help images.
 *  @ghidraAddress 0x20a1c8 (getter), 0x20a1d8 (setter) */
@property(nonatomic, strong, nullable) UIScrollView *scrView;

/** @brief The page indicator tracking the current help page.
 *  @ghidraAddress 0x20a1ec (getter), 0x20a1fc (setter) */
@property(nonatomic, strong, nullable) UIPageControl *pageCtrl;

/**
 * @brief Sets the preferred content size to the pad help area.
 * @return The initialised controller.
 * @ghidraAddress 0x209894
 */
- (instancetype)init;

/**
 * @brief Builds the paging scroll view, its two help images, and the page indicator.
 * @ghidraAddress 0x209900
 */
- (void)loadView;

/**
 * @brief Updates the page indicator to the page nearest the scroll view's content offset.
 * @param scrollView The scroll view that scrolled.
 * @ghidraAddress 0x209f10
 */
- (void)scrollViewDidScroll:(nonnull UIScrollView *)scrollView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
