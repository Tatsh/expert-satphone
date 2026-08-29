/**
 * @file
 * The terms/policy menu table for the in-app terms-of-service screen.
 *
 * Reconstructed from Ghidra program Jubeat (class TermsViewController, image base 0x100000000).
 * All @c \@ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableViewController, confirmed by the chain-up in @c -initWithStyle: . The
 * class is a grouped table of six rows: four legal documents opened in a
 * @c SettingsPolicyViewController (content, currency, payment-services, and minors), a specified
 * commercial transactions notice opened in the system browser, and an inquiry row opened in a
 * @c SettingsInquiryViewController. It is the hosted child of @c TermsNavController.
 */

#import <UIKit/UIKit.h>

// The close-notification delegate is the same untyped (@) slot as SettingsNavController's and is
// pushed down from TermsNavController, so the shared SettingsNavControllerDelegate protocol is
// reused rather than declaring a duplicate.
#import "SettingsNavController.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A grouped table listing the terms/policy documents, each row opening its target page.
 */
@interface TermsViewController : UITableViewController

/**
 * The owner notified when the screen closes. Stored only; pushed down from
 *        @c TermsNavController and untyped (@c \@ ) in the metadata, so it reuses the sibling
 *        @c SettingsNavControllerDelegate protocol.
 * @ghidraAddress 0x1141f0
 * @ghidraAddress 0x114210
 */
@property(weak, nonatomic, nullable) id<SettingsNavControllerDelegate> settingsDelegate;

/**
 * Builds the two backing arrays: the per-section row values (0 to 5) and the per-row cell
 *        styles (all zero).
 * @ghidraAddress 0x113094
 */
- (void)createMenuTable;

/**
 * Sets the navigation title and builds the menu table.
 * @param style The table view style. Passed to the superclass.
 * @return The initialised controller.
 * @ghidraAddress 0x1132a0
 */
- (instancetype)initWithStyle:(UITableViewStyle)style;

/**
 * Maps a menu value to its index path within a given section, or @c nil when absent.
 * @param targetPath The menu value to locate.
 * @param section The section to search.
 * @return The index path of the matching row, or @c nil.
 * @ghidraAddress 0x113ed0
 */
- (nullable NSIndexPath *)getTargetPath:(int)targetPath inSection:(int)section;

/**
 * Maps a menu value to its index path across all sections, or @c nil when absent.
 * @param targetPath The menu value to locate.
 * @return The index path of the matching row, or @c nil.
 * @ghidraAddress 0x11405c
 */
- (nullable NSIndexPath *)getTargetPath:(int)targetPath;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
