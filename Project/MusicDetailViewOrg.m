#import "MusicDetailViewOrg.h"

#import <QuartzCore/QuartzCore.h>

#import "AlertViewManager.h"
#import "EditDataManager.h"
#import "ImageCache.h"
#import "ImageLoading.h"
#import "JcfDownloadPageNavController.h"
#import "JcfManageNavController.h"
#import "JubeatAppDelegate.h"
#import "LatelyJcfListManager.h"
#import "MusicSelectViewController.h"
#import "Sequence.h"
#import "TuneInfo.h"

// The classic theme resource names for the start-button image variants and the edit/close sounds.
static NSString *const kStartButtonImage = @"menu_button_start";
static NSString *const kRandomButtonImage = @"menu_button_random";
static NSString *const kSingleButtonImage = @"menu_button_single";
static NSString *const kEditSelectSound = @"SD_OK";
static NSString *const kMusicLeftSound = @"SD_MUSIC_LEFT";
static NSString *const kMusicRightSound = @"SD_MUSIC_RIGHT";

// The download-selection preference remembers that the download entry was chosen (value 2).
static NSString *const kPrefJcfDownloadSelectKey = @"PrefJcfDownloadSelect";
static const NSInteger kJcfDownloadSelectDownload = 2;

// The download-sequence alert messages, the binary's shared Japanese literals.
static NSString *const kConnectErrorMessage = @"通信エラー";
static NSString *const kDownloadFinishedMessage = @"ダウンロード終わり";

// The music bar holds 120 dot views; each dot's sprite is a 4-bit nibble of the dot map and its
// image row a 2-bit field of the resource map.
enum {
    kMusicBarDotCount = 120,
    kMusicBarDotSpriteCount = 8,
};

// The scroll button fades out across an eighth of the half-width scroll span.
static const float kScrollFadeSpanFraction = 0.125f;

// The classic difficulty button's fixed square frame: 160 on the pad, 80 on the retina phone, and
// 74 on the non-retina phone.
static const double kDiffButtonSizePad = 160.0;      // @ghidraAddress 0x28f438
static const double kDiffButtonSizeRetina = 80.0;    // @ghidraAddress 0x28f3f8
static const double kDiffButtonSizeNonRetina = 74.0; // @ghidraAddress 0x28f6f8

// The seven high-score digits render with a right-justified %7d through highscoreNumImg; the score
// is clamped to the perfect score.
enum {
    kHighscoreDigitCount = 7,
    kExcellentScore = 1000000,
    kDigitGlyphCount = 10,
};
static const char kDigitZero = '0';

// The preferred-difficulty preference selects which difficulty's light pair the blink animation
// plays on, keyed by this animation name.
static NSString *const kPrefDifficultyKey = @"PrefDifficulty";
static NSString *const kBlinkAnimationKey = @"AnimBlinkNormal";

// The extend level image lives at difficulty-table row 4, column 4 of the level-number views.
enum {
    kExtendLevelNumIndex = 3,
    kExtendLevelRow = 4,
};

@implementation MusicDetailViewOrg

/** @ghidraAddress 0x502bc */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

/** @ghidraAddress 0x5b3ec */
- (void)pushButtonEdit:(nullable id)sender {
    [self editStart];
}

/** @ghidraAddress 0x5b3a8 */
- (void)pushButtonUpload:(nullable id)sender {
    if ([self checkEnableUpload]) {
        [self uploadStart];
    }
}

/** @ghidraAddress 0x5d368 */
- (void)loadListRelease {
    [self.pFileListView setDelegate:nil];
    self.pFileListView = nil;
}

/** @ghidraAddress 0x5e2b4 */
- (void)popoverPresentationControllerDidDismissPopover:
    (nullable UIPopoverPresentationController *)popoverPresentationController {
    [self loadListRelease];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x5c4fc */
- (void)scrollViewWillBeginDragging:(nullable UIScrollView *)scrollView {
}

/** @ghidraAddress 0x57170 */
- (void)setScoreBoard:(int)score fullcombo:(BOOL)fullcombo {
    // The classic theme clamps the score to the perfect score and shows only the rating and the
    // seven score digits (no combo/full-combo mark).
    int clamped = (score < kExcellentScore) ? score : kExcellentScore;
    char digits[8] = {
        kDigitZero, kDigitZero, kDigitZero, kDigitZero, kDigitZero, kDigitZero, kDigitZero, 0};
    if (clamped < 0) {
        [ratingView setImage:nil];
    } else {
        snprintf(digits, sizeof(digits), "%7d", clamped);
        SequenceRank rank = [Sequence rankOfPoint:clamped];
        [ratingView setImage:ratingImg[rank]];
    }
    for (int i = 0; i < kHighscoreDigitCount; ++i) {
        int glyph = digits[i] - kDigitZero;
        UIImage *image = ((unsigned int)glyph < kDigitGlyphCount) ? highscoreNumImg[glyph] : nil;
        [highscoreNumView[i] setImage:image];
    }
}

/** @ghidraAddress 0x537b0 */
- (nullable UIButton *)diffButton:(nullable NSString *)imageName {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    double size = self.isPad ? kDiffButtonSizePad :
                               (self.isRetina ? kDiffButtonSizeRetina : kDiffButtonSizeNonRetina);
    [button setFrame:CGRectMake(0.0, 0.0, size, size)];
    [button setImage:LoadScaledPngImage(imageName) forState:UIControlStateNormal];
    [button setExclusiveTouch:YES];
    [button setAdjustsImageWhenHighlighted:NO];
    [button setAdjustsImageWhenDisabled:NO];
    [button addTarget:self
                  action:@selector(selectDiff:)
        forControlEvents:UIControlEventTouchUpInside];
    return button;
}

/** @ghidraAddress 0x58ab8 */
- (void)setStartButtonEnable {
    if (self.editPage == 1) {
        int notesNum = [[EditDataManager sharedManager].getEditorInfo[@"notesNum"] intValue];
        [uploadBtn setEnabled:[self checkEnableUpload]];
        [editBtn setEnabled:[self checkEnableEdit]];
        [infoBtn setEnabled:[self checkEnableInfoChange]];
        if (notesNum == 0) {
            [self.buttonStartPlay setEnabled:NO];
            return;
        }
    }
    [self.buttonStartPlay setEnabled:YES];
    if (self.controller.sharePlayManager != nil && !self.isSharedStartable) {
        [self.buttonStartPlay setEnabled:NO];
    }
}

/** @ghidraAddress 0x58938 */
- (void)setEnableButton:(BOOL)enable {
    [btnDiff[0] setEnabled:enable];
    [btnDiff[1] setEnabled:enable];
    [btnDiff[2] setEnabled:enable];
    [btnDiff[3] setEnabled:enable];
    [infoBtn setEnabled:enable];
    [uploadBtn setEnabled:enable];
    [editBtn setEnabled:enable];
    [detailScrollButton[0] setEnabled:enable];
    [detailScrollButton[1] setEnabled:enable];
    if (enable) {
        [infoBtn setEnabled:[self checkEnableInfoChange]];
        [uploadBtn setEnabled:[self checkEnableUpload]];
        [editBtn setEnabled:[self checkEnableEdit]];
    }
}

/** @ghidraAddress 0x5ad18 */
- (void)editFileListViewSelectDownload {
    [[AudioManager sharedManager] playSeResFile:kMusicRightSound inDirectory:nil];
    [NSUserDefaults.standardUserDefaults setInteger:kJcfDownloadSelectDownload
                                             forKey:kPrefJcfDownloadSelectKey];
    [self.controller dismissViewControllerAnimated:self.isPad completion:nil];
    self.jcfDownloadPage = [[JcfDownloadPageNavController alloc] initWithMusicID:self.info.tuneID
                                                                        delegate:self];
    [self.controller presentViewController:self.jcfDownloadPage animated:YES completion:nil];
}

/** @ghidraAddress 0x5dc04 */
- (void)editFileListViewSelectNewFile {
    [NSUserDefaults.standardUserDefaults setInteger:kJcfDownloadSelectDownload
                                             forKey:kPrefJcfDownloadSelectKey];
    [self selectEditFile:@""];
    [self resetTextField:(int)self.info.tuneID isFirst:NO];
    [[EditDataManager sharedManager] resetEditorInfo];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
    [self editMusicBar];
    [self editStart];
    [[AudioManager sharedManager] playSeResFile:kEditSelectSound inDirectory:nil];
}

/** @ghidraAddress 0x5dd90 */
- (void)editFileListViewSelectItem:(int)index {
    if (index < 0) {
        return;
    }
    NSMutableArray<NSMutableDictionary *> *files =
        [[EditDataManager sharedManager] getFileInfoList:self.info.tuneID];
    [self selectEditFile:files[index][@"fileName"]];
    [self loadEditFile];
    [self resetTextField:(int)self.info.tuneID isFirst:NO];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
    [self editMusicBar];
    [self setStartButtonEnable];
    [[AudioManager sharedManager] playSeResFile:kEditSelectSound inDirectory:nil];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x5dfe4 */
- (void)editFileListViewDeleteFile:(nullable id)fileName {
    EditDataManager *manager = [EditDataManager sharedManager];
    NSString *lastEdit = [manager getLastEditFileName:(int)self.info.tuneID];
    NSString *path =
        [[manager getDirectoryPath:(int)self.info.tuneID] stringByAppendingPathComponent:fileName];
    [manager deleteJCF:path];
    if ([lastEdit isEqualToString:fileName]) {
        [manager clearEditData];
        [self editMusicBar];
        [self resetTextField:(int)self.info.tuneID isFirst:NO];
        [self setStartButtonEnable];
    }
}

/** @ghidraAddress 0x5e780 */
- (void)downloadEnd:(nullable id)sender {
    if (!self.isPad && self.jcfMan != nil) {
        [self loadEditFile];
        NSMutableArray<NSMutableDictionary *> *files =
            [[EditDataManager sharedManager] getFileInfoList:self.info.tuneID];
        [self.jcfMan reloadList:files];
        [self resetTextField:(int)self.info.tuneID isFirst:NO];
        [self setStartButtonEnable];
    }
    [self editMusicBar];
    NSString *owner = [NSString stringWithFormat:@"%d", self.info.tuneID];
    [[LatelyJcfListManager sharedManager] removeJcfOwner:owner];
}

/** @ghidraAddress 0x5679c */
- (void)clearInfo {
    [self.artworkView setImage:nil];
    [self.reflectionArtworkView setImage:nil];
    [self.tuneNameView setImage:nil];
}

/** @ghidraAddress 0x5b3f8 */
- (void)editFileListViewSelectEdit {
    [[AudioManager sharedManager] playSeResFile:kEditSelectSound inDirectory:nil];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
    [self editStart];
}

/** @ghidraAddress 0x5e308 */
- (void)editFileListViewCancel:(nullable id)sender {
    [self.controller enableCoverTap];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
}

/** @ghidraAddress 0x5e1d8 */
- (void)selectEditFile:(nullable id)fileName {
    [[EditDataManager sharedManager] setLastEditFileName:(int)self.info.tuneID fileName:fileName];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x5d0c4 */
- (BOOL)checkDownloadFile {
    if ([[EditDataManager sharedManager] getLastEditFileName:(int)self.info.tuneID] == nil) {
        return YES;
    }
    return [EditDataManager sharedManager].bIsDownload;
}

/** @ghidraAddress 0x5e38c */
- (void)errorSequenceDownload:(nullable id)sender {
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:nil
                                            msg:kConnectErrorMessage
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

/** @ghidraAddress 0x5e46c */
- (void)finishedSequenceDownload:(nullable id)sender {
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:nil
                                            msg:kDownloadFinishedMessage
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

/** @ghidraAddress 0x5e54c */
- (void)finishedSequenceOverCap:(nullable id)sender {
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:nil
                                            msg:kDownloadFinishedMessage
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

/** @ghidraAddress 0x5e9b8 */
- (void)removeUploadView {
    if (upLoadView != nil) {
        [topcover removeFromSuperview];
        topcover = nil;
        [upLoadView removeFromSuperview];
        upLoadView = nil;
    }
}

/** @ghidraAddress 0x5e664 */
- (void)customWebViewClose:(nullable id)webView seqIndex:(nullable id)seqIndex {
    [self resetTextField:(int)self.info.tuneID isFirst:NO];
    [self setStartButtonEnable];
    [[AudioManager sharedManager] playSeResFile:kMusicLeftSound inDirectory:nil];
    [self.controller enableCoverTap];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
}

/** @ghidraAddress 0x5c500 */
- (void)scrollViewDidScroll:(nullable UIScrollView *)scrollView {
    float offsetX = (float)scrollView.contentOffset.x;
    float half = (float)(scrollView.contentSize.width * 0.5);
    float denom = half * kScrollFadeSpanFraction;
    [detailScrollButton[0] setAlpha:(double)(1.0f - MIN(offsetX / denom, 1.0f))];
    [detailScrollButton[1] setAlpha:(double)(1.0f - MIN((half - offsetX) / denom, 1.0f))];
}

/** @ghidraAddress 0x57aa4 */
- (void)setMusicBarDot:(nullable char *)dots mbarRes:(nullable char *)mbarRes {
    if (dots == nullptr) {
        for (int i = 0; i < kMusicBarDotCount; ++i) {
            [mbarDotView[i] setImage:nil];
        }
        return;
    }
    for (int i = 0; i < kMusicBarDotCount; ++i) {
        int row = 0;
        if (mbarRes != nullptr) {
            row = (mbarRes[i >> 2] >> ((i & 3) * 2)) & 3;
        }
        int sprite = ((dots[i >> 1] >> ((i & 1) * 4)) & 0xf) - 1;
        UIImage *image =
            ((unsigned int)sprite < kMusicBarDotSpriteCount) ? mbarDotImg[row][sprite] : nil;
        [mbarDotView[i] setImage:image];
    }
}

/** @ghidraAddress 0x5f390 */
- (CGPoint)getDifficultyPos:(int)difficulty {
    int index = (difficulty > 2) ? 0 : difficulty;
    int scrollY = (int)self.scrollView.frame.origin.y;
    int buttonX = (int)btnDiff[index].frame.origin.x;
    int scrollX = (int)self.scrollView.frame.origin.x;
    int buttonY = (int)btnDiff[index].frame.origin.y;
    return CGPointMake((double)(int)((double)scrollX + (double)buttonX),
                       (double)(int)((double)scrollY + (double)buttonY));
}

/** @ghidraAddress 0x59ff0 */
- (void)activateAnim:(BOOL)activate {
    int difficulty = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
    if (activate) {
        [lightView[difficulty][0].layer addAnimation:lightBlinkAnim forKey:kBlinkAnimationKey];
        [lightView[difficulty][1].layer addAnimation:lightBlinkAnim forKey:kBlinkAnimationKey];
        return;
    }
    [lightView[difficulty][0].layer removeAnimationForKey:kBlinkAnimationKey];
    [lightView[difficulty][0] setAlpha:1.0];
    [lightView[difficulty][1].layer removeAnimationForKey:kBlinkAnimationKey];
    [lightView[difficulty][1] setAlpha:1.0];
}

/** @ghidraAddress 0x5d1b4 */
- (void)pushInfoEdit:(nullable id)sender {
    if (![self checkDownloadFile] && self.isPad) {
        [[AudioManager sharedManager] playSeResFile:kMusicRightSound inDirectory:nil];
        self.pEditModalView = [[EditModalView alloc] initWithType:0];
        [self.pEditModalView setEditDelegate:self];
        self.isEditInfoOpen = YES;
        [self.controller presentViewController:self.pEditModalView animated:YES completion:nil];
        [self.controller unenableCoverTap];
    }
}

/** @ghidraAddress 0x5ce5c */
- (void)editModalViewClose:(nullable id)sender {
    [[AudioManager sharedManager] playSeResFile:kMusicLeftSound inDirectory:nil];
    NSMutableDictionary *editorInfo = [[EditDataManager sharedManager] getEditorInfo];
    [editTxt[0] setText:editorInfo[@"fumenName"]];
    [editTxt[1] setText:editorInfo[@"editorName"]];
    [editTxt[2] setText:editorInfo[@"comment"]];
    int level = [editorInfo[@"level"] intValue];
    // The classic theme keeps level images in a per-difficulty table; the extend slot uses the
    // extend row.
    [levelNumView[kExtendLevelNumIndex] setImage:levelNumImg[kExtendLevelRow][level]];
    [levelNumView[kExtendLevelNumIndex] setAlpha:1.0];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x5ecac */
- (nullable id)getStartImage {
    if (![JubeatAppDelegate.appDelegate isRandom]) {
        return [[ImageCache sharedCache] getResPNG:kStartButtonImage];
    }
    if ([JubeatAppDelegate.appDelegate isHold]) {
        return [[ImageCache sharedCache] getResPNG:kStartButtonImage];
    }
    return [[ImageCache sharedCache] getResPNG:kRandomButtonImage];
}

/** @ghidraAddress 0x5ede4 */
- (nullable id)getSingleImage {
    if (![JubeatAppDelegate.appDelegate isRandom]) {
        return [[ImageCache sharedCache] getResPNG:kSingleButtonImage];
    }
    if ([JubeatAppDelegate.appDelegate isHold]) {
        return [[ImageCache sharedCache] getResPNG:kSingleButtonImage];
    }
    return [[ImageCache sharedCache] getResPNG:kRandomButtonImage];
}

@end
