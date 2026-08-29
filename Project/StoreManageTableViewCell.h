/**
 * @file
 * @brief A row of the store's purchase-management table.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreManageTableViewCell, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares one method beyond the property
 * accessors and it is implemented.
 *
 * The superclass was read from the class object's superclass slot at 0x34d620, which binds to
 * @c _OBJC_CLASS_$_UITableViewCell at load time rather than being stored in the file.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A subtitle-style cell carrying a track name, an artist, and an action button.
 */
@interface StoreManageTableViewCell : UITableViewCell

/**
 * @brief The label showing the track name.
 *
 * This class's own property, distinct from the @c titleLabel that @c UIButton exposes — the
 * initialiser touches both.
 */
@property(nonatomic, strong, nullable) UILabel *titleLabel;
/** @brief The label showing the artist. */
@property(nonatomic, strong, nullable) UILabel *artistLabel;
/** @brief The row's action button. */
@property(nonatomic, strong, nullable) UIButton *btn;

/**
 * @brief Builds the row, sizing the button's text for the device idiom.
 *
 * @param isPad Whether to use the larger of the two font sizes.
 * @param reuseIdentifier Passed straight to the superclass.
 * @return The initialised cell.
 * @ghidraAddress 0x9096c
 */
- (instancetype)initWithPad:(BOOL)isPad reuseIdentifier:(nullable NSString *)reuseIdentifier;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
