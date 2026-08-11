#import "Downloader.h"

#import "CJSONDeserializer.h"
#import "Downloader_Protected.h"
#import "JubeatAppDelegate.h"

// The ivars are declared in Downloader_Protected.h so the SessionDownloader subclass can reach
// them, matching how the binary indexes the shared slots by offset.
@implementation Downloader

/** @ghidraAddress 0xa7d4c */
- (instancetype)initWithURL:(NSURL *)url delegate:(id<DownloaderDelegate>)aDelegate {
    self = [super init];
    if (self) {
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:4
                                                       timeoutInterval:30.0];
        [req setValue:JubeatAppDelegate.appDelegate.userAgent forHTTPHeaderField:@"User-Agent"];
        request = req;
        delegate = aDelegate;
        _tag = 0;
    }
    return self;
}

/** @ghidraAddress 0xa7e9c */
- (instancetype)initWithURL:(NSURL *)url
               postJsonData:(NSData *)jsonData
                   delegate:(id<DownloaderDelegate>)aDelegate {
    self = [super init];
    if (self) {
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:4
                                                       timeoutInterval:30.0];
        [req setHTTPMethod:@"POST"];
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSString *length = [NSString stringWithFormat:@"%d", (int)jsonData.length];
        [req setValue:length forHTTPHeaderField:@"Content-Length"];
        [req setHTTPBody:jsonData];
        [req setValue:JubeatAppDelegate.appDelegate.userAgent forHTTPHeaderField:@"User-Agent"];
        request = req;
        delegate = aDelegate;
    }
    return self;
}

/** @ghidraAddress 0xa80a8 */
- (instancetype)initWithURL:(NSURL *)url
                   postData:(NSData *)postData
                   delegate:(id<DownloaderDelegate>)aDelegate {
    self = [super init];
    if (self) {
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:4
                                                       timeoutInterval:30.0];
        [req setHTTPMethod:@"POST"];
        NSString *length = [NSString stringWithFormat:@"%d", (int)postData.length];
        [req setValue:length forHTTPHeaderField:@"Content-Length"];
        [req setHTTPBody:postData];
        [req setValue:JubeatAppDelegate.appDelegate.userAgent forHTTPHeaderField:@"User-Agent"];
        request = req;
        delegate = aDelegate;
    }
    return self;
}

/** @ghidraAddress 0xa8298 */
- (void)startDownloading {
    [self connectionCancel];
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.defaultSessionConfiguration;
    NSURLSession *sess = [NSURLSession sessionWithConfiguration:config
                                                       delegate:self
                                                  delegateQueue:NSOperationQueue.mainQueue];
    session = sess;
    NSURLSessionTask *task = [sess dataTaskWithRequest:request];
    sessionTask = task;
    [task resume];
}

/** @ghidraAddress 0xa83a4 */
- (void)cancel {
    delegate = nil;
    [self connectionCancel];
    data = nil;
}

/** @ghidraAddress 0xa88e0 */
- (void)connectionCancel {
    [sessionTask cancel];
    sessionTask = nil;
}

#pragma mark - NSURLSessionDataDelegate

/** @ghidraAddress 0xa83f4 */
- (void)URLSession:(NSURLSession *)urlSession
              dataTask:(NSURLSessionDataTask *)urlDataTask
    didReceiveResponse:(NSURLResponse *)response
     completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    if (session != urlSession) {
        return;
    }
    int64_t expected = response.expectedContentLength;
    dl_size = expected;
    if (expected > 0) {
        data = [NSMutableData dataWithCapacity:(NSUInteger)expected];
    }
    completionHandler(NSURLSessionResponseAllow);
}

/** @ghidraAddress 0xa84e4 */
- (void)URLSession:(NSURLSession *)urlSession
          dataTask:(NSURLSessionDataTask *)urlDataTask
    didReceiveData:(NSData *)receivedData {
    if (session != urlSession) {
        return;
    }
    if (!data) {
        data = [NSMutableData dataWithCapacity:0x10000];
    }
    [data appendData:receivedData];
    if ([delegate respondsToSelector:@selector(downloaderProceed:)]) {
        [delegate performSelector:@selector(downloaderProceed:) withObject:self];
    }
}

/** @ghidraAddress 0xa8608 */
- (void)URLSession:(NSURLSession *)urlSession
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
    if (session != urlSession) {
        return;
    }
    session = nil;
    BOOL succeeded = (error == nil);
    if (!succeeded) {
        data = nil;
    }
    SEL selector = succeeded ? @selector(downloaderFinished:) : @selector(downloaderError:);
    if ([delegate respondsToSelector:selector]) {
        [delegate performSelector:selector withObject:self];
    }
}

#pragma mark - Accessors

/** @ghidraAddress 0xa8710 */
- (unsigned long long)currentSize {
    return data.length;
}

/** @ghidraAddress 0xa8728 */
- (float)currentProgress {
    if (dl_size <= 0) {
        return 0.0f;
    }
    float progress = (float)data.length / (float)dl_size;
    if (progress > 1.0f) {
        progress = 1.0f;
    }
    return progress;
}

/** @ghidraAddress 0xa8794 */
- (NSData *)getData {
    return data;
}

/** @ghidraAddress 0xa87a4 */
- (NSDictionary *)getDataInJSON {
    if (!data) {
        return nil;
    }
    NSError *error = nil;
    id json = [NSDictionary dictionaryWithJSONData:data error:&error];
    if ([json isKindOfClass:NSDictionary.class]) {
        return json;
    }
    return nil;
}

/** @ghidraAddress 0xa891c */
- (int)tag {
    return _tag;
}

/** @ghidraAddress 0xa892c */
- (void)setTag:(int)tag {
    _tag = tag;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0xa8878 */
- (void)dealloc {
    delegate = nil;
    [self connectionCancel];
    // [super dealloc] is compiler-emitted (ARC — .cxx_destruct at 0xa893c).
}

@end
