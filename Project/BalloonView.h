/**
 * @file
 * A rounded speech-balloon view that draws itself with a triangular arrow on one edge.
 *
 * Reconstructed from Ghidra program Jubeat (class BalloonView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, taken from the dyld bind at the class object's superclass slot
 * (0x350550) rather than from the name.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Which edge of the balloon carries the arrow.
 *
 * The raw values are the four arms of the jump table at 0x1ba5dc and 0x1baba4. The names are
 * inferred from the geometry each arm draws — the runtime metadata types the property only as
 * @c Q, so it records the width and not the meaning.
 */
typedef NS_ENUM(NSUInteger, BalloonViewArrowDirection) {
    BalloonViewArrowDirectionUp = 0,    /*!< Above the top edge; the balloon points upwards. */
    BalloonViewArrowDirectionDown = 1,  /*!< Below the bottom edge. */
    BalloonViewArrowDirectionLeft = 2,  /*!< Left of the leading edge. */
    BalloonViewArrowDirectionRight = 3, /*!< Right of the trailing edge. */
};

/**
 * A speech balloon: a rounded rectangle with one triangular arrow.
 */
@interface BalloonView : UIView

/**
 * The edge the arrow sits on.
 *
 * Defaults to @c BalloonViewArrowDirectionUp.
 */
@property(nonatomic) BalloonViewArrowDirection arrowDirection;
/**
 * How far along its edge the arrow's centre sits, in points from the leading edge.
 *
 * Defaults to 0.3, which is below the minimum the drawing code enforces, so the default always
 * clamps up to @c borderRadius plus half the arrow width. The spelling is the binary's.
 */
@property(nonatomic) CGFloat arrowPosision;
/**
 * The arrow's base width and its height measured outwards from the edge.
 *
 * Defaults to 20 x 12.
 */
@property(nonatomic) CGSize arrowSize;
/** The balloon's fill. Defaults to black at 0.6 alpha. */
@property(nonatomic, strong) UIColor *balloonColor;
/** The outline's colour. Defaults to white. */
@property(nonatomic, strong) UIColor *borderColor;
/** The corner radius. Defaults to 8. */
@property(nonatomic) CGFloat borderRadius;
/**
 * The outline's width. Defaults to 2.
 *
 * The outline straddles the balloon's edge, so the drawing code insets every edge by half of it.
 * A value of zero or less suppresses the stroke colour and width, though not the stroke itself.
 */
@property(nonatomic) CGFloat borderWidth;
/** Padding between the balloon's inner edge and @c contentRect. Defaults to zero. */
@property(nonatomic) UIEdgeInsets contentEdgeInsets;

/**
 * The rectangle a caller may lay content out in.
 *
 * The bounds inset by the border, then by the arrow's height on whichever edge carries it, then by
 * @c contentEdgeInsets. Computed on each call; there is no backing ivar.
 * @ghidraAddress 0x1ba468
 */
@property(nonatomic, readonly) CGRect contentRect;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
