/** @file
 * The title screen, knit theme.
 *
 * Reconstructed from Ghidra program Jubeat (class TitleViewControllerKnt, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. The class object is at 0x348a30.
 *
 * Built by @c -[RootViewController createKnitTitleViewController] for @c JubeatThemeKnit, and again
 * by @c -titleSwitch, which always swaps to this one.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The title screen in knit livery.
 */
@interface TitleViewControllerKnt : UIViewController

/** @brief Begins the title sequence. DECLARED ONLY. */
- (void)start;
/** @brief Halts the title sequence before teardown. DECLARED ONLY. */
- (void)stopAnimation;
/** @brief Reveals the logo once the screen has faded in. DECLARED ONLY. */
- (void)showLogo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
