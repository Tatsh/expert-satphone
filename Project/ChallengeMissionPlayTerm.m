#import "ChallengeMissionPlayTerm.h"

// The only mission type this class knows how to resolve.
static const unsigned int kSupportedMissionType = 1;

// A play-term row's columns. Column 6 is the flag word, evidenced by the bit tests that gate the
// three collections below. Column 0 carries a music identifier, evidenced by -1 being treated as
// "unconstrained". The meanings of columns 2, 3 and 5 are not established by this routine, so they
// are named by position rather than given a role they have not earned.
enum {
    kTermColumnMusicID = 0,
    kTermColumnSecond = 2,
    kTermColumnThird = 3,
    kTermColumnFifth = 5,
    kTermColumnFlags = 6,
};

// The flag word's bits, each gating one list. Evidenced by which ivar each guarded block fills.
enum {
    kTermFlagMusicNG = 1 << 0,
    kTermFlagMarkerNG = 1 << 1,
    kTermFlagLevelNG = 1 << 2,
};

// An achievement row's columns, each evidenced by the list it feeds.
enum {
    kAchieveColumnPlay = 0,
    kAchieveColumnMusic = 1,
    kAchieveColumnLevel = 2,
    kAchieveColumnMarker = 3,
};

// A row of play terms is only comparable once there is a second row to compare it against.
static const NSUInteger kMinimumComparableRows = 2;

// -1 in the music column means "any music", so a row carrying it is never counted as a mismatch.
static const int kUnconstrainedMusicID = -1;

// Reads one integer out of a play-term row. The binary re-sends -missionDetail for every single
// read rather than holding it in a local, which is why this takes the terms object.
static int TermValue(ChallengeMissionTerms *data, NSUInteger row, NSUInteger column) {
    return [[[data.missionDetail objectAtIndexedSubscript:row] objectAtIndexedSubscript:column]
        intValue];
}

// Builds an array of one column's value from every achievement row.
//
// The three guarded blocks that fill musicNGID, markerNG and levelNG are this loop three times over
// with only the column changing, so they are de-inlined here per the reconstruction rules.
// -achieveDetail is re-sent once per key inside the loop, as well as once to drive it.
//
// Returns nil rather than an empty array when nothing was collected, because the binary leaves the
// destination ivar untouched in that case rather than nilling it.
static NSArray *CollectAchieveColumn(ChallengeMissionAchieve *achieve, NSUInteger column) {
    NSMutableArray *collected = [[NSMutableArray alloc] init];
    for (id key in achieve.achieveDetail) {
        [collected
            addObject:[[achieve.achieveDetail objectForKey:key] objectAtIndexedSubscript:column]];
    }
    return collected.count != 0 ? [collected copy] : nil;
}

// Builds a seven-entry flag array, one per play-term column, all the same value.
static NSMutableArray *ColumnFlags(BOOL value) {
    // Seven entries and a nil terminator, counted from the stack slots the binary writes before
    // the call rather than from the decompile, which shows only the first.
    return [[NSMutableArray alloc]
        initWithObjects:@(value), @(value), @(value), @(value), @(value), @(value), @(value), nil];
}

@implementation ChallengeMissionPlayTerm

/** @ghidraAddress 0x1ef288 */
- (instancetype)init {
    self = [super init];
    if (self) {
        [self reset];
    }
    return self;
}

/** @ghidraAddress 0x1ef2e4 */
- (void)reset {
    // Only three of the six lists. levelNG, playHistory and historyDup are left alone.
    _musicNGID = nil;
    _requireMusicInfo = nil;
    _markerNG = nil;
}

/** @ghidraAddress 0x1ef338 */
- (void)initWithData:(ChallengeMissionTerms *)data achieve:(ChallengeMissionAchieve *)achieve {
    if (data.missionType != kSupportedMissionType) {
        return;
    }

    int termFlags = TermValue(data, 0, kTermColumnFlags);

    // This whole block computes a per-column "something differed" array and then throws it away —
    // nothing reads the array and nothing stores it. It is roughly 380 instructions of dead work,
    // and it is the inverse of the live block further down: it starts all-NO and sets YES on a
    // mismatch, where the live one starts all-YES and sets NO. It also omits the -1 guards the
    // live one applies. Reproduced because it is what the binary does; see TYPES_PENDING.md.
    if (data.missionDetail.count >= kMinimumComparableRows) {
        int expectedMusicID = TermValue(data, 0, kTermColumnMusicID);
        int expectedSecond = TermValue(data, 0, kTermColumnSecond);
        int expectedThird = TermValue(data, 0, kTermColumnThird);
        int expectedFifth = TermValue(data, 0, kTermColumnFifth);

        NSMutableArray *discardedFlags = ColumnFlags(NO);
        // The count is read a second time rather than reused, so it is written that way here.
        if (data.missionDetail.count >= kMinimumComparableRows) {
            for (NSUInteger row = 1; row < data.missionDetail.count; ++row) {
                // The -1 guard wraps all four tests here, where the live block below guards each
                // column separately. So an unconstrained music column suppresses the other three
                // comparisons entirely.
                if (expectedMusicID == kUnconstrainedMusicID) {
                    continue;
                }
                if (TermValue(data, row, kTermColumnMusicID) != expectedMusicID) {
                    [discardedFlags setObject:@YES atIndexedSubscript:kTermColumnMusicID];
                }
                if (TermValue(data, row, kTermColumnSecond) != expectedSecond) {
                    [discardedFlags setObject:@YES atIndexedSubscript:kTermColumnSecond];
                }
                if (TermValue(data, row, kTermColumnThird) != expectedThird) {
                    [discardedFlags setObject:@YES atIndexedSubscript:kTermColumnThird];
                }
                if (TermValue(data, row, kTermColumnFifth) != expectedFifth) {
                    [discardedFlags setObject:@YES atIndexedSubscript:kTermColumnFifth];
                }
            }
        }
    }

    if (termFlags & kTermFlagMusicNG) {
        NSArray *collected = CollectAchieveColumn(achieve, kAchieveColumnMusic);
        if (collected != nil) {
            _musicNGID = collected;
        }
    }
    if (termFlags & kTermFlagMarkerNG) {
        NSArray *collected = CollectAchieveColumn(achieve, kAchieveColumnMarker);
        if (collected != nil) {
            _markerNG = collected;
        }
    }
    if (termFlags & kTermFlagLevelNG) {
        NSArray *collected = CollectAchieveColumn(achieve, kAchieveColumnLevel);
        if (collected != nil) {
            _levelNG = collected;
        }
    }

    if (data.missionDetail.count >= kMinimumComparableRows) {
        int expectedMusicID = TermValue(data, 0, kTermColumnMusicID);
        int expectedSecond = TermValue(data, 0, kTermColumnSecond);
        int expectedThird = TermValue(data, 0, kTermColumnThird);
        int expectedFifth = TermValue(data, 0, kTermColumnFifth);

        NSMutableArray *columnFlags = ColumnFlags(YES);
        // Reuses the flag word's storage as a plain boolean from here on, which is why the value
        // read at the top is captured in its own local above.
        BOOL everyColumnAgrees = YES;

        if (data.missionDetail.count >= kMinimumComparableRows) {
            for (NSUInteger row = 1; row < data.missionDetail.count; ++row) {
                // Each column is skipped entirely when its expected value is -1.
                if (expectedMusicID != kUnconstrainedMusicID &&
                    TermValue(data, row, kTermColumnMusicID) != expectedMusicID) {
                    [columnFlags setObject:@NO atIndexedSubscript:kTermColumnMusicID];
                    everyColumnAgrees = NO;
                }
                if (expectedSecond != kUnconstrainedMusicID &&
                    TermValue(data, row, kTermColumnSecond) != expectedSecond) {
                    [columnFlags setObject:@NO atIndexedSubscript:kTermColumnSecond];
                    everyColumnAgrees = NO;
                }
                if (expectedThird != kUnconstrainedMusicID &&
                    TermValue(data, row, kTermColumnThird) != expectedThird) {
                    [columnFlags setObject:@NO atIndexedSubscript:kTermColumnThird];
                    everyColumnAgrees = NO;
                }
                if (expectedFifth != kUnconstrainedMusicID &&
                    TermValue(data, row, kTermColumnFifth) != expectedFifth) {
                    [columnFlags setObject:@NO atIndexedSubscript:kTermColumnFifth];
                    everyColumnAgrees = NO;
                }
            }
        }

        NSMutableArray *history = [[NSMutableArray alloc] init];
        for (id key in achieve.achieveDetail) {
            id row = [data.missionDetail objectAtIndexedSubscript:[key intValue]];
            // When every compared column agreed, the row is fetched and dropped on the floor, so
            // the history ends up empty and neither list below is written.
            if (!everyColumnAgrees) {
                [history addObject:row];
            }
        }
        if (history.count != 0) {
            _playHistory = [history copy];
            _historyDup = [columnFlags copy];
        }
    }

    // Compared through the property rather than the ivar, and only this one list gates the rest.
    if (self.musicNGID != nil) {
        return;
    }

    NSMutableArray *outstanding = [data.missionDetail mutableCopy];
    NSMutableDictionary *achieved = [achieve.achieveDetail mutableCopy];
    // Descending: the comparator boxes both keys and answers [second compare:first]. That order is
    // what makes the removals below safe, since each index is removed before any lower one shifts.
    NSArray *achievedKeys =
        [achieved.allKeys sortedArrayUsingComparator:^NSComparisonResult(id first, id second) {
          /** @ghidraAddress 0x1f0a28 */
          return [@([second intValue]) compare:@([first intValue])];
        }];
    for (id key in achievedKeys) {
        [outstanding removeObjectAtIndex:[key intValue]];
    }
    if (outstanding.count != 0) {
        _requireMusicInfo = [outstanding copy];
    }
}

@end
