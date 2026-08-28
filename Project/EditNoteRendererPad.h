/** @file
 * The iPad edit-mode note renderer: the concrete @c EditNoteRenderer subclass that draws the
 * chart editor on the pad idiom.
 *
 * Reconstructed from Ghidra program Jubeat (class EditNoteRendererPad, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * @c EditNoteRendererPad fills in the drawing, layout, and coordinate-conversion override points
 * that @c EditNoteRenderer leaves empty: it draws the editing grid, note chips, measure lines, the
 * area selection, the timeline/music bar, the on-screen buttons, and the tune info, and converts
 * between screen dots, sectors, and positions. Its layout constants are the pad values; the phone
 * sibling is @c EditNoteRendererPhone . Every drawing method batches quads into the two atlas
 * textures (@c texFront and @c texChip ) and the @c texDebugFont glyph sheet, which the top-level
 * @c -draw flushes with @c -commitDraw .
 */

#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "EditNoteRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@class Texture2D;

/**
 * @brief The kind of one edit-sequence event record.
 */
typedef NS_CLOSED_ENUM(short, EditSequenceEventType) {
    EditSequenceEventTypeEnd = 0,     /*!< The table terminator. */
    EditSequenceEventTypeNote = 1,    /*!< A note chip. */
    EditSequenceEventTypeMeasure = 2, /*!< A measure boundary line. */
    EditSequenceEventTypeBpm = 3,     /*!< A tempo (bpm) change, carrying a measure number. */
    EditSequenceEventTypeBar = 4,     /*!< A bar line subdivided by the measure division. */
};

/**
 * @brief One 20-byte event record of an edit sequence's event table.
 *
 * The record's layout is recovered from the edit renderer's traversal (a stride of @c 0x14 bytes);
 * the type is at @c +0x0 , a bpm measure number at @c +0x2 , the dot position at @c +0x4 , the note
 * key index at @c +0x8 , and a bar's end position at @c +0xc . It is the same 20-byte record
 * @c EditSequence stores as a @c SequenceEvent, viewed through the edit renderer's field names, so
 * it carries a trailing reserved word at @c +0x10 to keep the stride at 20 bytes. Its true owner is
 * @c EditSequence .
 */
typedef struct EditSequenceEvent {
    EditSequenceEventType type; /*!< The event kind. */                          // +0x00
    short measure; /*!< The measure number a tempo event names. */               // +0x02
    unsigned int position; /*!< The event's dot position. */                     // +0x04
    int keyIndex; /*!< The 0..15 panel index of a note. */                       // +0x08
    int endPosition; /*!< A bar's end dot position. */                           // +0x0c
    unsigned int reserved; /*!< Unread; present so the stride stays 20 bytes. */ // +0x10
} EditSequenceEvent;

/**
 * @brief The pad edit-mode note renderer.
 */
@interface EditNoteRendererPad : EditNoteRenderer {
@protected
    unsigned int frame; /*!< The frames elapsed in the current state. */               // +0x60
    unsigned int subStateChangeFrame; /*!< The frame the sub-state last changed on. */ // +0x64
    unsigned int startMarkFrame; /*!< The frame the start marker began animating. */   // +0x68
    unsigned int effSlot; /*!< The active effect slot. */                              // +0x74
    float lastHakuPhase; /*!< The beat (haku) phase as of the last frame. */           // +0x6c
    float bounceEnergy; /*!< The residual bounce animation energy. */                  // +0x70
    float baseAlpha; /*!< The overall draw opacity. */                                 // +0x78
    float modeCnt; /*!< The display-mode cross-fade counter, 0..10. */                 // +0x7c
    float dotBySec; /*!< Dots per sector: the grid zoom factor. */                     // +0x94
    float baseScale; /*!< The saved base zoom, restored on pinch end. */               // +0x98
    float pinchScaleBak; /*!< The zoom saved when a pinch gesture began. */            // +0x9c
    int conflictDot; /*!< The conflict marker position, in dots. */                    // +0x80
    int clapSector; /*!< The sector the metronome last clapped on. */                  // +0x90
    NSData *clapSe; /*!< The metronome clap sound-effect data. */                      // +0x88
}

#pragma mark - Lifecycle

/**
 * @brief Initialises the pad renderer: opaque, display mode 0, clap enabled, and the grid zoom,
 *        base zoom, and pinch backup all set to 1.
 * @return The initialised renderer, or @c nil.
 * @ghidraAddress 0x20b214
 */
- (instancetype)init;

/**
 * @brief Deletes the atlas textures, then chains to the superclass deallocation.
 * @ghidraAddress 0x20e8a8
 */
- (void)dealloc;

#pragma mark - Textures

/**
 * @brief Loads the front and chip atlases, the debug-font sheet, and the clap sound effect.
 *
 * Builds the @c texFront and @c texChip atlases from their sprite-rect plists, then blits the
 * decrypted marker, hold, key, and background sub-images into them; clamps the configuration's
 * difficulty to 2 and level to 10; and short-circuits when the marker, difficulty, level, and tune
 * of @p conf already match the loaded configuration. The selector spelling @c loadTexure: (a
 * missing "t") is the binary's own.
 * @param conf The edit renderer configuration.
 * @param artwork The jacket artwork image.
 * @param index An additional texture image.
 * @ghidraAddress 0x20b2b4
 */
- (void)loadTexure:(nullable EditRendererConf *)conf
           artwork:(nullable UIImage *)artwork
             index:(nullable UIImage *)index;

/**
 * @brief Releases the debug-font, front, and chip atlas textures.
 * @ghidraAddress 0x20bd90
 */
- (void)releaseTexture;

#pragma mark - Play lifecycle

/**
 * @brief Resets per-state animation counters and, entering state 2, lazily loads the "go" cue; on
 *        state 5 starts the result BGM.
 * @param state The high-level render state.
 * @ghidraAddress 0x20bde0
 */
- (void)setState:(unsigned int)state;

/**
 * @brief Begins playback: moves to state 3 and clears the "go" cue player.
 * @ghidraAddress 0x20c0d8
 */
- (void)startPlay;

/**
 * @brief Ends the result screen: in state 5 sets the finished sub-state.
 * @ghidraAddress 0x20c114
 */
- (void)endResult;

/**
 * @brief Snaps the metronome clap sector to the current cursor sector.
 * @ghidraAddress 0x20c160
 */
- (void)resetCurrentTime;

/**
 * @brief Sets the decibel scale, updating the grid zoom and conflict marker.
 * @param dbs The decibel scale; the grid zoom is @c baseScale/dbs clamped to 0.2..1.0.
 * @ghidraAddress 0x20e428
 */
- (void)setDbs:(float)dbs;

/**
 * @brief Saves the current grid zoom as the base zoom.
 * @ghidraAddress 0x20e4c0
 */
- (void)saveBaseScale;

#pragma mark - Drawing

/**
 * @brief Draws one frame, dispatching on the render state and flushing both atlases.
 * @ghidraAddress 0x20e4dc
 */
- (void)draw;

/**
 * @brief Draws a clipped sub-rectangle of a sprite: blits only the part of sprite @p clip drawn at
 *        @p drawPosition that lies inside @p drawArea , at @c baseAlpha times @p alpha .
 * @param clip The sprite index.
 * @param drawPosition The top-left corner to draw at.
 * @param drawArea The clip rectangle the sprite is trimmed to.
 * @param alpha The opacity multiplier.
 * @ghidraAddress 0x20c194
 */
- (void)drawClip:(int)clip
    drawPosition:(CGPoint)drawPosition
        drawArea:(CGRect)drawArea
           alpha:(float)alpha;

/**
 * @brief Draws debug text glyph-by-glyph from the debug-font sheet, then flushes it.
 * @param text The C string to draw.
 * @param pos The top-left position to draw it at.
 * @param alpha The opacity, multiplied by @c baseAlpha .
 * @ghidraAddress 0x20e728
 */
- (void)drawDebugText:(nullable const char *)text pos:(CGPoint)pos alpha:(float)alpha;

#pragma mark - Layout

/**
 * @brief The rectangle of the edit timeline scrubber.
 * @return The timeline rectangle, @c {84, 208, 600, 43} .
 * @ghidraAddress 0x20e8f8
 */
- (CGRect)getTimeLineRect;

/**
 * @brief The rectangle of the area-selection start handle.
 * @return The selection-start rectangle.
 * @ghidraAddress 0x20cba8
 */
- (CGRect)getAreaSelectStart;

/**
 * @brief The rectangle of the area-selection end handle.
 * @return The selection-end rectangle.
 * @ghidraAddress 0x20cc28
 */
- (CGRect)getAreaSelectEnd;

/**
 * @brief The vertical offset of the button area. This override returns 0.
 * @return The button-area offset.
 * @ghidraAddress 0x20e418
 */
- (double)buttonAreaOffset;

#pragma mark - Coordinate conversion

/**
 * @brief Converts a dot count to a sector count: @c dot * dotBySec .
 * @param dot The dot count.
 * @return The sector count.
 * @ghidraAddress 0x20caec
 */
- (int)dot2sector:(int)dot;

/**
 * @brief Converts a horizontal position to a sector: @c currentSector + (pos - 100) * dotBySec .
 * @param pos The position, in points.
 * @return The sector.
 * @ghidraAddress 0x20cb08
 */
- (int)pos2sector:(int)pos;

/**
 * @brief Converts a sector to a horizontal position: @c (sector - currentSector) / dotBySec + 100 .
 * @param sector The sector.
 * @return The position, in points.
 * @ghidraAddress 0x20cb54
 */
- (int)sector2pos:(int)sector;

#pragma mark - Field rendering

/**
 * @brief Draws the beat-pulsing background layers and the four side rails.
 * @ghidraAddress 0x20c550
 */
- (void)renderBG;

/**
 * @brief Draws the shutter overlay. This override is empty.
 * @param open Whether the shutter is open.
 * @ghidraAddress 0x20c810
 */
- (void)renderShutter:(BOOL)open;

/**
 * @brief Draws the per-panel markers of the 4x4 grid and their conflict lights.
 * @ghidraAddress 0x20c378
 */
- (void)renderMarker;

/**
 * @brief Draws the timeline scrubber: the bar, its 120 note markers, and the play head.
 * @param pos The scrubber's top-left corner.
 * @param timeline Whether the play head is drawn.
 * @param alpha The opacity, multiplied by @c baseAlpha .
 * @ghidraAddress 0x20c814
 */
- (void)renderMusicBar:(CGPoint)pos timeline:(BOOL)timeline alpha:(double)alpha;

/**
 * @brief Draws one note chip at a horizontal position from the chip atlas.
 * @param posX The chip's horizontal position, in sectors.
 * @param keyIndex The 0..15 panel index selecting the chip's row and column.
 * @param uniType The chip variant; 1 selects the transposed texture orientation.
 * @param alpha The opacity.
 * @ghidraAddress 0x20cca8
 */
- (void)renderNoteChip:(float)posX keyIndex:(int)keyIndex uniType:(int)uniType alpha:(float)alpha;

/**
 * @brief Draws one horizontal grid line of the given kind at a position.
 * @param posX The line's horizontal position.
 * @param lineType The line kind, 0..4.
 * @param alpha The opacity.
 * @ghidraAddress 0x20ce30
 */
- (void)renderBaseLine:(float)posX lineType:(int)lineType alpha:(float)alpha;

/**
 * @brief Draws a measure number to the left of a position, as its decimal digits.
 * @param measure The measure number; -1 and 0 draw dedicated glyphs.
 * @param posX The horizontal anchor.
 * @param alpha The opacity.
 * @ghidraAddress 0x20cf2c
 */
- (void)renderMeasureNum:(int)measure posX:(float)posX alpha:(float)alpha;

/**
 * @brief Draws the current area selection: its fill, its two boundary lines, and its two handles.
 * @param alpha The opacity.
 * @ghidraAddress 0x20d1b4
 */
- (void)renderSelectArea:(float)alpha;

/**
 * @brief Draws the paste-preview line and its parts when a start but no end sector is selected.
 * @param alpha The opacity.
 * @ghidraAddress 0x20d3d8
 */
- (void)renderPastLine:(float)alpha;

/**
 * @brief Draws one sequence event (note, measure line, bpm change, or measure) at a base position.
 * @param index The event's index in @p event .
 * @param event The sequence event table.
 * @param basePos The base position offset, in sectors.
 * @param uniType The chip variant for note events.
 * @param alpha The opacity.
 * @ghidraAddress 0x20d560
 */
- (void)renderSequenceParts:(int)index
                      event:(const EditSequenceEvent *)event
                    basePos:(float)basePos
                    uniType:(int)uniType
                      alpha:(float)alpha;

/**
 * @brief Draws the visible run of the sequence: the field grid, the on-screen events, and lines.
 * @param alpha The opacity.
 * @ghidraAddress 0x20d838
 */
- (void)renderSequenceChip:(float)alpha;

/**
 * @brief Draws the tune information panel. This override is empty.
 * @param pos The panel position.
 * @param artworkSize The jacket artwork size.
 * @param alpha The opacity.
 * @ghidraAddress 0x20de50
 */
- (void)renderTuneInfo:(CGPoint)pos artworkSize:(double)artworkSize alpha:(double)alpha;

/**
 * @brief Draws the upper background frame, its divider, and the clap indicator.
 * @param alpha The opacity.
 * @ghidraAddress 0x20de54
 */
- (void)renderUpperBG:(float)alpha;

/**
 * @brief Draws the upper region: the timeline (with play head when playing) and the sequence.
 * @ghidraAddress 0x20e020
 */
- (void)renderUpper;

/**
 * @brief Draws one button-light sprite at a point.
 * @param lightType The light sprite index.
 * @param point The point to draw it at.
 * @ghidraAddress 0x20e08c
 */
- (void)renderButtonLight:(int)lightType atPoint:(CGPoint)point;

/**
 * @brief Draws the 4x4 button grid, lighting pressed enabled buttons.
 * @ghidraAddress 0x20e0ec
 */
- (void)renderButtons;

/**
 * @brief Draws the pre-start intro: the background, upper frame, tune info, timeline, and buttons,
 *        cued in over frames, and fires the ready sound on frame 20.
 * @ghidraAddress 0x20e234
 */
- (void)renderPreStart;

/**
 * @brief Draws the full-combo effect. This override is empty.
 * @param combo The combo count.
 * @param isResult Whether the result screen is showing.
 * @ghidraAddress 0x20e410
 */
- (void)renderFullcombo:(int)combo isResult:(BOOL)isResult;

/**
 * @brief Draws the finish effect. This override is empty.
 * @ghidraAddress 0x20e414
 */
- (void)renderFinish;

#pragma mark - Buttons

/**
 * @brief The button identifier for the end action.
 * @ghidraAddress 0x20e420
 */
@property(nonatomic, readonly) unsigned int endButtonID;

#pragma mark - Textures

/**
 * @brief The front atlas texture: the field, markers, buttons, lines, and digits.
 * @ghidraAddress 0x20e91c (getter), 0x20e92c (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texFront;

/**
 * @brief The chip atlas texture: the note chips.
 * @ghidraAddress 0x20e940 (getter), 0x20e950 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texChip;

/**
 * @brief The debug-font glyph sheet.
 * @ghidraAddress 0x20e964 (getter), 0x20e974 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texDebugFont;

/**
 * @brief The "go" cue audio player.
 * @ghidraAddress 0x20e988 (getter), 0x20e998 (setter)
 */
@property(nonatomic, strong, nullable) AVAudioPlayer *sePlayerGo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
