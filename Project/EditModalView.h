/**
 * @file
 * @brief The edit-mode modal form for a custom sequence's metadata.
 *
 * Reconstructed from Ghidra program Jubeat (class EditModalView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * Despite the @c View suffix the class is a @c UINavigationController : @c -initWithType: chains up
 * to @c -[UINavigationController init] , and every lifecycle override forwards to
 * @c UINavigationController . It wraps a single @c EditModalTableViewController whose navigation
 * item carries the Cancel and Update bar-button items.
 */

#import <UIKit/UIKit.h>

#import "EditModalTableViewController.h"

@class EditModalView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What an @c EditModalView tells its owner.
 *
 * The protocol's name is the binary's own, taken from the delegate ivar's encoding.
 */
@protocol EditModalViewDelegate <NSObject>

@required
/**
 * @brief Sent to persist the edited metadata.
 *
 * Sent unconditionally (no @c -respondsToSelector: guard) from both @c -pushUpdate: and
 * @c -selectUpdate: .
 */
- (void)editModalViewDelegateSaveEditFile;

@optional
/**
 * @brief Sent when the modal is dismissed.
 * @param view The modal being closed.
 */
- (void)editModalViewClose:(EditModalView *)view;

/**
 * @brief Sent when the edited entry should be re-selected after saving.
 * @param view The modal.
 */
- (void)selectUpdate:(EditModalView *)view;

@end

/**
 * @brief A modal navigation controller that edits a custom sequence's metadata.
 */
@interface EditModalView : UINavigationController <EditModalTableViewControllerDelegate>

/**
 * @brief The object told about close, save, and re-select events.
 *
 * Stored weakly (the binary uses @c objc_storeWeak / @c objc_loadWeakRetained ).
 * @ghidraAddress 0x1e5794
 * @ghidraAddress 0x1e57b4
 */
@property(nonatomic, weak, nullable) id<EditModalViewDelegate> editDelegate;

/**
 * @brief Builds the modal for a given edit mode.
 * @param type The edit mode. A value of @c 1 enables uploading in the wrapped table controller and
 *     suppresses the Cancel and Update bar-button items.
 * @return The initialised controller.
 * @ghidraAddress 0x1e5060
 */
- (instancetype)initWithType:(int)type;

/**
 * @brief Builds a configured text field for the given frame and adds it to the view.
 *
 * @param textField Unused; the method builds its own field.
 * @param frame The field's frame.
 * @ghidraAddress 0x1e4e38
 */
- (void)setTextField:(nullable UITextField *)textField frame:(CGRect)frame;

/**
 * @brief Dismisses the modal, synchronising user defaults and notifying the delegate.
 * @param sender The bar-button item.
 * @ghidraAddress 0x1e547c
 */
- (void)pushClose:(nullable id)sender;

/**
 * @brief Saves the edited metadata, then closes the modal.
 * @param sender The bar-button item.
 * @ghidraAddress 0x1e5568
 */
- (void)pushUpdate:(nullable id)sender;

/**
 * @brief Saves the edited metadata, then asks the delegate to re-select the entry.
 * @param sender The bar-button item.
 * @ghidraAddress 0x1e5600
 */
- (void)selectUpdate:(nullable id)sender;

/**
 * @brief Presents the modal. Empty in the binary.
 * @ghidraAddress 0x1e56fc
 */
- (void)openEditModal;

/**
 * @brief Tears the modal down. Empty in the binary.
 * @ghidraAddress 0x1e5788
 */
- (void)terminate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
