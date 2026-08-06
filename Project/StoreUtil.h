/** @file
 * Store helper routines.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreUtil, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the one member
 * @c -[StoreMusicInfo initWithDictionary:] reaches is declared. The class object is at 0x348158.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Odds and ends the store screens share.
 */
@interface StoreUtil : NSObject

/**
 * @brief Whether a string is a URL worth keeping.
 *
 * @c StoreMusicInfo gates three of its six string fields on this and leaves them nil when it
 * answers NO, so an unusable URL is dropped rather than stored. DECLARED ONLY.
 *
 * @param url The candidate, as it arrived from the server.
 */
+ (BOOL)isValidURL:(nullable NSString *)url;

/**
 * @brief Maps a pack identifier to its App Store product identifier.
 *
 * DECLARED ONLY.
 *
 * @param packID The pack's identifier, as @c StorePackInfo carries it.
 * @return The product identifier, or nil for a pack with no product.
 * @ghidraAddress 0xbab70
 */
+ (nullable NSString *)productIDForPackID:(int)packID;

/**
 * @brief Where a downloaded tune's data would live.
 *
 * DECLARED ONLY. Returns the path whether or not anything is there; the caller tests it with
 * @c -[NSFileManager fileExistsAtPath:] .
 *
 * @param musicID The tune.
 * @return The path.
 */
+ (nullable NSString *)filePathForMusicID:(int)musicID;

/**
 * @brief The endpoint the store's knit background colour is fetched from.
 *
 * DECLARED ONLY — the body has not been reconstructed yet. Fetched during
 * @c -[LogoViewController loadView] , alongside the event type.
 *
 * @return The knit-colour URL.
 * @ghidraAddress 0xba7f4
 */
+ (nullable NSURL *)knitColorURL;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
