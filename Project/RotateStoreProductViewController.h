/** @file
 * The App Store product sheet, unlocked from portrait.
 *
 * Reconstructed from Ghidra program Jubeat (class RotateStoreProductViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c SKStoreProductViewController, from the dyld bind at the class object's
 * superclass slot (0x3528a0).
 *
 * The class exists for its three rotation answers alone. Its other three members override
 * superclass methods and add nothing to them — see TYPES_PENDING.md.
 */

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A store product sheet that rotates to every orientation.
 */
@interface RotateStoreProductViewController : SKStoreProductViewController
@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
