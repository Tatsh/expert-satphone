/** @file
 * An image view that fetches its own artwork over HTTP.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreImageView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIImageView, from the dyld bind at the class object's superclass slot
 * (0x34e390).
 *
 * The downloader doubles as the busy flag: it is non-nil exactly while a fetch is in flight, and
 * every path that ends one clears it.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief An image view that loads itself from @c imageURL on demand.
 */
@interface StoreImageView : UIImageView <DownloaderDelegate>

/**
 * @brief Where to fetch the artwork from.
 * @ghidraAddress 0xd2058 (getter)
 */
@property(nonatomic, strong, nullable) NSString *imageURL;

/**
 * @brief The fetch in flight, or nil when none is.
 * @ghidraAddress 0xd207c (getter)
 */
@property(nonatomic, strong, nullable) Downloader *imageDownloader;

/**
 * @brief Starts fetching @c imageURL , unless there is no URL or a fetch is already running.
 * @ghidraAddress 0xd1c14
 */
- (void)startDownloadImage;

/**
 * @brief Cancels any fetch and puts a given image up instead.
 *
 * Despite the name it *sets* an image rather than clearing one — pass nil to blank the view.
 *
 * @param image The image to show.
 * @ghidraAddress 0xd1d74
 */
- (void)unloadImage:(nullable UIImage *)image;

/**
 * @brief Takes the fetched bytes as the view's image.
 *
 * On a Retina screen the image is rebuilt at the screen's scale, because @c -initWithData: always
 * decodes at scale 1 and would otherwise draw at twice its intended size.
 *
 * @param downloader The finished fetch.
 * @ghidraAddress 0xd1e24
 */
- (void)downloaderFinished:(id)downloader;

/**
 * @brief Clears the fetch. The view keeps whatever image it already had.
 * @param downloader The failed fetch. Unused.
 * @ghidraAddress 0xd1fd8
 */
- (void)downloaderError:(id)downloader;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
