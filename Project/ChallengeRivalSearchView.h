/** @file
 * The challenge-mode rival-search modal.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeRivalSearchView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ChallengeRivalSearchView;

/**
 * @brief Told when the rival-search modal wants to close itself.
 */
@protocol ChallengeRivalSearchViewDelegate <NSObject>
/** @brief Close the modal. */
- (void)closeMenu;
@end

/**
 * @brief A modal that takes a rival's search ID in a text field, looks the rival up through the
 * server, and — once found — shows an add/cancel prompt that registers the rival.
 */
@interface ChallengeRivalSearchView : UIView

/**
 * @brief The delegate told when the modal should close. Held weakly.
 * @ghidraAddress 0x16a314 (getter), 0x16a334 (setter)
 */
@property(nonatomic, weak, nullable) id<ChallengeRivalSearchViewDelegate> aDelegate;

/**
 * @brief Builds the search box and the (initially hidden) rival-add prompt.
 * @param frame The modal's frame.
 * @return The initialised view.
 * @ghidraAddress 0x167248
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
