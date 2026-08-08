/** @file
 * The StoreKit purchase manager.
 *
 * Reconstructed from Ghidra program Jubeat (class PurchaseManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: five of thirty-five members written. The shared instance, init, and
 * StoreKit lifecycle — verified against the disassembly via curl on port 8089.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Drives in-app purchases.
 */
@interface PurchaseManager : NSObject

/**
 * @brief The shared instance.
 * @ghidraAddress 0xb5068
 */
@property(class, nonatomic, readonly) PurchaseManager *sharedManager;

/**
 * @brief Builds the manager.
 * @return The initialised manager.
 * @ghidraAddress 0xb50e8
 */
- (instancetype)init;

/**
 * @brief Whether the device can make payments.
 * @return YES when StoreKit says so.
 * @ghidraAddress 0xb5130
 */
+ (BOOL)isPurchasable;

/**
 * @brief Brings the purchase manager up.
 *
 * Adds itself as a transaction observer on the default queue.
 * @ghidraAddress 0xb5144
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
 * @brief The packs the player has bought. DECLARED ONLY.
 */
@property(nonatomic, readonly, nullable) NSArray *purchasedPackIDs;

/**
 * @brief The packs whose purchase has not settled yet. DECLARED ONLY.
 */
@property(nonatomic, readonly, nullable) NSArray *pendingPackIDs;

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
 * Removes itself as a transaction observer.
 * @ghidraAddress 0xb5194
 */
- (void)end;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
