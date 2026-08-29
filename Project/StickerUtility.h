/**
 * @file
 * The iMessage sticker store, shared with the app extension through an app group.
 *
 * Reconstructed from Ghidra program Jubeat (class StickerUtility, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject, taken from the dyld bind at the class object's superclass slot
 * (0x34e6d8).
 *
 * Stickers live as files in the app group's container, and their display names in a dictionary in
 * the group's user defaults keyed by file name. The two halves are written separately and nothing
 * reconciles them, so a file without a defaults entry, or the reverse, is possible.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Reads and writes the shared sticker set.
 *
 * The class has no ivars and no instance methods.
 */
@interface StickerUtility : NSObject

/**
 * Forgets every sticker's display name.
 *
 * Removes the whole name dictionary from the group's defaults. Note it does **not** call
 * @c -synchronize, where @c +saveSticker:displayName:data: does, and it does not delete the
 * sticker files — so the images survive with no names attached.
 * @ghidraAddress 0xdc634
 */
+ (void)cleanStickerList;

/**
 * Reports whether a sticker is present.
 *
 * **This does not do what its name says.** The body never reads @c name: it checks only that the
 * app group's container directory itself exists, so it answers the same value for every argument
 * and for a sticker that was never saved. See TYPES_PENDING.md.
 *
 * @param name The sticker's file name. Ignored.
 * @return Whether the app group's container exists.
 * @ghidraAddress 0xdc690
 */
+ (BOOL)checkExistSticker:(nullable NSString *)name;

/**
 * Writes a sticker's image into the app group and records its display name.
 *
 * The name is only recorded when the file write succeeds, so a failed write leaves the defaults
 * untouched rather than half-updated.
 *
 * @param fileName The file to write, relative to the group container. Also the dictionary key.
 * @param displayName The name to show for it.
 * @param data The image bytes.
 * @ghidraAddress 0xdc73c
 */
+ (void)saveSticker:(nullable NSString *)fileName
        displayName:(nullable NSString *)displayName
               data:(nullable NSData *)data;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
