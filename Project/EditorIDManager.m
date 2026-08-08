#import "EditorIDManager.h"

#import <Security/Security.h>

#import "JubeatAppDelegate.h"

// The provisioning client is not reconstructed as a class yet, so it is reached by name; see
// TYPES_PENDING.md.
static NSString *const kJubeatLabAccessClassName = @"jubeatLabAccess";

// The JSON keys the provisioning response is read under. From the CFStrings at 0x2d5240, 0x2da060,
// 0x2da080, and 0x2e0fa0.
static NSString *const kResponseStatusKey = @"Status";
static NSString *const kResponseUserIDKey = @"UserID";
static NSString *const kResponsePasswordKey = @"Passwd";
static NSString *const kResponseMessageKey = @"MsgUser";

// The selectors the provisioning client is messaged through and reports back on.
@interface NSObject (JubeatLabAccess)
- (instancetype)initUIDApi:(nullable id)delegate;
- (void)startAccess;
- (void)cancel;
- (nullable NSDictionary *)getDataInJSON;
@end

@interface EditorIDManager () {
    __weak id<EditorIDManagerDelegate> delegate; // +0x128, ivar-offset global 0x349bd8
    id idDownloader;                             // +0x68, ivar-offset global 0x349bdc
}
@end

@implementation EditorIDManager

/** @ghidraAddress 0x1d308c */
+ (BOOL)isExistEditorID {
    NSDictionary *idQuery = [self getKeyQuery:self.getEditorIDKey];
    NSDictionary *passQuery = [self getKeyQuery:self.getEditorPassKey];

    // Both lookups share one out-parameter and neither result is used, so this is a presence test
    // rather than a fetch. Whatever the second lookup writes overwrites the first.
    CFTypeRef found = NULL;
    OSStatus idStatus = SecItemCopyMatching((__bridge CFDictionaryRef)idQuery, &found);
    OSStatus passStatus = SecItemCopyMatching((__bridge CFDictionaryRef)passQuery, &found);

    // The binary ors the two statuses and tests for zero, so both must be errSecSuccess.
    if ((idStatus | passStatus) == errSecSuccess) {
        return YES;
    }
    // A half-provisioned device is wiped rather than left alone. The ccmp at 0x1d315c makes this
    // fire when either status is errSecItemNotFound, not only when both are.
    if (idStatus == errSecItemNotFound || passStatus == errSecItemNotFound) {
        [self deleteKeychain];
    }
    return NO;
}

/** @ghidraAddress 0x1d33c4 */
+ (NSString *)getKeyString:(id)key {
    NSDictionary *query = [self getKeyQuery:key];

    CFTypeRef attributes = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &attributes) != errSecSuccess) {
        return nil;
    }

    // The found attributes become the basis of a second query that asks for the payload, the same
    // two-step -[JubeatAppDelegate musicListKey] uses.
    NSMutableDictionary *fetch =
        [NSMutableDictionary dictionaryWithDictionary:(__bridge NSDictionary *)attributes];
    fetch[(__bridge NSString *)kSecClass] = (__bridge id)kSecClassGenericPassword;
    fetch[(__bridge NSString *)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    CFRelease(attributes);

    CFTypeRef payload = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)fetch, &payload) != errSecSuccess) {
        return nil;
    }
    NSData *bytes = (__bridge NSData *)payload;
    return [[NSString alloc] initWithBytes:bytes.bytes
                                    length:bytes.length
                                  encoding:NSUTF8StringEncoding];
}

/** @ghidraAddress 0x1d2ec4 */
+ (NSDictionary *)getKeyQuery:(id)key {
    // A generic-password lookup scoped to the bundle identifier, asking for the item's attributes
    // and capping the match at one. The pairs are read in order from the stack setup at 0x1d2eec.
    NSString *service = NSBundle.mainBundle.bundleIdentifier;
    return @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : key,
        (__bridge id)kSecAttrService : service,
        (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne,
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
    };
}

#pragma mark - Provisioning

/** @ghidraAddress 0x1d272c */
- (instancetype)initWithDelegate:(id<EditorIDManagerDelegate>)aDelegate {
    self = [super init];
    if (self) {
        delegate = aDelegate;
        idDownloader = [[NSClassFromString(kJubeatLabAccessClassName) alloc] initUIDApi:self];
        [idDownloader startAccess];
    }
    return self;
}

/** @ghidraAddress 0x1d27f8 */
- (void)cancel {
    [idDownloader cancel];
}

/** @ghidraAddress 0x1d28dc */
- (NSDictionary *)createAddQuery:(id)key {
    // A generic-password entry scoped to the bundle identifier, with an empty label and
    // description, accessible after first unlock. Pairs read in order from the stack setup at
    // 0x1d2904.
    NSString *service = NSBundle.mainBundle.bundleIdentifier;
    return @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : key,
        (__bridge id)kSecAttrService : service,
        (__bridge id)kSecAttrLabel : @"",
        (__bridge id)kSecAttrDescription : @"",
        (__bridge id)kSecAttrAccessible : (__bridge id)kSecAttrAccessibleAfterFirstUnlock,
    };
}

/** @ghidraAddress 0x1d2810 */
- (void)jubeatLabAccessProceed:(id)access {
    // Empty in the binary.
}

/** @ghidraAddress 0x1d2814 */
- (void)jubeatLabAccessError:(id)access {
    // Ignores callbacks from a stale client, then reports the failure with no message.
    if (idDownloader != access) {
        return;
    }
    idDownloader = nil;
    if ([delegate respondsToSelector:@selector(errorIDDownload:msgStr:)]) {
        [delegate errorIDDownload:self msgStr:nil];
    }
}

/** @ghidraAddress 0x1d2a5c */
- (void)jubeatLabAccessFinished:(id)access {
    // Ignores callbacks from a stale client.
    if (idDownloader != access) {
        return;
    }
    NSDictionary *json = [access getDataInJSON];
    NSNumber *status = json[kResponseStatusKey];
    NSString *userID = json[kResponseUserIDKey];
    NSString *password = json[kResponsePasswordKey];

    // A missing identifier or passphrase is a failure with no message.
    if (!userID || !password) {
        if ([delegate respondsToSelector:@selector(errorIDDownload:msgStr:)]) {
            [delegate errorIDDownload:self msgStr:nil];
        }
        return;
    }

    if (status.intValue == 0) {
        // Write both keychain items, then refresh the user agent that carries the identifier.
        NSMutableDictionary *idAdd = [NSMutableDictionary
            dictionaryWithDictionary:[self createAddQuery:self.class.getEditorIDKey]];
        idAdd[(__bridge id)kSecValueData] = [userID dataUsingEncoding:NSUTF8StringEncoding];
        SecItemAdd((__bridge CFDictionaryRef)idAdd, NULL);

        NSMutableDictionary *passAdd = [NSMutableDictionary
            dictionaryWithDictionary:[self createAddQuery:self.class.getEditorPassKey]];
        passAdd[(__bridge id)kSecValueData] = [password dataUsingEncoding:NSUTF8StringEncoding];
        SecItemAdd((__bridge CFDictionaryRef)passAdd, NULL);

        [JubeatAppDelegate.appDelegate refreshUserAgent];

        if ([delegate respondsToSelector:@selector(successIDDownload:)]) {
            [delegate successIDDownload:self];
        }
    } else {
        // A non-zero status is a failure carrying the server's user-facing message.
        NSString *message = json[kResponseMessageKey];
        if ([delegate respondsToSelector:@selector(errorIDDownload:msgStr:)]) {
            [delegate errorIDDownload:self msgStr:message];
        }
    }
}

@end
