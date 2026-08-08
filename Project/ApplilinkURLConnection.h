/** @file
 * The applilink SDK's connection runner.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkURLConnection, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. The class object
 * is at 0x351df8.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What an @c ApplilinkURLConnection reports back while it runs a request.
 *
 * The protocol's name is the binary's own, from the delegate ivar's encoding
 * @c \@"<ApplilinkURLConnectionDelegate>" .
 */
@protocol ApplilinkURLConnectionDelegate <NSObject>
@optional
/**
 * @brief Sent when the request fails.
 * @param error The failure.
 */
- (void)failLoadWithError:(nullable NSError *)error;
/**
 * @brief Sent when the request completes, with the body decoded as a UTF-8 string.
 * @param response The decoded response body.
 */
- (void)finishLoadWithResponse:(nullable NSString *)response;
/**
 * @brief Asked before following a redirect.
 * @param request The redirect target.
 * @return Whether to intercept it.
 */
- (BOOL)redirectStartLoad:(nullable NSURLRequest *)request;
@end

/**
 * @brief Runs one @c NSURLConnection and reports its outcome to a delegate.
 */
@interface ApplilinkURLConnection : NSObject <NSURLConnectionDataDelegate>

/**
 * @brief The delegate told about the connection's outcome. Held weakly.
 * @ghidraAddress 0x231090 (getter)
 */
@property(nonatomic, weak, nullable) id<ApplilinkURLConnectionDelegate> connectionDelegate;

/**
 * @brief The buffer the response body is accumulated into.
 * @ghidraAddress 0x2310c4 (getter)
 */
@property(nonatomic, strong, nullable) NSMutableData *receivedData;

/**
 * @brief The response received for the current request.
 * @ghidraAddress 0x23110c (getter)
 */
@property(nonatomic, strong, nullable) NSURLResponse *responseData;

/**
 * @brief Starts a connection for a request and records the delegate.
 * @param request The request to run.
 * @param delegate The object to report back to.
 * @ghidraAddress 0x230c40
 */
- (void)loadRequestWithRequest:(nullable NSURLRequest *)request
                      delegate:(nullable id<ApplilinkURLConnectionDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
