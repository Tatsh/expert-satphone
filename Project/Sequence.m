#import "Sequence.h"

#import "BFCodec.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "LabUtilities.h"

// The chart-header magic bytes accepted by -initWithData: and +checkExistHoldMarker:.
static const char kSequenceMagicI = 'I';
static const char kSequenceMagicJ = 'J';
static const char kSequenceMagicB = 'B';
static const char kSequenceMagicS = 'S';
static const char kSequenceMagicQ = 'Q';

// The event kinds packed into a SequenceEvent's low byte.
enum {
    kSequenceEventTap = 1,
    kSequenceEventPoorMarker = 2,
    kSequenceEventMeasure = 3,
    kSequenceEventHaku = 4,
    kSequenceEventTempo = 5,
    kSequenceEventHold = 6,
};

// The chart header is 96 bytes; each event record that follows is 8 bytes on disc, holding a
// 24-byte header magic at 0, then the event count word, then per-event pairs.
static const NSUInteger kSequenceHeaderByteCount = 96; // 0x60
static const NSUInteger kSequenceDiscEventByteCount = 8;
static const NSUInteger kSequenceHeaderMagicLength = 0x24;
// Offsets of the header fields within the 0x24-byte magic block read by the initialiser, starting
// four bytes past the four-byte magic.
static const NSUInteger kSequenceHeaderEventCountOffset = 0x04;
static const NSUInteger kSequenceHeaderNumPlayEventOffset = 0x08;
static const NSUInteger kSequenceHeaderEndSectorOffset = 0x0c;
static const NSUInteger kSequenceHeaderFirstMarkerOffset = 0x12;
static const NSUInteger kSequenceHeaderFirstSectorOffset = 0x14;
// The music-bar bitmap sits at byte 36 of the blob and spans 60 bytes.
static const NSUInteger kSequenceMusicBarOffset = 36; // 0x24

// The music-bar-result grade codes, two bits per segment: silent, cleared, or failed.
enum {
    kSequenceBarSilent = 0,
    kSequenceBarCleared = 1,
    kSequenceBarFailed = 2,
};

// A sector maps to a music-bar segment by scaling against the end sector.
static const int kSequenceMusicBarSegments = 120; // 0x78

// The judgement windows, in sectors, mapping a signed timing delta to a grade. Each window is a
// half-open interval biased so that "delta in [-early, late)" reduces to an unsigned range test;
// they match ClassifyNoteTimingGrade exactly. The early edges are one wider than the late edges.
static const int kSequenceWindowPerfectBias = 12;          // 0xc:   [-12, +11]
static const int kSequenceWindowGreatBias = 24;            // 0x18:  [-24, +23]
static const int kSequenceWindowGoodBias = 48;             // 0x30:  [-48, +47]
static const int kSequenceWindowPoorBias = 115;            // 0x73:  [-115, +84]
static const unsigned int kSequenceWindowPerfectSpan = 24; // 0x18
static const unsigned int kSequenceWindowGreatSpan = 48;   // 0x30
static const unsigned int kSequenceWindowGoodSpan = 96;    // 0x60
static const unsigned int kSequenceWindowPoorSpan = 200;   // 0xc8

// The marker-lookahead and lookbehind spans, in sectors, used by -getMarkerState: and friends.
static const unsigned int kSequenceMarkerLookahead = 0xa0;
static const unsigned int kSequenceMarkerLookbehind = 0x50;
static const int kSequenceMarkerNone = 0x800;

// The hold-release grade table at 0x293b60 holds {threshold, grade} word pairs read at +4; the
// grade for a release is chosen by its percentage completion against two cut points.
// @ghidraAddress 0x293b64
static const short kSequenceReleaseGrades[] = {
    SequenceJudgeGradePoor, SequenceJudgeGradeGood, SequenceJudgeGradeGreat};
static const int kSequenceReleaseGreatPercent = 80; // 0x50; percent > 80 grades great.
static const int kSequenceReleasePoorPercent = 51;  // 0x33; percent < 51 grades poor.
static const int kSequenceReleaseFullPercent = 100; // 0x64
// The release timing scales the hold's remaining length by this factor to size its grace window.
// @ghidraAddress 0x293b10
static const float kSequenceReleaseGraceScale = 58.0f;
// A hold's packed value carries its length divisor in bits 6-7, each unit worth this many sectors.
static const unsigned int kSequenceHoldLengthUnit = 0xc0;

// The sector-to-time scale: a time in seconds times this yields the sector position.
// @ghidraAddress 0x28f2d0
static const double kSequenceSectorsPerSecond = 300.0;

// The score rank point thresholds, ascending; +rankOfPoint: returns the highest tier not exceeded.
static const unsigned int kSequenceRankPoint1 = 500000;
static const unsigned int kSequenceRankPoint2 = 700000;
static const unsigned int kSequenceRankPoint4 = 850000;
static const unsigned int kSequenceRankPoint5 = 900000;
static const unsigned int kSequenceRankPoint6 = 950000;
static const unsigned int kSequenceRankPoint7 = 980000;
static const unsigned int kSequenceRankPointMax = 999999;
// The 800000-point boundary is compared as (point >> 8) against this value.
static const unsigned int kSequenceRankPoint3Shifted = 0xc35;

// The tension gauge range and the score scale applied to raw points.
static const int kSequenceTensionMax = 0x400;
static const int kSequencePointScale = 100000;
static const float kSequenceTensionFixedScale = 1024.0f;
static const int kSequenceTensionFixedShift = 10;

// The difficulty entry names inside a downloaded pack's archive.
static NSString *const kSequenceDifficultyBasic = @"seq_bas";
static NSString *const kSequenceDifficultyAdvanced = @"seq_adv";
static NSString *const kSequenceDifficultyExtreme = @"seq_ext";

// The custom-chart header dictionary keys.
static NSString *const kSequenceKeyEventNum = @"eventNum";
static NSString *const kSequenceKeyNotesNum = @"notesNum";
static NSString *const kSequenceKeyEndSector = @"endSector";
static NSString *const kSequenceKeyFirstMarker = @"firstMarker";
static NSString *const kSequenceKeyFirstSector = @"firstSector";
static NSString *const kSequenceKeyMusicBar = @"musicBar";

@implementation Sequence

#pragma mark - Music-bar helpers

// Sets a music-bar segment to cleared, clearing the failed bit of its two-bit field. Matches the
// "OR in cleared, AND out failed" bit twiddling repeated throughout -judge:btnPress:.
static inline void SequenceSetBarCleared(char *musicBarResult, unsigned int segment) {
    const unsigned int shift = (segment & 3) << 1;
    char *byte = &musicBarResult[segment >> 2];
    *byte = (char)((*byte | (char)(1 << shift)) & (char)(~(2 << shift)));
}

// Sets a music-bar segment to failed unless it is already cleared. Matches the "leave an existing
// cleared segment alone, else clear cleared and set failed" branch.
static inline void SequenceSetBarFailed(char *musicBarResult, unsigned int segment) {
    const unsigned int shift = (segment & 3) << 1;
    char *byte = &musicBarResult[segment >> 2];
    if ((((int)*byte >> shift) & 3) != kSequenceBarCleared) {
        *byte = (char)((*byte & (char)(~(1 << shift))) | (char)(2 << shift));
    }
}

// Maps a sector to its music-bar segment, guarding against a zero end sector.
static inline unsigned int SequenceBarSegment(int sector, unsigned int endSectorValue) {
    if (endSectorValue == 0) {
        return 0;
    }
    return (unsigned int)(sector * kSequenceMusicBarSegments) / endSectorValue;
}

// Classifies a signed timing delta into a grade for a tap, tightest window first. This is the
// branchless window chain the compiler inlined into -judge:btnPress: for the tap path.
static inline SequenceJudgeGrade SequenceClassifyTap(int delta) {
    SequenceJudgeGrade grade = SequenceJudgeGradeMiss;
    if ((unsigned int)(delta + kSequenceWindowPoorBias) < kSequenceWindowPoorSpan) {
        grade = SequenceJudgeGradePoor;
    }
    if ((unsigned int)(delta + kSequenceWindowGoodBias) < kSequenceWindowGoodSpan) {
        grade = SequenceJudgeGradeGood;
    }
    if ((unsigned int)(delta + kSequenceWindowGreatBias) < kSequenceWindowGreatSpan) {
        grade = SequenceJudgeGradeGreat;
    }
    if ((unsigned int)(delta + kSequenceWindowPerfectBias) < kSequenceWindowPerfectSpan) {
        grade = SequenceJudgeGradePerfect;
    }
    return grade;
}

// The hold-head variant of the window chain: a delta outside the widest window grades Miss when
// late and None when early, so a not-yet-reachable hold head is skipped rather than missed.
static inline SequenceJudgeGrade SequenceClassifyHoldHead(int delta) {
    SequenceJudgeGrade grade = SequenceJudgeGradePoor;
    if ((unsigned int)(delta + kSequenceWindowPoorBias) >= kSequenceWindowPoorSpan) {
        grade = (delta > 0) ? SequenceJudgeGradeMiss : SequenceJudgeGradeNone;
    }
    if ((unsigned int)(delta + kSequenceWindowGoodBias) < kSequenceWindowGoodSpan) {
        grade = SequenceJudgeGradeGood;
    }
    if ((unsigned int)(delta + kSequenceWindowGreatBias) < kSequenceWindowGreatSpan) {
        grade = SequenceJudgeGradeGreat;
    }
    if ((unsigned int)(delta + kSequenceWindowPerfectBias) < kSequenceWindowPerfectSpan) {
        grade = SequenceJudgeGradePerfect;
    }
    return grade;
}

#pragma mark - Class methods

+ (void)getMusicBarData:(char *)raw raw:(NSData *)data {
    if (data != nil && data.length > kSequenceHeaderByteCount) {
        [data getBytes:raw range:NSMakeRange(kSequenceMusicBarOffset, kSequenceMusicBarByteCount)];
    }
}

+ (unsigned int)checkExistHoldMarkerFlag:(KUnzip *)data {
    NSArray<NSString *> *names =
        @[ kSequenceDifficultyBasic, kSequenceDifficultyAdvanced, kSequenceDifficultyExtreme ];
    BFCodec *codec = [[BFCodec alloc] init];
    NSData *key = GetBgmCipherKey();

    NSMutableData *basic = [data uncompress:names[0]];
    [codec cipherInit:key];
    [codec decipher:basic];
    BOOL hasBasic = [self checkExistHoldMarker:basic];

    NSMutableData *advanced = [data uncompress:names[1]];
    [codec cipherInit:key];
    [codec decipher:advanced];
    unsigned int advancedFlag = [self checkExistHoldMarker:advanced] ? 2 : 0;

    NSMutableData *extreme = [data uncompress:names[2]];
    [codec cipherInit:key];
    [codec decipher:extreme];
    unsigned int extremeFlag = [self checkExistHoldMarker:extreme] ? 4 : 0;

    return extremeFlag | advancedFlag | (hasBasic ? 1 : 0);
}

+ (BOOL)checkExistHoldMarker:(NSData *)data {
    if (data == nil || data.length < kSequenceHeaderMagicLength + 1) {
        return NO;
    }
    char header[kSequenceHeaderMagicLength];
    [data getBytes:header length:kSequenceHeaderMagicLength];
    if (header[0] != kSequenceMagicI || header[1] != kSequenceMagicJ ||
        header[2] != kSequenceMagicS || header[3] != kSequenceMagicQ) {
        return NO;
    }
    const unsigned int eventCount = *(const unsigned int *)&header[kSequenceHeaderEventCountOffset];
    if (data.length < eventCount * kSequenceDiscEventByteCount + kSequenceHeaderByteCount ||
        eventCount == 0) {
        return NO;
    }
    for (unsigned int i = 0; i < eventCount; ++i) {
        char record[kSequenceDiscEventByteCount];
        [data getBytes:record
                 range:NSMakeRange(kSequenceHeaderByteCount + i * kSequenceDiscEventByteCount,
                                   kSequenceDiscEventByteCount)];
        if (record[0] == kSequenceEventHold) {
            return YES;
        }
    }
    return NO;
}

+ (SequenceRank)rankOfPoint:(unsigned int)point {
    if (point > kSequenceRankPointMax) {
        return SequenceRankTier8;
    }
    SequenceRank rank = SequenceRankTier2;
    if (point < kSequenceRankPoint2) {
        rank = (point > kSequenceRankPoint1 - 1) ? SequenceRankTier1 : SequenceRankTier0;
    }
    if ((point >> 8) >= kSequenceRankPoint3Shifted) {
        rank = SequenceRankTier3;
    }
    if (point >= kSequenceRankPoint4) {
        rank = SequenceRankTier4;
    }
    if (point >= kSequenceRankPoint5) {
        rank = SequenceRankTier5;
    }
    if (point >= kSequenceRankPoint6) {
        rank = SequenceRankTier6;
    }
    if (point >= kSequenceRankPoint7) {
        rank = SequenceRankTier7;
    }
    return rank;
}

#pragma mark - Random remap table

// Builds the panel-remap table: identity by default, shuffled in random mode. Called from both
// initialisers. The identity seed is a 16-entry pool at 0x293b20.
/** @ghidraAddress 0x1abb20 */
- (void)createRandomTable {
    for (unsigned int i = 0; i < kSequencePanelCount; ++i) {
        replaceTable[i] = i;
    }
    JubeatAppDelegate *app = JubeatAppDelegate.appDelegate;
    const BOOL random = app.isRandom;
    const BOOL challenge = JubeatAppDelegate.appDelegate.bChallengeMode;
    const BOOL hold = JubeatAppDelegate.appDelegate.isHold;
    if (random && !challenge && !hold) {
        for (unsigned int i = 0; i < kSequencePanelCount; ++i) {
            const unsigned int j = (unsigned int)(rand() % kSequencePanelCount);
            const unsigned int tmp = replaceTable[j];
            replaceTable[j] = replaceTable[i];
            replaceTable[i] = tmp;
        }
    }
}

// Rewrites the first-marker panel bitmask through the remap table.
/** @ghidraAddress 0x1abc90 */
- (void)replaceFirstMarker {
    char remapped[kSequencePanelCount] = {0};
    const unsigned short original = _firstMarker;
    for (unsigned int i = 0; i < kSequencePanelCount; ++i) {
        if (original & (1 << (i & 0x1f))) {
            remapped[replaceTable[i]] = 1;
        }
    }
    unsigned short bitmask = 0;
    for (unsigned int i = 0; i < kSequencePanelCount; ++i) {
        if (remapped[i]) {
            bitmask |= (unsigned short)(1 << i);
        }
    }
    _firstMarker = bitmask;
}

#pragma mark - Initialisers

- (instancetype)initWithData:(NSData *)data {
    [self createRandomTable];
    if (data == nil || data.length < kSequenceHeaderMagicLength + 1) {
        return nil;
    }
    char header[kSequenceHeaderMagicLength];
    [data getBytes:header length:kSequenceHeaderMagicLength];
    BOOL magicOK = NO;
    if (header[0] == kSequenceMagicJ) {
        magicOK = (header[1] == kSequenceMagicB && header[2] == kSequenceMagicS &&
                   header[3] == kSequenceMagicQ);
    } else if (header[0] == kSequenceMagicI) {
        magicOK = (header[1] == kSequenceMagicJ &&
                   ((header[2] == kSequenceMagicB && header[3] == kSequenceMagicQ) ||
                    (header[2] == kSequenceMagicS && header[3] == kSequenceMagicQ)));
    }
    if (!magicOK) {
        return nil;
    }
    const int eventCount = *(const int *)&header[kSequenceHeaderEventCountOffset];
    if ((NSUInteger)data.length <
        eventCount * kSequenceDiscEventByteCount + kSequenceHeaderByteCount) {
        return nil;
    }

    self = [super init];
    if (self == nil) {
        return nil;
    }
    numEvent = (unsigned int)eventCount;
    numPlayEvent = *(const unsigned int *)&header[kSequenceHeaderNumPlayEventOffset];
    endSector = *(const unsigned int *)&header[kSequenceHeaderEndSectorOffset];
    _firstMarker = *(const unsigned short *)&header[kSequenceHeaderFirstMarkerOffset];
    _firstMarkerSector = *(const unsigned int *)&header[kSequenceHeaderFirstSectorOffset];
    [self replaceFirstMarker];
    [data getBytes:musicBar range:NSMakeRange(kSequenceMusicBarOffset, kSequenceMusicBarByteCount)];

    NSMutableArray *playEvents = [[NSMutableArray alloc] init];
    NSMutableArray *holdEvents = [[NSMutableArray alloc] init];
    events = (SequenceEvent *)malloc((size_t)numEvent * sizeof(SequenceEvent));
    replayJudgeTable = (short *)malloc((size_t)numEvent * sizeof(short));
    replayTmpJudgeTable = (short *)malloc((size_t)numEvent * sizeof(short));

    int playCount = 0;
    for (unsigned int i = 0; i < numEvent; ++i) {
        unsigned int packed[2];
        [data getBytes:packed
                 range:NSMakeRange(kSequenceHeaderByteCount + i * kSequenceDiscEventByteCount,
                                   kSequenceDiscEventByteCount)];
        const unsigned int kind = packed[0] & 0xff;
        SequenceEvent *event = &events[i];
        event->kind = (short)kind;
        event->sector = packed[0] >> 8;
        event->value = packed[1];
        if (kind == kSequenceEventHold) {
            playCount += 2;
            [holdEvents addObject:@[ @((int)event->sector), @(event->value) ]];
        } else if (kind == kSequenceEventTap) {
            event->value = replaceTable[packed[1]];
            [playEvents addObject:@[ @((int)event->sector), @((int)event->value) ]];
            playCount += 1;
        }
    }
    playEventTable = [NSArray arrayWithArray:playEvents];
    holdEventTable = [NSArray arrayWithArray:holdEvents];
    if ((int)numPlayEvent != playCount) {
        numPlayEvent = (unsigned int)playCount;
    }
    return self;
}

- (instancetype)initWithCustomData:(NSDictionary *)data tableData:(NSArray *)tableData {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    [self createRandomTable];
    const NSInteger tableCount = (NSInteger)tableData.count;
    numEvent = [data[kSequenceKeyEventNum] unsignedIntValue];
    numPlayEvent = [data[kSequenceKeyNotesNum] unsignedIntValue];
    endSector = [data[kSequenceKeyEndSector] unsignedIntValue];
    _firstMarker = (unsigned short)[data[kSequenceKeyFirstMarker] unsignedIntValue];
    _firstMarkerSector = [data[kSequenceKeyFirstSector] unsignedIntValue];
    [self replaceFirstMarker];
    [data[kSequenceKeyMusicBar] getBytes:musicBar length:kSequenceMusicBarByteCount];

    events = (SequenceEvent *)malloc((size_t)numEvent * sizeof(SequenceEvent));
    replayJudgeTable = (short *)malloc((size_t)numEvent * sizeof(short));
    replayTmpJudgeTable = (short *)malloc((size_t)numEvent * sizeof(short));

    int playCount = 0;
    if (tableCount >= 1) {
        for (NSInteger i = 0; i < tableCount; ++i) {
            const unsigned long word = [tableData[i] unsignedLongValue];
            if (word == 0) {
                break;
            }
            const unsigned int kind = (unsigned int)word & 0xf;
            SequenceEvent *event = &events[i];
            event->kind = (short)kind;
            event->sector = ((unsigned int)word >> 4) & 0xfffff;
            event->value = (unsigned int)((word >> 0x18) & 0xff);
            if (kind == kSequenceEventTap) {
                playCount += 1;
                event->value = replaceTable[(word >> 0x18) & 0xff];
            }
            if (kind == kSequenceEventPoorMarker) {
                break;
            }
        }
    }
    if (playCount != (int)numPlayEvent) {
        numPlayEvent = (unsigned int)playCount;
    }
    return self;
}

#pragma mark - Play-state reset

- (void)reset {
    _currentTime = 0.0;
    _currentSector = 0;
    currentIndex = 0;
    currentHoldIndex = 0;
    oldTempo = 0;
    currentTempo = 0;
    for (unsigned int i = 0; i < numEvent; ++i) {
        events[i].judge = SequenceJudgeGradeNone;
        events[i].holdHeadJudge = SequenceJudgeGradeNone;
        replayJudgeTable[i] = 0;
        replayTmpJudgeTable[i] = 0;
    }
    judgedIndex = 0;
    for (unsigned int i = 0; i < kSequencePanelCount; ++i) {
        lastJudge[i] = SequenceJudgeGradeNone;
        lastJudgeSector[i] = 0;
    }
    nextMeasureSector = 0;
    lastMeasureSector = 0;
    nextHakuSector = 0;
    lastHakuSector = 0;
    gameScore = (ScoreData){0};
}

- (void)replay {
    _currentTime = 0.0;
    _currentSector = 0;
    currentIndex = 0;
    currentHoldIndex = 0;
    oldTempo = 0;
    currentTempo = 0;
    // A replay preserves the recorded replay-judge tables and only clears the per-event live
    // grades.
    for (unsigned int i = 0; i < numEvent; ++i) {
        events[i].judge = SequenceJudgeGradeNone;
        events[i].holdHeadJudge = SequenceJudgeGradeNone;
    }
    judgedIndex = 0;
    for (unsigned int i = 0; i < kSequencePanelCount; ++i) {
        lastJudge[i] = SequenceJudgeGradeNone;
        lastJudgeSector[i] = 0;
    }
    nextMeasureSector = 0;
    lastMeasureSector = 0;
    nextHakuSector = 0;
    lastHakuSector = 0;
    gameScore = (ScoreData){0};
}

#pragma mark - Seeking

- (void)seekToTime:(double)time {
    if (_currentTime > time) {
        return;
    }
    _currentTime = time;
    const int sector = (int)(time * kSequenceSectorsPerSecond);
    _currentSector = (unsigned int)sector;

    if (currentIndex < numEvent && events[currentIndex].sector <= (unsigned int)sector) {
        do {
            SequenceEvent *event = &events[currentIndex];
            const short kind = event->kind;
            if (kind == kSequenceEventMeasure) {
                lastMeasureSector = event->sector;
                for (unsigned int j = currentIndex + 1; j < numEvent; ++j) {
                    if (events[j].kind == kSequenceEventMeasure) {
                        nextMeasureSector = events[j].sector;
                        break;
                    }
                }
            } else if (kind == kSequenceEventTempo) {
                oldTempo = currentTempo;
                currentTempo = events[currentIndex].value;
            } else if (kind == kSequenceEventHaku) {
                lastHakuSector = event->sector;
                for (unsigned int j = currentIndex + 1; j < numEvent; ++j) {
                    if (events[j].kind == kSequenceEventHaku) {
                        nextHakuSector = events[j].sector;
                        break;
                    }
                }
            }
            ++currentIndex;
            if (currentIndex >= numEvent) {
                break;
            }
        } while (events[currentIndex].sector <= _currentSector);
    }

    for (; currentHoldIndex < numEvent; ++currentHoldIndex) {
        SequenceEvent *event = &events[currentHoldIndex];
        if (event->kind == kSequenceEventHold &&
            _currentSector < event->sector + (event->value >> 8) + kSequenceMarkerLookbehind) {
            return;
        }
    }
}

#pragma mark - Marker state

- (void)getMarkerState:(int *)state {
    const unsigned int startIndex = currentIndex;
    for (unsigned int panel = 0; panel < kSequencePanelCount; ++panel) {
        state[panel] = kSequenceMarkerNone;
        const unsigned int grade = (unsigned int)lastJudge[panel];
        if (grade > (unsigned int)SequenceJudgeGradeMiss) {
            const unsigned int age = _currentSector - lastJudgeSector[panel];
            if (age < kSequenceMarkerLookahead) {
                state[panel] = (int)(age | (grade << 0xc));
            }
        }
    }

    if (startIndex != 0) {
        for (int i = (int)startIndex - 1; i >= 0; --i) {
            const unsigned int age = _currentSector - events[i].sector;
            if (age > kSequenceMarkerLookbehind) {
                break;
            }
            unsigned int panel;
            if (events[i].kind == kSequenceEventHold) {
                if (events[i].holdHeadJudge != SequenceJudgeGradeNone) {
                    continue;
                }
                panel = events[i].value & 0xf;
            } else if (events[i].kind == kSequenceEventTap &&
                       events[i].judge == SequenceJudgeGradeNone && events[i].value < 0x10) {
                panel = events[i].value;
            } else {
                continue;
            }
            if (state[panel] == kSequenceMarkerNone) {
                state[panel] = (int)(age + (kSequenceMarkerLookahead - 1));
            }
        }
    }

    for (unsigned int i = currentIndex; i < numEvent; ++i) {
        const unsigned int lead = events[i].sector - _currentSector;
        if (lead > kSequenceMarkerLookahead - 1) {
            return;
        }
        unsigned int panel;
        if (events[i].kind == kSequenceEventHold) {
            if (events[i].holdHeadJudge != SequenceJudgeGradeNone) {
                continue;
            }
            panel = events[i].value & 0xf;
        } else if (events[i].kind == kSequenceEventTap &&
                   events[i].judge == SequenceJudgeGradeNone && events[i].value < 0x10) {
            panel = events[i].value;
        } else {
            continue;
        }
        if (state[panel] == kSequenceMarkerNone) {
            state[panel] = (int)((kSequenceMarkerLookahead - 1) - lead);
        }
    }
}

- (void)getHoldMarkerState:(MainGameHoldState *)state {
    for (unsigned int panel = 0; panel < kSequencePanelCount; ++panel) {
        state[panel].state = 0;
    }
    for (unsigned int i = currentHoldIndex; i < numEvent; ++i) {
        SequenceEvent *event = &events[i];
        const int sector = (int)event->sector;
        const int lead = sector - (int)_currentSector;
        if (lead > (int)(kSequenceMarkerLookahead - 1)) {
            return;
        }
        if (event->kind != kSequenceEventHold) {
            continue;
        }
        const unsigned int value = event->value;
        const int releaseSector = (int)event->holdReleaseSector;
        const unsigned int panel = value & 0xf;
        MainGameHoldState *slot = &state[panel];
        slot->move = (value >> 4) & 0xf;
        if (event->holdHeadJudge == SequenceJudgeGradeNone) {
            const int clampedLead = (lead < 0) ? 0 : lead;
            slot->state = 1;
            slot->currentSector = kSequenceMarkerLookahead - clampedLead;
            slot->endSector = kSequenceMarkerLookahead;
        } else {
            const unsigned int length = (unsigned int)((sector - releaseSector) + (value >> 8));
            const unsigned int elapsed = _currentSector - (unsigned int)releaseSector;
            if ((int)-elapsed <= (int)length && event->judge == SequenceJudgeGradeNone) {
                slot->state = 2;
                slot->currentSector = elapsed;
                slot->endSector = length;
            }
        }
    }
}

#pragma mark - Score accessors

- (const ScoreData *)getScore {
    return &gameScore;
}

- (BOOL)isFullcombo {
    return numPlayEvent == (unsigned int)gameScore.curCombo;
}

- (BOOL)isExcellent {
    return numPlayEvent == (unsigned int)gameScore.nPerfect;
}

- (SequenceRank)rank {
    return [Sequence rankOfPoint:(unsigned int)gameScore.totalPoint];
}

- (const char *)getMusicBar {
    return musicBar;
}

#pragma mark - Phase getters

- (float)hakuPhase {
    if (lastHakuSector <= nextHakuSector && nextHakuSector - lastHakuSector != 0) {
        if (lastHakuSector <= _currentSector && _currentSector <= nextHakuSector) {
            return (float)(_currentSector - lastHakuSector) /
                   (float)(nextHakuSector - lastHakuSector);
        }
    }
    return 0.0f;
}

- (float)measurePhase {
    if (lastMeasureSector <= nextMeasureSector && nextMeasureSector - lastMeasureSector != 0) {
        if (lastMeasureSector <= _currentSector && _currentSector <= nextMeasureSector) {
            return (float)(_currentSector - lastMeasureSector) /
                   (float)(nextMeasureSector - lastMeasureSector);
        }
    }
    return 0.0f;
}

- (float)playPosition {
    if (_currentSector < endSector) {
        return (float)_currentSector / (float)endSector;
    }
    return 1.0f;
}

#pragma mark - Scoring

/** @ghidraAddress 0x1ad138 */
- (void)addJudge:(short)grade {
    float tensionDelta;
    int tensionUnits;
    switch (grade) {
    case SequenceJudgeGradeMiss:
        ++gameScore.nMiss;
        gameScore.curCombo = 0;
        tensionDelta = -8.0f / (float)numPlayEvent;
        tensionUnits = -8;
        break;
    case SequenceJudgeGradePoor:
        ++gameScore.nPoor;
        // A poor resets the combo and costs -8 tension exactly like a miss.
        gameScore.curCombo = 0;
        tensionDelta = -8.0f / (float)numPlayEvent;
        tensionUnits = -8;
        break;
    case SequenceJudgeGradeGood:
        ++gameScore.nGood;
        ++gameScore.curCombo;
        tensionDelta = 1.0f / (float)numPlayEvent;
        tensionUnits = 1;
        break;
    case SequenceJudgeGradeGreat:
        ++gameScore.nGreat;
        ++gameScore.curCombo;
        tensionDelta = 2.0f / (float)numPlayEvent;
        tensionUnits = 2;
        break;
    case SequenceJudgeGradePerfect:
        ++gameScore.nPerfect;
        ++gameScore.curCombo;
        tensionDelta = 2.0f / (float)numPlayEvent;
        tensionUnits = 2;
        break;
    default:
        tensionDelta = 0.0f;
        tensionUnits = 0;
        break;
    }

    long rawPoints = 0;
    if (numPlayEvent != 0) {
        rawPoints = ((long)gameScore.nPoor + (long)gameScore.nGood * 4 +
                     (long)gameScore.nGreat * 7 + (long)gameScore.nPerfect * 10) *
                    kSequencePointScale / (long)(unsigned int)numPlayEvent;
    }
    if (gameScore.maxCombo < gameScore.curCombo) {
        gameScore.maxCombo = gameScore.curCombo;
    }

    // The fixed-point tension step is min/max-clamped against the integer unit count with the
    // binary's exact sign-dependent selection.
    int step = tensionUnits;
    const int scaled = (int)(tensionDelta * kSequenceTensionFixedScale);
    if (tensionUnits <= scaled || tensionUnits < 1) {
        step = scaled;
    }
    if (step <= tensionUnits || tensionUnits >= 0) {
        tensionUnits = step;
    }
    int tension = gameScore.tension + tensionUnits;
    if (tension < 0) {
        tension = 0;
    } else if (tension > kSequenceTensionMax) {
        tension = kSequenceTensionMax;
    }
    gameScore.tension = tension;

    const int basePoints = ((int)rawPoints * 9) / 10;
    int bonus = tension * kSequencePointScale;
    if (bonus < 0) {
        bonus += (1 << kSequenceTensionFixedShift) - 1;
    }
    bonus >>= kSequenceTensionFixedShift;
    gameScore.point = basePoints;
    gameScore.bonusPoint = bonus;
    gameScore.totalPoint = basePoints + bonus;
}

#pragma mark - Judging

- (void)judge:(int)btnPress btnPress:(int)btnDown {
    unsigned int index = judgedIndex;
    if (index >= numEvent) {
        return;
    }
    long eventIndex = (int)index;
    BOOL allJudged = YES;
    do {
        SequenceEvent *event = &events[eventIndex];
        const int delta = (int)_currentSector - (int)event->sector;
        if (delta < -kSequenceWindowPoorBias) {
            break;
        }
        if (event->kind == kSequenceEventTap && event->judge == SequenceJudgeGradeNone) {
            const unsigned int panel = event->value & 0xf;
            const SequenceJudgeGrade grade = SequenceClassifyTap(delta);
            const unsigned int segment = SequenceBarSegment((int)event->sector, endSector);
            if ((1 << panel & btnPress) == 0 && grade != SequenceJudgeGradeMiss) {
                if (delta > 0 && grade == SequenceJudgeGradePoor) {
                    SequenceSetBarCleared(gameScore.musicBarResult, segment);
                }
                if (allJudged) {
                    allJudged = NO;
                    judgedIndex = (unsigned int)eventIndex;
                } else {
                    allJudged = NO;
                }
            } else {
                unsigned int recorded = (unsigned int)(unsigned short)replayJudgeTable[eventIndex];
                if (recorded == 0) {
                    replayJudgeTable[eventIndex] = (short)grade;
                    recorded = grade;
                }
                const short finalGrade = (short)recorded;
                event->judge = finalGrade;
                [self addJudge:finalGrade];
                if (recorded == (unsigned int)SequenceJudgeGradeMiss) {
                    SequenceSetBarCleared(gameScore.musicBarResult, segment);
                } else {
                    lastJudge[panel] = finalGrade;
                    lastJudgeSector[panel] = _currentSector;
                    if (recorded - 3 < 2) {
                        SequenceSetBarFailed(gameScore.musicBarResult, segment);
                    } else if (recorded == (unsigned int)SequenceJudgeGradePoor) {
                        SequenceSetBarCleared(gameScore.musicBarResult, segment);
                    }
                }
            }
        }

        event = &events[eventIndex];
        if (event->kind == kSequenceEventHold) {
            if (event->judge == SequenceJudgeGradeNone) {
                const unsigned int value = event->value;
                const unsigned int panel = value & 0xf;
                if (event->holdHeadJudge == SequenceJudgeGradeNone) {
                    const SequenceJudgeGrade grade = SequenceClassifyHoldHead(delta);
                    const unsigned int segment = SequenceBarSegment((int)event->sector, endSector);
                    if (grade != SequenceJudgeGradeNone) {
                        if ((1 << panel & btnPress) == 0 && grade != SequenceJudgeGradeMiss) {
                            if (delta > 0 && grade == SequenceJudgeGradePoor) {
                                SequenceSetBarCleared(gameScore.musicBarResult, segment);
                            }
                        } else {
                            unsigned int recorded =
                                (unsigned int)(unsigned short)replayTmpJudgeTable[eventIndex];
                            if (recorded == 0) {
                                replayTmpJudgeTable[eventIndex] = (short)grade;
                                recorded = grade;
                            }
                            const short headGrade = (short)recorded;
                            event->holdHeadJudge = headGrade;
                            event->holdReleaseSector = _currentSector;
                            [self addJudge:headGrade];
                            if (recorded == (unsigned int)SequenceJudgeGradeMiss) {
                                SequenceSetBarCleared(gameScore.musicBarResult, segment);
                                const unsigned int endSeg = SequenceBarSegment(
                                    (int)(event->sector + (value >> 8)), endSector);
                                SequenceSetBarCleared(gameScore.musicBarResult, endSeg);
                                event->judge = SequenceJudgeGradeMiss;
                            } else {
                                lastJudge[panel] = headGrade;
                                lastJudgeSector[panel] = _currentSector;
                                if (recorded - 3 < 2) {
                                    SequenceSetBarFailed(gameScore.musicBarResult, segment);
                                } else if (recorded == (unsigned int)SequenceJudgeGradePoor) {
                                    SequenceSetBarCleared(gameScore.musicBarResult, segment);
                                }
                            }
                        }
                    }
                } else {
                    // The hold head was already judged; this frame judges its release. The release
                    // window is measured from the hold's tail sector (its start plus its length).
                    const unsigned int held = value >> 8;
                    const int releaseDelta = (int)_currentSector - (int)(event->sector + held);
                    const unsigned int segment =
                        SequenceBarSegment((int)(event->sector + held), endSector);
                    if (releaseDelta < 0) {
                        if (delta > -kSequenceWindowPoorBias && (1 << panel & btnDown) == 0) {
                            const int fromRelease = releaseDelta + (int)held;
                            const unsigned int divisor =
                                ((value >> 6) & 3) * kSequenceHoldLengthUnit;
                            const int grace = (int)held - (int)(((float)held / (float)divisor) *
                                                                kSequenceReleaseGraceScale);
                            if (grace <= fromRelease) {
                                event->judge = SequenceJudgeGradePerfect;
                            } else {
                                int percent = 0;
                                if (grace != 0) {
                                    percent = (fromRelease * kSequenceReleaseFullPercent) / grace;
                                }
                                if (percent < 0) {
                                    percent = 0;
                                }
                                if (percent > kSequenceReleaseFullPercent) {
                                    percent = kSequenceReleaseFullPercent;
                                }
                                long tableIndex = 1;
                                if (percent > kSequenceReleaseGreatPercent) {
                                    tableIndex = 2;
                                }
                                if (percent < kSequenceReleasePoorPercent) {
                                    tableIndex = 0;
                                }
                                const short releaseGrade = kSequenceReleaseGrades[tableIndex];
                                event->judge = releaseGrade;
                                if ((unsigned short)releaseGrade - 3 < 2) {
                                    SequenceSetBarFailed(gameScore.musicBarResult, segment);
                                } else if ((unsigned short)releaseGrade - 1 < 2) {
                                    SequenceSetBarCleared(gameScore.musicBarResult, segment);
                                }
                            }
                        }
                    } else {
                        event->judge = SequenceJudgeGradePerfect;
                    }
                    short releaseGrade = event->judge;
                    if (releaseGrade > SequenceJudgeGradeMiss) {
                        lastJudge[panel] = releaseGrade;
                        lastJudgeSector[panel] = _currentSector;
                        releaseGrade = event->judge;
                    }
                    if (releaseGrade != SequenceJudgeGradeNone) {
                        [self addJudge:releaseGrade];
                    }
                }
            }
            allJudged = (BOOL)(allJudged && event->judge != SequenceJudgeGradeNone);
        }
        ++eventIndex;
    } while ((unsigned int)eventIndex < numEvent);

    index = (unsigned int)eventIndex;
    if (!allJudged) {
        return;
    }
    judgedIndex = index;
}

#pragma mark - Event tables

- (nullable NSArray *)getPlayEvents {
    return playEventTable;
}

- (nullable NSArray *)getHoldEvents {
    return holdEventTable;
}

- (double)currentTime {
    return _currentTime;
}

- (unsigned int)currentSector {
    return _currentSector;
}

- (unsigned short)firstMarker {
    return _firstMarker;
}

- (unsigned int)firstMarkerSector {
    return _firstMarkerSector;
}

#pragma mark - Lifecycle

- (void)dealloc {
    if (events != nullptr) {
        free(events);
    }
    if (replayJudgeTable != nullptr) {
        free(replayJudgeTable);
    }
    if (replayTmpJudgeTable != nullptr) {
        free(replayTmpJudgeTable);
    }
}

@end
