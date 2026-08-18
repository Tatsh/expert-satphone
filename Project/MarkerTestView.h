/** @file
 * The marker (note-hit graphic) preview view.
 *
 * Reconstructed from Ghidra program Jubeat (class MarkerTestView, image base 0x100000000); all
 * @ghidraAddress values are offsets relative to that image base. This class has no embedded
 * @c __FILE__ path, so it stays at the @c Project/ root.
 *
 * A @c CAEAGLLayer-backed @c UIView that is structurally its own OpenGL ES view: it owns an
 * @c EAGLContext , a default framebuffer, and a colour renderbuffer, and draws the loaded marker
 * animation and a press button through a small table of @c Texture2D sprite sheets. Touches toggle
 * the press flag, @c -draw advances the timing state machine and renders one frame, and the sound
 * names for each interface theme are held in @c soundNames .
 */

#import <OpenGLES/EAGL.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A self-contained OpenGL ES view that previews a marker's hit animation.
 */
@interface MarkerTestView : UIView

/**
 * @brief Returns @c CAEAGLLayer so the view is backed by a Core Animation EAGL layer.
 * @return The @c CAEAGLLayer class.
 * @ghidraAddress 0x80294
 */
+ (Class)layerClass;

/**
 * @brief Initialises the view, its EAGL context and framebuffer, and the per-theme sound names.
 * @param frame The view's frame.
 * @return The initialised view, or @c nil if the GL context could not be created.
 * @ghidraAddress 0x802a8
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Creates the framebuffer, colour renderbuffer, and shared quad index buffer, and configures
 *        the fixed-function GL state.
 * @return @c YES if the framebuffer is complete, otherwise @c NO.
 * @ghidraAddress 0x80710
 */
- (BOOL)createFramebuffer;

/**
 * @brief Loads a marker's animation frames and press button into the ten sprite-sheet textures.
 *
 * Opens the marker's data archive, decrypts each named entry into an image, and packs the marker
 * frames and the up/down button graphics into the texture table with @c -setSubImage:inRect: .
 *
 * @param markerID The marker identifier (for example @c mk0001 ).
 * @ghidraAddress 0x80984
 */
- (void)loadMarkerTex:(nullable NSString *)markerID;

/**
 * @brief Releases the ten sprite-sheet textures and resets the current marker.
 * @ghidraAddress 0x80e58
 */
- (void)releaseTex;

/**
 * @brief Resets the press flags, timing state, and base time to start a fresh preview.
 * @ghidraAddress 0x80f54
 */
- (void)reset;

/**
 * @brief Advances the timing state machine, plays the matching hit sound, and renders one frame.
 * @ghidraAddress 0x80fa4
 */
- (void)draw;

/**
 * @brief Deletes the framebuffer, colour renderbuffer, and index buffer.
 * @ghidraAddress 0x81620
 */
- (void)destroyFramebuffer;

/**
 * @brief The current marker identifier, set when marker textures are loaded.
 * @ghidraAddress 0x817a0 (getter)
 */
@property(atomic, readonly, nullable) NSString *currentMarker;

/**
 * @brief The per-theme hit-sound names, indexed by @c JubeatTheme .
 *
 * A three-element array (original, ripples, knit), each element a four-element array of
 * sound names ordered perfect, good, fast, slow.
 * @ghidraAddress 0x817b0 (getter), 0x817c0 (setter)
 */
@property(nonatomic, strong, nullable) NSArray<NSArray<NSString *> *> *soundNames;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
