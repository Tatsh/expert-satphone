/**
 * @file
 * The tweet/result-frame resource manager.
 *
 * Reconstructed from Ghidra program Jubeat (class TweetResourceManager, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. The class object is at
 * 0x3480d8.
 *
 * Owns the catalogue of result-screen frame backgrounds used when composing a score tweet, and the
 * on-disk layout under the app's Library directory that stores each frame's downloaded
 * @c twitterResources.zip archive. Every archive carries a trailing MD5 digest that is verified
 * before use, and the bundled copies are migrated into that layout on first launch.
 */

#import <Foundation/Foundation.h>

@class KUnzip;

NS_ASSUME_NONNULL_BEGIN

/**
 * Owns the frame-background catalogue and the enciphered archives that back each frame.
 */
@interface TweetResourceManager : NSObject

/**
 * The shared instance, built once.
 * @return The shared manager.
 * @ghidraAddress 0x79434
 */
+ (instancetype)sharedManager;

/**
 * The path of the append-data directory, creating it and its parents on demand.
 *
 * The directory is @c \<Library\>/Private Documents/appendData ; the method creates the library
 * directory, the @c Private Documents directory, and the @c appendData directory in turn when any
 * is absent.
 * @return The @c appendData directory path.
 * @ghidraAddress 0x79c4c
 */
+ (NSString *)getAppendResourcePath;

/**
 * The directory that holds one frame's archive, creating it on demand.
 * @param frameName The frame's directory name (its @c fileName catalogue value).
 * @return The frame's directory path under the append-data directory.
 * @ghidraAddress 0x79e1c
 */
+ (NSString *)getFrameDirectoryPath:(NSString *)frameName;

/**
 * The path of one frame's @c twitterResources.zip archive when it exists on disk.
 * @param frameName The frame's directory name.
 * @return The archive path, or nil when either the frame directory or the archive is absent.
 * @ghidraAddress 0x79f10
 */
+ (nullable NSString *)getFrameFilePath:(NSString *)frameName;

/**
 * Verifies that a frame archive names the expected directory.
 *
 * Opens @p data as an archive (stripping its trailing sixteen-byte digest), reads the
 * @c twitterResources/filename.txt entry, and compares its UTF-8 contents to @p dirName.
 * @param data The archive bytes, digest included.
 * @param dirName The expected frame directory name.
 * @return @c YES when the archive's stored name matches @p dirName, @c NO otherwise.
 * @ghidraAddress 0x7a03c
 */
+ (BOOL)checkResourceName:(NSData *)data dirName:(NSString *)dirName;

/**
 * Verifies a frame archive against its trailing MD5 digest.
 *
 * The last sixteen bytes are the expected digest; the MD5 is taken over everything before them.
 * @param data The archive bytes, digest included.
 * @return @c YES when the digest matches and @p data is longer than the digest, @c NO otherwise.
 * @ghidraAddress 0x7a19c
 */
+ (BOOL)checkMD5:(nullable NSData *)data;

/**
 * Opens a frame's archive, falling back to the default frame when it is missing or corrupt.
 *
 * Loads @p frameName 's archive, verifies its digest, and returns it as an archive reader with the
 * trailing digest stripped. When that fails it retries with the default frame. The bytes still need
 * deciphering by the caller.
 * @param frameName The requested frame's directory name.
 * @return The archive reader, or nil when neither the requested nor the default frame is usable.
 * @ghidraAddress 0x7a298
 */
+ (nullable KUnzip *)getResourceData:(NSString *)frameName;

/**
 * Verifies every catalogued background frame's archive, deleting any that fails.
 *
 * Walks the frames whose @c itemType is zero, and for each confirms the archive is present, its
 * MD5 digest matches, and its stored directory name is correct; a failing archive is removed.
 * @return @c YES when every frame's archive is present and valid, @c NO otherwise.
 * @ghidraAddress 0x7a430
 */
+ (BOOL)checkResourceData;

/**
 * Deletes a frame's stored archive.
 * @param frameName The frame's directory name.
 * @ghidraAddress 0x7a7fc
 */
+ (void)removeResourceData:(NSString *)frameName;

/**
 * Copies each bundled background-frame archive into the append-data layout.
 *
 * For every frame whose @c itemType is zero, copies @c twitterResources.zip out of the app bundle's
 * @c appendData/\<frameName\> directory into the frame's on-disk directory, replacing any existing
 * copy.
 * @return Always @c NO ; the binary discards the per-frame copy results and returns a fixed value.
 * @ghidraAddress 0x7a8f4
 */
+ (BOOL)moveResourceDataInDoc;

/**
 * Reports whether a persisted frame selection is currently unlocked.
 *
 * Finds the background frame whose @c fileName equals @p frameName and reports it enabled when it
 * is unconditionally free (@c termType zero) or unlocked by the install count reaching the frame's
 * threshold (@c termType one).
 * @param frameName The persisted frame selection's directory name.
 * @return @c YES when the frame exists and is unlocked, @c NO otherwise.
 * @ghidraAddress 0x7ad84
 */
+ (BOOL)checkEnableSelecteFrame:(nullable NSString *)frameName;

/**
 * The frame-background catalogue, each entry a descriptor dictionary.
 * @return The catalogue array.
 * @ghidraAddress 0x79550
 */
- (nullable NSArray<NSDictionary *> *)getResourceList;

/**
 * The cached install-application count, seeded from the reward store at init.
 * @return The install count.
 * @ghidraAddress 0x79570
 */
- (int)getInstallApplicationNum;

/**
 * Sets the cached install-application count.
 * @param installApplicationNum The new count.
 * @ghidraAddress 0x79560
 */
- (void)setInstallApplicationNum:(int)installApplicationNum;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
