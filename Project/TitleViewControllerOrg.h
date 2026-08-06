/** @file
 * The title screen, original theme.
 *
 * Reconstructed from Ghidra program Jubeat (class TitleViewControllerOrg, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. The class object is at 0x348a78.
 *
 * One of three title screens the transition dispatcher picks between on
 * @c JubeatAppDelegate.currentTheme. This is the fallback: theme 1 gets
 * @c TitleViewControllerRpl and theme 2 goes through
 * @c -[RootViewController createKnitTitleViewController], while every other value lands here.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The title screen in the game's own livery.
 */
@interface TitleViewControllerOrg : UIViewController

/**
 * @brief Begins the title sequence.
 *
 * The selector is plain @c start, shared with @c LogoViewController and @c PurchaseManager.
 * DECLARED ONLY.
 */
- (void)start;
/**
 * @brief Halts the title sequence before teardown. DECLARED ONLY.
 */
- (void)stopAnimation;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
