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
