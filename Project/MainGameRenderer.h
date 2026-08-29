/**
 * @file
 * The base gameplay renderer and driver for a single play session.
 *
 * Reconstructed from Ghidra program Jubeat (class MainGameRenderer, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject, taken from the @c [NSObject init] chain-up in @c -init at
 * 0xf6b4. This is the abstract base of the renderer family: @c MainGameRendererPad ,
 * @c MainGameRendererPhone , their ripples (@c ...Rpl ) and knit-theme (@c ...Knt ) variants, and
 * the edit-note renderers all derive from it. Almost every drawing and layout method here is an
 * empty or constant-returning override point that a concrete subclass fills in per device idiom and
 * theme, so the base carries the shared state (the protected combo, marker, and hold-marker ivars
 * below) and the play-session properties while leaving the actual geometry to its subclasses.
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/** The game grid's panel count. */
enum {
    kMainGameGridPanelCount = 16 /*!< The number of panels in the game's 4x4 grid, sizing the
                                      per-panel state arrays. */
};

/**
 * One panel's hold-marker tracking state.
 *
 * The metadata types it `{?="state"i"move"I"currentSector"I"endSector"I}`: sixteen bytes, one
 * signed and three unsigned 32-bit fields, and the field names are the binary's own.
 */
typedef struct {
    int state; /*!< The hold's lifecycle state. */                              // +0x00
    unsigned int move; /*!< Whether and how the hold is moving. */              // +0x04
    unsigned int currentSector; /*!< The sector the hold currently occupies. */ // +0x08
    unsigned int endSector; /*!< The sector the hold terminates in. */          // +0x0c
} MainGameHoldState;

/**
 * A play session's cumulative score summary.
 *
 * The metadata types it `{?=iiiiiiiiiii[30c]}`, seventy-six bytes; the field names are the
 * binary's own, recovered from the @c _replayBackupScore ivar encoding. The type is shared with the
 * score system (it is what @c -[Sequence getScore] returns), but no reconstructed file defines it
 * yet, so it is declared here where this class first needs it.
 */
typedef struct {
    int nMiss; /*!< The number of missed notes. */                                 // +0x00
    int nPoor; /*!< The number of notes judged poor. */                            // +0x04
    int nGood; /*!< The number of notes judged good. */                            // +0x08
    int nGreat; /*!< The number of notes judged great. */                          // +0x0c
    int nPerfect; /*!< The number of notes judged perfect. */                      // +0x10
    int curCombo; /*!< The combo running at the play position. */                  // +0x14
    int maxCombo; /*!< The longest combo reached. */                               // +0x18
    int tension; /*!< The tension gauge level, clamped to its maximum. */          // +0x1c
    int point; /*!< The base score from notes, nine tenths of the raw. */          // +0x20
    int bonusPoint; /*!< The bonus scaled from @c tension . */                     // +0x24
    int totalPoint; /*!< @c point plus @c bonusPoint ; the final score. */         // +0x28
    char musicBarResult[30]; /*!< The result-screen music bar's per-bar grades. */ // +0x2c
} ScoreData;

@class RendererConf;
@class Sequence;
@class EAGLView;
@class HoldMarkerRender;

/**
 * The abstract base renderer for a play session.
 */
@interface MainGameRenderer : NSObject {
@protected
    float shutterOpen;                        /*!< The shutter-open animation progress. */
    unsigned int lastCombo;                   /*!< The combo count as of the last frame. */
    unsigned int comboEffectFrame;            /*!< The combo burst animation frame. */
    unsigned int comboCutFrame;               /*!< The combo cut-in animation frame. */
    unsigned int scoreDisplay;                /*!< The score currently shown, tweened up. */
    unsigned int partnerScoreDisplay;         /*!< The partner's shown score, tweened up. */
    int markerState[kMainGameGridPanelCount]; /*!< Per-panel marker animation state. */
    MainGameHoldState holdState[kMainGameGridPanelCount]; /*!< Per-panel hold-marker state. */
    HoldMarkerRender *holdMarkerRender;                   /*!< The hold-marker sub-renderer. */
}

/**
 * Initialises the renderer, clearing its texture-change, good-job image, and score-backup
 *        state.
 * @return The initialised renderer, or @c nil.
 * @ghidraAddress 0xf6b4
 */
- (instancetype)init;

/**
 * Loads the textures for a play session. The base implementation does nothing; each concrete
 *        subclass loads the idiom- and theme-appropriate textures.
 * @param conf The renderer configuration describing the tune, difficulty, and marker.
 * @param artwork The jacket artwork image.
 * @param index An additional texture image the subclass composites in.
 * @ghidraAddress 0xf714
 */
- (void)loadTexure:(nullable RendererConf *)conf
           artwork:(nullable UIImage *)artwork
             index:(nullable UIImage *)index;

/**
 * Releases the session textures. The base implementation does nothing.
 * @ghidraAddress 0xf718
 */
- (void)releaseTexture;

/**
 * The ready-go countdown duration, in seconds. The base returns 0.
 * @return The countdown duration.
 * @ghidraAddress 0xf7c4
 */
- (double)durationOfReadyGo;

/**
 * Notifies the renderer that play has started. The base implementation does nothing.
 * @ghidraAddress 0xf7cc
 */
- (void)startPlay;

/**
 * Notifies the renderer that the result screen should begin. The base does nothing.
 * @ghidraAddress 0xf7d0
 */
- (void)endResult;

/**
 * The vertical offset of the button area, in points. The base returns 0.
 * @return The button-area offset.
 * @ghidraAddress 0xf7d4
 */
- (double)buttonAreaOffset;

/**
 * The vertical offset of the game area, in points. The base returns 0.
 * @return The game-area offset.
 * @ghidraAddress 0xf7dc
 */
- (double)gameAreaOffset;

/**
 * Draws one frame. The base implementation does nothing; subclasses render the play field.
 * @ghidraAddress 0xf7e4
 */
- (void)draw;

/**
 * Draws debug text at a point. The base implementation does nothing.
 * @param text The C string to draw.
 * @param pos The position to draw it at.
 * @param alpha The opacity.
 * @ghidraAddress 0xf7e8
 */
- (void)drawDebugText:(nullable const char *)text pos:(CGPoint)pos alpha:(float)alpha;

/**
 * The rectangle of the result-screen music bar. The base returns @c CGRectZero .
 * @return The music-bar rectangle.
 * @ghidraAddress 0xf7fc
 */
- (CGRect)getMusicBarRect;

/**
 * Snapshots the sequence's current score into @c replayBackupScore for replay, and marks the
 *        score backed up.
 * @ghidraAddress 0xf810
 */
- (void)backupScoreData;

/**
 * Notifies the renderer that a replay was selected. The base implementation does nothing.
 * @ghidraAddress 0xf87c
 */
- (void)replaySelect;

/**
 * Notifies the renderer that a replay ended. The base implementation does nothing.
 * @ghidraAddress 0xf880
 */
- (void)replayEnd;

/**
 * The renderer configuration for the current session.
 * @ghidraAddress 0xf884 (getter), 0xf894 (setter)
 */
@property(nonatomic, strong, nullable) RendererConf *rendererConf;

/**
 * The high-level render state. Setting it also resets @c subState to 0.
 * @ghidraAddress 0xf71c (getter), 0xf72c (setter)
 */
@property(nonatomic) unsigned int state;

/**
 * The render sub-state within the current @c state .
 * @ghidraAddress 0xf8a8 (getter), 0xf8b8 (setter)
 */
@property(nonatomic) unsigned int subState;

/**
 * Whether the combo counter is shown.
 * @ghidraAddress 0xf8c8 (getter), 0xf8d8 (setter)
 */
@property(nonatomic) BOOL showCombo;

/**
 * Whether the session set a new record.
 * @ghidraAddress 0xf8e8 (getter), 0xf8f8 (setter)
 */
@property(nonatomic) BOOL isNewRecord;

/**
 * The previous best score record for this tune.
 * @ghidraAddress 0xf908 (getter), 0xf918 (setter)
 */
@property(nonatomic) unsigned int scoreRecord;

/**
 * The currently pressed button bitmask.
 * @ghidraAddress 0xf928 (getter), 0xf938 (setter)
 */
@property(nonatomic) int btnPress;

/**
 * The currently held-down button bitmask.
 * @ghidraAddress 0xf948 (getter), 0xf958 (setter)
 */
@property(nonatomic) int btnDown;

/**
 * Whether the session partner has finished.
 * @ghidraAddress 0xf968 (getter), 0xf978 (setter)
 */
@property(nonatomic) BOOL partnerFinished;

/**
 * The partner's current score.
 * @ghidraAddress 0xf988 (getter), 0xf998 (setter)
 */
@property(nonatomic) unsigned int partnerScore;

/**
 * The partner's final bonus.
 * @ghidraAddress 0xf9a8 (getter), 0xf9b8 (setter)
 */
@property(nonatomic) unsigned int partnerFinalBonus;

/**
 * Whether the partner achieved a full combo.
 * @ghidraAddress 0xf9c8 (getter), 0xf9d8 (setter)
 */
@property(nonatomic) BOOL partnerFullcombo;

/**
 * The note sequence being played.
 * @ghidraAddress 0xf9e8 (getter), 0xf9f8 (setter)
 */
@property(nonatomic, strong, nullable) Sequence *sequence;

/**
 * The GL view this renderer draws into.
 * @ghidraAddress 0xfa0c (getter), 0xfa1c (setter)
 */
@property(nonatomic, strong, nullable) EAGLView *eaglView;

/**
 * The ghost-play button bitmask.
 * @ghidraAddress 0xfa30 (getter), 0xfa40 (setter)
 */
@property(nonatomic) int ghostPress;

/**
 * The good-job overlay image view. Stored without ownership, matching the binary.
 * @ghidraAddress 0xfa50 (getter), 0xfa60 (setter)
 */
@property(nonatomic, unsafe_unretained, nullable) UIImageView *goodJobImage;

/**
 * The peak opacity of the good-job overlay.
 * @ghidraAddress 0xfa70 (getter), 0xfa80 (setter)
 */
@property(nonatomic) float goodJobAlphaMax;

/**
 * Whether this is a session (versus) play.
 * @ghidraAddress 0xfa90 (getter), 0xfaa0 (setter)
 */
@property(nonatomic) BOOL isSession;

/**
 * Whether the session partner is connected.
 * @ghidraAddress 0xfab0 (getter), 0xfac0 (setter)
 */
@property(nonatomic) BOOL isConnected;

/**
 * Whether this is a custom (edit) sequence.
 * @ghidraAddress 0xfad0 (getter), 0xfae0 (setter)
 */
@property(nonatomic) BOOL isCustom;

/**
 * Whether the tune was downloaded.
 * @ghidraAddress 0xfaf0 (getter), 0xfb00 (setter)
 */
@property(nonatomic) BOOL isDownload;

/**
 * Whether a texture change is pending.
 * @ghidraAddress 0xfb10 (getter), 0xfb20 (setter)
 */
@property(nonatomic) BOOL isTextureChange;

/**
 * Whether the session has music.
 * @ghidraAddress 0xfb30 (getter), 0xfb40 (setter)
 */
@property(nonatomic) BOOL hasMusic;

/**
 * Whether a replay is playing.
 * @ghidraAddress 0xfb50 (getter), 0xfb60 (setter)
 */
@property(nonatomic) BOOL replayPlaying;

/**
 * Whether the score has been backed up for replay.
 * @ghidraAddress 0xfb70 (getter), 0xfb80 (setter)
 */
@property(nonatomic) BOOL scoreBackup;

/**
 * Whether the session has reached its end sub-state.
 * @ghidraAddress 0xf748
 */
@property(nonatomic, readonly) BOOL isEndState;

/**
 * The button identifier for the end action. The base returns 0.
 * @ghidraAddress 0xf76c
 */
@property(nonatomic, readonly) unsigned int endButtonID;

/**
 * The button identifier for the evaluate action. The base returns 0.
 * @ghidraAddress 0xf774
 */
@property(nonatomic, readonly) unsigned int evaluateButtonID;

/**
 * The button identifier for the good-job action. The base returns 0.
 * @ghidraAddress 0xf77c
 */
@property(nonatomic, readonly) unsigned int goodJobButtonID;

/**
 * The position of the good-job overlay. The base returns @c CGPointZero .
 * @ghidraAddress 0xf784
 */
@property(nonatomic, readonly) CGPoint goodJobPosition;

/**
 * The default button margin used by the 480-point-tall phone layout.
 * @ghidraAddress 0xf7ec
 */
@property(nonatomic, readonly) int buttonMarginForScreen40;

/**
 * The default upper-background height used by the 480-point-tall phone layout.
 * @ghidraAddress 0xf7f4
 */
@property(nonatomic, readonly) int upperBgHeight40;

/**
 * The button identifier for the tweet-send action. The base returns 0.
 * @ghidraAddress 0xf794
 */
@property(nonatomic, readonly) unsigned int twitterSendButtonID;

/**
 * The position of the tweet-send button. The base returns @c CGPointZero .
 * @ghidraAddress 0xf79c
 */
@property(nonatomic, readonly) CGPoint twitterBtnPosition;

/**
 * The button identifier for the store-move action. The base returns 0.
 * @ghidraAddress 0xf7ac
 */
@property(nonatomic, readonly) unsigned int storeMoveButtonID;

/**
 * The position of the store-move button. The base returns @c CGPointZero .
 * @ghidraAddress 0xf7b4
 */
@property(nonatomic, readonly) CGPoint storeMoveBtnPosition;

/**
 * The score snapshot captured for replay by @c -backupScoreData .
 * @ghidraAddress 0xfb90
 */
@property(nonatomic, readonly) ScoreData replayBackupScore;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
