#import "CubePurchaseInfo.h"

#import "StoreUtil.h"

// The store dictionary keys.
static NSString *const kCubeKeyItemID = @"item_id";
static NSString *const kCubeKeyName = @"name";
static NSString *const kCubeKeyDescription = @"description";

@implementation CubePurchaseInfo {
    NSString *purchaseID;   // +0x8
    SKProduct *productInfo; // +0x10
    NSString *itemName;     // +0x18
    NSString *description;  // +0x20
}

/** @ghidraAddress 0x63b68 */
- (void)initWithDictionary:(NSDictionary *)dictionary {
    purchaseID = dictionary[kCubeKeyItemID];
    itemName = dictionary[kCubeKeyName];
    description = dictionary[kCubeKeyDescription];
}

/** @ghidraAddress 0x63c48 */
- (void)updateProduct:(SKProduct *)product {
    productInfo = product;
}

/** @ghidraAddress 0x63c5c */
- (NSString *)getProductID {
    return purchaseID;
}

/** @ghidraAddress 0x63c6c */
- (NSString *)getPriceString {
    return [StoreUtil priceString:productInfo.price withLocale:productInfo.priceLocale];
}

/** @ghidraAddress 0x63d10 */
- (SKProduct *)getProduct {
    return productInfo;
}

/** @ghidraAddress 0x63d20 */
- (int)getCubeNum {
    return itemName.intValue;
}

/** @ghidraAddress 0x63d38 */
- (NSString *)getName {
    return itemName;
}

/** @ghidraAddress 0x63d48 */
- (NSString *)getDescription {
    return description;
}

@end
