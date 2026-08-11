/** @file
 * The @c UIDevice @c SystemVersionCheck category.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base. The runtime metadata records this as category
 * @c SystemVersionCheck on @c UIDevice (category_t at 0x32f640). Only the declaration is
 * reconstructed here: the implementation is supplied outside this tree, so this header exists to
 * type the message sends faithfully.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A numeric OS-version comparison for @c UIDevice.
 */
@interface UIDevice (SystemVersionCheck)

/**
 * @brief Whether the device's OS version is at least @p version, compared numerically.
 * @param version The minimum version string (for example @c \@"9.0" ).
 * @return @c YES when the running version is greater than or equal to @p version.
 * @ghidraAddress 0x1fde90
 */
- (BOOL)systemVersionGreaterEqual:(nonnull NSString *)version;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
