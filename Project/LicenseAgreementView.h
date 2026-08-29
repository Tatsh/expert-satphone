/**
 * @file
 * @brief Licence agreement overlay shown on the title screen.
 *
 * Reconstructed from Ghidra program Jubeat (class LicenseAgreementView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A @c CAGradientLayer -backed licence-agreement sheet.
 *
 * Downloads the current licence date and message (through @c jubeatLabAccess , a @c Downloader , or
 * a @c SessionDownloader depending on the preference key), presents the licence text in a
 * scrollable @c UITextView with Agree and Disagree buttons, and records the agreed date against the
 * key in @c NSUserDefaults . The Agree button becomes enabled only once the user scrolls the policy
 * text to the bottom.
 */
// clang-format off
// One protocol per line: the packed form, which begins a continuation line with ": UIView <", is
// read by Doxygen as undocumented ivars named after the trailing protocols.
@interface LicenseAgreementView : UIView <DownloaderDelegate,
                                          UIScrollViewDelegate,
                                          UITextViewDelegate>
// clang-format on

/**
 * @brief The layer class, so the view is backed by a @c CAGradientLayer .
 * @return The @c CAGradientLayer class.
 * @ghidraAddress 0x1f5278
 */
+ (Class)layerClass;

/**
 * @brief Designated initialiser: builds the board and starts the licence-date download.
 *
 * Stores @p delegate weakly and @p keyString as the defaults key, defaults the pad scale to 1.0
 * (raising it to 1.5 when running on a pad and the key is pad-scaled), then dispatches on the key:
 * @c PrefAgreeLicenseVersion starts a @c jubeatLabAccess licence-version download;
 * @c PrefTitleAgreeLicenseVersion compares the stored agreed date against the app delegate's
 * current licence date and either notifies the delegate or builds the board;
 * @c PrefStoreAgreeLicenseVersion starts a store-policy @c Downloader ; and
 * @c PrefAgreeChallengePolicyVersion starts a challenge-policy @c SessionDownloader .
 * @param delegate The object notified of the agreement outcome. Held weakly.
 * @param keyString The @c NSUserDefaults key recording the agreed licence date.
 * @return The initialised view.
 * @ghidraAddress 0x1f528c
 */
- (instancetype)init:(nullable id)delegate keyString:(nullable NSString *)keyString;

/**
 * @brief Reports whether the given key participates in the pad-scaled layout.
 * @param key The defaults key.
 * @return @c YES for the title, store, and challenge licence keys.
 * @ghidraAddress 0x1f51ec
 */
- (BOOL)enablePadScale:(nullable NSString *)key;

/**
 * @brief Reports whether the licence stored under the key predates the downloaded current date.
 * @param agreedDate The date last agreed to, or nil when nothing has been agreed.
 * @param currentDate The current licence date from the server.
 * @return @c YES when no date has been agreed or the agreed date is earlier than @p currentDate .
 * @ghidraAddress 0x1f64c8
 */
- (BOOL)checkLicenseUpdate:(nullable NSString *)agreedDate
               currentDate:(nullable NSString *)currentDate;

/**
 * @brief Builds the gradient board, heading, scrollable policy text, and the two buttons.
 * @param message The licence policy text.
 * @ghidraAddress 0x1f6604
 */
- (void)createLicenseBoard:(nullable NSString *)message;

/**
 * @brief Empty in the shipped binary.
 * @param message The message that would be displayed.
 * @ghidraAddress 0x1f6600
 */
- (void)displayMessage:(nullable NSString *)message;

/**
 * @brief Routes a download error message to the delegate's @c agreementError:msgStr: .
 * @param msgStr The error message, or nil.
 * @ghidraAddress 0x1f5928
 */
- (void)sendErrorDelegate:(nullable NSString *)msgStr;

/**
 * @brief @c jubeatLabAccess callback for download progress. Empty in the shipped binary.
 * @param access The licence-access client.
 * @ghidraAddress 0x1f59d0
 */
- (void)jubeatLabAccessProceed:(nullable id)access;

/**
 * @brief @c jubeatLabAccess callback for a failed download; reports the error to the delegate.
 * @param access The licence-access client.
 * @ghidraAddress 0x1f59d4
 */
- (void)jubeatLabAccessError:(nullable id)access;

/**
 * @brief @c jubeatLabAccess callback for a finished download; parses the response and drives the
 * flow.
 * @param access The licence-access client.
 * @ghidraAddress 0x1f59e4
 */
- (void)jubeatLabAccessFinished:(nullable id)access;

/**
 * @brief @c Downloader callback for a finished download; parses the store or challenge response.
 * @param downloader The download that finished.
 * @ghidraAddress 0x1f5cd0
 */
- (void)downloaderFinished:(nullable id)downloader;

/**
 * @brief @c Downloader callback for a failed download; reports the error to the delegate.
 * @param downloader The download that failed.
 * @ghidraAddress 0x1f64b4
 */
- (void)downloaderError:(nullable id)downloader;

/**
 * @brief @c Downloader callback for download progress. Empty in the shipped binary.
 * @param downloader The download in progress.
 * @ghidraAddress 0x1f64c4
 */
- (void)downloaderProceed:(nullable id)downloader;

/**
 * @brief Persists the agreed date and fades the board out, then notifies the delegate.
 * @param sender The Agree button.
 * @ghidraAddress 0x1f76c4
 */
- (void)pushAgree:(nullable id)sender;

/**
 * @brief Notifies the delegate that the user declined.
 * @param sender The Disagree button.
 * @ghidraAddress 0x1f78b0
 */
- (void)pushDisAgree:(nullable id)sender;

/**
 * @brief Enables the Agree button once the policy text is scrolled to the bottom.
 * @param scrollView The scrolling licence text view.
 * @ghidraAddress 0x1f74fc
 */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;

/**
 * @brief Enables the Agree button when dragging ends at the bottom of the policy text.
 * @param scrollView The scrolling licence text view.
 * @param decelerate Whether scrolling will continue to decelerate.
 * @ghidraAddress 0x1f75e0
 */
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;

/**
 * @brief The view that is dimmed behind the sheet.
 * @ghidraAddress 0x1f7954 (getter), 0x1f7974 (setter).
 */
@property(weak, nonatomic, nullable) UIView *weakCoverView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
