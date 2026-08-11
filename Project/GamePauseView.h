/** @file
 * The in-game pause overlay with resume, restart, and end buttons.
 *
 * Reconstructed from Ghidra program Jubeat (class GamePauseView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x34d848.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c GamePauseView tells its owner when a button is tapped.
 *
 * The protocol's name is the binary's own, from the delegate ivar's encoding
 * @c \@"<GamePauseViewDelegate>" .
 */
@protocol GamePauseViewDelegate <NSObject>
/** @brief Sent when the resume button is tapped. */
- (void)resumeInPauseView;
/** @brief Sent when the restart button is tapped. */
- (void)restartInPauseView;
/** @brief Sent when the end button is tapped. */
- (void)endInPauseView;
@end

/**
 * @brief A modal pause overlay themed per the current game theme.
 */
@interface GamePauseView : UIView

/**
 * @brief The object told when a button is tapped. Held weakly.
 * @ghidraAddress 0x98a50 (getter)
 */
@property(nonatomic, weak, nullable) id<GamePauseViewDelegate> delegate;

/**
 * @brief Builds the overlay, themed and laid out per the current theme and challenge mode.
 * @return The initialised overlay.
 * @ghidraAddress 0x97400
 */
- (instancetype)init;

/**
 * @brief Presents the overlay over a view, optionally fading it in.
 * @param view The view to present over.
 * @param animated Whether to fade in.
 * @ghidraAddress 0x98134
 */
- (void)showInView:(nonnull UIView *)view animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
