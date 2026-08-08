/** @file
 * The persisted score record.
 *
 * Reconstructed from Ghidra program Jubeat (class ScoreRecord, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x3481f8.
 */

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief One tune's scores, as stored by Core Data: the per-difficulty best score, play-mode
 * marker, full-combo flag, and full-marker blob, plus a tamper-check digest over the three scores.
 */
@interface ScoreRecord : NSManagedObject

/** @brief The tune identifier. */
@property(nonatomic, strong, nullable) NSNumber *tuneID;
/** @brief Whether the basic chart was full-combo'd. */
@property(nonatomic, strong, nullable) NSNumber *fcBas;
/** @brief Whether the advanced chart was full-combo'd. */
@property(nonatomic, strong, nullable) NSNumber *fcAdv;
/** @brief Whether the extreme chart was full-combo'd. */
@property(nonatomic, strong, nullable) NSNumber *fcExt;
/** @brief The basic chart's full-marker blob. */
@property(nonatomic, strong, nullable) NSData *mbBas;
/** @brief The advanced chart's full-marker blob. */
@property(nonatomic, strong, nullable) NSData *mbAdv;
/** @brief The extreme chart's full-marker blob. */
@property(nonatomic, strong, nullable) NSData *mbExt;
/** @brief The basic chart's best score. */
@property(nonatomic, strong, nullable) NSNumber *scoBas;
/** @brief The advanced chart's best score. */
@property(nonatomic, strong, nullable) NSNumber *scoAdv;
/** @brief The extreme chart's best score. */
@property(nonatomic, strong, nullable) NSNumber *scoExt;
/** @brief The last time this tune was played. */
@property(nonatomic, strong, nullable) NSDate *lastPlayDate;
/** @brief The number of times this tune was played. */
@property(nonatomic, strong, nullable) NSNumber *playCount;
/** @brief The basic chart's play-mode marker. */
@property(nonatomic, strong, nullable) NSNumber *pmBas;
/** @brief The advanced chart's play-mode marker. */
@property(nonatomic, strong, nullable) NSNumber *pmAdv;
/** @brief The extreme chart's play-mode marker. */
@property(nonatomic, strong, nullable) NSNumber *pmExt;
/** @brief Whether the full-combo state has been checked. */
@property(nonatomic, strong, nullable) NSNumber *fcCheck;
/** @brief The tamper-check digest over the three scores. */
@property(nonatomic, strong, nullable) NSData *chksco;

/**
 * @brief Fetches the record for a tune.
 * @param tuneID The tune identifier.
 * @return The record, or nil when none exists.
 * @ghidraAddress 0x9bc90
 */
+ (nullable ScoreRecord *)recordForTuneID:(unsigned int)tuneID;

/**
 * @brief Fetches the records for a list of tunes.
 * @param tuneIDs The tune identifiers.
 * @return The matching records.
 * @ghidraAddress 0x9be20
 */
+ (nullable NSArray<ScoreRecord *> *)recordsForTuneIDs:(nullable NSArray *)tuneIDs;

/**
 * @brief Fetches every record.
 * @return All the records.
 * @ghidraAddress 0x9bf94
 */
+ (nullable NSArray<ScoreRecord *> *)allRecords;

/**
 * @brief Inserts and initialises a fresh record for a tune (scores cleared, play markers maxed).
 * @param tuneID The tune identifier.
 * @return The new record.
 * @ghidraAddress 0x9c098
 */
+ (nullable ScoreRecord *)createRecordWithTuneID:(unsigned int)tuneID;

/**
 * @brief Resets a record's scores, markers, and full-combo flags to their defaults.
 * @param record The record to reset.
 * @ghidraAddress 0x9c49c
 */
+ (void)reset:(nullable ScoreRecord *)record;

/**
 * @brief Computes the tamper check for a set of scores.
 *
 * Writes a 16-byte digest, which is the width @c ScoreMigrationPolicy reads back and compares.
 *
 * @param tuneID The tune the scores belong to.
 * @param bas The basic chart's score.
 * @param adv The advanced chart's score.
 * @param ext The extreme chart's score.
 * @param hash A 16-byte buffer to write the digest into.
 * @ghidraAddress 0x9c8ac
 */
+ (void)hashScoreforTune:(int)tuneID
                     bas:(int)bas
                     adv:(int)adv
                     ext:(int)ext
                    hash:(unsigned char *)hash;

/**
 * @brief The tamper check for an existing record.
 * @param record The record to digest.
 * @return The 16-byte digest as data.
 * @ghidraAddress 0x9c940
 */
+ (nullable NSData *)hashScore:(nullable ScoreRecord *)record;

/**
 * @brief Whether a record's stored digest matches a fresh digest of its scores.
 * @param record The record to check.
 * @return @c YES when the record is untampered.
 * @ghidraAddress 0x9cad8
 */
+ (BOOL)checkScore:(nullable ScoreRecord *)record;

/**
 * @brief The sum of every valid, untampered score across the current music list.
 * @return The total score.
 * @ghidraAddress 0x9cb8c
 */
+ (NSInteger)totalScore;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
