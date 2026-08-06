/** @file
 * The single owner of all sound: one background music player, plus a delegated sound-effect pool.
 *
 * Reconstructed from Ghidra program Jubeat (class AudioManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject , from the dyld bind at the class object's superclass slot
 * (0x34d1c0).
 *
 * Sound effects are not handled here at all; every effect method forwards to the @c SEManager the
 * initialiser builds. What this class owns is the one BGM player, its volume, and the fade timer
 * that moves between them.
 *
 * RECONSTRUCTION STATE: seventeen of thirty-two members written. The fade out, push/pop, and
 * interruption callbacks are declared but not reconstructed; see RECONSTRUCTION_STATUS.md.
 */

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The application's one audio manager.
 */
@interface AudioManager : NSObject <AVAudioPlayerDelegate>

/**
 * @brief The shared instance.
 * @return The manager.
 * @ghidraAddress 0x77d28
 */
@property(class, nonatomic, readonly) AudioManager *sharedManager;

/**
 * @brief The player the background music is running on.
 * @ghidraAddress 0x349f24 (ivar offset global)
 */
@property(nonatomic, readonly, nullable) AVAudioPlayer *bgmPlayer;

/**
 * @brief Whether an audio-session interruption is currently in effect.
 * @ghidraAddress 0x349f28 (ivar offset global)
 */
@property(nonatomic, readonly) BOOL interrupted;

/**
 * @brief How far into the background music playback has reached, in seconds.
 *
 * Read-only as a property, but a setter exists as a plain method — see @c -setBgmPos: .
 *
 * @ghidraAddress 0x78850
 */
@property(nonatomic, readonly) double bgmPos;

/**
 * @brief The background music's length in seconds.
 * @ghidraAddress 0x78880
 */
@property(nonatomic, readonly) double bgmDuration;

/**
 * @brief Whether the background music is playing.
 * @ghidraAddress 0x78898
 */
@property(nonatomic, readonly) BOOL bgmPlaying;

/**
 * @brief Builds the manager and its sound-effect pool.
 *
 * Sets both volumes to full, subscribes to @c UIApplicationDidBecomeActiveNotification , and
 * creates the @c SEManager .
 *
 * @return The initialised manager.
 * @ghidraAddress 0x77da8
 */
- (instancetype)init;

/**
 * @brief Seeks the background music back to its start.
 *
 * Does nothing when no player is loaded.
 *
 * @ghidraAddress 0x78448
 */
- (void)seekBgmToTop;

/**
 * @brief Moves the background music's playback position.
 *
 * @param bgmPos The new position in seconds.
 * @ghidraAddress 0x78868
 */
- (void)setBgmPos:(double)bgmPos;

/**
 * @brief Plays an already-prepared sound-effect player.
 *
 * Ignores a nil player rather than forwarding it.
 *
 * @param player The effect to play.
 * @ghidraAddress 0x780e4
 */
- (void)playSePlayer:(nullable AVAudioPlayer *)player;

/**
 * @brief Stops every sound effect in flight.
 * @ghidraAddress 0x78104
 */
- (void)stopAllSe;

/**
 * @brief Marks the start of an audio-session interruption.
 * @ghidraAddress 0x78ebc
 */
- (void)beginInterruption;

/**
 * @brief Marks the end of an audio-session interruption.
 * @ghidraAddress 0x78ed0
 */
- (void)endInterruption;

/**
 * @brief Plays a sound effect from a file path.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param path The file to play.
 * @ghidraAddress 0x77ea0
 */
- (void)playSeFile:(nullable NSString *)path;

/**
 * @brief Plays a sound effect from a bundle resource.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param name The resource name.
 * @param directory The bundle subdirectory.
 * @ghidraAddress 0x77f50
 */
- (void)playSeResFile:(nullable NSString *)name inDirectory:(nullable NSString *)directory;

/**
 * @brief Plays a sound effect from data already in memory.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param data The encoded audio.
 * @ghidraAddress 0x78040
 */
- (void)playSeData:(nullable NSData *)data;

/**
 * @brief Loads background music from a file path.
 *
 * Drops any previous player first, so a failed load leaves nothing loaded.
 *
 * @param path The file to load.
 * @return @c YES when the music loaded.
 * @ghidraAddress 0x7811c
 */
- (BOOL)loadBgmFile:(nullable NSString *)path;

/**
 * @brief Loads background music from a bundled AAC resource.
 *
 * The extension is fixed at @c m4a , so this only ever finds AAC.
 *
 * @param name The resource name.
 * @param directory The bundle subdirectory.
 * @return @c YES when the music loaded.
 * @ghidraAddress 0x78248
 */
- (BOOL)loadBgmResAAC:(nullable NSString *)name inDirectory:(nullable NSString *)directory;

/**
 * @brief Loads background music from data already in memory.
 *
 * @param data The encoded audio.
 * @return @c YES when the music loaded.
 * @ghidraAddress 0x7834c
 */
- (BOOL)loadBgmData:(nullable NSData *)data;

/**
 * @brief Starts the background music, optionally fading it in.
 *
 * Does nothing when no player is loaded or one is already playing. During an interruption the
 * request is remembered rather than played.
 *
 * @param loop Whether the track repeats.
 * @param fadeTime How long the fade in takes; a value at or below the tick interval skips it.
 * @ghidraAddress 0x7846c
 */
- (void)startBgm:(BOOL)loop fadeTime:(double)fadeTime;

/**
 * @brief Advances a fade in by one tick.
 *
 * Ignores a timer that is not the current one, which is how a superseded fade is discarded.
 *
 * @param timer The driving timer.
 * @ghidraAddress 0x78690
 */
- (void)onFadeinTimer:(nullable NSTimer *)timer;

/**
 * @brief Stops the background music.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @ghidraAddress 0x787a4
 */
- (void)stopBgm;

/**
 * @brief Saves the current background music so another track can play over it.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @ghidraAddress 0x788b0
 */
- (void)pushBgm;

/**
 * @brief Restores the background music saved by @c -pushBgm .
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @return @c YES when something was restored.
 * @ghidraAddress 0x7894c
 */
- (BOOL)popBgm;

/**
 * @brief Fades the background music out over a time.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param fadeTime How long the fade takes.
 * @ghidraAddress 0x789f0
 */
- (void)fadeoutBgm:(double)fadeTime;

/**
 * @brief Changes the background music's playback rate.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param speed The new rate.
 * @ghidraAddress 0x78b6c
 */
- (void)setBgmSpeed:(float)speed;

/**
 * @brief Advances a fade out by one tick.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param timer The driving timer.
 * @ghidraAddress 0x78bc0
 */
- (void)onFadeoutTimer:(nullable NSTimer *)timer;

/**
 * @brief Drops a background music player.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param stopFirst Whether the player is stopped before being dropped.
 * @ghidraAddress 0x78cb0
 */
- (void)releaseBgm:(BOOL)stopFirst;

/**
 * @brief Called back when the application returns to the foreground.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param notification The notification.
 * @ghidraAddress 0x78ee0
 */
- (void)appDidBecomeActive:(nullable NSNotification *)notification;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
