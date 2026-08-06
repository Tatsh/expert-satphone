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
 * DECLARED ONLY — the body has not been reconstructed yet. See TYPES_PENDING.md.
 *
 * @param pszBaseName The resource name, with no scale suffix and no @c .png extension.
 * @return The image at its correct scale, or nil when the file is missing.
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
