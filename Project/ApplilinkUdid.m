#import "ApplilinkUdid.h"

#import <AdSupport/ASIdentifierManager.h>
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>

#import "ApplilinkCore.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkPasteBoard.h"

// The ApplilinkCore accessors this class reads; ApplilinkCore's header is still a stub here. See
// TYPES_PENDING.md.
@interface ApplilinkCore (Udid)
+ (nullable NSString *)ad_udid;
+ (nullable NSString *)udid;
+ (nullable NSString *)old_udid;
+ (nullable NSString *)pasteBoard_udid;
+ (void)setAdUdid:(nullable NSString *)adUdid;
+ (void)clearInitialize;
@end

// The Applilink error codes this class reports. They index into the localised-message table owned
// by ApplilinkNetworkError.
typedef enum {
    kErrorNoData = 0x3f4,             // No stored UDID data.
    kErrorWriteFailed = 0x3f7,        // A pasteboard or keychain write failed.
    kErrorNotDictionary = 0x3f8,      // A keychain record was not a dictionary.
    kErrorIndexOutOfRange = 0x3f9,    // A reward UDID index was out of range.
    kErrorValidateNotDict = 0x3fb,    // Validation: record is not a dictionary.
    kErrorValidateNoAccount = 0x3fc,  // Validation: missing account field.
    kErrorValidateNoCreated = 0x3fd,  // Validation: missing creation-date field.
    kErrorValidateNoModified = 0x3fe, // Validation: missing modification-date field.
    kErrorValidateNoGeneric = 0x3ff,  // Validation: missing generic (count) field.
    kErrorValidateExpired = 0x400,    // Validation: the record's use count is exhausted.
    kErrorDeleteFailed = 0x402,       // A keychain delete failed.
} ApplilinkUdidErrorCode;

// The number of keychain and pasteboard storage slots swept when deleting every UDID.
static const int kStorageIndexCount = 0x100;

// The oldest operating-system version that exposes the advertising-identifier framework.
static const float kAdSupportMinOSVersion = 6.1f;

// The reward-network UDID type selectors.
typedef enum {
    kRewardNetworkTypeOld = 0,
    kRewardNetworkTypeAdvertising = 1,
} ApplilinkUdidRewardNetworkType;

// The isUDIDPriorityType selector, which picks which secondary identifier is sent as old_udid.
typedef enum {
    kPriorityTypeDefault = 0,
    kPriorityTypeOld = 1,
    kPriorityTypePasteBoard = 2,
} ApplilinkUdidPriorityType;

// The keychain account key that records the storage index for the advertising service.
static NSString *const kAdStorageIndexKey = @"adStorageIndex";
// The default storage index used when the keychain holds no account string.
static NSString *const kDefaultStorageIndex = @"0";

// The base service names, combined with the server environment by +getServiceName(Old).
static NSString *const kAdvertisingServiceName = @"ApplilinkAdUdid";
static NSString *const kOldServiceName = @"ApplilinkUdid";

// The NSUserDefaults key holding the server environment name, and the production value.
static NSString *const kEnvKey = @"ApplilinkNetwork.env";
static NSString *const kEnvProduction = @"0";
// The NSUserDefaults key holding the pasteboard reward storage index.
static NSString *const kRewardStorageIndexKey = @"ApplilinkReward.storageIndex";

// Format strings combining a service name with an environment prefix or a storage index.
static NSString *const kEnvServiceFormat = @"%@_%@";
static NSString *const kServiceIndexFormat = @"%@-%@";
static NSString *const kServiceIndexNumberFormat = @"%@-%d";
// The format used to build one hex byte of an MD5 digest.
static NSString *const kHexByteFormat = @"%02x";
// The separator splitting a keychain access group into its bundle-seed identifier prefix.
static NSString *const kAccessGroupSeparator = @".";

// Parameter dictionary keys used when attaching UDIDs to a request.
static NSString *const kParamKeyUdid = @"udid";
static NSString *const kParamKeyOldUdid = @"old_udid";
// The pasteboard record key holding the stored UDID value.
static NSString *const kPasteBoardValueKey = @"Value";

// The name of the serial dispatch queue backing the singleton and pasteboard.
static NSString *const kQueueName = @"ApplilinkUdid";

// The all-zero advertising identifier returned when tracking is disabled; its MD5 hash is skipped.
static NSString *const kNullAdvertisingIdentifier = @"00000000-0000-0000-0000-000000000000";

// The bundle-seed keychain lookup account.
static NSString *const kBundleSeedAccount = @"bundleSeedID";

// Only these two names are resolved at runtime, by +getAdUdid: each is shifted forward by one
// character, and decoding subtracts one from every byte to recover "ASIdentifierManager" and
// "advertisingIdentifier". The sharedManager, UUIDString, and isAdvertisingTrackingEnabled
// selectors are all sent directly.
static NSString *const kEncodedIdentifierManagerClass = @"BTJefoujgjfsNbobhfs";
static NSString *const kEncodedAdvertisingIdentifierSelector = @"bewfsujtjohJefoujgjfs";

// Decodes a Caesar-shifted name by subtracting one from each byte.
static NSString *DecodeShiftedName(NSString *encoded) {
    const char *bytes = [encoded cStringUsingEncoding:NSASCIIStringEncoding];
    NSMutableData *decoded = [NSMutableData dataWithLength:strlen(bytes)];
    char *out = (char *)decoded.mutableBytes;
    for (size_t i = 0; bytes[i] != '\0'; ++i) {
        out[i] = (char)(bytes[i] - 1);
    }
    return [NSString stringWithCString:out encoding:NSASCIIStringEncoding];
}

// The singleton and its serial queue live in one block of globals that +allocWithZone: and
// +sharedInstance share; they cannot be method-local statics because a single slot is read and
// written from both methods and from -init.
static ApplilinkUdid *g_pApplilinkUdidShared = nil;
static dispatch_queue_t g_pApplilinkUdidQueue = nil;

@implementation ApplilinkUdid

@synthesize pasteBoard = _pasteBoard;

#pragma mark - Lifecycle

/** @ghidraAddress 0x25d99c */
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x25da14 */
      // The shared serial queue is created here, before the singleton, and -init only reads it.
      g_pApplilinkUdidQueue = dispatch_queue_create(kQueueName.UTF8String, nullptr);
      if (g_pApplilinkUdidShared == nil) {
          g_pApplilinkUdidShared = [super allocWithZone:zone];
      }
    });
    return g_pApplilinkUdidShared;
}

/** @ghidraAddress 0x25da9c */
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x25dae4 */
      g_pApplilinkUdidShared = [[ApplilinkUdid alloc] init];
      g_pApplilinkUdidShared.pasteBoard = [[ApplilinkPasteBoard alloc] init];
    });
    return g_pApplilinkUdidShared;
}

/** @ghidraAddress 0x25d7cc */
- (instancetype)init {
    // The binary runs [super init] synchronously on the queue +allocWithZone: already created.
    __block ApplilinkUdid *initialized = nil;
    dispatch_sync(g_pApplilinkUdidQueue, ^{
      /** @ghidraAddress 0x25d8dc */
      initialized = [super init];
    });
    return initialized;
}

#pragma mark - UDID pasteboard storage

/** @ghidraAddress 0x25db84 */
+ (NSDictionary *)writeUDIDForFirstEmptyLocationWithError:(NSError **)error {
    ApplilinkUdid *shared = [ApplilinkUdid sharedInstance];
    NSDictionary *storageData = shared.pasteBoard.storageData;
    NSString *udid = storageData[kPasteBoardValueKey];
    if (udid == nil) {
        // No stored value: mint a fresh UUID.
        CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
        udid = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
        CFRelease(uuid);
    }
    NSError *writeError = nil;
    NSDictionary *written = [shared.pasteBoard writeStorageData:udid error:&writeError];
    if (written == nil) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorWriteFailed];
        }
    } else {
        shared.pasteBoard.nonPasteBoardUdidFlag = NO;
    }
    return written;
}

/** @ghidraAddress 0x25dd6c */
+ (NSDictionary *)writeUDIDForFirstEmptyLocationWithUdid:(NSString *)udid {
    ApplilinkUdid *shared = [ApplilinkUdid sharedInstance];
    NSError *writeError = nil;
    NSDictionary *written = [shared.pasteBoard writeStorageData:udid error:&writeError];
    if (written != nil) {
        [ApplilinkUdid sharedInstance].pasteBoard.nonPasteBoardUdidFlag = NO;
    }
    return written;
}

/** @ghidraAddress 0x25de98 */
+ (NSDictionary *)writeUDIDWithUdid:(NSString *)udid {
    ApplilinkUdid *shared = [ApplilinkUdid sharedInstance];
    NSString *serviceName = [ApplilinkUdid getServiceName];
    NSError *readError = nil;
    NSDictionary *existing = [shared.pasteBoard storageDataWithServiceName:serviceName
                                                              storageIndex:0
                                                                     error:&readError];
    if (existing != nil) {
        [shared.pasteBoard deleteWithStorageIndex:0 error:&readError];
    }
    NSDictionary *written = [shared.pasteBoard writeStorageData:udid
                                                   storageIndex:0
                                                          error:&readError];
    if (written != nil) {
        [ApplilinkUdid sharedInstance].pasteBoard.nonPasteBoardUdidFlag = NO;
    }
    return written;
}

/** @ghidraAddress 0x25e0c0 */
+ (NSDictionary *)udidWithServiceName:(NSString *)serviceName
                         storageIndex:(int)storageIndex
                                error:(NSError **)error {
    ApplilinkUdid *shared = [ApplilinkUdid sharedInstance];
    NSError *readError = nil;
    NSDictionary *data = [shared.pasteBoard storageDataWithServiceName:serviceName
                                                          storageIndex:storageIndex
                                                                 error:&readError];
    if (data == nil && error != nullptr) {
        *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorNoData];
    }
    return data;
}

/** @ghidraAddress 0x25e1e4 */
+ (NSDictionary *)udidForFirstInvalidDataWithError:(NSError **)error {
    NSDictionary *data = [ApplilinkUdid sharedInstance].pasteBoard.storageData;
    if (data == nil && error != nullptr) {
        *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorNoData];
    }
    return data;
}

/** @ghidraAddress 0x25e2b0 */
+ (NSDictionary *)udidOldForFirstInvalidDataWithError:(NSError **)error {
    NSDictionary *data = [ApplilinkUdid sharedInstance].pasteBoard.storageDataOld;
    if (data == nil && error != nullptr) {
        *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorNoData];
    }
    return data;
}

/** @ghidraAddress 0x25e37c */
+ (BOOL)deleteUDIDWithServiceName:(NSString *)serviceName
                     storageIndex:(int)storageIndex
                            error:(NSError **)error {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:kEnvKey];
    if (env != nil && ![env isEqualToString:kEnvProduction]) {
        NSError *deleteError = nil;
        [[ApplilinkUdid sharedInstance].pasteBoard deleteWithStorageIndex:storageIndex
                                                                    error:&deleteError];
        if (deleteError != nil) {
            *error = deleteError;
            return NO;
        }
    }
    return YES;
}

/** @ghidraAddress 0x25e4cc */
+ (void)deleteAllUDID {
    ApplilinkPasteBoard *pasteBoard = [[ApplilinkPasteBoard alloc] init];
    NSString *serviceName = [pasteBoard getServiceName];
    for (int index = 0; index < kStorageIndexCount; ++index) {
        NSError *readError = nil;
        NSDictionary *data = [ApplilinkUdid udidWithServiceName:serviceName
                                                   storageIndex:index
                                                          error:&readError];
        if (data != nil && readError == nil) {
            NSError *deleteError = nil;
            [ApplilinkUdid deleteUDIDWithServiceName:serviceName
                                        storageIndex:index
                                               error:&deleteError];
        }
    }
    NSString *oldServiceName = [pasteBoard getServiceNameOld];
    for (int index = 0; index < kStorageIndexCount; ++index) {
        NSError *readError = nil;
        NSDictionary *data = [ApplilinkUdid udidWithServiceName:oldServiceName
                                                   storageIndex:index
                                                          error:&readError];
        if (data != nil && readError == nil) {
            NSError *deleteError = nil;
            [ApplilinkUdid deleteUDIDWithServiceName:oldServiceName
                                        storageIndex:index
                                               error:&deleteError];
        }
    }
}

#pragma mark - Advertising reward UDID

/** @ghidraAddress 0x25e6d0 */
+ (NSString *)getAdvertisingRewardUdidWithError:(NSError **)error {
    if (![ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        return nil;
    }
    NSString *serviceName = [ApplilinkUdid getServiceName];
    NSString *storageIndex = [ApplilinkUdid getServiceIndex:kAdStorageIndexKey];
    NSError *readError = nil;
    NSString *record = [ApplilinkUdid getUdidWithService:serviceName
                                            storageIndex:storageIndex
                                   rewardNetworkUDIDType:kRewardNetworkTypeAdvertising
                                                   error:&readError];
    if (readError != nil || record == nil) {
        *error = readError;
        return [ApplilinkUdid getAdvertisingUdid];
    }
    return record;
}

/** @ghidraAddress 0x25e804 */
+ (NSString *)createAdvertisingRewardUdidWithError:(NSError **)error {
    if (![ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        return nil;
    }
    NSString *serviceName = [ApplilinkUdid getServiceName];
    NSString *storageIndex = [ApplilinkUdid getServiceIndex:kAdStorageIndexKey];
    NSError *readError = nil;
    NSString *storedUdid = [ApplilinkUdid getUdidWithService:serviceName
                                                storageIndex:storageIndex
                                       rewardNetworkUDIDType:kRewardNetworkTypeAdvertising
                                                       error:&readError];
    NSString *newUdid = [ApplilinkUdid getAdvertisingUdid];
    if (storedUdid == nil) {
        NSError *setError = readError;
        [ApplilinkUdid setNewUdid:newUdid error:&setError];
        if (setError != nil) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorWriteFailed];
        }
        [ApplilinkCore clearInitialize];
        return newUdid;
    }
    if (![storedUdid isEqualToString:newUdid]) {
        NSError *oldError = readError;
        [ApplilinkUdid setOldUdid:storedUdid error:&oldError];
        NSError *newError = oldError;
        [ApplilinkUdid setNewUdid:newUdid error:&newError];
        [ApplilinkCore clearInitialize];
        *error = nil;
        return newUdid;
    }
    return storedUdid;
}

/** @ghidraAddress 0x25ea80 */
+ (BOOL)deleteAdvertisingRewardUdidIndex:(int)index error:(NSError **)error {
    // The bound test is unsigned in the binary, so a negative index is out of range, not below it.
    if ((unsigned int)index >= (unsigned int)kStorageIndexCount) {
        if (error == nullptr) {
            return NO;
        }
        *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorIndexOutOfRange];
        return NO;
    }
    NSString *serviceKey = [NSString
        stringWithFormat:kServiceIndexNumberFormat, [ApplilinkUdid getServiceName], index];
    NSError *deleteError = nil;
    [ApplilinkUdid deleteKeyChainService:serviceKey error:&deleteError];
    if (deleteError == nil) {
        return YES;
    }
    if (error == nullptr) {
        return NO;
    }
    *error = deleteError;
    return NO;
}

/** @ghidraAddress 0x25ebb8 */
+ (void)deleteAllAdvertisingUDID {
    for (int index = 0; index < kStorageIndexCount; ++index) {
        NSError *deleteError = nil;
        [ApplilinkUdid deleteAdvertisingRewardUdidIndex:index error:&deleteError];
    }
}

#pragma mark - Old and new UDID

/** @ghidraAddress 0x25ec18 */
+ (BOOL)setOldUdid:(NSString *)oldUdid error:(NSError **)error {
    NSString *serviceKey = [NSString stringWithFormat:kServiceIndexFormat,
                                                      [ApplilinkUdid getServiceNameOld],
                                                      kDefaultStorageIndex];
    return [ApplilinkUdid setUdidWithService:serviceKey withUDID:oldUdid];
}

/** @ghidraAddress 0x25ecec */
+ (NSString *)getOldUdidWithError:(NSError **)error {
    NSString *serviceName = [ApplilinkUdid getServiceNameOld];
    return [ApplilinkUdid getUdidWithService:serviceName
                                storageIndex:kDefaultStorageIndex
                       rewardNetworkUDIDType:kRewardNetworkTypeOld
                                       error:error];
}

/** @ghidraAddress 0x25ed68 */
+ (BOOL)deleteOldUdidWithError:(NSError **)error {
    NSString *serviceKey = [NSString stringWithFormat:kServiceIndexFormat,
                                                      [ApplilinkUdid getServiceNameOld],
                                                      kDefaultStorageIndex];
    NSError *deleteError = nil;
    [ApplilinkUdid deleteKeyChainService:serviceKey error:&deleteError];
    if (deleteError == nil) {
        return YES;
    }
    if (error == nullptr) {
        return NO;
    }
    *error = deleteError;
    return NO;
}

/** @ghidraAddress 0x25ee5c */
+ (BOOL)setNewUdid:(NSString *)newUdid error:(NSError **)error {
    NSString *storageIndex = [ApplilinkUdid getServiceIndex:kAdStorageIndexKey];
    NSString *serviceName = [ApplilinkUdid getServiceName];
    if (storageIndex == nil || storageIndex.length == 0) {
        storageIndex = kDefaultStorageIndex;
    }
    NSString *serviceKey =
        [NSString stringWithFormat:kServiceIndexFormat, serviceName, storageIndex];
    [ApplilinkCore setAdUdid:newUdid];
    BOOL stored = [ApplilinkUdid setUdidWithService:serviceKey withUDID:newUdid];
    if (stored) {
        [ApplilinkUdid setService:kAdStorageIndexKey withStorageIndex:storageIndex];
    }
    return stored;
}

#pragma mark - Keychain access

/** @ghidraAddress 0x25efdc */
+ (BOOL)setUdidWithService:(NSString *)service withUDID:(NSString *)udid {
    NSDate *now = [NSDate date];
    // Spelled out because the binary boxes this with -numberWithInteger:, which @1 cannot express.
    NSNumber *initialUseCount = [NSNumber numberWithInteger:1];
    if (udid == nil) {
        return NO;
    }
    if ([ApplilinkUdid searchWithService:service] != nil) {
        // Replace any stale record before adding the new one.
        NSError *deleteError = nil;
        [ApplilinkUdid deleteKeyChainService:service error:&deleteError];
    }
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : udid,
        (__bridge id)kSecAttrService : service,
        (__bridge id)kSecAttrCreationDate : now,
        (__bridge id)kSecAttrModificationDate : now,
        (__bridge id)kSecAttrGeneric : initialUseCount,
    };
    SecItemAdd((__bridge CFDictionaryRef)query, nullptr);
    return YES;
}

/** @ghidraAddress 0x25f200 */
+ (NSString *)getUdidWithService:(NSString *)service
                    storageIndex:(NSString *)storageIndex
           rewardNetworkUDIDType:(int)rewardNetworkUDIDType
                           error:(NSError **)error {
    // This date is read once here and reused below as the record's new modification date.
    NSDate *now = [NSDate date];
    if (storageIndex == nil || storageIndex.length == 0) {
        storageIndex = kDefaultStorageIndex;
    }
    NSString *serviceKey = [NSString stringWithFormat:kServiceIndexFormat, service, storageIndex];
    NSDictionary *record = [ApplilinkUdid searchWithService:serviceKey];
    if (record == nil) {
        return nil;
    }
    NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary:record];
    NSError *validateError = nil;
    if (![ApplilinkUdid validate:record error:&validateError]) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorNotDictionary];
        }
        return nil;
    }
    NSString *account = attributes[(__bridge id)kSecAttrAccount];
    if (![account isKindOfClass:[NSString class]]) {
        account = nil;
    }
    NSDictionary *matchQuery = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService : serviceKey,
    };
    NSDictionary *update = @{
        (__bridge id)kSecAttrModificationDate : now,
    };
    CFTypeRef match = nullptr;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)matchQuery, &match);
    if (status == errSecSuccess) {
        SecItemUpdate((__bridge CFDictionaryRef)matchQuery, (__bridge CFDictionaryRef)update);
    }
    // The attribute dictionary is only a staging area; the account string is what is returned.
    return account;
}

/** @ghidraAddress 0x25f5a8 */
+ (NSDictionary *)searchWithService:(NSString *)service {
    if (service == nil) {
        return nil;
    }
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        // The binary really does key this pair on kSecMatchLimitOne with kSecMatchLimit as the
        // value. SecItemCopyMatching ignores the unknown key and defaults the limit to one, so the
        // transposition is invisible at runtime.
        (__bridge id)kSecMatchLimitOne : (__bridge id)kSecMatchLimit,
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecAttrService : service,
    };
    CFTypeRef result = nullptr;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess) {
        return nil;
    }
    return (__bridge_transfer NSDictionary *)result;
}

/** @ghidraAddress 0x25f6e4 */
+ (BOOL)deleteKeyChainService:(NSString *)service error:(NSError **)error {
    if ([ApplilinkUdid searchWithService:service] != nil) {
        NSDictionary *query = @{
            (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
            (__bridge id)kSecAttrService : service,
        };
        OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
        if (status != errSecSuccess) {
            if (error != nullptr) {
                *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorDeleteFailed];
            }
            return NO;
        }
    }
    return YES;
}

/** @ghidraAddress 0x25f850 */
+ (BOOL)validate:(NSDictionary *)attributes error:(NSError **)error {
    if (![attributes isKindOfClass:[NSDictionary class]]) {
        if (error == nullptr) {
            return NO;
        }
        *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorValidateNotDict];
        return NO;
    }
    if (attributes[(__bridge id)kSecAttrAccount] == nil) {
        if (error == nullptr) {
            return NO;
        }
        *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorValidateNoAccount];
        return NO;
    }
    if (attributes[(__bridge id)kSecAttrCreationDate] == nil) {
        if (error == nullptr) {
            return NO;
        }
        *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorValidateNoCreated];
        return NO;
    }
    if (attributes[(__bridge id)kSecAttrModificationDate] == nil) {
        if (error == nullptr) {
            return NO;
        }
        *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorValidateNoModified];
        return NO;
    }
    NSNumber *useCount = attributes[(__bridge id)kSecAttrGeneric];
    if (useCount == nil) {
        if (error == nullptr) {
            return NO;
        }
        *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorValidateNoGeneric];
        return NO;
    }
    if (useCount.intValue > 0) {
        return YES;
    }
    if (error == nullptr) {
        return NO;
    }
    *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorValidateExpired];
    return NO;
}

/** @ghidraAddress 0x25fb34 */
+ (NSString *)getServiceIndex:(NSString *)service {
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        // Transposed in the binary, exactly as in +searchWithService:.
        (__bridge id)kSecMatchLimitOne : (__bridge id)kSecMatchLimit,
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecAttrService : service,
    };
    CFTypeRef result = nullptr;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess) {
        return kDefaultStorageIndex;
    }
    NSDictionary *attributes = (__bridge_transfer NSDictionary *)result;
    NSString *account = attributes[(__bridge id)kSecAttrAccount];
    if (![account isKindOfClass:[NSString class]]) {
        return kDefaultStorageIndex;
    }
    return account;
}

/** @ghidraAddress 0x25fcfc */
+ (void)setService:(NSString *)service withStorageIndex:(NSString *)storageIndex {
    NSError *deleteError = nil;
    [ApplilinkUdid deleteKeyChainService:service error:&deleteError];
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : storageIndex,
        (__bridge id)kSecAttrService : service,
    };
    SecItemAdd((__bridge CFDictionaryRef)query, nullptr);
}

#pragma mark - Advertising identifier

/** @ghidraAddress 0x25fe58 */
+ (NSString *)getCFUUID {
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidString =
        (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    CFRelease(uuid);
    return uuidString;
}

/** @ghidraAddress 0x25fea4 */
+ (NSString *)getAdvertisingUdid {
    if (![ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        return nil;
    }
    NSString *adUdid = [ApplilinkUdid getAdUdid];
    if ([adUdid isEqualToString:kNullAdvertisingIdentifier]) {
        return nil;
    }
    return [ApplilinkUdid md5WithString:adUdid];
}

/** @ghidraAddress 0x25ff58 */
+ (BOOL)isAdvertisingTrackingEnabled {
    if (![ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        return YES;
    }
    // Unlike +getAdUdid, this one messages ASIdentifierManager directly through its class
    // reference; it does not go through the encoded names.
    return ASIdentifierManager.sharedManager.isAdvertisingTrackingEnabled;
}

/** @ghidraAddress 0x25ffd8 */
+ (BOOL)isAdvertisingTrackingOSVersion {
    return [UIDevice currentDevice].systemVersion.floatValue >= kAdSupportMinOSVersion;
}

/** @ghidraAddress 0x26006c */
+ (NSString *)md5WithString:(NSString *)string {
    if (string == nil) {
        return nil;
    }
    const char *data = string.UTF8String;
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data, (CC_LONG)strlen(data), digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:0x20];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; ++i) {
        [hex appendFormat:kHexByteFormat, digest[i]];
    }
    return hex;
}

#pragma mark - UDID parameters and state

/** @ghidraAddress 0x260180 */
+ (BOOL)setUdidParameters:(id)udidParameters isUDIDPriorityType:(int)isUDIDPriorityType {
    NSString *adUdid = [ApplilinkCore ad_udid];
    NSString *udid = [ApplilinkCore udid];
    NSString *oldUdid = [ApplilinkCore old_udid];
    NSString *pasteBoardUdid = [ApplilinkCore pasteBoard_udid];
    if (adUdid == nil && udid == nil && oldUdid == nil) {
        [ApplilinkCore clearInitialize];
        return NO;
    }
    if ([ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        // Advertising tracking is available: prefer the advertising UDID.
        if (adUdid == nil) {
            [ApplilinkCore clearInitialize];
            return NO;
        }
        [udidParameters setValue:adUdid forKey:kParamKeyUdid];
        NSString *secondaryUdid;
        if (isUDIDPriorityType == kPriorityTypeDefault) {
            secondaryUdid = (udid == nil || [adUdid isEqualToString:udid]) ? oldUdid : udid;
        } else if (isUDIDPriorityType == kPriorityTypeOld) {
            secondaryUdid = oldUdid;
        } else if (isUDIDPriorityType == kPriorityTypePasteBoard && udid != nil &&
                   ![udid isEqualToString:pasteBoardUdid]) {
            secondaryUdid = pasteBoardUdid;
        } else {
            secondaryUdid = nil;
        }
        if (![adUdid isEqualToString:secondaryUdid]) {
            [udidParameters setValue:secondaryUdid forKey:kParamKeyOldUdid];
        }
        return YES;
    }
    // Advertising tracking is unavailable: fall back to the current UDID.
    if (udid == nil) {
        if (oldUdid != nil) {
            [udidParameters setValue:oldUdid forKey:kParamKeyUdid];
        } else {
            return NO;
        }
    } else {
        [udidParameters setValue:udid forKey:kParamKeyUdid];
        if (oldUdid != nil && ![oldUdid isEqualToString:udid]) {
            [udidParameters setValue:oldUdid forKey:kParamKeyOldUdid];
        }
    }
    if (isUDIDPriorityType == kPriorityTypePasteBoard && udid != nil &&
        ![udid isEqualToString:pasteBoardUdid]) {
        [udidParameters setValue:pasteBoardUdid forKey:kParamKeyOldUdid];
    }
    return YES;
}

/** @ghidraAddress 0x260474 */
+ (BOOL)setUdidParameters:(id)udidParameters {
    NSString *adUdid = [ApplilinkCore ad_udid];
    NSString *udid = [ApplilinkCore udid];
    NSString *oldUdid = [ApplilinkCore old_udid];
    if (adUdid == nil && udid == nil && oldUdid == nil) {
        return NO;
    }
    NSString *primaryUdid;
    if ([ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        primaryUdid = adUdid;
    } else {
        primaryUdid = (udid == nil) ? oldUdid : udid;
    }
    if (primaryUdid == nil) {
        return NO;
    }
    [udidParameters setValue:primaryUdid forKey:kParamKeyUdid];
    return YES;
}

/** @ghidraAddress 0x2605d4 */
+ (BOOL)isUdidThreeKinds {
    NSString *adUdid = [ApplilinkCore ad_udid];
    NSString *udid = [ApplilinkCore udid];
    NSString *oldUdid = [ApplilinkCore old_udid];
    if (adUdid == nil || udid == nil || oldUdid == nil) {
        return NO;
    }
    if ([adUdid isEqualToString:udid]) {
        return NO;
    }
    if ([oldUdid isEqualToString:udid]) {
        return NO;
    }
    return ![adUdid isEqualToString:oldUdid];
}

/** @ghidraAddress 0x2606d4 */
+ (BOOL)isUdidSDKPasteBoard {
    NSString *udid = [ApplilinkCore udid];
    NSString *pasteBoardUdid = [ApplilinkCore pasteBoard_udid];
    if (udid == nil || pasteBoardUdid == nil) {
        return NO;
    }
    return ![udid isEqualToString:pasteBoardUdid];
}

/** @ghidraAddress 0x26077c */
+ (NSString *)getServiceName {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:kEnvKey];
    if ([env isEqualToString:kEnvProduction]) {
        return kAdvertisingServiceName;
    }
    return [NSString stringWithFormat:kEnvServiceFormat, env, kAdvertisingServiceName];
}

/** @ghidraAddress 0x260864 */
+ (NSString *)getServiceNameOld {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:kEnvKey];
    if ([env isEqualToString:kEnvProduction]) {
        return kOldServiceName;
    }
    return [NSString stringWithFormat:kEnvServiceFormat, env, kOldServiceName];
}

/** @ghidraAddress 0x26094c */
+ (void)setUdidKeychainFromPasteBoard {
    NSString *storedIndex =
        [[NSUserDefaults standardUserDefaults] stringForKey:kRewardStorageIndexKey];
    NSString *serviceName = [ApplilinkUdid getServiceName];
    if (storedIndex != nil) {
        NSDictionary *record = [ApplilinkUdid udidWithServiceName:serviceName
                                                     storageIndex:storedIndex.intValue
                                                            error:nullptr];
        if (record != nil) {
            [ApplilinkUdid setOldUdid:record[kPasteBoardValueKey] error:nullptr];
            return;
        }
    }
    NSString *oldServiceName = [ApplilinkUdid getServiceNameOld];
    if (storedIndex != nil) {
        NSDictionary *record = [ApplilinkUdid udidWithServiceName:oldServiceName
                                                     storageIndex:storedIndex.intValue
                                                            error:nullptr];
        if (record != nil) {
            [ApplilinkUdid setOldUdid:record[kPasteBoardValueKey] error:nullptr];
        }
    }
}

/** @ghidraAddress 0x260b6c */
+ (BOOL)isPasteBoardStatus {
    return [ApplilinkUdid sharedInstance].pasteBoard.nonPasteBoardUdidFlag;
}

/** @ghidraAddress 0x260bf4 */
+ (NSString *)getAdUdid {
    NSString *className = DecodeShiftedName(kEncodedIdentifierManagerClass);
    Class identifierManagerClass = NSClassFromString(className);
    NSString *selectorName = DecodeShiftedName(kEncodedAdvertisingIdentifierSelector);
    SEL advertisingIdentifierSelector = NSSelectorFromString(selectorName);
    id identifierManager = [identifierManagerClass performSelector:@selector(sharedManager)];
    NSUUID *advertisingIdentifier =
        [identifierManager performSelector:advertisingIdentifierSelector];
    if (advertisingIdentifier == nil) {
        return nil;
    }
    // Only the class and the advertisingIdentifier selector are resolved by name; -UUIDString is
    // sent directly.
    return advertisingIdentifier.UUIDString;
}

/** @ghidraAddress 0x260db0 */
- (NSString *)bundleSeedID {
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : kBundleSeedAccount,
        (__bridge id)kSecAttrService : @"",
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
    };
    CFTypeRef result = nullptr;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecItemNotFound) {
        status = SecItemAdd((__bridge CFDictionaryRef)query, &result);
    }
    if (status != errSecSuccess) {
        return nil;
    }
    NSDictionary *attributes = (__bridge_transfer NSDictionary *)result;
    NSString *accessGroup = attributes[(__bridge id)kSecAttrAccessGroup];
    return [[accessGroup componentsSeparatedByString:kAccessGroupSeparator] objectEnumerator]
        .nextObject;
}

/** @ghidraAddress 0x260f58 */
+ (void)debugLog {
    NSString *env = [[NSUserDefaults standardUserDefaults] objectForKey:kEnvKey];
    if (env == nil) {
        return;
    }
    // The binary reads the singleton slot directly rather than going through +sharedInstance, so
    // this is a no-op when the singleton has not been created yet.
    [g_pApplilinkUdidShared.pasteBoard debugLog];
    (void)[ApplilinkCore ad_udid]; // Yes, the binary evaluates and discards these accessors.
    (void)[ApplilinkCore udid];
    (void)[ApplilinkCore old_udid];
}

@end
