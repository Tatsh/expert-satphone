#import "StoreRecommendPackView.h"

#import "PurchaseManager.h"
#import "StoreUtil.h"

@implementation StoreRecommendPackView {
    UIImageView *bgView;
    UILabel *labelName;
    UILabel *labelPurchased;
    UILabel *labelComment;
    UILabel *labelPrice;
    UIImageView *newMarker;
    UIImageView *extendMarker;
}

/** @ghidraAddress 0x145638 */
- (void)setBgImage:(UIImage *)bgImg {
    bgView.image = bgImg;
}

/** @ghidraAddress 0x145704 */
- (void)loadPackInfo:(StorePackInfo *)packInfo index:(NSUInteger)index {
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
    labelPurchased.hidden = !owned;

    _index = index;
    // Note labelComment is left untouched here: nothing in this method writes it.
}

/** @ghidraAddress 0x145650 */
- (void)handleTap:(id)sender {
    // Yes, sender is unused: the delegate is handed the tile rather than the recogniser. The
    // delegate is loaded from the weak slot twice, once to test and once to send to.
    if ([self.delegate respondsToSelector:@selector(storePackViewSelected:)]) {
        [self.delegate performSelector:@selector(storePackViewSelected:) withObject:self];
    }
}

@end
