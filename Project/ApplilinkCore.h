/** @file
 * The applilink SDK core.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkCore, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the one member
 * @c +[ApplilinkBundle rewardBundle] reaches is declared. The full class is reconstructed in the
 * sibling ../rbplus-src tree, from the other binary that embeds this SDK.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The SDK's shared configuration and lifecycle.
 */
@interface ApplilinkCore : NSObject

/**
 * @brief Whether the device's preferred languages take priority over the bundle default.
 *
 * When YES, @c +[ApplilinkBundle rewardBundle] looks for a language-specific @c .lproj sub-bundle
 * before falling back to the resource bundle itself. DECLARED ONLY.
 */
@property(class, nonatomic, readonly) BOOL isPriorityDeviceLanguages;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
