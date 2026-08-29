/**
 * @file
 * One purchasable cube pack.
 *
 * Reconstructed from Ghidra program Jubeat (class CubePurchaseInfo, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A cube pack's identity, price and store product.
 *
 * Backed by four ivars: @c purchaseID, @c productInfo (an @c SKProduct), @c itemName and
 * @c description.
 */
@interface CubePurchaseInfo : NSObject

/**
 * Fills the pack from a store dictionary.
 * @param dictionary The store dictionary (carries @c item_id , @c name , and @c description ).
 * @ghidraAddress 0x63b68
 */
- (void)initWithDictionary:(nullable NSDictionary *)dictionary;

/**
 * Attaches the resolved StoreKit product.
 * @param product The product.
 * @ghidraAddress 0x63c48
 */
- (void)updateProduct:(nullable SKProduct *)product;

/**
 * The pack's product identifier.
 * @return The product identifier.
 * @ghidraAddress 0x63c5c
 */
- (nullable NSString *)getProductID;

/**
 * The pack's price, already formatted for display. DECLARED ONLY.
 * @return The formatted price.
 * @ghidraAddress 0x63c6c
 */
- (nullable NSString *)getPriceString;

/**
 * The attached StoreKit product.
 * @return The attached StoreKit product, or nil when none has been resolved.
 * @ghidraAddress 0x63d10
 */
- (nullable SKProduct *)getProduct;

/**
 * How many cubes the pack contains.
 *
 * @c -[itemName intValue], so the count is carried as text and parsed on every call.
 * @ghidraAddress 0x63d20
 */
- (int)getCubeNum;

/**
 * The pack's name (also the cube count as a string).
 * @return The pack's name.
 * @ghidraAddress 0x63d38
 */
- (nullable NSString *)getName;

/**
 * The pack's description line.
 * @return The pack's description line.
 * @ghidraAddress 0x63d48
 */
- (nullable NSString *)getDescription;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
