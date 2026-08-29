/**
 * @file
 * @brief The store campaign item-detail card.
 *
 * Reconstructed from Ghidra program Jubeat (class CampaignItemDetailView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, from the chain-up in @c -initWithFrame: at 0x171ec4.
 *
 * The card shows one campaign item's icon, name, explanation, unlock terms, and copyright; it
 * offers a download/purchase button and an external-link button, and it can play a sample tune. It
 * acts as a @c DownloaderDelegate for both its info fetch and its sample fetch, and as an
 * @c AlertViewManagerDelegate for the network-error alerts it raises.
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "Downloader.h"

@class CampaignItemInfo;
@class StoreImageView;
@class UnselectableTextView;
// StoreCampaignViewController owns this card and is only messaged, never sized, here; it is not yet
// reconstructed, so declare the selectors this class sends to it.
@class StoreCampaignViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Which artwork and title the download button should carry.
 *
 * The value is @c CampaignItemInfo.buttonType, mapped by @c -getButtonColor: and
 * @c -getButtonName: to a fill colour and a title.
 */
typedef NS_ENUM(int, CampaignItemDetailButtonType) {
    CampaignItemDetailButtonTypeDownload = 0,   /*!< A blue "download" button. */
    CampaignItemDetailButtonTypeDownloaded = 1, /*!< A near-white "downloaded" button, disabled. */
    CampaignItemDetailButtonTypeLocked = 2,     /*!< A near-white button titled "download". */
    CampaignItemDetailButtonTypeSerial = 3,     /*!< A blue "serial input" button. */
    CampaignItemDetailButtonTypeUpdate = 4,     /*!< A green "update" button. */
};

/**
 * @brief The sample-tune playback state.
 *
 * Held in the @c samplePlaying ivar, which encodes as @c i (a 4-byte @c int). The binary only ever
 * writes @c Stopped and @c Downloading to the ivar; @c Playing exists as the @c -samplePlaying
 * artwork state rather than a value stored in the ivar.
 */
typedef NS_ENUM(int, CampaignItemSampleState) {
    CampaignItemSampleStatePlaying = 0,     /*!< The sample tune is playing. */
    CampaignItemSampleStateDownloading = 1, /*!< The sample tune is downloading. */
    CampaignItemSampleStateStopped = -1,    /*!< No sample tune is active. */
};

/**
 * @brief A campaign item's detail card.
 */
@interface CampaignItemDetailView : UIView <DownloaderDelegate, AlertViewManagerDelegate>

/**
 * @brief The card's delegate. Held weakly.
 * @ghidraAddress 0x1743ec (getter)
 * @ghidraAddress 0x17440c (setter)
 */
@property(nonatomic, weak, nullable) id delegate;

/**
 * @brief The store campaign controller that owns this card. Held weakly.
 * @ghidraAddress 0x174420 (getter)
 * @ghidraAddress 0x174440 (setter)
 */
@property(nonatomic, weak, nullable) StoreCampaignViewController *viewController;

/**
 * @brief Builds the card: the pack background, the item icon, the four labels, the two text views,
 * the download and link buttons, the sample button, and the sample activity indicator.
 * @param frame The card's frame.
 * @return The initialised card.
 * @ghidraAddress 0x171e6c
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Maps a button state to its fill colour.
 * @param buttonType The button state.
 * @return The fill colour.
 * @ghidraAddress 0x171ca0
 */
- (nullable UIColor *)getButtonColor:(int)buttonType;

/**
 * @brief Maps a button state to its title.
 * @param buttonType The button state.
 * @return The title, or nil for an out-of-range state.
 * @ghidraAddress 0x171de0
 */
- (nullable NSString *)getButtonName:(int)buttonType;

/**
 * @brief Sets the item to display without any side effects. The class has no @c campaignInfo
 * property; this stores the @c itemInfo ivar directly.
 * @param campaignInfo The campaign item.
 * @ghidraAddress 0x173474
 */
- (void)setCampaignInfo:(nullable CampaignItemInfo *)campaignInfo;

/**
 * @brief Replaces the item and refreshes the download button.
 * @param campaignInfo The new campaign item.
 * @ghidraAddress 0x173288
 */
- (void)updateCampaignState:(nullable CampaignItemInfo *)campaignInfo;

/**
 * @brief Populates the labels, icon, and buttons from the current item, and subscribes to the BGM
 * finish notification.
 * @ghidraAddress 0x173488
 */
- (void)loadInfo;

/**
 * @brief Refreshes the download button's colour, titles, and enabled state from the item.
 * @ghidraAddress 0x173138
 */
- (void)dlButtonUpdate;

/**
 * @brief Whether the device already holds the current item's data.
 * @return @c YES when the item is present.
 * @ghidraAddress 0x1732dc
 */
- (BOOL)hasItem;

/**
 * @brief Clears the item and returns every subview to its empty state, and unsubscribes from the
 * BGM finish notification.
 * @ghidraAddress 0x172e34
 */
- (void)removeCampaignInfo;

/**
 * @brief Cancels the in-flight info download, if any.
 * @ghidraAddress 0x173060
 */
- (void)cancelLoading;

/**
 * @brief Stops the sample tune: fades out the BGM, drops the sample downloader, and resets the
 * sample UI and state.
 * @ghidraAddress 0x1730ac
 */
- (void)stopSample;

/**
 * @brief Download-button tap: forwards to the owning controller's item download.
 * @param sender The download button.
 * @ghidraAddress 0x17384c
 */
- (void)doPurchase:(nullable id)sender;

/**
 * @brief Link-button tap: forwards to the owning controller's external link.
 * @param sender The link button.
 * @ghidraAddress 0x17388c
 */
- (void)handleLink:(nullable id)sender;

/**
 * @brief Sample-button tap: starts the sample download when idle, otherwise stops playback.
 * @param sender The sample button.
 * @ghidraAddress 0x1738cc
 */
- (void)handleSample:(nullable id)sender;

/**
 * @brief BGM-finish notification handler: marks the sample stopped and resets the sample UI.
 * @param notification The notification.
 * @ghidraAddress 0x1739f8
 */
- (void)finishBgm:(nullable NSNotification *)notification;

/**
 * @brief Puts the sample button into its stopped artwork.
 * @ghidraAddress 0x173ef0
 */
- (void)sampleStop;

/**
 * @brief Puts the sample button into its downloading artwork and starts the indicator.
 * @ghidraAddress 0x173f9c
 */
- (void)sampleDownloading;

/**
 * @brief Puts the sample button into its playing artwork and stops the indicator.
 * @ghidraAddress 0x174048
 */
- (void)samplePlaying;

/**
 * @brief @c Downloader completion: on the sample download, loads and plays the sample BGM.
 * @param downloader The finished request.
 * @ghidraAddress 0x173a14
 */
- (void)downloaderFinished:(id)downloader;

/**
 * @brief @c Downloader failure: raises a network-error alert for the info or sample download.
 * @param downloader The failed request.
 * @ghidraAddress 0x173b2c
 */
- (void)downloaderError:(id)downloader;

/**
 * @brief @c Downloader progress. The shipped body is empty.
 * @param downloader The request.
 * @ghidraAddress 0x173eec
 */
- (void)downloaderProceed:(id)downloader;

/**
 * @brief Alert-dismiss delegate: on the info-error alert, tells the owning controller to close.
 * @param info The alert result dictionary.
 * @ghidraAddress 0x1740f4
 */
- (void)alertClose:(nonnull NSDictionary *)info;

/**
 * @brief Alert-button delegate: on the info-error alert, tells the owning controller to close.
 * @param info The alert result dictionary.
 * @ghidraAddress 0x1741f0
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

/**
 * @brief Closes any presented alert.
 * @ghidraAddress 0x1742ec
 */
- (void)detailClose;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
