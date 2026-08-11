/** @file
 * The challenge-mode menu container.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeMenuRootView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. The class object is at
 * 0x3490f0.
 *
 * This view hosts the challenge-mode landing menu (@c ChallengeMenuView) over a dimming cover, and
 * cross-fades in one of six sub-views (present list, name-setting sheet, rival search, rival list,
 * previous ranking, and login/information) on top of it when a menu row is chosen. The superclass
 * is @c UIView, taken from the dyld bind at the class object's superclass slot and confirmed by the
 * @c -initWithFrame: chain-up.
 */

#import <UIKit/UIKit.h>

#import "ChallengeLoginInformationView.h"
#import "ChallengeMenuView.h"
#import "ChallengeNameSettingView.h"
#import "ChallengePresentView.h"
#import "ChallengeRivalListView.h"
#import "ChallengeRivalSearchView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c ChallengeMenuRootView tells its owner.
 *
 * The delegate ivar is weak and untyped in the metadata (@c \@,W,N). @c -closeMenuView and
 * @c -refreshView are sent directly, so they are effectively required; @c -refreshStatus and
 * @c -cubePurchaseStart are guarded by @c -respondsToSelector: and are optional.
 */
@protocol ChallengeMenuRootViewDelegate <NSObject>
/** @brief The root menu finished fading out and the owner should dismiss it. */
- (void)closeMenuView;
/** @brief A sub-view was dismissed; the owner should refresh the landing menu. */
- (void)refreshView;
@optional
/** @brief The player's status changed and should be refreshed. */
- (void)refreshStatus;
/** @brief The player asked to buy cubes. */
- (void)cubePurchaseStart;
@end

/**
 * @brief The challenge-mode menu container that switches between the landing menu and its
 * sub-views with fade transitions.
 */
@interface ChallengeMenuRootView : UIView <ChallengeMenuViewDelegate,
                                           ChallengePresentViewDelegate,
                                           ChallengeNameSettingViewDelegate,
                                           ChallengeRivalSearchViewDelegate,
                                           ChallengeRivalListViewDelegate,
                                           ChallengeLoginInformationViewDelegate>

/**
 * @brief The object told about close, refresh, and purchase events. Held weakly.
 * @ghidraAddress 0x102648 (getter), 0x102668 (setter)
 */
@property(nonatomic, weak, nullable) id<ChallengeMenuRootViewDelegate> aDelegate;

/**
 * @brief Builds the dimming cover and the landing menu, both initially transparent.
 * @param frame The view's frame.
 * @return The initialised view.
 * @ghidraAddress 0x100ed8
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Fades the cover and the landing menu in together.
 * @ghidraAddress 0x1011bc
 */
- (void)enterRootMenu;

/**
 * @brief Lazily builds the sub-view for @p index and fades it in over the menu.
 * @param index The sub-view selector (see @c -createMenuView:).
 * @ghidraAddress 0x1013b4
 */
- (void)enterMenuSelectedView:(int)index;

/**
 * @brief Close-button callback: plays the cancel sound, fades the cover and menu out, and tells
 * the delegate to dismiss the root menu.
 * @ghidraAddress 0x1014ec
 */
- (void)closeRootMenu;

/**
 * @brief Fades the landing menu in.
 * @ghidraAddress 0x1017a0
 */
- (void)enterMenu;

/**
 * @brief Plays the cancel sound and fades the landing menu out.
 * @ghidraAddress 0x1018c4
 */
- (void)outerMenu;

/**
 * @brief First half of the crossfade into a sub-view: fades the menu out, then fades the current
 * sub-view in.
 * @ghidraAddress 0x101a2c
 */
- (void)switchInMenu;

/**
 * @brief First half of the crossfade back to the menu: plays the cancel sound, tells the delegate
 * to refresh, removes the current sub-view, then fades the menu back in and rebuilds it.
 * @ghidraAddress 0x101cd8
 */
- (void)switchOutMenu;

/**
 * @brief Builds (replacing any existing instance) the sub-view for @p index and records it as the
 * current view.
 *
 * The index maps to: @c 0 present list, @c 1 name-setting sheet, @c 2 rival search, @c 3 rival
 * list, @c 4 previous ranking, and @c 5 login/information. Any other value does nothing. Each
 * sub-view is built at @c {0, 0, self.frame.size.width, self.frame.size.height}, made its own
 * delegate, given user interaction, faded to transparent, and added as a subview.
 *
 * @param index The sub-view selector.
 * @ghidraAddress 0x1020a4
 */
- (void)createMenuView:(int)index;

/**
 * @brief Menu-row callback: plays the labo-menu sound, builds the chosen sub-view, and starts the
 * crossfade into it.
 * @param menu The row's tag, boxed.
 * @ghidraAddress 0x102424
 */
- (void)selectMenu:(nullable NSNumber *)menu;

/**
 * @brief Sub-view callback: crossfades back to the landing menu.
 * @ghidraAddress 0x1024dc
 */
- (void)closeMenu;

/**
 * @brief Forwards a status refresh to the delegate when it responds to @c -refreshStatus .
 * @ghidraAddress 0x1024e8
 */
- (void)refreshStatus;

/**
 * @brief Forwards a cube-purchase request to the delegate when it responds to
 * @c -cubePurchaseStart .
 * @ghidraAddress 0x102598
 */
- (void)cubePurchase;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
