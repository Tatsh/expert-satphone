/**
 * @file
 * One row of the mission-achievement download list.
 *
 * Reconstructed from Ghidra program Jubeat (class MissionAchieveDownloadPageViewCell, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableViewCell, taken from the dyld bind at the class object's superclass
 * slot (0x351130) rather than from the name.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * What a @c MissionAchieveDownloadPageViewCell tells its owner.
 */
@protocol MissionAchieveDownloadPageViewCellDelegate <NSObject>
@optional
/**
 * Sent when the row's download button is tapped.
 * @param cell The row that was tapped — not the button.
 */
- (void)tapDownloadBtn:(id)cell;
@end

/**
 * A three-line description with a fixed-size download button at its trailing edge.
 */
@interface MissionAchieveDownloadPageViewCell : UITableViewCell

/**
 * The object told when the download button is tapped.
 *
 * Weak, per the @c W attribute in the metadata, and encoded as a bare @c \@ with no protocol, so
 * the dispatch goes through @c -respondsToSelector: rather than a declared conformance.
 * @ghidraAddress 0x1ed2bc (getter)
 */
@property(nonatomic, weak) id aDelegate;

/**
 * Builds the plate, the label and the button at the metrics for the current idiom.
 * @param style The cell style.
 * @param reuseIdentifier The reuse identifier, or nil for a non-reusable cell.
 * @return The initialised cell.
 * @ghidraAddress 0x1ecdd0
 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier;

/**
 * Fills the row in and sets the button's enabled appearance.
 *
 * Note the button's @c enabled state is never touched — only its background colour changes, so a
 * "disabled" button still reports taps.
 *
 * @param bgImg The plate drawn behind the row.
 * @param text The row's text, wrapped over up to three lines.
 * @param btnEnable Green when YES, grey when NO.
 * @ghidraAddress 0x1ed110
 */
- (void)setBgImage:(nullable UIImage *)bgImg
              text:(nullable NSString *)text
         btnEnable:(BOOL)btnEnable;

/**
 * The download button's action.
 * @param sender The button. Unused — the delegate is handed the cell instead.
 * @ghidraAddress 0x1ed208
 */
- (void)tapDownload:(id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
