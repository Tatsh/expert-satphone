/** @file
 * The challenge-mode rival-list modal.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeRivalListView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. The class object is at
 * 0x34e608.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ChallengeRivalListView;

/**
 * @brief Told when the rival modal closes.
 */
@protocol ChallengeRivalListViewDelegate <NSObject>
@optional
/** @brief Close the modal. */
- (void)closeMenu;
@end

/**
 * @brief A modal that downloads the player's rival list, shows it in a table, and lets each rival's
 * registration be removed through the server.
 */
@interface ChallengeRivalListView : UIView

/**
 * @brief The delegate told when the modal closes. Held weakly.
 * @ghidraAddress 0xdb17c (getter), 0xdb19c (setter)
 */
@property(nonatomic, weak, nullable) id<ChallengeRivalListViewDelegate> aDelegate;

/**
 * @brief Builds the modal and kicks off the rival-list download.
 * @param frame The modal's frame.
 * @return The initialised view.
 * @ghidraAddress 0xd9ec4
 */
- (instancetype)initWithFrame:(CGRect)frame;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
