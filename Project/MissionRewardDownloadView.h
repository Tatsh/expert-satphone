/** @file
 * A challenge-mission reward-item download overlay.
 *
 * Reconstructed from Ghidra program Jubeat (class MissionRewardDownloadView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The view is a centred background plate carrying a reward-item icon, a name label, a
 * three-line description label, a download button, a close button, and a hidden sample
 * button laid over the icon. It fetches the reward's image, plays a sample tune, and downloads
 * the reward item itself. The item download runs as a @c StoreDownloadManager task set behind a
 * @c StoreDialogView progress dialog, while the preliminary metadata and image fetches use a
 * @c Downloader and a @c SessionDownloader. The reward's kind is read from a
 * @c ChallengeMissionReward: sticker (5/6), music (3), marker (4), and image (0) items each take a
 * different download and install path.
 *
 * The superclass binds to @c _OBJC_CLASS_$_UIView at load time; @c -initWithFrame: chains to
 * @c -[UIView initWithFrame:]. The runtime metadata lists no adopted protocols, so the class
 * declares none; the @c Downloader, @c StoreDownloadManager, @c StoreDialogView, and
 * @c AlertViewManager callback groups below are matched informally by selector.
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "Downloader.h"
#import "StoreDownloadManager.h"

@class ChallengeMissionReward;
@class Downloader;
@class StoreDialogView;
@class StoreDownloadManager;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A challenge-mission reward-item download overlay.
 */
@interface MissionRewardDownloadView
    : UIView <AlertViewManagerDelegate, DownloaderDelegate, StoreDownloadManagerDelegate>

/**
 * @brief The overlay's owner, told when the window is closed.
 *
 * Weak, per the @c W attribute and bare @c \@ encoding in the metadata. The close handler messages
 * it through @c -respondsToSelector: / @c -performSelector:withObject: rather than a fixed
 * protocol, so it is left untyped.
 * @ghidraAddress 0x1799c8 (getter), 0x1799e8 (setter)
 */
@property(nonatomic, weak, nullable) id aDelegate;

/**
 * @brief Builds the plate, icon, labels, buttons, progress dialog, and sample controls for the
 * current idiom.
 * @param frame The view's frame.
 * @return The initialised view.
 * @ghidraAddress 0x1767d0
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Reports whether the reward item is already present on disk.
 *
 * For a sticker the answer is whether the shared app-group container is available; for a music
 * item and a marker it resolves the item's on-disk path (also caching it in @c itemPath) and asks
 * @c NSFileManager whether that file exists.
 * @return @c YES when the item is considered already downloaded.
 * @ghidraAddress 0x176534
 */
- (BOOL)checkItemDownload;

/**
 * @brief Populates the icon, labels, and download button from a reward and kicks off the image
 * fetch.
 * @param reward The reward to display.
 * @param enableDownload Whether the download button should be offered.
 * @ghidraAddress 0x177378
 */
- (void)setMissionInfo:(nullable ChallengeMissionReward *)reward
        enableDownload:(BOOL)enableDownload;

/**
 * @brief The close button's action: stops any sample playback, cancels downloads, and tells the
 * delegate to close the reward window.
 * @param sender The close button.
 * @ghidraAddress 0x177648
 */
- (void)tapCloseBtn:(nullable id)sender;

/**
 * @brief The sample button's action: downloads the sample-tune metadata, or toggles playback of an
 * already-loaded sample.
 * @ghidraAddress 0x1777fc
 */
- (void)tapSample;

/**
 * @brief Timer callback that starts sample playback once the loading delay elapses.
 * @ghidraAddress 0x177a38
 */
- (void)sampleWait;

/**
 * @brief The download button's action: posts the reward id and begins the metadata fetch.
 * @ghidraAddress 0x177b4c
 */
- (void)tapDownload;

/**
 * @brief Downloader completion callback; dispatches on the request's tag.
 * @param downloader The finished request.
 * @ghidraAddress 0x177cf8
 */
- (void)downloaderFinished:(nullable Downloader *)downloader;

/**
 * @brief Downloader failure callback; stops spinners, dismisses the dialog, and shows an error
 * alert for the item-download stage.
 * @param downloader The failed request.
 * @ghidraAddress 0x178f60
 */
- (void)downloaderError:(nullable Downloader *)downloader;

/**
 * @brief Downloader progress callback; drives the dialog's progress bar during the item download.
 * @param downloader The request making progress.
 * @ghidraAddress 0x1790a4
 */
- (void)downloaderProceed:(nullable Downloader *)downloader;

/**
 * @brief The progress dialog's abort callback: cancels the item download and hides the dialog.
 * @param dialogView The dialog whose abort button was pressed.
 * @ghidraAddress 0x179130
 */
- (void)storeDialogCancel:(nullable StoreDialogView *)dialogView;

/**
 * @brief Fades the progress dialog in.
 * @ghidraAddress 0x1791e0
 */
- (void)showDialog;

/**
 * @brief Plays a sound effect and fades the progress dialog out.
 * @ghidraAddress 0x179458
 */
- (void)hideDialog;

/**
 * @brief Alert-button callback; closes the challenge-mode session on the server-error alert.
 * @param info The alert's echoed-back info dictionary.
 * @ghidraAddress 0x1796bc
 */
- (void)alertSelect:(nullable NSDictionary *)info;

/**
 * @brief Store download-manager task-start callback. Empty in this view.
 * @param manager The download manager.
 * @ghidraAddress 0x17977c
 */
- (void)downloadManagerStartTask:(nullable StoreDownloadManager *)manager;

/**
 * @brief Store download-manager completion callback; records the reward, dismisses the dialog, and
 * marks the button downloaded.
 * @param manager The download manager.
 * @ghidraAddress 0x179780
 */
- (void)downloadManagerCompleted:(nullable StoreDownloadManager *)manager;

/**
 * @brief Store download-manager failure callback; shows an error alert and dismisses the dialog.
 * @param manager The download manager.
 * @ghidraAddress 0x17987c
 */
- (void)downloadManagerFailed:(nullable StoreDownloadManager *)manager;

/**
 * @brief Store download-manager progress callback; drives the dialog's progress bar.
 * @param manager The download manager.
 * @ghidraAddress 0x17995c
 */
- (void)downloadManagerProceed:(nullable StoreDownloadManager *)manager;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
