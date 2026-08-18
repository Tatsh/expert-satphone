#import "EvaluateJcfView.h"

#import <QuartzCore/QuartzCore.h>

#import "EditDataManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "StoreButton.h"
#import "jubeatLabAccess.h"

// The panel size, chosen by device idiom.
static const CGFloat kPanelWidthPad = 360.0;
static const CGFloat kPanelWidthPhone = 300.0;
static const CGFloat kPanelHeightPad = 400.0;
static const CGFloat kPanelHeightPhone = 360.0;

// The gradient-backed panel's layer styling.
static const CGFloat kPanelCornerRadius = 6.0;
static const CGFloat kPanelBorderWidth = 2.0;
static const CGFloat kPanelShadowRadius = 4.0;
static const float kPanelShadowOpacity = 0.5f;
// The panel gradient runs from the top, through a stop this many points down, to the bottom.
static const CGFloat kGradientMidLocationNumerator = 40.0; // @ghidraAddress 0x28f1f8
// The three greys of the panel gradient (top to bottom).
static const CGFloat kGradientWhiteTop = 0.961;    // @ghidraAddress 0x292420
static const CGFloat kGradientWhiteMiddle = 0.855; // @ghidraAddress 0x292428
static const CGFloat kGradientWhiteBottom = 0.762; // @ghidraAddress 0x292430

// The shared blue-green fill of the store-style buttons.
static const CGFloat kButtonFillGreen = 0.433; // @ghidraAddress 0x292440
static const CGFloat kButtonFillBlue = 0.617;  // @ghidraAddress 0x292448
static const CGFloat kStoreButtonCornerRadius = 3.0;
static const CGFloat kButtonTitleFontSize = 14.0;

// The cancel button, centred horizontally and anchored to the bottom of the panel.
static const CGFloat kCancelButtonHeight = 32.0;            // @ghidraAddress 0x28f458
static const CGFloat kCancelButtonHorizontalPadding = 24.0; // Added to the sized-to-fit width.
static const CGFloat kCancelButtonVerticalOffset = 24.0;    // First bottom subtraction.
static const CGFloat kCancelButtonBottomMargin = 16.0;      // Second bottom subtraction.

// The discarded good-job icon, laid out inside a strip this tall at this left inset.
static const CGFloat kGoodJobIconAreaHeight = 40.0;
static const CGFloat kGoodJobIconX = 16.0;

// The level-vote title label.
static const CGFloat kLevelTitleX = 20.0;
static const CGFloat kLevelTitleY = 60.0;
static const CGFloat kLevelTitleHeight = 20.0;
static const CGFloat kLevelTitleWidthPad = 250.0;   // @ghidraAddress 0x293da8
static const CGFloat kLevelTitleWidthPhone = 200.0; // @ghidraAddress 0x293da0

// The commit button, whose y is shared with the tick labels.
static const CGFloat kCommitRowY = 90.0;               // @ghidraAddress 0x28f440
static const CGFloat kLevelCommitButtonXPad = 290.0;   // @ghidraAddress 0x293db8
static const CGFloat kLevelCommitButtonXPhone = 240.0; // @ghidraAddress 0x293db0

// The ten numbered tick labels beneath the slider.
static const int kNumTickLabels = 10;
static const int kTickLabelXOffset = 20;
static const CGFloat kTickLabelWidth = 40.0;
static const CGFloat kTickLabelHeight = 20.0;
// The per-idiom left edges of each tick label, before the fixed offset is added.
static const int kPadTickPositions[] = {7, 33, 58, 82, 108, 132, 158, 184, 210, 230};
static const int kPhoneTickPositions[] = {7, 27, 46, 66, 86, 105, 125, 144, 163, 180};

// The level slider; its width matches the level-title label.
static const CGFloat kSliderX = 20.0;
static const CGFloat kSliderY = 110.0; // @ghidraAddress 0x28f5e8
static const CGFloat kSliderHeight = 20.0;
static const float kSliderMinLevel = 0.0f;
static const float kSliderMaxLevel = 9.0f; // Inline immediate 0x41100000.

// The alpha the good-job label fades to once its vote is sent.
static const CGFloat kGoodJobDimAlpha = 0.5;

// The value the slider snaps up to the next whole level past.
static const float kSliderRoundThreshold = 0.5f;

// The scaled-image asset names.
static NSString *const kGoodJobIconImageName = @"menu_icon_download";
static NSString *const kBackgroundImageName = @"upload_bg";
static NSString *const kLevelCommitImageName = @"btn_level_upload";

// The two title formats, from the UTF-16 CFStrings at 0x2e1e40 and 0x2e1e80.
static NSString *const kLevelVoteTitleFormat = @"LEVEL投票 : %d";
static NSString *const kLevelValueTitleFormat = @"自分的な難易度 : %d";
static NSString *const kTickLabelFormat = @"%d";

// The cancel-button title is looked up in the main bundle's default table.
static NSString *const kCancelButtonKey = @"Cancel";

// The jubeatLab response key and the editor-info flag it sets.
static NSString *const kStatusKey = @"status";
static NSString *const kGoodJobSendKey = @"goodJobSend";
// The status value that marks a successful jubeatLab response.
static const int kStatusOK = 0;

@implementation EvaluateJcfView {
    StoreButton *btnCancel;                      // +0x54
    UIButton *goodJobBtn;                        // +0x68
    UIImageView *goodJobLabel;                   // +0x6c
    UILabel *levelTitle;                         // +0x58
    UISlider *levelSlider;                       // +0x60
    UIButton *levelCommitBtn;                    // +0x5c
    NSString *seqID;                             // +0x48
    int sendLevel;                               // +0x4c
    int musicID;                                 // +0x50
    UILabel *textLabel;                          // (declared in the metadata, unused here)
    __weak id<EvaluateJcfViewDelegate> delegate; // +0x44
    BOOL isPad;                                  // +0x40
    jubeatLabAccess *goodJobCommit;              // +0x64
    jubeatLabAccess *levelCommit;                // +0x70
}

#pragma mark - Layer

/** @ghidraAddress 0x1fac5c */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

#pragma mark - Construction

/** @ghidraAddress 0x1fac70 */
- (void)createStoreBtn:(id)sender {
    // The button is built but neither stored nor added anywhere: the binary discards it.
    StoreButton *button = [[StoreButton alloc] initWithFrame:CGRectZero];
    // The original used the full component call; green and blue are non-standard components.
    button.buttonColor = [UIColor colorWithRed:0
                                         green:kButtonFillGreen
                                          blue:kButtonFillBlue
                                         alpha:1.0];
    button.cornerRadius = kStoreButtonCornerRadius;
    [button setExclusiveTouch:YES];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonTitleFontSize];
}

/** @ghidraAddress 0x1fada8 */
- (instancetype)initWithID:(NSString *)seqIDArg
              defaultLevel:(int)defaultLevel
                  delegate:(id)delegateArg
                    tuneID:(int)tuneID {
    isPad = JubeatAppDelegate.appDelegate.isPad;
    CGFloat panelWidth = isPad ? kPanelWidthPad : kPanelWidthPhone;
    CGFloat panelHeight = isPad ? kPanelHeightPad : kPanelHeightPhone;
    self = [super initWithFrame:CGRectMake(0, 0, panelWidth, panelHeight)];
    if (self) {
        delegate = delegateArg;
        seqID = seqIDArg;
        sendLevel = defaultLevel;
        musicID = tuneID;

        CAGradientLayer *gradient = (CAGradientLayer *)self.layer;
        gradient.cornerRadius = kPanelCornerRadius;
        gradient.borderWidth = kPanelBorderWidth;
        gradient.borderColor = UIColor.lightGrayColor.CGColor;
        gradient.locations = @[ @(0.0f), @(kGradientMidLocationNumerator / panelHeight), @(1.0f) ];
        gradient.colors = @[
            (__bridge id)[UIColor colorWithWhite:kGradientWhiteTop alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithWhite:kGradientWhiteMiddle alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithWhite:kGradientWhiteBottom alpha:1.0].CGColor
        ];
        // The light-grey border set above is immediately replaced with grey.
        gradient.borderColor = UIColor.grayColor.CGColor;
        gradient.shadowRadius = kPanelShadowRadius;
        gradient.shadowOffset = CGSizeZero;
        gradient.shadowOpacity = kPanelShadowOpacity;

        // The good-job icon is loaded and framed but never stored nor added: the binary discards
        // it.
        UIImageView *goodJobIcon =
            [[UIImageView alloc] initWithImage:LoadScaledPngImage(kGoodJobIconImageName)];
        CGFloat iconHeight = goodJobIcon.frame.size.height;
        CGFloat iconY = (CGFloat)((int)(kGoodJobIconAreaHeight - iconHeight) / 2 + 1);
        goodJobIcon.frame =
            CGRectMake(kGoodJobIconX, iconY, goodJobIcon.frame.size.width, iconHeight);
        (void)goodJobIcon; // Yes, the binary throws this view away.

        UIImageView *background =
            [[UIImageView alloc] initWithImage:LoadScaledPngImage(kBackgroundImageName)];
        CGSize backgroundSize = background.frame.size;
        background.frame = CGRectMake(panelWidth - backgroundSize.width,
                                      panelHeight - backgroundSize.height,
                                      backgroundSize.width,
                                      backgroundSize.height);
        [self addSubview:background];

        btnCancel = [[StoreButton alloc] initWithFrame:CGRectZero];
        // The original used the full component call; green and blue are non-standard components.
        btnCancel.buttonColor = [UIColor colorWithRed:0
                                                green:kButtonFillGreen
                                                 blue:kButtonFillBlue
                                                alpha:1.0];
        btnCancel.cornerRadius = kStoreButtonCornerRadius;
        [btnCancel setExclusiveTouch:YES];
        btnCancel.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonTitleFontSize];
        [btnCancel setTitle:[NSBundle.mainBundle localizedStringForKey:kCancelButtonKey
                                                                 value:@""
                                                                 table:nil]
                   forState:UIControlStateNormal];
        [btnCancel addTarget:self
                      action:@selector(pushCancel:)
            forControlEvents:UIControlEventTouchUpInside];
        [btnCancel sizeToFit];
        CGFloat cancelWidth = btnCancel.frame.size.width + kCancelButtonHorizontalPadding;
        CGFloat cancelX = panelWidth * 0.5 - cancelWidth * 0.5;
        CGFloat cancelY = panelHeight - kCancelButtonVerticalOffset - kCancelButtonBottomMargin;
        btnCancel.frame = CGRectMake(cancelX, cancelY, cancelWidth, kCancelButtonHeight);
        [self addSubview:btnCancel];

        CGFloat rowWidth = isPad ? kLevelTitleWidthPad : kLevelTitleWidthPhone;
        levelTitle = [[UILabel alloc]
            initWithFrame:CGRectMake(kLevelTitleX, kLevelTitleY, rowWidth, kLevelTitleHeight)];
        levelTitle.backgroundColor = UIColor.clearColor;
        levelTitle.text = [NSString stringWithFormat:kLevelVoteTitleFormat, defaultLevel + 1];
        [self addSubview:levelTitle];

        UIImage *commitImage = LoadScaledPngImage(kLevelCommitImageName);
        CGSize commitSize = commitImage.size;
        CGFloat commitX = isPad ? kLevelCommitButtonXPad : kLevelCommitButtonXPhone;
        levelCommitBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        levelCommitBtn.frame =
            CGRectMake(commitX, kCommitRowY, commitSize.width, commitSize.height);
        levelCommitBtn.backgroundColor = UIColor.clearColor;
        [levelCommitBtn setImage:commitImage forState:UIControlStateNormal];
        [levelCommitBtn setExclusiveTouch:YES];
        [self addSubview:levelCommitBtn];
        [levelCommitBtn addTarget:self
                           action:@selector(pushLevelCommit:)
                 forControlEvents:UIControlEventTouchUpInside];

        for (int i = 0; i < kNumTickLabels; ++i) {
            const int *tickPositions = isPad ? kPadTickPositions : kPhoneTickPositions;
            CGFloat tickX = (CGFloat)(tickPositions[i] + kTickLabelXOffset);
            UILabel *tick = [[UILabel alloc]
                initWithFrame:CGRectMake(tickX, kCommitRowY, kTickLabelWidth, kTickLabelHeight)];
            tick.text = [NSString stringWithFormat:kTickLabelFormat, i + 1];
            tick.backgroundColor = UIColor.clearColor;
            [self addSubview:tick];
        }

        levelSlider = [[UISlider alloc]
            initWithFrame:CGRectMake(kSliderX, kSliderY, rowWidth, kSliderHeight)];
        levelSlider.maximumValue = kSliderMaxLevel;
        levelSlider.minimumValue = kSliderMinLevel;
        levelSlider.value = (float)defaultLevel;
        [levelSlider addTarget:self
                        action:@selector(sliderChange:)
              forControlEvents:UIControlEventValueChanged];
        sendLevel = defaultLevel;
        [self addSubview:levelSlider];
    }
    return self;
}

#pragma mark - Button handlers

/** @ghidraAddress 0x1fba60 */
- (void)pushCancel:(id)sender {
    [self evaluateEnd];
}

/** @ghidraAddress 0x1fba6c */
- (void)pushGoodJob:(id)sender {
    goodJobCommit = [[jubeatLabAccess alloc] initGoodJobApi:self tuneID:musicID seqID:seqID];
    [goodJobCommit startAccess];
    // The good-job button and label are never wired up in the initialiser, so these are no-ops.
    [goodJobBtn setEnabled:NO];
    [goodJobLabel setAlpha:kGoodJobDimAlpha];
}

/** @ghidraAddress 0x1fbb20 */
- (void)pushLevelCommit:(id)sender {
    levelCommit = [[jubeatLabAccess alloc] initLevelApi:self
                                                 tuneID:musicID
                                                  seqID:seqID
                                                  level:sendLevel];
    if (levelCommit) {
        [levelCommit startAccess];
        [levelCommitBtn setEnabled:NO];
    }
}

#pragma mark - Slider

/** @ghidraAddress 0x1fbbd4 */
- (void)sliderChange:(UISlider *)sender {
    float value = sender.value;
    int rounded = (int)value;
    // Round half up to the next whole level.
    if (value > (float)((int)value) + kSliderRoundThreshold) {
        rounded += 1;
    }
    sender.value = (float)rounded;
    // Read back the clamped value the slider settled on.
    [self levelChange:(int)sender.value];
}

/** @ghidraAddress 0x1fbc90 */
- (void)levelChange:(int)level {
    sendLevel = level;
    if (levelSlider) {
        levelSlider.value = (float)level;
    }
    levelTitle.text = [NSString stringWithFormat:kLevelValueTitleFormat, level + 1];
}

#pragma mark - Closing

/** @ghidraAddress 0x1fbd34 */
- (void)evaluateEnd {
    if ([delegate respondsToSelector:@selector(closeEvaluate:)]) {
        // The binary passes the delegate itself as the selector's argument, not the view.
        [delegate performSelector:@selector(closeEvaluate:) withObject:delegate];
    }
}

#pragma mark - jubeatLabAccess callbacks

/** @ghidraAddress 0x1fbdd8 */
- (void)jubeatLabAccessError:(jubeatLabAccess *)access {
    if (goodJobCommit == access) {
        goodJobCommit = nil;
    } else if (levelCommit == access) {
        levelCommit = nil;
    }
}

/** @ghidraAddress 0x1fbe38 */
- (void)jubeatLabAccessFinished:(jubeatLabAccess *)access {
    if (access == nil) {
        return;
    }
    NSDictionary *json = access.getDataInJSON;
    if (json) {
        if ([json[kStatusKey] intValue] == kStatusOK && goodJobCommit == access) {
            [EditDataManager sharedManager].getEditorInfo[kGoodJobSendKey] = @(1);
        }
    }
    if (goodJobCommit == access) {
        EditDataManager *editData = [EditDataManager sharedManager];
        editData.getEditorInfo[kGoodJobSendKey] = @(1);
        NSString *path = [editData getLastEditFilePath:musicID];
        [editData saveJCF:path];
        goodJobCommit = nil;
    } else if (levelCommit == access) {
        levelCommit = nil;
    }
    [self evaluateEnd];
}

@end
