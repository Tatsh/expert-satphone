/** @file
 * One mission's achievement record, as the challenge server sends it.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeMissionAchieve, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject, taken from the dyld bind at the class object's superclass slot
 * (0x351270).
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The wire keys of a mission achievement record.
 */
typedef NSString *ChallengeMissionAchieveKey NS_TYPED_ENUM;
/** @brief The mission's identifier. */
extern ChallengeMissionAchieveKey const ChallengeMissionAchieveKeyMissionID;
/** @brief The alternative mission identifier, read only when the first is zero. */
extern ChallengeMissionAchieveKey const ChallengeMissionAchieveKeyMasterMissionID;
/** @brief The achievement's identifier. */
extern ChallengeMissionAchieveKey const ChallengeMissionAchieveKeyAchievementID;
/** @brief The mission's state. */
extern ChallengeMissionAchieveKey const ChallengeMissionAchieveKeyStatus;
/** @brief The per-mission detail dictionary. */
extern ChallengeMissionAchieveKey const ChallengeMissionAchieveKeyData;
/** @brief The date the mission was cleared. */
extern ChallengeMissionAchieveKey const ChallengeMissionAchieveKeyClearDate;

/**
 * @brief A mission's identity, state and progress detail.
 *
 * Every property is readonly; the two loaders below write the ivars directly.
 */
@interface ChallengeMissionAchieve : NSObject

/** @brief The mission this record is about. -1 until loaded. */
@property(nonatomic, readonly) int missionID;
/** @brief The achievement within that mission. -1 until loaded. */
@property(nonatomic, readonly) int achievementID;
/** @brief The mission's state. -1 until loaded. */
@property(nonatomic, readonly) int missionState;
/** @brief The per-mission progress detail, copied on load. */
@property(nonatomic, readonly, nullable) NSDictionary *achieveDetail;
/** @brief The clear date, as the server's text. Retained on load, not copied. */
@property(nonatomic, readonly, nullable) NSString *termCompleteDate;

/**
 * @brief Returns an empty record with the three identifiers set to -1.
 * @return The initialised record.
 * @ghidraAddress 0x1eed9c
 */
- (instancetype)init;

/**
 * @brief Loads every field from a server record.
 *
 * **This returns @c BOOL, not an object,** despite its name. The metadata encodes it
 * @c B24@0:8@16 and the body ends in a bare @c mov @c w0,#1 — it also never chains to
 * @c -init or @c [super @c init]. It is a loader wearing an initialiser's name, and it always
 * answers YES.
 *
 * @param dict The server's record.
 * @return Always YES.
 * @ghidraAddress 0x1eee00
 */
- (BOOL)initWithDictionary:(nullable NSDictionary *)dict;

/**
 * @brief Merges a later server record into this one.
 *
 * Does nothing unless the record's mission identifier matches this one's. Each remaining field is
 * applied only if the record carries its key, so a partial record updates only what it mentions.
 *
 * @param dict The server's record.
 * @ghidraAddress 0x1eefc0
 */
- (void)updateAchieve:(nullable NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
