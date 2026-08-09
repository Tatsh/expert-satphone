/** @file
 * The challenge-mode mission page.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeMissionPageView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The view hosts two toggled @c UITableViews over a shared background plate: a mission-sheet list
 * (with an optional event-sheet section) and a rewards list. A pair of list buttons switches
 * between them with a cross-fade. Selecting a mission-sheet row cross-fades in a
 * @c ChallengeMissionSheetView; selecting a reward row cross-fades in a
 * @c MissionRewardDownloadView. The sheet list itself is fetched from the server through a
 * @c SessionDownloader whose response JSON this view parses. The superclass is @c UIView, taken
 * from the @c objc_msgSendSuper2 @c initWithFrame: chain-up.
 */

#import <UIKit/UIKit.h>

#import "ChallengeMissionSheetView.h"
#import "MissionRewardDownloadView.h"
#import "SessionDownloader.h"

@class ChallengeMissionSheetView;
@class MissionRewardDownloadView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c ChallengeMissionPageView tells its owner.
 *
 * The delegate ivar is weak and untyped in the metadata (@c \@,W,N). @c -closeMenu is sent
 * directly, so it is effectively required; @c -cubePurchase and @c -refreshStatus are guarded by
 * @c -respondsToSelector: and are optional.
 */
@protocol ChallengeMissionPageViewDelegate <NSObject>
/** @brief The page should be dismissed. */
- (void)closeMenu;
@optional
/** @brief The player asked to buy cubes. */
- (void)cubePurchase;
/** @brief The player's status changed and should be refreshed. */
- (void)refreshStatus;
@end

/**
 * @brief The challenge-mode mission page: two toggled tables over a shared plate.
 */
@interface ChallengeMissionPageView
    : UIView <UITableViewDataSource, UITableViewDelegate, DownloaderDelegate, UIAlertViewDelegate>

/**
 * @brief The object told about close, purchase, and refresh events. Held weakly.
 * @ghidraAddress 0xae940 (getter), 0xae960 (setter)
 */
@property(nonatomic, weak, nullable) id<ChallengeMissionPageViewDelegate> aDelegate;

/**
 * @brief Builds the background plate, the title, close and list buttons, and starts the
 * sheet-list download.
 * @param frame The view's frame.
 * @return The initialised view.
 * @ghidraAddress 0xaa91c
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief List-button callback: records the tapped list, swaps the two button images, downloads
 * the reward list the first time the reward tab is chosen, and otherwise cross-fades the tables.
 * @param sender The tapped @c UIButton, whose tag is the list index (0 mission, 1 reward).
 * @ghidraAddress 0xab448
 */
- (void)tapListBtn:(nullable id)sender;

/**
 * @brief Cross-fades between the mission-sheet and reward tables, updating the empty-state label
 * and re-enabling the buttons when both lists are empty.
 * @param list The list to switch to (0 mission, 1 reward).
 * @ghidraAddress 0xab60c
 */
- (void)switchListView:(int)list;

/**
 * @brief Close-button callback: tells the delegate to dismiss the page.
 * @param sender The tapped control.
 * @ghidraAddress 0xabbf4
 */
- (void)tapClose:(nullable id)sender;

/**
 * @brief Alert callback: closes the page, or reports a challenge-mode session error when the
 * boxed flag is set.
 * @param sender The boxed @c BOOL selection.
 * @ghidraAddress 0xabc34
 */
- (void)cancelSettingMenu:(nullable id)sender;

/**
 * @brief Close-button callback while a sheet is shown: returns to the sheet list, otherwise tells
 * the delegate to dismiss the page.
 * @param sender The tapped control.
 * @ghidraAddress 0xabce0
 */
- (void)closeSettingMenu:(nullable id)sender;

/**
 * @brief Called when the presented mission sheet finishes displaying: clears the download-wait
 * flag and re-enables the close button.
 * @ghidraAddress 0xabda0
 */
- (void)missionSheetDisplayEnd;

/**
 * @brief @c DownloaderDelegate success callback: parses the sheet-list or reward-list JSON and
 * builds the matching table.
 * @param downloader The finished @c SessionDownloader; its tag selects the list (0 sheet, 1
 * reward).
 * @ghidraAddress 0xabdc8
 */
- (void)downloaderFinished:(nullable id)downloader;

/**
 * @brief @c DownloaderDelegate failure callback: re-enables the buttons and shows the server-error
 * alert.
 * @param downloader The failed @c SessionDownloader.
 * @ghidraAddress 0xacf9c
 */
- (void)downloaderError:(nullable id)downloader;

/**
 * @brief Whitens the tint of a section header view before it is displayed.
 * @ghidraAddress 0xaca30
 */
- (void)tableView:(nonnull UITableView *)tableView
    willDisplayHeaderView:(nonnull UIView *)view
               forSection:(NSInteger)section;

/**
 * @brief Vends a mission-sheet or reward cell, alternating the background plate per row and
 * formatting the sheet's period.
 * @ghidraAddress 0xad12c
 */
- (nullable UITableViewCell *)tableView:(nonnull UITableView *)tableView
                  cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @brief Empty @c UITableViewDelegate hook.
 * @ghidraAddress 0xad87c
 */
- (void)tableView:(nonnull UITableView *)tableView
      willDisplayCell:(nonnull UITableViewCell *)cell
    forRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @brief The fixed per-row height, in points.
 * @ghidraAddress 0xad880
 */
- (CGFloat)tableView:(nonnull UITableView *)tableView
    heightForRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @brief Two sections on the mission table when event sheets exist, otherwise one.
 * @ghidraAddress 0xad898
 */
- (NSInteger)numberOfSectionsInTableView:(nonnull UITableView *)tableView;

/**
 * @brief The row count for the given section and table.
 * @ghidraAddress 0xad8f4
 */
- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section;

/**
 * @brief Row-selection callback: opens a @c ChallengeMissionSheetView (mission list) or a
 * @c MissionRewardDownloadView (reward list).
 * @ghidraAddress 0xad9a4
 */
- (void)tableView:(nonnull UITableView *)tableView
    didSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @brief Presents the appropriate alert for a challenge-connect error carried in the response
 * dictionary.
 * @param info The response dictionary, keyed by @c "status" and optionally @c "err_message".
 * @ghidraAddress 0xacaa8
 */
- (void)challengeConnectError:(nullable NSDictionary *)info;

/**
 * @brief Cross-fades between the sheet list and the presented mission sheet.
 * @param showSheet YES to fade the mission sheet in, NO to return to the list.
 * @ghidraAddress 0xadf4c
 */
- (void)switchMissionView:(BOOL)showSheet;

/**
 * @brief @c UIAlertView delegate callback: reports a challenge-mode session error for tag 9999.
 * @param info The alert-result dictionary, keyed by @c "Tag".
 * @ghidraAddress 0xae498
 */
- (void)alertSelect:(nullable NSDictionary *)info;

/**
 * @brief Reward-download callback: cross-fades the reward-download view out and removes it.
 * @param sender The reward-download view.
 * @ghidraAddress 0xae558
 */
- (void)closeRewardWin:(nullable id)sender;

/**
 * @brief Forwards a cube-purchase request to the delegate when it responds to @c -cubePurchase .
 * @ghidraAddress 0xae7e0
 */
- (void)cubePurchase;

/**
 * @brief Forwards a status refresh to the delegate when it responds to @c -refreshStatus .
 * @ghidraAddress 0xae890
 */
- (void)refreshStatus;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
