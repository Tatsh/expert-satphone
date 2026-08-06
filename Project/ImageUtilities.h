/** @file
 * Image loading helpers.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: only the declaration is recovered.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Loads a bundled PNG at the scale the current screen wants.
 *
 * Callers pass a bare resource name with no extension and no @c \@2x suffix.
 *
 * @param pszBaseName The resource's base name.
 * @return The loaded image, or nil.
 * @ghidraAddress 0x7ebe8
 */
UIImage *_Nullable LoadScaledPngImage(NSString *pszBaseName);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
