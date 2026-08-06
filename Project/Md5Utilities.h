/** @file
 * MD5 helpers.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: only the declaration is recovered; the body is not reconstructed yet.
 *
 * This is one of the few genuine free functions in this tree. It takes no receiver argument and
 * belongs to no class, so the reconstruction rules' search for an owning class is exhausted and it
 * stays a free function.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Hashes a NUL-terminated C string and returns the digest as a hexadecimal string.
 *
 * @param lpcszInput The string to hash, as UTF-8 bytes.
 * @return The digest rendered in hexadecimal.
 * @ghidraAddress 0x7f168
 */
NSString *CreateMd5HexStringFromCString(const char *lpcszInput);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
