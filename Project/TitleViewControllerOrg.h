/**
 * @file
 * The title screen, original theme.
 *
 * Reconstructed from Ghidra program Jubeat (class TitleViewControllerOrg, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c TitleViewController , from the dyld bind at the class object's superclass
 * slot (0x34a78 + 8) and confirmed by the super calls at 0x13abe8, 0x13c5e8, and 0x13c4c8.
 *
 * The class is complete: all twenty-four hand-written members are recovered, including the view
 * construction, the animation control, and the tap and swipe handling.
 */

#import <UIKit/UIKit.h>

#import "EditorIDManager.h"
#import "MarkerDownloadView.h"
#import "TitleViewController.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The title screen in the game's own livery.
 */
// clang-format off
// One protocol per line: a continuation line that begins with ": Base <" is read by Doxygen as
// undocumented ivars named after the trailing protocols.
@interface TitleViewControllerOrg : TitleViewController <EditorIDManagerDelegate,
                                                         MarkerDownloadViewDelegate>
// clang-format on

/**
 * Builds the controller and subscribes to background/foreground notifications.
 * @return The initialised controller.
 * @ghidraAddress 0x13abb8
 */
- (instancetype)init;

/**
 * Tears down the controller and unsubscribes from notifications.
 * @ghidraAddress 0x13c580
 */
- (void)dealloc;

/**
 * Builds the view hierarchy.
 *
 * Creates the title background with its 5-frame animation and two gradient layers, then the
 * jubeat logo, touch prompt, copyright, coBtn, and marker view.
 * @ghidraAddress 0x13ac88
 */
- (void)loadView;

/**
 * Begins the title sequence.
 *
 * Hides the logo views and starts the title BGM and welcome voice.
 * @ghidraAddress 0x13b65c
 */
- (void)start;

/**
 * Fades the touch prompt between a tenth and full opacity, forever.
 * @ghidraAddress 0x13b7a8
 */
- (void)blinkPrompt;

/**
 * Starts the prompt blink and arms the hidden-code input.
 *
 * Resets @c kcState , installs the four swipe recognisers in the order up, down, right, left and
 * keeps them in that order, installs the tap recogniser, and lifts the corporate button back above
 * them.
 * @ghidraAddress 0x13b9e0
 */
- (void)startBlinkPrompt;

/**
 * Shows the marker download view and starts the marker check.
 *
 * The check's completion is what calls @c -markerCheckEnd and so arms the title screen.
 * @ghidraAddress 0x13b960
 */
- (void)startMarkerCheck;

/**
 * Fades the logo and copyright in over 0.5 s, then starts the marker check.
 *
 * The curve is linear and the completion ignores its finished flag, so the marker check always
 * runs.
 * @ghidraAddress 0x13bd1c
 */
- (void)showLogo;

/**
 * Handles a tap on the title screen.
 *
 * Two hidden square hot-spots on the logo finish the sequence that @c -handleSwipe: starts;
 * completing it plays a sound and speeds the cube background up, and does not leave the title.
 * Every other tap begins the start flow: it covers the title and hands over to the challenge policy
 * or the editor-identifier download, either of which reaches @c -nextScene later.
 * @param sender The recogniser that fired.
 * @ghidraAddress 0x13be70
 */
- (void)handleTap:(UITapGestureRecognizer *)sender;

/**
 * Handles a swipe on the title screen.
 *
 * Advances the hidden up, up, down, down, left, right, left, right code held in @c kcState . A
 * swipe out of sequence restarts the code.
 * @param sender The recogniser that fired.
 * @ghidraAddress 0x13c328
 */
- (void)handleSwipe:(UISwipeGestureRecognizer *)sender;

/**
 * Pauses the title animation when the app backgrounds.
 * @param sender The notification.
 * @ghidraAddress 0x13c418
 */
- (void)suspend:(id)sender;

/**
 * Resumes the title animation when the app foregrounds.
 * @param sender The notification.
 * @ghidraAddress 0x13c478
 */
- (void)resume:(id)sender;

/**
 * Drops the views created in @c -loadView.
 * @ghidraAddress 0x13c498
 */
- (void)viewDidUnload;

/**
 * Called when the marker check finishes.
 * @ghidraAddress 0x13c554
 */
- (void)markerCheckEnd;

/**
 * Leaves the title screen for the music-select screen.
 *
 * Removes the swipe and tap recognisers, plays the confirm sound, fades the BGM out over 1.5 s,
 * replaces the prompt's slow blink with ten fast cycles, and sends @c -endTitle to the root
 * controller. Unguarded: nothing prevents a second entry.
 * @ghidraAddress 0x13c5fc
 */
- (void)nextScene;

/**
 * Creates the licence agreement view centred on the screen.
 * @ghidraAddress 0x13ca38
 */
- (void)createPolicyView;

/**
 * Reports that only portrait orientations are supported.
 * @param interfaceOrientation The orientation being asked about.
 * @return @c YES for portrait and portrait-upside-down.
 * @ghidraAddress 0x13c560
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * The orientations the title screen allows.
 * @return Portrait and portrait-upside-down (6).
 * @ghidraAddress 0x13c570
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * Whether the title screen rotates at all.
 * @return Always @c YES .
 * @ghidraAddress 0x13c578
 */
- (BOOL)shouldAutorotate;

/**
 * Handles a licence agreement error.
 * @param agreement The agreement.
 * @param msgStr The error message.
 * @ghidraAddress 0x13cb84
 */
- (void)agreementError:(id)agreement msgStr:(NSString *)msgStr;

/**
 * Handles a licence agreement success.
 * @param agreement The agreement.
 * @ghidraAddress 0x13cd24
 */
- (void)agreementSuccess:(id)agreement;

/**
 * Handles a licence agreement failure.
 * @param agreement The agreement.
 * @ghidraAddress 0x13cd9c
 */
- (void)agreementFailed:(id)agreement;

/**
 * @c EditorIDManagerDelegate : the editor-ID download failed; shows the network-error alert.
 *
 * Both parameters are @c nullable to match the protocol's own declaration, which the surrounding
 * @c NS_ASSUME_NONNULL_BEGIN would otherwise contradict.
 * @param download The download.
 * @param msgStr The error message, or @c nil for the default network-error string.
 * @ghidraAddress 0x13ce04
 */
- (void)errorIDDownload:(nullable id)download msgStr:(nullable NSString *)msgStr;

/**
 * @c EditorIDManagerDelegate : the editor-ID download succeeded; registers the user id and
 * shows the challenge policy.
 * @param download The download.
 * @ghidraAddress 0x13cfac
 */
- (void)successIDDownload:(nullable id)download;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
