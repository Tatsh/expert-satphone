#import "TweetResourceManager.h"

#import <CommonCrypto/CommonDigest.h>

#import "GameNetworkUtil.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "Md5Utilities.h"

// The frame-descriptor dictionary keys.
static NSString *const kSerialKey = @"serial";
static NSString *const kItemNameKey = @"itemName";
static NSString *const kVersionKey = @"version";
static NSString *const kItemTypeKey = @"itemType";
static NSString *const kTermTypeKey = @"termType";
static NSString *const kTermsTableKey = @"termsTable";
static NSString *const kFileNameKey = @"fileName";

// The four bundled background frames' internal item names and on-disk directory names.
static NSString *const kDefaultItemName = @"twBgDefault";
static NSString *const kClassicItemName = @"twBgClassic";
static NSString *const kRipplesItemName = @"twBgRipples";
static NSString *const kKnitItemName = @"twBgKnit";
static NSString *const kDefaultFrameName = @"shareData";
static NSString *const kClassicFrameName = @"classic";
static NSString *const kRipplesFrameName = @"ripples";
static NSString *const kKnitFrameName = @"knit";

// The on-disk resource layout: <Library>/Private Documents/appendData/<frameName>/.
static NSString *const kPrivateDocumentsDirectoryName = @"Private Documents";
static NSString *const kAppendDataDirectoryName = @"appendData";
static NSString *const kFrameArchiveFileName = @"twitterResources.zip";

// The name entry stored inside a frame archive, at twitterResources/filename.txt.
static NSString *const kArchiveResourceDirectory = @"twitterResources";
static NSString *const kArchiveNameEntryFile = @"filename.txt";

// The bundled archives, packaged as twitterResources.zip under appendData/<frameName> in the app
// bundle.
static NSString *const kBundleResourceName = @"twitterResources";
static NSString *const kBundleResourceType = @"zip";
static NSString *const kBundleSubdirectoryFormat = @"appendData/%@";

// The frame's itemType: only background frames (itemType 0) carry a downloadable archive.
enum { kFrameItemTypeBackground = 0 };

// The frame's termType: 0 is always free, 1 is unlocked once the install count reaches the frame's
// first termsTable threshold.
enum { kFrameTermTypeFree = 0, kFrameTermTypeInstallCount = 1 };

@interface TweetResourceManager ()
/** @ghidraAddress 0x79580 */
- (nullable NSArray<NSDictionary *> *)readResourceList;
@end

@implementation TweetResourceManager {
    NSArray<NSDictionary *> *resourceList;
    int insAppNum;
}

#pragma mark - Singleton

/** @ghidraAddress 0x79434 */
+ (instancetype)sharedManager {
    static TweetResourceManager *g_pTweetResourceManagerShared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x79474 */
      g_pTweetResourceManagerShared = [[TweetResourceManager alloc] init];
    });
    return g_pTweetResourceManagerShared;
}

/** @ghidraAddress 0x794b4 */
- (instancetype)init {
    self = [super init];
    if (self) {
        resourceList = [self readResourceList];
        insAppNum = [GameNetworkUtil readInstallAppNum];
    }
    return self;
}

#pragma mark - Accessors

/** @ghidraAddress 0x79550 */
- (NSArray<NSDictionary *> *)getResourceList {
    return resourceList;
}

/** @ghidraAddress 0x79570 */
- (int)getInstallApplicationNum {
    return insAppNum;
}

/** @ghidraAddress 0x79560 */
- (void)setInstallApplicationNum:(int)installApplicationNum {
    insAppNum = installApplicationNum;
}

#pragma mark - Catalogue

/** @ghidraAddress 0x79580 */
- (NSArray<NSDictionary *> *)readResourceList {
    NSDictionary *defaultFrame = @{
        kSerialKey : @0,
        kItemNameKey : kDefaultItemName,
        kVersionKey : @1.0f,
        kItemTypeKey : @0,
        kTermTypeKey : @0,
        kTermsTableKey : @[ @0 ],
        kFileNameKey : kDefaultFrameName
    };
    NSDictionary *classicFrame = @{
        kSerialKey : @1,
        kItemNameKey : kClassicItemName,
        kVersionKey : @1.0f,
        kItemTypeKey : @0,
        kTermTypeKey : @0,
        kTermsTableKey : @[ @2 ],
        kFileNameKey : kClassicFrameName
    };
    NSDictionary *ripplesFrame = @{
        kSerialKey : @2,
        kItemNameKey : kRipplesItemName,
        kVersionKey : @1.0f,
        kItemTypeKey : @0,
        kTermTypeKey : @0,
        kTermsTableKey : @[ @4 ],
        kFileNameKey : kRipplesFrameName
    };
    NSDictionary *knitFrame = @{
        kSerialKey : @3,
        kItemNameKey : kKnitItemName,
        kVersionKey : @1.0f,
        kItemTypeKey : @0,
        kTermTypeKey : @0,
        kTermsTableKey : @[ @6 ],
        kFileNameKey : kKnitFrameName
    };
    return [NSArray arrayWithArray:@[ defaultFrame, classicFrame, ripplesFrame, knitFrame ]];
}

#pragma mark - Resource layout

/** @ghidraAddress 0x79c4c */
+ (NSString *)getAppendResourcePath {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *library = JubeatAppDelegate.appLibraryDirectory;
    NSString *privateDocuments =
        [library stringByAppendingPathComponent:kPrivateDocumentsDirectoryName];
    NSString *appendData =
        [privateDocuments stringByAppendingPathComponent:kAppendDataDirectoryName];
    if (![fileManager fileExistsAtPath:library]) {
        [fileManager createDirectoryAtPath:library
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:nil];
    }
    if (![fileManager fileExistsAtPath:privateDocuments]) {
        [fileManager createDirectoryAtPath:privateDocuments
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:nil];
    }
    if (![fileManager fileExistsAtPath:appendData]) {
        [fileManager createDirectoryAtPath:appendData
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:nil];
    }
    return appendData;
}

/** @ghidraAddress 0x79e1c */
+ (NSString *)getFrameDirectoryPath:(NSString *)frameName {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *directory = [[self getAppendResourcePath] stringByAppendingPathComponent:frameName];
    if (![fileManager fileExistsAtPath:directory]) {
        [fileManager createDirectoryAtPath:directory
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:nil];
    }
    return directory;
}

/** @ghidraAddress 0x79f10 */
+ (NSString *)getFrameFilePath:(NSString *)frameName {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *directory = [[self getAppendResourcePath] stringByAppendingPathComponent:frameName];
    NSString *file = [directory stringByAppendingPathComponent:kFrameArchiveFileName];
    if (![fileManager fileExistsAtPath:directory] || ![fileManager fileExistsAtPath:file]) {
        return nil;
    }
    return file;
}

#pragma mark - Integrity

/** @ghidraAddress 0x7a03c */
+ (BOOL)checkResourceName:(NSData *)data dirName:(NSString *)dirName {
    KUnzip *archive =
        [[KUnzip alloc] initWithData:data range:NSMakeRange(0, data.length - CC_MD5_DIGEST_LENGTH)];
    NSString *entry =
        [kArchiveResourceDirectory stringByAppendingPathComponent:kArchiveNameEntryFile];
    NSData *nameData = [archive uncompress:entry];
    if (nameData) {
        NSString *storedName = [[NSString alloc] initWithData:nameData
                                                     encoding:NSUTF8StringEncoding];
        if ([dirName isEqualToString:storedName]) {
            return YES;
        }
    }
    return NO;
}

/** @ghidraAddress 0x7a19c */
+ (BOOL)checkMD5:(NSData *)data {
    if (data && data.length > CC_MD5_DIGEST_LENGTH) {
        unsigned char digest[CC_MD5_DIGEST_LENGTH];
        [data getBytes:digest
                 range:NSMakeRange(data.length - CC_MD5_DIGEST_LENGTH, CC_MD5_DIGEST_LENGTH)];
        if (VerifyMd5Digest(
                data.bytes, (unsigned int)(data.length - CC_MD5_DIGEST_LENGTH), digest)) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Resource data

/** @ghidraAddress 0x7a298 */
+ (KUnzip *)getResourceData:(NSString *)frameName {
    NSData *data = nil;
    NSString *file = [self getFrameFilePath:frameName];
    if (file) {
        data = [NSData dataWithContentsOfFile:file];
        if ([self checkMD5:data] && data) {
            return [[KUnzip alloc] initWithData:data
                                          range:NSMakeRange(0, data.length - CC_MD5_DIGEST_LENGTH)];
        }
    }
    // Fall back to the default frame's archive.
    file = [self getFrameFilePath:kDefaultFrameName];
    if (file) {
        data = [NSData dataWithContentsOfFile:file];
        if ([self checkMD5:data]) {
            return [[KUnzip alloc] initWithData:data
                                          range:NSMakeRange(0, data.length - CC_MD5_DIGEST_LENGTH)];
        }
    }
    return nil;
}

/** @ghidraAddress 0x7a430 */
+ (BOOL)checkResourceData {
    NSArray<NSDictionary *> *list = [[self sharedManager] getResourceList];
    NSMutableArray<NSString *> *fileNames = [[NSMutableArray alloc] init];
    for (NSDictionary *info in list) {
        if ([info[kItemTypeKey] intValue] == kFrameItemTypeBackground) {
            [fileNames addObject:info[kFileNameKey]];
        }
    }
    BOOL valid = YES;
    for (NSString *name in fileNames) {
        NSString *file = [self getFrameFilePath:name];
        if (!file) {
            valid = NO;
            continue;
        }
        NSData *data = [NSData dataWithContentsOfFile:file];
        if (![self checkMD5:data]) {
            [self removeResourceData:name];
            valid = NO;
            continue;
        }
        if ([self checkResourceName:data dirName:name]) {
            continue;
        }
        [self removeResourceData:name];
        valid = NO;
    }
    return valid;
}

/** @ghidraAddress 0x7a7fc */
+ (void)removeResourceData:(NSString *)frameName {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *file = [[self getFrameDirectoryPath:frameName]
        stringByAppendingPathComponent:kFrameArchiveFileName];
    if ([fileManager fileExistsAtPath:file]) {
        [fileManager removeItemAtPath:file error:nil];
    }
}

/** @ghidraAddress 0x7a8f4 */
+ (BOOL)moveResourceDataInDoc {
    NSArray<NSDictionary *> *list = [[self sharedManager] getResourceList];
    NSMutableArray<NSString *> *fileNames = [[NSMutableArray alloc] init];
    for (NSDictionary *info in list) {
        if ([info[kItemTypeKey] intValue] == kFrameItemTypeBackground) {
            [fileNames addObject:info[kFileNameKey]];
        }
    }
    NSFileManager *fileManager = NSFileManager.defaultManager;
    for (NSString *name in fileNames) {
        NSString *subdirectory = [NSString stringWithFormat:kBundleSubdirectoryFormat, name];
        NSString *source = [NSBundle.mainBundle pathForResource:kBundleResourceName
                                                         ofType:kBundleResourceType
                                                    inDirectory:subdirectory];
        NSString *destination = [[self getFrameDirectoryPath:name]
            stringByAppendingPathComponent:kFrameArchiveFileName];
        if ([fileManager fileExistsAtPath:destination]) {
            [fileManager removeItemAtPath:destination error:nil];
        }
        [fileManager copyItemAtPath:source toPath:destination error:nil];
    }
    // The binary discards every copy result and returns a fixed NO.
    return NO;
}

#pragma mark - Selection

/** @ghidraAddress 0x7ad84 */
+ (BOOL)checkEnableSelecteFrame:(NSString *)frameName {
    if (!frameName) {
        return NO;
    }
    NSArray<NSDictionary *> *list = [[self sharedManager] getResourceList];
    int installNum = [[self sharedManager] getInstallApplicationNum];
    for (NSDictionary *info in list) {
        if ([info[kItemTypeKey] intValue] != kFrameItemTypeBackground) {
            continue;
        }
        if (![info[kFileNameKey] isEqualToString:frameName]) {
            continue;
        }
        int termType = [info[kTermTypeKey] intValue];
        if (termType == kFrameTermTypeFree) {
            return YES;
        }
        if (termType == kFrameTermTypeInstallCount &&
            [info[kTermsTableKey][0] intValue] <= installNum) {
            return YES;
        }
        return NO;
    }
    return NO;
}

@end
