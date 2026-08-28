/** @file
 * One challenge mission sheet: a named, dated group of missions with its reward and progress.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeMissionSheet, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The same shape as the other challenge model classes: @c -initWithDictionary: reads the server's
 * JSON in, @c -generateMissionSheetDictionary writes it back out, and @c -generateSaveData ciphers
 * an archived copy for local persistence.
 */

#import <Foundation/Foundation.h>

@class ChallengeMissionReward;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A challenge mission sheet's identity, dates, reward, and mission tables.
 */
@interface ChallengeMissionSheet : NSObject

/** @brief Whether the player has confirmed (seen) the sheet. Wire key @c "confirm_flag". */
@property(nonatomic, readonly) BOOL bConfirmed;
/** @brief The sheet's display name. Wire key @c "name". */
@property(nonatomic, readonly, nullable) NSString *sheetName;
/** @brief The sheet's identifier. Wire key @c "sheet_id". */
@property(nonatomic, readonly) int sheetID;
/** @brief The number of missions in the sheet. Wire key @c "amount". */
@property(nonatomic, readonly) int missionCnt;
/** @brief The total mission count across the campaign. Wire key @c "total". */
@property(nonatomic, readonly) int totalMissionCnt;
/** @brief Whether this is an event sheet. Wire key @c "is_event". */
@property(nonatomic, readonly) BOOL isEvent;
/** @brief The sheet's version tag. Wire key @c "version". Defaults to the empty string. */
@property(nonatomic, readonly, nullable) NSString *updateTime;
/** @brief When the sheet becomes visible. Wire key @c "view_start". Defaults to the empty string.
 */
@property(nonatomic, readonly, nullable) NSString *sheetStartDate;
/** @brief When the sheet stops being visible. Wire key @c "view_end". Defaults to empty string. */
@property(nonatomic, readonly, nullable) NSString *sheetEndDate;
/** @brief The sheet's background image URL. */
@property(nonatomic, readonly, nullable) NSString *sheetBgURL;
/** @brief The sheet's reward. Wire key @c "reward". */
@property(nonatomic, readonly, nullable) ChallengeMissionReward *reward;
/** @brief The @c ChallengeMissionTerms for each mission. Built from wire key @c "mission_list". */
@property(nonatomic, readonly, nullable) NSArray *missionTable;
/** @brief The @c ChallengeMissionAchieve for each mission, when every mission has one. */
@property(nonatomic, readonly, nullable) NSArray *missionAchieveTable;
/** @brief The @c ChallengeMissionPlayTerm for each mission. */
@property(nonatomic, readonly, nullable) NSArray *missionSimpleTable;
/** @brief Whether the sheet holds a complete, saveable mission list. */
@property(nonatomic, readonly) BOOL enableSave;

/**
 * @brief Returns an empty sheet.
 * @return The initialised sheet.
 * @ghidraAddress 0x1f0c08
 */
- (instancetype)init;

/**
 * @brief Fills the sheet in from a server dictionary.
 * @param dictionary The server's sheet record.
 * @ghidraAddress 0x1f0c40
 */
- (void)initWithDictionary:(nullable NSDictionary *)dictionary;

/**
 * @brief Deciphers and unarchives a saved sheet, filling the object in when its id matches.
 * @param data The ciphered, archived sheet data.
 * @param sheetID The expected sheet identifier.
 * @return YES when the data deciphered, unarchived, and matched @p sheetID .
 * @ghidraAddress 0x1f0fd0
 */
- (BOOL)initWithData:(nullable NSData *)data sheetID:(int)sheetID;

/**
 * @brief Rebuilds the mission-terms table (and the reward) from a server dictionary.
 *
 * Sorts the @c "mission_list" entries by ascending numeric key, builds a @c ChallengeMissionTerms
 * for each, and marks the sheet saveable only when the built count matches @c missionCnt .
 * @param dictionary The server's sheet record.
 * @ghidraAddress 0x1f1134
 */
- (void)updateMissionTerms:(nullable NSDictionary *)dictionary;

/**
 * @brief Rebuilds the achievement and play-term tables from an achievement dictionary.
 *
 * For each mission term, looks up its achievement record by the @c "%d" -formatted mission id,
 * building a @c ChallengeMissionAchieve and a @c ChallengeMissionPlayTerm ; the achievement table
 * is kept only when every mission matched.
 * @param dictionary The achievement records keyed by mission id.
 * @ghidraAddress 0x1f1584
 */
- (void)updateMissionAchieves:(nullable NSDictionary *)dictionary;

/**
 * @brief Ciphers an archived copy of the sheet for local persistence.
 * @return The ciphered archived data, or @c nil when the sheet is not saveable.
 * @ghidraAddress 0x1f1994
 */
- (nullable NSData *)generateSaveData;

/**
 * @brief Writes the sheet back out in the server's dictionary format.
 * @return The sheet dictionary.
 * @ghidraAddress 0x1f1ac4
 */
- (nullable NSMutableDictionary *)generateMissionSheetDictionary;

/**
 * @brief Builds the @c "mission_list" dictionary mapping each mission's dictionary to its boxed id.
 * @return The mission dictionary, or @c nil when there are no missions.
 * @ghidraAddress 0x1f1e5c
 */
- (nullable NSDictionary *)generateMissionDictionary;

/**
 * @brief Marks the sheet confirmed, reporting whether this call was the one that changed it.
 * @return YES when the sheet had not been confirmed before this call.
 * @ghidraAddress 0x1f2084
 */
- (BOOL)checkMissionSheet;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
