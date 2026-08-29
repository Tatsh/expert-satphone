/**
 * @file
 * A one-shot NSURLSession image downloader keyed for a cache.
 *
 * Reconstructed from Ghidra program Jubeat (class ImageDownloader, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x34ed38.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ImageDownloader;

/**
 * Told when an @c ImageDownloader finishes loading its image.
 *
 * The protocol's name is the binary's own, from the delegate ivar's encoding
 * @c \@"<ImageDownloaderDelegate>" .
 */
@protocol ImageDownloaderDelegate <NSObject>
/**
 * Sent when the image has loaded.
 * @param downloader The downloader.
 * @param key The key the downloader was created with.
 */
- (void)imageDownloader:(nonnull ImageDownloader *)downloader didLoad:(nullable id)key;
@end

/**
 * Downloads one image over an @c NSURLSession and reports it to a delegate.
 */
@interface ImageDownloader : NSObject <NSURLSessionDataDelegate>

/** The image's URL. @ghidraAddress 0xff180 (getter) */
@property(nonatomic, readonly, nullable) NSURL *imageURL;
/** The cache key the download is associated with. @ghidraAddress 0xff1a0 (getter) */
@property(nonatomic, readonly, nullable) id key;
/** The delegate told when the image loads. Held weakly. @ghidraAddress 0xff158 (getter) */
@property(nonatomic, weak, nullable) id<ImageDownloaderDelegate> delegate;
/** Whether a download is in progress. @ghidraAddress 0xff1b4 (getter) */
@property(nonatomic, readonly, getter=isDownloading) BOOL downloading;

/**
 * Builds a downloader for an image URL and cache key.
 * @param imageURL The image's URL.
 * @param key The cache key.
 * @return The initialised downloader.
 * @ghidraAddress 0xfeb38
 */
- (instancetype)initWithImageURL:(nullable NSURL *)imageURL forKey:(nullable id)key;

/**
 * Starts the download.
 * @ghidraAddress 0xfebf0
 */
- (void)startDownload;

/**
 * Cancels the download.
 * @ghidraAddress 0xfedfc
 */
- (void)cancelDownload;

/**
 * The loaded image, or nil.
 * @return The loaded image, or nil when the download has not produced one.
 * @ghidraAddress 0xfee58
 */
- (nullable UIImage *)getImage;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
