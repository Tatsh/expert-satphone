#import "MusicDetailViewRpl.h"

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

// The Ripples theme resource names for the start-button image variants and the edit/close sounds.
static NSString *const kStartButtonImage = @"menu_button_start_rpl";
static NSString *const kRandomButtonImage = @"menu_button_random_rpl";
static NSString *const kSingleButtonImage = @"menu_button_single_rpl";
static NSString *const kEditSelectSound = @"SD_RPL_OK";
static NSString *const kMusicLeftSound = @"SD_RPL_MUSIC_LEFT";
static NSString *const kMusicRightSound = @"SD_RPL_MUSIC_RIGHT";
static NSString *const kMusicSelectSound = @"SD_RPL_MUSIC_SELECT";

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

// The upload sheet fades out over this (negative, as the binary passes it) duration.
static const NSTimeInterval kUploadEndFadeDuration = -0.2; // @ghidraAddress 0x28e050

// An unselected difficulty button dims to this alpha and shrinks to this scale on the Ripples
// theme.
static const CGFloat kDiffButtonDimAlpha = 0.5;  // fmov 0x3fe0000000000000
static const CGFloat kDiffButtonDimScale = 0.95; // @ghidraAddress 0x28f6e0
enum { kDiffButtonCount = 3, kExtendButtonIndex = 3 };

// The difficulty button's fixed frame size, per idiom.
static const double kDiffButtonWidthPad = 142.0;   // @ghidraAddress 0x292e88
static const double kDiffButtonWidthPhone = 78.0;  // @ghidraAddress 0x28f5f0
static const double kDiffButtonHeightPad = 138.0;  // @ghidraAddress 0x2924c8
static const double kDiffButtonHeightPhone = 76.0; // @ghidraAddress 0x292488

// The seven high-score digits render with a right-justified %7d through highscoreNumImg; a perfect
// score shows the excellent image instead of a rank.
enum {
    kHighscoreDigitCount = 7,
    kExcellentScore = 1000000,
    kDigitGlyphCount = 10,
};
static const char kDigitZero = '0';

// The scroll page and preferred difficulty persist across sessions under these preference keys.
static NSString *const kPrefEditSelectKey = @"PrefEditSelect";
static NSString *const kPrefDifficultyKey = @"PrefDifficulty";

// The three scroll-settled delegate callbacks share this tail: it snaps the settled page,
// re-derives the hold flag from the current difficulty's hold mark (except on the edit page),
// refreshes the start button, records the page, and applies either the difficulty (snapping a stale
// extreme back to basic) on the detail page or the edit music bar on the edit page.
static inline void MusicDetailViewRplSettleScrollPage(MusicDetailViewRpl *self) {
    [self setEnableButton:YES];
    double width = self.scrollView.frame.size.width;
    int page = (int)((width * 0.5 + self.scrollView.contentOffset.x) / width);
    self.editPage = page;
    int difficulty = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
    BOOL holdHidden = self->holdMark[difficulty].isHidden;
    [JubeatAppDelegate.appDelegate setHoldFlag:(page != 1) && !holdHidden];
    [self refreshStartButton];
    if (self.isStarted) {
        return;
    }
    [NSUserDefaults.standardUserDefaults setInteger:page forKey:kPrefEditSelectKey];
    if (page == 0) {
        int detailDifficulty =
            (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
        if (detailDifficulty > 2) {
            [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefDifficultyKey];
            detailDifficulty = 0;
        }
        [self changeDifficulty:detailDifficulty];
    } else {
        [self editMusicBar];
    }
    [self setStartButtonEnable];
}

// A chart level maps to a zero-based level-image index: below 2 -> first image, 10+ -> last of ten.
static inline char MusicDetailViewRplLevelIndex(int level) {
    if (level < 2) {
        return 0;
    }
    if (level < 10) {
        return (char)(level - 1);
    }
    return 9;
}

@implementation MusicDetailViewRpl

/** @ghidraAddress 0x12ad40 */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

/** @ghidraAddress 0x13884c */
- (void)dealloc {
    // Empty in the binary too: the only instruction is the super call, and the class has a
    // .cxx_destruct, so that call is what ARC emits.
}

/** @ghidraAddress 0x135630 */
- (void)pushButtonEdit:(nullable id)sender {
    [self editStart];
}

/** @ghidraAddress 0x13554c */
- (void)pushButtonUpload:(nullable id)sender {
    if ([self checkEnableUpload]) {
        [self uploadStart];
    }
}

/** @ghidraAddress 0x13752c */
- (void)loadListRelease {
    [self.pFileListView setDelegate:nil];
    self.pFileListView = nil;
}

/** @ghidraAddress 0x1384d4 */
- (void)popoverPresentationControllerDidDismissPopover:
    (nullable UIPopoverPresentationController *)popoverPresentationController {
    [self loadListRelease];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x1366a0 */
- (void)scrollViewWillBeginDragging:(nullable UIScrollView *)scrollView {
}

/** @ghidraAddress 0x12f0dc */
- (void)setInfo:(nullable TuneInfo *)info score:(nullable id)score {
    [super setInfo:info score:score];
    if (info == nil) {
        return;
    }
    self.levelBas = MusicDetailViewRplLevelIndex(info.lvBas);
    self.levelAdv = MusicDetailViewRplLevelIndex(info.lvAdv);
    self.levelExt = MusicDetailViewRplLevelIndex(info.lvExt);
    [self.buttonLink setEnabled:(info.iTunesURL != nil)];
    [self.buttonLink setHidden:(info.iTunesURL == nil)];
    [self.btnRecommendTwitter setHidden:NO];
    [self.btnRecommendFacebook setHidden:NO];
    [levelNumView[0] setImage:levelNumImg[self.levelBas]];
    [levelNumView[1] setImage:levelNumImg[self.levelAdv]];
    [levelNumView[2] setImage:levelNumImg[self.levelExt]];
    [levelNumView[kExtendButtonIndex] setImage:levelNumImg[self.levelExt]];
    [levelNumView[kExtendButtonIndex] setAlpha:0.0];
    [self resetScore];
    [self putScore:score];
    [self loadContentFromPath:info.filePath orData:nil];
    [self loadEditFile];
    [self resetTextField:(int)info.tuneID isFirst:YES];
    [self editMusicBar];
}

/** @ghidraAddress 0x1316b4 */
- (void)setScoreBoard:(int)score fullcombo:(BOOL)fullcombo {
    char digits[8] = {
        kDigitZero, kDigitZero, kDigitZero, kDigitZero, kDigitZero, kDigitZero, kDigitZero, 0};
    if (score < 0) {
        [ratingView setImage:nil];
        [comboView setImage:nil];
    } else if (score < kExcellentScore) {
        SequenceRank rank = [Sequence rankOfPoint:score];
        [ratingView setImage:ratingImg[rank]];
        [comboView setImage:(fullcombo ? fullcomboImg : nil)];
        snprintf(digits, sizeof(digits), "%7d", score);
    } else {
        [ratingView setImage:nil];
        [comboView setImage:excellentImg];
        snprintf(digits, sizeof(digits), "%7d", score);
    }
    for (int i = 0; i < kHighscoreDigitCount; ++i) {
        int glyph = digits[i] - kDigitZero;
        UIImage *image = ((unsigned int)glyph < kDigitGlyphCount) ? highscoreNumImg[glyph] : nil;
        [highscoreNumView[i] setImage:image];
    }
}

/** @ghidraAddress 0x12dc84 */
- (nullable UIButton *)diffButton:(nullable NSString *)imageName {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    double width = self.isPad ? kDiffButtonWidthPad : kDiffButtonWidthPhone;
    double height = self.isPad ? kDiffButtonHeightPad : kDiffButtonHeightPhone;
    [button setFrame:CGRectMake(0.0, 0.0, width, height)];
    [button setImage:LoadScaledPngImage(imageName) forState:UIControlStateNormal];
    [button setExclusiveTouch:YES];
    [button setAdjustsImageWhenHighlighted:NO];
    [button setAdjustsImageWhenDisabled:NO];
    [button addTarget:self
                  action:@selector(selectDiff:)
        forControlEvents:UIControlEventTouchUpInside];
    return button;
}

/** @ghidraAddress 0x131a48 */
- (void)changeDifficulty:(int)difficulty {
    // The selected base button is full and unscaled; the other two dim and shrink; the extend
    // button is always full.
    for (int i = 0; i < kDiffButtonCount; ++i) {
        if (i == difficulty) {
            [btnDiff[i] setAlpha:1.0];
            [btnDiff[i] setTransform:CGAffineTransformIdentity];
        } else {
            [btnDiff[i] setAlpha:kDiffButtonDimAlpha];
            [btnDiff[i]
                setTransform:CGAffineTransformMakeScale(kDiffButtonDimScale, kDiffButtonDimScale)];
        }
    }
    [btnDiff[kExtendButtonIndex] setAlpha:1.0];
    [btnDiff[kExtendButtonIndex] setTransform:CGAffineTransformIdentity];
    [self infoChange:difficulty];
}

/** @ghidraAddress 0x132ed4 */
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

/** @ghidraAddress 0x132d54 */
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

/** @ghidraAddress 0x134ebc */
- (void)editFileListViewSelectDownload {
    [[AudioManager sharedManager] playSeResFile:kMusicRightSound inDirectory:nil];
    [NSUserDefaults.standardUserDefaults setInteger:kJcfDownloadSelectDownload
                                             forKey:kPrefJcfDownloadSelectKey];
    [self.controller dismissViewControllerAnimated:self.isPad completion:nil];
    self.jcfDownloadPage = [[JcfDownloadPageNavController alloc] initWithMusicID:self.info.tuneID
                                                                        delegate:self];
    [self.controller presentViewController:self.jcfDownloadPage animated:YES completion:nil];
}

/** @ghidraAddress 0x137e24 */
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

/** @ghidraAddress 0x137fb0 */
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

/** @ghidraAddress 0x138204 */
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

/** @ghidraAddress 0x1389a0 */
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

/** @ghidraAddress 0x130afc */
- (void)clearInfo {
    [self.artworkView setImage:nil];
    [self.reflectionArtworkView setImage:nil];
    [self.tuneNameView setImage:nil];
}

/** @ghidraAddress 0x135590 */
- (void)editFileListViewSelectEdit {
    [[AudioManager sharedManager] playSeResFile:kEditSelectSound inDirectory:nil];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
    [self editStart];
}

/** @ghidraAddress 0x138528 */
- (void)editFileListViewCancel:(nullable id)sender {
    [self.controller enableCoverTap];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
}

/** @ghidraAddress 0x1383f8 */
- (void)selectEditFile:(nullable id)fileName {
    [[EditDataManager sharedManager] setLastEditFileName:(int)self.info.tuneID fileName:fileName];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x137288 */
- (BOOL)checkDownloadFile {
    if ([[EditDataManager sharedManager] getLastEditFileName:(int)self.info.tuneID] == nil) {
        return YES;
    }
    return [EditDataManager sharedManager].bIsDownload;
}

/** @ghidraAddress 0x1385ac */
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

/** @ghidraAddress 0x13868c */
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

/** @ghidraAddress 0x13876c */
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

/** @ghidraAddress 0x138bd8 */
- (void)removeUploadView {
    if (upLoadView != nil) {
        [topcover removeFromSuperview];
        topcover = nil;
        [upLoadView removeFromSuperview];
        upLoadView = nil;
    }
}

/** @ghidraAddress 0x138884 */
- (void)customWebViewClose:(nullable id)webView seqIndex:(nullable id)seqIndex {
    [self resetTextField:(int)self.info.tuneID isFirst:NO];
    [self setStartButtonEnable];
    [[AudioManager sharedManager] playSeResFile:kMusicLeftSound inDirectory:nil];
    [self.controller enableCoverTap];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
}

/** @ghidraAddress 0x1366a4 */
- (void)scrollViewDidScroll:(nullable UIScrollView *)scrollView {
    float offsetX = (float)scrollView.contentOffset.x;
    float half = (float)(scrollView.contentSize.width * 0.5);
    float denom = half * kScrollFadeSpanFraction;
    [detailScrollButton[0] setAlpha:(double)(1.0f - MIN(offsetX / denom, 1.0f))];
    [detailScrollButton[1] setAlpha:(double)(1.0f - MIN((half - offsetX) / denom, 1.0f))];
}

/** @ghidraAddress 0x131ed8 */
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

/** @ghidraAddress 0x139544 */
- (CGPoint)getDifficultyPos:(int)difficulty {
    int index = (difficulty > 2) ? 0 : difficulty;
    int scrollY = (int)self.scrollView.frame.origin.y;
    int buttonX = (int)btnDiff[index].frame.origin.x;
    int scrollX = (int)self.scrollView.frame.origin.x;
    int buttonY = (int)btnDiff[index].frame.origin.y;
    return CGPointMake((double)(int)((double)scrollX + (double)buttonX),
                       (double)(int)((double)scrollY + (double)buttonY));
}

/** @ghidraAddress 0x138c40 */
- (void)uploadEnd:(nullable id)sender {
    __weak UIView *weakCover = topcover;
    __weak JcfUpLoadView *weakUpload = upLoadView;
    // The binary passes a negative fade duration here; kept as-is.
    [UIView animateWithDuration:kUploadEndFadeDuration
        animations:^{
          /** @ghidraAddress 0x138de4 */
          [weakCover setAlpha:0.0];
          [weakUpload setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x138eac */
          [self removeUploadView];
        }];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x131ca0 */
- (void)scrollChange:(nullable id)sender {
    if (self.isStarted) {
        return;
    }
    double width = self.scrollView.frame.size.width;
    double offsetX = self.scrollView.contentOffset.x;
    int page = (int)floor((width * 0.5 + offsetX) / width);
    double snapX = (page != 0) ? 0.0 : (double)(int)width;
    [self.scrollView setContentOffset:CGPointMake(snapX, 0.0) animated:YES];
    [self setEnableButton:NO];
    if (page == 1) {
        int difficulty =
            (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
        if (difficulty > 2) {
            [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefDifficultyKey];
            difficulty = 0;
        }
        [self changeDifficulty:difficulty];
    } else {
        [self editMusicBar];
    }
    [[AudioManager sharedManager] playSeResFile:kMusicSelectSound inDirectory:nil];
    [self setStartButtonEnable];
}

/** @ghidraAddress 0x136780 */
- (void)scrollViewDidEndScrollingAnimation:(nullable UIScrollView *)scrollView {
    [detailScrollButton[0] setAlpha:1.0];
    [detailScrollButton[1] setAlpha:1.0];
    MusicDetailViewRplSettleScrollPage(self);
}

/** @ghidraAddress 0x136a80 */
- (void)scrollViewDidEndDecelerating:(nullable UIScrollView *)scrollView {
    MusicDetailViewRplSettleScrollPage(self);
}

/** @ghidraAddress 0x136d54 */
- (void)scrollViewDidEndDragging:(nullable UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        MusicDetailViewRplSettleScrollPage(self);
    }
}

/** @ghidraAddress 0x137378 */
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

/** @ghidraAddress 0x137024 */
- (void)editModalViewClose:(nullable id)sender {
    [[AudioManager sharedManager] playSeResFile:kMusicLeftSound inDirectory:nil];
    NSMutableDictionary *editorInfo = [[EditDataManager sharedManager] getEditorInfo];
    [editTxt[0] setText:editorInfo[@"fumenName"]];
    [editTxt[1] setText:editorInfo[@"editorName"]];
    [editTxt[2] setText:editorInfo[@"comment"]];
    int level = [editorInfo[@"level"] intValue];
    [levelNumView[kExtendButtonIndex] setImage:levelNumImg[level]];
    [levelNumView[kExtendButtonIndex] setAlpha:1.0];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x138ecc */
- (nullable id)getStartImage {
    if (![JubeatAppDelegate.appDelegate isRandom]) {
        return [[ImageCache sharedCache] getResPNG:kStartButtonImage];
    }
    if ([JubeatAppDelegate.appDelegate isHold]) {
        return [[ImageCache sharedCache] getResPNG:kStartButtonImage];
    }
    return [[ImageCache sharedCache] getResPNG:kRandomButtonImage];
}

/** @ghidraAddress 0x139004 */
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
