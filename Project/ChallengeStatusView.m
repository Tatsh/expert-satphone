#import "ChallengeStatusView.h"

#import <QuartzCore/QuartzCore.h>

#import "ChallengeStatus.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// Two ChallengeStatus accessors this view reads that are not yet declared on the (incomplete)
// ChallengeStatus header. See TYPES_PENDING.md.
@interface ChallengeStatus (ChallengeStatusView)
- (int)jCubeNum;
- (nullable NSString *)timeStringFromInterval:(double)interval Minute:(BOOL)minute;
@end

@interface ChallengeStatusView ()
- (void)setNumberImage:(int)type num:(int)number;
- (void)tapBuyCube:(nonnull id)sender;
- (void)alertSelect:(nonnull NSDictionary *)info;
@end

// The number-type selectors passed to -setNumberImage:num:.
static const int kStatusNumberTypeCoin = 0;
static const int kStatusNumberTypeCoinLimit = 1;
static const int kStatusNumberTypeCube = 2;

// The digit counts: three for the coin/limit fields, five for the cube field.
static const int kStatusCoinDigits = 3;
static const int kStatusCubeDigits = 5;
static const int kStatusDigitBase = 10;

// The images.
static NSString *const kStatusBackgroundImageName = @"challenge_status_bg";
static NSString *const kStatusSlashImageName = @"scratch_num_slash";
static NSString *const kStatusBuyCubeImageName = @"scratch_btn_buyjcube";
static NSString *const kStatusNumberImageFormat = @"scratch_num_s0%d";

// The rest-time label copy: "あと %@".
static NSString *const kStatusRestTimeFormat = @"あと%@";

// The layout base coordinates by idiom: the digit column's left edge and top.
static const int kStatusOriginXPad = 0x46;   // 70
static const int kStatusOriginXPhone = 0x1c; // 28
static const int kStatusOriginYPad = 0x1a;   // 26
static const int kStatusOriginYPhone = 0xb;  // 11

// The rest-time label: its width (from the pool at 0x28f3f0), height, font size, and the cube
// column's x by idiom.
static const CGFloat kStatusRestLabelWidth = 100.0; // @ghidraAddress 0x28f3f0
static const CGFloat kStatusRestLabelHeight = 30.0;
static const CGFloat kStatusRestLabelYOffsetPad = 16.0;
static const CGFloat kStatusRestLabelYOffsetPhone = 2.0;
static const CGFloat kStatusRestFontSizePad = 17.0;
static const CGFloat kStatusRestFontSizePhone = 10.0;
static const int kStatusCubeColumnXPad = 0x118;  // 280
static const int kStatusCubeColumnXPhone = 0x82; // 130

// The buy-cube button is inset by ten points and padded by twenty on each axis around the cube
// column and the button image.
static const CGFloat kStatusBuyButtonInset = -10.0;
static const CGFloat kStatusBuyButtonPad = 20.0;
static const CGFloat kStatusBuyButtonBaseline = 2.0;

// The half-scale used to centre the buy-cube button vertically.
static const CGFloat kStatusHalf = 0.5;

// The coin-regeneration threshold: below one second remaining, a coin is regenerated.
static const double kStatusRegenThreshold = 1.0;

// The delegate selector for starting a cube purchase, and the confirmation alert's OK button index.
static const int kStatusConfirmOKButton = 1;

@implementation ChallengeStatusView {
    UIImageView *bgView;                // +0x8
    UIImage *numberTable[10];           // +0x10
    UIImageView *playCoinImage[3];      // +0x60
    UIImageView *playCoinLimitImage[3]; // +0x78
    UIImageView *playCoinSlash;         // +0x90
    UIImageView *cubeImage[5];          // +0x98
    UILabel *coinRestTime;              // +0xc0
    UIButton *buyCube;                  // +0xc8
    // _aDelegate (weak) at +0xd0 is synthesised.
}

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0x85e48 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    self.opaque = NO;
    self.layer.doubleSided = NO;
    if (!isPad) {
        // The phone reads the screen rate (its result is used implicitly by LoadScaledPngImage's
        // own scaling); the value itself is not stored here.
        (void)ChallengeStatus.sharedStatus.phoneScreenRate;
    }

    int originX = isPad ? kStatusOriginXPad : kStatusOriginXPhone;
    int originY = isPad ? kStatusOriginYPad : kStatusOriginYPhone;

    // The background fills its natural size.
    UIImage *bg = LoadScaledPngImage(kStatusBackgroundImageName);
    bgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, bg.size.width, bg.size.height)];
    bgView.image = bg;
    [self addSubview:bgView];

    // The ten digit images.
    for (int i = 0; i < kStatusDigitBase; ++i) {
        numberTable[i] =
            LoadScaledPngImage([NSString stringWithFormat:kStatusNumberImageFormat, i]);
    }
    CGFloat digitWidth = numberTable[0].size.width;
    CGFloat digitHeight = numberTable[0].size.height;

    // The slash sits after the three coin digits.
    playCoinSlash = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kStatusSlashImageName)];
    playCoinSlash.frame = CGRectMake(originX + digitWidth * kStatusCoinDigits,
                                     originY,
                                     playCoinSlash.image.size.width,
                                     playCoinSlash.image.size.height);
    [self addSubview:playCoinSlash];

    // The three coin digits, then (after the slash) the three limit digits.
    CGFloat limitX = originX + digitWidth * kStatusCoinDigits + playCoinSlash.image.size.width;
    for (int i = 0; i < kStatusCoinDigits; ++i) {
        playCoinImage[i] = [[UIImageView alloc]
            initWithFrame:CGRectMake(originX + digitWidth * i, originY, digitWidth, digitHeight)];
        playCoinImage[i].image = numberTable[0];
        [self addSubview:playCoinImage[i]];

        playCoinLimitImage[i] = [[UIImageView alloc]
            initWithFrame:CGRectMake(limitX + digitWidth * i, originY, digitWidth, digitHeight)];
        playCoinLimitImage[i].image = numberTable[0];
        [self addSubview:playCoinLimitImage[i]];
    }

    // The coin rest-time label sits to the right of the limit column.
    CGFloat labelYOffset = isPad ? kStatusRestLabelYOffsetPad : kStatusRestLabelYOffsetPhone;
    int limitRightX = (int)(limitX + digitWidth * kStatusCoinDigits);
    coinRestTime = [[UILabel alloc] initWithFrame:CGRectMake(limitRightX - 100,
                                                             (int)(labelYOffset + originY),
                                                             kStatusRestLabelWidth,
                                                             kStatusRestLabelHeight)];
    coinRestTime.font =
        [UIFont systemFontOfSize:isPad ? kStatusRestFontSizePad : kStatusRestFontSizePhone];
    coinRestTime.textAlignment = NSTextAlignmentRight;
    coinRestTime.text = @"";
    [self addSubview:coinRestTime];

    // The five cube digits, from the idiom's cube column. The running x advances by a digit width
    // each slot, and its vertical centre accumulates a half-digit-height for the button.
    int cubeX = isPad ? kStatusCubeColumnXPad : kStatusCubeColumnXPhone;
    for (int i = 0; i < kStatusCubeDigits; ++i) {
        cubeImage[i] = [[UIImageView alloc]
            initWithFrame:CGRectMake(cubeX + digitWidth * i, originY, digitWidth, digitHeight)];
        cubeImage[i].image = numberTable[0];
        [self addSubview:cubeImage[i]];
    }
    // The button's vertical centre is the digit row plus half a digit height.
    CGFloat buttonCentreY = originY + digitHeight * kStatusHalf;

    // The buy-cube button covers the end of the cube column, inset by ten and padded by twenty.
    buyCube = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *buyImage = LoadScaledPngImage(kStatusBuyCubeImageName);
    [buyCube setImage:buyImage forState:UIControlStateNormal];
    int buttonX = (int)(cubeX + digitWidth * kStatusCubeDigits + digitWidth);
    int buttonY =
        (int)(buttonCentreY - buyImage.size.height * kStatusHalf + kStatusBuyButtonBaseline);
    buyCube.frame = CGRectMake(buttonX + kStatusBuyButtonInset,
                               buttonY + kStatusBuyButtonInset,
                               buyImage.size.width + kStatusBuyButtonPad,
                               buyImage.size.height + kStatusBuyButtonPad);
    [buyCube addTarget:self
                  action:@selector(tapBuyCube:)
        forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:buyCube];
    return self;
}

#pragma mark - Number rendering

/** @ghidraAddress 0x86710 */
- (void)setNumberImage:(int)type num:(int)number {
    int digitCount = (type == kStatusNumberTypeCube) ? kStatusCubeDigits : kStatusCoinDigits;
    // Digits are filled from the least-significant place; leading zeros are blanked except the
    // ones place.
    __unsafe_unretained UIImageView *const *slots;
    if (type == kStatusNumberTypeCoin) {
        slots = playCoinImage;
    } else if (type == kStatusNumberTypeCoinLimit) {
        slots = playCoinLimitImage;
    } else {
        slots = cubeImage;
    }
    for (int i = 0; i < digitCount; ++i) {
        UIImage *digit = (i == 0 || number != 0) ? numberTable[number % kStatusDigitBase] : nil;
        slots[digitCount - 1 - i].image = digit;
        number /= kStatusDigitBase;
    }
}

#pragma mark - Status refresh

/** @ghidraAddress 0x868bc */
- (void)updateDisplayStatus {
    ChallengeStatus *status = ChallengeStatus.sharedStatus;
    [self setNumberImage:kStatusNumberTypeCoin num:status.coinNum];
    [self setNumberImage:kStatusNumberTypeCoinLimit num:status.coinLim];
    [self setNumberImage:kStatusNumberTypeCube num:status.jCubeNum];
    if (status.coinNum < status.coinLim) {
        double timeLeft = [status getTimeLeft:status.coinRestDate];
        NSString *time = [status timeStringFromInterval:timeLeft Minute:YES];
        coinRestTime.text = [NSString stringWithFormat:kStatusRestTimeFormat, time];
    } else {
        coinRestTime.text = @"";
    }
}

/** @ghidraAddress 0x86a84 */
- (void)timerUpdate {
    ChallengeStatus *status = ChallengeStatus.sharedStatus;
    if (status.coinNum < status.coinLim) {
        double timeLeft = [status getTimeLeft:status.coinRestDate];
        if (timeLeft >= kStatusRegenThreshold) {
            NSString *time = [status timeStringFromInterval:[status getTimeLeft:status.coinRestDate]
                                                     Minute:YES];
            coinRestTime.text = [NSString stringWithFormat:kStatusRestTimeFormat, time];
        } else {
            // The timer elapsed: regenerate a coin and re-render the coin count.
            [status restCoinNum];
            [self setNumberImage:kStatusNumberTypeCoin num:status.coinNum];
            if (status.coinNum < status.coinLim) {
                NSString *time =
                    [status timeStringFromInterval:[status getTimeLeft:status.coinRestDate]
                                            Minute:YES];
                coinRestTime.text = [NSString stringWithFormat:kStatusRestTimeFormat, time];
            } else {
                coinRestTime.text = @"";
            }
        }
    } else {
        coinRestTime.text = @"";
    }
}

#pragma mark - Buy cube

/** @ghidraAddress 0x86d30 */
- (void)tapBuyCube:(id)sender {
    if ([self.aDelegate respondsToSelector:@selector(cubePurchaseStart:)]) {
        [self.aDelegate performSelector:@selector(cubePurchaseStart:) withObject:self];
    }
}

/** @ghidraAddress 0x86de4 */
- (void)alertSelect:(NSDictionary *)info {
    if ([info[@"btnMessage"] intValue] == kStatusConfirmOKButton) {
        if ([self.aDelegate respondsToSelector:@selector(cubePurchaseStart:)]) {
            [self.aDelegate performSelector:@selector(cubePurchaseStart:) withObject:self];
        }
    }
}

@end
