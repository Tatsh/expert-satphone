/** @file
 * An unimplemented countdown view.
 *
 * Reconstructed from Ghidra program Jubeat (class TimerView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, taken from the dyld bind at the class object's superclass slot
 * (0x34f970).
 *
 * **This class does nothing.** It ships six ivars, a delegate property and four methods, of which
 * three have empty bodies and the fourth only forwards to @c UIView. Nothing anywhere in the class
 * reads or writes @c startTime, @c endTime, @c currentTime, @c timer or @c timeText — only the
 * compiler-generated @c .cxx_destruct touches the last two, to release them. It is scaffolding that
 * was declared, compiled and shipped without ever being filled in. See TYPES_PENDING.md.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A countdown view that never counts.
 */
@interface TimerView : UIView

/**
 * @brief Weak and untyped, per the metadata. Nothing this class defines reads it.
 * @ghidraAddress 0x15c8f0 (getter)
 */
@property(nonatomic, weak) id aDelegate;

/**
 * @brief Forwards to @c UIView and does nothing else.
 * @ghidraAddress 0x15c8ac
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Empty. The compiled body is a single return instruction.
 * @param timeFont Ignored.
 * @ghidraAddress 0x15c8e4
 */
- (void)setTimeFont:(nullable UIFont *)timeFont;

/**
 * @brief Empty. The compiled body is a single return instruction.
 * @param timer Ignored. A @c double, per the @c d encoding — a duration, not the @c NSTimer ivar.
 * @ghidraAddress 0x15c8e8
 */
- (void)setTimer:(double)timer;

/**
 * @brief Empty. The compiled body is a single return instruction.
 * @ghidraAddress 0x15c8ec
 */
- (void)timerStart;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
