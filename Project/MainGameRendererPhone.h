/** @file
 * The iPhone in-game play renderer.
 *
 * Reconstructed from Ghidra program Jubeat (class MainGameRendererPhone, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * @c MainGameRendererPhone is the phone-idiom concrete subclass of @c MainGameRenderer : the
 * OpenGL ES renderer that fills in every drawing override the abstract base leaves empty. It draws
 * the play-field background and combo burst, the note markers and hold markers, the 4x4 button
 * grid, the score and bonus digits, the difficulty music bar and tune information, the pre-start
 * and ready/go countdowns, and the finish and result screens. Its layout constants are the phone
 * values; the parallel @c MainGameRendererPad carries the pad values. It branches on two cached
 * device flags — @c isRetina (2x sprites) and @c is4Inch (the taller four-inch phone, whose game
 * area is pushed down by @c buttonMarginForScreen40 / @c upperBgHeight40 ).
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "MainGameRenderer.h"

@class Texture2D;
@class RendererConf;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone-idiom concrete in-game renderer.
 */
@interface MainGameRendererPhone : MainGameRenderer {
@protected
    BOOL isRetina; /*!< Cached phone-retina flag, sampled once at init. */             // +0x168
    BOOL is4Inch; /*!< Cached four-inch-aspect flag, sampled once at init. */          // +0x169
    unsigned int frame; /*!< The per-state frame counter, advanced each draw. */       // +0x16c
    unsigned int subStateChangeFrame; /*!< The frame the sub-state last changed on. */ // +0x170
    Texture2D *texFront; /*!< The front atlas: chips, buttons, tune info, marks. */    // +0x178
    Texture2D *texMarker; /*!< The note-marker atlas, unzipped from the archive. */    // +0x180
    Texture2D *texHoldMarker; /*!< The hold-marker atlas. */                           // +0x188
    Texture2D *texCombo; /*!< The combo-number and background atlas. */                // +0x190
    Texture2D *texReady; /*!< The ready/go countdown atlas. */                         // +0x198
    Texture2D *texRating; /*!< The result-screen rating atlas. */                      // +0x1a0
    Texture2D *texClear0; /*!< The first cleared-screen atlas. */                      // +0x1a8
    Texture2D *texClear1; /*!< The second cleared-screen atlas. */                     // +0x1b0
    Texture2D *texClear2; /*!< The third cleared-screen atlas. */                      // +0x1b8
    Texture2D *texDebugFont; /*!< The debug-font atlas. */                             // +0x1c0
    int markerDir[kMainGameGridPanelCount]; /*!< Per-panel marker spin direction. */   // +0x1c8
}

/**
 * @brief Initialises the renderer, caching the phone-retina and four-inch-aspect device flags.
 * @return The initialised renderer, or @c nil.
 * @ghidraAddress 0x10a3c0
 */
- (instancetype)init;

#pragma mark - Textures

/**
 * @brief Loads every play-session texture: the debug font, the ready atlas, the front atlas (with
 *        the difficulty, music-bar, and level words, the note markers unzipped from the marker
 *        archive, the jacket artwork, the index image, and an optional partner-name label), the
 *        hold-marker atlas (and its @c HoldMarkerRender ), and the combo atlas. The selector
 *        spelling @c loadTexure: is the binary's own.
 * @param conf The renderer configuration.
 * @param artwork The jacket artwork image.
 * @param index An additional index image composited into the front atlas.
 * @ghidraAddress 0x10a490
 */
- (void)loadTexure:(nullable RendererConf *)conf
           artwork:(nullable UIImage *)artwork
             index:(nullable UIImage *)index;

/**
 * @brief Rebuilds the result-screen rating atlas for a rank.
 * @param rank The tune's rank, selecting the rating resource.
 * @ghidraAddress 0x10b680
 */
- (void)loadRatingTex:(short)rank;

/**
 * @brief Releases the debug-font, front, ready, rating, and three cleared-screen textures. It does
 *        not release the marker, hold-marker, or combo textures, matching the binary.
 * @ghidraAddress 0x10b8e8
 */
- (void)releaseTexture;

#pragma mark - Play lifecycle

/**
 * @brief Sets the high-level render state. Entering the result state (5) loads the rating and
 *        cleared-screen textures and starts the result BGM; the reset states (0 and 2) clear the
 *        per-frame combo and shutter counters. Every path resets the frame counter and chains up.
 * @param state The state to enter.
 * @ghidraAddress 0x10b98c
 */
- (void)setState:(unsigned int)state;

/**
 * @brief Clears the ready texture and enters the playing state (3).
 * @ghidraAddress 0x10bcf4
 */
- (void)startPlay;

/**
 * @brief Marks the session finished when it is in the result state (5).
 * @ghidraAddress 0x10bd34
 */
- (void)endResult;

/**
 * @brief The ready-go countdown duration, in seconds.
 * @return The countdown duration.
 * @ghidraAddress 0x10e798
 */
- (double)durationOfReadyGo;

#pragma mark - Drawing

/**
 * @brief Draws the note markers over the sixteen-panel grid, spinning random-direction markers,
 *        drawing the lead-in fade, and delegating the hold markers to @c HoldMarkerRender .
 * @ghidraAddress 0x10bd80
 */
- (void)renderMarker;

/**
 * @brief Draws the play-field background: the tension shutter, the combo burst animation, and the
 *        shutter halves that slide with the beat.
 * @ghidraAddress 0x10c17c
 */
- (void)renderBG;

/**
 * @brief Draws the combo number and its burst and cut-in animations.
 * @param combo The current combo count.
 * @ghidraAddress 0x10c78c
 */
- (void)renderCombo:(unsigned int)combo;

/**
 * @brief Draws the score digits tweening up towards a target, with a board and per-digit scale.
 * @param score The target score.
 * @param point The digits' origin.
 * @param alpha The opacity.
 * @param scale The per-digit scale.
 * @param boardY The score board's vertical position.
 * @ghidraAddress 0x10cb34
 */
- (void)renderUpdatedScore:(unsigned int)score
                   atPoint:(CGPoint)point
                     alpha:(double)alpha
                     scale:(double)scale
                    boardY:(float)boardY;

/**
 * @brief Draws the player and partner scores at a point, with a horizontal scale and alpha.
 * @param score The player's score.
 * @param partnerScore The partner's score.
 * @param point The score block's origin.
 * @param scaleH The horizontal scale.
 * @param alpha The opacity.
 * @ghidraAddress 0x10cd38
 */
- (void)renderScore:(unsigned int)score
       partnerScore:(unsigned int)partnerScore
            atPoint:(CGPoint)point
             scaleH:(double)scaleH
              alpha:(double)alpha;

/**
 * @brief Draws the final-bonus digits at a point.
 * @param bonus The bonus value.
 * @param point The digits' origin.
 * @param alpha The opacity.
 * @ghidraAddress 0x10d418
 */
- (void)renderBonus:(unsigned int)bonus atPoint:(CGPoint)point alpha:(double)alpha;

/**
 * @brief Draws the difficulty music bar: the leading difficulty chip, one chip per bar cell, and
 *        the optional timeline cursor.
 * @param position The bar's origin.
 * @param timeline Whether to draw the timeline cursor.
 * @param alpha The opacity.
 * @ghidraAddress 0x10d578
 */
- (void)renderMusicBar:(CGPoint)position timeline:(BOOL)timeline alpha:(double)alpha;

/**
 * @brief Draws the tune information block: jacket, title, difficulty word, and level.
 * @param position The block's origin.
 * @param artworkSize The jacket's square size.
 * @param alpha The opacity.
 * @ghidraAddress 0x10d8e8
 */
- (void)renderTuneInfo:(CGPoint)position artworkSize:(double)artworkSize alpha:(double)alpha;

/**
 * @brief Draws the upper background band, and on the four-inch phone the tiled filler above and
 *        below it.
 * @param y The band's bottom edge, in points.
 * @ghidraAddress 0x10da6c
 */
- (void)renderUpperBG:(double)y;

/**
 * @brief Draws the upper region: the tune information, the live music bar, and the score.
 * @ghidraAddress 0x10dbf8
 */
- (void)renderUpper;

/**
 * @brief Draws the 4x4 button grid, highlighting pressed panels.
 * @param offset The grid's vertical offset, in points.
 * @ghidraAddress 0x10de28
 */
- (void)renderButtons:(double)offset;

/**
 * @brief Draws the pre-start intro.
 * @ghidraAddress 0x10e340
 */
- (void)renderPreStart;

/**
 * @brief Draws a soft circle of the given size at a point.
 * @param center The circle's centre.
 * @param size The circle's diameter, in points.
 * @param alpha The opacity.
 * @ghidraAddress 0x10e69c
 */
- (void)renderCircle:(CGPoint)center size:(double)size alpha:(double)alpha;

/**
 * @brief Draws the ready/go countdown, playing the ready and go sounds on their frames.
 * @ghidraAddress 0x10e7a4
 */
- (void)renderReadyGo;

/**
 * @brief Draws the start-mark banner.
 * @ghidraAddress 0x10efd4
 */
- (void)renderStartMark;

/**
 * @brief Draws the finish transition.
 * @ghidraAddress 0x10f13c
 */
- (void)renderFinish;

/**
 * @brief Draws the cleared-screen animation for a rank.
 * @param rank The tune's rank.
 * @param centerY The animation's vertical centre.
 * @return Whether the animation is still running.
 * @ghidraAddress 0x10f4e4
 */
- (BOOL)renderCleared:(unsigned int)rank centerY:(double)centerY;

/**
 * @brief Draws the failed-screen animation for a rank.
 * @param rank The tune's rank.
 * @param centerY The animation's vertical centre.
 * @return Whether the animation is still running.
 * @ghidraAddress 0x10f82c
 */
- (BOOL)renderFailed:(unsigned int)rank centerY:(double)centerY;

/**
 * @brief Draws the result screen: the cleared or failed animation, the score, bonus, records, and
 *        the action buttons.
 * @ghidraAddress 0x10fe00
 */
- (void)renderResult;

/**
 * @brief Draws the whole play frame, dispatching on the state to the render methods and flushing
 *        every texture atlas.
 * @ghidraAddress 0x110fdc
 */
- (void)draw;

/**
 * @brief Draws a run of debug text from the debug-font atlas, advancing per glyph and wrapping on
 *        newlines.
 * @param text The C string to draw.
 * @param pos The starting position.
 * @param alpha The opacity.
 * @ghidraAddress 0x1113f0
 */
- (void)drawDebugText:(nullable const char *)text pos:(CGPoint)pos alpha:(float)alpha;

/**
 * @brief Notifies the renderer that a replay ended, clearing the replay-playing flag.
 * @ghidraAddress 0x111568
 */
- (void)replayEnd;

/**
 * @brief Reacts to a replay selection: on a downloaded custom tune with music, swaps the front
 *        atlas's sprite 8 to the replay chip and fades the good-job overlay out.
 * @ghidraAddress 0x111578
 */
- (void)replaySelect;

#pragma mark - Layout override points

/**
 * @brief The vertical offset of the button area, in points. Non-zero only during the result
 *        state's opening slide.
 * @ghidraAddress 0x10fb28
 */
@property(nonatomic, readonly) double buttonAreaOffset;

/**
 * @brief The vertical offset of the game area, in points. Pushed down on the four-inch phone.
 * @ghidraAddress 0x10fb94
 */
@property(nonatomic, readonly) double gameAreaOffset;

#pragma mark - Button override points

/**
 * @brief The button identifier for the end action. Returns 11 for the phone.
 * @ghidraAddress 0x10fbd4
 */
@property(nonatomic, readonly) unsigned int endButtonID;

/**
 * @brief The button identifier for the evaluate action. Returns 10 for the phone.
 * @ghidraAddress 0x10fbdc
 */
@property(nonatomic, readonly) unsigned int evaluateButtonID;

/**
 * @brief The button identifier for the good-job action. Returns 9 for the phone.
 * @ghidraAddress 0x10fbe4
 */
@property(nonatomic, readonly) unsigned int goodJobButtonID;

/**
 * @brief The position of the good-job overlay, derived from @c goodJobButtonID .
 * @ghidraAddress 0x10fbec
 */
@property(nonatomic, readonly) CGPoint goodJobPosition;

/**
 * @brief The button identifier for the tweet-send action. Returns 10 for the phone.
 * @ghidraAddress 0x10fc98
 */
@property(nonatomic, readonly) unsigned int twitterSendButtonID;

/**
 * @brief The position of the tweet-send button, derived from @c twitterSendButtonID .
 * @ghidraAddress 0x10fca0
 */
@property(nonatomic, readonly) CGPoint twitterBtnPosition;

/**
 * @brief The button identifier for the store-move action. Returns 10 for the phone.
 * @ghidraAddress 0x10fd4c
 */
@property(nonatomic, readonly) unsigned int storeMoveButtonID;

/**
 * @brief The position of the store-move button, derived from @c storeMoveButtonID .
 * @ghidraAddress 0x10fd54
 */
@property(nonatomic, readonly) CGPoint storeMoveBtnPosition;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
