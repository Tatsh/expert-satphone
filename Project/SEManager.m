#import "SEManager.h"

// How many players the set is built for.
static const int kPlayingSetCapacity = 32;

@implementation SEManager {
    NSMutableSet *playingSEs;
}

/** @ghidraAddress 0x79064 */
- (instancetype)init {
    self = [super init];
    if (self) {
        playingSEs = [[NSMutableSet alloc] initWithCapacity:kPlayingSetCapacity];
    }
    return self;
}

/** @ghidraAddress 0x790ec */
- (void)play:(AVAudioPlayer *)player {
    // Started first, and only tracked if it actually started. This is the one method that touches
    // the set without holding its lock.
    if ([player play]) {
        player.delegate = self;
        [playingSEs addObject:player];
    }
}

/** @ghidraAddress 0x79158 */
- (void)stopAll {
    @synchronized(playingSEs) {
        // The emptiness test guards the removal as well as the loop, so an empty set does no work
        // at all.
        if (playingSEs.count != 0) {
            for (AVAudioPlayer *player in playingSEs) {
                [player stop];
            }
            [playingSEs removeAllObjects];
        }
    }
}

/** @ghidraAddress 0x792e4 */
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    // Yes, flag is unused: a player that failed is forgotten on the same path as one that finished.
    @synchronized(playingSEs) {
        if ([playingSEs containsObject:player]) {
            [playingSEs removeObject:player];
        }
    }
}

/** @ghidraAddress 0x79380 */
- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    // The binary's body is a single ret. A decode failure leaves the player in the set for good,
    // unlike every other way a player leaves it.
}

/** @ghidraAddress 0x79384 */
- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    // Instruction for instruction the same as the finish callback above, minus the unused flag. The
    // player is forgotten but not stopped.
    @synchronized(playingSEs) {
        if ([playingSEs containsObject:player]) {
            [playingSEs removeObject:player];
        }
    }
}

@end
