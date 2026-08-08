/** @file
 * The mission-achievement message banner.
 *
 * Reconstructed from Ghidra program Jubeat (class MissionAchievementMessage, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView , from the @c super initWithFrame: at 0x4e150 with
 * @c UIScreen.mainScreen.bounds .
 *
 * RECONSTRUCTION STATE: complete. Grown outwards from @c -[RootViewController init] , which builds
 * one with a nil title and installs itself as the delegate.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Told when the banner has dismissed itself.
 */
@protocol MissionAchievementMessageDelegate <NSObject>
@optional
/**
 * @brief Sent when the banner finishes its exit animation and should be removed.
 */
- (void)messageClose;
@end

/**
 * @brief A tappable banner that slides in to announce a completed mission and auto-dismisses.
 */
@interface MissionAchievementMessage : UIView

/**
 * @brief The object told when the banner dismisses. Held weakly.
 * @ghidraAddress 0x349c78
 */
@property(nonatomic, weak, nullable) id<MissionAchievementMessageDelegate> aDelegate;

/**
 * @brief Builds the banner for a mission title and its achievement state.
 *
 * Fills the whole screen with a dimming background, lays out the spinning completion icon, the
 * balloon message background, and the achievement text, then parks everything off-screen with
 * @c -transReset ready for @c -enterAnimationStart .
 * @param title The mission title payload.
 * @return The initialised banner.
 * @ghidraAddress 0x4e0c8
 */
- (instancetype)initWithTitle:(nullable id)title;

/**
 * @brief Runs the four-stage entry animation and plays the completion sound.
 *
 * Clears the tap flag, plays @c SD_MISSION_GAUGE , and fades the banner in over 0.2s; the
 * completion blocks start the icon spinning, slide the message view down, settle the balloon, and
 * finally arm the 6s auto-dismiss timer.
 * @ghidraAddress 0x4ea44
 */
- (void)enterAnimationStart;

/**
 * @brief Runs the exit animation that slides the banner back off-screen.
 * @ghidraAddress 0x4f058
 */
- (void)outerAnimationStart;

/**
 * @brief Parks the balloon and message view off-screen and hides the banner, ready for entry.
 *
 * Collapses the balloon toward its arrow with a zero scale and pushes the message view up by its
 * own height, then sets the banner's alpha to zero.
 * @ghidraAddress 0x4f5cc
 */
- (void)transReset;

/**
 * @brief The auto-dismiss timer callback: clears the timer and starts the exit animation.
 * @param timer The fired timer.
 * @ghidraAddress 0x4f730
 */
- (void)dispEnd:(nullable NSTimer *)timer;

/**
 * @brief Tells the delegate the banner has closed, if it responds.
 * @ghidraAddress 0x4f76c
 */
- (void)messageEnd;

/**
 * @brief Builds the balloon background sized to @p size and adds it to the message view.
 * @param size The balloon's content size.
 * @ghidraAddress 0x4f81c
 */
- (void)createMassageBg:(CGSize)size;

/**
 * @brief Measures the height the achievement text needs for a title.
 *
 * With no title the base line height (40 on a pad, 20 otherwise) is returned; otherwise the text is
 * measured in a throwaway label and the height grows by one line per achieved entry.
 * @param title The mission title payload.
 * @return The text height in points.
 * @ghidraAddress 0x4e6fc
 */
- (int)messageHeight:(nullable id)title;

/**
 * @brief Replaces the banner's text with a new title and re-lays out the balloon.
 *
 * Tears down the old balloon and text, re-lays the text inside the balloon content box, sizes a new
 * balloon to fit, and recentres the completion icon over it.
 * @param title The mission title payload.
 * @ghidraAddress 0x4fa3c
 */
- (void)setAchieveTitle:(nullable id)title;

/**
 * @brief Builds the attributed achievement text for a title.
 *
 * The title is an array of lines of segments; segment zero of each line is the sheet name in white
 * and the rest are achieved sub-titles in orange, one per line, closed with a white flourish.
 * @param title The mission title payload.
 * @return The attributed string.
 * @ghidraAddress 0x4fcf0
 */
- (nullable NSAttributedString *)createAchiveText:(nullable id)title;

/**
 * @brief Builds the array of reward-title lines for the mission sheets and their achievement state.
 *
 * For every sheet, opens a line group with the sheet name, then for each of the sheet's mission
 * terms whose id matches an achievement record renders a "title" or "title(progress/target)" entry;
 * a group is kept only when it gained at least one entry beyond its name.
 * @param title The array of @c ChallengeMissionSheet mission sheets.
 * @param achieve The achievement records, keyed by mission id.
 * @return The array of line groups, each an array of strings.
 * @ghidraAddress 0x4d790
 */
+ (nullable NSArray *)createTitleArray:(nullable NSArray *)title
                               achieve:(nullable NSDictionary *)achieve;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
