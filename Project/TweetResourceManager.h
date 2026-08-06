/** @file
 * The tweet-image resource manager.
 *
 * Reconstructed from Ghidra program Jubeat (class TweetResourceManager, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the three class methods
 * @c -[JubeatAppDelegate application:didFinishLaunchingWithOptions:] sends are declared. The class
 * object is at 0x3480d8.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Owns the backgrounds used when composing a score tweet.
 */
@interface TweetResourceManager : NSObject

/**
 * @brief Reports whether the resource data is present and usable.
 *
 * The result is tested by the @c tbnz at 0x9ab8, so it is a @c BOOL and only bit 0 is examined.
 * DECLARED ONLY.
 */
+ (BOOL)checkResourceData;
/**
 * @brief Migrates the resource data into the Documents directory.
 *
 * Sent at 0x9ac8 only when @c +checkResourceData returns NO. DECLARED ONLY.
 */
+ (void)moveResourceDataInDoc;
/**
 * @brief Reports whether a persisted frame selection is still valid.
 *
 * The launch handler passes whatever it read from the "PrefTwitterBgFrame" user default and removes
 * that default when this returns NO, so the argument's own type is whatever was written there and
 * is not established. Tested by the @c tbnz at 0x9b04. DECLARED ONLY.
 * @param frame The persisted frame selection.
 */
+ (BOOL)checkEnableSelecteFrame:(id)frame;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
