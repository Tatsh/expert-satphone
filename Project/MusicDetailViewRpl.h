/**
 * @file
 * The music-selection detail card for the Ripples theme.
 *
 * Reconstructed from Ghidra program Jubeat (class @c MusicDetailViewRpl, image base 0x100000000).
 * All @c @@ghidraAddress values are offsets relative to that image base. The superclass is
 * @c MusicDetailView, confirmed from the class metadata.
 *
 * This theme variant carries the real per-difficulty layout the base @c MusicDetailView leaves
 * empty: the difficulty buttons and their lamps, the level-number and rating image grids, the
 * high-score board, and the music-bar dot grids for the base and extend charts, along with the
 * edit, upload, and info controls. Object collaborators whose concrete class is not yet resolved
 * are typed @c id as a stand-in.
 */

#import <UIKit/UIKit.h>

#import "EditModalView.h"
#import "JcfDownloadPageNavController.h"
#import "JcfManageNavController.h"
#import "JcfUpLoadView.h"
#import "MusicDetailView.h"

@class TuneInfo;
@class JcfUpLoadView;

NS_ASSUME_NONNULL_BEGIN

/**
 * The detail card for the Ripples theme.
 */
@interface MusicDetailViewRpl : MusicDetailView <JcfDownloadPageNavControllerDelegate,
                                                 JcfManageNavControllerDelegate,
                                                 JcfUpLoadViewDelegate,
                                                 EditModalViewDelegate> {
    /** The difficulty buttons, indexed basic, advanced, extreme, then extend. */
    UIButton *btnDiff[4];
    /** The level number drawn on each difficulty button. */
    UIImageView *levelNumView[4];
    /** The level digit images, indexed by digit. */
    UIImage *levelNumImg[10];
    /** The board the high score is drawn on. */
    UIImageView *highscoreBoardView;
    /** The "HIGH SCORE" caption drawn on the board. */
    UIImageView *highscoreTextView;
    /** The clear-rating badge. */
    UIImageView *ratingView;
    /** The full-combo badge. */
    UIImageView *comboView;
    /** The high-score digits, most significant first. */
    UIImageView *highscoreNumView[7];
    /** The high-score digit images, indexed by digit. */
    UIImage *highscoreNumImg[10];
    /** The clear-rating badge images, indexed by rating. */
    UIImage *ratingImg[9];
    /** The full-combo badge image. */
    UIImage *fullcomboImg;
    /** The excellent badge image, replacing @c fullcomboImg on a perfect play. */
    UIImage *excellentImg;
    /** The measure bar the note-density dots are drawn in. */
    UIImageView *mbarBarView;
    /** The measure-bar dots, one per bar column. */
    UIImageView *mbarDotView[120];
    /** The measure-bar backgrounds, one per difficulty. */
    UIImage *mbarBarImg[4];
    /** The measure-bar dot images, by difficulty then density level. */
    UIImage *mbarDotImg[4][8];
    /** The measure-bar density map per difficulty, rows basic, advanced, and extreme. */
    char mbarDots[3][60];
    /** The editor chart names, one per difficulty. */
    UILabel *editTxt[3];
    /** The button opening the tune information page. */
    UIButton *infoBtn;
    /** The button uploading the editor chart. */
    UIButton *uploadBtn;
    /** The button opening the chart editor. */
    UIButton *editBtn;
    /** The buttons scrolling the detail card, previous then next. */
    UIButton *detailScrollButton[2];
    /** The chart upload view, live while an upload is in progress. */
    JcfUpLoadView *upLoadView;
    /** The cover shading the top of the card. */
    UIView *topcover;
    /** The lamp marking that the card can be scrolled. */
    UIImageView *scrollLamp;
    /** The lamp drawn on the extend difficulty button. */
    UIImageView *diffBtnLamp;
    /** The badge marking the chart's author, or @c nil when there is none. */
    UIImageView *userTagIcon;
    /** The extend measure-bar density map, in the same row order as @c mbarDots . */
    char extendMbarDots[3][60];
    /** The hold (favourite) marks, one per difficulty. */
    UIImageView *holdMark[3];
    /** The extend-available marks, one per difficulty. */
    UIImageView *extendMark[3];
    /** The extend-unlocked marks, one per difficulty. */
    UIImageView *extendOnMark[3];
    /** The random-select state as of the last refresh, used to skip redundant updates. */
    BOOL bRandomBak;
}

/**
 * The backing layer class.
 * @return The result.
 * @ghidraAddress 0x12ad40
 */
+ (Class)layerClass;

/**
 * Designated initialiser; builds the theme-specific detail layout.
 * @param frame The frame argument.
 * @return The result.
 * @ghidraAddress 0x12ad54
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Builds a difficulty button.
 * @param imageName The base name of the button's scaled PNG image.
 * @return The configured button.
 * @ghidraAddress 0x12dc84
 */
- (nullable UIButton *)diffButton:(nullable NSString *)imageName;

/**
 * Loads the theme image assets.
 * @ghidraAddress 0x12ddf4
 */
- (void)loadImages;

/**
 * Loads the detail layout from a content dictionary.
 * @param dict The dict argument.
 * @ghidraAddress 0x12e48c
 */
- (void)loadContentFromDictionary:(nullable NSDictionary *)dict;

/**
 * Loads the detail layout from a file path or in-memory data.
 * @param path The path argument.
 * @param data The data argument.
 * @ghidraAddress 0x12e820
 */
- (void)loadContentFromPath:(nullable NSString *)path orData:(nullable NSData *)data;

/**
 * Loads the extend-chart music bars from the packed extend archive at @p path.
 * @param path The extend archive path.
 * @ghidraAddress 0x12ee08
 */
- (void)loadExtendMusicBar:(nullable NSString *)path;

/**
 * Stores the base-chart tune and score, then lays the card out.
 * @param info The info argument.
 * @param score The score argument.
 * @ghidraAddress 0x12f0dc
 */
- (void)setInfo:(nullable TuneInfo *)info score:(nullable ScoreRecord *)score;

/**
 * Switches the shown info to a difficulty.
 * @param difficulty The difficulty argument.
 * @ghidraAddress 0x12f538
 */
- (void)infoChange:(int)difficulty;

/**
 * Stores the extend-chart tune and score.
 * @param info The info argument.
 * @param score The score argument.
 * @ghidraAddress 0x12ff1c
 */
- (void)setExtendInfo:(nullable TuneInfo *)info score:(nullable ScoreRecord *)score;

/**
 * Switches the shown extend info to a difficulty.
 * @param difficulty The difficulty argument.
 * @ghidraAddress 0x1303d0
 */
- (void)changeExtend:(int)difficulty;

/**
 * Clears the shown info.
 * @ghidraAddress 0x130afc
 */
- (void)clearInfo;

/**
 * Runs the difficulty-change animation.
 * @ghidraAddress 0x130bb0
 */
- (void)difficultyChangeAnimation;

/**
 * Handles a difficulty-button tap.
 * @param selectDiff The selectDiff argument.
 * @ghidraAddress 0x130dc0
 */
- (void)selectDiff:(nullable id)selectDiff;

/**
 * Fills the score board.
 * @param score The score argument.
 * @param fullcombo The fullcombo argument.
 * @ghidraAddress 0x1316b4
 */
- (void)setScoreBoard:(int)score fullcombo:(BOOL)fullcombo;

/**
 * Applies a difficulty change.
 * @param difficulty The difficulty argument.
 * @ghidraAddress 0x131a48
 */
- (void)changeDifficulty:(int)difficulty;

/**
 * Handles a difficulty scroll change.
 * @param scrollChange The scrollChange argument.
 * @ghidraAddress 0x131ca0
 */
- (void)scrollChange:(nullable id)scrollChange;

/**
 * Fills the music-bar dot grid from a resource.
 * @param dots The dots argument.
 * @param mbarRes The mbarRes argument.
 * @ghidraAddress 0x131ed8
 */
- (void)setMusicBarDot:(nullable char *)dots mbarRes:(nullable char *)mbarRes;

/**
 * Rebuilds the music-bar dot views.
 * @ghidraAddress 0x131ffc
 */
- (void)editMusicBar;

/**
 * Resets an edit text field.
 * @param index The index argument.
 * @param isFirst The isFirst argument.
 * @ghidraAddress 0x132508
 */
- (void)resetTextField:(int)index isFirst:(BOOL)isFirst;

/**
 * Enables or disables the action buttons.
 * @param enable The enable argument.
 * @ghidraAddress 0x132d54
 */
- (void)setEnableButton:(BOOL)enable;

/**
 * Refreshes the start-button enabled state.
 * @ghidraAddress 0x132ed4
 */
- (void)setStartButtonEnable;

/**
 * Shows or hides the card.
 * @param show The show argument.
 * @ghidraAddress 0x133130
 */
- (void)show:(BOOL)show;

/**
 * Host-share delegate: the share was cancelled.
 * @ghidraAddress 0x133b9c
 */
- (void)hostShareCancelled;

/**
 * Shows or hides the share-data progress bar.
 * @param show The show argument.
 * @param animated The animated argument.
 * @ghidraAddress 0x133f18
 */
- (void)showDataProgress:(BOOL)show animated:(BOOL)animated;

/**
 * Start-play button action.
 * @param pushButtonStartPlay The pushButtonStartPlay argument.
 * @ghidraAddress 0x134524
 */
- (void)pushButtonStartPlay:(nullable id)pushButtonStartPlay;

/**
 * Edit-list delegate: the download entry was chosen.
 * @ghidraAddress 0x134ebc
 */
- (void)editFileListViewSelectDownload;

/**
 * Begins the chart upload flow.
 * @ghidraAddress 0x1350a0
 */
- (void)uploadStart;

/**
 * Upload button action.
 * @param pushButtonUpload The pushButtonUpload argument.
 * @ghidraAddress 0x13554c
 */
- (void)pushButtonUpload:(nullable id)pushButtonUpload;

/**
 * Edit-list delegate: the edit entry was chosen.
 * @ghidraAddress 0x135590
 */
- (void)editFileListViewSelectEdit;

/**
 * Edit button action.
 * @param pushButtonEdit The pushButtonEdit argument.
 * @ghidraAddress 0x135630
 */
- (void)pushButtonEdit:(nullable id)pushButtonEdit;

/**
 * Begins the chart edit flow.
 * @ghidraAddress 0x13563c
 */
- (void)editStart;

/**
 * Share button action.
 * @param pushButtonShare The pushButtonShare argument.
 * @ghidraAddress 0x135ab8
 */
- (void)pushButtonShare:(nullable id)pushButtonShare;

/**
 * Refreshes the start button.
 * @ghidraAddress 0x136200
 */
- (void)refreshStartButton;

/**
 * Scroll delegate: dragging began.
 * @param scrollView The scrollView argument.
 * @ghidraAddress 0x1366a0
 */
- (void)scrollViewWillBeginDragging:(nullable UIScrollView *)scrollView;

/**
 * Scroll delegate: content offset changed.
 * @param scrollView The scrollView argument.
 * @ghidraAddress 0x1366a4
 */
- (void)scrollViewDidScroll:(nullable UIScrollView *)scrollView;

/**
 * Scroll delegate: programmatic scroll ended.
 * @param scrollView The scrollView argument.
 * @ghidraAddress 0x136780
 */
- (void)scrollViewDidEndScrollingAnimation:(nullable UIScrollView *)scrollView;

/**
 * Scroll delegate: deceleration ended.
 * @param scrollView The scrollView argument.
 * @ghidraAddress 0x136a80
 */
- (void)scrollViewDidEndDecelerating:(nullable UIScrollView *)scrollView;

/**
 * Scroll delegate: dragging ended.
 * @param scrollView The scrollView argument.
 * @param decelerate The decelerate argument.
 * @ghidraAddress 0x136d54
 */
- (void)scrollViewDidEndDragging:(nullable UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate;

/**
 * Edit-modal delegate: the modal closed.
 * @param editModalViewClose The editModalViewClose argument.
 * @ghidraAddress 0x137024
 */
- (void)editModalViewClose:(nullable id)editModalViewClose;

/**
 * Whether a download file is present.
 * @return The result.
 * @ghidraAddress 0x137288
 */
- (BOOL)checkDownloadFile;

/**
 * Info-edit button action.
 * @param pushInfoEdit The pushInfoEdit argument.
 * @ghidraAddress 0x137378
 */
- (void)pushInfoEdit:(nullable id)pushInfoEdit;

/**
 * Releases the edit-file list.
 * @ghidraAddress 0x13752c
 */
- (void)loadListRelease;

/**
 * Opens the edit-file popover.
 * @ghidraAddress 0x137588
 */
- (void)editPopoverOpen;

/**
 * Edit-list delegate: a new file was chosen.
 * @ghidraAddress 0x137e24
 */
- (void)editFileListViewSelectNewFile;

/**
 * Edit-list delegate: an item was selected.
 * @param index The index argument.
 * @ghidraAddress 0x137fb0
 */
- (void)editFileListViewSelectItem:(int)index;

/**
 * Edit-list delegate: a file was deleted.
 * @param editFileListViewDeleteFile The editFileListViewDeleteFile argument.
 * @ghidraAddress 0x138204
 */
- (void)editFileListViewDeleteFile:(nullable NSString *)editFileListViewDeleteFile;

/**
 * Selects an edit file.
 * @param selectEditFile The selectEditFile argument.
 * @ghidraAddress 0x1383f8
 */
- (void)selectEditFile:(nullable NSString *)selectEditFile;

/**
 * Popover delegate: the popover was dismissed.
 * @param popoverPresentationController The popoverPresentationController argument.
 * @ghidraAddress 0x1384d4
 */
- (void)popoverPresentationControllerDidDismissPopover:
    (nullable UIPopoverPresentationController *)popoverPresentationController;

/**
 * Edit-list delegate: the list was cancelled.
 * @param editFileListViewCancel The editFileListViewCancel argument.
 * @ghidraAddress 0x138528
 */
- (void)editFileListViewCancel:(nullable id)editFileListViewCancel;

/**
 * Download-sequence delegate: an error occurred.
 * @param errorSequenceDownload The errorSequenceDownload argument.
 * @ghidraAddress 0x1385ac
 */
- (void)errorSequenceDownload:(nullable id)errorSequenceDownload;

/**
 * Download-sequence delegate: the download finished.
 * @param finishedSequenceDownload The finishedSequenceDownload argument.
 * @ghidraAddress 0x13868c
 */
- (void)finishedSequenceDownload:(nullable id)finishedSequenceDownload;

/**
 * Download-sequence delegate: the storage cap was exceeded.
 * @param finishedSequenceOverCap The finishedSequenceOverCap argument.
 * @ghidraAddress 0x13876c
 */
- (void)finishedSequenceOverCap:(nullable id)finishedSequenceOverCap;

/**
 * Releases owned resources.
 * @ghidraAddress 0x13884c
 */
- (void)dealloc;

/**
 * Custom web-view delegate: the web view closed.
 * @param customWebViewClose The customWebViewClose argument.
 * @param seqIndex The seqIndex argument.
 * @ghidraAddress 0x138884
 */
- (void)customWebViewClose:(nullable id)customWebViewClose seqIndex:(nullable id)seqIndex;

/**
 * Jcf download-end delegate.
 * @param downloadEnd The downloadEnd argument.
 * @ghidraAddress 0x1389a0
 */
- (void)downloadEnd:(nullable id)downloadEnd;

/**
 * Removes the upload overlay.
 * @ghidraAddress 0x138bd8
 */
- (void)removeUploadView;

/**
 * Upload-end callback.
 * @param uploadEnd The uploadEnd argument.
 * @ghidraAddress 0x138c40
 */
- (void)uploadEnd:(nullable id)uploadEnd;

/**
 * The start-button image for this theme.
 * @return The result.
 * @ghidraAddress 0x138ecc
 */
- (nullable UIImage *)getStartImage;

/**
 * The single-play button image for this theme.
 * @return The result.
 * @ghidraAddress 0x139004
 */
- (nullable UIImage *)getSingleImage;

/**
 * Toggles the extend-chart display mode.
 * @ghidraAddress 0x13913c
 */
- (void)changeExtendMode;

/**
 * The on-screen position for a difficulty.
 * @param difficulty The difficulty argument.
 * @return The result.
 * @ghidraAddress 0x139544
 */
- (CGPoint)getDifficultyPos:(int)difficulty;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
