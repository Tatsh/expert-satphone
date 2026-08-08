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
@interface jubeatLabAccess : NSObject <NSURLSessionDataDelegate>

/**
 * @brief Starts the request on the main queue.
 *
 * Cancels any running task, opens an @c NSURLSession with this object as its delegate, and resumes
 * a data task for the built request.
 * @ghidraAddress 0x1daa14
 */
- (void)startAccess;

/**
 * @brief Abandons the request: clears the weak delegate, cancels the task, and drops the data.
 * @ghidraAddress 0x1dab20
 */
- (void)cancel;

/**
 * @brief The accumulated response body.
 * @ghidraAddress 0x1daf10
 */
- (nullable NSData *)getData;

/**
 * @brief The response body decoded as a JSON dictionary, or nil when it is absent or not a
 * dictionary.
 * @ghidraAddress 0x1daf20
 */
- (nullable NSDictionary *)getDataInJSON;

/**
 * @brief The number of bytes received so far.
 * @ghidraAddress 0x1dae8c
 */
- (NSInteger)currentSize;

/**
 * @brief The download progress in [0, 1], or 0 when the expected length is unknown.
 * @ghidraAddress 0x1daea4
 */
- (float)currentProgress;

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
 * @brief Builds the keychain lookup query for an account. Identical to
 * @c +[EditorIDManager getKeyQuery:] .
 * @param key The account name.
 * @return The query dictionary.
 * @ghidraAddress 0x1d8840
 */
- (NSDictionary *)getKeyQuery:(nullable id)key;

/**
 * @brief Reads the keychain payload for an account and decodes it as a UTF-8 string. Identical to
 * @c +[EditorIDManager getKeyString:] .
 * @param key The account name.
 * @return The stored string, or nil when the lookup fails.
 * @ghidraAddress 0x1d89b0
 */
- (nullable NSString *)getKeyString:(nullable id)key;

/**
 * @brief Starts a create-user-identifier request, POSTing the device UUID.
 * @param delegate The object told how the request finished.
 * @return The initialised client.
 * @ghidraAddress 0x1d90a8
 */
- (instancetype)initUIDApi:(nullable id)delegate;

/**
 * @brief Starts a session-open request, POSTing the passphrase for the current editor identifier.
 * @param delegate The object told how the request finished.
 * @return The initialised client.
 * @ghidraAddress 0x1da078
 */
- (instancetype)initSessionApi:(nullable id)delegate;

/**
 * @brief Starts a top-page session-open request (the @c Session2 variant).
 * @param delegate The object told how the request finished.
 * @return The initialised client.
 * @ghidraAddress 0x1da320
 */
- (instancetype)initTopPageSessionApi:(nullable id)delegate;

/**
 * @brief Starts a GET for the privacy-policy last-update timestamp.
 * @param delegate The object told how the request finished.
 * @return The initialised client.
 * @ghidraAddress 0x1da5c8
 */
- (instancetype)initLicenseVersionApi:(nullable id)delegate;

/**
 * @brief Starts a GET for the privacy policy.
 * @param delegate The object told how the request finished.
 * @return The initialised client.
 * @ghidraAddress 0x1da694
 */
- (instancetype)initLicenseApi:(nullable id)delegate;

/**
 * @brief Starts a GET for the lab top-page URL.
 * @param delegate The object told how the request finished.
 * @return The initialised client.
 * @ghidraAddress 0x1da948
 */
- (instancetype)initTopPageApi:(nullable id)delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
