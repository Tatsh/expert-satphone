/** @file
 * The title screen, ripples (Rpl) theme.
 *
 * Reconstructed from Ghidra program Jubeat (class TitleViewControllerRpl, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c TitleViewController , from the dyld bind at the class object's superclass
 * slot (0x348a70 + 8) and confirmed by the super calls at 0x13d140, 0x13ff9c, and 0x13fea0.
 *
 * The class is complete: all twenty-four hand-written members are recovered, including the ripple
 * background built by @c -addRippleLayers .
 */

#import <UIKit/UIKit.h>

#import "EditorIDManager.h"
#import "MarkerDownloadView.h"
#import "TitleViewController.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The title screen in the ripples livery.
 */
@interface TitleViewControllerRpl
    : TitleViewController <EditorIDManagerDelegate, MarkerDownloadViewDelegate>

/**
 * @brief Builds the controller, records whether this is a pad, and subscribes to notifications.
 * @return The initialised controller.
 * @ghidraAddress 0x13d140
 */
- (instancetype)init;

/**
 * @brief Tears down the controller and unsubscribes from notifications.
 * @ghidraAddress 0x13ff9c
 */
- (void)dealloc;

/**
 * @brief Builds the view hierarchy.
 *
 * Stores yHorizon, builds the sky and reflection gradient layers, and the jubeat logo, touch,
 * copyright, and marker views.
 * @ghidraAddress 0x13e17c
 */
- (void)loadView;

/**
 * @brief Begins the title sequence.
 *
 * Hides the logo views, adds ripple layers, and starts the title BGM.
 * @ghidraAddress 0x13e918
 */
- (void)start;

/**
 * @brief Fades the touch prompt in and out forever.
 * @ghidraAddress 0x13ea74
 */
- (void)blinkPrompt;

/**
 * @brief Adds ripple layers to the background.
 * @ghidraAddress 0x13d250
 */
- (void)addRippleLayers;

/**
 * @brief Starts the prompt blink and installs the four swipe and one tap recognisers.
 * @ghidraAddress 0x13ecac
 */
- (void)startBlinkPrompt;

/**
 * @brief Fades the logo in and then starts the marker check.
 * @ghidraAddress 0x13efe8
 */
- (void)showLogo;

/**
 * @brief Handles a tap on the title screen.
 *
 * Part of the Konami-code handler.
 * @param sender The recogniser.
 * @ghidraAddress 0x13f13c
 */
- (void)handleTap:(id)sender;

/**
 * @brief Handles a swipe on the title screen.
 *
 * Konami-code state machine on kcState.
 * @param sender The recogniser.
 * @ghidraAddress 0x13f990
 */
- (void)handleSwipe:(id)sender;

/**
 * @brief Pauses the title animation when the app backgrounds.
 * @param sender The notification.
 * @ghidraAddress 0x13fa80
 */
- (void)suspend:(id)sender;

/**
 * @brief Resumes the title animation when the app foregrounds.
 * @param sender The notification.
 * @ghidraAddress 0x13fca4
 */
- (void)resume:(id)sender;

/**
 * @brief Drops the views created in @c -loadView.
 * @ghidraAddress 0x13fea0
 */
- (void)viewDidUnload;

/**
 * @brief Called when the marker check finishes.
 * @ghidraAddress 0x13ff70
 */
- (void)markerCheckEnd;

/**
 * @brief Advances to the next scene.
 * @ghidraAddress 0x140018
 */
- (void)nextScene;

/**
 * @brief Creates the licence agreement view.
 * @ghidraAddress 0x140454
 */
- (void)createPolicyView;

/**
 * @brief Reports that only portrait orientations are supported.
 * @param interfaceOrientation The orientation being asked about.
 * @return @c YES for portrait and portrait-upside-down.
 * @ghidraAddress 0x13ff7c
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @brief The orientations the title screen allows.
 * @return Portrait and portrait-upside-down (6).
 * @ghidraAddress 0x13ff8c
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Whether the title screen rotates at all.
 * @return Always @c YES .
 * @ghidraAddress 0x13ff94
 */
- (BOOL)shouldAutorotate;

/**
 * @brief Handles a licence agreement error.
 * @param agreement The agreement.
 * @param msgStr The error message.
 * @ghidraAddress 0x1405a0
 */
- (void)agreementError:(id)agreement msgStr:(NSString *)msgStr;

/**
 * @brief Handles a licence agreement success.
 * @param agreement The agreement.
 * @ghidraAddress 0x140740
 */
- (void)agreementSuccess:(id)agreement;

/**
 * @brief Handles a licence agreement failure.
 * @param agreement The agreement.
 * @ghidraAddress 0x1407b8
 */
- (void)agreementFailed:(id)agreement;

/**
 * @brief Handles an ID download error.
 * @param download The download.
 * @param msgStr The error message.
 * @ghidraAddress 0x140820
 */
- (void)errorIDDownload:(nullable id)download msgStr:(nullable NSString *)msgStr;

/**
 * @brief Handles a successful ID download.
 * @param download The download.
 * @ghidraAddress 0x1409c8
 */
- (void)successIDDownload:(nullable id)download;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
