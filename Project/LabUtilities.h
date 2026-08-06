/** @file
 * The jubeat Lab URL cipher.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * The one caller is @c -[JubeatAppDelegate application:didFinishLaunchingWithOptions:], which uses
 * it once on first launch to obfuscate the Lab URL before storing it in user defaults.
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
 * One edge is worth knowing about: @c -dataUsingEncoding: returns nil for input it cannot encode,
 * and @c +dataWithData: raises on nil rather than returning it, so a malformed string throws rather
 * than producing the nil this function's nil check implies it handles.
 *
 * @param pszString The plaintext. nil is accepted and yields nil.
 * @return The ciphertext, autoreleased, or nil when the input was nil.
 * @ghidraAddress 0x8011c
 */
NSMutableData *_Nullable CreateLabEncryptedData(NSString *_Nullable pszString);

/**
 * @brief The Blowfish key the packed asset archives are enciphered with.
 *
 * DECLARED ONLY. Despite the name it is not limited to audio: @c -[ArtworkLoader loadArtwork] uses
 * it to decipher artwork out of the same archives. The name is Ghidra's, already applied to the
 * function in the program database.
 *
 * @return The key material, to be handed to @c -[BFCodec cipherInit:] .
 * @ghidraAddress 0x7f7a0
 */
NSData *_Nullable GetBgmCipherKey(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
