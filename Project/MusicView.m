#import "MusicView.h"

#import <QuartzCore/QuartzCore.h>

#import "ImageCache.h"
#import "JubeatAppDelegate.h"
#import "LatelyJcfListManager.h"
#import "RankImageUtility.h"
#import "ScoreRecord.h"
#import "TuneInfo.h"
#import "music_grid_layout.h"

// The three difficulty charts, ordered as the rank arrays are populated (extreme first, then
// advanced, then basic) and indexed the way the fixed-index blocks read them (basic 0, advanced 1,
// extreme 2).
enum {
    kDifficultyCount = 3,
};

// Column-type-indexed layout tables live in __const. Each is a run of six 4-byte integers keyed by
// the music-select column type. iPad and non-iPad idioms take different tables where they differ.
// The four-byte entries are read as signed integers.
static const int kNameLabelYByColTypePad[] = {8, 4, 5, 4, 2, 2};        // 0x28f550
static const int kNameLabelYByColTypePhone[] = {4, 2, 2, 30, 24, 18};   // 0x28f55c
static const int kArtistLabelYByColType[] = {30, 24, 18, 90, 50, 32};   // 0x28f568
static const int kRankFirstYByColTypePad[] = {90, 50, 32, 14, 12, 8};   // 0x28f574
static const int kRankFirstYByColTypePhone[] = {14, 12, 8, 25, 25, 22}; // 0x28f580
static const int kRankStepYByColTypePad[] = {25, 25, 22, 25, 18, 15};   // 0x28f58c
static const int kRankStepYByColTypePhone[] = {25, 18, 15, 0, 0, 0};    // 0x28f598

// Per-idiom horizontal base of the rank/frame stacks: index 0 (phone) 80.0, index 1 (iPad) 180.0.
static const double kRankBaseXByIsPad[] = {80.0, 180.0}; // 0x28f540

// Layout scalars read from the constant pool.
static const float kRankChipHldScale = 20.0f;   // hold-marker frame x-scale factor (0x28f538)
static const double kRankFcOffset = -2.0;       // full-combo marker origin factor
static const double kArtistLabelExtraGap = 8.0; // added to the artist-label baseline
static const CGFloat kNameLabelHeightPad = 21.0;
static const CGFloat kNameLabelHeightPhone = 18.0;
static const CGFloat kArtistLabelHeightPad = 17.0;
static const CGFloat kNameFontSizePad = 16.0;
static const CGFloat kNameFontSizePhone = 12.0;
static const CGFloat kArtistFontSizePad = 14.0;
static const CGFloat kArtistFontSizePhone = 10.0;

// The artwork's perspective transform m34 term (0xbf50624de0000000).
static const CGFloat kArtworkPerspectiveM34 = -0.0010000000474974513;
// The artwork's one-point layer border.
static const CGFloat kArtworkBorderWidth = 1.0;

// Artwork-anchored button metrics, all multiplied by the cell scale.
static const CGFloat kPlaylistButtonInset = 16.0;
static const CGFloat kBgmButtonInset = 18.0;
static const CGFloat kActionButtonSize = 36.0; // 0x28f53c

// The scale threshold above which the iPad artist label re-appears in showNameAndArtist:.
static const double kArtistScaleThreshold = 100.0; // 0x28f3f0
static const int kArtistScaleThresholdValue = 60;  // (int)(scale * 100) must exceed this

// jubeatLab download icon metrics.
static const CGFloat kDownloadIconOffsetX = -12.0;
static const CGFloat kDownloadIconOffsetY = -14.0;
static const CGFloat kDownloadIconExtraY = 32.0; // 0x28f458
static const CGFloat kDownloadIconSize = 29.0;

// Rating-chip reveal modes for setRatingChipHidden:.
enum {
    kRatingChipModeHidden = 0,
    kRatingChipModeAdRank = 1,
    kRatingChipModeAll = 2,
};

// Animation durations.
static const NSTimeInterval kScaleFadeDuration = 0.2;    // 0x28e040
static const NSTimeInterval kSquareFadeDuration = 0.1;   // 0x28f290
static const NSTimeInterval kButtonPressDuration = 0.25; // 0x3fd0000000000000
static const CGFloat kButtonPressScale = 0.5;

@interface MusicView () {
@public
    // Device-idiom flags, filled from the app delegate in the initialiser.
    BOOL isPad; // 0x349b94
    BOOL isPhoneRetina;
    BOOL is4Inch;
    // Layout scalars threaded through the frame arithmetic.
    double artwork_size;
    double imageSize;
    double currentScale;
    int defaultWidth;
    // The rank, advertised-rank, and rating-chip subview groups. The three rank* arrays hold one
    // element per difficulty; the chip arrays collect the frame overlays and hold-marker overlays.
    NSMutableArray *rankBgArray;
    NSMutableArray *rankImgArray;
    NSMutableArray *rankFcArray;
    NSMutableArray *adRankBgArray;
    NSMutableArray *adRankImgArray;
    NSMutableArray *adRankFcArray;
    NSMutableArray *adRankBgChipArray;
}
- (CGPoint)centerArtworkImg;
@end

// Builds the extreme, advanced, and basic rank stacks bottom-to-top, then the three full-combo
// markers. Each difficulty's frame overlay (rankBgOrg), hold-marker overlay (rankBgHld), rank
// background (rankBg), rank letter (rankImg), advertised-rank background (adRankBg), and
// advertised-rank letter (adRankImg) are laid out from the pooled column-type tables. This
// de-inlines the giant repeated block that dominates the shipped initialiser.
static inline void MusicViewBuildRankStacks(MusicView *self, int colType, double scale) {
    // The rank-word and frame basenames take a theme suffix: "_rpl" for the ripples theme, "_knt"
    // for the knit theme, and nothing for the original theme.
    NSString *suffix;
    switch (JubeatAppDelegate.appDelegate.currentTheme) {
    case JubeatThemeRipples:
        suffix = @"_rpl";
        break;
    case JubeatThemeKnit:
        suffix = @"_knt";
        break;
    default:
        suffix = @"";
        break;
    }
    NSString *nameBas = [NSString stringWithFormat:@"rank_basic%@", suffix];
    NSString *nameAdv = [NSString stringWithFormat:@"rank_advanced%@", suffix];
    NSString *nameExt = [NSString stringWithFormat:@"rank_extreme%@", suffix];

    self->rankBgArray = [[NSMutableArray alloc] init];
    self->rankImgArray = [[NSMutableArray alloc] init];
    self->rankFcArray = [[NSMutableArray alloc] init];
    self.rankBgChipArray = [[NSMutableArray alloc] init];
    self->adRankBgChipArray = [[NSMutableArray alloc] init];
    self->adRankBgArray = [[NSMutableArray alloc] init];
    self->adRankImgArray = [[NSMutableArray alloc] init];
    self->adRankFcArray = [[NSMutableArray alloc] init];

    // On iPad the artwork-relative widths are used as-is (scale factor 1.0 inside the stack); on
    // phones the whole stack is scaled by the cell scale.
    const double stackScale = self->isPad ? 1.0 : scale;
    const int *firstY = self->isPad ? kRankFirstYByColTypePad : kRankFirstYByColTypePhone;
    const int *stepY = self->isPad ? kRankStepYByColTypePad : kRankStepYByColTypePhone;
    // The rank background and frame overlay share one horizontal base: scale * (isPad ? 180 : 80).
    // The advertised-rank background and the hold overlay instead use scale * scale * (isPad ? 20 :
    // 0).
    const double baseX = scale * kRankBaseXByIsPad[self->isPad ? 1 : 0];
    const double hldX = (double)(float)(scale * scale * (self->isPad ? kRankChipHldScale : 0.0f));

    // --- Extreme ---
    int y = firstY[colType];
    UIImage *imgExt = [[ImageCache sharedCache] getResPNG:nameExt];
    self.rankBgExt = [[UIImageView alloc] initWithImage:imgExt];
    self.rankBgExt.frame = CGRectMake(
        baseX, (double)y, stackScale * imgExt.size.width, stackScale * imgExt.size.height);
    self.rankImgExt = [[UIImageView alloc]
        initWithFrame:CGRectMake(
                          0, 0, stackScale * imgExt.size.width, stackScale * imgExt.size.height)];
    [self->rankBgArray addObject:self.rankBgExt];
    [self->rankImgArray addObject:self.rankImgExt];

    self.adRankBgExt = [[UIImageView alloc] initWithImage:imgExt];
    self.adRankBgExt.frame = CGRectMake(
        hldX, (double)y, stackScale * imgExt.size.width, stackScale * imgExt.size.height);
    self.adRankImgExt = [[UIImageView alloc]
        initWithFrame:CGRectMake(
                          0, 0, stackScale * imgExt.size.width, stackScale * imgExt.size.height)];
    [self->adRankBgArray addObject:self.adRankBgExt];
    [self->adRankImgArray addObject:self.adRankImgExt];

    NSString *nameFrmExt = [NSString stringWithFormat:@"rank_frm_ext%@", suffix];
    UIImage *frmExt = [[ImageCache sharedCache] getResPNG:nameFrmExt];
    self.rankBgOrgExt = [[UIImageView alloc] initWithImage:frmExt];
    self.rankBgOrgExt.frame = CGRectMake(
        baseX, (double)y, stackScale * frmExt.size.width, stackScale * frmExt.size.height);
    UIImage *frmExtHld = [[ImageCache sharedCache] getResPNG:nameFrmExt];
    self.rankBgHldExt = [[UIImageView alloc] initWithImage:frmExtHld];
    self.rankBgHldExt.frame = CGRectMake(
        hldX, (double)y, stackScale * frmExtHld.size.width, stackScale * frmExtHld.size.height);
    [self.rankBgChipArray addObject:self.rankBgOrgExt];
    [self.rankBgChipArray addObject:self.rankBgHldExt];
    [self->adRankBgChipArray addObject:self.rankBgHldExt];

    // --- Advanced ---
    y += stepY[colType];
    UIImage *imgAdv = [[ImageCache sharedCache] getResPNG:nameAdv];
    self.rankBgAdv = [[UIImageView alloc] initWithImage:imgAdv];
    self.rankBgAdv.frame = CGRectMake(
        baseX, (double)y, stackScale * imgAdv.size.width, stackScale * imgAdv.size.height);
    self.rankImgAdv = [[UIImageView alloc]
        initWithFrame:CGRectMake(
                          0, 0, stackScale * imgAdv.size.width, stackScale * imgAdv.size.height)];
    [self->rankBgArray addObject:self.rankBgAdv];
    [self->rankImgArray addObject:self.rankImgAdv];

    self.adRankBgAdv = [[UIImageView alloc] initWithImage:imgAdv];
    self.adRankBgAdv.frame = CGRectMake(
        hldX, (double)y, stackScale * imgAdv.size.width, stackScale * imgAdv.size.height);
    self.adRankImgAdv = [[UIImageView alloc]
        initWithFrame:CGRectMake(
                          0, 0, stackScale * imgAdv.size.width, stackScale * imgAdv.size.height)];
    [self->adRankBgArray addObject:self.adRankBgAdv];
    [self->adRankImgArray addObject:self.adRankImgAdv];

    NSString *nameFrmAdv = [NSString stringWithFormat:@"rank_frm_adv%@", suffix];
    UIImage *frmAdv = [[ImageCache sharedCache] getResPNG:nameFrmAdv];
    self.rankBgOrgAdv = [[UIImageView alloc] initWithImage:frmAdv];
    self.rankBgOrgAdv.frame = CGRectMake(
        baseX, (double)y, stackScale * frmAdv.size.width, stackScale * frmAdv.size.height);
    UIImage *frmAdvHld = [[ImageCache sharedCache] getResPNG:nameFrmAdv];
    self.rankBgHldAdv = [[UIImageView alloc] initWithImage:frmAdvHld];
    self.rankBgHldAdv.frame = CGRectMake(
        hldX, (double)y, stackScale * frmAdvHld.size.width, stackScale * frmAdvHld.size.height);
    [self.rankBgChipArray addObject:self.rankBgOrgAdv];
    [self.rankBgChipArray addObject:self.rankBgHldAdv];
    [self->adRankBgChipArray addObject:self.rankBgHldAdv];

    // --- Basic ---
    y += stepY[colType];
    UIImage *imgBas = [[ImageCache sharedCache] getResPNG:nameBas];
    self.rankBgBas = [[UIImageView alloc] initWithImage:imgBas];
    self.rankBgBas.frame = CGRectMake(
        baseX, (double)y, stackScale * imgBas.size.width, stackScale * imgBas.size.height);
    self.rankImgBas = [[UIImageView alloc]
        initWithFrame:CGRectMake(
                          0, 0, stackScale * imgBas.size.width, stackScale * imgBas.size.height)];
    [self->rankBgArray addObject:self.rankBgBas];
    [self->rankImgArray addObject:self.rankImgBas];

    self.adRankBgBas = [[UIImageView alloc] initWithImage:imgBas];
    self.adRankBgBas.frame = CGRectMake(
        hldX, (double)y, stackScale * imgBas.size.width, stackScale * imgBas.size.height);
    self.adRankImgBas = [[UIImageView alloc]
        initWithFrame:CGRectMake(
                          0, 0, stackScale * imgBas.size.width, stackScale * imgBas.size.height)];
    [self->adRankBgArray addObject:self.adRankBgBas];
    [self->adRankImgArray addObject:self.adRankImgBas];

    NSString *nameFrmBas = [NSString stringWithFormat:@"rank_frm_bas%@", suffix];
    UIImage *frmBas = [[ImageCache sharedCache] getResPNG:nameFrmBas];
    self.rankBgOrgBas = [[UIImageView alloc] initWithImage:frmBas];
    self.rankBgOrgBas.frame = CGRectMake(
        baseX, (double)y, stackScale * frmBas.size.width, stackScale * frmBas.size.height);
    UIImage *frmBasHld = [[ImageCache sharedCache] getResPNG:nameFrmBas];
    self.rankBgHldBas = [[UIImageView alloc] initWithImage:frmBasHld];
    self.rankBgHldBas.frame = CGRectMake(
        hldX, (double)y, stackScale * frmBasHld.size.width, stackScale * frmBasHld.size.height);
    [self.rankBgChipArray addObject:self.rankBgOrgBas];
    [self.rankBgChipArray addObject:self.rankBgHldBas];
    [self->adRankBgChipArray addObject:self.rankBgHldBas];

    // --- Full-combo markers, all pinned off-screen top-left at -2*scale until a score arrives ---
    UIImage *full = [[ImageCache sharedCache] getResPNG:@"rank_full"];
    const CGRect fcFrame = CGRectMake(scale * kRankFcOffset,
                                      scale * kRankFcOffset,
                                      stackScale * full.size.width,
                                      stackScale * full.size.height);
    self.rankFcExt = [[UIImageView alloc] initWithImage:full];
    self.rankFcExt.frame = fcFrame;
    self.rankFcAdv = [[UIImageView alloc] initWithImage:full];
    self.rankFcAdv.frame = fcFrame;
    self.rankFcBas = [[UIImageView alloc] initWithImage:full];
    self.rankFcBas.frame = fcFrame;
    [self->rankFcArray addObject:self.rankFcExt];
    [self->rankFcArray addObject:self.rankFcAdv];
    [self->rankFcArray addObject:self.rankFcBas];

    self.adRankFcExt = [[UIImageView alloc] initWithImage:full];
    self.adRankFcExt.frame = fcFrame;
    self.adRankFcAdv = [[UIImageView alloc] initWithImage:full];
    self.adRankFcAdv.frame = fcFrame;
    self.adRankFcBas = [[UIImageView alloc] initWithImage:full];
    self.adRankFcBas.frame = fcFrame;
    [self->adRankFcArray addObject:self.adRankFcExt];
    [self->adRankFcArray addObject:self.adRankFcAdv];
    [self->adRankFcArray addObject:self.adRankFcBas];
}

// Builds the playlist and BGM-select buttons over the artwork's top-right corner, disabled and
// hidden until a long-press reveals them.
static inline void MusicViewBuildActionButtons(MusicView *self, double scale) {
    const double edge = scale * kActionButtonSize;
    self.btnPlaylistAction = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnPlaylistAction.exclusiveTouch = YES;
    const CGRect artFrame = self.imgView.frame;
    self.btnPlaylistAction.frame = CGRectMake(artFrame.origin.x - scale * kPlaylistButtonInset,
                                              artFrame.origin.y - scale * kPlaylistButtonInset,
                                              edge,
                                              edge);
    [self.btnPlaylistAction addTarget:self
                               action:@selector(tapPlaylistAction:)
                     forControlEvents:UIControlEventTouchUpInside];
    self.btnPlaylistAction.hidden = YES;
    self.btnPlaylistAction.contentMode = UIViewContentModeScaleAspectFit;
    self.btnPlaylistAction.adjustsImageWhenDisabled = NO;

    self.btnBgmSelect = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnBgmSelect.exclusiveTouch = YES;
    const CGRect artFrame2 = self.imgView.frame;
    self.btnBgmSelect.frame =
        CGRectMake((artFrame2.origin.x + artFrame2.size.width) - scale * kBgmButtonInset,
                   (artFrame2.origin.y + artFrame2.size.height) - scale * kBgmButtonInset,
                   edge,
                   edge);
    [self.btnBgmSelect addTarget:self
                          action:@selector(tapBgmSelect:)
                forControlEvents:UIControlEventTouchUpInside];
    self.btnBgmSelect.hidden = YES;
    self.btnBgmSelect.contentMode = UIViewContentModeScaleAspectFit;
    self.btnBgmSelect.adjustsImageWhenDisabled = NO;
}

// Installs every subview in the shipped order: artwork, labels, the frame/hold chip overlays, the
// advertised-rank full-combo markers and letters nested inside their backgrounds, the
// advertised-rank backgrounds, then the rank full-combo markers and letters nested inside their
// backgrounds, the rank backgrounds, and finally the two buttons.
static inline void MusicViewInstallSubviews(MusicView *self) {
    [self addSubview:self.imgView];
    [self addSubview:self.nameLabel];
    [self addSubview:self.artistNameLabel];
    for (UIView *chip in self.rankBgChipArray) {
        [self addSubview:chip];
    }
    [self.adRankBgBas addSubview:self.adRankFcBas];
    [self.adRankBgAdv addSubview:self.adRankFcAdv];
    [self.adRankBgExt addSubview:self.adRankFcExt];
    [self.adRankBgBas addSubview:self.adRankImgBas];
    [self.adRankBgAdv addSubview:self.adRankImgAdv];
    [self.adRankBgExt addSubview:self.adRankImgExt];
    [self addSubview:self.adRankBgBas];
    [self addSubview:self.adRankBgAdv];
    [self addSubview:self.adRankBgExt];
    [self.rankBgBas addSubview:self.rankFcBas];
    [self.rankBgAdv addSubview:self.rankFcAdv];
    [self.rankBgExt addSubview:self.rankFcExt];
    [self.rankBgBas addSubview:self.rankImgBas];
    [self.rankBgAdv addSubview:self.rankImgAdv];
    [self.rankBgExt addSubview:self.rankImgExt];
    [self addSubview:self.rankBgBas];
    [self addSubview:self.rankBgAdv];
    [self addSubview:self.rankBgExt];
    [self addSubview:self.btnPlaylistAction];
    [self addSubview:self.btnBgmSelect];
}

// Builds the artwork image view: black, aspect-scaled, with a subtle perspective transform and a
// one-point layer border (the colour is applied by the caller after the theme is known), and
// installs it via the setter.
static inline void
MusicViewBuildArtworkImageView(MusicView *self, double scale, double artworkSize) {
    const double edge = scale * artworkSize;
    self.imgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, edge, edge)];
    self.imgView.opaque = NO;
    self.imgView.backgroundColor = UIColor.blackColor;
    self.imgView.contentMode = UIViewContentModeScaleAspectFit;
    self.imgView.center = [self centerArtworkImg];
    // A subtle perspective transform: the identity with m34 set.
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = kArtworkPerspectiveM34;
    self.imgView.layer.transform = transform;
    self.imgView.layer.doubleSided = NO;
    self.imgView.layer.borderWidth = kArtworkBorderWidth;
    self.imgView.userInteractionEnabled = YES;
    self.imgView.exclusiveTouch = YES;
}

// Builds the name label, and on iPad the artist label, at their column-type baselines and installs
// them via the setters.
static inline void MusicViewBuildLabels(MusicView *self,
                                        double scale,
                                        double artworkSize,
                                        int colType,
                                        double labelWidth,
                                        UIColor *textColor) {
    const CGFloat nameHeight = self->isPad ? kNameLabelHeightPad : kNameLabelHeightPhone;
    self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, labelWidth, nameHeight)];
    self.nameLabel.opaque = NO;
    self.nameLabel.backgroundColor = UIColor.clearColor;
    self.nameLabel.font = [UIFont
        fontWithName:(!self->isPad && !self->isPhoneRetina) ? @"Helvetica" : @"Helvetica-Bold"
                size:self->isPad ? kNameFontSizePad : kNameFontSizePhone];
    self.nameLabel.textColor = textColor;
    self.nameLabel.textAlignment = NSTextAlignmentCenter;
    self.nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.nameLabel.contentMode = UIViewContentModeScaleToFill;
    const int *nameY = self->isPad ? kNameLabelYByColTypePad : kNameLabelYByColTypePhone;
    self.nameLabel.center =
        CGPointMake((double)((float)scale * (float)self->defaultWidth * 0.5f),
                    (double)((int)nameHeight >> 1) + scale * artworkSize + (double)nameY[colType]);
    if (self->isPad) {
        self.artistNameLabel =
            [[UILabel alloc] initWithFrame:CGRectMake(0, 0, labelWidth, kArtistLabelHeightPad)];
        self.artistNameLabel.opaque = NO;
        self.artistNameLabel.backgroundColor = UIColor.clearColor;
        self.artistNameLabel.font =
            [UIFont fontWithName:@"Helvetica"
                            size:self->isPad ? kArtistFontSizePad : kArtistFontSizePhone];
        self.artistNameLabel.textColor = textColor;
        self.artistNameLabel.textAlignment = NSTextAlignmentCenter;
        self.artistNameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        self.artistNameLabel.contentMode = UIViewContentModeScaleToFill;
        self.artistNameLabel.center = CGPointMake(
            (double)((float)scale * (float)self->defaultWidth * 0.5f),
            scale * artworkSize + (double)kArtistLabelYByColType[colType] + kArtistLabelExtraGap);
    }
}

@implementation MusicView

#pragma mark - Lifecycle

/** @ghidraAddress 0x44528 */
- (instancetype)initWithFrame:(CGRect)frame
                  artworkSize:(double)artworkSize
                      colType:(int)colType
                    labelDisp:(BOOL)labelDisp {
    const double scale = GetMusicCellScaleForColumnType(colType);
    defaultWidth = (int)frame.size.width;
    imageSize = artworkSize;
    currentScale = scale;
    const double labelWidth = frame.size.width * scale;
    self = [super initWithFrame:CGRectMake(frame.origin.x * scale,
                                           frame.origin.y * scale,
                                           frame.size.width * scale,
                                           frame.size.height * scale)];
    if (self) {
        self.multipleTouchEnabled = NO;
        self.opaque = NO;
        self.backgroundColor = UIColor.clearColor;

        JubeatAppDelegate *app = JubeatAppDelegate.appDelegate;
        isPad = app.isPad;
        artwork_size = artworkSize;
        isPhoneRetina = JubeatAppDelegate.appDelegate.isPhoneRetina;
        is4Inch = JubeatAppDelegate.appDelegate.deviceType == JubeatDeviceTypePhoneRetina4Inch;

        MusicViewBuildArtworkImageView(self, scale, artwork_size);

        // The artwork border and label text colour both depend on the theme.
        UIColor *borderColor;
        UIColor *textColor;
        switch (JubeatAppDelegate.appDelegate.currentTheme) {
        case JubeatThemeRipples:
            // The original used colorWithRed:0 green:0.72 blue:0.63 alpha:1.
            borderColor = [UIColor colorWithRed:0.0
                                          green:0.7200000286102295
                                           blue:0.6299999952316284
                                          alpha:1.0];
            textColor = UIColor.blackColor;
            break;
        case JubeatThemeKnit:
            borderColor = UIColor.blackColor; // colorWithRed:0 green:0 blue:0 alpha:1
            textColor = UIColor.blackColor;
            break;
        default:
            // The original used colorWithRed:0 green:0 blue:0.49 alpha:1.
            borderColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.49000000953674316 alpha:1.0];
            textColor = UIColor.whiteColor;
            break;
        }
        self.imgView.layer.borderColor = borderColor.CGColor;

        MusicViewBuildLabels(self, scale, artwork_size, colType, labelWidth, textColor);

        // The theme is re-read here for effect only; the result is discarded.
        if (JubeatAppDelegate.appDelegate.currentTheme != JubeatThemeRipples) {
            (void)JubeatAppDelegate.appDelegate.currentTheme; // Yes, the binary discards this.
        }

        MusicViewBuildRankStacks(self, colType, scale);
        MusicViewBuildActionButtons(self, scale);
        MusicViewInstallSubviews(self);

        self.autoresizesSubviews = YES;
        self.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
            UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin; // 0x3f
        self.imgView.autoresizesSubviews = YES;
        self.imgView.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
            UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin; // 0x3f

        if (!labelDisp) {
            self.nameLabel.alpha = 0.0;
            self.artistNameLabel.alpha = 0.0;
            [rankBgArray[0] setAlpha:0.0];
            [rankBgArray[1] setAlpha:0.0];
            [rankBgArray[2] setAlpha:0.0];
        }
        // The extreme column with an artist label starts with the artist hidden.
        if (colType == 2 && self.artistNameLabel) {
            self.artistNameLabel.alpha = 0.0;
        }

        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        tap.numberOfTapsRequired = 1;
        tap.numberOfTouchesRequired = 1;
        [self.imgView addGestureRecognizer:tap];

        UILongPressGestureRecognizer *press =
            [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                          action:@selector(handlePress:)];
        press.minimumPressDuration = 0.5;
        [self.imgView addGestureRecognizer:press];
    }
    return self;
}

#pragma mark - Colour

/** @ghidraAddress 0x443c8 */
- (UIColor *)getTextColor {
    const JubeatTheme theme = JubeatAppDelegate.appDelegate.currentTheme;
    const NSInteger customBgmID =
        [NSUserDefaults.standardUserDefaults integerForKey:@"PrefCustomBgmID"];
    if ((NSInteger)self.tuneInfo.tuneID == customBgmID) {
        // The original used colorWithRed:1 green:0.435 blue:0.835 alpha:1.
        return [UIColor colorWithRed:1.0
                               green:0.43529412150382996
                                blue:0.8352941274642944
                               alpha:1.0];
    }
    if (theme == JubeatThemeRipples) {
        return UIColor.blackColor;
    }
    if (theme == JubeatThemeKnit) {
        return UIColor.blackColor;
    }
    return UIColor.whiteColor;
}

/** @ghidraAddress 0x47ea8 */
- (void)refreshTextColor {
    UIColor *color = [self getTextColor];
    self.nameLabel.textColor = color;
    self.artistNameLabel.textColor = color;
}

#pragma mark - Geometry

/** @ghidraAddress 0x47ad0 */
- (CGPoint)centerArtworkImg {
    return CGPointMake((double)defaultWidth * currentScale * 0.5, currentScale * imageSize * 0.5);
}

#pragma mark - Tune data

/** @ghidraAddress 0x47b14 */
- (void)setInfo:(TuneInfo *)info bArtistNameDisp:(BOOL)bArtistNameDisp {
    self.tuneInfo = info;
    NSMutableArray *owners = [LatelyJcfListManager.sharedManager getJcfOwnerList];
    if (owners.count != 0) {
        NSUInteger i = 0;
        do {
            if ((int)self.tuneInfo.tuneID == [[owners[i] objectAtIndex:0] integerValue]) {
                [self addDownloadNotice];
                break;
            }
            ++i;
        } while (i < owners.count);
    }

    if (info.name == nil) {
        self.nameLabel.text = @"";
    } else {
        self.nameLabel.text = info.name;
    }
    if (bArtistNameDisp) {
        if (info.artist == nil) {
            self.artistNameLabel.text = @"";
        } else {
            self.artistNameLabel.text = info.artist;
        }
    }

    UIColor *color = [self getTextColor];
    self.nameLabel.textColor = color;
    self.artistNameLabel.textColor = color;
}

/** @ghidraAddress 0x4ab68 */
- (void)setInfo:(TuneInfo *)info {
    [self setInfo:info bArtistNameDisp:isPad];
    self.tuneInfo = info;
}

/** @ghidraAddress 0x47f50 */
- (void)setExtendInfo:(TuneInfo *)info {
    self.extendTuneInfo = nil;
    // The three hold-marker chip overlays start hidden.
    [adRankBgChipArray[2] setHidden:YES];
    [adRankBgChipArray[1] setHidden:YES];
    [adRankBgChipArray[0] setHidden:YES];
    if (info != nil) {
        if (info.extendFlag & 1) {
            [adRankBgChipArray[2] setHidden:NO];
        }
        if ((info.extendFlag >> 1) & 1) {
            [adRankBgChipArray[1] setHidden:NO];
        }
        if ((info.extendFlag >> 2) & 1) {
            [adRankBgChipArray[0] setHidden:NO];
        }
        self.extendTuneInfo = info;
    }
}

/** @ghidraAddress 0x4abd8 */
- (void)clearInfo {
    self.tuneInfo = nil;
    UIImageView *bas = self.rankBgBas;
    UIImageView *adv = self.rankBgAdv;
    UIImageView *ext = self.rankBgExt;
    ext.hidden = YES;
    adv.hidden = YES;
    bas.hidden = YES;
    UIImageView *adBas = self.adRankBgBas;
    UIImageView *adAdv = self.adRankBgAdv;
    UIImageView *adExt = self.adRankBgExt;
    adExt.hidden = YES;
    adAdv.hidden = YES;
    adBas.hidden = YES;
}

#pragma mark - Score rendering

/** @ghidraAddress 0x4ae30 */
- (void)setScore:(ScoreRecord *)record {
    unsigned int hideFcBas;
    unsigned int hideFcAdv;
    unsigned int hideFcExt;
    if (![ScoreRecord checkScore:record]) {
        hideFcExt = 0;
        hideFcAdv = 0;
        hideFcBas = 0;
    } else {
        int scoBas = [record.scoBas intValue];
        int scoAdv = [record.scoAdv intValue];
        int scoExt = [record.scoExt intValue];
        BOOL fcBas = [record.fcBas boolValue];
        BOOL fcAdv = [record.fcAdv boolValue];
        BOOL fcExt = [record.fcExt boolValue];
        hideFcBas = fcBas ? 1 : ([record.pmBas intValue] == 0);
        hideFcAdv = fcAdv ? 1 : ([record.pmAdv intValue] == 0);
        hideFcExt = fcExt ? 1 : ([record.pmExt intValue] == 0);

        if (scoBas >= 0) {
            self.rankImgBas.image = GetRankImageForPoint(scoBas);
            self.rankBgBas.hidden = NO;
        }
        if (scoAdv >= 0) {
            self.rankImgAdv.image = GetRankImageForPoint(scoAdv);
            self.rankBgAdv.hidden = NO;
        }
        if (scoExt >= 0) {
            self.rankImgExt.image = GetRankImageForPoint(scoExt);
            self.rankBgExt.hidden = NO;
        }
    }
    self.rankFcBas.hidden = !hideFcBas;
    self.rankFcAdv.hidden = !hideFcAdv;
    self.rankFcExt.hidden = !hideFcExt;
}

/** @ghidraAddress 0x4814c */
- (void)setExtendScore:(ScoreRecord *)record {
    unsigned int showFcBas = 1;
    unsigned int showFcAdv = 1;
    unsigned int showFcExt = 1;
    if ([ScoreRecord checkScore:record]) {
        int scoBas = [record.scoBas intValue];
        int scoAdv = [record.scoAdv intValue];
        int scoExt = [record.scoExt intValue];
        BOOL fcBas = [record.fcBas boolValue];
        BOOL fcAdv = [record.fcAdv boolValue];
        BOOL fcExt = [record.fcExt boolValue];
        unsigned int pmZeroBas = fcBas ? 0 : ([record.pmBas intValue] == 0);
        unsigned int pmZeroAdv = fcAdv ? 0 : ([record.pmAdv intValue] == 0);
        unsigned int pmZeroExt = fcExt ? 0 : ([record.pmExt intValue] == 0);
        unsigned int markBas = (unsigned int)fcBas | pmZeroBas;
        unsigned int markAdv = (unsigned int)fcAdv | pmZeroAdv;
        unsigned int markExt = (unsigned int)fcExt | pmZeroExt;
        // When any difficulty newly qualifies for a perfect-master mark, the record's full-combo
        // flags are rewritten so the mark persists.
        if ((pmZeroBas | pmZeroAdv | pmZeroExt) == 1) {
            record.fcBas = @(markBas);
            record.fcAdv = @(markAdv);
            record.fcExt = @(markExt);
        }
        if (scoBas >= 0) {
            self.adRankImgBas.image = GetRankImageForPoint(scoBas);
            self.adRankBgBas.hidden = NO;
        }
        showFcBas = markBas ^ 1;
        showFcAdv = markAdv ^ 1;
        showFcExt = markExt ^ 1;
        if (scoAdv >= 0) {
            self.adRankImgAdv.image = GetRankImageForPoint(scoAdv);
            self.adRankBgAdv.hidden = NO;
        }
        if (scoExt >= 0) {
            self.adRankImgExt.image = GetRankImageForPoint(scoExt);
            self.adRankBgExt.hidden = NO;
        }
    }
    self.adRankFcBas.hidden = showFcBas;
    self.adRankFcAdv.hidden = showFcAdv;
    self.adRankFcExt.hidden = showFcExt;
}

#pragma mark - Rating chips

/** @ghidraAddress 0x48900 */
- (void)setRatingChipHidden:(int)mode {
    if (mode == kRatingChipModeHidden) {
        for (NSUInteger i = 0; i < self.rankBgChipArray.count; ++i) {
            [self.rankBgChipArray[i] setAlpha:0.0];
        }
        for (NSUInteger i = 0; i < adRankBgArray.count; ++i) {
            [adRankBgArray[i] setAlpha:0.0];
        }
        for (NSUInteger i = 0; i < rankBgArray.count; ++i) {
            [rankBgArray[i] setAlpha:0.0];
        }
    } else if (mode == kRatingChipModeAdRank) {
        for (NSUInteger i = 0; i < self.rankBgChipArray.count; ++i) {
            [self.rankBgChipArray[i] setAlpha:0.0];
        }
        for (NSUInteger i = 0; i < adRankBgArray.count; ++i) {
            [adRankBgArray[i] setAlpha:1.0];
        }
        for (NSUInteger i = 0; i < rankBgArray.count; ++i) {
            [rankBgArray[i] setAlpha:1.0];
        }
    } else if (mode == kRatingChipModeAll) {
        for (NSUInteger i = 0; i < self.rankBgChipArray.count; ++i) {
            [self.rankBgChipArray[i] setAlpha:1.0];
        }
        for (NSUInteger i = 0; i < adRankBgArray.count; ++i) {
            [adRankBgArray[i] setAlpha:1.0];
        }
        for (NSUInteger i = 0; i < rankBgArray.count; ++i) {
            [rankBgArray[i] setAlpha:1.0];
        }
    }
}

#pragma mark - Label visibility and scaling

/** @ghidraAddress 0x4ad48 */
- (void)showNameAndArtist:(BOOL)show {
    self.nameLabel.alpha = show ? 1.0 : 0.0;
    if (isPad && (int)(currentScale * kArtistScaleThreshold) > kArtistScaleThresholdValue) {
        self.artistNameLabel.alpha = show ? 1.0 : 0.0;
    }
}

/** @ghidraAddress 0x48da4 */
- (void)scaleChange:(int)colType {
    __weak UILabel *weakNameLabel = self.nameLabel;
    __weak UILabel *weakArtistLabel = self.artistNameLabel;
    __weak NSMutableArray *weakRankBgArray = rankBgArray;
    self.imgView.center = [self centerArtworkImg];
    __weak NSMutableArray *weakAdRankBgArray = adRankBgArray;
    __weak NSMutableArray *weakChipArray = self.rankBgChipArray;
    [UIView animateWithDuration:kScaleFadeDuration
                     animations:^{
                       /** @ghidraAddress 0x4901c */
                       [weakNameLabel setAlpha:0.0];
                       [weakArtistLabel setAlpha:0.0];
                       [weakRankBgArray[0] setAlpha:0.0];
                       [weakRankBgArray[1] setAlpha:0.0];
                       [weakRankBgArray[2] setAlpha:0.0];
                       for (NSUInteger i = 0; i < weakAdRankBgArray.count; ++i) {
                           [weakAdRankBgArray[i] setAlpha:0.0];
                       }
                       for (NSUInteger i = 0; i < weakChipArray.count; ++i) {
                           [weakChipArray[i] setAlpha:0.0];
                       }
                     }
                     completion:^(BOOL __attribute__((unused)) finished){
                         /** @ghidraAddress 0x4935c */
                     }];
}

/** @ghidraAddress 0x49360 */
- (void)fadeoutLabel {
    __weak UILabel *weakNameLabel = self.nameLabel;
    __weak UILabel *weakArtistLabel = self.artistNameLabel;
    __weak NSMutableArray *weakRankBgArray = rankBgArray;
    [self hidePlaylistActionButton];
    self.imgView.center = [self centerArtworkImg];
    __weak NSMutableArray *weakAdRankBgArray = adRankBgArray;
    __weak NSMutableArray *weakChipArray = self.rankBgChipArray;
    MusicView *squareSelf = self;
    [UIView animateWithDuration:kSquareFadeDuration
        animations:^{
          /** @ghidraAddress 0x49628 */
          [weakNameLabel setAlpha:0.0];
          [weakArtistLabel setAlpha:0.0];
          [weakRankBgArray[0] setAlpha:0.0];
          [weakRankBgArray[1] setAlpha:0.0];
          [weakRankBgArray[2] setAlpha:0.0];
          for (NSUInteger i = 0; i < weakAdRankBgArray.count; ++i) {
              [weakAdRankBgArray[i] setAlpha:0.0];
          }
          for (NSUInteger i = 0; i < weakChipArray.count; ++i) {
              [weakChipArray[i] setAlpha:0.0];
          }
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x49968 */
          // Square the artwork by forcing its height to its width. The binary reads the width
          // for both the width and height slots; size.height is never used.
          CGRect frame = squareSelf.imgView.frame;
          squareSelf.imgView.frame =
              CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, frame.size.width);
        }];
}

/** @ghidraAddress 0x49ab4 */
- (void)switchLabel:(int)colType {
    const double scale = GetMusicCellScaleForColumnType(colType);
    __weak UILabel *weakNameLabel = self.nameLabel;
    __weak UILabel *weakArtistLabel = self.artistNameLabel;
    currentScale = scale;
    const int width = (int)(scale * (double)defaultWidth);
    const CGFloat nameHeight = isPad ? kNameLabelHeightPad : kNameLabelHeightPhone;
    self.nameLabel.frame = CGRectMake(0, 0, (double)width, nameHeight);
    const int *nameY = isPad ? kNameLabelYByColTypePad : kNameLabelYByColTypePhone;
    self.nameLabel.center =
        CGPointMake((double)(width >> 1),
                    (double)((int)nameHeight >> 1) + scale * artwork_size + (double)nameY[colType]);
    self.artistNameLabel.frame = CGRectMake(0, 0, (double)width, kArtistLabelHeightPad);
    self.artistNameLabel.center = CGPointMake(
        (double)(width >> 1),
        scale * artwork_size + (double)kArtistLabelYByColType[colType] + kArtistLabelExtraGap);

    // Rank-word background/full-combo image basenames vary by theme.
    NSString *basicName;
    const JubeatTheme theme = JubeatAppDelegate.appDelegate.currentTheme;
    if (theme == JubeatThemeRipples) {
        basicName = @"rank_basic_rpl";
    } else if (JubeatAppDelegate.appDelegate.currentTheme == JubeatThemeKnit) {
        basicName = @"rank_basic_knt";
    } else {
        basicName = @"rank_basic";
    }
    UIImage *rankImage = [[ImageCache sharedCache] getResPNG:basicName];
    UIImage *fullImage = [[ImageCache sharedCache] getResPNG:@"rank_full"];

    const double stackScale = isPad ? 1.0 : scale;
    const double fcOffset = scale * kRankFcOffset;
    const int *firstY = isPad ? kRankFirstYByColTypePad : kRankFirstYByColTypePhone;
    const int *stepY = isPad ? kRankStepYByColTypePad : kRankStepYByColTypePhone;

    // Re-lay the three rank stacks.
    for (int i = 0; i < kDifficultyCount; ++i) {
        const double chipY = (double)(firstY[colType] + stepY[colType] * i);
        [rankBgArray[i] setFrame:CGRectMake(scale * kRankBaseXByIsPad[isPad ? 1 : 0],
                                            chipY,
                                            stackScale * rankImage.size.width,
                                            stackScale * rankImage.size.height)];
        [rankImgArray[i] setFrame:CGRectMake(0,
                                             0,
                                             stackScale * rankImage.size.width,
                                             stackScale * rankImage.size.height)];
        [rankFcArray[i] setFrame:CGRectMake(fcOffset,
                                            fcOffset,
                                            stackScale * fullImage.size.width,
                                            stackScale * fullImage.size.height)];
    }

    // Re-lay the frame/hold overlays per difficulty.
    const double hldX = (double)(float)(scale * scale * (isPad ? kRankChipHldScale : 0.0f));
    int extY = firstY[colType];
    const double orgX = scale * kRankBaseXByIsPad[isPad ? 1 : 0];
    [self.rankBgOrgExt setFrame:CGRectMake(orgX,
                                           (double)extY,
                                           stackScale * rankImage.size.width,
                                           stackScale * kRankChipHldScale)];
    [self.rankBgHldExt setFrame:CGRectMake(hldX,
                                           (double)extY,
                                           stackScale * rankImage.size.width,
                                           stackScale * kRankChipHldScale)];
    int advY = extY + stepY[colType];
    [self.rankBgOrgAdv setFrame:CGRectMake(orgX,
                                           (double)advY,
                                           stackScale * rankImage.size.width,
                                           stackScale * kRankChipHldScale)];
    [self.rankBgHldAdv setFrame:CGRectMake(hldX,
                                           (double)advY,
                                           stackScale * rankImage.size.width,
                                           stackScale * kRankChipHldScale)];
    int basY = advY + stepY[colType];
    [self.rankBgOrgBas setFrame:CGRectMake(orgX,
                                           (double)basY,
                                           stackScale * rankImage.size.width,
                                           stackScale * kRankChipHldScale)];
    [self.rankBgHldBas setFrame:CGRectMake(hldX,
                                           (double)basY,
                                           stackScale * rankImage.size.width,
                                           stackScale * kRankChipHldScale)];

    // Re-lay the three advertised-rank stacks.
    for (int i = 0; i < kDifficultyCount; ++i) {
        const double chipY = (double)(firstY[colType] + stepY[colType] * i);
        [adRankBgArray[i] setFrame:CGRectMake(orgX,
                                              chipY,
                                              stackScale * rankImage.size.width,
                                              stackScale * kRankChipHldScale)];
        [adRankImgArray[i] setFrame:CGRectMake(0,
                                               0,
                                               stackScale * rankImage.size.width,
                                               stackScale * rankImage.size.height)];
        [adRankFcArray[i] setFrame:CGRectMake(fcOffset,
                                              fcOffset,
                                              stackScale * fullImage.size.width,
                                              stackScale * fullImage.size.height)];
    }

    __weak NSMutableArray *weakRankBgArray = rankBgArray;
    __weak NSMutableArray *weakAdRankBgArray = adRankBgArray;
    __weak NSMutableArray *weakChipArray = self.rankBgChipArray;
    const NSInteger labelDisp =
        [NSUserDefaults.standardUserDefaults integerForKey:@"PrefRatingChipType"];
    MusicView *gateSelf = self;
    const double gateScale = scale;
    [UIView animateWithDuration:kScaleFadeDuration
                     animations:^{
                       /** @ghidraAddress 0x4a7b0 */
                       [weakNameLabel setAlpha:1.0];
                       if (gateSelf->isPad &&
                           (int)(gateScale * kArtistScaleThreshold) > kArtistScaleThresholdValue) {
                           [weakArtistLabel setAlpha:1.0];
                       }
                       if (labelDisp != 0) {
                           [weakRankBgArray[0] setAlpha:1.0];
                       }
                       if (labelDisp != 0) {
                           [weakRankBgArray[1] setAlpha:1.0];
                       }
                       if (labelDisp != 0) {
                           [weakRankBgArray[2] setAlpha:1.0];
                       }
                       if (labelDisp == kRatingChipModeAll) {
                           for (NSUInteger i = 0; i < weakAdRankBgArray.count; ++i) {
                               [weakAdRankBgArray[i] setAlpha:1.0];
                           }
                           for (NSUInteger i = 0; i < weakChipArray.count; ++i) {
                               [weakChipArray[i] setAlpha:1.0];
                           }
                       }
                     }
                     completion:^(BOOL __attribute__((unused)) finished){
                         /** @ghidraAddress 0x4ab64 */
                     }];

    // Re-anchor the two buttons to the (re-read) artwork frame.
    const double edge = scale * kActionButtonSize;
    CGRect artFrame = self.imgView.frame;
    self.btnPlaylistAction.frame = CGRectMake(artFrame.origin.x - scale * kPlaylistButtonInset,
                                              artFrame.origin.y - scale * kPlaylistButtonInset,
                                              edge,
                                              edge);
    CGRect artFrame2 = self.imgView.frame;
    self.btnBgmSelect.frame =
        CGRectMake((artFrame2.origin.x + artFrame2.size.width) - scale * kBgmButtonInset,
                   (artFrame2.origin.y + artFrame2.size.height) - scale * kBgmButtonInset,
                   edge,
                   edge);
}

#pragma mark - Buttons

/** @ghidraAddress 0x4b2e4 */
- (void)hidePlaylistActionButton {
    if (!self.btnPlaylistAction.isHidden) {
        self.btnPlaylistAction.enabled = NO;
        if (self.btnPlaylistAction.alpha <= 0.0) {
            self.btnPlaylistAction.hidden = YES;
        } else {
            __weak MusicView *weakSelf = self;
            [UIView animateWithDuration:kScaleFadeDuration
                animations:^{
                  /** @ghidraAddress 0x4b688 */
                  [weakSelf.btnPlaylistAction setAlpha:0.0];
                }
                completion:^(BOOL __attribute__((unused)) finished) {
                  /** @ghidraAddress 0x4b6f4 */
                  [weakSelf.btnPlaylistAction setEnabled:YES];
                }];
        }
    }
    if (!self.btnBgmSelect.isHidden) {
        self.btnBgmSelect.enabled = NO;
        if (self.btnBgmSelect.alpha <= 0.0) {
            self.btnBgmSelect.hidden = YES;
        } else {
            __weak MusicView *weakSelf = self;
            [UIView animateWithDuration:kScaleFadeDuration
                animations:^{
                  /** @ghidraAddress 0x4b760 */
                  [weakSelf.btnBgmSelect setAlpha:0.0];
                }
                completion:^(BOOL __attribute__((unused)) finished) {
                  /** @ghidraAddress 0x4b7cc */
                  [weakSelf.btnBgmSelect setEnabled:YES];
                }];
        }
    }
}

#pragma mark - Gestures

/** @ghidraAddress 0x4b838 */
- (void)handleTap:(UITapGestureRecognizer *)recognizer {
    if ([self.delegate respondsToSelector:@selector(musicViewTapped:)]) {
        [self removeDownloadNotice];
        [self.delegate musicViewTapped:self];
    }
}

/** @ghidraAddress 0x4b9b4 */
- (void)handlePress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan) {
        return;
    }
    if ([self.delegate respondsToSelector:@selector(musicViewPressed:)]) {
        [self.delegate musicViewPressed:self];
    }
    if ([self.delegate respondsToSelector:@selector(musicViewGetPlaylistActionType:)]) {
        BOOL inPlaylist = [self.delegate musicViewGetPlaylistActionType:self];
        UIImage *up;
        UIImage *down;
        if (!inPlaylist) {
            up = [[ImageCache sharedCache] getResPNG:@"pl_add_up"];
            down = [[ImageCache sharedCache] getResPNG:@"pl_add_down"];
        } else {
            up = [[ImageCache sharedCache] getResPNG:@"pl_remove_up"];
            down = [[ImageCache sharedCache] getResPNG:@"pl_remove_down"];
        }
        if (down != nil && up != nil) {
            [self.btnPlaylistAction setImage:up forState:UIControlStateNormal];
            [self.btnPlaylistAction setImage:down forState:UIControlStateHighlighted];
            self.btnPlaylistAction.hidden = NO;
            self.btnPlaylistAction.enabled = NO;
            self.btnPlaylistAction.alpha = 0.0;
            self.btnPlaylistAction.transform =
                CGAffineTransformMakeScale(kButtonPressScale, kButtonPressScale);
            __weak MusicView *weakSelf = self;
            [UIView animateWithDuration:kButtonPressDuration
                animations:^{
                  /** @ghidraAddress 0x4c1ac */
                  [weakSelf.btnPlaylistAction setAlpha:1.0];
                  [weakSelf.btnPlaylistAction setTransform:CGAffineTransformIdentity];
                }
                completion:^(BOOL __attribute__((unused)) finished) {
                  /** @ghidraAddress 0x4c28c */
                  [weakSelf.btnPlaylistAction setEnabled:YES];
                }];
        }
    }

    NSString *prefix = [self bgmImagePrefix];
    UIImage *bgmUp =
        [[ImageCache sharedCache] getResPNG:[NSString stringWithFormat:@"%@up", prefix]];
    UIImage *bgmDown =
        [[ImageCache sharedCache] getResPNG:[NSString stringWithFormat:@"%@down", prefix]];
    if (bgmUp != nil && bgmDown != nil) {
        [self.btnBgmSelect setImage:bgmUp forState:UIControlStateNormal];
        [self.btnBgmSelect setImage:bgmDown forState:UIControlStateHighlighted];
        self.btnBgmSelect.hidden = NO;
        self.btnBgmSelect.enabled = NO;
        self.btnBgmSelect.alpha = 0.0;
        self.btnBgmSelect.transform =
            CGAffineTransformMakeScale(kButtonPressScale, kButtonPressScale);
        __weak MusicView *weakSelf = self;
        [UIView animateWithDuration:kButtonPressDuration
            animations:^{
              /** @ghidraAddress 0x4c2f8 */
              [weakSelf.btnBgmSelect setAlpha:1.0];
              [weakSelf.btnBgmSelect setTransform:CGAffineTransformIdentity];
            }
            completion:^(BOOL __attribute__((unused)) finished) {
              /** @ghidraAddress 0x4c3d8 */
              [weakSelf.btnBgmSelect setEnabled:YES];
            }];
    }
}

/** @ghidraAddress 0x4b8f4 */
- (NSString *)bgmImagePrefix {
    const NSInteger customBgmID =
        [NSUserDefaults.standardUserDefaults integerForKey:@"PrefCustomBgmID"];
    if ((NSInteger)self.tuneInfo.tuneID == customBgmID) {
        return @"bgm_stop_";
    }
    return @"bgm_set_";
}

/** @ghidraAddress 0x4c444 */
- (void)tapPlaylistAction:(id)sender {
    if ([self.delegate respondsToSelector:@selector(musicViewPlaylistAction:)]) {
        [self.delegate musicViewPlaylistAction:self];
    }
}

/** @ghidraAddress 0x4c4f0 */
- (void)tapBgmSelect:(id)sender {
    if ([self.delegate respondsToSelector:@selector(musicViewSelectBgmAction:)]) {
        [self.delegate musicViewSelectBgmAction:self];
    }
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    __weak MusicView *weakSelf = self;
    MusicView *strongSelf = self;
    [UIView animateWithDuration:kButtonPressDuration
        animations:^{
          /** @ghidraAddress 0x4c6ec */
          [weakSelf.btnBgmSelect setAlpha:0.0];
          [strongSelf.btnBgmSelect
              setTransform:CGAffineTransformMakeScale(kButtonPressScale, kButtonPressScale)];
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x4c810 */
          NSString *prefix = [strongSelf bgmImagePrefix];
          UIImage *up =
              [[ImageCache sharedCache] getResPNG:[NSString stringWithFormat:@"%@up", prefix]];
          UIImage *down =
              [[ImageCache sharedCache] getResPNG:[NSString stringWithFormat:@"%@down", prefix]];
          if (up != nil && down != nil) {
              [strongSelf.btnBgmSelect setImage:up forState:UIControlStateNormal];
              [strongSelf.btnBgmSelect setImage:down forState:UIControlStateHighlighted];
          }
          [UIView animateWithDuration:kButtonPressDuration
              animations:^{
                /** @ghidraAddress 0x4ca88 */
                [weakSelf.btnBgmSelect setAlpha:1.0];
                [strongSelf.btnBgmSelect setTransform:CGAffineTransformIdentity];
              }
              completion:^(BOOL __attribute__((unused)) innerFinished) {
                /** @ghidraAddress 0x4cb98 */
                [UIApplication.sharedApplication endIgnoringInteractionEvents];
              }];
        }];
}

#pragma mark - Download notice

/** @ghidraAddress 0x4cc38 */
- (void)addDownloadNotice {
    if (self.jcfIcon != nil) {
        return;
    }
    UIImage *icon = [[ImageCache sharedCache] getResPNG:@"edit_dl_icon"];
    self.jcfIcon = [[UIImageView alloc] initWithImage:icon];
    CGRect artFrameX = self.imgView.frame;
    CGRect artFrameY = self.imgView.frame;
    self.jcfIcon.frame = CGRectMake(artFrameX.origin.x + kDownloadIconOffsetX,
                                    artFrameY.origin.y + kDownloadIconOffsetY + kDownloadIconExtraY,
                                    kDownloadIconSize,
                                    kDownloadIconSize);
    [self addSubview:self.jcfIcon];
}

/** @ghidraAddress 0x4ce30 */
- (void)removeDownloadNotice {
    if (self.jcfIcon != nil) {
        [self.jcfIcon removeFromSuperview];
        self.jcfIcon = nil;
        NSString *owner = [NSString stringWithFormat:@"%d", self.tuneInfo.tuneID];
        [LatelyJcfListManager.sharedManager removeJcfOwner:owner];
    }
}

@end
