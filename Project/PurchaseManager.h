/** @file
 * The StoreKit purchase manager.
 *
 * Reconstructed from Ghidra program Jubeat (class PurchaseManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. The class object at 0x348100 has 81
 * cross-references; only the members reached so far are declared.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Drives in-app purchases.
 */
@interface PurchaseManager : NSObject

/**
 * @brief The shared instance.
 */
@property(class, nonatomic, readonly) PurchaseManager *sharedManager;

/**
 * @brief Tears the purchase manager down.
 *
 * Called from @c -[JubeatAppDelegate applicationWillTerminate:] at 0xb800. The name is the
 * binary's own selector, which is simply @c end.
 */
- (void)end;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
