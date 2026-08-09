#import "VideoView.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#import "ApplilinkFile.h"
#import "ApplilinkMessage.h"
#import "ApplilinkUtilities.h"
#import "GradationView.h"

// RecommendAdCache is a not-yet-reconstructed applilink cache class; only the icon-availability
// query is used here.
@interface RecommendAdCache : NSObject
+ (BOOL)getMoviePlayerIcon;
@end

// KVO key paths observed on the player item and player layer.
static NSString *const kKeyPathStatus = @"status";
static NSString *const kKeyPathPlaybackBufferEmpty = @"playbackBufferEmpty";
static NSString *const kKeyPathPlaybackLikelyToKeepUp = @"playbackLikelyToKeepUp";
static NSString *const kKeyPathReadyForDisplay = @"readyForDisplay";

// Streaming-error overlay message keys, resolved through +[ApplilinkMessage localizedMessage:].
static NSString *const kStreamingErrorMessageKey1 = @"RewardNetworkAppListErrorMessage1";
static NSString *const kStreamingErrorMessageKey2 = @"RewardNetworkAppListErrorMessage2";

// The value @"1" of the movie-voice flag means the movie plays with sound.
static NSString *const kMovieVoiceOnFlag = @"1";

// Locale codes distinguishing the Japanese asset set from the fallback.
static NSString *const kLocaleJapanese = @"ja";
static NSString *const kLocaleDefault = @"en";

// Button and label image basenames.
static NSString *const kBackImageFormat = @"back_%@.png";
static NSString *const kSoundOffImageName = @"sound_off.png";
static NSString *const kSoundOnImageName = @"sound_on.png";
static NSString *const kStoreImageFormat = @"dl_%@.png";
static NSString *const kPlayImageName = @"play.png";
static NSString *const kStopImageName = @"stop.png";

// Remaining-time label formats.
static NSString *const kTimeZeroText = @" 00:00";
static NSString *const kTimeFormat = @"-%02d:%02d";

// The shared 0.20-second animation duration global, defined elsewhere in the binary.
extern const double g_dAnimDuration020;

// The menu overlay states stored in _menuStatus.
typedef NS_ENUM(int, VideoViewMenuStatus) {
    VideoViewMenuStatusHidden = 0,    // Overlay hidden.
    VideoViewMenuStatusShown = 1,     // Overlay fully shown.
    VideoViewMenuStatusAnimating = 2, // Overlay fading in or out.
    VideoViewMenuStatusFinished = 3,  // Overlay pinned on after playback ends.
};

// The streaming-timeout watchdog delay in seconds (read from __const at 0x291bd0).
static const NSTimeInterval kStreamingTimeout = 180.0;

// The menu auto-hide delay in seconds.
static const NSTimeInterval kMenuAutoHideDelay = 3.0;

// The pause-check re-arm delay in seconds.
static const NSTimeInterval kPauseCheckDelay = 2.0;

// Fraction of the short screen side used for the streaming-error font and grey overlay component
// (read from __const at 0x2944d0).
static const CGFloat kErrorFontScale = 0.0625;

// The streaming-error overlay's grey level and alpha (read from __const at 0x28e080 for alpha).
static const CGFloat kErrorOverlayAlpha = 0.8;

@implementation VideoView

#pragma mark - Lifecycle

/** @ghidraAddress 0x227104 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
            UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
        self.contentMode = UIViewContentModeScaleAspectFit;
    }
    return self;
}

/** @ghidraAddress 0x2271e0 */
- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.playerLayer) {
        self.playerLayer.frame = self.bounds;
    }
    if (self.gradationTopView) {
        [self.gradationTopView setNeedsDisplay];
    }
    if (self.gradationButtomView) {
        [self.gradationButtomView setNeedsDisplay];
    }
}

/** @ghidraAddress 0x2272a0 */
- (void)setAutoPlay {
    self.autoPlayFlg = YES;
}

#pragma mark - Loading

/** @ghidraAddress 0x2272b4 */
- (void)setMovieUrl:(NSString *)movieUrl
          posterUrl:(NSString *)posterUrl
      movieVoiceFlg:(NSString *)movieVoiceFlg {
    [self streamingTimeoutWatch];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      /** @ghidraAddress 0x2273e0 */
      if (![RecommendAdCache getMoviePlayerIcon]) {
          if (self.delegate && [self.delegate respondsToSelector:@selector(closeNotice:)]) {
              [self.delegate closeNotice:self];
          }
          return;
      }
      NSString *fileName = [ApplilinkUtilities getFileNameFromPath:movieUrl];
      NSString *cachePath =
          [[ApplilinkFile getCacheDataPath] stringByAppendingPathComponent:fileName];
      NSURL *url;
      if ([NSFileManager.defaultManager fileExistsAtPath:cachePath]) {
          url = [NSURL fileURLWithPath:cachePath];
      } else {
          if (self.autoPlayFlg) {
              // Not cached and set to auto-play: report the error and create no player.
              if (self.delegate &&
                  [self.delegate respondsToSelector:@selector(movieAutoStartError)]) {
                  [self.delegate movieAutoStartError];
              }
              return;
          }
          url = [NSURL URLWithString:movieUrl];
      }
      self.playerItem = [[AVPlayerItem alloc] initWithURL:url];
      [self.playerItem addObserver:self
                        forKeyPath:kKeyPathStatus
                           options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                           context:nullptr];
      [self.playerItem addObserver:self
                        forKeyPath:kKeyPathPlaybackBufferEmpty
                           options:NSKeyValueObservingOptionNew
                           context:nullptr];
      [self.playerItem addObserver:self
                        forKeyPath:kKeyPathPlaybackLikelyToKeepUp
                           options:NSKeyValueObservingOptionNew
                           context:nullptr];
      [NSNotificationCenter.defaultCenter addObserver:self
                                             selector:@selector(playerDidPlayToEndTime:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.playerItem];
      self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
      BOOL soundOn = [movieVoiceFlg isEqualToString:kMovieVoiceOnFlag];
      if (soundOn) {
          [self.player setVolume:1.0f];
      } else {
          // The binary leaves the muted-path setVolume: argument in its zeroed register: 0.0f.
          [self.player setVolume:0.0f];
      }
      [self.player setMuted:!soundOn];
      self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
      [self.playerLayer addObserver:self
                         forKeyPath:kKeyPathReadyForDisplay
                            options:NSKeyValueObservingOptionNew
                            context:nullptr];
      self.playerLayer.frame = self.bounds;
      self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
      self.playerLayer.position =
          CGPointMake(CGRectGetWidth(self.bounds) * 0.5, CGRectGetHeight(self.bounds) * 0.5);
      self.playerLayer.anchorPoint = CGPointMake(0.5, 0.5);
      self.playerLayer.contentsGravity = kCAGravityCenter;
      dispatch_async(dispatch_get_main_queue(), ^{
        /** @ghidraAddress 0x2279c0 */
        [self buildPlayerChromeWithPosterUrl:posterUrl movieVoiceFlg:movieVoiceFlg];
      });
    });
}

// Main-queue body that builds the whole on-screen chrome (menu overlay, gradients, buttons, and
// time label). De-inlined from Block_VideoViewBuildPlayerChrome @ 0x2279c0.
- (void)buildPlayerChromeWithPosterUrl:(NSString *)posterUrl
                         movieVoiceFlg:(NSString *)movieVoiceFlg {
    [self.layer addSublayer:self.playerLayer];
    NSString *resourcePath = [ApplilinkFile getResourcePath];
    CGRect screen = UIScreen.mainScreen.bounds;
    // Normalise so longSide is the larger dimension and shortSide the smaller.
    CGFloat shortSide = CGRectGetWidth(screen);
    CGFloat longSide = CGRectGetHeight(screen);
    if (longSide < shortSide) {
        CGFloat swap = shortSide;
        shortSide = longSide;
        longSide = swap;
    }
    NSString *localeSuffix = [[ApplilinkUtilities localeString] isEqualToString:kLocaleJapanese] ?
                                 kLocaleJapanese :
                                 kLocaleDefault;

    self.memuView = [[UIView alloc] initWithFrame:self.frame];
    self.memuView.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    self.memuView.backgroundColor = UIColor.blackColor;
    [self addSubview:self.memuView];
    if (self.autoPlayFlg) {
        self.memuView.hidden = YES;
    }
    self.menuStatus = VideoViewMenuStatusShown;

    [self setPosterImgWithUrl:posterUrl];

    // The gradient strips are longSide/8 + 4 tall.
    CGFloat stripHeight = (CGFloat)(longSide * 0.125 + 4.0);

    self.gradationTopView = [[GradationView alloc]
        initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.frame), stripHeight)];
    self.gradationTopView.backgroundColor = UIColor.clearColor;
    self.gradationTopView.topColor = UIColor.blackColor;
    self.gradationTopView.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.gradationTopView.contentMode = UIViewContentModeScaleAspectFit;
    [self.memuView addSubview:self.gradationTopView];

    self.gradationButtomView =
        [[GradationView alloc] initWithFrame:CGRectMake(0,
                                                        CGRectGetHeight(self.frame) - stripHeight,
                                                        CGRectGetWidth(self.frame),
                                                        stripHeight)];
    self.gradationButtomView.backgroundColor = UIColor.clearColor;
    self.gradationButtomView.bottomColor = UIColor.blackColor;
    self.gradationButtomView.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    self.gradationButtomView.contentMode = UIViewContentModeScaleAspectFit;
    [self.memuView addSubview:self.gradationButtomView];

    // Back button, keyed by locale suffix, hosted in the top gradient.
    if (!self.backButton) {
        self.backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    }
    NSString *backName = [NSString stringWithFormat:kBackImageFormat, localeSuffix];
    UIImage *backImage =
        [UIImage imageWithContentsOfFile:[resourcePath stringByAppendingPathComponent:backName]];
    if (backImage) {
        // The button height is half the strip height (stripHeight * 4 * 0.125 == stripHeight/2),
        // and its width preserves the image aspect ratio.
        CGFloat backHeight = (CGFloat)(stripHeight * 4.0f * 0.125f);
        CGFloat backWidth = backImage.size.width / backImage.size.height * backHeight;
        [self.backButton setImage:backImage forState:UIControlStateNormal];
        self.backButton.frame = CGRectMake((CGFloat)(shortSide * 0.5f) / 20.0f,
                                           (CGFloat)((stripHeight - backHeight) * 2.0f / 3.0f),
                                           backWidth,
                                           backHeight);
        self.backButton.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
        self.backButton.contentMode = UIViewContentModeScaleAspectFill;
        self.backButton.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
        self.backButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
        [self.gradationTopView addSubview:self.backButton];
        [self.backButton addTarget:self
                            action:@selector(backAction)
                  forControlEvents:UIControlEventTouchUpInside];
    }

    // Sound indicator: a UIButton with interaction disabled, in the top gradient.
    if (!self.soundButton) {
        self.soundButton = [UIButton buttonWithType:UIButtonTypeCustom];
    }
    // Button dimension used for the sound and store controls: longSide * 0.0625.
    CGFloat controlSize = longSide * kErrorFontScale;
    UIImage *soundOffImage = [UIImage
        imageWithContentsOfFile:[resourcePath stringByAppendingPathComponent:kSoundOffImageName]];
    if (soundOffImage) {
        [self.soundButton setImage:soundOffImage forState:UIControlStateNormal];
    }
    UIImage *soundOnImage = [UIImage
        imageWithContentsOfFile:[resourcePath stringByAppendingPathComponent:kSoundOnImageName]];
    if (soundOnImage) {
        [self.soundButton setImage:soundOnImage forState:UIControlStateSelected];
    }
    self.soundButton.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.soundButton.contentMode = UIViewContentModeScaleAspectFill;
    self.soundButton.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    self.soundButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    CGFloat soundSize = stripHeight / 3.0f;
    self.soundButton.frame =
        CGRectMake(CGRectGetWidth(self.frame) - soundSize - 10.0 - controlSize * 3.0 - 10.0,
                   (CGFloat)((stripHeight - stripHeight / 3.0f) * 3.0f / 5.0f),
                   soundSize,
                   (CGFloat)((stripHeight - soundSize) * 3.0f / 5.0f));
    [self.gradationTopView addSubview:self.soundButton];
    self.soundButton.userInteractionEnabled = NO;
    self.soundButton.selected = [movieVoiceFlg isEqualToString:kMovieVoiceOnFlag];

    // Remaining-time label in the top gradient.
    if (!self.currentTimeLabel) {
        CGFloat labelWidth = controlSize * 3.0 + 10.0;
        self.currentTimeLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(CGRectGetWidth(self.frame) - controlSize * 3.0 - 10.0,
                                     10.0,
                                     labelWidth,
                                     stripHeight - 10.0)];
        self.currentTimeLabel.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
        self.currentTimeLabel.font = [UIFont systemFontOfSize:shortSide * kErrorFontScale];
        self.currentTimeLabel.adjustsFontSizeToFitWidth = YES;
        self.currentTimeLabel.lineBreakMode = NSLineBreakByClipping;
        self.currentTimeLabel.numberOfLines = 1;
        self.currentTimeLabel.textAlignment = NSTextAlignmentCenter;
        self.currentTimeLabel.textColor = UIColor.whiteColor;
        self.currentTimeLabel.text = @"";
        self.currentTimeLabel.backgroundColor = UIColor.clearColor;
        [self.gradationTopView addSubview:self.currentTimeLabel];
    }

    // Store button in the bottom gradient, sized by the smaller of two candidate scales.
    if (!self.storeButton) {
        self.storeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    }
    NSString *storeName = [NSString stringWithFormat:kStoreImageFormat, localeSuffix];
    UIImage *storeImage =
        [UIImage imageWithContentsOfFile:[resourcePath stringByAppendingPathComponent:storeName]];
    if (storeImage) {
        [self.storeButton setImage:storeImage forState:UIControlStateNormal];
        CGFloat heightScale = (CGFloat)(stripHeight * 4.0f * 0.125f) / storeImage.size.height;
        CGFloat widthScale =
            (CGFloat)(CGRectGetWidth(self.frame) * 6.0 * 0.125) / storeImage.size.width;
        CGFloat scale = heightScale < widthScale ? heightScale : widthScale;
        CGFloat storeWidth = (CGFloat)(storeImage.size.width * scale);
        CGFloat storeHeight = (CGFloat)(storeImage.size.height * scale);
        self.storeButton.frame = CGRectMake((CGRectGetWidth(self.frame) - storeWidth) * 0.5,
                                            (CGFloat)((stripHeight - storeHeight) * 0.5f),
                                            storeWidth,
                                            storeHeight);
        self.storeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                            UIViewAutoresizingFlexibleRightMargin |
                                            UIViewAutoresizingFlexibleTopMargin;
        self.storeButton.contentMode = UIViewContentModeScaleAspectFill;
        self.storeButton.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
        self.storeButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
        [self.gradationButtomView addSubview:self.storeButton];
        [self.storeButton addTarget:self
                             action:@selector(storeAction)
                   forControlEvents:UIControlEventTouchUpInside];
    }

    // Play/pause button, centred over the view, hidden until the movie is ready.
    self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *playImage = [UIImage
        imageWithContentsOfFile:[resourcePath stringByAppendingPathComponent:kPlayImageName]];
    if (playImage) {
        [self.playButton setImage:playImage forState:UIControlStateNormal];
    }
    UIImage *stopImage = [UIImage
        imageWithContentsOfFile:[resourcePath stringByAppendingPathComponent:kStopImageName]];
    if (stopImage) {
        [self.playButton setImage:stopImage forState:UIControlStateSelected];
    }
    CGFloat playSide = (CGFloat)(shortSide * 0.25f);
    self.playButton.frame = CGRectMake(0, 0, playSide, playSide);
    self.playButton.center =
        CGPointMake(CGRectGetWidth(self.frame) * 0.5, CGRectGetHeight(self.frame) * 0.5);
    self.playButton.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.playButton.contentMode = UIViewContentModeScaleAspectFill;
    self.playButton.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    self.playButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    self.playButton.hidden = YES;
    [self.memuView addSubview:self.playButton];
    [self.playButton addTarget:self
                        action:@selector(playAction:)
              forControlEvents:UIControlEventTouchUpInside];

    if (self.delegate) {
        if ([self.delegate respondsToSelector:@selector(viewReady:)]) {
            [self.delegate viewReady:self];
        }
        if (!self.autoPlayFlg && !self.player.isMuted &&
            [self.delegate respondsToSelector:@selector(movieSoundUse)]) {
            [self.delegate movieSoundUse];
        }
    }
}

/** @ghidraAddress 0x228c6c */
- (void)setPosterImgWithUrl:(NSString *)url {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      /** @ghidraAddress 0x228d1c */
      if ([ApplilinkFile getBannerWithUrl:url]) {
          NSString *fileName = [ApplilinkUtilities getFileNameFromPath:url];
          NSString *path =
              [[ApplilinkFile getBannerCachePath] stringByAppendingPathComponent:fileName];
          UIImage *image = [UIImage imageWithContentsOfFile:path];
          if (image) {
              dispatch_async(dispatch_get_main_queue(), ^{
                /** @ghidraAddress 0x228e8c */
                self.posterImg = [[UIImageView alloc] initWithImage:image];
                self.posterImg.frame =
                    CGRectMake(0, 0, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame));
                self.posterImg.center = CGPointMake(CGRectGetWidth(self.frame) * 0.5,
                                                    CGRectGetHeight(self.frame) * 0.5);
                self.posterImg.autoresizingMask =
                    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
                    UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
                    UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
                self.posterImg.contentMode = UIViewContentModeScaleAspectFit;
                if (self.memuView) {
                    [self.memuView addSubview:self.posterImg];
                    [self.memuView sendSubviewToBack:self.posterImg];
                }
              });
          }
      }
    });
}

#pragma mark - Controls

/** @ghidraAddress 0x2290b8 */
- (void)backAction {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(menuOff) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(backAction)
                                               object:nil];
    [self deallocPlayer];
    if (self.delegate && [self.delegate respondsToSelector:@selector(closeNotice:)]) {
        [self.delegate closeNotice:self];
    }
    self.delegate = nil;
}

/** @ghidraAddress 0x229188 */
- (void)soundAction:(UIButton *)sender {
    [self.player setVolume:sender.isSelected ? 0.0f : 1.0f];
    sender.selected = !sender.isSelected;
}

/** @ghidraAddress 0x229224 */
- (void)storeAction {
    [self pause];
    if (self.delegate && [self.delegate respondsToSelector:@selector(storeNotice:)]) {
        [self.delegate storeNotice:self];
    }
}

/** @ghidraAddress 0x2292a8 */
- (void)playAction:(UIButton *)sender {
    if (!sender.isSelected) {
        if (!self.playFlg) {
            [self setupTimer];
        }
        self.playFlg = YES;
        if (self.posterImg) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(movieStart)]) {
                [self.delegate movieStart];
            }
        }
        [self.posterImg removeFromSuperview];
        self.posterImg = nil;
        self.memuView.backgroundColor = UIColor.clearColor;
        [self menuOff];
        [self.player play];
    } else {
        [self.player pause];
    }
    sender.selected = !sender.isSelected;
}

/** @ghidraAddress 0x229458 */
- (void)skipAction:(id)sender {
    [self pause];
    if (self.delegate && [self.delegate respondsToSelector:@selector(movieEnd)]) {
        [self.delegate movieEnd];
    }
}

/** @ghidraAddress 0x2294d8 */
- (void)repeat {
    [self setupTimer];
    [self.player seekToTime:CMTimeMakeWithSeconds(0, 1000000000)];
    [self.player play];
    self.playButton.selected = YES;
    if (self.delegate && [self.delegate respondsToSelector:@selector(movieStart)]) {
        [self.delegate movieStart];
    }
}

/** @ghidraAddress 0x2295c0 */
- (void)pause {
    [self.player pause];
    self.playButton.selected = NO;
}

/** @ghidraAddress 0x229614 */
- (void)finish {
    [self.player pause];
    self.playButton.hidden = YES;
    [self menuOn];
    self.menuStatus = VideoViewMenuStatusFinished;
}

#pragma mark - Playback observation

/** @ghidraAddress 0x229690 */
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:kKeyPathReadyForDisplay]) {
        [self.playerLayer removeObserver:self forKeyPath:kKeyPathReadyForDisplay];
    }
    if (self.playerItem == object) {
        if ([keyPath isEqualToString:kKeyPathStatus]) {
            AVPlayerItemStatus status = self.playerItem.status;
            if (status == AVPlayerItemStatusFailed) {
                [self streamingError];
            } else if (status == AVPlayerItemStatusReadyToPlay) {
                [self syncTimeRemaining];
                [self setCacheTimer];
                if (self.autoPlayFlg) {
                    self.memuView.hidden = YES;
                    self.playButton.hidden = NO;
                    [self playAction:self.playButton];
                    if (self.delegate) {
                        if (!self.player.isMuted &&
                            [self.delegate respondsToSelector:@selector(movieSoundUse)]) {
                            [self.delegate movieSoundUse];
                        }
                        if ([self.delegate respondsToSelector:@selector(movieReady)]) {
                            [self.delegate movieReady];
                        }
                        if ([self.delegate respondsToSelector:@selector(movieCacheEnd)]) {
                            [self.delegate movieCacheEnd];
                        }
                    }
                }
            }
            return;
        }
    }
    if (self.playerItem == object && [keyPath isEqualToString:kKeyPathPlaybackBufferEmpty]) {
        if (self.playerItem.isPlaybackBufferEmpty) {
            [self streamingError];
        }
        return;
    }
    if (self.playerItem == object && [keyPath isEqualToString:kKeyPathPlaybackLikelyToKeepUp]) {
        // The binary reads the flag but discards it.
        (void)self.playerItem.isPlaybackLikelyToKeepUp;
    }
}

/** @ghidraAddress 0x22996c */
- (void)playerDidPlayToEndTime:(NSNotification *)notification {
    [self.player pause];
    if (self.delegate && [self.delegate respondsToSelector:@selector(movieEnd)]) {
        [self.delegate movieEnd];
    }
}

#pragma mark - Timers

/** @ghidraAddress 0x2299f8 */
- (void)setupTimer {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(streamingTimeoutNowCheck)
                                               object:nil];
    // self is captured through a __strong __block variable, matching the binary's byref block.
    __block VideoView *blockSelf = self;
    self.playTimeObserver =
        [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.5, 1000000000)
                                                  queue:nil
                                             usingBlock:^(CMTime time) {
                                               /** @ghidraAddress 0x229b78 */
                                               [blockSelf syncTimeRemaining];
                                             }];
    [self syncTimeRemaining];
}

/** @ghidraAddress 0x229bb0 */
- (void)syncTimeRemaining {
    CMTime durationTime = self.playerItem ? self.playerItem.duration : kCMTimeZero;
    double duration = CMTimeGetSeconds(durationTime);
    CMTime currentTime = self.player ? self.player.currentTime : kCMTimeZero;
    double current = CMTimeGetSeconds(currentTime);
    self.currentTimeLabel.text = [self timeToString:(float)(duration - current)];
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(pauseCheck)
                                               object:nil];
    if ((float)(duration - current) > 0.0f && self.playButton.isSelected) {
        [self performSelector:@selector(pauseCheck) withObject:nil afterDelay:kPauseCheckDelay];
    }
}

/** @ghidraAddress 0x229d28 */
- (void)pauseCheck {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(pauseCheck)
                                               object:nil];
    if (self.playButton.isSelected) {
        [self pause];
    }
}

/** @ghidraAddress 0x229dac */
- (NSString *)timeToString:(float)time {
    if (time <= 0.0f) {
        return [NSString stringWithFormat:kTimeZeroText];
    }
    int total = (int)time;
    return [NSString stringWithFormat:kTimeFormat, total / 60, total % 60];
}

/** @ghidraAddress 0x229e3c */
- (void)setCacheTimer {
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    self.timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_cancel_handler(self.timerSource, ^{
      /** @ghidraAddress 0x229f70 */
      if (self.timerSource) {
          // The binary dispatch_release()s the source here; under ARC the strong ivar's
          // nil assignment balances the create instead.
          self.timerSource = nil;
      }
    });
    dispatch_source_set_event_handler(self.timerSource, ^{
      /** @ghidraAddress 0x229fbc */
      [self availableDuration];
    });
    dispatch_source_set_timer(
        self.timerSource, dispatch_time(DISPATCH_TIME_NOW, 0), 1000000000, 500000000);
    dispatch_resume(self.timerSource);
}

/** @ghidraAddress 0x229fe0 */
- (void)pauseTimer {
    if (self.timerSource) {
        dispatch_suspend(self.timerSource);
    }
}

/** @ghidraAddress 0x229ff8 */
- (void)cancelTimer {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(streamingTimeoutNowCheck)
                                               object:nil];
    if (self.timerSource) {
        dispatch_source_cancel(self.timerSource);
        // The binary dispatch_release()s the source here; under ARC the strong ivar's nil
        // assignment below balances the create instead.
        self.timerSource = nil;
    }
}

/** @ghidraAddress 0x22a070 */
- (double)availableDuration {
    if (!self.player) {
        return 0.0;
    }
    NSArray<NSValue *> *loadedRanges = self.player.currentItem.loadedTimeRanges;
    if (loadedRanges.count == 0) {
        return 0.0;
    }
    CMTimeRange range = loadedRanges[0] ? loadedRanges[0].CMTimeRangeValue : kCMTimeRangeZero;
    double buffered = CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration);
    double duration = self.playerItem ? CMTimeGetSeconds(self.playerItem.duration) : 0.0;
    // Still buffering: not yet a third of the movie and under 7.5 seconds cached.
    if (buffered < duration / 3.0 && buffered < 7.5) {
        return buffered;
    }
    if (!self.playFlg && self.playButton.isHidden) {
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x22a340 */
          self.playButton.hidden = NO;
          if (self.delegate && [self.delegate respondsToSelector:@selector(movieReady)]) {
              [self.delegate movieReady];
          }
        });
    }
    double totalDuration = self.playerItem ? CMTimeGetSeconds(self.playerItem.duration) : 0.0;
    if (buffered < totalDuration) {
        return buffered;
    }
    [self cancelTimer];
    if (!self.autoPlayFlg && self.delegate &&
        [self.delegate respondsToSelector:@selector(movieCacheEnd)]) {
        [self.delegate movieCacheEnd];
    }
    return buffered;
}

#pragma mark - Menu overlay

/** @ghidraAddress 0x22a3ec */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.errorFlg) {
        [self backAction];
    }
    if (self.menuStatus == VideoViewMenuStatusHidden) {
        self.menuStatus = VideoViewMenuStatusAnimating;
        self.memuView.hidden = NO;
        [UIView animateWithDuration:g_dAnimDuration020
            delay:0
            options:0
            animations:^{
              /** @ghidraAddress 0x22a54c */
              self.memuView.alpha = 1.0;
              self.menuStatus = VideoViewMenuStatusShown;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x22a5b0 */
              [self performSelector:@selector(menuOff)
                         withObject:nil
                         afterDelay:kMenuAutoHideDelay];
            }];
    } else {
        [self menuOff];
    }
}

/** @ghidraAddress 0x22a5e8 */
- (void)menuOn {
    if (self.menuStatus == VideoViewMenuStatusHidden) {
        self.menuStatus = VideoViewMenuStatusAnimating;
        self.memuView.hidden = NO;
        [UIView animateWithDuration:g_dAnimDuration020
                              delay:0
                            options:0
                         animations:^{
                           /** @ghidraAddress 0x22a6bc */
                           self.memuView.alpha = 1.0;
                           self.menuStatus = VideoViewMenuStatusShown;
                         }
                         completion:^(BOOL finished){
                             /** @ghidraAddress 0x22a720 */
                             // The binary's completion is an empty global block.
                         }];
    }
}

/** @ghidraAddress 0x22a724 */
- (void)menuOff {
    if (!self.errorFlg && self.playFlg && self.menuStatus != VideoViewMenuStatusFinished) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(menuOff)
                                                   object:nil];
        if (self.menuStatus == VideoViewMenuStatusShown) {
            self.menuStatus = VideoViewMenuStatusAnimating;
            [UIView animateWithDuration:g_dAnimDuration020
                delay:0
                options:0
                animations:^{
                  /** @ghidraAddress 0x22a868 */
                  self.memuView.alpha = 0.0;
                }
                completion:^(BOOL finished) {
                  /** @ghidraAddress 0x22a89c */
                  self.memuView.hidden = YES;
                  self.menuStatus = VideoViewMenuStatusHidden;
                }];
        }
    }
}

#pragma mark - Streaming timeout

/** @ghidraAddress 0x22a8fc */
- (void)streamingTimeoutWatch {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(streamingTimeoutWatch)
                                               object:nil];
    [self performSelector:@selector(streamingTimeoutNowCheck)
               withObject:nil
               afterDelay:kStreamingTimeout];
}

/** @ghidraAddress 0x22a96c */
- (void)streamingTimeoutNowCheck {
    if (self.playButton.isHidden) {
        [self streamingError];
    }
}

/** @ghidraAddress 0x22a9c4 */
- (void)streamingError {
    if (self.delegate && [self.delegate respondsToSelector:@selector(movieError)]) {
        [self.delegate movieError];
    }
    [self deallocPlayer];
    [self finish];
    if (!self.errorFlg) {
        self.errorFlg = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x22aac0 */
          [self showStreamingErrorOverlay];
        });
    }
}

// Builds the translucent overlay with the two localised error-message labels. De-inlined from
// Block_VideoViewShowStreamingErrorOverlay @ 0x22aac0.
- (void)showStreamingErrorOverlay {
    self.playButton.hidden = YES;
    // Font sized from the short side of the menu view.
    CGFloat shortSide = CGRectGetWidth(self.memuView.frame);
    if (CGRectGetHeight(self.memuView.frame) < shortSide) {
        shortSide = CGRectGetHeight(self.memuView.frame);
    }
    CGFloat fontSize = shortSide * kErrorFontScale;

    UIView *overlay = [[UIView alloc] initWithFrame:self.memuView.frame];
    overlay.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    // The binary builds this grey via colorWithRed:green:blue:alpha: with 0.2 components and 0.8
    // alpha (0.2 reuses the g_dAnimDuration020 constant for the RGB channels).
    overlay.backgroundColor = [UIColor colorWithRed:g_dAnimDuration020
                                              green:g_dAnimDuration020
                                               blue:g_dAnimDuration020
                                              alpha:kErrorOverlayAlpha];
    [self.memuView addSubview:overlay];

    CGFloat quarter = (CGFloat)(CGRectGetHeight(overlay.frame) * 0.25f);
    CGFloat labelX = (CGFloat)(fontSize / 10.0f);
    CGFloat labelWidth = (CGFloat)((fontSize / 10.0f) * 8.0f);

    UILabel *label1 =
        [[UILabel alloc] initWithFrame:CGRectMake(labelX, quarter, labelWidth, quarter)];
    label1.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    label1.font = [UIFont boldSystemFontOfSize:fontSize];
    label1.numberOfLines = 1;
    label1.adjustsFontSizeToFitWidth = YES;
    label1.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    label1.textAlignment = NSTextAlignmentCenter;
    label1.textColor = UIColor.whiteColor;
    label1.backgroundColor = UIColor.clearColor;
    label1.text = [ApplilinkMessage localizedMessage:kStreamingErrorMessageKey1];
    [overlay addSubview:label1];

    UILabel *label2 =
        [[UILabel alloc] initWithFrame:CGRectMake(labelX, quarter + quarter, labelWidth, quarter)];
    label2.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    label2.font = [UIFont boldSystemFontOfSize:fontSize];
    label2.numberOfLines = 1;
    label2.adjustsFontSizeToFitWidth = YES;
    label2.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    label2.textAlignment = NSTextAlignmentCenter;
    label2.textColor = UIColor.whiteColor;
    label2.backgroundColor = UIColor.clearColor;
    label2.text = [ApplilinkMessage localizedMessage:kStreamingErrorMessageKey2];
    [overlay addSubview:label2];
}

#pragma mark - Store lifecycle notices (empty stubs in the binary)

/** @ghidraAddress 0x22b048 */
- (void)openErrorNotice {
}

/** @ghidraAddress 0x22b04c */
- (void)appStoreOpenedNotice {
}

/** @ghidraAddress 0x22b050 */
- (void)appStoreCloseNotice {
}

/** @ghidraAddress 0x22b054 */
- (void)appStoreClosedNotice {
}

/** @ghidraAddress 0x22b058 */
- (void)appStoreFailLoadNoticeWithError:(NSError *)error {
}

/** @ghidraAddress 0x22b05c */
- (void)appStoreTransitionNotice {
}

#pragma mark - Teardown

/** @ghidraAddress 0x22b060 */
- (void)deallocPlayer {
    [self cancelTimer];
    if (self.player) {
        [self.player pause];
        [self.player removeTimeObserver:self.playTimeObserver];
        [self.playerItem removeObserver:self forKeyPath:kKeyPathStatus context:nullptr];
        [self.playerItem removeObserver:self
                             forKeyPath:kKeyPathPlaybackBufferEmpty
                                context:nullptr];
        [self.playerItem removeObserver:self
                             forKeyPath:kKeyPathPlaybackLikelyToKeepUp
                                context:nullptr];
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:AVPlayerItemDidPlayToEndTimeNotification
                                                    object:self.playerItem];
        [self.playerLayer setPlayer:nil];
        self.playerLayer = nil;
        self.player = nil;
        self.playerItem = nil;
        self.playTimeObserver = nil;
    }
}

/** @ghidraAddress 0x22b1f4 */
- (void)clearDelegate {
    self.delegate = nil;
}

/** @ghidraAddress 0x22b204 */
- (void)dealloc {
    [self deallocPlayer];
    [self clearDelegate];
}

@end
