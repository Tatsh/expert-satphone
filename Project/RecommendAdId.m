#import "RecommendAdId.h"

#import <UIKit/UIKit.h>

#import "ApplilinkConsts.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkWebAPI.h"
#import "Crypto.h"

// The advertising-udid accessor; ApplilinkUdid is not reconstructed in this tree yet. See
// TYPES_PENDING.md.
@interface ApplilinkUdid : NSObject
+ (nullable NSString *)getAdUdid;
@end

// The synchronous web-API entry point ApplilinkWebAPI vends; not yet declared in its header. See
// TYPES_PENDING.md.
@interface ApplilinkWebAPI (Synchronous)
+ (nullable NSDictionary *)requestSynchronousWithURL:(nullable NSString *)url
                                              method:(nullable NSString *)method
                                          parameters:(nullable NSDictionary *)parameters
                                         cachePolicy:(nullable id)cachePolicy
                                               error:(NSError *_Nullable *_Nullable)error;
@end

// The lowest iOS version whose ad-identifier record is stored server-side (through the Applilink
// pasteboard web API) rather than in a local device pasteboard.
static const float kServerStorageMinimumSystemVersion = 7.0f;

// Builds the local pasteboard name from a fixed prefix, the country code, and the category id:
// "ApplilinkRecommend.AdId_<countryCode>_<categoryId>".
static NSString *const kServiceNameFormat = @"%@_%@_%@";
static NSString *const kServiceNamePrefix = @"ApplilinkRecommend.AdId";

// The pasteboard type under which the archived record is stored on the local device pasteboard.
static NSString *const kPasteboardType = @"applilink.adid";

// Applilink pasteboard web-API endpoint paths, appended to the SSL base URL.
static NSString *const kPathGet = @"/ad/external/pasteboard/get.php";
static NSString *const kPathSet = @"/ad/external/pasteboard/set.php";
static NSString *const kPathDelete = @"/ad/external/pasteboard/delete.php";

// HTTP methods used by the pasteboard web API.
static NSString *const kHTTPMethodGet = @"GET";
static NSString *const kHTTPMethodPost = @"POST";

// Keys of the record dictionary returned to and accepted from callers.
static NSString *const kKeyCountryCode = @"CountryCode";
static NSString *const kKeyCategoryId = @"CategoryId";
static NSString *const kKeyAdIdFrom = @"AdIdFrom";
static NSString *const kKeyAdType = @"AdType";
static NSString *const kKeyEntryDate = @"EntryDate";

// Keys of the web-API request body.
static NSString *const kRequestKeyUdid = @"udid";
static NSString *const kRequestKeyCountryCode = @"country_code";
static NSString *const kRequestKeyCategoryId = @"category_id";
static NSString *const kRequestKeyAdIdFrom = @"ad_id_from";
static NSString *const kRequestKeyAdType = @"ad_type";

// Keys of the web-API response body.
static NSString *const kResponseKeyStatus = @"status";
static NSString *const kResponseKeyErrorCode = @"error_code";
static NSString *const kResponseKeyKind = @"kind";
static NSString *const kResponseKeyCountryCode = @"country_code";
static NSString *const kResponseKeyCategoryId = @"category_id";
static NSString *const kResponseKeyAdIdFrom = @"ad_id_from";
static NSString *const kResponseKeyAdType = @"ad_type";

// Response @c kind values that map an unsuccessful response to a specific Applilink error.
static NSString *const kKindAuthorization = @"authorization";
static NSString *const kKindParameterError = @"parameter_error";

// The NSString encoding used both for the Crypto hashing input and for its decrypted output.
static const NSStringEncoding kStringEncoding = NSUTF8StringEncoding;

// The Crypto cryptor direction: 0 encrypts, 1 decrypts.
static const unsigned int kCryptorEncrypt = 0;
static const unsigned int kCryptorDecrypt = 1;

// Applilink error codes passed to +localizedApplilinkErrorWithCode:[userInfo:].
enum {
    kErrorCodeGeneric = 1000,
    kErrorParameterError = 1001,        // 0x3e9
    kErrorAuthorization = 1002,         // 0x3ea
    kErrorRequestFailed = 1003,         // 0x3eb
    kErrorServerRejected = 1009,        // 0x3f1
    kErrorPasteboardUnavailable = 1013, // 0x3f5
    kErrorRecordNotFound = 1018,        // 0x3fa
    kErrorUdidUnavailable = 1028,       // 0x404
};

// Response @c error_code sentinel for a well-formed successful response, and the specific
// server-side error code the response maps to +localizedApplilinkErrorWithCode:.
enum {
    kResponseErrorCodeNone = 100000000,
    kResponseErrorCodeServerRejected = 0xc106101,
};

@interface RecommendAdId () {
    // The local device pasteboard name; also the Crypto hashing key for locally stored records.
    NSString *_serviceName;
}
- (nullable NSDictionary *)convertToData:(nullable NSDictionary *)data;
- (nullable NSDictionary *)getPasteboardWithUdid:(nullable NSString *)udid
                                     countryCode:(nullable NSString *)countryCode
                                      categoryId:(nullable NSString *)categoryId
                                           error:(NSError *_Nullable *_Nullable)error;
- (void)setPasteboardWithUdid:(nullable NSString *)udid
                  countryCode:(nullable NSString *)countryCode
                   categoryId:(nullable NSString *)categoryId
                     adIdFrom:(nullable NSString *)adIdFrom
                       adType:(nullable NSString *)adType
                        error:(NSError *_Nullable *_Nullable)error;
- (void)deletePasteboardWithUdid:(nullable NSString *)udid
                     countryCode:(nullable NSString *)countryCode
                      categoryId:(nullable NSString *)categoryId
                           error:(NSError *_Nullable *_Nullable)error;
@end

@implementation RecommendAdId

#pragma mark - Lifecycle

/** @ghidraAddress 0x22ba00 */
- (instancetype)initWithCountryCode:(NSString *)countryCode categoryId:(NSString *)categoryId {
    self = [super init];
    if (self) {
        _serviceName = [NSString
            stringWithFormat:kServiceNameFormat, kServiceNamePrefix, countryCode, categoryId];
    }
    return self;
}

#pragma mark - Public record access

/** @ghidraAddress 0x22bad8 */
- (NSDictionary *)getWithCountryCode:(NSString *)countryCode
                          categoryId:(NSString *)categoryId
                               error:(NSError *_Nullable *)error {
    if ([UIDevice currentDevice].systemVersion.floatValue >= kServerStorageMinimumSystemVersion) {
        NSString *udid = [ApplilinkUdid getAdUdid];
        if (udid == nil) {
            if (error != nullptr) {
                *error =
                    [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorUdidUnavailable];
            }
            return nil;
        }
        NSString *hashedUdid = [Crypto sha1:udid];
        NSError *requestError = nil;
        NSDictionary *record = [self getPasteboardWithUdid:hashedUdid
                                               countryCode:countryCode
                                                categoryId:categoryId
                                                     error:&requestError];
        if (requestError != nil) {
            if (error != nullptr) {
                *error = requestError;
            }
            return nil;
        }
        return record;
    }
    UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:_serviceName create:NO];
    if (pasteboard == nil) {
        if (error != nullptr) {
            *error =
                [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorPasteboardUnavailable];
        }
        return nil;
    }
    id archived = [pasteboard valueForPasteboardType:kPasteboardType];
    if (archived == nil) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorRecordNotFound];
        }
        return nil;
    }
    NSDictionary *stored = [NSKeyedUnarchiver unarchiveObjectWithData:archived];
    return [self convertToData:stored];
}

/** @ghidraAddress 0x22be90 */
- (void)setWithAdIdFrom:(NSString *)adIdFrom
            countryCode:(NSString *)countryCode
             categoryId:(NSString *)categoryId
                 adType:(NSString *)adType
                  error:(NSError *_Nullable *)error {
    if ([UIDevice currentDevice].systemVersion.floatValue >= kServerStorageMinimumSystemVersion) {
        NSString *udid = [ApplilinkUdid getAdUdid];
        if (udid == nil) {
            if (error != nullptr) {
                *error =
                    [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorUdidUnavailable];
            }
            return;
        }
        NSString *hashedUdid = [Crypto sha1:udid];
        NSError *requestError = nil;
        [self setPasteboardWithUdid:hashedUdid
                        countryCode:countryCode
                         categoryId:categoryId
                           adIdFrom:adIdFrom
                             adType:adType
                              error:&requestError];
        if (requestError != nil) {
            if (error != nullptr) {
                *error = requestError;
            }
            return;
        }
        NSMutableDictionary *record = [NSMutableDictionary dictionaryWithCapacity:4];
        if (countryCode != nil) {
            [record setValue:countryCode forKey:kKeyCountryCode];
        }
        if (categoryId != nil) {
            [record setValue:categoryId forKey:kKeyCategoryId];
        }
        if (adIdFrom != nil) {
            [record setValue:adIdFrom forKey:kKeyAdIdFrom];
        }
        if (adType != nil) {
            [record setValue:adType forKey:kKeyAdType];
        }
        return;
    }
    // Pre-iOS 7: build the record locally, encrypt each field with the service-name-derived key,
    // and archive it into a persistent device pasteboard.
    NSData *keyData = [_serviceName dataUsingEncoding:kStringEncoding];
    NSData *key = [Crypto createHash:keyData];
    NSData *encryptedAdIdFrom = [Crypto cryptorToData:kCryptorEncrypt
                                                value:[adIdFrom dataUsingEncoding:kStringEncoding]
                                                  key:key];
    NSData *encryptedCountryCode =
        [Crypto cryptorToData:kCryptorEncrypt
                        value:[countryCode dataUsingEncoding:kStringEncoding]
                          key:key];
    NSData *encryptedCategoryId =
        [Crypto cryptorToData:kCryptorEncrypt
                        value:[categoryId dataUsingEncoding:kStringEncoding]
                          key:key];
    NSData *encryptedAdType = nil;
    if (adType != nil) {
        encryptedAdType = [Crypto cryptorToData:kCryptorEncrypt
                                          value:[adType dataUsingEncoding:kStringEncoding]
                                            key:key];
    }
    NSDate *entryDate = [NSDate date];
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithCapacity:5];
    if (encryptedAdIdFrom != nil) {
        [record setValue:encryptedAdIdFrom forKey:kKeyAdIdFrom];
    }
    if (encryptedCountryCode != nil) {
        [record setValue:encryptedCountryCode forKey:kKeyCountryCode];
    }
    if (encryptedCategoryId != nil) {
        [record setValue:encryptedCategoryId forKey:kKeyCategoryId];
    }
    if (entryDate != nil) {
        [record setValue:entryDate forKey:kKeyEntryDate];
    }
    // Yes, the binary gates on adType but stores encryptedAdType (nil above when adType is nil).
    if (adType != nil) {
        [record setValue:encryptedAdType forKey:kKeyAdType];
    }
    UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:_serviceName create:YES];
    if (pasteboard == nil) {
        if (error != nullptr) {
            *error =
                [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorPasteboardUnavailable];
        }
        return;
    }
    pasteboard.persistent = YES;
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:record];
    [pasteboard setData:archived forPasteboardType:kPasteboardType];
    // Yes, the binary discards this decrypted round-trip; it is evaluated only for its side
    // effects.
    [self convertToData:record];
}

/** @ghidraAddress 0x22c5a4 */
- (BOOL)deleteWithCountryCode:(NSString *)countryCode
                   categoryId:(NSString *)categoryId
                        error:(NSError *_Nullable *)error {
    if ([UIDevice currentDevice].systemVersion.floatValue >= kServerStorageMinimumSystemVersion) {
        NSString *udid = [ApplilinkUdid getAdUdid];
        if (udid == nil) {
            if (error != nullptr) {
                *error =
                    [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorUdidUnavailable];
            }
            return NO;
        }
        NSString *hashedUdid = [Crypto sha1:udid];
        NSError *requestError = nil;
        [self deletePasteboardWithUdid:hashedUdid
                           countryCode:countryCode
                            categoryId:categoryId
                                 error:&requestError];
        if (requestError != nil) {
            if (error != nullptr) {
                *error = requestError;
            }
            return NO;
        }
        return YES;
    }
    UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:_serviceName create:NO];
    if (pasteboard == nil) {
        if (error != nullptr) {
            *error =
                [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorPasteboardUnavailable];
        }
        return NO;
    }
    [pasteboard setData:nil forPasteboardType:kPasteboardType];
    [UIPasteboard removePasteboardWithName:_serviceName];
    return YES;
}

#pragma mark - Local record decryption

/** @ghidraAddress 0x22c830 */
- (NSDictionary *)convertToData:(NSDictionary *)data {
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithDictionary:data];
    NSData *keyData = [_serviceName dataUsingEncoding:kStringEncoding];
    NSData *key = [Crypto createHash:keyData];

    id encryptedAdIdFrom = record[kKeyAdIdFrom];
    NSString *adIdFrom = [[NSString alloc] initWithData:[Crypto cryptorToData:kCryptorDecrypt
                                                                        value:encryptedAdIdFrom
                                                                          key:key]
                                               encoding:kStringEncoding];
    if (adIdFrom != nil) {
        record[kKeyAdIdFrom] = adIdFrom;
    }

    NSString *countryCode = [[NSString alloc]
        initWithData:[Crypto cryptorToData:kCryptorDecrypt value:record[kKeyCountryCode] key:key]
            encoding:kStringEncoding];
    if (countryCode != nil) {
        record[kKeyCountryCode] = countryCode;
    }

    NSString *categoryId = [[NSString alloc]
        initWithData:[Crypto cryptorToData:kCryptorDecrypt value:record[kKeyCategoryId] key:key]
            encoding:kStringEncoding];
    if (categoryId != nil) {
        record[kKeyCategoryId] = categoryId;
    }

    id encryptedAdType = record[kKeyAdType];
    // Yes, the binary gates the ad-type decryption on the AdIdFrom entry, not on the AdType entry.
    if (encryptedAdIdFrom != nil) {
        NSString *adType = [[NSString alloc] initWithData:[Crypto cryptorToData:kCryptorDecrypt
                                                                          value:encryptedAdType
                                                                            key:key]
                                                 encoding:kStringEncoding];
        if (adType != nil) {
            record[kKeyAdType] = adType;
        }
    }
    return record;
}

#pragma mark - Pasteboard web API

// Maps an unsuccessful pasteboard-web-API response to an Applilink error code, returning 0 when the
// response indicates success. De-inlines the identical classification block the binary repeats in
// each of the three web-API methods.
static NSInteger ErrorCodeForResponse(NSDictionary *response) {
    id status = response[kResponseKeyStatus];
    if (![status isKindOfClass:[NSString class]] && ![status isKindOfClass:[NSNumber class]]) {
        status = nil;
    }
    BOOL succeeded = [status boolValue];

    id errorCodeValue = response[kResponseKeyErrorCode];
    int errorCode;
    if (([errorCodeValue isKindOfClass:[NSString class]] ||
         [errorCodeValue isKindOfClass:[NSNumber class]]) &&
        errorCodeValue != nil) {
        errorCode = [errorCodeValue intValue];
    } else {
        errorCode = kResponseErrorCodeNone;
    }

    id kind = response[kResponseKeyKind];
    if (![kind isKindOfClass:[NSString class]]) {
        kind = nil;
    }

    if (errorCode == kResponseErrorCodeNone && succeeded) {
        return 0;
    }
    if (errorCode == kResponseErrorCodeServerRejected) {
        return kErrorServerRejected;
    }
    if ([kind isEqualToString:kKindAuthorization]) {
        return kErrorAuthorization;
    }
    if ([kind isEqualToString:kKindParameterError]) {
        return kErrorParameterError;
    }
    return kErrorCodeGeneric;
}

/** @ghidraAddress 0x22cc00 */
- (NSDictionary *)getPasteboardWithUdid:(NSString *)udid
                            countryCode:(NSString *)countryCode
                             categoryId:(NSString *)categoryId
                                  error:(NSError *_Nullable *)error {
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithCapacity:3];
    if (udid != nil) {
        [body setValue:udid forKey:kRequestKeyUdid];
    }
    if (countryCode != nil) {
        [body setValue:countryCode forKey:kRequestKeyCountryCode];
    }
    if (categoryId != nil) {
        [body setValue:categoryId forKey:kRequestKeyCategoryId];
    }
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathGet];
    NSError *requestError = nil;
    NSDictionary *response = [ApplilinkWebAPI requestSynchronousWithURL:url
                                                                 method:kHTTPMethodGet
                                                             parameters:body
                                                            cachePolicy:nil
                                                                  error:&requestError];
    if (requestError != nil) {
        if (error != nullptr) {
            *error = requestError;
        }
        return nil;
    }
    if (response == nil) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorRequestFailed
                                                                   userInfo:nil];
        }
        return nil;
    }
    NSInteger errorCode = ErrorCodeForResponse(response);
    if (errorCode != 0) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:errorCode
                                                                   userInfo:response];
        }
        return nil;
    }
    NSString *responseCountryCode = response[kResponseKeyCountryCode];
    NSString *responseCategoryId = response[kResponseKeyCategoryId];
    NSString *responseAdIdFrom = response[kResponseKeyAdIdFrom];
    NSString *responseAdType = response[kResponseKeyAdType];
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithCapacity:4];
    if (responseCountryCode != nil) {
        [record setValue:responseCountryCode forKey:kKeyCountryCode];
    }
    if (responseCategoryId != nil) {
        [record setValue:responseCategoryId forKey:kKeyCategoryId];
    }
    if (responseAdIdFrom != nil) {
        [record setValue:responseAdIdFrom forKey:kKeyAdIdFrom];
    }
    if (responseAdType != nil) {
        [record setValue:responseAdType forKey:kKeyAdType];
    }
    return record;
}

/** @ghidraAddress 0x22d228 */
- (void)setPasteboardWithUdid:(NSString *)udid
                  countryCode:(NSString *)countryCode
                   categoryId:(NSString *)categoryId
                     adIdFrom:(NSString *)adIdFrom
                       adType:(NSString *)adType
                        error:(NSError *_Nullable *)error {
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithCapacity:5];
    if (udid != nil) {
        [body setValue:udid forKey:kRequestKeyUdid];
    }
    if (countryCode != nil) {
        [body setValue:countryCode forKey:kRequestKeyCountryCode];
    }
    if (categoryId != nil) {
        [body setValue:categoryId forKey:kRequestKeyCategoryId];
    }
    if (adIdFrom != nil) {
        [body setValue:adIdFrom forKey:kRequestKeyAdIdFrom];
    }
    if (adType != nil) {
        [body setValue:adType forKey:kRequestKeyAdType];
    }
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathSet];
    NSError *requestError = nil;
    NSDictionary *response = [ApplilinkWebAPI requestSynchronousWithURL:url
                                                                 method:kHTTPMethodPost
                                                             parameters:body
                                                            cachePolicy:nil
                                                                  error:&requestError];
    if (requestError != nil) {
        if (error != nullptr) {
            *error = requestError;
        }
        return;
    }
    if (response == nil) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorRequestFailed
                                                                   userInfo:nil];
        }
        return;
    }
    NSInteger errorCode = ErrorCodeForResponse(response);
    if (errorCode != 0 && error != nullptr) {
        *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:errorCode
                                                               userInfo:response];
    }
}

/** @ghidraAddress 0x22d764 */
- (void)deletePasteboardWithUdid:(NSString *)udid
                     countryCode:(NSString *)countryCode
                      categoryId:(NSString *)categoryId
                           error:(NSError *_Nullable *)error {
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithCapacity:3];
    if (udid != nil) {
        [body setValue:udid forKey:kRequestKeyUdid];
    }
    if (countryCode != nil) {
        [body setValue:countryCode forKey:kRequestKeyCountryCode];
    }
    if (categoryId != nil) {
        [body setValue:categoryId forKey:kRequestKeyCategoryId];
    }
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathDelete];
    NSError *requestError = nil;
    NSDictionary *response = [ApplilinkWebAPI requestSynchronousWithURL:url
                                                                 method:kHTTPMethodPost
                                                             parameters:body
                                                            cachePolicy:nil
                                                                  error:&requestError];
    if (requestError != nil) {
        if (error != nullptr) {
            *error = requestError;
        }
        return;
    }
    if (response == nil) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorRequestFailed
                                                                   userInfo:nil];
        }
        return;
    }
    NSInteger errorCode = ErrorCodeForResponse(response);
    if (errorCode != 0 && error != nullptr) {
        *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:errorCode
                                                               userInfo:response];
    }
}

@end
