/** @file
 * The title screen, REFLEC BEAT plus theme.
 *
 * Reconstructed from Ghidra program Jubeat (class TitleViewControllerRpl, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. The class object is at 0x348a70.
 *
 * Selected when @c JubeatAppDelegate.currentTheme is 1. The "Rpl" in the runtime name is what fixes
 * the theme numbering: this game ships a REFLEC BEAT plus skin, which is the sibling title whose
 * reconstruction lives in ../rbplus-src.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The title screen in REFLEC BEAT plus livery.
 */
@interface TitleViewControllerRpl : UIViewController

/**
 * @brief Begins the title sequence. DECLARED ONLY.
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
