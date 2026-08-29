/**
 * @file
 * @brief The play restrictions a challenge mission imposes, derived from its terms and current
 * progress.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeMissionPlayTerm, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject.
 */

#import <Foundation/Foundation.h>

#import "ChallengeMissionAchieve.h"
#import "ChallengeMissionTerms.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The lists a mission's play terms resolve to.
 *
 * Every property is readonly; @c -initWithData:achieve: writes the ivars directly and leaves any
 * list it has nothing to say about untouched rather than nilling it.
 */
@interface ChallengeMissionPlayTerm : NSObject

/** @brief Music identifiers the mission excludes. */
@property(nonatomic, readonly, nullable) NSArray *musicNGID;
/** @brief Markers the mission excludes. */
@property(nonatomic, readonly, nullable) NSArray *markerNG;
/** @brief Levels the mission excludes. */
@property(nonatomic, readonly, nullable) NSArray *levelNG;
/** @brief The plays already recorded against the mission. */
@property(nonatomic, readonly, nullable) NSArray *playHistory;
/**
 * @brief Per-column flags saying which of the compared terms still agree across every play.
 *
 * Seven entries of @c NSNumber booleans, indexed by play-term column. Set alongside
 * @c playHistory and only when that is set.
 */
@property(nonatomic, readonly, nullable) NSArray *historyDup;
/** @brief The mission rows still outstanding, once the achieved ones are removed. */
@property(nonatomic, readonly, nullable) NSArray *requireMusicInfo;

/**
 * @brief Returns an empty term with @c -reset already applied.
 * @return The initialised term.
 * @ghidraAddress 0x1ef288
 */
- (instancetype)init;

/**
 * @brief Clears three of the six lists.
 *
 * Only @c musicNGID, @c requireMusicInfo and @c markerNG are cleared. @c levelNG,
 * @c playHistory and @c historyDup are left as they were.
 * @ghidraAddress 0x1ef2e4
 */
- (void)reset;

/**
 * @brief Resolves a mission's terms against its progress.
 *
 * **Returns void, not an object,** despite its name — the metadata encodes it @c v32@0:8@16@24
 * and it never chains to an initialiser. Does nothing unless @c data is mission type 1.
 *
 * @param data The mission's terms.
 * @param achieve The player's progress against that mission.
 * @ghidraAddress 0x1ef338
 */
- (void)initWithData:(nullable ChallengeMissionTerms *)data
             achieve:(nullable ChallengeMissionAchieve *)achieve;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
