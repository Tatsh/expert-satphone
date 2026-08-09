/** @file
 * The core gameplay judgement engine for a single play session.
 *
 * Reconstructed from Ghidra program Jubeat (class Sequence, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject, taken from the @c [NSObject init] chain-up in @c -initWithData: at
 * 0x1abe24. A @c Sequence loads a chart's note events, advances the play position over time
 * (@c -seekToTime: ), judges button presses into timing grades (@c -judge:btnPress: ), and tracks
 * the combo, score, tension, the beat (haku) and measure phases, and the hold markers. It owns a
 * malloc'd C array of note events plus two @c short replay-judge side tables, and exposes its live
 * score summary as the shared @c ScoreData that @c MainGameRenderer snapshots for replay.
 *
 * The class carries no embedded @c __FILE__ path and no C++ RTTI, so the file basename is the
 * runtime class name and this file lives at the @c Project/ root.
 */

#import <Foundation/Foundation.h>

#import "MainGameRenderer.h"

@class KUnzip;

NS_ASSUME_NONNULL_BEGIN

/// The number of playfield panels (a 4x4 grid), sizing the per-panel judgement arrays.
enum { kSequencePanelCount = 16 };

/// The number of segments in the result-screen music bar; each note maps to one via its sector.
enum { kSequenceMusicBarSegmentCount = 120 };

/// The length of the raw music-bar bitmap the chart carries, in bytes.
enum { kSequenceMusicBarByteCount = 60 };

/**
 * @brief A judgement grade for a single note hit.
 *
 * Recovered from @c -addJudge: at 0x1ad138, whose @c switch dispatches on these exact values, and
 * from the timing-window classifier inlined into @c -judge:btnPress: . A @c Poor grade resets the
 * combo and costs tension exactly as a @c Miss does; the two differ only in which tally they bump.
 * The field is a @c short throughout the engine, so the enumeration is backed by @c short .
 */
typedef NS_ENUM(short, SequenceJudgeGrade) {
    SequenceJudgeGradeNone = 0,    /*!< No judgement (too early, or not yet judged). */
    SequenceJudgeGradeMiss = 1,    /*!< A miss; resets the combo and costs tension. */
    SequenceJudgeGradePoor = 2,    /*!< A poor; resets the combo and costs tension like a miss. */
    SequenceJudgeGradeGood = 3,    /*!< A good; extends the combo. */
    SequenceJudgeGradeGreat = 4,   /*!< A great; extends the combo. */
    SequenceJudgeGradePerfect = 5, /*!< A perfect; extends the combo. */
};

/**
 * @brief A score rank tier, returned by @c +rankOfPoint: and @c -rank .
 *
 * Recovered from the ascending point thresholds in @c +rankOfPoint: at 0x1aba80; the field is a
 * @c short return, so the enumeration is backed by @c short .
 */
typedef NS_ENUM(short, SequenceRank) {
    SequenceRankTier0 = 0, /*!< Below 500000 points. */
    SequenceRankTier1 = 1, /*!< 500000 to 699999 points. */
    SequenceRankTier2 = 2, /*!< 700000 to 799999 points. */
    SequenceRankTier3 = 3, /*!< 800000 to 849999 points. */
    SequenceRankTier4 = 4, /*!< 850000 to 899999 points. */
    SequenceRankTier5 = 5, /*!< 900000 to 949999 points. */
    SequenceRankTier6 = 6, /*!< 950000 to 979999 points. */
    SequenceRankTier7 = 7, /*!< 980000 to 999999 points. */
    SequenceRankTier8 = 8, /*!< A perfect 1000000 points. */
};

/**
 * @brief One note event of a chart.
 *
 * The metadata types the malloc'd @c events array element as @c {?=ssIIsI} : twenty bytes (padded
 * from eighteen), recovered from @c -initWithData: at 0x1abe24, @c -judge:btnPress: at 0x1ad360,
 * and @c -seekToTime: at 0x1acaac. The chart packs each event as two 32-bit words: the first holds
 * @c kind in its low byte and @c sector in its upper twenty-four bits, the second is @c value . The
 * two grade fields are distinct: a tap or a hold's release writes @c judge , while a hold's head
 * press writes @c holdHeadJudge .
 */
typedef struct {
    short kind;          // +0x00 The event kind (1 tap, 3 measure, 4 haku, 5 tempo, 6 hold).
    short judge;         // +0x02 The tap grade, or a hold's release grade.
    unsigned int sector; // +0x04 The event's timing position, in sectors.
    unsigned int value;  // +0x08 Panel index in the low four bits, plus packed hold data.
    short holdHeadJudge; // +0x0c A hold's head-press grade.
    unsigned int holdReleaseSector; // +0x10 The sector at which a hold was released.
} SequenceEvent;

/**
 * @brief The core gameplay judgement engine for a single play session.
 */
@interface Sequence : NSObject {
@protected
    SequenceEvent *events;                     /*!< The malloc'd chart-event array. */
    unsigned int numEvent;                     /*!< The number of events in @c events . */
    unsigned int numPlayEvent;                 /*!< The number of judged (scoring) notes. */
    unsigned int endSector;                    /*!< The chart's final sector. */
    char musicBar[kSequenceMusicBarByteCount]; /*!< The raw music-bar bitmap from the chart. */
    unsigned int currentIndex;                 /*!< The seek cursor over @c events . */
    unsigned int currentHoldIndex;             /*!< The seek cursor over hold events. */
    unsigned int judgedIndex;                  /*!< The judgement cursor over @c events . */
    unsigned int currentTempo;                 /*!< The tempo in effect at the play position. */
    unsigned int oldTempo;                     /*!< The tempo in effect before the last change. */
    unsigned int lastHakuSector;               /*!< The sector of the last beat (haku) line. */
    unsigned int nextHakuSector;               /*!< The sector of the next beat (haku) line. */
    unsigned int lastMeasureSector;            /*!< The sector of the last measure line. */
    unsigned int nextMeasureSector;            /*!< The sector of the next measure line. */
    short lastJudge[kSequencePanelCount];      /*!< The most recent grade shown per panel. */
    unsigned int lastJudgeSector[kSequencePanelCount]; /*!< The sector of that grade per panel. */
    ScoreData gameScore;                               /*!< The live score summary. */
    unsigned int replaceTable[kSequencePanelCount];    /*!< The panel-remap table (random mode). */
    BOOL isPerfectMode;              /*!< Whether perfect-mode judging is in effect. */
    NSArray *playEventTable;         /*!< Tap events, as boxed [grade, panel] pairs. */
    NSArray *holdEventTable;         /*!< Hold events, as boxed [grade, value] pairs. */
    short *replayJudgeTable;         /*!< The recorded per-note tap grades, for replay. */
    short *replayTmpJudgeTable;      /*!< The recorded per-note hold grades, for replay. */
    unsigned short _firstMarker;     /*!< The panel bitmask of the first marker. */
    unsigned int _currentSector;     /*!< The current play position, in sectors. */
    unsigned int _firstMarkerSector; /*!< The sector of the first marker. */
    double _currentTime;             /*!< The current play position, in seconds. */
}

/**
 * @brief Copies the chart's raw music-bar bitmap out of an encoded sequence blob.
 * @param raw The 60-byte destination buffer.
 * @param data The encoded sequence blob; ignored unless longer than 96 bytes.
 * @ghidraAddress 0x1ab5a4
 */
+ (void)getMusicBarData:(char *)raw raw:(nullable NSData *)data;

/**
 * @brief Returns a bitmask of which difficulties in a downloaded pack contain a hold marker.
 * @param data The KUnzip archive holding the three difficulty sequence entries.
 * @return Bit 0 basic, bit 1 advanced, and bit 2 extreme, set where that difficulty has a hold.
 * @ghidraAddress 0x1ab608
 */
+ (unsigned int)checkExistHoldMarkerFlag:(nullable KUnzip *)data;

/**
 * @brief Returns whether a single decoded sequence blob contains any hold marker.
 * @param data The decoded sequence blob.
 * @return @c YES if any event is a hold event.
 * @ghidraAddress 0x1ab92c
 */
+ (BOOL)checkExistHoldMarker:(nullable NSData *)data;

/**
 * @brief Maps a point total to its score rank tier.
 * @param point The total points.
 * @return The rank tier.
 * @ghidraAddress 0x1aba80
 */
+ (SequenceRank)rankOfPoint:(unsigned int)point;

/**
 * @brief Initialises the engine from a packed binary sequence blob.
 * @param data The encoded sequence blob, whose header is one of the @c "IJBQ" / @c "IJSQ" magics.
 * @return The initialised engine, or @c nil if the blob is missing or malformed.
 * @ghidraAddress 0x1abe24
 */
- (nullable instancetype)initWithData:(nullable NSData *)data;

/**
 * @brief Initialises the engine from an editor's custom chart dictionary and note table.
 * @param data The chart-header dictionary (event count, note count, end sector, first marker).
 * @param tableData The array of boxed packed note words.
 * @return The initialised engine, or @c nil.
 * @ghidraAddress 0x1ac3a0
 */
- (nullable instancetype)initWithCustomData:(nullable NSDictionary *)data
                                  tableData:(nullable NSArray *)tableData;

/**
 * @brief Resets the play state for a replay, preserving the recorded replay-judge tables.
 * @ghidraAddress 0x1ac728
 */
- (void)replay;

/**
 * @brief Resets the play state and clears every recorded judgement for a fresh play.
 * @ghidraAddress 0x1ac8fc
 */
- (void)reset;

/**
 * @brief Advances the play position to a time, updating the tempo, measure, and beat phases.
 * @param time The new play time, in seconds; times before the current one are ignored.
 * @ghidraAddress 0x1acaac
 */
- (void)seekToTime:(double)time;

/**
 * @brief Fills a per-panel marker-animation state array for the current position.
 * @param state A 16-element destination array of packed marker states.
 * @ghidraAddress 0x1accc4
 */
- (void)getMarkerState:(int *)state;

/**
 * @brief Fills a per-panel hold-marker state array for the current position.
 * @param state A 16-element destination array of @c MainGameHoldState .
 * @ghidraAddress 0x1ace9c
 */
- (void)getHoldMarkerState:(MainGameHoldState *)state;

/**
 * @brief Returns the live score summary.
 * @return A pointer to the internal score data; not owned by the caller.
 * @ghidraAddress 0x1acfd0
 */
- (const ScoreData *)getScore;

/**
 * @brief Returns whether every scoring note has been judged at least good (a full combo).
 * @ghidraAddress 0x1acfe0
 */
- (BOOL)isFullcombo;

/**
 * @brief Returns whether every scoring note was judged perfect (an excellent).
 * @ghidraAddress 0x1ad008
 */
- (BOOL)isExcellent;

/**
 * @brief Returns the score rank tier for the current total points.
 * @ghidraAddress 0x1ad030
 */
- (SequenceRank)rank;

/**
 * @brief Returns the chart's raw music-bar bitmap.
 * @return A pointer to the internal 60-byte bitmap; not owned by the caller.
 * @ghidraAddress 0x1ad058
 */
- (const char *)getMusicBar;

/**
 * @brief Returns the tap events as boxed @c [grade, panel] number pairs.
 * @ghidraAddress 0x1adbb8
 */
- (nullable NSArray *)getPlayEvents;

/**
 * @brief Returns the hold events as boxed @c [grade, value] number pairs.
 * @ghidraAddress 0x1adbc8
 */
- (nullable NSArray *)getHoldEvents;

/**
 * @brief Judges the current button state against the notes around the play position.
 * @param btnPress The bitmask of buttons newly pressed this frame.
 * @param btnDown The bitmask of buttons currently held down.
 * @ghidraAddress 0x1ad360
 */
- (void)judge:(int)btnPress btnPress:(int)btnDown;

/**
 * @brief The normalised phase within the current beat (haku) interval, in [0, 1].
 * @ghidraAddress 0x1ad068
 */
@property(nonatomic, readonly) float hakuPhase;

/**
 * @brief The normalised phase within the current measure interval, in [0, 1].
 * @ghidraAddress 0x1ad0b4
 */
@property(nonatomic, readonly) float measurePhase;

/**
 * @brief The normalised play position over the whole chart, in [0, 1].
 * @ghidraAddress 0x1ad100
 */
@property(nonatomic, readonly) float playPosition;

/**
 * @brief The current play position, in seconds.
 * @ghidraAddress 0x1adbd8
 */
@property(nonatomic, readonly) double currentTime;

/**
 * @brief The current play position, in sectors.
 * @ghidraAddress 0x1adbe8
 */
@property(nonatomic, readonly) unsigned int currentSector;

/**
 * @brief The panel bitmask of the first marker.
 * @ghidraAddress 0x1adbf8
 */
@property(nonatomic, readonly) unsigned short firstMarker;

/**
 * @brief The sector of the first marker.
 * @ghidraAddress 0x1adc08
 */
@property(nonatomic, readonly) unsigned int firstMarkerSector;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
