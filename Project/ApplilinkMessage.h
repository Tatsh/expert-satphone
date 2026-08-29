/**
 * @file
 * @brief The applilink SDK's localised-message helper.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkMessage, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares one method for this class and it is
 * implemented. The class has no instance state.
 *
 * The superclass binds to @c _OBJC_CLASS_$_NSObject at load time; it is not stored in the file.
 *
 * The other binary that embeds the SDK carries this class too, and the two disagree in two
 * substantive ways — see the implementation. This build carries the later revision.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Maps a message key to its localised string.
 */
@interface ApplilinkMessage : NSObject

/**
 * @brief The localised text for a message key, with a built-in English fallback.
 *
 * Looks the key up in the @c "Message" table of the reward bundle, passing a hard-coded English
 * default chosen by the key itself. An unrecognised key gets an empty default.
 *
 * @param localizedMessage The message key.
 * @return The localised text, the built-in default when the bundle is missing, or an empty string
 *         for an unrecognised key.
 * @ghidraAddress 0x24fe94
 */
+ (NSString *)localizedMessage:(NSString *)localizedMessage;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
