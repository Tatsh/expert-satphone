/**
 * @file
 * The OpenGL ES 1.1 rendering view backing the game.
 */

#import <OpenGLES/EAGL.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * The OpenGL ES 1.1 rendering view backing the game.
 *
 * A @c CAEAGLLayer-backed @c UIView that owns the default framebuffer, colour and depth
 * renderbuffers, and a shared element-array (index) buffer, drives the GL context, and forwards
 * UIKit touches into a pair of tracking sets consumed by the engine each frame.
 */
@interface EAGLView : UIView

/** The EAGL rendering context this view draws into. */
@property(nonatomic, strong, nullable) EAGLContext *renderContext;

/**
 * Returns @c CAEAGLLayer so the view is backed by a Core Animation EAGL layer.
 * @return The @c CAEAGLLayer class.
 * @ghidraAddress 0xca80
 */
+ (Class)layerClass;

/**
 * Binds this view's render context as the current context for the calling thread.
 * @ghidraAddress 0xcd50
 */
- (void)startRenderContext;

/**
 * Runs a block on a background queue against a second GL context that shares this view's
 *        sharegroup, so GL resources can be uploaded off the main thread.
 * @param block The work to perform with the shared context bound.
 * @ghidraAddress 0xcda0
 */
- (void)performBlockInBackground:(void (^)(void))block;

/**
 * Makes the render context current and clears the framebuffer in preparation for a frame.
 * @ghidraAddress 0xcf98
 */
- (void)prepareToRender;

/**
 * Discards the depth attachment and presents the colour renderbuffer to the screen.
 * @ghidraAddress 0xd024
 */
- (void)swapBuffer;

/**
 * Creates the framebuffer, colour and depth renderbuffers, and the shared quad index buffer,
 *        and configures the fixed-function GL state.
 * @return @c YES if the framebuffer is complete, otherwise @c NO.
 * @ghidraAddress 0xd0b8
 */
- (BOOL)createFramebuffer;

/**
 * Deletes the framebuffer, renderbuffers, and index buffer.
 * @ghidraAddress 0xd3c8
 */
- (void)destroyFramebuffer;

/**
 * Sets up an orthographic projection covering a 2D space of the given size.
 * @param size The width and height of the 2D space, in points.
 * @ghidraAddress 0xd4b8
 */
- (void)set2dSpace:(CGSize)size;

/**
 * Returns the touches accumulated for the current frame, then clears the release set.
 * @return A snapshot set combining the current and just-released touches.
 * @ghidraAddress 0xd504
 */
- (nonnull NSMutableSet *)touches;

/**
 * Clears both the current and release touch sets.
 * @ghidraAddress 0xd6b4
 */
- (void)resetTouches;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
