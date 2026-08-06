#import "CubePurchaseListViewCell.h"

#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The first digit's artwork, loaded once in the initialiser purely to measure it. The rest of the
// set is named through the format below.
static NSString *const kFirstDigitImageName = @"scratch_num_s00";
static NSString *const kDigitImageNameFormat = @"scratch_num_s0%@";
static NSString *const kLabelPlateImageName = @"cube_pur_plate_label";

enum {
    // The most digits the row can hold artwork for.
    kDigitSlotCount = 5,
    // The digit-counting loop's own guard. It allows one pass more than there are slots.
    kMaxExtraDigitPasses = 4,
};

// Row metrics, one pair per idiom. Most pad figures are twice the phone's, but the description's
// x and width are not (85 against 42, and 273 against 136), so each is carried separately.
static const CGFloat kPhonePlateX = 25.0;
static const CGFloat kPadPlateX = 50.0; // @ghidraAddress 0x28f2c8
static const CGFloat kPhonePlateY = 1.0;
static const CGFloat kPadPlateY = 2.0;
static const CGFloat kPhonePlateWidth = 223.0; // @ghidraAddress 0x28f730
static const CGFloat kPadPlateWidth = 446.0;   // @ghidraAddress 0x28f738
static const CGFloat kPhonePlateHeight = 46.0; // @ghidraAddress 0x28f740
static const CGFloat kPadPlateHeight = 92.0;   // @ghidraAddress 0x28f748

static const int kPhoneDigitStartX = 105;
static const int kPadDigitStartX = 210;
static const CGFloat kPhoneDigitY = 10.0;
static const CGFloat kPadDigitY = 20.0;

static const CGFloat kPhoneLabelPlateX = 64.0;     // @ghidraAddress 0x28f1f0
static const CGFloat kPadLabelPlateX = 128.0;      // @ghidraAddress 0x28f750
static const CGFloat kPhoneLabelPlateWidth = 37.0; // @ghidraAddress 0x28f620
static const CGFloat kPadLabelPlateWidth = 74.0;   // @ghidraAddress 0x28f6f8

static const CGFloat kPhoneDescriptionX = 42.0;      // @ghidraAddress 0x28f758
static const CGFloat kPadDescriptionX = 85.0;        // @ghidraAddress 0x28f760
static const CGFloat kPhoneDescriptionWidth = 136.0; // @ghidraAddress 0x28f768
static const CGFloat kPadDescriptionWidth = 273.0;   // @ghidraAddress 0x28f770

static const CGFloat kPhonePriceX = 148.0;    // @ghidraAddress 0x28f778
static const CGFloat kPadPriceX = 296.0;      // @ghidraAddress 0x28f780
static const CGFloat kPhonePriceWidth = 75.0; // @ghidraAddress 0x28f788
static const CGFloat kPadPriceWidth = 150.0;  // @ghidraAddress 0x28f790

static const CGFloat kPhonePriceFontSize = 14.0;
static const CGFloat kPadPriceFontSize = 17.0;
// The description's point size is the digit artwork's height less this, truncated to a whole
// number, so it tracks whatever size the artwork happens to be.
static const CGFloat kDescriptionFontHeightAdjustment = -1.0;

@implementation CubePurchaseListViewCell {
    UIButton *bgImage;
    UILabel *priceText;
    UILabel *descriptText;
    UIImageView *labelImg;
    UIImageView *numImg[kDigitSlotCount];
}

/** @ghidraAddress 0x63dc0 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                          tag:(int)tag {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
        CGFloat plateX = isPad ? kPadPlateX : kPhonePlateX;
        CGFloat plateHeight = isPad ? kPadPlateHeight : kPhonePlateHeight;
        CGFloat digitY = isPad ? kPadDigitY : kPhoneDigitY;

        bgImage = [UIButton buttonWithType:UIButtonTypeCustom];
        bgImage.frame = CGRectMake(plateX,
                                   isPad ? kPadPlateY : kPhonePlateY,
                                   isPad ? kPadPlateWidth : kPhonePlateWidth,
                                   plateHeight);
        bgImage.tag = tag;
        [self addSubview:bgImage];
        self.backgroundColor = UIColor.clearColor;

        // Loaded here only to measure: every digit view takes this one image's size, and the
        // description's point size is derived from its height.
        UIImage *digitImage = LoadScaledPngImage(kFirstDigitImageName);

        int digitX = isPad ? kPadDigitStartX : kPhoneDigitStartX;
        for (int i = 0; i < kDigitSlotCount; ++i) {
            numImg[i] = [[UIImageView alloc]
                initWithFrame:CGRectMake(
                                  digitX, digitY, digitImage.size.width, digitImage.size.height)];
            [bgImage addSubview:numImg[i]];
            // Truncated to a whole number on every step, not accumulated in floating point.
            digitX = (int)(digitX + digitImage.size.width);
        }

        labelImg = [[UIImageView alloc]
            initWithFrame:CGRectMake(isPad ? kPadLabelPlateX : kPhoneLabelPlateX,
                                     digitY,
                                     isPad ? kPadLabelPlateWidth : kPhoneLabelPlateWidth,
                                     digitImage.size.height)];
        [bgImage addSubview:labelImg];

        // The description's y is the same value as the plate's x; the binary keeps one register
        // for both, so this is one constant used twice rather than two that happen to agree.
        descriptText = [[UILabel alloc]
            initWithFrame:CGRectMake(isPad ? kPadDescriptionX : kPhoneDescriptionX,
                                     plateX,
                                     isPad ? kPadDescriptionWidth : kPhoneDescriptionWidth,
                                     digitImage.size.height)];
        descriptText.textAlignment = NSTextAlignmentCenter;
        descriptText.font = [UIFont
            systemFontOfSize:(int)(digitImage.size.height + kDescriptionFontHeightAdjustment)];
        [bgImage addSubview:descriptText];

        priceText =
            [[UILabel alloc] initWithFrame:CGRectMake(isPad ? kPadPriceX : kPhonePriceX,
                                                      0,
                                                      isPad ? kPadPriceWidth : kPhonePriceWidth,
                                                      plateHeight)];
        priceText.textAlignment = NSTextAlignmentCenter;
        priceText.font =
            [UIFont systemFontOfSize:(isPad ? kPadPriceFontSize : kPhonePriceFontSize)];
        priceText.text = @"";
        [bgImage addSubview:priceText];

        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return self;
}

/** @ghidraAddress 0x64328 */
- (void)setBgImage:(UIImage *)bgImg
              info:(CubePurchaseInfo *)info
             cache:(NSMutableDictionary *)cache
         aDelegate:(id)aDelegate {
    [bgImage setBackgroundImage:bgImg forState:UIControlStateNormal];
    // Yes, the target is the argument, not self, and the argument is never stored in _aDelegate.
    [bgImage addTarget:aDelegate
                  action:@selector(tapPurchaseBtn:)
        forControlEvents:UIControlEventTouchUpInside];

    int cubeNum = [info getCubeNum];

    // How many digit slots to fill. The guard allows one pass more than there are slots, so a
    // count of six digits is reachable — see TYPES_PENDING.md.
    int digitCount = 1;
    if (cubeNum > 9 || cubeNum < -9) {
        int counter = cubeNum;
        int extraDigits = 0;
        do {
            counter /= 10;
            ++extraDigits;
        } while ((counter > 9 || counter < -9) && extraDigits <= kMaxExtraDigitPasses);
        digitCount = extraDigits + 1;
    }

    // Filled from the least significant digit backwards, so slot 0 ends up holding the most
    // significant one.
    int remaining = cubeNum;
    for (int slot = digitCount; slot > 0; --slot) {
        NSNumber *digit = @(remaining % 10);
        UIImage *digitImage = [cache objectForKey:digit];
        if (digitImage == nil) {
            digitImage =
                LoadScaledPngImage([NSString stringWithFormat:kDigitImageNameFormat, digit]);
            // Stored without a nil check, so a missing digit asset raises here rather than
            // drawing nothing.
            [cache setObject:digitImage forKey:digit];
        }
        numImg[slot - 1].image = digitImage;
        remaining /= 10;
    }

    UIImage *plateImage = [cache objectForKey:kLabelPlateImageName];
    if (plateImage == nil) {
        plateImage = LoadScaledPngImage(kLabelPlateImageName);
        [cache setObject:plateImage forKey:kLabelPlateImageName];
    }
    labelImg.image = plateImage;

    priceText.text = [info getPriceString];
    descriptText.text = [info getDescription];
}

@end
