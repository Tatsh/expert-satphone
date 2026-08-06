/** @file
 * The Blowfish codec.
 *
 * Reconstructed from Ghidra program Jubeat (class BFCodec, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the two members
 * @c CreateLabEncryptedData sends are declared. The class object is at 0x3481d8, and
 * @c -cipherInit: alone has 189 cross-references, so this is one of the most widely used classes in
 * the binary and its own implementation is a substantial separate job.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A Blowfish cipher that works in place on an @c NSMutableData.
 */
@interface BFCodec : NSObject

/**
 * @brief Sets the key from a data buffer.
 *
 * Callers pass a 16-byte MD5 digest. There is a sibling @c -cipherInit:length: at 0x949e0 that
 * takes an explicit length; this one does not, so the buffer's own length is the key length.
 * DECLARED ONLY.
 *
 * @param key The key material.
 * @ghidraAddress 0x94a58
 */
- (void)cipherInit:(NSData *)key;
/**
 * @brief Encrypts a buffer in place.
 *
 * In place is not an inference: @c CreateLabEncryptedData makes a mutable copy purely so this can
 * modify it, and then returns that same object rather than any result of this call. DECLARED ONLY.
 *
 * @param data The buffer to encrypt, modified in place.
 * @ghidraAddress 0x94aec
 */
- (void)encipher:(NSMutableData *)data;
/**
 * @brief Decrypts a buffer in place.
 *
 * The counterpart to @c -encipher: , and in place for the same reason: @c -[ArtworkLoader
 * loadArtwork] passes the unzipped bytes here and then reads the *same* object back into
 * @c -[UIImage initWithData:] , never a return value. DECLARED ONLY.
 *
 * @param data The buffer to decrypt, modified in place.
 */
- (void)decipher:(NSMutableData *)data;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
