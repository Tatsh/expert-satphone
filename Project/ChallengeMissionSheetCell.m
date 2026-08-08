#import "ChallengeMissionSheetCell.h"

#import "ChallengeMissionAchieve.h"
#import "ChallengeMissionTerms.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The cell's delegate: told when the row is tapped or long-pressed, and when the stamp animation
// finishes. Every callback is optional and reached through -respondsToSelector:/-performSelector:,
// so the protocol is forward-declared here rather than imported; its owner is not yet
// reconstructed.
@protocol ChallengeMissionSheetCellDelegate <NSObject>
@optional
- (void)tapStampCell:(nullable ChallengeMissionSheetCell *)cell;
- (void)pressStampCell:(nullable ChallengeMissionSheetCell *)cell;
- (void)stampAnimationEnd:(nullable ChallengeMissionSheetCell *)cell;
@end

// The row's content sits five points in from every edge, so each subview is that much smaller than
// the cell in both dimensions.
static const CGFloat kContentOrigin = 5.0;
static const CGFloat kContentInset = 10.0;

// The idle icon behind the ring, and the muted disabled ring, are drawn part-transparent.
static const CGFloat kIconAlpha = 0.3;
static const CGFloat kDisabledChartAlpha = 0.4;

// The ring's stroke widths differ by idiom; its borders, shadow, and disabled base are fixed.
static const float kRingLineWidthPad = 15.0f;
static const float kRingLineWidthPhone = 8.0f;
static const float kRingBorderInside = 0.0f;
static const float kRingBorderOutside = 0.5f;
static const CGFloat kRingShadowRadius = 3.0;
static const CGFloat kRingShadowOffset = 3.0;
static const float kRingShadowOpacity = 0.5f;

// The rate is drawn as up to three digit images plus a trailing per-cent glyph.
static const NSInteger kRateDigitCount = 10;
static const NSUInteger kRateHundredsSlot = 0;
static const NSUInteger kRateTensSlot = 1;
static const NSUInteger kRateUnitsSlot = 2;

// The achievement rate is a fraction; it is shown as a whole percentage capped at 100.
static const float kPercentScale = 100.0f;
static const int kPercentMax = 100;
static const int kRateBase = 10;

// A mission's condition kind. Fewer than this many kinds are known; the counting rules below are
// keyed to the kind's bit.
static const unsigned int kMissionTypeCount = 7;
// Kinds 1, 2, and 6 (bits 1, 2, 6): the progress count is the detail collection's element count.
static const unsigned int kCountByLengthTypes = 0x46;
// Kinds 3, 4, and 5 (bits 3, 4, 5): the mission target is the first detail element's integer.
static const unsigned int kMissionCntFirstElementTypes = 0x38;
// Kinds 4 and 5 (bits 4, 5): the achievement is the value under the "0" key.
static const unsigned int kAchieveCntKeyZeroTypes = 0x30;
// Kind 3: the achievement is the sum of every value in the detail dictionary.
static const unsigned int kAchieveCntSumType = 3;

// The stamp fades in over this long; the completion mark over slightly longer.
static const NSTimeInterval kStampFadeDuration = 0.2;
static const NSTimeInterval kCompleteFadeDuration = 0.4;

// The chart's percentage above which a mission is treated as complete, and the raw fill of a
// complete ring.
static const int kCompleteMissionState = 2;
static const float kFullPercent = 1.0f;

// The mission's per-state opacity: hidden until earned, then shown.
static const CGFloat kStampHidden = 0.0;
static const CGFloat kStampShown = 1.0;

// The completion and skip stamps, and the undecided-mission lock.
static NSString *const kRateFormat = @"cm_rate_%d";
static NSString *const kPerImageName = @"cm_rate_per";
static NSString *const kCompleteImageName = @"cm_rate_comp";
static NSString *const kSkipImageName = @"cm_rate_skip";
static NSString *const kLockImageName = @"cm_icon_lock";

// The mission-type icons, indexed by (missionType - 1) clamped to zero.
static NSString *const kMissionIconNames[] = {
    @"cm_icon_play",
    @"cm_icon_rank",
    @"cm_icon_panel",
    @"cm_icon_rival",
    @"cm_icon_store",
    @"cm_icon_drop",
    @"cm_icon_badge",
};

@implementation ChallengeMissionSheetCell {
    ChallengeMissionTerms *dispTerm;
    ChallengeMissionAchieve *dispAchieve;
    BOOL detailEnable;
    UIButton *detailBtn;
    BOOL missionEnable;
    UIImageView *completeImage;
    UIImageView *iconImageView;
    UIView *cellView;
    UIView *stampView;
    UILabel *titleText;
    UILabel *endText;
    BOOL bMove;
    PieChartView *chartView;
    UIView *rateView;
    NSMutableArray *rateImage;
    UIImageView *rateImageView[3];
    UIImageView *perImageView;
    int missionCnt;
    int achieveCnt;
    float achieveRate;
}

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0x84144 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }
    self.backgroundColor = UIColor.clearColor;

    CGFloat contentWidth = frame.size.width - kContentInset;
    CGFloat contentHeight = frame.size.height - kContentInset;

    cellView = [[UIView alloc]
        initWithFrame:CGRectMake(kContentOrigin, kContentOrigin, contentWidth, contentHeight)];
    cellView.backgroundColor = UIColor.clearColor;
    [self addSubview:cellView];
    bMove = NO;

    chartView = [[PieChartView alloc]
        initWithFrame:CGRectMake(kContentOrigin, kContentOrigin, contentWidth, contentHeight)];
    chartView.aDelegate = self;
    UIColor *baseColor = [UIColor colorWithRed:0.9098039269447327
                                         green:0.9686274528503418
                                          blue:0.7607843279838562
                                         alpha:1.0];
    UIColor *chartColor = [UIColor colorWithRed:0.6980392336845398
                                          green:0.9019607901573181
                                           blue:0.21176470816135406
                                          alpha:1.0];
    UIColor *borderColor = [UIColor colorWithRed:0.06666667014360428
                                           green:0.19607843458652496
                                            blue:0.062745101749897
                                           alpha:1.0];
    [chartView setChartColor:chartColor baseColor:baseColor borderColor:borderColor];
    // The original spelled this out as colorWithWhite:1.0 alpha:1.0.
    [chartView setBgColor:UIColor.whiteColor];
    float ringLineWidth =
        [JubeatAppDelegate.appDelegate isPad] ? kRingLineWidthPad : kRingLineWidthPhone;
    (void)[JubeatAppDelegate.appDelegate isPad]; // Yes, the binary reads isPad a second time here
                                                 // and discards it.
    [chartView setLineWidth:ringLineWidth
               borderInside:kRingBorderInside
              borderOutsize:kRingBorderOutside];
    chartView.layer.shadowRadius = kRingShadowRadius;
    chartView.layer.shadowOffset = CGSizeMake(kRingShadowOffset, kRingShadowOffset);
    chartView.layer.shadowOpacity = kRingShadowOpacity;
    [self addSubview:chartView];

    iconImageView =
        [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, contentWidth, contentHeight)];
    iconImageView.alpha = kIconAlpha;
    [chartView addSubview:iconImageView];

    detailBtn = [[UIButton alloc]
        initWithFrame:CGRectMake(kContentOrigin, kContentOrigin, contentWidth, contentHeight)];
    detailBtn.exclusiveTouch = YES;
    detailBtn.backgroundColor = UIColor.clearColor;
    [detailBtn addTarget:self
                  action:@selector(tapDetail)
        forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:detailBtn];
    UILongPressGestureRecognizer *press =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(longPressBtnMode)];
    [detailBtn addGestureRecognizer:press];

    rateImage = [[NSMutableArray alloc] init];
    UIImage *lastDigit = nil;
    for (int digit = 0; digit < kRateDigitCount; ++digit) {
        lastDigit = LoadScaledPngImage([NSString stringWithFormat:kRateFormat, digit]);
        [rateImage addObject:lastDigit];
    }

    int digitWidth = (int)lastDigit.size.width;
    int digitHeight = (int)lastDigit.size.height;
    // The three digit slots sit left-to-right, each one digit wide; the per-cent glyph follows.
    rateImageView[kRateHundredsSlot] =
        [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, digitWidth, digitHeight)];
    rateImageView[kRateTensSlot] =
        [[UIImageView alloc] initWithFrame:CGRectMake(digitWidth, 0, digitWidth, digitHeight)];
    rateImageView[kRateUnitsSlot] =
        [[UIImageView alloc] initWithFrame:CGRectMake(digitWidth * 2, 0, digitWidth, digitHeight)];

    // The rate group is centred vertically and pushed left of centre by two digit widths.
    int rateViewX = (int)(contentWidth * 0.5 - (double)(digitWidth * 2));
    int rateViewY = (int)((contentHeight - (double)digitHeight) * 0.5);

    UIImage *perImage = LoadScaledPngImage(kPerImageName);
    CGSize perSize = perImage.size;
    perImageView = [[UIImageView alloc]
        initWithFrame:CGRectMake(digitWidth * 3, 0, perSize.width, perSize.height)];
    perImageView.image = perImage;

    int rateViewWidth = (int)((double)(digitWidth * 3) + perSize.width);
    rateView =
        [[UIView alloc] initWithFrame:CGRectMake(rateViewX, rateViewY, rateViewWidth, digitHeight)];
    [chartView addSubview:rateView];
    [rateView addSubview:rateImageView[kRateHundredsSlot]];
    [rateView addSubview:rateImageView[kRateTensSlot]];
    [rateView addSubview:rateImageView[kRateUnitsSlot]];
    [rateView addSubview:perImageView];

    completeImage =
        [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, contentWidth, contentHeight)];
    completeImage.alpha = kStampHidden;
    [chartView addSubview:completeImage];

    missionEnable = NO;
    detailEnable = YES;
    return self;
}

#pragma mark - Rate display

/** @ghidraAddress 0x84ac4 */
- (void)setRateNumber {
    int percent = (int)(achieveRate * kPercentScale);
    if (percent > kPercentMax) {
        percent = kPercentMax;
    }

    // The group is nudged so the visible digits stay centred: one digit wide for a single digit,
    // half a digit for two, and not at all for three.
    UIImage *digitZero = rateImage[0];
    int offsetX;
    if (percent < kRateBase) {
        offsetX = (int)(0.0 - digitZero.size.width);
    } else if (percent >= kPercentMax) {
        offsetX = 0;
    } else {
        offsetX = (int)(digitZero.size.width * -0.5);
    }

    rateImageView[kRateUnitsSlot].image = rateImage[percent % kRateBase];
    if (percent >= kRateBase) {
        int tens = (percent / kRateBase) % kRateBase;
        if (percent >= kRateBase || tens > 0) {
            rateImageView[kRateTensSlot].image = rateImage[tens];
        }
        if (percent / kRateBase >= kRateBase) {
            int hundreds = (percent / (kRateBase * kRateBase)) % kRateBase;
            if (percent >= kPercentMax || hundreds > 0) {
                rateImageView[kRateHundredsSlot].image = rateImage[hundreds];
            }
        }
    }

    rateView.transform = CGAffineTransformMakeTranslation((CGFloat)offsetX, 0);
}

#pragma mark - Population

/** @ghidraAddress 0x84d78 */
- (float)setMissionInfo:(ChallengeMissionTerms *)terms achieve:(ChallengeMissionAchieve *)achieve {
    dispTerm = terms;
    dispAchieve = achieve;
    titleText.text = terms.missionTitle;

    int iconIndex = (int)terms.missionType - 1;
    if (iconIndex < 0) {
        iconIndex = 0;
    }
    iconImageView.image = LoadScaledPngImage(kMissionIconNames[iconIndex]);

    UIImage *stampImage = LoadScaledPngImage(kCompleteImageName);
    if (achieve.missionState == 4 || achieve.missionState == 0) {
        stampImage = LoadScaledPngImage(kSkipImageName);
    }
    completeImage.image = stampImage;

    if (dispAchieve.missionState == 0) {
        completeImage.alpha = kStampHidden;
    } else if (dispAchieve.missionState == 1) {
        completeImage.alpha = kStampHidden;
    } else {
        completeImage.alpha = kStampShown;
        rateView.alpha = kStampHidden;
        [chartView setPercent:kFullPercent];
    }

    missionCnt = 0;
    achieveCnt = 0;

    if (terms.missionDetail != nil) {
        missionCnt = 0;
        unsigned int type = terms.missionType;
        if (type < kMissionTypeCount) {
            unsigned int bit = 1u << type;
            if ((bit & kCountByLengthTypes) == 0) {
                if ((bit & kMissionCntFirstElementTypes) != 0) {
                    missionCnt = [terms.missionDetail[0] intValue];
                }
            } else {
                missionCnt = (int)terms.missionDetail.count;
            }
        }
    }

    if (achieve.achieveDetail != nil) {
        achieveCnt = 0;
        unsigned int type = terms.missionType;
        if (type < kMissionTypeCount) {
            unsigned int bit = 1u << type;
            if ((bit & kCountByLengthTypes) == 0) {
                if ((bit & kAchieveCntKeyZeroTypes) == 0) {
                    if (type == kAchieveCntSumType) {
                        for (id key in achieve.achieveDetail) {
                            achieveCnt += [achieve.achieveDetail[key] intValue];
                        }
                    }
                } else {
                    achieveCnt = [achieve.achieveDetail[@"0"] intValue];
                }
            } else {
                achieveCnt = (int)achieve.achieveDetail.count;
            }
        }
    }

    achieveRate = 0;
    if (missionCnt > 0) {
        achieveRate = (float)achieveCnt / (float)missionCnt;
    }
    [self setRateNumber];
    missionEnable = YES;
    return achieveRate;
}

#pragma mark - State

/** @ghidraAddress 0x85378 */
- (void)setMarker:(BOOL)marker {
    // The shipped body does nothing.
}

/** @ghidraAddress 0x8537c */
- (void)disableCell {
    cellView.backgroundColor = UIColor.clearColor;
    missionEnable = NO;
    iconImageView.alpha = kStampHidden;
    rateView.alpha = kStampHidden;

    UIColor *baseColor = [UIColor colorWithRed:0.7843137383460999
                                         green:0.8901960849761963
                                          blue:0.6823529601097107
                                         alpha:1.0];
    UIColor *chartColor = [UIColor colorWithRed:0.6980392336845398
                                          green:0.9019607901573181
                                           blue:0.21176470816135406
                                          alpha:1.0];
    UIColor *borderColor = [UIColor colorWithRed:0.06666667014360428
                                           green:0.19607843458652496
                                            blue:0.062745101749897
                                           alpha:1.0];
    [chartView setChartColor:chartColor baseColor:baseColor borderColor:borderColor];
    [chartView setBgColor:[UIColor colorWithWhite:0.8999999761581421 alpha:1.0]];
    chartView.alpha = kDisabledChartAlpha;
}

// The binary's selector spelling ("undiceided") is kept verbatim.
/** @ghidraAddress 0x85580 */
- (void)undiceidedCell {
    missionEnable = NO;
    iconImageView.image = LoadScaledPngImage(kLockImageName);
    rateView.alpha = kStampHidden;
}

#pragma mark - Reveal

/** @ghidraAddress 0x855fc */
- (void)missionOpen {
    if (!missionEnable) {
        return;
    }
    if (!bMove) {
        bMove = YES;
        if (dispAchieve.missionState < kCompleteMissionState) {
            [chartView startNextPercent:achieveRate];
        } else {
            [chartView setPercent:kFullPercent];
        }
    }

    if (dispAchieve.missionState == 1) {
        __weak UIView *weakStampView = stampView;
        [UIView animateWithDuration:kStampFadeDuration
            delay:0
            options:UIViewAnimationOptionCurveLinear
            animations:^{
              /** @ghidraAddress 0x85854 */
              weakStampView.alpha = kStampShown;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x858a0 */
              if ([self.aDelegate respondsToSelector:@selector(stampAnimationEnd:)]) {
                  [self.aDelegate performSelector:@selector(stampAnimationEnd:) withObject:self];
              }
            }];
    } else {
        if ([self.aDelegate respondsToSelector:@selector(stampAnimationEnd:)]) {
            [self.aDelegate performSelector:@selector(stampAnimationEnd:) withObject:self];
        }
    }
}

/** @ghidraAddress 0x85968 */
- (void)stampAnimation {
    // The shipped body does nothing.
}

#pragma mark - Touch handling

/** @ghidraAddress 0x8596c */
- (void)tapDetail {
    if (missionEnable && detailEnable) {
        if ([self.aDelegate respondsToSelector:@selector(tapStampCell:)]) {
            [self.aDelegate performSelector:@selector(tapStampCell:) withObject:self];
        }
    }
}

/** @ghidraAddress 0x85a44 */
- (void)longPressBtnMode {
    if (missionEnable && detailEnable) {
        if ([self.aDelegate respondsToSelector:@selector(pressStampCell:)]) {
            [self.aDelegate performSelector:@selector(pressStampCell:) withObject:self];
        }
    }
}

/** @ghidraAddress 0x85b1c */
- (void)enableTouch:(BOOL)enable {
    detailEnable = enable;
}

#pragma mark - PieChartViewDelegate

/** @ghidraAddress 0x85b2c */
- (void)chartAnimationEnd {
    // The test truncates the float rate to an int, so any rate in [1.0, 2.0) counts as complete.
    if ((int)achieveRate == 1) {
        rateView.alpha = kStampHidden;
        __weak UIImageView *weakCompleteImage = completeImage;
        completeImage.alpha = kStampHidden;
        [UIView animateWithDuration:kCompleteFadeDuration
                              delay:0
                            options:UIViewAnimationOptionCurveLinear
                         animations:^{
                           /** @ghidraAddress 0x85c68 */
                           weakCompleteImage.alpha = kStampShown;
                         }
                         completion:^(BOOL finished){
                             // The original passes an empty global completion block here.
                         }];
    }
}

@end
