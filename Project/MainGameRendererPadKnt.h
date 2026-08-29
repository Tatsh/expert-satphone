/**
 * @file
 * @brief The knit-theme iPad in-game renderer: the @c MainGameRenderer subclass that draws a play
 * session on the pad idiom with the "Knit" visual theme.
 *
 * Reconstructed from Ghidra program Jubeat (class MainGameRendererPadKnt, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c MainGameRenderer (direct, not @c MainGameRendererPad ): the Knit pad
 * renderer is a sibling of the default @c MainGameRendererPad , not a subclass of it, and it
 * carries its own layout state (the @c frame , @c subStateChangeFrame , @c startMarkFrame , @c
 * markerDir , and @c musicBarRect ivars) rather than inheriting the default pad's. It draws the
 * knit background (a scrolling @c UpperBGKnit wave decoration plus @c EffectBgKnit bursts and a
 * pulsing beat background), the 4x4 marker grid and hold markers, the combo counter, the running
 * and partner score, the tune-info panel, the music bar, the on-screen button grid, the ready/go
 * countdown, the start and finish marks, the full-combo and excellent flourishes, and the
 * cleared/failed result screen. Every drawing method batches quads into the atlas textures, which
 * the top-level @c -draw flushes with @c -commitDraw . The phone sibling is @c
 * MainGameRendererPhoneKnt .
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
 * @brief The knit-theme pad in-game renderer.
 */
@interface MainGameRendererPadKnt : MainGameRenderer {
@protected
    unsigned int frame;               /*!< The frames elapsed in the current render state. */
    unsigned int subStateChangeFrame; /*!< The frame the interactive sub-state last changed on. */
    unsigned int startMarkFrame;      /*!< The start-mark animation frame counter. */
    float lastHakuPhase;              /*!< The beat phase as of the previous frame. */
    float bounceEnergy;               /*!< The accumulated knit-bounce energy. */
    unsigned int effFrame;            /*!< The knit-effect scheduling frame counter. */
    unsigned int effSlot;             /*!< The next knit-effect table slot to spawn. */
    int markerDir[kMainGameGridPanelCount]; /*!< The random-mode marker direction per panel. */
    CGRect musicBarRect;                    /*!< The result-screen music-bar rectangle. */
}

#pragma mark - Lifecycle

/**
 * @brief Initialises the knit pad renderer: chains to the superclass, then builds the empty
 *        effect-sprite array, the knit upper-background decoration, and its wave geometry.
 * @return The initialised renderer, or @c nil.
 * @ghidraAddress 0x1fdf14
 */
- (instancetype)init;

/**
 * @brief Releases the session textures, then chains to the superclass deallocation.
 * @ghidraAddress 0x206d7c
 */
- (void)dealloc;

#pragma mark - Textures

/**
 * @brief Loads the knit pad session atlases: the debug font, the six wave layers, the beat
 *        background, the ready/go textures, the front, marker, hold-marker and combo atlases, and
 *        the tune-info blits. The selector spelling @c loadTexure: (a missing "t") is the binary's.
 * @param conf The renderer configuration describing the tune, difficulty, and marker.
 * @param artwork The jacket artwork image.
 * @param index An additional texture image the renderer composites in.
 * @ghidraAddress 0x1fe04c
 */
- (void)loadTexure:(nullable RendererConf *)conf
           artwork:(nullable UIImage *)artwork
             index:(nullable UIImage *)index;

/**
 * @brief Loads the result-screen atlas and result-background atlas, sets the result clip rect, and
 *        blits the per-rank end-mark graphic.
 * @param rank The score rank tier; ranks 0..7 select a per-rank end-mark resource.
 * @ghidraAddress 0x20004c
 */
- (void)loadResultTex:(short)rank;

/**
 * @brief Releases every knit session texture.
 * @ghidraAddress 0x20036c
 */
- (void)releaseTexture;

#pragma mark - State

/**
 * @brief Sets the render state, resetting per-state counters and, in the ready-go and result
 *        states, preparing the go voice player and result BGM.
 * @param state The high-level render state.
 * @ghidraAddress 0x20048c
 */
- (void)setState:(unsigned int)state;

#pragma mark - Play lifecycle

/**
 * @brief Begins playback: moves to state 3 and clears the go voice player.
 * @ghidraAddress 0x2007e4
 */
- (void)startPlay;

/**
 * @brief Ends the result screen: in the result state sets the finished sub-state.
 * @ghidraAddress 0x200820
 */
- (void)endResult;

/**
 * @brief Selects a replay: for a downloaded custom tune with music, arms the replay, reloads the
 *        start mark, and fades the good-job overlay out.
 * @ghidraAddress 0x206ddc
 */
- (void)replaySelect;

/**
 * @brief Ends a replay, clearing the replay-playing flag.
 * @ghidraAddress 0x206dcc
 */
- (void)replayEnd;

/**
 * @brief The ready-go countdown duration, in seconds.
 * @return The countdown duration, in seconds.
 * @ghidraAddress 0x203238
 */
- (double)durationOfReadyGo;

#pragma mark - Layout

/**
 * @brief The vertical offset of the button area, in points. Always zero for the knit pad.
 * @return Always 0.
 * @ghidraAddress 0x205a98
 */
- (double)buttonAreaOffset;

/**
 * @brief The vertical offset of the game area, in points.
 * @return The game-area offset, in points.
 * @ghidraAddress 0x205aa0
 */
- (double)gameAreaOffset;

#pragma mark - Buttons

/**
 * @brief The button identifier for the end action.
 * @ghidraAddress 0x205aac
 */
@property(nonatomic, readonly) unsigned int endButtonID;

/**
 * @brief The button identifier for the evaluate action.
 * @ghidraAddress 0x205ab4
 */
@property(nonatomic, readonly) unsigned int evaluateButtonID;

/**
 * @brief The button identifier for the good-job action.
 * @ghidraAddress 0x205abc
 */
@property(nonatomic, readonly) unsigned int goodJobButtonID;

/**
 * @brief The centre position of the good-job overlay, derived from @c goodJobButtonID .
 * @ghidraAddress 0x205ac4
 */
@property(nonatomic, readonly) CGPoint goodJobPosition;

/**
 * @brief The button identifier for the tweet-send action.
 * @ghidraAddress 0x205b34
 */
@property(nonatomic, readonly) unsigned int twitterSendButtonID;

/**
 * @brief The position of the tweet-send button, derived from @c twitterSendButtonID .
 * @ghidraAddress 0x205b3c
 */
@property(nonatomic, readonly) CGPoint twitterBtnPosition;

/**
 * @brief The button identifier for the store-move action.
 * @ghidraAddress 0x205bac
 */
@property(nonatomic, readonly) unsigned int storeMoveButtonID;

/**
 * @brief The position of the store-move button, derived from @c storeMoveButtonID .
 * @ghidraAddress 0x205bb4
 */
@property(nonatomic, readonly) CGPoint storeMoveBtnPosition;

#pragma mark - Drawing

/**
 * @brief Draws one frame, dispatching on the render state and flushing every atlas.
 * @ghidraAddress 0x206744
 */
- (void)draw;

/**
 * @brief Draws debug text glyph-by-glyph from the debug-font sheet.
 * @param text The C string to draw.
 * @param pos The top-left position to draw it at.
 * @param alpha The opacity.
 * @ghidraAddress 0x206c14
 */
- (void)drawDebugText:(nullable const char *)text pos:(CGPoint)pos alpha:(float)alpha;

/**
 * @brief The rectangle of the result-screen music bar.
 * @return The music-bar rectangle.
 * @ghidraAddress 0x202390
 */
- (CGRect)getMusicBarRect;

/**
 * @brief Draws a clipped sprite: appends a quad drawing sprite @p clip into @p drawArea , clipped
 * to
 *        @p drawPosition , skipping the draw entirely when nothing is visible.
 * @param clip The sprite index.
 * @param drawPosition The clip window's top-left corner.
 * @param drawArea The destination rectangle before clipping.
 * @param alpha The opacity.
 * @ghidraAddress 0x20086c
 */
- (void)drawClip:(int)clip
    drawPosition:(CGPoint)drawPosition
        drawArea:(CGRect)drawArea
           alpha:(float)alpha;

/**
 * @brief Draws the start-mark intro: each first-marker panel's clipped frame glyphs and its centre
 *        glyph, animating in and advancing @c startMarkFrame .
 * @param alpha The overall opacity multiplier.
 * @ghidraAddress 0x200a40
 */
- (void)renderStartMark:(float)alpha;

/**
 * @brief Draws the 4x4 marker grid, the hold markers, and the first-marker highlight.
 * @ghidraAddress 0x200db4
 */
- (void)renderMarker;

/**
 * @brief Draws the knit beat background, schedules and advances the knit burst effects, and draws
 *        the active effect sprites.
 * @ghidraAddress 0x201124
 */
- (void)renderBG;

/**
 * @brief Draws the beat-background shutter bars, tweening the shutter-open amount.
 * @param animate Whether the shutter-open amount is advanced this frame.
 * @ghidraAddress 0x2015b4
 */
- (void)renderShutter:(BOOL)animate;

/**
 * @brief Draws the combo counter and its cut-in burst.
 * @param combo The current combo count.
 * @param alpha The opacity.
 * @ghidraAddress 0x20186c
 */
- (void)renderCombo:(unsigned int)combo alpha:(float)alpha;

/**
 * @brief Draws the score digits animating up from a previous value (the new-record score).
 * @param score The target score.
 * @param point The top-left anchor.
 * @param alpha The opacity.
 * @ghidraAddress 0x201cc0
 */
- (void)renderUpdatedScore:(unsigned int)score atPoint:(CGPoint)point alpha:(double)alpha;

/**
 * @brief Draws the running score, tweening the shown value toward the target.
 * @param score The player's score.
 * @param point The top-left anchor.
 * @param alpha The opacity.
 * @ghidraAddress 0x201e60
 */
- (void)renderScore:(unsigned int)score atPoint:(CGPoint)point alpha:(double)alpha;

/**
 * @brief Draws the partner's score row during a session play.
 * @param score The partner's score.
 * @param point The top-left anchor.
 * @param scale The horizontal scale.
 * @param alpha The opacity.
 * @ghidraAddress 0x202060
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
 * @ghidraAddress 0x2023a8
 */
- (void)renderMusicBar:(CGPoint)pos timeline:(BOOL)timeline alpha:(double)alpha;

/**
 * @brief Draws the tune-info panel: the jacket artwork, the tune name, and the difficulty and
 * level.
 * @param pos The panel's top-left corner.
 * @param artworkSize The jacket artwork edge length.
 * @param alpha The opacity.
 * @ghidraAddress 0x202748
 */
- (void)renderTuneInfo:(CGPoint)pos artworkSize:(double)artworkSize alpha:(double)alpha;

/**
 * @brief Advances and draws the knit upper background: triggers a wave rise under each held button,
 *        then renders the wave layers.
 * @param isResult Whether a result is being shown.
 * @ghidraAddress 0x20293c
 */
- (void)renderUpperBG:(BOOL)isResult;

/**
 * @brief Draws the upper region: the tune-info panel, the music bar, the score, and the partner
 *        score.
 * @ghidraAddress 0x202ad4
 */
- (void)renderUpper;

/**
 * @brief Draws the 4x4 on-screen button grid, lighting pressed buttons.
 * @ghidraAddress 0x202c8c
 */
- (void)renderButtons;

/**
 * @brief Draws the pre-start intro: the background, upper region, tune info, score, music bar, and
 *        buttons cued in over frames.
 * @ghidraAddress 0x203018
 */
- (void)renderPreStart;

/**
 * @brief Draws the ready/go countdown.
 * @ghidraAddress 0x203240
 */
- (void)renderReadyGo;

/**
 * @brief Draws the full-combo flourish.
 * @param animFrame The animation frame counter.
 * @param isResult Whether the flourish is drawn on the result screen (which offsets the frame).
 * @ghidraAddress 0x203a70
 */
- (void)renderFullcombo:(int)animFrame isResult:(BOOL)isResult;

/**
 * @brief Draws the finish banner and, once done, loads the result texture off-thread.
 * @ghidraAddress 0x203fb0
 */
- (void)renderFinish;

/**
 * @brief Draws the excellent (perfect-score) result flourish.
 * @param animFrame The animation frame counter.
 * @return Whether the animation has finished.
 * @ghidraAddress 0x2042e4
 */
- (BOOL)renderExcellent:(unsigned int)animFrame;

/**
 * @brief Draws the rank rating graphic.
 * @param animFrame The animation frame counter.
 * @ghidraAddress 0x204dd0
 */
- (void)renderRating:(unsigned int)animFrame;

/**
 * @brief Draws the cleared result graphic.
 * @param animFrame The animation frame counter.
 * @return Whether the animation has finished.
 * @ghidraAddress 0x2051b8
 */
- (BOOL)renderCleared:(unsigned int)animFrame;

/**
 * @brief Draws the failed result graphic.
 * @param animFrame The animation frame counter.
 * @return Whether the animation has finished.
 * @ghidraAddress 0x205628
 */
- (BOOL)renderFailed:(unsigned int)animFrame;

/**
 * @brief Draws the result screen: the flourish, the score, the rating, the new-record banner, and
 *        the action marks.
 * @ghidraAddress 0x205c24
 */
- (void)renderResult;

#pragma mark - Textures

/**
 * @brief The first ready/go atlas texture.
 * @ghidraAddress 0x206fe8 (getter), 0x206ff8 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texReady0;

/**
 * @brief The second ready/go atlas texture.
 * @ghidraAddress 0x20700c (getter), 0x20701c (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texReady1;

/**
 * @brief The front atlas texture: the field, buttons, and lines.
 * @ghidraAddress 0x207030 (getter), 0x207040 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texFront;

/**
 * @brief The marker atlas texture.
 * @ghidraAddress 0x207054 (getter), 0x207064 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texMarker;

/**
 * @brief The hold-marker atlas texture.
 * @ghidraAddress 0x207078 (getter), 0x207088 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texHoldMarker;

/**
 * @brief The combo-number atlas texture.
 * @ghidraAddress 0x20709c (getter), 0x2070ac (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texCombo;

/**
 * @brief The result-screen atlas texture.
 * @ghidraAddress 0x2070c0 (getter), 0x2070d0 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texResult;

/**
 * @brief The result-screen background atlas texture.
 * @ghidraAddress 0x2070e4 (getter), 0x2070f4 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texResultBg;

/**
 * @brief The knit beat-background atlas texture.
 * @ghidraAddress 0x207108 (getter), 0x207118 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texBeatBg;

/**
 * @brief The debug-font glyph sheet.
 * @ghidraAddress 0x20712c (getter), 0x20713c (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texDebugFont;

/**
 * @brief The pre-loaded "GO" voice player, prepared on entry to the ready-go state.
 * @ghidraAddress 0x207150 (getter), 0x207160 (setter)
 */
@property(nonatomic, strong, nullable) AVAudioPlayer *sePlayerGo;

/**
 * @brief The six knit wave-layer atlas textures.
 * @ghidraAddress 0x207174 (getter), 0x207184 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray<Texture2D *> *texWaveAr;

/**
 * @brief The knit upper-background wave decoration.
 * @ghidraAddress 0x207198 (getter), 0x2071a8 (setter)
 */
@property(nonatomic, strong, nullable) UpperBGKnit *upperBgKnt;

/**
 * @brief A knit background effect sprite.
 * @ghidraAddress 0x2071bc (getter), 0x2071cc (setter)
 */
@property(nonatomic, strong, nullable) EffectBgKnit *effectBgKnt;

/**
 * @brief The live knit background effect sprites.
 * @ghidraAddress 0x2071e0 (getter), 0x2071f0 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray<EffectBgKnit *> *arrayBgEff;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
