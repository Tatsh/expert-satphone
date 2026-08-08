/** @file
 * The purchasable-music catalogue.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreMusicListManager, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: ten of seventeen members written. The shared instance, init, and catalogue
 * queries — verified against the disassembly via curl on port 8089.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Holds the list of music available in the store.
 */
@interface StoreMusicListManager : NSObject

/**
 * @brief The shared instance.
 * @ghidraAddress 0xd395c
 */
@property(class, nonatomic, readonly) StoreMusicListManager *sharedManager;

/**
 * @brief Builds the manager and its builtin-music list.
 * @return The initialised manager.
 * @ghidraAddress 0xd39dc
 */
- (instancetype)init;

/**
 * @brief The builtin-music list.
 * @return The array of builtin IDs.
 * @ghidraAddress 0xd3e98
 */
- (NSArray *)builtinMusic;

/**
 * @brief The purchased-music list (arrayMusic).
 * @return The array of purchased music dicts.
 * @ghidraAddress 0xd3ea4
 */
- (NSArray *)purchasedMusic;

/**
 * @brief The extend-music list.
 * @return The array of extend music dicts.
 * @ghidraAddress 0xd3eb0
 */
- (NSArray *)extendMusic;

/**
 * @brief The extend-music dictionary.
 * @return The dict of extend music.
 * @ghidraAddress 0xd3ebc
 */
- (NSDictionary *)extendMusicDictionary;

/**
 * @brief The original-music dictionary.
 * @return The dict of original music.
 * @ghidraAddress 0xd3ec8
 */
- (NSDictionary *)originalMusicDictionary;

/**
 * @brief The combined list of music IDs (builtin + purchased).
 * @return The array of IDs.
 * @ghidraAddress 0xd3ed4
 */
- (NSArray *)listMusicID;

/**
 * @brief The builtin-music list.
 * @ghidraAddress 0xd6b38 (getter)
 * @ghidraAddress 0xd6b48 (setter)
 */
@property(nonatomic, strong, nullable) NSArray *arrayBuiltinMusic;

/**
 * @brief The store's music list.
 * @ghidraAddress 0xd6af0 (getter)
 * @ghidraAddress 0xd6b00 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *arrayMusic;

/**
 * @brief The extend-music list.
 * @ghidraAddress 0xd6b14 (getter)
 * @ghidraAddress 0xd6b24 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *arrayExtendMusic;

/**
 * @brief The extend-music dictionary.
 * @ghidraAddress 0xd6b5c (getter)
 * @ghidraAddress 0xd6b6c (setter)
 */
@property(nonatomic, strong, nullable) NSMutableDictionary *dictExtendMusic;

/**
 * @brief The original-music dictionary.
 * @ghidraAddress 0xd6b80 (getter)
 * @ghidraAddress 0xd6b90 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableDictionary *dictOriginalMusic;

/**
 * @brief The store's own purchase link for a tune, which overrides whatever the tune list carries.
 *
 * Searches arrayMusic for ID == tuneID.
 * @param tuneID The tune.
 * @return The link, or nil when the store has none.
 * @ghidraAddress 0xd40c0
 */
- (nullable NSString *)linkURLForID:(unsigned int)tuneID;

/**
 * @brief The extend-pack record for a tune, if it belongs to one.
 *
 * DECLARED ONLY. The three keys @c -[TuneInfo initWithfilePath:dictionary:] reads out of it are
 * @c extendFlag , @c holdFlag and @c extID , each optional.
 *
 * @param tuneID The tune.
 * @return The record, or nil.
 */
- (nullable NSDictionary *)extendInfoForID:(unsigned int)tuneID;

/**
 * @brief Whether a tune is in the catalogue at all.
 * @param musicID The tune.
 * @return YES when the catalogue lists it.
 * @ghidraAddress 0xd3b1c
 */
- (BOOL)hasMusic:(int)musicID;

/**
 * @brief Loads the store's music list.
 *
 * Sent at 0x9eec, immediately after the four PurchaseManager calls and before the audio session is
 * configured. DECLARED ONLY.
 */
- (void)loadMusicList;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
