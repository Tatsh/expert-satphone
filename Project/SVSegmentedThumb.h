/** @file
 * The sliding selected-segment highlight ("thumb") view of Sam Vermette's third-party
 * SVSegmentedControl library.
 *
 * Reconstructed from Ghidra program Jubeat (class SVSegmentedThumb, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class has no embedded
 * __FILE__ path in the binary, so this file sits at the Project/ root.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// The control that owns and positions the thumb. Not reconstructed in this tree yet; see
// TYPES_PENDING.md. Held unretained (a back-pointer to the parent).
@class SVSegmentedControl;

/**
 * @brief The rounded highlight the segmented control slides over its selected segment.
 *
 * It renders either a caller-supplied background image or, by default, a device-gray gradient
 * pill tinted with @c tintColor, and carries the segment's title in two crossfading labels.
 */
@interface SVSegmentedThumb : UIView

/**
 * @brief The owning segmented control. Held unretained (a back-pointer to the parent).
 * @ghidraAddress 0x170830 (getter), 0x170840 (setter)
 */
@property(nonatomic, unsafe_unretained, nullable) SVSegmentedControl *segmentedControl;

/**
 * @brief A custom image drawn in place of the default gradient when the thumb is unselected.
 *
 * Setting it also toggles the drop shadow: the shadow casts only when there is no background
 * image.
 * @ghidraAddress 0x170850 (getter), 0x16fd84 (setter)
 */
@property(nonatomic, strong, nullable) UIImage *backgroundImage;

/**
 * @brief A custom image drawn in place of the default gradient when the thumb is selected.
 * @ghidraAddress 0x170860 (getter), 0x170870 (setter)
 */
@property(nonatomic, strong, nullable) UIImage *highlightedBackgroundImage;

/**
 * @brief The colour multiplied over the default gradient with the overlay blend mode.
 *
 * Setting it marks the thumb for redisplay.
 * @ghidraAddress 0x170884 (getter), 0x16fe10 (setter)
 */
@property(nonatomic, strong, nullable) UIColor *tintColor;

/**
 * @brief The label text colour. The setter pushes the value onto both labels.
 * @ghidraAddress 0x170894 (getter), 0x16ff28 (setter)
 */
@property(nonatomic, assign, nullable) UIColor *textColor;

/**
 * @brief The label text shadow colour. The setter pushes the value onto both labels' shadowColor.
 * @ghidraAddress 0x1708a4 (getter), 0x16ffcc (setter)
 */
@property(nonatomic, assign, nullable) UIColor *textShadowColor;

/**
 * @brief The label text shadow offset. The setter pushes the value onto both labels' shadowOffset.
 * @ghidraAddress 0x1708b4 (getter), 0x170070 (setter)
 */
@property(nonatomic, assign) CGSize textShadowOffset;

/**
 * @brief Whether the thumb casts a drop shadow. The setter drives the layer's shadow opacity.
 * @ghidraAddress 0x1708c8 (getter), 0x170110 (setter)
 */
@property(nonatomic, assign) BOOL shouldCastShadow;

/**
 * @brief Whether the thumb is in its selected (pressed) look.
 *
 * The setter fades the thumb and marks it for redisplay.
 * @ghidraAddress 0x1708d8 (getter), 0x1705ec (setter)
 */
@property(nonatomic, assign) BOOL selected;

/**
 * @brief Alias of @c textShadowColor. The setter forwards to @c -setTextShadowColor:.
 * @ghidraAddress 0x1708e8 (getter), 0x170818 (setter)
 */
@property(nonatomic, assign, nullable) UIColor *shadowColor;

/**
 * @brief Alias of @c textShadowOffset. The setter forwards to @c -setTextShadowOffset:.
 * @ghidraAddress 0x1708f8 (getter), 0x17080c (setter)
 */
@property(nonatomic, assign) CGSize shadowOffset;

/**
 * @brief Alias of @c shouldCastShadow. The setter forwards to @c -setShouldCastShadow:.
 * @ghidraAddress 0x17090c (getter), 0x170824 (setter)
 */
@property(nonatomic, assign) BOOL castsShadow;

/**
 * @brief The font of both labels. The getter reads the primary label's font; the setter pushes
 * the value onto both labels.
 * @ghidraAddress 0x16f8c8 (getter), 0x16fe84 (setter)
 */
@property(nonatomic, assign, nullable) UIFont *font;

/**
 * @brief The primary title label, created lazily and added as a subview on first access.
 * @ghidraAddress 0x16f680
 */
@property(nonatomic, strong, readonly) UILabel *label;

/**
 * @brief The secondary (crossfade) title label, created lazily and added as a subview on first
 * access.
 * @ghidraAddress 0x16f7a4
 */
@property(nonatomic, strong, readonly) UILabel *secondLabel;

/**
 * @brief Builds the thumb with its library defaults (clear background, white text on a black
 * shadow offset up by one point, gray tint, and shadow casting enabled).
 * @param frame The view's frame.
 * @return The initialised thumb.
 * @ghidraAddress 0x16f508
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Restores the thumb to its unselected look, showing the primary label unless the control
 * crossfades labels while dragging.
 * @ghidraAddress 0x1706b4
 */
- (void)activate;

/**
 * @brief Puts the thumb into its selected look, hiding the primary label unless the control
 * crossfades labels while dragging.
 * @ghidraAddress 0x170760
 */
- (void)deactivate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
