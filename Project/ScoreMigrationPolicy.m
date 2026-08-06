#import "ScoreMigrationPolicy.h"

#include <string.h>

#import <UIKit/UIKit.h>

#import "ScoreRecord.h"

// The entity this policy handles. Anything else passes through untouched. From 0x2d96e0.
static NSString *const kScoreRecordEntityName = @"ScoreRecord";

// The source record's attribute names, from the CFStrings at 0x2ddf80 through 0x2de100.
static NSString *const kTuneIDKey = @"tuneID";
static NSString *const kScoreBasicKey = @"scoBas";
static NSString *const kScoreAdvancedKey = @"scoAdv";
static NSString *const kScoreExtremeKey = @"scoExt";
static NSString *const kChecksumKey = @"chksco";
static NSString *const kFullComboBasicKey = @"fcBas";
static NSString *const kFullComboAdvancedKey = @"fcAdv";
static NSString *const kFullComboExtremeKey = @"fcExt";
static NSString *const kMaxBonusBasicKey = @"mbBas";
static NSString *const kMaxBonusAdvancedKey = @"mbAdv";
static NSString *const kMaxBonusExtremeKey = @"mbExt";
static NSString *const kPerfectBasicKey = @"pmBas";
static NSString *const kPerfectAdvancedKey = @"pmAdv";
static NSString *const kPerfectExtremeKey = @"pmExt";
static NSString *const kLastPlayDateKey = @"lastPlayDate";
static NSString *const kPlayCountKey = @"playCount";

// The system version at which the stored scores stop being trustworthy, from 0x2ddfa0. Compared
// with NSNumericSearch, which is the 0x40 options immediate.
static NSString *const kTruncationSystemVersion = @"5.0";

// The digest width, an immediate 0x10 used both for the -getBytes:length: read and the byte loop.
static const NSUInteger kScoreHashLength = 16;

// The highest score the game can produce, materialised as `mov #0xf0000` then `movk #0x4240`. Any
// candidate above it is rejected without hashing.
static const int kMaximumScore = 1000000;

// How many high halves the search tries per chart: 0 through 16 inclusive, counted down from 0x11.
static const int kHighHalfCandidateCount = 17;

// What a stored 0xFFFF means when paired with the first high half: no score, not 65535.
static const unsigned int kStoredScoreAbsent = 0xFFFF;
static const int kScoreAbsent = -1;

@implementation ScoreMigrationPolicy

/** @ghidraAddress 0x15add0 */
- (BOOL)salvageScore:(NSManagedObject *)source
                 tid:(int)tuneID
                 bas:(int *)bas
                 adv:(int *)adv
                 ext:(int *)ext {
    // The digest is the only thing that can distinguish a correct guess, so a record without a
    // full-width one is unrecoverable and is refused before any searching happens.
    NSData *storedHash = [source valueForKey:kChecksumKey];
    if (storedHash.length != kScoreHashLength) {
        return NO;
    }
    unsigned char stored[kScoreHashLength];
    [storedHash getBytes:stored length:kScoreHashLength];

    // -shortValue, so each of these is the low 16 bits of the score that was actually achieved.
    unsigned int lowBasic = (unsigned int)[[source valueForKey:kScoreBasicKey] shortValue] & 0xFFFF;
    unsigned int lowAdvanced =
        (unsigned int)[[source valueForKey:kScoreAdvancedKey] shortValue] & 0xFFFF;
    unsigned int lowExtreme =
        (unsigned int)[[source valueForKey:kScoreExtremeKey] shortValue] & 0xFFFF;

    // Three nested searches over the missing high halves. The loops count down from 16, so the
    // first candidate tried for each chart is the largest.
    for (int highBasic = kHighHalfCandidateCount - 1; highBasic >= 0; --highBasic) {
        int candidateBasic =
            (highBasic == kHighHalfCandidateCount - 1 && lowBasic == kStoredScoreAbsent) ?
                kScoreAbsent :
                (int)(((unsigned int)highBasic << 16) | lowBasic);
        if (candidateBasic != kScoreAbsent && candidateBasic > kMaximumScore) {
            continue;
        }
        for (int highAdvanced = kHighHalfCandidateCount - 1; highAdvanced >= 0; --highAdvanced) {
            int candidateAdvanced =
                (highAdvanced == kHighHalfCandidateCount - 1 && lowAdvanced == kStoredScoreAbsent) ?
                    kScoreAbsent :
                    (int)(((unsigned int)highAdvanced << 16) | lowAdvanced);
            if (candidateAdvanced != kScoreAbsent && candidateAdvanced > kMaximumScore) {
                continue;
            }
            for (int highExtreme = kHighHalfCandidateCount - 1; highExtreme >= 0; --highExtreme) {
                int candidateExtreme = (highExtreme == kHighHalfCandidateCount - 1 &&
                                        lowExtreme == kStoredScoreAbsent) ?
                                           kScoreAbsent :
                                           (int)(((unsigned int)highExtreme << 16) | lowExtreme);
                if (candidateExtreme != kScoreAbsent && candidateExtreme > kMaximumScore) {
                    continue;
                }

                unsigned char candidateHash[kScoreHashLength];
                [ScoreRecord hashScoreforTune:tuneID
                                          bas:candidateBasic
                                          adv:candidateAdvanced
                                          ext:candidateExtreme
                                         hash:candidateHash];
                // Compared byte by byte, sixteen inlined comparisons rather than a memcmp.
                if (memcmp(candidateHash, stored, kScoreHashLength) == 0) {
                    *bas = candidateBasic;
                    *adv = candidateAdvanced;
                    *ext = candidateExtreme;
                    return YES;
                }
            }
        }
    }
    return NO;
}

/** @ghidraAddress 0x15b5d4 */
- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance
                                      entityMapping:(NSEntityMapping *)mapping
                                            manager:(NSMigrationManager *)manager
                                              error:(NSError **)error {
    NSManagedObjectContext *context = manager.destinationContext;
    NSString *entityName = mapping.destinationEntityName;
    if (![entityName isEqualToString:kScoreRecordEntityName]) {
        // Every other entity is left to the default mapping, and YES is still returned.
        return YES;
    }

    int tuneID = [[sInstance valueForKey:kTuneIDKey] intValue];
    int scoreBasic = 0;
    int scoreAdvanced = 0;
    int scoreExtreme = 0;
    BOOL verified;

    if ([UIDevice.currentDevice.systemVersion compare:kTruncationSystemVersion
                                              options:NSNumericSearch] == NSOrderedAscending) {
        // Below iOS 5 the stored values are still full width, so they are taken at face value and
        // only checked. Note -intValue here against -shortValue in the salvage path.
        scoreBasic = [[sInstance valueForKey:kScoreBasicKey] intValue];
        scoreAdvanced = [[sInstance valueForKey:kScoreAdvancedKey] intValue];
        scoreExtreme = [[sInstance valueForKey:kScoreExtremeKey] intValue];

        unsigned char hash[kScoreHashLength];
        [ScoreRecord hashScoreforTune:tuneID
                                  bas:scoreBasic
                                  adv:scoreAdvanced
                                  ext:scoreExtreme
                                 hash:hash];
        NSData *computed = [[NSData alloc] initWithBytes:hash length:kScoreHashLength];
        verified = [computed isEqualToData:[sInstance valueForKey:kChecksumKey]];
    } else {
        verified = [self salvageScore:sInstance
                                  tid:tuneID
                                  bas:&scoreBasic
                                  adv:&scoreAdvanced
                                  ext:&scoreExtreme];
    }

    // A record that fails is dropped in silence: no destination object, no error, and YES is still
    // returned so the migration continues. Reproduced as compiled.
    if (verified) {
        NSManagedObject *destination =
            [NSEntityDescription insertNewObjectForEntityForName:entityName
                                          inManagedObjectContext:context];

        [destination setValue:@(tuneID) forKey:kTuneIDKey];
        // The flags and counters are copied straight across as objects; only the three scores go
        // through the recovery above.
        [destination setValue:[sInstance valueForKey:kFullComboBasicKey] forKey:kFullComboBasicKey];
        [destination setValue:[sInstance valueForKey:kFullComboAdvancedKey]
                       forKey:kFullComboAdvancedKey];
        [destination setValue:[sInstance valueForKey:kFullComboExtremeKey]
                       forKey:kFullComboExtremeKey];
        [destination setValue:[sInstance valueForKey:kMaxBonusBasicKey] forKey:kMaxBonusBasicKey];
        [destination setValue:[sInstance valueForKey:kMaxBonusAdvancedKey]
                       forKey:kMaxBonusAdvancedKey];
        [destination setValue:[sInstance valueForKey:kMaxBonusExtremeKey]
                       forKey:kMaxBonusExtremeKey];
        [destination setValue:@(scoreBasic) forKey:kScoreBasicKey];
        [destination setValue:@(scoreAdvanced) forKey:kScoreAdvancedKey];
        [destination setValue:@(scoreExtreme) forKey:kScoreExtremeKey];
        [destination setValue:[sInstance valueForKey:kLastPlayDateKey] forKey:kLastPlayDateKey];
        [destination setValue:[sInstance valueForKey:kPlayCountKey] forKey:kPlayCountKey];
        [destination setValue:[sInstance valueForKey:kPerfectBasicKey] forKey:kPerfectBasicKey];
        [destination setValue:[sInstance valueForKey:kPerfectAdvancedKey]
                       forKey:kPerfectAdvancedKey];
        [destination setValue:[sInstance valueForKey:kPerfectExtremeKey] forKey:kPerfectExtremeKey];

        // Re-digested from the migrated record, so the new store carries a digest over the
        // recovered full-width scores.
        [destination setValue:[ScoreRecord hashScore:destination] forKey:kChecksumKey];
    }
    return YES;
}

@end
