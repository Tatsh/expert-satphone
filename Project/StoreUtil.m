#import "StoreUtil.h"

#import <StoreKit/StoreKit.h>

#import "JubeatAppDelegate.h"
#import "StoreMusicInfo.h"
#import "StoreMusicListManager.h"

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

// TouchJSON's deserialiser category, used by -checkStoreResponse:.
@interface NSDictionary (CJSONDeserializer)
+ (nullable id)dictionaryWithJSONData:(nullable NSData *)data error:(NSError **)error;
@end

// The lowercase SHA-256 hex of a data buffer; a free function not reconstructed yet. Declared here
// so -checkStoreResponse: can call it. See TYPES_PENDING.md.
FOUNDATION_EXTERN NSString *_Nullable CreateSha256HexStringFromData(NSData *_Nullable data,
                                                                    BOOL uppercase);

// The salt written over the signature prefix before hashing. Kept verbatim from 0xba9a4.
static const char *const kStoreResponseSalt =
    "i3yuYjsZeKQq9zZ7dbm18Buwt6LioKJdfeGD7pMirHuTwfcC2vohdEnBNz9lkkld";
// The signature is the leading 64 hex characters of the response.
static const NSUInteger kStoreResponseSignatureLength = 0x40;

// De-inlined: wraps a path in "https://agx.s.konaminet.jp<path>" and builds the NSURL. The binary
// emits this two-format-call, alloc/initWithString: sequence inline in each URL builder.
static inline NSURL *StoreUtilURLForPath(NSString *path) {
    NSString *urlString = [NSString stringWithFormat:kStoreURLFormat, kStoreHost, path];
    return [[NSURL alloc] initWithString:urlString];
}

// De-inlined: appends the client-info query fragment to a mutable path and wraps it. The
// query-carrying URL builders share this tail.
static inline NSURL *StoreUtilURLForPathWithClientInfo(NSMutableString *path) {
    [path appendString:[StoreUtil queryStringForDictionary:JubeatAppDelegate.clientInfo]];
    return StoreUtilURLForPath(path);
}

// De-inlined: builds the policy/store URL with a {version, target} query where the version value is
// read from the given user-defaults key (or "" when absent). Shared by the two policy-store URLs.
static inline NSURL *StoreUtilPolicyStoreURLWithVersionDefaultsKey(NSString *defaultsKey) {
    NSMutableString *path = [NSMutableString
        stringWithFormat:@"%s/policy/store/?target=%s", kStoreCGIPath, kStoreRegion];
    NSString *version = [NSUserDefaults.standardUserDefaults objectForKey:defaultsKey];
    if (!version) {
        version = @"";
    }
    NSDictionary *params =
        @{@"version" : version, @"target" : [NSString stringWithFormat:@"%s", kStoreRegion]};
    [path appendString:[StoreUtil queryStringForDictionary:params]];
    return StoreUtilURLForPath(path);
}

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

/** @ghidraAddress 0xba318 */
+ (NSURL *)storeNewInfoURL {
    // Builds "/agx/main/cgi/new/?target=JP" plus the client-info query, under the store host.
    NSMutableString *path =
        [NSMutableString stringWithFormat:kStoreNewInfoPathFormat, kStoreCGIPath, kStoreRegion];
    return StoreUtilURLForPathWithClientInfo(path);
}

/** @ghidraAddress 0xb9a2c */
+ (NSURL *)packListURL:(unsigned int)head limit:(unsigned int)limit genre:(unsigned int)genre {
    NSMutableString *path =
        [NSMutableString stringWithFormat:@"%s/packlist_secure/?target=%s&head=%d&limit=%d",
                                          kStoreCGIPath,
                                          kStoreRegion,
                                          head,
                                          limit];
    if (genre != 0) {
        [path appendFormat:@"&genre=%d", genre];
    }
    return StoreUtilURLForPathWithClientInfo(path);
}

/** @ghidraAddress 0xb9ba0 */
+ (NSURL *)recommendPackListURL:(unsigned int)useGenre {
    // Head 0, limit 8, and — when a genre is wanted — one drawn at random from a fixed ten-entry
    // table. Verified at 0xb9c04: rand() % 10 indexes kRecommendGenres.
    static const int kRecommendGenres[] = {0, 130, 135, 115, 120, 140, 70, 110, 105, 100};
    NSMutableString *path =
        [NSMutableString stringWithFormat:@"%s/packlist_secure/?target=%s&head=%d&limit=%d",
                                          kStoreCGIPath,
                                          kStoreRegion,
                                          0,
                                          8];
    if (useGenre != 0) {
        [path appendFormat:@"&genre=%d", kRecommendGenres[rand() % 10]];
    }
    return StoreUtilURLForPathWithClientInfo(path);
}

/** @ghidraAddress 0xb9d48 */
+ (NSURL *)selectivePackListURL:(NSArray *)packIDs {
    // An empty set has no URL. Otherwise the pack identifiers are appended comma-separated after
    // "&packs=", the first without a leading comma. No client-info query.
    if (packIDs.count == 0) {
        return nil;
    }
    NSMutableString *path = [NSMutableString
        stringWithFormat:@"%s/optional_packlist/?target=%s&packs=", kStoreCGIPath, kStoreRegion];
    [packIDs enumerateObjectsUsingBlock:^(NSNumber *packID, NSUInteger index, BOOL *stop) {
      /** @ghidraAddress 0xb9eac */
      [path appendFormat:(index == 0 ? @"%d" : @",%d"), packID.unsignedIntValue];
    }];
    return StoreUtilURLForPath(path);
}

/** @ghidraAddress 0xb9f28 */
+ (NSURL *)packInfoURL:(unsigned int)packID {
    NSMutableString *path =
        [NSMutableString stringWithFormat:@"%s/packinfo_secure/?target=%s&pack=%d",
                                          kStoreCGIPath,
                                          kStoreRegion,
                                          packID];
    return StoreUtilURLForPathWithClientInfo(path);
}

/** @ghidraAddress 0xba078 */
+ (NSURL *)restorePackInfoURL:(unsigned int)packID {
    NSMutableString *path =
        [NSMutableString stringWithFormat:@"%s/restore_packinfo_secure/?target=%s&pack=%d",
                                          kStoreCGIPath,
                                          kStoreRegion,
                                          packID];
    return StoreUtilURLForPathWithClientInfo(path);
}

/** @ghidraAddress 0xba1c8 */
+ (NSURL *)musicInfoURL:(unsigned int)musicID {
    NSMutableString *path =
        [NSMutableString stringWithFormat:@"%s/musicinfo_secure/?target=%s&music=%d",
                                          kStoreCGIPath,
                                          kStoreRegion,
                                          musicID];
    return StoreUtilURLForPathWithClientInfo(path);
}

/** @ghidraAddress 0xba48c */
+ (NSURL *)privilegeListURL:(int)key {
    // Unlike the pack/music URLs this one carries no client-info query.
    NSString *path =
        [NSString stringWithFormat:@"%s/musiclistfree_secure/?target=%s&head=0&limit=10&key=%d",
                                   kStoreCGIPath,
                                   kStoreRegion,
                                   key];
    return StoreUtilURLForPath(path);
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
    return StoreUtilURLForPath(path);
}

/** @ghidraAddress 0xba64c */
+ (NSURL *)campaignSerialCheckURL {
    NSString *path = [NSString stringWithFormat:@"%s/campaign/verify/index.jsp", kStoreCGIPath];
    return StoreUtilURLForPath(path);
}

/** @ghidraAddress 0xba720 */
+ (NSURL *)campaignItemURL {
    NSString *path = [NSString stringWithFormat:@"%s/campaign/fetch/index.jsp", kStoreCGIPath];
    return StoreUtilURLForPath(path);
}

/** @ghidraAddress 0xba7f4 */
+ (NSURL *)knitColorURL {
    NSString *path = [NSString stringWithFormat:@"%s/knit/change_color/index.jsp", kStoreCGIPath];
    return StoreUtilURLForPath(path);
}

/** @ghidraAddress 0xba8c8 */
+ (NSURL *)markerListURL {
    NSString *path =
        [NSString stringWithFormat:@"%s/check_marker/?target=%s", kStoreCGIPath, kStoreRegion];
    return StoreUtilURLForPath(path);
}

/** @ghidraAddress 0xbb3bc */
+ (NSURL *)recommendPackURL:(unsigned int)musicID {
    NSMutableString *path =
        [NSMutableString stringWithFormat:@"%s/recommended_pack/?target=%s&music=%d",
                                          kStoreCGIPath,
                                          kStoreRegion,
                                          musicID];
    return StoreUtilURLForPathWithClientInfo(path);
}

/** @ghidraAddress 0xbb50c */
+ (NSURL *)startNewsURL {
    NSString *path =
        [NSString stringWithFormat:@"%s/startup/?target=%s", kStoreCGIPath, kStoreRegion];
    return StoreUtilURLForPath(path);
}

/** @ghidraAddress 0xbb5e8 */
+ (NSURL *)passedInfoListURL {
    // A single literal endpoint under the store host.
    NSString *urlString =
        [NSString stringWithFormat:@"https://%@/agx/main/news/passed_info.jsp", kStoreHost];
    return [[NSURL alloc] initWithString:urlString];
}

/** @ghidraAddress 0xbb67c */
+ (NSURL *)storeUserPolicyURL {
    return StoreUtilPolicyStoreURLWithVersionDefaultsKey(@"PrefStoreAgreeLicenseVersion");
}

/** @ghidraAddress 0xbb8b8 */
+ (NSURL *)storeExtendListURL {
    return StoreUtilPolicyStoreURLWithVersionDefaultsKey(@"PrefExtendListLastUpdate");
}

#pragma mark - Identifier maps

// The App Store product-identifier prefix for a pack. From the CFString at 0x2da3c0.
static NSString *const kStorePackProductPrefix = @"jubeat.pack";

/** @ghidraAddress 0xbab70 */
+ (NSString *)productIDForPackID:(int)packID {
    // Only positive pack identifiers have a product; the rest map to nil.
    if (packID > 0) {
        return [NSString stringWithFormat:@"%@%05d", kStorePackProductPrefix, packID];
    }
    return nil;
}

/** @ghidraAddress 0xbabc8 */
+ (int)packIDForProductID:(NSString *)productID {
    // Requires the "jubeat.pack" prefix and a positive number after it; -1 otherwise.
    if (productID.length > kStorePackProductPrefix.length &&
        [productID hasPrefix:kStorePackProductPrefix]) {
        int packID = [productID substringFromIndex:kStorePackProductPrefix.length].intValue;
        if (packID >= 1) {
            return packID;
        }
    }
    return -1;
}

#pragma mark - Music presence

/** @ghidraAddress 0xbbda8 */
+ (BOOL)existDownloadableExtendMusic:(NSArray *)entries {
    // A downloadable extend exists when an entry's base tune is in the store list and on disk but
    // its non-zero extend tune is not yet downloaded. Verified at 0xbbdf0-0xbbf3c.
    for (StoreMusicInfo *entry in entries) {
        if (![StoreMusicListManager.sharedManager hasMusic:entry.musicID]) {
            continue;
        }
        if (entry.extendMusicID == 0) {
            continue;
        }
        if ([self existMusicFile:entry.musicID] && ![self existMusicFile:entry.extendMusicID]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Affiliate parameters

/** @ghidraAddress 0xbad90 */
+ (NSDictionary *)affiliateParametersFromURL:(NSURL *)url {
    // Only iTunes URLs carry affiliate parameters. The query's i/at/ct pairs become the item
    // identifier, affiliate token, and campaign token. Verified at 0xbadd0-0xbb0a0.
    if (!url) {
        return nil;
    }
    if (![url.host isEqualToString:@"itunes.apple.com"]) {
        return nil;
    }
    NSInteger itemID = 0;
    NSString *affiliateToken = nil;
    NSString *campaignToken = nil;
    for (NSString *pair in [url.query componentsSeparatedByString:@"&"]) {
        if (pair.length == 0) {
            continue;
        }
        NSArray *kv = [pair componentsSeparatedByString:@"="];
        if (kv.count != 2) {
            continue;
        }
        NSString *key = kv[0];
        if ([key isEqualToString:@"i"]) {
            itemID = [kv[1] integerValue];
        } else if ([key isEqualToString:@"at"]) {
            affiliateToken = kv[1];
        } else if ([key isEqualToString:@"ct"]) {
            campaignToken = kv[1];
        }
    }
    if (!affiliateToken || itemID <= 0) {
        return nil;
    }
    if (!campaignToken) {
        return @{
            SKStoreProductParameterITunesItemIdentifier : @(itemID),
            SKStoreProductParameterAffiliateToken : affiliateToken,
        };
    }
    return @{
        SKStoreProductParameterITunesItemIdentifier : @(itemID),
        SKStoreProductParameterAffiliateToken : affiliateToken,
        SKStoreProductParameterCampaignToken : campaignToken,
    };
}

#pragma mark - Response verification

/** @ghidraAddress 0xba9a4 */
+ (NSDictionary *)checkStoreResponse:(NSData *)response {
    // The first 64 bytes are the expected SHA-256 hex of the body once its own signature prefix has
    // been overwritten with a fixed salt. Verified at 0xba9d4-0xbaa78.
    if (response.length < kStoreResponseSignatureLength) {
        return nil;
    }
    NSMutableData *salted = [[NSMutableData alloc] initWithData:response];
    NSData *signatureData = [salted subdataWithRange:NSMakeRange(0, kStoreResponseSignatureLength)];
    NSString *expected = [[NSString alloc] initWithData:signatureData
                                               encoding:NSUTF8StringEncoding];
    [salted replaceBytesInRange:NSMakeRange(0, kStoreResponseSignatureLength)
                      withBytes:kStoreResponseSalt
                         length:kStoreResponseSignatureLength];
    NSString *computed = CreateSha256HexStringFromData(salted, NO);
    if ([computed compare:expected options:NSCaseInsensitiveSearch] != NSOrderedSame) {
        return nil;
    }
    // The verified body is everything after the signature prefix.
    NSData *body =
        [response subdataWithRange:NSMakeRange(kStoreResponseSignatureLength,
                                               response.length - kStoreResponseSignatureLength)];
    return [NSDictionary dictionaryWithJSONData:body error:nil];
}

#pragma mark - Formatting

/** @ghidraAddress 0xbaca0 */
+ (NSString *)priceString:(NSNumber *)price withLocale:(NSLocale *)locale {
    if (!price || !locale) {
        return @"";
    }
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.formatterBehavior = NSNumberFormatterBehavior10_4;
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.locale = locale;
    return [formatter stringFromNumber:price];
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

/** @ghidraAddress 0xbbaf4 */
+ (BOOL)existMusicFile:(int)musicID {
    // On a build that ships the Music resource bundle, a tune is present when it is in the built-in
    // list; otherwise fall through to the on-disk check. Verified at 0xbbb1c-0xbbd44.
    if ([NSBundle.mainBundle pathForResource:@"Music" ofType:@""]) {
        for (NSNumber *builtin in StoreMusicListManager.sharedManager.builtinMusic) {
            if (builtin.intValue == musicID) {
                return YES;
            }
        }
    }
    // The downloaded-file check uses a plain "%d.jbt", not the zero-padded -filePathForMusicID:
    // form.
    NSString *name = [[NSString alloc] initWithFormat:@"%d.jbt", musicID];
    NSString *path = [JubeatAppDelegate.appDocumentsDirectory stringByAppendingPathComponent:name];
    return [NSFileManager.defaultManager fileExistsAtPath:path];
}

/** @ghidraAddress 0xbb310 */
+ (NSString *)filePathForMusicID:(unsigned int)musicID {
    // "<documents>/%09d.jbt" — the path is returned whether or not the file exists.
    NSString *name = [[NSString alloc] initWithFormat:@"%09d.jbt", musicID];
    return [JubeatAppDelegate.appDocumentsDirectory stringByAppendingPathComponent:name];
}

@end
