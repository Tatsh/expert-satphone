#import "MissionAchievementMessage.h"

#import <QuartzCore/QuartzCore.h>

#import "AudioManager.h"
#import "BalloonView.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The completion sound played as the banner enters. From the CFString at 0x2d6960.
static NSString *const kMissionGaugeSEName = @"SD_MISSION_GAUGE";

// The banner auto-dismisses after this many seconds; the 6.0f is planted in -enterAnimationStart at
// 0x4eb2c and threaded through every entry stage as the NSTimer interval.
static const NSTimeInterval kMissionMessageDismissDelay = 6.0;

// The four entry-stage durations and the two exit-stage durations. From the pooled doubles at
// 0x28e040 (0.2), 0x28f260 (0.3), and the fmov immediate 0x4034000000000000 (20.0) for the slide.
static const NSTimeInterval kMissionMessageShortStageDuration = 0.2;  // @ghidraAddress 0x28e040
static const NSTimeInterval kMissionMessageSettleStageDuration = 0.3; // @ghidraAddress 0x28f260
static const CGFloat kMissionMessageSlideDownDistance = 20.0;         // fmov 0x4034000000000000

@implementation MissionAchievementMessage {
    UIImageView *conImg;         // +0x08, ivar-offset global 0x349c5c
    UIView *messageView;         // +0x10, ivar-offset global 0x349c54
    BalloonView *bgView;         // +0x18, ivar-offset global 0x349c60
    int fontSize;                // +0x20, ivar-offset global 0x349c4c
    UILabel *messageText;        // +0x28, ivar-offset global 0x349c6c
    int viewHeight;              // +0x30, ivar-offset global 0x349c50
    int bgWidth;                 // +0x34, ivar-offset global 0x349c64
    int bgHeight;                // +0x38, ivar-offset global 0x349c68
    NSMutableArray *conImgTable; // +0x40, ivar-offset global 0x349c58
    NSTimer *messageTimer;       // +0x48, ivar-offset global 0x349c74
    BOOL bTap;                   // +0x50, ivar-offset global 0x349c70
    BOOL isPad;                  // +0x51, ivar-offset global 0x349c48
    // _aDelegate is weak, at +0x58 (ivar-offset global 0x349c78).
}

#pragma mark - Entry animation

/** @ghidraAddress 0x4ea44 */
- (void)enterAnimationStart {
    // A four-stage chain: fade the banner in, start the icon and slide the message down, settle the
    // balloon back to identity, then arm the auto-dismiss timer and unlock tapping. The 6.0s timer
    // interval is threaded through every stage's completion block.
    bTap = NO;
    [AudioManager.sharedManager playSeResFile:kMissionGaugeSEName inDirectory:nil];

    __weak MissionAchievementMessage *weakSelf = self;
    [UIView animateWithDuration:kMissionMessageShortStageDuration
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x4eba8 */
          weakSelf.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x4ebf4 */
          MissionAchievementMessage *strongSelf = weakSelf;
          [strongSelf->conImg startAnimating];
          __weak UIView *weakMessageView = strongSelf->messageView;
          [UIView animateWithDuration:kMissionMessageShortStageDuration
              delay:0
              options:UIViewAnimationOptionCurveLinear
              animations:^{
                /** @ghidraAddress 0x4ed34 */
                weakMessageView.transform =
                    CGAffineTransformMakeTranslation(0, kMissionMessageSlideDownDistance);
              }
              completion:^(BOOL innerFinished) {
                /** @ghidraAddress 0x4edb8 */
                __weak BalloonView *weakBgView = strongSelf->bgView;
                [UIView animateWithDuration:kMissionMessageSettleStageDuration
                    delay:0
                    options:UIViewAnimationOptionCurveLinear
                    animations:^{
                      /** @ghidraAddress 0x4eedc */
                      // The identity transform, built the long way as the binary does: translate by
                      // zero, then scale by one, undoing the collapse -createMassageBg: left.
                      weakBgView.transform =
                          CGAffineTransformScale(CGAffineTransformMakeTranslation(0, 0), 1, 1);
                    }
                    completion:^(BOOL settleFinished) {
                      /** @ghidraAddress 0x4efa4 */
                      // Arm the auto-dismiss timer and unlock tapping, regardless of whether the
                      // animation ran to completion, so the banner can always be dismissed.
                      strongSelf->messageTimer =
                          [NSTimer scheduledTimerWithTimeInterval:kMissionMessageDismissDelay
                                                           target:strongSelf
                                                         selector:@selector(dispEnd:)
                                                         userInfo:nil
                                                          repeats:NO];
                      strongSelf->bTap = YES;
                    }];
              }];
        }];
}

#pragma mark - Exit animation

/** @ghidraAddress 0x4f058 */
- (void)outerAnimationStart {
    // The mirror of the entry: collapse the balloon toward its arrow and slide the message up, then
    // fade the banner out and tell the delegate it has closed. Taps are locked for the whole exit.
    bTap = NO;

    // The two target transforms are computed here and baked into the animation block. The balloon
    // collapses to nothing at an offset of (bgWidth - bgWidth/4, bgHeight - bgHeight/3); the
    // message slides up by its own height.
    CGAffineTransform bgTarget = CGAffineTransformScale(
        CGAffineTransformMakeTranslation(bgWidth - bgWidth / 4, bgHeight - bgHeight / 3), 0, 0);
    CGAffineTransform messageTarget = CGAffineTransformMakeTranslation(0, -viewHeight);

    [conImg startAnimating];

    __weak MissionAchievementMessage *weakSelf = self;
    __weak BalloonView *weakBgView = bgView;
    __weak UIView *weakMessageView = messageView;
    [UIView animateWithDuration:kMissionMessageSettleStageDuration
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x4f318 */
          weakBgView.transform = bgTarget;
          weakMessageView.transform = messageTarget;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x4f418 */
          MissionAchievementMessage *strongSelf = weakSelf;
          [UIView animateWithDuration:kMissionMessageShortStageDuration
              delay:0
              options:UIViewAnimationOptionCurveLinear
              animations:^{
                /** @ghidraAddress 0x4f50c */
                weakSelf.alpha = 0;
              }
              completion:^(BOOL fadeFinished) {
                /** @ghidraAddress 0x4f558 */
                [strongSelf messageEnd];
              }];
        }];
}

/** @ghidraAddress 0x4f5cc */
- (void)transReset {
    // Park the balloon collapsed at its arrow offset and the message above the frame, then hide the
    // whole banner. This is the state -enterAnimationStart animates out of.
    bgView.transform = CGAffineTransformScale(
        CGAffineTransformMakeTranslation(bgWidth - bgWidth / 4, bgHeight - bgHeight / 3), 0, 0);
    messageView.transform = CGAffineTransformMakeTranslation(0, -viewHeight);
    self.alpha = 0;
}

#pragma mark - Dismissal

/** @ghidraAddress 0x4f730 */
- (void)dispEnd:(NSTimer *)timer {
    messageTimer = nil;
    [self outerAnimationStart];
}

/** @ghidraAddress 0x4f76c */
- (void)messageEnd {
    if ([self.aDelegate respondsToSelector:@selector(messageClose)]) {
        [self.aDelegate messageClose];
    }
}

#pragma mark - Touch handling

/** @ghidraAddress 0x4fcec */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    // Empty in the binary.
}

/** @ghidraAddress 0x4fcc8 */
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    // A tap while the banner is up dismisses it early; the flag guards against a second tap during
    // the exit animation.
    if (bTap) {
        bTap = NO;
        [self outerAnimationStart];
    }
}

#pragma mark - Balloon background

/** @ghidraAddress 0x4f81c */
- (void)createMassageBg:(CGSize)size {
    // A BalloonView with a soft drop shadow and a downward arrow, inset by 12 points on each side.
    bgView = [[BalloonView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    bgView.layer.shadowColor = UIColor.blackColor.CGColor;
    bgView.layer.shadowRadius = 3;     // 0x4008000000000000
    bgView.layer.shadowOpacity = 0.9f; // 0x28f3b0
    bgView.layer.shadowOffset = CGSizeMake(0, 1);
    bgView.arrowDirection = BalloonViewArrowDirectionRight; // 3
    bgView.contentEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
    [messageView addSubview:bgView];
    bgWidth = (int)bgView.frame.size.width;
    bgHeight = (int)bgView.frame.size.height;
}

@end
