/**
 * @file
 * @brief The challenge-mode scratch-mode music-detail card.
 *
 * Reconstructed from Ghidra program Jubeat (class @c ScratchMusicDetailView, image base
 * 0x100000000). All @c @@ghidraAddress values are offsets relative to that image base. The class
 * object is at 0x349220.
 *
 * The superclass is @c MusicDetailView, proven by the @c initWithFrame: chain-up at 0x15f658 and by
 * the many @c MusicDetailView accessor calls throughout (@c artworkView, @c reflectionArtworkView,
 * @c isPad, @c buttonStartPlay, @c coverView, the @c level* and @c mbar* score fields, and so on).
 * The layer is a @c CAGradientLayer, from @c +layerClass at 0x15f644.
 *
 * The card shows a scratch tune's artwork with the base class's reflection, its name plate, a
 * per-difficulty level/high-score/rating/full-combo/music-bar board, three difficulty buttons, a
 * ranking button that raises a @c ChallengeRankingListView, a store-jump button, and a
 * coin-consumption footer. It reads its content from a @c ChallengeStatus scratch info-table entry
 * and from an encrypted tune archive.
 */

#import <UIKit/UIKit.h>

#import "MusicDetailView.h"

@class ChallengeMusicInfo;
@class ChallengeRankingListView;
@class TuneInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The delegate told about the play, ranking, and store actions.
 *
 * All three selectors are dispatched with a direct message to the (weak) delegate, without a
 * @c respondsToSelector: guard.
 */
@protocol ScratchMusicDetailViewDelegate <NSObject>
/** @brief The enabled start-play button was tapped. */
- (void)startChallengeMusic;
/** @brief The ranking button was tapped. */
- (void)openRanking;
/**
 * @brief Open the jubeat store on the pack containing this tune.
 * @param packID The tune's pack identifier.
 */
- (void)openJubeatStore:(NSInteger)packID;
@end

/**
 * @brief The scratch-mode music-detail card over a @c ChallengeStatus scratch panel.
 */
@interface ScratchMusicDetailView : MusicDetailView

/**
 * @brief The card's backing layer class: a @c CAGradientLayer.
 * @return The @c CAGradientLayer class.
 * @ghidraAddress 0x15f644
 */
+ (Class)layerClass;

/**
 * @brief Designated initialiser; builds the background, the three difficulty buttons, the ranking
 *        button and list digits, the start-play button, the music-bar dots, the high-score board,
 *        the rating and combo views, the hold marks, and the store button, laid out for the pad or
 *        phone idiom.
 * @param frame The card's frame.
 * @return The initialised card, or @c nil.
 * @ghidraAddress 0x15f658
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Builds a difficulty button from a resource image, targeting @c -selectDiff:.
 * @param imageName The button's resource name.
 * @return The configured button.
 * @ghidraAddress 0x160b00
 */
- (nullable UIButton *)diffButton:(nullable NSString *)imageName;

/**
 * @brief Loads the rating, level, high-score, music-bar, full-combo, and excellent image atlases.
 * @ghidraAddress 0x160c28
 */
- (void)loadImages;

/**
 * @brief Populates the artwork, reflection, name plate, and music-bar data from a content
 *        dictionary, then applies the persisted difficulty.
 * @param dict The content dictionary.
 * @ghidraAddress 0x161194
 */
- (void)loadContentFromDictionary:(nullable NSDictionary *)dict;

/**
 * @brief Populates the artwork, reflection, name plate, and music-bar data from an encrypted tune
 *        archive at a path or in memory, then applies the persisted difficulty.
 * @param path A tune-archive file path.
 * @param data An in-memory tune archive.
 * @ghidraAddress 0x161528
 */
- (void)loadContentFromPath:(nullable NSString *)path orData:(nullable NSData *)data;

/**
 * @brief Applies the persisted difficulty when an extend music-bar archive is present at a path.
 * @param path A tune-archive file path.
 * @ghidraAddress 0x161a64
 */
- (void)loadExtendMusicBar:(nullable NSString *)path;

/**
 * @brief Sets the six ranking-number digit views from the number's decimal digits, blanking leading
 *        zero positions when the value is not positive.
 * @param number The rank to display.
 * @ghidraAddress 0x161b84
 */
- (void)setRankingNumberImage:(int)number;

/**
 * @brief Chains to the base class then sets the three per-difficulty level digit views from the
 *        tune's clamped levels, resets the score, and reloads the artwork.
 * @param info The tune.
 * @param score The score record (forwarded to the base class).
 * @ghidraAddress 0x161c40
 */
- (void)setInfo:(nullable TuneInfo *)info score:(nullable id)score;

/**
 * @brief Refreshes the board for one difficulty: the ranking number, the score board, the
 *        music-bar dots, and the three hold marks from the current hold flags.
 * @param difficulty The difficulty index (0 basic, 1 advanced, 2 extreme).
 * @ghidraAddress 0x161f30
 */
- (void)infoChange:(int)difficulty;

/**
 * @brief Clears the artwork, reflection, and name-plate images.
 * @ghidraAddress 0x1622b8
 */
- (void)clearInfo;

/**
 * @brief The theme-prefixed sound name for a base name (@c "SD_RPL_" , @c "SD_KNT_" , or @c "SD_"
 * ).
 * @param name The base sound name.
 * @return The theme-prefixed sound name.
 * @ghidraAddress 0x16236c
 */
- (nullable NSString *)soundName:(nullable NSString *)name;

/**
 * @brief Difficulty-button action: enables the two other buttons, disables the tapped one, plays
 *        the difficulty's confirm sound, persists the choice, and animates the board over.
 * @param sender The tapped difficulty button.
 * @ghidraAddress 0x16245c
 */
- (void)selectDiff:(nullable id)sender;

/**
 * @brief Sets the seven high-score digit views, the rating view, and the combo view from a score
 *        and full-combo flag. A negative score blanks everything; a score of 1,000,000 or more
 *        shows the excellent mark instead of a rating.
 * @param scoreValue The score value.
 * @param fullcombo Whether the chart was full-comboed.
 * @ghidraAddress 0x162920
 */
- (void)setScoreBoard:(int)scoreValue fullcombo:(BOOL)fullcombo;

/**
 * @brief Selects a difficulty: fades and scales the three difficulty buttons and the fourth-slot
 *        level view, then refreshes the board through @c -infoChange:.
 * @param difficulty The difficulty index (0 basic, 1 advanced, 2 extreme).
 * @ghidraAddress 0x162cb4
 */
- (void)changeDifficulty:(int)difficulty;

/**
 * @brief Sets the 120 music-bar dot views from a bar-dot buffer and a colour-resource buffer.
 * @param mbar The per-dot symbol buffer (nibble-packed), or @c nullptr to blank every dot.
 * @param mbarRes The per-dot colour buffer (2-bit-packed), or @c nullptr for colour 0.
 * @ghidraAddress 0x162f18
 */
- (void)setMusicBarDot:(nullable char *)mbar mbarRes:(nullable char *)mbarRes;

/**
 * @brief The start-play button background image.
 * @return The @c "menu_button_start_ch" image.
 * @ghidraAddress 0x163074
 */
- (nullable UIImage *)getStartImage;

/**
 * @brief The on-screen position of a difficulty button, in the scroll view's coordinate space.
 * @param difficulty The difficulty index (clamped to 0 when above 2).
 * @return The button's origin corrected by the scroll-view frame.
 * @ghidraAddress 0x1630d8
 */
- (CGPoint)getDifficultyPos:(int)difficulty;

/**
 * @brief Loads the full board for a scratch panel: stores the item slot, music id, difficulty, and
 *        pack id, wires the start-play and store buttons, reads the per-difficulty score/rank/combo
 *        from the panel's @c ChallengeMusicInfo, decrypts the tune archive into a @c TuneInfo and
 *        music-bar data, and sets the three level digits.
 * @param slot The scratch panel index.
 * @ghidraAddress 0x1631c8
 */
- (void)setDetailInfo:(int)slot;

/**
 * @brief Start-play button action: when enabled, plays the confirm sound and tells the delegate to
 *        start the challenge tune.
 * @param sender The start-play button.
 * @ghidraAddress 0x163d50
 */
- (void)pushButtonStartPlay:(nullable id)sender;

/**
 * @brief Ranking button action: plays the menu sound and tells the delegate to open the ranking.
 * @param sender The ranking button.
 * @ghidraAddress 0x163e24
 */
- (void)tapRanking:(nullable id)sender;

/**
 * @brief Removes and releases the ranking list view.
 * @ghidraAddress 0x163eac
 */
- (void)closeRanking;

/**
 * @brief Store button action: plays the menu sound and tells the delegate to open the store on the
 *        tune's pack.
 * @ghidraAddress 0x163ee8
 */
- (void)tapStoreMove;

/**
 * @brief Removes and releases the ranking list view when one is shown.
 * @ghidraAddress 0x163f7c
 */
- (void)showDetail;

/**
 * @brief Re-reads the three per-difficulty ranks from the panel's @c ChallengeMusicInfo.
 * @ghidraAddress 0x163fc8
 */
- (void)refreshDetail;

/**
 * @brief Empty in this build.
 * @ghidraAddress 0x1640ac
 */
- (void)timerUpdate;

#pragma mark - Properties

/**
 * @brief The delegate told about play, ranking, and store actions. Weak, per the @c W metadata.
 * @ghidraAddress 0x1640b0 (getter), 0x1640d0 (setter)
 */
@property(nonatomic, weak, nullable) id<ScratchMusicDetailViewDelegate> aDelegate;
/**
 * @brief The tune's music identifier. Encodes as @c I .
 * @ghidraAddress 0x1640e4
 */
@property(nonatomic, assign, readonly) unsigned int musicID;
/**
 * @brief The selected difficulty index. Encodes as @c i .
 * @ghidraAddress 0x1640f4
 */
@property(nonatomic, assign, readonly) int difficulty;
/**
 * @brief The tune's decrypted info.
 * @ghidraAddress 0x164104
 */
@property(nonatomic, strong, readonly, nullable) TuneInfo *tuneInfo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
