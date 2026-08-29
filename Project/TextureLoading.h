/**
 * @file
 * @brief The bundled-resource texture and image loaders.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * These five routines form one contiguous cluster in the binary (0x124ce8..0x125448) that turns a
 * bundled asset into a @c Texture2D atlas, a texture sub-image, or a plain @c UIImage . Each takes
 * its collaborators — the texture, the @c BFCodec cipher — as explicit arguments and none carries
 * a @c self / @c _cmd pair, so they are genuine C free functions rather than methods of
 * @c Texture2D or @c BFCodec ; the reconstruction rules' search for an owning class is exhausted
 * (the two @c CreateTexture2DFrom* factories vend a @c Texture2D but are not registered in its
 * runtime method table, exactly as @c LoadScaledPngImage is not a @c UIImage method). No embedded
 * @c __FILE__ has been located, so this file's name is this tree's own; it is recorded in
 * TYPES_PENDING.md as unproven.
 *
 * The encrypted variants all skip a fixed four-byte header that precedes the image payload, and
 * read their sprite-rect @c .plist unencrypted even when the image itself is enciphered.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "BFCodec.h"
#import "Texture2D.h"

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Decrypts an encrypted image blob in place and builds a @c UIImage from it.
 *
 * Deciphers @p encryptedData through @p cipher — which rewrites the buffer in place — then builds
 * an image from the payload after a fixed four-byte header. The header skip is unconditional and
 * unvalidated, so a plaintext buffer fed here loses its first four bytes and yields @c nil .
 *
 * @param cipher The Blowfish codec, already keyed.
 * @param encryptedData The ciphertext. Mutated in place by the decrypt.
 * @return An autoreleased image, or @c nil when the decrypt failed.
 * @ghidraAddress 0x125448
 */
UIImage *_Nullable CreateImageFromEncryptedData(BFCodec *cipher, NSMutableData *encryptedData);

/**
 * @brief Loads a bundled PNG and blits it into an existing texture atlas at a point.
 *
 * Resolves @p resourceName as a @c .png in the main bundle and, if present, draws it into
 * @p texture at @p point . A missing resource leaves the atlas untouched and returns @c NO .
 *
 * @param texture The atlas to patch.
 * @param resourceName The bundle resource name, without the @c .png extension.
 * @param point The destination origin in texels.
 * @return @c YES when the resource existed and was blitted, @c NO otherwise.
 * @ghidraAddress 0x124ce8
 */
BOOL LoadTextureSubImageFromResource(Texture2D *texture, NSString *resourceName, CGPoint point);

/**
 * @brief Decrypts a bundled @c .tex asset and blits it into an existing texture atlas at a point.
 *
 * The encrypted twin of @c LoadTextureSubImageFromResource : reads the @c .tex, deciphers it
 * through @p cipher , skips the four-byte header, and blits the decoded image into @p texture at
 * @p point .
 *
 * @param texture The atlas to patch.
 * @param resourceName The bundle resource name, without the @c .tex extension.
 * @param cipher The Blowfish codec, already keyed.
 * @param point The destination origin in texels.
 * @return @c YES on success; @c NO if the resource was missing, the decrypt failed, or the bytes
 *         were not a valid image.
 * @ghidraAddress 0x124e00
 */
BOOL LoadTextureSubImageFromEncryptedTex(Texture2D *texture,
                                         NSString *resourceName,
                                         BFCodec *cipher,
                                         CGPoint point);

/**
 * @brief Vends a fully-populated @c Texture2D atlas from a bundled PNG plus its sprite-rect plist.
 *
 * Loads @p resourceName as a @c .png, wraps it in a @c Texture2D , then sets the sprite table from
 * the matching @c .plist . A missing @c .plist fails the whole load even when the PNG decoded; the
 * two files must ship as a pair.
 *
 * @param resourceName The base name shared by both files, without an extension.
 * @return An autoreleased atlas with its sprite table set, or @c nil .
 * @ghidraAddress 0x124fec
 */
Texture2D *_Nullable CreateTexture2DFromPngResource(NSString *resourceName);

/**
 * @brief Vends a @c Texture2D atlas from an encrypted @c .tex asset plus its plaintext plist.
 *
 * The encrypted twin of @c CreateTexture2DFromPngResource . Only the image bytes pass through
 * @p cipher ; the sprite-rect @c .plist is read unencrypted.
 *
 * @param resourceName The base name shared by the @c .tex and @c .plist , without an extension.
 * @param cipher The Blowfish codec, already keyed.
 * @return An autoreleased atlas with its sprite table set, or @c nil .
 * @ghidraAddress 0x1251b0
 */
Texture2D *_Nullable CreateTexture2DFromEncryptedTexResource(NSString *resourceName,
                                                             BFCodec *cipher);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
