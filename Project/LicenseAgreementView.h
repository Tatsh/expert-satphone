/** @file
 * Licence agreement overlay.
 *
 * Reconstructed from Ghidra program Jubeat (class LicenseAgreementView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub. Only the members reached so far are declared.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The licence agreement sheet shown on the title screen.
 */
@interface LicenseAgreementView : UIView

/**
 * @brief Builds the view for a given defaults key.
 * @param keyString The defaults key, e.g. PrefAgreeChallengePolicyVersion at 0x2d60a0.
 * @return The initialised view.
 * @ghidraAddress 0x1c4b8
 */
- (instancetype)initWithKeyString:(NSString *)keyString;

/**
 * @brief Sets the view that is dimmed behind the sheet.
 * @param coverView The cover view.
 * @ghidraAddress 0x1c5a0
 */
- (void)setWeakCoverView:(UIView *)coverView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
