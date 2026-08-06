/** @file
 * The jubeat Lab URL cipher.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: only the declaration is recovered. The body is fully analysed but needs a
 * @c BFCodec declaration first, so it is not written yet.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Blowfish-encrypts a string with the Lab key.
 *
 * The launch handler calls this once, on first launch only, to turn the plaintext Lab URL into the
 * blob it persists under the "PrefjubeatLabURL" user default.
 *
 * The returned object is the same buffer that was enciphered, not a copy, so it is mutable and a
 * caller could keep changing it. The key is an MD5 of a 19-character passphrase that this function
 * rebuilds on its own stack rather than calling @c CreateLabUrlCipherKey at 0x7f9b0, though the
 * passphrase is byte-for-byte the same.
 *
 * @param pszString The plaintext. nil is accepted and yields nil.
 * @return The ciphertext, autoreleased, or nil when the input was nil.
 * @ghidraAddress 0x8011c
 */
NSMutableData *_Nullable CreateLabEncryptedData(NSString *_Nullable pszString);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
