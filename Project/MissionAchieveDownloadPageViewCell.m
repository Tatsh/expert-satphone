#import "MissionAchieveDownloadPageViewCell.h"

#import "JubeatAppDelegate.h"

// The plate. The same two widths every list row in this tree uses, though these are immediates
// here rather than pool doubles.
static const int kPhonePlateWidth = 309;
static const int kPadPlateWidth = 460;
static const int kPhonePlateHeight = 60;
static const int kPadPlateHeight = 96;

static const CGFloat kPhoneTextInset = 10.0;
static const CGFloat kPadTextInset = 20.0;
static const CGFloat kPhoneTextWidth = 299.0; // @ghidraAddress 0x292a10
static const CGFloat kPadTextWidth = 440.0;   // @ghidraAddress 0x292f50

static const CGFloat kPhoneFontSize = 12.0;
static const CGFloat kPadFontSize = 20.0;

static const NSInteger kTextLineCount = 3;

// The button is the same size on both idioms; only its position tracks the plate.
static const CGFloat kButtonWidth = 80.0;  // @ghidraAddress 0x28f3f8
static const CGFloat kButtonHeight = 40.0; // @ghidraAddress 0x28f1f8
// Its leading edge sits this far in from the plate's trailing edge, which leaves a 20-point margin
// on both idioms once its own width is taken off.
static const int kButtonTrailingInset = 100;

@implementation MissionAchieveDownloadPageViewCell {
    UIImageView *bgImage;
    UILabel *listText;
    UIButton *downloadBtn;
}

/** @ghidraAddress 0x1ecdd0 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
        int plateWidth = isPad ? kPadPlateWidth : kPhonePlateWidth;
        int plateHeight = isPad ? kPadPlateHeight : kPhonePlateHeight;

        bgImage = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, plateWidth, plateHeight)];
        [self addSubview:bgImage];
        self.backgroundColor = UIColor.clearColor;

        // Inset plus width lands exactly on the plate's trailing edge on both idioms.
        listText =
            [[UILabel alloc] initWithFrame:CGRectMake(isPad ? kPadTextInset : kPhoneTextInset,
                                                      0,
                                                      isPad ? kPadTextWidth : kPhoneTextWidth,
                                                      plateHeight)];
        listText.numberOfLines = kTextLineCount;
        listText.font = [UIFont systemFontOfSize:(isPad ? kPadFontSize : kPhoneFontSize)];
        [self addSubview:listText];

        downloadBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        // Vertically centred by integer arithmetic, so an odd remainder rounds towards zero.
        downloadBtn.frame = CGRectMake(plateWidth - kButtonTrailingInset,
                                       (plateHeight - (int)kButtonHeight) / 2,
                                       kButtonWidth,
                                       kButtonHeight);
        downloadBtn.backgroundColor = UIColor.grayColor;
        downloadBtn.exclusiveTouch = YES;
        [downloadBtn addTarget:self
                        action:@selector(tapDownload:)
              forControlEvents:UIControlEventTouchUpInside];
        // Added last, so it sits over the label, which spans the plate's whole width.
        [self addSubview:downloadBtn];
    }
    return self;
}

/** @ghidraAddress 0x1ed110 */
- (void)setBgImage:(UIImage *)bgImg text:(NSString *)text btnEnable:(BOOL)btnEnable {
    bgImage.image = bgImg;
    listText.text = text;
    // Yes, only the colour changes. The button's own enabled state is never touched, so a grey
    // button still reports its taps.
    downloadBtn.backgroundColor = btnEnable ? UIColor.greenColor : UIColor.grayColor;
}

/** @ghidraAddress 0x1ed208 */
- (void)tapDownload:(id)sender {
    // Yes, sender is unused: the delegate is handed the cell rather than the button.
    if ([self.aDelegate respondsToSelector:@selector(tapDownloadBtn:)]) {
        [self.aDelegate performSelector:@selector(tapDownloadBtn:) withObject:self];
    }
}

@end
