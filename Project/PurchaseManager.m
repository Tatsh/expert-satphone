#import "PurchaseManager.h"

#import <CoreFoundation/CoreFoundation.h>
#import <StoreKit/StoreKit.h>

#import "BFCodec.h"
#import "JubeatAppDelegate.h"

NSData *CreateMd5DataFromCString(const char *lpcszInput);

@implementation PurchaseManager {
    NSMutableArray *purchasedProducts;           // offset global 0x34a4b8
    NSMutableDictionary *pendingReceipts;        // offset global 0x34a4bc
    NSMutableDictionary *pendingConsumeReceipts; // offset global 0x34a4e4
    int purchaseCnt;                             // offset global 0x34a4b4
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
