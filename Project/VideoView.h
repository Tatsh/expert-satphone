/** @file
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
 * @brief The lifecycle callbacks the video player reports to its owner.
 *
 * Every method is optional; the player guards each dispatch with @c -respondsToSelector: .
 */
@protocol VideoViewDelegate <NSObject>
@optional
/**
 * @brief The on-screen chrome finished building.
 * @param view The player sending the message.
 */
- (void)viewReady:(nullable VideoView *)view;
/** @brief The movie became ready to play. */
- (void)movieReady;
/** @brief The movie started playing. */
- (void)movieStart;
/** @brief The movie stopped at its end (or was skipped). */
- (void)movieEnd;
/** @brief The movie finished buffering to the cache. */
- (void)movieCacheEnd;
/** @brief The movie is playing with sound. */
- (void)movieSoundUse;
/** @brief The movie could not stream (timeout or buffer stall). */
- (void)movieError;
/** @brief The movie could not auto-start because it was not yet cached. */
- (void)movieAutoStartError;
/**
 * @brief The player wants to close.
 * @param view The player sending the message.
 */
- (void)closeNotice:(nullable VideoView *)view;
/**
 * @brief The player wants to open the store.
 * @param view The player sending the message.
 */
- (void)storeNotice:(nullable VideoView *)view;
@end

/**
 * @brief An @c AVPlayer-backed advert-video view with a touch-revealed menu overlay.
 */
@interface VideoView : UIView

/**
 * @brief The lifecycle delegate.
 *
 * Held @c assign (a plain pointer store, not @c objc_storeWeak), so the owner must clear it via
 * @c -clearDelegate before the delegate is deallocated.
 */
@property(assign, nonatomic, nullable) id<VideoViewDelegate> delegate;
/** @brief The player driving playback. */
@property(strong, nonatomic, nullable) AVPlayer *player;
/** @brief The layer that renders the player's video. */
@property(strong, nonatomic, nullable) AVPlayerLayer *playerLayer;
/** @brief The current item being played. */
@property(strong, nonatomic, nullable) AVPlayerItem *playerItem;
/** @brief The menu overlay container. Note the binary's misspelling "memu". */
@property(strong, nonatomic, nullable) UIView *memuView;
/** @brief The top gradient strip that hosts the back, sound, and time controls. */
@property(strong, nonatomic, nullable) GradationView *gradationTopView;
/** @brief The bottom gradient strip that hosts the store button. Note the binary's misspelling
 * "Buttom". */
@property(strong, nonatomic, nullable) GradationView *gradationButtomView;
/**
 * @brief The menu overlay state.
 *
 * 0 = hidden, 1 = shown, 2 = animating, 3 = finished (menu pinned on after playback ends). Backed
 * by an @c int-width ivar.
 */
@property(assign, nonatomic) int menuStatus;
/** @brief The label showing the remaining play time. */
@property(strong, nonatomic, nullable) UILabel *currentTimeLabel;
/** @brief The back button. */
@property(strong, nonatomic, nullable) UIButton *backButton;
/** @brief The store button. */
@property(strong, nonatomic, nullable) UIButton *storeButton;
/** @brief The sound-state indicator (a @c UIButton with user interaction disabled). */
@property(strong, nonatomic, nullable) UIButton *soundButton;
/** @brief The play/pause button. */
@property(strong, nonatomic, nullable) UIButton *playButton;
/** @brief The poster image shown before playback begins. */
@property(strong, nonatomic, nullable) UIImageView *posterImg;
/** @brief The token returned by @c -addPeriodicTimeObserverForInterval:queue:usingBlock: . */
@property(strong, nonatomic, nullable) id playTimeObserver;
/** @brief The GCD timer source that polls the cached duration. */
@property(strong, nonatomic, nullable) dispatch_source_t timerSource;
/** @brief Set once a streaming error has been shown, to suppress a second overlay. */
@property(assign, nonatomic) BOOL errorFlg;
/** @brief Set once the movie has started playing. */
@property(assign, nonatomic) BOOL playFlg;
/** @brief Set when the movie should auto-start as soon as it is ready. */
@property(assign, nonatomic) BOOL autoPlayFlg;

/**
 * @brief Initialises a transparent, non-opaque, aspect-fit video view.
 * @param frame The view frame.
 * @return The initialised view.
 * @ghidraAddress 0x227104
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Marks the view to auto-start playback once the movie is ready.
 * @ghidraAddress 0x2272a0
 */
- (void)setAutoPlay;

/**
 * @brief Begins resolving and loading the movie, then builds the on-screen chrome.
 * @param movieUrl The movie URL (cached file or stream).
 * @param posterUrl The poster/banner image URL.
 * @param movieVoiceFlg @c @"1" to play with sound, otherwise muted.
 * @ghidraAddress 0x2272b4
 */
- (void)setMovieUrl:(nullable NSString *)movieUrl
          posterUrl:(nullable NSString *)posterUrl
      movieVoiceFlg:(nullable NSString *)movieVoiceFlg;

/**
 * @brief Loads the poster image from the applilink cache and installs it behind the chrome.
 * @param url The poster/banner image URL.
 * @ghidraAddress 0x228c6c
 */
- (void)setPosterImgWithUrl:(nullable NSString *)url;

/**
 * @brief Tears the player down and reports @c -closeNotice: to the delegate.
 * @ghidraAddress 0x2290b8
 */
- (void)backAction;

/**
 * @brief Toggles the movie's volume and the sound indicator's selected state.
 * @param sender The sound button.
 * @ghidraAddress 0x229188
 */
- (void)soundAction:(nullable UIButton *)sender;

/**
 * @brief Pauses playback and reports @c -storeNotice: to the delegate.
 * @ghidraAddress 0x229224
 */
- (void)storeAction;

/**
 * @brief Toggles play/pause; on first play removes the poster and starts the timer.
 * @param sender The play button.
 * @ghidraAddress 0x2292a8
 */
- (void)playAction:(nullable UIButton *)sender;

/**
 * @brief Pauses playback and reports @c -movieEnd to the delegate.
 * @param sender The originating control.
 * @ghidraAddress 0x229458
 */
- (void)skipAction:(nullable id)sender;

/**
 * @brief Seeks to the start, replays, and reports @c -movieStart to the delegate.
 * @ghidraAddress 0x2294d8
 */
- (void)repeat;

/**
 * @brief Pauses playback and deselects the play button.
 * @ghidraAddress 0x2295c0
 */
- (void)pause;

/**
 * @brief Pauses, hides the play button, and pins the menu on (finished state).
 * @ghidraAddress 0x229614
 */
- (void)finish;

/**
 * @brief KVO handler for the player item's status and buffering key paths.
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
 * @brief Notification handler for @c AVPlayerItemDidPlayToEndTimeNotification .
 * @param notification The play-to-end notification.
 * @ghidraAddress 0x22996c
 */
- (void)playerDidPlayToEndTime:(nullable NSNotification *)notification;

/**
 * @brief Installs the periodic remaining-time observer and refreshes the readout once.
 * @ghidraAddress 0x2299f8
 */
- (void)setupTimer;

/**
 * @brief Refreshes the remaining-time label and reschedules the pause check.
 * @ghidraAddress 0x229bb0
 */
- (void)syncTimeRemaining;

/**
 * @brief Pauses if the play button is currently selected.
 * @ghidraAddress 0x229d28
 */
- (void)pauseCheck;

/**
 * @brief Formats a remaining time in seconds as a @c mm:ss string.
 * @param time The remaining time in seconds.
 * @return The formatted string.
 * @ghidraAddress 0x229dac
 */
- (nullable NSString *)timeToString:(float)time;

/**
 * @brief Creates and starts the GCD timer that polls the cached duration twice a second.
 * @ghidraAddress 0x229e3c
 */
- (void)setCacheTimer;

/**
 * @brief Suspends the cache timer if it is running.
 * @ghidraAddress 0x229fe0
 */
- (void)pauseTimer;

/**
 * @brief Cancels and releases the cache timer and any pending timeout check.
 * @ghidraAddress 0x229ff8
 */
- (void)cancelTimer;

/**
 * @brief Polls how much of the movie has buffered, revealing the play button and firing cache-end.
 * @return The buffered duration in seconds.
 * @ghidraAddress 0x22a070
 */
- (double)availableDuration;

/**
 * @brief Toggles the menu overlay on touch.
 * @param touches The touches that began.
 * @param event The event they belong to.
 * @ghidraAddress 0x22a3ec
 */
- (void)touchesBegan:(nullable NSSet *)touches withEvent:(nullable UIEvent *)event;

/**
 * @brief Fades the menu overlay in.
 * @ghidraAddress 0x22a5e8
 */
- (void)menuOn;

/**
 * @brief Fades the menu overlay out (only while playing and not in the error or finished state).
 * @ghidraAddress 0x22a724
 */
- (void)menuOff;

/**
 * @brief Arms the streaming-timeout watchdog.
 * @ghidraAddress 0x22a8fc
 */
- (void)streamingTimeoutWatch;

/**
 * @brief Fires a streaming error if playback still has not begun when the watchdog elapses.
 * @ghidraAddress 0x22a96c
 */
- (void)streamingTimeoutNowCheck;

/**
 * @brief Reports the streaming error, tears the player down, and shows the error overlay.
 * @ghidraAddress 0x22a9c4
 */
- (void)streamingError;

/**
 * @brief Store lifecycle notice stub (empty in the binary).
 * @ghidraAddress 0x22b048
 */
- (void)openErrorNotice;

/**
 * @brief Store lifecycle notice stub (empty in the binary).
 * @ghidraAddress 0x22b04c
 */
- (void)appStoreOpenedNotice;

/**
 * @brief Store lifecycle notice stub (empty in the binary).
 * @ghidraAddress 0x22b050
 */
- (void)appStoreCloseNotice;

/**
 * @brief Store lifecycle notice stub (empty in the binary).
 * @ghidraAddress 0x22b054
 */
- (void)appStoreClosedNotice;

/**
 * @brief Store lifecycle notice stub (empty in the binary).
 * @param error The load error, ignored.
 * @ghidraAddress 0x22b058
 */
- (void)appStoreFailLoadNoticeWithError:(nullable NSError *)error;

/**
 * @brief Store lifecycle notice stub (empty in the binary).
 * @ghidraAddress 0x22b05c
 */
- (void)appStoreTransitionNotice;

/**
 * @brief Cancels the timer, removes observers, and releases the player, layer, and item.
 * @ghidraAddress 0x22b060
 */
- (void)deallocPlayer;

/**
 * @brief Clears the delegate pointer.
 * @ghidraAddress 0x22b1f4
 */
- (void)clearDelegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
