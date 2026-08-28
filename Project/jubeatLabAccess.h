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
 * @return The bytes received so far.
 * @ghidraAddress 0x1daf10
 */
- (nullable NSData *)getData;

/**
 * @brief The response body decoded as a JSON dictionary, or nil when it is absent or not a
 * dictionary.
 * @return The decoded JSON dictionary, or nil when it is absent or not a dictionary.
 * @ghidraAddress 0x1daf20
 */
- (nullable NSDictionary *)getDataInJSON;

/**
 * @brief The number of bytes received so far.
 * @return The byte count received so far.
 * @ghidraAddress 0x1dae8c
 */
- (NSUInteger)currentSize;

/**
 * @brief The download progress in [0, 1], or 0 when the expected length is unknown.
 * @return The progress in [0, 1], or 0 when the expected length is unknown.
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

/**
 * @brief Starts an upload of a custom sequence.
 *
 * POSTs @c {uuid, passwd, jcfData} to @c users/\<editorID\>/seqs , with the sequence data
 * base64-encoded.
 * @param delegate The object told how the request finished.
 * @param seqData The sequence data to upload.
 * @return The initialised client.
 * @ghidraAddress 0x1d9228
 */
- (instancetype)initUploadApi:(nullable id)delegate seqData:(nullable NSData *)seqData;

/**
 * @brief Starts a GET of a shared sequence by its identifier.
 *
 * Fetches @c seqs/\<seqID\>?userID=\<editorID\> .
 * @param delegate The object told how the request finished.
 * @param seqID The sequence identifier.
 * @return The initialised client.
 * @ghidraAddress 0x1d9588
 */
- (instancetype)initDownloadApi:(nullable id)delegate seqID:(nullable id)seqID;

/**
 * @brief Starts a GET of the recommended pack for a tune.
 * @param delegate The object told how the request finished.
 * @param tuneID The tune identifier.
 * @return The initialised client.
 * @ghidraAddress 0x1d96c8
 */
- (instancetype)initComprisedPackApi:(nullable id)delegate tuneID:(unsigned int)tuneID;

/**
 * @brief Starts a good-job (like) POST for a sequence.
 *
 * POSTs @c {userID, musicID} to @c seqs/\<seqID\>/Like . A missing editor identifier is sent as
 * @c "ERRUSR".
 * @param delegate The object told how the request finished.
 * @param tuneID The tune identifier.
 * @param seqID The sequence identifier.
 * @return The initialised client.
 * @ghidraAddress 0x1d976c
 */
- (instancetype)initGoodJobApi:(nullable id)delegate tuneID:(int)tuneID seqID:(nullable id)seqID;

/**
 * @brief Starts a vote-level POST for a sequence.
 *
 * POSTs @c {level, userID, musicID} to @c seqs/\<seqID\>/VoteLevel .
 * @param delegate The object told how the request finished.
 * @param tuneID The tune identifier.
 * @param seqID The sequence identifier.
 * @param level The voted level.
 * @return The initialised client.
 * @ghidraAddress 0x1d9a5c
 */
- (instancetype)initLevelApi:(nullable id)delegate
                      tuneID:(int)tuneID
                       seqID:(nullable id)seqID
                       level:(int)level;

/**
 * @brief Starts a play-count POST for a sequence.
 *
 * POSTs @c {userID, musicID} to @c seqs/\<seqID\>/Played .
 * @param delegate The object told how the request finished.
 * @param tuneID The tune identifier.
 * @param seqID The sequence identifier.
 * @return The initialised client.
 * @ghidraAddress 0x1d9d88
 */
- (instancetype)initPlayApi:(nullable id)delegate tuneID:(int)tuneID seqID:(nullable id)seqID;

/**
 * @brief Starts a special-user creation POST.
 *
 * POSTs @c {userName, userID, userType} to @c users/SpecialUser .
 * @param delegate The object told how the request finished.
 * @param userID The user identifier.
 * @param name The user name.
 * @param userType The user type.
 * @return The initialised client.
 * @ghidraAddress 0x1da760
 */
- (instancetype)initCreateUserID:(nullable id)delegate
                          userID:(nullable id)userID
                            name:(nullable id)name
                        userType:(int)userType;

/**
 * @brief Builds a web-page URL under the lab host.
 *
 * Assembles @c "<scheme>://jubeat-lab.s.game.konami.jp/<pagePath>" . As with @c -getApiPath:api:
 * the scheme is used verbatim and the @c "https" comparison is discarded.
 * @param scheme The URL scheme.
 * @param pagePath The page path under the host.
 * @return The page URL.
 * @ghidraAddress 0x1d8e90
 */
+ (nullable NSURL *)getWebPagePath:(nullable NSString *)scheme
                          pagePath:(nullable NSString *)pagePath;

/**
 * @brief The user-management web page URL.
 * @return The user-management page URL.
 * @ghidraAddress 0x1db05c
 */
+ (nullable NSURL *)getUserPageURL;

/**
 * @brief The session-error web page URL.
 * @return The session-error page URL.
 * @ghidraAddress 0x1db0e8
 */
+ (nullable NSURL *)getUserPageSessionFailedURL;

/**
 * @brief The sequence-search web page URL for a music identifier.
 * @param musicID The music identifier.
 * @return The search-page URL.
 * @ghidraAddress 0x1db160
 */
+ (nullable NSURL *)getSequenceSerchURL:(int)musicID;

/**
 * @brief The sequence-detail web page URL for a sequence identifier.
 * @param sequenceID The sequence identifier.
 * @return The detail-page URL.
 * @ghidraAddress 0x1db224
 */
+ (nullable NSURL *)getSequencePageURL:(nullable id)sequenceID;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
