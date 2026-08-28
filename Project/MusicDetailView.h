/** @file
 * The music-selection detail card.
 *
 * Reconstructed from Ghidra program Jubeat (class @c MusicDetailView, image base 0x100000000). All
 * @c @@ghidraAddress values are offsets relative to that image base. The superclass is @c UIView,
 * from the @c initWithFrame: chain-up at 0x126714.
 *
 * The card shows the picked tune's artwork with a mirrored reflection, its name plate, a random
 * marker, a link-to-store button, Twitter and Facebook recommend buttons, a start-play button, a
 * host-share-play button, a share-message label, and a share-data progress bar. It also drives the
 * pack-id search and social-share flow (@c SearchPackIDView over a dimming @c topcover), the
 * custom-chart edit flow (@c EditModalView and @c EditFileListViewDeleteController in a popover),
 * and jcf download and manage navigation controllers.
 *
 * In this shipped build many of the card's display and layout entry points are empty: the theme
 * variants @c MusicDetailViewOrg and its siblings carry the real per-difficulty layout, while this
 * base class keeps only the shared construction, the score and edit data plumbing, and the store,
 * social, and recommend actions.
 */

#import <UIKit/UIKit.h>

#import "EditFileListViewController.h"
#import "SearchPackIDView.h"

@class EditFileListViewDeleteController;
@class EditModalView;
@class JcfDownloadPageNavController;
@class JcfManageNavController;
@class MusicSelectViewController;
@class ScoreRecord;
@class SearchPackIDView;
@class TuneInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The music-selection detail card shown when a tune is picked.
 *
 * The class declares five delegate protocols in its runtime metadata:
 * @c UIScrollViewDelegate, @c UITextFieldDelegate, @c UINavigationControllerDelegate,
 * @c EditFileListViewDelegate, and @c UIPopoverPresentationControllerDelegate. It additionally
 * fills informal (respondsToSelector-checked) delegate roles for the pack-id search view, the
 * edit-modal save callback, the jcf download-end callback, and the host-share cancellation.
 */
@interface MusicDetailView : UIView <UIScrollViewDelegate,
                                     UITextFieldDelegate,
                                     UINavigationControllerDelegate,
                                     EditFileListViewDelegate,
                                     UIPopoverPresentationControllerDelegate,
                                     SearchPackIDViewDelegate>

/**
 * @brief Designated initialiser; builds every subview at the origin and hides the modal chrome.
 * @param frame The card's frame.
 * @return The initialised card, or @c nil.
 * @ghidraAddress 0x126714
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Stores the base-chart tune; the score argument is ignored.
 * @param info The base-chart tune.
 * @param score The score record (discarded in this build).
 * @ghidraAddress 0x127790
 */
- (void)setInfo:(nullable TuneInfo *)info score:(nullable id)score;

/**
 * @brief Stores the extend-chart tune; the score argument is ignored.
 * @param info The extend-chart tune.
 * @param score The score record (discarded in this build).
 * @ghidraAddress 0x1277d0
 */
- (void)setExtendInfo:(nullable TuneInfo *)info score:(nullable id)score;

/**
 * @brief Empty in this build.
 * @ghidraAddress 0x127810
 */
- (void)clearInfo;

/**
 * @brief Empty in this build.
 * @param dict The content dictionary.
 * @ghidraAddress 0x127814
 */
- (void)loadContentFromDictionary:(nullable NSDictionary *)dict;

/**
 * @brief Empty in this build.
 * @param path A file path.
 * @param data In-memory data.
 * @ghidraAddress 0x127818
 */
- (void)loadContentFromPath:(nullable NSString *)path orData:(nullable NSData *)data;

/**
 * @brief Empty in this build.
 * @param show Whether to show the card.
 * @ghidraAddress 0x12781c
 */
- (void)show:(BOOL)show;

/**
 * @brief Empty in this build.
 * @ghidraAddress 0x127820
 */
- (void)hostShareCancelled;

/**
 * @brief Empty in this build.
 * @param show Whether to show the progress bar.
 * @param animated Whether the change is animated.
 * @ghidraAddress 0x127824
 */
- (void)showDataProgress:(BOOL)show animated:(BOOL)animated;

/**
 * @brief Empty in this build.
 * @param activate Whether to activate the animation.
 * @ghidraAddress 0x127828
 */
- (void)activateAnim:(BOOL)activate;

/**
 * @brief Opens the tune's iTunes URL in the browser, when it has one.
 * @param sender The link button.
 * @ghidraAddress 0x12782c
 */
- (void)pushLink:(nullable id)sender;

/**
 * @brief Starts the recommend flow: picks the social network from the sender's tag, dims the card,
 *        installs the pack-search sheet, and animates it in.
 * @param sender The tapped recommend button (tag 0 chooses Twitter, otherwise Facebook).
 * @ghidraAddress 0x127958
 */
- (void)pushRecommend:(nullable id)sender;

/**
 * @brief Pack-search delegate: the search resolved; fades the sheet out and posts the share text.
 * @param view The pack-search view.
 * @ghidraAddress 0x127fb0
 */
- (void)packIDSearchEnd:(nullable SearchPackIDView *)view;

/**
 * @brief Pack-search delegate: the search was cancelled; fades the sheet and scrim out.
 * @param view The pack-search view.
 * @ghidraAddress 0x128308
 */
- (void)packIDSearchCancel:(nullable SearchPackIDView *)view;

/**
 * @brief The recommend string from the pack-search view, or @c nil when none is installed.
 * @return The recommend string.
 * @ghidraAddress 0x128638
 */
- (nullable NSString *)getRecommendString;

/**
 * @brief Removes the pack-search view and the dimming cover, then releases both.
 * @ghidraAddress 0x1286c4
 */
- (void)searchViewDealloc;

/**
 * @brief Presents an @c SLComposeViewController for the given service, seeded with the text.
 * @param service The social service type.
 * @param text The initial post text; an empty string when @c nil.
 * @ghidraAddress 0x128768
 */
- (void)socialSend:(nullable NSString *)service sendText:(nullable NSString *)text;

/**
 * @brief Presents the Twitter composer with the given text.
 * @param text The initial post text.
 * @ghidraAddress 0x128928
 */
- (void)sendTwitter:(nullable NSString *)text;

/**
 * @brief Resets every base and extend score to -1, clears full-combo flags, and drops music bars.
 * @ghidraAddress 0x128948
 */
- (void)resetScore;

/**
 * @brief Populates the base-chart score, full-combo flags, and music bars from a score record.
 * @param score The score record, or @c nil.
 * @ghidraAddress 0x128ac4
 */
- (void)putScore:(nullable ScoreRecord *)score;

/**
 * @brief Populates the extend-chart score, full-combo flags, and music bars from a score record.
 * @param score The score record, or @c nil.
 * @ghidraAddress 0x128f98
 */
- (void)putExtendScore:(nullable ScoreRecord *)score;

/**
 * @brief Dismisses the edit popover or jcf download page and closes the detail view.
 * @ghidraAddress 0x12946c
 */
- (void)closePopWindow;

/**
 * @brief Asks the controller to close the detail view.
 * @ghidraAddress 0x129580
 */
- (void)close;

/**
 * @brief Builds the share dictionary by decrypting the tune's packed assets over its base dict.
 * @return The share dictionary.
 * @ghidraAddress 0x1295c0
 */
- (nullable NSDictionary *)infoDictForShare;

/**
 * @brief Loads the tune's last edit file into the shared edit data manager, or clears it.
 * @ghidraAddress 0x129a84
 */
- (void)loadEditFile;

/**
 * @brief Saves the shared edit data back to the tune's last edit file, when one exists.
 * @ghidraAddress 0x129b50
 */
- (void)saveEditFile;

/**
 * @brief Edit-modal delegate: forwards to @c -saveEditFile.
 * @ghidraAddress 0x129c08
 */
- (void)editModalViewDelegateSaveEditFile;

/**
 * @brief Whether the tune's info may be changed (no host share, a local last-edit file, iPad).
 * @return @c YES when editing the info is allowed.
 * @ghidraAddress 0x129c14
 */
- (BOOL)checkEnableInfoChange;

/**
 * @brief Whether the tune may be uploaded (as @c -checkEnableInfoChange plus a non-empty note
 * count).
 * @return @c YES when uploading is allowed.
 * @ghidraAddress 0x129d68
 */
- (BOOL)checkEnableUpload;

/**
 * @brief Whether the tune's chart may be edited (no host share, a local last-edit file, iPad).
 * @return @c YES when editing is allowed.
 * @ghidraAddress 0x129f20
 */
- (BOOL)checkEnableEdit;

/**
 * @brief Jcf download-end delegate: on non-iPad, reloads the manage list from the tune's files.
 * @param sender The download page.
 * @ghidraAddress 0x12a074
 */
- (void)downloadEnd:(nullable id)sender;

/**
 * @brief Dismisses the presented controller and turns the parent to the pack-purchase store page.
 * @param store The store (unused pass-through).
 * @param packID The pack id to purchase.
 * @ghidraAddress 0x12a198
 */
- (void)moveStore:(nullable id)store packID:(nullable NSString *)packID;

/**
 * @brief Empty in this build.
 * @ghidraAddress 0x12a238
 */
- (void)setStartButtonEnable;

/**
 * @brief Double-tap gesture on the artwork: asks the controller to select a random tune.
 * @param gesture The tap recogniser.
 * @ghidraAddress 0x12a23c
 */
- (void)dtpGesture:(nullable UITapGestureRecognizer *)gesture;

/**
 * @brief Empty in this build.
 * @ghidraAddress 0x12a27c
 */
- (void)refreshStartButton;

/**
 * @brief Long-press gesture on the artwork: toggles the app's random flag on the began state.
 * @param gesture The long-press recogniser.
 * @ghidraAddress 0x12a280
 */
- (void)lpGesture:(nullable UILongPressGestureRecognizer *)gesture;

/**
 * @brief Empty in this build.
 * @ghidraAddress 0x12a314
 */
- (void)changeExtendMode;

/**
 * @brief The on-screen position for a difficulty; always @c CGPointZero in this build.
 * @param difficulty The difficulty index.
 * @return @c CGPointZero.
 * @ghidraAddress 0x12a318
 */
- (CGPoint)getDifficultyPos:(int)difficulty;

/**
 * @brief Empty in this build.
 * @ghidraAddress 0x12a328
 */
- (void)refreshInfo;

#pragma mark - Properties

/** @brief The base-chart tune. @ghidraAddress 0x12a32c (getter), 0x12a33c (setter) */
@property(nonatomic, strong, nullable) TuneInfo *info;
/** @brief The full-card dimming cover. @ghidraAddress 0x12a350 (getter), 0x12a360 (setter) */
@property(nonatomic, strong, nullable) UIView *coverView;
/** @brief The artwork image. @ghidraAddress 0x12a374 (getter), 0x12a384 (setter) */
@property(nonatomic, strong, nullable) UIImageView *artworkView;
/** @brief The mirrored-artwork reflection. @ghidraAddress 0x12a398 (getter), 0x12a3a8 (setter) */
@property(nonatomic, strong, nullable) UIImageView *reflectionArtworkView;
/** @brief The tune-name plate. @ghidraAddress 0x12a3bc (getter), 0x12a3cc (setter) */
@property(nonatomic, strong, nullable) UIImageView *tuneNameView;
/** @brief The start-play button. @ghidraAddress 0x12a3e0 (getter), 0x12a3f0 (setter) */
@property(nonatomic, strong, nullable) UIButton *buttonStartPlay;
/** @brief The host-share-play button. @ghidraAddress 0x12a404 (getter), 0x12a414 (setter) */
@property(nonatomic, strong, nullable) UIButton *buttonHostSharePlay;
/** @brief The share-status message label. @ghidraAddress 0x12a428 (getter), 0x12a438 (setter) */
@property(nonatomic, strong, nullable) UILabel *labelShareMessage;
/** @brief The share-data progress bar. @ghidraAddress 0x12a44c (getter), 0x12a45c (setter) */
@property(nonatomic, strong, nullable) UIProgressView *shareDataProgress;
/** @brief The link-to-store button. @ghidraAddress 0x12a470 (getter), 0x12a480 (setter) */
@property(nonatomic, strong, nullable) UIButton *buttonLink;
/** @brief The random-select marker. @ghidraAddress 0x12a494 (getter), 0x12a4a4 (setter) */
@property(nonatomic, strong, nullable) UIImageView *randView;
/** @brief The Twitter recommend button. @ghidraAddress 0x12a4b8 (getter), 0x12a4c8 (setter) */
@property(nonatomic, strong, nullable) UIButton *btnRecommendTwitter;
/** @brief The Facebook recommend button. @ghidraAddress 0x12a4dc (getter), 0x12a4ec (setter) */
@property(nonatomic, strong, nullable) UIButton *btnRecommendFacebook;
/** @brief Whether the card is in host-share mode. @ghidraAddress 0x12a500 (getter), 0x12a510
 * (setter) */
@property(nonatomic, assign) BOOL isShared;
/** @brief The edit-file list scroll view. @ghidraAddress 0x12a520 (getter), 0x12a530 (setter) */
@property(nonatomic, strong, nullable) UIScrollView *scrollView;
/** @brief The edit-file delete list controller. @ghidraAddress 0x12a544 (getter), 0x12a554 (setter)
 */
@property(nonatomic, strong, nullable) EditFileListViewDeleteController *pFileListView;
/** @brief The edit-file list popover. @ghidraAddress 0x12a568 (getter), 0x12a578 (setter) */
@property(nonatomic, strong, nullable) UIPopoverController *pLoadList;
/** @brief Whether this is the first selection. @ghidraAddress 0x12a58c (getter), 0x12a59c (setter)
 */
@property(nonatomic, assign) BOOL isFirstSelect;
/** @brief The edit modal. @ghidraAddress 0x12a5ac (getter), 0x12a5bc (setter) */
@property(nonatomic, strong, nullable) EditModalView *pEditModalView;
/** @brief The current edit page index. @ghidraAddress 0x12a5d0 (getter), 0x12a5e0 (setter) */
@property(nonatomic, assign) int editPage;
/** @brief The jcf download navigation controller. @ghidraAddress 0x12a5f0 (getter), 0x12a600
 * (setter) */
@property(nonatomic, strong, nullable) JcfDownloadPageNavController *jcfDownloadPage;
/** @brief The jcf manage navigation controller. @ghidraAddress 0x12a614 (getter), 0x12a624 (setter)
 */
@property(nonatomic, strong, nullable) JcfManageNavController *jcfMan;
/** @brief The share index string. @ghidraAddress 0x12a638 (getter), 0x12a648 (setter) */
@property(nonatomic, strong, nullable) NSString *customIndex;
/** @brief Whether the edit-info modal is open. @ghidraAddress 0x12a65c (getter), 0x12a66c (setter)
 */
@property(nonatomic, assign) BOOL isEditInfoOpen;
/** @brief The base-chart basic level. @ghidraAddress 0x12a67c (getter), 0x12a68c (setter) */
@property(nonatomic, assign) char levelBas;
/** @brief The base-chart advanced level. @ghidraAddress 0x12a69c (getter), 0x12a6ac (setter) */
@property(nonatomic, assign) char levelAdv;
/** @brief The base-chart extreme level. @ghidraAddress 0x12a6bc (getter), 0x12a6cc (setter) */
@property(nonatomic, assign) char levelExt;
/** @brief The base-chart basic score. @ghidraAddress 0x12a6dc (getter), 0x12a6ec (setter) */
@property(nonatomic, assign) int scoreBas;
/** @brief The base-chart advanced score. @ghidraAddress 0x12a6fc (getter), 0x12a70c (setter) */
@property(nonatomic, assign) int scoreAdv;
/** @brief The base-chart extreme score. @ghidraAddress 0x12a71c (getter), 0x12a72c (setter) */
@property(nonatomic, assign) int scoreExt;
/** @brief The base-chart basic full-combo flag. @ghidraAddress 0x12a73c (getter), 0x12a74c (setter)
 */
@property(nonatomic, assign) BOOL fullComboBas;
/** @brief The base-chart advanced full-combo flag. @ghidraAddress 0x12a75c (getter), 0x12a76c
 * (setter) */
@property(nonatomic, assign) BOOL fullComboAdv;
/** @brief The base-chart extreme full-combo flag. @ghidraAddress 0x12a77c (getter), 0x12a78c
 * (setter) */
@property(nonatomic, assign) BOOL fullComboExt;
/** @brief The base-chart basic music bar. @ghidraAddress 0x12a79c (getter), 0x12a7ac (setter) */
@property(nonatomic, strong, nullable) NSData *mbarBas;
/** @brief The base-chart advanced music bar. @ghidraAddress 0x12a7c0 (getter), 0x12a7d0 (setter) */
@property(nonatomic, strong, nullable) NSData *mbarAdv;
/** @brief The base-chart extreme music bar. @ghidraAddress 0x12a7e4 (getter), 0x12a7f4 (setter) */
@property(nonatomic, strong, nullable) NSData *mbarExt;
/** @brief Whether the device is an iPad. @ghidraAddress 0x12a808 (getter), 0x12a818 (setter) */
@property(nonatomic, assign) BOOL isPad;
/** @brief Whether the device is a retina phone. @ghidraAddress 0x12a828 (getter), 0x12a838 (setter)
 */
@property(nonatomic, assign) BOOL isRetina;
/** @brief Whether play has started. @ghidraAddress 0x12a848 (getter), 0x12a858 (setter) */
@property(nonatomic, assign) BOOL isStarted;
/** @brief Whether the host share is startable. @ghidraAddress 0x12a868 (getter), 0x12a878 (setter)
 */
@property(nonatomic, assign) BOOL isSharedStartable;
/** @brief The extend-chart tune. @ghidraAddress 0x12a888 (getter), 0x12a898 (setter) */
@property(nonatomic, strong, nullable) TuneInfo *extendInfo;
/** @brief The extend-chart basic level. @ghidraAddress 0x12a8ac (getter), 0x12a8bc (setter) */
@property(nonatomic, assign) char extendLevelBas;
/** @brief The extend-chart advanced level. @ghidraAddress 0x12a8cc (getter), 0x12a8dc (setter) */
@property(nonatomic, assign) char extendLevelAdv;
/** @brief The extend-chart extreme level. @ghidraAddress 0x12a8ec (getter), 0x12a8fc (setter) */
@property(nonatomic, assign) char extendLevelExt;
/** @brief The extend-chart basic score. @ghidraAddress 0x12a90c (getter), 0x12a91c (setter) */
@property(nonatomic, assign) int extendScoreBas;
/** @brief The extend-chart advanced score. @ghidraAddress 0x12a92c (getter), 0x12a93c (setter) */
@property(nonatomic, assign) int extendScoreAdv;
/** @brief The extend-chart extreme score. @ghidraAddress 0x12a94c (getter), 0x12a95c (setter) */
@property(nonatomic, assign) int extendScoreExt;
/** @brief The extend-chart basic full-combo flag. @ghidraAddress 0x12a96c (getter), 0x12a97c
 * (setter) */
@property(nonatomic, assign) BOOL extendFullComboBas;
/** @brief The extend-chart advanced full-combo flag. @ghidraAddress 0x12a98c (getter), 0x12a99c
 * (setter) */
@property(nonatomic, assign) BOOL extendFullComboAdv;
/** @brief The extend-chart extreme full-combo flag. @ghidraAddress 0x12a9ac (getter), 0x12a9bc
 * (setter) */
@property(nonatomic, assign) BOOL extendFullComboExt;
/** @brief The extend-chart basic music bar. @ghidraAddress 0x12a9cc (getter), 0x12a9dc (setter) */
@property(nonatomic, strong, nullable) NSData *extendMbarBas;
/** @brief The extend-chart advanced music bar. @ghidraAddress 0x12a9f0 (getter), 0x12aa00 (setter)
 */
@property(nonatomic, strong, nullable) NSData *extendMbarAdv;
/** @brief The extend-chart extreme music bar. @ghidraAddress 0x12aa14 (getter), 0x12aa24 (setter)
 */
@property(nonatomic, strong, nullable) NSData *extendMbarExt;
/** @brief The owning music-select controller. @ghidraAddress 0x12aa38 (getter), 0x12aa58 (setter)
 */
@property(nonatomic, weak, nullable) MusicSelectViewController *controller;
/** @brief The pack-id search sheet. @ghidraAddress 0x12aa6c (getter), 0x12aa7c (setter) */
@property(nonatomic, strong, nullable) SearchPackIDView *searchPackView;
/** @brief The selected social service type. @ghidraAddress 0x12aa90 (getter), 0x12aaa0 (setter) */
@property(nonatomic, assign, nullable) NSString *socialType;
/** @brief The recommend dimming cover. @ghidraAddress 0x12aab0 (getter), 0x12aac0 (setter) */
@property(nonatomic, strong, nullable) UIView *topcover;

@end

/**
 * @brief The selectors the base declares but only the concrete theme subclasses implement.
 */
@interface MusicDetailView (ThemeOverrides)

/**
 * @brief Declared, never implemented on the base: the concrete theme subclasses supply the body.
 * @note MusicDetailView's runtime metadata holds 154 methods and none is @c infoChange: (there is
 *       no category adding it either). The binary implements this selector only on
 *       MusicDetailViewOrg (0x551d4), MusicDetailViewRpl (0x12f538), MusicDetailViewKnt
 *       (0x199e88), and ScratchMusicDetailView (0x161f30). The declaration is required because
 *       MusicSelectViewController holds the card in a base-typed ivar and sends this selector to
 *       it; no subclass calls @c super, so the base needs no body.
 * @param difficulty The difficulty index to show.
 */
- (void)infoChange:(int)difficulty;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
