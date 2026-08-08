/** @file
 * The challenge-mode player-name setting sheet.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeNameSettingView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. The class object
 * is at 0x34e658.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ChallengeNameSettingView;

/**
 * @brief Told when the name-setting sheet wants to close itself.
 */
@protocol ChallengeNameSettingViewDelegate <NSObject>
/** @brief Close the sheet. */
- (void)closeMenu;
@end

/**
 * @brief A modal sheet letting the player edit and register their challenge-mode name, showing the
 * current search ID beneath a name-entry field.
 */
@interface ChallengeNameSettingView : UIView

/**
 * @brief The delegate told when the sheet should close. Held weakly.
 * @ghidraAddress 0xdc588 (getter), 0xdc5a8 (setter)
 */
@property(nonatomic, weak, nullable) id<ChallengeNameSettingViewDelegate> aDelegate;

/**
 * @brief Builds the sheet, choosing whether it shows a back/close button.
 * @param frame The sheet's frame.
 * @param backEnable Whether the close button is added (also selects the confirmation copy).
 * @return The initialised view.
 * @ghidraAddress 0xdb214
 */
- (nullable instancetype)initWithFrame:(CGRect)frame backEnable:(BOOL)backEnable;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
