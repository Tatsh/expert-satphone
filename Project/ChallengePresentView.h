/**
 * @file
 * @brief The challenge-mode present-list modal.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengePresentView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. The class object is at
 * 0x34d7a8.
 */

#import <UIKit/UIKit.h>

#import "ChallengePresentListView.h"

NS_ASSUME_NONNULL_BEGIN

@class ChallengePresentView;

/**
 * @brief Told when the present modal closes or changes the player's status.
 */
@protocol ChallengePresentViewDelegate <NSObject>
@optional
/** @brief Close the modal. */
- (void)closeMenu;
/** @brief The player's status changed and should be refreshed. */
- (void)refreshStatus;
@end

/**
 * @brief A modal that downloads the player's present list, shows it in a table, and lets each
 * present be accepted or declined through the server.
 */
@interface ChallengePresentView : UIView <ChallengePresentListViewDelegate>

/**
 * @brief The delegate told about close and status-refresh events. Held weakly.
 * @ghidraAddress 0x96620 (getter), 0x96640 (setter)
 */
@property(nonatomic, weak, nullable) id<ChallengePresentViewDelegate> aDelegate;

/**
 * @brief Builds the modal and kicks off the present-list download.
 * @param frame The modal's frame.
 * @return The initialised view.
 * @ghidraAddress 0x9516c
 */
- (instancetype)initWithFrame:(CGRect)frame;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
