/**
 * @file
 * Registers a destination URL with the applilink advertising back end.
 *
 * Reconstructed from Ghidra program Jubeat (class DestinationCore, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject, from the dyld bind at the class object's superclass slot
 * (0x352468). The class declares no ivars; its four metadata properties are @c NSObject protocol
 * conformance rather than storage of its own.
 */

#import <Foundation/Foundation.h>

#import "ApplilinkURLConnection.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Posts one registration to @c /destination/regist.php and drops the answer.
 *
 * All three connection callbacks are implemented and all three are inert, so nothing this class
 * starts is ever acted on.
 */
@interface DestinationCore : NSObject <ApplilinkURLConnectionDelegate>

/**
 * Registers a return URL for a country.
 *
 * **The @c delegate argument is never read.** The connection is given @c self instead, so the
 * caller's object is silently ignored — see TYPES_PENDING.md.
 *
 * @param countryCode The country code, sent as @c country_code .
 * @param url The return URL, sent as @c rturl .
 * @param delegate Discarded.
 * @ghidraAddress 0x250d24
 */
- (void)destinationRegistWithCountryCode:(nullable NSString *)countryCode
                                     url:(nullable NSString *)url
                                delegate:(nullable id)delegate;

/**
 * Inert. The body is a single @c ret .
 * @param error Ignored.
 * @ghidraAddress 0x250f50
 */
- (void)failLoadWithError:(nullable NSError *)error;

/**
 * Inert. The body is a single @c ret .
 * @param response Ignored.
 * @ghidraAddress 0x250f54
 */
- (void)finishLoadWithResponse:(nullable NSString *)response;

/**
 * Refuses every redirect.
 * @param request Ignored.
 * @return Always NO.
 * @ghidraAddress 0x250f58
 */
- (BOOL)redirectStartLoad:(nullable NSURLRequest *)request;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
