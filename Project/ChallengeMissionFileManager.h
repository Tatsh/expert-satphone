/**
 * @file
 * @brief The on-disk store for challenge-mission sheets.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeMissionFileManager, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * A singleton that owns the in-memory table of @c ChallengeMissionSheet objects and mirrors it to
 * one file per sheet under @c Documents/sheet , named @c stmps<id>.dat . It loads every sheet at
 * construction, keeps the table sorted by ascending sheet id, and offers add, delete, clean, and
 * existence-check operations that keep the files and the table in step.
 */

#import <Foundation/Foundation.h>

@class ChallengeMissionSheet;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Owns and persists the challenge-mission sheet table.
 */
@interface ChallengeMissionFileManager : NSObject

/**
 * @brief The shared manager, created once on first access.
 * @return The singleton instance.
 * @ghidraAddress 0x1bdf78
 */
+ (instancetype)sharedManager;

/**
 * @brief Loads every saved sheet, sorts the table, and dumps it for debugging.
 * @return The initialised manager.
 * @ghidraAddress 0x1bdff8
 */
- (instancetype)init;

/**
 * @brief The sheet-data directory, creating it when it does not yet exist.
 * @return The @c Documents/sheet path.
 * @ghidraAddress 0x1be0d0
 */
- (nullable NSString *)sheetDataDirectoryPath;

/**
 * @brief Joins a file name onto the sheet-data directory.
 * @param fileName The sheet file's base name.
 * @return The full path.
 * @ghidraAddress 0x1be1a4
 */
- (nullable NSString *)sheetDataFilePath:(nullable NSString *)fileName;

/**
 * @brief The file name for a sheet id.
 * @param sheetID The sheet's identifier.
 * @return A name of the form @c stmps<id>.dat .
 * @ghidraAddress 0x1be228
 */
- (nullable NSString *)sheetDataFileName:(int)sheetID;

/**
 * @brief Writes a sheet's ciphered save data to its file, replacing any existing one.
 * @param sheet The sheet to persist.
 * @ghidraAddress 0x1be260
 */
- (void)saveChallengeMission:(nullable ChallengeMissionSheet *)sheet;

/**
 * @brief Rebuilds the sheet table from every @c stmps<id>.dat file in the directory.
 *
 * Each file is deciphered into a @c ChallengeMissionSheet ; files that fail to load are deleted.
 * The resulting table is sorted by ascending sheet id.
 * @ghidraAddress 0x1be394
 */
- (void)loadChallengeMission;

/**
 * @brief Deletes every stored sheet that is absent from a server sheet list.
 * @param missionSheets The sheets the server still offers.
 * @ghidraAddress 0x1be858
 */
- (void)cleanMissionSheet:(nullable NSArray<ChallengeMissionSheet *> *)missionSheets;

/**
 * @brief Removes a sheet's file from disk.
 * @param sheetID The sheet's identifier.
 * @ghidraAddress 0x1bea70
 */
- (void)deleteMissionSheet:(int)sheetID;

/**
 * @brief Persists a sheet and inserts it into the table in ascending-id order.
 *
 * When a sheet with the same id is already present it is replaced in place.
 * @param sheet The sheet to add.
 * @return YES, always.
 * @ghidraAddress 0x1beb24
 */
- (BOOL)addMissionSheet:(nullable ChallengeMissionSheet *)sheet;

/**
 * @brief Marks a stored sheet confirmed, re-saving it when the flag actually changed.
 * @param sheetID The sheet's identifier.
 * @ghidraAddress 0x1bec98
 */
- (void)confirmedMissionSheet:(int)sheetID;

/**
 * @brief Looks a sheet up in the table by id.
 * @param sheetID The sheet's identifier.
 * @return The matching sheet, or @c nil when none is stored.
 * @ghidraAddress 0x1bed94
 */
- (nullable ChallengeMissionSheet *)getChallengeSheet:(int)sheetID;

/**
 * @brief Tests whether a stored sheet matches a server manifest entry, purging it when stale.
 *
 * A stored sheet whose count or update time differs from the manifest is removed from the table
 * and deleted from disk.
 * @param sheetID The sheet's identifier.
 * @param count The mission count the server reports.
 * @param updateTime The version tag the server reports.
 * @return YES when a current, matching sheet is already stored.
 * @ghidraAddress 0x1beee4
 */
- (BOOL)isExistMissionSheet:(int)sheetID
                      count:(int)count
                 updateTime:(nullable NSString *)updateTime;

/**
 * @brief Whether an event sheet is stored.
 * @return NO, always, in this build.
 * @ghidraAddress 0x1bf0f8
 */
- (BOOL)isExistEventMissionSheet;

/**
 * @brief Dumps the sheet table for debugging.
 * @ghidraAddress 0x1bf100
 */
- (void)printSheetData;

/** @brief The id of the sheet the player last selected. @ghidraAddress 0x1bf104 */
@property(nonatomic, readonly) int selectedSheetID;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
