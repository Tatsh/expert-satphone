#import "ApplilinkFile.h"

#import "ApplilinkUtilities.h"

// The maximum age, in seconds, a cached file may reach before the prune methods delete it. Read as
// the double 0x40f5180000000000 from the constant pool, which is 86400.0 (one day).
static const NSTimeInterval kCacheMaxAge = 86400.0;

// The name of the SDK's root directory under the temporary directory.
static NSString *const kApplilinkDirectory = @"applilink";
// The subdirectory of the SDK root holding all cached content.
static NSString *const kContentsDirectory = @"contents";
// The banner-image cache subdirectory of the contents directory.
static NSString *const kBannerCacheDirectory = @"cache_img";
// The data cache subdirectory of the contents directory.
static NSString *const kCacheDataDirectory = @"cache_data";
// The resource subdirectory of the contents directory.
static NSString *const kResourceDirectory = @"res";
// The format used to name an HTML template file from its ad model and location.
static NSString *const kTemplateFileNameFormat = @"%d_%@.html";

@implementation ApplilinkFile

#pragma mark - Fetching

+ (ApplilinkFileFetchResult)getBannerWithUrl:(id)url {
    if ([url isKindOfClass:NSNull.class]) {
        return ApplilinkFileFetchResultCached;
    }
    NSString *file = [ApplilinkUtilities getFileNameFromPath:url];
    NSString *path = [self getBannerCachePath];
    if ([self existImageFile:file path:path]) {
        return ApplilinkFileFetchResultCached;
    }
    NSData *data = [self getFileWithUrl:url];
    if (data == nil || [UIImage imageWithData:data] == nil) {
        return ApplilinkFileFetchResultFailure;
    }
    [self saveData:data file:file path:path];
    return ApplilinkFileFetchResultDownloaded;
}

+ (ApplilinkFileFetchResult)getResourceWithUrl:(NSString *)url {
    NSString *file = [ApplilinkUtilities getFileNameFromPath:url];
    NSString *path = [self getResourcePath];
    if ([self existImageFile:file path:path]) {
        return ApplilinkFileFetchResultCached;
    }
    NSData *data = [self getFileWithUrl:url];
    if (data == nil || [UIImage imageWithData:data] == nil) {
        return ApplilinkFileFetchResultFailure;
    }
    [self saveData:data file:file path:path];
    return ApplilinkFileFetchResultDownloaded;
}

+ (ApplilinkFileFetchResult)getDataWithUrl:(NSString *)url {
    NSString *file = [ApplilinkUtilities getFileNameFromPath:url];
    NSString *path = [self getResourcePath];
    if ([self existImageFile:file path:path]) {
        return ApplilinkFileFetchResultCached;
    }
    NSData *data = [self getFileWithUrl:url];
    if (data != nil) {
        [self saveData:data file:file path:path];
    }
    return data != nil ? ApplilinkFileFetchResultDownloaded : ApplilinkFileFetchResultFailure;
}

+ (ApplilinkFileFetchResult)getCacheDataWithUrl:(NSString *)url {
    NSString *file = [ApplilinkUtilities getFileNameFromPath:url];
    NSString *path = [self getCacheDataPath];
    if ([self existImageFile:file path:path]) {
        return ApplilinkFileFetchResultCached;
    }
    NSData *data = [self getFileWithUrl:url];
    if (data != nil) {
        [self saveData:data file:file path:path];
    }
    return data != nil ? ApplilinkFileFetchResultDownloaded : ApplilinkFileFetchResultFailure;
}

+ (NSData *)getFileWithUrl:(NSString *)url {
    NSURL *requestURL = [NSURL URLWithString:url];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:requestURL];
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:&error];
    if (error != nil) {
        return nil;
    }
    return data;
}

#pragma mark - Saving and deleting

+ (void)saveData:(NSData *)data file:(NSString *)file path:(NSString *)path {
    NSString *fullPath = [path stringByAppendingPathComponent:file];
    [data writeToFile:fullPath atomically:YES];
}

+ (void)deleteFile:(NSString *)file path:(NSString *)path {
    NSString *fullPath = [path stringByAppendingPathComponent:file];
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSError *error = nil;
    [fileManager removeItemAtPath:fullPath error:&error];
}

+ (void)deleteFile:(NSString *)path {
    if (path != nil && path.length != 0) {
        NSFileManager *fileManager = NSFileManager.defaultManager;
        NSError *error = nil;
        [fileManager removeItemAtPath:path error:&error];
    }
}

#pragma mark - Existence tests

+ (BOOL)existFile:(NSString *)file path:(NSString *)path {
    NSString *fullPath = [path stringByAppendingPathComponent:file];
    NSFileManager *fileManager = NSFileManager.defaultManager;
    return [fileManager fileExistsAtPath:fullPath];
}

+ (BOOL)existImageFile:(NSString *)file path:(NSString *)path {
    NSString *fullPath = [path stringByAppendingPathComponent:file];
    NSFileManager *fileManager = NSFileManager.defaultManager;
    if ([fileManager fileExistsAtPath:fullPath]) {
        if ([UIImage imageWithContentsOfFile:fullPath] != nil) {
            return YES;
        }
        if (file != nil && file.length != 0) {
            [self deleteFile:file];
        }
    }
    return NO;
}

#pragma mark - Folder management

+ (void)createFolder {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *applilinkPath =
        [NSTemporaryDirectory() stringByAppendingPathComponent:kApplilinkDirectory];
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:applilinkPath isDirectory:&isDirectory]) {
        NSError *error = nil;
        [fileManager createDirectoryAtPath:applilinkPath
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
    NSString *contentsPath = [applilinkPath stringByAppendingPathComponent:kContentsDirectory];
    isDirectory = NO;
    if (![fileManager fileExistsAtPath:contentsPath isDirectory:&isDirectory]) {
        NSError *error = nil;
        [fileManager createDirectoryAtPath:contentsPath
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
    NSString *bannerCachePath = [contentsPath stringByAppendingPathComponent:kBannerCacheDirectory];
    isDirectory = NO;
    if (![fileManager fileExistsAtPath:bannerCachePath isDirectory:&isDirectory]) {
        NSError *error = nil;
        [fileManager createDirectoryAtPath:bannerCachePath
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
    NSString *cacheDataPath = [contentsPath stringByAppendingPathComponent:kCacheDataDirectory];
    isDirectory = NO;
    if (![fileManager fileExistsAtPath:cacheDataPath isDirectory:&isDirectory]) {
        NSError *error = nil;
        [fileManager createDirectoryAtPath:cacheDataPath
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
    NSString *resourcePath = [contentsPath stringByAppendingPathComponent:kResourceDirectory];
    isDirectory = NO;
    if (![fileManager fileExistsAtPath:resourcePath isDirectory:&isDirectory]) {
        NSError *error = nil;
        [fileManager createDirectoryAtPath:resourcePath
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
}

+ (void)delateFolder {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *contentsPath = [self getContentsPath];
    BOOL isDirectory = NO;
    if ([fileManager fileExistsAtPath:contentsPath isDirectory:&isDirectory]) {
        NSError *error = nil;
        [fileManager removeItemAtPath:contentsPath error:&error];
    }
}

#pragma mark - Cache paths

+ (NSString *)getContentsPath {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:kApplilinkDirectory];
    return [path stringByAppendingPathComponent:kContentsDirectory];
}

+ (NSString *)getBannerCachePath {
    return [[self getContentsPath] stringByAppendingPathComponent:kBannerCacheDirectory];
}

+ (NSString *)getResourcePath {
    return [[self getContentsPath] stringByAppendingPathComponent:kResourceDirectory];
}

+ (NSString *)getCacheDataPath {
    return [[self getContentsPath] stringByAppendingPathComponent:kCacheDataDirectory];
}

+ (NSString *)getTemplatePathWithAdModel:(int)adModel adLocation:(NSString *)adLocation {
    NSString *fileName = [NSString stringWithFormat:kTemplateFileNameFormat, adModel, adLocation];
    return [[self getContentsPath] stringByAppendingPathComponent:fileName];
}

#pragma mark - Cache pruning

+ (void)clearCacheBannerImage {
    [self clearCacheInDirectory:[self getBannerCachePath]];
}

+ (void)clearCacheData {
    [self clearCacheInDirectory:[self getCacheDataPath]];
}

+ (void)allClearCacheBannerImage {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *bannerCachePath = [self getBannerCachePath];
    BOOL isDirectory = NO;
    if ([fileManager fileExistsAtPath:bannerCachePath isDirectory:&isDirectory]) {
        NSError *error = nil;
        [fileManager removeItemAtPath:bannerCachePath error:&error];
    }
    [self createFolder];
}

#pragma mark - Private

// Shared body of +clearCacheBannerImage (0x238578) and +clearCacheData (0x23891c), which are
// byte-for-byte identical apart from the directory each prunes. Ensures the directory exists, then
// deletes every file in it older than kCacheMaxAge.
+ (void)clearCacheInDirectory:(NSString *)directory {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    NSError *error = nil;
    if (![fileManager fileExistsAtPath:directory isDirectory:&isDirectory]) {
        [fileManager createDirectoryAtPath:directory
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
    NSArray<NSString *> *entries = [fileManager contentsOfDirectoryAtPath:directory error:&error];
    for (NSString *entry in entries) {
        NSString *fullPath = [directory stringByAppendingPathComponent:entry];
        if (![fileManager fileExistsAtPath:fullPath]) {
            continue;
        }
        NSError *attributesError = nil;
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath
                                                                 error:&attributesError];
        if (attributesError != nil) {
            continue;
        }
        NSTimeInterval age = [NSDate.date timeIntervalSinceDate:attributes.fileModificationDate];
        if (age > kCacheMaxAge) {
            [fileManager removeItemAtPath:fullPath error:nil];
        }
    }
}

@end
