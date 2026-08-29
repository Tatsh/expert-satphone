/**
 * @file
 * @brief Reconstructed interface for the Applilink recommend SDK's @c RecommendAdData.
 *
 * @c RecommendAdData is the recommend network's advert-data model store. It is a stateless utility
 * class: every member is a class method and the class holds no instance state. The store reads the
 * archived advert payload that the SDK caches in @c NSUserDefaults (the @c
 * ApplilinkRecommend.allAdData blob and its sub-lists), narrows and filters those records by advert
 * identifier, advert model, advert type, and application identifier, resolves the on-disk banner
 * and interstitial cache paths, runs the weighted interstitial lottery, extracts the movie and
 * poster creatives, and derives the install-flag string for a record. The Applilink SDK ships as a
 * closed third-party library; the full class surface is recovered here from the Objective-C
 * metadata of the @e jubeat @e plus binary.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The recommend network's advert-data model store.
 */
@interface RecommendAdData : NSObject

/**
 * @brief The archived banner-display-status list.
 *
 * In debug mode the list comes from @c RecommendDebug; otherwise it is unarchived from the
 * @c ApplilinkRecommend.allAdData blob under its @c banner_display_status_list key.
 * @return The banner-display-status records, or @c nil.
 * @ghidraAddress 0x2574d8
 */
+ (nullable NSArray *)getBannerDisplayStatusList;

/**
 * @brief The archived advert-model setting list.
 *
 * In debug mode the list comes from @c RecommendDebug; otherwise it is unarchived from the
 * @c ApplilinkRecommend.allAdData blob under its @c ad_model_setting_list key.
 * @return The advert-model setting records, or @c nil.
 * @ghidraAddress 0x257604
 */
+ (nullable NSArray *)getAdModelSettingList;

/**
 * @brief The archived advert list.
 *
 * Unarchived from the @c ApplilinkRecommend.allAdData blob under its @c list key.
 * @return The advert records, or @c nil.
 * @ghidraAddress 0x257730
 */
+ (nullable NSArray *)getAdList;

/**
 * @brief The archived self-advert list.
 *
 * Unarchived from the @c ApplilinkRecommend.allAdData blob under its @c self key.
 * @return The self-advert records, or @c nil.
 * @ghidraAddress 0x25780c
 */
+ (nullable NSArray *)getSelfList;

/**
 * @brief The raw network response data cached under the @c ApplilinkNetwork.responseNsData key.
 * @return The cached response object, or @c nil.
 * @ghidraAddress 0x2578e8
 */
+ (nullable NSData *)getResponseNsData;

/**
 * @brief The archived interstitial-specification dictionary.
 *
 * Unarchived from the @c ApplilinkRecommend.allAdData blob under its @c interstitial_spec_list key.
 * @return The interstitial-specification dictionary, or @c nil.
 * @ghidraAddress 0x25797c
 */
+ (nullable NSDictionary *)getInterstitialSpecList;

/**
 * @brief The cached advert status for an advert model.
 *
 * Looks the advert model up in the banner-display-status list and returns its @c status value.
 * @param adModel The advert-model identifier.
 * @return The advert @c status value, or zero when the model is absent or malformed.
 * @ghidraAddress 0x257a58
 */
+ (int)getAdStatusByAdModel:(int)adModel;

/**
 * @brief The advert-data records for an advert identifier.
 *
 * Narrows the advert list to the records whose @c ad_id equals @p adId.
 * @param adId The advert identifier.
 * @return The narrowed advert records, or @c nil when the list is empty.
 * @ghidraAddress 0x257c14
 */
+ (nullable NSArray *)getAdDataByAdId:(int)adId;

/**
 * @brief The first record of a list whose @c ad_type equals a value.
 * @param list The advert records to search.
 * @param adType The advert-type identifier.
 * @return The first matching record, or @c nil.
 * @ghidraAddress 0x257d0c
 */
+ (nullable NSDictionary *)getAdDataList:(nullable NSArray *)list adType:(int)adType;

/**
 * @brief The advert-data record for an application identifier.
 *
 * Narrows the advert list to the records whose @c appli_id equals @p appliId, preferring a record
 * whose @c primary_flg is set, and returns that record.
 * @param appliId The advert application identifier.
 * @return The advert-data record, or @c nil.
 * @ghidraAddress 0x257ee0
 */
+ (nullable NSDictionary *)getAdDataWithAppliId:(nullable NSString *)appliId;

/**
 * @brief The advert list narrowed to a single advert type.
 * @param adType The advert-type identifier.
 * @return The advert records whose @c ad_type equals @p adType.
 * @ghidraAddress 0x258144
 */
+ (nullable NSArray *)getAdListByAdType:(int)adType;

/**
 * @brief The application-banner records for the lottery banner.
 *
 * Draws a lottery banner, resolves its cached @c banner_url (picked at random from
 * @c banner_url_list) to the on-disk banner-cache path, and records the creative identifier and
 * install flag.
 * @return An array with the single resolved banner record, or @c nil.
 * @ghidraAddress 0x258208
 */
+ (nullable NSArray *)getAppBannerList;

/**
 * @brief The application-icon records for the lottery icons.
 *
 * Resolves each drawn lottery-icon @c banner_icon_url (picked at random from @c
 * banner_icon_url_list) to its cached file name and records the creative identifier and install
 * flag.
 * @return The resolved icon records.
 * @ghidraAddress 0x258780
 */
+ (nullable NSArray *)getAppIconList;

/**
 * @brief The application-interstitial records for the lottery interstitial.
 *
 * Draws a lottery interstitial, and for a movie creative resolves the movie and poster URLs,
 * otherwise resolves the interstitial banner. The resolved creative is copied to the on-disk
 * banner-cache path, the creative identifier is recorded, and the install-flag string is attached.
 * @param movieFlg Whether only movie-capable interstitials are eligible.
 * @return An array with the single resolved interstitial record, or @c nil.
 * @ghidraAddress 0x258cbc
 */
+ (nullable NSArray *)getAppInterstitialList:(BOOL)movieFlg;

/**
 * @brief Draw a lottery banner record.
 *
 * Filters the banner-type adverts to the ones still within their display term, then picks one
 * uniformly at random.
 * @return The drawn banner record, or @c nil.
 * @ghidraAddress 0x259420
 */
+ (nullable NSDictionary *)getLotteryBannerData;

/**
 * @brief Draw up to four lottery icon records.
 *
 * Filters the icon-type adverts to the ones still within their display term, shuffles them, and
 * returns the first four (or fewer).
 * @return The drawn icon records, or @c nil.
 * @ghidraAddress 0x25951c
 */
+ (nullable NSArray *)getLotteryIconData;

/**
 * @brief Draw a lottery interstitial record.
 *
 * Reduces the interstitial display-specification list to the entries whose daily and total display
 * counts, install state, and movie capability still allow a display, then draws one weighted by
 * priority.
 * @param movieFlg Whether only movie-capable interstitials are eligible.
 * @return The drawn interstitial record, or @c nil.
 * @ghidraAddress 0x259678
 */
+ (nullable NSDictionary *)getLotteryInterstitialDataForMovie:(BOOL)movieFlg;

/**
 * @brief Draw one record from a priority-weighted list.
 *
 * Sums every record's @c priority, draws a value in that range, and returns the record whose
 * cumulative priority window contains the draw.
 * @param list The candidate records, each carrying a @c priority.
 * @return The drawn record, or @c nil.
 * @ghidraAddress 0x2597cc
 */
+ (nullable NSDictionary *)getLotteryInterstitialDataWithList:(nullable NSArray *)list;

/**
 * @brief The interstitial display-specification list sorted by descending priority.
 * @return The @c ad_display_spec entries sorted by @c priority.
 * @ghidraAddress 0x259a60
 */
+ (nullable NSArray *)getInterstitialSpecPriorityList;

/**
 * @brief Filter a display-specification list by remaining display count.
 *
 * Keeps the entries whose recorded daily and total display counts are still below their
 * @c max_display_count_daily and @c max_display_count_total limits.
 * @param list The @c ad_display_spec entries to filter.
 * @return The entries that may still be displayed.
 * @ghidraAddress 0x259b70
 */
+ (nullable NSArray *)getInterstitialSpecCountForAdDisplaySpecList:(nullable NSArray *)list;

/**
 * @brief Filter a display-specification list by install state, movie capability, and display term.
 *
 * Keeps the entries whose advert is installed (or whose install is not required), which are movie
 * capable when @p movieFlg is set, and whose display term has not expired, carrying the @c priority
 * through to each surviving record.
 * @param list The @c ad_display_spec entries to filter.
 * @param movieFlg Whether only movie-capable interstitials are eligible.
 * @return The entries that may still be displayed.
 * @ghidraAddress 0x25a0bc
 */
+ (nullable NSArray *)getInterstitialSpecInstallForAdDisplaySpecList:(nullable NSArray *)list
                                                            movieFlg:(BOOL)movieFlg;

/**
 * @brief Whether an advert-data record describes a movie creative.
 *
 * The record is a movie when its @c external_ad_disp_mng.ad_content_kind equals the movie kind and
 * it carries a non-empty @c movie_url.
 * @param adData The advert-data record.
 * @return @c YES when the record is a playable movie creative.
 * @ghidraAddress 0x25a860
 */
+ (BOOL)checkMovieWithAdData:(nullable NSDictionary *)adData;

/**
 * @brief The interstitial advert records for a display-specification list.
 *
 * Resolves each entry's advert data by @c ad_id_to, narrows it to the interstitial advert type,
 * keeps the records that carry a non-empty @c interstitial_banner_url, and de-duplicates them.
 * @param list The @c ad_display_spec entries.
 * @return The de-duplicated interstitial advert records.
 * @ghidraAddress 0x25aa08
 */
+ (nullable NSArray *)getAdInterstitialUrlListTermForAdDisplaySpecList:(nullable NSArray *)list;

/**
 * @brief The de-duplicated poster-rectangle records for every movie advert.
 * @return The @c poster_url_rect_list entries of the movie adverts, de-duplicated.
 * @ghidraAddress 0x25ae10
 */
+ (nullable NSArray *)getPosterUrlList;

/**
 * @brief The de-duplicated interstitial banner URLs of a list.
 * @param list The advert records to gather from.
 * @return The non-empty @c interstitial_banner_url_list entries, de-duplicated.
 * @ghidraAddress 0x25b21c
 */
+ (nullable NSArray *)getAdInterstitialUrlListTermForList:(nullable NSArray *)list;

/**
 * @brief The de-duplicated movie URLs decoded from every advert's @c movie_url_list.
 *
 * Strips the @c applilink://ext-app:80/movie? prefix, URL-decodes the payload, splits it on @c &,
 * strips the @c movie_url= prefix from each field, URL-decodes it, and keeps the non-empty results.
 * @return The decoded movie URLs, de-duplicated.
 * @ghidraAddress 0x25b558
 */
+ (nullable NSArray *)getMovieUrlList;

/**
 * @brief The archived daily advert-display-count dictionary, valid only for today.
 *
 * Unarchives the @c adDisplayCountDaily blob and returns it only when its recorded @c adDisplayDate
 * matches the current day; otherwise @c nil.
 * @return The daily display-count dictionary, or @c nil.
 * @ghidraAddress 0x25ba64
 */
+ (nullable NSDictionary *)getAdDisplayCountDailyDictionary;

/**
 * @brief The archived total advert-display-count dictionary.
 * @return The total display-count dictionary, or @c nil.
 * @ghidraAddress 0x25bc60
 */
+ (nullable NSDictionary *)getAdDisplayCountTotalDictionary;

/**
 * @brief The advert type for an advert model at an ad location.
 *
 * Searches the advert-model setting list for the entry matching @p adLocation and @p adModel and
 * returns its @c ad_type value, defaulting to the app-banner type when there is no match.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @return The advert-type identifier.
 * @ghidraAddress 0x25bd10
 */
+ (int)getAdTypeWithAdModel:(int)adModel adLocation:(nullable NSString *)adLocation;

/**
 * @brief Filter a list to the records still within their display term.
 *
 * Keeps the records whose @c external_ad_disp_mng.end_date is at or after the current time.
 * @param list The advert records to filter.
 * @return The records still within their display term.
 * @ghidraAddress 0x25c008
 */
+ (nullable NSArray *)getAdListTermForList:(nullable NSArray *)list;

/**
 * @brief The de-duplicated banner URLs of a list, gathered from each record's @c banner_url_list.
 * @param list The advert records to gather from.
 * @return The non-empty @c banner_url_list entries.
 * @ghidraAddress 0x25c38c
 */
+ (nullable NSArray *)getAdBannerListForList:(nullable NSArray *)list;

/**
 * @brief A randomly shuffled copy of a list.
 * @param list The list to shuffle.
 * @return A new array with the elements of @p list in random order.
 * @ghidraAddress 0x25c690
 */
+ (nullable NSArray *)shuffled:(nullable NSArray *)list;

/**
 * @brief Run the interstitial-display frequency lottery for an ad location.
 *
 * Reads the @c frequency_n / @c frequency_m specification for @p adLocation, advances the persisted
 * per-location frequency counters, and decides whether the interstitial should be shown this time.
 * @param adLocation The ad-location identifier.
 * @return @c nil when the interstitial should be shown, otherwise a localised @c NSError describing
 * why it was suppressed.
 * @ghidraAddress 0x25c834
 */
+ (nullable NSError *)lotteryInterstitialWithAdLocation:(nullable NSString *)adLocation;

/**
 * @brief The install-flag string for an advert-data record.
 *
 * Returns @c "1" when the record's @c install_flg is already set, or when the record's
 * @c default_scheme URL can be opened by the device; otherwise @c "0".
 * @param adData The advert-data record.
 * @return @c "1" or @c "0".
 * @ghidraAddress 0x25cfec
 */
+ (nullable NSString *)getInstallFlgWithAdData:(nullable NSDictionary *)adData;

/**
 * @brief The debug movie advert-data record for a movie URL.
 *
 * Searches @c RecommendDebug.movieList for the record whose @c movie_url equals @p movieUrl,
 * copies it, and attaches the install-flag string.
 * @param movieUrl The movie URL to match.
 * @return The movie advert-data record, or @c nil.
 * @ghidraAddress 0x25d284
 */
+ (nullable NSDictionary *)getMovieAdData:(nullable NSString *)movieUrl;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
