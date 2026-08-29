/**
 * @file
 * The challenge-mode present-list table view.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengePresentListView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. The class object
 * is at 0x3515d8.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ChallengePresentListView;

/**
 * Told when the present list is closed or a row is selected.
 */
@protocol ChallengePresentListViewDelegate <NSObject>
@optional
/**
 * The close button was tapped.
 * @param sender The close button.
 */
- (void)tapClose:(nullable id)sender;
/**
 * The row at the given index path was selected.
 * @param indexPath The selected row's index path.
 */
- (void)selectListCell:(nullable NSIndexPath *)indexPath;
@end

/**
 * A table view of the player's presents, over a background plate with a title and a close
 * button, alternating the row plate art between two images.
 */
@interface ChallengePresentListView : UIView <UITableViewDataSource, UITableViewDelegate>

/**
 * The delegate told about close and selection events. Held weakly.
 * @ghidraAddress 0x1fcf1c (getter), 0x1fcf3c (setter)
 */
@property(nonatomic, weak, nullable) id<ChallengePresentListViewDelegate> aDelegate;

/**
 * Builds the list view and its chrome.
 * @param frame The view's frame.
 * @return The initialised view.
 * @ghidraAddress 0x1fc548
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Sets the present records and reloads the table.
 * @param listArray The present records, each a dictionary.
 * @ghidraAddress 0x1fcae4
 */
- (void)setListArray:(nullable NSArray *)listArray;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
