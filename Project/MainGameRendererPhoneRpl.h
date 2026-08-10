/** @file
 * The iPhone Ripples-theme in-game renderer: the concrete @c MainGameRenderer subclass that draws a
 * play session with the "Ripples" (rpl) theme skin on the phone idiom.
 *
 * Reconstructed from Ghidra program Jubeat (class MainGameRendererPhoneRpl, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * "Rpl" abbreviates "Ripples" (the ripple visual theme), not "replay". The superclass is
 * @c MainGameRenderer (not @c MainGameRendererPhone ): @c -init chains to @c [MainGameRenderer
 * init] , and this class declares its own @c frame , @c subStateChangeFrame , @c startMarkFrame ,
 * and
 * @c markerDir ivars, which would collide with @c MainGameRendererPhone were it a subclass of it.
 * It fills in every drawing and layout override point that @c MainGameRenderer leaves empty for the
 * Ripples theme: it loads the theme's atlas textures (@c game_front_rpl_tex_pn2 ,
 * @c game_combo_rpl_tex_pn2 , @c game_marker_tex_pn2 , @c game_hold_marker_tex ,
 * @c game_ready_rpl_0_tex , @c game_ready_rpl_1_tex , and the debug-font glyph sheet), draws the
 * rippling background of drifting sprites, the 4x4 marker grid and hold markers, the combo counter,
 * the running score and bonus, the tune-info panel, the music bar, the on-screen button grid, the
 * ready/go countdown, the start and finish marks, the full-combo and excellent flourishes, and the
 * cleared/failed result screen. Its layout constants are the phone's; the pad Ripples sibling is
 * @c MainGameRendererPadRpl , and the non-theme phone sibling is @c MainGameRendererPhone .
 *
 * It branches on two cached device flags, @c isRetina (2x sprites) and @c is4Inch (the taller
 * four-inch phone, whose game area is pushed down by @c buttonMarginForScreen40 /
 * @c upperBgHeight40 ).
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "MainGameRenderer.h"

@class AVAudioPlayer;
@class RendererConf;
@class Texture2D;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone Ripples-theme in-game renderer.
 */
@interface MainGameRendererPhoneRpl : MainGameRenderer {
@protected
    BOOL isRetina;                    /*!< Cached phone-retina flag, sampled once at init. */
    BOOL is4Inch;                     /*!< Cached four-inch-aspect flag, sampled once at init. */
    unsigned int frame;               /*!< The frames elapsed in the current render state. */
    unsigned int subStateChangeFrame; /*!< The frame the sub-state last changed on. */
    unsigned int startMarkFrame;      /*!< The start-mark animation frame counter. */
    float lastHakuPhase;              /*!< The beat phase as of the last background update. */
    float bounceEnergy;               /*!< The accumulated button-press bounce energy. */
    int markerDir[kMainGameGridPanelCount]; /*!< The random-mode marker direction per panel. */
}

#pragma mark - Lifecycle

/**
 * @brief Initialises the renderer, caching the phone-retina and four-inch-aspect device flags and
 *        building the background and upper-background ripple pools.
 * @return The initialised renderer, or @c nil.
 * @ghidraAddress 0x147758
 */
- (nullable instancetype)init;

/**
 * @brief Releases the session textures, then chains to the superclass deallocation.
 * @ghidraAddress 0x151f94
 */
- (void)dealloc;

#pragma mark - Textures

/**
 * @brief Loads the phone Ripples-theme session atlases: the two ready textures, front, combo,
 *        marker, hold-marker, and debug-font textures, blits the difficulty, level, and start/end
 *        marks into the front atlas, and builds the hold-marker sub-renderer and the
 *        upper-background ripple pool. The selector spelling @c loadTexure: (a missing "t") is the
 *        binary's own.
 * @param conf The renderer configuration describing the tune, difficulty, and marker.
 * @param artwork The jacket artwork image.
 * @param index An additional texture image the renderer composites in.
 * @ghidraAddress 0x1478a4
 */
- (void)loadTexure:(nullable RendererConf *)conf
           artwork:(nullable UIImage *)artwork
             index:(nullable UIImage *)index;

/**
 * @brief Loads the rating (rank judgement) graphic for a rank tier into the front atlas.
 * @param rank The score rank tier, 0..7; ranks below 8 select a per-rank judgement resource.
 * @ghidraAddress 0x149464
 */
- (void)loadResultTex:(short)rank;

/**
 * @brief Releases the front, ready, and debug-font session textures.
 * @ghidraAddress 0x1496a0
 */
- (void)releaseTexture;

#pragma mark - State

/**
 * @brief Sets the render state, resetting per-state counters and, in the ready-go state, loading
 *        the "GO" voice player, and in the result state starting the result BGM.
 * @param state The high-level render state.
 * @ghidraAddress 0x149704
 */
- (void)setState:(unsigned int)state;

#pragma mark - Play lifecycle

/**
 * @brief Begins playback: moves to the play state and clears the "GO" voice player.
 * @ghidraAddress 0x149a28
 */
- (void)startPlay;

/**
 * @brief Ends the result screen: in the result state sets the finished sub-state.
 * @ghidraAddress 0x149a64
 */
- (void)endResult;

/**
 * @brief Selects a replay: for a downloaded custom tune with music, arms the replay and fades the
 *        good-job overlay out.
 * @ghidraAddress 0x151ff4
 */
- (void)replaySelect;

/**
 * @brief Ends a replay, clearing the replay-playing flag.
 * @ghidraAddress 0x151fe4
 */
- (void)replayEnd;

/**
 * @brief The ready-go countdown duration, in seconds.
 * @ghidraAddress 0x14d70c
 */
- (double)durationOfReadyGo;

#pragma mark - Layout

/**
 * @brief The vertical offset of the button area, in points.
 * @return The button-area offset, always 0 for this renderer.
 * @ghidraAddress 0x150b20
 */
@property(nonatomic, readonly) double buttonAreaOffset;

/**
 * @brief The vertical offset of the game area, in points. Pushed down on the four-inch phone.
 * @ghidraAddress 0x150b28
 */
@property(nonatomic, readonly) double gameAreaOffset;

#pragma mark - Buttons

/**
 * @brief The button identifier for the end action.
 * @ghidraAddress 0x150b68
 */
@property(nonatomic, readonly) unsigned int endButtonID;

/**
 * @brief The button identifier for the evaluate action.
 * @ghidraAddress 0x150b70
 */
@property(nonatomic, readonly) unsigned int evaluateButtonID;

/**
 * @brief The button identifier for the good-job action.
 * @ghidraAddress 0x150b78
 */
@property(nonatomic, readonly) unsigned int goodJobButtonID;

/**
 * @brief The centre position of the good-job overlay, derived from @c goodJobButtonID .
 * @ghidraAddress 0x150b80
 */
@property(nonatomic, readonly) CGPoint goodJobPosition;

/**
 * @brief The button identifier for the tweet-send action.
 * @ghidraAddress 0x150c20
 */
@property(nonatomic, readonly) unsigned int twitterSendButtonID;

/**
 * @brief The position of the tweet-send button, derived from @c twitterSendButtonID .
 * @ghidraAddress 0x150c28
 */
@property(nonatomic, readonly) CGPoint twitterBtnPosition;

/**
 * @brief The button identifier for the store-move action.
 * @ghidraAddress 0x150cc8
 */
@property(nonatomic, readonly) unsigned int storeMoveButtonID;

/**
 * @brief The position of the store-move button, derived from @c storeMoveButtonID .
 * @ghidraAddress 0x150cd0
 */
@property(nonatomic, readonly) CGPoint storeMoveBtnPosition;

#pragma mark - Drawing

/**
 * @brief Draws the start-mark intro animation over the first-marker panels.
 * @param alpha The overlay opacity multiplier.
 * @ghidraAddress 0x149ab0
 */
- (void)renderStartMark:(float)alpha;

/**
 * @brief Draws the 4x4 marker grid, the marker hit frames, and the hold markers, then the start
 *        mark once the first marker approaches.
 * @ghidraAddress 0x14a008
 */
- (void)renderMarker;

/**
 * @brief Draws the rippling background: the base plate, the drifting background ripples, and (in a
 *        beat frame) a spawn of a new ripple driven by the tension tier.
 * @ghidraAddress 0x14a3ac
 */
- (void)renderBG;

/**
 * @brief Draws the two scrolling shutter bars and their caps, optionally driving the shutter-open
 *        amount from the tension and beat.
 * @param drive Whether to advance the shutter-open amount this frame.
 * @ghidraAddress 0x14aac0
 */
- (void)renderShutter:(BOOL)drive;

/**
 * @brief Draws the combo counter and its cut-in burst.
 * @param combo The current combo count.
 * @param alpha The opacity.
 * @ghidraAddress 0x14affc
 */
- (void)renderCombo:(unsigned int)combo alpha:(float)alpha;

/**
 * @brief Draws the score digits animating up from a previous value into a growing record banner.
 * @param score The target score.
 * @param point The top-left anchor.
 * @param alpha The opacity.
 * @ghidraAddress 0x14b4c8
 */
- (void)renderUpdatedScore:(unsigned int)score atPoint:(CGPoint)point alpha:(double)alpha;

/**
 * @brief Draws the running score, its label, and the six-figure rollup.
 * @param score The player's score.
 * @param point The top-left anchor.
 * @param alpha The opacity.
 * @ghidraAddress 0x14b6a0
 */
- (void)renderScore:(unsigned int)score atPoint:(CGPoint)point alpha:(double)alpha;

/**
 * @brief Draws the partner's score, at 0.7 scale, half-alpha when disconnected.
 * @param score The partner's score.
 * @param point The top-left anchor.
 * @param scale The horizontal scale.
 * @param alpha The opacity.
 * @ghidraAddress 0x14bbe8
 */
- (void)renderPartnerScore:(unsigned int)score
                   atPoint:(CGPoint)point
                     scale:(double)scale
                     alpha:(double)alpha;

/**
 * @brief Draws the music bar and its per-note markers.
 * @param pos The bar's top-left corner.
 * @param timeline Whether the play head is drawn.
 * @param alpha The opacity.
 * @ghidraAddress 0x14bf14
 */
- (void)renderMusicBar:(CGPoint)pos timeline:(BOOL)timeline alpha:(double)alpha;

/**
 * @brief Draws the tune-info panel: the jacket artwork, the tune name, the difficulty word, and the
 *        level word.
 * @param pos The panel's top-left corner.
 * @param artworkSize The jacket artwork edge length.
 * @param alpha The opacity.
 * @ghidraAddress 0x14c2e0
 */
- (void)renderTuneInfo:(CGPoint)pos artworkSize:(double)artworkSize alpha:(double)alpha;

/**
 * @brief Draws the upper background: the tiled upper plate, and (when told to) the beam wipe, and
 *        steps and renders the upper-background ripple pool.
 * @param wipe Whether to draw and animate the upper-band beam wipe.
 * @ghidraAddress 0x14c5d4
 */
- (void)renderUpperBG:(BOOL)wipe;

/**
 * @brief Draws the upper region: the tune-info panel, the music bar, the score, and the partner
 *        score.
 * @ghidraAddress 0x14ceb0
 */
- (void)renderUpper;

/**
 * @brief Draws the 4x4 on-screen button grid, lighting pressed buttons, with the four-inch phone's
 *        letterbox filler bands.
 * @ghidraAddress 0x14d12c
 */
- (void)renderButtons;

/**
 * @brief Draws the pre-start intro: the field, shutter, upper region, and buttons cued in over
 *        frames.
 * @ghidraAddress 0x14d420
 */
- (void)renderPreStart;

/**
 * @brief Draws the ready/go countdown.
 * @ghidraAddress 0x14d718
 */
- (void)renderReadyGo;

/**
 * @brief Draws the full-combo flourish over the grid corners and the corner glyphs.
 * @param frame The animation frame counter.
 * @ghidraAddress 0x14e254
 */
- (void)renderFullcombo:(int)frame;

/**
 * @brief Draws the finish banner: the full-combo flourish when a full combo, and advances the
 *        finish sub-state (loading the result graphics in the background).
 * @ghidraAddress 0x14ed9c
 */
- (void)renderFinish;

/**
 * @brief Draws the excellent flourish, its beam, its ring of chips, and the "EXCELLENT" wipe.
 * @param frame The animation frame counter.
 * @return Whether the animation has finished.
 * @ghidraAddress 0x14f0e8
 */
- (BOOL)renderExcellent:(unsigned int)frame;

/**
 * @brief Draws the rank rating (judgement) graphic, sliding and scaling in.
 * @param frame The animation frame counter.
 * @ghidraAddress 0x14feb8
 */
- (void)renderRating:(unsigned int)frame;

/**
 * @brief Draws the cleared result graphic and its rating.
 * @param frame The animation frame counter.
 * @return Whether the animation is still running.
 * @ghidraAddress 0x150348
 */
- (BOOL)renderCleared:(unsigned int)frame;

/**
 * @brief Draws the failed result graphic and its rating.
 * @param frame The animation frame counter.
 * @return Whether the animation is still running.
 * @ghidraAddress 0x1507cc
 */
- (BOOL)renderFailed:(unsigned int)frame;

/**
 * @brief Draws the result screen: the cleared/failed/excellent graphic, the score, the rating, the
 *        new-record banner, and the action marks.
 * @ghidraAddress 0x150d70
 */
- (void)renderResult;

/**
 * @brief Draws one frame, dispatching on the render state and flushing every atlas.
 * @ghidraAddress 0x151a58
 */
- (void)draw;

/**
 * @brief Draws debug text glyph-by-glyph from the debug-font sheet.
 * @param text The C string to draw.
 * @param pos The top-left position to draw it at.
 * @param alpha The opacity.
 * @ghidraAddress 0x151e2c
 */
- (void)drawDebugText:(nullable const char *)text pos:(CGPoint)pos alpha:(float)alpha;

#pragma mark - Textures

/**
 * @brief The first ready/go atlas texture: the "READY" disc and letters.
 * @ghidraAddress 0x152268 (getter), 0x152278 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texReady0;

/**
 * @brief The second ready/go atlas texture: the "GO" chips.
 * @ghidraAddress 0x15228c (getter), 0x15229c (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texReady1;

/**
 * @brief The front atlas texture: the field, buttons, tune-info, score glyphs, and result graphics.
 * @ghidraAddress 0x1522b0 (getter), 0x1522c0 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texFront;

/**
 * @brief The marker atlas texture.
 * @ghidraAddress 0x1522d4 (getter), 0x1522e4 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texMarker;

/**
 * @brief The hold-marker atlas texture.
 * @ghidraAddress 0x1522f8 (getter), 0x152308 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texHoldMarker;

/**
 * @brief The combo-number and background atlas texture.
 * @ghidraAddress 0x15231c (getter), 0x15232c (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texCombo;

/**
 * @brief The debug-font glyph sheet.
 * @ghidraAddress 0x152340 (getter), 0x152350 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texDebugFont;

/**
 * @brief The "GO" voice audio player, loaded lazily in the ready-go state.
 * @ghidraAddress 0x152364 (getter), 0x152374 (setter)
 */
@property(nonatomic, strong, nullable) AVAudioPlayer *sePlayerGo;

/**
 * @brief The background ripple pool.
 * @ghidraAddress 0x152388 (getter), 0x152398 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *arrayBgRip;

/**
 * @brief The upper-background drifting-sprite ripple pool.
 * @ghidraAddress 0x1523ac (getter), 0x1523bc (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *arrayUpperBgRip;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
