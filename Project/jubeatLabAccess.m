#import "jubeatLabAccess.h"

#import <Security/Security.h>

#import "CJSONSerializer.h"
#import "EditorIDManager.h"
#import "JubeatAppDelegate.h"

// TouchJSON's deserialiser category, the same one -[Downloader getDataInJSON] uses.
@interface NSDictionary (CJSONDeserializer)
+ (nullable id)dictionaryWithJSONData:(nullable NSData *)data error:(NSError **)error;
@end

@interface jubeatLabAccess ()
// De-inlined: cancels and drops the session task. @ghidraAddress 0x1db2d0
- (void)connectionCancel;
@end

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

// The web-page paths reached through +getWebPagePath:pagePath:. From the CFStrings at 0x2e1460,
// 0x2e1480, 0x2e14a0, 0x2e14e0, and the C string "JP" at 0x27f352.
static NSString *const kJubeatLabUserPageFormat = @"aqq/contents/manage/index.jsp?t=%s";
static NSString *const kJubeatLabSessionErrorPage = @"aqq/contents/error/session_err.jsp";
static NSString *const kJubeatLabMusicPage = @"aqq/contents/ios/music.jsp";
static NSString *const kJubeatLabDetailPage = @"aqq/contents/ios/detail.jsp";
static const char *const kJubeatLabRegion = "JP";

@implementation jubeatLabAccess {
    NSMutableURLRequest *request;      // +0x08, ivar-offset global 0x34bc68
    NSMutableData *data;               // +0x10, ivar-offset global 0x34bc78
    NSInteger dl_size;                 // +0x18, ivar-offset global 0x34bc7c
    __weak id delegate;                // +0x20, ivar-offset global 0x34bc6c
    NSURLSession *session;             // +0x28, ivar-offset global 0x34bc70
    NSURLSessionDataTask *sessionTask; // +0x30, ivar-offset global 0x34bc74
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

#pragma mark - Web-page URLs

/** @ghidraAddress 0x1d8e90 */
+ (NSURL *)getWebPagePath:(NSString *)scheme pagePath:(NSString *)pagePath {
    // As with -getApiPath:api:, the scheme is used verbatim and the "https" comparison discarded.
    (void)[scheme isEqualToString:@"https"];
    NSString *urlString =
        [NSMutableString stringWithFormat:@"%@://%@/%@", scheme, kJubeatLabHost, pagePath];
    return [NSURL URLWithString:urlString];
}

/** @ghidraAddress 0x1db05c */
+ (NSURL *)getUserPageURL {
    NSString *page = [NSString stringWithFormat:kJubeatLabUserPageFormat, kJubeatLabRegion];
    return [self getWebPagePath:@"https" pagePath:page];
}

/** @ghidraAddress 0x1db0e8 */
+ (NSURL *)getUserPageSessionFailedURL {
    NSString *page = [NSString stringWithFormat:@"%@", kJubeatLabSessionErrorPage];
    return [self getWebPagePath:@"https" pagePath:page];
}

/** @ghidraAddress 0x1db160 */
+ (NSURL *)getSequenceSerchURL:(int)musicID {
    NSString *midString = [NSString stringWithFormat:@"%d", musicID];
    NSString *page = [NSString stringWithFormat:@"%@?mid=%@&kfs=a", kJubeatLabMusicPage, midString];
    return [self getWebPagePath:@"https" pagePath:page];
}

/** @ghidraAddress 0x1db224 */
+ (NSURL *)getSequencePageURL:(id)sequenceID {
    NSString *page = [NSString stringWithFormat:@"%@?s=%@", kJubeatLabDetailPage, sequenceID];
    return [self getWebPagePath:@"https" pagePath:page];
}

#pragma mark - Request lifecycle

/** @ghidraAddress 0x1daa14 */
- (void)startAccess {
    [self connectionCancel];
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.defaultSessionConfiguration;
    session = [NSURLSession sessionWithConfiguration:config
                                            delegate:self
                                       delegateQueue:NSOperationQueue.mainQueue];
    sessionTask = [session dataTaskWithRequest:request];
    [sessionTask resume];
}

/** @ghidraAddress 0x1dab20 */
- (void)cancel {
    delegate = nil;
    [self connectionCancel];
    data = nil;
}

/** @ghidraAddress 0x1db2d0 */
- (void)connectionCancel {
    [sessionTask cancel];
    sessionTask = nil;
}

/** @ghidraAddress 0x1daf10 */
- (NSData *)getData {
    return data;
}

/** @ghidraAddress 0x1daf20 */
- (NSDictionary *)getDataInJSON {
    if (!data) {
        return nil;
    }
    id json = [NSDictionary dictionaryWithJSONData:data error:nil];
    if ([json isKindOfClass:NSDictionary.class]) {
        return json;
    }
    return nil;
}

/** @ghidraAddress 0x1dae8c */
- (NSInteger)currentSize {
    return data.length;
}

/** @ghidraAddress 0x1daea4 */
- (float)currentProgress {
    // Zero until the expected length is known; then the fraction received, capped at 1.
    if (dl_size <= 0) {
        return 0;
    }
    float progress = (float)data.length / (float)dl_size;
    if (progress > 1.0f) {
        progress = 1.0f;
    }
    return progress;
}

#pragma mark - NSURLSessionDataDelegate

/** @ghidraAddress 0x1dab70 */
- (void)URLSession:(NSURLSession *)aSession
              dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveResponse:(NSURLResponse *)response
     completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    // Ignores callbacks from a stale session; pre-sizes the buffer when the length is known.
    if (session != aSession) {
        return;
    }
    dl_size = (NSInteger)response.expectedContentLength;
    if (dl_size > 0) {
        data = [NSMutableData dataWithCapacity:dl_size];
    }
    completionHandler(NSURLSessionResponseAllow);
}

/** @ghidraAddress 0x1dac60 */
- (void)URLSession:(NSURLSession *)aSession
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)receivedData {
    if (session != aSession) {
        return;
    }
    if (!data) {
        // A 64 KiB buffer when the response length was unknown.
        data = [NSMutableData dataWithCapacity:0x10000];
    }
    [data appendData:receivedData];
    if ([delegate respondsToSelector:@selector(jubeatLabAccessProceed:)]) {
        [delegate performSelector:@selector(jubeatLabAccessProceed:) withObject:self];
    }
}

/** @ghidraAddress 0x1dad84 */
- (void)URLSession:(NSURLSession *)aSession
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
    // Ignores a stale session, then reports success or failure to the delegate. A failure also
    // drops the partial data.
    if (session != aSession) {
        return;
    }
    session = nil;
    SEL callback;
    if (!error) {
        callback = @selector(jubeatLabAccessFinished:);
    } else {
        data = nil;
        callback = @selector(jubeatLabAccessError:);
    }
    if ([delegate respondsToSelector:callback]) {
        [delegate performSelector:callback withObject:self];
    }
}

#pragma mark - Teardown

/** @ghidraAddress 0x1daff4 */
- (void)dealloc {
    delegate = nil;
    [self connectionCancel];
}

@end
