/** @file
 * The music-select screen.
 *
 * Reconstructed from Ghidra program Jubeat (class MusicSelectViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. The class object is at 0x348a68.
 * Only the members the screen-transition dispatcher and @c RootViewController send are declared.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The screen the player picks a song from.
 */
@interface MusicSelectViewController : UIViewController

/**
 * @brief Starts the menu background music.
 *
 * Sent once the screen is installed, on both routes that build it. DECLARED ONLY.
 */
- (void)startMainBgm;
/**
 * @brief Stops the rolling store banner.
 *
 * Sent before the screen is torn down for a theme change, and only on that route — the other three
 * teardowns of this screen do not send it. DECLARED ONLY.
 */
- (void)stopStoreInfo;
/**
 * @brief Restarts the menu music if it stopped. DECLARED ONLY.
 */
- (void)checkAndRetryBgm;
/**
 * @brief Asks the servers for fresh store and notification data. DECLARED ONLY.
 */
- (void)requestNewInfo;
/**
 * @brief Starts a chart download.
 *
 * The capital J and L are the binary's own spelling of the selector. DECLARED ONLY.
 *
 * @param downloadID The identifier the delegate parked in @c jcfDownloadID.
 */
- (void)JcfDownLoad:(id)downloadID;
/**
 * @brief Jumps to the store entry a pending deep link names.
 *
 * Sent when any of @c storePackID, @c storeCampaignID, or @c storeGenreID is set. DECLARED ONLY.
 */
- (void)schemeMoveStore;
/**
 * @brief Shows a queued notification banner.
 *
 * The fallback when no store deep link and no download are pending. DECLARED ONLY.
 */
- (void)notificationDisp;
/**
 * @brief Opens the song detail panel.
 *
 * Sent on returning from the editor, and only when nothing else is pending. DECLARED ONLY.
 */
- (void)startOpenDetailPanel;
/**
 * @brief Rebuilds the marker list. DECLARED ONLY.
 */
- (void)reloadMarkerSelectView;
/**
 * @brief Presents a queued push notification. DECLARED ONLY.
 */
- (void)pushNotificate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
