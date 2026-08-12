#import "ApplilinkConsts.h"

#import "AnalysisNetworkCore.h"
#import "Crypto.h"

// The applilink SDK collaborators. Not reconstructed in this tree yet; declared here as forward
// classes. See TYPES_PENDING.md.
@interface ApplilinkUdid : NSObject
+ (BOOL)isAdvertisingTrackingEnabled;
@end

@interface ApplilinkParameters : NSObject
- (void)setRequestWithAdModel:(int)adModel
                   adLocation:(NSString *)adLocation
                  requestCode:(id)requestCode;
@end

@interface ApplilinkCore : NSObject
+ (void)toDelegateFailOpenWithError:(NSError *)error appParam:(id)appParam delegate:(id)delegate;
@end

@interface ApplilinkNetworkError : NSObject
+ (NSError *)localizedApplilinkErrorWithCode:(NSInteger)code;
@end

@interface RecommendCore : NSObject
+ (instancetype)sharedInstance;
- (void)startSessionWithCallback:(void (^)(NSError *error))callback;
@end

// The server environment name is compared against these string keys, each selecting a base URL.
static NSString *const kEnvProduction = @"0";
static NSString *const kEnvStaging = @"1";
static NSString *const kEnvSandboxAlt = @"2";
static NSString *const kEnvSandbox = @"3";
static NSString *const kEnvDevelopmentAlt = @"4";

// The base URLs keyed by the server environment name above.
static NSString *const kUrlProduction = @"https://www.applilink.jp";
static NSString *const kUrlStaging = @"https://st.es.i-revoinf.jp";
static NSString *const kUrlDevelopment = @"https://dev.es.i-revoinf.jp";
static NSString *const kUrlSandbox = @"https://sandbox.applilink.jp";

// The short environment tags keyed by the same server environment name.
static NSString *const kEnvStrRelease = @"release";
static NSString *const kEnvStrStaging = @"staging";
static NSString *const kEnvStrDevelop = @"develop";
static NSString *const kEnvStrSandbox = @"sandbox";
static NSString *const kEnvStrLocalhost = @"localhost";

// The cookie domains, one for the production/sandbox hosts and one for the i-revoinf hosts.
static NSString *const kCookieDomainApplilink = @".applilink.jp";
static NSString *const kCookieDomainRevoinf = @".i-revoinf.jp";

// The SDK version string.
static NSString *const kSdkVersion = @"2.4.0";

// The minimum operating-system version, as a float, that the SDK supports.
static const float kMinimumSystemVersion = 6.1f;

// The NSUserDefaults keys for the SDK's persisted state.
static NSString *const kDefaultsKeyEnv = @"ApplilinkNetwork.env";
static NSString *const kDefaultsKeyAppliId = @"ApplilinkNetwork.appliId";
static NSString *const kDefaultsKeyUserId = @"ApplilinkNetwork.userId";
static NSString *const kDefaultsKeyRewardReLoginFlg = @"ApplilinkReward.reLoginFlg";
static NSString *const kDefaultsKeyRecommendReLoginFlg = @"ApplilinkRecommend.reLoginFlg";
static NSString *const kDefaultsKeyAppInstallListExpire =
    @"ApplilinkRecommend.app.install.list.expire";
static NSString *const kDefaultsKeyTemplateList = @"ApplilinkRecommend.template.list";
static NSString *const kDefaultsKeyCacheAdId = @"ApplilinkRecommend.adid";

// The Crypto keys under which each persisted payload is encrypted.
static NSString *const kCryptoKeyUserId = @"applilink.reward.recommend";
static NSString *const kCryptoKeyAppInstallList = @"applilink.recommend.install.list";
static NSString *const kCryptoKeyTemplateList = @"applilink.recommend.template.list";
static NSString *const kCryptoKeyCacheAdId = @"applilink.recommend.ad.id";

// The application-install list is matched to the app's own URL scheme, then written to a temporary
// file, keyed by these dictionary keys and file name.
static NSString *const kBundleUrlTypesKey = @"CFBundleURLTypes";
static NSString *const kBundleUrlSchemesKey = @"CFBundleURLSchemes";
static NSString *const kInstallEntryDefaultSchemeKey = @"default_scheme";
static NSString *const kInstallEntryAdIdKey = @"ad_id";
static NSString *const kAppListRootKey = @"applist";
static NSString *const kTemplateListRootKey = @"templateList";
static NSString *const kAppInstallListFileName = @"applilinkapplist";

// The application-install list stays valid for one hour after it is stored.
static const NSTimeInterval kAppInstallListLifetime = 3600.0;

// The Crypto direction argument: encrypt plaintext, or decrypt ciphertext.
enum {
    kCryptoModeEncrypt = 0,
    kCryptoModeDecrypt = 1,
};

// The Applilink error codes reported to the delegate when a request is refused.
static const NSInteger kErrorSdkUnavailable = 0x401;
static const NSInteger kErrorTrackingDisabled = 0x404;

// The cached, decrypted user identifier.
static NSString *g_userId = nil;

// Whether the user identifier has already been posted once. Set on the first -setUserId: whose
// identifier matches the cached one, so the analysis POST for an unchanged identifier only fires
// once for the process.
static BOOL g_didPostUserId = NO;

// The country code, and whether the SDK itself supplied it (which locks out later overrides).
static NSString *g_countryCode = nil;
static BOOL g_appliCountryCodeSet = NO;

// The advert category identifier.
static NSString *g_categoryId = nil;

// The advertising identifier.
static NSString *g_adId = nil;

@implementation ApplilinkConsts

#pragma mark - Environment

/** @ghidraAddress 0x22e76c */
+ (NSString *)envServer {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultsKeyEnv];
}

/** @ghidraAddress 0x22e7d8 */
+ (NSString *)baseUrlSsl {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultsKeyEnv];
    if ([env isEqualToString:kEnvProduction]) {
        return kUrlProduction;
    }
    if ([env isEqualToString:kEnvStaging]) {
        return kUrlStaging;
    }
    if ([env isEqualToString:kEnvSandboxAlt]) {
        return kUrlDevelopment;
    }
    if ([env isEqualToString:kEnvSandbox]) {
        return kUrlSandbox;
    }
    if ([env isEqualToString:kEnvDevelopmentAlt]) {
        return kUrlDevelopment;
    }
    return kUrlProduction;
}

/** @ghidraAddress 0x22e904 */
+ (NSString *)getUrl:(NSString *)path {
    return [[self baseUrlSsl] stringByAppendingString:path];
}

/** @ghidraAddress 0x22e994 */
+ (NSString *)envStr {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultsKeyEnv];
    if ([env isEqualToString:kEnvProduction]) {
        return kEnvStrRelease;
    }
    if ([env isEqualToString:kEnvStaging]) {
        return kEnvStrStaging;
    }
    if ([env isEqualToString:kEnvSandboxAlt]) {
        return kEnvStrDevelop;
    }
    if ([env isEqualToString:kEnvSandbox]) {
        return kEnvStrSandbox;
    }
    if ([env isEqualToString:kEnvDevelopmentAlt]) {
        return kEnvStrLocalhost;
    }
    return kEnvStrRelease;
}

/** @ghidraAddress 0x22eacc */
+ (NSString *)cookieDomain {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultsKeyEnv];
    // The i-revoinf domain covers the staging, sandbox-alt, and development-alt environments; every
    // other environment (production and sandbox) uses the applilink domain.
    if (![env isEqualToString:kEnvProduction] &&
        ([env isEqualToString:kEnvStaging] || [env isEqualToString:kEnvSandboxAlt] ||
         (![env isEqualToString:kEnvSandbox] && [env isEqualToString:kEnvDevelopmentAlt]))) {
        return kCookieDomainRevoinf;
    }
    return kCookieDomainApplilink;
}

/** @ghidraAddress 0x22ebe0 */
+ (NSString *)appliId {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultsKeyAppliId];
}

/** @ghidraAddress 0x22ec4c */
+ (BOOL)canUseApplilinkSdk {
    return [UIDevice currentDevice].systemVersion.floatValue >= kMinimumSystemVersion;
}

/** @ghidraAddress 0x22ece0 */
+ (NSString *)version {
    return kSdkVersion;
}

#pragma mark - User identifier

/** @ghidraAddress 0x22ed0c */
+ (void)setUserId:(NSString *)userId {
    if (userId == nil) {
        [[NSUserDefaults standardUserDefaults] setObject:nil forKey:kDefaultsKeyUserId];
        g_userId = nil;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsKeyUserId];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kDefaultsKeyRecommendReLoginFlg];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return;
    }
    // The comparison uses the previous cached identifier, then the cache is refreshed regardless.
    BOOL changed = ![userId isEqualToString:g_userId];
    g_userId = [NSString stringWithString:userId];
    if (changed) {
        [AnalysisNetworkCore postSetUserIDWithCallback:^(NSError *__attribute__((unused)) error){
            /** @ghidraAddress 0x22f0d0 */
            // The binary passes an empty completion block here.
        }];
        NSData *value = [userId dataUsingEncoding:NSUTF8StringEncoding];
        NSData *key = [kCryptoKeyUserId dataUsingEncoding:NSUTF8StringEncoding];
        NSData *encrypted = [Crypto cryptorToData:kCryptoModeEncrypt value:value key:key];
        [[NSUserDefaults standardUserDefaults] setObject:encrypted forKey:kDefaultsKeyUserId];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kDefaultsKeyRewardReLoginFlg];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kDefaultsKeyRecommendReLoginFlg];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[RecommendCore sharedInstance]
            startSessionWithCallback:^(NSError *__attribute__((unused)) error){
                /** @ghidraAddress 0x22f0d4 */
                // The binary passes an empty completion block here.
            }];
    } else if (!g_didPostUserId) {
        [AnalysisNetworkCore postSetUserIDWithCallback:^(NSError *__attribute__((unused)) error){
            /** @ghidraAddress 0x22f0d8 */
            // The binary passes an empty completion block here.
        }];
    }
    g_didPostUserId = YES;
}

/** @ghidraAddress 0x22f0dc */
+ (NSString *)userId {
    if (g_userId == nil) {
        NSData *stored = [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultsKeyUserId];
        if (stored != nil) {
            NSData *key = [kCryptoKeyUserId dataUsingEncoding:NSUTF8StringEncoding];
            NSData *decrypted = [Crypto cryptorToData:kCryptoModeDecrypt value:stored key:key];
            g_userId = [[NSString alloc] initWithData:decrypted encoding:NSUTF8StringEncoding];
        }
    }
    return g_userId;
}

#pragma mark - Re-login flags

/** @ghidraAddress 0x22f240 */
+ (BOOL)isNeedRewardLogin {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultsKeyRewardReLoginFlg] != nil;
}

/** @ghidraAddress 0x22f2b4 */
+ (BOOL)isNeedRecommendLogin {
    return
        [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultsKeyRecommendReLoginFlg] != nil;
}

/** @ghidraAddress 0x22f328 */
+ (void)loggedInReward {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsKeyRewardReLoginFlg];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/** @ghidraAddress 0x22f3bc */
+ (void)loggedInRecommend {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsKeyRecommendReLoginFlg];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Country and category

/** @ghidraAddress 0x22f450 */
+ (void)setAppliCountryCode:(NSString *)appliCountryCode {
    g_countryCode = [NSString stringWithString:appliCountryCode];
    g_appliCountryCodeSet = YES;
}

/** @ghidraAddress 0x22f4a8 */
+ (void)setCountryCode:(NSString *)countryCode {
    if (g_appliCountryCodeSet) {
        return;
    }
    g_countryCode = [NSString stringWithString:countryCode];
}

/** @ghidraAddress 0x22f508 */
+ (NSString *)countryCode {
    return g_countryCode;
}

/** @ghidraAddress 0x22f518 */
+ (void)setCategoryId:(NSString *)categoryId {
    g_categoryId = categoryId;
}

/** @ghidraAddress 0x22f544 */
+ (NSString *)categoryId {
    return g_categoryId;
}

#pragma mark - Advertising identifier

/** @ghidraAddress 0x22f554 */
+ (void)setAdId:(NSString *)adId {
    g_adId = [NSString stringWithString:adId];
}

/** @ghidraAddress 0x22f634 */
+ (NSString *)adId {
    return g_adId;
}

/** @ghidraAddress 0x22f68c */
+ (NSString *)getCacheAdId {
    NSData *stored = [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultsKeyCacheAdId];
    if (stored == nil) {
        return nil;
    }
    NSData *key = [kCryptoKeyCacheAdId dataUsingEncoding:NSUTF8StringEncoding];
    NSData *decrypted = [Crypto cryptorToData:kCryptoModeDecrypt value:stored key:key];
    NSString *value = [[NSString alloc] initWithData:decrypted encoding:NSUTF8StringEncoding];
    if (value == nil) {
        return nil;
    }
    return [NSString stringWithString:value];
}

/** @ghidraAddress 0x22f7f4 */
+ (void)setCacheAdId:(NSString *)adId {
    if (adId == nil || [adId isKindOfClass:[NSNull class]]) {
        return;
    }
    NSData *value = [adId dataUsingEncoding:NSUTF8StringEncoding];
    NSData *key = [kCryptoKeyCacheAdId dataUsingEncoding:NSUTF8StringEncoding];
    NSData *encrypted = [Crypto cryptorToData:kCryptoModeEncrypt value:value key:key];
    [[NSUserDefaults standardUserDefaults] setObject:encrypted forKey:kDefaultsKeyCacheAdId];
}

#pragma mark - Application-install list

/** @ghidraAddress 0x22f938 */
+ (void)setAppInstallList:(NSArray *)appInstallList {
    if (appInstallList == nil) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsKeyAppInstallListExpire];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return;
    }

    NSString *ownScheme = [[[[NSBundle mainBundle].infoDictionary valueForKey:kBundleUrlTypesKey]
        objectAtIndex:0] valueForKey:kBundleUrlSchemesKey][0];
    if (ownScheme != nil) {
        for (NSDictionary *entry in appInstallList) {
            if ([ownScheme isEqualToString:entry[kInstallEntryDefaultSchemeKey]]) {
                [self setAdId:entry[kInstallEntryAdIdKey]];
                break;
            }
        }
    }

    NSDictionary *wrapped =
        [NSDictionary dictionaryWithObjectsAndKeys:appInstallList, kAppListRootKey, nil];
    NSData *plain = [wrapped.description dataUsingEncoding:NSUTF8StringEncoding];
    NSData *key = [kCryptoKeyAppInstallList dataUsingEncoding:NSUTF8StringEncoding];
    NSData *encrypted = [Crypto cryptorToData:kCryptoModeEncrypt value:plain key:key];
    NSString *filePath =
        [NSTemporaryDirectory() stringByAppendingPathComponent:kAppInstallListFileName];
    [encrypted writeToFile:filePath atomically:YES];

    NSDate *expiry = [[NSDate date] dateByAddingTimeInterval:kAppInstallListLifetime];
    NSData *archivedExpiry = [NSKeyedArchiver archivedDataWithRootObject:expiry];
    [[NSUserDefaults standardUserDefaults] setObject:archivedExpiry
                                              forKey:kDefaultsKeyAppInstallListExpire];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/** @ghidraAddress 0x22ff14 */
+ (id)appInstallList {
    NSData *archivedExpiry =
        [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultsKeyAppInstallListExpire];
    if (archivedExpiry == nil) {
        return nil;
    }
    NSDate *expiry = [NSKeyedUnarchiver unarchiveObjectWithData:archivedExpiry];
    if (expiry == nil) {
        return nil;
    }

    NSString *filePath =
        [NSTemporaryDirectory() stringByAppendingPathComponent:kAppInstallListFileName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([expiry compare:[NSDate date]] == NSOrderedAscending) {
        [fileManager removeItemAtPath:filePath error:nil];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsKeyAppInstallListExpire];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return nil;
    }

    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    if (fileHandle == nil) {
        return nil;
    }

    NSData *stored = [fileHandle readDataToEndOfFile];
    NSData *key = [kCryptoKeyAppInstallList dataUsingEncoding:NSUTF8StringEncoding];
    NSData *decrypted = [Crypto cryptorToData:kCryptoModeDecrypt value:stored key:key];
    NSString *plainText = [[NSString alloc] initWithData:decrypted encoding:NSUTF8StringEncoding];
    NSArray *list = plainText.propertyList[kAppListRootKey];

    if ([self adId] == nil) {
        NSString *ownScheme =
            [[[[NSBundle mainBundle].infoDictionary valueForKey:kBundleUrlTypesKey] objectAtIndex:0]
                valueForKey:kBundleUrlSchemesKey][0];
        if (ownScheme != nil) {
            for (NSDictionary *entry in list) {
                if ([ownScheme isEqualToString:entry[kInstallEntryDefaultSchemeKey]]) {
                    [self setAdId:entry[kInstallEntryAdIdKey]];
                    break;
                }
            }
        }
    }
    // The binary loads and decrypts the list to refresh the advertising identifier, but returns nil
    // rather than the parsed list.
    return nil;
}

#pragma mark - Template list

/** @ghidraAddress 0x2305bc */
+ (void)setTemplateList:(NSDictionary *)templateList {
    if (templateList == nil) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsKeyTemplateList];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return;
    }
    NSDictionary *wrapped =
        [NSDictionary dictionaryWithObjectsAndKeys:templateList, kTemplateListRootKey, nil];
    NSData *plain = [wrapped.description dataUsingEncoding:NSUTF8StringEncoding];
    NSData *key = [kCryptoKeyTemplateList dataUsingEncoding:NSUTF8StringEncoding];
    NSData *encrypted = [Crypto cryptorToData:kCryptoModeEncrypt value:plain key:key];
    [[NSUserDefaults standardUserDefaults] setObject:encrypted forKey:kDefaultsKeyTemplateList];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/** @ghidraAddress 0x2307c8 */
+ (id)templateList {
    NSData *stored = [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultsKeyTemplateList];
    if (stored == nil) {
        return nil;
    }
    NSData *key = [kCryptoKeyTemplateList dataUsingEncoding:NSUTF8StringEncoding];
    NSData *decrypted = [Crypto cryptorToData:kCryptoModeDecrypt value:stored key:key];
    NSString *plainText = [[NSString alloc] initWithData:decrypted encoding:NSUTF8StringEncoding];
    return plainText.propertyList[kTemplateListRootKey];
}

#pragma mark - Reset

/** @ghidraAddress 0x230950 */
+ (void)clearData {
    NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Request gating

/** @ghidraAddress 0x230a30 */
+ (BOOL)checkUseSDKWithAdModel:(int)adModel
                    adLocation:(NSString *)adLocation
                 verticalAlign:(int)verticalAlign
                   requestCode:(id)requestCode
                      delegate:(id)delegate {
    NSInteger errorCode;
    if ([ApplilinkConsts canUseApplilinkSdk]) {
        if ([ApplilinkUdid isAdvertisingTrackingEnabled]) {
            return YES;
        }
        errorCode = kErrorTrackingDisabled;
    } else {
        errorCode = kErrorSdkUnavailable;
    }
    ApplilinkParameters *params = [[ApplilinkParameters alloc] init];
    [params setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
    NSError *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:errorCode];
    [ApplilinkCore toDelegateFailOpenWithError:error appParam:params delegate:delegate];
    return NO;
}

@end
