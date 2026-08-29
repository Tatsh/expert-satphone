/**
 * @file
 * @brief Reconstructed interface for the applilink advert SDK's @c ApplilinkFile helper.
 *
 * @c ApplilinkFile is the SDK's stateless file and cache utility: it fetches banner, resource, and
 * data files from URLs (backed by an on-disk cache), saves, deletes, and tests files under a cache
 * folder tree rooted in the temporary directory, builds the cache path components, and prunes stale
 * cached files. The class has no instance state; every member is a class method.
 *
 * Reconstructed from Ghidra program Jubeat (class @c ApplilinkFile, image base @c 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The outcome of a cached-file fetch.
 *
 * Backed by @c int to match the 4-byte value the fetch methods return in @c w0.
 */
typedef NS_ENUM(int, ApplilinkFileFetchResult) {
    ApplilinkFileFetchResultFailure =
        0, /*!< The download or decode failed and nothing was cached. */
    ApplilinkFileFetchResultDownloaded =
        1, /*!< The file was downloaded and written to the cache. */
    ApplilinkFileFetchResultCached =
        2, /*!< The file was already present in the cache (or the URL was @c NSNull). */
};

/**
 * @brief Applilink SDK banner, resource, and data file cache utilities.
 */
@interface ApplilinkFile : NSObject

/**
 * @brief Fetch a banner image, caching it under the banner-image cache directory.
 *
 * When @p url is an @c NSNull, or the banner is already cached, the file is left untouched.
 * Otherwise the file is downloaded, decoded as a @c UIImage to validate it, and written to the
 * cache under the URL's trailing file-name component.
 * @param url The banner URL, or an @c NSNull to skip the fetch.
 * @return The fetch outcome.
 * @ghidraAddress 0x23750c
 */
+ (ApplilinkFileFetchResult)getBannerWithUrl:(nullable id)url;

/**
 * @brief Fetch a resource image, caching it under the resource cache directory.
 *
 * The resource is downloaded and validated as a @c UIImage before being written to the cache under
 * the URL's trailing file-name component; an already-cached resource is left untouched.
 * @param url The resource URL.
 * @return The fetch outcome.
 * @ghidraAddress 0x2376a4
 */
+ (ApplilinkFileFetchResult)getResourceWithUrl:(nullable NSString *)url;

/**
 * @brief Fetch a data file, caching it under the resource cache directory.
 *
 * Unlike @c +getResourceWithUrl: the payload is not decoded as an image; any downloaded data is
 * written to the cache under the URL's trailing file-name component.
 * @param url The data URL.
 * @return The fetch outcome.
 * @ghidraAddress 0x237800
 */
+ (ApplilinkFileFetchResult)getDataWithUrl:(nullable NSString *)url;

/**
 * @brief Fetch a data file, caching it under the cache-data directory.
 * @param url The data URL.
 * @return The fetch outcome.
 * @ghidraAddress 0x237920
 */
+ (ApplilinkFileFetchResult)getCacheDataWithUrl:(nullable NSString *)url;

/**
 * @brief Download the contents of a URL synchronously.
 * @param url The URL to download.
 * @return The downloaded data, or @c nil when the request failed.
 * @ghidraAddress 0x237a40
 */
+ (nullable NSData *)getFileWithUrl:(nullable NSString *)url;

/**
 * @brief Write data to a named file under a directory.
 * @param data The data to write.
 * @param file The file name to write under @p path.
 * @param path The directory to write into.
 * @ghidraAddress 0x237b3c
 */
+ (void)saveData:(nullable NSData *)data
            file:(nullable NSString *)file
            path:(nullable NSString *)path;

/**
 * @brief Delete a named file under a directory.
 * @param file The file name to delete under @p path.
 * @param path The directory containing the file.
 * @ghidraAddress 0x237bd8
 */
+ (void)deleteFile:(nullable NSString *)file path:(nullable NSString *)path;

/**
 * @brief Delete a file at a path.
 *
 * The path is deleted only when it is non-@c nil and non-empty.
 * @param path The path to delete.
 * @ghidraAddress 0x237c88
 */
+ (void)deleteFile:(nullable NSString *)path;

/**
 * @brief Test whether a named file exists under a directory.
 * @param file The file name to test under @p path.
 * @param path The directory to look in.
 * @return @c YES when the file exists.
 * @ghidraAddress 0x237d20
 */
+ (BOOL)existFile:(nullable NSString *)file path:(nullable NSString *)path;

/**
 * @brief Test whether a named image file exists and is loadable under a directory.
 *
 * When the file exists but cannot be decoded as a @c UIImage, it is deleted and @c NO is returned.
 * @param file The image file name to test under @p path.
 * @param path The directory to look in.
 * @return @c YES when the file exists and decodes as an image.
 * @ghidraAddress 0x237dd0
 */
+ (BOOL)existImageFile:(nullable NSString *)file path:(nullable NSString *)path;

/**
 * @brief Create the applilink cache folder tree if it is missing.
 *
 * Ensures the @c applilink directory in the temporary directory and, beneath its @c contents
 * subdirectory, the @c cache_img, @c cache_data, and @c res directories all exist.
 * @ghidraAddress 0x237f08
 */
+ (void)createFolder;

/**
 * @brief The @c applilink/contents directory under the temporary directory.
 * @return The contents directory path.
 * @ghidraAddress 0x238230
 */
+ (nullable NSString *)getContentsPath;

/**
 * @brief The banner-image cache directory (@c contents/cache_img).
 * @return The banner cache directory path.
 * @ghidraAddress 0x2382bc
 */
+ (nullable NSString *)getBannerCachePath;

/**
 * @brief The resource directory (@c contents/res).
 * @return The resource directory path.
 * @ghidraAddress 0x238320
 */
+ (nullable NSString *)getResourcePath;

/**
 * @brief The cache-data directory (@c contents/cache_data).
 * @return The cache-data directory path.
 * @ghidraAddress 0x238384
 */
+ (nullable NSString *)getCacheDataPath;

/**
 * @brief Build the HTML template path for an ad model and location.
 *
 * The file name is formatted as @c "<adModel>_<adLocation>.html" under the contents directory.
 * @param adModel The ad-model identifier.
 * @param adLocation The ad-location identifier.
 * @return The template file path.
 * @ghidraAddress 0x2383e8
 */
+ (nullable NSString *)getTemplatePathWithAdModel:(int)adModel
                                       adLocation:(nullable NSString *)adLocation;

/**
 * @brief Delete the entire contents directory tree.
 *
 * The selector keeps the binary's misspelling (@c delateFolder) verbatim.
 * @ghidraAddress 0x2384bc
 */
+ (void)delateFolder;

/**
 * @brief Prune stale banner-image cache files.
 *
 * Ensures the banner cache directory exists, then removes every file whose modification date is
 * more than one day old.
 * @ghidraAddress 0x238578
 */
+ (void)clearCacheBannerImage;

/**
 * @brief Prune stale cache-data files.
 *
 * Ensures the cache-data directory exists, then removes every file whose modification date is more
 * than one day old.
 * @ghidraAddress 0x23891c
 */
+ (void)clearCacheData;

/**
 * @brief Delete and recreate the banner-image cache directory.
 * @ghidraAddress 0x238cc0
 */
+ (void)allClearCacheBannerImage;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
