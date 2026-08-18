/** @file
 * The navigation controller that manages downloaded jubeatLab custom-sequence (jcf) files.
 *
 * Reconstructed from Ghidra program Jubeat (class JcfManageNavController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * A @c UINavigationController that wraps a single @c EditFileListViewDeleteController listing the
 * player's downloaded custom-sequence files so they can be deleted or shared. It sets up its own
 * navigation bar chrome and a left "Close" button that notifies the delegate.
 */

#import <UIKit/UIKit.h>

#import "RotatableNavigationController.h"

@class EditFileListViewDeleteController;
@class JcfManageNavController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c JcfManageNavController tells its owner. The delegate is messaged dynamically
 * behind @c -respondsToSelector: ; this protocol only documents the selector.
 */
@protocol JcfManageNavControllerDelegate <NSObject>
@optional
/** @brief The user closed the custom-sequence management list. */
- (void)editFileListViewCancel:(nullable JcfManageNavController *)controller;
@end

/**
 * @brief Hosts the downloaded custom-sequence management list in a navigation controller.
 */
@interface JcfManageNavController : RotatableNavigationController

/**
 * @brief The object told when the management list is closed.
 *
 * A weak reference (the binary stores it with @c objc_storeWeak).
 */
@property(nonatomic, weak, nullable) id aDelegate;

/**
 * @brief The wrapped list of downloaded custom-sequence files.
 */
@property(nonatomic, strong, nullable) EditFileListViewDeleteController *pFileListView;

/**
 * @brief The designated initialiser: builds the wrapped file list, the navigation bar chrome, and
 * the left "Close" button.
 * @param delegate The object told when the list is closed. Stored weakly and set as the wrapped
 * list's delegate.
 * @param fileList The downloaded custom-sequence files to list.
 * @param selName The name of the file to select initially.
 * @return The initialised navigation controller.
 * @ghidraAddress 0x1f2284
 */
- (instancetype)init:(nullable id<JcfManageNavControllerDelegate>)delegate
            fileList:(nullable NSArray *)fileList
             selName:(nullable NSString *)selName;

/**
 * @brief Forwards the share flag to the wrapped file list.
 * @param shareFlg Whether the wrapped list is presented for sharing.
 * @ghidraAddress 0x1f2774
 */
- (void)setShareFlg:(BOOL)shareFlg;

/**
 * @brief Forwards the tune id to the wrapped file list.
 * @param tuneID The tune id whose files are listed.
 * @ghidraAddress 0x1f27bc
 */
- (void)setTuneID:(int)tuneID;

/**
 * @brief Reloads the wrapped file list with a new set of files.
 * @param fileList The downloaded custom-sequence files to list.
 * @ghidraAddress 0x1f2f28
 */
- (void)reloadList:(nullable NSArray *)fileList;

/**
 * @brief Left "Close" button action: notifies the delegate that the list was closed.
 * @param sender The bar button item.
 * @ghidraAddress 0x1f2d2c
 */
- (void)pushClose:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
