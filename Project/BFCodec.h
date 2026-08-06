/** @file
 * The Blowfish codec.
 *
 * Reconstructed from Ghidra program Jubeat (class BFCodec, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject, from the dyld bind at the class object's superclass slot
 * (0x34d760).
 *
 * The class is a thin Objective-C shell over a C Blowfish implementation, adding CBC chaining and a
 * length trailer of its own. @c -cipherInit: alone has 189 cross-references, so essentially every
 * encrypted asset and request in the application passes through here.
 */

#import <Foundation/Foundation.h>

#import "BFCodecContext.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A Blowfish cipher that works in place on an @c NSMutableData.
 */
@interface BFCodec : NSObject

/**
 * @brief Builds a codec with a zeroed chaining vector and a fresh key schedule.
 * @return The initialised codec.
 * @ghidraAddress 0x94978
 */
- (instancetype)init;

/**
 * @brief Sets the key from a raw buffer, and resets the chaining vector to its fixed value.
 *
 * The vector is **not** derived from the key or from anything else — it is eight bytes written
 * literally into the ivar. See TYPES_PENDING.md.
 *
 * @param key The key material.
 * @param length The key's length in bytes.
 * @ghidraAddress 0x949e0
 */
- (void)cipherInit:(const char *)key length:(int)length;

/**
 * @brief Sets the key from a data buffer.
 *
 * Callers pass a 16-byte MD5 digest. A nil key returns without touching anything, so the codec
 * keeps whatever key it had.
 *
 * @param key The key material.
 * @ghidraAddress 0x94a58
 */
- (void)cipherInit:(nullable NSData *)key;

/**
 * @brief Encrypts a buffer in place, growing it to hold the padding and a length trailer.
 *
 * The buffer is resized to @c (length @c + @c 15) @c & @c ~7 : the plaintext rounded up to a block
 * boundary, plus one more block holding the original length. Chaining is CBC from the fixed vector.
 *
 * @param data The buffer to encrypt, modified in place.
 * @return The buffer's new length.
 * @ghidraAddress 0x94aec
 */
- (unsigned int)encipher:(nullable NSMutableData *)data;

/**
 * @brief Decrypts a buffer in place.
 *
 * Both of the trailer's words are checked before anything is decrypted, and the buffer is truncated
 * back to the plaintext afterwards. The return type is @c BOOL rather than the @c void this header
 * previously claimed, from the metadata encoding @c B24\@0:8\@16 .
 *
 * @param data The buffer to decrypt, modified in place.
 * @return NO when the trailer does not describe the buffer, YES otherwise.
 * @ghidraAddress 0x94e20
 */
- (BOOL)decipher:(nullable NSMutableData *)data;

/**
 * @brief Wipes the chaining vector and releases the key schedule.
 * @ghidraAddress 0x9510c
 */
- (void)dealloc;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
