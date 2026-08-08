/** @file
 * The session-signed HTTP client.
 *
 * Reconstructed from Ghidra program Jubeat (class SessionDownloader, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c Downloader , from the @c objc_msgSendSuper2 @c init at 0xffe6c; the
 * overrides reach @c Downloader 's own request/session/task/data/delegate slots through
 * @c Downloader_Protected.h .
 *
 * Every request is signed: a SHA-256 MAC of the body plus a fixed salt goes out in @c
 * JBT_REQUEST_MAC and the response's @c JBT_RESPONSE_MAC is verified the same way. When the server
 * reports a stale session the client transparently re-opens one against @c +[ScratchUtil
 * challengeSessionURL] and retries, up to five times for ordinary failures.
 */

#import <Foundation/Foundation.h>

#import "Downloader.h"

NS_ASSUME_NONNULL_BEGIN

@interface SessionDownloader : Downloader

/**
 * @brief Builds a signed POST from a URL and a parameter dictionary.
 *
 * Copies @p postDictionary, ensures it carries a @c cnonce (a random one when absent), merges every
 * @c +[JubeatAppDelegate clientInfo] entry, JSON-serialises it, and chains to
 * @c -initWithURL:postData:delegate: .
 * @param url The endpoint.
 * @param postDictionary The request parameters.
 * @param delegate The object told how the request finished.
 * @return The initialised client.
 * @ghidraAddress 0xff324
 */
- (instancetype)initWithURL:(nullable NSURL *)url
             postDictionary:(nullable NSDictionary *)postDictionary
                   delegate:(nullable id)delegate;

/**
 * @brief Builds a signed GET-style request that carries a fresh random @c cnonce.
 * @param url The endpoint.
 * @param delegate The object told how the request finished.
 * @return The initialised client.
 * @ghidraAddress 0xffb48
 */
- (instancetype)initWithURL:(nullable NSURL *)url delegate:(nullable id)delegate;

/**
 * @brief Builds a signed POST from a URL and a ready request body.
 * @param url The endpoint.
 * @param postData The request body.
 * @param delegate The object told how the request finished.
 * @return The initialised client.
 * @ghidraAddress 0xffe1c
 */
- (instancetype)initWithURL:(nullable NSURL *)url
                   postData:(nullable NSData *)postData
                   delegate:(nullable id)delegate;

/**
 * @brief The request's API tag, used to decide the session-retry behaviour.
 * @ghidraAddress 0x100e3c
 */
@property(nonatomic) int apiTag;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
