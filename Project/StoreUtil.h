/**
 * @file
 * @brief Store helper routines.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreUtil, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The class is complete: all thirty-five hand-written class methods are recovered — the layout
 * metrics, the query-string helper, the whole family of server URL builders, the identifier maps,
 * the SHA-256-verified response check, the currency formatter, and the affiliate-parameter parser.
 * The class object is at 0x348158.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Odds and ends the store screens share.
 */
@interface StoreUtil : NSObject

/**
 * @brief The store tab header height, 44 points.
 * @return Always 44.
 * @ghidraAddress 0xb9844
 */
+ (int)storeTabHeaderHeight;
/**
 * @brief The store tab footer height, 49 points.
 * @return Always 49.
 * @ghidraAddress 0xb984c
 */
+ (int)storeTabFooterHeight;
/**
 * @brief The store category list height, 80 points.
 * @return Always 80.
 * @ghidraAddress 0xb9854
 */
+ (int)storeCategoryListHeight;
/**
 * @brief The store category title height, 100 points.
 * @return Always 100.
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
 * @return The new-information URL.
 * @ghidraAddress 0xba318
 */
+ (nullable NSURL *)storeNewInfoURL;

/**
 * @brief The pack-list URL for a page, optionally filtered by genre.
 *
 * Formats @c packlist_secure with the head and limit and appends @c "&genre=%d" only when @p genre
 * is non-zero, then the client-info query.
 * @param head The first index.
 * @param limit The page size.
 * @param genre The genre filter, or 0 for none.
 * @return The pack-list URL for the page.
 * @ghidraAddress 0xb9a2c
 */
+ (nullable NSURL *)packListURL:(unsigned int)head
                          limit:(unsigned int)limit
                          genre:(unsigned int)genre;
/**
 * @brief The recommended-pack-list URL: head 0, limit 8, and a random genre when @p useGenre is
 * set.
 *
 * When @p useGenre is non-zero it appends @c "&genre=%d" with a value chosen at random from a
 * ten-entry table.
 * @param useGenre Whether to append a random genre filter.
 * @return The recommended-pack-list URL.
 * @ghidraAddress 0xb9ba0
 */
+ (nullable NSURL *)recommendPackListURL:(unsigned int)useGenre;
/**
 * @brief The optional-pack-list URL for a set of pack identifiers.
 *
 * Formats @c optional_packlist with a comma-separated @c packs list. Returns nil for an empty set.
 * @param packIDs The pack identifiers, as @c NSNumber s.
 * @return The optional-pack-list URL, or nil for an empty set.
 * @ghidraAddress 0xb9d48
 */
+ (nullable NSURL *)selectivePackListURL:(nullable NSArray *)packIDs;

/**
 * @brief The pack-info URL for a pack, carrying the client info as a query.
 * @param packID The pack identifier.
 * @return The pack-info URL.
 * @ghidraAddress 0xb9f28
 */
+ (nullable NSURL *)packInfoURL:(unsigned int)packID;
/**
 * @brief The restore-pack-info URL for a pack, carrying the client info as a query.
 * @param packID The pack identifier.
 * @return The restore-pack-info URL.
 * @ghidraAddress 0xba078
 */
+ (nullable NSURL *)restorePackInfoURL:(unsigned int)packID;
/**
 * @brief The music-info URL for a tune, carrying the client info as a query.
 * @param musicID The tune identifier.
 * @return The music-info URL.
 * @ghidraAddress 0xba1c8
 */
+ (nullable NSURL *)musicInfoURL:(unsigned int)musicID;
/**
 * @brief The free-music-list (privilege) URL keyed by a value.
 * @param key The list key.
 * @return The free-music-list URL.
 * @ghidraAddress 0xba48c
 */
+ (nullable NSURL *)privilegeListURL:(int)key;
/**
 * @brief The privilege music-info URL; forwards to @c +musicInfoURL: .
 * @param musicID The tune identifier.
 * @return Whatever @c +musicInfoURL: returns for the tune.
 * @ghidraAddress 0xba56c
 */
+ (nullable NSURL *)privilegeMusicInfoURL:(unsigned int)musicID;

/**
 * @brief The receipt-verify URL for a new purchase; delegates to @c ScratchUtil .
 * @return The receipt-verify URL.
 * @ghidraAddress 0xba464
 */
+ (nullable NSURL *)verifyReceiptNewURL;
/**
 * @brief The receipt-verify URL for a consumable purchase; delegates to @c ScratchUtil . Identical
 * to @c +verifyReceiptNewURL .
 * @return The receipt-verify URL.
 * @ghidraAddress 0xba478
 */
+ (nullable NSURL *)verifyReceiptConsumeURL;

/**
 * @brief The campaign-list URL.
 * @return The campaign-list URL.
 * @ghidraAddress 0xba578
 */
+ (nullable NSURL *)campaignListURL;
/**
 * @brief The campaign serial-check URL.
 * @return The campaign serial-check URL.
 * @ghidraAddress 0xba64c
 */
+ (nullable NSURL *)campaignSerialCheckURL;
/**
 * @brief The campaign-item fetch URL.
 * @return The campaign-item fetch URL.
 * @ghidraAddress 0xba720
 */
+ (nullable NSURL *)campaignItemURL;
/**
 * @brief The marker-list check URL.
 * @return The marker-list check URL.
 * @ghidraAddress 0xba8c8
 */
+ (nullable NSURL *)markerListURL;
/**
 * @brief The recommended-pack URL for a tune, carrying the client info as a query.
 * @param musicID The tune identifier.
 * @return The recommended-pack URL.
 * @ghidraAddress 0xbb3bc
 */
+ (nullable NSURL *)recommendPackURL:(unsigned int)musicID;
/**
 * @brief The startup-news URL.
 * @return The startup-news URL.
 * @ghidraAddress 0xbb50c
 */
+ (nullable NSURL *)startNewsURL;
/**
 * @brief The passed-information list URL.
 * @return The passed-information list URL.
 * @ghidraAddress 0xbb5e8
 */
+ (nullable NSURL *)passedInfoListURL;
/**
 * @brief The store user-policy URL, carrying the agreed licence version.
 *
 * The query is @c {version: <PrefStoreAgreeLicenseVersion or "">, target: "JP"} .
 * @return The store user-policy URL.
 * @ghidraAddress 0xbb67c
 */
+ (nullable NSURL *)storeUserPolicyURL;
/**
 * @brief The store extend-list URL, carrying the last-update timestamp.
 *
 * Structurally identical to @c +storeUserPolicyURL but the version value is read from
 * @c PrefExtendListLastUpdate .
 * @return The store extend-list URL.
 * @ghidraAddress 0xbb8b8
 */
+ (nullable NSURL *)storeExtendListURL;

/**
 * @brief Verifies a signed store response and returns its JSON body.
 *
 * The first 64 bytes are the expected lowercase SHA-256 hex of the body with a fixed salt in place
 * of that prefix; when it matches, the remaining bytes are parsed as a JSON dictionary. Returns nil
 * for a response shorter than 64 bytes or a failed signature.
 * @param response The raw signed response.
 * @return The verified JSON dictionary, or nil.
 * @ghidraAddress 0xba9a4
 */
+ (nullable NSDictionary *)checkStoreResponse:(nullable NSData *)response;

/**
 * @brief Formats a price number as a currency string in a locale.
 *
 * Returns the empty string when either argument is nil; otherwise uses an
 * @c NSNumberFormatterCurrencyStyle formatter in the 10.4 behaviour.
 * @param price The price number.
 * @param locale The store-front locale.
 * @return The formatted price, or @c "".
 * @ghidraAddress 0xbaca0
 */
+ (nullable NSString *)priceString:(nullable NSNumber *)price
                        withLocale:(nullable NSLocale *)locale;

/**
 * @brief Whether a string is a URL worth keeping.
 *
 * @c StoreMusicInfo gates three of its six string fields on this and leaves them nil when it
 * answers NO, so an unusable URL is dropped rather than stored. DECLARED ONLY.
 *
 * @param url The candidate, as it arrived from the server.
 * @return YES when the string is a URL worth keeping, NO when it should be dropped.
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
 * @brief Maps an App Store product identifier back to its pack identifier.
 *
 * Strips the @c "jubeat.pack" prefix and parses the remainder; returns -1 when the string does not
 * carry the prefix or the number is not positive.
 * @param productID The product identifier.
 * @return The pack identifier, or -1.
 * @ghidraAddress 0xbabc8
 */
+ (int)packIDForProductID:(nullable NSString *)productID;

/**
 * @brief Whether a tune's file is present, whether built in or downloaded.
 *
 * When the bundled @c Music resource exists it answers YES for any identifier in
 * @c StoreMusicListManager 's built-in list; otherwise it tests whether
 * @c "<documents>/%d.jbt" exists on disk.
 * @param musicID The tune identifier.
 * @return YES when the tune's file is present, NO otherwise.
 * @ghidraAddress 0xbbaf4
 */
+ (BOOL)existMusicFile:(int)musicID;

/**
 * @brief Whether any entry has a downloadable extend tune that is not yet on disk.
 *
 * Answers YES for the first entry whose base tune is in the store list and present on disk while
 * its non-zero @c extendMusicID is not.
 * @param entries The store music entries.
 * @return YES when at least one entry has a downloadable extend tune, NO otherwise.
 * @ghidraAddress 0xbbda8
 */
+ (BOOL)existDownloadableExtendMusic:(nullable NSArray *)entries;

/**
 * @brief Extracts the App Store affiliate parameters from an iTunes URL.
 *
 * Returns nil unless the host is @c itunes.apple.com and the query carries a positive @c i item
 * identifier and an @c at affiliate token; a @c ct campaign token is added when present.
 * @param url The affiliate URL.
 * @return The @c SKStoreProductParameter dictionary, or nil.
 * @ghidraAddress 0xbad90
 */
+ (nullable NSDictionary *)affiliateParametersFromURL:(nullable NSURL *)url;

/**
 * @brief Where a downloaded tune's data would live.
 *
 * DECLARED ONLY. Returns the path whether or not anything is there; the caller tests it with
 * @c -[NSFileManager fileExistsAtPath:] .
 *
 * @param musicID The tune.
 * @return The path.
 */
+ (nullable NSString *)filePathForMusicID:(unsigned int)musicID;

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
