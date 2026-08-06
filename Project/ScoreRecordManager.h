/** @file
 * The player's score record store.
 *
 * Reconstructed from Ghidra program Jubeat (class ScoreRecordManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. The class object at 0x3480e0 has 12
 * cross-references; only the members reached so far are declared.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Owns the persisted score records.
 */
@interface ScoreRecordManager : NSObject

/**
 * @brief The shared instance.
 */
@property(class, nonatomic, readonly) ScoreRecordManager *sharedManager;

/**
 * @brief Flushes the score records to disk.
 *
 * Called from @c -[JubeatAppDelegate applicationWillTerminate:] at 0xb830, which is its only call
 * site in the binary.
 */
- (void)saveRecords;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
