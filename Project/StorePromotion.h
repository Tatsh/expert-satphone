/**
 * @file
 * One promoted item in the store.
 *
 * Reconstructed from Ghidra program Jubeat (class StorePromotion, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject.
 *
 * A promotion is either a pack or a genre, never both: the two initialisers fill in one set of
 * fields and clear the other.
 */

#import <Foundation/Foundation.h>

#import "StorePackInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A promoted pack or genre, with its banner artwork and, for a pack, its sample list.
 */
@interface StorePromotion : NSObject

/**
 * The promoted genre's index. Zero for a pack promotion.
 * @ghidraAddress 0x1bda50 (getter)
 */
@property(nonatomic, readonly) NSUInteger genreIndex;

/**
 * The promoted pack. Nil for a genre promotion.
 * @ghidraAddress 0x1bda60 (getter)
 */
@property(nonatomic, readonly, nullable) StorePackInfo *packInfo;

/**
 * The banner artwork's address, as text.
 * @ghidraAddress 0x1bda70 (getter)
 */
@property(nonatomic, readonly, nullable) NSString *imageURL;

/**
 * The pack's sample tracks, one dictionary each. Nil for a genre promotion.
 * @ghidraAddress 0x1bda80 (getter)
 */
@property(nonatomic, readonly, nullable) NSArray *sampleList;

/**
 * Builds a pack promotion and picks which of its samples to play.
 *
 * The sample slot is chosen once here, with @c rand() , and never changes for the promotion's
 * lifetime — so the same track plays every time until the promotion is rebuilt.
 *
 * @param packInfo The promoted pack.
 * @param imageURL The banner artwork's address.
 * @param sampleURL The samples. Despite the name this is the sample **list**, an array of
 * dictionaries, and it is what @c _sampleList holds.
 * @return The initialised promotion.
 * @ghidraAddress 0x1bd754
 */
- (instancetype)initWithPackInfo:(nullable StorePackInfo *)packInfo
                        imageURL:(nullable NSString *)imageURL
                       sampleURL:(nullable NSArray *)sampleURL;

/**
 * Builds a genre promotion.
 *
 * A genre promotion has no samples: both @c _packInfo and @c _sampleList are cleared and the slot
 * is set to zero.
 *
 * @param genreIndex The promoted genre.
 * @param imageURL The banner artwork's address.
 * @return The initialised promotion.
 * @ghidraAddress 0x1bd88c
 */
- (instancetype)initWithGenreIndex:(NSUInteger)genreIndex imageURL:(nullable NSString *)imageURL;

/**
 * The chosen sample's audio address.
 * @return The address, or nil when there is no sample list.
 * @ghidraAddress 0x1bd954
 */
- (nullable NSString *)getSampleURL;

/**
 * The chosen sample's track name.
 *
 * Unlike @c -getSampleURL this one has no nil guard on the sample list; see TYPES_PENDING.md.
 *
 * @return The name.
 * @ghidraAddress 0x1bd9d8
 */
- (nullable NSString *)getSampleName;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
