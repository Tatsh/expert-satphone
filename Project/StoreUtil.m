#import "StoreUtil.h"

#import "JubeatAppDelegate.h"

// ScratchUtil is reached only for the shared receipt-verify URL; its class is reached by name since
// only this one selector is needed here.
static NSString *const kScratchUtilClassName = @"ScratchUtil";

// The store-new-info endpoint. From the CFStrings at 0x2da2c0, 0x2da200, and 0x2da5c0, and the C
// strings at 0x2829a2 and 0x27f352.
static NSString *const kStoreNewInfoPathFormat = @"%s/new/?target=%s";
static const char *const kStoreCGIPath = "/agx/main/cgi";
static const char *const kStoreRegion = "JP";
static NSString *const kStoreHost = @"agx.s.konaminet.jp";
static NSString *const kStoreURLFormat = @"https://%@%@";

// The block that appends one query pair; declared so -queryStringForDictionary: can reference it by
// name in a comment. Its selectors are messaged dynamically.
@interface NSObject (StoreUtilScratch)
+ (nullable NSURL *)cubeVerifyReceiptURL;
@end

@interface StoreUtil ()
// De-inlined: wraps a path in "https://agx.s.konaminet.jp<path>" and builds the NSURL. The binary
// emits this two-format-call, alloc/initWithString: sequence inline in each URL builder.
+ (nullable NSURL *)storeURLForPath:(NSString *)path;
@end

@implementation StoreUtil

#pragma mark - Layout metrics

/** @ghidraAddress 0xb9844 */
+ (int)storeTabHeaderHeight {
    return 44;
}

/** @ghidraAddress 0xb984c */
+ (int)storeTabFooterHeight {
    return 49;
}

/** @ghidraAddress 0xb9854 */
+ (int)storeCategoryListHeight {
    return 80;
}

/** @ghidraAddress 0xb985c */
+ (int)storeCategoryTitleHeight {
    return 100;
}

#pragma mark - Query strings

/** @ghidraAddress 0xb9864 */
+ (NSString *)queryStringForDictionary:(NSDictionary *)dictionary {
    // Appends one "&key=value" pair per string entry; the leading "&" is unconditional, so the
    // result is a fragment to append after an existing query, not a standalone query string.
    NSMutableString *query = [[NSMutableString alloc] init];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
      /** @ghidraAddress 0xb9950 */
      if ([key isKindOfClass:NSString.class] && [value isKindOfClass:NSString.class]) {
          [query appendFormat:@"&%@=%@", key, value];
      }
    }];
    return [NSString stringWithString:query];
}

#pragma mark - URLs

+ (NSURL *)storeURLForPath:(NSString *)path {
    NSString *urlString = [NSString stringWithFormat:kStoreURLFormat, kStoreHost, path];
    return [[NSURL alloc] initWithString:urlString];
}

/** @ghidraAddress 0xba318 */
+ (NSURL *)storeNewInfoURL {
    // Builds "/agx/main/cgi/new/?target=JP" plus the client-info query, under the store host.
    NSMutableString *path =
        [NSMutableString stringWithFormat:kStoreNewInfoPathFormat, kStoreCGIPath, kStoreRegion];
    [path appendString:[self queryStringForDictionary:JubeatAppDelegate.clientInfo]];
    return [self storeURLForPath:path];
}

/** @ghidraAddress 0xba464 */
+ (NSURL *)verifyReceiptNewURL {
    return [NSClassFromString(kScratchUtilClassName) cubeVerifyReceiptURL];
}

/** @ghidraAddress 0xba478 */
+ (NSURL *)verifyReceiptConsumeURL {
    // Identical to +verifyReceiptNewURL; both delegate to the same ScratchUtil endpoint.
    return [NSClassFromString(kScratchUtilClassName) cubeVerifyReceiptURL];
}

/** @ghidraAddress 0xba578 */
+ (NSURL *)campaignListURL {
    NSString *path = [NSString stringWithFormat:@"%s/campaign/list/index.jsp", kStoreCGIPath];
    return [self storeURLForPath:path];
}

/** @ghidraAddress 0xba64c */
+ (NSURL *)campaignSerialCheckURL {
    NSString *path = [NSString stringWithFormat:@"%s/campaign/verify/index.jsp", kStoreCGIPath];
    return [self storeURLForPath:path];
}

/** @ghidraAddress 0xba720 */
+ (NSURL *)campaignItemURL {
    NSString *path = [NSString stringWithFormat:@"%s/campaign/fetch/index.jsp", kStoreCGIPath];
    return [self storeURLForPath:path];
}

/** @ghidraAddress 0xba7f4 */
+ (NSURL *)knitColorURL {
    NSString *path = [NSString stringWithFormat:@"%s/knit/change_color/index.jsp", kStoreCGIPath];
    return [self storeURLForPath:path];
}

/** @ghidraAddress 0xba8c8 */
+ (NSURL *)markerListURL {
    NSString *path =
        [NSString stringWithFormat:@"%s/check_marker/?target=%s", kStoreCGIPath, kStoreRegion];
    return [self storeURLForPath:path];
}

@end
