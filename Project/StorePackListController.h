/**
 * @file
 * The store's pack-list data-model controller.
 *
 * Reconstructed from Ghidra program Jubeat (class StorePackListController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. The class
 * object is at 0x348fc8.
 *
 * The superclass is @c NSObject : @c -init chains to @c [NSObject init] and @c -dealloc to
 * @c [NSObject dealloc].
 *
 * The controller downloads the store's genre and pack catalogue through a @c Downloader , matches
 * the resulting entries to StoreKit products with an @c SKProductsRequest , groups the packs by
 * genre into @c StorePackListGenre models, and reports progress to a weak
 * @c id<StorePackListDelegate> .
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#import "Downloader.h"
#import "StorePackInfo.h"

NS_ASSUME_NONNULL_BEGIN

@class StorePackListController;
@class StorePackListGenre;
@class StorePromotion;

/**
 * Receives the pack-list controller's download outcomes.
 *
 * The selectors are recovered from the messages @c StorePackListController sends its delegate; the
 * protocol itself carries no metadata in the binary.
 */
@protocol StorePackListDelegate <NSObject>
@optional
/**
 * Sent when a catalogue or product fetch fails.
 * @param controller The reporting controller.
 * @param errorMessage The localised error text to present.
 */
- (void)packListDownloadError:(StorePackListController *)controller
                 errorMessage:(nullable NSString *)errorMessage;
/**
 * Sent when a catalogue fetch completes with packs.
 * @param controller The reporting controller.
 * @param isInitial Whether this fetch also loaded the genre and promotion lists for the first time.
 * @param showPack The pack to reveal, or nil when there is none to show.
 */
- (void)packListDownloadSuccess:(StorePackListController *)controller
                      isInitial:(BOOL)isInitial
                       showPack:(nullable StorePackInfo *)showPack;
/**
 * Sent when a fetch completes but yields no packs.
 * @param controller The reporting controller.
 */
- (void)packListDownloadNothing:(StorePackListController *)controller;
/**
 * Sent when an additional single-pack fetch resolves its product.
 * @param controller The reporting controller.
 * @param showPack The resolved pack, or nil.
 */
- (void)additionPackInfoDownloadSuccess:(StorePackListController *)controller
                               showPack:(nullable StorePackInfo *)showPack;
@end

/**
 * Fetches, groups, and vends the store's genre and pack lists.
 */
@interface StorePackListController : NSObject <DownloaderDelegate, SKProductsRequestDelegate>

/**
 * The App Store country recorded from the most recent product's price locale.
 * @return The two-letter country code, or nil before any product has been received.
 * @ghidraAddress 0xcb86c
 */
+ (nullable NSString *)storeCountry;

/**
 * Builds an empty controller seeded with a single "all" genre.
 * @return The initialised controller.
 * @ghidraAddress 0xcb8ac
 */
- (instancetype)init;

/**
 * The number of genres currently held.
 * @return The genre count.
 * @ghidraAddress 0xcb9d8
 */
- (NSUInteger)numGenres;

/**
 * The display names of the held genres, in order.
 * @return The genre names.
 * @ghidraAddress 0xcb9f0
 */
- (NSArray<NSString *> *)genreNames;

/**
 * A copy of the held genre models, in order.
 * @return The genre models.
 * @ghidraAddress 0xcbb20
 */
- (NSArray<StorePackListGenre *> *)genreInfos;

/**
 * Appends genres from a two-element [ids, names] pair, zipping them into genre models.
 * @param genreList A two-element array: an @c NSArray of genre-ID numbers and an @c NSArray of
 *        name strings.
 * @ghidraAddress 0xcbb48
 */
- (void)addGenres:(nullable NSArray *)genreList;

/**
 * Appends genres from a two-element [ids, names] pair and attaches extend info by ID.
 * @param genreList A two-element array of parallel ID and name arrays.
 * @param extendList A dictionary keyed by the decimal-string form of each genre ID, holding extend
 *        info to apply to the built genres.
 * @ghidraAddress 0xcbe80
 */
- (void)addGenres:(nullable NSArray *)genreList extendList:(nullable NSDictionary *)extendList;

/**
 * Builds the promotion list from promotion entries and the valid StoreKit products.
 * @param promotionList The promotion entries, each a dictionary with an @c ID and @c ImageURL.
 * @param validProducts The valid @c SKProduct objects to match pack promotions against.
 * @ghidraAddress 0xcc3e8
 */
- (void)addPromotions:(nullable NSArray *)promotionList
        validProducts:(nullable NSArray<SKProduct *> *)validProducts;

/**
 * The most recently built promotion list.
 * @return The promotions, or nil.
 * @ghidraAddress 0xccba4
 */
- (nullable NSArray<StorePromotion *> *)promotions;

/**
 * The list position of the genre with the given identifier.
 *
 * The binary spells this selector with a lowercase "genreID"; it is kept verbatim.
 * @param genreID The genre identifier to find.
 * @return The genre's index, or 0 when no genre matches.
 * @ghidraAddress 0xccbb4
 */
- (int)genreIndexForgenreID:(NSInteger)genreID;

/**
 * The genre model with the given identifier.
 * @param genreID The genre identifier to find; a negative value yields nil.
 * @return The matching genre, or nil.
 * @ghidraAddress 0xccc80
 */
- (nullable StorePackListGenre *)packListForGenreID:(NSInteger)genreID;

/**
 * The genre model at the given list position.
 * @param genreIndex The genre index.
 * @return The genre at that position, or nil when out of range.
 * @ghidraAddress 0xccd44
 */
- (nullable StorePackListGenre *)packListForGenreIndex:(NSUInteger)genreIndex;

/**
 * Starts a fresh fetch of the first catalogue page for the given genre identifier.
 * @param genreID The genre identifier to fetch.
 * @ghidraAddress 0xccdb0
 */
- (void)startFetchForGenreID:(NSUInteger)genreID;

/**
 * Starts fetching the next catalogue page for the genre at the given list position.
 * @param genreIndex The genre index; out-of-range indices are ignored.
 * @ghidraAddress 0xcce9c
 */
- (void)startFetchForGenreIndex:(NSUInteger)genreIndex;

/**
 * Starts fetching the next page for the given genre model, found by identity.
 * @param genre The genre model to fetch; ignored when not held.
 * @ghidraAddress 0xccfd0
 */
- (void)startFetchGenre:(nullable StorePackListGenre *)genre;

/**
 * Starts a StoreKit request to resolve a single additional pack by identifier.
 * @param packID The boxed pack identifier to resolve; a nil value is ignored.
 * @ghidraAddress 0xcd030
 */
- (void)startFetchAdditionalPack:(nullable NSNumber *)packID;

/**
 * Cancels any in-flight download or product request and clears the pending additional pack.
 * @ghidraAddress 0xcd16c
 */
- (void)cancelFetching;

/**
 * Whether a download or product request is currently in flight.
 *
 * A computed getter over @c packlistDownloader and @c productsRequest ; the property has no ivar.
 * @ghidraAddress 0xcd1e8
 */
@property(nonatomic, readonly) BOOL isFetching;

/**
 * Whether the genre and promotion lists have been loaded at least once.
 * @ghidraAddress 0xcebdc
 */
@property(nonatomic, readonly) BOOL initiallyLoaded;

/**
 * The pending additional-pack identifier, held for the duration of its StoreKit request.
 * @ghidraAddress 0xceb84 (getter), 0xceb94 (setter)
 */
@property(nonatomic, strong, nullable) NSNumber *additionalPackID;

/**
 * The download-outcome delegate.
 * @ghidraAddress 0xceba8 (getter), 0xcebc8 (setter)
 */
@property(nonatomic, weak, nullable) id<StorePackListDelegate> delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
