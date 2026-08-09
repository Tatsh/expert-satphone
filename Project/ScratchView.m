#import "ScratchView.h"

#import "AudioManager.h"
#import "ChallengeStatus.h"
#import "ImageCache.h"
#import "ScratchUtil.h"
#import "StoreDialogView.h"
#import "StoreUtil.h"
#import "SystemUtilities.h"

// The shared 0.2s animation duration, pooled at 0x28f240 and shared across the view layer.
extern const double g_dAnimDuration020;
// The scratch-entry accessors this card reads; ScratchInfo exposes them only through its private
// ivars so far, so they are declared locally. See TYPES_PENDING.md.
@interface ScratchInfo (ScratchView)
- (unsigned int)musicID;
- (BOOL)bOpen;
- (nullable NSString *)imgURL;
- (nullable NSString *)itemURL;
@end

// The default fallback jacket, shown before the real artwork arrives.
static NSString *const kDefaultJacketImageName = @"store_jacket_160";

// The scratch cover-layer image names: five stacked layers, one of the five picked at random to
// use the plain "_00" name and the rest a two-digit "_%d%d" variant name.
static NSString *const kCoverImageFormat = @"scratch_btn_scratch_%d%d";
static NSString *const kCoverImageFormatZero = @"scratch_btn_scratch_00";

// The scratch and scratch-open sound-effect resource names.
static NSString *const kScratchSeName = @"SD_SCRATCH";
static NSString *const kScratchOpenSeName = @"SD_SCRATCH_OPEN";

// The five stacked cover layers; they overlay the whole card rather than tiling it.
static const int kCoverCount = 5;

// The scratch-progress step machine. The finger drives scratchStep from 0 up to kStepOpen. A
// sound plays every kStepSoundInterval steps, the delegate's scratchEnable: fires at kStepEnable,
// the start notification fires at kStepStart, and the covers begin fading from kStepFadeBegin.
static const int kStepClosed = 0;
static const int kStepEnable = 4;
static const int kStepSoundInterval = 0x14;  // 20
static const int kStepStart = 0x14;          // 20
static const int kStepFadeBegin = 0x50;      // 80
static const int kStepOpen = 0x78;           // 120
static const int kStepScratchingLow = 0x15;  // 21 (getState scratching-range base)
static const int kStepScratchingSpan = 0x63; // 99 (getState scratching-range span)

// The per-layer step offsets: the five covers begin fading at successively earlier steps, so they
// clear back-to-front as the finger passes. Layer 4 begins fading first (at step 0) and layer 0
// last (at kStepFadeBegin), each layer kStepFadeStagger steps apart.
static const int kStepFadeStagger = 0x14; // 20

// The cover fade divides the offset step count by this span to reach an alpha ramp.
static const float kFadeStepSpan = 20.0f; // fmov s8,0x41a00000

// The animation option the reveal and cover fades use (3 << 16 -> CurveLinear).
static const UIViewAnimationOptions kScratchAnimationOptions = UIViewAnimationOptionCurveLinear;

// The reveal effect view's starting alpha, pooled at 0x291c98.
static const CGFloat kEffectStartAlpha = 0.699999988079071; // @ghidraAddress 0x291c98

// The enable-cover's tint white and alpha (colorWithWhite:0.1 alpha:0.5). The same pooled 0.1 at
// 0x28f2b8 also supplies the delay of every animation in this class.
static const CGFloat kEnableCoverWhite = 0.10000000149011612; // @ghidraAddress 0x28f2b8

// The delay before each scratch animation begins (the same pooled 0.1 as kEnableCoverWhite).
static const CGFloat kScratchAnimationDelay = 0.10000000149011612; // @ghidraAddress 0x28f2b8

// The scratch button's red background tint (colorWithRed:0.8 green:0.6 blue:0.6 alpha:1.0).
static const CGFloat kScratchButtonRed = 0.800000011920929;    // @ghidraAddress 0x28e080
static const CGFloat kScratchButtonGreen = 0.6000000238418579; // @ghidraAddress 0x28f230

// The download indicator's frame side (initWithFrame:0,0,30,30; fmov d2,0x403e000000000000).
static const CGFloat kIndicatorSide = 30.0; // fmov immediate at 0x1ae758

@implementation ScratchView {
    UIImageView *scratchCoverView[5];           // +0x8
    UIImageView *artWork;                       // +0x30
    UIImageView *effectArtWork;                 // +0x38
    UIView *enableCover;                        // +0x40
    BOOL bOpen;                                 // +0x48
    BOOL bDownloading;                          // +0x49
    BOOL bEnableScratch;                        // +0x4a
    UIButton *scratchBtn;                       // +0x50
    BOOL bScratching;                           // +0x58
    int scratchStep;                            // +0x5c
    BOOL bScratchWait;                          // +0x60
    UIActivityIndicatorView *downloadIndicator; // +0x68
    // _aDelegate (weak) at +0x70 is synthesised.
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x1ae120 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        CGFloat width = frame.size.width;
        CGFloat height = frame.size.height;

        self.opaque = NO;
        self.layer.doubleSided = NO;
        // Originally colorWithRed:0.8 green:0.6 blue:0.6 alpha:1.0.
        self.backgroundColor = [UIColor colorWithRed:kScratchButtonRed
                                               green:kScratchButtonGreen
                                                blue:kScratchButtonGreen
                                               alpha:1.0];
        scratchStep = kStepClosed;

        scratchBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [scratchBtn setFrame:CGRectMake(0, 0, width, height)];
        scratchBtn.backgroundColor = [UIColor colorWithRed:kScratchButtonRed
                                                     green:kScratchButtonGreen
                                                      blue:kScratchButtonGreen
                                                     alpha:1.0];
        [scratchBtn addTarget:self
                       action:@selector(tapScratchView:)
             forControlEvents:UIControlEventTouchUpInside];
        [scratchBtn addTarget:self
                       action:@selector(moveScratchView:)
             forControlEvents:UIControlEventTouchDragInside];
        [scratchBtn addTarget:self
                       action:@selector(touchBeganScratch:)
             forControlEvents:UIControlEventTouchDown];
        [scratchBtn addTarget:self
                       action:@selector(touchEndScratch:)
             forControlEvents:UIControlEventTouchDragExit];
        scratchBtn.exclusiveTouch = YES;
        [self addSubview:scratchBtn];

        artWork = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
        artWork.image = [ImageCache.sharedCache getResPNG:kDefaultJacketImageName];
        [self addSubview:artWork];

        effectArtWork = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
        effectArtWork.backgroundColor = UIColor.whiteColor;
        effectArtWork.alpha = 0;
        [self addSubview:effectArtWork];

        enableCover = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
        // Originally colorWithWhite:0.1 alpha:0.5.
        enableCover.backgroundColor = [UIColor colorWithWhite:kEnableCoverWhite alpha:0.5];
        [artWork addSubview:enableCover];

        // Pick one of the five cover layers at random to use the plain "_00" name; the rest use the
        // two-digit variant name formatted with the layer's random pair.
        int randomLayer = rand() % kCoverCount;
        for (int i = kCoverCount - 1; i >= 0; --i) {
            NSString *coverName = [NSString stringWithFormat:kCoverImageFormat, randomLayer, i];
            if (i == 0) {
                coverName = [NSString stringWithFormat:kCoverImageFormatZero];
            }
            scratchCoverView[i] =
                [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
            scratchCoverView[i].image = [ImageCache.sharedCache getResPNG:coverName];
            [self addSubview:scratchCoverView[i]];
        }

        downloadIndicator = [[UIActivityIndicatorView alloc]
            initWithFrame:CGRectMake(0, 0, kIndicatorSide, kIndicatorSide)];
        downloadIndicator.center = CGPointMake(width * 0.5, height * 0.5);
        downloadIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
        downloadIndicator.hidesWhenStopped = YES;
        [self addSubview:downloadIndicator];
    }
    return self;
}

#pragma mark - Artwork

/** @ghidraAddress 0x1ae808 */
- (void)refreshScratchImage:(ScratchInfo *)info {
    if (bOpen && info.musicID != 0) {
        NSString *path = [ScratchUtil imagePathForMusicID:info.musicID];
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        if (image) {
            // The open jacket sits in a square whose side is the card's (truncated) width.
            artWork.image = image;
            int side = (int)self.frame.size.width;
            [artWork setFrame:CGRectMake(0, 0, side, side)];
        } else {
            // Fall back to the default jacket at the card's full size and start a download.
            artWork.image = [ImageCache.sharedCache getResPNG:kDefaultJacketImageName];
            [artWork setFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
            NSString *imgURL = info.imgURL;
            if ([StoreUtil isValidURL:imgURL]) {
                Downloader *downloader =
                    [[Downloader alloc] initWithURL:[NSURL URLWithString:imgURL] delegate:self];
                downloader.tag = 0;
                [downloader startDownloading];
            }
        }
    } else {
        artWork.image = [ImageCache.sharedCache getResPNG:kDefaultJacketImageName];
        [artWork setFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
    }
}

/** @ghidraAddress 0x1aeb60 */
- (void)updateView:(BOOL)animated {
    ScratchInfo *info = ChallengeStatus.sharedStatus.scratchInfoTable[self.tag];
    bOpen = info.bOpen;
    [self refreshScratchImage:info];
    if (!info.bOpen) {
        // Not yet open: reset the step and show all five covers.
        scratchStep = kStepClosed;
        scratchCoverView[0].alpha = 1.0;
        scratchCoverView[1].alpha = 1.0;
        scratchCoverView[2].alpha = 1.0;
        scratchCoverView[3].alpha = 1.0;
        scratchCoverView[4].alpha = 1.0;
    } else if (scratchStep == kStepClosed) {
        // Already open and still at the start: jump to the open step and hide the covers.
        scratchStep = kStepOpen;
        scratchCoverView[0].alpha = 0;
        scratchCoverView[1].alpha = 0;
        scratchCoverView[2].alpha = 0;
        scratchCoverView[3].alpha = 0;
        scratchCoverView[4].alpha = 0;
    }
    [self timerUpdate];
}

/** @ghidraAddress 0x1afcb8 */
- (void)imageSet {
    // Empty in the binary.
}

#pragma mark - Touch handling

/** @ghidraAddress 0x1aed40 */
- (void)tapScratchView:(id)sender {
    if (![self.aDelegate isScratchEnable]) {
        if (scratchStep < 1 || scratchStep > kStepOpen - 1) {
            return;
        }
    }
    if (bScratching) {
        bScratching = NO;
        return;
    }
    ScratchInfo *info = ChallengeStatus.sharedStatus.scratchInfoTable[self.tag];
    if (info.bOpen && scratchStep > kStepOpen - 1) {
        NSString *itemPath = [ScratchUtil itemPathForMusicID:info.musicID];
        if (![NSFileManager.defaultManager fileExistsAtPath:itemPath]) {
            NSString *itemURL = info.itemURL;
            if (![StoreUtil isValidURL:itemURL]) {
                return;
            }
            Downloader *downloader = [[Downloader alloc] initWithURL:[NSURL URLWithString:itemURL]
                                                            delegate:self];
            downloader.tag = 1;
            [downloader startDownloading];
            [self.aDelegate showModalDialog:self];
            return;
        }
    }
    if ([self.aDelegate respondsToSelector:@selector(selectScratch:)]) {
        [self.aDelegate performSelector:@selector(selectScratch:) withObject:self];
    }
}

/** @ghidraAddress 0x1af09c */
- (void)touchEndScratch:(id)sender {
    bScratching = NO;
}

/** @ghidraAddress 0x1af0ac */
- (void)touchBeganScratch:(id)sender {
    bScratching = NO;
}

/** @ghidraAddress 0x1af0bc */
- (void)startIndicator {
    [downloadIndicator startAnimating];
}

/** @ghidraAddress 0x1af0d4 */
- (void)moveScratchView:(id)sender {
    if (![self.aDelegate isScratchEnable] && scratchStep == kStepClosed) {
        return;
    }
    if (scratchStep < kStepOpen) {
        bScratching = YES;
    }
    // Play the scratch sound each time the step crosses a whole interval, while mid-scratch. The
    // guard is the binary's own XOR: true only when 1 <= scratchStep <= kStepOpen - 1.
    if ((scratchStep > kStepOpen - 1) != (scratchStep != 0) &&
        scratchStep % kStepSoundInterval == 0) {
        [AudioManager.sharedManager playSeResFile:kScratchSeName inDirectory:nil];
    }
    if (scratchStep == kStepEnable) {
        [self.aDelegate scratchEnable:NO];
    }
    if (!bScratchWait) {
        ++scratchStep;
    }
    if (scratchStep == kStepStart) {
        // Crossed the start threshold: enter the wait state and spin up the indicator.
        bScratchWait = YES;
        ++scratchStep;
        [downloadIndicator startAnimating];
        if ([self.aDelegate respondsToSelector:@selector(scratchStart:)]) {
            [self.aDelegate performSelector:@selector(scratchStart:) withObject:self];
        }
    } else if (scratchStep == kStepOpen) {
        // Reached the open step: play the open sound, mark open, and animate the reveal.
        [AudioManager.sharedManager playSeResFile:kScratchOpenSeName inDirectory:nil];
        bOpen = YES;
        [self scratchEffect:YES];
        if ([self.aDelegate respondsToSelector:@selector(scratchEnd:)]) {
            [self.aDelegate performSelector:@selector(scratchEnd:) withObject:self];
        }
    } else {
        // Mid-drag: fade the five covers, each starting kStepFadeStagger steps earlier.
        for (int i = 0; i < kCoverCount; ++i) {
            int offsetStep = scratchStep - (kStepFadeBegin - i * kStepFadeStagger);
            float ramp = 0;
            if (offsetStep >= 0) {
                ramp = (float)offsetStep / kFadeStepSpan;
            }
            if (ramp > 1.0f) {
                ramp = 1.0f;
            }
            scratchCoverView[i].alpha = 1.0f - ramp;
        }
    }
}

#pragma mark - Reveal effect

/** @ghidraAddress 0x1af500 */
- (void)scratchEffect:(BOOL)show {
    if (show) {
        __weak UIImageView *weakEffect = effectArtWork;
        effectArtWork.alpha = kEffectStartAlpha;
        [UIView animateWithDuration:g_dAnimDuration020
            delay:kScratchAnimationDelay
            options:kScratchAnimationOptions
            animations:^{
              /** @ghidraAddress 0x1af610 */
              weakEffect.alpha = 0;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x1af65c */
              (void)finished;
            }];
    }
}

#pragma mark - State machine

/** @ghidraAddress 0x1af660 */
- (BOOL)scratchContinue {
    if (scratchStep < kStepStart) {
        [self.aDelegate scratchEnable:YES];
        [self scratchOpen:YES];
        return YES;
    }
    bScratchWait = NO;
    if (ChallengeStatus.sharedStatus.nailNum > 0 &&
        ChallengeStatus.sharedStatus.scratchablePanelNum > 0) {
        [self setButtonEnable:NO];
    }
    [self updateView:NO];
    [downloadIndicator stopAnimating];
    return NO;
}

/** @ghidraAddress 0x1af7c0 */
- (void)scratchCancel {
    bScratchWait = NO;
    scratchStep = kStepClosed;
    scratchCoverView[0].alpha = 1.0;
    scratchCoverView[1].alpha = 1.0;
    scratchCoverView[2].alpha = 1.0;
    scratchCoverView[3].alpha = 1.0;
    scratchCoverView[4].alpha = 1.0;
    [downloadIndicator stopAnimating];
}

/** @ghidraAddress 0x1af880 */
- (void)scratchOpen:(BOOL)animated {
    [AudioManager.sharedManager playSeResFile:kScratchOpenSeName inDirectory:nil];
    bScratchWait = NO;
    scratchStep = kStepOpen;
    if (ChallengeStatus.sharedStatus.nailNum > 0 &&
        ChallengeStatus.sharedStatus.scratchablePanelNum > 0) {
        [self setButtonEnable:NO];
    }
    if (animated) {
        for (int i = 0; i < kCoverCount; ++i) {
            __weak UIImageView *weakCover = scratchCoverView[i];
            [UIView animateWithDuration:g_dAnimDuration020
                delay:kScratchAnimationDelay
                options:kScratchAnimationOptions
                animations:^{
                  /** @ghidraAddress 0x1afc38 */
                  weakCover.alpha = 0;
                }
                completion:^(BOOL finished) {
                  /** @ghidraAddress 0x1afc84 */
                  (void)finished;
                }];
        }
    }
    [self scratchEffect:animated];
    [downloadIndicator stopAnimating];
}

/** @ghidraAddress 0x1afc88 */
- (ScratchViewState)getState {
    if ((unsigned int)(scratchStep - kStepScratchingLow) < kStepScratchingSpan) {
        return ScratchViewStateScratching;
    }
    return (ScratchViewState)bOpen;
}

/** @ghidraAddress 0x1b00f4 */
- (void)timerUpdate {
    // Empty in the binary.
}

/** @ghidraAddress 0x1b00f8 */
- (void)setButtonEnable:(BOOL)enable {
    bEnableScratch = enable;
    __weak UIView *weakCover = enableCover;
    if (enable) {
        [UIView animateWithDuration:g_dAnimDuration020
            delay:kScratchAnimationDelay
            options:kScratchAnimationOptions
            animations:^{
              /** @ghidraAddress 0x1b0270 */
              weakCover.alpha = 0;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x1b02bc */
              (void)finished;
            }];
    } else {
        [UIView animateWithDuration:g_dAnimDuration020
            delay:kScratchAnimationDelay
            options:kScratchAnimationOptions
            animations:^{
              /** @ghidraAddress 0x1b02c0 */
              weakCover.alpha = 1.0;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x1b030c */
              (void)finished;
            }];
    }
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x1afcbc */
- (void)downloaderFinished:(Downloader *)downloader {
    ScratchInfo *info = ChallengeStatus.sharedStatus.scratchInfoTable[self.tag];
    if (downloader.tag == 1) {
        NSData *data = [downloader getData];
        NSString *itemPath = [ScratchUtil itemPathForMusicID:info.musicID];
        NSURL *url = [[NSURL alloc] initFileURLWithPath:itemPath isDirectory:NO];
        [data writeToURL:url atomically:YES];
        ExcludeUrlFromICloudBackup(url);
        [self.aDelegate hideModalDialog];
        if ([self.aDelegate respondsToSelector:@selector(selectScratch:)]) {
            [self.aDelegate performSelector:@selector(selectScratch:) withObject:self];
        }
    } else if (downloader.tag == 0) {
        NSData *data = [downloader getData];
        NSString *imagePath = [ScratchUtil imagePathForMusicID:info.musicID];
        NSURL *url = [[NSURL alloc] initFileURLWithPath:imagePath isDirectory:NO];
        [data writeToURL:url atomically:YES];
        ExcludeUrlFromICloudBackup(url);
        [self refreshScratchImage:info];
    }
}

/** @ghidraAddress 0x1affbc */
- (void)downloaderError:(Downloader *)downloader {
    if (downloader.tag == 1) {
        [self.aDelegate hideModalDialog];
    }
}

/** @ghidraAddress 0x1b0028 */
- (void)downloaderProceed:(Downloader *)downloader {
    if (downloader.tag == 1) {
        [self.aDelegate modalDialog].progressView.progress = [downloader currentProgress];
    }
}

@end
