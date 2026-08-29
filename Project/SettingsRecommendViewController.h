/**
 * @file
 * The settings-screen recommend advert view controller.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsRecommendViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. The class object
 * is at 0x34e298. It hosts a recommend ad-area web view over a grey background with a loading
 * spinner, and is the ad area's view delegate.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A view controller presenting the recommend advert list in the settings screen.
 */
@interface SettingsRecommendViewController : UIViewController

/** The loading spinner shown until the advert list appears.
 *  @ghidraAddress 0xd00c8 (getter), 0xd00d8 (setter) */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicatorView;

/**
 * Builds the controller: a grey background, a recommend ad-area web view, and a centred
 *        loading spinner, and opens the ad area.
 * @return The initialised controller.
 * @ghidraAddress 0xcf890
 */
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
