#import "NteTitleOptionDropView.h"

#include <stdlib.h>

#import "ImageLoading.h"

// The only move type the class distinguishes. Anything else takes the other arm everywhere.
static const int kMoveTypeRight = 1;

// The artwork is one of title_anime_2, _3 or _4, picked afresh on every construction.
static NSString *const kArtworkNameFormat = @"title_anime_%d";
enum {
    kArtworkVariantCount = 3,
    kArtworkFirstVariant = 2,
};

// A quarter turn, at float precision rather than double — the pool holds the widened float, not
// M_PI_2 itself.
static const CGFloat kQuarterTurn = (float)M_PI_2; // @ghidraAddress 0x292f20

static const NSTimeInterval kDropDuration = 0.5;
// Only the right-hand ornament waits before it falls.
static const NSTimeInterval kRightDropDelay = 0.1f; // @ghidraAddress 0x28f2b8

@implementation NteTitleOptionDropView {
    UIImageView *mainImage;
    int moveType;
}

/** @ghidraAddress 0x140b70 */
- (instancetype)initWithMoveType:(CGRect)frame type:(int)type {
    self = [super initWithFrame:frame];
    if (self) {
        NSString *artworkName = [NSString
            stringWithFormat:kArtworkNameFormat,
                             (arc4random() % kArtworkVariantCount) + kArtworkFirstVariant];
        UIImage *artwork = LoadScaledEncryptedTexImage(artworkName);

        // The left ornament sits at the origin; the right one is pushed out to the frame's right
        // edge, truncated to a whole point.
        CGFloat x = 0;
        if (type == kMoveTypeRight) {
            x = (int)(frame.size.width - artwork.size.width);
        }

        moveType = type;
        mainImage = [[UIImageView alloc]
            initWithFrame:CGRectMake(x, 0, artwork.size.width, artwork.size.height)];
        mainImage.image = artwork;
        [self addSubview:mainImage];

        // The view animates itself the moment it is built. Nothing else has to start it.
        [self startAnimation];
    }
    return self;
}

/** @ghidraAddress 0x140d24 */
- (void)startAnimation {
    // Narrowed to float and negated there before being widened again — fcvt, fneg on an s
    // register, fcvt back — so the distance carries float precision, not the frame's.
    float dropDistance = -(float)self.frame.size.height;

    NSTimeInterval delay = (moveType == kMoveTypeRight) ? kRightDropDelay : 0.0;
    // The two ornaments spin away from each other.
    CGFloat rotation = (moveType == kMoveTypeRight) ? -kQuarterTurn : kQuarterTurn;

    CGAffineTransform transform = CGAffineTransformConcat(
        CGAffineTransformMakeRotation(rotation), CGAffineTransformMakeTranslation(0, dropDistance));

    __weak NteTitleOptionDropView *weakSelf = self;
    [UIView animateWithDuration:kDropDuration
        delay:delay
        options:UIViewAnimationOptionCurveEaseIn
        animations:^{
          /** @ghidraAddress 0x140efc */
          // The block captures self both ways and uses both: the transform goes through the weak
          // reference (objc_loadWeakRetained) and the alpha through the strong one.
          weakSelf.transform = transform;
          self.alpha = 0.0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x140fc4 */
          [self dropAnimEnd:self];
        }];
}

/** @ghidraAddress 0x141094 */
- (void)stopAnimation {
    // The binary's body is a single ret. Once started, the drop cannot be called off.
}

/** @ghidraAddress 0x140fe8 */
- (void)dropAnimEnd:(id)sender {
    // Yes, sender is unused: the delegate is handed the ornament rather than the sender, and the
    // completion block above passes the ornament anyway. The delegate is loaded from the weak slot
    // twice, once to test and once to send to.
    if ([self.aDelegate respondsToSelector:@selector(dropAnimEnd:)]) {
        [self.aDelegate performSelector:@selector(dropAnimEnd:) withObject:self];
    }
}

@end
