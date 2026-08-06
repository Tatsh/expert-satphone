/** @file
 * One purchasable cube pack.
 *
 * Reconstructed from Ghidra program Jubeat (class CubePurchaseInfo, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the three members
 * @c CubePurchaseListViewCell reaches are declared; the class also carries
 * @c -initWithDictionary:, @c -updateProduct:, @c -getProductID, @c -getProduct and @c -getName,
 * listed in TYPES_PENDING.md.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A cube pack's identity, price and store product.
 *
 * Backed by four ivars: @c purchaseID, @c productInfo (an @c SKProduct), @c itemName and
 * @c description.
 */
@interface CubePurchaseInfo : NSObject

/**
 * @brief How many cubes the pack contains.
 *
 * @c -[itemName intValue], so the count is carried as text and parsed on every call.
 * DECLARED ONLY.
 * @ghidraAddress 0x63d20
 */
- (int)getCubeNum;
/**
 * @brief The pack's price, already formatted for display. DECLARED ONLY.
 * @ghidraAddress 0x63c6c
 */
- (nullable NSString *)getPriceString;
/**
 * @brief The pack's description line. DECLARED ONLY.
 * @ghidraAddress 0x63d48
 */
- (nullable NSString *)getDescription;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
