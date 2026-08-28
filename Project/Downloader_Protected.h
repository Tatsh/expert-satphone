/** @file
 * The @c Downloader ivars shared with its @c SessionDownloader subclass.
 *
 * The binary's @c SessionDownloader reads and writes @c Downloader 's own request, session, task,
 * data, size, and delegate slots directly by offset (it is a compiled subclass in the same image),
 * so the reconstruction exposes them here for the subclass to see. These offset globals are listed
 * on each ivar; @c Downloader.m and @c SessionDownloader.m both import this header.
 */

#import <Foundation/Foundation.h>

#import "Downloader.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The @c Downloader ivars its @c SessionDownloader subclass reaches directly.
 */
@interface Downloader () {
@public
    /** The request being run. */
    NSURLRequest *request; // offset global 0x34a36c
    /** The session the request runs on. */
    NSURLSession *session; // offset global 0x34a378
    /** The task carrying the request. */
    NSURLSessionTask *sessionTask; // offset global 0x34a37c
    /** The response body accumulated so far. */
    NSMutableData *data; // offset global 0x34a380
    /** The total byte count the response declared. */
    int64_t dl_size; // offset global 0x34a384
    // Weak, from the objc_storeWeak at 0xa7e60 and every clear at 0xa83c4/0xa889c via 0x27cf74, and
    // every read via objc_loadWeakRetained. The encoding is a bare @ and records none of that.
    /** The object told how the request finished. */
    __weak id<DownloaderDelegate> delegate; // offset global 0x34a370
    /** The caller's tag, distinguishing concurrent requests sharing one delegate. */
    int _tag; // offset global 0x34a374
}
@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
