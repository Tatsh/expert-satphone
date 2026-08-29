/**
 * @file
 * The iPad in-game renderer: the concrete @c MainGameRenderer subclass that draws a play
 * session on the pad idiom.
 *
 * Reconstructed from Ghidra program Jubeat (class MainGameRendererPad, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * @c MainGameRendererPad fills in every drawing and layout override point that
 * @c MainGameRenderer leaves empty: it loads the idiom's atlas textures, draws the pulsing
 * background, the 4x4 marker grid and hold markers, the combo counter, the running score and
 * bonus, the tune-info panel, the music bar, the on-screen button grid, the ready/go countdown,
 * the start and finish marks, and the cleared/failed result screen. Every drawing method batches
 * quads into the atlas textures (@c texBG , @c texFront , @c texMarker , @c texCombo ,
 * @c texHoldMarker , @c texReady , @c texRating , @c texClear0 .. @c texClear2 , and the
 * @c texDebugFont glyph sheet), which the top-level @c -draw flushes with @c -commitDraw . Its
 * layout constants are the pad's; the phone sibling is @c MainGameRendererPhone .
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "MainGameRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@class Texture2D;
@class RendererConf;

/**
 * The pad in-game renderer.
 */
@interface MainGameRendererPad : MainGameRenderer {
@protected
    unsigned int frame;                     /*!< The frames elapsed in the current render state. */
    unsigned int subStateChangeFrame;       /*!< The frame the sub-state last changed on. */
    int markerDir[kMainGameGridPanelCount]; /*!< The random-mode marker direction per panel. */
}

#pragma mark - Lifecycle

/**
 * Initialises the pad renderer, chaining to the superclass.
 * @return The initialised renderer, or @c nil.
 * @ghidraAddress 0x102758
 */
- (instancetype)init;

/**
 * Releases the session textures, then chains to the superclass deallocation.
 * @ghidraAddress 0x109ed4
 */
- (void)dealloc;

#pragma mark - Textures

/**
 * Loads the pad session atlases: background, front, marker, combo, hold-marker, ready, and
 *        debug-font textures, and builds the hold-marker sub-renderer. The selector spelling
 *        @c loadTexure: (a missing "t") is the binary's own.
 * @param conf The renderer configuration describing the tune, difficulty, and marker.
 * @param artwork The jacket artwork image.
 * @param index An additional texture image the renderer composites in.
 * @ghidraAddress 0x102790
 */
- (void)loadTexure:(nullable RendererConf *)conf
           artwork:(nullable UIImage *)artwork
             index:(nullable UIImage *)index;

/**
 * Loads the rating (rank judgement) texture for a rank tier.
 * @param rank The score rank tier, 0..8; ranks below 9 select a per-rank judgement resource.
 * @ghidraAddress 0x103e6c
 */
- (void)loadRatingTex:(short)rank;

/**
 * Releases every session texture.
 * @ghidraAddress 0x104168
 */
- (void)releaseTexture;

#pragma mark - State

/**
 * Sets the render state, resetting per-state counters and, in the result state, loading the
 *        rating and cleared/failed textures and starting the result BGM.
 * @param state The high-level render state.
 * @ghidraAddress 0x104258
 */
- (void)setState:(unsigned int)state;

#pragma mark - Play lifecycle

/**
 * Begins playback: clears the ready texture and moves to state 3.
 * @ghidraAddress 0x1045b4
 */
- (void)startPlay;

/**
 * Ends the result screen: in the result state sets the finished sub-state.
 * @ghidraAddress 0x1045f0
 */
- (void)endResult;

/**
 * Selects a replay: for a downloaded custom tune with music, arms the replay and fades the
 *        good-job overlay in.
 * @ghidraAddress 0x109f34
 */
- (void)replaySelect;

/**
 * Ends a replay, clearing the replay-playing flag.
 * @ghidraAddress 0x109f24
 */
- (void)replayEnd;

/**
 * The ready-go countdown duration, in seconds.
 * @return The countdown duration, in seconds.
 * @ghidraAddress 0x106f6c
 */
- (double)durationOfReadyGo;

#pragma mark - Layout

/**
 * The vertical offset of the button area. In the result state it rises over the first 20
 *        frames.
 * @return The button-area offset, in points.
 * @ghidraAddress 0x1085f0
 */
- (double)buttonAreaOffset;

/**
 * The vertical offset of the game area, in points.
 * @return The game-area offset.
 * @ghidraAddress 0x10865c
 */
- (double)gameAreaOffset;

#pragma mark - Buttons

/**
 * The button identifier for the end action.
 * @ghidraAddress 0x108668
 */
@property(nonatomic, readonly) unsigned int endButtonID;

/**
 * The button identifier for the evaluate action.
 * @ghidraAddress 0x108670
 */
@property(nonatomic, readonly) unsigned int evaluateButtonID;

/**
 * The button identifier for the good-job action.
 * @ghidraAddress 0x108678
 */
@property(nonatomic, readonly) unsigned int goodJobButtonID;

/**
 * The centre position of the good-job overlay, derived from @c goodJobButtonID .
 * @ghidraAddress 0x108680
 */
@property(nonatomic, readonly) CGPoint goodJobPosition;

/**
 * The button identifier for the tweet-send action.
 * @ghidraAddress 0x1086fc
 */
@property(nonatomic, readonly) unsigned int twitterSendButtonID;

/**
 * The position of the tweet-send button, derived from @c twitterSendButtonID .
 * @ghidraAddress 0x108704
 */
@property(nonatomic, readonly) CGPoint twitterBtnPosition;

/**
 * The button identifier for the store-move action.
 * @ghidraAddress 0x108780
 */
@property(nonatomic, readonly) unsigned int storeMoveButtonID;

/**
 * The position of the store-move button, derived from @c storeMoveButtonID .
 * @ghidraAddress 0x108788
 */
@property(nonatomic, readonly) CGPoint storeMoveBtnPosition;

#pragma mark - Drawing

/**
 * Draws one frame, dispatching on the render state and flushing every atlas.
 * @ghidraAddress 0x109938
 */
- (void)draw;

/**
 * Draws debug text glyph-by-glyph from the debug-font sheet.
 * @param text The C string to draw.
 * @param pos The top-left position to draw it at.
 * @param alpha The opacity.
 * @ghidraAddress 0x109d6c
 */
- (void)drawDebugText:(nullable const char *)text pos:(CGPoint)pos alpha:(float)alpha;

/**
 * Draws the pulsing background, the combo-burst effect, and the shutter.
 * @ghidraAddress 0x104bcc
 */
- (void)renderBG;

/**
 * Draws the 4x4 marker grid, the marker hit frames, and the hold markers.
 * @ghidraAddress 0x10478c
 */
- (void)renderMarker;

/**
 * Draws one panel's marker hit frame.
 * @param point The panel's top-left corner.
 * @param alpha The opacity.
 * @ghidraAddress 0x10463c
 */
- (void)renderMarkFrame:(CGPoint)point alpha:(double)alpha;

/**
 * Draws the combo counter and its cut-in burst.
 * @param combo The current combo count.
 * @ghidraAddress 0x1052ac
 */
- (void)renderCombo:(unsigned int)combo;

/**
 * Draws the score digits animating up from a previous value.
 * @param score The target score.
 * @param point The top-left anchor.
 * @param alpha The opacity.
 * @param scale The horizontal scale.
 * @param boardY The score-board vertical position.
 * @ghidraAddress 0x1055cc
 */
- (void)renderUpdatedScore:(unsigned int)score
                   atPoint:(CGPoint)point
                     alpha:(double)alpha
                     scale:(double)scale
                    boardY:(float)boardY;

/**
 * Draws the running score and the partner's score.
 * @param score The player's score.
 * @param partnerScore The partner's score.
 * @param point The top-left anchor.
 * @param scaleH The horizontal scale.
 * @param alpha The opacity.
 * @ghidraAddress 0x10586c
 */
- (void)renderScore:(unsigned int)score
       partnerScore:(unsigned int)partnerScore
            atPoint:(CGPoint)point
             scaleH:(double)scaleH
              alpha:(double)alpha;

/**
 * Draws the bonus number.
 * @param bonus The bonus points.
 * @param point The top-left anchor.
 * @param alpha The opacity.
 * @ghidraAddress 0x105e20
 */
- (void)renderBonus:(unsigned int)bonus atPoint:(CGPoint)point alpha:(double)alpha;

/**
 * Draws the result-screen music bar and its per-note markers.
 * @param pos The bar's top-left corner.
 * @param timeline Whether the play head is drawn.
 * @param alpha The opacity.
 * @ghidraAddress 0x105f74
 */
- (void)renderMusicBar:(CGPoint)pos timeline:(BOOL)timeline alpha:(double)alpha;

/**
 * Draws the tune-info panel: the jacket artwork and the tune name and artist.
 * @param pos The panel's top-left corner.
 * @param artworkSize The jacket artwork edge length.
 * @param alpha The opacity.
 * @ghidraAddress 0x1063b0
 */
- (void)renderTuneInfo:(CGPoint)pos artworkSize:(double)artworkSize alpha:(double)alpha;

/**
 * Draws the upper background band.
 * @param y The band's vertical position.
 * @param height The band's height.
 * @ghidraAddress 0x1065a0
 */
- (void)renderUpperBG:(double)y height:(double)height;

/**
 * Draws the upper region: the tune-info panel, the music bar, and the score.
 * @ghidraAddress 0x106678
 */
- (void)renderUpper;

/**
 * Draws the 4x4 on-screen button grid, lighting pressed buttons.
 * @param offsetY The vertical offset applied to the grid.
 * @ghidraAddress 0x106804
 */
- (void)renderButtons:(double)offsetY;

/**
 * Draws the pre-start intro: the field, upper region, and buttons cued in over frames.
 * @ghidraAddress 0x106b94
 */
- (void)renderPreStart;

/**
 * Draws a ring sprite scaled about a point.
 * @param point The centre point.
 * @param size The ring diameter.
 * @param alpha The opacity.
 * @ghidraAddress 0x106e00
 */
- (void)renderCircle:(CGPoint)point size:(double)size alpha:(double)alpha;

/**
 * Draws the ready/go countdown.
 * @ghidraAddress 0x106f78
 */
- (void)renderReadyGo;

/**
 * Draws the start-mark intro animation.
 * @ghidraAddress 0x107904
 */
- (void)renderStartMark;

/**
 * Draws the finish banner animation.
 * @ghidraAddress 0x107a98
 */
- (void)renderFinish;

/**
 * Draws the cleared result graphic.
 * @param animFrame The animation frame counter.
 * @param centerY The graphic's vertical centre.
 * @return Whether the animation is still running.
 * @ghidraAddress 0x107e44
 */
- (BOOL)renderCleared:(unsigned int)animFrame centerY:(double)centerY;

/**
 * Draws the failed result graphic.
 * @param animFrame The animation frame counter.
 * @param centerY The graphic's vertical centre.
 * @return Whether the animation is still running.
 * @ghidraAddress 0x10823c
 */
- (BOOL)renderFailed:(unsigned int)animFrame centerY:(double)centerY;

/**
 * Draws the result screen: the cleared/failed graphic, the score, the rating, and the
 *        action buttons.
 * @ghidraAddress 0x108804
 */
- (void)renderResult;

#pragma mark - Textures

/**
 * The background atlas texture.
 * @ghidraAddress 0x10a140 (getter), 0x10a150 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texBG;

/**
 * The front atlas texture: the field, buttons, and lines.
 * @ghidraAddress 0x10a164 (getter), 0x10a174 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texFront;

/**
 * The marker atlas texture.
 * @ghidraAddress 0x10a188 (getter), 0x10a198 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texMarker;

/**
 * The combo-number atlas texture.
 * @ghidraAddress 0x10a1ac (getter), 0x10a1bc (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texCombo;

/**
 * The hold-marker atlas texture.
 * @ghidraAddress 0x10a1d0 (getter), 0x10a1e0 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texHoldMarker;

/**
 * The ready/go and start-mark atlas texture.
 * @ghidraAddress 0x10a1f4 (getter), 0x10a204 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texReady;

/**
 * The rank-rating (judgement) atlas texture.
 * @ghidraAddress 0x10a218 (getter), 0x10a228 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texRating;

/**
 * The first cleared/failed result atlas texture.
 * @ghidraAddress 0x10a23c (getter), 0x10a24c (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texClear0;

/**
 * The second cleared/failed result atlas texture.
 * @ghidraAddress 0x10a260 (getter), 0x10a270 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texClear1;

/**
 * The third cleared/failed result atlas texture.
 * @ghidraAddress 0x10a284 (getter), 0x10a294 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texClear2;

/**
 * The debug-font glyph sheet.
 * @ghidraAddress 0x10a2a8 (getter), 0x10a2b8 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texDebugFont;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
