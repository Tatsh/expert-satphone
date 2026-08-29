/**
 * @file
 * The music-select song tile.
 *
 * Reconstructed from Ghidra program Jubeat (class MusicView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The superclass is @c UIView, from
 * the @c initWithFrame: chain-up at 0x44528.
 *
 * The tile draws its artwork, name and artist labels, and a per-difficulty rank background, rank
 * image, and full-combo image stack (basic, advanced, and extreme), plus advertised-rank variants
 * of each, through @c UIImageView subviews rather than the OpenGL @c Texture2D path. It also hosts
 * a jubeatLab-download icon, playlist and BGM-select buttons, and rating chips.
 */

#import <UIKit/UIKit.h>

@class MusicView;
@class ScoreRecord;
@class TuneInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * What a hosting controller learns from a music tile's gestures and buttons.
 */
@protocol MusicViewDelegate <NSObject>

@optional

/**
 * The tile was tapped.
 * @param view The tapped tile.
 */
- (void)musicViewTapped:(nonnull MusicView *)view;

/**
 * The tile received a long press.
 * @param view The pressed tile.
 */
- (void)musicViewPressed:(nonnull MusicView *)view;

/**
 * Whether the tile's tune is already in the playlist, choosing the remove artwork over add.
 * @param view The tile asking.
 * @return @c YES to show the remove button, @c NO to show the add button.
 */
- (BOOL)musicViewGetPlaylistActionType:(nonnull MusicView *)view;

/**
 * The playlist add/remove button was tapped.
 * @param view The tile whose button fired.
 */
- (void)musicViewPlaylistAction:(nonnull MusicView *)view;

/**
 * The BGM-select button was tapped.
 * @param view The tile whose button fired.
 */
- (void)musicViewSelectBgmAction:(nonnull MusicView *)view;

@end

/**
 * A song tile: artwork, labels, and per-difficulty rank and full-combo image stacks.
 */
@interface MusicView : UIView

/**
 * Builds the tile at a device- and column-scaled frame.
 *
 * The incoming frame and artwork size are multiplied by the column type's cell scale
 * (@c GetMusicCellScaleForColumnType). Three device idioms drive the layout: iPad, retina iPhone,
 * and the four-inch iPhone, read from the app delegate. The artwork image view carries a subtle
 * perspective transform (m34 of @c -0.001) and a themed one-point border, and the labels, rank
 * stacks, and two action buttons are laid out and installed as subviews.
 *
 * @param frame The unscaled frame.
 * @param artworkSize The unscaled artwork edge length.
 * @param colType The music-select column type, an index into the layout tables.
 * @param labelDisp Whether the name and artist labels start visible.
 * @return The initialised tile.
 * @ghidraAddress 0x44528
 */
- (instancetype)initWithFrame:(CGRect)frame
                  artworkSize:(double)artworkSize
                      colType:(int)colType
                    labelDisp:(BOOL)labelDisp;

/**
 * The centre point of the artwork image view for the current scale.
 * @return The centre in the tile's coordinate space.
 * @ghidraAddress 0x47ad0
 */
- (CGPoint)centerArtworkImg;

/**
 * The label text colour for the current theme and custom-BGM selection.
 *
 * When the tile's tune is the current custom BGM the colour is a highlight
 * (red 1.0, green 0.435, blue 0.835). Otherwise the ripples and knit themes use black and the
 * original theme uses white.
 *
 * @return The label colour.
 * @ghidraAddress 0x443c8
 */
- (nonnull UIColor *)getTextColor;

/**
 * Re-applies @c getTextColor to both labels.
 * @ghidraAddress 0x47ea8
 */
- (void)refreshTextColor;

/**
 * Sets the tune, name, and (optionally) artist text, and refreshes the label colour.
 *
 * If the tune already appears in the recently-downloaded jubeatLab list, the download notice is
 * shown.
 *
 * @param info The tune to display.
 * @param bArtistNameDisp Whether to fill in the artist label.
 * @ghidraAddress 0x47b14
 */
- (void)setInfo:(nullable TuneInfo *)info bArtistNameDisp:(BOOL)bArtistNameDisp;

/**
 * Sets the tune, showing the artist label only on iPad.
 * @param info The tune to display.
 * @ghidraAddress 0x4ab68
 */
- (void)setInfo:(nullable TuneInfo *)info;

/**
 * Reveals the advertised-extend rank chips whose extend flags are set.
 * @param info The extend tune whose flags select which chips to show, or @c nil to hide all three.
 * @ghidraAddress 0x47f50
 */
- (void)setExtendInfo:(nullable TuneInfo *)info;

/**
 * Renders the advertised-rank images and full-combo markers from an extend score.
 * @param record The score record.
 * @ghidraAddress 0x4814c
 */
- (void)setExtendScore:(nullable ScoreRecord *)record;

/**
 * Renders the rank images and full-combo markers from a score.
 * @param record The score record.
 * @ghidraAddress 0x4ae30
 */
- (void)setScore:(nullable ScoreRecord *)record;

/**
 * Sets the alpha of the rank, advertised-rank, and chip stacks to a hidden state.
 * @param mode 0 hides all, 1 shows the advertised and rank stacks, 2 shows every stack.
 * @ghidraAddress 0x48900
 */
- (void)setRatingChipHidden:(int)mode;

/**
 * Rescales the tile for the given column type, crossfading the labels and rank chips in.
 * @param colType The music-select column type to scale to.
 * @ghidraAddress 0x48da4
 */
- (void)scaleChange:(int)colType;

/**
 * Fades the labels and rank chips out and squares the artwork image view.
 * @ghidraAddress 0x49360
 */
- (void)fadeoutLabel;

/**
 * Rescales for a column type, animating the labels and rank chips across the change.
 * @param colType The music-select column type to switch to.
 * @ghidraAddress 0x49ab4
 */
- (void)switchLabel:(int)colType;

/**
 * Clears the tune and hides every rank background.
 * @ghidraAddress 0x4abd8
 */
- (void)clearInfo;

/**
 * Shows or hides the name label, and on iPad at a large scale the artist label too.
 * @param show Whether the labels are shown.
 * @ghidraAddress 0x4ad48
 */
- (void)showNameAndArtist:(BOOL)show;

/**
 * Fades out and disables the playlist and BGM-select buttons.
 * @ghidraAddress 0x4b2e4
 */
- (void)hidePlaylistActionButton;

/**
 * Tap handler: notifies the delegate and clears any download notice.
 * @param recognizer The tap recogniser.
 * @ghidraAddress 0x4b838
 */
- (void)handleTap:(nullable UITapGestureRecognizer *)recognizer;

/**
 * The BGM-artwork basename prefix for the current tune (@c "bgm_stop_" when selected,
 *        else @c "bgm_set_").
 * @return The prefix string.
 * @ghidraAddress 0x4b8f4
 */
- (nonnull NSString *)bgmImagePrefix;

/**
 * Long-press handler: notifies the delegate and reveals the playlist and BGM buttons.
 * @param recognizer The long-press recogniser.
 * @ghidraAddress 0x4b9b4
 */
- (void)handlePress:(nullable UILongPressGestureRecognizer *)recognizer;

/**
 * Fires @c musicViewPlaylistAction: on the delegate.
 * @param sender The button.
 * @ghidraAddress 0x4c444
 */
- (void)tapPlaylistAction:(nullable id)sender;

/**
 * Fires @c musicViewSelectBgmAction: and animates the button, ignoring interaction events
 *        for the duration.
 * @param sender The button.
 * @ghidraAddress 0x4c4f0
 */
- (void)tapBgmSelect:(nullable id)sender;

/**
 * Adds the jubeatLab download icon over the artwork, once.
 * @ghidraAddress 0x4cc38
 */
- (void)addDownloadNotice;

/**
 * Removes the jubeatLab download icon and forgets the tune's recent-download ownership.
 * @ghidraAddress 0x4ce30
 */
- (void)removeDownloadNotice;

#pragma mark - Properties

/** The artwork image view. */
@property(nonatomic, strong, nullable) UIImageView *imgView;
/** The tune title label. */
@property(nonatomic, strong, nullable) UILabel *nameLabel;
/** The artist label. */
@property(nonatomic, strong, nullable) UILabel *artistNameLabel;
/** The playlist add/remove button. */
@property(nonatomic, strong, nullable) UIButton *btnPlaylistAction;
/** The BGM-select button. */
@property(nonatomic, strong, nullable) UIButton *btnBgmSelect;
/** The displayed tune. */
@property(nonatomic, strong, nullable) TuneInfo *tuneInfo;
/** The extend tune whose flags reveal the chip overlays. */
@property(nonatomic, strong, nullable) TuneInfo *extendTuneInfo;
/** The jubeatLab download icon, present only while the notice is shown. */
@property(nonatomic, strong, nullable) UIImageView *jcfIcon;

/** The basic-difficulty rank background. */
@property(nonatomic, strong, nullable) UIImageView *rankBgBas;
/** The advanced-difficulty rank background. */
@property(nonatomic, strong, nullable) UIImageView *rankBgAdv;
/** The extreme-difficulty rank background. */
@property(nonatomic, strong, nullable) UIImageView *rankBgExt;
/** The basic-difficulty rank letter. */
@property(nonatomic, strong, nullable) UIImageView *rankImgBas;
/** The advanced-difficulty rank letter. */
@property(nonatomic, strong, nullable) UIImageView *rankImgAdv;
/** The extreme-difficulty rank letter. */
@property(nonatomic, strong, nullable) UIImageView *rankImgExt;
/** The basic-difficulty full-combo marker. */
@property(nonatomic, strong, nullable) UIImageView *rankFcBas;
/** The advanced-difficulty full-combo marker. */
@property(nonatomic, strong, nullable) UIImageView *rankFcAdv;
/** The extreme-difficulty full-combo marker. */
@property(nonatomic, strong, nullable) UIImageView *rankFcExt;
/** The basic-difficulty frame overlay. */
@property(nonatomic, strong, nullable) UIImageView *rankBgOrgBas;
/** The advanced-difficulty frame overlay. */
@property(nonatomic, strong, nullable) UIImageView *rankBgOrgAdv;
/** The extreme-difficulty frame overlay. */
@property(nonatomic, strong, nullable) UIImageView *rankBgOrgExt;
/** The basic-difficulty hold-marker frame overlay. */
@property(nonatomic, strong, nullable) UIImageView *rankBgHldBas;
/** The advanced-difficulty hold-marker frame overlay. */
@property(nonatomic, strong, nullable) UIImageView *rankBgHldAdv;
/** The extreme-difficulty hold-marker frame overlay. */
@property(nonatomic, strong, nullable) UIImageView *rankBgHldExt;

/** The basic-difficulty advertised-rank background. */
@property(nonatomic, strong, nullable) UIImageView *adRankBgBas;
/** The advanced-difficulty advertised-rank background. */
@property(nonatomic, strong, nullable) UIImageView *adRankBgAdv;
/** The extreme-difficulty advertised-rank background. */
@property(nonatomic, strong, nullable) UIImageView *adRankBgExt;
/** The basic-difficulty advertised-rank letter. */
@property(nonatomic, strong, nullable) UIImageView *adRankImgBas;
/** The advanced-difficulty advertised-rank letter. */
@property(nonatomic, strong, nullable) UIImageView *adRankImgAdv;
/** The extreme-difficulty advertised-rank letter. */
@property(nonatomic, strong, nullable) UIImageView *adRankImgExt;
/** The basic-difficulty advertised full-combo marker. */
@property(nonatomic, strong, nullable) UIImageView *adRankFcBas;
/** The advanced-difficulty advertised full-combo marker. */
@property(nonatomic, strong, nullable) UIImageView *adRankFcAdv;
/** The extreme-difficulty advertised full-combo marker. */
@property(nonatomic, strong, nullable) UIImageView *adRankFcExt;

/** The rating-chip background array. */
@property(nonatomic, strong, nullable) NSMutableArray *rankBgChipArray;

/** The gesture and button delegate. */
@property(nonatomic, weak, nullable) id<MusicViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
