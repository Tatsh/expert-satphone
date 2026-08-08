#import "jubeatLabAccess.h"

#import <Security/Security.h>

#import "CJSONSerializer.h"
#import "EditorIDManager.h"
#import "JubeatAppDelegate.h"

// The API host and the versioned path prefix every endpoint hangs off. From the CFString at
// 0x2e1520 and the C string at 0x288deb.
static NSString *const kJubeatLabHost = @"jubeat-lab.s.game.konami.jp";
static const char *const kJubeatLabPathPrefix = "/aqq/api/JP/v1";

// The client identity key echoed in the create-user body. From the CFString at cf_uuid.
static NSString *const kJubeatLabUUIDKey = @"uuid";

// The endpoints reached so far. From the CFStrings at 0x2e1240 and 0x2d99c0.
static NSString *const kJubeatLabUsersAPI = @"users";
static NSString *const kJubeatLabPOSTCommand = @"POST";
static NSString *const kJubeatLabGETCommand = @"GET";

// The endpoint path formats and the session body key. From the CFStrings at 0x2e1380, 0x2e13a0,
// 0x2e13c0, 0x2dba00, 0x2e1440, and cf_passwd.
static NSString *const kJubeatLabSessionAPIFormat = @"users/%@/Session";
static NSString *const kJubeatLabSession2APIFormat = @"users/%@/Session2";
static NSString *const kJubeatLabLicenseVersionAPI = @"policy/lastUpdate";
static NSString *const kJubeatLabLicenseAPI = @"policy";
static NSString *const kJubeatLabTopPageAPI = @"utils/getLabURL";
static NSString *const kJubeatLabPasswordKey = @"passwd";

// The request timeout in seconds; the pooled double at the requestWithURL: call is 15.0.
static const NSTimeInterval kJubeatLabTimeout = 15.0;

@implementation jubeatLabAccess {
    NSMutableURLRequest *request; // +0x08, ivar-offset global 0x34bc68
    __weak id delegate;           // +0x20, ivar-offset global 0x34bc6c
}

/** @ghidraAddress 0x1d8b20 */
- (instancetype)initWithURL:(NSURL *)url delegate:(id)aDelegate {
    self = [super init];
    if (self) {
        request = [NSMutableURLRequest requestWithURL:url
                                          cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                      timeoutInterval:kJubeatLabTimeout];
        [request setValue:JubeatAppDelegate.appDelegate.userAgent forHTTPHeaderField:@"User-Agent"];
        delegate = aDelegate;
    }
    return self;
}

/** @ghidraAddress 0x1d8c64 */
- (instancetype)initWithURL:(NSURL *)url
                   sendData:(NSData *)sendData
                    command:(NSString *)command
                   delegate:(id)aDelegate {
    self = [super init];
    if (self) {
        request = [NSMutableURLRequest requestWithURL:url
                                          cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                      timeoutInterval:kJubeatLabTimeout];
        request.HTTPMethod = command;
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:[NSString stringWithFormat:@"%d", (int)sendData.length]
            forHTTPHeaderField:@"Content-Length"];
        if (sendData) {
            request.HTTPBody = sendData;
            [request setValue:JubeatAppDelegate.appDelegate.userAgent
                forHTTPHeaderField:@"User-Agent"];
        }
        delegate = aDelegate;
    }
    return self;
}

/** @ghidraAddress 0x1d8f8c */
- (NSURL *)getApiPath:(NSString *)scheme api:(NSString *)api {
    NSString *path = [NSMutableString stringWithFormat:@"%s/%@", kJubeatLabPathPrefix, api];
    // The binary compares the scheme against "https" here but discards the result; the scheme used
    // is the argument itself. Verified at 0x1d900c-0x1d9038.
    (void)[scheme isEqualToString:@"https"];
    NSString *urlString = [NSString stringWithFormat:@"%@://%@%@", scheme, kJubeatLabHost, path];
    return [[NSURL alloc] initWithString:urlString];
}

/** @ghidraAddress 0x1d8840 */
- (NSDictionary *)getKeyQuery:(id)key {
    // Identical to +[EditorIDManager getKeyQuery:]: a generic-password lookup scoped to the bundle
    // identifier that asks for the attributes and caps the match at one.
    NSString *service = NSBundle.mainBundle.bundleIdentifier;
    return @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : key,
        (__bridge id)kSecAttrService : service,
        (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne,
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
    };
}

/** @ghidraAddress 0x1d89b0 */
- (NSString *)getKeyString:(id)key {
    // Identical to +[EditorIDManager getKeyString:]: a two-step lookup, attributes then payload.
    CFTypeRef attributes = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)[self getKeyQuery:key], &attributes) !=
        errSecSuccess) {
        return nil;
    }
    NSMutableDictionary *fetch =
        [NSMutableDictionary dictionaryWithDictionary:(__bridge NSDictionary *)attributes];
    fetch[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    fetch[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
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

/** @ghidraAddress 0x1d90a8 */
- (instancetype)initUIDApi:(id)aDelegate {
    // POSTs the device UUID to the users endpoint to mint an editor identifier.
    NSURL *url = [self getApiPath:@"https" api:kJubeatLabUsersAPI];
    NSDictionary *body = @{kJubeatLabUUIDKey : JubeatAppDelegate.clientInfo[kJubeatLabUUIDKey]};
    NSData *json = [CJSONSerializer.serializer serializeDictionary:body error:nil];
    return [self initWithURL:url sendData:json command:kJubeatLabPOSTCommand delegate:aDelegate];
}

/** @ghidraAddress 0x1da078 */
- (instancetype)initSessionApi:(id)aDelegate {
    // POSTs {"passwd": <passphrase>} to users/<editorID>/Session. The editor identifier fills the
    // path and its passphrase is the body. Verified at 0x1da0e0 (the two getKeyString: reads).
    NSString *editorID = [self getKeyString:EditorIDManager.getEditorIDKey];
    NSString *passwd = [self getKeyString:EditorIDManager.getEditorPassKey];
    NSString *api = [NSString stringWithFormat:kJubeatLabSessionAPIFormat, editorID];
    NSURL *url = [self getApiPath:@"https" api:api];
    NSDictionary *body = @{kJubeatLabPasswordKey : passwd};
    NSData *json = [CJSONSerializer.serializer serializeDictionary:body error:nil];
    return [self initWithURL:url sendData:json command:kJubeatLabPOSTCommand delegate:aDelegate];
}

/** @ghidraAddress 0x1da320 */
- (instancetype)initTopPageSessionApi:(id)aDelegate {
    // The Session2 twin of -initSessionApi:.
    NSString *editorID = [self getKeyString:EditorIDManager.getEditorIDKey];
    NSString *passwd = [self getKeyString:EditorIDManager.getEditorPassKey];
    NSString *api = [NSString stringWithFormat:kJubeatLabSession2APIFormat, editorID];
    NSURL *url = [self getApiPath:@"https" api:api];
    NSDictionary *body = @{kJubeatLabPasswordKey : passwd};
    NSData *json = [CJSONSerializer.serializer serializeDictionary:body error:nil];
    return [self initWithURL:url sendData:json command:kJubeatLabPOSTCommand delegate:aDelegate];
}

/** @ghidraAddress 0x1da5c8 */
- (instancetype)initLicenseVersionApi:(id)aDelegate {
    NSString *api = [NSString stringWithFormat:@"%@", kJubeatLabLicenseVersionAPI];
    NSURL *url = [self getApiPath:@"https" api:api];
    return [self initWithURL:url sendData:nil command:kJubeatLabGETCommand delegate:aDelegate];
}

/** @ghidraAddress 0x1da694 */
- (instancetype)initLicenseApi:(id)aDelegate {
    NSString *api = [NSString stringWithFormat:@"%@", kJubeatLabLicenseAPI];
    NSURL *url = [self getApiPath:@"https" api:api];
    return [self initWithURL:url sendData:nil command:kJubeatLabGETCommand delegate:aDelegate];
}

/** @ghidraAddress 0x1da948 */
- (instancetype)initTopPageApi:(id)aDelegate {
    NSString *api = [NSString stringWithFormat:@"%@", kJubeatLabTopPageAPI];
    NSURL *url = [self getApiPath:@"https" api:api];
    return [self initWithURL:url sendData:nil command:kJubeatLabGETCommand delegate:aDelegate];
}

@end
