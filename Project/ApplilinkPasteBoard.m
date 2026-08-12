#import "ApplilinkPasteBoard.h"

#import <UIKit/UIKit.h>

#import "ApplilinkConsts.h"
#import "ApplilinkNetworkError.h"
#import "Crypto.h"

// The envServer accessor ApplilinkConsts vends; not yet declared in its header. See
// TYPES_PENDING.md.
@interface ApplilinkConsts (EnvServer)
+ (NSString *)envServer;
@end

// The pasteboard type under which every record archive is stored.
static NSString *const kPasteboardType = @"applilink.udid";

// The base service name appended to the server environment to form a service name, and the format
// that combines them.
static NSString *const kServiceName = @"ApplilinkUdid";
static NSString *const kServiceNameFormat = @"%@_%@";

// The format that turns a service name and a slot index into a named pasteboard.
static NSString *const kPasteboardNameFormat = @"%@-%d";

// The value used to disable pasteboard creation (a read) or enable it (a write).
static NSString *const kEnvDisabled = @"0";

// Record dictionary keys.
static NSString *const kValueKey = @"Value";
static NSString *const kEntryDateKey = @"EntryDate";
static NSString *const kLastAccessKey = @"LastAccess";
static NSString *const kVersionKey = @"Version";
static NSString *const kStorageIndexKey = @"StorageIndex";

// The number of pasteboard slots probed for each service name.
static const int kStorageSlotCount = 0x100;

// The schema version written into every record.
static const NSInteger kRecordVersion = 1;

// The cipher mode passed to Crypto: 0 enciphers, 1 deciphers.
enum {
    kCipherEncrypt = 0,
    kCipherDecrypt = 1,
};

// Localised error codes raised through ApplilinkNetworkError.
enum {
    kErrorInvalidField = 1013,      // A pasteboard slot could not be opened.
    kErrorWriteFailed = 1015,       // Every slot write failed.
    kErrorValidateError = 1016,     // A decoded record failed validation.
    kErrorInvalidKey = 1017,        // The storage index exceeded the slot count.
    kErrorInvalidDataType = 1018,   // A slot held no value for the record type.
    kErrorInvalidFormat = 1019,     // The record was not a dictionary.
    kErrorInvalidValue = 1020,      // The record was missing its value.
    kErrorInvalidEntryDate = 1021,  // The record was missing its entry date.
    kErrorInvalidLastAccess = 1022, // The record was missing its last access.
    kErrorInvalidVersion = 1023,    // The record was missing its version.
    kErrorOldVersion = 1024,        // The record's version was not positive.
};

@implementation ApplilinkPasteBoard

@synthesize nonPasteBoardUdidFlag = _nonPasteBoardUdidFlag;

#pragma mark - Lifecycle

/** @ghidraAddress 0x266fd0 */
- (instancetype)init {
    return [super init];
}

/** @ghidraAddress 0x268874 */
- (void)dealloc {
    // [super dealloc] is compiler-emitted (ARC).
}

#pragma mark - Validation

/** @ghidraAddress 0x267ff4 */
+ (BOOL)validate:(NSDictionary *)dict error:(NSError **)error {
    if (![dict isKindOfClass:[NSDictionary class]]) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorInvalidFormat];
        }
        return NO;
    }
    if (dict[kValueKey] == nil) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorInvalidValue];
        }
        return NO;
    }
    if (dict[kEntryDateKey] == nil) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorInvalidEntryDate];
        }
        return NO;
    }
    if (dict[kLastAccessKey] == nil) {
        if (error != nullptr) {
            *error =
                [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorInvalidLastAccess];
        }
        return NO;
    }
    if (dict[kVersionKey] == nil) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorInvalidVersion];
        }
        return NO;
    }
    if ([dict[kVersionKey] intValue] <= 0) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorOldVersion];
        }
        return NO;
    }
    return YES;
}

#pragma mark - Reading

/** @ghidraAddress 0x26700c */
- (NSDictionary *)storageData {
    NSString *serviceName = [self getServiceName];
    for (int storageIndex = 0; storageIndex < kStorageSlotCount; ++storageIndex) {
        NSString *name =
            [NSString stringWithFormat:kPasteboardNameFormat, serviceName, storageIndex];
        if ([UIPasteboard pasteboardWithName:name create:NO] != nil) {
            NSError *readError = nil;
            NSDictionary *record = [self storageDataWithServiceName:serviceName
                                                       storageIndex:storageIndex
                                                              error:&readError];
            if (readError == nil && record != nil) {
                self.nonPasteBoardUdidFlag = NO;
                return record;
            }
        }
    }
    self.nonPasteBoardUdidFlag = YES;
    return [self storageDataOld];
}

/** @ghidraAddress 0x267208 */
- (NSDictionary *)storageDataOld {
    NSString *serviceName = [self getServiceNameOld];
    for (int storageIndex = 0; storageIndex < kStorageSlotCount; ++storageIndex) {
        NSString *name =
            [NSString stringWithFormat:kPasteboardNameFormat, serviceName, storageIndex];
        if ([UIPasteboard pasteboardWithName:name create:NO] != nil) {
            NSError *readError = nil;
            NSDictionary *record = [self storageDataWithServiceName:serviceName
                                                       storageIndex:storageIndex
                                                              error:&readError];
            if (readError == nil && record != nil) {
                return record;
            }
        }
    }
    return nil;
}

/** @ghidraAddress 0x2673a4 */
- (NSDictionary *)storageDataWithServiceName:(NSString *)serviceName
                                storageIndex:(int)storageIndex
                                       error:(NSError **)error {
    if (storageIndex >= kStorageSlotCount) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorInvalidKey];
        }
        return nil;
    }
    NSString *name = [NSString stringWithFormat:kPasteboardNameFormat, serviceName, storageIndex];
    UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:name create:NO];
    if (pasteboard == nil) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorInvalidField];
        }
        return nil;
    }
    NSData *archive = [pasteboard valueForPasteboardType:kPasteboardType];
    if (archive == nil) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorInvalidDataType];
        }
        return nil;
    }
    NSDictionary *record = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
    NSError *validateError = nil;
    if (![ApplilinkPasteBoard validate:record error:&validateError]) {
        // The stored record is invalid: clear the slot and report the failure. The binary passes a
        // nil data to clear the slot; a typed nil sidesteps the framework's nonnull annotation.
        NSData *emptyData = nil;
        [pasteboard setData:emptyData forPasteboardType:kPasteboardType];
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorValidateError];
        }
        return nil;
    }
    NSMutableDictionary *refreshed = [NSMutableDictionary dictionaryWithDictionary:record];
    NSDate *now = [NSDate date];
    if (now != nil) {
        refreshed[kLastAccessKey] = now;
    }
    NSData *rewritten = [NSKeyedArchiver archivedDataWithRootObject:refreshed];
    [pasteboard setData:rewritten forPasteboardType:kPasteboardType];
    return [self convertToData:record serviceName:serviceName storageIndex:storageIndex];
}

#pragma mark - Writing

/** @ghidraAddress 0x2677d0 */
- (NSDictionary *)writeStorageData:(NSString *)udid error:(NSError **)error {
    NSString *serviceName = [self getServiceName];
    NSError *writeError = nil;
    NSError *deleteError = nil;
    for (int storageIndex = 0; storageIndex < kStorageSlotCount; ++storageIndex) {
        NSString *name =
            [NSString stringWithFormat:kPasteboardNameFormat, serviceName, storageIndex];
        if ([UIPasteboard pasteboardWithName:name create:NO] == nil) {
            NSDictionary *record = [self writeStorageData:udid
                                             storageIndex:storageIndex
                                                    error:&writeError];
            if (record != nil) {
                return record;
            }
            [self deleteWithStorageIndex:storageIndex error:&deleteError];
        }
    }
    if (writeError != nil || deleteError != nil) {
        // The binary writes through the error pointer here without a nullptr check.
        *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorWriteFailed];
    }
    return nil;
}

/** @ghidraAddress 0x267a20 */
- (NSDictionary *)writeStorageData:(NSString *)udid
                      storageIndex:(int)storageIndex
                             error:(NSError **)error {
    if (storageIndex >= kStorageSlotCount) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorInvalidKey];
        }
        return nil;
    }
    NSString *serviceName = [self getServiceName];
    NSString *name = [NSString stringWithFormat:kPasteboardNameFormat, serviceName, storageIndex];
    NSData *keySeed = [name dataUsingEncoding:NSUTF8StringEncoding];
    NSData *key = [Crypto createHash:keySeed];
    NSData *plaintext = [udid dataUsingEncoding:NSUTF8StringEncoding];
    NSData *encryptedValue = [Crypto cryptorToData:kCipherEncrypt value:plaintext key:key];
    NSDate *now = [NSDate date];
    NSDictionary *record = [NSDictionary dictionaryWithObjectsAndKeys:encryptedValue,
                                                                      kValueKey,
                                                                      now,
                                                                      kEntryDateKey,
                                                                      now,
                                                                      kLastAccessKey,
                                                                      @(kRecordVersion),
                                                                      kVersionKey,
                                                                      nil];
    UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:name create:YES];
    if (pasteboard == nil) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorInvalidField];
        }
        return nil;
    }
    pasteboard.persistent = YES;
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:record];
    [pasteboard setData:archive forPasteboardType:kPasteboardType];
    return [self convertToData:record serviceName:serviceName storageIndex:storageIndex];
}

/** @ghidraAddress 0x267dec */
- (BOOL)deleteWithStorageIndex:(int)storageIndex error:(NSError **)error {
    if (storageIndex >= kStorageSlotCount) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorInvalidKey];
        }
        return NO;
    }
    NSString *serviceName = [self getServiceName];
    NSString *name = [NSString stringWithFormat:kPasteboardNameFormat, serviceName, storageIndex];
    UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:name create:NO];
    if (pasteboard == nil) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorInvalidField];
        }
        return NO;
    }
    if ([pasteboard valueForPasteboardType:kPasteboardType] == nil) {
        if (error != nullptr) {
            *error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorInvalidDataType];
        }
        return NO;
    }
    // The binary passes a nil data to clear the slot; a typed nil sidesteps the framework's
    // nonnull.
    NSData *emptyData = nil;
    [pasteboard setData:emptyData forPasteboardType:kPasteboardType];
    [UIPasteboard removePasteboardWithName:name];
    return YES;
}

#pragma mark - Record conversion

/** @ghidraAddress 0x2682e0 */
- (NSDictionary *)convertToData:(NSDictionary *)record
                    serviceName:(NSString *)serviceName
                   storageIndex:(int)storageIndex {
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:record];
    NSNumber *index = @((NSInteger)storageIndex);
    if (index != nil) {
        result[kStorageIndexKey] = index;
    }
    NSString *name = [NSString stringWithFormat:kPasteboardNameFormat, serviceName, storageIndex];
    NSData *key = [Crypto createHash:[name dataUsingEncoding:NSUTF8StringEncoding]];
    NSData *encryptedValue = result[kValueKey];
    NSData *decrypted = [Crypto cryptorToData:kCipherDecrypt value:encryptedValue key:key];
    NSString *value = [[NSString alloc] initWithData:decrypted encoding:NSUTF8StringEncoding];
    if (value != nil) {
        result[kValueKey] = value;
    }
    return result;
}

#pragma mark - Service names

/** @ghidraAddress 0x268524 */
- (NSString *)getServiceName {
    NSString *env = [ApplilinkConsts baseUrlSsl];
    if (env == nil || [env isEqualToString:kEnvDisabled]) {
        return kServiceName;
    }
    return [NSString stringWithFormat:kServiceNameFormat, env, kServiceName];
}

/** @ghidraAddress 0x2685e4 */
- (NSString *)getServiceNameOld {
    NSString *env = [ApplilinkConsts envServer];
    if (env == nil || [env isEqualToString:kEnvDisabled]) {
        return kServiceName;
    }
    return [NSString stringWithFormat:kServiceNameFormat, env, kServiceName];
}

#pragma mark - Debugging

/** @ghidraAddress 0x2686a4 */
- (void)debugLog {
    NSString *serviceName = [self getServiceName];
    for (int storageIndex = 0; storageIndex < kStorageSlotCount; ++storageIndex) {
        NSString *name =
            [NSString stringWithFormat:kPasteboardNameFormat, serviceName, storageIndex];
        if ([UIPasteboard pasteboardWithName:name create:NO] != nil) {
            NSError *readError = nil;
            NSDictionary *record = [self storageDataWithServiceName:serviceName
                                                       storageIndex:storageIndex
                                                              error:&readError];
            if (readError == nil && record != nil) {
                (void)record[kValueKey]; // Yes, the binary discards this lookup.
            }
        }
    }
}

@end
