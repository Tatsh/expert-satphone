/**
 * @file
 * Base title controller.
 *
 * Reconstructed from Ghidra program Jubeat (class TitleViewController, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * This is the shared base of the four themed title screens (Org, Rpl, Knt, Nte). It owns the
 * corporate ("co_info") button, the licence/message overlay, the top-page licence check
 * (@c jubeatLabAccess), and the news-list download (@c Downloader). The themed subclasses add the
 * logo, blink prompt, gesture handling, and marker check on top of it.
 *
 * The superclass is @c UIViewController , from the @c -init tail call to
 * @c -[UIViewController init] at 0x1e0f0. There is no hand-written @c -dealloc ; the class relies
 * on the compiler-emitted @c .cxx_destruct at 0x1f2c4.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "MessageTextView.h"

NS_ASSUME_NONNULL_BEGIN

@class jubeatLabAccess;

/**
 * Base class for the four themed title screens.
 *
 * Acts as the delegate for the message overlay and the news-list downloader, and as the callback
 * target for the top-page licence check.
 */
@interface TitleViewController : UIViewController <DownloaderDelegate, MessageTextViewDelegate> {
    /** The "explain" button opening the payment-services (資金決済法について) message overlay. */
    UIButton *explainBtn;
    /** The corporate ("co_info") button opening the Konami site; built in @c setCorporateButton. */
    UIButton *coBtn;
    /**
     * Whether taps are currently accepted. Encoded @c ^B in the runtime metadata: it is a
     * @c BOOL pointer used purely as a truthy flag, only ever assigned @c (BOOL *)YES / @c NO and
     * never dereferenced.
     */
    BOOL *bEnableTap;
    /** The top-page licence-URL fetch, live between @c -start and its completion. */
    jubeatLabAccess *labAccess;
    /** The news-list download, live between @c -start and its completion. */
    Downloader *infoDownloader;
    /** The payment-services message overlay shown by @c -tapExplain: . */
    MessageTextView *textView;
    /** The dimming backdrop behind @c textView . */
    UIView *coverView;
}

/**
 * Initialises the controller and enables tapping.
 * @return The initialised controller.
 * @ghidraAddress 0x1e0f0
 */
- (instancetype)init;

/**
 * Builds the base view hierarchy: adds the corporate button.
 * @ghidraAddress 0x1e13c
 */
- (void)loadView;

/**
 * Opens the payment-services message overlay.
 *
 * Disables tapping, fades in a dimming backdrop and a @c MessageTextView that downloads the
 * challenge-mode policy text, both centred on the view.
 * @param sender The button that was tapped.
 * @ghidraAddress 0x1e190
 */
- (void)tapExplain:(nullable id)sender;

/**
 * Opens the Konami corporate site in a Safari view controller.
 * @param sender The button that was tapped.
 * @ghidraAddress 0x1e6dc
 */
- (void)tapCorporateButton:(nullable id)sender;

/**
 * Dismisses the message overlay and re-enables tapping.
 * @param sender The message overlay reporting its close.
 * @ghidraAddress 0x1e7c4
 */
- (void)closeMessage:(nullable id)sender;

/**
 * Shows a download-failure alert, then dismisses the message overlay and re-enables tapping.
 * @param sender The message overlay reporting the failure.
 * @param msgStr The server-supplied error text shown in the alert.
 * @ghidraAddress 0x1e840
 */
- (void)messageDownloadError:(nullable id)sender msgStr:(nullable NSString *)msgStr;

/**
 * Begins the title-screen network work.
 *
 * Kicks off the top-page licence check and the news-list download.
 * @ghidraAddress 0x1e9a8
 */
- (void)start;

/**
 * Shows the logo. Empty in the base class; overridden by the themed subclasses.
 * @ghidraAddress 0x1ea8c
 */
- (void)showLogo;

/**
 * Cancels the licence check and the news-list download.
 * @ghidraAddress 0x1ea90
 */
- (void)stopAnimation;

/**
 * Callback: the top-page licence check failed. Drops the request.
 * @param access The finished request.
 * @ghidraAddress 0x1eb04
 */
- (void)jubeatLabAccessError:(nullable id)access;

/**
 * Callback: the top-page licence check finished.
 *
 * On status 0, stores the encrypted lab URL in @c NSUserDefaults .
 * @param access The finished request.
 * @ghidraAddress 0x1eb1c
 */
- (void)jubeatLabAccessFinished:(nullable id)access;

/**
 * Callback: the news-list download finished.
 *
 * Parses the server time (an April-1 date turns on the hidden April-Fools flags), the encrypted
 * info-list URL, and the notification-page URL and its update time.
 * @param downloader The finished request.
 * @ghidraAddress 0x1ec5c
 */
- (void)downloaderFinished:(nullable id)downloader;

/**
 * Switches to the next controller. Empty in the base class; overridden by subclasses.
 * @ghidraAddress 0x1f0f4
 */
- (void)switchController;

/**
 * Builds the corporate ("co_info") button, themed and anchored to the top-right corner.
 * @ghidraAddress 0x1f0f8
 */
- (void)setCorporateButton;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
