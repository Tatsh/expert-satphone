/**
 * @file
 * @brief The iPhone edit-mode note renderer.
 *
 * Reconstructed from Ghidra program Jubeat (class EditNoteRendererPhone, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * @c EditNoteRendererPhone is the phone-idiom concrete subclass of @c EditNoteRenderer : the
 * OpenGL ES 1.1 renderer that fills in every drawing override the superclass leaves empty. It
 * draws the shutter background, the 4x4 button grid, the note markers, the music bar, the tune
 * information, the pre-start and ready/go countdowns, and the full-combo result. Its layout
 * constants are the phone values; the parallel @c EditNoteRendererPad carries the pad values.
 */

#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "EditNoteRenderer.h"

@class Texture2D;
@class EffectBgKnit;
@class EditRendererConf;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The phone-idiom concrete edit-mode note renderer.
 */
@interface EditNoteRendererPhone : EditNoteRenderer {
@protected
    BOOL isRetina; /*!< Cached phone-retina flag, sampled once at init. */             // +0x60
    unsigned int frame; /*!< The per-state frame counter, advanced each draw. */       // +0x64
    unsigned int subStateChangeFrame; /*!< The frame the sub-state last changed on. */ // +0x68
    float lastHakuPhase; /*!< The beat phase as of the last frame. */                  // +0x6c
    unsigned int effFrame; /*!< The knit-effect animation frame. */                    // +0x70
    unsigned int effSlot; /*!< The next knit-effect slot to fill. */                   // +0x74
    float bounceEnergy; /*!< The residual bounce energy of the beat effect. */         // +0x78
}

/**
 * @brief Initialises the renderer, building an empty background-effect array and caching the
 *        phone-retina flag.
 * @return The initialised renderer, or @c nil.
 * @ghidraAddress 0x20ea28
 */
- (instancetype)init;

#pragma mark - Textures

/**
 * @brief Loads every edit-session texture and sound: the debug font, the knit beat background and
 *        its two colour variants, the ready and go textures, the front atlas (with the level,
 *        start, and end marks and the note markers unzipped from the marker archive), the jacket
 *        artwork, and the index image. The selector spelling @c loadTexure: is the binary's own.
 * @param conf The edit renderer configuration.
 * @param artwork The jacket artwork image.
 * @param index An additional index image.
 * @ghidraAddress 0x20eaf4
 */
- (void)loadTexure:(nullable EditRendererConf *)conf
           artwork:(nullable UIImage *)artwork
             index:(nullable UIImage *)index;

/**
 * @brief Releases the debug-font, ready, front, and beat-background textures. It does not release
 *        the note-marker texture, matching the binary.
 * @ghidraAddress 0x20fdf4
 */
- (void)releaseTexture;

#pragma mark - Play lifecycle

/**
 * @brief Sets the high-level render state, resetting the per-frame counters and preparing the
 *        state's audio (loading the go sound for the ready state and the result BGM for the
 *        result state).
 * @param state The state to enter.
 * @ghidraAddress 0x20fe6c
 */
- (void)setState:(unsigned int)state;

/**
 * @brief Enters the ready state and clears the go-sound player.
 * @ghidraAddress 0x2101ac
 */
- (void)startPlay;

/**
 * @brief Marks the session finished when it is in the result state.
 * @ghidraAddress 0x2101e8
 */
- (void)endResult;

#pragma mark - Drawing

/**
 * @brief Draws one clipped note chip from the front atlas, clamping the chip to the draw area.
 * @param drawIndex The sprite index in the front atlas.
 * @param drawPosition The chip's origin.
 * @param drawArea The clip rectangle the chip is confined to.
 * @param alpha The opacity.
 * @ghidraAddress 0x210234
 */
- (void)drawClip:(int)drawIndex
    drawPosition:(CGPoint)drawPosition
        drawArea:(CGRect)drawArea
           alpha:(float)alpha;

/**
 * @brief Draws the five beat-background shutter columns, top and bottom halves, sliding by the
 *        shutter-open animation.
 * @ghidraAddress 0x210438
 */
- (void)renderMarker;

/**
 * @brief Advances and draws the shutter animation across the five beat-background columns.
 * @param animate Whether to advance the shutter-open value this frame.
 * @ghidraAddress 0x210594
 */
- (void)renderShutter:(BOOL)animate;

/**
 * @brief Records the combo count for the next frame. This phone override draws nothing else.
 * @param combo The current combo count.
 * @param alpha The opacity.
 * @ghidraAddress 0x210788
 */
- (void)renderCombo:(unsigned int)combo alpha:(float)alpha;

/**
 * @brief Draws the difficulty music bar: the leading difficulty chip, one chip per bar cell, and
 *        the optional timeline cursor.
 * @param position The bar's origin.
 * @param timeline Whether to draw the timeline cursor.
 * @param alpha The opacity.
 * @ghidraAddress 0x21079c
 */
- (void)renderMusicBar:(CGPoint)position timeline:(BOOL)timeline alpha:(double)alpha;

/**
 * @brief Draws the tune information block: jacket, title, difficulty word, and level.
 * @param position The block's origin.
 * @param artworkSize The jacket's square size.
 * @param alpha The opacity.
 * @ghidraAddress 0x210b48
 */
- (void)renderTuneInfo:(CGPoint)position artworkSize:(double)artworkSize alpha:(double)alpha;

/**
 * @brief Draws the upper background. This phone override does nothing.
 * @param arg Unused.
 * @ghidraAddress 0x210ddc
 */
- (void)renderUpperBG:(BOOL)arg;

/**
 * @brief Draws the upper region: the tune information and the (optionally live) music bar.
 * @ghidraAddress 0x210de0
 */
- (void)renderUpper;

/**
 * @brief Draws the 4x4 button grid, highlighting pressed panels.
 * @ghidraAddress 0x210e5c
 */
- (void)renderButtons;

/**
 * @brief Draws the pre-start intro: shutter, sliding tune information, fading music bar, and
 *        buttons, playing the start sound and advancing the sub-state at the end of the intro.
 * @ghidraAddress 0x210fe8
 */
- (void)renderPreStart;

/**
 * @brief Draws the ready/go countdown, playing the ready and go sounds on their frames and
 *        finishing the sub-state when the countdown ends.
 * @ghidraAddress 0x21114c
 */
- (void)renderReadyGo;

/**
 * @brief Draws the full-combo banner, sliding and squashing over the animation and playing the
 *        full-combo sounds on the result variant.
 * @param frameArg The animation frame.
 * @param isResult Whether the result variant (offset by the intro length) is drawn.
 * @ghidraAddress 0x211978
 */
- (void)renderFullcombo:(int)frameArg isResult:(BOOL)isResult;

/**
 * @brief Draws the finish region. This phone override does nothing.
 * @ghidraAddress 0x211ea0
 */
- (void)renderFinish;

/**
 * @brief The vertical offset of the button area, in points. Returns 0 for the phone.
 * @return The button-area offset.
 * @ghidraAddress 0x211ea4
 */
- (double)buttonAreaOffset;

/**
 * @brief Draws the whole edit frame, dispatching on the state to the render methods and flushing
 *        every texture atlas.
 * @ghidraAddress 0x211eb4
 */
- (void)draw;

/**
 * @brief Draws a run of debug text from the debug-font atlas, advancing per glyph and wrapping on
 *        newlines.
 * @param text The C string to draw.
 * @param pos The starting position.
 * @param alpha The opacity.
 * @ghidraAddress 0x212158
 */
- (void)drawDebugText:(nullable const char *)text pos:(CGPoint)pos alpha:(float)alpha;

/**
 * @brief The rectangle of the edit timeline, in phone points.
 * @return The timeline rectangle.
 * @ghidraAddress 0x212310
 */
- (CGRect)getTimeLineRect;

#pragma mark - Read-only accessors

/**
 * @brief The button identifier for the end action. Returns 15 for the phone.
 * @ghidraAddress 0x211eac
 */
@property(nonatomic, readonly) unsigned int endButtonID;

#pragma mark - Textures and effects

/**
 * @brief The ready-countdown texture.
 * @ghidraAddress 0x212330 (getter), 0x212340 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texReady0;

/**
 * @brief The go-countdown texture.
 * @ghidraAddress 0x212360 (getter), 0x212370 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texReady1;

/**
 * @brief The front atlas: chips, buttons, level, marks, and tune information.
 * @ghidraAddress 0x212380 (getter), 0x212390 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texFront;

/**
 * @brief The note-marker atlas, unzipped from the marker archive.
 * @ghidraAddress 0x2123a0 (getter), 0x2123b0 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texMarker;

/**
 * @brief The knit beat-background atlas.
 * @ghidraAddress 0x2123c0 (getter), 0x2123d0 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texBeatBg;

/**
 * @brief The debug-font atlas.
 * @ghidraAddress 0x2123f0 (getter), 0x212400 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texDebugFont;

/**
 * @brief The go-sound player, prepared lazily when the ready state is entered.
 * @ghidraAddress 0x212410 (getter), 0x212420 (setter)
 */
@property(nonatomic, strong, nullable) AVAudioPlayer *sePlayerGo;

/**
 * @brief The current knit background effect.
 * @ghidraAddress 0x212430 (getter), 0x212440 (setter)
 */
@property(nonatomic, strong, nullable) EffectBgKnit *effectBgKnt;

/**
 * @brief The array of active knit background effects.
 * @ghidraAddress 0x212450 (getter), 0x212460 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *arrayBgEff;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
