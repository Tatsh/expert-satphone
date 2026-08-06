/** @file
 * The application's own scaled-image loader.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * These are genuine free functions: neither takes a receiver argument and neither belongs to a
 * class, so the reconstruction rules' search for an owning class is exhausted. The file's name is
 * this tree's own, not the binary's — no embedded @c __FILE__ has been located for either routine,
 * so it is recorded in TYPES_PENDING.md as unproven.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Loads a PNG from the bundle at the right Retina variant and tags it with the right scale.
 *
 * The application's replacement for @c +[UIImage imageNamed:], with 479 call sites and no caching.
 * The variant is chosen by @c GetScaledResourcePath, which uses @c _pn2 / @c _pn3 suffixes rather
 * than Apple's @c \@2x convention — so @c -initWithContentsOfFile: cannot infer the scale and the
 * image has to be re-wrapped through @c +imageWithCGImage:scale:orientation: to carry it.
 *
 * @param pszBaseName The resource name, with no scale suffix and no @c .png extension.
 * @return The image at its correct scale, or nil when the file is missing.
 * @ghidraAddress 0x7ebe8
 */
UIImage *_Nullable LoadScaledPngImage(NSString *pszBaseName);

/**
 * @brief The same job as @c LoadScaledPngImage, for the encrypted @c .tex assets.
 *
 * Resolves the variant through the same @c GetScaledResourcePath, reads the file, decrypts it
 * through @c BFCodec with a key derived by MD5, and re-wraps the result at the right scale for the
 * same reason its PNG companion does.
 *
 * DECLARED ONLY — the body has not been reconstructed yet. See TYPES_PENDING.md.
 *
 * @param pszBaseName The resource name, with no scale suffix and no extension.
 * @return The decrypted image at its correct scale, or nil when the file is missing.
 * @ghidraAddress 0x7e9dc
 */
UIImage *_Nullable LoadScaledEncryptedTexImage(NSString *pszBaseName);

/**
 * @brief Resolves a resource name to the bundle path of the variant this device should use.
 *
 * Chooses between the plain, @c _pn2 and @c _pn3 variants from the interface idiom and the main
 * screen's scale, and reports back both whether a scaled variant was chosen and what scale it
 * carries — neither of which the returned path conveys on its own.
 *
 * DECLARED ONLY — the body has not been reconstructed yet, though the signature is proven from the
 * call in @c LoadScaledPngImage. See TYPES_PENDING.md.
 *
 * @param pszBaseName The resource name, with no scale suffix and no extension.
 * @param pfScaled Set to YES when a scaled variant was chosen. Seeded NO by the caller.
 * @param pflScale Set to the chosen variant's scale. Seeded 2.0 by the caller.
 * @param pszExtension The file extension to look for, without the dot.
 * @return The full path, or nil when no variant exists.
 * @ghidraAddress 0x7e37c
 */
NSString *_Nullable GetScaledResourcePath(NSString *pszBaseName,
                                          BOOL *pfScaled,
                                          float *pflScale,
                                          NSString *pszExtension);

/**
 * @brief The Blowfish key downloaded resource data is enciphered with.
 *
 * DECLARED ONLY — the body has not been reconstructed yet. Handed to
 * @c -[BFCodec cipherInit:] before a downloaded campaign image is written to disk, so the cached
 * copy on disk is enciphered rather than a plain PNG.
 *
 * @return The key material.
 * @ghidraAddress 0x7fa54
 */
NSData *_Nullable CreateResourceDataCipherKey(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
