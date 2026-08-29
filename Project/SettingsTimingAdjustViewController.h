/**
 * @file
 * The timing-offset calibration settings screen.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsTimingAdjustViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. The superclass
 * is @c UIViewController : every chained-through call (@c -init , @c -loadView ,
 * @c -viewWillAppear: , @c -viewDidAppear: , @c -viewWillDisappear: , @c -viewDidDisappear: , and
 * @c -dealloc ) messages @c super as @c UIViewController , and the orientation methods return plain
 * literals rather than deferring to a rotatable base. This class has no embedded @c __FILE__ path,
 * so it stays at the @c Project/ root beside the other @c Settings*ViewController files.
 *
 * A @c UISlider tunes the audio/visual timing offset (@c delaySector , a @c float ), a
 * @c CADisplayLink drives an @c AdjustTestView preview animation, and a looping test sound plays
 * while the preview runs. The chosen offset is persisted to @c NSUserDefaults under
 * @c PrefAdjustSector .
 */

#import <UIKit/UIKit.h>

#import "AdjustTestView.h"
#import "AlertViewManager.h"

@class CADisplayLink;

NS_ASSUME_NONNULL_BEGIN

/**
 * The timing-adjust calibration view controller.
 */
@interface SettingsTimingAdjustViewController : UIViewController <AlertViewManagerDelegate>

/**
 * Sets the navigation title, seeds @c delaySector from @c NSUserDefaults , subscribes to the
 *        app suspend/resume notifications, and starts the display-link animation.
 * @return The initialised controller.
 * @ghidraAddress 0x1745e0
 */
- (instancetype)init;

/**
 * Builds the whole calibration UI: the background image, the four labels, the slider, the
 *        rounded preview container, the preview @c AdjustTestView , and the play/pause button.
 * @ghidraAddress 0x174740
 */
- (void)loadView;

/**
 * Chains up to @c UIViewController .
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x1754b8
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * Chains up to @c UIViewController .
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x1754f0
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * Pauses the preview and flushes @c NSUserDefaults , then chains up.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x175528
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * Drops the preview view, removes the notification observers, then chains up.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x1755b8
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * Allows portrait and portrait-upside-down only.
 * @param interfaceOrientation The orientation being queried.
 * @return @c YES for portrait orientations.
 * @ghidraAddress 0x175658
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * Returns the portrait and portrait-upside-down mask.
 * @return The supported orientation mask.
 * @ghidraAddress 0x175668
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * Returns @c YES to permit autorotation.
 * @return @c YES.
 * @ghidraAddress 0x175670
 */
- (BOOL)shouldAutorotate;

/**
 * Presents the auto-calibration confirmation alert (Cancel / OK).
 * @param sender The control that fired the action.
 * @ghidraAddress 0x175678
 */
- (void)tapAutoSetting:(nullable id)sender;

/**
 * The auto-calibration alert callback: on the OK button, shows the "done" confirmation.
 * @param info The alert-manager info dictionary carrying the tapped button index.
 * @ghidraAddress 0x17582c
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

/**
 * Drops the preview view and removes the notification observers, then chains up.
 * @ghidraAddress 0x17596c
 */
- (void)dealloc;

/**
 * Slider value-changed action: snaps the slider, maps it to @c delaySector , updates the
 *        value label and preview offset, and persists the offset.
 * @param sender The slider.
 * @ghidraAddress 0x1759fc
 */
- (void)changeTiming:(nullable id)sender;

/**
 * Formats the current slider value into the value label.
 * @ghidraAddress 0x175b04
 */
- (void)refreshValue;

/**
 * Play/pause button action: toggles playback, swaps the button icon, and starts or pauses
 *        the preview and its looping test sound.
 * @param sender The button.
 * @ghidraAddress 0x175cb8
 */
- (void)switchPrev:(nullable id)sender;

/**
 * App-suspend notification handler: pauses the animation and preview and forces the paused
 *        state.
 * @param notification The suspend notification.
 * @ghidraAddress 0x175ec0
 */
- (void)appSuspended:(nullable NSNotification *)notification;

/**
 * App-resume notification handler: resumes the preview and the animation.
 * @param notification The resume notification.
 * @ghidraAddress 0x175f60
 */
- (void)appResume:(nullable NSNotification *)notification;

/**
 * Background-music-finished notification handler: forces the paused state and stops the
 *        preview.
 * @param notification The finish notification.
 * @ghidraAddress 0x175fa0
 */
- (void)finishMusic:(nullable NSNotification *)notification;

/**
 * Creates the @c CADisplayLink targeting @c -loop: and adds it to the current run loop.
 * @ghidraAddress 0x17606c
 */
- (void)startAnimation;

/**
 * Pauses the display link, if any.
 * @ghidraAddress 0x1761a0
 */
- (void)pauseAnimation;

/**
 * Unpauses the display link, if any.
 * @ghidraAddress 0x176224
 */
- (void)resumeAnimation;

/**
 * Invalidates and clears the display link, if any.
 * @ghidraAddress 0x1762a8
 */
- (void)stopAnimation;

/**
 * Display-link callback: draws one preview frame.
 * @param sender The display link.
 * @ghidraAddress 0x17633c
 */
- (void)loop:(nullable CADisplayLink *)sender;

/**
 * Builds the theme-prefixed sound-effect resource name for the given base name.
 * @param name The base sound-effect name (for example @c MUSIC_SELECT or @c SKIP ).
 * @return The theme-prefixed resource name (for example @c SD_RPL_MUSIC_SELECT ).
 * @ghidraAddress 0x176354
 */
- (nullable NSString *)soundName:(nullable NSString *)name;

/**
 * The display link driving the preview animation.
 * @ghidraAddress 0x176444 (getter)
 * @ghidraAddress 0x176454 (setter)
 */
@property(nonatomic, strong, nullable) CADisplayLink *displayLink;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
