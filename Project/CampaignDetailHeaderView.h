/**
 * @file
 * @brief The header panel atop a campaign-detail page.
 *
 * Reconstructed from Ghidra program Jubeat (class CampaignDetailHeaderView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, from the @c -initWithFrame: chain-up at 0x121f4c. The header shows
 * the campaign item's artwork with a faded reflection, its name and comment, a download button and
 * a link button whose taps forward to the header's delegate, and a BGM sample play/stop control
 * with an activity indicator. It downloads the sample as a @c Downloader delegate and reacts to the
 * audio player finishing as an audio finish callback.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"

@class CampaignItemInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Receives the header's button taps.
 *
 * The download and link buttons target the header's delegate directly, so the delegate carries out
 * the purchase and the link navigation.
 */
@protocol CampaignDetailHeaderViewDelegate <NSObject>

/**
 * @brief Sent when the download button is tapped.
 * @param sender The download button.
 */
- (void)doPurchase:(nullable id)sender;

/**
 * @brief Sent when the link button is tapped.
 * @param sender The link button.
 */
- (void)handleLink:(nullable id)sender;

@end

/**
 * @brief A campaign item's detail header: artwork with its reflection, name, comment, a download
 * button, a link button, and a tappable BGM sample control.
 */
@interface CampaignDetailHeaderView : UIView <DownloaderDelegate>

/**
 * @brief The object that carries out the download and link button taps. Held weakly.
 * @ghidraAddress 0x123610 (getter)
 * @ghidraAddress 0x123630 (setter)
 */
@property(nonatomic, weak, nullable) id<CampaignDetailHeaderViewDelegate> delegate;

/**
 * @brief Builds the header's subviews.
 * @param frame The header's frame.
 * @return The initialised header.
 * @ghidraAddress 0x121ef4
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Lays the header out for a campaign item: sizes the name and comment to their text,
 * repositions the download and link buttons below the content, grows the header to fit, refreshes
 * the download button, and enables the sample control if the item has a sample.
 * @param itemInfo The campaign item to display.
 * @ghidraAddress 0x122a90
 */
- (void)setCampaignInfo:(nullable CampaignItemInfo *)itemInfo;

/**
 * @brief Sets the artwork and rebuilds its reflection.
 * @param artwork The artwork image.
 * @ghidraAddress 0x122e70
 */
- (void)setArtwork:(nullable UIImage *)artwork;

/**
 * @brief Replaces the campaign item and refreshes the download button.
 * @param itemInfo The new campaign item.
 * @ghidraAddress 0x123098
 */
- (void)updateCampaignState:(nullable CampaignItemInfo *)itemInfo;

/**
 * @brief Toggles BGM sample playback: starts a sample download and spins the indicator, or stops
 * the current playback.
 * @param sender The sample button.
 * @ghidraAddress 0x1230ec
 */
- (void)handleSample:(nullable id)sender;

/**
 * @brief Fades out any BGM sample, tears the sample download down, and resets the control.
 * @ghidraAddress 0x123240
 */
- (void)stopSample;

/**
 * @brief Handles the audio player finishing the BGM sample: clears the playing state and hides the
 * playing marker.
 * @param notification The finish notification.
 * @ghidraAddress 0x1232ec
 */
- (void)finishBgm:(nullable NSNotification *)notification;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
