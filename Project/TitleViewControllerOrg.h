/** @file
 * The title screen, original theme.
 *
 * Reconstructed from Ghidra program Jubeat (class TitleViewControllerOrg, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c TitleViewController , from the dyld bind at the class object's superclass
 * slot (0x34a78 + 8) and confirmed by the super calls at 0x13abe8, 0x13c5e8, and 0x13c4c8.
 *
 * The class is complete: all twenty-four hand-written members are recovered. The view construction,
 * animation control, and input handling are declared but not reconstructed; see
 * RECONSTRUCTION_STATUS.md.
 */

#import <UIKit/UIKit.h>

#import "TitleViewController.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The title screen in the game's own livery.
 */
@interface TitleViewControllerOrg : TitleViewController

/**
 * @brief Builds the controller and subscribes to background/foreground notifications.
 * @return The initialised controller.
 * @ghidraAddress 0x13abb8
 */
- (instancetype)init;

/**
 * @brief Tears down the controller and unsubscribes from notifications.
 * @ghidraAddress 0x13c580
 */
- (void)dealloc;

/**
 * @brief Builds the view hierarchy.
 *
 * Creates the title background with its 5-frame animation and two gradient layers, then the
 * jubeat logo, touch prompt, copyright, coBtn, and marker view.
 * @ghidraAddress 0x13ac88
 */
- (void)loadView;

/**
 * @brief Begins the title sequence.
 *
 * Hides the logo views and starts the title BGM and welcome voice.
 * @ghidraAddress 0x13b65c
 */
- (void)start;

/**
 * @brief Halts the title sequence before teardown. DECLARED ONLY.
 */
- (void)stopAnimation;

/**
 * @brief Fades the touch prompt in and out forever.
 * @ghidraAddress 0x13b7a8
 */
- (void)blinkPrompt;

/**
 * @brief Starts the prompt blink and installs the four swipe and one tap recognisers.
 * @ghidraAddress 0x13b9e0
 */
- (void)startBlinkPrompt;

/**
 * @brief Fades the logo in and then starts the marker check.
 * @ghidraAddress 0x13bd1c
 */
- (void)showLogo;

/**
 * @brief Handles a tap on the title screen.
 *
 * Part of the Konami-code handler; checks the touch location against the logo rects.
 * @param sender The recogniser.
 * @ghidraAddress 0x13be70
 */
- (void)handleTap:(id)sender;

/**
 * @brief Handles a swipe on the title screen.
 *
 * Konami-code state machine on kcState.
 * @param sender The recogniser.
 * @ghidraAddress 0x13c328
 */
- (void)handleSwipe:(id)sender;

/**
 * @brief Pauses the title animation when the app backgrounds.
 * @param sender The notification.
 * @ghidraAddress 0x13c418
 */
- (void)suspend:(id)sender;

/**
 * @brief Resumes the title animation when the app foregrounds.
 * @param sender The notification.
 * @ghidraAddress 0x13c478
 */
- (void)resume:(id)sender;

/**
 * @brief Drops the views created in @c -loadView.
 * @ghidraAddress 0x13c498
 */
- (void)viewDidUnload;

/**
 * @brief Called when the marker check finishes.
 * @ghidraAddress 0x13c554
 */
- (void)markerCheckEnd;

/**
 * @brief Advances to the next scene, removing the swipe recognisers.
 * @ghidraAddress 0x13c5fc
 */
- (void)nextScene;

/**
 * @brief Creates the licence agreement view centred on the screen.
 * @ghidraAddress 0x13ca38
 */
- (void)createPolicyView;

/**
 * @brief Reports that only portrait orientations are supported.
 * @param interfaceOrientation The orientation being asked about.
 * @return @c YES for portrait and portrait-upside-down.
 * @ghidraAddress 0x13c560
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @brief The orientations the title screen allows.
 * @return Portrait and portrait-upside-down (6).
 * @ghidraAddress 0x13c570
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Whether the title screen rotates at all.
 * @return Always @c YES .
 * @ghidraAddress 0x13c578
 */
- (BOOL)shouldAutorotate;

/**
 * @brief Handles a licence agreement error.
 * @param agreement The agreement.
 * @param msgStr The error message.
 * @ghidraAddress 0x13cb84
 */
- (void)agreementError:(id)agreement msgStr:(NSString *)msgStr;

/**
 * @brief Handles a licence agreement success.
 * @param agreement The agreement.
 * @ghidraAddress 0x13cd24
 */
- (void)agreementSuccess:(id)agreement;

/**
 * @brief Handles a licence agreement failure.
 * @param agreement The agreement.
 * @ghidraAddress 0x13cd9c
 */
- (void)agreementFailed:(id)agreement;

/**
 * @brief Handles an ID download error.
 * @param download The download.
 * @param msgStr The error message.
 * @ghidraAddress 0x13ce04
 */
- (void)errorIDDownload:(id)download msgStr:(NSString *)msgStr;

/**
 * @brief Handles a successful ID download.
 * @param download The download.
 * @ghidraAddress 0x13cfac
 */
- (void)successIDDownload:(id)download;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
