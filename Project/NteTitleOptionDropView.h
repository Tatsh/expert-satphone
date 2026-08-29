/**
 * @file
 * A title-screen ornament that drops away when the title is dismissed.
 *
 * Reconstructed from Ghidra program Jubeat (class NteTitleOptionDropView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, from the dyld bind at the class object's superclass slot
 * (0x34f380).
 *
 * The view animates itself as soon as it is built — the initialiser ends by calling
 * @c -startAnimation — so it exists only to fall off the screen.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * What a @c NteTitleOptionDropView tells its owner.
 */
@protocol NteTitleOptionDropViewDelegate <NSObject>
@optional
/**
 * Sent when the drop has finished.
 * @param dropView The ornament that finished.
 */
- (void)dropAnimEnd:(id)dropView;
@end

/**
 * One of three randomly chosen title ornaments, which rotates and falls.
 */
@interface NteTitleOptionDropView : UIView

/**
 * The object told when the drop finishes.
 *
 * Weak and untyped in the metadata, so the dispatch goes through @c -respondsToSelector: rather
 * than a declared conformance.
 * @ghidraAddress 0x141098 (getter)
 */
@property(nonatomic, weak) id aDelegate;

/**
 * Picks one of three artwork variants at random, places it, and starts the drop.
 *
 * @param frame The view's frame. Despite the selector's first keyword this is the frame, not a
 * move type — the metadata types the method @c \@52\@0:8{CGRect=...}16i48 .
 * @param type Which side the ornament belongs to. Only the value 1 is distinguished: it
 * right-aligns the artwork, delays the drop, and reverses the spin.
 * @return The initialised ornament, already animating.
 * @ghidraAddress 0x140b70
 */
- (instancetype)initWithMoveType:(CGRect)frame type:(int)type;

/**
 * Spins the ornament a quarter turn and drops it by its own height while fading it out.
 * @ghidraAddress 0x140d24
 */
- (void)startAnimation;

/**
 * Inert. The body is a single @c ret .
 * @ghidraAddress 0x141094
 */
- (void)stopAnimation;

/**
 * Relays the drop's completion to the delegate.
 * @param sender The ornament. Unused — the delegate is handed the ornament regardless.
 * @ghidraAddress 0x140fe8
 */
- (void)dropAnimEnd:(id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
