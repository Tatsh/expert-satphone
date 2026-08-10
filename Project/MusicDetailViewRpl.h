/** @file
 * The music-selection detail card for the Ripples theme.
 *
 * Reconstructed from Ghidra program Jubeat (class @c MusicDetailViewRpl, image base 0x100000000).
 * All @c @ghidraAddress values are offsets relative to that image base. The superclass is
 * @c MusicDetailView, confirmed from the class metadata.
 *
 * This theme variant carries the real per-difficulty layout the base @c MusicDetailView leaves
 * empty: the difficulty buttons and their lamps, the level-number and rating image grids, the
 * high-score board, and the music-bar dot grids for the base and extend charts, along with the
 * edit, upload, and info controls. Object collaborators whose concrete class is not yet resolved
 * are typed @c id as a stand-in.
 */

#import <UIKit/UIKit.h>

#import "MusicDetailView.h"

@class TuneInfo;
@class JcfUpLoadView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The detail card for the Ripples theme.
 */
@interface MusicDetailViewRpl : MusicDetailView {
    UIButton *btnDiff[4];
    UIImageView *levelNumView[4];
    UIImage *levelNumImg[10];
    UIImageView *highscoreBoardView;
    UIImageView *highscoreTextView;
    UIImageView *ratingView;
    UIImageView *comboView;
    UIImageView *highscoreNumView[7];
    UIImage *highscoreNumImg[10];
    UIImage *ratingImg[9];
    UIImage *fullcomboImg;
    UIImage *excellentImg;
    UIImageView *mbarBarView;
    UIImageView *mbarDotView[120];
    UIImage *mbarBarImg[4];
    UIImage *mbarDotImg[4][8];
    char mbarDots[3][60];
    UILabel *editTxt[3];
    UIButton *infoBtn;
    UIButton *uploadBtn;
    UIButton *editBtn;
    UIButton *detailScrollButton[2];
    JcfUpLoadView *upLoadView;
    UIView *topcover;
    UIImageView *scrollLamp;
    UIImageView *diffBtnLamp;
    UIImageView *userTagIcon;
    char extendMbarDots[3][60];
    UIImageView *holdMark[3];
    UIImageView *extendMark[3];
    UIImageView *extendOnMark[3];
    BOOL bRandomBak;
}

/**
 * @brief The backing layer class.
 * @return The result.
 * @ghidraAddress 0x12ad40
 */
+ (Class)layerClass;

/**
 * @brief Designated initialiser; builds the theme-specific detail layout.
 * @param frame The frame argument.
 * @return The result.
 * @ghidraAddress 0x12ad54
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Builds a difficulty button.
 * @param diffButton The diffButton argument.
 * @return The result.
 * @ghidraAddress 0x12dc84
 */
- (nullable id)diffButton:(nullable id)diffButton;

/**
 * @brief Loads the theme image assets.
 * @ghidraAddress 0x12ddf4
 */
- (void)loadImages;

/**
 * @brief Loads the detail layout from a content dictionary.
 * @param dict The dict argument.
 * @ghidraAddress 0x12e48c
 */
- (void)loadContentFromDictionary:(nullable NSDictionary *)dict;

/**
 * @brief Loads the detail layout from a file path or in-memory data.
 * @param path The path argument.
 * @param data The data argument.
 * @ghidraAddress 0x12e820
 */
- (void)loadContentFromPath:(nullable NSString *)path orData:(nullable NSData *)data;

/**
 * @brief Loads the extend-chart music bar.
 * @param data The data argument.
 * @ghidraAddress 0x12ee08
 */
- (void)loadExtendMusicBar:(nullable NSData *)data;

/**
 * @brief Stores the base-chart tune and score, then lays the card out.
 * @param info The info argument.
 * @param score The score argument.
 * @ghidraAddress 0x12f0dc
 */
- (void)setInfo:(nullable TuneInfo *)info score:(nullable id)score;

/**
 * @brief Switches the shown info to a difficulty.
 * @param difficulty The difficulty argument.
 * @ghidraAddress 0x12f538
 */
- (void)infoChange:(int)difficulty;

/**
 * @brief Stores the extend-chart tune and score.
 * @param info The info argument.
 * @param score The score argument.
 * @ghidraAddress 0x12ff1c
 */
- (void)setExtendInfo:(nullable TuneInfo *)info score:(nullable id)score;

/**
 * @brief Switches the shown extend info to a difficulty.
 * @param difficulty The difficulty argument.
 * @ghidraAddress 0x1303d0
 */
- (void)changeExtend:(int)difficulty;

/**
 * @brief Clears the shown info.
 * @ghidraAddress 0x130afc
 */
- (void)clearInfo;

/**
 * @brief Runs the difficulty-change animation.
 * @ghidraAddress 0x130bb0
 */
- (void)difficultyChangeAnimation;

/**
 * @brief Handles a difficulty-button tap.
 * @param selectDiff The selectDiff argument.
 * @ghidraAddress 0x130dc0
 */
- (void)selectDiff:(nullable id)selectDiff;

/**
 * @brief Fills the score board.
 * @param score The score argument.
 * @param fullcombo The fullcombo argument.
 * @ghidraAddress 0x1316b4
 */
- (void)setScoreBoard:(int)score fullcombo:(BOOL)fullcombo;

/**
 * @brief Applies a difficulty change.
 * @param difficulty The difficulty argument.
 * @ghidraAddress 0x131a48
 */
- (void)changeDifficulty:(int)difficulty;

/**
 * @brief Handles a difficulty scroll change.
 * @param scrollChange The scrollChange argument.
 * @ghidraAddress 0x131ca0
 */
- (void)scrollChange:(nullable id)scrollChange;

/**
 * @brief Fills the music-bar dot grid from a resource.
 * @param dots The dots argument.
 * @param mbarRes The mbarRes argument.
 * @ghidraAddress 0x131ed8
 */
- (void)setMusicBarDot:(nullable char *)dots mbarRes:(nullable char *)mbarRes;

/**
 * @brief Rebuilds the music-bar dot views.
 * @ghidraAddress 0x131ffc
 */
- (void)editMusicBar;

/**
 * @brief Resets an edit text field.
 * @param index The index argument.
 * @param isFirst The isFirst argument.
 * @ghidraAddress 0x132508
 */
- (void)resetTextField:(int)index isFirst:(BOOL)isFirst;

/**
 * @brief Enables or disables the action buttons.
 * @param enable The enable argument.
 * @ghidraAddress 0x132d54
 */
- (void)setEnableButton:(BOOL)enable;

/**
 * @brief Refreshes the start-button enabled state.
 * @ghidraAddress 0x132ed4
 */
- (void)setStartButtonEnable;

/**
 * @brief Shows or hides the card.
 * @param show The show argument.
 * @ghidraAddress 0x133130
 */
- (void)show:(BOOL)show;

/**
 * @brief Host-share delegate: the share was cancelled.
 * @ghidraAddress 0x133b9c
 */
- (void)hostShareCancelled;

/**
 * @brief Shows or hides the share-data progress bar.
 * @param show The show argument.
 * @param animated The animated argument.
 * @ghidraAddress 0x133f18
 */
- (void)showDataProgress:(BOOL)show animated:(BOOL)animated;

/**
 * @brief Start-play button action.
 * @param pushButtonStartPlay The pushButtonStartPlay argument.
 * @ghidraAddress 0x134524
 */
- (void)pushButtonStartPlay:(nullable id)pushButtonStartPlay;

/**
 * @brief Edit-list delegate: the download entry was chosen.
 * @ghidraAddress 0x134ebc
 */
- (void)editFileListViewSelectDownload;

/**
 * @brief Begins the chart upload flow.
 * @ghidraAddress 0x1350a0
 */
- (void)uploadStart;

/**
 * @brief Upload button action.
 * @param pushButtonUpload The pushButtonUpload argument.
 * @ghidraAddress 0x13554c
 */
- (void)pushButtonUpload:(nullable id)pushButtonUpload;

/**
 * @brief Edit-list delegate: the edit entry was chosen.
 * @ghidraAddress 0x135590
 */
- (void)editFileListViewSelectEdit;

/**
 * @brief Edit button action.
 * @param pushButtonEdit The pushButtonEdit argument.
 * @ghidraAddress 0x135630
 */
- (void)pushButtonEdit:(nullable id)pushButtonEdit;

/**
 * @brief Begins the chart edit flow.
 * @ghidraAddress 0x13563c
 */
- (void)editStart;

/**
 * @brief Share button action.
 * @param pushButtonShare The pushButtonShare argument.
 * @ghidraAddress 0x135ab8
 */
- (void)pushButtonShare:(nullable id)pushButtonShare;

/**
 * @brief Refreshes the start button.
 * @ghidraAddress 0x136200
 */
- (void)refreshStartButton;

/**
 * @brief Scroll delegate: dragging began.
 * @param scrollView The scrollView argument.
 * @ghidraAddress 0x1366a0
 */
- (void)scrollViewWillBeginDragging:(nullable UIScrollView *)scrollView;

/**
 * @brief Scroll delegate: content offset changed.
 * @param scrollView The scrollView argument.
 * @ghidraAddress 0x1366a4
 */
- (void)scrollViewDidScroll:(nullable UIScrollView *)scrollView;

/**
 * @brief Scroll delegate: programmatic scroll ended.
 * @param scrollView The scrollView argument.
 * @ghidraAddress 0x136780
 */
- (void)scrollViewDidEndScrollingAnimation:(nullable UIScrollView *)scrollView;

/**
 * @brief Scroll delegate: deceleration ended.
 * @param scrollView The scrollView argument.
 * @ghidraAddress 0x136a80
 */
- (void)scrollViewDidEndDecelerating:(nullable UIScrollView *)scrollView;

/**
 * @brief Scroll delegate: dragging ended.
 * @param scrollView The scrollView argument.
 * @param decelerate The decelerate argument.
 * @ghidraAddress 0x136d54
 */
- (void)scrollViewDidEndDragging:(nullable UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate;

/**
 * @brief Edit-modal delegate: the modal closed.
 * @param editModalViewClose The editModalViewClose argument.
 * @ghidraAddress 0x137024
 */
- (void)editModalViewClose:(nullable id)editModalViewClose;

/**
 * @brief Whether a download file is present.
 * @return The result.
 * @ghidraAddress 0x137288
 */
- (BOOL)checkDownloadFile;

/**
 * @brief Info-edit button action.
 * @param pushInfoEdit The pushInfoEdit argument.
 * @ghidraAddress 0x137378
 */
- (void)pushInfoEdit:(nullable id)pushInfoEdit;

/**
 * @brief Releases the edit-file list.
 * @ghidraAddress 0x13752c
 */
- (void)loadListRelease;

/**
 * @brief Opens the edit-file popover.
 * @ghidraAddress 0x137588
 */
- (void)editPopoverOpen;

/**
 * @brief Edit-list delegate: a new file was chosen.
 * @ghidraAddress 0x137e24
 */
- (void)editFileListViewSelectNewFile;

/**
 * @brief Edit-list delegate: an item was selected.
 * @param index The index argument.
 * @ghidraAddress 0x137fb0
 */
- (void)editFileListViewSelectItem:(int)index;

/**
 * @brief Edit-list delegate: a file was deleted.
 * @param editFileListViewDeleteFile The editFileListViewDeleteFile argument.
 * @ghidraAddress 0x138204
 */
- (void)editFileListViewDeleteFile:(nullable id)editFileListViewDeleteFile;

/**
 * @brief Selects an edit file.
 * @param selectEditFile The selectEditFile argument.
 * @ghidraAddress 0x1383f8
 */
- (void)selectEditFile:(nullable id)selectEditFile;

/**
 * @brief Popover delegate: the popover was dismissed.
 * @param popoverPresentationController The popoverPresentationController argument.
 * @ghidraAddress 0x1384d4
 */
- (void)popoverPresentationControllerDidDismissPopover:
    (nullable UIPopoverPresentationController *)popoverPresentationController;

/**
 * @brief Edit-list delegate: the list was cancelled.
 * @param editFileListViewCancel The editFileListViewCancel argument.
 * @ghidraAddress 0x138528
 */
- (void)editFileListViewCancel:(nullable id)editFileListViewCancel;

/**
 * @brief Download-sequence delegate: an error occurred.
 * @param errorSequenceDownload The errorSequenceDownload argument.
 * @ghidraAddress 0x1385ac
 */
- (void)errorSequenceDownload:(nullable id)errorSequenceDownload;

/**
 * @brief Download-sequence delegate: the download finished.
 * @param finishedSequenceDownload The finishedSequenceDownload argument.
 * @ghidraAddress 0x13868c
 */
- (void)finishedSequenceDownload:(nullable id)finishedSequenceDownload;

/**
 * @brief Download-sequence delegate: the storage cap was exceeded.
 * @param finishedSequenceOverCap The finishedSequenceOverCap argument.
 * @ghidraAddress 0x13876c
 */
- (void)finishedSequenceOverCap:(nullable id)finishedSequenceOverCap;

/**
 * @brief Releases owned resources.
 * @ghidraAddress 0x13884c
 */
- (void)dealloc;

/**
 * @brief Custom web-view delegate: the web view closed.
 * @param customWebViewClose The customWebViewClose argument.
 * @param seqIndex The seqIndex argument.
 * @ghidraAddress 0x138884
 */
- (void)customWebViewClose:(nullable id)customWebViewClose seqIndex:(nullable id)seqIndex;

/**
 * @brief Jcf download-end delegate.
 * @param downloadEnd The downloadEnd argument.
 * @ghidraAddress 0x1389a0
 */
- (void)downloadEnd:(nullable id)downloadEnd;

/**
 * @brief Removes the upload overlay.
 * @ghidraAddress 0x138bd8
 */
- (void)removeUploadView;

/**
 * @brief Upload-end callback.
 * @param uploadEnd The uploadEnd argument.
 * @ghidraAddress 0x138c40
 */
- (void)uploadEnd:(nullable id)uploadEnd;

/**
 * @brief The start-button image for this theme.
 * @return The result.
 * @ghidraAddress 0x138ecc
 */
- (nullable id)getStartImage;

/**
 * @brief The single-play button image for this theme.
 * @return The result.
 * @ghidraAddress 0x139004
 */
- (nullable id)getSingleImage;

/**
 * @brief Toggles the extend-chart display mode.
 * @ghidraAddress 0x13913c
 */
- (void)changeExtendMode;

/**
 * @brief The on-screen position for a difficulty.
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
