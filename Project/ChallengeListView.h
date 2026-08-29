/**
 * @file
 * The challenge-mode list view: a titled, closable table used for the rival and line-up
 * lists.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeListView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x351808.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ChallengeListView;

/**
 * Told when the list is closed or a row is selected.
 */
@protocol ChallengeListViewDelegate <NSObject>
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
 * A table of list rows over a background plate with a title and a close button. Rows
 * alternate their plate art, with a distinct plate for the picked-up row, and an optional
 * detail-text sub-list runs in parallel with the main list.
 */
@interface ChallengeListView : UIView <UITableViewDataSource, UITableViewDelegate>

/**
 * The delegate told about close and selection events. Held weakly.
 * @ghidraAddress 0x20975c (getter), 0x20977c (setter)
 */
@property(nonatomic, weak, nullable) id<ChallengeListViewDelegate> aDelegate;

/**
 * Builds the list view and its chrome.
 * @param frame The view's frame.
 * @param listPosY An extra offset added to the table's y position.
 * @return The initialised view.
 * @ghidraAddress 0x208b30
 */
- (instancetype)initWithFrame:(CGRect)frame listPosY:(int)listPosY;

/**
 * Sets the title image.
 * @param image The title image.
 * @param animation Whether to cross-fade the image.
 * @ghidraAddress 0x209118
 */
- (void)setTitleImage:(nullable UIImage *)image animation:(BOOL)animation;

/**
 * Sets the optional detail-text sub-list, run in parallel with the main list.
 * @param subListArray The detail strings.
 * @ghidraAddress 0x209130
 */
- (void)setSubListArray:(nullable NSArray *)subListArray;

/**
 * Sets the main list rows, clears any pickup, and reloads the table.
 * @param listArray The row records.
 * @ghidraAddress 0x209144
 */
- (void)setListArray:(nullable NSArray *)listArray;

/**
 * Marks the row at the given index as picked up and scrolls it into a cell.
 * @param slot The row index to pick up.
 * @ghidraAddress 0x209268
 */
- (void)pickUpCell:(int)slot;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
