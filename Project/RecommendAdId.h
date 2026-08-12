/** @file
 * The Applilink recommend SDK's advertising-identifier record.
 *
 * @c RecommendAdId persists the advertising identifier keyed by country code and category id, and
 * resolves the identifier used for an inbound advert redirect. The Applilink SDK ships as a closed
 * third-party library, so only the methods reachable here are declared. Reconstructed from Ghidra
 * program Jubeat (image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x351d08.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The recommend network's advertising-identifier record.
 */
@interface RecommendAdId : NSObject

/**
 * @brief Initialises the record for a country code and category id.
 * @param countryCode The country code.
 * @param categoryId The advert category identifier.
 * @return The initialised record.
 * @ghidraAddress 0x22ba00
 */
- (instancetype)initWithCountryCode:(nullable NSString *)countryCode
                         categoryId:(nullable NSString *)categoryId;

/**
 * @brief Loads the stored advertising identifier for a country code and category id.
 * @param countryCode The country code.
 * @param categoryId The advert category identifier.
 * @param error On failure, the localised error; may be @c nullptr.
 * @return The stored record, or nil.
 * @ghidraAddress 0x22bad8
 */
- (nullable NSDictionary *)getWithCountryCode:(nullable NSString *)countryCode
                                   categoryId:(nullable NSString *)categoryId
                                        error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Stores the advertising identifier for an inbound advert redirect.
 * @param adIdFrom The source advertising identifier.
 * @param countryCode The country code.
 * @param categoryId The advert category identifier.
 * @param adType The advert-type string.
 * @param error On failure, the localised error; may be @c nullptr.
 * @ghidraAddress 0x22be90
 */
- (void)setWithAdIdFrom:(nullable NSString *)adIdFrom
            countryCode:(nullable NSString *)countryCode
             categoryId:(nullable NSString *)categoryId
                 adType:(nullable NSString *)adType
                  error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Deletes the stored advertising identifier for a country code and category id.
 * @param countryCode The country code.
 * @param categoryId The advert category identifier.
 * @param error On failure, the localised error; may be @c nullptr.
 * @return @c NO when the udid or pasteboard is unavailable, otherwise @c YES .
 * @ghidraAddress 0x22c5a4
 */
- (BOOL)deleteWithCountryCode:(nullable NSString *)countryCode
                   categoryId:(nullable NSString *)categoryId
                        error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
