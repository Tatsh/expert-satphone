/**
 * @file
 * The lock overlay shown over a tweet frame that is not yet unlocked.
 *
 * Reconstructed from Ghidra program Jubeat (class FrameLockView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, taken from the dyld bind at the class object's superclass slot
 * (0x34d2b0) rather than from the name.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A dimming panel with a padlock and a "install N more apps" caption.
 *
 * The caption's number counts down as the player installs the promoted apps; reaching zero fades
 * the whole overlay away.
 */
@interface FrameLockView : UIView

/**
 * Builds the overlay over a frame of the given size.
 *
 * A number of zero or less starts the overlay already hidden, so an unlocked frame costs nothing
 * to construct.
 *
 * @param frame The area to cover. Kept, so the later re-centring can use it.
 * @param unlockNumber How many more installs are required. Negative values are clamped to zero.
 * @ghidraAddress 0x7b0a0
 */
- (instancetype)initWithFrame:(CGRect)frame unlockNumber:(int)unlockNumber;

/**
 * Updates the caption, and fades the overlay away when the count reaches zero.
 *
 * The fade runs only when the overlay is currently visible, so setting zero twice animates once.
 * A count above zero updates the caption but never brings a hidden overlay back.
 *
 * @param unlockNumber How many more installs are required. Negative values are clamped to zero.
 * @ghidraAddress 0x7b4d4
 */
- (void)setUnlockNumber:(int)unlockNumber;

/**
 * Chooses between the caption and the padlock.
 *
 * YES shows the caption at full opacity and leaves the padlock as it was. NO hides the caption and
 * re-loads the padlock at its selected artwork, re-centred on the frame this view was built with.
 *
 * @param lockTextDisp Whether to show the caption.
 * @ghidraAddress 0x7b6e4
 */
- (void)setLockTextDisp:(BOOL)lockTextDisp;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
