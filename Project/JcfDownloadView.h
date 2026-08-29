/**
 * @file
 * @brief The modal board that downloads one jubeatLab custom sequence (a @c .jcf chart).
 *
 * Reconstructed from Ghidra program Jubeat (class JcfDownloadView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView: @c -initWithID:delegate: calls @c -[super initWithFrame:] with the
 * board's own size (0x1eb720). The view is itself the gradient-backed board — @c +layerClass
 * returns @c CAGradientLayer — shown over a dimmed parent. It owns a @c JcfDownloader , which it
 * starts at construction time, and is that downloader's delegate: it implements the four
 * sequence-download outcome selectors and updates its label, buttons, and spinner for each.
 */

#import <UIKit/UIKit.h>

#import "JcfDownloader.h"

NS_ASSUME_NONNULL_BEGIN

@class JcfDownloadView;

/**
 * @brief What a @c JcfDownloadView tells its owner.
 *
 * Both messages are dispatched with @c -performSelector: after a @c -respondsToSelector: guard, so
 * both are optional.
 */
@protocol JcfDownloadViewDelegate <NSObject>
@optional
/**
 * @brief Sent from the Cancel/End button once the download has finished or been dismissed.
 * @param view The modal (see the reconstruction note: the binary passes the delegate itself here).
 */
- (void)jcfDownloadEnd:(nullable JcfDownloadView *)view;
/**
 * @brief Sent from the move-to-store button after a successful download whose tune belongs to a
 * purchasable pack.
 * @param view The modal (see the reconstruction note: the binary passes the delegate itself here).
 * @param packID The comprised-pack identifier the download resolved.
 */
- (void)jcfDownloadMoveStore:(nullable JcfDownloadView *)view packID:(nullable NSString *)packID;
@end

/**
 * @brief A gradient-backed board that downloads a @c .jcf chart and reports the outcome.
 */
@interface JcfDownloadView : UIView <JcfDownloaderDelegate>

/**
 * @brief The layer class backing the board: a @c CAGradientLayer .
 * @return The @c CAGradientLayer class.
 * @ghidraAddress 0x1eb4ec
 */
+ (Class)layerClass;

/**
 * @brief A @c StoreButton factory helper.
 *
 * Builds a blue-green rounded @c StoreButton , but neither stores nor adds it: the binary discards
 * the result, and the sender argument is ignored.
 * @param sender Ignored.
 * @ghidraAddress 0x1eb500
 */
- (void)createStoreBtn:(nullable id)sender;

/**
 * @brief Builds the board, its label, the three buttons, and the spinner, then starts the
 * download.
 *
 * The board is @c 320 wide on a pad and @c 300 otherwise, @c 360 tall either way. The move-to-store
 * (@c btnOK ) and end (@c btnEnd ) buttons start fully transparent, flanking the centre; the
 * centred @c btnCancel is shown while the download runs. The owned @c JcfDownloader is created and
 * begins immediately.
 * @param customID The shared chart's custom id, handed to the @c JcfDownloader .
 * @param delegateArg The object told the outcome; held weakly.
 * @return The initialised view.
 * @ghidraAddress 0x1eb638
 */
- (instancetype)initWithID:(nullable NSString *)customID
                  delegate:(nullable id<JcfDownloadViewDelegate>)delegateArg;

/**
 * @brief Cancel/End button action: ends the modal through @c -downloadEnd .
 * @param sender The button.
 * @ghidraAddress 0x1ec59c
 */
- (void)pushCancel:(nullable id)sender;

/**
 * @brief Move-to-store button action: tells the delegate @c -jcfDownloadMoveStore:packID: .
 * @param sender The button.
 * @ghidraAddress 0x1ec5a8
 */
- (void)pushMoveStore:(nullable id)sender;

/**
 * @brief Adds the full-board progress label showing "downloading".
 *
 * The download itself was already begun by the @c JcfDownloader built in
 * @c -initWithID:delegate: , so this only overlays the status label.
 * @ghidraAddress 0x1ec658
 */
- (void)startDownload;

/**
 * @brief Tells the delegate @c -jcfDownloadEnd: that the modal has finished.
 * @ghidraAddress 0x1ec78c
 */
- (void)downloadEnd;

/**
 * @brief @c JcfDownloaderDelegate : the download failed; shows the message and an OK button.
 * @param downloader The failed downloader.
 * @param msg The user-facing message, or @c nil to use the default failure text.
 * @ghidraAddress 0x1ec830
 */
- (void)errorSequenceDownload:(nullable JcfDownloader *)downloader msgStr:(nullable NSString *)msg;

/**
 * @brief @c JcfDownloaderDelegate : the edit-slot cap was reached; shows the cap message and an OK
 * button.
 * @param downloader The downloader.
 * @ghidraAddress 0x1ec914
 */
- (void)finishedSequenceOverCap:(nullable JcfDownloader *)downloader;

/**
 * @brief @c JcfDownloaderDelegate : the tune is not built in and belongs to a purchasable pack;
 * stores the pack id and reveals the move-to-store buttons.
 * @param downloader The downloader.
 * @param packID The comprised-pack identifier.
 * @ghidraAddress 0x1eca00
 */
- (void)finishedSequenceNotExistPack:(nullable JcfDownloader *)downloader
                              packID:(nullable NSString *)packID;

/**
 * @brief @c JcfDownloaderDelegate : the chart downloaded and saved; stores the tune id and shows
 * the completed message with an OK button.
 * @param downloader The downloader.
 * @param tuneID The saved tune id.
 * @ghidraAddress 0x1ecb88
 */
- (void)finishedSequenceDownload:(nullable JcfDownloader *)downloader
                          tuneID:(nullable NSString *)tuneID;

/**
 * @brief The tune id resolved by a successful download.
 * @return The music id, or @c -1 if none.
 * @ghidraAddress 0x1eccbc
 */
- (int)getDownloadMusicID;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
