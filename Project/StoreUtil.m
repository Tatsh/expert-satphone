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
// De-inlined: appends the client-info query fragment to a mutable path and wraps it. The
// query-carrying URL builders share this tail.
+ (nullable NSURL *)storeURLForPathWithClientInfo:(NSMutableString *)path;
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

+ (NSURL *)storeURLForPathWithClientInfo:(NSMutableString *)path {
    [path appendString:[self queryStringForDictionary:JubeatAppDelegate.clientInfo]];
    return [self storeURLForPath:path];
}

/** @ghidraAddress 0xba318 */
+ (NSURL *)storeNewInfoURL {
    // Builds "/agx/main/cgi/new/?target=JP" plus the client-info query, under the store host.
    NSMutableString *path =
        [NSMutableString stringWithFormat:kStoreNewInfoPathFormat, kStoreCGIPath, kStoreRegion];
    return [self storeURLForPathWithClientInfo:path];
}

/** @ghidraAddress 0xb9f28 */
+ (NSURL *)packInfoURL:(unsigned int)packID {
    NSMutableString *path =
        [NSMutableString stringWithFormat:@"%s/packinfo_secure/?target=%s&pack=%d",
                                          kStoreCGIPath,
                                          kStoreRegion,
                                          packID];
    return [self storeURLForPathWithClientInfo:path];
}

/** @ghidraAddress 0xba078 */
+ (NSURL *)restorePackInfoURL:(unsigned int)packID {
    NSMutableString *path =
        [NSMutableString stringWithFormat:@"%s/restore_packinfo_secure/?target=%s&pack=%d",
                                          kStoreCGIPath,
                                          kStoreRegion,
                                          packID];
    return [self storeURLForPathWithClientInfo:path];
}

/** @ghidraAddress 0xba1c8 */
+ (NSURL *)musicInfoURL:(unsigned int)musicID {
    NSMutableString *path =
        [NSMutableString stringWithFormat:@"%s/musicinfo_secure/?target=%s&music=%d",
                                          kStoreCGIPath,
                                          kStoreRegion,
                                          musicID];
    return [self storeURLForPathWithClientInfo:path];
}

/** @ghidraAddress 0xba48c */
+ (NSURL *)privilegeListURL:(int)key {
    // Unlike the pack/music URLs this one carries no client-info query.
    NSString *path =
        [NSString stringWithFormat:@"%s/musiclistfree_secure/?target=%s&head=0&limit=10&key=%d",
                                   kStoreCGIPath,
                                   kStoreRegion,
                                   key];
    return [self storeURLForPath:path];
}

/** @ghidraAddress 0xba56c */
+ (NSURL *)privilegeMusicInfoURL:(unsigned int)musicID {
    return [self musicInfoURL:musicID];
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

/** @ghidraAddress 0xbb3bc */
+ (NSURL *)recommendPackURL:(unsigned int)musicID {
    NSMutableString *path =
        [NSMutableString stringWithFormat:@"%s/recommended_pack/?target=%s&music=%d",
                                          kStoreCGIPath,
                                          kStoreRegion,
                                          musicID];
    return [self storeURLForPathWithClientInfo:path];
}

/** @ghidraAddress 0xbb50c */
+ (NSURL *)startNewsURL {
    NSString *path =
        [NSString stringWithFormat:@"%s/startup/?target=%s", kStoreCGIPath, kStoreRegion];
    return [self storeURLForPath:path];
}

/** @ghidraAddress 0xbb5e8 */
+ (NSURL *)passedInfoListURL {
    // A single literal endpoint under the store host.
    NSString *urlString =
        [NSString stringWithFormat:@"https://%@/agx/main/news/passed_info.jsp", kStoreHost];
    return [[NSURL alloc] initWithString:urlString];
}

#pragma mark - Utilities

/** @ghidraAddress 0xbb230 */
+ (BOOL)isValidURL:(NSString *)url {
    // A URL is kept only when it parses and its scheme is http or https.
    NSURL *parsed = [NSURL URLWithString:url];
    if (!parsed) {
        return NO;
    }
    if ([parsed.scheme isEqualToString:@"http"]) {
        return YES;
    }
    return [parsed.scheme isEqualToString:@"https"];
}

/** @ghidraAddress 0xbb310 */
+ (NSString *)filePathForMusicID:(unsigned int)musicID {
    // "<documents>/%09d.jbt" — the path is returned whether or not the file exists.
    NSString *name = [[NSString alloc] initWithFormat:@"%09d.jbt", musicID];
    return [JubeatAppDelegate.appDocumentsDirectory stringByAppendingPathComponent:name];
}

@end
