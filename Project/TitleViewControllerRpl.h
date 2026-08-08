/** @file
 * The title screen, REFLEC BEAT plus theme.
 *
 * Reconstructed from Ghidra program Jubeat (class TitleViewControllerRpl, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c TitleViewController , from the dyld bind at the class object's superclass
 * slot (0x348a70 + 8) and confirmed by the super calls at 0x13d140, 0x13ff9c, and 0x13fea0.
 *
 * RECONSTRUCTION STATE: nine of twenty-four members written. The view construction, animation
 * control, and input handling are declared but not reconstructed; see RECONSTRUCTION_STATUS.md.
 */

#import <UIKit/UIKit.h>

#import "TitleViewController.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The title screen in REFLEC BEAT plus livery.
 */
@interface TitleViewControllerRpl : TitleViewController

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
 * @brief Builds the view hierarchy. DECLARED ONLY.
 * @ghidraAddress 0x13e17c
 */
- (void)loadView;

/**
 * @brief Begins the title sequence. DECLARED ONLY.
 * @ghidraAddress 0x13e918
 */
- (void)start;

/**
 * @brief Halts the title sequence before teardown. DECLARED ONLY.
 */
- (void)stopAnimation;

/**
 * @brief Fades the touch prompt in and out. DECLARED ONLY.
 * @ghidraAddress 0x13ea74
 */
- (void)blinkPrompt;

/**
 * @brief Adds ripple layers to the background. DECLARED ONLY.
 * @ghidraAddress 0x13d250
 */
- (void)addRippleLayers;

/**
 * @brief Starts the prompt blink and installs recognisers. DECLARED ONLY.
 * @ghidraAddress 0x13ecac
 */
- (void)startBlinkPrompt;

/**
 * @brief Fades the logo in. DECLARED ONLY.
 * @ghidraAddress 0x13efe8
 */
- (void)showLogo;

/**
 * @brief Handles a tap on the title screen. DECLARED ONLY.
 * @param sender The recogniser.
 * @ghidraAddress 0x13f13c
 */
- (void)handleTap:(id)sender;

/**
 * @brief Handles a swipe on the title screen. DECLARED ONLY.
 * @param sender The recogniser.
 * @ghidraAddress 0x13f990
 */
- (void)handleSwipe:(id)sender;

/**
 * @brief Pauses the title animation. DECLARED ONLY.
 * @param sender The notification.
 * @ghidraAddress 0x13fa80
 */
- (void)suspend:(id)sender;

/**
 * @brief Resumes the title animation. DECLARED ONLY.
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

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
