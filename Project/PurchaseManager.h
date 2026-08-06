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
 * @brief Brings the purchase manager up.
 *
 * First of the four calls @c -[JubeatAppDelegate application:didFinishLaunchingWithOptions:] makes
 * at 0x9e14-0x9ec4, each on a separately fetched @c sharedManager. DECLARED ONLY.
 */
- (void)start;
/**
 * @brief Whether the product has already been bought. DECLARED ONLY.
 * @ghidraAddress 0xb61d8
 */
- (BOOL)isPurchased:(nullable NSString *)productID;
/**
 * @brief Whether a purchase of the product is in flight. DECLARED ONLY.
 *
 * Callers treat this as equivalent to purchased for display purposes, so a pending pack already
 * shows as owned.
 * @ghidraAddress 0xb61f0
 */
- (BOOL)isPending:(nullable NSString *)productID;
/**
 * @brief Loads the product catalogue. DECLARED ONLY.
 */
- (void)loadProductList;
/**
 * @brief Loads purchases that were started but not finished. DECLARED ONLY.
 */
- (void)loadPendingList;
/**
 * @brief Loads consumable purchases awaiting consumption. DECLARED ONLY.
 */
- (void)loadPendingConsumeList;
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
