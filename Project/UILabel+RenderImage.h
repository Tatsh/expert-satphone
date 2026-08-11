/** @file
 * The @c UILabel @c renderImage category.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base. The runtime metadata attributes @c renderImage to
 * @c UILabel; the renderers message it on their partner-name labels to rasterise them into an
 * atlas. Only the declaration is reconstructed here: the implementation is supplied outside this
 * tree (a shared category), so this header exists to type the message sends faithfully.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Renders the receiver's current contents into a bitmap image.
 */
@interface UILabel (RenderImage)

/**
 * @brief Rasterises the label's layer into a @c UIImage at the label's bounds and scale.
 * @return The rendered image, or @c nil if the label has no drawable bounds.
 * @ghidraAddress 0x391013
 */
- (nullable UIImage *)renderImage;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
