/** @file
 * The edit-mode note renderer.
 *
 * Reconstructed from Ghidra program Jubeat (class EditNoteRenderer, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * @note The task brief described this class as a subclass of @c MainGameRenderer , but the shipped
 * runtime metadata contradicts that: the class's @c instStart is @c 0x8 (immediately after the
 * @c isa pointer) and it declares its own complete ivar set from @c shutterOpen at @c +0x8 onward,
 * while @c -init chains up to @c [NSObject init] . A genuine @c MainGameRenderer subclass would
 * have
 * @c instStart == 0x204 (its superclass's @c instSize ) and would not redeclare the shared ivars.
 * @c EditNoteRenderer is therefore an independent, parallel renderer whose direct superclass is
 * @c NSObject . It mirrors the shape of much of the @c MainGameRenderer interface but is a leaner,
 * edit-specific reimplementation: it carries no hold-marker state, and its configuration and
 * sequence are the edit-mode @c EditRendererConf and @c EditSequence types. Almost every drawing,
 * layout, and coordinate-conversion method is an empty or constant-returning override point that
 * the concrete @c EditNoteRendererPad and @c EditNoteRendererPhone subclasses fill in.
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// The number of panels in the game's 4x4 grid, sizing the per-panel marker-state array.
enum { kEditNoteGridPanelCount = 16 };

@class EditRendererConf;
@class EditSequence;
@class EAGLView;

/**
 * @brief The edit-mode note renderer. Its direct superclass is @c NSObject (see the file comment).
 */
@interface EditNoteRenderer : NSObject {
@protected
    float shutterOpen;                        /*!< The shutter-open animation progress. */
    unsigned int lastCombo;                   /*!< The combo count as of the last frame. */
    unsigned int comboEffectFrame;            /*!< The combo burst animation frame. */
    unsigned int comboCutFrame;               /*!< The combo cut-in animation frame. */
    unsigned int scoreDisplay;                /*!< The score currently shown, tweened up. */
    unsigned int partnerScoreDisplay;         /*!< The partner's shown score, tweened up. */
    int markerState[kEditNoteGridPanelCount]; /*!< Per-panel marker animation state. */
}

/**
 * @brief Initialises the renderer with edit-mode defaults: the button area enabled, display mode 0,
 *        and both the start and end selection sectors cleared to -1.
 * @return The initialised renderer, or @c nil.
 * @ghidraAddress 0x20add0
 */
- (nullable instancetype)init;

#pragma mark - Textures

/**
 * @brief Loads the textures for the edit session. This override does nothing; the concrete idiom
 *        subclasses load the appropriate textures. The selector spelling @c loadTexure: is the
 *        binary's own (a missing "t"), kept verbatim.
 * @param conf The edit renderer configuration.
 * @param artwork The jacket artwork image.
 * @param index An additional texture image.
 * @ghidraAddress 0x20ae6c
 */
- (void)loadTexure:(nullable EditRendererConf *)conf
           artwork:(nullable UIImage *)artwork
             index:(nullable UIImage *)index;

/**
 * @brief Releases the session textures. This override does nothing.
 * @ghidraAddress 0x20ae70
 */
- (void)releaseTexture;

#pragma mark - Play lifecycle override points

/**
 * @brief Notifies the renderer that play has started. This override does nothing.
 * @ghidraAddress 0x20aedc
 */
- (void)startPlay;

/**
 * @brief Notifies the renderer that the result screen should begin. This override does nothing.
 * @ghidraAddress 0x20aee0
 */
- (void)endResult;

/**
 * @brief Resets the edit playback to the current time. This override does nothing.
 * @ghidraAddress 0x20af48
 */
- (void)resetCurrentTime;

/**
 * @brief Saves the base scale for the edit view. This override does nothing.
 * @ghidraAddress 0x20af50
 */
- (void)saveBaseScale;

#pragma mark - Layout override points

/**
 * @brief The vertical offset of the button area, in points. This override returns 0.
 * @return The button-area offset.
 * @ghidraAddress 0x20aee4
 */
- (double)buttonAreaOffset;

/**
 * @brief The rectangle of the edit timeline. This override returns @c CGRectZero .
 * @return The timeline rectangle.
 * @ghidraAddress 0x20aef4
 */
- (CGRect)getTimeLineRect;

/**
 * @brief The rectangle of the area-selection start handle. This override returns @c CGRectZero .
 * @return The selection-start rectangle.
 * @ghidraAddress 0x20af20
 */
- (CGRect)getAreaSelectStart;

/**
 * @brief The rectangle of the area-selection end handle. This override returns @c CGRectZero .
 * @return The selection-end rectangle.
 * @ghidraAddress 0x20af34
 */
- (CGRect)getAreaSelectEnd;

#pragma mark - Drawing override points

/**
 * @brief Draws one frame. This override does nothing; subclasses render the edit field.
 * @ghidraAddress 0x20aeec
 */
- (void)draw;

/**
 * @brief Draws debug text at a point. This override does nothing.
 * @param text The C string to draw.
 * @param pos The position to draw it at.
 * @param alpha The opacity.
 * @ghidraAddress 0x20aef0
 */
- (void)drawDebugText:(nullable const char *)text pos:(CGPoint)pos alpha:(float)alpha;

#pragma mark - Coordinate conversion override points

/**
 * @brief Converts a horizontal position to a sector index. This override returns 0.
 * @param pos The position, in points.
 * @return The sector index.
 * @ghidraAddress 0x20af08
 */
- (int)pos2sector:(int)pos;

/**
 * @brief Converts a sector index to a horizontal position. This override returns 0.
 * @param sector The sector index.
 * @return The position, in points.
 * @ghidraAddress 0x20af10
 */
- (int)sector2pos:(int)sector;

/**
 * @brief Converts a dot index to a sector index. This override returns 0.
 * @param dot The dot index.
 * @return The sector index.
 * @ghidraAddress 0x20af18
 */
- (int)dot2sector:(int)dot;

#pragma mark - Edit configuration

/**
 * @brief Sets the decibel scale for the edit waveform display. This override does nothing.
 * @param dbs The decibel scale.
 * @ghidraAddress 0x20af4c
 */
- (void)setDbs:(float)dbs;

#pragma mark - Read-only accessors

/**
 * @brief Whether the session has reached its end sub-state.
 * @ghidraAddress 0x20aea0
 */
@property(nonatomic, readonly) BOOL isEndState;

/**
 * @brief The button identifier for the end action. This override returns 0.
 * @ghidraAddress 0x20aec4
 */
@property(nonatomic, readonly) unsigned int endButtonID;

/**
 * @brief The button identifier for the good-job action. This override returns 0.
 * @ghidraAddress 0x20aecc
 */
@property(nonatomic, readonly) unsigned int goodJobButtonID;

/**
 * @brief The button identifier for the level action. This override returns 0.
 * @ghidraAddress 0x20aed4
 */
@property(nonatomic, readonly) unsigned int levelButtonID;

#pragma mark - Session state

/**
 * @brief The high-level render state. Setting it also resets @c subState to 0.
 * @ghidraAddress 0x20ae74 (getter), 0x20ae84 (setter)
 */
@property(nonatomic) unsigned int state;

/**
 * @brief The render sub-state within the current @c state .
 * @ghidraAddress 0x20af78 (getter), 0x20af88 (setter)
 */
@property(nonatomic) unsigned int subState;

/**
 * @brief Whether the combo counter is shown.
 * @ghidraAddress 0x20af98 (getter), 0x20afa8 (setter)
 */
@property(nonatomic) BOOL showCombo;

/**
 * @brief Whether the session set a new record.
 * @ghidraAddress 0x20afb8 (getter), 0x20afc8 (setter)
 */
@property(nonatomic) BOOL isNewRecord;

/**
 * @brief The currently pressed button bitmask.
 * @ghidraAddress 0x20afd8 (getter), 0x20afe8 (setter)
 */
@property(nonatomic) int btnPress;

/**
 * @brief The currently held-down button bitmask.
 * @ghidraAddress 0x20aff8 (getter), 0x20b008 (setter)
 */
@property(nonatomic) int btnDown;

/**
 * @brief Whether the session partner has finished.
 * @ghidraAddress 0x20b018 (getter), 0x20b028 (setter)
 */
@property(nonatomic) BOOL partnerFinished;

/**
 * @brief The partner's current score.
 * @ghidraAddress 0x20b038 (getter), 0x20b048 (setter)
 */
@property(nonatomic) unsigned int partnerScore;

/**
 * @brief The partner's final bonus.
 * @ghidraAddress 0x20b058 (getter), 0x20b068 (setter)
 */
@property(nonatomic) unsigned int partnerFinalBonus;

/**
 * @brief Whether the partner achieved a full combo.
 * @ghidraAddress 0x20b078 (getter), 0x20b088 (setter)
 */
@property(nonatomic) BOOL partnerFullcombo;

#pragma mark - Collaborators

/**
 * @brief The edit renderer configuration for the current session.
 * @ghidraAddress 0x20af54 (getter), 0x20af64 (setter)
 */
@property(nonatomic, strong, nullable) EditRendererConf *rendererConf;

/**
 * @brief The edit note sequence being played.
 * @ghidraAddress 0x20b098 (getter), 0x20b0a8 (setter)
 */
@property(nonatomic, strong, nullable) EditSequence *sequence;

/**
 * @brief The GL view this renderer draws into.
 * @ghidraAddress 0x20b0bc (getter), 0x20b0cc (setter)
 */
@property(nonatomic, strong, nullable) EAGLView *eaglView;

#pragma mark - Edit-specific state

/**
 * @brief Whether the on-screen edit buttons are enabled.
 * @ghidraAddress 0x20b0e0 (getter), 0x20b0f0 (setter)
 */
@property(nonatomic) BOOL enableBtn;

/**
 * @brief The edit display mode.
 * @ghidraAddress 0x20b100 (getter), 0x20b110 (setter)
 */
@property(nonatomic) int displayMode;

/**
 * @brief The sector currently under the edit cursor.
 * @ghidraAddress 0x20b120 (getter), 0x20b130 (setter)
 */
@property(nonatomic) int currentSector;

/**
 * @brief The number of divisions per measure in the edit grid.
 * @ghidraAddress 0x20b140 (getter), 0x20b150 (setter)
 */
@property(nonatomic) int divMeasure;

/**
 * @brief The first sector of the current area selection, or -1 when none is selected.
 * @ghidraAddress 0x20b160 (getter), 0x20b170 (setter)
 */
@property(nonatomic) int areaStartSector;

/**
 * @brief The last sector of the current area selection, or -1 when none is selected.
 * @ghidraAddress 0x20b180 (getter), 0x20b190 (setter)
 */
@property(nonatomic) int areaEndSector;

/**
 * @brief Whether the metronome clap is enabled.
 * @ghidraAddress 0x20b1a0 (getter), 0x20b1b0 (setter)
 */
@property(nonatomic) BOOL enableClap;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
