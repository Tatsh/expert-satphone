/**
 * @file
 * The challenge-mode menu: a seven-row table over a background plate, with a close button
 * and an unread-present badge on its first row.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeMenuView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, taken from the dyld bind at the class object's superclass slot.
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "PurchaseManager.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * What a @c ChallengeMenuView tells its owner (the challenge menu's root view).
 *
 * The delegate is weak and untyped in the metadata (@c T@,W,N); it is messaged directly rather than
 * through a declared conformance, so both selectors are effectively required.
 */
@protocol ChallengeMenuViewDelegate <NSObject>
/** The close button was tapped. */
- (void)closeRootMenu;
/**
 * A menu row was tapped. The argument boxes the row's tag.
 * @param menu The tapped row's tag, boxed.
 */
- (void)selectMenu:(nullable NSNumber *)menu;
@end

/**
 * The challenge-mode landing menu.
 *
 * A plain @c UITableView of seven fixed rows sits on a centred background plate beside a close
 * button. The first row carries a numeric badge showing the count of unread presents. Tapping the
 * store row (tag 6) drives an in-app-purchase restore flow through @c PurchaseManager, guarded by a
 * progress dialog and a confirmation alert.
 */
@interface ChallengeMenuView : UIView <UITableViewDataSource,
                                       UITableViewDelegate,
                                       AlertViewManagerDelegate,
                                       PurchaseManagerDelegate>

/**
 * The object told about close and row-selection events. Held weakly.
 * @ghidraAddress 0x44180 (getter), 0x441a0 (setter)
 */
@property(nonatomic, weak, nullable) id<ChallengeMenuViewDelegate> aDelegate;

/**
 * Builds the menu: background plate, close button, digit-artwork cache, and the table.
 * @param frame The view's frame.
 * @return The initialised view.
 * @ghidraAddress 0x426d4
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * The close button's action: tells the delegate to close the root menu.
 * @param sender The tapped button. Unused.
 * @ghidraAddress 0x42cc4
 */
- (void)closeSettingMenu:(nullable id)sender;

/**
 * A menu row's action.
 *
 * The store row (tag 6) either shows a link-purchases confirmation alert, or, when a consume
 * receipt is already pending, drops straight into the progress dialog and refreshes the receipt.
 * Every other row records its tag and hands it to the delegate.
 *
 * @param sender The tapped button, whose tag identifies the row.
 * @ghidraAddress 0x42d04
 */
- (void)tapMenu:(nullable id)sender;

/**
 * Alert-button callback: begins the purchase restore when the link-purchases alert is
 * confirmed.
 * @param info The alert-info dictionary carrying @c "Tag" and @c "btnMessage".
 * @ghidraAddress 0x42ff0
 */
- (void)alertSelect:(nullable NSDictionary *)info;

/**
 * Presents the modal progress dialog, faded in, and disables interaction beneath it.
 * @param message The single-line status text.
 * @ghidraAddress 0x43158
 */
- (void)showVerifyDialog:(nullable NSString *)message;

/**
 * Removes the progress dialog and re-enables interaction.
 * @ghidraAddress 0x4352c
 */
- (void)hideVerifyDialog;

/**
 * Restore failed: drops the purchase delegate and hides the dialog.
 * @param error The failure. Unused.
 * @ghidraAddress 0x43578
 */
- (void)restoreFailed:(nullable NSError *)error;

/**
 * Restore finished with nothing to restore: hides the dialog and shows the completion alert.
 * @ghidraAddress 0x435d8
 */
- (void)restoreNothing;

/**
 * Restore succeeded: hides the dialog and shows the completion alert.
 *
 * Byte-for-byte identical to @c -restoreNothing in the binary.
 * @ghidraAddress 0x43768
 */
- (void)restoreSucceeded;

/**
 * Purchase succeeded: shows a follow-up link-purchases confirmation alert.
 * @param productID The purchased product identifier. Unused.
 * @ghidraAddress 0x438f8
 */
- (void)purchaseSucceeded:(nullable NSString *)productID;

/**
 * Purchase failed: shows a network-error alert for a code-1 failure, then hides the dialog.
 * @param productID The product identifier. Unused.
 * @param error The failure; its @c code selects the alert.
 * @ghidraAddress 0x43ae8
 */
- (void)purchaseFailed:(nullable NSString *)productID error:(nullable NSError *)error;

/**
 * Refreshes the present badge on the first row. Forwards to @c -setPresentMark.
 * @ghidraAddress 0x43cb0
 */
- (void)refreshView;

/**
 * Draws a count on the present badge's per-digit image views, or clears them.
 * @param num The count. Clamped to 999; a single digit lands in the middle of the three-wide row.
 * @ghidraAddress 0x43cbc
 */
- (void)setPresentNum:(int)num;

/**
 * Reads the unread-present count and pushes it onto the first row's cell.
 * @ghidraAddress 0x43e64
 */
- (void)setPresentMark;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
