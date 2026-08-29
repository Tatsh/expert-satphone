/**
 * @file
 * @brief The copyright row of the store detail table.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreDetailCopyrightCell, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares one method beyond the property
 * accessor and it is implemented.
 *
 * The superclass was read from the class object's superclass slot at 0x34ec50, which binds to
 * @c _OBJC_CLASS_$_UITableViewCell at load time rather than being stored in the file.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A non-selectable cell holding wrapped copyright text.
 */
@interface StoreDetailCopyrightCell : UITableViewCell

/**
 * @brief The label the copyright text is set on.
 *
 * Read-only per the property metadata (@c T@"UILabel",R,N,V_labelCopyright); the initialiser
 * assigns the backing ivar directly.
 */
@property(nonatomic, readonly, nullable) UILabel *labelCopyright;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
