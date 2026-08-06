#import "NteGameOptionRenderer.h"

#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The strip's artwork, from the CFString at 0x2dda80. An encrypted .tex, not a PNG.
static NSString *const kStripImageName = @"redy_anim";

// The phone's scale is its own width over this reference width.
static const double kReferenceWidth = 320.0; // @ghidraAddress 0x28f470

// A phone that is neither a pad nor four-inch shortens the strip by this instead of scaling it.
static const double kShortScreenHeightAdjustment = -60.0; // @ghidraAddress 0x291bc8

// The reveal moves in this many equal steps, each a third of the strip's width.
static const int kDivisionCount = 3;
static const float kDivisionValue = 0.3333333432674408f;

// Each step's slide, and the pause before the first one.
static const NSTimeInterval kStepDuration = 0.2; // @ghidraAddress 0x28f240
static const NSTimeInterval kFirstStepDelay = 1.0;
static const NSTimeInterval kBetweenStepsDelay = 0.2; // @ghidraAddress 0x28f240

@implementation NteGameOptionRenderer {
    float phoneRate;
    UIImageView *rightImage;
    int divCnt;
    float divValue;
}

/** @ghidraAddress 0x153404 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
        BOOL is4inch = JubeatAppDelegate.appDelegate.is4inchAspect;

        phoneRate = isPad ? 1.0f : (float)(frame.size.width / kReferenceWidth);
        self.clipsToBounds = YES;
        // Yes, -setUserActivity: on a UIView, cleared to nil. It has no visible effect here.
        self.userActivity = nil;

        UIImage *stripImage = LoadScaledEncryptedTexImage(kStripImageName);

        // The two idiom flags are combined with a bitwise or, not a logical one — the height is
        // scaled for a pad *or* a four-inch phone, and only a short phone takes the flat
        // adjustment. The width is always scaled.
        CGFloat stripHeight = (isPad | is4inch) ?
                                  stripImage.size.height * phoneRate :
                                  stripImage.size.height + kShortScreenHeightAdjustment;
        rightImage = [[UIImageView alloc]
            initWithFrame:CGRectMake(0, 0, stripImage.size.width * phoneRate, stripHeight)];
        rightImage.image = stripImage;
        [self addSubview:rightImage];

        divCnt = kDivisionCount;
        divValue = kDivisionValue;
    }
    return self;
}

/** @ghidraAddress 0x1538a8 */
- (void)openStart {
    rightImage.transform = CGAffineTransformMakeTranslation(0, 0);

    __weak UIImageView *weakRightImage = rightImage;
    [UIView animateWithDuration:kStepDuration
        delay:kFirstStepDelay
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          /** @ghidraAddress 0x153a10 */
          // One division across. Note the width comes from the renderer's own frame, not the
          // strip's.
          weakRightImage.transform =
              CGAffineTransformMakeTranslation(self.frame.size.width * self->divValue, 0);
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x153afc */
          [self nextOpen:1];
        }];
}

/** @ghidraAddress 0x15363c */
- (void)nextOpen:(int)index {
    int step = index + 1;

    __weak UIImageView *weakRightImage = rightImage;
    [UIView animateWithDuration:kStepDuration
        delay:kBetweenStepsDelay
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          /** @ghidraAddress 0x153770 */
          // The step count is captured as an int and widened through NEON — sxtl then scvtf —
          // rather than being stored as a float.
          weakRightImage.transform =
              CGAffineTransformMakeTranslation(self.frame.size.width * self->divValue * step, 0);
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x15386c */
          // The chain stops when the next step would reach the division count, so the strip ends
          // translated by exactly divCnt divisions.
          if (step < self->divCnt) {
              [self nextOpen:step];
          }
        }];
}

@end
