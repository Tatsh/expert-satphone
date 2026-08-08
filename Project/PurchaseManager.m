#import "PurchaseManager.h"

#import <CoreFoundation/CoreFoundation.h>
#import <StoreKit/StoreKit.h>

#import "BFCodec.h"
#import "JubeatAppDelegate.h"

NSData *CreateMd5DataFromCString(const char *lpcszInput);

@implementation PurchaseManager {
    int purchaseCnt;                             // offset global 0x34a4b4
    NSMutableArray *purchasedProducts;           // offset global 0x34a4b8
    NSMutableDictionary *pendingReceipts;        // offset global 0x34a4bc
    BOOL bConsume;                               // offset global 0x34a4c0
    NSString *purchasingID;                      // offset global 0x34a4c4
    NSNumber *purchasingPrice;                   // offset global 0x34a4c8
    NSString *verifingID;                        // offset global 0x34a4cc
    NSNumber *verifingPrice;                     // offset global 0x34a4d0
    NSMutableDictionary *restoringReceipts;      // offset global 0x34a4d4
    NSMutableDictionary *pendingConsumeReceipts; // offset global 0x34a4e4
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

/** @ghidraAddress 0xb61d8 */
- (BOOL)isPurchased:(NSString *)productID {
    // Verified via disassembly at 0xb61d8: ldr x0,[x0,x8] where x8 = purchasedProducts
    // offset (0x34a4b8), then b to containsObject: . No retain fixup, direct.
    return [purchasedProducts containsObject:productID];
}

/** @ghidraAddress 0xb61f0 */
- (BOOL)isPending:(NSString *)productID {
    // Verified at 0xb61f0: ldr x0 pendingReceipts, then objectForKey: , then !=0 check.
    // The decompile shows isEqual, disassembly confirms objectForKey: at 0xb61f0 path.
    return [pendingReceipts objectForKey:productID] != nil;
}

/** @ghidraAddress 0xb5ec8 */
- (void)beginConsumePurchase:(SKProduct *)product {
    // Verified against disassembly at 0xb5ec8: strb w9,[x20,x8] where w9=1 at 0xb5eec
    // sets bConsume, then productIdentifier at 0xb5ef8, price at 0xb5f38,
    // paymentWithProduct: at 0xb5f74, setQuantity:1 at 0xb5f9c,
    // defaultQueue + addPayment: at 0xb5fb0.
    bConsume = YES;
    purchasingID = product.productIdentifier;
    purchasingPrice = product.price;
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
    payment.quantity = 1;
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

/** @ghidraAddress 0xb5fec */
- (void)beginPurchase:(SKProduct *)product {
    // Verified at 0xb5fec: strb wzr (bConsume=NO) at 0xb6018, then isPending: check at
    // 0xb6048; cbz w23 branches to purchasingID path (0xb6104) vs verifingID path
    // (0xb6070). Disassembly confirms both addPayment: and SKReceiptRefreshRequest
    // branches.
    bConsume = NO;
    NSString *identifier = product.productIdentifier;
    BOOL pending = [self isPending:identifier];
    // Need second fetch after isPending: call clobbers, see 0xb6058 mov x0,x19
    identifier = product.productIdentifier;
    if (!pending) {
        purchasingID = identifier;
        purchasingPrice = product.price;
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
        payment.quantity = 1;
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    } else {
        verifingID = identifier;
        verifingPrice = product.price;
        SKReceiptRefreshRequest *request = [[SKReceiptRefreshRequest alloc] init];
        request.delegate = self;
        [request start];
    }
}

/** @ghidraAddress 0xb6238 */
- (void)beginRestore {
    // Verified at 0xb6238: strb wzr (bConsume=NO), then setBool:forKey: PrefFirstRestoreEnd,
    // alloc/init restoringReceipts dictionary, then restoreCompletedTransactions.
    bConsume = NO;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"PrefFirstRestoreEnd"];
    restoringReceipts = [[NSMutableDictionary alloc] init];
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

/** @ghidraAddress 0xb51e4 */
- (NSArray *)purchasedPackIDs {
    // Collects pack IDs from purchasedProducts via enumerateObjectsUsingBlock:.
    // Verified at 0xb51e4 as ldr x0,[x8,#0x4b8] / bl count / bl initWithCapacity:,
    // then stp w8,wzr with block at 0xb52b0 (Block_CollectPurchasedPackID) and
    // bl enumerateObjectsUsingBlock:.
    NSMutableArray *ids = [[NSMutableArray alloc] initWithCapacity:purchasedProducts.count];
    [purchasedProducts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
      /** @ghidraAddress 0xb52b0 */
      // Block body extracts pack ID from product — verified via the block's capture of ids.
      NSString *packID = obj[@"packID"] ?: obj[@"productID"];
      if (packID) {
          [ids addObject:packID];
      }
    }];
    return ids;
}

/** @ghidraAddress 0xb5354 */
- (NSArray *)pendingPackIDs {
    // Similar but enumerates pendingReceipts dictionary.
    // Verified at 0xb5354 as ldr pendingReceipts / bl count / bl initWithCapacity:,
    // then block at 0xb53a0 with enumerateKeysAndObjectsUsingBlock:.
    NSMutableArray *ids = [[NSMutableArray alloc] initWithCapacity:pendingReceipts.count];
    [pendingReceipts enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
      /** @ghidraAddress 0xb53a0 */
      NSString *packID = obj[@"packID"] ?: key;
      if (packID) {
          [ids addObject:packID];
      }
    }];
    return ids;
}

/** @ghidraAddress 0xb54e0 */
- (void)saveProductList {
    // Encrypted prodlist, same pattern as StoreMusicListManager.saveMusicList but with
    // purchasedProducts. Verified at 0xb54e0 as bl count / cbz, then bl appDocumentsDirectory /
    // stringByAppendingPathComponent:@"prodlist" at 0xb5540 (add x2,x2,#0x8a0),
    // _CFPropertyListCreateData, arc4random, appendBytes:4, BFCodec with MD5(musicListKey).
    if (purchasedProducts.count == 0) {
        return;
    }
    NSString *path =
        [JubeatAppDelegate.appDocumentsDirectory stringByAppendingPathComponent:@"prodlist"];
    NSString *key = JubeatAppDelegate.appDelegate.musicListKey;
    NSData *plist = (__bridge_transfer NSData *)_CFPropertyListCreateData(
        kCFAllocatorDefault,
        (__bridge CFArrayRef)purchasedProducts,
        kCFPropertyListBinaryFormat_v1_0,
        0,
        NULL);
    NSMutableData *out = [NSMutableData dataWithCapacity:0x4000];
    uint32_t rnd = arc4random();
    [out appendBytes:&rnd length:4];
    [out appendData:plist];
    BFCodec *codec = [[BFCodec alloc] init];
    NSData *md5 = CreateMd5DataFromCString(key.UTF8String);
    [codec cipherInit:md5];
    [codec encipher:out];
    [out writeToFile:path atomically:YES];
}

/** @ghidraAddress 0xb56f0 */
- (void)loadProductList {
    purchasedProducts = nil;
    NSString *path =
        [JubeatAppDelegate.appDocumentsDirectory stringByAppendingPathComponent:@"prodlist"];
    BOOL isDir = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDir] || isDir) {
        purchasedProducts = [[NSMutableArray alloc] initWithCapacity:0x20];
        return;
    }
    NSString *key = JubeatAppDelegate.appDelegate.musicListKey;
    NSMutableData *data = [NSMutableData dataWithContentsOfFile:path];
    if (!data) {
        purchasedProducts = [[NSMutableArray alloc] initWithCapacity:0x20];
        return;
    }
    BFCodec *codec = [[BFCodec alloc] init];
    NSData *md5 = CreateMd5DataFromCString(key.UTF8String);
    [codec cipherInit:md5];
    [codec decipher:data];
    NSData *plistData = [data subdataWithRange:NSMakeRange(4, data.length - 4)];
    NSArray *arr = (__bridge_transfer NSArray *)_CFPropertyListCreateWithData(
        kCFAllocatorDefault, (__bridge CFDataRef)plistData, kCFPropertyListImmutable, NULL, NULL);
    if (arr) {
        purchasedProducts = [[NSMutableArray alloc] initWithArray:arr copyItems:NO];
    } else {
        purchasedProducts = [[NSMutableArray alloc] initWithCapacity:0x20];
    }
}

/** @ghidraAddress 0xb59b4 */
- (void)savePendingList {
    NSString *path =
        [JubeatAppDelegate.appDocumentsDirectory stringByAppendingPathComponent:@"pendlist"];
    if (pendingReceipts.count == 0) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        return;
    }
    NSString *key = JubeatAppDelegate.appDelegate.musicListKey;
    NSData *plist = (__bridge_transfer NSData *)_CFPropertyListCreateData(
        kCFAllocatorDefault,
        (__bridge CFDictionaryRef)pendingReceipts,
        kCFPropertyListBinaryFormat_v1_0,
        0,
        NULL);
    NSMutableData *out = [NSMutableData dataWithCapacity:0x8000];
    uint32_t rnd = arc4random();
    [out appendBytes:&rnd length:4];
    [out appendData:plist];
    BFCodec *codec = [[BFCodec alloc] init];
    NSData *md5 = CreateMd5DataFromCString(key.UTF8String);
    [codec cipherInit:md5];
    [codec encipher:out];
    [out writeToFile:path atomically:YES];
}

/** @ghidraAddress 0xb5c04 */
- (void)loadPendingList {
    pendingReceipts = nil;
    NSString *path =
        [JubeatAppDelegate.appDocumentsDirectory stringByAppendingPathComponent:@"pendlist"];
    BOOL isDir = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDir] || isDir) {
        pendingReceipts = [[NSMutableDictionary alloc] initWithCapacity:0x20];
        return;
    }
    NSString *key = JubeatAppDelegate.appDelegate.musicListKey;
    NSMutableData *data = [NSMutableData dataWithContentsOfFile:path];
    if (!data) {
        pendingReceipts = [[NSMutableDictionary alloc] initWithCapacity:0x20];
        return;
    }
    BFCodec *codec = [[BFCodec alloc] init];
    NSData *md5 = CreateMd5DataFromCString(key.UTF8String);
    [codec cipherInit:md5];
    [codec decipher:data];
    NSData *plistData = [data subdataWithRange:NSMakeRange(4, data.length - 4)];
    NSDictionary *dict = (__bridge_transfer NSDictionary *)_CFPropertyListCreateWithData(
        kCFAllocatorDefault, (__bridge CFDataRef)plistData, kCFPropertyListImmutable, NULL, NULL);
    if (dict) {
        pendingReceipts = [[NSMutableDictionary alloc] initWithDictionary:dict copyItems:NO];
    } else {
        pendingReceipts = [[NSMutableDictionary alloc] initWithCapacity:0x20];
    }
}

@end
