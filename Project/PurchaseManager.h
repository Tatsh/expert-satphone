/** @file
 * The StoreKit purchase manager.
 *
 * Reconstructed from Ghidra program Jubeat (class PurchaseManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: twenty-one of thirty-five members written. The shared instance, StoreKit
 * lifecycle, consumable/non-consumable entry points, and the add/verify scaffolding — verified
 * against the disassembly via curl on port 8089.
 */

#import <Foundation/Foundation.h>

@class SKProduct;

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
 * @brief Whether the product has already been bought.
 * @param productID The product identifier.
 * @return YES if contained in purchasedProducts.
 * @ghidraAddress 0xb61d8
 */
- (BOOL)isPurchased:(nullable NSString *)productID;
/**
 * @brief Whether a purchase of the product is in flight.
 * @param productID The product identifier.
 * @return YES if a receipt is pending.
 * @ghidraAddress 0xb61f0
 */
- (BOOL)isPending:(nullable NSString *)productID;
/**
 * @brief Start a consumable purchase (bConsume = YES).
 * @param product The SKProduct.
 * @ghidraAddress 0xb5ec8
 */
- (void)beginConsumePurchase:(SKProduct *)product;
/**
 * @brief Start a non-consumable purchase, or refresh receipt if already pending.
 * @param product The SKProduct.
 * @ghidraAddress 0xb5fec
 */
- (void)beginPurchase:(SKProduct *)product;
/**
 * @brief Begin restoring completed transactions.
 * @ghidraAddress 0xb6238
 */
- (void)beginRestore;
/**
 * @brief Add a product to purchasedProducts if not already present, and clear pending.
 * @param productID The product identifier.
 * @ghidraAddress 0xb6308
 */
- (void)addProduct:(NSString *)productID;
/**
 * @brief Create a consume-verify post dictionary.
 * @param sku The SKU.
 * @param prices The prices array.
 * @return The dictionary or nil.
 * @ghidraAddress 0xb63bc
 */
- (nullable NSDictionary *)createConsumeVerifyPostDictionary:(NSString *)sku
                                                      prices:(NSArray *)prices;
/**
 * @brief Create verify post data for given products.
 * @param products The products array.
 * @return The dictionary or nil.
 * @ghidraAddress 0xb66ec
 */
- (nullable NSDictionary *)createVerifyPostData:(NSArray *)products;
/**
 * @brief Create verify post dictionary with product prices.
 * @param products The products array.
 * @param productPrices The prices array.
 * @return The dictionary or nil.
 * @ghidraAddress 0xb6af0
 */
- (nullable NSDictionary *)createVerifyPostDictionary:(NSArray *)products
                                        productPrices:(NSArray *)productPrices;
/**
 * @brief Verify the receipt for the current verifingID/Price.
 * @ghidraAddress 0xb6ec4
 */
- (void)verifyReceipt;
/**
 * @brief The packs the player has bought.
 * @ghidraAddress 0xb51e4
 */
@property(nonatomic, readonly, nullable) NSArray *purchasedPackIDs;

/**
 * @brief The packs whose purchase has not settled yet.
 * @ghidraAddress 0xb5354
 */
@property(nonatomic, readonly, nullable) NSArray *pendingPackIDs;

/**
 * @brief Loads the product catalogue.
 * @ghidraAddress 0xb56f0
 */
- (void)loadProductList;
/**
 * @brief Loads purchases that were started but not finished.
 * @ghidraAddress 0xb5c04
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
