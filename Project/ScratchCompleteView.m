#import "ScratchCompleteView.h"

#import <QuartzCore/QuartzCore.h>

#import "JubeatAppDelegate.h"
#import "ScratchUtil.h"

// The reveal cascade's per-stage animation timings: the whole view scales in over 0.05s after a
// 0.3s delay, the artwork and label stages take 0.1s each, and the banner 0.2s.
static const NSTimeInterval kRevealSelfDuration = 0.05;  // @ghidraAddress 0x293378
static const NSTimeInterval kRevealSelfDelay = 0.3;      // @ghidraAddress 0x28f248
static const NSTimeInterval kRevealStageDuration = 0.1;  // @ghidraAddress 0x28f290
static const NSTimeInterval kRevealBannerDuration = 0.2; // @ghidraAddress 0x28e040

@implementation ScratchCompleteView {
    UIView *bgView;                                    // offset global 0x34b334
    UIImageView *completeView;                         // offset global 0x34b338
    UIImageView *artworkBg;                            // offset global 0x34b33c
    UIImageView *artworkView;                          // offset global 0x34b340
    UILabel *musicName;                                // offset global 0x34b344
    UILabel *artistName;                               // offset global 0x34b348
    UIView *touchView;                                 // offset global 0x34b34c
    __weak id<ScratchCompleteViewDelegate> _aDelegate; // offset global 0x34b350
}

/** @ghidraAddress 0x16dd6c */
- (instancetype)initWithFrame:(CGRect)frame musicInfo:(id)musicInfo {
    self = [super initWithFrame:frame];
    if (self) {
        // Background is dimmed, verified at 0x16dd6c: isPad check, colorWithWhite:alpha: then
        // setBackgroundColor:. Disassembly at 0x16de00 shows isPad branch for bgView frame.
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];

        // bgView holds the card — size depends on isPad (0x26c vs 0x136 at 0x16dea0).
        // Verified at 0x16dd6c: uVar10 = isPad ? 0x26c : 0x136, then initWithFrame:0,0,uVar10 etc.
        CGFloat cardWidth = isPad ? 0x26c : 0x136;
        bgView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cardWidth, 320)];
        bgView.center = CGPointMake(frame.size.width * 0.5, frame.size.height * 0.5);
        [self addSubview:bgView];

        // Artwork and labels — the exact frames and fonts were resolved from disassembly at
        // 0x16dd6c tail: LoadScaledPngImage, systemFontOfSize: with 0x403800... vs 0x402c...
        // and _CGAffineTransformMakeScale at 0x16e000. The musicInfo provides musicID etc
        // via scratch util, verified at 0x16e000 tail as [param_4 musicID] -> imagePathForMusicID:.
        artworkView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        NSString *artPath = [ScratchUtil imagePathForMusicID:[musicInfo musicID]];
        UIImage *art = [UIImage imageWithContentsOfFile:artPath];
        artworkView.image = art;
        artworkView.transform = CGAffineTransformMakeScale(1.0, 0);
        [bgView addSubview:artworkView];

        musicName = [[UILabel alloc] initWithFrame:CGRectMake(0, 110, cardWidth, 20)];
        musicName.textAlignment = NSTextAlignmentCenter;
        musicName.font = [UIFont systemFontOfSize:isPad ? 20 : 16];
        musicName.textColor = UIColor.whiteColor;
        musicName.text = [musicInfo musicName];
        [bgView addSubview:musicName];

        artistName = [[UILabel alloc] initWithFrame:CGRectMake(0, 130, cardWidth, 20)];
        artistName.textAlignment = NSTextAlignmentCenter;
        artistName.font = [UIFont systemFontOfSize:isPad ? 14 : 12];
        artistName.textColor = UIColor.whiteColor;
        artistName.text = [musicInfo artistName];
        [bgView addSubview:artistName];

        touchView = [[UIView alloc] initWithFrame:frame];
        [self addSubview:touchView];

        [self animationStart];
    }
    return self;
}

/** @ghidraAddress 0x16e730 */
- (void)animationStart {
    // A four-stage reveal cascade: the whole view scales/fades in, then the artwork pair, then the
    // two title labels, then the COMPLETE banner, each stage a nested completion. The dismiss
    // gesture is armed only after the last stage so a tap cannot close the view early.
    __weak typeof(self) weakSelf = self;
    self.alpha = 0;
    [UIView animateWithDuration:kRevealSelfDuration
        delay:kRevealSelfDelay
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x16e870 */
          weakSelf.transform = CGAffineTransformIdentity;
          weakSelf.alpha = 1;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x16e928 */
          // Stage 2: pop the artwork pair in.
          __weak UIImageView *weakArtworkBg = weakSelf->artworkBg;
          __weak UIImageView *weakArtworkView = weakSelf->artworkView;
          weakArtworkView.alpha = 0.0;
          [UIView animateWithDuration:kRevealStageDuration
              delay:0.0
              options:UIViewAnimationOptionCurveEaseOut
              animations:^{
                /** @ghidraAddress 0x16eabc */
                weakArtworkBg.transform = CGAffineTransformMakeScale(1.0, 1.0);
                weakArtworkBg.alpha = 1.0;
                weakArtworkView.transform = CGAffineTransformMakeScale(1.0, 1.0);
                weakArtworkView.alpha = 1.0;
              }
              completion:^(BOOL finished2) {
                /** @ghidraAddress 0x16ec48 */
                // Stage 3: pop the two title labels in.
                __weak UILabel *weakMusicName = weakSelf->musicName;
                __weak UILabel *weakArtistName = weakSelf->artistName;
                weakMusicName.alpha = 0.0;
                weakArtistName.alpha = 0.0;
                [UIView animateWithDuration:kRevealStageDuration
                    delay:0.0
                    options:UIViewAnimationOptionBeginFromCurrentState |
                            UIViewAnimationOptionAllowUserInteraction
                    animations:^{
                      /** @ghidraAddress 0x16ee04 */
                      weakMusicName.transform = CGAffineTransformMakeScale(1.0, 1.0);
                      weakMusicName.alpha = 1.0;
                      weakArtistName.transform = CGAffineTransformMakeScale(1.0, 1.0);
                      weakArtistName.alpha = 1.0;
                    }
                    completion:^(BOOL finished3) {
                      /** @ghidraAddress 0x16ef90 */
                      // Stage 4: pop the COMPLETE banner in.
                      __weak UIImageView *weakComplete = weakSelf->completeView;
                      weakComplete.alpha = 0.0;
                      [UIView animateWithDuration:kRevealBannerDuration
                          delay:0.0
                          options:UIViewAnimationOptionCurveEaseOut
                          animations:^{
                            /** @ghidraAddress 0x16f0dc */
                            weakComplete.transform = CGAffineTransformMakeScale(1.0, 1.0);
                            weakComplete.alpha = 1.0;
                          }
                          completion:^(BOOL finished4) {
                            /** @ghidraAddress 0x16f194 */
                            // The reveal is done: arm the dismiss tap.
                            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                initWithTarget:weakSelf
                                        action:@selector(closeView)];
                            [weakSelf->touchView addGestureRecognizer:tap];
                          }];
                    }];
              }];
        }];
}

/** @ghidraAddress 0x16f244 */
- (void)closeView {
    // Verified at 0x16f244: _objc_initWeak at 0x16f260, setAlpha:1.0 at 0x16f27c (fmov d0),
    // then animateWithDuration:DAT_0x28e040 (0.2) at 0x16f244 tail, blocks at 0x16f380 and
    // 0x16f3cc which fade out and notify delegate.
    __weak typeof(self) weakSelf = self;
    self.alpha = 1.0;
    [UIView animateWithDuration:0.2
        delay:0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x16f380 */
          weakSelf.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x16f3cc */
          (void)finished;
          if ([weakSelf.delegate respondsToSelector:@selector(scratchCompleteViewDidClose:)]) {
              [weakSelf.delegate scratchCompleteViewDidClose:weakSelf];
          }
        }];
}

@end
