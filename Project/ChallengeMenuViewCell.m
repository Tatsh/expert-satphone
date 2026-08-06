#import "ChallengeMenuViewCell.h"

#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

enum {
    // The badge's two digit rows, sized once and never resized.
    kTwoDigitSlotCount = 2,
    kThreeDigitSlotCount = 3,
    // A single digit is drawn in the middle slot of the three-wide row.
    kThreeDigitCentreSlot = 1,
};

// The badge plate behind the digits, from the CFString at 0x2d6420.
static NSString *const kBadgeImageName = @"challenge_pre_badge";

// The width the row centres its button within.
static const CGFloat kPhoneContentWidth = 310.0; // @ghidraAddress 0x28f410
static const CGFloat kPadContentWidth = 460.0;   // @ghidraAddress 0x28f4f0

// The badge sits three quarters of the way across the button, spelled as a multiply by three then
// a quarter rather than as 0.75, which is the order the binary evaluates in.
static const CGFloat kBadgeThirds = 3.0;
static const CGFloat kBadgeQuarter = 0.25;

// Half a digit short of centre per digit either side: three digits start 1.5 widths left of the
// plate's midpoint, two start one width left. Both land exactly centred.
static const CGFloat kThreeDigitStartOffset = -1.5;

// Above this the badge shows this instead, rather than refusing to draw.
static const int kMaximumBadgeNumber = 999;
static const int kTwoDigitFloor = 10;
static const int kThreeDigitFloor = 100;

@implementation ChallengeMenuViewCell {
    UIButton *menuBtn;
    UIImageView *numImageBg;
    NSArray *numImage;
    UIImageView *numImage3d[kThreeDigitSlotCount];
    UIImageView *numImage2d[kTwoDigitSlotCount];
}

/** @ghidraAddress 0x41b74 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Redundant: a freshly allocated instance already has this nil. Reproduced because the
        // binary really does release and clear it here.
        menuBtn = nil;
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return self;
}

/** @ghidraAddress 0x42314 */
- (void)setNumber:(int)number {
    if (number == 0) {
        numImageBg.hidden = YES;
        return;
    }
    numImageBg.hidden = NO;

    // Every slot in both rows is cleared first, so the row not in use draws nothing.
    for (int slot = 0; slot < kThreeDigitSlotCount; ++slot) {
        numImage3d[slot].image = nil;
    }
    for (int slot = 0; slot < kTwoDigitSlotCount; ++slot) {
        numImage2d[slot].image = nil;
    }

    int shown = number > kMaximumBadgeNumber ? kMaximumBadgeNumber : number;
    if (shown < kTwoDigitFloor) {
        // Yes, the three-wide row, not the two-wide one — a single digit sits in its centre.
        numImage3d[kThreeDigitCentreSlot].image = numImage[shown];
    } else if (shown < kThreeDigitFloor) {
        numImage2d[0].image = numImage[shown / 10];
        numImage2d[1].image = numImage[shown % 10];
    } else {
        numImage3d[2].image = numImage[shown % 10];
        numImage3d[1].image = numImage[shown / 10 % 10];
        // The modulo here cannot bite, since shown is already capped at 999 and so this quotient
        // never exceeds nine. The binary computes it anyway.
        numImage3d[0].image = numImage[shown / 100 % 10];
    }
}

/** @ghidraAddress 0x41c24 */
- (void)setBgImage:(UIImage *)bgImg numImage:(NSArray *)numImg {
    // The whole construction happens once. A second call only re-applies the tag, the target and
    // the background image below.
    if (menuBtn == nil) {
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;

        menuBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        CGFloat contentWidth = isPad ? kPadContentWidth : kPhoneContentWidth;
        menuBtn.frame = CGRectMake(
            (contentWidth - bgImg.size.width) / 2, 0, bgImg.size.width, bgImg.size.height);
        menuBtn.exclusiveTouch = YES;
        [self addSubview:menuBtn];

        UIImage *badgeImage = LoadScaledPngImage(kBadgeImageName);
        numImageBg = [[UIImageView alloc] initWithImage:badgeImage];
        numImageBg.frame = CGRectMake(menuBtn.frame.size.width * kBadgeThirds * kBadgeQuarter,
                                      (menuBtn.frame.size.height - badgeImage.size.height) / 2,
                                      badgeImage.size.width,
                                      badgeImage.size.height);

        if (numImg != nil) {
            numImage = [numImg copy];
            // Every digit slot is sized and placed from digit zero's artwork, so the set is
            // assumed uniform.
            UIImage *digit = numImage[0];
            CGFloat digitY = (int)((badgeImage.size.height - digit.size.height) / 2);

            CGFloat x =
                (int)(badgeImage.size.width / 2 + digit.size.width * kThreeDigitStartOffset);
            for (int slot = 0; slot < kThreeDigitSlotCount; ++slot) {
                numImage3d[slot] = [[UIImageView alloc]
                    initWithFrame:CGRectMake(x, digitY, digit.size.width, digit.size.height)];
                [numImageBg addSubview:numImage3d[slot]];
                // Truncated on every step, so the digits stay on whole points.
                x = (int)(x + digit.size.width);
            }

            x = (int)(badgeImage.size.width / 2 - digit.size.width);
            for (int slot = 0; slot < kTwoDigitSlotCount; ++slot) {
                numImage2d[slot] = [[UIImageView alloc]
                    initWithFrame:CGRectMake(x, digitY, digit.size.width, digit.size.height)];
                [numImageBg addSubview:numImage2d[slot]];
                x = (int)(x + digit.size.width);
            }
            // The binary sends -size to the digit twice more with the result discarded, once at
            // 0x420c8 and once at 0x42214. Left out, since neither has any effect.
        }

        // Hidden until -setNumber: is given something to show, whether or not the digits exist.
        numImageBg.hidden = YES;
        [menuBtn addSubview:numImageBg];
    }

    menuBtn.tag = self.tag;
    // The target is the delegate, not self. With a nil delegate UIKit walks the responder chain
    // from the button instead, which reaches this cell — and that is what the empty -tapMenu:
    // below absorbs.
    [menuBtn addTarget:self.aDelegate
                  action:@selector(tapMenu:)
        forControlEvents:UIControlEventTouchUpInside];
    [menuBtn setBackgroundImage:bgImg forState:UIControlStateNormal];
}

/** @ghidraAddress 0x425e4 */
- (void)tapMenu:(id)sender {
    // Yes, empty. The compiled body is a single return instruction. See the note above: this is
    // the responder-chain fallback for a row with no delegate, not dead code.
}

@end
