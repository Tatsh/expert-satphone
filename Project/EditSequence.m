#import "EditSequence.h"

#import "AlertViewManager.h"
#import "BFCodec.h"
#import "KUnzip.h"
#import "LabUtilities.h"

// The maximum number of working events and clipboard events; the malloc'd arrays hold 2000 records
// of 20 bytes each (40000 bytes).
static const int kEditSequenceMaxEvents = 2000;
static const size_t kEditSequenceEventArrayByteCount = 40000;

// The event kinds packed into a SequenceEvent's low byte, matching Sequence's disc format.
enum {
    kEditSequenceEventTap = 1,
    kEditSequenceEventEnd = 2,
    kEditSequenceEventMeasure = 3,
    kEditSequenceEventHaku = 4,
    kEditSequenceEventTempo = 5,
    kEditSequenceEventHold = 6,
};

// The template slots. Slot 0 is the empty structural template (measure/beat/tempo lines only);
// slots 1..3 are the basic, advanced, and extreme difficulty note templates.
enum {
    kEditSequenceSlotEmpty = 0,
    kEditSequenceSlotBasic = 1,
    kEditSequenceSlotAdvanced = 2,
    kEditSequenceSlotExtreme = 3,
};

// The sequence-header magic block length and the fixed 96-byte header, matching Sequence.
static const NSUInteger kEditSequenceHeaderMagicLength = 0x24;
static const NSUInteger kEditSequenceHeaderByteCount = 0x60;
static const NSUInteger kEditSequenceDiscEventByteCount = 8;
static const NSUInteger kEditSequenceMusicBarOffset = 0x24;
// The header fields read out of the 0x24-byte magic block by -createEvents:tempSlot:.
static const NSUInteger kEditSequenceHeaderEventCountOffset = 0x04;
static const NSUInteger kEditSequenceHeaderNumPlayEventOffset = 0x08;
static const NSUInteger kEditSequenceHeaderEndSectorOffset = 0x0c;
static const NSUInteger kEditSequenceHeaderFirstMarkerOffset = 0x12;
static const NSUInteger kEditSequenceHeaderFirstSectorOffset = 0x14;

// The music-bar note-density is clamped to a single hex nibble's worth minus one before packing.
static const int kEditSequenceMaxDensityNibble = 8;

// The note-count ceiling, applied by -addNote:divide:isSwitch: and -exeAreaPaste:.
static const unsigned int kEditSequenceMaxNotes = 0x577;
// The trailing dead-zone before the end sector into which a note may not be placed or pasted.
static const unsigned int kEditSequenceEndSectorMargin = 0x9a;
// The fixed conflict-detection window, in sectors, returned by -getConflictSector.
static const unsigned int kEditSequenceConflictSector = 0x135;
// The near-note snap and conflict windows used by the note operations, in sectors.
static const int kEditSequenceSnapConflictSector = 8;
static const int kEditSequenceDeleteSearchSector = 0xaa;
static const int kEditSequenceKeyRunSector = 9;
static const int kEditSequenceClapWindow = 0xd;
// The one-past-terminator no-snap divide value for -getNearDiveBeatSector:divide:.
static const int kEditSequenceNoSnapDivide = 0xf;

// The marker lookahead and lookbehind spans, in sectors, and the "no marker" sentinel.
static const unsigned int kEditSequenceMarkerLookahead = 0xa0;
static const unsigned int kEditSequenceMarkerLookbehind = 0x50;
static const int kEditSequenceMarkerNone = 0x800;
static const unsigned int kEditSequenceMarkerGradeShift = 0xc;

// The history depth limit; the oldest entry is dropped once the count exceeds this.
static const NSUInteger kEditSequenceMaxHistory = 299;
// The empty-history history cursor sentinel.
static const int kEditSequenceHistoryEmpty = -1;

// The sector-to-time scale: a time in seconds times this yields the sector position. This is the
// same 300.0 scale the play engine uses.
// @ghidraAddress 0x28f2d0
static const double kEditSequenceSectorsPerSecond = 300.0;

// The measure-rewind seek offset, in sectors, added when scanning back two measures.
static const unsigned int kEditSequenceRewindMargin = 300;

// The template-slot remap table at 0x293b20 is the identity {0, 1, 2, 3}; -loadTemplate: and the
// per-slot template accessors index into it.
// @ghidraAddress 0x293b20
static const int kEditSequenceTemplateSlotMap[] = {kEditSequenceSlotEmpty,
                                                   kEditSequenceSlotBasic,
                                                   kEditSequenceSlotAdvanced,
                                                   kEditSequenceSlotExtreme};

// The debug labels passed to -printInfoParts: around -eventShift:destIndex:.
static NSString *const kEditSequenceInfoBefore = @"Before";
static NSString *const kEditSequenceInfoAfter = @"After";

// The archive entry names of the three difficulties inside a downloaded pack, matching Sequence.
static NSString *const kEditSequenceDifficultyBasic = @"seq_bas";
static NSString *const kEditSequenceDifficultyAdvanced = @"seq_adv";
static NSString *const kEditSequenceDifficultyExtreme = @"seq_ext";

// The over-limit alert strings, resolved from the CFString constants at 0x2e21a0 and 0x2e21c0.
static NSString *const kEditSequenceOverLimitTitle = @"イベント";
static NSString *const kEditSequenceOverLimitMessage =
    @"イベント数が2000を越えるため、小節、拍を該当譜面から削除します。";
static NSString *const kEditSequenceOKKey = @"OK";

@implementation EditSequence

#pragma mark - Music-bar helpers

// Maps a sector to its music-bar segment index, guarding against a zero end sector.
static inline int EditSequenceBarSegment(int sector, unsigned int endSectorValue) {
    if (endSectorValue == 0) {
        return 0;
    }
    return (int)((unsigned int)(sector * kEditSequenceMusicBarSegmentCount) / endSectorValue);
}

// Writes a note-density count into one segment's nibble of the packed music bar; even segments use
// the low nibble and odd segments the high nibble of byte segment/2.
static inline void EditSequenceWriteMusicBarNibble(char *bar, int segment, int density) {
    char *byte = &bar[segment >> 1];
    if ((segment & 1) == 0) {
        *byte = (char)((*byte & 0xf0) + (char)density);
    } else {
        *byte = (char)((*byte & 0x0f) | (char)(density << 4));
    }
}

// Sets one segment's nibble of the packed conflict bar to the conflict flag.
static inline void EditSequenceWriteConflictNibble(char *table, int segment) {
    char *byte = &table[segment >> 1];
    if ((segment & 1) == 0) {
        *byte = (char)((*byte & 0xf0) | 1);
    } else {
        *byte = (char)((*byte & 0x0f) | 0x10);
    }
}

#pragma mark - Event data

- (NSMutableArray<NSNumber *> *)getEventData {
    NSMutableArray<NSNumber *> *result = [[NSMutableArray alloc] init];
    // Always re-encodes the full 2000-entry event array, matching the binary's fixed loop count.
    for (int i = 0; i < kEditSequenceMaxEvents; ++i) {
        const SequenceEvent *event = &events[i];
        const unsigned long word = (unsigned long)(long)event->kind +
                                   (unsigned long)(unsigned int)((int)event->sector << 4) +
                                   (unsigned long)(unsigned int)((int)event->value << 0x18);
        [result addObject:@(word)];
    }
    return result;
}

#pragma mark - Class methods

+ (void)getMusicBarData:(char *)raw raw:(NSData *)data {
    if (data != nil && data.length > kEditSequenceHeaderByteCount) {
        [data getBytes:raw
                 range:NSMakeRange(kEditSequenceMusicBarOffset, kEditSequenceMusicBarByteCount)];
    }
}

- (BOOL)checkEventsLegality:(NSData *)data {
    if (data == nil || data.length <= kEditSequenceHeaderMagicLength) {
        return NO;
    }
    char header[kEditSequenceHeaderMagicLength];
    [data getBytes:header length:kEditSequenceHeaderMagicLength];
    BOOL magicOK = NO;
    if (header[0] == 'J') {
        magicOK = (header[1] == 'B' && header[2] == 'S' && header[3] == 'Q');
    } else if (header[0] == 'I') {
        magicOK = (header[1] == 'J' && header[2] == 'B' && header[3] == 'Q') ||
                  (header[1] == 'J' && header[2] == 'S' && header[3] == 'Q');
    }
    if (!magicOK) {
        return NO;
    }
    const int eventCount = *(const int *)&header[kEditSequenceHeaderEventCountOffset];
    return (NSUInteger)(eventCount * (int)kEditSequenceDiscEventByteCount +
                        (int)kEditSequenceHeaderByteCount) <= data.length;
}

- (void)createEvents:(NSData *)data tempSlot:(int)slot {
    if (slot >= kEditSequenceTemplateSlotCount) {
        return;
    }
    char header[kEditSequenceHeaderMagicLength];
    [data getBytes:header length:kEditSequenceHeaderMagicLength];
    const unsigned int rawEventCount =
        *(const unsigned int *)&header[kEditSequenceHeaderEventCountOffset];

    templateNotesNum[slot] = 0;
    unsigned int cappedEventCount = kEditSequenceMaxEvents;
    if (rawEventCount < kEditSequenceMaxEvents + 1) {
        cappedEventCount = rawEventCount;
    }
    templateNumEvent[slot] = cappedEventCount;
    numPlayEvent = *(const unsigned int *)&header[kEditSequenceHeaderNumPlayEventOffset];
    endSector = *(const unsigned int *)&header[kEditSequenceHeaderEndSectorOffset];
    _firstMarker = *(const unsigned short *)&header[kEditSequenceHeaderFirstMarkerOffset];
    _firstMarkerSector = *(const unsigned int *)&header[kEditSequenceHeaderFirstSectorOffset];
    templateEndSector[slot] = endSector;
    char *slotMusicBar = templateMusicBar[slot];
    [data getBytes:slotMusicBar
             range:NSMakeRange(kEditSequenceMusicBarOffset, kEditSequenceMusicBarByteCount)];

    if (eventsTemplate[slot] == nullptr) {
        eventsTemplate[slot] = (SequenceEvent *)malloc(kEditSequenceEventArrayByteCount);
        bzero(eventsTemplate[slot], kEditSequenceEventArrayByteCount);
    }
    memset(slotMusicBar, 0, kEditSequenceTemplateMusicBarByteCount);

    int outIndex = 0;
    if (rawEventCount != 0) {
        if (slot == kEditSequenceSlotEmpty) {
            // The empty structural template keeps only measure/beat/tempo lines: taps and holds are
            // dropped (a hold is rewritten to a tap and then skipped) so the slot carries the grid
            // alone.
            short measureNumber = 0;
            unsigned int limit = rawEventCount;
            for (unsigned int i = 0; i < limit; ++i) {
                unsigned int packed[2];
                [data getBytes:packed
                         range:NSMakeRange(kEditSequenceHeaderByteCount +
                                               i * kEditSequenceDiscEventByteCount,
                                           kEditSequenceDiscEventByteCount)];
                unsigned int kind = packed[0] & 0xff;
                SequenceEvent *event = &eventsTemplate[slot][outIndex];
                event->kind = (short)kind;
                event->sector = packed[0] >> 8;
                event->value = packed[1];
                if (kind == kEditSequenceEventMeasure) {
                    event->judge = measureNumber;
                    ++measureNumber;
                } else if (kind == kEditSequenceEventHold) {
                    kind = kEditSequenceEventTap;
                    event->kind = kEditSequenceEventTap;
                    event->value = packed[1] & 0xf;
                    --limit;
                } else if (kind == kEditSequenceEventEnd) {
                    ++outIndex;
                    break;
                }
                if (kind != kEditSequenceEventTap) {
                    ++outIndex;
                }
            }
        } else {
            short measureNumber = 0;
            unsigned int limit = rawEventCount;
            for (unsigned int i = 0; i < limit; ++i) {
                unsigned int packed[2];
                [data getBytes:packed
                         range:NSMakeRange(kEditSequenceHeaderByteCount +
                                               i * kEditSequenceDiscEventByteCount,
                                           kEditSequenceDiscEventByteCount)];
                SequenceEvent *event = &eventsTemplate[slot][outIndex];
                event->kind = (short)(packed[0] & 0xff);
                event->sector = packed[0] >> 8;
                event->value = packed[1];
                switch (packed[0] & 0xff) {
                case kEditSequenceEventEnd:
                    ++outIndex;
                    goto done;
                case kEditSequenceEventMeasure:
                    event->judge = measureNumber;
                    ++measureNumber;
                    break;
                case kEditSequenceEventHold:
                    event->kind = kEditSequenceEventTap;
                    event->value = packed[1] & 0xf;
                    --limit;
                    // Falls through to the tap density accounting.
                    __attribute__((fallthrough));
                case kEditSequenceEventTap: {
                    const int segment = EditSequenceBarSegment((int)(packed[0] >> 8), endSector);
                    slotMusicBar[segment] = (char)(slotMusicBar[segment] + 1);
                    ++templateNotesNum[slot];
                    break;
                }
                default:
                    break;
                }
                // When the chart is over the event cap the loop compresses runs of measure/beat
                // lines, otherwise it advances one record per event.
                if (rawEventCount < kEditSequenceMaxEvents + 1) {
                    ++outIndex;
                } else if ((unsigned short)(eventsTemplate[slot][outIndex].kind - 3) > 1) {
                    ++outIndex;
                }
            }
        }
    }
done:
    templateNumEvent[slot] = (unsigned int)outIndex;
    if (rawEventCount > kEditSequenceMaxEvents) {
        [[AlertViewManager sharedManager]
            makeAlert:0
             delegate:(id<AlertViewManagerDelegate>)self
                  tag:0
                title:kEditSequenceOverLimitTitle
                  msg:kEditSequenceOverLimitMessage
               cancel:[NSBundle.mainBundle localizedStringForKey:kEditSequenceOKKey
                                                           value:@""
                                                           table:nil]
              btnText:nil
                 show:YES];
    }
}

#pragma mark - Music-bar and conflict-table refresh

- (void)refreshEditMusicBar {
    bzero(editMusicBar, sizeof(editMusicBar));
    for (unsigned int i = 0; i < numEvent; ++i) {
        if (events[i].kind == kEditSequenceEventTap) {
            const int segment = EditSequenceBarSegment((int)events[i].sector, endSector);
            ++editMusicBar[segment];
        }
    }
}

- (void)refreshMusicBar {
    memset(musicBar, 0, kEditSequenceMusicBarByteCount);
    for (int segment = 0; segment < kEditSequenceMusicBarSegmentCount; ++segment) {
        int density = editMusicBar[segment];
        if (density > kEditSequenceMaxDensityNibble) {
            density = kEditSequenceMaxDensityNibble;
        }
        EditSequenceWriteMusicBarNibble(musicBar, segment, density);
    }
}

- (void)refreshConflictTable {
    memset(conflictTable, 0, kEditSequenceMusicBarByteCount);
    for (int segment = 0; segment < kEditSequenceMusicBarSegmentCount; ++segment) {
        if (editConflictTable[segment] != 0) {
            EditSequenceWriteConflictNibble(conflictTable, segment);
        }
    }
}

- (void)loadTemplate:(int)slot {
    if (slot >= kEditSequenceTemplateSlotCount) {
        return;
    }
    const int mapped = kEditSequenceTemplateSlotMap[slot];
    memcpy(events, eventsTemplate[mapped], kEditSequenceEventArrayByteCount);
    for (int segment = 0; segment < kEditSequenceMusicBarSegmentCount; ++segment) {
        editMusicBar[segment] = (int)templateMusicBar[mapped][segment];
    }
    memset(editConflictTable, 0, kEditSequenceMusicBarSegmentCount);
    numEvent = templateNumEvent[mapped];
    endSector = templateEndSector[mapped];
    notesNum = templateNotesNum[mapped];
    [self refreshMusicBar];
    [self createConflictTable];
    [editHistory removeAllObjects];
    _enableRedo = NO;
    _enableUndo = NO;
}

- (void)createConflictTable {
    memset(editConflictTable, 0, kEditSequenceMusicBarSegmentCount);
    for (unsigned int i = 0; i < numEvent; ++i) {
        if (events[i].kind == kEditSequenceEventTap && [self checkConflictArea:i vector:1]) {
            const int segment = EditSequenceBarSegment((int)events[i].sector, endSector);
            editConflictTable[segment] = 1;
        }
    }
    [self refreshConflictTable];
}

#pragma mark - Conflict detection

- (BOOL)checkConflictEvent:(int)index btn:(unsigned int)btn {
    return events[index].kind == kEditSequenceEventTap && events[index].value == btn;
}

- (int)searchBtnNearSector:(int)sector btn:(int)btn {
    if (numEvent == 0) {
        return -1;
    }
    int best = -1;
    int bestDistance = (int)endSector;
    for (unsigned int i = 0; i < numEvent; ++i) {
        if (events[i].kind == kEditSequenceEventTap && (int)events[i].value == btn) {
            int delta = (int)events[i].sector - sector;
            if (delta < 0) {
                delta = -delta;
            }
            if (bestDistance < delta) {
                return best;
            }
            bestDistance = delta;
            best = (int)i;
        }
    }
    return best;
}

- (int)searchNearIndex:(int)sector {
    if (numEvent == 0) {
        return 0;
    }
    int best = -1;
    int bestDistance = (int)endSector;
    for (unsigned int i = 0; i < numEvent; ++i) {
        int delta = (int)events[i].sector - sector;
        if (delta < 0) {
            delta = -delta;
        }
        if (bestDistance < delta) {
            break;
        }
        bestDistance = delta;
        best = (int)i;
        if (i + 1 >= numEvent) {
            return 0;
        }
    }
    return best;
}

- (int)checkConflictByIndex:(int)index
                        btn:(unsigned int)btn
                        vec:(int)direction
                       area:(int)area
                  sameCheck:(BOOL)sameCheck {
    const int referenceSector = (int)events[index].sector;
    BOOL backward = NO;
    if (direction < 1) {
        backward = (direction != 0);
        if (index == 0 && direction != 0) {
            return -1;
        }
    } else {
        if ((int)numEvent == index) {
            return -1;
        }
    }
    int probe = index + (sameCheck ? 0 : direction);
    if (probe >= kEditSequenceMaxEvents) {
        return -1;
    }
    int probeSector = (int)events[probe].sector;

    if (direction < 1) {
        if (backward) {
            if (probe == 0 || area < referenceSector - probeSector) {
                return -1;
            }
            while (YES) {
                if ([self checkConflictEvent:probe btn:btn]) {
                    return probe;
                }
                if (probe - 1 >= kEditSequenceMaxEvents || -direction == probe) {
                    return -1;
                }
                const int nextSector = (int)events[probe + direction].sector;
                probe += direction;
                if (referenceSector - nextSector > area) {
                    return -1;
                }
            }
        }
        if (probeSector - referenceSector <= area) {
            while (YES) {
                if ([self checkConflictEvent:probe btn:btn]) {
                    return probe;
                }
                if (probe + direction >= kEditSequenceMaxEvents) {
                    break;
                }
                const int nextSector = (int)events[probe + direction].sector;
                probe += direction;
                if (nextSector - referenceSector > area) {
                    return -1;
                }
            }
        }
    } else {
        if (backward) {
            if (referenceSector - probeSector <= area && probe != 0 && probe != (int)numEvent) {
                while (YES) {
                    if ([self checkConflictEvent:probe btn:btn]) {
                        return probe;
                    }
                    if (probe + direction >= kEditSequenceMaxEvents) {
                        break;
                    }
                    const int nextSector = (int)events[probe + direction].sector;
                    const BOOL wrap = (-direction == probe);
                    probe += direction;
                    if (referenceSector - nextSector > area || wrap || probe == (int)numEvent) {
                        return -1;
                    }
                }
            }
        } else if (probeSector - referenceSector <= area && probe != (int)numEvent) {
            while (YES) {
                if ([self checkConflictEvent:probe btn:btn]) {
                    return probe;
                }
                if (probe + direction >= kEditSequenceMaxEvents) {
                    break;
                }
                const int nextSector = (int)events[probe + direction].sector;
                probe += direction;
                if (nextSector - referenceSector > area || probe == (int)numEvent) {
                    return -1;
                }
            }
        }
    }
    return -1;
}

- (int)checkConflictBySector:(int)sector
                         btn:(unsigned int)btn
                         vec:(int)direction
                        area:(int)area
                   sameCheck:(BOOL)sameCheck {
    int probe = [self searchNearIndex:sector];
    BOOL backward = NO;
    if (direction < 1) {
        backward = (direction != 0);
        if (direction != 0 && probe == 0) {
            return -1;
        }
    } else {
        if (probe == (int)numEvent) {
            return -1;
        }
    }
    probe += (sameCheck ? 0 : direction);
    if ((unsigned int)probe >= kEditSequenceMaxEvents) {
        return -1;
    }

    if (direction < 1) {
        if (backward) {
            while (probe != 0) {
                int delta = sector - (int)events[probe].sector;
                if (delta < 0) {
                    delta = -delta;
                }
                if (area < delta) {
                    return -1;
                }
                if ([self checkConflictEvent:probe btn:btn]) {
                    return probe;
                }
                probe += direction;
                if ((unsigned int)probe >= kEditSequenceMaxEvents) {
                    return -1;
                }
            }
        } else {
            while (YES) {
                int delta = (int)events[probe].sector - sector;
                if (delta < 0) {
                    delta = -delta;
                }
                if (area < delta) {
                    break;
                }
                if ([self checkConflictEvent:probe btn:btn]) {
                    return probe;
                }
                probe += direction;
                if ((unsigned int)probe >= kEditSequenceMaxEvents) {
                    return -1;
                }
            }
        }
    } else {
        if (backward) {
            while (YES) {
                if (probe == 0 || probe == (int)numEvent) {
                    return -1;
                }
                int delta = sector - (int)events[probe].sector;
                if (delta < 0) {
                    delta = -delta;
                }
                if (area < delta) {
                    break;
                }
                if ([self checkConflictEvent:probe btn:btn]) {
                    return probe;
                }
                probe += direction;
                if ((unsigned int)probe >= kEditSequenceMaxEvents) {
                    return -1;
                }
            }
        } else {
            while (probe != (int)numEvent) {
                int delta = (int)events[probe].sector - sector;
                if (delta < 0) {
                    delta = -delta;
                }
                if (area < delta) {
                    return -1;
                }
                if ([self checkConflictEvent:probe btn:btn]) {
                    return probe;
                }
                probe += direction;
                if ((unsigned int)probe >= kEditSequenceMaxEvents) {
                    return -1;
                }
            }
        }
    }
    return -1;
}

- (BOOL)checkConflictBySector:(int)sector
                          btn:(unsigned int)btn
                         area:(int)area
                    sameCheck:(BOOL)sameCheck {
    if ([self checkConflictBySector:sector btn:btn vec:1 area:area sameCheck:sameCheck] != -1) {
        return YES;
    }
    return [self checkConflictBySector:sector btn:btn vec:-1 area:area sameCheck:sameCheck] != -1;
}

- (BOOL)checkConflictByIndex:(int)index
                         btn:(unsigned int)btn
                        area:(int)area
                   sameCheck:(BOOL)sameCheck {
    if ([self checkConflictByIndex:index btn:btn vec:-1 area:area sameCheck:sameCheck] != -1) {
        return YES;
    }
    return [self checkConflictByIndex:index btn:btn vec:1 area:area sameCheck:sameCheck] != -1;
}

- (BOOL)checkConflictArea:(unsigned int)index vector:(int)direction {
    return [self checkConflictByIndex:(int)index
                                  btn:events[index].value
                                  vec:direction
                                 area:(int)kEditSequenceConflictSector
                            sameCheck:NO] != -1;
}

- (BOOL)checkConflict:(unsigned int)btn vector:(int)direction {
    // The binary returns "index != 0"; a conflict found at index 0 reads as no conflict here.
    return [self checkConflictByIndex:(int)_currentIndex
                                  btn:btn
                                  vec:direction
                                 area:0
                            sameCheck:YES] != 0;
}

- (BOOL)checkKeyConflict:(int)btn {
    const int index = [self searchBtnNearSector:(int)_currentSector btn:btn];
    if (index == -1) {
        return NO;
    }
    return [self checkConflictByIndex:index
                                  btn:(unsigned int)btn
                                 area:(int)kEditSequenceConflictSector
                            sameCheck:NO];
}

- (BOOL)conflictKeyCheck:(unsigned int)btn vector:(int)direction {
    unsigned int index = _currentIndex;
    if ((int)events[index].sector == (int)_currentSector) {
        if ([self checkConflictEvent:(int)index btn:btn]) {
            return YES;
        }
        index = _currentIndex;
    }
    int probe = (int)index + direction;
    if (probe > kEditSequenceMaxEvents - 1) {
        return NO;
    }
    const int referenceSector = (int)_currentSector;
    while (YES) {
        if (probe > kEditSequenceMaxEvents - 1) {
            return NO;
        }
        int delta = (int)events[probe].sector - referenceSector;
        if (delta < 0) {
            delta = -delta;
        }
        if (probe < 0) {
            return NO;
        }
        if (delta > kEditSequenceKeyRunSector) {
            return NO;
        }
        const BOOL conflict = [self checkConflictEvent:probe btn:btn];
        probe += conflict ? 0 : direction;
        if (conflict) {
            return YES;
        }
    }
}

#pragma mark - History

- (void)addHistory:(NSArray *)parts {
    if (parts == nil) {
        return;
    }
    if (editHistory.count > kEditSequenceMaxHistory) {
        [editHistory removeObjectAtIndex:0];
    }
    if (currentHistory == kEditSequenceHistoryEmpty) {
        [editHistory removeAllObjects];
    }
    if (editHistory.count != 0 && editHistory.count - 1 != (NSUInteger)currentHistory) {
        // Editing after an undo drops the now-orphaned redo tail.
        if (currentHistory + 1 < (int)editHistory.count) {
            int drop = ((int)editHistory.count - 1) - currentHistory;
            do {
                [editHistory removeLastObject];
                --drop;
            } while (drop != 0);
        }
    }
    [editHistory addObject:parts];
    currentHistory = (int)editHistory.count - 1;
    _enableRedo = NO;
    _enableUndo = YES;
}

- (int)rollController:(BOOL)undo {
    if (undo) {
        if (!_enableUndo) {
            return 0;
        }
    } else if (!_enableRedo) {
        return 0;
    }
    const int count = (int)editHistory.count;
    if (count == 0) {
        return 0;
    }
    int cursor = currentHistory;
    if (!undo) {
        ++cursor;
        currentHistory = cursor;
    }
    NSArray *entry = editHistory[cursor];
    if (entry == nil) {
        [editHistory removeObjectAtIndex:(NSUInteger)(count - 1)];
        return 0;
    }
    // An entry stores its parts back-to-front for a redo; a mismatched leading type is reversed so
    // both directions replay in the correct order.
    if (entry.count > 1) {
        const int firstType = [entry[0][2] intValue];
        if (undo) {
            if (firstType == 1) {
                entry = entry.reverseObjectEnumerator.allObjects;
            }
        } else if (firstType == 0) {
            entry = entry.reverseObjectEnumerator.allObjects;
        }
    }
    for (NSInteger i = (NSInteger)entry.count - 1; i >= 0; --i) {
        NSArray *part = entry[i];
        if (part == nil) {
            continue;
        }
        const int index = [part[0] intValue];
        const int sector = [part[1] intValue];
        const int type = [part[2] intValue];
        const int value = [part[3] intValue];
        BOOL insert;
        if (!undo) {
            if (type == 0) {
                insert = YES;
            } else if (type == 1) {
                insert = NO;
            } else {
                continue;
            }
        } else if (type == 0) {
            insert = NO;
        } else if (type == 1) {
            insert = YES;
        } else {
            continue;
        }
        if (insert) {
            [self eventShift:index destIndex:index + 1];
            SequenceEvent *event = &events[index];
            event->kind = kEditSequenceEventTap;
            event->sector = (unsigned int)sector;
            event->value = (unsigned int)value;
            ++numEvent;
            ++notesNum;
        } else {
            [self eventShift:index + 1 destIndex:index];
            --numEvent;
            --notesNum;
        }
    }
    [self refreshEditMusicBar];
    [self refreshMusicBar];
    [self createConflictTable];
    cursor = currentHistory;
    if (undo) {
        --cursor;
        currentHistory = cursor;
    }
    _enableUndo = (cursor != kEditSequenceHistoryEmpty);
    _enableRedo = ((int)editHistory.count - 1 != currentHistory);
    return count;
}

- (BOOL)isClap {
    return bClapSE;
}

- (int)undoHistory {
    return [self rollController:YES];
}

- (int)redoHistory {
    return [self rollController:NO];
}

- (void)addHistoryParts:(NSMutableArray *)parts
                  index:(int)index
                 sector:(int)sector
                   type:(int)type
                  value:(int)value {
    NSMutableArray *part = [[NSMutableArray alloc] initWithCapacity:4];
    part[0] = @(index);
    part[1] = @(sector);
    part[2] = @(type);
    part[3] = @(value);
    [parts addObject:part];
}

#pragma mark - Note operations

- (int)addNote:(unsigned int)btn divide:(int)divide isSwitch:(BOOL)isSwitch {
    int sector = [self getNearDiveBeatSector:(int)_currentSector divide:divide];
    if ((int)(endSector - kEditSequenceEndSectorMargin) < sector) {
        return 2;
    }
    if ([self checkConflictBySector:sector
                                btn:btn
                               area:kEditSequenceSnapConflictSector
                          sameCheck:YES]) {
        if (isSwitch) {
            [self deleteNote:btn];
        }
        return 0;
    }

    int insertIndex = -1;
    if (numEvent != 0) {
        for (unsigned int i = 0; i < numEvent; ++i) {
            if (sector < (int)events[i].sector) {
                insertIndex = (int)i;
                break;
            }
        }
        if (numEvent > kEditSequenceMaxEvents - 1) {
            return 1;
        }
    }
    if (notesNum > kEditSequenceMaxNotes) {
        return 1;
    }
    if (insertIndex < 0) {
        return 0;
    }

    [self eventShift:insertIndex destIndex:insertIndex + 1];
    SequenceEvent *event = &events[insertIndex];
    event->kind = kEditSequenceEventTap;
    event->sector = (unsigned int)sector;
    event->value = btn;
    NSMutableArray *parts = [[NSMutableArray alloc] init];
    [self addHistoryParts:parts index:insertIndex sector:sector type:0 value:(int)btn];
    [self addHistory:parts];
    ++numEvent;
    ++notesNum;

    const int segment = EditSequenceBarSegment((int)events[insertIndex].sector, endSector);
    const int density = ++editMusicBar[segment];
    if (density < kEditSequenceMaxDensityNibble) {
        EditSequenceWriteMusicBarNibble(musicBar, segment, density);
    }
    BOOL conflict = [self checkConflictArea:(unsigned int)insertIndex vector:1] ||
                    [self checkConflictArea:(unsigned int)insertIndex vector:-1];
    if (conflict) {
        ++editConflictTable[segment];
    }
    if (editConflictTable[segment] > 0) {
        EditSequenceWriteConflictNibble(conflictTable, segment);
    }
    _enableUndo = YES;
    _enableRedo = NO;
    return 0;
}

- (int)addNote:(unsigned int)btn {
    if (![self conflictKeyCheck:btn vector:1] && ![self conflictKeyCheck:btn vector:-1]) {
        if (numEvent > kEditSequenceMaxEvents - 1) {
            return 1;
        }
        const int insertIndex = (int)_currentIndex;
        [self eventShift:insertIndex destIndex:insertIndex + 1];
        SequenceEvent *event = &events[insertIndex];
        event->kind = kEditSequenceEventTap;
        event->value = btn;
        event->sector = _currentSector;
        NSMutableArray *parts = [[NSMutableArray alloc] init];
        [self addHistoryParts:parts
                        index:insertIndex
                       sector:(int)_currentSector
                         type:0
                        value:(int)btn];
        [self addHistory:parts];
        ++numEvent;
        ++notesNum;

        const int segment = EditSequenceBarSegment((int)events[_currentIndex].sector, endSector);
        const int density = ++editMusicBar[segment];
        if (density < kEditSequenceMaxDensityNibble) {
            EditSequenceWriteMusicBarNibble(musicBar, segment, density);
        }
        BOOL conflict = [self checkConflictArea:(unsigned int)insertIndex vector:1] ||
                        [self checkConflictArea:(unsigned int)insertIndex vector:-1];
        if (conflict) {
            ++editConflictTable[segment];
        }
        if (editConflictTable[segment] > 0) {
            EditSequenceWriteConflictNibble(conflictTable, segment);
        }
        _enableUndo = YES;
        _enableRedo = NO;
    } else {
        [self deleteNote:btn];
    }
    return 0;
}

- (BOOL)deleteNote:(unsigned int)btn {
    // Scans forwards then backwards from the current index for the nearest matching note within the
    // delete search window, then removes whichever is closer.
    int forwardIndex = -1;
    unsigned int forwardDistance = 0xb4;
    if (_currentIndex < numEvent) {
        for (unsigned int i = _currentIndex; i < numEvent; ++i) {
            int delta = (int)events[i].sector - (int)_currentSector;
            if (delta < 0) {
                delta = -delta;
            }
            if (delta > kEditSequenceDeleteSearchSector) {
                break;
            }
            if (events[i].kind == kEditSequenceEventTap && events[i].value == btn) {
                forwardIndex = (int)i;
                forwardDistance = (unsigned int)delta;
                break;
            }
        }
    }
    int backwardIndex = -1;
    unsigned int backwardDistance = 0xb4;
    for (int i = (int)_currentIndex - 1; i > 0; --i) {
        int delta = (int)events[i].sector - (int)_currentSector;
        if (delta < 0) {
            delta = -delta;
        }
        if (delta > kEditSequenceDeleteSearchSector) {
            break;
        }
        if (events[i].kind == kEditSequenceEventTap && events[i].value == btn) {
            backwardIndex = i;
            backwardDistance = (unsigned int)delta;
            break;
        }
    }
    if ((backwardIndex & forwardIndex) == -1) {
        return NO;
    }
    int target = backwardIndex;
    if (forwardDistance <= backwardDistance) {
        target = forwardIndex;
    }

    const int targetSector = (int)events[target].sector;
    const int segment = EditSequenceBarSegment(targetSector, endSector);
    int density = editMusicBar[segment];
    if (density > 0) {
        --density;
    }
    editMusicBar[segment] = density;
    if (density < kEditSequenceMaxDensityNibble) {
        EditSequenceWriteMusicBarNibble(musicBar, segment, editMusicBar[segment]);
    }

    NSMutableArray *parts = [[NSMutableArray alloc] init];
    [self addHistoryParts:parts index:target sector:targetSector type:1 value:(int)btn];
    [self addHistory:parts];
    [self eventShift:target + 1 destIndex:target];
    --numEvent;
    events[numEvent].kind = 0;
    --notesNum;
    --_currentIndex;
    [self createConflictTable];
    _enableUndo = YES;
    _enableRedo = NO;
    return YES;
}

#pragma mark - Beat and rate math

- (float)getNearBeatRate:(float)rate {
    const unsigned int endSectorValue = endSector;
    unsigned int best = endSectorValue;
    unsigned int bestDelta = endSectorValue;
    for (unsigned int i = 0; i < templateNumEvent[kEditSequenceSlotEmpty]; ++i) {
        const SequenceEvent *event = &eventsTemplate[kEditSequenceSlotEmpty][i];
        if (event->kind == kEditSequenceEventHaku) {
            const unsigned int delta = event->sector - (unsigned int)((float)endSectorValue * rate);
            if (bestDelta > delta) {
                best = event->sector;
                bestDelta = delta;
            }
        }
    }
    return (float)best / (float)endSectorValue;
}

- (int)getNearDiveBeatSector:(int)sector divide:(int)divide {
    if (divide == kEditSequenceNoSnapDivide) {
        return sector;
    }
    int steps = divide;
    if (divide == 0) {
        steps = 1;
    }
    if (sector < 0) {
        return 0;
    }
    const unsigned int endSectorValue = endSector;
    if ((int)endSectorValue < sector) {
        return (int)endSectorValue;
    }

    // Find the nearest beat line in the empty template.
    int nearestSector = (int)endSectorValue;
    int nearestDelta = (int)endSectorValue;
    unsigned int nearestBeatIndex = 0;
    for (unsigned int i = 0; i < templateNumEvent[kEditSequenceSlotEmpty]; ++i) {
        const SequenceEvent *event = &eventsTemplate[kEditSequenceSlotEmpty][i];
        if (event->kind == kEditSequenceEventHaku) {
            int delta = (int)event->sector - sector;
            int absDelta = delta < 0 ? -delta : delta;
            int absNearest = nearestDelta < 0 ? -nearestDelta : nearestDelta;
            if (absNearest > absDelta) {
                nearestSector = (int)event->sector;
                nearestDelta = delta;
                nearestBeatIndex = i;
            }
        }
    }
    if (steps == 1 || nearestSector == sector) {
        return nearestSector;
    }

    // Pick the neighbouring beat on the side the reference sector lies, then subdivide between
    // them.
    int neighbourSector = 0;
    if (nearestDelta < 1) {
        for (unsigned int i = nearestBeatIndex + 1; i < templateNumEvent[kEditSequenceSlotEmpty];
             ++i) {
            if (eventsTemplate[kEditSequenceSlotEmpty][i].kind == kEditSequenceEventHaku) {
                neighbourSector = (int)eventsTemplate[kEditSequenceSlotEmpty][i].sector;
                break;
            }
        }
    } else {
        for (int i = (int)nearestBeatIndex - 1; i >= 1; --i) {
            if (eventsTemplate[kEditSequenceSlotEmpty][i - 1].kind == kEditSequenceEventHaku) {
                neighbourSector = (int)eventsTemplate[kEditSequenceSlotEmpty][i - 1].sector;
                break;
            }
        }
    }

    int span = neighbourSector - nearestSector;
    int base = nearestSector;
    if (span < 0) {
        base = neighbourSector;
        span = -span;
    }
    int bestSector = base;
    int bestDelta = (int)endSectorValue;
    for (int step = 0; step <= steps; ++step) {
        int subSector = base + (steps != 0 ? (step * span) / steps : 0);
        int delta = subSector - sector;
        int absDelta = delta < 0 ? -delta : delta;
        int absBest = bestDelta < 0 ? -bestDelta : bestDelta;
        if (absBest > absDelta) {
            bestSector = subSector;
            bestDelta = delta;
        }
    }
    return bestSector;
}

- (float)getNearDivBeatRate:(float)rate divide:(int)divide {
    const float endSectorValue = (float)endSector;
    const int sector = [self getNearDiveBeatSector:(int)(endSectorValue * rate) divide:divide];
    return (float)sector / (float)endSector;
}

- (float)sector2rate:(int)sector {
    return (float)sector / (float)endSector;
}

- (unsigned int)rate2sector:(float)rate {
    return (unsigned int)(int)((float)endSector * rate);
}

- (int)getFrontBeatSector:(int)sector {
    int result = 0;
    for (unsigned int i = 0; i < templateNumEvent[kEditSequenceSlotEmpty]; ++i) {
        const SequenceEvent *event = &eventsTemplate[kEditSequenceSlotEmpty][i];
        if (sector < (int)event->sector) {
            return result;
        }
        if (event->kind == kEditSequenceEventHaku) {
            result = (int)event->sector;
        }
    }
    return -1;
}

- (int)getBackBeatSector:(int)sector {
    for (unsigned int i = 0; i < templateNumEvent[kEditSequenceSlotEmpty]; ++i) {
        const SequenceEvent *event = &eventsTemplate[kEditSequenceSlotEmpty][i];
        if (sector < (int)event->sector && event->kind == kEditSequenceEventHaku) {
            return (int)event->sector;
        }
    }
    return -1;
}

#pragma mark - Chart loading

- (void)eventArrayDecode:(NSArray<NSNumber *> *)table {
    const int count = (int)table.count;
    numEvent = 0;
    notesNum = 0;
    if (count <= 0) {
        return;
    }
    short measureNumber = 0;
    for (int i = 0; i < count; ++i) {
        const unsigned long word = [table[i] unsignedLongValue];
        if (word == 0) {
            return;
        }
        const unsigned int kind = (unsigned int)word & 0xf;
        SequenceEvent *event = &events[numEvent];
        event->kind = (short)kind;
        event->sector = ((unsigned int)word >> 4) & 0xfffff;
        event->value = (unsigned int)(word >> 0x18) & 0xff;
        if (kind == kEditSequenceEventEnd) {
            ++numEvent;
            return;
        }
        short currentKind = events[numEvent].kind;
        if (currentKind == kEditSequenceEventTap) {
            const int segment = EditSequenceBarSegment((int)events[numEvent].sector, endSector);
            ++editMusicBar[segment];
            ++notesNum;
            currentKind = events[numEvent].kind;
        }
        if (currentKind == kEditSequenceEventMeasure) {
            events[numEvent].judge = measureNumber;
            ++measureNumber;
        }
        ++numEvent;
    }
}

- (void)importSequenceData:(NSArray<NSNumber *> *)table {
    [self eventArrayDecode:table];
    [self createConflictTable];
    [self refreshEditMusicBar];
    [self refreshMusicBar];
    [editHistory removeAllObjects];
}

- (instancetype)initWithData:(KUnzip *)data sequenceData:(NSArray<NSNumber *> *)sequenceData {
    BFCodec *codec = [[BFCodec alloc] init];
    NSData *key = GetBgmCipherKey();
    [codec cipherInit:key];
    NSMutableData *basic = [data uncompress:kEditSequenceDifficultyBasic];
    [codec decipher:basic];
    NSMutableData *advanced = [data uncompress:kEditSequenceDifficultyAdvanced];
    [codec decipher:advanced];
    NSMutableData *extreme = [data uncompress:kEditSequenceDifficultyExtreme];
    [codec decipher:extreme];

    if (![self checkEventsLegality:basic] || ![self checkEventsLegality:advanced] ||
        ![self checkEventsLegality:extreme]) {
        return nil;
    }
    self = [super init];
    if (self == nil) {
        return nil;
    }
    numCopyEvent = 0;
    eventsTemplate[0] = nullptr;
    eventsTemplate[1] = nullptr;
    eventsTemplate[2] = nullptr;
    eventsTemplate[3] = nullptr;
    events = nullptr;
    [self createEvents:basic tempSlot:kEditSequenceSlotBasic];
    [self createEvents:advanced tempSlot:kEditSequenceSlotAdvanced];
    [self createEvents:extreme tempSlot:kEditSequenceSlotExtreme];
    [self createEvents:basic tempSlot:kEditSequenceSlotEmpty];
    copyEvents = (SequenceEvent *)malloc(kEditSequenceEventArrayByteCount);
    events = (SequenceEvent *)malloc(kEditSequenceEventArrayByteCount);
    if (sequenceData == nil) {
        [self loadTemplate:kEditSequenceSlotEmpty];
    } else {
        [self eventArrayDecode:sequenceData];
        [self createConflictTable];
    }
    [self refreshMusicBar];
    editHistory = [[NSMutableArray alloc] init];
    return self;
}

#pragma mark - Play-state

- (void)reset {
    backSector = 0;
    _currentTime = 0.0;
    _currentSector = 0;
    _currentIndex = 0;
    clapIndex = 0;
    oldTempo = 0;
    currentTempo = 0;
    for (unsigned int i = 0; i < numEvent; ++i) {
        if (events[i].kind != kEditSequenceEventMeasure) {
            events[i].judge = 0;
        }
    }
    judgedIndex = 0;
    for (unsigned int i = 0; i < kEditSequencePanelCount; ++i) {
        lastJudge[i] = 0;
        lastJudgeSector[i] = 0;
    }
    nextMeasureSector = 0;
    lastMeasureSector = 0;
    nextHakuSector = 0;
    lastHakuSector = 0;
    gameScore = (ScoreData){0};
}

- (void)seekToTime:(double)time {
    _currentTime = time;
    unsigned int sector = (unsigned int)(time * kEditSequenceSectorsPerSecond);
    _currentSector = sector;
    if (sector > endSector) {
        sector = endSector;
    }
    _currentSector = sector;

    const int previousClapIndex = clapIndex;
    clapIndex = 0;
    bClapSE = NO;
    int currentSectorValue = (int)_currentSector;
    unsigned int scan = (unsigned int)clapIndex;
    if (scan < numEvent) {
        const int previousBackSector = backSector;
        do {
            const unsigned int eventSector = events[scan].sector;
            if (currentSectorValue + kEditSequenceClapWindow < (int)eventSector) {
                break;
            }
            if (events[scan].kind == kEditSequenceEventTap && previousClapIndex <= (int)scan &&
                previousBackSector + kEditSequenceClapWindow < (int)eventSector) {
                bClapSE = YES;
                scan = (unsigned int)clapIndex;
            }
            ++scan;
            clapIndex = (int)scan;
        } while (scan < numEvent);
        currentSectorValue = (int)_currentSector;
    }
    backSector = currentSectorValue;

    _currentIndex = 0;
    if (numEvent == 0) {
        return;
    }
    do {
        const unsigned int eventSector = events[_currentIndex].sector;
        if (_currentSector < eventSector) {
            return;
        }
        const short kind = events[_currentIndex].kind;
        if (kind == kEditSequenceEventMeasure) {
            lastMeasureSector = eventSector;
            for (unsigned int j = _currentIndex + 1; j < numEvent; ++j) {
                if (events[j].kind == kEditSequenceEventMeasure) {
                    nextMeasureSector = events[j].sector;
                    break;
                }
            }
        } else if (kind == kEditSequenceEventTempo) {
            oldTempo = currentTempo;
            currentTempo = events[_currentIndex].value;
        } else if (kind == kEditSequenceEventHaku) {
            lastHakuSector = eventSector;
            for (unsigned int j = _currentIndex + 1; j < numEvent; ++j) {
                if (events[j].kind == kEditSequenceEventHaku) {
                    nextHakuSector = events[j].sector;
                    break;
                }
            }
        }
        ++_currentIndex;
    } while (_currentIndex < numEvent);
}

- (void)getMarkerState:(int *)state {
    const unsigned int startIndex = _currentIndex;
    const unsigned int startSector = events[startIndex].sector;
    for (unsigned int panel = 0; panel < kEditSequencePanelCount; ++panel) {
        state[panel] = kEditSequenceMarkerNone;
        const unsigned int grade = (unsigned int)lastJudge[panel];
        if (grade > 1) {
            const unsigned int age = _currentSector - lastJudgeSector[panel];
            if (age < kEditSequenceMarkerLookahead) {
                state[panel] = (int)(age | (grade << kEditSequenceMarkerGradeShift));
            }
        }
    }

    unsigned int backStart = startIndex + (startSector < _currentSector ? 1 : 0);
    if (backStart != 0) {
        for (int i = (int)backStart - 1; i >= 0; --i) {
            const unsigned int age = _currentSector - events[i].sector;
            if (age > kEditSequenceMarkerLookbehind) {
                break;
            }
            if (events[i].kind == kEditSequenceEventTap && events[i].value < 0x10 &&
                state[events[i].value] == kEditSequenceMarkerNone) {
                state[events[i].value] = (int)(age + (kEditSequenceMarkerLookahead - 1));
            }
        }
    }

    const BOOL skipCurrent = events[startIndex].sector < _currentSector;
    unsigned int index = startIndex + (skipCurrent ? 1 : 0);
    if (index < numEvent) {
        unsigned int lead = events[index].sector - _currentSector;
        if (lead < kEditSequenceMarkerLookahead) {
            unsigned int scan = startIndex + (skipCurrent ? 1 : 0);
            do {
                ++scan;
                if (events[index].kind == kEditSequenceEventTap && events[index].value < 0x10 &&
                    state[events[index].value] == kEditSequenceMarkerNone) {
                    state[events[index].value] = (int)((kEditSequenceMarkerLookahead - 1) - lead);
                }
                if (scan >= numEvent) {
                    break;
                }
                lead = events[scan].sector - _currentSector;
                index = scan;
            } while (lead < kEditSequenceMarkerLookahead);
        }
    }
}

#pragma mark - Table accessors

- (const char *)getMusicBar {
    return musicBar;
}

- (const char *)getConflictBar {
    return conflictTable;
}

- (const SequenceEvent *)getSequenceEventTable {
    return events;
}

- (const SequenceEvent *)getSequencePasteTable {
    return copyEvents;
}

- (unsigned int)getEndSector {
    return endSector;
}

- (unsigned int)getConflictSector {
    return kEditSequenceConflictSector;
}

- (int)getRewindMeasureSector {
    if (numEvent == 0) {
        return 0;
    }
    int result = 0;
    int pending = 0;
    for (unsigned int i = 0; i < numEvent; ++i) {
        if (_currentSector < events[i].sector + kEditSequenceRewindMargin) {
            return result;
        }
        if (events[i].kind == kEditSequenceEventMeasure) {
            result = pending;
            pending = (int)events[i].sector;
        }
    }
    return result;
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

#pragma mark - Area operations

- (int)searchSectorIndex:(int)sector {
    for (int i = 0; i < kEditSequenceMaxEvents; ++i) {
        if (sector <= (int)events[i].sector) {
            return i;
        }
        if (events[i].kind == kEditSequenceEventEnd) {
            break;
        }
    }
    return -1;
}

- (BOOL)exeAreaCopy:(int)startSec endSec:(int)endSec {
    const int startIndex = [self searchSectorIndex:startSec];
    numCopyEvent = 0;
    unsigned int written = 0;
    if (startIndex < kEditSequenceMaxEvents) {
        for (int i = startIndex; i < kEditSequenceMaxEvents; ++i) {
            const unsigned int eventSector = events[i].sector;
            if ((int)eventSector > endSec) {
                break;
            }
            if (events[i].kind == kEditSequenceEventTap) {
                SequenceEvent *dest = &copyEvents[written];
                dest->kind = kEditSequenceEventTap;
                dest->value = events[i].value;
                copyEvents[numCopyEvent].sector = eventSector - (unsigned int)startSec;
                written = ++numCopyEvent;
            }
        }
    }
    copyEvents[written].kind = kEditSequenceEventEnd;
    return (int)written != 0;
}

- (void)exeAreaDelete:(int)startSec endSec:(int)endSec {
    int index = [self searchSectorIndex:startSec];
    NSMutableArray *history = [[NSMutableArray alloc] init];
    if (index < kEditSequenceMaxEvents) {
        int runStart = -1;
        while (index < kEditSequenceMaxEvents) {
            // This deletion block is emitted twice in the binary, once when the scan runs past the
            // range and once when it hits a non-note event inside an open run; both are reproduced.
            if ((int)events[index].sector > endSec) {
                if (runStart != -1) {
                    const int span = index - runStart;
                    if (span != 0 && runStart <= index) {
                        [self addHistoryParts:history
                                        index:runStart
                                       sector:(int)events[runStart].sector
                                         type:1
                                        value:(int)events[runStart].value];
                        if (runStart + 1 != index) {
                            for (int i = runStart; i < index - 1; ++i) {
                                [self addHistoryParts:history
                                                index:runStart
                                               sector:(int)events[i + 1].sector
                                                 type:1
                                                value:(int)events[i + 1].value];
                            }
                        }
                    }
                    [self eventShift:index destIndex:runStart];
                    numEvent -= (unsigned int)span;
                    notesNum -= (unsigned int)span;
                }
                break;
            }
            int nextRunStart;
            if (events[index].kind == kEditSequenceEventTap) {
                nextRunStart = (runStart != -1) ? runStart : index;
            } else if (runStart == -1) {
                nextRunStart = -1;
            } else {
                const int span = index - runStart;
                if (span != 0 && runStart <= index) {
                    [self addHistoryParts:history
                                    index:runStart
                                   sector:(int)events[runStart].sector
                                     type:1
                                    value:(int)events[runStart].value];
                    if (runStart + 1 != index) {
                        for (int i = runStart; i < index - 1; ++i) {
                            [self addHistoryParts:history
                                            index:runStart
                                           sector:(int)events[i + 1].sector
                                             type:1
                                            value:(int)events[i + 1].value];
                        }
                    }
                }
                [self eventShift:index destIndex:runStart];
                numEvent -= (unsigned int)span;
                notesNum -= (unsigned int)span;
                index = runStart;
                nextRunStart = -1;
            }
            runStart = nextRunStart;
            ++index;
        }
    }
    if (history.count != 0) {
        [self addHistory:history.reverseObjectEnumerator.allObjects];
    }
    [self refreshEditMusicBar];
    [self refreshMusicBar];
}

- (int)exeAreaPaste:(int)startSec {
    int copyCount = (int)numCopyEvent;
    if (copyCount == 0) {
        return 0;
    }
    if ((unsigned int)((int)numEvent + copyCount) > kEditSequenceMaxEvents - 1) {
        return 1;
    }
    if ((unsigned int)((int)notesNum + copyCount) > kEditSequenceMaxNotes) {
        return 1;
    }
    if ((int)(endSector - kEditSequenceEndSectorMargin) <
        (int)copyEvents[copyCount - 1].sector + startSec) {
        return 2;
    }
    int destIndex = [self searchSectorIndex:startSec];
    NSMutableArray *history = [[NSMutableArray alloc] init];
    if (destIndex < kEditSequenceMaxEvents) {
        unsigned int copyIndex = 0;
        while (copyIndex < numCopyEvent && destIndex < kEditSequenceMaxEvents) {
            int inner = (int)copyIndex;
            if (inner < kEditSequenceMaxEvents) {
                copyIndex = (unsigned int)inner;
                while (YES) {
                    const unsigned int pasteSector = copyEvents[copyIndex].sector + startSec;
                    if (endSector <= pasteSector) {
                        break;
                    }
                    if (events[destIndex].sector <= pasteSector || numCopyEvent <= copyIndex) {
                        break;
                    }
                    if (![self checkConflictBySector:(int)pasteSector
                                                 btn:copyEvents[copyIndex].value
                                                area:kEditSequenceSnapConflictSector
                                           sameCheck:YES]) {
                        [self eventShift:destIndex destIndex:destIndex + 1];
                        SequenceEvent *dest = &events[destIndex];
                        dest->kind = copyEvents[copyIndex].kind;
                        const unsigned int value = copyEvents[copyIndex].value;
                        dest->sector = pasteSector;
                        dest->value = value;
                        [self addHistoryParts:history
                                        index:destIndex
                                       sector:(int)pasteSector
                                         type:0
                                        value:(int)value];
                        ++numEvent;
                        ++notesNum;
                    }
                    ++copyIndex;
                    if ((long)copyIndex > kEditSequenceMaxEvents - 1) {
                        goto next;
                    }
                }
                copyIndex = numCopyEvent;
            }
        next:
            ++destIndex;
        }
    }
    if (history.count != 0) {
        [self addHistory:history];
    }
    [self refreshEditMusicBar];
    [self refreshMusicBar];
    [self createConflictTable];
    return 0;
}

#pragma mark - Counts and markers

- (unsigned int)getTemplateNoteNum:(int)slot {
    return templateNotesNum[kEditSequenceTemplateSlotMap[slot]];
}

- (unsigned int)getNoteNum {
    return notesNum;
}

- (unsigned int)getEventNum {
    return numEvent;
}

- (unsigned int)getFirstMarker {
    if (numEvent == 0) {
        return 0;
    }
    unsigned int marker = 0;
    int firstSector = -1;
    for (unsigned int i = 0; i < numEvent; ++i) {
        if (events[i].kind == kEditSequenceEventTap) {
            if (firstSector >= 0 && firstSector != (int)events[i].sector) {
                return marker;
            }
            firstSector = (int)events[i].sector;
            marker += (1 << (events[i].value & 0x1f));
        }
    }
    return marker;
}

- (unsigned int)getFirstSector {
    if (numEvent == 0) {
        return 0;
    }
    for (unsigned int i = 0; i < numEvent; ++i) {
        if (events[i].kind == kEditSequenceEventTap) {
            return events[i].sector;
        }
    }
    return 0;
}

#pragma mark - Debug and event shifting

- (void)printInfoParts:(NSString *)info {
    // The binary body is empty; the argument is accepted and discarded.
    (void)info;
}

- (void)eventShift:(int)srcIndex destIndex:(int)destIndex {
    [self printInfoParts:kEditSequenceInfoBefore];
    memmove(&events[destIndex],
            &events[srcIndex],
            ((size_t)((int)numEvent - srcIndex)) * sizeof(SequenceEvent));
    [self printInfoParts:kEditSequenceInfoAfter];
}

#pragma mark - Scalar accessors

- (double)currentTime {
    return _currentTime;
}

- (unsigned int)currentSector {
    return _currentSector;
}

- (unsigned int)currentIndex {
    return _currentIndex;
}

- (unsigned short)firstMarker {
    return _firstMarker;
}

- (unsigned int)firstMarkerSector {
    return _firstMarkerSector;
}

- (BOOL)enableUndo {
    return _enableUndo;
}

- (BOOL)enableRedo {
    return _enableRedo;
}

#pragma mark - Lifecycle

- (void)dealloc {
    if (events != nullptr) {
        free(events);
    }
    if (copyEvents != nullptr) {
        free(copyEvents);
    }
    for (int slot = 0; slot < kEditSequenceTemplateSlotCount; ++slot) {
        if (eventsTemplate[slot] != nullptr) {
            free(eventsTemplate[slot]);
            eventsTemplate[slot] = nullptr;
        }
    }
}

@end
