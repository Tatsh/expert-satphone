#import "StorePackCell.h"

#import "PurchaseManager.h"
#import "StoreUtil.h"

@implementation StorePackCell {
    UIImageView *bgView;
    UILabel *labelName;
    UILabel *labelPrice;
    UILabel *labelPurchased;
    UIImageView *newMarker;
    UIImageView *extendMarker;
}

/** @ghidraAddress 0xf1878 */
- (BOOL)isPurchased {
    return !labelPurchased.hidden;
}

/** @ghidraAddress 0xf18a4 */
- (void)setIsPurchased:(BOOL)isPurchased {
    labelPurchased.hidden = !isPurchased;
}

/** @ghidraAddress 0xf18c0 */
- (void)loadPackInfo:(StorePackInfo *)packInfo {
    labelName.text = packInfo.packName;
    newMarker.hidden = !packInfo.isNew;
    extendMarker.hidden = !packInfo.hasExtend;
    labelPrice.attributedText = packInfo.attributedPriceString;

    NSString *productID = [StoreUtil productIDForPackID:packInfo.packID];
    // A pending purchase counts as owned for display. The manager is fetched afresh for each
    // question rather than held, and the second is only asked when the first says no.
    BOOL owned = [PurchaseManager.sharedManager isPurchased:productID];
    if (!owned) {
        owned = [PurchaseManager.sharedManager isPending:productID];
    }
    // The label is hidden directly rather than through self.isPurchased, which would do the same
    // thing. The setter exists and this method does not use it.
    labelPurchased.hidden = !owned;
}

/** @ghidraAddress 0xf1ad4 */
- (void)setBgImage:(UIImage *)bgImg {
    bgView.image = bgImg;
}

@end
