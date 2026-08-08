/** @file
 * The settings-screen credits view controller.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsCreditsViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. It lays out the
 * staff-roll credits as a column of white @c UILabel rows over a black background, each row driven
 * by a small property-list string and positioned by @c -addCredit:atPoint:span:nameSpan:. The
 * column metrics differ between the pad and the handset, and again for the four-inch handset.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A view controller presenting the staff credits in the settings screen.
 */
@interface SettingsCreditsViewController : UIViewController

/**
 * @brief Sets the navigation title to "CREDITS" and, on iOS 7 and later, opts the layout into
 *        extending under opaque bars.
 * @return The initialised controller.
 * @ghidraAddress 0xe90b4
 */
- (nullable instancetype)init;

/**
 * @brief Builds the credits column: a black background and a stack of white role and name labels,
 *        laid out per device idiom.
 * @ghidraAddress 0xe9968
 */
- (void)loadView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
