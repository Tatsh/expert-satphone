/** @file
 * The splash screen shown at launch: the Konami and BEMANI logos, then the age-rating notice.
 *
 * Reconstructed from Ghidra program Jubeat (class LogoViewController, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController , from the dyld bind at the class object's superclass slot
 * (0x34d3f0).
 *
 * The controller doubles as the delegate for three @c Downloader objects, which fetch campaign
 * artwork while the logos play, so the wait for the network is hidden behind the animation.
 *
 * RECONSTRUCTION STATE: eleven of twenty-one members written. The animation driver, the
 * initialiser, and the campaign-image handling are declared but not reconstructed; see
 * RECONSTRUCTION_STATUS.md.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The launch splash screen and its logo animation.
 */
@interface LogoViewController : UIViewController

/**
 * @brief Builds the controller.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @return The initialised controller.
 * @ghidraAddress 0x82414
 */
- (instancetype)init;

/**
 * @brief Builds the view hierarchy by hand rather than from a nib.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @ghidraAddress 0x8244c
 */
- (void)loadView;

/**
 * @brief Advances the logo animation one step.
 *
 * DECLARED ONLY — the body has not been reconstructed yet. This is the state machine that drives
 * the @c state ivar.
 *
 * @ghidraAddress 0x828ec
 */
- (void)fireAnimation;

/**
 * @brief Resets the splash to its opening frame and starts the animation.
 *
 * Blacks out the view, hides both logos, and returns @c state to zero.
 *
 * @ghidraAddress 0x82fe0
 */
- (void)start;

/**
 * @brief Tears the splash down and hands control back to the root controller.
 *
 * @param sender The timer or control that ended the splash. Unused.
 * @ghidraAddress 0x830bc
 */
- (void)end:(nullable id)sender;

/**
 * @brief Skips the remainder of the splash when the screen is tapped.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param sender The recognising gesture.
 * @ghidraAddress 0x8314c
 */
- (void)handleTap:(nullable id)sender;

/**
 * @brief Drops the views and cancels the downloads that are still in flight.
 * @ghidraAddress 0x8335c
 */
- (void)viewDidUnload;

/**
 * @brief Reports that only the two portrait orientations are supported.
 * @param interfaceOrientation The orientation being asked about.
 * @return @c YES for either portrait orientation.
 * @ghidraAddress 0x8350c
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @brief The orientations the splash allows.
 * @return Both portrait orientations.
 * @ghidraAddress 0x8351c
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Whether the splash rotates at all.
 * @return Always @c YES .
 * @ghidraAddress 0x83524
 */
- (BOOL)shouldAutorotate;

/**
 * @brief Called when a download finishes.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param downloader The downloader that finished.
 * @ghidraAddress 0x83598
 */
- (void)downloaderFinished:(nullable id)downloader;

/**
 * @brief Called when a download fails.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param downloader The downloader that failed.
 * @ghidraAddress 0x83c90
 */
- (void)downloaderError:(nullable id)downloader;

/**
 * @brief Deletes the cached campaign image.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @ghidraAddress 0x83cfc
 */
- (void)removeCampaignImage;

/**
 * @brief The directory the campaign image is cached in.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @return The directory path.
 * @ghidraAddress 0x83eb4
 */
- (nullable NSString *)getCampaignImageDirPath;

/**
 * @brief The on-disk path for one campaign image.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param name The image's name.
 * @return The full path.
 * @ghidraAddress 0x83f88
 */
- (nullable NSString *)getCampaignImagePath:(nullable NSString *)name;

/**
 * @brief Whether a campaign image is already cached.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param name The image's name.
 * @return @c YES when the file is present.
 * @ghidraAddress 0x8400c
 */
- (BOOL)checkCampaignImage:(nullable NSString *)name;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
