/** @file
 * Base title controller.
 *
 * Reconstructed from Ghidra program Jubeat (class TitleViewController, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub. The class object is at 0x348a60 (inferred from the Org/Rpl
 * siblings at 0x348a78/0x348a70). Only the members reached so far are declared.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Base class for the two title screens.
 */
@interface TitleViewController : UIViewController

/**
 * @brief Shared initialiser. DECLARED ONLY.
 * @ghidraAddress 0x139e38
 */
- (instancetype)init;

/**
 * @brief Builds the base view hierarchy. DECLARED ONLY.
 * @ghidraAddress 0x139f5c
 */
- (void)loadView;

/**
 * @brief Begins the title sequence. DECLARED ONLY.
 * @ghidraAddress 0x13a5a8
 */
- (void)start;

/**
 * @brief The co-button view. Backed by the ivar at 0x34adfc in the Org subclass.
 */
@property(nonatomic, strong, nullable) UIView *coBtn;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
