/**
 * @file
 * @brief The applilink SDK's localised resource bundle.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkBundle, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares one method for this class and it is
 * implemented. The class has no instance state.
 *
 * The superclass binds to @c _OBJC_CLASS_$_NSObject at load time; it is not stored in the file.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Vends the SDK's resource bundle.
 */
@interface ApplilinkBundle : NSObject

/**
 * @brief The SDK's @c ApplilinkNetworkResources bundle, loaded once and cached.
 *
 * Prefers the device-language @c .lproj sub-bundle when @c ApplilinkCore prioritises the device
 * languages, and falls back to the resource bundle itself.
 * @ghidraAddress 0x2372f4
 */
@property(class, nonatomic, readonly, nullable) NSBundle *rewardBundle;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
