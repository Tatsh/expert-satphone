/**
 * @file
 * @brief The Core Data migration that rebuilds the score store.
 *
 * Reconstructed from Ghidra program Jubeat (class ScoreMigrationPolicy, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares two methods for this class and both
 * are implemented.
 *
 * The superclass was read from the class object's superclass slot at 0x34f8a8, which binds to
 * @c _OBJC_CLASS_$_NSEntityMigrationPolicy at load time rather than being stored in the file.
 */

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Carries score records across a store version, recovering scores the old schema truncated.
 *
 * The old store kept each score in a 16-bit field alongside a 16-byte tamper digest computed over
 * the *untruncated* values. On iOS 5 and later the truncation is visible, so the migration cannot
 * simply copy the fields across: it has to work out what the original 32-bit scores were. It does
 * that by brute force, in @c -salvageScore:tid:bas:adv:ext:.
 */
@interface ScoreMigrationPolicy : NSEntityMigrationPolicy

/**
 * @brief Recovers the three original scores by searching for the ones the digest was taken over.
 *
 * Each stored score is the low 16 bits of the original. The method tries every high half from 0 to
 * 16 for each of the three charts, rejects any candidate above one million, recomputes the digest
 * with @c +[ScoreRecord hashScoreforTune:bas:adv:ext:hash:], and compares all 16 bytes against the
 * stored @c "chksco". The first exact match wins and is written back through the out-parameters.
 *
 * A stored value of 0xFFFF combined with the first high half is treated as the sentinel 0xFFFFFFFF,
 * which is how the schema spells "no score recorded" rather than a score of 65535.
 *
 * @param source The record being migrated.
 * @param tuneID The tune identifier, which is part of the digest.
 * @param bas Out-parameter for the recovered basic score. Untouched unless the method answers YES.
 * @param adv Out-parameter for the recovered advanced score.
 * @param ext Out-parameter for the recovered extreme score.
 * @return YES when a candidate reproduced the stored digest exactly.
 * @ghidraAddress 0x15add0
 */
- (BOOL)salvageScore:(NSManagedObject *)source
                 tid:(int)tuneID
                 bas:(int *)bas
                 adv:(int *)adv
                 ext:(int *)ext;
/**
 * @brief Creates the migrated record, verifying or recovering its scores first.
 *
 * Ignores every entity but @c "ScoreRecord". Below iOS 5.0 it takes the stored scores at face value
 * and only checks the digest; from 5.0 upwards it goes through @c -salvageScore:tid:bas:adv:ext:.
 * A record whose scores cannot be verified either way is silently dropped — no destination object
 * is created and no error is reported.
 * @ghidraAddress 0x15b5d4
 */
- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance
                                      entityMapping:(NSEntityMapping *)mapping
                                            manager:(NSMigrationManager *)manager
                                              error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
