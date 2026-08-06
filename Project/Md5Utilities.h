/** @file
 * MD5 helpers.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
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
 * Plain CommonCrypto MD5 over @c strlen bytes, rendered as 32 lower-case hexadecimal characters.
 * The binary unrolls the sixteen per-byte appends rather than looping.
 *
 * @param lpcszInput The string to hash, as UTF-8 bytes.
 * @return The digest rendered in hexadecimal, 32 characters long.
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
