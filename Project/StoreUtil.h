/** @file
 * Store helper routines.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreUtil, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: grown outwards from its callers. The class object is at 0x348158. The
 * layout metrics, the query-string helper, the store-new-info URL, and the receipt-verify URLs are
 * recovered; the remaining URL builders and the pack/product identifier maps are declared only.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Odds and ends the store screens share.
 */
@interface StoreUtil : NSObject

/**
 * @brief The store tab header height, 44 points.
 * @ghidraAddress 0xb9844
 */
+ (int)storeTabHeaderHeight;
/**
 * @brief The store tab footer height, 49 points.
 * @ghidraAddress 0xb984c
 */
+ (int)storeTabFooterHeight;
/**
 * @brief The store category list height, 80 points.
 * @ghidraAddress 0xb9854
 */
+ (int)storeCategoryListHeight;
/**
 * @brief The store category title height, 100 points.
 * @ghidraAddress 0xb985c
 */
+ (int)storeCategoryTitleHeight;

/**
 * @brief Builds a @c "&key=value" query fragment from a dictionary's string entries.
 *
 * Every pair, including the first, is prefixed with @c "&" , so the result is not a well-formed
 * query string on its own; non-string keys or values are skipped and nothing is percent-encoded.
 * @param dictionary The parameters.
 * @return The concatenated fragment.
 * @ghidraAddress 0xb9864
 */
+ (nullable NSString *)queryStringForDictionary:(nullable NSDictionary *)dictionary;

/**
 * @brief The store's new-information URL, carrying the client info as a query.
 * @ghidraAddress 0xba318
 */
+ (nullable NSURL *)storeNewInfoURL;

/**
 * @brief The pack-info URL for a pack, carrying the client info as a query.
 * @param packID The pack identifier.
 * @ghidraAddress 0xb9f28
 */
+ (nullable NSURL *)packInfoURL:(unsigned int)packID;
/**
 * @brief The restore-pack-info URL for a pack, carrying the client info as a query.
 * @param packID The pack identifier.
 * @ghidraAddress 0xba078
 */
+ (nullable NSURL *)restorePackInfoURL:(unsigned int)packID;
/**
 * @brief The music-info URL for a tune, carrying the client info as a query.
 * @param musicID The tune identifier.
 * @ghidraAddress 0xba1c8
 */
+ (nullable NSURL *)musicInfoURL:(unsigned int)musicID;
/**
 * @brief The free-music-list (privilege) URL keyed by a value.
 * @param key The list key.
 * @ghidraAddress 0xba48c
 */
+ (nullable NSURL *)privilegeListURL:(int)key;
/**
 * @brief The privilege music-info URL; forwards to @c +musicInfoURL: .
 * @param musicID The tune identifier.
 * @ghidraAddress 0xba56c
 */
+ (nullable NSURL *)privilegeMusicInfoURL:(unsigned int)musicID;

/**
 * @brief The receipt-verify URL for a new purchase; delegates to @c ScratchUtil .
 * @ghidraAddress 0xba464
 */
+ (nullable NSURL *)verifyReceiptNewURL;
/**
 * @brief The receipt-verify URL for a consumable purchase; delegates to @c ScratchUtil . Identical
 * to @c +verifyReceiptNewURL .
 * @ghidraAddress 0xba478
 */
+ (nullable NSURL *)verifyReceiptConsumeURL;

/**
 * @brief The campaign-list URL.
 * @ghidraAddress 0xba578
 */
+ (nullable NSURL *)campaignListURL;
/**
 * @brief The campaign serial-check URL.
 * @ghidraAddress 0xba64c
 */
+ (nullable NSURL *)campaignSerialCheckURL;
/**
 * @brief The campaign-item fetch URL.
 * @ghidraAddress 0xba720
 */
+ (nullable NSURL *)campaignItemURL;
/**
 * @brief The marker-list check URL.
 * @ghidraAddress 0xba8c8
 */
+ (nullable NSURL *)markerListURL;
/**
 * @brief The recommended-pack URL for a tune, carrying the client info as a query.
 * @param musicID The tune identifier.
 * @ghidraAddress 0xbb3bc
 */
+ (nullable NSURL *)recommendPackURL:(unsigned int)musicID;
/**
 * @brief The startup-news URL.
 * @ghidraAddress 0xbb50c
 */
+ (nullable NSURL *)startNewsURL;
/**
 * @brief The passed-information list URL.
 * @ghidraAddress 0xbb5e8
 */
+ (nullable NSURL *)passedInfoListURL;

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
