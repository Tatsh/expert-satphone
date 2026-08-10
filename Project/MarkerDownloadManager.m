#import "MarkerDownloadManager.h"

#import "Downloader.h"
#import "MarkerManager.h"

// Verifies a trailing MD5 digest over a data buffer; a free function not reconstructed yet. See
// TYPES_PENDING.md.
FOUNDATION_EXTERN BOOL VerifyMd5Digest(const void *_Nullable data,
                                       size_t length,
                                       const unsigned char *_Nullable expectedDigest);

// The extra MarkerManager class methods this manager uses that its header does not yet declare. See
// TYPES_PENDING.md.
@interface MarkerManager (MarkerDownload)
+ (nullable NSString *)getMarkerPath:(nullable NSString *)markerID;
+ (void)saveMarker:(nullable NSData *)data markerID:(nullable NSString *)markerID;
+ (void)pullOutMarkerBanner:(nullable NSString *)markerPath bannerID:(nullable NSString *)bannerID;
+ (void)setMarkerInfo:(nullable NSDictionary *)info;
@end

// The task dictionary keys.
static NSString *const kMarkerTaskKeyItemURL = @"ItemURL";
static NSString *const kMarkerTaskKeyID = @"ID";
static NSString *const kMarkerTaskKeyVersion = @"Version";

// The banner name is "tm_" + the marker id's characters 2..5 + "_banner".
static NSString *const kMarkerBannerFormat = @"tm_%@_banner";
static const NSUInteger kMarkerBannerRangeLocation = 2;
static const NSUInteger kMarkerBannerRangeLength = 4;

// The saved marker-info dictionary keys.
static NSString *const kMarkerInfoKeyMarkerID = @"markerID";
static NSString *const kMarkerInfoKeyVersion = @"version";
static NSString *const kMarkerInfoKeyBannerName = @"bannerName";

// The trailing MD5 digest length appended to each downloaded pack.
static const NSUInteger kMarkerDigestLength = 0x10;

@interface MarkerDownloadManager () {
    BOOL isStarted;             // +0x8
    NSArray *tasks;             // +0x10
    Downloader *fileDownloader; // +0x18
    id delegate;                // +0x20 (assign)
    unsigned int _currentIndex; // +0x28
}
@end

// Starts a download for the task at the given index through a fresh Downloader, then tells the
// delegate a task started. Folded from the two identical blocks in -start and -downloaderFinished:.
static inline void MarkerDownloadManagerStartTaskAtIndex(MarkerDownloadManager *self,
                                                         unsigned int index) {
    NSDictionary *task = self->tasks[index];
    NSURL *url = [NSURL URLWithString:task[kMarkerTaskKeyItemURL]];
    self->fileDownloader = [[Downloader alloc] initWithURL:url delegate:self];
    [self->fileDownloader startDownloading];
    if ([self->delegate respondsToSelector:@selector(downloadManagerStartTask:)]) {
        [self->delegate performSelector:@selector(downloadManagerStartTask:) withObject:self];
    }
}

// Reports a failure to the delegate.
static inline void MarkerDownloadManagerNotifyFailed(MarkerDownloadManager *self) {
    if ([self->delegate respondsToSelector:@selector(downloadManagerFailed:)]) {
        [self->delegate performSelector:@selector(downloadManagerFailed:) withObject:self];
    }
}

@implementation MarkerDownloadManager

@synthesize currentIndex = _currentIndex;

#pragma mark - Construction

/** @ghidraAddress 0x870bc */
- (instancetype)initWithTasks:(NSArray *)tasks_
                     delegate:(id<MarkerDownloadManagerDelegate>)aDelegate {
    if (!tasks_) {
        return nil;
    }
    self = [super init];
    if (self) {
        tasks = [[NSMutableArray alloc] initWithArray:tasks_];
        delegate = aDelegate;
        isStarted = NO;
    }
    return self;
}

/** @ghidraAddress 0x87b98 */
- (void)dealloc {
    delegate = nil;
    // [super dealloc] is compiler-emitted (ARC).
}

#pragma mark - Progress

/** @ghidraAddress 0x87240 */
- (unsigned int)numTasks {
    return (unsigned int)tasks.count;
}

/** @ghidraAddress 0x871c0 */
- (float)currentProgress {
    return fileDownloader.currentProgress;
}

/** @ghidraAddress 0x871d8 */
- (float)overallProgress {
    return ((float)self.currentIndex + self.currentProgress) / (float)tasks.count;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x87268 */
- (void)start {
    if (isStarted) {
        return;
    }
    self.currentIndex = 0;
    NSDictionary *task = tasks[0];
    NSURL *url = [NSURL URLWithString:task[kMarkerTaskKeyItemURL]];
    fileDownloader = [[Downloader alloc] initWithURL:url delegate:self];
    [fileDownloader startDownloading];
    isStarted = YES;
    if ([delegate respondsToSelector:@selector(downloadManagerStartTask:)]) {
        [delegate performSelector:@selector(downloadManagerStartTask:) withObject:self];
    }
}

/** @ghidraAddress 0x8741c */
- (void)cancel {
    [fileDownloader cancel];
    fileDownloader = nil;
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x87458 */
- (void)downloaderFinished:(id)downloader {
    NSData *data = [fileDownloader getData];
    // The pack must carry at least its trailing MD5 digest.
    if (data.length <= kMarkerDigestLength) {
        fileDownloader = nil;
        MarkerDownloadManagerNotifyFailed(self);
        return;
    }
    unsigned char digest[16];
    [data getBytes:digest
             range:NSMakeRange(data.length - kMarkerDigestLength, kMarkerDigestLength)];
    BOOL ok = VerifyMd5Digest(data.bytes, (int)data.length - kMarkerDigestLength, digest);
    fileDownloader = nil;
    if (!ok) {
        MarkerDownloadManagerNotifyFailed(self);
        return;
    }

    // Install the verified marker and its banner, and record its info.
    NSDictionary *task = tasks[self.currentIndex];
    NSString *markerID = task[kMarkerTaskKeyID];
    NSString *markerPath = [MarkerManager getMarkerPath:markerID];
    NSString *bannerName = [NSString
        stringWithFormat:kMarkerBannerFormat,
                         [markerID substringWithRange:NSMakeRange(kMarkerBannerRangeLocation,
                                                                  kMarkerBannerRangeLength)]];
    [MarkerManager saveMarker:data markerID:markerID];
    [MarkerManager pullOutMarkerBanner:markerPath bannerID:bannerName];
    NSString *version = task[kMarkerTaskKeyVersion];
    NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
    [info setValue:markerID forKey:kMarkerInfoKeyMarkerID];
    [info setValue:version forKey:kMarkerInfoKeyVersion];
    [info setValue:bannerName forKey:kMarkerInfoKeyBannerName];
    [MarkerManager setMarkerInfo:[NSDictionary dictionaryWithDictionary:info]];

    // Advance to the next task, or report completion.
    self.currentIndex = self.currentIndex + 1;
    if (self.currentIndex < tasks.count) {
        MarkerDownloadManagerStartTaskAtIndex(self, self.currentIndex);
    } else if ([delegate respondsToSelector:@selector(downloadManagerCompleted:)]) {
        [delegate performSelector:@selector(downloadManagerCompleted:) withObject:self];
    }
}

/** @ghidraAddress 0x87a3c */
- (void)downloaderProceed:(id)downloader {
    if ([delegate respondsToSelector:@selector(downloadManagerProceed:)]) {
        [delegate performSelector:@selector(downloadManagerProceed:) withObject:self];
    }
}

/** @ghidraAddress 0x87ae0 */
- (void)downloaderError:(id)downloader {
    fileDownloader = nil;
    MarkerDownloadManagerNotifyFailed(self);
}

@end
