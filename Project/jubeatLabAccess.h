/** @file
 * The jubeatLab HTTP API client.
 *
 * Reconstructed from Ghidra program Jubeat (class jubeatLabAccess, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject , from the @c super init at 0x1d8c98.
 *
 * The binary keeps the class's own lowercase @c jubeatLabAccess name, so it is preserved verbatim.
 *
 * RECONSTRUCTION STATE: grown outwards from @c -[EditorIDManager initWithDelegate:] , which builds
 * one through @c -initUIDApi: . The two core initialisers, the URL builder, and the UID endpoint
 * are recovered; the ~30 other endpoint initialisers all funnel through
 * @c -initWithURL:sendData:command:delegate: and are reconstructed in later passes.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Builds and holds an HTTP request to the jubeatLab API and reports its outcome to a
 * delegate.
 */
@interface jubeatLabAccess : NSObject

/**
 * @brief Builds a plain GET request to a URL.
 *
 * Creates a 15-second @c NSMutableURLRequest , stamps the application's User-Agent, and stores the
 * request and the weakly-held delegate.
 * @param url The endpoint.
 * @param delegate The object told how the request finished. Held weakly.
 * @return The initialised client.
 * @ghidraAddress 0x1d8b20
 */
- (instancetype)initWithURL:(nullable NSURL *)url delegate:(nullable id)delegate;

/**
 * @brief Builds a request to a URL with a body and an explicit HTTP method.
 *
 * Sets the method, a @c application/json content type, and the body's length; when a body is
 * present it is attached and the User-Agent stamped. Stores the request and the weak delegate.
 * @param url The endpoint.
 * @param sendData The request body, or nil.
 * @param command The HTTP method (for example @c "POST").
 * @param delegate The object told how the request finished. Held weakly.
 * @return The initialised client.
 * @ghidraAddress 0x1d8c64
 */
- (instancetype)initWithURL:(nullable NSURL *)url
                   sendData:(nullable NSData *)sendData
                    command:(nullable NSString *)command
                   delegate:(nullable id)delegate;

/**
 * @brief Builds the URL for an API endpoint.
 *
 * Assembles @c "<scheme>://jubeat-lab.s.game.konami.jp/aqq/api/JP/v1/<api>" . The scheme is the
 * @p scheme argument verbatim; the binary tests it against @c "https" but discards the result.
 * @param scheme The URL scheme, for example @c "https".
 * @param api The API path segment, for example @c "users".
 * @return The endpoint URL.
 * @ghidraAddress 0x1d8f8c
 */
- (nullable NSURL *)getApiPath:(nullable NSString *)scheme api:(nullable NSString *)api;

/**
 * @brief Starts a create-user-identifier request, POSTing the device UUID.
 * @param delegate The object told how the request finished.
 * @return The initialised client.
 * @ghidraAddress 0x1d90a8
 */
- (instancetype)initUIDApi:(nullable id)delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
