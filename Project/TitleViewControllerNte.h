/**
 * @file
 * NTE (new title event) split title-screen controller.
 *
 * Reconstructed from Ghidra program Jubeat (class TitleViewControllerNte, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * This themed title hosts two stacked child controllers: an @c UnsealViewController flip-book in
 * the top strip and an @c NteTitleCoreController below it. It scales its layout for the three
 * device idioms (iPad, 3.5-inch phone, and 4-inch phone) and forwards the shared title lifecycle
 * (@c -start , @c -showLogo , @c -stopAnimation ) down to the bottom controller.
 *
 * Selected by @c -[RootViewController createKnitTitleViewController] and torn down through the base
 * @c -titleSwitch . The superclass is @c TitleViewController , taken from the @c -init tail call to
 * @c -[TitleViewController init] at 0x71ec8 (and the matching super sends in @c -loadView ,
 * @c -viewDidLoad , @c -viewDidUnload , and @c -dealloc ).
 */

#import <UIKit/UIKit.h>

#import "TitleViewController.h"
#import "UnsealViewController.h"

NS_ASSUME_NONNULL_BEGIN

// The bottom child controller's class is not yet reconstructed; forward-declared for the property.
@class NteTitleCoreController;

/**
 * The NTE themed title screen composed of a top flip-book and a bottom core controller.
 *
 * Acts as the @c UnsealViewController flip-book's delegate, relaying its page changes into the
 * bottom controller's background.
 */
@interface TitleViewControllerNte : TitleViewController <UnsealViewControllerDelegate> {
    /**
     * The layout scale for a non-iPad screen: the screen width divided by 320, or 1 on iPad.
     * Encoded @c f in the runtime metadata.
     */
    float phoneRate;
}

/** The container view for the top flip-book strip. */
@property(strong, nonatomic, nullable) UIView *topView;
/** The container view for the bottom core strip. */
@property(strong, nonatomic, nullable) UIView *bottomView;
/** The top flip-book controller. */
@property(strong, nonatomic, nullable) UnsealViewController *topController;
/** The bottom core controller. */
@property(strong, nonatomic, nullable) NteTitleCoreController *bottomController;

/**
 * Initialises the controller and builds both child controllers sized to the device idiom.
 * @return The initialised controller.
 * @ghidraAddress 0x71e74
 */
- (instancetype)init;

/**
 * Builds the base view hierarchy, then loads both child controllers' views.
 * @ghidraAddress 0x72288
 */
- (void)loadView;

/**
 * Begins the base title network work, then starts the bottom controller.
 * @ghidraAddress 0x722f8
 */
- (void)start;

/**
 * Forwards the logo reveal to the bottom controller.
 * @ghidraAddress 0x72354
 */
- (void)showLogo;

/**
 * Tears down both child controllers and stops the bottom controller's animation.
 * @ghidraAddress 0x7236c
 */
- (void)stopAnimation;

/**
 * Delegate callback from the flip-book: swaps the bottom controller's background image.
 * @param index The index of the newly shown artwork.
 * @param completed Whether the page-turn animation ran to completion.
 * @ghidraAddress 0x72474
 */
- (void)changeSelectedImage:(int)index completed:(BOOL)completed;

/**
 * Notification handler for entering the background. Does nothing.
 * @param notification The @c UIApplicationDidEnterBackgroundNotification .
 * @ghidraAddress 0x7248c
 */
- (void)suspend:(nullable NSNotification *)notification;

/**
 * Notification handler for returning to the foreground. Does nothing.
 * @param notification The @c UIApplicationWillEnterForegroundNotification .
 * @ghidraAddress 0x72490
 */
- (void)resume:(nullable NSNotification *)notification;

/**
 * Builds the top and bottom container views and installs each child controller's view.
 * @ghidraAddress 0x72494
 */
- (void)viewDidLoad;

/**
 * Chains up to the base implementation. Adds nothing.
 * @ghidraAddress 0x72868
 */
- (void)viewDidUnload;

/**
 * Rotation hook. Does nothing.
 * @param toInterfaceOrientation The orientation being rotated to.
 * @param duration The rotation animation duration.
 * @ghidraAddress 0x728a0
 */
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration;

/**
 * Size-transition hook. Does nothing.
 * @param size The size being transitioned to.
 * @param coordinator The transition coordinator.
 * @ghidraAddress 0x728a4
 */
- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator;

/**
 * Permits rotation only to the two portrait orientations.
 * @param interfaceOrientation The candidate orientation.
 * @return @c YES for portrait or upside-down portrait.
 * @ghidraAddress 0x728a8
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * The supported orientations: portrait and upside-down portrait.
 * @return @c UIInterfaceOrientationMaskPortrait | @c UIInterfaceOrientationMaskPortraitUpsideDown .
 * @ghidraAddress 0x728b8
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * Allows autorotation.
 * @return @c YES .
 * @ghidraAddress 0x728c0
 */
- (BOOL)shouldAutorotate;

/**
 * Releases the container views and removes the notification observers.
 * @ghidraAddress 0x728c8
 */
- (void)dealloc;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
