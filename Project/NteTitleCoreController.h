/** @file
 * NTE (new title event) core title-screen controller.
 *
 * Reconstructed from Ghidra program Jubeat (class @c NteTitleCoreController , image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The bottom child of @c TitleViewControllerNte : an animated title screen backed by an
 * @c EAGLView with an @c UpperBGKnit wave background, driven by a @c CADisplayLink loop. A
 * "concierge" character can be tapped to ripple the waves, and a hidden shake/swipe/tap state
 * machine (the @c kcState / @c hnState pair) unlocks a Hinabita easter-egg mode. The screen also
 * hosts the licence-agreement sheet, the editor-ID provisioning flow, and the marker-download
 * check before it transitions off the title.
 *
 * The superclass is @c TitleViewController , from the @c -init tail call to
 * @c -[TitleViewController init] and the matching super sends in @c -loadView , @c -viewDidAppear ,
 * @c -viewDidUnload , and @c -dealloc .
 */

#import <UIKit/UIKit.h>

#import "EditorIDManager.h"
#import "LicenseAgreementView.h"
#import "MarkerDownloadView.h"
#import "NteTitleOptionDropView.h"
#import "TitleViewController.h"

@class EAGLView;
@class UpperBGKnit;
@class Texture2D;
@class NteTitleOptionView;
@class SePlayer;
@class CMMotionManager;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The animated NTE title-screen core: GL wave background, tappable concierge, hidden
 * shake/swipe easter egg, and the licence and marker flows.
 *
 * Acts as the delegate for its @c LicenseAgreementView , @c EditorIDManager ,
 * @c MarkerDownloadView , and each @c NteTitleOptionDropView it drops.
 */
@interface NteTitleCoreController : TitleViewController <EditorIDManagerDelegate,
                                                         MarkerDownloadViewDelegate,
                                                         NteTitleOptionDropViewDelegate>

/**
 * @brief Sets the @c unsealHeight ivar: the top strip's height, used to offset the marker view and
 * the licence sheet on iPad.
 * @param unsealHeight_ The unseal strip height in points.
 * @ghidraAddress 0x1ce434
 */
- (void)setUnsealHeight:(int)unsealHeight_;

/**
 * @brief Initialises the controller with the background artwork names and the GL background bounds.
 * @param nameArray The per-page background image base names. Copied.
 * @param bounds The background bounds; stored in @c bgBounds and used to size the @c EAGLView.
 * @return The initialised controller.
 * @ghidraAddress 0x1ce444
 */
- (instancetype)initWithNameArray:(nullable NSArray<NSString *> *)nameArray bounds:(CGRect)bounds;

/**
 * @brief Loads and decrypts the page background image at @p index.
 * @param index The page index into @c fileNameArray.
 * @return The scaled, decrypted background image.
 * @ghidraAddress 0x1ce9f8
 */
- (nullable UIImage *)getBgImage:(int)index;

/**
 * @brief Becomes first responder so motion (shake) events are delivered.
 * @param animated Whether the appearance was animated.
 * @ghidraAddress 0x1cea98
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * @brief Builds the view hierarchy: the GL view, the background image view, the option ornament,
 * the jubeat logo, the touch prompt, and the marker view, sized per device idiom.
 * @ghidraAddress 0x1ceaec
 */
- (void)loadView;

/**
 * @brief Starts the title: hides the logo and prompt, loads and plays the BGM and welcome SE, and
 * schedules the @c CADisplayLink loop.
 * @ghidraAddress 0x1cf22c
 */
- (void)start;

/**
 * @brief Launches the looping "run car" flyby of the option ornament across the screen.
 * @ghidraAddress 0x1cf408
 */
- (void)startRunCar;

/**
 * @brief The @c CADisplayLink callback: renders the GL frame and feeds accelerometer deltas into
 * the wave background.
 * @param sender The display link.
 * @ghidraAddress 0x1cfab0
 */
- (void)loop:(nullable CADisplayLink *)sender;

/**
 * @brief Adds the pulsing opacity animation to the touch-prompt layer.
 * @ghidraAddress 0x1cfc54
 */
- (void)blinkPrompt;

/**
 * @brief Presents the marker-download check modal over the controller's view.
 * @ghidraAddress 0x1cfe0c
 */
- (void)startMarkerCheck;

/**
 * @brief Installs the swipe and tap recognisers, resets the easter-egg state, and starts the
 * blinking prompt.
 * @ghidraAddress 0x1cfe94
 */
- (void)startBlinkPrompt;

/**
 * @brief Fades the jubeat logo up to full opacity, then begins the marker check on completion.
 * @ghidraAddress 0x1d0228
 */
- (void)showLogo;

/**
 * @brief The concierge character's hit rect, relative to the logo view.
 * @return The concierge rectangle.
 * @ghidraAddress 0x1d03ac
 */
- (CGRect)getConciergeRect;

/**
 * @brief The option ornament's current presentation-layer frame (its live animated position).
 * @return The option view rectangle.
 * @ghidraAddress 0x1d0444
 */
- (CGRect)getOptViewRect;

/**
 * @brief Drops a pair of falling option ornaments at the tap point.
 * @param point The drop origin.
 * @ghidraAddress 0x1d04e4
 */
- (void)addOptionDrop:(CGPoint)point;

/**
 * @brief The tap-gesture handler: drives the Konami-code hit regions, the concierge ripple, the
 * option drop, and the licence/next-scene entry.
 * @param recognizer The tap recogniser.
 * @ghidraAddress 0x1d06cc
 */
- (void)handleTap:(nullable UITapGestureRecognizer *)recognizer;

/**
 * @brief The swipe-gesture handler: advances the four-direction Konami-code state machine.
 * @param recognizer The swipe recogniser.
 * @ghidraAddress 0x1d0d58
 */
- (void)handleSwipe:(nullable UISwipeGestureRecognizer *)recognizer;

/**
 * @brief Runs the page-curl transition to a new background page.
 * @param index The new page index.
 * @param completed Whether this is the committing pass (updates @c currentPage) or the reverse.
 * @ghidraAddress 0x1d0e54
 */
- (void)changeTitleBg:(int)index completed:(BOOL)completed;

/**
 * @brief The reverse-curl animation completion: curls the current page back into view.
 * @ghidraAddress 0x1d0fd0
 */
- (void)needReverseEnd;

/**
 * @brief The curl-animation completion: re-enables interaction events.
 * @ghidraAddress 0x1d10d0
 */
- (void)curlAnimEnd;

/**
 * @brief Application-background handler: removes the prompt animation and invalidates the loop.
 * @param notification The notification.
 * @ghidraAddress 0x1d1118
 */
- (void)suspend:(nullable NSNotification *)notification;

/**
 * @brief Application-foreground handler: restarts the prompt, the loop, and device motion.
 * @param notification The notification.
 * @ghidraAddress 0x1d11bc
 */
- (void)resume:(nullable NSNotification *)notification;

/**
 * @brief Invalidates the loop, stops device motion, and stops all sound effects.
 * @ghidraAddress 0x1d12e8
 */
- (void)stopAnimation;

/**
 * @brief Tears down the option, background, prompt, recogniser, and texture references.
 * @ghidraAddress 0x1d1388
 */
- (void)viewDidUnload;

/**
 * @brief An option-drop finished falling: removes it from the view and the tracking array.
 * @param dropView The finished drop view.
 * @ghidraAddress 0x1d1520
 */
- (void)dropAnimEnd:(nullable NteTitleOptionDropView *)dropView;

/**
 * @brief The marker check completed: starts the blinking prompt.
 * @ghidraAddress 0x1d1580
 */
- (void)markerCheckEnd;

/**
 * @brief Caches the portrait flag before a legacy rotation.
 * @param toInterfaceOrientation The target orientation.
 * @param duration The rotation duration.
 * @ghidraAddress 0x1d158c
 */
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration;

/**
 * @brief Caches the portrait flag before a size transition.
 * @param size The target size.
 * @param coordinator The transition coordinator.
 * @ghidraAddress 0x1d1604
 */
- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(nullable id<UIViewControllerTransitionCoordinator>)coordinator;

/**
 * @brief Whether the given (legacy) interface orientation is supported: landscape only.
 * @param interfaceOrientation The orientation to test.
 * @return @c YES for the two landscape orientations.
 * @ghidraAddress 0x1d167c
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @brief The supported interface orientations: landscape.
 * @return @c UIInterfaceOrientationMaskLandscape.
 * @ghidraAddress 0x1d168c
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Whether the controller autorotates: always @c YES.
 * @return @c YES.
 * @ghidraAddress 0x1d1694
 */
- (BOOL)shouldAutorotate;

/**
 * @brief Removes observers, stops the option view and device motion, terminates the SE player,
 * and calls @c super.
 * @ghidraAddress 0x1d169c
 */
- (void)dealloc;

/**
 * @brief Transitions off the title: removes gestures, plays the confirm SE, fades the BGM, blinks
 * the prompt fast, and tells the root controller to end the title.
 * @ghidraAddress 0x1d17fc
 */
- (void)nextScene;

/**
 * @brief Builds and reveals the licence-agreement sheet over the dimming cover.
 * @ghidraAddress 0x1d1c44
 */
- (void)createPolicyView;

/**
 * @brief @c EditorIDManagerDelegate / licence error: shows the network-error alert and tears down
 * the sheet and cover.
 * @param manager The reporting manager.
 * @param msgStr The error message, or @c nil for the default network-error string.
 * @ghidraAddress 0x1d1f8c
 */
- (void)agreementError:(nullable id)manager msgStr:(nullable NSString *)msgStr;

/**
 * @brief Licence accepted: tears down the sheet and cover and transitions to the next scene.
 * @param sender The reporting view.
 * @ghidraAddress 0x1d2168
 */
- (void)agreementSuccess:(nullable id)sender;

/**
 * @brief Licence declined: tears down the sheet and cover, staying on the title.
 * @param sender The reporting view.
 * @ghidraAddress 0x1d21e0
 */
- (void)agreementFailed:(nullable id)sender;

/**
 * @brief @c EditorIDManagerDelegate : the editor-ID download failed; shows the network-error alert.
 * @param manager The reporting manager.
 * @param msgStr The error message, or @c nil for the default network-error string.
 * @ghidraAddress 0x1d2248
 */
- (void)errorIDDownload:(nullable id)manager msgStr:(nullable NSString *)msgStr;

/**
 * @brief @c EditorIDManagerDelegate : the editor-ID download succeeded; registers the user id and
 * shows the licence sheet.
 * @param manager The reporting manager.
 * @ghidraAddress 0x1d23f0
 */
- (void)successIDDownload:(nullable id)manager;

/**
 * @brief Whether the given motion event is a shake.
 * @param event The motion event.
 * @return @c YES when the event is a shake.
 * @ghidraAddress 0x1d24a4
 */
- (BOOL)checkShakeEvent:(nullable UIEvent *)event;

/**
 * @brief Whether the controller can become first responder: always @c YES.
 * @return @c YES.
 * @ghidraAddress 0x1d250c
 */
- (BOOL)canBecomeFirstResponder;

/**
 * @brief Motion began: routes to the shake check.
 * @param motion The motion type.
 * @param event The motion event.
 * @ghidraAddress 0x1d2514
 */
- (void)motionBegan:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event;

/**
 * @brief Motion cancelled: routes to the shake check.
 * @param motion The motion type.
 * @param event The motion event.
 * @ghidraAddress 0x1d2524
 */
- (void)motionCancelled:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event;

/**
 * @brief Motion ended: routes to the shake check and plays the shake SE when it was a shake.
 * @param motion The motion type.
 * @param event The motion event.
 * @ghidraAddress 0x1d2534
 */
- (void)motionEnded:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
