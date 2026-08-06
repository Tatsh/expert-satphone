#import "AudioManager.h"

#import <UIKit/UIKit.h>

#import "SEManager.h"

// -loadBgmResAAC:inDirectory: only ever looks for this extension.
static NSString *const kBgmResourceExtension = @"m4a";

// The fade timer ticks at this rate, and it doubles as the threshold below which a requested fade
// is not worth running.
static const NSTimeInterval kFadeTickInterval = 0.1; // @ghidraAddress 0x28f290

// What -startBgm:fadeTime: passes to -setNumberOfLoops: for a looping track. Not AVAudioPlayer's
// documented -1 for "forever", just a number large enough that it never runs out.
static const NSInteger kBgmLoopForever = 2000000000;

@implementation AudioManager {
    // Declared in this order by the runtime metadata; the ivar offset globals sit in a different
    // order again, and the offsets are what the code indexes by.
    float bgmVolume;                // offset global 0x349f1c
    AVAudioPlayer *pushedBgmPlayer; // offset global 0x349f40
    float pushedBgmVolume;          // offset global 0x349f18
    BOOL fadeInOrOut;               // offset global 0x349f30
    // Weak, from the objc_loadWeakRetained in -startBgm:fadeTime: and -onFadeinTimer: and the
    // objc_storeWeak that clears it. The run loop owns a scheduled timer, so this does not.
    __weak NSTimer *fadeTimer; // offset global 0x349f2c
    double fadeInterval;       // offset global 0x349f38
    double fadeDuration;       // offset global 0x349f34
    SEManager *seManager;      // offset global 0x349f20
    BOOL isBgmSuspended;       // offset global 0x349f3c
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

#pragma mark - Background music loading

/** @ghidraAddress 0x7811c */
- (BOOL)loadBgmFile:(NSString *)path {
    if (!path) {
        return NO;
    }
    // The old player goes before the new one is built, so a failed load leaves nothing loaded.
    _bgmPlayer = nil;

    NSError *error = nil;
    _bgmPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                        error:&error];
    // The test is on the error, not on the player. A player that came back nil without setting an
    // error would be kept and reported as a success.
    if (error) {
        _bgmPlayer = nil;
        return NO;
    }
    _bgmPlayer.delegate = self;
    [_bgmPlayer prepareToPlay];
    return YES;
}

/** @ghidraAddress 0x78248 */
- (BOOL)loadBgmResAAC:(NSString *)name inDirectory:(NSString *)directory {
    if (!name) {
        return NO;
    }
    // The extension is fixed, so this only ever finds AAC in an m4a container.
    NSString *path = directory ?
                         [NSBundle.mainBundle pathForResource:name
                                                       ofType:kBgmResourceExtension
                                                  inDirectory:directory] :
                         [NSBundle.mainBundle pathForResource:name ofType:kBgmResourceExtension];
    return [self loadBgmFile:path];
}

/** @ghidraAddress 0x7834c */
- (BOOL)loadBgmData:(NSData *)data {
    if (!data) {
        return NO;
    }
    _bgmPlayer = nil;

    NSError *error = nil;
    _bgmPlayer = [[AVAudioPlayer alloc] initWithData:data error:&error];
    // Same error-not-player test as -loadBgmFile:.
    if (error) {
        _bgmPlayer = nil;
        return NO;
    }
    _bgmPlayer.delegate = self;
    [_bgmPlayer prepareToPlay];
    return YES;
}

#pragma mark - Background music playback

/** @ghidraAddress 0x7846c */
- (void)startBgm:(BOOL)loop fadeTime:(double)fadeTime {
    // Does nothing without a loaded player, and nothing if one is already playing.
    if (!_bgmPlayer || _bgmPlayer.playing) {
        return;
    }

    _bgmPlayer.numberOfLoops = loop ? kBgmLoopForever : 0;

    if (_interrupted) {
        // Remembered rather than played; -appDidBecomeActive: is what resumes it.
        isBgmSuspended = YES;
        return;
    }

    // A fade shorter than one tick is not worth running, so it becomes an immediate start.
    if (fadeTime <= kFadeTickInterval) {
        _bgmPlayer.volume = bgmVolume;
        [_bgmPlayer play];
        return;
    }

    if (fadeTimer) {
        [fadeTimer invalidate];
    }
    fadeInOrOut = YES;
    _bgmPlayer.volume = 0.0f;
    // Elapsed time, despite the name; fadeInterval is the total. The two read backwards.
    fadeDuration = 0.0;
    fadeInterval = fadeTime;

    fadeTimer = [NSTimer timerWithTimeInterval:kFadeTickInterval
                                        target:self
                                      selector:@selector(onFadeinTimer:)
                                      userInfo:nil
                                       repeats:YES];
    [_bgmPlayer play];
    [NSRunLoop.currentRunLoop addTimer:fadeTimer forMode:NSRunLoopCommonModes];
}

/** @ghidraAddress 0x78690 */
- (void)onFadeinTimer:(NSTimer *)timer {
    // A timer that is not the current one is a leftover from a superseded fade.
    if (fadeTimer != timer) {
        return;
    }

    fadeDuration += kFadeTickInterval;
    if (fadeDuration < fadeInterval) {
        _bgmPlayer.volume = (float)(fadeDuration * bgmVolume / fadeInterval);
        return;
    }

    _bgmPlayer.volume = bgmVolume;
    [fadeTimer invalidate];
    fadeTimer = nil;
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
