/** @file
 * The persisted score record.
 *
 * Reconstructed from Ghidra program Jubeat (class ScoreRecord, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the two class methods
 * @c ScoreMigrationPolicy sends are declared. The class object is at 0x3481f8.
 */

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief One tune's scores, as stored by Core Data.
 */
@interface ScoreRecord : NSManagedObject

/**
 * @brief Computes the tamper check for a set of scores.
 *
 * Writes a 16-byte digest, which is the width @c ScoreMigrationPolicy reads back and compares.
 * DECLARED ONLY.
 *
 * @param tuneID The tune the scores belong to.
 * @param bas The basic chart's score.
 * @param adv The advanced chart's score.
 * @param ext The extreme chart's score.
 * @param hash A 16-byte buffer to write the digest into.
 */
+ (void)hashScoreforTune:(int)tuneID
                     bas:(int)bas
                     adv:(int)adv
                     ext:(int)ext
                    hash:(unsigned char *)hash;
/**
 * @brief The tamper check for an existing record. DECLARED ONLY.
 * @param record The record to digest.
 */
+ (nullable NSData *)hashScore:(id)record;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
