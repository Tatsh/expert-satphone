/** @file
 * A single scratch-card view: an artwork jacket hidden behind five stacked cover layers that the
 * user rubs away to reveal the artwork.
 *
 * Reconstructed from Ghidra program Jubeat (class ScratchView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "ScratchInfo.h"

@class StoreDialogView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The three discrete states @c -getState reports.
 *
 * Derived from the scratch step: a step in the mid-scratch range reports @c
 * ScratchViewStateScratching, otherwise the state follows the @c bOpen flag.
 */
typedef NS_ENUM(int, ScratchViewState) {
    ScratchViewStateClosed = 0, /*!< The card is closed and unscratched. */
    ScratchViewStateOpen = 1,   /*!< The card has been fully revealed. */
    ScratchViewStateScratching =
        2, /*!< The card is mid-scratch (step in the open animation range). */
};

/**
 * @brief The delegate a scratch card reports its progress to.
 *
 * The card sends @c -isScratchEnable and @c -scratchEnable: directly, reaches its host dialog
 * through @c -modalDialog / @c -showModalDialog: / @c -hideModalDialog , and forwards the four
 * scratch-lifecycle notifications through @c -performSelector:withObject: after a
 * @c -respondsToSelector: guard, so those four are optional.
 */
@protocol ScratchViewDelegate <NSObject>
@required
/** @brief Whether the card may currently be scratched. */
- (BOOL)isScratchEnable;
/** @brief Enables or disables scratching across the host. */
- (void)scratchEnable:(BOOL)enable;
/** @brief The host's modal download dialog, or @c nil before it has been built. */
- (nullable StoreDialogView *)modalDialog;
/** @brief Shows the modal download dialog over the given sender. */
- (void)showModalDialog:(id)sender;
/** @brief Hides the modal download dialog. */
- (void)hideModalDialog;
@optional
/** @brief Sent when this card is chosen. */
- (void)selectScratch:(id)sender;
/** @brief Sent once the scratch gesture crosses its start threshold. */
- (void)scratchStart:(id)sender;
/** @brief Sent once the card is fully scratched open. */
- (void)scratchEnd:(id)sender;
@end

/**
 * @brief One scratch card: a jacket image under five stacked cover layers, with a rub gesture, a
 * reveal effect, a download indicator, and a small scratch-progress state machine.
 */
@interface ScratchView : UIView <DownloaderDelegate>

/**
 * @brief The scratch delegate. Held weakly.
 * @ghidraAddress 0x1b0310 (getter), 0x1b0330 (setter)
 */
@property(nonatomic, weak, nullable) id<ScratchViewDelegate> aDelegate;

/**
 * @brief Builds the card, its scratch button, artwork, five cover layers, and download indicator.
 * @param frame The card's frame.
 * @return The initialised card.
 * @ghidraAddress 0x1ae120
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Installs the artwork for a scratch entry, downloading it if it is not already on disk.
 * @param info The scratch entry describing the artwork.
 * @ghidraAddress 0x1ae808
 */
- (void)refreshScratchImage:(nullable ScratchInfo *)info;

/**
 * @brief Refreshes the card from the challenge status table for its tag and resets the covers.
 * @param animated Whether to animate (unused; the covers are set directly).
 * @ghidraAddress 0x1aeb60
 */
- (void)updateView:(BOOL)animated;

/**
 * @brief Handles a tap on the card: selects it, or triggers an item download when it is open.
 * @param sender The scratch button.
 * @ghidraAddress 0x1aed40
 */
- (void)tapScratchView:(nullable id)sender;

/**
 * @brief Ends a scratch gesture by clearing the scratching flag.
 * @param sender The scratch button.
 * @ghidraAddress 0x1af09c
 */
- (void)touchEndScratch:(nullable id)sender;

/**
 * @brief Begins a scratch gesture by clearing the scratching flag.
 * @param sender The scratch button.
 * @ghidraAddress 0x1af0ac
 */
- (void)touchBeganScratch:(nullable id)sender;

/**
 * @brief Starts the download indicator spinner.
 * @ghidraAddress 0x1af0bc
 */
- (void)startIndicator;

/**
 * @brief Advances the scratch state while the finger drags, fading the covers in staggered.
 * @param sender The scratch button.
 * @ghidraAddress 0x1af0d4
 */
- (void)moveScratchView:(nullable id)sender;

/**
 * @brief Fades the reveal effect view out over the artwork.
 * @param show Whether to run the effect (false is a no-op).
 * @ghidraAddress 0x1af500
 */
- (void)scratchEffect:(BOOL)show;

/**
 * @brief Continues a paused scratch: opens the card early, or resumes and refreshes.
 * @return Whether the caller should keep the card in the paused (wait) state.
 * @ghidraAddress 0x1af660
 */
- (BOOL)scratchContinue;

/**
 * @brief Cancels a paused scratch, restoring the covers and stopping the spinner.
 * @ghidraAddress 0x1af7c0
 */
- (void)scratchCancel;

/**
 * @brief Opens the card fully, optionally animating the five covers away.
 * @param animated Whether to animate the covers fading out.
 * @ghidraAddress 0x1af880
 */
- (void)scratchOpen:(BOOL)animated;

/**
 * @brief The current scratch state.
 * @return One of @c ScratchViewState.
 * @ghidraAddress 0x1afc88
 */
- (ScratchViewState)getState;

/**
 * @brief A placeholder image-installation hook (empty in the binary).
 * @ghidraAddress 0x1afcb8
 */
- (void)imageSet;

/**
 * @brief Downloader callback: writes the fetched artwork or item to disk and refreshes.
 * @param downloader The finished downloader.
 * @ghidraAddress 0x1afcbc
 */
- (void)downloaderFinished:(nullable Downloader *)downloader;

/**
 * @brief Downloader callback: hides the modal dialog on an item-download failure.
 * @param downloader The failed downloader.
 * @ghidraAddress 0x1affbc
 */
- (void)downloaderError:(nullable Downloader *)downloader;

/**
 * @brief Downloader callback: drives the modal dialog's progress bar during an item download.
 * @param downloader The in-progress downloader.
 * @ghidraAddress 0x1b0028
 */
- (void)downloaderProceed:(nullable Downloader *)downloader;

/**
 * @brief A per-frame timer hook (empty in the binary).
 * @ghidraAddress 0x1b00f4
 */
- (void)timerUpdate;

/**
 * @brief Fades the enable-cover in or out to reflect whether scratching is allowed.
 * @param enable Whether scratching is enabled.
 * @ghidraAddress 0x1b00f8
 */
- (void)setButtonEnable:(BOOL)enable;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
