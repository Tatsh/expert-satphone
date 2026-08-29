/**
 * @file
 * The applilink SDK's compile-time and runtime constants and persisted configuration.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkConsts, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x351da8.
 *
 * This is Konami's applilink SDK. The class holds no instance state: its mutable state lives
 * in file-scope statics and @c NSUserDefaults , with the persisted user id, application-install
 * list, and template list encrypted through @c Crypto .
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Answers questions about what the SDK can do on this device and stores its configuration.
 */
@interface ApplilinkConsts : NSObject

/** The server environment name, from @c NSUserDefaults . @ghidraAddress 0x22e76c */
@property(class, nonatomic, readonly, nullable) NSString *envServer;
/** The HTTPS base every applilink web-API path is appended to. @ghidraAddress 0x22e7d8 */
@property(class, nonatomic, readonly, nullable) NSString *baseUrlSsl;
/** A short environment tag (release/staging/develop/sandbox/localhost).
 *  @ghidraAddress 0x22e994 */
@property(class, nonatomic, readonly, nullable) NSString *envStr;
/** The cookie domain for the current environment. @ghidraAddress 0x22eacc */
@property(class, nonatomic, readonly, nullable) NSString *cookieDomain;
/** The applilink application identifier. @ghidraAddress 0x22ebe0 */
@property(class, nonatomic, readonly, nullable) NSString *appliId;
/** Whether the SDK is usable at all on this OS version (iOS 6.1+). @ghidraAddress 0x22ec4c
 */
@property(class, nonatomic, readonly) BOOL canUseApplilinkSdk;
/** The SDK version string. @ghidraAddress 0x22ece0 */
@property(class, nonatomic, readonly, nullable) NSString *version;
/** The cached, decrypted user identifier. @ghidraAddress 0x22f0dc (getter),
 *  0x22ed0c (setter) */
@property(class, nonatomic, nullable) NSString *userId;
/** Whether a reward re-login is needed. @ghidraAddress 0x22f240 */
@property(class, nonatomic, readonly) BOOL isNeedRewardLogin;
/** Whether a recommend re-login is needed. @ghidraAddress 0x22f2b4 */
@property(class, nonatomic, readonly) BOOL isNeedRecommendLogin;
/** The advert category identifier. @ghidraAddress 0x22f544 (getter), 0x22f518 (setter) */
@property(class, nonatomic, nullable) NSString *categoryId;
/** The advertising identifier. @ghidraAddress 0x22f634 (getter), 0x22f554 (setter) */
@property(class, nonatomic, nullable) NSString *adId;
/** The country code. @ghidraAddress 0x22f508 (getter), 0x22f4a8 (setter) */
@property(class, nonatomic, nullable) NSString *countryCode;

/**
 * The SSL base URL with a path appended.
 * @param path The path to append.
 * @return The full URL string.
 * @ghidraAddress 0x22e904
 */
+ (nullable NSString *)getUrl:(nullable NSString *)path;

/**
 * Sets the user identifier (encrypting it), or clears it when nil, and flags a re-login.
 * @param userId The user identifier, or nil to clear it.
 * @ghidraAddress 0x22ed0c
 */
+ (void)setUserId:(nullable NSString *)userId;

/**
 * Clears the reward re-login flag. The binary declares a @c BOOL return but computes none.
 * @ghidraAddress 0x22f328
 */
+ (void)loggedInReward;

/**
 * Clears the recommend re-login flag. The binary declares a @c BOOL return but computes
 * none.
 * @ghidraAddress 0x22f3bc
 */
+ (void)loggedInRecommend;

/**
 * Sets the country code and locks out later overrides.
 * @param appliCountryCode The SDK-supplied country code.
 * @ghidraAddress 0x22f450
 */
+ (void)setAppliCountryCode:(nullable NSString *)appliCountryCode;

/**
 * The decrypted cached advertising identifier, or nil.
 * @return The advertising identifier.
 * @ghidraAddress 0x22f68c
 */
+ (nullable NSString *)getCacheAdId;

/**
 * Stores the advertising identifier, encrypted, in @c NSUserDefaults .
 * @param adId The advertising identifier.
 * @ghidraAddress 0x22f7f4
 */
+ (void)setCacheAdId:(nullable NSString *)adId;

/**
 * Stores the application-install list (encrypted to a temporary file) with a one-hour
 *        expiry, updating the advertising id from the entry matching the app's own URL scheme.
 * @param appInstallList The install list, or nil to clear it.
 * @ghidraAddress 0x22f938
 */
+ (void)setAppInstallList:(nullable NSArray *)appInstallList;

/**
 * Loads the application-install list to refresh the advertising id; always returns nil.
 * @return @c nil (the binary returns nil after refreshing the advertising id).
 * @ghidraAddress 0x22ff14
 */
+ (nullable id)appInstallList;

/**
 * Stores the template list, encrypted, in @c NSUserDefaults .
 * @param templateList The template list, or nil to clear it.
 * @ghidraAddress 0x2305bc
 */
+ (void)setTemplateList:(nullable NSDictionary *)templateList;

/**
 * The decrypted stored template list, or nil.
 * @return The template list.
 * @ghidraAddress 0x2307c8
 */
+ (nullable id)templateList;

/**
 * Clears the SDK's persistent defaults domain. The binary declares a @c BOOL return but
 *        computes none.
 * @ghidraAddress 0x230950
 */
+ (void)clearData;

/**
 * Whether the SDK may serve a request, reporting a failure to the delegate when not.
 * @param adModel The advert model.
 * @param adLocation The advert location.
 * @param verticalAlign The vertical alignment.
 * @param requestCode The request code.
 * @param delegate The delegate told of a refusal.
 * @return @c YES when the SDK is usable and ad tracking is enabled.
 * @ghidraAddress 0x230a30
 */
+ (BOOL)checkUseSDKWithAdModel:(int)adModel
                    adLocation:(nullable NSString *)adLocation
                 verticalAlign:(int)verticalAlign
                   requestCode:(nullable id)requestCode
                      delegate:(nullable id)delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
