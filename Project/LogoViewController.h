/** @file
 * The startup logo screen.
 *
 * Reconstructed from Ghidra program Jubeat (class LogoViewController, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its one known caller. The class object is at
 * 0x348a58.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The screen shown while the application starts up.
 */
@interface LogoViewController : UIViewController

/**
 * @brief Begins the logo sequence.
 *
 * Sent by @c -[RootViewController startLogo] once the controller and its view are installed. The
 * selector is the same one @c -[PurchaseManager start] uses — selectors are shared across classes,
 * so that is not evidence the two are related. DECLARED ONLY.
 */
- (void)start;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
