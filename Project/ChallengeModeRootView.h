/**
 * @file
 * The challenge-mode (scratch event) root view.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeModeRootView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. The class object is at
 * 0x2f5e30 (RO at 0x2f5258). The superclass is @c UIView, taken from the dyld bind at the class
 * object's superclass slot and confirmed by the @c -initWithFrame: chain-up.
 *
 * This view is the top-level container for the scratch challenge event: it hosts the scratch board,
 * the per-panel music detail sheet, the status bar, the ranking, line-up, menu, and login/message
 * sub-views over dimming covers, and it drives the artwork downloads, cube purchases, and the
 * StoreKit purchase flow. It registers itself with the shared @c ChallengeStatus so the many
 * challenge sub-views can message it back through @c ChallengeStatus.rootView.
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "ChallengeLineupView.h"
#import "ChallengeLoginInformationView.h"
#import "ChallengeMenuRootView.h"
#import "ChallengeNameSettingView.h"
#import "ChallengeRankingListView.h"
#import "CubePurchaseView.h"
#import "Downloader.h"
#import "PurchaseManager.h"
#import "ScratchCompleteView.h"
#import "ScratchMusicDetailView.h"
#import "ScratchView.h"
#import "StoreDialogView.h"

@class MusicSelectViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * The scratch challenge-mode root container.
 *
 * It is the delegate for nearly every challenge sub-view (scratch cards, the detail sheet, the
 * ranking list, the line-up, the login/information sheets, and the name-setting sheet), for the
 * session @c Downloader and @c AlertViewManager, and for the StoreKit @c PurchaseManager.
 */
@interface ChallengeModeRootView : UIView <AlertViewManagerDelegate,
                                           ChallengeLineupViewDelegate,
                                           ChallengeLoginInformationViewDelegate,
                                           ChallengeNameSettingViewDelegate,
                                           ChallengeRankingListViewDelegate,
                                           CubePurchaseViewDelegate,
                                           DownloaderDelegate,
                                           PurchaseManagerDelegate,
                                           ScratchCompleteViewDelegate,
                                           ScratchMusicDetailViewDelegate,
                                           ScratchViewDelegate,
                                           ChallengeMenuRootViewDelegate>

/**
 * The owning music-select controller. Held weakly.
 * @ghidraAddress 0x71bc8 (getter), 0x71be8 (setter)
 */
@property(nonatomic, weak, nullable) MusicSelectViewController *controller;

/**
 * The shared modal progress/store dialog panel.
 * @ghidraAddress 0x71bfc (getter)
 */
@property(nonatomic, strong, readonly, nullable) StoreDialogView *modalDialog;

/**
 * Builds the whole challenge-mode hierarchy over the main-screen bounds.
 * @return The initialised view.
 * @ghidraAddress 0x678e4
 */
- (instancetype)init;

/**
 * Prefixes a sound-effect base name with the current theme's prefix.
 * @param name The base sound-effect name.
 * @return The theme-prefixed resource name.
 * @ghidraAddress 0x68f60
 */
- (NSString *)soundName:(NSString *)name;

/**
 * Presents the appropriate login/information/how-to sheet or the login message.
 * @ghidraAddress 0x69050
 */
- (void)showLoginMessage;

/**
 * Checks whether every line-up artwork is present on disk, queueing the rest for download.
 * @return @c YES when nothing needs downloading.
 * @ghidraAddress 0x69e08
 */
- (BOOL)checkArtworkDownload;

/**
 * Starts the next queued artwork download.
 * @ghidraAddress 0x6a114
 */
- (void)imageDownload;

/**
 * Shows or hides the present-notification badge from the current present count.
 * @ghidraAddress 0x6a244
 */
- (void)setNotificateImage;

/**
 * Slides the challenge view in and starts the event BGM.
 * @param animated Whether to slide in from the top edge.
 * @ghidraAddress 0x6a2c8
 */
- (void)enterChallengeView:(BOOL)animated;

/**
 * Slides the challenge view off the top edge and closes challenge mode.
 * @param animated Accepted but unused by the binary.
 * @ghidraAddress 0x6a724
 */
- (void)outerChallengeView:(BOOL)animated;

/**
 * Seeds the shared status from a challenge-data dictionary and starts the refresh timer.
 * @param challengeData The challenge-data record.
 * @ghidraAddress 0x6a994
 */
- (void)setChallengeData:(NSDictionary *)challengeData;

/**
 * Iterates the line-up records (the binary discards each parsed value).
 * @ghidraAddress 0x6aaa0
 */
- (void)deleteMusicData;

/**
 * Refreshes the badge and the scratch board.
 * @ghidraAddress 0x6abbc
 */
- (void)refreshView;

/**
 * Closes the challenge session after a server session error.
 * @ghidraAddress 0x6ac08
 */
- (void)closeChallengeModeSessionError;

/**
 * The close-button action: plays the close sound and leaves challenge mode.
 * @param sender The close button.
 * @ghidraAddress 0x6ac8c
 */
- (void)closeChallengeMode:(nullable UIButton *)sender;

/**
 * The menu-button action: presents the challenge menu root view.
 * @param sender The menu button.
 * @ghidraAddress 0x6ad10
 */
- (void)tapMenuBtn:(UIButton *)sender;

/**
 * The line-up-button action: presents the line-up view over a cover.
 * @param sender The line-up button.
 * @ghidraAddress 0x6ae04
 */
- (void)tapLineupBtn:(UIButton *)sender;

/**
 * The ranking-button action: opens the all-songs ranking.
 * @param sender The ranking button.
 * @ghidraAddress 0x6af20
 */
- (void)tapRankingBtn:(UIButton *)sender;

/**
 * Calls @c -boolValue on the flag and discards the result.
 * @param dispFlag The boxed display flag.
 * @ghidraAddress 0x6af2c
 */
- (void)dispCoverView:(NSNumber *)dispFlag;

/**
 * A no-op in the shipped binary.
 * @param dispFlag The boxed display flag.
 * @ghidraAddress 0x6af3c
 */
- (void)dispDownloadDialog:(NSNumber *)dispFlag;

/**
 * Routes an alert result to the matching scratch, purchase, or close action.
 * @param dict The alert result dictionary (carries @c btnMessage and @c Tag).
 * @ghidraAddress 0x6af40
 */
- (void)alertSelect:(NSDictionary *)dict;

/**
 * Opens the per-panel music detail sheet with a scale-in animation.
 * @ghidraAddress 0x6b9a8
 */
- (void)openDetailView;

/**
 * Closes the music detail sheet with a scale-out animation.
 * @ghidraAddress 0x6bf34
 */
- (void)closeDetailView;

/**
 * Closes the name-setting sheet, then shows the login message.
 * @ghidraAddress 0x6c24c
 */
- (void)closeMenu;

/**
 * Removes the challenge menu root view.
 * @ghidraAddress 0x6c420
 */
- (void)closeMenuView;

/**
 * Refreshes the detail sheet after a ranking change.
 * @ghidraAddress 0x6c45c
 */
- (void)changeRanking;

/**
 * Builds the scratch-confirmation message, warning when little play time remains.
 * @return The confirmation message.
 * @ghidraAddress 0x6c474
 */
- (NSString *)scratchMessage;

/**
 * Starts the challenge music, recovering play coins with cubes when short.
 * @ghidraAddress 0x6c59c
 */
- (void)startChallengeMusic;

/**
 * Applies the result of a nail (single-panel) scratch.
 * @param info The scratch result dictionary.
 * @ghidraAddress 0x6ca44
 */
- (void)updateNailState:(NSDictionary *)info;

/**
 * Fades the menu cover in.
 * @ghidraAddress 0x6cc9c
 */
- (void)showMenuCoverView;

/**
 * Fades the menu cover out and removes it.
 * @ghidraAddress 0x6cdec
 */
- (void)hideMenuCoverView;

/**
 * Fades the modal cover in.
 * @ghidraAddress 0x6cfa4
 */
- (void)showCoverView;

/**
 * Fades the modal cover out and removes it.
 * @ghidraAddress 0x6d0f4
 */
- (void)hideCoverView;

/**
 * Shows the modal dialog as a bare progress panel with the given message.
 * @param message The progress message.
 * @ghidraAddress 0x6d2ac
 */
- (void)showPurchaseDialog:(NSString *)message;

/**
 * Hides the purchase progress dialog.
 * @ghidraAddress 0x6d59c
 */
- (void)hidePurchaseDialog;

/**
 * Sets the modal dialog's message text.
 * @param message The message.
 * @ghidraAddress 0x6d91c
 */
- (void)setPurchaseDialogMessage:(NSString *)message;

/**
 * Shows the modal dialog wired to a delegate, with the abort button enabled on completion.
 * @param delegate The dialog delegate.
 * @ghidraAddress 0x6d9a8
 */
- (void)showModalDialog:(nullable id)delegate;

/**
 * Hides the modal dialog.
 * @ghidraAddress 0x6dd88
 */
- (void)hideModalDialog;

/**
 * The per-tick refresh: updates the status bar and, once per session, the login message.
 * @param timer The refresh timer.
 * @ghidraAddress 0x6e0c0
 */
- (void)timerRefresh:(NSTimer *)timer;

/**
 * Handles a finished session/artwork download.
 * @param downloader The finished downloader.
 * @ghidraAddress 0x6e11c
 */
- (void)downloaderFinished:(id)downloader;

/**
 * Handles a failed session/artwork download.
 * @param downloader The failed downloader.
 * @ghidraAddress 0x6f3a8
 */
- (void)downloaderError:(id)downloader;

/**
 * Presents the cube-purchase view.
 * @ghidraAddress 0x6f9f4
 */
- (void)cubePurchaseStart;

/**
 * Dismisses the cube-purchase view.
 * @ghidraAddress 0x6fcf4
 */
- (void)closeCubePurchase;

/**
 * The cover-tap action: dismisses whichever sub-view is showing.
 * @ghidraAddress 0x6fecc
 */
- (void)closeView;

/**
 * Dismisses the line-up view.
 * @ghidraAddress 0x6ff50
 */
- (void)closeLineupView;

/**
 * Dismisses the login message.
 * @ghidraAddress 0x6ff9c
 */
- (void)closeLoginMessage;

/**
 * Dismisses the login information sheet.
 * @ghidraAddress 0x70008
 */
- (void)closeLoginInformation;

/**
 * The StoreKit success callback.
 * @param productID The purchased product identifier.
 * @ghidraAddress 0x70064
 */
- (void)purchaseSucceeded:(id)productID;

/**
 * The StoreKit failure callback.
 * @param productID The product identifier.
 * @param error The failure.
 * @ghidraAddress 0x70154
 */
- (void)purchaseFailed:(NSString *)productID error:(NSError *)error;

/**
 * The store dialog's cancel action.
 * @param sender The dialog.
 * @ghidraAddress 0x70348
 */
- (void)storeDialogCancel:(id)sender;

/**
 * Selects a scratch panel and confirms the scratch.
 * @param sender The tapped scratch view.
 * @ghidraAddress 0x70398
 */
- (void)selectScratch:(id)sender;

/**
 * Enables or disables scratching.
 * @param enable Whether scratching is enabled.
 * @ghidraAddress 0x70ac0
 */
- (void)scratchEnable:(BOOL)enable;

/**
 * Whether scratching is currently enabled.
 * @return @c YES when scratching is enabled.
 * @ghidraAddress 0x70ad0
 */
- (BOOL)isScratchEnable;

/**
 * Begins a scratch on the given panel.
 * @param sender The scratch view.
 * @ghidraAddress 0x70ae0
 */
- (void)scratchStart:(id)sender;

/**
 * Opens the scratch-complete view.
 * @ghidraAddress 0x70e88
 */
- (void)openScratchComplete;

/**
 * Closes the scratch-complete view.
 * @ghidraAddress 0x70fc4
 */
- (void)closeScratchComplete;

/**
 * Ends a scratch on the given panel.
 * @param sender The scratch view.
 * @ghidraAddress 0x70fc8
 */
- (void)scratchEnd:(id)sender;

/**
 * Opens the all-songs ranking over a cover.
 * @ghidraAddress 0x7100c
 */
- (void)openAllRanking;

/**
 * Opens the ranking for the selected panel, cross-fading from the detail sheet.
 * @ghidraAddress 0x71358
 */
- (void)openRanking;

/**
 * Closes the ranking, cross-fading back to the detail sheet when appropriate.
 * @ghidraAddress 0x71730
 */
- (void)closeRanking;

/**
 * Enters the jubeat store's pack-purchase flow for the given pack.
 * @param packID The pack identifier.
 * @ghidraAddress 0x71a8c
 */
- (void)openJubeatStore:(NSInteger)packID;

/**
 * Refreshes the status bar display.
 * @ghidraAddress 0x71b78
 */
- (void)refreshStatus;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
