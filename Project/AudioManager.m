#import "AudioManager.h"

#import <UIKit/UIKit.h>

#import "SEManager.h"

@implementation AudioManager {
    // Declared in this order by the runtime metadata; the ivar offset globals sit in a different
    // order again, and the offsets are what the code indexes by.
    float bgmVolume;                // offset global 0x349f1c
    AVAudioPlayer *pushedBgmPlayer; // offset global 0x349f40
    float pushedBgmVolume;          // offset global 0x349f18
    BOOL fadeInOrOut;               // offset global 0x349f30
    NSTimer *fadeTimer;             // offset global 0x349f2c
    double fadeInterval;            // offset global 0x349f38
    double fadeDuration;            // offset global 0x349f34
    SEManager *seManager;           // offset global 0x349f20
    BOOL isBgmSuspended;            // offset global 0x349f3c
}

/** @ghidraAddress 0x77d28 */
+ (AudioManager *)sharedManager {
    static AudioManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x77d68 */
      instance = [[AudioManager alloc] init];
    });
    return instance;
}

/** @ghidraAddress 0x77da8 */
- (instancetype)init {
    self = [super init];
    if (self) {
        // Both start at full; the fade machinery moves bgmVolume from here.
        pushedBgmVolume = 1.0f;
        bgmVolume = 1.0f;
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(appDidBecomeActive:)
                                                   name:UIApplicationDidBecomeActiveNotification
                                                 object:nil];
        seManager = [[SEManager alloc] init];
    }
    return self;
}

#pragma mark - Sound effects

/** @ghidraAddress 0x780e4 */
- (void)playSePlayer:(AVAudioPlayer *)player {
    // The nil check is here rather than in SEManager, whose -play: does not guard.
    if (!player) {
        return;
    }
    [seManager play:player];
}

/** @ghidraAddress 0x78104 */
- (void)stopAllSe {
    [seManager stopAll];
}

#pragma mark - Background music position

/** @ghidraAddress 0x78448 */
- (void)seekBgmToTop {
    if (self.bgmPlayer) {
        self.bgmPlayer.currentTime = 0.0;
    }
}

/** @ghidraAddress 0x78850 */
- (double)bgmPos {
    // Unguarded, unlike -seekBgmToTop: a message to a nil player returns zero.
    return self.bgmPlayer.currentTime;
}

/** @ghidraAddress 0x78868 */
- (void)setBgmPos:(double)bgmPos {
    self.bgmPlayer.currentTime = bgmPos;
}

/** @ghidraAddress 0x78880 */
- (double)bgmDuration {
    return self.bgmPlayer.duration;
}

/** @ghidraAddress 0x78898 */
- (BOOL)bgmPlaying {
    return self.bgmPlayer.playing;
}

#pragma mark - Interruptions

/** @ghidraAddress 0x78ebc */
- (void)beginInterruption {
    _interrupted = YES;
}

/** @ghidraAddress 0x78ed0 */
- (void)endInterruption {
    _interrupted = NO;
}

/** @ghidraAddress 0x78d9c */
- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    // Empty in the binary: the whole body is a single ret at 0x78d9c, so a decode error is
    // swallowed without so much as a log.
}

@end
