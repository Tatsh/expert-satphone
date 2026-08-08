#import "ImageDownloader.h"

#import "JubeatAppDelegate.h"

// The request timeout and the receive buffer's initial capacity.
static const NSTimeInterval kImageDownloadTimeout = 12.0; // fmov 0x4028000000000000
static const NSUInteger kImageDownloadBufferCapacity = 0x4000;

// The device scale at which the decoded image needs no rescaling.
static const CGFloat kImageNativeScale = 1.0;

@implementation ImageDownloader {
    NSMutableData *data;                          // +0x8
    UIImage *downloadedImage;                     // +0x10
    NSURLSession *session;                        // +0x18
    NSURLSessionTask *sessionTask;                // +0x20
    BOOL _downloading;                            // +0x28
    NSURL *_imageURL;                             // +0x30
    id _key;                                      // +0x38
    __weak id<ImageDownloaderDelegate> _delegate; // +0x40
}

@synthesize imageURL = _imageURL;
@synthesize key = _key;
@synthesize delegate = _delegate;
@synthesize downloading = _downloading;

#pragma mark - Construction

/** @ghidraAddress 0xfeb38 */
- (instancetype)initWithImageURL:(NSURL *)imageURL forKey:(id)key {
    self = [super init];
    if (self) {
        _imageURL = imageURL;
        _key = key;
    }
    return self;
}

/** @ghidraAddress 0xff1c4 */
- (void)dealloc {
    [sessionTask cancel];
    // [super dealloc] is compiler-emitted (ARC).
}

#pragma mark - Download

/** @ghidraAddress 0xfebf0 */
- (void)startDownload {
    data = [[NSMutableData alloc] initWithCapacity:kImageDownloadBufferCapacity];
    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:self.imageURL
                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                            timeoutInterval:kImageDownloadTimeout];
    [request setValue:JubeatAppDelegate.appDelegate.userAgent forHTTPHeaderField:@"User-Agent"];
    session =
        [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration
                                      delegate:self
                                 delegateQueue:NSOperationQueue.currentQueue];
    sessionTask = [session dataTaskWithRequest:request];
    [sessionTask resume];
    _downloading = YES;
}

/** @ghidraAddress 0xfedfc */
- (void)cancelDownload {
    _downloading = NO;
    [sessionTask cancel];
    sessionTask = nil;
    data = nil;
}

/** @ghidraAddress 0xfee58 */
- (UIImage *)getImage {
    return downloadedImage;
}

#pragma mark - NSURLSessionDataDelegate

/** @ghidraAddress 0xfee68 */
- (void)URLSession:(NSURLSession *)aSession
              dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveResponse:(NSURLResponse *)response
     completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    if (session != aSession) {
        return;
    }
    completionHandler(NSURLSessionResponseAllow);
}

/** @ghidraAddress 0xfeed0 */
- (void)URLSession:(NSURLSession *)aSession
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)receivedData {
    if (session != aSession) {
        return;
    }
    [data appendData:receivedData];
}

/** @ghidraAddress 0xfef44 */
- (void)URLSession:(NSURLSession *)aSession
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
    if (session != aSession) {
        return;
    }
    if (error) {
        session = nil;
        data = nil;
        _downloading = NO;
        return;
    }
    downloadedImage = nil;
    _downloading = NO;
    UIImage *image = [[UIImage alloc] initWithData:data];
    if (image) {
        // A non-native screen scale re-wraps the decoded CGImage at that scale.
        if (UIScreen.mainScreen.scale == kImageNativeScale) {
            downloadedImage = image;
        } else {
            downloadedImage = [UIImage imageWithCGImage:image.CGImage
                                                  scale:UIScreen.mainScreen.scale
                                            orientation:UIImageOrientationUp];
        }
    }
    data = nil;
    session = nil;
    if (downloadedImage) {
        [self.delegate imageDownloader:self didLoad:self.key];
    }
}

@end
