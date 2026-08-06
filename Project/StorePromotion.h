/** @file
 * One promoted item in the store.
 *
 * Reconstructed from Ghidra program Jubeat (class StorePromotion, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the member @c BannerView
 * reaches is declared; the class also carries @c -initWithPackInfo:imageURL:sampleURL:,
 * @c -initWithGenreIndex:imageURL:, @c -getSampleURL and @c -getSampleName, listed in
 * TYPES_PENDING.md.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A promoted pack or genre, with its banner artwork and sample list.
 *
 * Backed by five ivars: @c playSlot, @c _genreIndex, @c _packInfo (a @c StorePackInfo),
 * @c _imageURL and @c _sampleList.
 */
@interface StorePromotion : NSObject

/**
 * @brief The banner artwork's address, as text.
 *
 * DECLARED ONLY — the accessor is synthesised, but nothing else about the class is reconstructed.
 * @ghidraAddress 0x1bda70 (getter)
 */
@property(nonatomic, readonly, nullable) NSString *imageURL;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
