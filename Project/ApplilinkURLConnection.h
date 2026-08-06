/** @file
 * The applilink SDK's connection runner.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkURLConnection, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the one member reached so far
 * is declared.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c ApplilinkURLConnection reports back while it runs a request.
 *
 * The protocol is inferred from the callbacks @c DestinationCore implements, not from a declared
 * conformance in the metadata.
 */
@protocol ApplilinkURLConnectionDelegate <NSObject>
@optional
/**
 * @brief Sent when the request fails.
 * @param error The failure.
 */
- (void)failLoadWithError:(nullable NSError *)error;
/**
 * @brief Sent when the request completes.
 * @param response The response.
 */
- (void)finishLoadWithResponse:(nullable NSURLResponse *)response;
/**
 * @brief Asked before following a redirect.
 * @param request The redirect target.
 * @return Whether to follow it.
 */
- (BOOL)redirectStartLoad:(nullable NSURLRequest *)request;
@end

/**
 * @brief Runs one request and reports back to a delegate.
 */
@interface ApplilinkURLConnection : NSObject

/**
 * @brief Starts the request.
 *
 * DECLARED ONLY.
 *
 * @param request The request to run.
 * @param delegate The object to report back to.
 */
- (void)loadRequestWithRequest:(nullable NSURLRequest *)request
                      delegate:(nullable id<ApplilinkURLConnectionDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
