#import "SessionDownloader.h"

#import "CJSONSerializer.h"
#import "Downloader_Protected.h"
#import "EditorIDManager.h"
#import "JubeatAppDelegate.h"
#import "Md5Utilities.h"
#import "ScratchUtil.h"

// The request timeout in seconds; the pooled double at 0x28f258.
static const NSTimeInterval kSessionTimeout = 60.0;

// The MAC salt appended to the body before hashing. Kept verbatim from the CFString at 0x?.
static NSString *const kSessionMACSalt = @"88f2cf8c0772a78aa256118894184355";

// The status codes that drive session retries. 0x18b50-0x18b52 re-open unconditionally; 0x18b53
// re-opens only for the session-scoped API tags; 0x186aa is the "no retry" success-like case.
static const int kSessionStaleStatusFirst = 0x18b50;
static const int kSessionStaleStatusReopenTag = 0x18b53;
static const int kSessionNoRetryStatus = 0x186aa;
static const int kSessionMaxRetries = 5;

// The API tags whose failures re-open the session. 1, 2, and 3 flush the cached session response in
// -startDownloading; 2 and 3 additionally re-open on a 0x18b53.
static const int kApiTagSession1 = 1;
static const int kApiTagSession2 = 2;
static const int kApiTagSession3 = 3;

// The process-wide session cache: the last session cookies, a validity flag, and the cached session
// response body. From the globals at 0x354180, 0x354188, and 0x354190.
static NSArray *sSessionCookies = nil;
static BOOL sSessionValid = NO;
static NSData *sSessionResponse = nil;

@interface SessionDownloader () {
@public
    NSString *sendCnonce;     // +0x50, ivar-offset global 0x34aa88
    NSURLRequest *tmpRequest; // +0x38, ivar-offset global 0x34aa8c
    NSURL *requestURL;        // +0x40, ivar-offset global 0x34aa94
    NSData *requestData;      // +0x48, ivar-offset global 0x34aa98
    int retryCnt;             // +0x60, ivar-offset global 0x34aa90
    NSString *receiveHash;    // +0x58, ivar-offset global 0x34aa9c
}
- (NSString *)dataHash:(NSData *)bodyData;
- (NSURLRequest *)createPostRequest:(NSURL *)url postData:(NSData *)bodyData;
- (NSURLRequest *)getSessionRequest;
@end

// De-inlined from the two 0x18b5x arms: re-open the session against getSessionRequest and resume a
// fresh data task on the main queue, parking the original request in tmpRequest.
static inline void SessionDownloaderReopenSessionAndRetry(SessionDownloader *self) {
    self->tmpRequest = self->request;
    self->request = nil;
    self->request = [self getSessionRequest];
    self->session =
        [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration
                                      delegate:self
                                 delegateQueue:NSOperationQueue.mainQueue];
    self->sessionTask = [self->session dataTaskWithRequest:self->request];
    [self->sessionTask resume];
    self->data = nil;
}

// De-inlined from the retry-cap arm: rebuild the original signed request and resume it.
static inline void SessionDownloaderRetryOriginalRequest(SessionDownloader *self) {
    self->tmpRequest = nil;
    self->request = [self createPostRequest:self->requestURL postData:self->requestData];
    self->session =
        [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration
                                      delegate:self
                                 delegateQueue:NSOperationQueue.mainQueue];
    self->sessionTask = [self->session dataTaskWithRequest:self->request];
    [self->sessionTask resume];
    self->data = nil;
}

@implementation SessionDownloader

@synthesize apiTag = _apiTag; // _apiTag at ivar-offset global 0x34aa84

#pragma mark - Initialisers

/** @ghidraAddress 0xff324 */
- (instancetype)initWithURL:(NSURL *)url
             postDictionary:(NSDictionary *)postDictionary
                   delegate:(id)aDelegate {
    _apiTag = 0;
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:postDictionary];
    // Reuse a caller-supplied cnonce; otherwise mint a random one and record it in the body.
    sendCnonce = params[@"cnonce"];
    if (!sendCnonce) {
        sendCnonce = [NSString stringWithFormat:@"%d", rand()];
        params[@"cnonce"] = sendCnonce;
    }
    // Every client-info entry is folded into the request parameters.
    NSDictionary *clientInfo = JubeatAppDelegate.clientInfo;
    for (id key in clientInfo.allKeys) {
        params[key] = clientInfo[key];
    }
    NSData *json = [CJSONSerializer.serializer serializeDictionary:params error:nil];
    return [self initWithURL:url postData:json delegate:aDelegate];
}

/** @ghidraAddress 0xffb48 */
- (instancetype)initWithURL:(NSURL *)url delegate:(id)aDelegate {
    _apiTag = 0;
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    sendCnonce = [NSString stringWithFormat:@"%d", rand()];
    params[@"cnonce"] = sendCnonce;
    NSDictionary *clientInfo = JubeatAppDelegate.clientInfo;
    for (id key in clientInfo.allKeys) {
        params[key] = clientInfo[key];
    }
    NSData *json = [CJSONSerializer.serializer serializeDictionary:params error:nil];
    return [self initWithURL:url postData:json delegate:aDelegate];
}

/** @ghidraAddress 0xffe1c */
- (instancetype)initWithURL:(NSURL *)url postData:(NSData *)postData delegate:(id)aDelegate {
    self = [super init];
    if (self) {
        retryCnt = 0;
        requestURL = url;
        requestData = postData;
        request = [self createPostRequest:url postData:postData];
        self->delegate = aDelegate;
    }
    return self;
}

#pragma mark - Request signing

/** @ghidraAddress 0xff7b8 */
- (NSString *)dataHash:(NSData *)bodyData {
    // The MAC is the SHA-256 hex of the UTF-8 body with the fixed salt appended.
    NSString *body = [[NSString alloc] initWithData:[bodyData copy] encoding:NSUTF8StringEncoding];
    body = [body stringByAppendingString:kSessionMACSalt];
    return CreateSha256HexStringFromData([body dataUsingEncoding:NSUTF8StringEncoding], NO);
}

/** @ghidraAddress 0xff8b4 */
- (NSURLRequest *)createPostRequest:(NSURL *)url postData:(NSData *)bodyData {
    NSMutableURLRequest *req =
        [NSMutableURLRequest requestWithURL:url
                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                            timeoutInterval:kSessionTimeout];
    req.HTTPMethod = @"POST";
    [req setValue:[NSString stringWithFormat:@"%d", (int)bodyData.length]
        forHTTPHeaderField:@"Content-Length"];
    [req setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[self dataHash:bodyData] forHTTPHeaderField:@"JBT_REQUEST_MAC"];
    req.HTTPBody = bodyData;
    [req setValue:JubeatAppDelegate.appDelegate.userAgent forHTTPHeaderField:@"User-Agent"];
    // Without a live session the first request must open one; otherwise the cached cookies ride
    // along on this request.
    if (sSessionCookies.count == 0) {
        tmpRequest = req;
        return [self getSessionRequest];
    }
    [req setAllHTTPHeaderFields:[NSHTTPCookie requestHeaderFieldsWithCookies:sSessionCookies]];
    return req;
}

/** @ghidraAddress 0xfff4c */
- (NSURLRequest *)getSessionRequest {
    // The session-open POST: the editor identity, region, and this request's cnonce, signed the
    // same way. Verified at 0xfffa0: {target: "JP", user_id: <id>, passwd: <pass>, cnonce:
    // <cnonce>}.
    NSString *editorID = [EditorIDManager getKeyString:EditorIDManager.getEditorIDKey];
    NSString *passwd = [EditorIDManager getKeyString:EditorIDManager.getEditorPassKey];
    NSURL *url = ScratchUtil.challengeSessionURL;
    NSDictionary *body = @{
        @"target" : @"JP",
        @"user_id" : editorID,
        @"passwd" : passwd,
        @"cnonce" : sendCnonce,
    };
    NSData *json = [CJSONSerializer.serializer serializeDictionary:body error:nil];
    NSMutableURLRequest *req =
        [NSMutableURLRequest requestWithURL:url
                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                            timeoutInterval:kSessionTimeout];
    req.HTTPMethod = @"POST";
    [req setValue:[NSString stringWithFormat:@"%d", (int)json.length]
        forHTTPHeaderField:@"Content-Length"];
    [req setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[self dataHash:json] forHTTPHeaderField:@"JBT_REQUEST_MAC"];
    req.HTTPBody = json;
    [req setValue:JubeatAppDelegate.appDelegate.userAgent forHTTPHeaderField:@"User-Agent"];
    return req;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0xff648 */
- (void)startDownloading {
    // A session-scoped tag invalidates the cached session response so the request always goes out.
    if (self.apiTag == kApiTagSession2 || self.apiTag == kApiTagSession3 ||
        self.apiTag == kApiTagSession1) {
        sSessionValid = NO;
        sSessionResponse = nil;
    }
    // With a still-valid cached response the request is answered from it, without a network round
    // trip, by handing the delegate the cached body.
    if (sSessionValid) {
        data = [sSessionResponse copy];
        if ([delegate respondsToSelector:@selector(downloaderFinished:)]) {
            [delegate performSelector:@selector(downloaderFinished:) withObject:self];
            return;
        }
    } else {
        [super startDownloading];
    }
}

#pragma mark - NSURLSessionDataDelegate

/** @ghidraAddress 0x100340 */
- (void)URLSession:(NSURLSession *)aSession
              dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveResponse:(NSURLResponse *)response
     completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    if (session != aSession) {
        return;
    }
    NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
    NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:http.allHeaderFields
                                                              forURL:response.URL];
    receiveHash = http.allHeaderFields[@"JBT_RESPONSE_MAC"];
    if (cookies.count != 0) {
        sSessionCookies = [cookies copy];
    }
    dl_size = (NSInteger)response.expectedContentLength;
    if (dl_size > 0) {
        data = [NSMutableData dataWithCapacity:dl_size];
    }
    completionHandler(NSURLSessionResponseAllow);
}

/** @ghidraAddress 0x100560 */
- (void)URLSession:(NSURLSession *)aSession
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
    if (session != aSession) {
        return;
    }
    if (error) {
        // A transport error clears the session and reports failure.
        session = nil;
        data = nil;
        if ([delegate respondsToSelector:@selector(downloaderError:)]) {
            [delegate performSelector:@selector(downloaderError:) withObject:self];
        }
        return;
    }

    NSDictionary *json = [self getDataInJSON];
    // Verify the response MAC: SHA-256 hex of the body plus this request's cnonce plus the salt.
    NSString *body = [[NSString alloc] initWithData:[data copy] encoding:NSUTF8StringEncoding];
    body = [body stringByAppendingString:sendCnonce];
    body = [body stringByAppendingString:kSessionMACSalt];
    NSData *macData = [body dataUsingEncoding:NSUTF8StringEncoding];
    NSString *computed = macData ? CreateSha256HexStringFromData(macData, NO) : nil;

    SEL callback = nullptr;
    if (!receiveHash || ![computed isEqualToString:receiveHash] || !json) {
        // A missing or mismatched MAC, or a body that is not a JSON dictionary, is a failure.
        callback = @selector(downloaderError:);
    } else {
        NSNumber *status = json[@"status"];
        if (!status) {
            callback = @selector(downloaderFinished:);
        } else {
            int code = status.intValue;
            if ((unsigned int)(code - kSessionStaleStatusFirst) < 3) {
                // A stale session: re-open it and retry this request unconditionally.
                SessionDownloaderReopenSessionAndRetry(self);
                return;
            }
            if (code == kSessionStaleStatusReopenTag) {
                if (self.apiTag == kApiTagSession2 || self.apiTag == kApiTagSession3) {
                    SessionDownloaderReopenSessionAndRetry(self);
                    return;
                }
                // Otherwise cache this session response for the short-circuit in -startDownloading.
                sSessionValid = YES;
                sSessionResponse = [data copy];
            } else if (code != kSessionNoRetryStatus && tmpRequest) {
                // Any other error retries the original request up to five times.
                if (retryCnt < kSessionMaxRetries) {
                    SessionDownloaderRetryOriginalRequest(self);
                } else if ([delegate respondsToSelector:@selector(downloaderError:)]) {
                    [delegate performSelector:@selector(downloaderError:) withObject:self];
                }
                ++retryCnt;
                return;
            }
            callback = @selector(downloaderFinished:);
        }
    }
    if (callback && [delegate respondsToSelector:callback]) {
        [delegate performSelector:callback withObject:self];
    }
}

@end
