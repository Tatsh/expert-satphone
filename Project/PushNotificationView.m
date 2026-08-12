#import "PushNotificationView.h"

#import <QuartzCore/QuartzCore.h>

#import "AudioManager.h"
#import "BalloonView.h"
#import "JubeatAppDelegate.h"

// The notification dictionary keys.
static NSString *const kPushKeyBody = @"body";
static NSString *const kPushKeySound = @"sound";
static NSString *const kPushKeyURL = @"url";

// The sound-file suffix stripped before the sound name is played as an SE.
static NSString *const kPushSoundSuffix = @".caf";

// The balloon's shadow, arrow, and content inset. The arrow direction 4 is off the balloon's
// four-way enum, i.e. no arrow.
static const CGFloat kPushShadowRadius = 3.0;
static const float kPushShadowOpacity = 0.9f; // @ghidraAddress 0x28f3b0
static const CGFloat kPushShadowOffsetY = 1.0;
static const NSUInteger kPushArrowDirectionNone = 4;
static const CGFloat kPushContentInset = 12.0;

// The label's left inset and the width it takes off the banner.
static const CGFloat kPushLabelX = 10.0;
static const CGFloat kPushLabelWidthInset = -20.0;

// The off-screen slide clears the banner's height plus this margin.
static const CGFloat kPushSlideMargin = 10.0;

// The slide animation duration and the on-screen display time before auto-dismiss.
static const NSTimeInterval kPushSlideDuration = 0.7; // @ghidraAddress 0x291c98
static const NSTimeInterval kPushDisplayDuration = 5.0;

@interface PushNotificationView () {
    BalloonView *bgView;         // +0x8
    NSDictionary *currentNotice; // +0x10
    NSTimer *dispTimer;          // +0x18
    BOOL bActive;                // +0x20
    UILabel *notiLabel;          // +0x28
    UIButton *linkBtn;           // +0x30
    __weak id aDelegate;         // +0x38
}
- (void)popNotification;
- (void)onDrawTimer:(NSTimer *)timer;
- (void)tapNotification:(id)sender;
@end

@implementation PushNotificationView

#pragma mark - Construction

/** @ghidraAddress 0xc8f98 */
- (instancetype)initWithFrame:(CGRect)frame delegate:(id)delegate {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    aDelegate = delegate;
    bActive = NO;

    // Start parked one banner-height above the screen so the first pop slides down into place.
    self.transform =
        CGAffineTransformMakeTranslation(0, -(self.frame.size.height + kPushSlideMargin));

    // The balloon background, arrow-less with a soft drop shadow.
    bgView =
        [[BalloonView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
    bgView.layer.shadowColor = UIColor.blackColor.CGColor;
    bgView.layer.shadowRadius = kPushShadowRadius;
    bgView.layer.shadowOpacity = kPushShadowOpacity;
    bgView.layer.shadowOffset = CGSizeMake(0, kPushShadowOffsetY);
    bgView.arrowDirection = (BalloonViewArrowDirection)kPushArrowDirectionNone;
    bgView.contentEdgeInsets = UIEdgeInsetsMake(
        kPushContentInset, kPushContentInset, kPushContentInset, kPushContentInset);
    [self addSubview:bgView];

    // The message label.
    notiLabel = [[UILabel alloc] initWithFrame:CGRectMake(kPushLabelX,
                                                          0,
                                                          frame.size.width + kPushLabelWidthInset,
                                                          frame.size.height)];
    notiLabel.textColor = UIColor.whiteColor;
    [self addSubview:notiLabel];

    // A transparent button covering the banner that reports taps.
    linkBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    linkBtn.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
    linkBtn.backgroundColor = UIColor.clearColor;
    [linkBtn addTarget:self
                  action:@selector(tapNotification:)
        forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:linkBtn];
    return self;
}

#pragma mark - Display

/** @ghidraAddress 0xc9a10 */
- (void)startNotification {
    if (bActive) {
        return;
    }
    [self popNotification];
}

/** @ghidraAddress 0xc93b8 */
- (void)popNotification {
    currentNotice = JubeatAppDelegate.appDelegate.popNotification;
    if (!currentNotice) {
        bActive = NO;
        return;
    }
    bActive = YES;
    NSString *body = currentNotice[kPushKeyBody];
    NSString *sound =
        [currentNotice[kPushKeySound] stringByReplacingOccurrencesOfString:kPushSoundSuffix
                                                                withString:@""];
    notiLabel.text = body;

    __weak PushNotificationView *weakSelf = self;
    [UIView animateWithDuration:kPushSlideDuration
        animations:^{
          /** @ghidraAddress 0xc95f8 */
          weakSelf.transform = CGAffineTransformMakeTranslation(0, 0);
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0xc967c */
          [AudioManager.sharedManager playSeResFile:sound inDirectory:nil];
          self->dispTimer = [NSTimer timerWithTimeInterval:kPushDisplayDuration
                                                    target:self
                                                  selector:@selector(onDrawTimer:)
                                                  userInfo:nil
                                                   repeats:NO];
          [NSRunLoop.currentRunLoop addTimer:self->dispTimer forMode:NSRunLoopCommonModes];
        }];
}

/** @ghidraAddress 0xc97c0 */
- (void)onDrawTimer:(NSTimer *)timer {
    [dispTimer invalidate];
    dispTimer = nil;
    __weak PushNotificationView *weakSelf = self;
    [UIView animateWithDuration:kPushSlideDuration
        animations:^{
          /** @ghidraAddress 0xc9910 */
          weakSelf.transform =
              CGAffineTransformMakeTranslation(0, -(weakSelf.frame.size.height + kPushSlideMargin));
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0xc99f0 */
          [self popNotification];
        }];
}

/** @ghidraAddress 0xc9a30 */
- (void)stopNotification {
    [self.layer removeAllAnimations];
    [dispTimer invalidate];
    __weak PushNotificationView *weakSelf = self;
    [UIView animateWithDuration:kPushSlideDuration
                     animations:^{
                       /** @ghidraAddress 0xc9b78 */
                       weakSelf.transform = CGAffineTransformMakeTranslation(
                           0, -(weakSelf.frame.size.height + kPushSlideMargin));
                     }
                     completion:^(BOOL __attribute__((unused)) finished){
                         /** @ghidraAddress 0xc9c58 */
                     }];
    dispTimer = nil;
    bActive = NO;
}

#pragma mark - Tap

/** @ghidraAddress 0xc9c5c */
- (void)tapNotification:(id)sender {
    if (currentNotice[kPushKeyURL] && [aDelegate respondsToSelector:@selector(tapNotification:)]) {
        [aDelegate performSelector:@selector(tapNotification:) withObject:currentNotice];
    }
}

#pragma mark - State

/** @ghidraAddress 0xc9d34 */
- (BOOL)isActive {
    return bActive;
}

@end
