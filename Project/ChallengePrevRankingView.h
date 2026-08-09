/** @file
 * The challenge-mode previous-event ranking and line-up view.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengePrevRankingView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. The class object
 * is at 0x34f3c8.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ChallengePrevRankingView;

/**
 * @brief Told when the previous-ranking view wants its host menu closed.
 *
 * The delegate is messaged through @c -respondsToSelector: then @c -performSelector: , so the
 * selector is optional.
 */
@protocol ChallengePrevRankingViewDelegate <NSObject>
@optional
/** @brief Close the hosting challenge-mode menu. */
- (void)closeMenu;
@end

/**
 * @brief A challenge-mode modal that fetches the previous event's line-up over a signed session
 * request, then presents the line-up sub-list and, on selection, the per-tune ranking sub-list.
 *
 * Construction fires only the previous-scratch request; the sub-list chrome is built lazily once
 * the line-up (and its artwork) has downloaded.
 */
@interface ChallengePrevRankingView : UIView

/**
 * @brief The delegate told when the menu should close. Held weakly.
 * @ghidraAddress 0x142a48 (getter), 0x142a68 (setter)
 */
@property(nonatomic, weak, nullable) id<ChallengePrevRankingViewDelegate> aDelegate;

/**
 * @brief Builds the view and kicks off the previous-scratch line-up download.
 *
 * Posts @c {prev: @1} to @c +[ScratchUtil challengePrevScratchURL] through a @c SessionDownloader
 * (tag @c 1 , API tag @c 9 ) and allocates the artwork cache; it builds no chrome itself.
 * @param frame The modal's frame.
 * @return The initialised view.
 * @ghidraAddress 0x141108
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
