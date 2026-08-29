/**
 * @file
 * The modal that downloads the marker (note-hit graphic) list and each marker.
 *
 * Reconstructed from Ghidra program Jubeat (class MarkerDownloadView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView: @c -init calls @c -[super initWithFrame:] with the main screen's
 * bounds (0x5fbf4). The view fills the screen with a dimmed cover that carries a @c StoreDialogView
 * progress panel at its centre.
 *
 * The class drives a marker download from four collaborators and is their delegate at each stage:
 * it is a @c DownloaderDelegate for the list request, a @c MarkerDownloadManagerDelegate for the
 * per-marker queue, an @c AlertViewManagerDelegate for the retry and skip prompts, and a
 * @c StoreDialogViewDelegate for the panel's abort button.
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "Downloader.h"
#import "MarkerDownloadManager.h"
#import "StoreDialogView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * What a @c MarkerDownloadView tells its owner.
 *
 * The single message is dispatched with @c -performSelector: after a @c -respondsToSelector:
 * guard, so it is optional.
 */
@protocol MarkerDownloadViewDelegate <NSObject>
@optional
/**
 * Sent once the marker check and download have finished, whether they succeeded, were
 * cancelled, or were skipped.
 */
- (void)markerCheckEnd;
@end

/**
 * A full-screen dimming cover carrying a @c StoreDialogView download-progress panel.
 */
@interface MarkerDownloadView : UIView <DownloaderDelegate,
                                        MarkerDownloadManagerDelegate,
                                        AlertViewManagerDelegate,
                                        StoreDialogViewDelegate>

/**
 * The object told when the marker check ends. Weak, and dispatched through
 * @c -respondsToSelector: .
 */
@property(nonatomic, weak, nullable) id<MarkerDownloadViewDelegate> delegate;

/**
 * The view the modal is shown over. Weak.
 */
@property(nonatomic, weak, nullable) UIView *parentView;

/**
 * Builds the cover and the progress panel at the screen's size.
 *
 * The panel is @c 400×300 on a pad and @c 300×270 otherwise, its message eighteen point on a pad
 * and sixteen otherwise, centred in the screen. The cover is a forty-per-cent black slab that
 * starts fully transparent.
 * @return The initialised view.
 * @ghidraAddress 0x5fbb4
 */
- (instancetype)init;

/**
 * Starts the marker check: shows the dialog (unless the markers are already legal) and
 * downloads the marker list.
 * @ghidraAddress 0x5ff44
 */
- (void)show;

/**
 * Requests the marker list from the store.
 * @ghidraAddress 0x5ffd0
 */
- (void)downloadMarkerList;

/**
 * Ends the check: hides the dialog and tells the delegate @c -markerCheckEnd .
 * @ghidraAddress 0x60068
 */
- (void)markerDownloadEnd;

/**
 * Aborts the check: hides the dialog, cancels the queue, resets the current marker to
 * @c "mk0026" , and tells the delegate @c -markerCheckEnd .
 * @ghidraAddress 0x60128
 */
- (void)markerDownloadCancel;

/**
 * Starts downloading the queued markers, or ends the check when the queue is empty.
 * @ghidraAddress 0x60270
 */
- (void)markerDownload;

/**
 * Builds the download queue by diffing the downloaded marker list against the installed
 * markers, then shows the dialog when there is work to do.
 * @ghidraAddress 0x603ec
 */
- (void)createMarkerDownloadList;

/**
 * @c DownloaderDelegate : the list request failed.
 * @param downloader The failed request.
 * @ghidraAddress 0x609bc
 */
- (void)downloaderError:(id)downloader;

/**
 * @c DownloaderDelegate : the list request finished; validate it and start the markers.
 * @param downloader The finished request.
 * @ghidraAddress 0x609c8
 */
- (void)downloaderFinished:(id)downloader;

/**
 * Handles a failed list download: ends the check when the markers are legal, otherwise
 * treats it as a queue failure.
 * @ghidraAddress 0x60b60
 */
- (void)listDownloadFailed;

/**
 * Presents the retry-or-skip alert (tag @c 2 ).
 * @ghidraAddress 0x60bec
 */
- (void)showDownloadRetryAlert;

/**
 * Presents the confirm-skip alert (tag @c 1 ).
 * @ghidraAddress 0x60d9c
 */
- (void)showListSkipAlert;

/**
 * @c AlertViewManagerDelegate : routes the retry and skip alert buttons.
 * @param info The alert result, carrying @c "Tag" and @c "btnMessage" .
 * @ghidraAddress 0x60f4c
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

/**
 * Fades the cover in and puts the panel into its spinner state.
 * @ghidraAddress 0x610c8
 */
- (void)showModalDialog;

/**
 * Fades the cover out, stops the spinner, and detaches the modal.
 * @ghidraAddress 0x613e0
 */
- (void)hideModalDialog;

/**
 * @c StoreDialogViewDelegate : the panel's abort button was pressed.
 * @param dialogView The panel.
 * @ghidraAddress 0x616bc
 */
- (void)storeDialogCancel:(id)dialogView;

/**
 * @c MarkerDownloadManagerDelegate : the queue made progress.
 * @param manager The queue.
 * @ghidraAddress 0x616e4
 */
- (void)downloadManagerProceed:(MarkerDownloadManager *)manager;

/**
 * @c MarkerDownloadManagerDelegate : the queue completed.
 * @param manager The queue.
 * @ghidraAddress 0x61750
 */
- (void)downloadManagerCompleted:(MarkerDownloadManager *)manager;

/**
 * @c MarkerDownloadManagerDelegate : the queue failed.
 * @param manager The queue.
 * @ghidraAddress 0x617f4
 */
- (void)downloadManagerFailed:(nullable MarkerDownloadManager *)manager;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
