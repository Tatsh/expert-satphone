/** @file
 * The HTTP client.
 *
 * Reconstructed from Ghidra program Jubeat (class Downloader, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. The class object is at 0x348250 and
 * @c -startDownloading alone has 98 cross-references, so essentially every server call in the
 * application goes through this class. Only the two members reached so far are declared.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Performs a single HTTP request.
 */
@protocol DownloaderDelegate <NSObject>
@optional
/**
 * @brief Sent when the request completes. The body is read back with @c -getData .
 * @param downloader The finished request.
 */
- (void)downloaderFinished:(id)downloader;
/**
 * @brief Sent when the request fails.
 * @param downloader The failed request.
 */
- (void)downloaderError:(id)downloader;
@end

@interface Downloader : NSObject

/**
 * @brief Builds a plain GET.
 *
 * DECLARED ONLY.
 *
 * @param url The endpoint.
 * @param delegate The object to report completion to, or nil.
 */
- (instancetype)initWithURL:(NSURL *)url delegate:(nullable id<DownloaderDelegate>)delegate;

/**
 * @brief The body the request returned. DECLARED ONLY.
 * @return The downloaded bytes.
 */
- (nullable NSData *)getData;

/**
 * @brief Abandons the request. DECLARED ONLY.
 */
- (void)cancel;

/**
 * @brief Builds a JSON POST.
 *
 * The delegate is @c nullable and the one reconstructed caller passes nil, which makes the request
 * fire-and-forget: nothing observes whether it succeeded. DECLARED ONLY.
 *
 * @param url The endpoint.
 * @param jsonData The serialised request body.
 * @param delegate The object to report completion to, or nil.
 */
- (instancetype)initWithURL:(NSURL *)url
               postJsonData:(NSData *)jsonData
                   delegate:(nullable id)delegate;
/**
 * @brief Starts the request. DECLARED ONLY.
 */
- (void)startDownloading;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
