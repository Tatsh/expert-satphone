/** @file
 * The purchasable-music catalogue.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreMusicListManager, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: five of seventeen members written. The shared instance, init, and catalogue
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
