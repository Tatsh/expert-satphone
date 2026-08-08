#import "StoreDownloadManager.h"

#import "BFCodec.h"
#import "Downloader.h"
#import "KUnzip.h"
#import "LabUtilities.h"
#import "StoreDownloadTask.h"
#import "StoreMusicListManager.h"

// Verifies a trailing MD5 digest over a data buffer; a free function not reconstructed yet. See
// TYPES_PENDING.md.
FOUNDATION_EXTERN BOOL VerifyMd5Digest(const void *_Nullable data,
                                       size_t length,
                                       const unsigned char *_Nullable expectedDigest);

// The tune-info cipher key; a free function not reconstructed yet. See TYPES_PENDING.md.
FOUNDATION_EXTERN NSData *_Nullable CreateTuneInfoCipherKey(void);

// The hold-marker probe over an opened archive; Sequence is not reconstructed yet. See
// TYPES_PENDING.md.
@interface Sequence : NSObject
+ (unsigned int)checkExistHoldMarkerFlag:(nullable KUnzip *)unzip;
@end

// Apple's private property-list deserialiser category, as the binary calls it. See
// TYPES_PENDING.md.
@interface NSDictionary (PropertyList)
+ (nullable NSDictionary *)dictionaryFromPropertyListData:(nullable NSData *)data;
@end

// The tune-info archive entries, tried newest-first.
static NSString *const kInfoV3EntryName = @"infov3";
static NSString *const kInfoV2EntryName = @"infov2";
static NSString *const kInfoEntryName = @"info";

// The four-byte header stripped from the deciphered infov3 payload.
static const NSUInteger kInfoV3HeaderLength = 4;

// The tune-info dictionary's id key.
static NSString *const kTuneInfoIDKey = @"ID";

// The trailing MD5 digest length appended to each downloaded pack.
static const NSUInteger kDigestLength = 16;

@interface StoreDownloadManager () <DownloaderDelegate>
- (void)startTaskAtIndex:(unsigned int)index;
- (void)notifyStartTask;
- (void)notifyFailed;
@end

@implementation StoreDownloadManager {
    BOOL isStarted;             // +0x8
    NSArray *tasks;             // +0x10
    Downloader *fileDownloader; // +0x18
    __weak id delegate;         // +0x20
    unsigned int _currentIndex; // +0x28
}

@synthesize currentIndex = _currentIndex;

#pragma mark - Construction

/** @ghidraAddress 0xd7c04 */
- (instancetype)initWithTasks:(NSArray *)tasks_
                     delegate:(id<StoreDownloadManagerDelegate>)aDelegate {
    if (!tasks_) {
        return nil;
    }
    self = [super init];
    if (self) {
        tasks = [[NSArray alloc] initWithArray:tasks_];
        delegate = aDelegate;
        isStarted = NO;
    }
    return self;
}

/** @ghidraAddress 0xd870c */
- (void)dealloc {
    delegate = nil;
    // [super dealloc] is compiler-emitted (ARC).
}

#pragma mark - Tune info

/** @ghidraAddress 0xd79bc */
- (NSDictionary *)getTuneInfoFromUnzip:(KUnzip *)unzip {
    if (!unzip) {
        return nil;
    }
    NSMutableData *payload = [unzip uncompress:kInfoV3EntryName];
    if (payload) {
        // The v3 payload is deciphered with the tune-info key, then its four-byte header is
        // dropped.
        BFCodec *codec = [[BFCodec alloc] init];
        [codec cipherInit:CreateTuneInfoCipherKey()];
        [codec decipher:payload];
        NSData *body = [payload subdataWithRange:NSMakeRange(kInfoV3HeaderLength,
                                                             payload.length - kInfoV3HeaderLength)];
        return [NSDictionary dictionaryFromPropertyListData:body];
    }
    // The older payloads are deciphered with the BGM key and used whole.
    NSMutableData *legacy = [unzip uncompress:kInfoV2EntryName];
    if (!legacy) {
        legacy = [unzip uncompress:kInfoEntryName];
    }
    if (!legacy) {
        return nil;
    }
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:GetBgmCipherKey()];
    [codec decipher:legacy];
    return [NSDictionary dictionaryFromPropertyListData:legacy];
}

#pragma mark - Progress

/** @ghidraAddress 0xd7d88 */
- (unsigned int)numTasks {
    return (unsigned int)tasks.count;
}

/** @ghidraAddress 0xd7d08 */
- (float)currentProgress {
    return fileDownloader.currentProgress;
}

/** @ghidraAddress 0xd7d20 */
- (float)overallProgress {
    return ((float)self.currentIndex + self.currentProgress) / (float)tasks.count;
}

#pragma mark - Lifecycle

// Tells the delegate a task started.
- (void)notifyStartTask {
    if ([delegate respondsToSelector:@selector(downloadManagerStartTask:)]) {
        [delegate performSelector:@selector(downloadManagerStartTask:) withObject:self];
    }
}

// Reports a failure to the delegate.
- (void)notifyFailed {
    if ([delegate respondsToSelector:@selector(downloadManagerFailed:)]) {
        [delegate performSelector:@selector(downloadManagerFailed:) withObject:self];
    }
}

// Starts a download for the task at the given index through a fresh Downloader. Folded from the two
// identical blocks in -start and -downloaderFinished:.
- (void)startTaskAtIndex:(unsigned int)index {
    StoreDownloadTask *task = tasks[index];
    NSURL *url = [NSURL URLWithString:task.sourceURL];
    fileDownloader = [[Downloader alloc] initWithURL:url delegate:self];
    [fileDownloader startDownloading];
    [self notifyStartTask];
}

/** @ghidraAddress 0xd7db0 */
- (void)start {
    if (isStarted) {
        return;
    }
    self.currentIndex = 0;
    [self startTaskAtIndex:0];
    isStarted = YES;
}

/** @ghidraAddress 0xd7f5c */
- (void)cancel {
    [fileDownloader cancel];
    fileDownloader = nil;
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0xd7f98 */
- (void)downloaderFinished:(id)downloader {
    NSData *data = [fileDownloader getData];
    // The pack must carry at least its trailing MD5 digest.
    if (data.length <= kDigestLength) {
        fileDownloader = nil;
        [self notifyFailed];
        return;
    }
    unsigned char digest[16];
    [data getBytes:digest range:NSMakeRange(data.length - kDigestLength, kDigestLength)];
    BOOL ok = VerifyMd5Digest(data.bytes, (int)data.length - kDigestLength, digest);
    fileDownloader = nil;
    if (!ok) {
        [self notifyFailed];
        return;
    }

    // Save the verified pack to its destination, excluded from backup.
    StoreDownloadTask *task = tasks[self.currentIndex];
    NSURL *destURL = [[NSURL alloc] initFileURLWithPath:task.destPath isDirectory:NO];
    [data writeToURL:destURL atomically:YES];
    [destURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];

    // Unpack it and, when it carries a hold marker, register its tune's hold/extend flags.
    KUnzip *unzip = [[KUnzip alloc] initWithData:data range:NSMakeRange(0, data.length)];
    unsigned int holdFlag = [Sequence checkExistHoldMarkerFlag:unzip];
    if (holdFlag != 0) {
        NSDictionary *info = [self getTuneInfoFromUnzip:unzip];
        unsigned int tuneID = (unsigned int)[info[kTuneInfoIDKey] intValue];
        [[StoreMusicListManager sharedManager] extendMusicInfo:tuneID holdFlg:holdFlag extendFlg:0];
        [[StoreMusicListManager sharedManager] saveMusicList];
    }

    // Advance to the next task, or report completion.
    self.currentIndex = self.currentIndex + 1;
    if (self.currentIndex < tasks.count) {
        [self startTaskAtIndex:self.currentIndex];
    } else if ([delegate respondsToSelector:@selector(downloadManagerCompleted:)]) {
        [delegate performSelector:@selector(downloadManagerCompleted:) withObject:self];
    }
}

/** @ghidraAddress 0xd85b0 */
- (void)downloaderProceed:(id)downloader {
    if ([delegate respondsToSelector:@selector(downloadManagerProceed:)]) {
        [delegate performSelector:@selector(downloadManagerProceed:) withObject:self];
    }
}

/** @ghidraAddress 0xd8654 */
- (void)downloaderError:(id)downloader {
    fileDownloader = nil;
    [self notifyFailed];
}

@end
