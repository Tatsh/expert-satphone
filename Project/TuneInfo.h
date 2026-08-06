/** @file
 * One tune's catalogue entry.
 *
 * Reconstructed from Ghidra program Jubeat (class TuneInfo, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject, from the dyld bind at the class object's superclass slot
 * (0x34d170).
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A tune, its three difficulty levels, and how it sorts.
 */
@interface TuneInfo : NSObject

/**
 * @brief Where the tune's data lives.
 */
@property(nonatomic, strong, nullable) NSString *filePath;

/**
 * @brief The tune's title.
 */
@property(nonatomic, strong, nullable) NSString *name;

/**
 * @brief The title's reading, used for sorting.
 */
@property(nonatomic, strong, nullable) NSString *nameYomi;

/**
 * @brief The artist.
 */
@property(nonatomic, strong, nullable) NSString *artist;

/**
 * @brief Where to buy the tune.
 */
@property(nonatomic, strong, nullable) NSString *iTunesURL;

/**
 * @brief The basic chart's level. A @c char in the metadata, not an @c int .
 */
@property(nonatomic) char lvBas;

/**
 * @brief The advanced chart's level.
 */
@property(nonatomic) char lvAdv;

/**
 * @brief The extreme chart's level.
 */
@property(nonatomic) char lvExt;

/**
 * @brief The tune's identifier.
 */
@property(nonatomic) unsigned int tuneID;

/**
 * @brief Which extend pack the tune belongs to, or zero.
 */
@property(nonatomic) unsigned int extendID;

/**
 * @brief The tune's extend flags, or zero.
 */
@property(nonatomic) unsigned int extendFlag;

/**
 * @brief The tune's hold-marker flags, or zero.
 */
@property(nonatomic) unsigned int holdFlag;

/**
 * @brief Builds a tune from a catalogue dictionary.
 *
 * The purchase link is resolved in two steps: the store's own link wins, and the dictionary's
 * @c iTunesURL is only consulted when the store has none. The three extend fields are zeroed
 * first and then filled in only for the keys the extend record actually carries.
 *
 * @param filePath Where the tune's data lives.
 * @param dictionary The catalogue entry.
 * @return The initialised tune.
 * @ghidraAddress 0x770bc
 */
- (instancetype)initWithfilePath:(nullable NSString *)filePath
                      dictionary:(nullable NSDictionary *)dictionary;

/**
 * @brief The tune as a dictionary, in the same shape the catalogue uses.
 *
 * @c Name is written without a nil check while @c NameYomi and @c Artist are guarded; see
 * TYPES_PENDING.md.
 *
 * @return An immutable copy.
 * @ghidraAddress 0x775d0
 */
- (nullable NSDictionary *)infoDict;

/**
 * @brief Whether the tune is a licensed track rather than an original.
 *
 * Decided from the leading digit of the identifier rendered as nine zero-padded decimals, so it is
 * really a test for an identifier in the two-hundred-million to four-hundred-million range.
 *
 * @return YES for a licensed tune.
 * @ghidraAddress 0x778a0
 */
- (BOOL)isLicensedTune;

/**
 * @brief Orders two tunes with licensed ones first, then by reading.
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult .
 * @ghidraAddress 0x77930
 */
- (NSInteger)compareLicensedFirst:(nullable TuneInfo *)other;

/**
 * @brief Orders two tunes by their readings, falling back to the identifier.
 *
 * A tune with a reading sorts before one without. When neither has one the order is by identifier
 * **descending**, which is the opposite direction to the reading comparison.
 *
 * @param other The tune to compare against.
 * @return An @c NSComparisonResult .
 * @ghidraAddress 0x779c4
 */
- (NSInteger)compareYomi:(nullable TuneInfo *)other;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
