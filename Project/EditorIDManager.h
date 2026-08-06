/** @file
 * The editor identifier store.
 *
 * Reconstructed from Ghidra program Jubeat (class EditorIDManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its caller. The class object at 0x348060 has 126
 * cross-references; only the members reached so far are declared.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Holds the editor identifier that development builds are keyed on.
 */
@interface EditorIDManager : NSObject

/**
 * @brief Whether an editor identifier has been provisioned on this device.
 *
 * Called from @c -[JubeatAppDelegate refreshUserAgent] at 0xa3ac to decide whether the User-Agent's
 * trailing bracketed field carries a key or stays empty.
 */
@property(class, nonatomic, readonly) BOOL isExistEditorID;

/**
 * @brief The raw editor identifier key.
 */
+ (id)getEditorIDKey;
/**
 * @brief Renders an editor identifier key as the string used in the User-Agent.
 */
+ (NSString *)getKeyString:(id)editorIDKey;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
