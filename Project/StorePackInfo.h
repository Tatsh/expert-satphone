/** @file
 * One purchasable pack in the store.
 *
 * Reconstructed from Ghidra program Jubeat (class StorePackInfo, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x34ded8.
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A pack's identity, name, price, store flags, and track list.
 */
@interface StorePackInfo : NSObject

/**
 * @brief The pack's identifier. Four bytes in the metadata, so @c int.
 * @ghidraAddress 0xbe3d0 (getter)
 */
@property(nonatomic, readonly) int packID;
/** @brief Whether to show the "new" marker. @ghidraAddress 0xbe3e0 (getter) */
@property(nonatomic, readonly) BOOL isNew;
/** @brief Whether to show the "extend" marker. @ghidraAddress 0xbe3f0 (getter) */
@property(nonatomic, readonly) BOOL hasExtend;
/** @brief The pack artwork's address. @ghidraAddress 0xbe400 (getter) */
@property(nonatomic, readonly, nullable) NSString *artworkURL;
/** @brief The pack's display name. @ghidraAddress 0xbe410 (getter) */
@property(nonatomic, readonly, nullable) NSString *packName;
/** @brief The pack's long description. @ghidraAddress 0xbe420 (getter) */
@property(nonatomic, readonly, nullable) NSString *comment;
/** @brief The pack's one-line comment. @ghidraAddress 0xbe430 (getter) */
@property(nonatomic, readonly, nullable) NSString *shortComment;
/** @brief The pack's copyright line. @ghidraAddress 0xbe440 (getter) */
@property(nonatomic, readonly, nullable) NSString *copyright;
/** @brief The related-site link URL string. @ghidraAddress 0xbe450 (getter) */
@property(nonatomic, readonly, nullable) NSString *linkURL;
/** @brief The related-site link title. @ghidraAddress 0xbe460 (getter) */
@property(nonatomic, readonly, nullable) NSString *linkTitle;
/** @brief The pack's tracks, each a @c StoreMusicInfo. @ghidraAddress 0xbe470 (getter) */
@property(nonatomic, readonly, nullable) NSArray *musicInfos;
/** @brief The StoreKit product backing the pack. @ghidraAddress 0xbe480 (getter) */
@property(nonatomic, readonly, nullable) SKProduct *product;
/** @brief The regular (pre-discount) yen price. @ghidraAddress 0xbe490 (getter) */
@property(nonatomic, readonly, nullable) NSDecimalNumber *regularPriceJPY;

/**
 * @brief The formatted price string, or nil when there is no product.
 * @ghidraAddress 0xbd5ac (getter)
 */
@property(nonatomic, readonly, nullable) NSString *priceString;
/**
 * @brief The price styled for display; a struck-through regular price precedes a discounted price.
 * @ghidraAddress 0xbd6b4 (getter)
 */
@property(nonatomic, readonly, nullable) NSAttributedString *attributedPriceString;

/**
 * @brief Builds a pack from a store dictionary and its StoreKit product.
 * @param dictionary The store's pack dictionary, or nil to seed only from the product.
 * @param product The StoreKit product, or nil.
 * @return The initialised pack.
 * @ghidraAddress 0xbd4a0
 */
- (instancetype)initWithDictionary:(nullable NSDictionary *)dictionary
                           product:(nullable SKProduct *)product;

/**
 * @brief The best artwork URL for the current device from a pack dictionary.
 *
 * On a Retina pad the HD address is preferred when valid; otherwise the standard address is used,
 * and either way an invalid address yields nil.
 * @param dictionary The pack dictionary.
 * @return The artwork URL string, or nil.
 * @ghidraAddress 0xbdb4c
 */
- (nullable NSString *)getArtworkURL:(nullable NSDictionary *)dictionary;

/**
 * @brief Fills the pack from a store list dictionary.
 * @param dictionary The pack dictionary.
 * @ghidraAddress 0xbdca0
 */
- (void)setPackInfo:(nullable NSDictionary *)dictionary;

/**
 * @brief Fills the pack's detail-only fields from a detail dictionary, keeping any already set.
 * @param dictionary The detail dictionary.
 * @return Whether the track list was populated.
 * @ghidraAddress 0xbdf84
 */
- (BOOL)setPackDetailInfo:(nullable NSDictionary *)dictionary;

/**
 * @brief Builds the track list from an array of track dictionaries, unless it is already set.
 * @param musicList The array of track dictionaries.
 * @return Whether the track list ended up populated.
 * @ghidraAddress 0xbe18c
 */
- (BOOL)setMusicInfo:(nullable NSArray *)musicList;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
