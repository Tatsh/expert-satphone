/**
 * @file
 * The application's Blowfish key factories.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * Each of these takes no receiver argument and belongs to no class, so the reconstruction rules'
 * search for an owning class is exhausted and they stay free functions. Each derives a Blowfish key
 * as the MD5 digest of a fixed passphrase and returns it as 16 bytes of @c NSData , ready to hand
 * to
 * @c -[BFCodec cipherInit:] . The passphrases are assembled on the stack in pieces — a 16-byte
 * @c q -register store of a shared rodata literal at 0x28f980 followed by register immediates — so
 * that no full passphrase appears contiguously in the file. The reconstructions below fold each
 * assembly back into the plaintext string it spells, with the decoded value in a comment.
 *
 * Two more members of the same seven-function cluster, @c GetBgmCipherKey (0x7f7a0) and
 * @c CreateResourceDataCipherKey (0x7fa54), live elsewhere in the tree.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/**
 * The Blowfish key for encrypted texture assets.
 *
 * @c MD5("copious plus knit ripples") — a 25-character passphrase.
 *
 * @return The key material, 16 bytes, to be handed to @c -[BFCodec cipherInit:] .
 * @ghidraAddress 0x7f6ec
 */
NSData *CreateTextureCipherKey(void);

/**
 * The Blowfish key for encrypted tune/music metadata.
 *
 * @c MD5("Konami Bemani Mobile iOS") — a 24-character passphrase. Its rodata prefix is shared with
 * @c GetBgmCipherKey , which differs only in the "iOS"/"iPad" tail, so the two produce entirely
 * different keys.
 *
 * @return The key material, 16 bytes, to be handed to @c -[BFCodec cipherInit:] .
 * @ghidraAddress 0x7f854
 */
NSData *CreateTuneInfoCipherKey(void);

/**
 * The Blowfish key for the encrypted save file.
 *
 * @c MD5("js^_Yjs5ea`YUe6FQSAH;@S") — a 23-character obfuscated passphrase. The save-file encrypt
 * and decrypt paths each derive the key independently rather than sharing one.
 *
 * @return The key material, 16 bytes, to be handed to @c -[BFCodec cipherInit:] .
 * @ghidraAddress 0x7f904
 */
NSData *CreateSaveDataCipherKey(void);

/**
 * The Blowfish key protecting the "Lab" URL and its table view.
 *
 * @c MD5("js^_YjfYXH`_]MQM;6.") — a 19-character obfuscated passphrase, the shortest of the
 * cluster.
 * @c -[JubeatAppDelegate application:didFinishLaunchingWithOptions:] open-codes this same
 * derivation inline (see @c CreateLabEncryptedData ) rather than calling here.
 *
 * @return The key material, 16 bytes, to be handed to @c -[BFCodec cipherInit:] .
 * @ghidraAddress 0x7f9b0
 */
NSData *CreateLabUrlCipherKey(void);

/**
 * The Blowfish key for per-sheet mission data.
 *
 * @c MD5("jubeatmissiondata") — a 17-character passphrase. Distinct from @c CreateSaveDataCipherKey
 * despite both being save-related: that one guards the main save file, this one the mission
 * records.
 *
 * @return The key material, 16 bytes, to be handed to @c -[BFCodec cipherInit:] .
 * @ghidraAddress 0x7faf0
 */
NSData *CreateMissionDataCipherKey(void);

/**
 * The Blowfish key for the challenge-resource (panel) data.
 * @return The key material, to be handed to @c -[BFCodec cipherInit:] .
 * @ghidraAddress 0x7fa54
 */
NSData *CreateResourceDataCipherKey(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
