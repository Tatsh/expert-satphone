/**
 * @file
 * @brief The iPad Ripples-theme in-game renderer: the concrete @c MainGameRenderer subclass that
 * draws a play session with the "Ripples" (rpl) theme skin on the pad idiom.
 *
 * Reconstructed from Ghidra program Jubeat (class MainGameRendererPadRpl, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c MainGameRenderer (not @c MainGameRendererPad ): @c -init chains to
 * @c [MainGameRenderer init] at 0x10011945c, and this class declares its own @c frame ,
 * @c subStateChangeFrame , and @c markerDir ivars, which would collide with @c MainGameRendererPad
 * were it a subclass of it. It fills in every drawing and layout override point that
 * @c MainGameRenderer leaves empty for the Ripples theme: it loads the theme's atlas textures
 * (@c game_front_rpl_tex , @c game_combo_rpl_tex , @c game_marker_tex , @c game_hold_marker_tex ,
 * @c game_ready_rpl_0_tex , @c game_ready_rpl_1_tex , @c game_result_rpl_tex , and the debug-font
 * glyph sheet), draws the rippling background of bouncing sprites, the 4x4 marker grid and hold
 * markers, the combo counter, the running score and bonus, the tune-info panel, the music bar, the
 * on-screen button grid, the ready/go countdown, the start and finish marks, the full-combo and
 * excellent flourishes, and the cleared/failed result screen. Its layout constants are the pad's;
 * the phone sibling is @c MainGameRendererPhone and the non-theme pad sibling is
 * @c MainGameRendererPad .
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "MainGameRenderer.h"

@class AVAudioPlayer;
@class Texture2D;
@class RendererConf;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The pad Ripples-theme in-game renderer.
 */
@interface MainGameRendererPadRpl : MainGameRenderer {
@protected
    unsigned int frame;                     /*!< The frames elapsed in the current render state. */
    unsigned int subStateChangeFrame;       /*!< The frame the sub-state last changed on. */
    unsigned int startMarkFrame;            /*!< The start-mark animation frame counter. */
    float lastHakuPhase;                    /*!< The beat phase as of the last upper-BG update. */
    float bounceEnergy;                     /*!< The accumulated button-press bounce energy. */
    int markerDir[kMainGameGridPanelCount]; /*!< The random-mode marker direction per panel. */
}

#pragma mark - Lifecycle

/**
 * @brief Initialises the renderer, chaining to the superclass and building the background and
 *        upper-background ripple pools.
 * @return The initialised renderer, or @c nil.
 * @ghidraAddress 0x119430
 */
- (instancetype)init;

/**
 * @brief Releases the session textures, then chains to the superclass deallocation.
 * @ghidraAddress 0x121a08
 */
- (void)dealloc;

#pragma mark - Textures

/**
 * @brief Loads the pad Ripples-theme session atlases: the two ready textures, front, combo, marker,
 *        hold-marker, and debug-font textures, and builds the hold-marker sub-renderer and the
 *        upper-background ripple pool. The selector spelling @c loadTexure: (a missing "t") is the
 *        binary's own.
 * @param conf The renderer configuration describing the tune, difficulty, and marker.
 * @param artwork The jacket artwork image.
 * @param index An additional texture image the renderer composites in.
 * @ghidraAddress 0x1194f8
 */
- (void)loadTexure:(nullable RendererConf *)conf
           artwork:(nullable UIImage *)artwork
             index:(nullable UIImage *)index;

/**
 * @brief Loads the result atlas and the rating (rank judgement) texture for a rank tier.
 * @param rank The score rank tier, 0..7; ranks below 8 select a per-rank judgement resource.
 * @ghidraAddress 0x11aa04
 */
- (void)loadResultTex:(short)rank;

/**
 * @brief Releases the front, ready, result, and debug-font session textures.
 * @ghidraAddress 0x11ab94
 */
- (void)releaseTexture;

#pragma mark - State

/**
 * @brief Sets the render state, resetting per-state counters and, in the ready-go state, loading
 *        the "GO" voice player, and in the result state loading the result atlas and starting the
 *        result BGM.
 * @param state The high-level render state.
 * @ghidraAddress 0x11ac10
 */
- (void)setState:(unsigned int)state;

#pragma mark - Play lifecycle

/**
 * @brief Begins playback: moves to the play state and clears the "GO" voice player.
 * @ghidraAddress 0x11aef8
 */
- (void)startPlay;

/**
 * @brief Ends the result screen: in the result state sets the finished sub-state.
 * @ghidraAddress 0x11af34
 */
- (void)endResult;

/**
 * @brief Selects a replay: for a downloaded custom tune with music, arms the replay and fades the
 *        good-job overlay out.
 * @ghidraAddress 0x121a68
 */
- (void)replaySelect;

/**
 * @brief Ends a replay, clearing the replay-playing flag.
 * @ghidraAddress 0x121a58
 */
- (void)replayEnd;

/**
 * @brief The ready-go countdown duration, in seconds.
 * @return The countdown duration, in seconds.
 * @ghidraAddress 0x11e2f8
 */
- (double)durationOfReadyGo;

#pragma mark - Layout

/**
 * @brief The vertical offset of the button area, in points.
 * @return The button-area offset, always 0 for this renderer.
 * @ghidraAddress 0x1208cc
 */
- (double)buttonAreaOffset;

/**
 * @brief The vertical offset of the game area, in points.
 * @return The game-area offset.
 * @ghidraAddress 0x1208d4
 */
- (double)gameAreaOffset;

#pragma mark - Buttons

/**
 * @brief The button identifier for the end action.
 * @ghidraAddress 0x1208e0
 */
@property(nonatomic, readonly) unsigned int endButtonID;

/**
 * @brief The button identifier for the evaluate action.
 * @ghidraAddress 0x1208e8
 */
@property(nonatomic, readonly) unsigned int evaluateButtonID;

/**
 * @brief The button identifier for the good-job action.
 * @ghidraAddress 0x1208f0
 */
@property(nonatomic, readonly) unsigned int goodJobButtonID;

/**
 * @brief The centre position of the good-job overlay, derived from @c goodJobButtonID .
 * @ghidraAddress 0x1208f8
 */
@property(nonatomic, readonly) CGPoint goodJobPosition;

/**
 * @brief The button identifier for the tweet-send action.
 * @ghidraAddress 0x120968
 */
@property(nonatomic, readonly) unsigned int twitterSendButtonID;

/**
 * @brief The position of the tweet-send button, derived from @c twitterSendButtonID .
 * @ghidraAddress 0x120970
 */
@property(nonatomic, readonly) CGPoint twitterBtnPosition;

/**
 * @brief The button identifier for the store-move action.
 * @ghidraAddress 0x1209e0
 */
@property(nonatomic, readonly) unsigned int storeMoveButtonID;

/**
 * @brief The position of the store-move button, derived from @c storeMoveButtonID .
 * @ghidraAddress 0x1209e8
 */
@property(nonatomic, readonly) CGPoint storeMoveBtnPosition;

#pragma mark - Drawing

/**
 * @brief Draws one frame, dispatching on the render state and flushing every atlas.
 * @ghidraAddress 0x121590
 */
- (void)draw;

/**
 * @brief Draws debug text glyph-by-glyph from the debug-font sheet.
 * @param text The C string to draw.
 * @param pos The top-left position to draw it at.
 * @param alpha The opacity.
 * @ghidraAddress 0x1218e0
 */
- (void)drawDebugText:(nullable const char *)text pos:(CGPoint)pos alpha:(float)alpha;

/**
 * @brief Draws the rippling background: the base plate, the bouncing background ripples, and (in a
 *        beat frame) a spawn of a new ripple driven by the tension tier.
 * @ghidraAddress 0x11b770
 */
- (void)renderBG;

/**
 * @brief Draws the two scrolling shutter bars and their caps, optionally driving the shutter open
 *        amount from the tension and beat.
 * @param drive Whether to advance the shutter-open amount this frame.
 * @ghidraAddress 0x11bd24
 */
- (void)renderShutter:(BOOL)drive;

/**
 * @brief Draws the 4x4 marker grid, the marker hit frames, and the hold markers, then the start
 *        mark once the first marker approaches.
 * @ghidraAddress 0x11b434
 */
- (void)renderMarker;

/**
 * @brief Draws the start-mark intro animation over the first-marker panels.
 * @param alpha The overlay opacity multiplier.
 * @ghidraAddress 0x11af80
 */
- (void)renderStartMark:(float)alpha;

/**
 * @brief Draws the combo counter and its cut-in burst.
 * @param combo The current combo count.
 * @param alpha The opacity.
 * @ghidraAddress 0x11c2b8
 */
- (void)renderCombo:(unsigned int)combo alpha:(float)alpha;

/**
 * @brief Draws the score digits animating up from a previous value into a growing record banner.
 * @param score The target score.
 * @param point The top-left anchor.
 * @param alpha The opacity.
 * @ghidraAddress 0x11c680
 */
- (void)renderUpdatedScore:(unsigned int)score atPoint:(CGPoint)point alpha:(double)alpha;

/**
 * @brief Draws the running score, its label, and the six-figure rollup.
 * @param score The player's score.
 * @param point The top-left anchor.
 * @param alpha The opacity.
 * @ghidraAddress 0x11c7f4
 */
- (void)renderScore:(unsigned int)score atPoint:(CGPoint)point alpha:(double)alpha;

/**
 * @brief Draws the partner's score, at 0.7 scale, half-alpha when disconnected.
 * @param score The partner's score.
 * @param point The top-left anchor.
 * @param scale The horizontal scale.
 * @param alpha The opacity.
 * @ghidraAddress 0x11ca7c
 */
- (void)renderPartnerScore:(unsigned int)score
                   atPoint:(CGPoint)point
                     scale:(double)scale
                     alpha:(double)alpha;

/**
 * @brief Draws the result-screen music bar and its per-note markers.
 * @param pos The bar's top-left corner.
 * @param timeline Whether the play head is drawn.
 * @param alpha The opacity.
 * @ghidraAddress 0x11ccfc
 */
- (void)renderMusicBar:(CGPoint)pos timeline:(BOOL)timeline alpha:(double)alpha;

/**
 * @brief Draws the tune-info panel: the jacket artwork, the tune name, the difficulty word, and the
 *        level word.
 * @param pos The panel's top-left corner.
 * @param artworkSize The jacket artwork edge length.
 * @param alpha The opacity.
 * @ghidraAddress 0x11d038
 */
- (void)renderTuneInfo:(CGPoint)pos artworkSize:(double)artworkSize alpha:(double)alpha;

/**
 * @brief Draws the upper background: the tiled upper plate, and (when told to) the beam wipe, and
 *        steps and renders the upper-background ripple pool.
 * @param wipe Whether to draw and animate the upper-band beam wipe.
 * @ghidraAddress 0x11d1a4
 */
- (void)renderUpperBG:(BOOL)wipe;

/**
 * @brief Draws the upper region: the tune-info panel, the music bar, the score, and the partner
 *        score.
 * @ghidraAddress 0x11dcdc
 */
- (void)renderUpper;

/**
 * @brief Draws the 4x4 on-screen button grid, lighting pressed buttons.
 * @ghidraAddress 0x11de94
 */
- (void)renderButtons;

/**
 * @brief Draws the pre-start intro: the field, shutter, upper region, and buttons cued in over
 *        frames.
 * @ghidraAddress 0x11e0d8
 */
- (void)renderPreStart;

/**
 * @brief Draws the ready/go countdown.
 * @ghidraAddress 0x11e304
 */
- (void)renderReadyGo;

/**
 * @brief Draws the full-combo flourish over the four grid corners and the corner glyphs.
 * @param animFrame The animation frame counter.
 * @ghidraAddress 0x11ec14
 */
- (void)renderFullcombo:(int)animFrame;

/**
 * @brief Draws the finish banner: the full-combo flourish when a full combo, and advances the
 *        finish sub-state.
 * @ghidraAddress 0x11f43c
 */
- (void)renderFinish;

/**
 * @brief Draws the excellent flourish, its beam, its ring of chips, and the "EXCELLENT" wipe.
 * @param animFrame The animation frame counter.
 * @return Whether the animation has finished.
 * @ghidraAddress 0x11f788
 */
- (BOOL)renderExcellent:(unsigned int)animFrame;

/**
 * @brief Draws the rank rating (judgement) graphic, sliding and scaling in.
 * @param animFrame The animation frame counter.
 * @ghidraAddress 0x11ffbc
 */
- (void)renderRating:(unsigned int)animFrame;

/**
 * @brief Draws the cleared result graphic and its rating.
 * @param animFrame The animation frame counter.
 * @return Whether the animation is still running.
 * @ghidraAddress 0x1202e0
 */
- (BOOL)renderCleared:(unsigned int)animFrame;

/**
 * @brief Draws the failed result graphic and its rating.
 * @param animFrame The animation frame counter.
 * @return Whether the animation is still running.
 * @ghidraAddress 0x120658
 */
- (BOOL)renderFailed:(unsigned int)animFrame;

/**
 * @brief Draws the result screen: the cleared/failed/excellent graphic, the score, the rating, the
 *        new-record banner, and the action marks.
 * @ghidraAddress 0x120a58
 */
- (void)renderResult;

#pragma mark - Textures

/**
 * @brief The first ready/go atlas texture.
 * @ghidraAddress 0x10a140-style accessor
 */
@property(nonatomic, strong, nullable) Texture2D *texReady0;

/**
 * @brief The second ready/go atlas texture: the "GO" chips.
 */
@property(nonatomic, strong, nullable) Texture2D *texReady1;

/**
 * @brief The front atlas texture: the field, buttons, lines, tune-info, and score glyphs.
 */
@property(nonatomic, strong, nullable) Texture2D *texFront;

/**
 * @brief The marker atlas texture.
 */
@property(nonatomic, strong, nullable) Texture2D *texMarker;

/**
 * @brief The hold-marker atlas texture.
 */
@property(nonatomic, strong, nullable) Texture2D *texHoldMarker;

/**
 * @brief The combo-number and background atlas texture.
 */
@property(nonatomic, strong, nullable) Texture2D *texCombo;

/**
 * @brief The result atlas texture: cleared/failed/excellent graphics and the rating glyphs.
 */
@property(nonatomic, strong, nullable) Texture2D *texResult;

/**
 * @brief The debug-font glyph sheet.
 */
@property(nonatomic, strong, nullable) Texture2D *texDebugFont;

/**
 * @brief The "GO" voice audio player, loaded lazily in the ready-go state.
 */
@property(nonatomic, strong, nullable) AVAudioPlayer *sePlayerGo;

/**
 * @brief The background ripple pool.
 */
@property(nonatomic, strong, nullable) NSMutableArray *arrayBgRip;

/**
 * @brief The upper-background bouncing-sprite ripple pool.
 */
@property(nonatomic, strong, nullable) NSMutableArray *arrayUpperBgRip;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
