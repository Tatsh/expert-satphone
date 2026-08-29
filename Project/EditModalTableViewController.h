/**
 * @file
 * @brief The grouped-table content controller inside the edit-metadata modal.
 *
 * Reconstructed from Ghidra program Jubeat (class EditModalTableViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * This is the @c UITableViewController wrapped by @c EditModalView (a @c UINavigationController).
 * It lays out one section of three editable text fields (chart name, editor name, and comment,
 * each with a live character-count label), a level section carrying a 1-to-10 scale and a slider,
 * a copy-permission switch section, and (when uploading is enabled) an upload button section.
 */

#import <UIKit/UIKit.h>

@class EditModalTableViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What an @c EditModalTableViewController tells its owner.
 *
 * The delegate ivar is a bare weak @c id in the binary, so this protocol collects the one selector
 * the controller actually sends it. The concrete delegate is the wrapping @c EditModalView .
 */
@protocol EditModalTableViewControllerDelegate <NSObject>

@optional
/**
 * @brief Sent when the upload row is tapped, asking the owner to save and re-select the entry.
 * @param sender The controller.
 */
- (void)selectUpdate:(EditModalTableViewController *)sender;

@end

/**
 * @brief The edit-metadata form: text fields, a level slider, a copy switch, and an upload row.
 */
@interface EditModalTableViewController
    : UITableViewController <UITextViewDelegate, UITextFieldDelegate>

/**
 * @brief The object told about the upload-row tap.
 *
 * Stored weakly (the binary uses @c objc_storeWeak / @c objc_loadWeakRetained ).
 * @ghidraAddress 0x1e4d2c
 * @ghidraAddress 0x1e4d4c
 */
@property(nonatomic, weak, nullable) id<EditModalTableViewControllerDelegate> delegate;

/**
 * @brief Builds the controller, choosing whether the upload section is present.
 * @param enableUpload Whether the extra upload-button section is shown.
 * @return The initialised controller.
 * @ghidraAddress 0x1e2ec0
 */
- (instancetype)initEnableUpload:(BOOL)enableUpload;

/**
 * @brief Persists the edited field texts, level, and copy flag to the shared edit data.
 * @ghidraAddress 0x1e3d8c
 */
- (void)setEditorInfo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
