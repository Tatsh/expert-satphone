/** @file
 * The challenge scratch line-up modal.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeLineupView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. The class object is at
 * 0x3491b8.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ChallengeLineupView;

/**
 * @brief Told when the line-up modal is closed or a purchasable pack is chosen.
 *
 * Both selectors are dispatched with a direct message to the (weak) delegate, without a
 * @c respondsToSelector: guard.
 */
@protocol ChallengeLineupViewDelegate <NSObject>
/** @brief The close button was tapped and the fade-out has finished. */
- (void)closeLineupView;
/**
 * @brief Open the jubeat store on the pack containing the chosen tune.
 * @param packID The chosen tune's pack identifier.
 */
- (void)openJubeatStore:(NSInteger)packID;
@end

/**
 * @brief A dimmed-overlay modal listing the current scratch line-up over a background plate with a
 * title and a close button, each row showing a tune's artwork, name, and — on the pad — a store
 * button. On the phone, tapping a row raises the store alert instead.
 */
@interface ChallengeLineupView : UIView <UITableViewDataSource, UITableViewDelegate>

/**
 * @brief The delegate told about close and store events. Held weakly.
 * @ghidraAddress 0x14765c (getter), 0x14767c (setter)
 */
@property(nonatomic, weak, nullable) id<ChallengeLineupViewDelegate> aDelegate;

/**
 * @brief Builds the modal over the given frame, initially hidden. The rows come from
 * @c [ChallengeStatus sharedStatus].scratchLineUp .
 * @param frame The view's frame.
 * @return The initialised view.
 * @ghidraAddress 0x146128
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Reloads the table.
 * @ghidraAddress 0x146720
 */
- (void)refreshList;

/**
 * @brief Fades the modal in over 0.2 s.
 * @ghidraAddress 0x14693c
 */
- (void)showLineup;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
