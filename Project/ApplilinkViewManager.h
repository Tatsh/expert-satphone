/**
 * @file
 * The Applilink SDK's in-app video-player and notice host.
 *
 * A queue-guarded singleton that owns the on-screen @c ApplilinkVideoController: it presents the
 * player inside a caller-supplied view on the main queue, tears it back down, and relays the
 * player's ready/notice/close callbacks to the SDK delegate. Notices are forwarded only when the
 * delegate implements the optional selector.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkViewManager, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. This is a jubeat-specific SDK
 * class.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkStore.h"

@class ApplilinkParameters;

NS_ASSUME_NONNULL_BEGIN

/**
 * The SDK-delegate callbacks the manager relays. The receiver is dispatched dynamically
 * after a @c -respondsToSelector: guard, so the protocol only documents the selectors.
 */
@protocol ApplilinkViewManagerSdkDelegate <NSObject>
@optional
/** The managed view opened. */
- (void)openedNotice;
/**
 * The managed view was closed.
 * @param view The view that closed.
 */
- (void)closeNotice:(nullable id)view;
/**
 * The managed view finished loading and is ready.
 * @param view The view that became ready.
 */
- (void)viewReady:(nullable id)view;
@end

/**
 * The Applilink in-app video-player host singleton.
 *
 * Acts as the hosted @c ApplilinkVideoController 's @c SdkViewDelegate, relaying the ready and
 * close callbacks on to its own @c sdkDelegate.
 */
@interface ApplilinkViewManager : NSObject <SdkViewDelegate>

/**
 * The SDK delegate that opened-notice and close-notice callbacks are relayed to.
 * @ghidraAddress 0x2486e4
 */
@property(weak, nonatomic, nullable) id<ApplilinkViewManagerSdkDelegate> sdkDelegate;

/**
 * The shared instance, creating the private serial queue on first use.
 * @return The one and only manager.
 * @ghidraAddress 0x247e98
 */
+ (instancetype)sharedInstance;

/**
 * Presents the video player inside a view on the main queue.
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
 * Tears the video player down and drops the player and delegate references, on the main
 * queue.
 * @ghidraAddress 0x2482b8
 */
- (void)closeVideoView;

/**
 * Relays an opened-notice callback to the SDK delegate when it responds to it.
 * @ghidraAddress 0x2483d0
 */
- (void)openNotice;

/**
 * Relays a close-notice callback to the SDK delegate, then tears down the player when the
 * closing view is the current one.
 * @param view The view that reported the close.
 * @ghidraAddress 0x24847c
 */
- (void)closeNotice:(nullable id)view;

/**
 * Relays a view-ready callback to the SDK delegate when it responds to it.
 * @param view The view that became ready.
 * @ghidraAddress 0x24855c
 */
- (void)viewReady:(nullable id)view;

/**
 * Forwards a rotation to the current player, if any.
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
