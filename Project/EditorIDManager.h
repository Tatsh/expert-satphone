/** @file
 * The editor identifier store, backed by the keychain.
 *
 * Reconstructed from Ghidra program Jubeat (class EditorIDManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: grown outwards from its callers. The class object at 0x348060 has 126
 * cross-references, so most of it is still unrecovered. The keychain query builders and the
 * jubeatLab provisioning flow (@c -initWithDelegate: and its three callbacks) are recovered; the
 * account-name accessors @c +getEditorIDKey , @c +getEditorPassKey , and @c +deleteKeychain are
 * declared only.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Told how the editor-identifier provisioning download finished.
 */
@protocol EditorIDManagerDelegate <NSObject>
@optional
/**
 * @brief Sent when the download succeeds and the keychain has been written.
 * @param manager The manager that finished.
 */
- (void)successIDDownload:(nullable id)manager;
/**
 * @brief Sent when the download fails.
 * @param manager The manager that failed.
 * @param msgStr The server-supplied message, or nil.
 */
- (void)errorIDDownload:(nullable id)manager msgStr:(nullable NSString *)msgStr;
@end

/**
 * @brief Holds the editor identifier and its passphrase as keychain items.
 */
@interface EditorIDManager : NSObject

/**
 * @brief Starts a jubeatLab provisioning download that will write the editor keychain items.
 *
 * Stores the delegate weakly, builds a @c jubeatLabAccess client bound to this manager, and starts
 * it. The callbacks below report the outcome.
 * @param delegate The object told how the download finished.
 * @return The initialised manager.
 * @ghidraAddress 0x1d272c
 */
- (instancetype)initWithDelegate:(nullable id<EditorIDManagerDelegate>)delegate;

/**
 * @brief Cancels the in-flight provisioning download.
 * @ghidraAddress 0x1d27f8
 */
- (void)cancel;

/**
 * @brief Whether both the editor identifier and its passphrase are present in the keychain.
 *
 * Returns YES only when both lookups succeed. When either reports @c errSecItemNotFound it wipes
 * the keychain entries and returns NO, so a half-provisioned device is cleaned up rather than left
 * in that state.
 * @ghidraAddress 0x1d308c
 */
@property(class, nonatomic, readonly) BOOL isExistEditorID;

/**
 * @brief The keychain account for the editor identifier. DECLARED ONLY.
 */
+ (id)getEditorIDKey;
/**
 * @brief The keychain account for the editor passphrase. DECLARED ONLY.
 */
+ (id)getEditorPassKey;
/**
 * @brief Builds the keychain lookup query for an account.
 *
 * A generic-password query scoped to the bundle identifier that asks for the item's attributes and
 * caps the match at one result.
 * @param key The account name.
 * @return The query dictionary.
 * @ghidraAddress 0x1d2ec4
 */
+ (NSDictionary *)getKeyQuery:(id)key;
/**
 * @brief Removes the editor keychain entries. DECLARED ONLY.
 */
+ (void)deleteKeychain;

/**
 * @brief Builds the keychain add query for an account.
 *
 * A generic-password entry scoped to the bundle identifier with an empty label and description, set
 * to be accessible after first unlock.
 * @param key The account name.
 * @return The add-query dictionary.
 * @ghidraAddress 0x1d28dc
 */
- (NSDictionary *)createAddQuery:(id)key;

/**
 * @brief jubeatLab callback sent as the download proceeds. Does nothing.
 * @param access The jubeatLab client.
 * @ghidraAddress 0x1d2810
 */
- (void)jubeatLabAccessProceed:(nullable id)access;
/**
 * @brief jubeatLab callback sent when the download fails; tells the delegate.
 * @param access The jubeatLab client.
 * @ghidraAddress 0x1d2814
 */
- (void)jubeatLabAccessError:(nullable id)access;
/**
 * @brief jubeatLab callback sent when the download finishes; writes the keychain on success.
 *
 * Parses the JSON for @c Status , @c UserID , and @c Passwd . When all are present and the status
 * is zero it writes both keychain items, refreshes the user agent, and tells the delegate it
 * succeeded; otherwise it reports the failure with the server's @c MsgUser text.
 * @param access The jubeatLab client.
 * @ghidraAddress 0x1d2a5c
 */
- (void)jubeatLabAccessFinished:(nullable id)access;

/**
 * @brief Reads the keychain payload for an account and decodes it as a UTF-8 string.
 *
 * Returns nil when either keychain lookup fails. Like
 * @c -[JubeatAppDelegate musicListKey], the first query asks only for attributes and those
 * attributes are then reused as the basis of a second query that asks for the payload.
 * @ghidraAddress 0x1d33c4
 */
+ (nullable NSString *)getKeyString:(id)key;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
