/** @file
 * The settings-screen reward advert view controller.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsRewardViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. It hosts a
 * reward ad-area web view over a grey background with a loading spinner, and is the ad area's view
 * delegate. Unlike its recommend-network sibling it first provisions a jubeatLab editor ID (opening
 * the ad screen only once an ID is present), and it is the download delegate for that provisioning.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A view controller presenting the reward advert screen in the settings screen.
 */
@interface SettingsRewardViewController : UIViewController

/** @brief The loading spinner shown until the advert screen appears.
 *  @ghidraAddress 0x20acc4 (getter), 0x20acd4 (setter) */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicatorView;

/**
 * @brief Builds the controller: a grey background, a reward ad-area web view, and a centred
 *        loading spinner. Opens the ad screen if an editor ID already exists, otherwise starts a
 *        provisioning download with this controller as its delegate.
 * @return The initialised controller.
 * @ghidraAddress 0x20a250
 */
- (nullable instancetype)init;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
