/**
 * @file
 * The StoreKit purchase manager.
 *
 * Reconstructed from Ghidra program Jubeat (class PurchaseManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete — thirty-five of thirty-five members written. The class object at
 * 0x348100 has 81 cross-references; all hand-written members are recovered — verified against the
 * disassembly via curl on port 8089.
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@class SKPaymentQueue;
@class SKProduct;
@class SKRequest;

NS_ASSUME_NONNULL_BEGIN

/**
 * Drives in-app purchases.
 */
@protocol PurchaseManagerDelegate <NSObject>
@optional
/**
 * A purchase failed.
 * @param productID The product that failed.
 * @param error The failure, distinguishing a cancellation from a genuine error by its domain.
 */
- (void)purchaseFailed:(NSString *)productID error:(NSError *)error;
/** A restore finished with nothing to restore. */
- (void)restoreNothing;
@end

/**
 * The StoreKit purchase and restore front end, shared across the store screens.
 */
@interface PurchaseManager : NSObject <SKPaymentTransactionObserver, SKRequestDelegate>

/**
 * The delegate.
 * @ghidraAddress 0x34a4e8
 */
@property(nonatomic, weak, nullable) id<PurchaseManagerDelegate> delegate;

/**
 * The shared instance.
 * @ghidraAddress 0xb5068
 */
@property(class, nonatomic, readonly) PurchaseManager *sharedManager;

/**
 * Builds the manager.
 * @return The initialised manager.
 * @ghidraAddress 0xb50e8
 */
- (instancetype)init;

/**
 * Whether the device can make payments.
 * @return YES when StoreKit says so.
 * @ghidraAddress 0xb5130
 */
+ (BOOL)isPurchasable;

/**
 * Brings the purchase manager up.
 *
 * Adds itself as a transaction observer on the default queue.
 * @ghidraAddress 0xb5144
 */
- (void)start;
/**
 * Whether the product has already been bought.
 * @param productID The product identifier.
 * @return YES if contained in purchasedProducts.
 * @ghidraAddress 0xb61d8
 */
- (BOOL)isPurchased:(nullable NSString *)productID;
/**
 * Whether a purchase of the product is in flight.
 * @param productID The product identifier.
 * @return YES if a receipt is pending.
 * @ghidraAddress 0xb61f0
 */
- (BOOL)isPending:(nullable NSString *)productID;
/**
 * Start a consumable purchase (bConsume = YES).
 * @param product The SKProduct.
 * @ghidraAddress 0xb5ec8
 */
- (void)beginConsumePurchase:(SKProduct *)product;
/**
 * Start a non-consumable purchase, or refresh receipt if already pending.
 * @param product The SKProduct.
 * @ghidraAddress 0xb5fec
 */
- (void)beginPurchase:(SKProduct *)product;
/**
 * Begin restoring completed transactions.
 * @ghidraAddress 0xb6238
 */
- (void)beginRestore;
/**
 * Add a product to purchasedProducts if not already present, and clear pending.
 * @param productID The product identifier.
 * @ghidraAddress 0xb6308
 */
- (void)addProduct:(NSString *)productID;
/**
 * Create a consume-verify post dictionary.
 * @param sku The SKU.
 * @param prices The prices array.
 * @return The dictionary or nil.
 * @ghidraAddress 0xb63bc
 */
- (nullable NSDictionary *)createConsumeVerifyPostDictionary:(NSString *)sku
                                                      prices:(NSArray *)prices;
/**
 * Create verify post data for given products.
 * @param products The products array.
 * @return The dictionary or nil.
 * @ghidraAddress 0xb66ec
 */
- (nullable NSData *)createVerifyPostData:(NSArray *)products;
/**
 * Create verify post dictionary with product prices.
 * @param products The products array.
 * @param productPrices The prices array.
 * @return The dictionary or nil.
 * @ghidraAddress 0xb6af0
 */
- (nullable NSDictionary *)createVerifyPostDictionary:(NSArray *)products
                                        productPrices:(nullable NSArray *)productPrices;
/**
 * Verify the receipt for the current verifingID/Price.
 * @ghidraAddress 0xb6ec4
 */
- (void)verifyReceipt;
/**
 * Handle a failed receipt restore.
 * @param queue The payment queue.
 * @param error The error.
 * @ghidraAddress 0xb8970
 */
- (void)paymentQueue:(SKPaymentQueue *)queue
    restoreCompletedTransactionsFailedWithError:(NSError *)error;
/**
 * Handle a finished SKRequest.
 * @param request The request.
 * @ghidraAddress 0xb8a34
 */
- (void)requestDidFinish:(SKRequest *)request;
/**
 * Save pending consumable receipts.
 * @ghidraAddress 0xb8b78
 */
- (void)savePendingConsumeList;
/**
 * Load pending consumable receipts.
 * @ghidraAddress 0xb8dc8
 */
- (void)loadPendingConsumeList;
/**
 * Verify the consumable receipt.
 * @ghidraAddress 0xb908c
 */
- (void)verifyConsumeReceipt;
/**
 * Verify any pending consumable receipt.
 * @return YES if a verification was started.
 * @ghidraAddress 0xb92b4
 */
- (BOOL)verifyPendingConsumeReceipt;
/**
 * Check if an item ID is a consumable cube.
 * @param itemID The item ID.
 * @return YES if it has the jubeat.cube prefix.
 * @ghidraAddress 0xb9628
 */
- (BOOL)checkConsumeItemID:(NSString *)itemID;
/**
 * Handle an alert selection for a consumable.
 * @param alert The alert.
 * @ghidraAddress 0xb9644
 */
- (void)alertSelect:(id)alert;
/**
 * Tears down the manager and clears the delegate.
 * @ghidraAddress 0xb96a4
 */
- (void)dealloc;
/**
 * The packs the player has bought.
 * @ghidraAddress 0xb51e4
 */
@property(nonatomic, readonly, nullable) NSArray *purchasedPackIDs;

/**
 * The packs whose purchase has not settled yet.
 * @ghidraAddress 0xb5354
 */
@property(nonatomic, readonly, nullable) NSArray *pendingPackIDs;

/**
 * Loads the product catalogue.
 * @ghidraAddress 0xb56f0
 */
- (void)loadProductList;
/**
 * Loads purchases that were started but not finished.
 * @ghidraAddress 0xb5c04
 */
- (void)loadPendingList;
/**
 * Tears the purchase manager down.
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
