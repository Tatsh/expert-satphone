#import "NteTitleOptionView.h"

#include <math.h>

#import "ImageLoading.h"

// The direction mask -[setOptDirection:] reads. Bits 1 and 2 pick the tilt sense; bit 0 mirrors
// the plate and negates whatever tilt bits 1 and 2 chose.
enum {
    kOptDirectionMirror = 1 << 0,       // Mirror horizontally and negate the tilt.
    kOptDirectionTiltPositive = 1 << 1, // Tilt one way.
    kOptDirectionTiltNegative = 1 << 2, // Tilt the other way; overrides the positive tilt.
};

// The two ornament textures. title_anime_1 is the smog puff, title_anime_0 the car; the car sits to
// the right of the smog's width.
static NSString *const kSmogImageName = @"title_anime_1";
static NSString *const kCarImageName = @"title_anime_0";

// The tilt magnitude, stored as a 32-bit float and equal to pi/10 at float precision. The binary
// keeps the negation in a neighbouring pool slot (0x2943f0); the reconstruction negates instead.
static const float kTiltAngle = (float)(M_PI / 10.0); // @ghidraAddress 0x2943ec

// The smog starts collapsed to nothing and pushed out; it eases in to its resting scale and offset,
// looping forever. The rest offset multiplies the smog width on both axes — the y factor is applied
// to the width, not the height, which matches the binary.
static const CGFloat kSmogStartTranslateXFactor = 0.95; // @ghidraAddress 0x28f6e0
static const CGFloat kSmogStartTranslateYFactor = 0.5;
static const CGFloat kSmogRestScale = 0.7;             // @ghidraAddress 0x291c98
static const CGFloat kSmogRestTranslateXFactor = 0.15; // @ghidraAddress 0x291db0
static const CGFloat kSmogRestTranslateYFactor = 0.1;  // @ghidraAddress 0x28f2b8
static const NSTimeInterval kSmogRevealDuration = 0.6; // @ghidraAddress 0x28f230

// The car bobs up by a few points each pass and snaps back down before the next.
static const CGFloat kCarBobDistance = -5.0;
static const NSTimeInterval kCarBobDelay = 0.4; // @ghidraAddress 0x28f2c0

// A shared 0.20-second animation duration global, defined elsewhere in the binary.
extern const double g_dAnimDuration020;

@implementation NteTitleOptionView {
    UIView *bgView;
    UIView *carView;
    UIImageView *carImage;
    UIImageView *smogImage;
    CGSize smogSize;
    BOOL nextCarFunc;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x2078e4 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        CGFloat width = frame.size.width;
        CGFloat height = frame.size.height;

        bgView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
        [self addSubview:bgView];

        carView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
        [bgView addSubview:carView];

        UIImage *smogArt = LoadScaledEncryptedTexImage(kSmogImageName);
        smogSize = smogArt.size;
        smogImage = [[UIImageView alloc]
            initWithFrame:CGRectMake(0, 0, smogArt.size.width, smogArt.size.height)];
        smogImage.image = smogArt;
        [carView addSubview:smogImage];

        UIImage *carArt = LoadScaledEncryptedTexImage(kCarImageName);
        // The car is placed at the smog's width, truncated to a whole point.
        carImage = [[UIImageView alloc]
            initWithFrame:CGRectMake(
                              (int)smogArt.size.width, 0, carArt.size.width, carArt.size.height)];
        carImage.image = carArt;
        [carView addSubview:carImage];

        // The reveal starts as soon as the view is built.
        [self startAnimation];
    }
    return self;
}

#pragma mark - Layout

/** @ghidraAddress 0x207bc0 */
- (void)setOptDirection:(int)direction {
    float tilt = (direction & kOptDirectionTiltPositive) ? kTiltAngle : 0.0f;
    if (direction & kOptDirectionTiltNegative) {
        tilt = -kTiltAngle;
    }

    CGFloat scaleX = 1.0;
    if (direction & kOptDirectionMirror) {
        scaleX = -1.0;
        tilt = -tilt;
    }

    bgView.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(scaleX, 1.0),
                                               CGAffineTransformMakeRotation(tilt));
}

#pragma mark - Animation

/** @ghidraAddress 0x207cb0 */
- (void)startAnimation {
    __weak UIImageView *weakSmog = smogImage;
    // The initial alpha is set through the strong reference, the initial transform through the weak
    // one, matching the binary's split.
    smogImage.alpha = 0.0;

    CGAffineTransform start = CGAffineTransformConcat(
        CGAffineTransformMakeScale(0, 0),
        CGAffineTransformMakeTranslation(smogSize.width * kSmogStartTranslateXFactor,
                                         smogSize.height * kSmogStartTranslateYFactor));
    weakSmog.transform = start;

    CGAffineTransform rest = CGAffineTransformConcat(
        CGAffineTransformMakeScale(kSmogRestScale, kSmogRestScale),
        CGAffineTransformMakeTranslation(smogSize.width * kSmogRestTranslateXFactor,
                                         smogSize.width * kSmogRestTranslateYFactor));

    // The Repeat option makes the reveal loop on its own, so the completion is a no-op.
    [UIView animateWithDuration:kSmogRevealDuration
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionRepeat
                     animations:^{
                       /** @ghidraAddress 0x207f2c */
                       weakSmog.alpha = 1.0;
                       weakSmog.transform = rest;
                     }
                     completion:^(BOOL finished){
                     }];

    nextCarFunc = YES;
    [self startCarAnimation];
}

/** @ghidraAddress 0x207fd4 */
- (void)startCarAnimation {
    __weak UIView *weakCar = carView;
    CGAffineTransform bobUp = CGAffineTransformMakeTranslation(0, kCarBobDistance);

    // Snap the car back to its origin before the next pass; the previous pass left it raised.
    carView.transform = CGAffineTransformMakeTranslation(0, 0);

    [UIView animateWithDuration:g_dAnimDuration020
        delay:kCarBobDelay
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          /** @ghidraAddress 0x20816c */
          weakCar.transform = bobUp;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x2081e0 */
          // finished is ignored; only nextCarFunc stops the loop.
          if (self->nextCarFunc) {
              [self startCarAnimation];
          }
        }];
}

/** @ghidraAddress 0x208214 */
- (void)stopAnimation {
    nextCarFunc = NO;
    [carView.layer removeAllAnimations];
    [smogImage.layer removeAllAnimations];
}

@end
