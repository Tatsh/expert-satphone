/** @file
 * One scratch track's identity and the player's per-difficulty results.
 *
 * Reconstructed from Ghidra program Jubeat (class ScratchInfo, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x350a20.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A scratch track resolved from the challenge line-up, with the player's score, rank, and
 * full-combo state per difficulty.
 */
@interface ScratchInfo : NSObject

/** @brief The track's music identifier. */
@property(nonatomic) int musicID;

/**
 * @brief The identifier of the pack this track belongs to.
 * @ghidraAddress 0x1cab20
 */
@property(nonatomic) NSInteger packID;

/** @brief Whether the scratch card for this track has been opened. */
@property(nonatomic) BOOL bOpen;

/**
 * @brief The date this scratch track stops being playable.
 * @ghidraAddress 0x1cabf0
 */
@property(nonatomic, strong, nullable) NSDate *endDate;

/**
 * @brief The track's title.
 * @ghidraAddress 0x1cab60
 */
@property(nonatomic, copy, nullable) NSString *musicName;

/**
 * @brief The track's artist.
 * @ghidraAddress 0x1cab84
 */
@property(nonatomic, copy, nullable) NSString *artistName;

/**
 * @brief Builds the track from a store dictionary, looking its details up in the challenge line-up.
 * @param dictionary The store dictionary (carries @c music_id ).
 * @return The initialised track.
 * @ghidraAddress 0x1ca474
 */
- (instancetype)init:(nullable NSDictionary *)dictionary;

/**
 * @brief Updates the per-difficulty results from a rank dictionary.
 * @param dictionary The @c my_rank dictionary.
 * @ghidraAddress 0x1ca854
 */
- (void)openUpdate:(nullable NSDictionary *)dictionary;

/**
 * @brief The player's score for a difficulty (clamped to the first slot beyond the range).
 * @param difficulty The difficulty index.
 * @ghidraAddress 0x1caa60
 */
- (int)getMyScore:(int)difficulty;

/**
 * @brief The player's rank for a difficulty.
 * @param difficulty The difficulty index.
 * @ghidraAddress 0x1caa80
 */
- (int)getMyRank:(int)difficulty;

/**
 * @brief The player's index for a difficulty. Reads the same rank array as @c -getMyRank: — the
 * binary's getter reads the rank ivar despite its name.
 * @param difficulty The difficulty index.
 * @ghidraAddress 0x1caaa0
 */
- (int)getMyIndex:(int)difficulty;

/**
 * @brief Sets the player's rank for a difficulty; the index argument is unused.
 * @param difficulty The difficulty index.
 * @param rank The rank to store (only when non-negative).
 * @param index Unused.
 * @ghidraAddress 0x1caac0
 */
- (void)setMyRank:(int)difficulty rank:(int)rank index:(int)index;

/**
 * @brief Whether the player has a full combo on a difficulty.
 * @param difficulty The difficulty index.
 * @ghidraAddress 0x1caae0
 */
- (BOOL)getFullCombo:(int)difficulty;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
