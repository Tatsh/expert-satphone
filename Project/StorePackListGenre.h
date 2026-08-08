/** @file
 * A store genre model describing one pack-list genre: its display name, identifier, banner artwork
 * and colours, description, and the pack identifiers it accumulates as catalogue pages are fetched.
 * Used by the pack store's genre list and headings (@c StoreGenreTitleView and
 * @c StoreGenreBannerView).
 *
 * Reconstructed from Ghidra program Jubeat (class StorePackListGenre, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A store model for a single pack-list genre.
 */
@interface StorePackListGenre : NSObject

/**
 * @brief The genre's display name.
 */
@property(nonatomic, readonly, nullable) NSString *genreName;

/**
 * @brief The genre identifier.
 */
@property(nonatomic, readonly) NSUInteger genreID;

/**
 * @brief Whether the server reported a further catalogue page for this genre.
 */
@property(nonatomic, readonly) BOOL packlistContinued;

/**
 * @brief The number of packs already fetched for this genre, used as the next page offset.
 */
@property(nonatomic, readonly) NSUInteger numFetchedPack;

/**
 * @brief The genre's description.
 */
@property(nonatomic, readonly, nullable) NSString *genreComment;

/**
 * @brief The banner tile's artwork address, distinct from @c genreBgImageURL.
 * @ghidraAddress 0x1b0dd4
 */
@property(nonatomic, readonly, nullable) NSString *genreImageURL;

/**
 * @brief The banner tile's border colour.
 * @ghidraAddress 0x1b0de4
 */
@property(nonatomic, readonly, nullable) UIColor *genreColor;

/**
 * @brief The heading's backdrop colour.
 */
@property(nonatomic, readonly, nullable) UIColor *genreBGColor;

/**
 * @brief The heading banner's address.
 */
@property(nonatomic, readonly, nullable) NSString *genreBgImageURL;

/**
 * @brief Parse a slash-separated "red/green/blue" byte triple into a colour with the given alpha.
 * @param colorString The colour string, expected as three slash-separated 0-255 components.
 * @param alpha The alpha to apply to the parsed colour.
 * @return The parsed colour, or @c nil when the string is not exactly three components.
 * @ghidraAddress 0x1b0418
 */
- (nullable UIColor *)getColor:(nullable NSString *)colorString alpha:(float)alpha;

/**
 * @brief Build a genre with the given display name and identifier.
 * @param name The genre display name.
 * @param genreID The genre identifier.
 * @return The initialised genre.
 * @ghidraAddress 0x1b0594
 */
- (instancetype)initWithName:(nullable NSString *)name genreID:(NSUInteger)genreID;

/**
 * @brief Build a genre with a display name, identifier, banner image address, and colour string.
 * @param name The genre display name.
 * @param genreID The genre identifier.
 * @param imgURL The banner tile artwork address, applied only when non-empty.
 * @param col The slash-separated colour string, applied to @c genreColor and @c genreBGColor only
 *        when non-empty.
 * @return The initialised genre.
 * @ghidraAddress 0x1b06b8
 */
- (instancetype)initWithName:(nullable NSString *)name
                     genreID:(NSUInteger)genreID
                      imgURL:(nullable NSString *)imgURL
                         col:(nullable NSString *)col;

/**
 * @brief Whether the string is present and not empty.
 * @param string The string to test.
 * @return @c YES when the string is non-nil and not equal to the empty string.
 * @ghidraAddress 0x1b08b4
 */
- (BOOL)isExist:(nullable NSString *)string;

/**
 * @brief Fill the genre's banner image, colours, description, and heading image from an extend-info
 *        dictionary, keeping any field whose key is absent or empty.
 * @param info The extend-info dictionary.
 * @ghidraAddress 0x1b0910
 */
- (void)setExtendInfo:(nullable NSDictionary *)info;

/**
 * @brief The number of packs accumulated for this genre.
 * @return The pack count.
 * @ghidraAddress 0x1b0bc8
 */
- (NSUInteger)packCount;

/**
 * @brief The accumulated pack identifiers for this genre.
 * @return The boxed pack identifiers.
 * @ghidraAddress 0x1b0be0
 */
- (NSArray<NSNumber *> *)packList;

/**
 * @brief The boxed pack identifier at the given index, or @c nil when out of range.
 * @param index The pack index.
 * @return The boxed pack identifier, or @c nil.
 * @ghidraAddress 0x1b0bf0
 */
- (nullable NSNumber *)packInfoForIndex:(NSUInteger)index;

/**
 * @brief Append a fetched page of pack identifiers to the genre.
 * @param list The pack-identifier numbers from the page.
 * @param step The page size requested, added to @c numFetchedPack.
 * @param hasNext Whether the server reports a further page.
 * @ghidraAddress 0x1b0c5c
 */
- (void)updateList:(nullable NSArray<NSNumber *> *)list step:(NSUInteger)step hasNext:(BOOL)hasNext;

/**
 * @brief Set the genre description from a dictionary's @c Comment entry when present.
 * @param info The genre-info dictionary.
 * @ghidraAddress 0x1b0ce4
 */
- (void)updateGenreInfo:(nullable NSDictionary *)info;

/**
 * @brief Copy genre data from another genre. A no-op in the shipped binary.
 * @param genre The genre to copy from.
 * @ghidraAddress 0x1b0d80
 */
- (void)copyGenreData:(nullable StorePackListGenre *)genre;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
