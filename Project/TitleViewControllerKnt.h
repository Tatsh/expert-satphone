/**
 * @file
 * The title screen, knit (KNT) theme.
 *
 * Reconstructed from Ghidra program Jubeat (class @c TitleViewControllerKnt , image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * A close sibling of @c NteTitleCoreController : an animated GL title screen backed by an
 * @c EAGLView with an @c UpperBGKnit wave background, driven by a @c CADisplayLink loop. A
 * "concierge" character is drawn into the GL scene and can be tapped to ripple the waves, a hidden
 * shake/swipe/tap state machine (the @c kcState / @c hnState pair) unlocks a Hinabita easter-egg
 * mode, and a logo-tap easter egg swaps the concierge in. The screen also hosts the
 * licence-agreement sheet, the editor-ID provisioning flow, and the marker-download check before it
 * transitions off the title.
 *
 * Unlike @c NteTitleCoreController this KNT variant owns the concierge sprite itself
 * (@c -renderConcierge , @c -getConciergeType , @c -becomeConcierge ) and a @c copyrightView , and
 * it slides its touch prompt by @c tapDelayY when the concierge is the Hinabita type. It has no
 * falling option-drop ornaments.
 *
 * The superclass is @c TitleViewController , from the @c -init tail call to
 * @c -[TitleViewController init] and the matching super sends in @c -loadView , @c -viewDidUnload ,
 * and @c -dealloc .
 *
 * Built by @c -[RootViewController createKnitTitleViewController] for @c JubeatThemeKnit , and
 * again by @c -titleSwitch , which always swaps to this one.
 */

#import <UIKit/UIKit.h>

#import "EditorIDManager.h"
#import "MarkerDownloadView.h"
#import "TitleViewController.h"

@class CADisplayLink;
@class EAGLView;
@class LicenseAgreementView;
@class Texture2D;
@class UpperBGKnit;

NS_ASSUME_NONNULL_BEGIN

/**
 * The animated KNT title-screen: GL wave background, tappable/GL-drawn concierge, hidden
 * shake/swipe easter egg, and the licence and marker flows.
 *
 * Acts as the delegate for its @c EditorIDManager , its @c MarkerDownloadView , and (untyped) its
 * @c LicenseAgreementView .
 */
// clang-format off
// One protocol per line: a continuation line that begins with ": Base <" is read by Doxygen as
// undocumented ivars named after the trailing protocols.
@interface TitleViewControllerKnt : TitleViewController <EditorIDManagerDelegate,
                                                         MarkerDownloadViewDelegate>
// clang-format on

/**
 * Initialises the controller: caches the device idiom, builds the @c EAGLView and the
 * @c UpperBGKnit wave, registers the background and foreground observers, and starts device motion.
 * @return The initialised controller.
 * @ghidraAddress 0x184f48
 */
- (instancetype)init;

/**
 * Builds the view hierarchy: the GL view, the jubeat logo, the touch prompt, the copyright
 * image, the GL wave textures, the concierge texture, and the marker view, sized per device idiom.
 * @ghidraAddress 0x1853c4
 */
- (void)loadView;

/**
 * Starts the title: hides the logo, prompt, and copyright, loads and plays the BGM and the
 * welcome SE, and schedules the @c CADisplayLink loop.
 * @ghidraAddress 0x18637c
 */
- (void)start;

/**
 * The @c CADisplayLink callback: renders the GL frame, feeds accelerometer deltas into the
 * wave background, draws the concierge once unlocked, and commits the layers.
 * @param sender The display link.
 * @ghidraAddress 0x186570
 */
- (void)loop:(nullable CADisplayLink *)sender;

/**
 * Adds the pulsing opacity animation to the touch-prompt layer.
 * @ghidraAddress 0x1868ac
 */
- (void)blinkPrompt;

/**
 * Presents the marker-download check modal over the controller's view.
 * @ghidraAddress 0x186a64
 */
- (void)startMarkerCheck;

/**
 * Installs the four swipe recognisers and the tap recogniser, resets the easter-egg state,
 * re-parents the explain and corporate buttons, and starts the blinking prompt.
 * @ghidraAddress 0x186aec
 */
- (void)startBlinkPrompt;

/**
 * Fades the jubeat logo and copyright up to full opacity, then begins the marker check.
 * @ghidraAddress 0x186e80
 */
- (void)showLogo;

/**
 * The concierge character's hit rect, relative to the logo view.
 * @return The concierge rectangle.
 * @ghidraAddress 0x187048
 */
- (CGRect)getConciergeRect;

/**
 * The tap-gesture handler: drives the Konami-code hit regions, the concierge-swap easter
 * egg, the concierge ripple, and the licence/next-scene entry.
 * @param recognizer The tap recogniser.
 * @ghidraAddress 0x1870e0
 */
- (void)handleTap:(nullable UITapGestureRecognizer *)recognizer;

/**
 * The swipe-gesture handler: advances the four-direction Konami-code state machine.
 * @param recognizer The swipe recogniser.
 * @ghidraAddress 0x187648
 */
- (void)handleSwipe:(nullable UISwipeGestureRecognizer *)recognizer;

/**
 * Application-background handler: removes the prompt animation and invalidates the loop.
 * @param notification The notification.
 * @ghidraAddress 0x187744
 */
- (void)suspend:(nullable NSNotification *)notification;

/**
 * Application-foreground handler: restarts the prompt, the loop, and device motion.
 * @param notification The notification.
 * @ghidraAddress 0x1877e8
 */
- (void)resume:(nullable NSNotification *)notification;

/**
 * Invalidates the loop and stops device motion.
 * @ghidraAddress 0x187914
 */
- (void)stopAnimation;

/**
 * Tears down the background, prompt, recogniser, and texture references.
 * @ghidraAddress 0x18798c
 */
- (void)viewDidUnload;

/**
 * Draws the concierge sprite into the GL scene: its wandering position, the tap-count digit
 * readout, the shake bob, and the animation-frame cycle.
 * @ghidraAddress 0x187a70
 */
- (void)renderConcierge;

/**
 * The marker check completed: starts the blinking prompt.
 * @ghidraAddress 0x18803c
 */
- (void)markerCheckEnd;

/**
 * Caches the portrait flag before a legacy rotation.
 * @param toInterfaceOrientation The target orientation.
 * @param duration The rotation duration.
 * @ghidraAddress 0x188048
 */
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration;

/**
 * Caches the portrait flag before a size transition.
 * @param size The target size.
 * @param coordinator The transition coordinator.
 * @ghidraAddress 0x1880c0
 */
- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(nullable id<UIViewControllerTransitionCoordinator>)coordinator;

/**
 * Whether the given (legacy) interface orientation is supported: portrait only.
 * @param interfaceOrientation The orientation to test.
 * @return @c YES for @c UIInterfaceOrientationPortrait and
 *         @c UIInterfaceOrientationPortraitUpsideDown .
 * @ghidraAddress 0x188138
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * The supported interface orientations: the portrait pair.
 * @return @c UIInterfaceOrientationMaskPortrait |
 *         @c UIInterfaceOrientationMaskPortraitUpsideDown .
 * @ghidraAddress 0x188148
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * Whether the controller autorotates: always @c YES .
 * @return @c YES .
 * @ghidraAddress 0x188150
 */
- (BOOL)shouldAutorotate;

/**
 * Removes observers, empties the wave textures, re-arms device motion (the binary does not
 * stop it), terminates the SE player, and calls @c super .
 * @ghidraAddress 0x188158
 */
- (void)dealloc;

/**
 * The concierge sprite type: derived from the knit colour type, forced to the Hinabita type
 * when the app is in Hinabita mode.
 * @return The concierge type.
 * @ghidraAddress 0x188248
 */
- (int)getConciergeType;

/**
 * Unlocks the concierge easter egg: enters the walking state, strips the swipe recognisers,
 * seeds the concierge positions, lazily creates the bell SE player, and (for the Hinabita
 * concierge) slides the touch prompt down.
 * @ghidraAddress 0x188300
 */
- (void)becomeConcierge;

/**
 * Transitions off the title: removes gestures, plays the confirm SE, fades the BGM, blinks
 * the prompt fast, and tells the root controller to end the title.
 * @ghidraAddress 0x188890
 */
- (void)nextScene;

/**
 * Builds and reveals the licence-agreement sheet over the dimming cover.
 * @ghidraAddress 0x188ccc
 */
- (void)createPolicyView;

/**
 * Licence error: transitions on if the policy was already agreed, otherwise shows the
 * network-error alert and tears down the sheet and cover.
 * @param manager Ignored.
 * @param msgStr Ignored; the alert body is the fixed connection-error string.
 * @ghidraAddress 0x188e18
 */
- (void)agreementError:(nullable id)manager msgStr:(nullable NSString *)msgStr;

/**
 * Licence accepted: tears down the sheet and cover and transitions to the next scene.
 * @param sender The reporting view.
 * @ghidraAddress 0x188fb8
 */
- (void)agreementSuccess:(nullable id)sender;

/**
 * Licence declined: tears down the sheet and cover, staying on the title.
 * @param sender The reporting view.
 * @ghidraAddress 0x189030
 */
- (void)agreementFailed:(nullable id)sender;

/**
 * @c EditorIDManagerDelegate : the editor-ID download failed; shows the network-error alert.
 * @param manager The reporting manager.
 * @param msgStr The error message, or @c nil for the default network-error string.
 * @ghidraAddress 0x189098
 */
- (void)errorIDDownload:(nullable id)manager msgStr:(nullable NSString *)msgStr;

/**
 * @c EditorIDManagerDelegate : the editor-ID download succeeded; registers the user id and
 * shows the licence sheet.
 * @param manager The reporting manager.
 * @ghidraAddress 0x189240
 */
- (void)successIDDownload:(nullable id)manager;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
