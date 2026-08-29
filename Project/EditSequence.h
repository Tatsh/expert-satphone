/**
 * @file
 * @brief The chart-editor data model.
 *
 * Reconstructed from Ghidra program Jubeat (class EditSequence, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject , taken from the @c [NSObject init] chain-up in
 * @c -initWithData:sequenceData: at 0x21725c. An @c EditSequence is the editor sibling of the
 * play-time @c Sequence : it holds the edit events, four template slots (an empty structural
 * template plus the basic, advanced, and extreme difficulty templates loaded from a downloaded
 * pack), a music-bar note-density table and a conflict table, an undo/redo history, and note
 * add/delete plus area copy/paste/delete operations. It mirrors the play engine's beat (haku) and
 * measure phase trackers, its marker state, and its per-panel judgement ring so the edit renderer
 * can share the same drawing code.
 *
 * The class carries no embedded @c __FILE__ path and no C++ RTTI, so the file basename is the
 * runtime class name and this file lives at the @c Project/ root, beside @c Sequence . The note
 * event record is the same 20-byte @c SequenceEvent that @c Sequence defines, so this class reuses
 * it rather than redeclaring a parallel type.
 */

#import <Foundation/Foundation.h>

#import "MainGameRenderer.h"
#import "Sequence.h"

@class KUnzip;

NS_ASSUME_NONNULL_BEGIN

/** @brief The playfield panel count. */
enum {
    kEditSequencePanelCount = 16 /*!< The number of playfield panels (a 4x4 grid), sizing the
                                      per-panel judgement arrays. */
};

/** @brief The template slot count. */
enum {
    kEditSequenceTemplateSlotCount = 4 /*!< The number of template slots: an empty structural
                                            template plus three difficulty templates. */
};

/** @brief The music-bar segment count. */
enum {
    kEditSequenceMusicBarSegmentCount = 120 /*!< The number of segments in the music bar; each note
                                                 maps to one via its sector. */
};

/** @brief The packed music-bar and conflict-bar bitmap length. */
enum {
    kEditSequenceMusicBarByteCount = 60 /*!< The length of the packed music-bar and conflict-bar
                                             bitmaps, in bytes (two segments per byte). */
};

/** @brief The per-template raw music-bar buffer length. */
enum {
    kEditSequenceTemplateMusicBarByteCount = 120 /*!< The per-template raw music-bar buffer length,
                                                      in bytes (one segment per byte). */
};

/**
 * @brief The chart-editor data model.
 */
@interface EditSequence : NSObject {
@protected
    /// The four difficulty/structure templates, each a malloc'd 2000-entry event array.
    SequenceEvent *eventsTemplate[kEditSequenceTemplateSlotCount];
    /// The event count of each template slot.
    unsigned int templateNumEvent[kEditSequenceTemplateSlotCount];
    /// The end sector of each template slot.
    unsigned int templateEndSector[kEditSequenceTemplateSlotCount];
    /// The note count of each template slot.
    unsigned int templateNotesNum[kEditSequenceTemplateSlotCount];
    /// The raw per-segment note-density music bar of each template slot.
    char templateMusicBar[kEditSequenceTemplateSlotCount][kEditSequenceTemplateMusicBarByteCount];
    SequenceEvent *events;          /*!< The malloc'd working event array (2000 entries). */
    SequenceEvent *copyEvents;      /*!< The malloc'd area copy/paste clipboard (2000 entries). */
    unsigned int numEvent;          /*!< The number of events in @c events . */
    unsigned int numPlayEvent;      /*!< The scoring-note count parsed from the chart header. */
    unsigned int endSector;         /*!< The chart's final sector. */
    unsigned int notesNum;          /*!< The number of note events in @c events . */
    unsigned int numCopyEvent;      /*!< The number of events in @c copyEvents . */
    unsigned int judgedIndex;       /*!< The judgement cursor over @c events . */
    unsigned int currentTempo;      /*!< The tempo in effect at the play position. */
    unsigned int oldTempo;          /*!< The tempo in effect before the last change. */
    unsigned int lastHakuSector;    /*!< The sector of the last beat (haku) line. */
    unsigned int nextHakuSector;    /*!< The sector of the next beat (haku) line. */
    unsigned int lastMeasureSector; /*!< The sector of the last measure line. */
    unsigned int nextMeasureSector; /*!< The sector of the next measure line. */
    char musicBar[kEditSequenceMusicBarByteCount];       /*!< The packed note-density music bar. */
    int editMusicBar[kEditSequenceMusicBarSegmentCount]; /*!< Per-segment note-density counts. */
    char conflictTable[kEditSequenceMusicBarByteCount];  /*!< The packed conflict music bar. */
    char editConflictTable[kEditSequenceMusicBarSegmentCount]; /*!< Per-segment conflict flags. */
    short lastJudge[kEditSequencePanelCount]; /*!< The most recent grade shown per panel. */
    unsigned int
        lastJudgeSector[kEditSequencePanelCount]; /*!< The sector of that grade per panel. */
    ScoreData gameScore;         /*!< The live score summary, mirrored from the play engine. */
    NSMutableArray *editHistory; /*!< The undo/redo history of boxed edit-part records. */
    int currentHistory;          /*!< The cursor into @c editHistory ; -1 when empty. */
    int clapIndex;               /*!< The clap sound-effect scan cursor. */
    int backSector;              /*!< The play position of the previous @c -seekToTime: frame. */
    BOOL bClapSE;                /*!< Whether a clap sound effect should fire this frame. */
    BOOL _enableUndo;            /*!< Whether an undo is available. */
    BOOL _enableRedo;            /*!< Whether a redo is available. */
    unsigned short _firstMarker; /*!< The panel bitmask of the first marker. */
    unsigned int _currentSector; /*!< The current play position, in sectors. */
    unsigned int _currentIndex;  /*!< The seek cursor over @c events . */
    unsigned int _firstMarkerSector; /*!< The sector of the first marker. */
    double _currentTime;             /*!< The current play position, in seconds. */
}

/**
 * @brief Re-encodes the working event array into an array of boxed packed note words.
 * @return A mutable array of @c NSNumber packed words, always 2000 entries long.
 * @ghidraAddress 0x214654
 */
- (nullable NSMutableArray<NSNumber *> *)getEventData;

/**
 * @brief Copies a chart's raw music-bar bitmap out of an encoded sequence blob.
 * @param raw The 60-byte destination buffer.
 * @param data The encoded sequence blob; ignored unless longer than 96 bytes.
 * @ghidraAddress 0x214738
 */
+ (void)getMusicBarData:(char *)raw raw:(nullable NSData *)data;

/**
 * @brief Validates that a decoded sequence blob has a recognised header and a consistent length.
 * @param data The decoded sequence blob.
 * @return @c YES if the blob is a well-formed chart.
 * @ghidraAddress 0x21479c
 */
- (BOOL)checkEventsLegality:(nullable NSData *)data;

/**
 * @brief Parses a decoded sequence blob into one template slot.
 * @param data The decoded sequence blob.
 * @param slot The template slot (0 keeps only structural events; 1..3 are the difficulties).
 * @ghidraAddress 0x2148d8
 */
- (void)createEvents:(nullable NSData *)data tempSlot:(int)slot;

/**
 * @brief Rebuilds the per-segment note-density table @c editMusicBar from the working events.
 * @ghidraAddress 0x214d98
 */
- (void)refreshEditMusicBar;

/**
 * @brief Packs @c editMusicBar into the nibble-per-segment @c musicBar bitmap.
 * @ghidraAddress 0x214e44
 */
- (void)refreshMusicBar;

/**
 * @brief Packs @c editConflictTable into the nibble-per-segment @c conflictTable bitmap.
 * @ghidraAddress 0x214eb8
 */
- (void)refreshConflictTable;

/**
 * @brief Loads a template slot into the working event array and clears the history.
 * @param slot The template slot to load.
 * @ghidraAddress 0x214f24
 */
- (void)loadTemplate:(int)slot;

/**
 * @brief Rebuilds @c editConflictTable by testing every note event for a conflict.
 * @ghidraAddress 0x215070
 */
- (void)createConflictTable;

/**
 * @brief Returns whether the note event at an index is a note on a given button.
 * @param index The event index.
 * @param btn The panel index to match.
 * @return YES when the event is a note on that button, NO otherwise.
 * @ghidraAddress 0x215168
 */
- (BOOL)checkConflictEvent:(int)index btn:(unsigned int)btn;

/**
 * @brief Returns the index of the note nearest a sector on a given button, or -1.
 * @param sector The reference sector.
 * @param btn The panel index to match.
 * @return The nearest matching note's event index, or -1 when there is none.
 * @ghidraAddress 0x2151b4
 */
- (int)searchBtnNearSector:(int)sector btn:(int)btn;

/**
 * @brief Returns the event index nearest a sector.
 * @param sector The reference sector.
 * @return The nearest event's index.
 * @ghidraAddress 0x215244
 */
- (int)searchNearIndex:(int)sector;

/**
 * @brief Searches by index in one direction for a conflicting note within an area.
 * @param index The starting event index.
 * @param btn The panel index to match.
 * @param direction The search direction (@c 1 forwards, @c -1 backwards, @c 0 in place).
 * @param area The maximum sector distance that still counts as a conflict.
 * @param sameCheck Whether the reference index itself is excluded.
 * @return The conflicting event index, or -1.
 * @ghidraAddress 0x2152b4
 */
- (int)checkConflictByIndex:(int)index
                        btn:(unsigned int)btn
                        vec:(int)direction
                       area:(int)area
                  sameCheck:(BOOL)sameCheck;

/**
 * @brief Searches by sector in one direction for a conflicting note within an area.
 * @param sector The starting sector.
 * @param btn The panel index to match.
 * @param direction The search direction (@c 1 forwards, @c -1 backwards, @c 0 in place).
 * @param area The maximum sector distance that still counts as a conflict.
 * @param sameCheck Whether the reference sector's own note is excluded.
 * @return The conflicting event index, or -1.
 * @ghidraAddress 0x2155e4
 */
- (int)checkConflictBySector:(int)sector
                         btn:(unsigned int)btn
                         vec:(int)direction
                        area:(int)area
                   sameCheck:(BOOL)sameCheck;

/**
 * @brief Returns whether a sector conflicts with a note on a button, searching both directions.
 * @param sector The reference sector.
 * @param btn The panel index to match.
 * @param area The maximum sector distance that still counts as a conflict.
 * @param sameCheck Whether the reference sector's own note is excluded.
 * @return YES when a conflicting note is within the area, NO otherwise.
 * @ghidraAddress 0x215860
 */
- (BOOL)checkConflictBySector:(int)sector
                          btn:(unsigned int)btn
                         area:(int)area
                    sameCheck:(BOOL)sameCheck;

/**
 * @brief Returns whether an index conflicts with a note on a button, searching both directions.
 * @param index The reference event index.
 * @param btn The panel index to match.
 * @param area The maximum sector distance that still counts as a conflict.
 * @param sameCheck Whether the reference index itself is excluded.
 * @return YES when a conflicting note is within the area, NO otherwise.
 * @ghidraAddress 0x2158f8
 */
- (BOOL)checkConflictByIndex:(int)index
                         btn:(unsigned int)btn
                        area:(int)area
                   sameCheck:(BOOL)sameCheck;

/**
 * @brief Returns whether the note at an index conflicts with another note in the given direction.
 * @param index The event index whose button and area are tested.
 * @param direction The search direction.
 * @return YES when the note conflicts with another in that direction, NO otherwise.
 * @ghidraAddress 0x215988
 */
- (BOOL)checkConflictArea:(unsigned int)index vector:(int)direction;

/**
 * @brief Returns whether the note at the current index conflicts, on a button, in a direction.
 * @param btn The panel index to match.
 * @param direction The search direction.
 * @return YES when the note at the current index conflicts, NO otherwise.
 * @ghidraAddress 0x2159d4
 */
- (BOOL)checkConflict:(unsigned int)btn vector:(int)direction;

/**
 * @brief Returns whether adding a note on a button at the current sector would conflict.
 * @param btn The panel index to test.
 * @return YES when adding the note would conflict, NO otherwise.
 * @ghidraAddress 0x215a1c
 */
- (BOOL)checkKeyConflict:(int)btn;

/**
 * @brief Returns whether a run of notes on a button starting at the current index conflicts.
 * @param btn The panel index to match.
 * @param direction The scan direction.
 * @return YES when the run of notes conflicts, NO otherwise.
 * @ghidraAddress 0x215a8c
 */
- (BOOL)conflictKeyCheck:(unsigned int)btn vector:(int)direction;

/**
 * @brief Pushes an edit-part record onto the history, trimming and truncating as needed.
 * @param parts The array of boxed edit-part records for one undoable operation.
 * @ghidraAddress 0x215b94
 */
- (void)addHistory:(nullable NSArray *)parts;

/**
 * @brief Replays or reverses one history entry, rebuilding the music-bar and conflict tables.
 * @param undo @c YES to undo the current entry, @c NO to redo the next entry.
 * @return The history entry count at the time of the call.
 * @ghidraAddress 0x215ce8
 */
- (int)rollController:(BOOL)undo;

/**
 * @brief Whether a clap sound effect should fire on the current frame.
 * @ghidraAddress 0x2161ac
 */
@property(nonatomic, readonly) BOOL isClap;

/**
 * @brief Undoes the current history entry.
 * @return The history entry count.
 * @ghidraAddress 0x2161bc
 */
- (int)undoHistory;

/**
 * @brief Redoes the next history entry.
 * @return The history entry count.
 * @ghidraAddress 0x2161cc
 */
- (int)redoHistory;

/**
 * @brief Boxes one edit-part record (index, sector, type, value) and appends it to an array.
 * @param parts The destination array.
 * @param index The event index.
 * @param sector The event sector.
 * @param type The part type (@c 0 an add, @c 1 a delete).
 * @param value The event value (panel index).
 * @ghidraAddress 0x2161dc
 */
- (void)addHistoryParts:(nullable NSMutableArray *)parts
                  index:(int)index
                 sector:(int)sector
                   type:(int)type
                  value:(int)value;

/**
 * @brief Adds or toggles a note on a button, snapping to the nearest beat subdivision.
 * @param btn The panel index.
 * @param divide The beat subdivision (@c 15 disables snapping).
 * @param isSwitch Whether a conflicting note is deleted instead of ignored.
 * @return @c 0 on success, @c 1 when the event or note limit is reached, @c 2 when past the end.
 * @ghidraAddress 0x216380
 */
- (int)addNote:(unsigned int)btn divide:(int)divide isSwitch:(BOOL)isSwitch;

/**
 * @brief Adds a note at the current sector on a button, or deletes it when it already conflicts.
 * @param btn The panel index.
 * @return @c 0 always.
 * @ghidraAddress 0x2166c8
 */
- (int)addNote:(unsigned int)btn;

/**
 * @brief Deletes the note nearest the current position on a button.
 * @param btn The panel index.
 * @return @c YES if a note was deleted.
 * @ghidraAddress 0x216998
 */
- (BOOL)deleteNote:(unsigned int)btn;

/**
 * @brief Returns the beat-line rate nearest a fractional position, from the empty template.
 * @param rate The fractional position over the chart, in [0, 1].
 * @return The nearest beat-line rate.
 * @ghidraAddress 0x216c98
 */
- (float)getNearBeatRate:(float)rate;

/**
 * @brief Returns the sector nearest a sector on a subdivided beat grid.
 * @param sector The reference sector.
 * @param divide The beat subdivision (@c 15 returns the sector unchanged).
 * @return The nearest sector on the subdivided beat grid.
 * @ghidraAddress 0x216d14
 */
- (int)getNearDiveBeatSector:(int)sector divide:(int)divide;

/**
 * @brief Returns the fractional position nearest a fractional position on a subdivided beat grid.
 * @param rate The fractional position over the chart, in [0, 1].
 * @param divide The beat subdivision.
 * @return The nearest fractional position on the subdivided beat grid.
 * @ghidraAddress 0x216ee8
 */
- (float)getNearDivBeatRate:(float)rate divide:(int)divide;

/**
 * @brief Converts a sector to a fractional position over the chart.
 * @param sector The sector.
 * @return The fractional position over the chart, in [0, 1].
 * @ghidraAddress 0x216f40
 */
- (float)sector2rate:(int)sector;

/**
 * @brief Converts a fractional position over the chart to a sector.
 * @param rate The fractional position, in [0, 1].
 * @return The corresponding sector.
 * @ghidraAddress 0x216f5c
 */
- (unsigned int)rate2sector:(float)rate;

/**
 * @brief Returns the index of the beat line at or before a sector, from the empty template.
 * @param sector The reference sector.
 * @return The index of the beat line at or before the sector.
 * @ghidraAddress 0x216f78
 */
- (int)getFrontBeatSector:(int)sector;

/**
 * @brief Returns the sector of the first beat line after a sector, from the empty template.
 * @param sector The reference sector.
 * @return The sector of the first beat line after the reference sector.
 * @ghidraAddress 0x216fd4
 */
- (int)getBackBeatSector:(int)sector;

/**
 * @brief Decodes an array of boxed packed note words into the working event array.
 * @param table The array of @c NSNumber packed words.
 * @ghidraAddress 0x217028
 */
- (void)eventArrayDecode:(nullable NSArray<NSNumber *> *)table;

/**
 * @brief Loads a new chart into the working event array and rebuilds every derived table.
 * @param table The array of boxed packed note words.
 * @ghidraAddress 0x2171f0
 */
- (void)importSequenceData:(nullable NSArray<NSNumber *> *)table;

/**
 * @brief Initialises the editor from a downloaded pack archive and an optional edit-note table.
 * @param data The KUnzip archive holding the three difficulty sequence entries.
 * @param sequenceData The edit-note table to load, or @c nil to start from the empty template.
 * @return The initialised editor, or @c nil if any difficulty entry is malformed.
 * @ghidraAddress 0x21725c
 */
- (instancetype)initWithData:(nullable KUnzip *)data
                sequenceData:(nullable NSArray<NSNumber *> *)sequenceData;

/**
 * @brief Resets the play state and clears every recorded judgement.
 * @ghidraAddress 0x2175b0
 */
- (void)reset;

/**
 * @brief Advances the play position to a time, updating the tempo, measure, beat, and clap state.
 * @param time The new play time, in seconds.
 * @ghidraAddress 0x217754
 */
- (void)seekToTime:(double)time;

/**
 * @brief Fills a per-panel marker-animation state array for the current position.
 * @param state A 16-element destination array of packed marker states.
 * @ghidraAddress 0x2179a4
 */
- (void)getMarkerState:(int *)state;

/**
 * @brief Returns the packed note-density music bar.
 * @return The packed note-density music bar.
 * @ghidraAddress 0x217b64
 */
- (const char *)getMusicBar;

/**
 * @brief Returns the packed conflict music bar.
 * @return The packed conflict music bar.
 * @ghidraAddress 0x217b74
 */
- (const char *)getConflictBar;

/**
 * @brief Returns the working event array.
 * @return The working event array.
 * @ghidraAddress 0x217b84
 */
- (const SequenceEvent *)getSequenceEventTable;

/**
 * @brief Returns the area copy/paste clipboard event array.
 * @return The clipboard event array.
 * @ghidraAddress 0x217b94
 */
- (const SequenceEvent *)getSequencePasteTable;

/**
 * @brief Returns the chart's end sector.
 * @return The chart's end sector.
 * @ghidraAddress 0x217ba4
 */
- (unsigned int)getEndSector;

/**
 * @brief Returns the fixed conflict-detection window, in sectors.
 * @return The conflict-detection window, in sectors.
 * @ghidraAddress 0x217bb4
 */
- (unsigned int)getConflictSector;

/**
 * @brief Returns the sector of the measure two measures before the current position.
 * @return The rewind-target measure sector.
 * @ghidraAddress 0x217bbc
 */
- (int)getRewindMeasureSector;

/**
 * @brief The normalised phase within the current beat (haku) interval, in [0, 1].
 * @ghidraAddress 0x217c38
 */
@property(nonatomic, readonly) float hakuPhase;

/**
 * @brief The normalised phase within the current measure interval, in [0, 1].
 * @ghidraAddress 0x217c84
 */
@property(nonatomic, readonly) float measurePhase;

/**
 * @brief The normalised play position over the whole chart, in [0, 1].
 * @ghidraAddress 0x217cd0
 */
@property(nonatomic, readonly) float playPosition;

/**
 * @brief Returns the index of the first event at or after a sector, or -1 past a terminator.
 * @param sector The reference sector.
 * @return The index of the first event at or after the sector, or -1 past a terminator.
 * @ghidraAddress 0x217d08
 */
- (int)searchSectorIndex:(int)sector;

/**
 * @brief Copies the notes in a sector range into the clipboard.
 * @param startSec The inclusive start sector.
 * @param endSec The inclusive end sector.
 * @return @c YES if any note was copied.
 * @ghidraAddress 0x217d50
 */
- (BOOL)exeAreaCopy:(int)startSec endSec:(int)endSec;

/**
 * @brief Deletes the notes in a sector range, pushing the deletion onto the history.
 * @param startSec The inclusive start sector.
 * @param endSec The inclusive end sector.
 * @ghidraAddress 0x217e50
 */
- (void)exeAreaDelete:(int)startSec endSec:(int)endSec;

/**
 * @brief Pastes the clipboard notes starting at a sector, skipping conflicts.
 * @param startSec The paste-target start sector.
 * @return @c 0 on success, @c 1 when a limit is reached, @c 2 when it would run past the end.
 * @ghidraAddress 0x218168
 */
- (int)exeAreaPaste:(int)startSec;

/**
 * @brief Returns the note count of a template slot.
 * @param slot The template slot.
 * @return The template slot's note count.
 * @ghidraAddress 0x218484
 */
- (unsigned int)getTemplateNoteNum:(int)slot;

/**
 * @brief Returns the working note count.
 * @return The number of note events in the working array.
 * @ghidraAddress 0x2184a4
 */
- (unsigned int)getNoteNum;

/**
 * @brief Returns the working event count.
 * @return The number of events in the working array.
 * @ghidraAddress 0x2184b4
 */
- (unsigned int)getEventNum;

/**
 * @brief Returns the first-marker panel bitmask, computed from the leading same-sector notes.
 * @return The panel bitmask of the chart's first marker.
 * @ghidraAddress 0x2184c4
 */
- (unsigned int)getFirstMarker;

/**
 * @brief Returns the sector of the first note.
 * @return The first note's sector.
 * @ghidraAddress 0x21853c
 */
- (unsigned int)getFirstSector;

/**
 * @brief Prints debug information for an edit operation. The binary body is empty.
 * @param info The debug label.
 * @ghidraAddress 0x21864c
 */
- (void)printInfoParts:(nullable NSString *)info;

/**
 * @brief Moves a run of events from one index to another within @c events .
 * @param srcIndex The source index.
 * @param destIndex The destination index.
 * @ghidraAddress 0x218650
 */
- (void)eventShift:(int)srcIndex destIndex:(int)destIndex;

/**
 * @brief The current play position, in seconds.
 * @ghidraAddress 0x2186d4
 */
@property(nonatomic, readonly) double currentTime;

/**
 * @brief The current play position, in sectors.
 * @ghidraAddress 0x2186e4
 */
@property(nonatomic, readonly) unsigned int currentSector;

/**
 * @brief The seek cursor over the working events.
 * @ghidraAddress 0x2186f4
 */
@property(nonatomic, readonly) unsigned int currentIndex;

/**
 * @brief The panel bitmask of the first marker.
 * @ghidraAddress 0x218704
 */
@property(nonatomic, readonly) unsigned short firstMarker;

/**
 * @brief The sector of the first marker.
 * @ghidraAddress 0x218714
 */
@property(nonatomic, readonly) unsigned int firstMarkerSector;

/**
 * @brief Whether an undo is available.
 * @ghidraAddress 0x218724
 */
@property(nonatomic, readonly) BOOL enableUndo;

/**
 * @brief Whether a redo is available.
 * @ghidraAddress 0x218734
 */
@property(nonatomic, readonly) BOOL enableRedo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
