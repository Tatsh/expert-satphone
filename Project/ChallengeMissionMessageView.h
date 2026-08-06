/** @file
 * The "you have a new mission sheet" prompt.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeMissionMessageView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, from the dyld bind at the class object's superclass slot
 * (0x34cd60).
 *
 * A two-button confirmation panel centred over whatever presents it. Both buttons make the same
 * sound and both answer through the delegate; only the selector differs.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c ChallengeMissionMessageView tells its owner.
 */
@protocol ChallengeMissionMessageViewDelegate <NSObject>
@optional
/**
 * @brief Sent when the prompt is dismissed.
 */
- (void)closeMissionMessage;
/**
 * @brief Sent when the player accepts and wants the mission list.
 */
- (void)openMissionList;
@end

/**
 * @brief A centred panel asking whether to look at a newly arrived mission sheet.
 */
@interface ChallengeMissionMessageView : UIView

/**
 * @brief The object told which button was pressed.
 *
 * Weak and untyped in the metadata, so the dispatch goes through @c -respondsToSelector: rather
 * than a declared conformance.
 * @ghidraAddress 0x62c8c (getter)
 */
@property(nonatomic, weak) id aDelegate;

/**
 * @brief Builds the panel, sized from its own background artwork rather than from @c frame .
 *
 * The frame is used only to centre the result; the panel's size comes from the background image
 * scaled per idiom, and the two buttons are then spaced across it in three equal gaps.
 *
 * @param frame The area to centre within.
 * @return The initialised panel.
 * @ghidraAddress 0x62558
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief The dismiss button's action.
 * @param sender The button. Unused.
 * @ghidraAddress 0x62aa4
 */
- (void)closeMessage:(id)sender;

/**
 * @brief The accept button's action.
 * @param sender The button. Unused.
 * @ghidraAddress 0x62b98
 */
- (void)openMission:(id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
