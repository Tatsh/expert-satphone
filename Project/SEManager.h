/**
 * @file
 * @brief Keeps track of which sound effects are playing.
 *
 * Reconstructed from Ghidra program Jubeat (class SEManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject, from the dyld bind at the class object's superclass slot
 * (0x34d1e8).
 *
 * There is no shared instance: the class is a plain object a caller owns. Its whole state is one
 * set of players, and the three delegate callbacks plus @c -stopAll take that set's lock with
 * @c \@synchronized before touching it — @c -play: is the one method that does not. See
 * TYPES_PENDING.md.
 */

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Starts sound effects and stops them together.
 */
@interface SEManager : NSObject <AVAudioPlayerDelegate>

/**
 * @brief Builds the manager with room for thirty-two players.
 * @return The initialised manager.
 * @ghidraAddress 0x79064
 */
- (instancetype)init;

/**
 * @brief Starts a player and takes ownership of its delegate callbacks.
 *
 * A player that refuses to start is neither tracked nor made to report back.
 *
 * @param player The player to start.
 * @ghidraAddress 0x790ec
 */
- (void)play:(nullable AVAudioPlayer *)player;

/**
 * @brief Stops everything currently playing and forgets it.
 * @ghidraAddress 0x79158
 */
- (void)stopAll;

/**
 * @brief Forgets a player that has finished.
 *
 * The success flag is not consulted, so a player that failed is forgotten just the same.
 *
 * @param player The finished player.
 * @param flag Whether playback completed. Ignored.
 * @ghidraAddress 0x792e4
 */
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag;

/**
 * @brief Inert. The body is a single @c ret .
 * @param player Ignored.
 * @param error Ignored.
 * @ghidraAddress 0x79380
 */
- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(nullable NSError *)error;

/**
 * @brief Forgets a player the system has interrupted.
 *
 * The player is dropped from the set but not stopped — the interruption has already silenced it,
 * and nothing here can resume it afterwards.
 *
 * @param player The interrupted player.
 * @ghidraAddress 0x79384
 */
- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
