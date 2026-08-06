/** @file
 * The editor identifier store, backed by the keychain.
 *
 * Reconstructed from Ghidra program Jubeat (class EditorIDManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: grown outwards from its callers. The class object at 0x348060 has 126
 * cross-references, so most of it is still unrecovered. Every member here is a class method; the
 * class holds no instance state that this pass has reached.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Holds the editor identifier and its passphrase as keychain items.
 */
@interface EditorIDManager : NSObject

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
 * @brief Builds the keychain query dictionary for an account. DECLARED ONLY.
 */
+ (NSDictionary *)getKeyQuery:(id)key;
/**
 * @brief Removes the editor keychain entries. DECLARED ONLY.
 */
+ (void)deleteKeychain;

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
