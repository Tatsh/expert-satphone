/** @file
 * The Applilink SDK's in-app video-player and notice host.
 *
 * A queue-guarded singleton that owns the on-screen @c ApplilinkVideoController: it presents the
 * player inside a caller-supplied view on the main queue, tears it back down, and relays the
 * player's ready/notice/close callbacks to the SDK delegate. Notices are forwarded only when the
 * delegate implements the optional selector.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkViewManager, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. This is a jubeat-specific SDK
 * class with no counterpart in the sibling @c ../rbplus-src tree.
 */

#import <UIKit/UIKit.h>

@class ApplilinkParameters;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The SDK-delegate callbacks the manager relays. The receiver is dispatched dynamically
 * after a @c -respondsToSelector: guard, so the protocol only documents the selectors.
 */
@protocol ApplilinkViewManagerSdkDelegate <NSObject>
@optional
- (void)openedNotice;
- (void)closeNotice:(nullable id)view;
- (void)viewReady:(nullable id)view;
@end

/**
 * @brief The Applilink in-app video-player host singleton.
 */
@interface ApplilinkViewManager : NSObject

/**
 * @brief The SDK delegate that opened-notice and close-notice callbacks are relayed to.
 * @ghidraAddress 0x2486e4
 */
@property(weak, nonatomic, nullable) id<ApplilinkViewManagerSdkDelegate> sdkDelegate;

/**
 * @brief The shared instance, creating the private serial queue on first use.
 * @return The one and only manager.
 * @ghidraAddress 0x247e98
 */
+ (instancetype)sharedInstance;

/**
 * @brief Presents the video player inside a view on the main queue.
 *
 * Does nothing when a player is already on screen. Otherwise builds an
 * @c ApplilinkVideoController sized to the screen, installs it in @p view, makes the manager its
 * SDK delegate, and hands it the playback parameters.
 * @param view The view to host the player.
 * @param parentWindowFlag Whether the player treats its host as a parent window.
 * @param query The video request query.
 * @param autoPlay Whether playback starts automatically.
 * @param applilinkParams The applilink request parameters.
 * @param delegate The SDK delegate to relay callbacks to.
 * @ghidraAddress 0x247f3c
 */
- (void)showVideoViewWithUIView:(nullable UIView *)view
               parentWindowFlag:(BOOL)parentWindowFlag
                          query:(nullable NSString *)query
                       autoPlay:(BOOL)autoPlay
                applilinkParams:(nullable ApplilinkParameters *)applilinkParams
                       delegate:(nullable id)delegate;

/**
 * @brief Tears the video player down and drops the player and delegate references, on the main
 * queue.
 * @ghidraAddress 0x2482b8
 */
- (void)closeVideoView;

/**
 * @brief Relays an opened-notice callback to the SDK delegate when it responds to it.
 * @ghidraAddress 0x2483d0
 */
- (void)openNotice;

/**
 * @brief Relays a close-notice callback to the SDK delegate, then tears down the player when the
 * closing view is the current one.
 * @param view The view that reported the close.
 * @ghidraAddress 0x24847c
 */
- (void)closeNotice:(nullable id)view;

/**
 * @brief Relays a view-ready callback to the SDK delegate when it responds to it.
 * @param view The view that became ready.
 * @ghidraAddress 0x24855c
 */
- (void)viewReady:(nullable id)view;

/**
 * @brief Forwards a rotation to the current player, if any.
 * @param orientation The new interface orientation.
 * @param duration The rotation animation duration.
 * @ghidraAddress 0x248618
 */
- (void)rotateWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                              duration:(NSTimeInterval)duration;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
