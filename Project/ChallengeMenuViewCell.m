#import "ChallengeMenuViewCell.h"

enum {
    // The badge's two digit rows, sized once and never resized.
    kTwoDigitSlotCount = 2,
    kThreeDigitSlotCount = 3,
    // A single digit is drawn in the middle slot of the three-wide row.
    kThreeDigitCentreSlot = 1,
};

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

/** @ghidraAddress 0x425e4 */
- (void)tapMenu:(id)sender {
    // Yes, empty. The compiled body is a single return instruction.
}

@end
