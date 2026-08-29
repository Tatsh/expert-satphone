/**
 * @file
 * An animated circular progress (pie-ring) view.
 *
 * Reconstructed from Ghidra program Jubeat (class PieChartView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x34da28.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PieChartView;

/**
 * Told when the pie chart's fill animation finishes.
 */
@protocol PieChartViewDelegate <NSObject>
@optional
/** The fill animation reached its target percentage. */
- (void)chartAnimationEnd;
@end

/**
 * A ring that fills clockwise from the top to a percentage, over an optional base ring and
 * inner/outer borders, animating smoothly towards a target.
 */
@interface PieChartView : UIView

/**
 * The delegate told when the fill animation ends. Held weakly.
 * @ghidraAddress 0xa0160 (getter), 0xa0180 (setter)
 */
@property(nonatomic, weak, nullable) id<PieChartViewDelegate> aDelegate;

/**
 * Builds the view with its default colours (clear fill/line, gray base, black border).
 * @param frame The view's frame.
 * @return The initialised view.
 * @ghidraAddress 0x9f8e0
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Sets the fill, base-ring, and border colours.
 * @param chartColor The filled-arc colour.
 * @param baseColor The base-ring colour.
 * @param borderColor The inner/outer border colour.
 * @ghidraAddress 0x9fa74
 */
- (void)setChartColor:(nullable UIColor *)chartColor
            baseColor:(nullable UIColor *)baseColor
          borderColor:(nullable UIColor *)borderColor;

/**
 * Sets the background-disc colour.
 * @param bgColor The disc colour drawn behind the rings.
 * @ghidraAddress 0x9fb34
 */
- (void)setBgColor:(nullable UIColor *)bgColor;

/**
 * Sets the ring line width and the inner and outer border widths.
 * @param lineWidth_ The ring line width.
 * @param borderInside The inner border width.
 * @param borderOutsize The outer border width.
 * @ghidraAddress 0x9fb48
 */
- (void)setLineWidth:(float)lineWidth_
        borderInside:(float)borderInside
       borderOutsize:(float)borderOutsize;

/**
 * Sets the fill percentage immediately (clamped to 1.0) and redraws.
 * @param percent The fill fraction, 0…1.
 * @ghidraAddress 0x9fb70
 */
- (void)setPercent:(float)percent;

/**
 * Animates the fill towards a target percentage (clamped to 1.0), unless already animating.
 * @param percent The target fill fraction, 0…1.
 * @ghidraAddress 0x9fb90
 */
- (void)startNextPercent:(float)percent;

/**
 * Requests a redraw.
 * @ghidraAddress 0x9fd98
 */
- (void)refreshDisplay;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
