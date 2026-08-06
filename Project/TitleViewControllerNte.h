/** @file
 * The title screen, NagaCora collaboration theme.
 *
 * Reconstructed from Ghidra program Jubeat (class TitleViewControllerNte, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. The class object is at 0x348a38.
 *
 * Selected by @c -[RootViewController createKnitTitleViewController] only when the delegate reports
 * @c isNagaCoraMode and not @c isHinabitaMode, so the hinabita collaboration wins when both flags
 * are set. It is also the only class @c -titleSwitch tests for by kind, and that method always
 * replaces it with a @c TitleViewControllerKnt.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The title screen in NagaCora collaboration livery.
 */
@interface TitleViewControllerNte : UIViewController

/** @brief Begins the title sequence. DECLARED ONLY. */
- (void)start;
/**
 * @brief Halts the title sequence before teardown.
 *
 * @c -titleSwitch sends this only when the outgoing title is of this class, so the other three
 * title screens are torn down without it. DECLARED ONLY.
 */
- (void)stopAnimation;
/** @brief Reveals the logo once the screen has faded in. DECLARED ONLY. */
- (void)showLogo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
