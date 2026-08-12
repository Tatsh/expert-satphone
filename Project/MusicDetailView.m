#import "MusicDetailView.h"

#import <Social/Social.h>

#import "BFCodec.h"
#import "EditDataManager.h"
#import "EditFileListViewDeleteController.h"
#import "EditModalView.h"
#import "ImageCache.h"
#import "ImageLoading.h"
#import "JcfDownloadPageNavController.h"
#import "JcfManageNavController.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "LabUtilities.h"
#import "MusicSelectViewController.h"
#import "ScoreRecord.h"
#import "SearchPackIDView.h"
#import "TuneInfo.h"

// The random-select marker offset is nudged down ten points on the phone idiom only; the pad idiom
// leaves both recommend buttons flush with the marker's origin.
static const int kRecommendButtonPhoneInset = 10;

// The card's dimming scrim opacity: colorWithWhite:0 alpha:0.5 for the always-on cover, and
// colorWithWhite:0 alpha:0.3 for the recommend topcover.
static const CGFloat kCoverScrimAlpha = 0.5;    // 0x3fe0000000000000
static const CGFloat kTopcoverScrimAlpha = 0.3; // 0x10028f248

// The reflection and random-marker views draw at half opacity.
static const CGFloat kReflectionAlpha = 0.5; // 0x3fe0000000000000

// The long-press that toggles the random flag fires after two seconds.
static const NSTimeInterval kRandomPressDuration = 2.0; // fmov d0, 2.0

// The recommend sheet and pack-search fade run for a fifth of a second.
static const NSTimeInterval kRecommendFadeDuration = 0.2; // 0x10028e040

// A stored music bar is trimmed to its first 30 bytes; anything shorter is left untouched.
static const NSUInteger kMusicBarLength = 30;

// The number of taps that triggers the artwork's random-select gesture.
static const NSUInteger kRandomTapCount = 2;

// The recommend button tags: Twitter is tag 0, Facebook is tag 1.
enum {
    kRecommendTagTwitter = 0,
    kRecommendTagFacebook = 1,
};

// Resource names loaded from the image cache during construction.
static NSString *const kResITunesLink = @"store_itunes";
static NSString *const kResRandMarker = @"msel_mark_rand";
static NSString *const kResTwitterIcon = @"icon_rec_twitter";
static NSString *const kResFacebookIcon = @"icon_rec_facebook";

// The packed-asset member names uncompressed out of the tune file for the share dictionary.
static NSString *const kPackedArtwork = @"artwork_s";
static NSString *const kPackedNameW = @"name_w";
static NSString *const kPackedNameB = @"name_b";
static NSString *const kPackedSeqBas = @"seq_bas";
static NSString *const kPackedSeqAdv = @"seq_adv";
static NSString *const kPackedSeqExt = @"seq_ext";
static NSString *const kPackedIndex = @"index";

// The tune file's encrypted trailer skipped when opening it for share extraction.
static const NSUInteger kShareArchiveTail = 16;

// The editor-info key inspected to decide whether an upload is allowed.
static NSString *const kEditorNotesNumKey = @"notesNum";

@interface MusicDetailView ()
@end

@implementation MusicDetailView

// -infoChange: is abstract on the base: the binary defines it only on the concrete theme
// subclasses (Org/Rpl/Knt) and never on MusicDetailView itself, but the base declares it so the
// music-select screen can drive it polymorphically. The base body only traps a direct call.
- (void)infoChange:(int)difficulty {
    [self doesNotRecognizeSelector:_cmd];
}

#pragma mark - Construction

/** @ghidraAddress 0x126714 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        JubeatAppDelegate *appDelegate = [JubeatAppDelegate appDelegate];
        self.isPad = appDelegate.isPad;
        self.isRetina = [JubeatAppDelegate appDelegate].isPhoneRetina;

        self.coverView = [[UIView alloc] initWithFrame:self.bounds];
        self.coverView.opaque = NO;
        // The original used colorWithWhite:0 alpha:0.5.
        self.coverView.backgroundColor = [UIColor colorWithWhite:0 alpha:kCoverScrimAlpha];
        self.coverView.userInteractionEnabled = NO;
        self.coverView.hidden = YES;

        self.artworkView = [[UIImageView alloc] init];
        self.artworkView.contentMode = UIViewContentModeScaleAspectFit;
        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dtpGesture:)];
        tap.numberOfTapsRequired = kRandomTapCount;
        self.artworkView.userInteractionEnabled = YES;
        [self.artworkView addGestureRecognizer:tap];
        UILongPressGestureRecognizer *press =
            [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(lpGesture:)];
        press.minimumPressDuration = kRandomPressDuration;
        [self.artworkView addGestureRecognizer:press];
        [self addSubview:self.artworkView];

        self.reflectionArtworkView = [[UIImageView alloc] init];
        self.reflectionArtworkView.contentMode = UIViewContentModeScaleAspectFit;
        self.reflectionArtworkView.alpha = kReflectionAlpha;
        [self addSubview:self.reflectionArtworkView];

        self.tuneNameView = [[UIImageView alloc] init];
        self.tuneNameView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:self.tuneNameView];

        self.buttonLink = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *linkImage = [[ImageCache sharedCache] getResPNG:kResITunesLink];
        self.buttonLink.frame = CGRectMake(0, 0, linkImage.size.width, linkImage.size.height);
        [self.buttonLink setBackgroundImage:linkImage forState:UIControlStateNormal];
        [self.buttonLink addTarget:self
                            action:@selector(pushLink:)
                  forControlEvents:UIControlEventTouchUpInside];
        self.buttonLink.exclusiveTouch = YES;
        [self addSubview:self.buttonLink];

        UIImage *randImage = LoadScaledPngImage(kResRandMarker);
        self.randView = [[UIImageView alloc] initWithImage:randImage];
        self.randView.frame = CGRectMake(0, 0, randImage.size.width, randImage.size.height);
        self.randView.alpha = kReflectionAlpha;
        [self addSubview:self.randView];

        // The recommend buttons are sized to their icon plus a ten-point margin on the phone; the
        // pad idiom uses no margin.
        int recommendInset = self.isPad ? 0 : kRecommendButtonPhoneInset;
        UIImage *twitterImage = [[ImageCache sharedCache] getResPNG:kResTwitterIcon];
        CGFloat recommendWidth = recommendInset + twitterImage.size.width;
        CGFloat recommendHeight = recommendInset + twitterImage.size.height;

        self.btnRecommendTwitter = [UIButton buttonWithType:UIButtonTypeCustom];
        self.btnRecommendTwitter.frame = CGRectMake(0, 0, recommendWidth, recommendHeight);
        [self.btnRecommendTwitter setImage:twitterImage forState:UIControlStateNormal];
        self.btnRecommendTwitter.imageEdgeInsets =
            UIEdgeInsetsMake(0, 0, -recommendInset, -recommendInset);
        [self.btnRecommendTwitter addTarget:self
                                     action:@selector(pushRecommend:)
                           forControlEvents:UIControlEventTouchUpInside];
        self.btnRecommendTwitter.exclusiveTouch = YES;
        self.btnRecommendTwitter.tag = kRecommendTagTwitter;
        [self addSubview:self.btnRecommendTwitter];

        self.btnRecommendFacebook = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *facebookImage = [[ImageCache sharedCache] getResPNG:kResFacebookIcon];
        self.btnRecommendFacebook.frame = CGRectMake(0, 0, recommendWidth, recommendHeight);
        [self.btnRecommendFacebook setImage:facebookImage forState:UIControlStateNormal];
        self.btnRecommendFacebook.imageEdgeInsets =
            UIEdgeInsetsMake(0, 0, -recommendInset, -recommendInset);
        [self.btnRecommendFacebook addTarget:self
                                      action:@selector(pushRecommend:)
                            forControlEvents:UIControlEventTouchUpInside];
        self.btnRecommendFacebook.exclusiveTouch = YES;
        self.btnRecommendFacebook.tag = kRecommendTagFacebook;
        [self addSubview:self.btnRecommendFacebook];

        self.buttonStartPlay = [UIButton buttonWithType:UIButtonTypeCustom];
        self.buttonStartPlay.exclusiveTouch = YES;
        [self addSubview:self.buttonStartPlay];

        self.buttonHostSharePlay = [UIButton buttonWithType:UIButtonTypeCustom];
        self.buttonHostSharePlay.exclusiveTouch = YES;
        [self addSubview:self.buttonHostSharePlay];

        self.labelShareMessage = [[UILabel alloc] init];
        self.labelShareMessage.opaque = NO;
        self.labelShareMessage.backgroundColor = UIColor.whiteColor;
        self.labelShareMessage.hidden = YES;
        self.labelShareMessage.textAlignment = NSTextAlignmentCenter;
        [self addSubview:self.labelShareMessage];

        self.shareDataProgress =
            [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
        self.shareDataProgress.hidden = YES;
        [self addSubview:self.shareDataProgress];

        self.isStarted = NO;
        self.isSharedStartable = NO;
    }
    return self;
}

#pragma mark - Info

/** @ghidraAddress 0x127790 */
- (void)setInfo:(TuneInfo *)info score:(id)score {
    // The score argument is accepted but discarded in this build.
    self.info = info;
}

/** @ghidraAddress 0x1277d0 */
- (void)setExtendInfo:(TuneInfo *)info score:(id)score {
    // The score argument is accepted but discarded in this build.
    self.extendInfo = info;
}

/** @ghidraAddress 0x127810 */
- (void)clearInfo {
}

/** @ghidraAddress 0x127814 */
- (void)loadContentFromDictionary:(NSDictionary *)dict {
}

/** @ghidraAddress 0x127818 */
- (void)loadContentFromPath:(NSString *)path orData:(NSData *)data {
}

/** @ghidraAddress 0x12781c */
- (void)show:(BOOL)show {
}

/** @ghidraAddress 0x127820 */
- (void)hostShareCancelled {
}

/** @ghidraAddress 0x127824 */
- (void)showDataProgress:(BOOL)show animated:(BOOL)animated {
}

/** @ghidraAddress 0x127828 */
- (void)activateAnim:(BOOL)activate {
}

#pragma mark - Link and recommend

/** @ghidraAddress 0x12782c */
- (void)pushLink:(id)sender {
    if (self.info.iTunesURL) {
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:self.info.iTunesURL]];
    }
}

/** @ghidraAddress 0x127958 */
- (void)pushRecommend:(id)sender {
    self.socialType = SLServiceTypeFacebook;
    if ([(UIView *)sender tag] == kRecommendTagTwitter) {
        self.socialType = SLServiceTypeTwitter;
    }
    [self.controller unenableCoverTap];

    self.topcover = [[UIView alloc] initWithFrame:self.bounds];
    self.topcover.center = CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5);
    self.topcover.opaque = NO;
    // The original used colorWithWhite:0 alpha:0.3.
    self.topcover.backgroundColor = [UIColor colorWithWhite:0 alpha:kTopcoverScrimAlpha];
    [self addSubview:self.topcover];

    self.searchPackView = [[SearchPackIDView alloc] initWithID:self.info
                                                          type:self.socialType
                                                      delegate:self];
    self.searchPackView.center =
        CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5);
    [self addSubview:self.searchPackView];

    __weak UIView *weakTopcover = self.topcover;
    __weak SearchPackIDView *weakSearch = self.searchPackView;
    weakSearch.alpha = 0;
    weakTopcover.alpha = 0;
    [UIView animateWithDuration:kRecommendFadeDuration
        animations:^{
          /** @ghidraAddress 0x127e8c */
          weakSearch.alpha = 1.0;
          weakTopcover.alpha = 1.0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x127f5c */
          [self.searchPackView startDownload];
        }];
}

/** @ghidraAddress 0x127fb0 */
- (void)packIDSearchEnd:(SearchPackIDView *)view {
    NSString *recommendString = [self getRecommendString];
    __weak SearchPackIDView *weakSearch = self.searchPackView;
    __weak UIView *weakTopcover = self.topcover;
    weakSearch.alpha = 1.0;
    weakTopcover.alpha = 1.0;
    [UIView animateWithDuration:kRecommendFadeDuration
        animations:^{
          /** @ghidraAddress 0x1281cc */
          weakSearch.alpha = 0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x128218 */
          [self socialSend:self.socialType sendText:recommendString];
          [self searchViewDealloc];
          [self.controller enableCoverTap];
        }];
}

/** @ghidraAddress 0x128308 */
- (void)packIDSearchCancel:(SearchPackIDView *)view {
    __weak SearchPackIDView *weakSearch = self.searchPackView;
    __weak UIView *weakTopcover = self.topcover;
    weakSearch.alpha = 1.0;
    weakTopcover.alpha = 1.0;
    [UIView animateWithDuration:kRecommendFadeDuration
        animations:^{
          /** @ghidraAddress 0x128508 */
          weakTopcover.alpha = 0;
          weakSearch.alpha = 0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x1285d0 */
          [self searchViewDealloc];
          [self.controller enableCoverTap];
        }];
}

/** @ghidraAddress 0x128638 */
- (NSString *)getRecommendString {
    if (self.searchPackView == nil) {
        return nil;
    }
    return [self.searchPackView getRecommendString];
}

/** @ghidraAddress 0x1286c4 */
- (void)searchViewDealloc {
    [self.searchPackView removeFromSuperview];
    [self.topcover removeFromSuperview];
    self.searchPackView = nil;
    self.topcover = nil;
}

#pragma mark - Social share

/** @ghidraAddress 0x128768 */
- (void)socialSend:(NSString *)service sendText:(NSString *)text {
    SLComposeViewController *composer =
        [SLComposeViewController composeViewControllerForServiceType:service];
    [composer setInitialText:(text ? text : @"")];
    // The shipped block reads its argument as a plain integer; typed here as the framework's
    // SLComposeViewControllerResult.
    composer.completionHandler = ^(SLComposeViewControllerResult __attribute__((unused)) result) {
      /** @ghidraAddress 0x1288cc */
      [self.controller dismissViewControllerAnimated:YES completion:nil];
    };
    [self.controller presentViewController:composer animated:YES completion:nil];
}

/** @ghidraAddress 0x128928 */
- (void)sendTwitter:(NSString *)text {
    [self socialSend:SLServiceTypeTwitter sendText:text];
}

#pragma mark - Score

/** @ghidraAddress 0x128948 */
- (void)resetScore {
    self.scoreExt = -1;
    self.scoreAdv = -1;
    self.scoreBas = -1;
    self.fullComboExt = NO;
    self.fullComboAdv = NO;
    self.fullComboBas = NO;
    self.mbarBas = nil;
    self.mbarAdv = nil;
    self.mbarExt = nil;
    self.extendScoreExt = -1;
    self.extendScoreAdv = -1;
    self.extendScoreBas = -1;
    self.extendFullComboExt = NO;
    self.extendFullComboAdv = NO;
    self.extendFullComboBas = NO;
    self.extendMbarBas = nil;
    self.extendMbarAdv = nil;
    self.extendMbarExt = nil;
}

/** @ghidraAddress 0x128ac4 */
- (void)putScore:(ScoreRecord *)score {
    if (![ScoreRecord checkScore:score]) {
        return;
    }
    self.scoreBas = score.scoBas.intValue;
    self.scoreAdv = score.scoAdv.intValue;
    self.scoreExt = score.scoExt.intValue;
    self.fullComboBas = score.fcBas.boolValue;
    self.fullComboAdv = score.fcAdv.boolValue;
    self.fullComboExt = score.fcExt.boolValue;
    if (!self.fullComboBas && score.pmBas.intValue == 0) {
        self.fullComboBas = YES;
    }
    if (!self.fullComboExt && score.pmExt.intValue == 0) {
        self.fullComboExt = YES;
    }
    if (!self.fullComboAdv && score.pmAdv.intValue == 0) {
        self.fullComboAdv = YES;
    }
    if (score.mbBas.length > kMusicBarLength - 1) {
        self.mbarBas = [score.mbBas subdataWithRange:NSMakeRange(0, kMusicBarLength)];
    }
    if (score.mbAdv.length > kMusicBarLength - 1) {
        self.mbarAdv = [score.mbAdv subdataWithRange:NSMakeRange(0, kMusicBarLength)];
    }
    if (score.mbExt.length > kMusicBarLength - 1) {
        self.mbarExt = [score.mbExt subdataWithRange:NSMakeRange(0, kMusicBarLength)];
    }
}

/** @ghidraAddress 0x128f98 */
- (void)putExtendScore:(ScoreRecord *)score {
    if (![ScoreRecord checkScore:score]) {
        return;
    }
    self.extendScoreBas = score.scoBas.intValue;
    self.extendScoreAdv = score.scoAdv.intValue;
    self.extendScoreExt = score.scoExt.intValue;
    self.extendFullComboBas = score.fcBas.boolValue;
    self.extendFullComboAdv = score.fcAdv.boolValue;
    self.extendFullComboExt = score.fcExt.boolValue;
    if (!self.extendFullComboBas && score.pmBas.intValue == 0) {
        self.extendFullComboBas = YES;
    }
    if (!self.extendFullComboAdv && score.pmAdv.intValue == 0) {
        self.extendFullComboAdv = YES;
    }
    if (!self.extendFullComboExt && score.pmExt.intValue == 0) {
        self.extendFullComboExt = YES;
    }
    if (score.mbBas.length > kMusicBarLength - 1) {
        self.extendMbarBas = [score.mbBas subdataWithRange:NSMakeRange(0, kMusicBarLength)];
    }
    if (score.mbAdv.length > kMusicBarLength - 1) {
        self.extendMbarAdv = [score.mbAdv subdataWithRange:NSMakeRange(0, kMusicBarLength)];
    }
    if (score.mbExt.length > kMusicBarLength - 1) {
        self.extendMbarExt = [score.mbExt subdataWithRange:NSMakeRange(0, kMusicBarLength)];
    }
}

#pragma mark - Close

/** @ghidraAddress 0x12946c */
- (void)closePopWindow {
    if (self.isEditInfoOpen) {
        [self.controller dismissViewControllerAnimated:YES completion:nil];
        self.isEditInfoOpen = NO;
    } else if (self.jcfDownloadPage) {
        [self.controller dismissViewControllerAnimated:YES completion:nil];
    }
    [self.controller dismissViewControllerAnimated:NO completion:nil];
}

/** @ghidraAddress 0x129580 */
- (void)close {
    [self.controller closeDetailView];
}

#pragma mark - Share dictionary

/** @ghidraAddress 0x1295c0 */
- (NSDictionary *)infoDictForShare {
    KUnzip *archive = [[KUnzip alloc] initWithPath:self.info.filePath tail:kShareArchiveTail];
    if (archive == nil) {
        return self.info.infoDict;
    }
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:self.info.infoDict];
    BFCodec *codec = [[BFCodec alloc] init];
    NSData *cipherKey = GetBgmCipherKey();

    [codec cipherInit:cipherKey];
    NSMutableData *artwork = [archive uncompress:kPackedArtwork];
    [codec decipher:artwork];
    if (artwork) {
        dict[kPackedArtwork] = artwork;
    }

    [codec cipherInit:cipherKey];
    NSMutableData *nameW = [archive uncompress:kPackedNameW];
    [codec decipher:nameW];
    if (nameW) {
        dict[kPackedNameW] = nameW;
    }

    [codec cipherInit:cipherKey];
    NSMutableData *nameB = [archive uncompress:kPackedNameB];
    [codec decipher:nameB];
    if (nameB) {
        dict[kPackedNameB] = nameB;
    }

    [codec cipherInit:cipherKey];
    NSMutableData *seqBas = [archive uncompress:kPackedSeqBas];
    [codec decipher:seqBas];
    if (seqBas) {
        dict[kPackedSeqBas] = seqBas;
    }

    [codec cipherInit:cipherKey];
    NSMutableData *seqAdv = [archive uncompress:kPackedSeqAdv];
    [codec decipher:seqAdv];
    if (seqAdv) {
        dict[kPackedSeqAdv] = seqAdv;
    }

    [codec cipherInit:cipherKey];
    NSMutableData *seqExt = [archive uncompress:kPackedSeqExt];
    [codec decipher:seqExt];
    if (seqExt) {
        dict[kPackedSeqExt] = seqExt;
    }

    [codec cipherInit:cipherKey];
    NSMutableData *index = [archive uncompress:kPackedIndex];
    [codec decipher:index];
    if (index) {
        dict[kPackedIndex] = index;
    }

    return [NSDictionary dictionaryWithDictionary:dict];
}

#pragma mark - Edit flow

/** @ghidraAddress 0x129a84 */
- (void)loadEditFile {
    EditDataManager *manager = [EditDataManager sharedManager];
    NSString *path = [manager getLastEditFilePath:self.info.tuneID];
    if (path == nil) {
        [manager clearEditData];
    } else {
        [manager loadJCF:path];
    }
}

/** @ghidraAddress 0x129b50 */
- (void)saveEditFile {
    EditDataManager *manager = [EditDataManager sharedManager];
    NSString *path = [manager getLastEditFilePath:self.info.tuneID];
    if (path != nil) {
        [manager saveJCF:path];
    }
}

/** @ghidraAddress 0x129c08 */
- (void)editModalViewDelegateSaveEditFile {
    [self saveEditFile];
}

/** @ghidraAddress 0x129c14 */
- (BOOL)checkEnableInfoChange {
    if ([self.controller sharePlayManager] != nil) {
        return NO;
    }
    NSString *fileName = [[EditDataManager sharedManager] getLastEditFileName:self.info.tuneID];
    if (fileName == nil) {
        return NO;
    }
    if ([EditDataManager sharedManager].bIsDownload) {
        return NO;
    }
    return self.isPad;
}

/** @ghidraAddress 0x129d68 */
- (BOOL)checkEnableUpload {
    if ([self.controller sharePlayManager] != nil) {
        return NO;
    }
    NSString *fileName = [[EditDataManager sharedManager] getLastEditFileName:self.info.tuneID];
    if (fileName == nil) {
        return NO;
    }
    EditDataManager *manager = [EditDataManager sharedManager];
    if (manager.bIsDownload || !self.isPad) {
        return NO;
    }
    return [manager.getEditorInfo[kEditorNotesNumKey] intValue] != 0;
}

/** @ghidraAddress 0x129f20 */
- (BOOL)checkEnableEdit {
    if ([self.controller sharePlayManager] != nil) {
        return NO;
    }
    NSString *fileName = [[EditDataManager sharedManager] getLastEditFileName:self.info.tuneID];
    if (fileName == nil) {
        return NO;
    }
    if ([EditDataManager sharedManager].bIsDownload) {
        return NO;
    }
    return self.isPad;
}

#pragma mark - Download and store

/** @ghidraAddress 0x12a074 */
- (void)downloadEnd:(id)sender {
    if (self.isPad) {
        return;
    }
    if (self.jcfMan == nil) {
        return;
    }
    NSArray *fileList = [[EditDataManager sharedManager] getFileInfoList:self.info.tuneID];
    [self.jcfMan reloadList:fileList];
}

/** @ghidraAddress 0x12a198 */
- (void)moveStore:(id)store packID:(NSString *)packID {
    [self.controller dismissViewControllerAnimated:YES completion:nil];
    [self.controller turnToPackPurchase:packID];
}

#pragma mark - Start button and gestures

/** @ghidraAddress 0x12a238 */
- (void)setStartButtonEnable {
}

/** @ghidraAddress 0x12a23c */
- (void)dtpGesture:(UITapGestureRecognizer *)gesture {
    [self.controller setRandomSelect];
}

/** @ghidraAddress 0x12a27c */
- (void)refreshStartButton {
}

/** @ghidraAddress 0x12a280 */
- (void)lpGesture:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        JubeatAppDelegate *appDelegate = [JubeatAppDelegate appDelegate];
        [appDelegate setRandomFlag:!appDelegate.isRandom];
        [self refreshStartButton];
    }
}

/** @ghidraAddress 0x12a314 */
- (void)changeExtendMode {
}

/** @ghidraAddress 0x12a318 */
- (CGPoint)getDifficultyPos:(int)difficulty {
    return CGPointZero;
}

/** @ghidraAddress 0x12a328 */
- (void)refreshInfo {
}

@end
