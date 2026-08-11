#import "ScratchMusicDetailView.h"

#import <QuartzCore/QuartzCore.h>

#import "AudioManager.h"
#import "BFCodec.h"
#import "ChallengeRankingListView.h"
#import "ChallengeStatus.h"
#import "ImageCache.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "LabUtilities.h"
#import "NSDictionary+PropertyList.h"
#import "ScratchInfo.h"
#import "ScratchUtil.h"
#import "Sequence.h"
#import "StoreMusicListManager.h"
#import "TuneInfo.h"
#import "cipher_keys.h"

// The number of difficulties (basic, advanced, extreme) and their indices.
enum {
    kDiffBasic = 0,
    kDiffAdvanced = 1,
    kDiffExtreme = 2,
    kDiffCount = 3,
};

// The number of ranking-number digit views, high-score digit views, level digit views, and the
// per-numeral digit-atlas sizes.
static const int kRankingDigitCount = 6;
static const int kHighscoreDigitCount = 7;
static const int kDigitAtlasCount = 10;

// The number of music-bar dots and the packed layouts feeding them.
static const int kMusicBarDotCount = 120;
static const int kMusicBarDotColourCount = 4;
static const int kMusicBarDotShapeCount = 8;
static const int kMusicBarBytesPerDiff = 60; // char[kDiffCount][60]
static const int kMusicBarResBytes = 30;     // 2-bit-packed colour resource

// The excellent threshold: a score of one million or more shows the excellent mark.
static const int kExcellentScore = 1000000;

// The high-score is rendered right-aligned into seven digits via "%7d".
static const int kHighscoreFieldWidth = 7;

// The persisted-difficulty default preference key and the edit-select key.
static NSString *const kPrefDifficultyKey = @"PrefDifficulty";
static NSString *const kPrefEditSelectKey = @"PrefEditSelect";

// The resource names loaded during construction.
static NSString *const kResBackground = @"music_detail_bg_ch";
static NSString *const kResRankingListButton = @"ranking_list_btn";
static NSString *const kResHighscoreBoard = @"msc_hsboard_knt";
static NSString *const kResHighscoreText = @"msc_hstext_ch";
static NSString *const kResStoreButton = @"menu_button_store_ch";
static NSString *const kResStartButton = @"menu_button_start_ch";

// The digit and dot atlas name formats.
static NSString *const kFmtRankingNum = @"ranking_num_0%d";
static NSString *const kFmtHighscoreNum = @"msc_high_score_%d_ch";
static NSString *const kFmtLevelNum = @"lv_%02d_ch";
// The music-bar dot atlas: the "0" is a literal in the shipped name — the colour row index is not
// interpolated, so all four colour rows load the same eight shape images.
static NSString *const kFmtMusicBarDot = @"mini_dot_0_%d_ch";
static NSString *const kFmtDifficultyButton = @"msel_btn_%s_ch";
static NSString *const kFmtHoldMark = @"hold_ico_%c_ch";

// The uncompressed archive member names.
static NSString *const kArchiveArtwork = @"artwork";
static NSString *const kArchiveNameB = @"name_b";
static NSString *const kArchiveSeqBas = @"seq_bas";
static NSString *const kArchiveSeqAdv = @"seq_adv";
static NSString *const kArchiveSeqExt = @"seq_ext";
static NSString *const kArchiveInfoV3 = @"infov3";
static NSString *const kArchiveInfoV2 = @"infov2";
static NSString *const kArchiveInfo = @"info";

// The dictionary content member names.
static NSString *const kContentArtwork = @"artwork_s";
static NSString *const kContentNameB = @"name_b";
static NSString *const kContentSeqBas = @"seq_bas";
static NSString *const kContentSeqAdv = @"seq_adv";
static NSString *const kContentSeqExt = @"seq_ext";

// The sound-effect names.
static NSString *const kSeStoreMenu = @"SD_LABO_MENU";
static NSString *const kSeRankingMenu = @"SD_LABO_MENU";
static NSString *const kSeStartOK = @"SD_KNT_OK";
static NSString *const kSeDiffBasic = @"BASIC";
static NSString *const kSeDiffAdvanced = @"ADVANCED";
static NSString *const kSeDiffExtreme = @"EXTREME";
static NSString *const kStoreButtonSearch = @"scratch_btn_Search";

// The theme identifiers driving the sound-name prefix in -soundName:.
enum {
    kThemeRPL = 1,
    kThemeKNT = 2,
};

// The tune-archive encrypted trailer skipped when opening it.
static const NSUInteger kArchiveTail = 0x10;

// The music-bar data is trimmed to its first 30 bytes; anything shorter is left untouched.
static const int kMusicBarLength = 30;

// The reflection height ratio: the reflected copy is this fraction of the artwork's width.
static const CGFloat kReflectionRatioPad = 0.3f;         // @ghidraAddress 0x28e0b0
static const CGFloat kReflectionRatioPhone = 0.2f;       // @ghidraAddress 0x28f3c8
static const CGFloat kReflectionBaseWidthPad = 200.0f;   // @ghidraAddress 0x292b24
static const CGFloat kReflectionBaseWidthPhone = 110.0f; // @ghidraAddress 0x293330

// The artwork square: 10 points on the pad, 8 on the phone; 200 wide/tall on the pad, 110 on the
// phone.
static const CGFloat kArtworkSizePad = 200.0;   // @ghidraAddress 0x28f400
static const CGFloat kArtworkSizePhone = 110.0; // @ghidraAddress 0x28f5e8

// The difficulty-select confirm animation and its post-delay interaction re-enable.
static const NSTimeInterval kDiffAnimDuration = 0.3;     // @ghidraAddress 0x28f260
static const NSTimeInterval kDiffInteractionDelay = 0.4; // @ghidraAddress 0x28f268

// The dimmed alpha of the two non-selected difficulty buttons, and the shrunk scale.
static const CGFloat kDiffDimAlpha = 0.4;     // @ghidraAddress 0x28f2c0
static const CGFloat kDiffShrinkScale = 0.95; // @ghidraAddress 0x28f6e0

// The high-score text view's resting centre: (65, -7) on the pad, (33, -6) on the phone. The Y is
// genuinely negative — the caller animates only the X in from a 40-point offset.
static const CGFloat kHighscoreTextCentreXPad = 65.0;   // @ghidraAddress 0x291bc0
static const CGFloat kHighscoreTextCentreXPhone = 33.0; // @ghidraAddress 0x293328
static const CGFloat kHighscoreTextSlideOffset = 40.0;  // @ghidraAddress 0x28f1f8

@interface ScratchMusicDetailView () <ChallengeRankingListViewDelegate> {
    UIImageView *bgImageView;
    UIImageView *highscoreBoardView;
    UIImageView *highscoreTextView;
    UIImageView *ratingView;
    UIImageView *comboView;
    UIImageView *mbarBarView;
    UIImageView *extendFrame;
    UIImageView *extendDecription; // The binary's own misspelling of "Description".
    UIButton *btnDiff[kDiffCount];
    UIImageView *levelNumView[4];
    UIImage *levelNumImg[kDigitAtlasCount];
    UIImage *highscoreNumImg[kDigitAtlasCount];
    UIImage *rankingNumImg[kDigitAtlasCount];
    UIImageView *highscoreNumView[kHighscoreDigitCount];
    UIImage *ratingImg[9];
    UIImage *fullcomboImg;
    UIImage *excellentImg;
    UIImageView *mbarDotView[kMusicBarDotCount];
    UIImage *mbarBarImg[kMusicBarDotColourCount];
    UIImage *mbarDotImg[kMusicBarDotColourCount][kMusicBarDotShapeCount];
    char mbarDots[kDiffCount][kMusicBarBytesPerDiff];
    UIImageView *rankingNumView[kRankingDigitCount];
    UIImageView *holdMark[kDiffCount];
    int score[kDiffCount];
    BOOL bFullCombo[kDiffCount];
    int myRank[kDiffCount];
    int itemSlot;
    int _difficulty;
    ScratchInfo *minfo;
    UIButton *rankingBtn;
    UIButton *jbtStoreBtn;
    ChallengeRankingListView *rankingListView;
    NSInteger packID;
    unsigned int currentHoldFlg;
    unsigned int _musicID;
    UIView *consumeCoinView;
    UILabel *consumeTitleLabel;
    UILabel *baseConsumeCoin;
    UILabel *consumeCoin;
    __weak id<ScratchMusicDetailViewDelegate> _aDelegate;
    TuneInfo *_tuneInfo;
}
@end

// Maps a raw chart level to its digit-atlas index: below 2 shows the "0" glyph, 2..9 map to
// level-1, and 10 or above clamps to the last glyph.
static inline char ScratchMusicDetailViewLevelIndex(int level) {
    if (level < 2) {
        return 0;
    }
    if (level < 10) {
        return (char)(level - 1);
    }
    return 9;
}

@implementation ScratchMusicDetailView

@synthesize aDelegate = _aDelegate;
@synthesize musicID = _musicID;
@synthesize difficulty = _difficulty;
@synthesize tuneInfo = _tuneInfo;

#pragma mark - Layer

/** @ghidraAddress 0x15f644 */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

#pragma mark - Construction

/** @ghidraAddress 0x15f658 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }
    BOOL isPad = self.isPad;

    // The tiled background image, inserted behind every other subview.
    UIImage *bgImage = LoadScaledPngImage(kResBackground);
    bgImageView = [[UIImageView alloc] initWithImage:bgImage];
    // The origin is nudged (-2, -2) on the pad only so the tiled edge is not clipped.
    CGFloat bgOffset = isPad ? -2.0 : 0.0;
    bgImageView.frame = CGRectMake(bgOffset, bgOffset, bgImage.size.width, bgImage.size.height);
    [self insertSubview:bgImageView atIndex:0];

    // The artwork square (base class view). 10/8-point inset, 200/110-point square.
    CGFloat artInset = isPad ? 10.0 : 8.0;
    CGFloat artSize = isPad ? kArtworkSizePad : kArtworkSizePhone;
    self.artworkView.frame = CGRectMake(artInset, artInset, artSize, artSize);

    // The reflection sits just below the artwork; its height is the artwork width times the
    // idiom's reflection ratio.
    CGFloat reflectionWidth = isPad ? kReflectionBaseWidthPad : kReflectionBaseWidthPhone;
    CGFloat reflectionRatio = isPad ? kReflectionRatioPad : kReflectionRatioPhone;
    CGFloat reflectionY = (CGFloat)((float)((int)artInset + (int)artSize) + 0.5f);
    self.reflectionArtworkView.frame =
        CGRectMake(artInset, reflectionY, artSize, (CGFloat)(reflectionWidth * reflectionRatio));

    // The tune-name plate (base class view).
    self.tuneNameView.frame = CGRectMake(isPad ? 220.0 : 128.0, // x = (210/120) + (10/8)
                                         isPad ? 10.0 : 8.0,
                                         isPad ? 340.0 : 170.0,
                                         isPad ? 64.0 : 32.0);

    // The ten ranking-number digit images.
    for (int i = 0; i < kDigitAtlasCount; ++i) {
        rankingNumImg[i] = LoadScaledPngImage([NSString stringWithFormat:kFmtRankingNum, i]);
    }

    // The six ranking-number digit views, laid out left to right from the digit width.
    CGFloat rankNumX = isPad ? 360.0 : 204.0;
    CGFloat rankNumY = isPad ? 156.0 : 74.0;
    for (int i = 0; i < kRankingDigitCount; ++i) {
        CGSize digitSize = rankingNumImg[0].size;
        rankingNumView[i] = [[UIImageView alloc]
            initWithFrame:CGRectMake(rankNumX, rankNumY, digitSize.width, digitSize.height)];
        [self addSubview:rankingNumView[i]];
        rankNumX = (CGFloat)(int)(rankNumX + digitSize.width);
    }

    // The ranking button, sized to its image and placed at the right of the digit row.
    UIImage *rankBtnImage = [[ImageCache sharedCache] getResPNG:kResRankingListButton];
    rankingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    CGFloat rankDigitWidth = rankingNumImg[0].size.width;
    CGFloat rankPadGap = isPad ? 4.0 : 2.0;
    CGFloat rankBtnY = ((rankPadGap + rankNumY) + rankDigitWidth - rankBtnImage.size.width) - 5.0;
    rankingBtn.frame = CGRectMake((CGFloat)((int)rankNumX - 5),
                                  rankBtnY,
                                  rankBtnImage.size.width + 10.0,
                                  rankBtnImage.size.height + 10.0);
    [rankingBtn addTarget:self
                   action:@selector(tapRanking:)
         forControlEvents:UIControlEventTouchUpInside];
    [rankingBtn setImage:rankBtnImage forState:UIControlStateNormal];
    [self addSubview:rankingBtn];

    // The three difficulty buttons and their four level-number views, arranged in a shrinking
    // column. The centre coordinates come from the card's own width and the idiom's margins.
    CGFloat cardWidth = self.frame.size.width;
    CGFloat diffColX0 = isPad ? 50.0 : 60.0; // 0x28f2c8 / 0x28f258
    CGFloat diffColY = isPad ? 418.0 : 60.0; // 0x293308 / 0x28f430
    CGFloat diffCentres[kDiffCount][2] = {
        {diffColX0, diffColY},
        {cardWidth * 0.5, diffColY},
        {cardWidth - (isPad ? 60.0 : 50.0), diffColY},
    };
    static const char *const diffSuffixes[kDiffCount] = {"b", "a", "e"};
    CGFloat levelViewX = isPad ? 50.0 : 94.0;    // 0x28f2c8 / 0x28f420
    CGFloat levelViewY = isPad ? 90.0 : 48.0;    // 0x28f440 / 0x28f450
    CGFloat levelViewSize = isPad ? 32.0 : 18.0; // 0x28f458 / fmov 18.0
    for (int i = 0; i < kDiffCount; ++i) {
        btnDiff[i] =
            [self diffButton:[NSString stringWithFormat:kFmtDifficultyButton, diffSuffixes[i]]];
        levelNumView[i] = [[UIImageView alloc]
            initWithFrame:CGRectMake(levelViewX, levelViewY, levelViewSize, levelViewSize)];
        [btnDiff[i] addSubview:levelNumView[i]];
        btnDiff[i].center = CGPointMake(diffCentres[i][0], diffCentres[i][1]);
        [self addSubview:btnDiff[i]];
    }

    [self loadImages];

    // The start-play button, centred horizontally and pinned above the bottom.
    UIImage *startImage = [self getStartImage];
    int startX = (int)(cardWidth - startImage.size.width);
    if (startX < 0) {
        ++startX;
    }
    CGFloat startBottomInset = isPad ? 24.0 : 12.0;
    CGFloat startY = self.frame.size.height - (startImage.size.height + startBottomInset);
    self.buttonStartPlay.frame = CGRectMake(startX >> 1, startY, startImage.size.width, 24.0);
    [self.buttonStartPlay setBackgroundImage:startImage forState:UIControlStateNormal];
    [self.buttonStartPlay addTarget:self
                             action:@selector(pushButtonStartPlay:)
                   forControlEvents:UIControlEventTouchUpInside];

    // The music-bar bar view (an empty holder sized 0x0), centred on the card.
    mbarBarView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    [self addSubview:mbarBarView];
    mbarBarView.center = CGPointMake((isPad ? 2.0 : 0.0) + mbarBarView.frame.size.width * 0.5,
                                     isPad ? 301.0 : 151.5); // 0x293318 / 0x293310

    // The 120 music-bar dot views. The pad packs them at a 4-point stride starting at 57; the phone
    // packs them at a 2-point stride starting at 284.
    for (int i = 0; i < kMusicBarDotCount; ++i) {
        CGFloat dotX = isPad ? (CGFloat)(57 + i * 4) : (CGFloat)(284 + i * 2);
        CGFloat dotW = isPad ? 6.0 : 3.0;
        CGFloat dotH = isPad ? 36.0 : 18.0; // 0x28f530 / fmov 18.0
        mbarDotView[i] = [[UIImageView alloc] initWithFrame:CGRectMake(dotX, 0, dotW, dotH)];
        [mbarBarView addSubview:mbarDotView[i]];
    }
    [self addSubview:mbarBarView];

    // The high-score board plate.
    highscoreBoardView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kResHighscoreBoard)];
    highscoreBoardView.center = CGPointMake(isPad ? 420.0 : 145.0,  // 0x292538 / 0x292e68
                                            isPad ? 240.0 : 118.0); // 0x291bf0 / 0x28f428

    // The seven high-score digit views on the board.
    for (int i = 0; i < kHighscoreDigitCount; ++i) {
        CGFloat digitX = isPad ? (CGFloat)(i * 33) : (CGFloat)((float)i * 20.5f + 1.0f);
        CGFloat digitW = isPad ? 40.0 : 19.0; // 0x28f1f8 / fmov 19.0
        CGFloat digitH = isPad ? 40.0 : 24.0; // 0x28f1f8 / fmov 24.0
        highscoreNumView[i] =
            [[UIImageView alloc] initWithFrame:CGRectMake(digitX, 2.0, digitW, digitH)];
        [highscoreBoardView addSubview:highscoreNumView[i]];
    }

    // The rating view and the combo view on the board.
    CGFloat ratingX = isPad ? 236.0 : 145.0; // 0x293320 / 0x292e78
    CGFloat ratingY = isPad ? 0.0 : 1.0;
    CGFloat ratingSize = isPad ? 40.0 : 24.0; // 0x28f1f8 / fmov 24.0
    ratingView =
        [[UIImageView alloc] initWithFrame:CGRectMake(ratingX, ratingY, ratingSize, ratingSize)];
    [highscoreBoardView addSubview:ratingView];

    comboView =
        [[UIImageView alloc] initWithFrame:CGRectMake(isPad ? 93.0 : 56.0,   // 0x292e50/0x28f878
                                                      isPad ? 38.0 : 22.0,   // 0x28f4f8/fmov
                                                      isPad ? 140.0 : 88.0,  // 0x28f6a8/0x292400
                                                      isPad ? 16.0 : 11.0)]; // fmov 16.0/11.0
    [highscoreBoardView addSubview:comboView];

    // The "HIGH SCORE" text label on the board.
    highscoreTextView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kResHighscoreText)];
    highscoreTextView.center = CGPointMake(
        isPad ? kHighscoreTextCentreXPad : kHighscoreTextCentreXPhone, isPad ? -7.0 : -6.0);
    [highscoreBoardView addSubview:highscoreTextView];
    [self addSubview:highscoreBoardView];

    // Clamp any out-of-range persisted difficulty back to basic.
    NSInteger persistedDifficulty =
        [NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
    if ((unsigned int)persistedDifficulty > kDiffExtreme) {
        [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefDifficultyKey];
        persistedDifficulty = 0;
    }
    int difficulty = (int)persistedDifficulty;
    [btnDiff[kDiffBasic] setEnabled:(difficulty != kDiffBasic)];
    [btnDiff[kDiffAdvanced] setEnabled:(difficulty != kDiffAdvanced)];
    [btnDiff[kDiffExtreme] setEnabled:(difficulty != kDiffExtreme)];
    [self changeDifficulty:difficulty];

    // The three hold marks, one per difficulty button, initially hidden.
    static const char holdSuffixes[kDiffCount] = {'b', 'a', 'e'};
    CGFloat holdRightInset = isPad ? 10.0 : 5.0;
    for (int i = 0; i < kDiffCount; ++i) {
        UIImage *holdImage =
            LoadScaledPngImage([NSString stringWithFormat:kFmtHoldMark, holdSuffixes[i]]);
        holdMark[i] = [[UIImageView alloc] initWithImage:holdImage];
        CGFloat holdX =
            (btnDiff[difficulty].frame.size.width - holdImage.size.width) - holdRightInset;
        holdMark[i].frame = CGRectMake(holdX - 4.0,
                                       isPad ? 8.0 : 4.0, // 0x4020 / 0x4010
                                       holdImage.size.width,
                                       holdImage.size.height);
        [holdMark[i] setHidden:YES];
        [btnDiff[i] addSubview:holdMark[i]];
    }

    // The base class's link and recommend buttons are unused on this card.
    [self.buttonLink setHidden:YES];
    [self.btnRecommendTwitter setHidden:YES];
    [self.btnRecommendFacebook setHidden:YES];

    // The store-jump button, placed at the tune-name plate's origin.
    UIImage *storeImage = LoadScaledPngImage(kResStoreButton);
    CGRect nameFrame = self.tuneNameView.frame;
    CGFloat storeX = isPad ? 80.0 : nameFrame.origin.x; // 0x28f3f8 on pad
    jbtStoreBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [jbtStoreBtn setImage:storeImage forState:UIControlStateNormal];
    [jbtStoreBtn addTarget:self
                    action:@selector(tapStoreMove)
          forControlEvents:UIControlEventTouchUpInside];
    jbtStoreBtn.frame =
        CGRectMake(storeX, nameFrame.origin.y, storeImage.size.width, storeImage.size.height);
    [jbtStoreBtn setExclusiveTouch:YES];
    [self addSubview:jbtStoreBtn];

    // The base class's dimming cover goes on top.
    [self addSubview:self.coverView];

    return self;
}

#pragma mark - Difficulty buttons

/** @ghidraAddress 0x160b00 */
- (nullable UIButton *)diffButton:(nullable NSString *)imageName {
    UIImage *image = LoadScaledPngImage(imageName);
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, image.size.width, image.size.height);
    [button setImage:image forState:UIControlStateNormal];
    [button setExclusiveTouch:YES];
    [button setAdjustsImageWhenHighlighted:NO];
    [button setAdjustsImageWhenDisabled:NO];
    [button addTarget:self
                  action:@selector(selectDiff:)
        forControlEvents:UIControlEventTouchUpInside];
    return button;
}

#pragma mark - Image atlases

/** @ghidraAddress 0x160c28 */
- (void)loadImages {
    @autoreleasepool {
        // The eight rating images (e, d, c, b, a, s, ss, sss); index 8 of the atlas stays nil.
        ratingImg[0] = LoadScaledPngImage(@"msc_rate_e_ch");
        ratingImg[1] = LoadScaledPngImage(@"msc_rate_d_ch");
        ratingImg[2] = LoadScaledPngImage(@"msc_rate_c_ch");
        ratingImg[3] = LoadScaledPngImage(@"msc_rate_b_ch");
        ratingImg[4] = LoadScaledPngImage(@"msc_rate_a_ch");
        ratingImg[5] = LoadScaledPngImage(@"msc_rate_s_ch");
        ratingImg[6] = LoadScaledPngImage(@"msc_rate_ss_ch");
        ratingImg[7] = LoadScaledPngImage(@"msc_rate_sss_ch");

        // The ten high-score and ten level digit images, filled in one interleaved loop.
        for (int i = 0; i < kDigitAtlasCount; ++i) {
            highscoreNumImg[i] =
                LoadScaledPngImage([NSString stringWithFormat:kFmtHighscoreNum, i]);
            levelNumImg[i] = LoadScaledPngImage([NSString stringWithFormat:kFmtLevelNum, i]);
        }

        // The four music-bar bar images.
        mbarBarImg[0] = LoadScaledPngImage(@"mini_bar_b_ch");
        mbarBarImg[1] = LoadScaledPngImage(@"mini_bar_a_ch");
        mbarBarImg[2] = LoadScaledPngImage(@"mini_bar_e_ch");
        mbarBarImg[3] = LoadScaledPngImage(@"mini_bar_o_ch");

        // The four colour rows of eight dot shapes. The shipped name has a literal "0" where the
        // colour index would go, so every row loads the same eight images.
        for (int colour = 0; colour < kMusicBarDotColourCount; ++colour) {
            for (int shape = 0; shape < kMusicBarDotShapeCount; ++shape) {
                mbarDotImg[colour][shape] =
                    LoadScaledPngImage([NSString stringWithFormat:kFmtMusicBarDot, shape + 1]);
            }
        }

        fullcomboImg = LoadScaledPngImage(@"msc_fullcombo_ch");
        excellentImg = LoadScaledPngImage(@"msc_excellent_ch");
    }
}

/** @ghidraAddress 0x163074 */
- (nullable UIImage *)getStartImage {
    return [[ImageCache sharedCache] getResPNG:kResStartButton];
}

#pragma mark - Content loading

/** @ghidraAddress 0x161194 */
- (void)loadContentFromDictionary:(nullable NSDictionary *)dict {
    UIImage *artwork = [UIImage imageWithData:dict[kContentArtwork]];
    if (artwork) {
        [self.artworkView setImage:artwork];
        CGFloat ratio = self.isPad ? 0.3 : 0.2; // 0x28f248 / g_dAnimDuration020
        [self.reflectionArtworkView
            setImage:CreateReflectedImage(artwork, (int)(artwork.size.height * ratio))];
    }

    UIImage *nameImage = [UIImage imageWithData:dict[kContentNameB]];
    if (nameImage) {
        [self.tuneNameView setImage:nameImage];
    }

    if (dict[kContentSeqBas]) {
        [Sequence getMusicBarData:mbarDots[kDiffBasic] raw:dict[kContentSeqBas]];
    }
    if (dict[kContentSeqAdv]) {
        [Sequence getMusicBarData:mbarDots[kDiffAdvanced] raw:dict[kContentSeqAdv]];
    }
    if (dict[kContentSeqExt]) {
        [Sequence getMusicBarData:mbarDots[kDiffExtreme] raw:dict[kContentSeqExt]];
    }

    // When the edit-select preference is off, apply the persisted difficulty.
    if ([NSUserDefaults.standardUserDefaults integerForKey:kPrefEditSelectKey] == 0) {
        [self changeDifficulty:(int)[NSUserDefaults.standardUserDefaults
                                   integerForKey:kPrefDifficultyKey]];
    }
}

/** @ghidraAddress 0x161528 */
- (void)loadContentFromPath:(nullable NSString *)path orData:(nullable NSData *)data {
    KUnzip *archive = nil;
    if (path) {
        archive = [[KUnzip alloc] initWithPath:path tail:kArchiveTail];
    }
    if (archive == nil) {
        if (data.length < kArchiveTail + 1) {
            return;
        }
        archive = [[KUnzip alloc] initWithData:data
                                         range:NSMakeRange(0, data.length - kArchiveTail)];
        if (archive == nil) {
            return;
        }
    }

    BFCodec *codec = [[BFCodec alloc] init];
    NSData *cipherKey = GetBgmCipherKey();

    [codec cipherInit:cipherKey];
    NSMutableData *artworkData = [archive uncompress:kArchiveArtwork];
    [codec decipher:artworkData];
    UIImage *artwork = [UIImage imageWithData:artworkData];
    if (artwork) {
        [self.artworkView setImage:artwork];
        CGFloat ratio = self.isPad ? 0.3 : 0.2; // 0x28f248 / g_dAnimDuration020
        [self.reflectionArtworkView
            setImage:CreateReflectedImage(artwork, (int)(artwork.size.height * ratio))];
    }

    [codec cipherInit:cipherKey];
    NSMutableData *nameData = [archive uncompress:kArchiveNameB];
    [codec decipher:nameData];
    UIImage *nameImage = [UIImage imageWithData:nameData];
    if (nameImage) {
        [self.tuneNameView setImage:nameImage];
    }

    [codec cipherInit:cipherKey];
    NSMutableData *seqBas = [archive uncompress:kArchiveSeqBas];
    [codec decipher:seqBas];
    [Sequence getMusicBarData:mbarDots[kDiffBasic] raw:seqBas];

    [codec cipherInit:cipherKey];
    NSMutableData *seqAdv = [archive uncompress:kArchiveSeqAdv];
    [codec decipher:seqAdv];
    [Sequence getMusicBarData:mbarDots[kDiffAdvanced] raw:seqAdv];

    [codec cipherInit:cipherKey];
    NSMutableData *seqExt = [archive uncompress:kArchiveSeqExt];
    [codec decipher:seqExt];
    [Sequence getMusicBarData:mbarDots[kDiffExtreme] raw:seqExt];

    [self changeDifficulty:(int)[NSUserDefaults.standardUserDefaults
                               integerForKey:kPrefDifficultyKey]];
}

/** @ghidraAddress 0x161a64 */
- (void)loadExtendMusicBar:(nullable NSString *)path {
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:GetBgmCipherKey()];
    if (path == nil) {
        return;
    }
    KUnzip *archive = [[KUnzip alloc] initWithPath:path tail:kArchiveTail];
    if (archive != nil) {
        [self changeDifficulty:(int)[NSUserDefaults.standardUserDefaults
                                   integerForKey:kPrefDifficultyKey]];
    }
}

#pragma mark - Info

/** @ghidraAddress 0x161c40 */
- (void)setInfo:(nullable TuneInfo *)info score:(nullable id)scoreArg {
    [super setInfo:info score:scoreArg];
    if (info == nil) {
        return;
    }
    self.levelBas = ScratchMusicDetailViewLevelIndex(info.lvBas);
    self.levelAdv = ScratchMusicDetailViewLevelIndex(info.lvAdv);
    self.levelExt = ScratchMusicDetailViewLevelIndex(info.lvExt);

    [levelNumView[0] setImage:levelNumImg[(int)(unsigned char)self.levelBas]];
    [levelNumView[1] setImage:levelNumImg[(int)(unsigned char)self.levelAdv]];
    [levelNumView[2] setImage:levelNumImg[(int)(unsigned char)self.levelExt]];
    [levelNumView[3] setImage:levelNumImg[(int)(unsigned char)self.levelExt]];
    [levelNumView[3] setAlpha:0];

    [self resetScore];
    [self putScore:scoreArg];
    [self loadContentFromPath:info.filePath orData:nil];
}

/** @ghidraAddress 0x1622b8 */
- (void)clearInfo {
    [self.artworkView setImage:nil];
    [self.reflectionArtworkView setImage:nil];
    [self.tuneNameView setImage:nil];
}

#pragma mark - Board refresh

/** @ghidraAddress 0x161f30 */
- (void)infoChange:(int)difficulty {
    // The colour-resource buffer for the selected difficulty's music bar, drawn from the base
    // class's stored bar data. It stays all zeroes when the bar is too short.
    char mbarRes[kMusicBarResBytes] = {0};

    int rank = myRank[difficulty];
    if (rank < 0) {
        rank = -1;
    }
    [self setRankingNumberImage:rank];

    int diffScore = score[difficulty];
    char fullcombo = ((char *)bFullCombo)[difficulty];
    NSData *bar = nil;
    if (difficulty == kDiffExtreme) {
        if (self.mbarExt.length >= kMusicBarLength) {
            bar = self.mbarExt;
        }
    } else if (difficulty == kDiffAdvanced) {
        if (self.mbarAdv.length >= kMusicBarLength) {
            bar = self.mbarAdv;
        }
    } else if (difficulty == kDiffBasic) {
        if (self.mbarBas.length >= kMusicBarLength) {
            bar = self.mbarBas;
        }
    }
    if (bar) {
        [bar getBytes:mbarRes length:kMusicBarLength];
    }

    [self setScoreBoard:diffScore fullcombo:(fullcombo != 0)];
    [mbarBarView setImage:mbarBarImg[difficulty]];

    const char *dots = mbarDots[difficulty];
    for (int i = 0; i < kMusicBarDotCount; ++i) {
        // Two dot symbols per byte (a nibble each); four colour codes per resource byte (2 bits).
        int shape = ((dots[i >> 1] >> ((i & 1) * 4)) & 0xF) - 1;
        UIImage *dotImage = nil;
        if ((unsigned int)shape < kMusicBarDotShapeCount) {
            int colour = (mbarRes[i >> 2] >> ((i & 3) * 2)) & 3;
            dotImage = mbarDotImg[colour][shape];
        }
        [mbarDotView[i] setImage:dotImage];
    }

    // The three hold marks reflect the current hold flags.
    [holdMark[0] setHidden:YES];
    if (currentHoldFlg & 1) {
        [holdMark[0] setHidden:NO];
    }
    [holdMark[1] setHidden:YES];
    if ((currentHoldFlg >> 1) & 1) {
        [holdMark[1] setHidden:NO];
    }
    [holdMark[2] setHidden:YES];
    if ((currentHoldFlg >> 2) & 1) {
        [holdMark[2] setHidden:NO];
    }
}

/** @ghidraAddress 0x161b84 */
- (void)setRankingNumberImage:(int)number {
    // Fill the six digit views right to left, blanking leading positions once the value runs out.
    for (int i = kRankingDigitCount - 1; i >= 0; --i) {
        if (number < 1) {
            [rankingNumView[i] setImage:nil];
        } else {
            [rankingNumView[i] setImage:rankingNumImg[number % 10]];
            number /= 10;
        }
    }
}

/** @ghidraAddress 0x162920 */
- (void)setScoreBoard:(int)scoreValue fullcombo:(BOOL)fullcombo {
    char digits[8] = "0000000";
    if (scoreValue < 0) {
        // No score: blank the rating and combo, and show all-zero digits.
        [ratingView setImage:nil];
        [comboView setImage:nil];
    } else {
        if (scoreValue < kExcellentScore) {
            short rank = [Sequence rankOfPoint:scoreValue];
            [ratingView setImage:ratingImg[(int)(unsigned short)rank]];
            [comboView setImage:(fullcombo ? fullcomboImg : nil)];
        } else {
            // A perfect score: no rating, the excellent mark instead.
            [ratingView setImage:nil];
            [comboView setImage:excellentImg];
        }
        snprintf(digits, sizeof(digits), "%*d", kHighscoreFieldWidth, scoreValue);
    }

    for (int i = 0; i < kHighscoreDigitCount; ++i) {
        unsigned char c = (unsigned char)digits[i];
        UIImage *digitImage = nil;
        if ((unsigned int)(c - '0') < 10) {
            digitImage = highscoreNumImg[(char)c - '0'];
        }
        [highscoreNumView[i] setImage:digitImage];
    }
}

#pragma mark - Difficulty selection

/** @ghidraAddress 0x162cb4 */
- (void)changeDifficulty:(int)difficulty {
    for (int i = 0; i < kDiffCount; ++i) {
        if (i == difficulty) {
            [btnDiff[i] setAlpha:1.0];
            [btnDiff[i] setTransform:CGAffineTransformIdentity];
        } else {
            [btnDiff[i] setAlpha:kDiffDimAlpha];
            [btnDiff[i]
                setTransform:CGAffineTransformMakeScale(kDiffShrinkScale, kDiffShrinkScale)];
        }
    }
    // The fourth level slot (a dimmed extreme duplicate) is always shown at full scale.
    [levelNumView[3] setAlpha:1.0];
    [levelNumView[3] setTransform:CGAffineTransformIdentity];
    [self infoChange:difficulty];
}

/** @ghidraAddress 0x16245c */
- (void)selectDiff:(nullable id)sender {
    if (self.isStarted) {
        return;
    }
    int previous = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];

    NSString *soundBase = nil;
    int selected;
    if (btnDiff[kDiffBasic] == sender) {
        soundBase = [self soundName:kSeDiffBasic];
        [btnDiff[kDiffBasic] setEnabled:NO];
        [btnDiff[kDiffExtreme] setEnabled:YES];
        [btnDiff[kDiffAdvanced] setEnabled:YES];
        selected = kDiffBasic;
    } else if (btnDiff[kDiffAdvanced] == sender) {
        soundBase = [self soundName:kSeDiffAdvanced];
        [btnDiff[kDiffAdvanced] setEnabled:NO];
        [btnDiff[kDiffExtreme] setEnabled:YES];
        [btnDiff[kDiffBasic] setEnabled:YES];
        selected = kDiffAdvanced;
    } else if (btnDiff[kDiffExtreme] == sender) {
        soundBase = [self soundName:kSeDiffExtreme];
        [btnDiff[kDiffExtreme] setEnabled:NO];
        [btnDiff[kDiffBasic] setEnabled:YES];
        [btnDiff[kDiffAdvanced] setEnabled:YES];
        selected = kDiffExtreme;
    } else {
        return;
    }

    if (previous == selected) {
        return;
    }

    BOOL isPad = self.isPad;
    // Park the high-score text 40 points to the right and drop the board's alpha, then animate the
    // board and text back into place while applying the new difficulty.
    highscoreTextView.center = CGPointMake(
        (isPad ? kHighscoreTextCentreXPad : kHighscoreTextCentreXPhone) + kHighscoreTextSlideOffset,
        isPad ? -7.0 : -6.0);
    [highscoreBoardView setAlpha:0];
    [[AudioManager sharedManager] playSeResFile:soundBase inDirectory:nil];
    [NSUserDefaults.standardUserDefaults setInteger:selected forKey:kPrefDifficultyKey];

    [UIView animateWithDuration:kDiffAnimDuration
                     animations:^{
                       /** @ghidraAddress 0x162874 */
                       [self changeDifficulty:selected];
                       BOOL animIsPad = self.isPad;
                       self->highscoreTextView.center = CGPointMake(
                           animIsPad ? kHighscoreTextCentreXPad : kHighscoreTextCentreXPhone,
                           animIsPad ? -7.0 : -6.0);
                       [self->highscoreBoardView setAlpha:1.0];
                     }];
    [UIApplication.sharedApplication performSelector:@selector(endIgnoringInteractionEvents)
                                          withObject:nil
                                          afterDelay:kDiffInteractionDelay];
}

/** @ghidraAddress 0x162f18 */
- (void)setMusicBarDot:(nullable char *)mbar mbarRes:(nullable char *)mbarRes {
    if (mbar == nullptr) {
        for (int i = 0; i < kMusicBarDotCount; ++i) {
            [mbarDotView[i] setImage:nil];
        }
        return;
    }
    for (int i = 0; i < kMusicBarDotCount; ++i) {
        int colour = 0;
        if (mbarRes != nullptr) {
            colour = (mbarRes[i >> 2] >> ((i & 3) * 2)) & 3;
        }
        int shape = ((mbar[i >> 1] >> ((i & 1) * 4)) & 0xF) - 1;
        UIImage *dotImage = nil;
        if ((unsigned int)shape < kMusicBarDotShapeCount) {
            dotImage = mbarDotImg[colour][shape];
        }
        [mbarDotView[i] setImage:dotImage];
    }
}

#pragma mark - Detail info

/** @ghidraAddress 0x1630d8 */
- (CGPoint)getDifficultyPos:(int)difficulty {
    int index = (difficulty > kDiffExtreme) ? kDiffBasic : difficulty;

    int scrollY = (int)self.scrollView.frame.origin.y;
    int y = (int)((CGFloat)scrollY + btnDiff[index].frame.origin.y);

    int scrollX = (int)self.scrollView.frame.origin.x;
    int x = (int)((CGFloat)scrollX + btnDiff[index].frame.origin.x);

    return CGPointMake(x, y);
}

/** @ghidraAddress 0x1631c8 */
- (void)setDetailInfo:(int)slot {
    ChallengeStatus *status = [ChallengeStatus sharedStatus];
    itemSlot = slot;
    double enableTime = [status getMusicEnableTime:slot];
    [self.buttonStartPlay setEnabled:(0.0 <= enableTime)];

    ScratchInfo *info = status.scratchInfoTable[slot];
    _musicID = info.musicID;
    _difficulty = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
    packID = info.packID;

    if (packID < 1) {
        [jbtStoreBtn setHidden:YES];
    } else {
        [jbtStoreBtn setHidden:NO];
        [jbtStoreBtn setEnabled:YES];
        if ([[StoreMusicListManager sharedManager] hasMusic:_musicID]) {
            [jbtStoreBtn setHidden:YES];
        }
    }

    // Read the three per-difficulty score, full-combo, and rank values.
    for (int i = 0; i < kDiffCount; ++i) {
        score[i] = [info getMyScore:i];
        ((char *)bFullCombo)[i] = (char)[info getFullCombo:i];
        myRank[i] = [info getMyRank:i];
    }

    int rank = myRank[_difficulty];
    if (rank < 0) {
        rank = -1;
    }
    [self setRankingNumberImage:rank];

    // Open the tune's item archive and build a TuneInfo plus music-bar data from it.
    NSString *itemPath = [ScratchUtil itemPathForMusicID:info.musicID];
    if (![NSFileManager.defaultManager fileExistsAtPath:itemPath]) {
        return;
    }
    KUnzip *archive = [[KUnzip alloc] initWithPath:itemPath tail:kArchiveTail];
    if (archive == nil) {
        return;
    }

    BFCodec *codec = [[BFCodec alloc] init];
    NSData *cipherKey = GetBgmCipherKey();
    // The enumeration walks the archive's file list for its side effects only.
    for (id name in [archive fileList]) {
        (void)name;
    }

    currentHoldFlg = [Sequence checkExistHoldMarkerFlag:archive];

    NSMutableData *infoData = [archive uncompress:kArchiveInfoV3];
    if (infoData == nil) {
        infoData = [archive uncompress:kArchiveInfoV2];
        if (infoData == nil) {
            infoData = [archive uncompress:kArchiveInfo];
        }
        if (infoData != nil) {
            [codec cipherInit:GetBgmCipherKey()];
            [codec decipher:infoData];
            NSDictionary *infoDict = [NSDictionary dictionaryFromPropertyListData:infoData];
            if (infoDict) {
                _tuneInfo = [[TuneInfo alloc] initWithfilePath:itemPath dictionary:infoDict];
            }
        }
    } else {
        // The v3 archive uses the tune-info cipher key and skips a four-byte header.
        codec = [[BFCodec alloc] init];
        [codec cipherInit:CreateTuneInfoCipherKey()];
        [codec decipher:infoData];
        NSData *body = [infoData subdataWithRange:NSMakeRange(4, infoData.length - 4)];
        NSDictionary *infoDict = [NSDictionary dictionaryFromPropertyListData:body];
        if (infoDict) {
            _tuneInfo = [[TuneInfo alloc] initWithfilePath:itemPath dictionary:infoDict];
        }
    }

    [self setInfo:_tuneInfo score:nil];

    [codec cipherInit:cipherKey];
    NSMutableData *seqBas = [archive uncompress:kArchiveSeqBas];
    [codec decipher:seqBas];
    [Sequence getMusicBarData:mbarDots[kDiffBasic] raw:seqBas];

    [codec cipherInit:cipherKey];
    NSMutableData *seqAdv = [archive uncompress:kArchiveSeqAdv];
    [codec decipher:seqAdv];
    [Sequence getMusicBarData:mbarDots[kDiffAdvanced] raw:seqAdv];

    [codec cipherInit:cipherKey];
    NSMutableData *seqExt = [archive uncompress:kArchiveSeqExt];
    [codec decipher:seqExt];
    [Sequence getMusicBarData:mbarDots[kDiffExtreme] raw:seqExt];

    self.levelBas = ScratchMusicDetailViewLevelIndex(self.tuneInfo.lvBas);
    self.levelAdv = ScratchMusicDetailViewLevelIndex(self.tuneInfo.lvAdv);
    self.levelExt = ScratchMusicDetailViewLevelIndex(self.tuneInfo.lvExt);
}

#pragma mark - Sound

/** @ghidraAddress 0x16236c */
- (nullable NSString *)soundName:(nullable NSString *)name {
    unsigned int theme = [JubeatAppDelegate appDelegate].currentTheme;
    if (theme == kThemeRPL) {
        return [NSString stringWithFormat:@"SD_RPL_CV_%@", name];
    }
    if (theme == kThemeKNT) {
        return [NSString stringWithFormat:@"SD_KNT_CV_%@", name];
    }
    return [NSString stringWithFormat:@"SD_CV_%@", name];
}

#pragma mark - Actions

/** @ghidraAddress 0x163d50 */
- (void)pushButtonStartPlay:(nullable id)sender {
    if (![self.buttonStartPlay isEnabled]) {
        return;
    }
    [[AudioManager sharedManager] playSeResFile:kSeStartOK inDirectory:nil];
    [self.aDelegate startChallengeMusic];
}

/** @ghidraAddress 0x163e24 */
- (void)tapRanking:(nullable id)sender {
    [[AudioManager sharedManager] playSeResFile:kSeRankingMenu inDirectory:nil];
    [self.aDelegate openRanking];
}

/** @ghidraAddress 0x163ee8 */
- (void)tapStoreMove {
    [[AudioManager sharedManager] playSeResFile:kSeStoreMenu inDirectory:nil];
    [self.aDelegate openJubeatStore:packID];
}

/** @ghidraAddress 0x163eac */
- (void)closeRanking {
    [rankingListView removeFromSuperview];
    rankingListView = nil;
}

/** @ghidraAddress 0x163f7c */
- (void)showDetail {
    if (rankingListView != nil) {
        [rankingListView removeFromSuperview];
        rankingListView = nil;
    }
}

/** @ghidraAddress 0x163fc8 */
- (void)refreshDetail {
    ScratchInfo *info = [ChallengeStatus sharedStatus].scratchInfoTable[itemSlot];
    for (int i = 0; i < kDiffCount; ++i) {
        myRank[i] = [info getMyRank:i];
    }
}

/** @ghidraAddress 0x1640ac */
- (void)timerUpdate {
    // The shipped body is empty.
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x16303c */
- (void)dealloc {
    // The strong ivars are torn down by the compiler-generated .cxx_destruct (0x164114), which is
    // not authored here.
}

@end
