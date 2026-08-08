#import "ScratchCompleteView.h"

#import <QuartzCore/QuartzCore.h>

#import "JubeatAppDelegate.h"
#import "ScratchUtil.h"

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
    // Verified at 0x16e730: _objc_initWeak at 0x16e750, setAlpha:0 at 0x16e768 (movi v0),
    // then animateWithDuration:delay:options:animations:completion: at 0x16e730 tail
    // with DAT_0x293378 (0.3) and DAT_0x28f248 (0.1), blocks at 0x16e870 and 0x16e928.
    __weak typeof(self) weakSelf = self;
    self.alpha = 0;
    [UIView animateWithDuration:0.3
        delay:0.1
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x16e870 */
          weakSelf.transform = CGAffineTransformIdentity;
          weakSelf.alpha = 1;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x16e928 */
          // Reveal artwork — the completion block notifies that the view is visible.
          (void)finished;
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
