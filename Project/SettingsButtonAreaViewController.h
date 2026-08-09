/** @file
 * The settings-screen touch-area preview.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsButtonAreaViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. The screen
 * previews the jubeat play field — a 4x4 grid of buttons — inside an @c EAGLView driven by a
 * @c CADisplayLink, and offers a @c UISlider that adjusts the per-button touch-area width and
 * persists it to @c NSUserDefaults . The grid is rendered live through a @c Texture2D atlas: each
 * frame reads the view's touches, updates the pressed-button mask, and redraws the grid.
 */

#import <UIKit/UIKit.h>

@class CADisplayLink;
@class EAGLView;
@class Texture2D;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A view controller previewing the play-button area with an adjustable button width.
 */
@interface SettingsButtonAreaViewController : UIViewController

/**
 * @brief The slider controlling the previewed button width.
 * @ghidraAddress 0x112f9c (getter)
 * @ghidraAddress 0x112fac (setter)
 */
@property(nonatomic, strong, nullable) UISlider *slider;

/**
 * @brief The GL view the button grid is rendered into.
 * @ghidraAddress 0x112fc0 (getter)
 * @ghidraAddress 0x112fd0 (setter)
 */
@property(nonatomic, strong, nullable) EAGLView *glView;

/**
 * @brief The sprite atlas holding the button images.
 * @ghidraAddress 0x112fe4 (getter)
 * @ghidraAddress 0x112ff4 (setter)
 */
@property(nonatomic, strong, nullable) Texture2D *texButtons;

/**
 * @brief The display link driving the render loop.
 * @ghidraAddress 0x113008 (getter)
 * @ghidraAddress 0x113018 (setter)
 */
@property(nonatomic, strong, nullable) CADisplayLink *displayLink;

/**
 * @brief Sets the navigation title, opts the view out of opaque-bar extension, and observes the
 *        app suspend and resume notifications.
 * @return The initialised controller.
 * @ghidraAddress 0x111854
 */
- (instancetype)init;

/**
 * @brief The display-link callback: reads touches, updates the pressed mask, and renders one frame
 *        of the button grid.
 * @param displayLink The firing display link (unused).
 * @ghidraAddress 0x1119a0
 */
- (void)loop:(nullable CADisplayLink *)displayLink;

/**
 * @brief Builds the slider, the GL view, the button atlas, the preview border, and the caption
 *        label, then renders the first frame.
 * @ghidraAddress 0x111df8
 */
- (void)loadView;

/**
 * @brief Persists the slider's current value as the preview button width.
 * @param sender The slider that changed.
 * @ghidraAddress 0x1129f4
 */
- (void)buttonWidthChanged:(nullable UISlider *)sender;

/**
 * @brief Pauses the render loop when the app enters the background.
 * @param notification The suspend notification.
 * @ghidraAddress 0x112a7c
 */
- (void)appSuspended:(nullable NSNotification *)notification;

/**
 * @brief Resumes the render loop when the app returns to the foreground.
 * @param notification The resume notification.
 * @ghidraAddress 0x112b10
 */
- (void)appResumed:(nullable NSNotification *)notification;

/**
 * @brief Forwards the memory warning to the superclass.
 * @ghidraAddress 0x112ba0
 */
- (void)didReceiveMemoryWarning;

/**
 * @brief Releases the slider, GL view, and atlas when the view is unloaded.
 * @ghidraAddress 0x112bd8
 */
- (void)viewDidUnload;

/**
 * @brief Forwards to the superclass.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x112c58
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * @brief Creates and schedules the display link on first appearance.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x112c90
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * @brief Invalidates and drops the display link when leaving the screen.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x112de4
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * @brief Forwards to the superclass.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x112e98
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * @brief Allows only the two portrait orientations.
 * @param interfaceOrientation The orientation to test.
 * @return @c YES for portrait or portrait-upside-down.
 * @ghidraAddress 0x112ed0
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @brief The supported orientations: portrait and portrait-upside-down.
 * @return The orientation mask.
 * @ghidraAddress 0x112ee0
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Whether the controller supports automatic rotation.
 * @return Always @c YES.
 * @ghidraAddress 0x112ee8
 */
- (BOOL)shouldAutorotate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
