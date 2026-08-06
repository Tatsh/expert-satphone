/** @file
 * The applilink SDK's request builder.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkWebAPI, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the one member reached so far
 * is declared.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Builds the SDK's HTTP requests.
 */
@interface ApplilinkWebAPI : NSObject

/**
 * @brief Builds one request.
 *
 * DECLARED ONLY. The timeout is a @c float and the cache policy is an object, both from the
 * selector's type encoding @c \@52\@0:8\@16\@24\@32f40\@44 — not an @c NSTimeInterval and not an
 * @c NSURLRequestCachePolicy, which is what the names would otherwise suggest.
 *
 * @param url The absolute URL.
 * @param method The HTTP method.
 * @param parameters The already-joined query string.
 * @param timeout The timeout in seconds.
 * @param cachePolicy The cache policy, or nil for the default.
 * @return The request.
 */
- (nullable NSURLRequest *)requestWithURL:(nullable NSString *)url
                                   method:(nullable NSString *)method
                               parameters:(nullable NSString *)parameters
                                  timeout:(float)timeout
                              cachePolicy:(nullable id)cachePolicy;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
