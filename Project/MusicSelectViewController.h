/**
 * @file
 * @brief The music-select screen.
 *
 * Reconstructed from Ghidra program Jubeat (class @c MusicSelectViewController, image base
 * 0x100000000). All @c @@ghidraAddress values are offsets relative to that image base. The class
 * object is at 0x348a68 and the superclass is @c UIViewController.
 *
 * This is the hub screen the player picks a song from. It owns the scrolling music list and the
 * detail card, the store, settings, leaderboard, marker-select, challenge-mode, and playlist
 * entry points, the song search box, and the host share-play session. Method argument and ivar
 * collaborators whose concrete class is known from the runtime metadata are typed to that class;
 * those the metadata leaves as a bare object are typed @c id as a stand-in.
 */

#import <GameKit/GameKit.h>
#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "Downloader.h"
#import "EditorIDManager.h"
#import "JcfDownloadPageNavController.h"
#import "MarkerSelectView.h"
#import "MusicListView.h"
#import "MusicPlaylistViewController.h"
#import "MusicSelectBottomView.h"
#import "MusicView.h"
#import "PurchaseManager.h"
#import "SettingsNavController.h"
#import "SharePlayManager.h"

@class BalloonView;
@class ChallengeModeRootView;
@class JcfDownloadView;
@class JcfUpLoadView;
@class MarkerSelectView;
@class MusicDetailView;
@class MusicPlaylistManager;
@class MusicSelectBottomView;
@class MusicShareView;
@class NotificationPageNavController;
@class PushNotificationView;
@class RotatableNavigationController;
@class SessionDownloader;
@class StoreDialogView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The screen the player picks a song from.
 *
 * The class adopts nine delegate protocols in its runtime metadata: the app's
 * @c MusicViewDelegate, @c MusicListViewDelegate, @c MusicPlaylistViewControllerDelegate,
 * @c SharePlayManagerDelegate, and @c PurchaseManagerDelegate, and the framework's
 * @c UIAlertViewDelegate, @c UIPopoverPresentationControllerDelegate, @c UISearchBarDelegate, and
 * @c GKGameCenterControllerDelegate.
 */
@interface MusicSelectViewController : UIViewController <MusicViewDelegate,
                                                         MusicListViewDelegate,
                                                         MusicPlaylistViewControllerDelegate,
                                                         UIAlertViewDelegate,
                                                         SharePlayManagerDelegate,
                                                         UIPopoverPresentationControllerDelegate,
                                                         UISearchBarDelegate,
                                                         GKGameCenterControllerDelegate,
                                                         PurchaseManagerDelegate,
                                                         MarkerSelectViewDelegate,
                                                         MusicSelectBottomViewDelegate,
                                                         AlertViewManagerDelegate,
                                                         DownloaderDelegate,
                                                         EditorIDManagerDelegate,
                                                         JcfDownloadPageNavControllerDelegate,
                                                         SettingsNavControllerDelegate> {
    /** The how-to page index. Carried for the binary's ivar layout; nothing reads it. */
    unsigned int pageHowto;
    /** Whether the marker-select overlay is open. */
    BOOL isMarkerSelectOpen;
    /** The store-info banner index. Carried for the binary's ivar layout; nothing reads it. */
    unsigned int indexStoreInfo;
    /** Whether the device is a pad idiom. */
    BOOL isPad;
    /** Whether the display is Retina. */
    BOOL isRetina;
    /** Whether the device is a Retina pad. */
    BOOL isPadRetina;
    /** Whether a play is about to start, suppressing further selection. */
    BOOL willStart;
    /** Whether the menu BGM was suspended by another audio session. */
    BOOL mainBgmSuspended;
    /** The screen's background image. */
    UIImageView *bgImageView;
    /** The scrolling music list. */
    MusicListView *musicListView;
    /** The dimming cover placed behind an overlay. */
    UIView *coverView;
    /** Whether the delegate-owned cover is currently showing. */
    BOOL bOpenDelegateCover;
    /** The extra cover views layered over the screen alongside @c coverView . */
    NSArray *appendCoverView;
    /** The tap recogniser attached to the cover, dismissing it when tapped. */
    UIGestureRecognizer *appendCoverGesture;
    /** The song tile the player currently has selected. */
    MusicView *selectedMusicView;
    /** The detail card shown for @c selectedMusicView . */
    MusicDetailView *musicDetailView;
    /** Every tune known to the game. */
    NSArray *arrayAllTune;
    /** The extend (bonus) tunes, keyed by music ID. */
    NSDictionary *dictAllExtendTune;
    /** The tunes the player has not yet played. */
    NSMutableArray *arrayNotPlayedTune;
    /** The tunes matching the selected difficulty level. */
    NSMutableArray *arrayLevelList;
    /** The tunes in the active playlist. */
    NSMutableArray *arrayCurrentPlaylist;
    /** The index paths to remove on the next music-list update. */
    NSMutableArray *arrayDeleteList;
    /** The index paths to insert on the next music-list update. */
    NSMutableArray *arrayAddList;
    /** The tunes the player has held (marked as favourites). */
    NSMutableArray *arrayHoldList;
    /** The tunes the player has not held. */
    NSMutableArray *arrayNotHoldList;
    /** The store the playlists are read from and written to. */
    MusicPlaylistManager *playlistManager;
    /** The array backing the active playlist, one of the @c array... lists above. */
    id currentPlaylistSource;
    /** The active playlist index; -1 selects the not-yet-played list. */
    int playListIndex;
    /** The navigation controller hosting @c playlistViewCtrl . */
    RotatableNavigationController *playlistNavCtrl;
    /** The playlist picker presented over the list. */
    MusicPlaylistViewController *playlistViewCtrl;
    /** The button opening the settings screen. */
    UIButton *btnSettings;
    /** The button joining a local share-play session. */
    UIButton *btnJoinSession;
    /** The button opening the Game Center leaderboard. */
    UIButton *btnLeaderboard;
    /** The button opening the store. */
    UIButton *btnStore;
    /** The button opening challenge mode. */
    UIButton *btnChallenge;
    /** The "new" badge drawn over @c btnStore . */
    UIImageView *imgStoreNew;
    /** The "new" badge drawn over @c btnChallenge . */
    UIImageView *imgChallengeNew;
    /** The scratch ID of the running challenge, or negative when there is none. */
    int currentScratchID;
    /** The marker-select overlay. */
    MarkerSelectView *markerSelectView;
    /** The dimming cover placed behind @c markerSelectView . */
    UIView *markerSelectCover;
    /** The button opening @c markerSelectView . */
    UIButton *btnMarker;
    /** The image showing the selected marker on @c btnMarker . */
    UIImageView *btnMarkerImg;
    /** The store-information request, live between its start and completion. */
    Downloader *infoDownloader;
    /** The store's last-updated timestamp, compared against the stored one to raise the badge. */
    NSString *storeUpdateTime;
    /** The navigation controller hosting the settings screen. */
    SettingsNavController *settingsNavCtrl;
    /** The view shown to a share-play client while it waits for the host. */
    MusicShareView *shareClientView;
    /** The chart data sent to share-play clients. */
    NSData *shareMusicData;
    /** The chart upload view. */
    JcfUpLoadView *upLoadView;
    /** The chart download view. */
    JcfDownloadView *jcfDownloadView;
    /** The balloon tip pointing at the store button. */
    BalloonView *balloonView;
    /** The timer rotating the store-information banner. */
    NSTimer *infoBannerTimer;
    /** The off-screen tile the detail-open animation expands from. */
    MusicView *farOpenMusicView;
    /** Whether shake-to-shuffle is enabled. */
    BOOL bEnableShuffle;
    /** Whether @c musicDetailView is open. */
    BOOL bOpenMusicDetail;
    /** Whether the shuffle animation is running. The binary spells it with one @c f . */
    BOOL bSuffleAnim;
    /** Whether the search box is open. */
    BOOL bOpenSearchBox;
    /** The tunes matching the current search text. */
    NSMutableArray *searchArray;
    /** The song search box. */
    UISearchBar *searchBox;
    /** The swipe recognisers driving the list's page changes. */
    NSArray *arraySwipeRecognizer;
    /** The button cancelling the search and closing @c searchBox . */
    UIButton *searchCancelBtn;
    /** The search index mapping a search term to its matching tunes. */
    NSMutableDictionary *searchDictionary;
    /** The one-off tutorial overlay explaining search. */
    UIView *searchTutorialView;
    /** The one-off tutorial overlay explaining extend tunes. */
    UIView *extendTutorialView;
    /** The framing button dismissing @c extendTutorialView . */
    UIButton *extendTutorialFrame;
    /** The description image drawn inside @c extendTutorialView . */
    UIImageView *extendTutorialDescription;
    /** The search text saved while the search box is closed, restored when it reopens. */
    NSString *backUpString;
    /** Whether a modal is presented over the screen. */
    BOOL bOpenModal;
    /** Whether the settings screen is open. */
    BOOL bOpenSetting;
    /** Whether the notification page is open. */
    BOOL bOpenInfo;
    /** Whether challenge mode is open. */
    BOOL bOpenChallenge;
    /** The navigation controller hosting the chart-download pages. */
    JcfDownloadPageNavController *jcfDLPageViewController;
    /** The navigation controller hosting the notification pages. */
    NotificationPageNavController *notificationViewController;
    /** The jubeat Lab URL fetched at launch, or @c nil when the fetch failed. */
    NSString *jubeatLabURL;
    /** Which flow asked for purchase verification; see the @c kVerifyPurchaseType values. */
    int verifyPurchaseType;
    /** The store parameters held while the store is opened, then consumed and cleared. */
    NSDictionary *storeParams;
    /** The challenge-mode root view. */
    ChallengeModeRootView *challengeModeView;
    /** Whether challenge mode is being launched. */
    BOOL bLaunchCMode;
    /** The dimming cover shown while challenge mode loads. */
    UIView *challengeCoverView;
    /** The purchase-verification dialogue. */
    StoreDialogView *verifyDialog;
    /** The editor-ID download manager. */
    EditorIDManager *idManager;
    /** Whether the player has accepted the challenge-mode policy. */
    BOOL checkPolicy;
    /** The spinner shown while challenge information downloads. */
    UIActivityIndicatorView *indicatorChallenge;
    /** The timer that times the challenge-information download out. */
    NSTimer *indicatorTimer;
    /** The challenge-information request. */
    SessionDownloader *challengeInfoDownloader;
    /** The challenge mission tasks parsed from the challenge information. */
    NSMutableArray *missionTasks;
    /** The push-notification view. */
    PushNotificationView *notificationView;
    /** The paged scroll view carrying the background artwork. */
    UIScrollView *scrollBg;
    /** The number of pages in @c scrollBg . */
    int scrollPageNum;
    /** The bottom bar carrying the mode and playlist controls. */
    MusicSelectBottomView *bottomView;
}

/** @brief The host share-play session manager. @ghidraAddress 0x391a0 (getter), 0x391b0 (setter) */
@property(nonatomic, strong, nullable) SharePlayManager *sharePlayManager;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x1f354
 */
- (void)refreshMusicList;

/**
 * @brief Reconstructed method; see the implementation.
 * @return The result.
 * @ghidraAddress 0x207b4
 */
- (instancetype)init;

/**
 * @brief Reconstructed method; see the implementation.
 * @param tune The tune argument.
 * @return The result.
 * @ghidraAddress 0x20c84
 */
- (nullable id)soundName:(nullable id)tune;

/**
 * @brief Reconstructed method; see the implementation.
 * @param key The key argument.
 * @return The result.
 * @ghidraAddress 0x20d74
 */
- (nullable id)getTuneInfo:(nullable id)key;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x20ff0
 */
- (void)createArrayNotYetPlayed;

/**
 * @brief Reconstructed method; see the implementation.
 * @param level The level argument.
 * @ghidraAddress 0x21bbc
 */
- (void)createArrayLevel:(int)level;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x21e34
 */
- (void)createArrayHold;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x22014
 */
- (void)createArrayNotHold;

/**
 * @brief Reconstructed method; see the implementation.
 * @param tune The tune argument.
 * @return The result.
 * @ghidraAddress 0x221fc
 */
- (BOOL)matchTitle:(nullable id)tune;

/**
 * @brief Reconstructed method; see the implementation.
 * @param index The index argument.
 * @ghidraAddress 0x22488
 */
- (void)preparePlaylistArray:(NSInteger)index;

/**
 * @brief Reconstructed method; see the implementation.
 * @param listType The listType argument.
 * @param musicID The musicID argument.
 * @ghidraAddress 0x22984
 */
- (void)changeMusicListView:(NSInteger)listType musicID:(NSUInteger)musicID;

/**
 * @brief Reconstructed method; see the implementation.
 * @param listType The listType argument.
 * @param musicID The musicID argument.
 * @param isFirst The isFirst argument.
 * @ghidraAddress 0x22994
 */
- (void)changeMusicListView:(NSInteger)listType musicID:(NSUInteger)musicID isFirst:(BOOL)isFirst;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x22e78
 */
- (void)loadView;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x26998
 */
- (void)reloadMarkerSelectView;

/**
 * @brief Reconstructed method; see the implementation.
 * @param turnToGenreOpen The turnToGenreOpen argument.
 * @ghidraAddress 0x26b30
 */
- (void)turnToGenreOpen:(nullable id)turnToGenreOpen;

/**
 * @brief Reconstructed method; see the implementation.
 * @param turnToPackPurchase The turnToPackPurchase argument.
 * @ghidraAddress 0x26bf8
 */
- (void)turnToPackPurchase:(nullable id)turnToPackPurchase;

/**
 * @brief Reconstructed method; see the implementation.
 * @param turnToCampaignDetail The turnToCampaignDetail argument.
 * @ghidraAddress 0x26cc0
 */
- (void)turnToCampaignDetail:(nullable id)turnToCampaignDetail;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x26d88
 */
- (void)turnToStore;

/**
 * @brief Reconstructed method; see the implementation.
 * @param turnToStore The turnToStore argument.
 * @ghidraAddress 0x26f98
 */
- (void)turnToStore:(nullable id)turnToStore;

/**
 * @brief Reconstructed method; see the implementation.
 * @param clickPackInfomation The clickPackInfomation argument.
 * @ghidraAddress 0x27098
 */
- (void)clickPackInfomation:(nullable id)clickPackInfomation;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x271ec
 */
- (void)stopStoreInfo;

/**
 * @brief Reconstructed method; see the implementation.
 * @param tapPlaylists The tapPlaylists argument.
 * @ghidraAddress 0x272ac
 */
- (void)tapPlaylists:(nullable id)tapPlaylists;

/**
 * @brief Reconstructed method; see the implementation.
 * @param tapBgmSwitch The tapBgmSwitch argument.
 * @ghidraAddress 0x274f8
 */
- (void)tapBgmSwitch:(nullable id)tapBgmSwitch;

/**
 * @brief Reconstructed method; see the implementation.
 * @param popoverPresentationController The popoverPresentationController argument.
 * @return The result.
 * @ghidraAddress 0x275dc
 */
- (BOOL)popoverPresentationControllerShouldDismissPopover:
    (nullable UIPopoverPresentationController *)popoverPresentationController;

/**
 * @brief Reconstructed method; see the implementation.
 * @param popoverPresentationController The popoverPresentationController argument.
 * @ghidraAddress 0x27634
 */
- (void)popoverPresentationControllerDidDismissPopover:
    (nullable UIPopoverPresentationController *)popoverPresentationController;

/**
 * @brief Reconstructed method; see the implementation.
 * @param tapStoreInfo The tapStoreInfo argument.
 * @ghidraAddress 0x27694
 */
- (void)tapStoreInfo:(nullable id)tapStoreInfo;

/**
 * @brief Reconstructed method; see the implementation.
 * @param tapNotification The tapNotification argument.
 * @ghidraAddress 0x27734
 */
- (void)tapNotification:(nullable id)tapNotification;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x27cf8
 */
- (void)pushNotificate;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x27d54
 */
- (void)requestNewInfo;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x27f70
 */
- (void)setupMainBgm;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x282a4
 */
- (void)startMainBgm;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x2838c
 */
- (void)checkAndRetryBgm;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x28ac4
 */
- (void)hideStoreBalloon;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x28ccc
 */
- (void)launchChallengeMode;

/**
 * @brief Reconstructed method; see the implementation.
 * @param challengeConnectError The challengeConnectError argument.
 * @ghidraAddress 0x28e84
 */
- (void)challengeConnectError:(nullable id)challengeConnectError;

/**
 * @brief Reconstructed method; see the implementation.
 * @param downloaderFinished The downloaderFinished argument.
 * @ghidraAddress 0x291f0
 */
- (void)downloaderFinished:(nullable id)downloaderFinished;

/**
 * @brief Reconstructed method; see the implementation.
 * @param downloaderError The downloaderError argument.
 * @ghidraAddress 0x29df8
 */
- (void)downloaderError:(nullable id)downloaderError;

/**
 * @brief Reconstructed method; see the implementation.
 * @return The result.
 * @ghidraAddress 0x29fbc
 */
- (unsigned int)numberOfMusic;

/**
 * @brief Reconstructed method; see the implementation.
 * @param index The index argument.
 * @return The result.
 * @ghidraAddress 0x2a004
 */
- (nullable id)musicInfoForIndex:(NSUInteger)index;

/**
 * @brief Reconstructed method; see the implementation.
 * @param tuneID The tuneID argument.
 * @return The result.
 * @ghidraAddress 0x2a0b0
 */
- (int)musicIndexForTuneID:(int)tuneID;

/**
 * @brief Reconstructed method; see the implementation.
 * @param musicID The musicID argument.
 * @return The result.
 * @ghidraAddress 0x2a228
 */
- (nullable id)extendMusicInfoForMusicID:(unsigned int)musicID;

/**
 * @brief Reconstructed method; see the implementation.
 * @return The result.
 * @ghidraAddress 0x2a298
 */
- (nullable id)addMusicArray;

/**
 * @brief Reconstructed method; see the implementation.
 * @return The result.
 * @ghidraAddress 0x2a2a8
 */
- (nullable id)removeMusicArray;

/**
 * @brief Reconstructed method; see the implementation.
 * @param showCoverView The showCoverView argument.
 * @param addGesture The addGesture argument.
 * @ghidraAddress 0x2a2b8
 */
- (void)showCoverView:(nullable id)showCoverView addGesture:(nullable id)addGesture;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x2a650
 */
- (void)hiddenCoverView;

/**
 * @brief Reconstructed method; see the implementation.
 * @param controller The controller argument.
 * @param playlist The playlist argument.
 * @param musicID The musicID argument.
 * @ghidraAddress 0x2a9e4
 */
- (void)musicPlaylistViewController:(nullable id)controller
                   playlistSelected:(NSInteger)playlist
                    selectedMusicID:(NSUInteger)musicID;

/**
 * @brief Reconstructed method; see the implementation.
 * @param controller The controller argument.
 * @return The result.
 * @ghidraAddress 0x2ae28
 */
- (NSInteger)musicPlaylistViewControllerCurrentSelection:(nullable id)controller;

/**
 * @brief Reconstructed method; see the implementation.
 * @param controller The controller argument.
 * @ghidraAddress 0x2aeec
 */
- (void)musicPlaylistViewControllerWillClosed:(nullable id)controller;

/**
 * @brief Reconstructed method; see the implementation.
 * @param musicViewTapped The musicViewTapped argument.
 * @ghidraAddress 0x2af98
 */
- (void)musicViewTapped:(nullable id)musicViewTapped;

/**
 * @brief Reconstructed method; see the implementation.
 * @param musicViewPressed The musicViewPressed argument.
 * @ghidraAddress 0x2ca20
 */
- (void)musicViewPressed:(nullable id)musicViewPressed;

/**
 * @brief Reconstructed method; see the implementation.
 * @param musicViewSelectBgmAction The musicViewSelectBgmAction argument.
 * @ghidraAddress 0x2ca38
 */
- (void)musicViewSelectBgmAction:(nullable id)musicViewSelectBgmAction;

/**
 * @brief Reconstructed method; see the implementation.
 * @param musicViewPlaylistAction The musicViewPlaylistAction argument.
 * @ghidraAddress 0x2cbfc
 */
- (void)musicViewPlaylistAction:(nullable id)musicViewPlaylistAction;

/**
 * @brief Reconstructed method; see the implementation.
 * @param musicView The musicView argument.
 * @return The result.
 * @ghidraAddress 0x2cfac
 */
- (NSUInteger)musicViewGetPlaylistActionType:(nullable id)musicView;

/**
 * @brief Reconstructed method; see the implementation.
 * @param tapSettings The tapSettings argument.
 * @ghidraAddress 0x2d030
 */
- (void)tapSettings:(nullable id)tapSettings;

/**
 * @brief Reconstructed method; see the implementation.
 * @param settingsNavViewClose The settingsNavViewClose argument.
 * @ghidraAddress 0x2d160
 */
- (void)settingsNavViewClose:(nullable id)settingsNavViewClose;

/**
 * @brief Reconstructed method; see the implementation.
 * @param gameCenterStateChanged The gameCenterStateChanged argument.
 * @ghidraAddress 0x2d260
 */
- (void)gameCenterStateChanged:(nullable id)gameCenterStateChanged;

/**
 * @brief Reconstructed method; see the implementation.
 * @param tapLeaderboard The tapLeaderboard argument.
 * @ghidraAddress 0x2d2e0
 */
- (void)tapLeaderboard:(nullable id)tapLeaderboard;

/**
 * @brief Reconstructed method; see the implementation.
 * @param gameCenterViewController The gameCenterViewController argument.
 * @ghidraAddress 0x2d4a8
 */
- (void)gameCenterViewControllerDidFinish:
    (nullable GKGameCenterViewController *)gameCenterViewController;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x2d5e8
 */
- (void)closeDetailView;

/**
 * @brief Reconstructed method; see the implementation.
 * @param show The show argument.
 * @ghidraAddress 0x2e4fc
 */
- (void)showButtonMarker:(BOOL)show;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x2e9f8
 */
- (void)willStartPlay;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x2ea0c
 */
- (void)resetWillStart;

/**
 * @brief Reconstructed method; see the implementation.
 * @param startPlay The startPlay argument.
 * @ghidraAddress 0x2ea1c
 */
- (void)startPlay:(nullable id)startPlay;

/**
 * @brief Reconstructed method; see the implementation.
 * @param startEdit The startEdit argument.
 * @ghidraAddress 0x2ee04
 */
- (void)startEdit:(nullable id)startEdit;

/**
 * @brief Reconstructed method; see the implementation.
 * @param sender The sender argument.
 * @param filePath The filePath argument.
 * @ghidraAddress 0x2effc
 */
- (void)startHostShare:(nullable id)sender filePath:(nullable NSString *)filePath;

/**
 * @brief Reconstructed method; see the implementation.
 * @param disconnect The disconnect argument.
 * @ghidraAddress 0x2f17c
 */
- (void)cancelShare:(BOOL)disconnect;

/**
 * @brief Reconstructed method; see the implementation.
 * @param pushBtnJoin The pushBtnJoin argument.
 * @ghidraAddress 0x2f930
 */
- (void)pushBtnJoin:(nullable id)pushBtnJoin;

/**
 * @brief Reconstructed method; see the implementation.
 * @param shareHostSelected The shareHostSelected argument.
 * @ghidraAddress 0x2ff10
 */
- (void)shareHostSelected:(nullable id)shareHostSelected;

/**
 * @brief Reconstructed method; see the implementation.
 * @param alertSelect The alertSelect argument.
 * @ghidraAddress 0x2ff94
 */
- (void)alertSelect:(nullable id)alertSelect;

/**
 * @brief Reconstructed method; see the implementation.
 * @param sharePlayManagerConnectClient The sharePlayManagerConnectClient argument.
 * @ghidraAddress 0x30140
 */
- (void)sharePlayManagerConnectClient:(nullable id)sharePlayManagerConnectClient;

/**
 * @brief Reconstructed method; see the implementation.
 * @param manager The manager argument.
 * @param exist The exist argument.
 * @ghidraAddress 0x30280
 */
- (void)sharePlayManager:(nullable id)manager receiveExistMusicData:(BOOL)exist;

/**
 * @brief Reconstructed method; see the implementation.
 * @param sharePlayManagerSuccessSendMusicData The sharePlayManagerSuccessSendMusicData argument.
 * @ghidraAddress 0x30340
 */
- (void)sharePlayManagerSuccessSendMusicData:(nullable id)sharePlayManagerSuccessSendMusicData;

/**
 * @brief Reconstructed method; see the implementation.
 * @param sharePlayManagerFailedSendMusicData The sharePlayManagerFailedSendMusicData argument.
 * @ghidraAddress 0x30480
 */
- (void)sharePlayManagerFailedSendMusicData:(nullable id)sharePlayManagerFailedSendMusicData;

/**
 * @brief Reconstructed method; see the implementation.
 * @param sharePlayManagerAllClientReady The sharePlayManagerAllClientReady argument.
 * @ghidraAddress 0x30484
 */
- (void)sharePlayManagerAllClientReady:(nullable id)sharePlayManagerAllClientReady;

/**
 * @brief Reconstructed method; see the implementation.
 * @param sharePlayManagerConnectFailed The sharePlayManagerConnectFailed argument.
 * @ghidraAddress 0x305a0
 */
- (void)sharePlayManagerConnectFailed:(nullable id)sharePlayManagerConnectFailed;

/**
 * @brief Reconstructed method; see the implementation.
 * @param manager The manager argument.
 * @param client The client argument.
 * @ghidraAddress 0x3073c
 */
- (void)sharePlayManager:(nullable id)manager disconnectClient:(nullable id)client;

/**
 * @brief Reconstructed method; see the implementation.
 * @param sharePlayManagerConnectHost The sharePlayManagerConnectHost argument.
 * @ghidraAddress 0x30948
 */
- (void)sharePlayManagerConnectHost:(nullable id)sharePlayManagerConnectHost;

/**
 * @brief Reconstructed method; see the implementation.
 * @param sharePlayManagerDisconnect The sharePlayManagerDisconnect argument.
 * @ghidraAddress 0x30960
 */
- (void)sharePlayManagerDisconnect:(nullable id)sharePlayManagerDisconnect;

/**
 * @brief Reconstructed method; see the implementation.
 * @param manager The manager argument.
 * @param hostID The hostID argument.
 * @ghidraAddress 0x30b6c
 */
- (void)sharePlayManager:(nullable id)manager findHostID:(nullable id)hostID;

/**
 * @brief Reconstructed method; see the implementation.
 * @param manager The manager argument.
 * @param hostID The hostID argument.
 * @ghidraAddress 0x30b88
 */
- (void)sharePlayManager:(nullable id)manager lostHostID:(nullable id)hostID;

/**
 * @brief Reconstructed method; see the implementation.
 * @param manager The manager argument.
 * @param musicInfo The musicInfo argument.
 * @return The result.
 * @ghidraAddress 0x30ba4
 */
- (BOOL)sharePlayManager:(nullable id)manager receiveMusicInfo:(nullable id)musicInfo;

/**
 * @brief Reconstructed method; see the implementation.
 * @param manager The manager argument.
 * @param progress The progress argument.
 * @ghidraAddress 0x31818
 */
- (void)sharePlayManager:(nullable id)manager receiveProgress:(float)progress;

/**
 * @brief Reconstructed method; see the implementation.
 * @param manager The manager argument.
 * @param musicData The musicData argument.
 * @return The result.
 * @ghidraAddress 0x31874
 */
- (BOOL)sharePlayManager:(nullable id)manager musicDataReceived:(nullable id)musicData;

/**
 * @brief Reconstructed method; see the implementation.
 * @param sharePlayManagerHostSelectStart The sharePlayManagerHostSelectStart argument.
 * @ghidraAddress 0x31b30
 */
- (void)sharePlayManagerHostSelectStart:(nullable id)sharePlayManagerHostSelectStart;

/**
 * @brief Reconstructed method; see the implementation.
 * @param appSuspended The appSuspended argument.
 * @ghidraAddress 0x31b98
 */
- (void)appSuspended:(nullable id)appSuspended;

/**
 * @brief Reconstructed method; see the implementation.
 * @param appResumed The appResumed argument.
 * @ghidraAddress 0x31da4
 */
- (void)appResumed:(nullable id)appResumed;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x31e40
 */
- (void)didReceiveMemoryWarning;

/**
 * @brief Reconstructed method; see the implementation.
 * @param tapMarkerSelect The tapMarkerSelect argument.
 * @ghidraAddress 0x31e78
 */
- (void)tapMarkerSelect:(nullable id)tapMarkerSelect;

/**
 * @brief Reconstructed method; see the implementation.
 * @param markerSelectChanged The markerSelectChanged argument.
 * @ghidraAddress 0x329d4
 */
- (void)markerSelectChanged:(nullable id)markerSelectChanged;

/**
 * @brief Reconstructed method; see the implementation.
 * @param tapStore The tapStore argument.
 * @ghidraAddress 0x32a34
 */
- (void)tapStore:(nullable id)tapStore;

/**
 * @brief Reconstructed method; see the implementation.
 * @param animated The animated argument.
 * @ghidraAddress 0x32ae4
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * @brief Reconstructed method; see the implementation.
 * @param animated The animated argument.
 * @ghidraAddress 0x32b1c
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * @brief Reconstructed method; see the implementation.
 * @param animated The animated argument.
 * @ghidraAddress 0x32b70
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * @brief Reconstructed method; see the implementation.
 * @param animated The animated argument.
 * @ghidraAddress 0x32ba8
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * @brief Reconstructed method; see the implementation.
 * @param orientation The orientation argument.
 * @return The result.
 * @ghidraAddress 0x32be0
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation;

/**
 * @brief Reconstructed method; see the implementation.
 * @return The result.
 * @ghidraAddress 0x32bf0
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Reconstructed method; see the implementation.
 * @return The result.
 * @ghidraAddress 0x32bf8
 */
- (BOOL)shouldAutorotate;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x32c00
 */
- (void)unenableCoverTap;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x32c68
 */
- (void)enableCoverTap;

/**
 * @brief Reconstructed method; see the implementation.
 * @param JcfDownLoad The JcfDownLoad argument.
 * @ghidraAddress 0x32d10
 */
- (void)JcfDownLoad:(nullable id)JcfDownLoad;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x32e34
 */
- (void)JcfDownLoadTopPage;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x32fa0
 */
- (void)JcfDownLoad;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x3301c
 */
- (void)removeDownloadView;

/**
 * @brief Reconstructed method; see the implementation.
 * @param jcfDownloadEnd The jcfDownloadEnd argument.
 * @ghidraAddress 0x33084
 */
- (void)jcfDownloadEnd:(nullable id)jcfDownloadEnd;

/**
 * @brief Reconstructed method; see the implementation.
 * @param sender The sender argument.
 * @param musicID The musicID argument.
 * @ghidraAddress 0x33330
 */
- (void)downloadEnd:(nullable id)sender musicID:(nullable id)musicID;

/**
 * @brief Reconstructed method; see the implementation.
 * @param store The store argument.
 * @param packID The packID argument.
 * @ghidraAddress 0x33374
 */
- (void)moveStore:(nullable id)store packID:(nullable NSString *)packID;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x3348c
 */
- (void)schemeMoveStore;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x338c0
 */
- (void)popoverClose;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x33980
 */
- (void)resumeJcfDownload;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x34040
 */
- (void)startOpenDetailPanel;

/**
 * @brief Reconstructed method; see the implementation.
 * @param webView The webView argument.
 * @param seqIndex The seqIndex argument.
 * @ghidraAddress 0x3433c
 */
- (void)customWebViewClose:(nullable id)webView seqIndex:(nullable id)seqIndex;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x34448
 */
- (void)notificationDisp;

/**
 * @brief Reconstructed method; see the implementation.
 * @return The result.
 * @ghidraAddress 0x34584
 */
- (BOOL)checkLabURL;

/**
 * @brief Reconstructed method; see the implementation.
 * @param tapJubeatLab The tapJubeatLab argument.
 * @ghidraAddress 0x34754
 */
- (void)tapJubeatLab:(nullable id)tapJubeatLab;

/**
 * @brief Reconstructed method; see the implementation.
 * @param btnTouchesBegan The btnTouchesBegan argument.
 * @ghidraAddress 0x3478c
 */
- (void)btnTouchesBegan:(nullable id)btnTouchesBegan;

/**
 * @brief Reconstructed method; see the implementation.
 * @param btnTouchesCancel The btnTouchesCancel argument.
 * @ghidraAddress 0x3479c
 */
- (void)btnTouchesCancel:(nullable id)btnTouchesCancel;

/**
 * @brief Reconstructed method; see the implementation.
 * @param enable The enable argument.
 * @ghidraAddress 0x347ac
 */
- (void)setEnableGesture:(BOOL)enable;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x34810
 */
- (void)musicShuffleEnable;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x3485c
 */
- (void)musicShuffleDisable;

/**
 * @brief Reconstructed method; see the implementation.
 * @param sender The sender argument.
 * @ghidraAddress 0x3486c
 */
- (void)shuffleAnimation:(nullable id)sender;

/**
 * @brief Reconstructed method; see the implementation.
 * @param data The data argument.
 * @return The result.
 * @ghidraAddress 0x352ac
 */
- (BOOL)changeMusicData:(nullable id)data;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x35628
 */
- (void)setRandomSelect;

/**
 * @brief Reconstructed method; see the implementation.
 * @param event The event argument.
 * @return The result.
 * @ghidraAddress 0x35854
 */
- (BOOL)checkShakeEvent:(nullable id)event;

/**
 * @brief Reconstructed method; see the implementation.
 * @return The result.
 * @ghidraAddress 0x358d4
 */
- (BOOL)canBecomeFirstResponder;

/**
 * @brief Reconstructed method; see the implementation.
 * @param motion The motion argument.
 * @param event The event argument.
 * @ghidraAddress 0x358dc
 */
- (void)motionBegan:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event;

/**
 * @brief Reconstructed method; see the implementation.
 * @param motion The motion argument.
 * @param event The event argument.
 * @ghidraAddress 0x358ec
 */
- (void)motionCancelled:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event;

/**
 * @brief Reconstructed method; see the implementation.
 * @param motion The motion argument.
 * @param event The event argument.
 * @ghidraAddress 0x358fc
 */
- (void)motionEnded:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event;

/**
 * @brief Reconstructed method; see the implementation.
 * @param searchString The searchString argument.
 * @return The result.
 * @ghidraAddress 0x35944
 */
- (nullable id)getSearchArray:(nullable NSString *)searchString;

/**
 * @brief Reconstructed method; see the implementation.
 * @param sender The sender argument.
 * @return The result.
 * @ghidraAddress 0x35a9c
 */
- (BOOL)searchStringChanged:(nullable id)sender;

/**
 * @brief Reconstructed method; see the implementation.
 * @param enable The enable argument.
 * @ghidraAddress 0x35cb8
 */
- (void)setSearchEnable:(BOOL)enable;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x35dfc
 */
- (void)pushSearchBox;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x361b4
 */
- (void)pullSearchBox;

/**
 * @brief Reconstructed method; see the implementation.
 * @param recognizer The recognizer argument.
 * @ghidraAddress 0x36720
 */
- (void)handleSwipe:(nullable UISwipeGestureRecognizer *)recognizer;

/**
 * @brief Reconstructed method; see the implementation.
 * @param tapSearchCancel The tapSearchCancel argument.
 * @ghidraAddress 0x36780
 */
- (void)tapSearchCancel:(nullable id)tapSearchCancel;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x367f0
 */
- (void)exeSearchPickUp;

/**
 * @brief Reconstructed method; see the implementation.
 * @param searchBar The searchBar argument.
 * @param searchText The searchText argument.
 * @ghidraAddress 0x369f8
 */
- (void)searchBar:(nullable UISearchBar *)searchBar textDidChange:(nullable NSString *)searchText;

/**
 * @brief Reconstructed method; see the implementation.
 * @param searchBar The searchBar argument.
 * @ghidraAddress 0x36aa8
 */
- (void)searchBarSearchButtonClicked:(nullable UISearchBar *)searchBar;

/**
 * @brief Reconstructed method; see the implementation.
 * @param searchBar The searchBar argument.
 * @param selectedScope The selectedScope argument.
 * @ghidraAddress 0x36b30
 */
- (void)searchBar:(nullable UISearchBar *)searchBar
    selectedScopeButtonIndexDidChange:(NSInteger)selectedScope;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x36b34
 */
- (void)musicListScrollBegin;

/**
 * @brief Reconstructed method; see the implementation.
 * @param tapChangeMode The tapChangeMode argument.
 * @ghidraAddress 0x36b4c
 */
- (void)tapChangeMode:(nullable id)tapChangeMode;

/**
 * @brief Reconstructed method; see the implementation.
 * @param enable The enable argument.
 * @ghidraAddress 0x36c94
 */
- (void)challengeModeEnable:(BOOL)enable;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x36cb0
 */
- (void)updateMusicList;

/**
 * @brief Reconstructed method; see the implementation.
 * @param tapChallengeMode The tapChallengeMode argument.
 * @ghidraAddress 0x36d04
 */
- (void)tapChallengeMode:(nullable id)tapChallengeMode;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x36da0
 */
- (void)challengeModeClose;

/**
 * @brief Reconstructed method; see the implementation.
 * @param musicInfo The musicInfo argument.
 * @param difficulty The difficulty argument.
 * @ghidraAddress 0x36e5c
 */
- (void)challengeMusicStart:(nullable id)musicInfo diff:(int)difficulty;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x37094
 */
- (void)refreshRatingChip;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x370ac
 */
- (void)makeChallengeRootView;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x371a4
 */
- (void)downloadChallengeInfo;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x37844
 */
- (void)showChallengeCoverView;

/**
 * @brief Reconstructed method; see the implementation.
 * @param loadTimeOver The loadTimeOver argument.
 * @ghidraAddress 0x37c24
 */
- (void)loadTimeOver:(nullable id)loadTimeOver;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x37c78
 */
- (void)hideChallengeCoverView;

/**
 * @brief Reconstructed method; see the implementation.
 * @param showVerifyDialog The showVerifyDialog argument.
 * @ghidraAddress 0x37ee8
 */
- (void)showVerifyDialog:(nullable id)showVerifyDialog;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x382d0
 */
- (void)hideVerifyDialog;

/**
 * @brief Reconstructed method; see the implementation.
 * @param purchaseSucceeded The purchaseSucceeded argument.
 * @ghidraAddress 0x3830c
 */
- (void)purchaseSucceeded:(nullable id)purchaseSucceeded;

/**
 * @brief Reconstructed method; see the implementation.
 * @param sender The sender argument.
 * @param error The error argument.
 * @ghidraAddress 0x38434
 */
- (void)purchaseFailed:(nullable id)sender error:(nullable id)error;

/**
 * @brief Reconstructed method; see the implementation.
 * @param sender The sender argument.
 * @param message The message argument.
 * @ghidraAddress 0x38618
 */
- (void)errorIDDownload:(nullable id)sender msgStr:(nullable NSString *)message;

/**
 * @brief Reconstructed method; see the implementation.
 * @param successIDDownload The successIDDownload argument.
 * @ghidraAddress 0x387d0
 */
- (void)successIDDownload:(nullable id)successIDDownload;

/**
 * @brief Reconstructed method; see the implementation.
 * @param sender The sender argument.
 * @param message The message argument.
 * @ghidraAddress 0x3880c
 */
- (void)agreementError:(nullable id)sender msgStr:(nullable NSString *)message;

/**
 * @brief Reconstructed method; see the implementation.
 * @param agreementSuccess The agreementSuccess argument.
 * @ghidraAddress 0x389e4
 */
- (void)agreementSuccess:(nullable id)agreementSuccess;

/**
 * @brief Reconstructed method; see the implementation.
 * @param agreementFailed The agreementFailed argument.
 * @ghidraAddress 0x38a50
 */
- (void)agreementFailed:(nullable id)agreementFailed;

/**
 * @brief Reconstructed method; see the implementation.
 * @param restoreFailed The restoreFailed argument.
 * @ghidraAddress 0x38a88
 */
- (void)restoreFailed:(nullable id)restoreFailed;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x38af4
 */
- (void)restoreNothing;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x38cfc
 */
- (void)restoreSucceeded;

/**
 * @brief Reconstructed method; see the implementation.
 * @ghidraAddress 0x38f04
 */
- (void)dealloc;

/**
 * @brief Reconstructed method; see the implementation.
 * @param offset The offset argument.
 * @ghidraAddress 0x38fe8
 */
- (void)scrollOffset:(float)offset;

/**
 * @brief Reconstructed method; see the implementation.
 * @param pageNum The pageNum argument.
 * @param animated The animated argument.
 * @ghidraAddress 0x39078
 */
- (void)scrollFromPageNum:(int)pageNum bAnim:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
