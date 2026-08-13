#import "MarkerManager.h"

#import <objc/runtime.h>

#import <CommonCrypto/CommonDigest.h>

#import "BFCodec.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "Md5Utilities.h"
#import "neDebugLog.h"

// Marker info dictionary keys.
static NSString *const kMarkerInfoKeyMarkerID = @"markerID";
static NSString *const kMarkerInfoKeyVersion = @"version";
static NSString *const kMarkerInfoKeyBannerName = @"bannerName";

// NSUserDefaults keys.
static NSString *const kPrefMarkerInfoList = @"PrefMarkerInfoList";
static NSString *const kPrefCurrentMarkerID = @"PrefCurrentMarkerID";
static NSString *const kPrefMarkerVersionList = @"PrefMarkerVersionList";
static NSString *const kPrefMarker = @"PrefMarker";

// On-disc path components and format strings.
static NSString *const kPrivateDocumentsComponent = @"Private Documents";
static NSString *const kMarkerDirectoryComponent = @"marker";
static NSString *const kBannerDirectoryComponent = @"banner";
static NSString *const kBannerArchiveEntryName = @"banner.png";
static NSString *const kMarkerIDFormat = @"mk%04d";
static NSString *const kBannerNameFormat = @"tm%04d_banner";
static NSString *const kMarkerFileNameFormat = @"%@.zip";
static NSString *const kBannerFileNameFormat = @"%@.png";
static NSString *const kResourceNameFormat = @"%@.%@";
static NSString *const kMarkerResourceType = @"zip";
static NSString *const kBannerResourceType = @"png";

// Version sentinels.
static NSString *const kVersionUninstalled = @"0.0.0";
static NSString *const kVersionInitial = @"1.0.0";

// The identifier and index constants recovered as immediates in the binary.
static const int kReservedMarkerSize = 1000;
static const int kDefaultMarkerSize = 35;
// The default list runs identifiers 1 through 35 inclusive, with entry 26 pre-installed.
static const int kFirstDefaultMarkerNumber = 1;
static const int kDefaultMarkerNumberEnd = 36;
static const int kInitialMarkerNumber = 26;
// The numeric identifier occupies characters 2 through 5 of the marker's identifier string.
static const NSUInteger kMarkerNumberRangeLocation = 2;
static const NSUInteger kMarkerNumberRangeLength = 4;

@implementation MarkerManager {
    int currentSlot;
    __weak id delegate;
    NSMutableArray *downloadList;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x1b749c */
- (instancetype)initWithDelegate:(id)aDelegate {
    self = [super init];
    if (self) {
        delegate = aDelegate;
        currentSlot = 0;
    }
    return self;
}

/** @ghidraAddress 0x1b7520 */
- (void)setDownloadList:(NSArray *)list {
    if (downloadList != nil) {
        downloadList = nil;
    }
    downloadList = [NSMutableArray arrayWithArray:list];
    currentSlot = 0;
}

#pragma mark - Sizes

/** @ghidraAddress 0x1b75a8 */
+ (int)getReservedMarkerSize {
    return kReservedMarkerSize;
}

/** @ghidraAddress 0x1b75b0 */
+ (int)getDefaultMarkerSize {
    return kDefaultMarkerSize;
}

#pragma mark - List queries

/** @ghidraAddress 0x1b75b8 */
+ (int)getMarkerIndex:(NSString *)markerID {
    NSArray<NSDictionary<NSString *, NSString *> *> *list = [self getCurrentMarkerList];
    int index = 0;
    for (NSDictionary<NSString *, NSString *> *info in list) {
        if ([info[kMarkerInfoKeyMarkerID] isEqualToString:markerID]) {
            return index;
        }
        ++index;
    }
    return 0;
}

/** @ghidraAddress 0x1b775c */
+ (NSMutableArray<NSDictionary<NSString *, NSString *> *> *)getMarkerList {
    NSMutableData *data =
        [[NSUserDefaults.standardUserDefaults objectForKey:kPrefMarkerInfoList] mutableCopy];
    if (data == nil) {
        if (NE_DBG_FIRST(4)) {
            neDebugLog("getMarkerList: PrefMarkerInfoList absent from NSUserDefaults");
        }
        return nil;
    }
    NSData *key = CreateResourceDataCipherKey();
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:key];
    [codec decipher:data];
    id list = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (NE_DBG_FIRST(4)) {
        neDebugLog("getMarkerList: %lu-byte blob, unarchived %s count=%lu",
                   (unsigned long)data.length,
                   list ? object_getClassName(list) : "nil",
                   [list respondsToSelector:@selector(count)] ? (unsigned long)[list count] : 0UL);
    }
    return [NSMutableArray arrayWithArray:list];
}

/** @ghidraAddress 0x1b78b4 */
+ (void)setMarkerList:(NSArray<NSDictionary<NSString *, NSString *> *> *)list {
    NSArray *snapshot = [NSArray arrayWithArray:list];
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:snapshot];
    NSMutableData *data = [NSMutableData dataWithData:archived];
    NSData *key = CreateResourceDataCipherKey();
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:key];
    [codec encipher:data];
    [NSUserDefaults.standardUserDefaults setObject:data forKey:kPrefMarkerInfoList];
}

/** @ghidraAddress 0x1b7a04 */
+ (NSMutableArray<NSDictionary<NSString *, NSString *> *> *)getCurrentMarkerList {
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *current = [[NSMutableArray alloc] init];
    NSArray<NSDictionary<NSString *, NSString *> *> *list = [self getMarkerList];
    for (NSDictionary<NSString *, NSString *> *info in list) {
        if (![info[kMarkerInfoKeyVersion] isEqualToString:kVersionUninstalled]) {
            [current addObject:info];
        }
    }
    if (NE_DBG_FIRST(4)) {
        neDebugLog("getCurrentMarkerList: %lu of %lu markers installed",
                   (unsigned long)current.count,
                   (unsigned long)list.count);
    }
    return current;
}

/** @ghidraAddress 0x1b7bb8 */
+ (NSDictionary<NSString *, NSString *> *)getMarkerInfo:(int)index {
    return [self getCurrentMarkerList][index];
}

/** @ghidraAddress 0x1b7c1c */
+ (void)setMarkerInfo:(NSDictionary<NSString *, NSString *> *)info {
    NSString *markerID = info[kMarkerInfoKeyMarkerID];
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *list = [self getMarkerList];
    for (NSUInteger i = 0; i < list.count; ++i) {
        if ([list[i][kMarkerInfoKeyMarkerID] isEqualToString:markerID]) {
            [list replaceObjectAtIndex:i withObject:info];
            [self setMarkerList:list];
            return;
        }
    }
    int newNumber = [[markerID substringWithRange:NSMakeRange(kMarkerNumberRangeLocation,
                                                              kMarkerNumberRangeLength)] intValue];
    for (NSUInteger i = 0; i < list.count; ++i) {
        int existingNumber = [[list[i][kMarkerInfoKeyMarkerID]
            substringWithRange:NSMakeRange(kMarkerNumberRangeLocation, kMarkerNumberRangeLength)]
            intValue];
        if (newNumber < existingNumber) {
            [list insertObject:info atIndex:i];
            [self setMarkerList:list];
            return;
        }
    }
    [list addObject:info];
    [self setMarkerList:list];
}

#pragma mark - Data checks

/** @ghidraAddress 0x1b7ef8 */
+ (BOOL)checkMarkerBannerData:(NSString *)name {
    return YES;
}

/** @ghidraAddress 0x1b7f00 */
+ (BOOL)checkMarkerData:(NSString *)name {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *path = [self getMarkerPath:name];
    if (![fileManager fileExistsAtPath:path]) {
        return NO;
    }
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length > CC_MD5_DIGEST_LENGTH) {
        unsigned char expectedDigest[CC_MD5_DIGEST_LENGTH];
        [data getBytes:expectedDigest
                 range:NSMakeRange(data.length - CC_MD5_DIGEST_LENGTH, CC_MD5_DIGEST_LENGTH)];
        if (!VerifyMd5Digest(
                data.bytes, (unsigned int)data.length - CC_MD5_DIGEST_LENGTH, expectedDigest)) {
            return NO;
        }
    }
    return YES;
}

#pragma mark - Backup exclusion

/** @ghidraAddress 0x1b80a8 */
+ (void)setIgnoreSave:(NSURL *)url {
    NSError *error = nil;
    [url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&error];
}

#pragma mark - Installation

/** @ghidraAddress 0x1b8144 */
+ (void)pullOutMarkerBanner:(NSString *)path bannerID:(NSString *)bannerID {
    KUnzip *archive = [[KUnzip alloc] initWithPath:path];
    if (![archive fileExists:kBannerArchiveEntryName]) {
        [self copyMarkerItem:bannerID isBanner:YES];
    } else {
        NSMutableData *bytes = [archive uncompress:kBannerArchiveEntryName];
        NSString *bannerPath = [self getMarkerBannerPath:bannerID];
        [bytes writeToFile:bannerPath atomically:YES];
        [self setIgnoreSave:[NSURL fileURLWithPath:bannerPath]];
    }
}

/** @ghidraAddress 0x1b82ac */
+ (void)saveMarker:(NSData *)data markerID:(NSString *)markerID {
    NSString *path = [self getMarkerPath:markerID];
    NSURL *url = [[NSURL alloc] initFileURLWithPath:path isDirectory:NO];
    [data writeToURL:url atomically:YES];
    [self setIgnoreSave:url];
}

/** @ghidraAddress 0x1b8378 */
+ (void)copyMarkerItem:(NSString *)name isBanner:(BOOL)isBanner {
    NSString *directory = [self getMarkerDirectoryPath];
    if (isBanner) {
        directory = [directory stringByAppendingPathComponent:kBannerDirectoryComponent];
    }
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *type = isBanner ? kBannerResourceType : kMarkerResourceType;
    NSString *fileName = [NSString stringWithFormat:kResourceNameFormat, name, type];
    NSString *destinationPath = [directory stringByAppendingPathComponent:fileName];
    NSString *sourcePath = [NSBundle.mainBundle pathForResource:name ofType:type];
    if (sourcePath != nil) {
        NSError *error = nil;
        if ([fileManager fileExistsAtPath:destinationPath]) {
            [fileManager removeItemAtPath:destinationPath error:&error];
        }
        [fileManager copyItemAtPath:sourcePath toPath:destinationPath error:&error];
        [self setIgnoreSave:[NSURL fileURLWithPath:destinationPath]];
    }
}

/** @ghidraAddress 0x1b8634 */
+ (void)copyMarker:(NSString *)name {
    [self copyMarkerItem:name isBanner:NO];
}

/** @ghidraAddress 0x1b8644 */
+ (void)copyMarkerBanner:(NSString *)name {
    [self copyMarkerItem:name isBanner:YES];
}

/** @ghidraAddress 0x1b8654 */
+ (void)markerMove:(NSString *)markerID bannerID:(NSString *)bannerID {
    [self copyMarkerItem:markerID isBanner:NO];
    [self copyMarkerItem:bannerID isBanner:YES];
}

#pragma mark - Path building

/** @ghidraAddress 0x1b86d0 */
+ (NSString *)getMarkerDirectoryPath {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *libraryDirectory = JubeatAppDelegate.appLibraryDirectory;
    NSString *privateDocuments =
        [libraryDirectory stringByAppendingPathComponent:kPrivateDocumentsComponent];
    NSError *error = nil;
    // The binary tests and creates the Library directory, not the private-documents path it just
    // appended, then reuses that same error out-parameter for the marker directory below.
    if (![fileManager fileExistsAtPath:libraryDirectory]) {
        [fileManager createDirectoryAtPath:libraryDirectory
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
    NSString *markerDirectory =
        [privateDocuments stringByAppendingPathComponent:kMarkerDirectoryComponent];
    if (![fileManager fileExistsAtPath:markerDirectory]) {
        [fileManager createDirectoryAtPath:markerDirectory
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
    return markerDirectory;
}

/** @ghidraAddress 0x1b884c */
+ (NSString *)getMarkerPath:(NSString *)name {
    NSString *directory = [self getMarkerDirectoryPath];
    NSString *fileName = [NSString stringWithFormat:kMarkerFileNameFormat, name];
    return [directory stringByAppendingPathComponent:fileName];
}

/** @ghidraAddress 0x1b8910 */
+ (NSString *)getMarkerBannerPath:(NSString *)name {
    NSString *bannerDirectory =
        [[self getMarkerDirectoryPath] stringByAppendingPathComponent:kBannerDirectoryComponent];
    NSString *fileName = [NSString stringWithFormat:kBannerFileNameFormat, name];
    return [bannerDirectory stringByAppendingPathComponent:fileName];
}

#pragma mark - List construction

/** @ghidraAddress 0x1b8a04 */
+ (BOOL)createDefaultMarkerList {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults removeObjectForKey:kPrefMarkerInfoList];
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *list = [[NSMutableArray alloc] init];
    for (int number = kFirstDefaultMarkerNumber; number != kDefaultMarkerNumberEnd; ++number) {
        NSMutableDictionary<NSString *, NSString *> *info = [[NSMutableDictionary alloc] init];
        NSString *markerID = [NSString stringWithFormat:kMarkerIDFormat, number];
        NSString *bannerName = [NSString stringWithFormat:kBannerNameFormat, number];
        info[kMarkerInfoKeyMarkerID] = markerID;
        info[kMarkerInfoKeyVersion] =
            (number == kInitialMarkerNumber) ? kVersionInitial : kVersionUninstalled;
        info[kMarkerInfoKeyBannerName] = bannerName;
        [list addObject:[NSDictionary dictionaryWithDictionary:info]];
    }
    NSString *currentMarkerID = [NSString stringWithFormat:kMarkerIDFormat, kInitialMarkerNumber];
    [self setMarkerList:list];
    [defaults setObject:currentMarkerID forKey:kPrefCurrentMarkerID];
    return YES;
}

/** @ghidraAddress 0x1b8c68 */
+ (BOOL)convertMarkerList {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSDictionary<NSString *, NSString *> *versionList =
        [defaults objectForKey:kPrefMarkerVersionList];
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *list = [[NSMutableArray alloc] init];
    BOOL allPresent = YES;
    for (int number = kFirstDefaultMarkerNumber; number != kDefaultMarkerNumberEnd; ++number) {
        NSString *markerID = [NSString stringWithFormat:kMarkerIDFormat, number];
        NSString *version = kVersionInitial;
        if (![self checkMarkerData:markerID]) {
            allPresent = NO;
            version = kVersionUninstalled;
        } else {
            NSString *stored = versionList[markerID];
            if (stored != nil) {
                version = stored;
            }
        }
        NSString *bannerName = [NSString stringWithFormat:kBannerNameFormat, number];
        NSMutableDictionary<NSString *, NSString *> *info = [[NSMutableDictionary alloc] init];
        info[kMarkerInfoKeyMarkerID] = markerID;
        info[kMarkerInfoKeyBannerName] = bannerName;
        info[kMarkerInfoKeyVersion] = version;
        [list addObject:[NSDictionary dictionaryWithDictionary:info]];
    }
    (void)[defaults integerForKey:kPrefMarker]; // Read for effect; the binary discards the result.
    NSString *currentMarkerID = [NSString stringWithFormat:kMarkerIDFormat, kInitialMarkerNumber];
    [self setMarkerList:list];
    [defaults setObject:currentMarkerID forKey:kPrefCurrentMarkerID];
    [defaults removeObjectForKey:kPrefMarkerVersionList];
    [defaults removeObjectForKey:kPrefMarker];
    return allPresent;
}

/** @ghidraAddress 0x1b8fe0 */
+ (BOOL)checkRegularMarkerData {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSDictionary<NSString *, NSString *> *versionList =
        [defaults objectForKey:kPrefMarkerVersionList];
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *list = [self getMarkerList];
    NSString *markerDirectory = [self getMarkerDirectoryPath];
    NSString *bannerDirectory =
        [markerDirectory stringByAppendingPathComponent:kBannerDirectoryComponent];
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSError *error = nil;
    if (![fileManager fileExistsAtPath:markerDirectory]) {
        [fileManager createDirectoryAtPath:markerDirectory
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
    if (![fileManager fileExistsAtPath:bannerDirectory]) {
        [fileManager createDirectoryAtPath:bannerDirectory
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
    if (list == nil) {
        if (versionList != nil) {
            [self convertMarkerList];
        } else {
            [self createDefaultMarkerList];
        }
        list = [self getMarkerList];
        if (list == nil) {
            return NO;
        }
    } else if (versionList != nil) {
        [defaults removeObjectForKey:kPrefMarkerVersionList];
    }
    for (NSUInteger i = 0; i < list.count; ++i) {
        NSDictionary<NSString *, NSString *> *info = list[i];
        if (![self checkMarkerData:info[kMarkerInfoKeyMarkerID]]) {
            NSMutableDictionary<NSString *, NSString *> *mutableInfo =
                [NSMutableDictionary dictionaryWithDictionary:info];
            mutableInfo[kMarkerInfoKeyVersion] = kVersionUninstalled;
            [list replaceObjectAtIndex:i
                            withObject:[NSDictionary dictionaryWithDictionary:mutableInfo]];
        }
    }
    for (NSUInteger i = 0; i < list.count; ++i) {
        NSDictionary<NSString *, NSString *> *info = list[i];
        NSString *markerPath = [self getMarkerPath:info[kMarkerInfoKeyMarkerID]];
        [self pullOutMarkerBanner:markerPath bannerID:info[kMarkerInfoKeyBannerName]];
    }
    [self setMarkerList:list];
    return YES;
}

#pragma mark - Selection

/** @ghidraAddress 0x1b94ec */
+ (BOOL)enableMarkerSelect {
    NSArray<NSDictionary<NSString *, NSString *> *> *list = [self getMarkerList];
    // Selection stays disabled while any reserved marker (an id below kReservedMarkerSize) is
    // still uninstalled, so the number test runs on the uninstalled entries, not the installed
    // ones.
    for (NSDictionary<NSString *, NSString *> *info in list) {
        if ([info[kMarkerInfoKeyVersion] isEqualToString:kVersionUninstalled]) {
            int number = [[info[kMarkerInfoKeyMarkerID]
                substringWithRange:NSMakeRange(kMarkerNumberRangeLocation,
                                               kMarkerNumberRangeLength)] intValue];
            if (number < kReservedMarkerSize) {
                return NO;
            }
        }
    }
    return YES;
}

#pragma mark - Migration

/** @ghidraAddress 0x1b96f4 */
+ (BOOL)moveMarkerDataInDoc {
    NSString *markerDirectory = [self getMarkerDirectoryPath];
    NSString *bannerDirectory =
        [markerDirectory stringByAppendingPathComponent:kBannerDirectoryComponent];
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSError *error = nil;
    if (![fileManager fileExistsAtPath:markerDirectory]) {
        [fileManager createDirectoryAtPath:markerDirectory
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
    if (![fileManager fileExistsAtPath:bannerDirectory]) {
        [fileManager createDirectoryAtPath:bannerDirectory
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
    NSString *markerID = [NSString stringWithFormat:kMarkerIDFormat, kInitialMarkerNumber];
    [self copyMarkerItem:markerID isBanner:NO];
    return YES;
}

@end
