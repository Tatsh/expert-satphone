#import "PurchaseManager.h"

#import <StoreKit/StoreKit.h>

@implementation PurchaseManager {
    int purchaseCnt; // offset global 0x34a4b4
}

/** @ghidraAddress 0xb5068 */
+ (PurchaseManager *)sharedManager {
    static PurchaseManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0xb50a0 */
      instance = [[PurchaseManager alloc] init];
    });
    return instance;
}

/** @ghidraAddress 0xb50e8 */
- (instancetype)init {
    self = [super init];
    if (self) {
        // purchaseCnt is the only ivar touched here, zeroed via str wzr at 0xb5120.
        // Verified at 0xb50e8: ldrsw x8,[x8,#0x4b4] / str wzr,[x0,x8].
        purchaseCnt = 0;
    }
    return self;
}

/** @ghidraAddress 0xb5130 */
+ (BOOL)isPurchasable {
    // Single call at 0xb5130: bl canMakePayments.
    return SKPaymentQueue.canMakePayments;
}

/** @ghidraAddress 0xb5144 */
- (void)start {
    // Adds itself as observer on the default queue — verified at 0xb5144 as
    // ldr x0,[x8,#0x740] / bl defaultQueue / bl addTransactionObserver:.
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

/** @ghidraAddress 0xb5194 */
- (void)end {
    // Mirror of start: removeTransactionObserver: at 0xb5194.
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

@end
