/**
 * @file
 * The applilink recommend SDK's streaming-video player view.
 *
 * @c VideoView is the SDK @c UIView that plays an advert movie through an @c AVPlayer /
 * @c AVPlayerLayer, overlaying a menu (back, store, sound-state, and play/pause controls, two
 * @c GradationView strips, and a remaining-time label) over the video. It resolves the media from
 * the applilink cache or streams it, drives a periodic time observer and a GCD cache-poll timer,
 * watches for a streaming timeout, and reports the movie and store lifecycle back to a
 * @c VideoViewDelegate. This is a closed SDK class, recovered from the jubeat binary alone.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * Two ivar/property names carry the binary's own misspellings and are kept verbatim: @c memuView
 * (for "menuView") and @c gradationButtomView (for "gradationBottomView").
 */

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@class GradationView;
@class VideoView;

NS_ASSUME_NONNULL_BEGIN

/**
 * The lifecycle callbacks the video player reports to its owner.
 *
 * Every method is optional; the player guards each dispatch with @c -respondsToSelector: .
 */
@protocol VideoViewDelegate <NSObject>
@optional
/**
 * The on-screen chrome finished building.
 * @param view The player sending the message.
 */
- (void)viewReady:(nullable VideoView *)view;
/** The movie became ready to play. */
- (void)movieReady;
/** The movie started playing. */
- (void)movieStart;
/** The movie stopped at its end (or was skipped). */
- (void)movieEnd;
/** The movie finished buffering to the cache. */
- (void)movieCacheEnd;
/** The movie is playing with sound. */
- (void)movieSoundUse;
/** The movie could not stream (timeout or buffer stall). */
- (void)movieError;
/** The movie could not auto-start because it was not yet cached. */
- (void)movieAutoStartError;
/**
 * The player wants to close.
 * @param view The player sending the message.
 */
- (void)closeNotice:(nullable VideoView *)view;
/**
 * The player wants to open the store.
 * @param view The player sending the message.
 */
- (void)storeNotice:(nullable VideoView *)view;
@end

/**
 * An @c AVPlayer-backed advert-video view with a touch-revealed menu overlay.
 */
@interface VideoView : UIView

/**
 * The lifecycle delegate.
 *
 * Held @c assign (a plain pointer store, not @c objc_storeWeak), so the owner must clear it via
 * @c -clearDelegate before the delegate is deallocated.
 */
@property(assign, nonatomic, nullable) id<VideoViewDelegate> delegate;
/** The player driving playback. */
@property(strong, nonatomic, nullable) AVPlayer *player;
/** The layer that renders the player's video. */
@property(strong, nonatomic, nullable) AVPlayerLayer *playerLayer;
/** The current item being played. */
@property(strong, nonatomic, nullable) AVPlayerItem *playerItem;
/** The menu overlay container. Note the binary's misspelling "memu". */
@property(strong, nonatomic, nullable) UIView *memuView;
/** The top gradient strip that hosts the back, sound, and time controls. */
@property(strong, nonatomic, nullable) GradationView *gradationTopView;
/** The bottom gradient strip that hosts the store button. Note the binary's misspelling
 * "Buttom". */
@property(strong, nonatomic, nullable) GradationView *gradationButtomView;
/**
 * The menu overlay state.
 *
 * 0 = hidden, 1 = shown, 2 = animating, 3 = finished (menu pinned on after playback ends). Backed
 * by an @c int-width ivar.
 */
@property(assign, nonatomic) int menuStatus;
/** The label showing the remaining play time. */
@property(strong, nonatomic, nullable) UILabel *currentTimeLabel;
/** The back button. */
@property(strong, nonatomic, nullable) UIButton *backButton;
/** The store button. */
@property(strong, nonatomic, nullable) UIButton *storeButton;
/** The sound-state indicator (a @c UIButton with user interaction disabled). */
@property(strong, nonatomic, nullable) UIButton *soundButton;
/** The play/pause button. */
@property(strong, nonatomic, nullable) UIButton *playButton;
/** The poster image shown before playback begins. */
@property(strong, nonatomic, nullable) UIImageView *posterImg;
/** The token returned by @c -addPeriodicTimeObserverForInterval:queue:usingBlock: . */
@property(strong, nonatomic, nullable) id playTimeObserver;
/** The GCD timer source that polls the cached duration. */
@property(strong, nonatomic, nullable) dispatch_source_t timerSource;
/** Set once a streaming error has been shown, to suppress a second overlay. */
@property(assign, nonatomic) BOOL errorFlg;
/** Set once the movie has started playing. */
@property(assign, nonatomic) BOOL playFlg;
/** Set when the movie should auto-start as soon as it is ready. */
@property(assign, nonatomic) BOOL autoPlayFlg;

/**
 * Initialises a transparent, non-opaque, aspect-fit video view.
 * @param frame The view frame.
 * @return The initialised view.
 * @ghidraAddress 0x227104
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Marks the view to auto-start playback once the movie is ready.
 * @ghidraAddress 0x2272a0
 */
- (void)setAutoPlay;

/**
 * Begins resolving and loading the movie, then builds the on-screen chrome.
 * @param movieUrl The movie URL (cached file or stream).
 * @param posterUrl The poster/banner image URL.
 * @param movieVoiceFlg @c @"1" to play with sound, otherwise muted.
 * @ghidraAddress 0x2272b4
 */
- (void)setMovieUrl:(nullable NSString *)movieUrl
          posterUrl:(nullable NSString *)posterUrl
      movieVoiceFlg:(nullable NSString *)movieVoiceFlg;

/**
 * Loads the poster image from the applilink cache and installs it behind the chrome.
 * @param url The poster/banner image URL.
 * @ghidraAddress 0x228c6c
 */
- (void)setPosterImgWithUrl:(nullable NSString *)url;

/**
 * Tears the player down and reports @c -closeNotice: to the delegate.
 * @ghidraAddress 0x2290b8
 */
- (void)backAction;

/**
 * Toggles the movie's volume and the sound indicator's selected state.
 * @param sender The sound button.
 * @ghidraAddress 0x229188
 */
- (void)soundAction:(nullable UIButton *)sender;

/**
 * Pauses playback and reports @c -storeNotice: to the delegate.
 * @ghidraAddress 0x229224
 */
- (void)storeAction;

/**
 * Toggles play/pause; on first play removes the poster and starts the timer.
 * @param sender The play button.
 * @ghidraAddress 0x2292a8
 */
- (void)playAction:(nullable UIButton *)sender;

/**
 * Pauses playback and reports @c -movieEnd to the delegate.
 * @param sender The originating control.
 * @ghidraAddress 0x229458
 */
- (void)skipAction:(nullable id)sender;

/**
 * Seeks to the start, replays, and reports @c -movieStart to the delegate.
 * @ghidraAddress 0x2294d8
 */
- (void)repeat;

/**
 * Pauses playback and deselects the play button.
 * @ghidraAddress 0x2295c0
 */
- (void)pause;

/**
 * Pauses, hides the play button, and pins the menu on (finished state).
 * @ghidraAddress 0x229614
 */
- (void)finish;

/**
 * KVO handler for the player item's status and buffering key paths.
 * @param keyPath The observed key path.
 * @param object The observed object.
 * @param change The change dictionary.
 * @param context The observer context.
 * @ghidraAddress 0x229690
 */
- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary *)change
                       context:(nullable void *)context;

/**
 * Notification handler for @c AVPlayerItemDidPlayToEndTimeNotification .
 * @param notification The play-to-end notification.
 * @ghidraAddress 0x22996c
 */
- (void)playerDidPlayToEndTime:(nullable NSNotification *)notification;

/**
 * Installs the periodic remaining-time observer and refreshes the readout once.
 * @ghidraAddress 0x2299f8
 */
- (void)setupTimer;

/**
 * Refreshes the remaining-time label and reschedules the pause check.
 * @ghidraAddress 0x229bb0
 */
- (void)syncTimeRemaining;

/**
 * Pauses if the play button is currently selected.
 * @ghidraAddress 0x229d28
 */
- (void)pauseCheck;

/**
 * Formats a remaining time in seconds as a @c mm:ss string.
 * @param time The remaining time in seconds.
 * @return The formatted string.
 * @ghidraAddress 0x229dac
 */
- (nullable NSString *)timeToString:(float)time;

/**
 * Creates and starts the GCD timer that polls the cached duration twice a second.
 * @ghidraAddress 0x229e3c
 */
- (void)setCacheTimer;

/**
 * Suspends the cache timer if it is running.
 * @ghidraAddress 0x229fe0
 */
- (void)pauseTimer;

/**
 * Cancels and releases the cache timer and any pending timeout check.
 * @ghidraAddress 0x229ff8
 */
- (void)cancelTimer;

/**
 * Polls how much of the movie has buffered, revealing the play button and firing cache-end.
 * @return The buffered duration in seconds.
 * @ghidraAddress 0x22a070
 */
- (double)availableDuration;

/**
 * Toggles the menu overlay on touch.
 * @param touches The touches that began.
 * @param event The event they belong to.
 * @ghidraAddress 0x22a3ec
 */
- (void)touchesBegan:(nullable NSSet *)touches withEvent:(nullable UIEvent *)event;

/**
 * Fades the menu overlay in.
 * @ghidraAddress 0x22a5e8
 */
- (void)menuOn;

/**
 * Fades the menu overlay out (only while playing and not in the error or finished state).
 * @ghidraAddress 0x22a724
 */
- (void)menuOff;

/**
 * Arms the streaming-timeout watchdog.
 * @ghidraAddress 0x22a8fc
 */
- (void)streamingTimeoutWatch;

/**
 * Fires a streaming error if playback still has not begun when the watchdog elapses.
 * @ghidraAddress 0x22a96c
 */
- (void)streamingTimeoutNowCheck;

/**
 * Reports the streaming error, tears the player down, and shows the error overlay.
 * @ghidraAddress 0x22a9c4
 */
- (void)streamingError;

/**
 * Store lifecycle notice stub (empty in the binary).
 * @ghidraAddress 0x22b048
 */
- (void)openErrorNotice;

/**
 * Store lifecycle notice stub (empty in the binary).
 * @ghidraAddress 0x22b04c
 */
- (void)appStoreOpenedNotice;

/**
 * Store lifecycle notice stub (empty in the binary).
 * @ghidraAddress 0x22b050
 */
- (void)appStoreCloseNotice;

/**
 * Store lifecycle notice stub (empty in the binary).
 * @ghidraAddress 0x22b054
 */
- (void)appStoreClosedNotice;

/**
 * Store lifecycle notice stub (empty in the binary).
 * @param error The load error, ignored.
 * @ghidraAddress 0x22b058
 */
- (void)appStoreFailLoadNoticeWithError:(nullable NSError *)error;

/**
 * Store lifecycle notice stub (empty in the binary).
 * @ghidraAddress 0x22b05c
 */
- (void)appStoreTransitionNotice;

/**
 * Cancels the timer, removes observers, and releases the player, layer, and item.
 * @ghidraAddress 0x22b060
 */
- (void)deallocPlayer;

/**
 * Clears the delegate pointer.
 * @ghidraAddress 0x22b1f4
 */
- (void)clearDelegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
