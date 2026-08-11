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
 * The class is complete: all twenty-one hand-written members are recovered.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The launch splash screen and its logo animation.
 */
@interface LogoViewController : UIViewController <DownloaderDelegate>

/**
 * @brief Builds the controller.
 *
 * Does nothing but call @c super . The ivars are set up in @c -loadView instead.
 *
 * @return The initialised controller.
 * @ghidraAddress 0x82414
 */
- (instancetype)init;

/**
 * @brief Builds the view hierarchy by hand rather than from a nib.
 *
 * Creates the three logo images centred on the view and starting invisible, then starts the two
 * downloads that run behind the animation.
 *
 * @ghidraAddress 0x8244c
 */
- (void)loadView;

/**
 * @brief Runs one step of the logo animation and schedules the next.
 *
 * Each step animates one fade and passes itself as that animation's completion, so the sequence
 * advances one step per finished animation rather than on a timer. Once the sequence is over this
 * arms the timer that sends @c -end: .
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
 * @brief Skips ahead when the screen is tapped.
 *
 * A tap during either BEMANI logo step cuts that step short and jumps to the age-rating notice; a
 * tap while the notice is up ends the splash immediately instead of waiting out its hold. Taps at
 * any other point do nothing, and the recogniser is only installed once the BEMANI logo starts, so
 * the Konami logo cannot be skipped at all.
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
 * Handles all three downloaders. The knit-colour response also names the campaign banner, which is
 * either already cached or fetched by a fourth request; the banner is written to disk enciphered.
 * The event response can switch the app into hinabita or NagaCora mode.
 *
 * @param downloader The downloader that finished.
 * @ghidraAddress 0x83598
 */
- (void)downloaderFinished:(nullable Downloader *)downloader;

/**
 * @brief Called when a download fails.
 *
 * Forgets the downloader, but only for two of the three; a failed event request is left in place.
 *
 * @param downloader The downloader that failed.
 * @ghidraAddress 0x83c90
 */
- (void)downloaderError:(nullable Downloader *)downloader;

/**
 * @brief Empties the campaign image cache.
 *
 * Removes every file in the cache directory, not just one, and leaves the directory itself.
 *
 * @ghidraAddress 0x83cfc
 */
- (void)removeCampaignImage;

/**
 * @brief The directory the campaign image is cached in, creating it if absent.
 *
 * @return The directory path.
 * @ghidraAddress 0x83eb4
 */
- (nullable NSString *)getCampaignImageDirPath;

/**
 * @brief The on-disk path for one campaign image.
 *
 * @param name The image's name.
 * @return The full path.
 * @ghidraAddress 0x83f88
 */
- (nullable NSString *)getCampaignImagePath:(nullable NSString *)name;

/**
 * @brief Whether a campaign image is already cached.
 *
 * A miss empties the whole cache directory as a side effect, so the cache is all-or-nothing.
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
