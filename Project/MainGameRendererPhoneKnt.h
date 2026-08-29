/**
 * @file
 * @brief The knit-theme iPhone in-game play renderer.
 *
 * Reconstructed from Ghidra program Jubeat (class MainGameRendererPhoneKnt, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * @c MainGameRendererPhoneKnt is the knit-theme phone concrete subclass of @c MainGameRenderer (not
 * @c MainGameRendererPhone : it derives straight from the abstract base, which is why it carries
 * its own texture properties rather than inheriting the classic phone renderer's protected ivars).
 * It draws the knit-decorated play field: the scrolling knit upper background (@c UpperBGKnit ) and
 * its effect sprites (@c EffectBgKnit ), the note and hold markers, the 4x4 button grid, the score,
 * combo, and bonus digits, the difficulty music bar and tune information, the ready/go countdown,
 * and the finish, fullcombo, excellent, cleared, failed, rating, and result screens. It branches on
 * two cached device flags — @c isRetina (2x sprites) and @c is4Inch (the taller four-inch phone).
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "MainGameRenderer.h"

@class AVAudioPlayer;
@class EffectBgKnit;
@class RendererConf;
@class Texture2D;
@class UpperBGKnit;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The knit-theme phone-idiom concrete in-game renderer.
 */
@interface MainGameRendererPhoneKnt : MainGameRenderer {
@protected
    BOOL isRetina; /*!< Cached phone-retina flag, sampled once at init. */             // +0x168
    BOOL is4Inch; /*!< Cached four-inch-aspect flag, sampled once at init. */          // +0x169
    unsigned int frame; /*!< The per-state frame counter, advanced each draw. */       // +0x16c
    unsigned int subStateChangeFrame; /*!< The frame the sub-state last changed on. */ // +0x170
    unsigned int startMarkFrame; /*!< The start-mark animation frame counter. */       // +0x174
    float lastHakuPhase; /*!< The beat phase as of the previous frame. */              // +0x178
    float bounceEnergy; /*!< The smoothed knit-background bounce energy. */            // +0x17c
    unsigned int effFrame; /*!< The background-effect spawn frame counter. */          // +0x180
    unsigned int effSlot; /*!< The next background-effect slot to spawn. */            // +0x184
    int markerDir[kMainGameGridPanelCount]; /*!< Per-panel marker spin direction. */   // +0x188
}

/**
 * @brief Initialises the renderer, caching the device flags and building the knit background.
 * @return The initialised renderer, or @c nil.
 * @ghidraAddress 0x189460
 */
- (instancetype)init;

#pragma mark - Textures

/**
 * @brief Loads every play-session texture for the knit theme. The selector spelling @c loadTexure:
 *        is the binary's own.
 * @param conf The renderer configuration.
 * @param artwork The jacket artwork image.
 * @param index An additional index image composited into the front atlas.
 * @ghidraAddress 0x189680
 */
- (void)loadTexure:(nullable RendererConf *)conf
           artwork:(nullable UIImage *)artwork
             index:(nullable UIImage *)index;

/**
 * @brief Rebuilds the result-screen rating atlas for a rank.
 * @param rank The tune's rank, selecting the rating resource.
 * @ghidraAddress 0x18b76c
 */
- (void)loadResultTex:(short)rank;

/**
 * @brief Releases the play-session textures the knit renderer owns.
 * @ghidraAddress 0x18bce8
 */
- (void)releaseTexture;

#pragma mark - Play lifecycle

/**
 * @brief Sets the high-level render state, loading the result textures and BGM on the result state
 *        and resetting the per-frame counters. Every path resets the frame counter and chains up.
 * @param state The state to enter.
 * @ghidraAddress 0x18bdf4
 */
- (void)setState:(unsigned int)state;

/**
 * @brief Clears the ready textures and enters the playing state.
 * @ghidraAddress 0x18c118
 */
- (void)startPlay;

/**
 * @brief Marks the session finished when it is in the result state.
 * @ghidraAddress 0x18c154
 */
- (void)endResult;

/**
 * @brief The ready-go countdown duration, in seconds.
 * @return The countdown duration.
 * @ghidraAddress 0x18f3cc
 */
- (double)durationOfReadyGo;

#pragma mark - Drawing

/**
 * @brief Draws one clipped sprite region: a sprite index at a position within a clip area, at an
 *        opacity.
 * @param clip The sprite index.
 * @param drawPosition The draw position.
 * @param drawArea The clip rectangle.
 * @param alpha The opacity.
 * @ghidraAddress 0x18c1a0
 */
- (void)drawClip:(int)clip
    drawPosition:(CGPoint)drawPosition
        drawArea:(CGRect)drawArea
           alpha:(float)alpha;

/**
 * @brief Draws the start-mark banner over the first-marker panels.
 * @param alpha The opacity.
 * @ghidraAddress 0x18c3a4
 */
- (void)renderStartMark:(float)alpha;

/**
 * @brief Draws the note markers over the sixteen-panel grid, delegating the hold markers.
 * @ghidraAddress 0x18c74c
 */
- (void)renderMarker;

/**
 * @brief Draws the knit play-field background and its effect sprites.
 * @ghidraAddress 0x18caf0
 */
- (void)renderBG;

/**
 * @brief Draws the beat shutter over the play field.
 * @param drive Whether the shutter is opened.
 * @ghidraAddress 0x18d194
 */
- (void)renderShutter:(BOOL)drive;

/**
 * @brief Draws the combo number and its burst and cut-in animations.
 * @param combo The current combo count.
 * @param alpha The opacity.
 * @ghidraAddress 0x18d470
 */
- (void)renderCombo:(unsigned int)combo alpha:(float)alpha;

/**
 * @brief Draws the score digits tweening up towards a target.
 * @param score The target score.
 * @param point The digits' origin.
 * @param alpha The opacity.
 * @ghidraAddress 0x18d92c
 */
- (void)renderUpdatedScore:(unsigned int)score atPoint:(CGPoint)point alpha:(double)alpha;

/**
 * @brief Draws the player score at a point.
 * @param score The player's score.
 * @param point The score block's origin.
 * @param alpha The opacity.
 * @ghidraAddress 0x18dbc8
 */
- (void)renderScore:(unsigned int)score atPoint:(CGPoint)point alpha:(double)alpha;

/**
 * @brief Draws the partner score at a point, with a horizontal scale and alpha.
 * @param score The partner's score.
 * @param point The partner score block's origin.
 * @param scale The horizontal scale.
 * @param alpha The opacity.
 * @ghidraAddress 0x18dfb8
 */
- (void)renderPartnerScore:(unsigned int)score
                   atPoint:(CGPoint)point
                     scale:(double)scale
                     alpha:(double)alpha;

/**
 * @brief Draws the difficulty music bar and its optional timeline cursor.
 * @param pos The bar's origin.
 * @param timeline Whether to draw the timeline cursor.
 * @param alpha The opacity.
 * @ghidraAddress 0x18e34c
 */
- (void)renderMusicBar:(CGPoint)pos timeline:(BOOL)timeline alpha:(double)alpha;

/**
 * @brief Draws the tune information block: jacket, title, difficulty word, and level.
 * @param point The block's origin.
 * @param artworkSize The jacket's square size.
 * @param alpha The opacity.
 * @ghidraAddress 0x18e810
 */
- (void)renderTuneInfo:(CGPoint)point artworkSize:(double)artworkSize alpha:(double)alpha;

/**
 * @brief Draws the knit upper background band.
 * @param isResult Whether a result screen is being shown.
 * @ghidraAddress 0x18eb04
 */
- (void)renderUpperBG:(BOOL)isResult;

/**
 * @brief Draws the upper region: the tune information, the live music bar, and the score.
 * @ghidraAddress 0x18ec9c
 */
- (void)renderUpper;

/**
 * @brief Draws the 4x4 button grid, highlighting pressed panels.
 * @ghidraAddress 0x18ef18
 */
- (void)renderButtons;

/**
 * @brief Draws the pre-start intro.
 * @ghidraAddress 0x18f0e0
 */
- (void)renderPreStart;

/**
 * @brief Draws the ready/go countdown, playing the ready and go sounds on their frames.
 * @ghidraAddress 0x18f3d4
 */
- (void)renderReadyGo;

/**
 * @brief Draws the full-combo celebration banner and word.
 * @param animFrame The animation frame; the result-screen path adds 150 to it.
 * @param isResult Whether the banner is being shown on the result screen.
 * @ghidraAddress 0x18fc64
 */
- (void)renderFullcombo:(int)animFrame isResult:(BOOL)isResult;

/**
 * @brief Draws the finish transition.
 * @ghidraAddress 0x190340
 */
- (void)renderFinish;

/**
 * @brief Draws the excellent celebration animation for a frame.
 * @param animFrame The animation frame.
 * @return Whether the animation is still running.
 * @ghidraAddress 0x190674
 */
- (BOOL)renderExcellent:(unsigned int)animFrame;

/**
 * @brief Draws the result-screen rating chips for a frame.
 * @param animFrame The animation frame.
 * @ghidraAddress 0x19134c
 */
- (void)renderRating:(unsigned int)animFrame;

/**
 * @brief Draws the cleared-screen animation for a frame.
 * @param animFrame The animation frame.
 * @return Whether the animation is still running.
 * @ghidraAddress 0x1917fc
 */
- (BOOL)renderCleared:(unsigned int)animFrame;

/**
 * @brief Draws the failed-screen animation for a frame.
 * @param animFrame The animation frame.
 * @return Whether the animation is still running.
 * @ghidraAddress 0x191d6c
 */
- (BOOL)renderFailed:(unsigned int)animFrame;

/**
 * @brief Draws the result screen.
 * @ghidraAddress 0x1924f8
 */
- (void)renderResult;

/**
 * @brief Draws the whole play frame, dispatching on the state and flushing every texture atlas.
 * @ghidraAddress 0x193214
 */
- (void)draw;

/**
 * @brief Draws a run of debug text from the debug-font atlas.
 * @param text The C string to draw.
 * @param pos The starting position.
 * @param alpha The opacity.
 * @ghidraAddress 0x19369c
 */
- (void)drawDebugText:(nullable const char *)text pos:(CGPoint)pos alpha:(float)alpha;

/**
 * @brief Notifies the renderer that a replay ended, clearing the replay-playing flag.
 * @ghidraAddress 0x193854
 */
- (void)replayEnd;

/**
 * @brief Reacts to a replay selection.
 * @ghidraAddress 0x193864
 */
- (void)replaySelect;

#pragma mark - Layout override points

/**
 * @brief The vertical offset of the button area, in points. Always zero for the knit phone.
 * @ghidraAddress 0x1922a8
 */
@property(nonatomic, readonly) double buttonAreaOffset;

/**
 * @brief The vertical offset of the game area, in points. Pushed down on the four-inch phone.
 * @ghidraAddress 0x1922b0
 */
@property(nonatomic, readonly) double gameAreaOffset;

#pragma mark - Button override points

/**
 * @brief The button identifier for the end action. Returns 15 for the knit phone.
 * @ghidraAddress 0x1922f0
 */
@property(nonatomic, readonly) unsigned int endButtonID;

/**
 * @brief The button identifier for the evaluate action. Returns 14 for the knit phone.
 * @ghidraAddress 0x1922f8
 */
@property(nonatomic, readonly) unsigned int evaluateButtonID;

/**
 * @brief The button identifier for the good-job action. Returns 13 for the knit phone.
 * @ghidraAddress 0x192300
 */
@property(nonatomic, readonly) unsigned int goodJobButtonID;

/**
 * @brief The position of the good-job overlay, derived from @c goodJobButtonID .
 * @ghidraAddress 0x192308
 */
@property(nonatomic, readonly) CGPoint goodJobPosition;

/**
 * @brief The button identifier for the tweet-send action. Returns 14 for the knit phone.
 * @ghidraAddress 0x1923a8
 */
@property(nonatomic, readonly) unsigned int twitterSendButtonID;

/**
 * @brief The position of the tweet-send button, derived from @c twitterSendButtonID .
 * @ghidraAddress 0x1923b0
 */
@property(nonatomic, readonly) CGPoint twitterBtnPosition;

/**
 * @brief The button identifier for the store-move action. Returns 14 for the knit phone.
 * @ghidraAddress 0x192450
 */
@property(nonatomic, readonly) unsigned int storeMoveButtonID;

/**
 * @brief The position of the store-move button, derived from @c storeMoveButtonID .
 * @ghidraAddress 0x192458
 */
@property(nonatomic, readonly) CGPoint storeMoveBtnPosition;

#pragma mark - Textures and knit decoration

/**
 * @brief The first ready-countdown atlas.
 * @ghidraAddress 0x193ad8 (getter), 0x193ae8 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texReady0;

/**
 * @brief The second ready-countdown atlas.
 * @ghidraAddress 0x193afc (getter), 0x193b0c (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texReady1;

/**
 * @brief The result-screen atlas.
 * @ghidraAddress 0x193b20 (getter), 0x193b30 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texResult;

/**
 * @brief The result-screen background atlas.
 * @ghidraAddress 0x193b44 (getter), 0x193b54 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texResultBg;

/**
 * @brief The beat-background atlas.
 * @ghidraAddress 0x193b68 (getter), 0x193b78 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texBeatBg;

/**
 * @brief The debug-font atlas.
 * @ghidraAddress 0x193b8c (getter), 0x193b9c (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texDebugFont;

/**
 * @brief The "GO" countdown sound player.
 * @ghidraAddress 0x193bb0 (getter), 0x193bc0 (setter)
 */
@property(nonatomic, strong, nullable) AVAudioPlayer *sePlayerGo;

/**
 * @brief The knit-wave texture layers.
 * @ghidraAddress 0x193bd4 (getter), 0x193be4 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray<Texture2D *> *texWaveAr;

/**
 * @brief The knit upper-background decoration.
 * @ghidraAddress 0x193bf8 (getter), 0x193c08 (setter)
 */
@property(nonatomic, strong, nullable) UpperBGKnit *upperBgKnt;

/**
 * @brief The current knit background effect sprite.
 * @ghidraAddress 0x193c1c (getter), 0x193c2c (setter)
 */
@property(nonatomic, strong, nullable) EffectBgKnit *effectBgKnt;

/**
 * @brief The active knit background effect sprites.
 * @ghidraAddress 0x193c40 (getter), 0x193c50 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray<EffectBgKnit *> *arrayBgEff;

/**
 * @brief The hold-marker atlas.
 * @ghidraAddress 0x193c64 (getter), 0x193c74 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texHoldMarker;

/**
 * @brief The front atlas: chips, buttons, tune info, marks.
 * @ghidraAddress 0x193c88 (getter), 0x193c98 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texFront;

/**
 * @brief The note-marker atlas.
 * @ghidraAddress 0x193cac (getter), 0x193cbc (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texMarker;

/**
 * @brief The combo-number and background atlas.
 * @ghidraAddress 0x193cd0 (getter), 0x193ce0 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texCombo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
