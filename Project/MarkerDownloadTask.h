/**
 * @file
 * @brief One queued marker download.
 *
 * Reconstructed from Ghidra program Jubeat (class MarkerDownloadTask, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares one method beyond the property
 * accessors and it is implemented.
 *
 * The superclass binds to @c _OBJC_CLASS_$_NSObject at load time; it is not stored in the file.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A source and destination pair describing one marker download.
 */
@interface MarkerDownloadTask : NSObject

/**
 * @brief Where to fetch from.
 *
 * An @c NSString despite the name and despite the initialiser's @c URL keyword. The property
 * metadata encodes it as @c T@"NSString" and the initialiser stores its argument straight into it
 * with no conversion, so the argument is a string too.
 */
@property(nonatomic, strong, nullable) NSString *sourceURL;
/** @brief Where to write it. */
@property(nonatomic, strong, nullable) NSString *destPath;

/**
 * @brief Records a download to perform later.
 * @param url The source, as a string.
 * @param path The destination path.
 * @return The initialised task.
 * @ghidraAddress 0x87c60
 */
- (instancetype)initWithURL:(nullable NSString *)url path:(nullable NSString *)path;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
