/** @file
 * The timing-adjust test view.
 *
 * Reconstructed from Ghidra program Jubeat (class AdjustTestView, image base 0x100000000); all
 * @ghidraAddress values are offsets relative to that image base. This class has no embedded
 * @c __FILE__ path, so it stays at the @c Project/ root.
 *
 * A @c CAEAGLLayer-backed @c UIView that previews the marker animation for the four jubeat panels
 * while the user tunes an audio offset. It owns an @c EAGLContext , a default framebuffer, and a
 * colour renderbuffer, and draws the loaded marker frames and the four panel buttons through a
 * ten-entry table of @c Texture2D sprite sheets. Playback is driven by a @c Sequence and the shared
 * @c AudioManager background-music player; @c -draw seeks the sequence to the current music
 * position offset by @c adjustTime and renders one frame per panel.
 */

#import <OpenGLES/EAGL.h>
#import <UIKit/UIKit.h>

@class Sequence;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A self-contained OpenGL ES view that previews the marker animation for a timing-adjust
 *        test.
 */
@interface AdjustTestView : UIView

/**
 * @brief Returns @c CAEAGLLayer so the view is backed by a Core Animation EAGL layer.
 * @return The @c CAEAGLLayer class.
 * @ghidraAddress 0x9db78
 */
+ (Class)layerClass;

/**
 * @brief Initialises the view, its EAGL context and framebuffer, and the four panel buttons.
 * @param frame The view's frame.
 * @return The initialised view, or @c nil if the GL context could not be created.
 * @ghidraAddress 0x9db8c
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Creates the framebuffer, colour renderbuffer, and shared quad index buffer, and configures
 *        the fixed-function GL state.
 * @return @c YES if the framebuffer is complete, otherwise @c NO.
 * @ghidraAddress 0x9e014
 */
- (BOOL)createFramebuffer;

/**
 * @brief Loads a marker's animation frames and panel buttons into the ten sprite-sheet textures,
 *        and loads the test sequence and its background music.
 *
 * Opens the marker's data archive, decrypts each named entry into an image, and packs the marker
 * frames and the up/down button graphics into the texture table with @c -setSubImage:inRect: . Then
 * opens the bundled @c 999999999.jbt archive to build the @c Sequence and background-music data.
 *
 * @param markerID The marker identifier (for example @c mk0001 ).
 * @ghidraAddress 0x9e288
 */
- (void)loadMarkerTex:(nullable NSString *)markerID;

/**
 * @brief Releases the ten sprite-sheet textures, stops the background music, and drops the
 * sequence.
 * @ghidraAddress 0x9e904
 */
- (void)releaseTex;

/**
 * @brief Starts the preview: resets state, pushes and reloads the background music, and plays it.
 * @ghidraAddress 0x9ea70
 */
- (void)startPreview;

/**
 * @brief Pauses the preview if it is running: stops the music and restores the pushed track.
 * @ghidraAddress 0x9eb10
 */
- (void)pausePreview;

/**
 * @brief Suspends the preview: marks it paused, resets state, and stops the music.
 * @ghidraAddress 0x9ebcc
 */
- (void)suspendPreview;

/**
 * @brief Resumes the preview: restores the pushed track and fades the music back in.
 * @ghidraAddress 0x9ec3c
 */
- (void)resumePreview;

/**
 * @brief Sets the audio-timing offset from a sector value, scaling it by the frame rate.
 * @param adjust The offset in frame sectors.
 * @ghidraAddress 0x9eca0
 */
- (void)setAdjust:(int)adjust;

/**
 * @brief Resets the press flags, timing state, base time, and audio offset, and rewinds the
 *        sequence.
 * @ghidraAddress 0x9ecc0
 */
- (void)reset;

/**
 * @brief Draws one packed button sprite for a given animation state into the fixed test rectangle.
 *
 * The @p point is not used; the sprite is always drawn at a fixed inset. The @p btnState selects
 * the atlas texture and cell.
 *
 * @param point Ignored.
 * @param btnState The packed animation-state and frame value selecting the atlas cell.
 * @ghidraAddress 0x9edd8
 */
- (void)drawBtn:(CGPoint)point btnState:(int)btnState;

/**
 * @brief Advances the sequence to the current music position, judges the panels, and renders one
 *        frame per panel plus its button.
 * @ghidraAddress 0x9eec8
 */
- (void)draw;

/**
 * @brief Deletes the framebuffer, colour renderbuffer, and index buffer.
 * @ghidraAddress 0x9f308
 */
- (void)destroyFramebuffer;

/**
 * @brief Marks a panel as pressed from a button's down event, by its tag.
 * @param sender The button that was pressed.
 * @ghidraAddress 0x9f40c
 */
- (void)btnTouchesBegan:(UIButton *)sender;

/**
 * @brief Clears a panel's pressed flag from a button's up event, by its tag.
 * @param sender The button that was released.
 * @ghidraAddress 0x9f458
 */
- (void)btnTouchesEnd:(UIButton *)sender;

/**
 * @brief The playback sequence, built from the bundled test archive.
 * @ghidraAddress 0x9f51c (getter), 0x9f52c (setter)
 */
@property(nonatomic, strong, nullable) Sequence *sequence;

/**
 * @brief The current marker identifier, set when marker textures are loaded.
 * @ghidraAddress 0x9f50c (getter)
 */
@property(readonly, strong, nullable) NSString *currentMarker;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
