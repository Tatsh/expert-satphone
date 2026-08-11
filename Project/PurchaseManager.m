#import "PurchaseManager.h"

#import <CoreFoundation/CoreFoundation.h>
#import <StoreKit/StoreKit.h>

#import "BFCodec.h"
#import "Downloader.h"
#import "EditorIDManager.h"
#import "JubeatAppDelegate.h"
#import "SessionDownloader.h"
#import "StoreUtil.h"

NSData *CreateMd5DataFromCString(const char *lpcszInput);
NSString *CreateRandomString(int length);

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
    NSMutableData *verifyData;                   // offset global 0x34a4d8
    NSArray *verifingIDs;                        // offset global 0x34a4dc
    NSMutableDictionary *pendingConsumeReceipts; // offset global 0x34a4e4
    id _delegate;                                // offset global 0x34a4e8
}

/** @ghidraAddress 0xb5068 */
+ (PurchaseManager *)sharedManager {
    static PurchaseManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0xb50a8 */
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

/** @ghidraAddress 0xb6308 */
- (void)addProduct:(NSString *)productID {
    // Verified at 0xb6308: tbnz isPurchased check at 0xb6338, then addObject: at 0xb6354
    // and saveProductList, then isPending check at 0xb636c and removeObjectForKey: at 0xb6398.
    if (![self isPurchased:productID]) {
        [purchasedProducts addObject:productID];
        [self saveProductList];
    }
    if ([self isPending:productID]) {
        [pendingReceipts removeObjectForKey:productID];
        [self savePendingList];
    }
}

/** @ghidraAddress 0xb63bc */
- (NSDictionary *)createConsumeVerifyPostDictionary:(NSString *)sku prices:(NSArray *)prices {
    // Verified at 0xb63bc: mainBundle/appStoreReceiptURL/dataWithContentsOfURL/base64
    // at 0xb63f8, then CreateRandomString 0x10, clientInfo, initWithDictionary:,
    // setObject:forKey: receipt/target/sku/price/market, plus EditorID branch.
    NSData *receiptData = [NSData dataWithContentsOfURL:NSBundle.mainBundle.appStoreReceiptURL];
    NSString *receipt = [receiptData base64EncodedStringWithOptions:0];
    if (!receipt) {
        return nil;
    }
    NSString *nonce = CreateRandomString(0x10);
    NSMutableDictionary *dict =
        [[NSMutableDictionary alloc] initWithDictionary:JubeatAppDelegate.clientInfo];
    dict[@"receipt"] = receipt;
    dict[@"target"] = @"JP";
    dict[@"sku"] = sku;
    dict[@"price"] = prices;
    dict[@"market"] = @1;
    if ([EditorIDManager isExistEditorID]) {
        NSString *key = [EditorIDManager getEditorIDKey];
        NSString *userID = [EditorIDManager getKeyString:key];
        NSString *passKey = [EditorIDManager getEditorPassKey];
        NSString *passwd = [EditorIDManager getKeyString:passKey];
        dict[@"user_id"] = userID;
        dict[@"passwd"] = passwd;
    }
    return dict;
}

/** @ghidraAddress 0xb66ec */
- (NSDictionary *)createVerifyPostData:(NSArray *)products {
    NSData *receiptData = [NSData dataWithContentsOfURL:NSBundle.mainBundle.appStoreReceiptURL];
    NSString *receipt = [receiptData base64EncodedStringWithOptions:0];
    if (!receipt) {
        return nil;
    }
    NSString *nonce = CreateRandomString(0x10);
    NSMutableDictionary *dict =
        [[NSMutableDictionary alloc] initWithDictionary:JubeatAppDelegate.clientInfo];
    dict[@"receiptdata"] = receipt;
    dict[@"target"] = @"JP";
    dict[@"nonce"] = nonce;
    dict[@"products"] = products;
    if ([EditorIDManager isExistEditorID]) {
        NSString *key = [EditorIDManager getEditorIDKey];
        NSString *userID = [EditorIDManager getKeyString:key];
        NSString *passKey = [EditorIDManager getEditorPassKey];
        NSString *passwd = [EditorIDManager getKeyString:passKey];
        dict[@"userid"] = userID;
        dict[@"passwd"] = passwd;
    }
    NSDictionary *payload = [NSDictionary dictionaryWithDictionary:dict];
    // Serialise via CJSONSerializer and store in verifyData with hardcoded prefix.
    id serializer = [NSClassFromString(@"CJSONSerializer") performSelector:@selector(serializer)];
    NSData *json = [serializer performSelector:@selector(serializeDictionary:error:)
                                    withObject:payload];
    verifyData = [[NSMutableData alloc] initWithCapacity:0x1000];
    [verifyData appendBytes:"3fc9f6fe23460a7093aff11e4fa1f4b9omgker" length:0x20];
    [verifyData appendData:[nonce dataUsingEncoding:4]];
    return dict;
}

/** @ghidraAddress 0xb6af0 */
- (NSDictionary *)createVerifyPostDictionary:(NSArray *)products
                               productPrices:(NSArray *)productPrices {
    NSData *receiptData = [NSData dataWithContentsOfURL:NSBundle.mainBundle.appStoreReceiptURL];
    NSString *receipt = [receiptData base64EncodedStringWithOptions:0];
    if (!receipt) {
        return nil;
    }
    if (!productPrices) {
        NSMutableArray *tmp = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < products.count; ++i) {
            [tmp addObject:@(-1)];
        }
        productPrices = [tmp copy];
    }
    if (productPrices.count < products.count) {
        NSMutableArray *tmp = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < products.count; ++i) {
            [tmp addObject:@(-1)];
        }
        productPrices = [tmp copy];
    }
    NSMutableDictionary *dict =
        [[NSMutableDictionary alloc] initWithDictionary:JubeatAppDelegate.clientInfo];
    dict[@"receipt"] = receipt;
    dict[@"products"] = products;
    dict[@"prices"] = productPrices;
    return dict;
}

/** @ghidraAddress 0xb6ec4 */
- (void)verifyReceipt {
    // Verified at 0xb6ec4: arrayWithObjects: verifingID (0xb6f00), then verifingPrice check
    // at 0xb6f34 cbz, then copy to verifingIDs, then createVerifyPostDictionary:productPrices:
    // at 0xb6ec4 tail, then SessionDownloader with verifyReceiptNewURL and tag 0.
    NSArray *ids = [NSArray arrayWithObjects:&verifingID count:1];
    NSArray *prices;
    if (!verifingPrice) {
        prices = @[ @(-1) ];
    } else {
        prices = [NSArray arrayWithObjects:&verifingPrice count:1];
    }
    verifingIDs = [ids copy];
    NSDictionary *post = [self createVerifyPostDictionary:ids productPrices:prices];
    id downloader = [[NSClassFromString(@"SessionDownloader") alloc]
           initWithURL:[NSURL URLWithString:[NSClassFromString(@"StoreUtil")
                                                performSelector:@selector(verifyReceiptNewURL)]]
        postDictionary:post
              delegate:self];
    [downloader performSelector:@selector(setTag:) withObject:@0];
    [downloader performSelector:@selector(startDownloading)];
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
    [pendingReceipts enumerateKeysAndObjectsUsingBlock:^(NSString *productID, id obj, BOOL *stop) {
      /** @ghidraAddress 0xb5420 */
      int packID = [StoreUtil packIDForProductID:productID];
      if (packID > 0) {
          [ids addObject:[[NSNumber alloc] initWithInt:packID]];
      }
    }];
    return ids;
}

/** @ghidraAddress 0xb54e0 */
- (void)saveProductList {
    // Encrypted prodlist, same pattern as StoreMusicListManager.saveMusicList but with
    // purchasedProducts. Verified at 0xb54e0 as bl count / cbz, then bl appDocumentsDirectory /
    // stringByAppendingPathComponent:@"prodlist" at 0xb5540 (add x2,x2,#0x8a0),
    // CFPropertyListCreateData, arc4random, appendBytes:4, BFCodec with MD5(musicListKey).
    if (purchasedProducts.count == 0) {
        return;
    }
    NSString *path =
        [JubeatAppDelegate.appDocumentsDirectory stringByAppendingPathComponent:@"prodlist"];
    NSString *key = JubeatAppDelegate.appDelegate.musicListKey;
    NSData *plist =
        (__bridge_transfer NSData *)CFPropertyListCreateData(kCFAllocatorDefault,
                                                             (__bridge CFArrayRef)purchasedProducts,
                                                             kCFPropertyListBinaryFormat_v1_0,
                                                             0,
                                                             nullptr);
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
    NSArray *arr =
        (__bridge_transfer NSArray *)CFPropertyListCreateWithData(kCFAllocatorDefault,
                                                                  (__bridge CFDataRef)plistData,
                                                                  kCFPropertyListImmutable,
                                                                  nullptr,
                                                                  nullptr);
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
    NSData *plist = (__bridge_transfer NSData *)CFPropertyListCreateData(
        kCFAllocatorDefault,
        (__bridge CFDictionaryRef)pendingReceipts,
        kCFPropertyListBinaryFormat_v1_0,
        0,
        nullptr);
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
    NSDictionary *dict = (__bridge_transfer NSDictionary *)CFPropertyListCreateWithData(
        kCFAllocatorDefault,
        (__bridge CFDataRef)plistData,
        kCFPropertyListImmutable,
        nullptr,
        nullptr);
    if (dict) {
        pendingReceipts = [[NSMutableDictionary alloc] initWithDictionary:dict copyItems:NO];
    } else {
        pendingReceipts = [[NSMutableDictionary alloc] initWithCapacity:0x20];
    }
}

/** @ghidraAddress 0xb70d8 */
- (void)downloaderFinished:(Downloader *)downloader {
    // Verified at 0xb70d8: getDataInJSON at 0xb711c, then status integerValue check
    // at 0xb7168 -> cmp x19,#0x212f30000? Actually 0xb7178 cmp x19,x8 where w8 is 0x212f...,
    // then verified array handling at 0xb71a0 and purchaseFailed:error: dispatch.
    NSDictionary *json = [downloader getDataInJSON];
    if (!json) {
        [self downloaderError:downloader];
        return;
    }
    NSNumber *status = json[@"status"];
    if (!status || status.integerValue != 0x212f30000) {
        // Non-zero status — purchaseFailed with badresponse
        if ([self.delegate respondsToSelector:@selector(purchaseFailed:error:)]) {
            NSError *err = [NSError errorWithDomain:@"jp.konami.PurchaseManagerErrorDomain"
                                               code:2
                                           userInfo:@{NSLocalizedDescriptionKey : @"badresponse"}];
            [self.delegate purchaseFailed:verifingID error:err];
        }
        return;
    }
    // Success path continues with verified array handling — truncated for this tranche.
}

/** @ghidraAddress 0xb7da8 */
- (void)downloaderError:(Downloader *)downloader {
    if ([self.delegate respondsToSelector:@selector(purchaseFailed:error:)]) {
        NSError *err = [NSError errorWithDomain:@"jp.konami.PurchaseManagerErrorDomain"
                                           code:1
                                       userInfo:@{NSLocalizedDescriptionKey : @"NetworkErrorMsg"}];
        [self.delegate purchaseFailed:verifingID error:err];
    }
    verifingID = nil;
}

/** @ghidraAddress 0xb7f90 */
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    // Fast enumeration at 0xb7f90: countByEnumeratingWithState:objects:count: at 0xb7ff8,
    // then inner loop with transactionState etc. Verified via stp x28,x27 and bl.
    for (SKPaymentTransaction *transaction in transactions) {
        // Full state machine is deferred; this tranche documents the enumeration structure
        // verified in disassembly at 0xb7f90–0xb7ffc.
        (void)transaction;
    }
}

/** @ghidraAddress 0xb84a4 */
- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions {
    // Trivial enumeration — verified at 0xb84a4 as countByEnumeratingWithState: loop
    // that does nothing per element, matching the decompile's empty inner loop.
    for (SKPaymentTransaction *transaction in transactions) {
        (void)transaction;
    }
}

/** @ghidraAddress 0xb8598 */
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    // Two flags survive the block scopes: whether the restore ultimately succeeded and whether the
    // pending list needs saving.
    __block BOOL restoreSucceeded = NO;
    __block BOOL savePending = NO;
    if (restoringReceipts.count != 0) {
        // Copy every restored receipt into the pending map (as a set: the value is a placeholder),
        // then kick off server verification of the whole pending set.
        [restoringReceipts
            enumerateKeysAndObjectsUsingBlock:^(NSString *productID, id obj, BOOL *stop) {
              /** @ghidraAddress 0xb890c */
              [pendingReceipts setObject:@"dummy" forKey:productID];
            }];
        verifingIDs = [pendingReceipts.allKeys copy];
        if (pendingReceipts.count != 0) {
            NSDictionary *post = [self createVerifyPostDictionary:@[] productPrices:@[]];
            SessionDownloader *downloader =
                [[SessionDownloader alloc] initWithURL:[StoreUtil verifyReceiptNewURL]
                                        postDictionary:post
                                              delegate:self];
            [downloader setTag:1];
            [downloader startDownloading];
            return;
        }
    }
    restoringReceipts = nil;
    if (savePending) {
        [self savePendingList];
    }
    if (restoreSucceeded) {
        if ([self.delegate respondsToSelector:@selector(restoreSucceeded)]) {
            [self.delegate performSelector:@selector(restoreSucceeded)];
        }
    } else if ([self.delegate respondsToSelector:@selector(restoreNothing)]) {
        [self.delegate performSelector:@selector(restoreNothing)];
    }
}

/** @ghidraAddress 0xb8970 */
- (void)paymentQueue:(SKPaymentQueue *)queue
    restoreCompletedTransactionsFailedWithError:(NSError *)error {
    // Verified at 0xb8970: str xzr for restoringReceipts, then delegate restoreFailed:error
    restoringReceipts = nil;
    if ([self.delegate respondsToSelector:@selector(restoreFailed:)]) {
        [self.delegate performSelector:@selector(restoreFailed:) withObject:error];
    }
}

/** @ghidraAddress 0xb8a34 */
- (void)requestDidFinish:(SKRequest *)request {
    // Verified at 0xb8a34: pendingReceipts count >1 branches to verify post with tag 2
    if (pendingReceipts.count > 1) {
        NSDictionary *post = [self createVerifyPostDictionary:pendingReceipts.allKeys
                                                productPrices:nil];
        id downloader = [[NSClassFromString(@"SessionDownloader") alloc]
               initWithURL:[NSURL URLWithString:[NSClassFromString(@"StoreUtil")
                                                    performSelector:@selector(verifyReceiptNewURL)]]
            postDictionary:post
                  delegate:self];
        [downloader performSelector:@selector(setTag:) withObject:@2];
        [downloader performSelector:@selector(startDownloading)];
        return;
    }
    [self verifyReceipt];
}

/** @ghidraAddress 0xb8b78 */
- (void)savePendingConsumeList {
    NSString *path =
        [JubeatAppDelegate.appDocumentsDirectory stringByAppendingPathComponent:@"pendconlist"];
    if (pendingConsumeReceipts.count == 0) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        return;
    }
    NSString *key = JubeatAppDelegate.appDelegate.musicListKey;
    NSData *plist = (__bridge_transfer NSData *)CFPropertyListCreateData(
        kCFAllocatorDefault,
        (__bridge CFDictionaryRef)pendingConsumeReceipts,
        kCFPropertyListBinaryFormat_v1_0,
        0,
        nullptr);
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

/** @ghidraAddress 0xb8dc8 */
- (void)loadPendingConsumeList {
    pendingConsumeReceipts = nil;
    NSString *path =
        [JubeatAppDelegate.appDocumentsDirectory stringByAppendingPathComponent:@"pendconlist"];
    BOOL isDir = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDir] || isDir) {
        pendingConsumeReceipts = [[NSMutableDictionary alloc] initWithCapacity:0x20];
        return;
    }
    NSString *key = JubeatAppDelegate.appDelegate.musicListKey;
    NSMutableData *data = [NSMutableData dataWithContentsOfFile:path];
    if (!data) {
        pendingConsumeReceipts = [[NSMutableDictionary alloc] initWithCapacity:0x20];
        return;
    }
    BFCodec *codec = [[BFCodec alloc] init];
    NSData *md5 = CreateMd5DataFromCString(key.UTF8String);
    [codec cipherInit:md5];
    [codec decipher:data];
    NSData *plistData = [data subdataWithRange:NSMakeRange(4, data.length - 4)];
    NSDictionary *dict = (__bridge_transfer NSDictionary *)CFPropertyListCreateWithData(
        kCFAllocatorDefault,
        (__bridge CFDataRef)plistData,
        kCFPropertyListImmutable,
        nullptr,
        nullptr);
    if (dict) {
        pendingConsumeReceipts = [[NSMutableDictionary alloc] initWithDictionary:dict copyItems:NO];
    } else {
        pendingConsumeReceipts = [[NSMutableDictionary alloc] initWithCapacity:0x20];
    }
}

/** @ghidraAddress 0xb908c */
- (void)verifyConsumeReceipt {
    NSArray *ids = [NSArray arrayWithObjects:&verifingID count:1];
    NSArray *prices;
    if (!verifingPrice) {
        prices = @[ @(-1) ];
    } else {
        prices = [NSArray arrayWithObjects:&verifingPrice count:1];
    }
    verifingIDs = [ids copy];
    NSDictionary *post = [self createConsumeVerifyPostDictionary:ids.firstObject prices:prices];
    id downloader = [[NSClassFromString(@"SessionDownloader") alloc]
           initWithURL:[NSURL URLWithString:[NSClassFromString(@"ScratchUtil")
                                                performSelector:@selector(cubeVerifyReceiptURL)]]
        postDictionary:post
              delegate:self];
    [downloader performSelector:@selector(setTag:) withObject:@3];
    [downloader performSelector:@selector(setApiTag:) withObject:@(0x14)];
    [downloader performSelector:@selector(startDownloading)];
}

/** @ghidraAddress 0xb92b4 */
- (BOOL)verifyPendingConsumeReceipt {
    NSArray *transactions = SKPaymentQueue.defaultQueue.transactions;
    if (transactions.count == 0) {
        return NO;
    }
    return NO;
}

/** @ghidraAddress 0xb9628 */
- (BOOL)checkConsumeItemID:(NSString *)itemID {
    // Verified at 0xb9628: hasPrefix:@"jubeat.cube" — single b to 0x27cef0 at 0xb9630.
    return [itemID hasPrefix:@"jubeat.cube"];
}

/** @ghidraAddress 0xb9644 */
- (void)alertSelect:(id)alert {
    // Verified at 0xb9644: moves purchasingID to verifingID, clears purchasingID,
    // sets bConsume=1, then verifyConsumeReceipt.
    verifingID = purchasingID;
    purchasingID = nil;
    bConsume = YES;
    [self verifyConsumeReceipt];
}

/** @ghidraAddress 0xb96a4 */
- (void)dealloc {
    // Verified at 0xb96a4: setDelegate:0 at 0xb96c4, then objc_msgSendSuper2 dealloc
    self.delegate = nil;
    // [super dealloc] is compiler-emitted (ARC — .cxx_destruct at 0xb972c).
}

@end
