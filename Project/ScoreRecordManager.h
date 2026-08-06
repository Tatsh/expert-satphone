/** @file
 * The player's score record store, backed by Core Data.
 *
 * Reconstructed from Ghidra program Jubeat (class ScoreRecordManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: grown outwards from its callers. The class object at 0x3480e0 has 12
 * cross-references, the fewest of any class this chase has reached, so it is the closest to
 * complete. Only the members reached so far are declared.
 */

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Owns the persisted score records.
 */
@interface ScoreRecordManager : NSObject

/**
 * @brief The shared instance.
 *
 * DECLARED ONLY — the body has not been located yet. See TYPES_PENDING.md.
 */
@property(class, nonatomic, readonly) ScoreRecordManager *sharedManager;

/**
 * @brief The Core Data context the records live in.
 *
 * Backed by the @c _managedObjectContext ivar, whose offset global is at 0x34b39c. Nullable:
 * @c -saveRecords guards against it being nil rather than assuming it exists.
 */
@property(nonatomic, readonly, nullable) NSManagedObjectContext *managedObjectContext;

/**
 * @brief Flushes pending score-record changes to the store.
 *
 * Does nothing when the context is nil or reports no changes. Both the result of @c -save: and the
 * @c NSError it can write are discarded, so a failed save is silent.
 * @ghidraAddress 0x17174c
 */
- (void)saveRecords;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
