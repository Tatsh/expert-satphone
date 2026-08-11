/** @file
 * The music-selection detail card for the original (classic) theme.
 *
 * Reconstructed from Ghidra program Jubeat (class @c MusicDetailViewOrg, image base 0x100000000).
 * All @c @ghidraAddress values are offsets relative to that image base. The superclass is
 * @c MusicDetailView, confirmed from the class metadata.
 *
 * This theme variant carries the real per-difficulty layout the base @c MusicDetailView leaves
 * empty: the difficulty buttons and their lamps, the level-number and rating image grids, the
 * high-score board, and the music-bar dot grids for the base and extend charts, along with the
 * edit, upload, and info controls. Object collaborators whose concrete class is not yet resolved
 * are typed @c id as a stand-in.
 */

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#import "JcfDownloadPageNavController.h"
#import "JcfManageNavController.h"
#import "JcfUpLoadView.h"
#import "MusicDetailView.h"

@class TuneInfo;
@class JcfUpLoadView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The detail card for the original (classic) theme.
 */
@interface MusicDetailViewOrg : MusicDetailView <JcfDownloadPageNavControllerDelegate,
                                                 JcfManageNavControllerDelegate,
                                                 JcfUpLoadViewDelegate> {
    UIButton *btnDiff[4];
    UIImageView *lightView[4][2];
    UIImageView *diffTextView[4];
    UIImageView *levelTextView[4];
    UIImageView *levelNumView[4];
    UIImage *levelNumImg[5][10];
    UIImage *levelTextImg[5];
    CABasicAnimation *lightBlinkAnim;
    UIImageView *highscoreBoardView;
    UIImageView *ratingView;
    UIImageView *comboView;
    UIImageView *highscoreNumView[7];
    UIImage *highscoreNumImg[10];
    UIImage *ratingImg[9];
    UIImage *fullcomboImg;
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
    UIImageView *scrollLamp;
    UIImageView *diffBtnLamp;
    JcfUpLoadView *upLoadView;
    UIView *topcover;
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
 * @ghidraAddress 0x502bc
 */
+ (Class)layerClass;

/**
 * @brief Designated initialiser; builds the theme-specific detail layout.
 * @param frame The frame argument.
 * @return The result.
 * @ghidraAddress 0x502d0
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Builds a difficulty button.
 * @param imageName The base name of the button's scaled PNG image.
 * @return The configured button.
 * @ghidraAddress 0x537b0
 */
- (nullable UIButton *)diffButton:(nullable NSString *)imageName;

/**
 * @brief Loads the theme image assets.
 * @ghidraAddress 0x53958
 */
- (void)loadImages;

/**
 * @brief Loads the detail layout from a content dictionary.
 * @param dict The dict argument.
 * @ghidraAddress 0x5415c
 */
- (void)loadContentFromDictionary:(nullable NSDictionary *)dict;

/**
 * @brief Loads the detail layout from a file path or in-memory data.
 * @param path The path argument.
 * @param data The data argument.
 * @ghidraAddress 0x544f0
 */
- (void)loadContentFromPath:(nullable NSString *)path orData:(nullable NSData *)data;

/**
 * @brief Loads the extend-chart music bars from the packed extend archive at @p path.
 * @param path The extend archive path.
 * @ghidraAddress 0x54ad8
 */
- (void)loadExtendMusicBar:(nullable NSString *)path;

/**
 * @brief Stores the base-chart tune and score, then lays the card out.
 * @param info The info argument.
 * @param score The score argument.
 * @ghidraAddress 0x54dac
 */
- (void)setInfo:(nullable TuneInfo *)info score:(nullable id)score;

/**
 * @brief Switches the shown info to a difficulty.
 * @param difficulty The difficulty argument.
 * @ghidraAddress 0x551d4
 */
- (void)infoChange:(int)difficulty;

/**
 * @brief Stores the extend-chart tune and score.
 * @param info The info argument.
 * @param score The score argument.
 * @ghidraAddress 0x55bbc
 */
- (void)setExtendInfo:(nullable TuneInfo *)info score:(nullable id)score;

/**
 * @brief Switches the shown extend info to a difficulty.
 * @param difficulty The difficulty argument.
 * @ghidraAddress 0x56070
 */
- (void)changeExtend:(int)difficulty;

/**
 * @brief Clears the shown info.
 * @ghidraAddress 0x5679c
 */
- (void)clearInfo;

/**
 * @brief Handles a difficulty-button tap.
 * @param selectDiff The selectDiff argument.
 * @ghidraAddress 0x56850
 */
- (void)selectDiff:(nullable id)selectDiff;

/**
 * @brief Fills the score board.
 * @param score The score argument.
 * @param fullcombo The fullcombo argument.
 * @ghidraAddress 0x57170
 */
- (void)setScoreBoard:(int)score fullcombo:(BOOL)fullcombo;

/**
 * @brief Applies a difficulty change.
 * @param difficulty The difficulty argument.
 * @ghidraAddress 0x5749c
 */
- (void)changeDifficulty:(int)difficulty;

/**
 * @brief Handles a difficulty scroll change.
 * @param scrollChange The scrollChange argument.
 * @ghidraAddress 0x5786c
 */
- (void)scrollChange:(nullable id)scrollChange;

/**
 * @brief Fills the music-bar dot grid from a resource.
 * @param dots The dots argument.
 * @param mbarRes The mbarRes argument.
 * @ghidraAddress 0x57aa4
 */
- (void)setMusicBarDot:(nullable char *)dots mbarRes:(nullable char *)mbarRes;

/**
 * @brief Rebuilds the music-bar dot views.
 * @ghidraAddress 0x57bc8
 */
- (void)editMusicBar;

/**
 * @brief Resets an edit text field.
 * @param index The index argument.
 * @param isFirst The isFirst argument.
 * @ghidraAddress 0x580e8
 */
- (void)resetTextField:(int)index isFirst:(BOOL)isFirst;

/**
 * @brief Enables or disables the action buttons.
 * @param enable The enable argument.
 * @ghidraAddress 0x58938
 */
- (void)setEnableButton:(BOOL)enable;

/**
 * @brief Refreshes the start-button enabled state.
 * @ghidraAddress 0x58ab8
 */
- (void)setStartButtonEnable;

/**
 * @brief Shows or hides the card.
 * @param show The show argument.
 * @ghidraAddress 0x58d14
 */
- (void)show:(BOOL)show;

/**
 * @brief Host-share delegate: the share was cancelled.
 * @ghidraAddress 0x59668
 */
- (void)hostShareCancelled;

/**
 * @brief Shows or hides the share-data progress bar.
 * @param show The show argument.
 * @param animated The animated argument.
 * @ghidraAddress 0x599e4
 */
- (void)showDataProgress:(BOOL)show animated:(BOOL)animated;

/**
 * @brief Activates the difficulty light animation.
 * @param activate The activate argument.
 * @ghidraAddress 0x59ff0
 */
- (void)activateAnim:(BOOL)activate;

/**
 * @brief Start-play button action.
 * @param pushButtonStartPlay The pushButtonStartPlay argument.
 * @ghidraAddress 0x5a1c0
 */
- (void)pushButtonStartPlay:(nullable id)pushButtonStartPlay;

/**
 * @brief Edit-list delegate: the download entry was chosen.
 * @ghidraAddress 0x5ad18
 */
- (void)editFileListViewSelectDownload;

/**
 * @brief Begins the chart upload flow.
 * @ghidraAddress 0x5aefc
 */
- (void)uploadStart;

/**
 * @brief Upload button action.
 * @param pushButtonUpload The pushButtonUpload argument.
 * @ghidraAddress 0x5b3a8
 */
- (void)pushButtonUpload:(nullable id)pushButtonUpload;

/**
 * @brief Edit button action.
 * @param pushButtonEdit The pushButtonEdit argument.
 * @ghidraAddress 0x5b3ec
 */
- (void)pushButtonEdit:(nullable id)pushButtonEdit;

/**
 * @brief Edit-list delegate: the edit entry was chosen.
 * @ghidraAddress 0x5b3f8
 */
- (void)editFileListViewSelectEdit;

/**
 * @brief Begins the chart edit flow.
 * @ghidraAddress 0x5b498
 */
- (void)editStart;

/**
 * @brief Share button action.
 * @param pushButtonShare The pushButtonShare argument.
 * @ghidraAddress 0x5b914
 */
- (void)pushButtonShare:(nullable id)pushButtonShare;

/**
 * @brief Refreshes the start button.
 * @ghidraAddress 0x5c05c
 */
- (void)refreshStartButton;

/**
 * @brief Scroll delegate: dragging began.
 * @param scrollView The scrollView argument.
 * @ghidraAddress 0x5c4fc
 */
- (void)scrollViewWillBeginDragging:(nullable UIScrollView *)scrollView;

/**
 * @brief Scroll delegate: content offset changed.
 * @param scrollView The scrollView argument.
 * @ghidraAddress 0x5c500
 */
- (void)scrollViewDidScroll:(nullable UIScrollView *)scrollView;

/**
 * @brief Scroll delegate: programmatic scroll ended.
 * @param scrollView The scrollView argument.
 * @ghidraAddress 0x5c5dc
 */
- (void)scrollViewDidEndScrollingAnimation:(nullable UIScrollView *)scrollView;

/**
 * @brief Scroll delegate: deceleration ended.
 * @param scrollView The scrollView argument.
 * @ghidraAddress 0x5c8c8
 */
- (void)scrollViewDidEndDecelerating:(nullable UIScrollView *)scrollView;

/**
 * @brief Scroll delegate: dragging ended.
 * @param scrollView The scrollView argument.
 * @param decelerate The decelerate argument.
 * @ghidraAddress 0x5cb8c
 */
- (void)scrollViewDidEndDragging:(nullable UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate;

/**
 * @brief Edit-modal delegate: the modal closed.
 * @param editModalViewClose The editModalViewClose argument.
 * @ghidraAddress 0x5ce5c
 */
- (void)editModalViewClose:(nullable id)editModalViewClose;

/**
 * @brief Whether a download file is present.
 * @return The result.
 * @ghidraAddress 0x5d0c4
 */
- (BOOL)checkDownloadFile;

/**
 * @brief Info-edit button action.
 * @param pushInfoEdit The pushInfoEdit argument.
 * @ghidraAddress 0x5d1b4
 */
- (void)pushInfoEdit:(nullable id)pushInfoEdit;

/**
 * @brief Releases the edit-file list.
 * @ghidraAddress 0x5d368
 */
- (void)loadListRelease;

/**
 * @brief Opens the edit-file popover.
 * @ghidraAddress 0x5d3c4
 */
- (void)editPopoverOpen;

/**
 * @brief Edit-list delegate: a new file was chosen.
 * @ghidraAddress 0x5dc04
 */
- (void)editFileListViewSelectNewFile;

/**
 * @brief Edit-list delegate: an item was selected.
 * @param index The index argument.
 * @ghidraAddress 0x5dd90
 */
- (void)editFileListViewSelectItem:(int)index;

/**
 * @brief Edit-list delegate: a file was deleted.
 * @param editFileListViewDeleteFile The editFileListViewDeleteFile argument.
 * @ghidraAddress 0x5dfe4
 */
- (void)editFileListViewDeleteFile:(nullable id)editFileListViewDeleteFile;

/**
 * @brief Selects an edit file.
 * @param selectEditFile The selectEditFile argument.
 * @ghidraAddress 0x5e1d8
 */
- (void)selectEditFile:(nullable id)selectEditFile;

/**
 * @brief Popover delegate: the popover was dismissed.
 * @param popoverPresentationController The popoverPresentationController argument.
 * @ghidraAddress 0x5e2b4
 */
- (void)popoverPresentationControllerDidDismissPopover:
    (nullable UIPopoverPresentationController *)popoverPresentationController;

/**
 * @brief Edit-list delegate: the list was cancelled.
 * @param editFileListViewCancel The editFileListViewCancel argument.
 * @ghidraAddress 0x5e308
 */
- (void)editFileListViewCancel:(nullable id)editFileListViewCancel;

/**
 * @brief Download-sequence delegate: an error occurred.
 * @param errorSequenceDownload The errorSequenceDownload argument.
 * @ghidraAddress 0x5e38c
 */
- (void)errorSequenceDownload:(nullable id)errorSequenceDownload;

/**
 * @brief Download-sequence delegate: the download finished.
 * @param finishedSequenceDownload The finishedSequenceDownload argument.
 * @ghidraAddress 0x5e46c
 */
- (void)finishedSequenceDownload:(nullable id)finishedSequenceDownload;

/**
 * @brief Download-sequence delegate: the storage cap was exceeded.
 * @param finishedSequenceOverCap The finishedSequenceOverCap argument.
 * @ghidraAddress 0x5e54c
 */
- (void)finishedSequenceOverCap:(nullable id)finishedSequenceOverCap;

/**
 * @brief Releases owned resources.
 * @ghidraAddress 0x5e62c
 */
- (void)dealloc;

/**
 * @brief Custom web-view delegate: the web view closed.
 * @param customWebViewClose The customWebViewClose argument.
 * @param seqIndex The seqIndex argument.
 * @ghidraAddress 0x5e664
 */
- (void)customWebViewClose:(nullable id)customWebViewClose seqIndex:(nullable id)seqIndex;

/**
 * @brief Jcf download-end delegate.
 * @param downloadEnd The downloadEnd argument.
 * @ghidraAddress 0x5e780
 */
- (void)downloadEnd:(nullable id)downloadEnd;

/**
 * @brief Removes the upload overlay.
 * @ghidraAddress 0x5e9b8
 */
- (void)removeUploadView;

/**
 * @brief Upload-end callback.
 * @param uploadEnd The uploadEnd argument.
 * @ghidraAddress 0x5ea20
 */
- (void)uploadEnd:(nullable id)uploadEnd;

/**
 * @brief The start-button image for this theme.
 * @return The result.
 * @ghidraAddress 0x5ecac
 */
- (nullable id)getStartImage;

/**
 * @brief The single-play button image for this theme.
 * @return The result.
 * @ghidraAddress 0x5ede4
 */
- (nullable id)getSingleImage;

/**
 * @brief Toggles the extend-chart display mode.
 * @ghidraAddress 0x5ef1c
 */
- (void)changeExtendMode;

/**
 * @brief The on-screen position for a difficulty.
 * @param difficulty The difficulty argument.
 * @return The result.
 * @ghidraAddress 0x5f390
 */
- (CGPoint)getDifficultyPos:(int)difficulty;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
