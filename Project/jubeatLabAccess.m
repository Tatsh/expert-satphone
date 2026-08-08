#import "jubeatLabAccess.h"

#import "CJSONSerializer.h"
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

/** @ghidraAddress 0x1d90a8 */
- (instancetype)initUIDApi:(id)aDelegate {
    // POSTs the device UUID to the users endpoint to mint an editor identifier.
    NSURL *url = [self getApiPath:@"https" api:kJubeatLabUsersAPI];
    NSDictionary *body = @{kJubeatLabUUIDKey : JubeatAppDelegate.clientInfo[kJubeatLabUUIDKey]};
    NSData *json = [CJSONSerializer.serializer serializeDictionary:body error:nil];
    return [self initWithURL:url sendData:json command:kJubeatLabPOSTCommand delegate:aDelegate];
}

@end
