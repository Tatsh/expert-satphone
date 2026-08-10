#import "MusicDetailViewOrg.h"

#import <QuartzCore/QuartzCore.h>

#import "AlertViewManager.h"
#import "BFCodec.h"
#import "EditDataManager.h"
#import "ImageCache.h"
#import "ImageLoading.h"
#import "JcfDownloadPageNavController.h"
#import "JcfManageNavController.h"
#import "JcfUpLoadView.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "LabUtilities.h"
#import "LatelyJcfListManager.h"
#import "MusicSelectViewController.h"
#import "Sequence.h"
#import "TuneInfo.h"

extern const double g_dAnimDuration020; // @ghidraAddress 0x28f240 (0.2)

// The classic theme resource names for the start-button image variants and the edit/close sounds.
static NSString *const kStartButtonImage = @"menu_button_start";
static NSString *const kRandomButtonImage = @"menu_button_random";
static NSString *const kSingleButtonImage = @"menu_button_single";
static NSString *const kEditSelectSound = @"SD_OK";
static NSString *const kMusicLeftSound = @"SD_MUSIC_LEFT";
static NSString *const kMusicRightSound = @"SD_MUSIC_RIGHT";
static NSString *const kMusicSelectSound = @"SD_MUSIC_SELECT";

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

// The dimming cover behind the upload sheet is translucent black at this alpha and both fade in
// over this duration.
static const CGFloat kUploadCoverScrimAlpha = 0.3;     // @ghidraAddress 0x28f248
static const NSTimeInterval kUploadFadeDuration = 0.2; // @ghidraAddress 0x28e040

// Cancelling a host share fades the share-message label out over this duration.
static const NSTimeInterval kHostShareCancelFadeDuration = 0.1; // @ghidraAddress 0x28f290

// The random marker slides up by this many points out of view and toggles over this duration.
static const int kRandViewSlideOffset = 10;
static const NSTimeInterval kRandViewToggleDuration = 0.3; // @ghidraAddress 0x28f260

// The three selectable difficulty buttons (a fourth extend slot follows).
enum { kDiffButtonCount = 3 };

// Entering edit shrinks the difficulty buttons to this scale over this duration, and input stays
// locked for a slightly longer beat.
static const CGFloat kEditButtonShrinkScale = 0.1;         // @ghidraAddress 0x28f2b8
static const NSTimeInterval kEditTransitionDuration = 0.6; // @ghidraAddress 0x28f288
static const NSTimeInterval kEditInputLockDuration = 0.7;  // @ghidraAddress 0x28f2a0

// The host share-play button's background image.
static NSString *const kHostButtonImage = @"menu_button_host";

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

// The scroll page persists across sessions under this preference key.
static NSString *const kPrefEditSelectKey = @"PrefEditSelect";

// The packed-content dictionary keys and the reflection height fraction (of the artwork height) on
// the pad. The classic theme stores the tune name under name_w (white), unlike the other themes.
static NSString *const kContentArtwork = @"artwork_s";
static NSString *const kContentNameW = @"name_w";
static NSString *const kContentSeqBasic = @"seq_bas";
static NSString *const kContentSeqAdvanced = @"seq_adv";
static NSString *const kContentSeqExtreme = @"seq_ext";
static const double kReflectionFractionPad = 0.3; // @ghidraAddress 0x28f248
enum {
    kMbarBasicRow = 0,
    kMbarAdvancedRow = 1,
    kMbarExtremeRow = 2,
};

// The extend music-bar archive stores each difficulty's sequence under these member names and skips
// a 16-byte trailer; the three deciphered bars fill the extendMbarDots rows.
static NSString *const kExtendSeqBasic = @"seq_bas";
static NSString *const kExtendSeqAdvanced = @"seq_adv";
static NSString *const kExtendSeqExtreme = @"seq_ext";
static const NSUInteger kExtendArchiveTail = 16;
enum {
    kExtendMbarBasicRow = 0,
    kExtendMbarAdvancedRow = 1,
    kExtendMbarExtremeRow = 2,
};

// The extend level image lives at difficulty-table row 4, column 4 of the level-number views.
enum {
    kExtendLevelNumIndex = 3,
    kExtendLevelRow = 4,
};

// The three scroll-settled delegate callbacks share this tail: it snaps the settled page,
// re-derives the hold flag from the current difficulty's hold mark (except on the edit page),
// refreshes the start button, records the page, and applies either the difficulty (snapping a stale
// extreme back to basic) on the detail page or the edit music bar on the edit page.
static inline void MusicDetailViewOrgSettleScrollPage(MusicDetailViewOrg *self) {
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
static inline char MusicDetailViewOrgLevelIndex(int level) {
    if (level < 2) {
        return 0;
    }
    if (level < 10) {
        return (char)(level - 1);
    }
    return 9;
}

@implementation MusicDetailViewOrg

/** @ghidraAddress 0x502bc */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

/** @ghidraAddress 0x5e62c */
- (void)dealloc {
    // Empty in the binary too: the only instruction is the super call, and the class has a
    // .cxx_destruct, so that call is what ARC emits.
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

/** @ghidraAddress 0x55bbc */
- (void)setExtendInfo:(nullable TuneInfo *)info score:(nullable id)score {
    [super setExtendInfo:info score:score];
    [self loadExtendMusicBar:info.filePath];

    // Every hold and extend mark starts hidden across the three difficulties.
    for (int i = 0; i < kDiffButtonCount; ++i) {
        [holdMark[i] setHidden:YES];
        [extendMark[i] setHidden:YES];
        [extendOnMark[i] setHidden:YES];
    }

    self.extendLevelBas = MusicDetailViewOrgLevelIndex(info.lvBas);
    self.extendLevelAdv = MusicDetailViewOrgLevelIndex(info.lvAdv);
    self.extendLevelExt = MusicDetailViewOrgLevelIndex(info.lvExt);

    // Each difficulty that carries an extend chart (a set bit of extendFlag) reveals its extend and
    // extend-on marks, showing whichever matches the current extend mode.
    if (info != nil) {
        BOOL extendOn = JubeatAppDelegate.appDelegate.isExtend;
        for (int i = 0; i < kDiffButtonCount; ++i) {
            if ((info.extendFlag >> i) & 1) {
                [extendMark[i] setHidden:extendOn];
                [extendOnMark[i] setHidden:!extendOn];
            }
        }
    }
    if (score != nil) {
        [self putExtendScore:score];
    }
}

/** @ghidraAddress 0x5aefc */
- (void)uploadStart {
    [[AudioManager sharedManager] playSeResFile:kMusicSelectSound inDirectory:nil];

    // The dimming cover fills the card, translucent black, and starts transparent.
    topcover = [[UIView alloc] initWithFrame:self.bounds];
    [topcover setCenter:CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5)];
    [topcover setOpaque:NO];
    [topcover setBackgroundColor:[UIColor colorWithWhite:0 alpha:kUploadCoverScrimAlpha]];

    // The upload sheet is built from the current custom chart data and centred over the card.
    NSData *customData = [[EditDataManager sharedManager] getCurrentCustomData];
    upLoadView = [[JcfUpLoadView alloc] initWithData:customData delegate:self ctrl:self.controller];
    [upLoadView setCenter:CGPointMake(self.frame.size.width * 0.5, self.frame.size.height * 0.5)];
    [topcover setAlpha:0.0];
    [upLoadView setAlpha:0.0];
    [self addSubview:topcover];
    [self addSubview:upLoadView];

    __weak UIView *weakCover = topcover;
    __weak JcfUpLoadView *weakUpload = upLoadView;
    [UIView animateWithDuration:kUploadFadeDuration
                     animations:^{
                       /** @ghidraAddress 0x5b2d0 */
                       [weakCover setAlpha:1.0];
                       [weakUpload setAlpha:1.0];
                     }
                     completion:nil];
    [self.controller unenableCoverTap];
}

/** @ghidraAddress 0x5b498 */
- (void)editStart {
    [[AudioManager sharedManager] playSeResFile:kEditSelectSound inDirectory:nil];
    [self.controller showButtonMarker:NO];
    [self.buttonStartPlay setEnabled:NO];

    __weak MusicDetailViewOrg *weakSelf = self;
    [UIView animateWithDuration:kEditTransitionDuration
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          /** @ghidraAddress 0x5b6c8 */
          CATransform3D shrink =
              CATransform3DMakeScale(kEditButtonShrinkScale, kEditButtonShrinkScale, 1.0);
          for (int i = 0; i < kDiffButtonCount; ++i) {
              [self->btnDiff[i] setAlpha:0.0];
              self->btnDiff[i].layer.transform = shrink;
          }
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x5b864 */
          [weakSelf.controller startEdit:weakSelf.info];
        }];

    // Input is ignored through the transition and re-enabled a beat after it ends.
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:kEditInputLockDuration];
}

/** @ghidraAddress 0x54ad8 */
- (void)loadExtendMusicBar:(nullable NSString *)path {
    BFCodec *codec = [[BFCodec alloc] init];
    NSData *cipherKey = GetBgmCipherKey();
    [codec cipherInit:cipherKey];
    if (path == nil) {
        return;
    }
    KUnzip *archive = [[KUnzip alloc] initWithPath:path tail:kExtendArchiveTail];
    if (archive == nil) {
        return;
    }

    [codec cipherInit:cipherKey];
    NSMutableData *seqBas = [archive uncompress:kExtendSeqBasic];
    [codec decipher:seqBas];
    [Sequence getMusicBarData:extendMbarDots[kExtendMbarBasicRow] raw:seqBas];

    [codec cipherInit:cipherKey];
    NSMutableData *seqAdv = [archive uncompress:kExtendSeqAdvanced];
    [codec decipher:seqAdv];
    [Sequence getMusicBarData:extendMbarDots[kExtendMbarAdvancedRow] raw:seqAdv];

    [codec cipherInit:cipherKey];
    NSMutableData *seqExt = [archive uncompress:kExtendSeqExtreme];
    [codec decipher:seqExt];
    [Sequence getMusicBarData:extendMbarDots[kExtendMbarExtremeRow] raw:seqExt];

    // A settled detail page re-applies the preferred difficulty once the bars are loaded.
    if ([NSUserDefaults.standardUserDefaults integerForKey:kPrefEditSelectKey] == 0) {
        int difficulty =
            (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
        [self changeDifficulty:difficulty];
    }
}

/** @ghidraAddress 0x5415c */
- (void)loadContentFromDictionary:(nullable NSDictionary *)dict {
    UIImage *artwork = [UIImage imageWithData:dict[kContentArtwork]];
    if (artwork != nil) {
        [self.artworkView setImage:artwork];
        double fraction = self.isPad ? kReflectionFractionPad : g_dAnimDuration020;
        int reflectionHeight = (int)(artwork.size.height * fraction);
        [self.reflectionArtworkView setImage:CreateReflectedImage(artwork, reflectionHeight)];
    }
    UIImage *nameImage = [UIImage imageWithData:dict[kContentNameW]];
    if (nameImage != nil) {
        [self.tuneNameView setImage:nameImage];
    }
    if (dict[kContentSeqBasic] != nil) {
        [Sequence getMusicBarData:mbarDots[kMbarBasicRow] raw:dict[kContentSeqBasic]];
    }
    if (dict[kContentSeqAdvanced] != nil) {
        [Sequence getMusicBarData:mbarDots[kMbarAdvancedRow] raw:dict[kContentSeqAdvanced]];
    }
    if (dict[kContentSeqExtreme] != nil) {
        [Sequence getMusicBarData:mbarDots[kMbarExtremeRow] raw:dict[kContentSeqExtreme]];
    }
    // On the detail page (edit page 0) the classic theme re-applies the preferred difficulty once
    // the bars are loaded.
    if ([NSUserDefaults.standardUserDefaults integerForKey:kPrefEditSelectKey] == 0) {
        int difficulty =
            (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
        [self changeDifficulty:difficulty];
    }
}

/** @ghidraAddress 0x5c05c */
- (void)refreshStartButton {
    BOOL randomOn = JubeatAppDelegate.appDelegate.isRandom && !JubeatAppDelegate.appDelegate.isHold;
    if (randomOn == bRandomBak) {
        return;
    }
    bRandomBak = randomOn;

    // The start button shows the single-play image, or the start image when host-sharing; its
    // enabled state is preserved across the image swap.
    UIImage *image = self.isShared ? [self getStartImage] : [self getSingleImage];
    BOOL wasEnabled = self.buttonStartPlay.isEnabled;
    [self.buttonStartPlay setEnabled:YES];
    [self.buttonStartPlay setBackgroundImage:image forState:UIControlStateNormal];
    [self.buttonStartPlay setEnabled:wasEnabled];

    // The random marker rests in place when random is on and slides up out of view when off.
    if (randomOn) {
        [self.randView
            setTransform:CGAffineTransformMakeTranslation(0.0, -(double)kRandViewSlideOffset)];
    } else {
        [self.randView setTransform:CGAffineTransformIdentity];
    }

    __weak MusicDetailViewOrg *weakSelf = self;
    [UIView animateWithDuration:kRandViewToggleDuration
                     animations:^{
                       /** @ghidraAddress 0x5c3c0 */
                       [weakSelf.randView setAlpha:(randomOn ? 1.0 : 0.0)];
                       if (randomOn) {
                           [weakSelf.randView setTransform:CGAffineTransformIdentity];
                       } else {
                           [weakSelf.randView setTransform:CGAffineTransformMakeTranslation(
                                                               0.0, -(double)kRandViewSlideOffset)];
                       }
                     }
                     completion:nil];
}

/** @ghidraAddress 0x59668 */
- (void)hostShareCancelled {
    [self.buttonHostSharePlay
        setBackgroundImage:[[ImageCache sharedCache] getResPNG:kHostButtonImage]
                  forState:UIControlStateNormal];
    [self setStartButtonEnable];
    [self.buttonStartPlay setBackgroundImage:[self getSingleImage] forState:UIControlStateNormal];
    [self.buttonLink setEnabled:YES];
    [self.btnRecommendTwitter setEnabled:YES];
    [self.btnRecommendFacebook setEnabled:YES];

    __weak MusicDetailViewOrg *weakSelf = self;
    [UIView animateWithDuration:kHostShareCancelFadeDuration
        animations:^{
          /** @ghidraAddress 0x5990c */
          [weakSelf.labelShareMessage setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x59978 */
          [weakSelf.labelShareMessage setHidden:YES];
        }];
}

/** @ghidraAddress 0x5ea20 */
- (void)uploadEnd:(nullable id)sender {
    __weak UIView *weakCover = topcover;
    __weak JcfUpLoadView *weakUpload = upLoadView;
    // The binary passes a negative fade duration here; kept as-is.
    [UIView animateWithDuration:kUploadEndFadeDuration
        animations:^{
          /** @ghidraAddress 0x5ebc4 */
          [weakCover setAlpha:0.0];
          [weakUpload setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x5ec8c */
          [self removeUploadView];
        }];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x5786c */
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

/** @ghidraAddress 0x5c5dc */
- (void)scrollViewDidEndScrollingAnimation:(nullable UIScrollView *)scrollView {
    [detailScrollButton[0] setAlpha:1.0];
    [detailScrollButton[1] setAlpha:1.0];
    MusicDetailViewOrgSettleScrollPage(self);
}

/** @ghidraAddress 0x5c8c8 */
- (void)scrollViewDidEndDecelerating:(nullable UIScrollView *)scrollView {
    MusicDetailViewOrgSettleScrollPage(self);
}

/** @ghidraAddress 0x5cb8c */
- (void)scrollViewDidEndDragging:(nullable UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        MusicDetailViewOrgSettleScrollPage(self);
    }
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
