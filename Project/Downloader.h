/** @file
 * The HTTP client.
 *
 * Reconstructed from Ghidra program Jubeat (class Downloader, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject , from the dyld bind at the class object's superclass slot
 * (0x34db18 + 8).
 *
 * The class is a thin wrapper around @c NSURLSession : it builds an @c NSMutableURLRequest , starts
 * a data task on the main queue, accumulates the bytes into an @c NSMutableData , and reports back
 * through a weak delegate. Every server call in the application goes through it — 98
 * cross-references to @c -startDownloading alone.
 *
 * The delegate is weak: every store goes through @c objc_storeWeak (0x27cf74 at 0xa7e60, 0xa83c4,
 * 0xa889c) and every read through @c objc_loadWeakRetained. The ivar's encoding is a bare @ and
 * records none of that, so the decompile shows plain assignments.
 *
 * The class is complete: all seventeen hand-written members are recovered.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Performs a single HTTP request.
 */
@protocol DownloaderDelegate <NSObject>
@optional
/**
 * @brief Sent periodically as data arrives, and once more on completion.
 * @param downloader The request.
 */
- (void)downloaderProceed:(id)downloader;
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

@interface Downloader : NSObject <NSURLSessionDataDelegate>

/**
 * @brief Builds a plain GET.
 *
 * @param url The endpoint.
 * @param delegate The object to report completion to, or nil. Stored weakly.
 * @return The initialised request.
 * @ghidraAddress 0xa7d4c
 */
- (instancetype)initWithURL:(NSURL *)url delegate:(nullable id<DownloaderDelegate>)delegate;

/**
 * @brief Builds a JSON POST.
 *
 * @param url The endpoint.
 * @param jsonData The serialised request body.
 * @param delegate The object to report completion to, or nil. Stored weakly.
 * @return The initialised request.
 * @ghidraAddress 0xa7e9c
 */
- (instancetype)initWithURL:(NSURL *)url
               postJsonData:(NSData *)jsonData
                   delegate:(nullable id<DownloaderDelegate>)delegate;

/**
 * @brief Builds a POST with an arbitrary body.
 *
 * @param url The endpoint.
 * @param postData The request body.
 * @param delegate The object to report completion to, or nil. Stored weakly.
 * @return The initialised request.
 * @ghidraAddress 0xa80a8
 */
- (instancetype)initWithURL:(NSURL *)url
                   postData:(NSData *)postData
                   delegate:(nullable id<DownloaderDelegate>)delegate;

/**
 * @brief Starts the request.
 *
 * Cancels any previous session task first, then creates a new @c NSURLSession on the main queue
 * and resumes its data task.
 * @ghidraAddress 0xa8298
 */
- (void)startDownloading;

/**
 * @brief Abandons the request.
 *
 * Clears the weak delegate, cancels the session task, and drops the accumulated data.
 * @ghidraAddress 0xa83a4
 */
- (void)cancel;

/**
 * @brief Cancels the current session task and clears it.
 * @ghidraAddress 0xa88e0
 */
- (void)connectionCancel;

/**
 * @brief The total bytes downloaded so far.
 * @return The length of the accumulated data, or 0 when none.
 * @ghidraAddress 0xa8710
 */
- (unsigned long long)currentSize;

/**
 * @brief The fraction of the expected total that has arrived.
 * @return Progress in [0,1], or 0 when the expected length is unknown or already exceeded.
 * @ghidraAddress 0xa8728
 */
- (float)currentProgress;

/**
 * @brief The body the request returned.
 * @return The downloaded bytes, or nil before completion.
 * @ghidraAddress 0xa8794
 */
- (nullable NSData *)getData;

/**
 * @brief The body the request returned, parsed as JSON.
 *
 * Returns nil rather than raising when the body is missing or will not parse, which is what
 * @c -[LogoViewController downloaderFinished:] tests before reading any key out of it.
 *
 * @return The parsed body, or nil.
 * @ghidraAddress 0xa87a4
 */
- (nullable NSDictionary *)getDataInJSON;

/**
 * @brief An integer tag the caller may attach to the request.
 * @ghidraAddress 0xa891c
 */
@property(nonatomic) int tag;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
