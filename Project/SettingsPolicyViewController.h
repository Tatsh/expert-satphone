/**
 * @file
 * @brief The settings-screen policy/terms view controller.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsPolicyViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. It downloads one
 * of four legal documents (chosen by the policy type it is constructed with) from the challenge
 * server and shows the returned text in a non-editable @c UITextView over a white background. It is
 * the @c DownloaderDelegate for that request.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The legal document a @c SettingsPolicyViewController downloads and displays. The value is
 *        sent to the server as the request's @c type and also selects the navigation-bar title.
 */
typedef NS_ENUM(int, SettingsPolicyType) {
    SettingsPolicyTypeContent = 1,         /*!< The "jubeat plus" content usage terms. */
    SettingsPolicyTypeCurrency = 2,        /*!< The in-game currency usage terms. */
    SettingsPolicyTypePaymentServices = 4, /*!< The Payment Services Act notice. */
    SettingsPolicyTypeMinors = 8,          /*!< The notice for minors. */
};

/**
 * @brief A view controller presenting a downloaded policy/terms document in the settings screen.
 */
@interface SettingsPolicyViewController : UIViewController <DownloaderDelegate>

/**
 * @brief Sets the navigation title for the given policy type and, on iOS 7 and later, opts the
 *        layout into extending under opaque bars.
 * @param type Which policy document this controller presents.
 * @return The initialised controller.
 * @ghidraAddress 0x1d3bf4
 */
- (instancetype)initViewController:(SettingsPolicyType)type;

/**
 * @brief Builds the view: a white background and a non-editable @c UITextView, then kicks off the
 *        signed download of the selected policy document with this controller as its delegate.
 * @ghidraAddress 0x1d3d94
 */
- (void)loadView;

/**
 * @brief Loads the downloaded document text into the text view, or a localised network-error
 *        message when the response reports a failure or carries no usable policy text.
 * @param downloader The downloader that finished.
 * @ghidraAddress 0x1d415c
 */
- (void)downloaderFinished:(nullable Downloader *)downloader;

/**
 * @brief Shows a localised network-error message in the text view.
 * @param downloader The downloader that failed.
 * @ghidraAddress 0x1d43a4
 */
- (void)downloaderError:(nullable Downloader *)downloader;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
