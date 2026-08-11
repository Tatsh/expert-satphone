/** @file
 * The mission-achievement bonus-sheet download page.
 *
 * Reconstructed from Ghidra program Jubeat (class MissionAchieveDownloadPageView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView. The view is the same centred-plate list idiom as
 * @c ChallengeListView and @c ChallengePrevRankingListView: a background plate centred in the
 * view, a title image, an inset close button, and a table of
 * @c MissionAchieveDownloadPageViewCell rows. It additionally acts as its rows' download-button
 * delegate and rebuilds the list from a downloader-finished callback.
 */

#import <UIKit/UIKit.h>

#import "MissionAchieveDownloadPageViewCell.h"

@class SessionDownloader;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c MissionAchieveDownloadPageView tells its owner.
 */
@protocol MissionAchieveDownloadPageViewDelegate <NSObject>
/**
 * @brief Sent when the close button is tapped or the settings menu is dismissed.
 */
- (void)closeMenu;
@end

/**
 * @brief A list of downloadable mission-achievement bonus sheets over a centred background plate,
 * with a title, a close button, and a per-row download button.
 */
@interface MissionAchieveDownloadPageView : UIView <UITableViewDataSource,
                                                    UITableViewDelegate,
                                                    MissionAchieveDownloadPageViewCellDelegate>

/**
 * @brief The delegate told when the view is closed.
 *
 * Weak, per the @c W attribute in the metadata, and encoded as a bare @c \@ with no protocol; the
 * close handlers message it directly rather than through @c -respondsToSelector: .
 * @ghidraAddress 0x1ee1ec (getter), 0x1ee20c (setter)
 */
@property(nonatomic, weak, nullable) id<MissionAchieveDownloadPageViewDelegate> aDelegate;

/**
 * @brief Builds the plate, the title, the close button, and the table for the current idiom, then
 * loads the initial list from @c -downloaderFinished: .
 * @param frame The view's frame.
 * @return The initialised view.
 * @ghidraAddress 0x1ed354
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief The close button's action; tells the delegate to close the menu.
 * @param sender The close button. Unused.
 * @ghidraAddress 0x1ed918
 */
- (void)tapClose:(nullable id)sender;

/**
 * @brief Dismisses the settings menu; tells the delegate to close the menu.
 * @param sender The sender. Unused.
 * @ghidraAddress 0x1ed958
 */
- (void)closeSettingMenu:(nullable id)sender;

/**
 * @brief Rebuilds the mission list and reloads the table.
 * @param downloader The finished downloader. Unused — the list is built from fixed placeholder
 *                   records.
 * @ghidraAddress 0x1ed998
 */
- (void)downloaderFinished:(nullable SessionDownloader *)downloader;

/**
 * @brief A row's download button was tapped; confirms or refuses the download with an alert.
 * @param cell The row whose button was tapped.
 * @ghidraAddress 0x1edd74
 */
- (void)tapDownloadBtn:(nullable id)cell;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
