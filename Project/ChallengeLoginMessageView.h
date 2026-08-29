/**
 * @file
 * The daily-login sheet that tells the player how many free scratches remain.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeLoginMessageView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, taken from the dyld bind at the class object's superclass slot
 * (0x34dad0) rather than from the name.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A modal sheet shown once per day, carrying the remaining free-scratch count.
 *
 * The whole view is built in the initialiser; there is no separate layout pass and no nib.
 */
@interface ChallengeLoginMessageView : UIView

/**
 * The object told when the player dismisses the sheet.
 *
 * Weak, per the @c W attribute in the runtime metadata. Genuinely untyped: the metadata encodes it
 * as a bare @c \@ with no protocol, and @c -closeMessage: dispatches through
 * @c -respondsToSelector: and @c -performSelector: rather than through a declared protocol.
 * The expected selector is @c closeLoginMessage.
 * @ghidraAddress 0xa7c8c (getter)
 */
@property(nonatomic, weak) id aDelegate;

/**
 * Builds the whole sheet, sized from the background art and the device idiom.
 *
 * The phone enlarges the artwork by 1.3 while the pad uses it at its native size, and the two
 * labels take larger point sizes on the pad.
 *
 * @param frame The area to centre the sheet within. Only its size is used, to place the centre.
 * @param scratchNum The number of free scratches left, substituted into the upper label.
 * @ghidraAddress 0xa75fc
 */
- (instancetype)initWithFrame:(CGRect)frame scratchNum:(int)scratchNum;

/**
 * Dismisses the sheet: plays the menu sound, then notifies @c aDelegate.
 *
 * Note that it does not remove itself from its superview — closing is entirely the delegate's job,
 * and a delegate that does not answer @c closeLoginMessage leaves the sheet on screen.
 *
 * @param sender The button that was tapped. Unused.
 * @ghidraAddress 0xa7b98
 */
- (void)closeMessage:(id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
