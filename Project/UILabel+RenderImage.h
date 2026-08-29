/**
 * @file
 * @brief The @c UILabel @c renderImage category.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base. The runtime metadata attributes @c renderImage to
 * @c UILabel; the renderers message it on their partner-name labels to rasterise them into an
 * atlas. Its real IMP is at 0x1255c4 (Ghidra left it unrecognised as an ObjC method because every
 * caller dispatches through the @c objc_msgSend thunk at 0x391013).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Renders the receiver's current contents into a bitmap image.
 */
@interface UILabel (RenderImage)

/**
 * @brief Rasterises the view's layer into a @c UIImage sized to its frame, at 1.0 scale.
 * @return The rendered image.
 * @ghidraAddress 0x1255c4
 */
- (nullable UIImage *)renderImage;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
