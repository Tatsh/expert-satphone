/** @file
 * The challenge previous-ranking line-up list view.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengePrevRankingListView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. The class object
 * is at 0x34d078.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ChallengePrevRankingListView;

/**
 * @brief Told when the line-up list is closed or a row is selected.
 */
@protocol ChallengePrevRankingListViewDelegate <NSObject>
@optional
/** @brief The close button was tapped. */
- (void)closeLineupView;
/**
 * @brief The row at the given index path was selected.
 * @param indexPath The selected row's index path.
 */
- (void)selectListCell:(nullable NSIndexPath *)indexPath;
@end

/**
 * @brief A dimmed-overlay modal listing the previous-ranking line-up tunes over a background plate
 * with a title and a close button, each row showing a tune's artwork and name.
 */
@interface ChallengePrevRankingListView : UIView <UITableViewDataSource, UITableViewDelegate>

/**
 * @brief The delegate told about close and selection events. Held weakly.
 * @ghidraAddress 0x73b10 (getter), 0x73b30 (setter)
 */
@property(nonatomic, weak, nullable) id<ChallengePrevRankingListViewDelegate> aDelegate;

/**
 * @brief Builds the list view over the given line-up records, initially hidden.
 * @param frame The view's frame.
 * @param lineup The line-up records, each a dictionary with @c music_id and @c name .
 * @return The initialised view.
 * @ghidraAddress 0x72ee8
 */
- (instancetype)initWithFrame:(CGRect)frame lineup:(nullable NSArray *)lineup;

/**
 * @brief Reloads the table.
 * @ghidraAddress 0x73570
 */
- (void)refreshList;

/**
 * @brief Fades the view in over 0.2 s.
 * @ghidraAddress 0x73638
 */
- (void)showLineup;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
