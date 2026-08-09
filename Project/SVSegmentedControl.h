/** @file
 * A draggable, cross-fading segmented control from Sam Vermette's third-party SVSegmentedControl
 * library (MIT licence), with Konami additions layered on top of the early-2012 fork.
 *
 * Reconstructed from Ghidra program Jubeat (class SVSegmentedControl, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class has no embedded
 * __FILE__ path in the binary, so this file sits at the Project/ root.
 */

#import <UIKit/UIKit.h>

#import "SVSegmentedThumb.h"

NS_ASSUME_NONNULL_BEGIN

@class SVSegmentedControl;

/**
 * @brief The optional delegate notified when the control's selection changes.
 *
 * Retained deprecated API kept alongside @c changeHandler and target/action. The control sends
 * @c -segmentedControl:didSelectIndex: only when the delegate responds to it.
 */
@protocol SVSegmentedControlDelegate <NSObject>

/**
 * @brief Notifies the delegate that the user selected a segment.
 * @param segmentedControl The control whose selection changed.
 * @param index The newly selected segment index.
 */
- (void)segmentedControl:(SVSegmentedControl *)segmentedControl didSelectIndex:(NSUInteger)index;

@end

/**
 * @brief A horizontal segmented control whose selected segment is highlighted by a draggable,
 * cross-fading @c SVSegmentedThumb.
 *
 * The control lays its segments out at a uniform @c segmentWidth derived from the widest title,
 * slides the thumb under drag, and snaps it to the nearest segment on release, reporting the new
 * selection through a block, a delegate, and @c UIControlEventValueChanged.
 */
@interface SVSegmentedControl : UIControl

#pragma mark - Change notification

/**
 * @brief A block invoked with the newly selected index whenever the selection changes.
 * @ghidraAddress 0x16d8c0 (getter), 0x16d8d0 (setter)
 */
@property(nonatomic, copy, nullable) void (^changeHandler)(NSUInteger newIndex);

/**
 * @brief Deprecated block invoked with the control as its sender when the selection settles.
 * @ghidraAddress 0x16d8a4 (getter), 0x16d8b4 (setter)
 */
@property(nonatomic, copy, nullable) void (^selectedSegmentChangedHandler)(id sender);

/**
 * @brief Deprecated delegate notified of selection changes. Held unretained (unsafe assign).
 * @ghidraAddress 0x16dbf0 (getter), 0x16dc00 (setter)
 */
@property(nonatomic, assign, nullable) id<SVSegmentedControlDelegate> delegate;

#pragma mark - Appearance and configuration

/**
 * @brief The sliding highlight, created lazily on first access.
 * @ghidraAddress 0x16a874
 */
@property(nonatomic, strong, readonly) SVSegmentedThumb *thumb;

/**
 * @brief The index of the selected segment. Default is 0.
 * @ghidraAddress 0x16d8dc (getter), 0x16d8ec (setter)
 */
@property(nonatomic, assign) NSUInteger selectedIndex;

/**
 * @brief Whether the initial selection animates into place. Default is NO.
 * @ghidraAddress 0x16d8fc (getter), 0x16d90c (setter)
 */
@property(nonatomic, assign) BOOL animateToInitialSelection;

/**
 * @brief Whether the primary and secondary labels cross-fade while the thumb is dragged.
 * Default is NO.
 * @ghidraAddress 0x16da88 (getter), 0x16da98 (setter)
 */
@property(nonatomic, assign) BOOL crossFadeLabelsOnDrag;

/**
 * @brief The colour multiplied over the track with the overlay blend mode. Default is gray.
 * @ghidraAddress 0x16d960 (getter), 0x16d970 (setter)
 */
@property(nonatomic, strong, nullable) UIColor *tintColor;

/**
 * @brief A custom track background image. Setting it also sets @c height to the image's height.
 * @ghidraAddress 0x16d984 (getter), 0x16d7e8 (setter)
 */
@property(nonatomic, strong, nullable) UIImage *backgroundImage;

/**
 * @brief The control's height. Default is 32.0.
 * @ghidraAddress 0x16da68 (getter), 0x16da78 (setter)
 */
@property(nonatomic, assign) double height;

/**
 * @brief The inset of the thumb inside a segment. Default is UIEdgeInsetsMake(2, 2, 3, 2).
 * @ghidraAddress 0x16dc10 (getter), 0x16dc28 (setter)
 */
@property(nonatomic, assign) UIEdgeInsets thumbEdgeInset;

/**
 * @brief The inset of a title inside a segment. Default is UIEdgeInsetsMake(0, 10, 0, 10).
 * @ghidraAddress 0x16da38 (getter), 0x16da50 (setter)
 */
@property(nonatomic, assign) UIEdgeInsets titleEdgeInsets;

/**
 * @brief The corner radius of the drawn track. Default is 4.0.
 * @ghidraAddress 0x16d940 (getter), 0x16d950 (setter)
 */
@property(nonatomic, assign) double cornerRadius;

/**
 * @brief The title font. Default is [UIFont boldSystemFontOfSize:15].
 * @ghidraAddress 0x16d994 (getter), 0x16d9a4 (setter)
 */
@property(nonatomic, strong, nullable) UIFont *font;

/**
 * @brief The title colour. Default is gray.
 * @ghidraAddress 0x16d9b8 (getter), 0x16d9c8 (setter)
 */
@property(nonatomic, strong, nullable) UIColor *textColor;

/**
 * @brief The title shadow colour. Default is black.
 * @ghidraAddress 0x16d9dc (getter), 0x16d9ec (setter)
 */
@property(nonatomic, strong, nullable) UIColor *textShadowColor;

/**
 * @brief The title shadow offset. Default is CGSizeMake(0, -1).
 * @ghidraAddress 0x16da00 (getter), 0x16da14 (setter)
 */
@property(nonatomic, assign) CGSize textShadowOffset;

#pragma mark - Deprecated appearance aliases

/**
 * @brief Deprecated alias of @c textShadowColor. The setter forwards to @c -setTextShadowColor:.
 * @ghidraAddress 0x16dc40 (getter), 0x16d898 (setter)
 */
@property(nonatomic, strong, nullable) UIColor *shadowColor;

/**
 * @brief Deprecated alias of @c textShadowOffset. The setter forwards to @c -setTextShadowOffset:.
 * @ghidraAddress 0x16dc50 (getter), 0x16d88c (setter)
 */
@property(nonatomic, assign) CGSize shadowOffset;

/**
 * @brief Deprecated title padding. The setter forwards to symmetric left/right @c titleEdgeInsets.
 * @ghidraAddress 0x16da28 (getter), 0x16d870 (setter)
 */
@property(nonatomic, assign) double segmentPadding;

#pragma mark - Lifecycle and layout

/**
 * @brief Builds the control with the library defaults and the supplied segment titles.
 * @param titlesArray The segment titles.
 * @return The initialised control.
 * @ghidraAddress 0x16a4b0
 */
- (nullable instancetype)initWithSectionTitles:(NSArray<NSString *> *)titlesArray;

/**
 * @brief Selects a segment, optionally animating the thumb to it.
 * @param segmentIndex The segment to select.
 * @param animate Whether to animate the move.
 * @ghidraAddress 0x16d534
 */
- (void)moveThumbToIndex:(NSUInteger)segmentIndex animate:(BOOL)animate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
