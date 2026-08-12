#import "MissionDetailMessageView.h"

#import "AlertViewManager.h"
#import "ChallengeStatus.h"
#import "DetailTextView.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The three pieces of artwork.
static NSString *const kBackgroundImageName = @"cm_detail_bg";
static NSString *const kCloseButtonImageName = @"scratch_btn_cancel";
static NSString *const kPassButtonImageName = @"cm_btn_skip";

// The fade advances the alpha by this magnitude each tick, negated when fading out. Stored as a
// two-element single-precision table at 0x2923d8 ({0.2, -0.2}).
static const float kFadeStep = 0.2f;
// The fade timer fires at this interval. Held as a double widened from 0.03f at 0x2923d0.
static const NSTimeInterval kFadeInterval = 0.029999999329447746;

// The pass button is shown only when the mission has a skip cost and has not been achieved.
static NSString *const kMissionAchieveFormat = @"[%d/%d]"; // 0x28fb60 -> "[%d/%d]"

// Play-term detail formats and section headers.
static NSString *const kMusicNameEntryFormat = @"%@\n";                               // 0x2db880
static NSString *const kMusicSectionFormat = @"現在のシートで達成している楽曲\n%@\n"; // 0x2db8a0
static NSString *const kLevelSectionFormat = @"達成済みレベル\n%@\n";                 // 0x2db8c0
static NSString *const kMarkerSectionFormat = @"達成済みマーカー\n%@\n";              // 0x2db8e0
static NSString *const kLevelEntryFormat = @"%@レベル %d";                            // 0x2db920
static NSString *const kMarkerEntryFormat = @"%@マーカー %d";                         // 0x2db940
static NSString *const kHistorySectionFormat = @"%@\n%@\n";                           // 0x2db980
static NSString *const kHistoryHeader = @"現在のシートで達成している情報";            // 0x2db960
static NSString *const kFieldSeparator = @"/";                                        // 0x2db900
static NSString *const kPieceFormat = @"%@";                                          // 0x2d4360
static NSString *const kPieceAppendFormat = @"%@%@";                                  // 0x2d5c60
static NSString *const kNewline = @"\n";                                              // 0x2d5940

// The skip-purchase confirmation and the "buy jCube" prompt.
static NSString *const kSkipConfirmFormat =
    @"jCubeを%d個使用してこのミッションを達成済みにします。";                 // 0x2db9a0
static NSString *const kBuyCubePrompt = @"jCubeが足りません、購入しますか？"; // 0x2db9c0

// Localisation keys.
static NSString *const kLocalizationCancel = @"Cancel";
static NSString *const kLocalizationOK = @"OK";
static NSString *const kLocalizationServerError = @"ServerErrorMsg";

// Line-up dictionary keys.
static NSString *const kLineupKeyMusicID = @"music_id";
static NSString *const kLineupKeyName = @"name";

// Achievement-detail dictionary key for the count of a completed condition.
static NSString *const kAchieveCountKey = @"0";

// Alert-result dictionary keys echoed back to -alertSelect:.
static NSString *const kAlertKeyButton = @"btnMessage";
static NSString *const kAlertKeyTag = @"Tag";

// The three difficulty names, indexed by the play-history difficulty column. Held as a pointer
// array at 0x353a60 ({BASIC, ADVANCED, EXTREME}).
static NSString *const kDifficultyBasic = @"BASIC";
static NSString *const kDifficultyAdvanced = @"ADVANCED";
static NSString *const kDifficultyExtreme = @"EXTREME";

// The play-history columns that carry a displayable value; the remaining columns are skipped.
enum {
    kHistoryColumnMusic = 0,
    kHistoryColumnDifficulty = 2,
    kHistoryColumnLevel = 3,
    kHistoryColumnMarker = 5,
    kHistoryColumnCount = 7,
};

// The value a play-history cell carries when its condition is unset.
static const int kHistoryUnset = -1;

// The alert tags routed by -alertSelect:, and the button index for a positive response.
enum {
    kAlertTagBuyCube = 2,
    kAlertTagSkip = 1,
    kAlertPositiveButton = 1,
};

// The mission types whose achievement count is read differently.
enum {
    kMissionTypeCountFirstElement = 3,
    kMissionTypeCountKeyedFirst = 4,
    kMissionTypeCountKeyedFive = 5,
};

// Which direction the fade timer is driving the alpha.
typedef enum {
    MissionDetailFadeTypeIn = 0,   // Fading the overlay in.
    MissionDetailFadeTypeOut = 1,  // Fading the overlay out.
    MissionDetailFadeTypeIdle = 2, // No fade in progress.
} MissionDetailFadeType;

// The title label is inset this many points on each side (2 * 74).
static const CGFloat kTitleFixedX = 74.0;       // 0x28f6f8 -> 74.0
static const CGFloat kBackgroundYOffset = 40.0; // 0x28f1f8 -> 40.0
static const CGFloat kPadMissionTextY = 72.0;   // 0x291e40 -> 72.0
static const CGFloat kPhoneMissionTextY = 32.0; // 0x28f458 -> 32.0

@implementation MissionDetailMessageView {
    UIImageView *bgView;
    UILabel *missionTitle;
    UILabel *missionText;
    UILabel *missionAchieve;
    DetailTextView *detailText;
    BOOL bDispDetail;
    NSTimer *fadeTimer;
    NSArray *lineup;
    UIButton *closeBtn;
    UIButton *passBtn;
    UIButton *switchBtn;
    int fadeType;
    int skipCost;
    int missionID;
    int missionSheetID; // Present in the metadata; not touched by any reconstructed method.
    int achieveID;
    __weak UIView *parentView;
}

#pragma mark - Initialisation

/** @ghidraAddress 0xea078 */
- (instancetype)initWithFrame:(CGRect)frame coverFrame:(CGRect)coverFrame {
    // The name notwithstanding, only coverFrame reaches the superclass; frame is ignored.
    return [super initWithFrame:coverFrame];
}

/** @ghidraAddress 0xea0c0 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
        bDispDetail = NO;
        self.backgroundColor = UIColor.clearColor;
        self.alpha = 0.0;
        lineup = ChallengeStatus.sharedStatus.scratchLineUp;

        int frameWidth = (int)frame.size.width;
        int frameHeight = (int)frame.size.height;

        // Per idiom (pad first, phone second). The fmov immediates are not pool loads.
        CGFloat titleMargin = isPad ? 14.0 : 6.0;    // fmov immediate at 0xea3a0 (as int 14/6)
        CGFloat titleHeight = isPad ? 40.0 : 20.0;   // int 0x28/0x14 at 0xea3ac
        CGFloat titleFontSize = isPad ? 20.0 : 10.0; // fmov immediate at 0xea3b8
        CGFloat closeButtonX = isPad ? 16.0 : 8.0;   // fmov immediate at 0xea3c4
        int margin = isPad ? 24 : 12;                // int 0x18/0xc at 0xea3d4
        int achieveYOffset = isPad ? -46 : -23;      // int at 0xea3e0
        CGFloat achieveHeight = isPad ? 30.0 : 15.0; // fmov immediate at 0xea3f0
        CGFloat bodyFontSize = isPad ? 18.0 : 12.0;  // fmov immediate at 0xea3fc
        int passBottomInset = isPad ? 4 : 3;         // int at 0xea408
        CGFloat passButtonX = isPad ? 10.0 : 5.0;    // fmov immediate at 0xea40c
        int textHeightOffset = isPad ? -120 : -55;   // int at 0xea41c
        CGFloat missionTextY = isPad ? kPadMissionTextY : kPhoneMissionTextY; // 0x291e40 / 0x28f458
        CGFloat detailFontSize = isPad ? 16.0 : 10.0; // fmov immediate at 0xea440

        // The panel is sized from the background artwork and centred horizontally within the frame.
        UIImage *background = LoadScaledPngImage(kBackgroundImageName);
        CGFloat backgroundX = ((CGFloat)frameWidth - background.size.width) * 0.5;
        CGFloat backgroundY =
            (CGFloat)(frameHeight / 2) - background.size.height + kBackgroundYOffset;
        bgView = [[UIImageView alloc] initWithFrame:CGRectMake(backgroundX,
                                                               backgroundY,
                                                               background.size.width,
                                                               background.size.height)];
        [bgView setImage:background];
        bgView.userInteractionEnabled = YES;
        [self addSubview:bgView];

        int panelWidth = (int)background.size.width;
        int panelHeight = (int)background.size.height;

        // Title: centred, inset kTitleFixedX on each side.
        missionTitle = [[UILabel alloc] initWithFrame:CGRectMake(kTitleFixedX,
                                                                 titleMargin,
                                                                 panelWidth - kTitleFixedX * 2,
                                                                 titleHeight)];
        missionTitle.textAlignment = NSTextAlignmentCenter;
        missionTitle.font = [UIFont boldSystemFontOfSize:titleFontSize];
        missionTitle.backgroundColor = UIColor.clearColor;
        [bgView addSubview:missionTitle];

        // Close button: vertically centred on the title row.
        UIImage *closeImage = LoadScaledPngImage(kCloseButtonImageName);
        CGFloat closeButtonY =
            (CGFloat)(int)(titleMargin + titleHeight / 2 - closeImage.size.height * 0.5);
        closeBtn = [[UIButton alloc] initWithFrame:CGRectMake(closeButtonX,
                                                              closeButtonY,
                                                              closeImage.size.width,
                                                              closeImage.size.height)];
        [closeBtn setBackgroundImage:closeImage forState:UIControlStateNormal];
        [closeBtn addTarget:self
                      action:@selector(tapCloseBtn)
            forControlEvents:UIControlEventTouchUpInside];
        closeBtn.exclusiveTouch = YES;
        [bgView addSubview:closeBtn];

        // Achievement label: the right third of the body area, near the bottom of the panel.
        int bodyWidth = panelWidth - margin * 2;
        missionAchieve = [[UILabel alloc] initWithFrame:CGRectMake((bodyWidth * 2) / 3 + margin,
                                                                   panelHeight + achieveYOffset,
                                                                   bodyWidth / 3,
                                                                   achieveHeight)];
        missionAchieve.textAlignment = NSTextAlignmentRight;
        missionAchieve.backgroundColor = UIColor.clearColor;
        missionAchieve.font = [UIFont systemFontOfSize:bodyFontSize];
        [bgView addSubview:missionAchieve];

        // Pass button: bottom-left, sized from its artwork.
        UIImage *passImage = LoadScaledPngImage(kPassButtonImageName);
        passBtn =
            [[UIButton alloc] initWithFrame:CGRectMake(passButtonX,
                                                       (CGFloat)(panelHeight - passBottomInset) -
                                                           passImage.size.height,
                                                       passImage.size.width,
                                                       passImage.size.height)];
        [passBtn setBackgroundImage:passImage forState:UIControlStateNormal];
        [passBtn addTarget:self
                      action:@selector(tapPassBtn)
            forControlEvents:UIControlEventTouchUpInside];
        passBtn.exclusiveTouch = YES;
        [bgView addSubview:passBtn];

        // Body text: fills the width between the margins, from missionTextY to just above the
        // button row.
        missionText = [[UILabel alloc]
            initWithFrame:CGRectMake(
                              margin, missionTextY, bodyWidth, panelHeight + textHeightOffset)];
        missionText.textAlignment = NSTextAlignmentCenter;
        missionText.numberOfLines = 0;
        missionText.backgroundColor = UIColor.clearColor;
        missionText.font = [UIFont systemFontOfSize:bodyFontSize];
        [bgView addSubview:missionText];

        // The detail text view shares the body text's frame and starts hidden.
        detailText = [[DetailTextView alloc] initWithFrame:missionText.frame];
        detailText.opaque = NO;
        detailText.bounces = NO;
        detailText.backgroundColor = UIColor.clearColor;
        detailText.editable = NO;
        detailText.scrollEnabled = YES;
        detailText.alpha = 0.0;
        detailText.textAlignment = NSTextAlignmentLeft;
        detailText.font = [UIFont systemFontOfSize:detailFontSize];
        [bgView addSubview:detailText];

        // Disable any long-press recognisers the text view installed so it takes no selection.
        for (UIGestureRecognizer *recognizer in detailText.gestureRecognizers) {
            if ([recognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
                recognizer.enabled = NO;
            }
        }

        // The switch button is an invisible control overlaying the achievement label.
        switchBtn = [[UIButton alloc] initWithFrame:missionAchieve.frame];
        switchBtn.exclusiveTouch = YES;
        [switchBtn addTarget:self
                      action:@selector(tapSwitch)
            forControlEvents:UIControlEventTouchUpInside];
        [bgView addSubview:switchBtn];

        fadeType = MissionDetailFadeTypeIdle;
    }
    return self;
}

#pragma mark - Population

/** @ghidraAddress 0xeacc0 */
- (void)setMission:(ChallengeMissionTerms *)mission achieve:(ChallengeMissionAchieve *)achieve {
    missionTitle.text = mission.missionTitle;
    missionText.text = mission.missionExplain;
    missionID = mission.missionID;
    achieveID = achieve.achievementID;

    // The counts default the denominator (total) and numerator (achieved); the 3/4/5 mission types
    // override both from the mission's first condition and the achievement detail. The count calls
    // are made unconditionally, so they run even for the overriding types.
    int total = (int)mission.missionDetail.count;
    int achieved = (int)achieve.achieveDetail.count;
    switch (mission.missionType) {
    case kMissionTypeCountKeyedFive:
    case kMissionTypeCountKeyedFirst:
        total = [mission.missionDetail[0] intValue];
        achieved = [achieve.achieveDetail[kAchieveCountKey] intValue];
        break;
    case kMissionTypeCountFirstElement:
        total = [mission.missionDetail[0] intValue];
        achieved = 0;
        for (id key in achieve.achieveDetail) {
            achieved += [achieve.achieveDetail[key] intValue];
        }
        break;
    default:
        break;
    }

    // The displayed numerator is clamped to the denominator.
    int shown = achieved > total ? total : achieved;
    missionAchieve.text = [NSString stringWithFormat:kMissionAchieveFormat, shown, total];

    skipCost = mission.skipCost;
    (void)JubeatAppDelegate.appDelegate.isPad; // Yes, the binary discards this call's result.
    if (skipCost == 0 || achieve.missionState != 0) {
        passBtn.hidden = YES;
    } else {
        passBtn.hidden = NO;
        [passBtn setTitle:nil forState:UIControlStateNormal];
    }
}

/** @ghidraAddress 0xeb274 */
- (NSString *)getMusicName:(int)musicID {
    for (NSDictionary *entry in lineup) {
        if ([entry[kLineupKeyMusicID] intValue] == musicID) {
            return entry[kLineupKeyName];
        }
    }
    return nil;
}

/** @ghidraAddress 0xeb40c */
- (void)setPlayTerm:(ChallengeMissionPlayTerm *)playTerm {
    switchBtn.enabled = NO;
    if (playTerm) {
        NSString *detail = @"";

        // The tunes already achieved on the current sheet.
        if (playTerm.musicNGID.count != 0) {
            NSString *names = @"";
            for (NSUInteger i = 0; i < playTerm.musicNGID.count; ++i) {
                NSString *name = [self getMusicName:[playTerm.musicNGID[i] intValue]];
                if (name) {
                    names = [names stringByAppendingFormat:kMusicNameEntryFormat, name];
                }
            }
            if (![names isEqualToString:@""]) {
                detail = [NSString stringWithFormat:kMusicSectionFormat, names];
            }
        }

        // Achieved levels.
        if (playTerm.levelNG.count != 0) {
            NSString *levels = @"";
            for (NSUInteger i = 0; i < playTerm.levelNG.count; ++i) {
                levels =
                    [levels stringByAppendingFormat:kMusicNameEntryFormat, playTerm.levelNG[i]];
            }
            if (![levels isEqualToString:@""]) {
                detail = [detail stringByAppendingFormat:kLevelSectionFormat, levels];
            }
        }

        // Achieved markers.
        if (playTerm.markerNG.count != 0) {
            NSString *markers = @"";
            for (NSUInteger i = 0; i < playTerm.markerNG.count; ++i) {
                markers =
                    [markers stringByAppendingFormat:kMusicNameEntryFormat, playTerm.markerNG[i]];
            }
            if (![markers isEqualToString:@""]) {
                detail = [detail stringByAppendingFormat:kMarkerSectionFormat, markers];
            }
        }

        // Per-play conditions, one row per history entry. Each row lists the music, difficulty,
        // level, and marker columns that are not marked duplicate and carry a value.
        if (playTerm.playHistory.count != 0) {
            NSArray *difficulties = @[ kDifficultyBasic, kDifficultyAdvanced, kDifficultyExtreme ];
            NSString *content = @"";
            for (NSUInteger row = 0; row < playTerm.playHistory.count; ++row) {
                for (int column = 0; column < kHistoryColumnCount; ++column) {
                    NSString *piece = nil;
                    switch (column) {
                    case kHistoryColumnMusic:
                        if (![playTerm.historyDup[column] boolValue]) {
                            int musicID = [playTerm.playHistory[row][column] intValue];
                            NSString *name = [self getMusicName:musicID];
                            if (name) {
                                piece = [NSString stringWithFormat:kPieceFormat, name];
                            }
                        }
                        break;
                    case kHistoryColumnDifficulty:
                        if (![playTerm.historyDup[column] boolValue]) {
                            int value = [playTerm.playHistory[row][column] intValue];
                            if (value != kHistoryUnset) {
                                NSString *separator =
                                    [content isEqualToString:@""] ? @"" : kFieldSeparator;
                                piece = [NSString stringWithFormat:kPieceAppendFormat,
                                                                   separator,
                                                                   difficulties[value]];
                            }
                        }
                        break;
                    case kHistoryColumnLevel:
                        if (![playTerm.historyDup[column] boolValue]) {
                            int value = [playTerm.playHistory[row][column] intValue];
                            if (value != kHistoryUnset) {
                                NSString *separator =
                                    [content isEqualToString:@""] ? @"" : kFieldSeparator;
                                piece =
                                    [NSString stringWithFormat:kLevelEntryFormat, separator, value];
                            }
                        }
                        break;
                    case kHistoryColumnMarker:
                        if (![playTerm.historyDup[column] boolValue]) {
                            int value = [playTerm.playHistory[row][column] intValue];
                            if (value != kHistoryUnset) {
                                NSString *separator =
                                    [content isEqualToString:@""] ? @"" : kFieldSeparator;
                                piece = [NSString
                                    stringWithFormat:kMarkerEntryFormat, separator, value];
                            }
                        }
                        break;
                    default:
                        break;
                    }
                    if (piece) {
                        content = [content stringByAppendingFormat:kPieceFormat, piece];
                    }
                }
                if (![content isEqualToString:@""]) {
                    content = [content stringByAppendingFormat:kNewline];
                }
            }
            if (![content isEqualToString:@""]) {
                detail =
                    [detail stringByAppendingFormat:kHistorySectionFormat, kHistoryHeader, content];
            }
        }

        if (![detail isEqualToString:@""]) {
            detailText.text = detail;
            switchBtn.enabled = YES;
        }
    }

    // The detail view starts hidden behind the body text.
    detailText.alpha = 0.0;
    missionText.alpha = 1.0;
}

#pragma mark - Skip purchase

/** @ghidraAddress 0xec214 */
- (void)tapPassBtn {
    NSString *cancel = [NSBundle.mainBundle localizedStringForKey:kLocalizationCancel
                                                            value:@""
                                                            table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocalizationOK value:@"" table:nil];
    NSArray *others = @[ ok ];
    if (ChallengeStatus.sharedStatus.jCubeNum < skipCost) {
        // Not enough jCube: offer to buy some.
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:self
                                              tag:kAlertTagBuyCube
                                            title:@""
                                              msg:kBuyCubePrompt
                                           cancel:cancel
                                          btnText:others
                                             show:YES];
    } else {
        // Confirm spending jCube on the skip.
        NSString *message = [NSString stringWithFormat:kSkipConfirmFormat, skipCost];
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:self
                                              tag:kAlertTagSkip
                                            title:@""
                                              msg:message
                                           cancel:cancel
                                          btnText:others
                                             show:YES];
    }
}

/** @ghidraAddress 0xec880 */
- (void)alertSelect:(NSDictionary *)info {
    int button = [info[kAlertKeyButton] intValue];
    int tag = [info[kAlertKeyTag] intValue];
    if (button != kAlertPositiveButton) {
        return;
    }
    if (tag == kAlertTagBuyCube) {
        if ([self.aDelegate respondsToSelector:@selector(cubePurchase)]) {
            [self.aDelegate performSelector:@selector(cubePurchase)];
        }
    } else if (tag == kAlertTagSkip) {
        if ([self.aDelegate respondsToSelector:@selector(missionSkip)]) {
            [self.aDelegate performSelector:@selector(missionSkip)];
        }
    }
}

#pragma mark - Downloader delegate

/** @ghidraAddress 0xeca48 */
- (void)downloaderError:(id)downloader {
    [UIApplication.sharedApplication endIgnoringInteractionEvents];
    NSString *message = [NSBundle.mainBundle localizedStringForKey:kLocalizationServerError
                                                             value:@""
                                                             table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocalizationOK value:@"" table:nil];
    [AlertViewManager.sharedManager makeAlert:0
                                     delegate:self
                                          tag:0
                                        title:@""
                                          msg:message
                                       cancel:ok
                                      btnText:nil
                                         show:YES];
}

/** @ghidraAddress 0xecbc4 */
- (void)downloaderFinished:(id)downloader {
    // Empty in the binary.
}

#pragma mark - Buttons

/** @ghidraAddress 0xecbc8 */
- (void)tapSwitch {
    BOOL wasShowing = bDispDetail;
    bDispDetail = !bDispDetail;
    CGFloat detailAlpha = wasShowing ? 0.0 : 1.0;
    detailText.alpha = detailAlpha;
    missionText.alpha = 1.0 - detailAlpha;
}

/** @ghidraAddress 0xecc48 */
- (void)tapCloseBtn {
    if ([self.aDelegate respondsToSelector:@selector(closeDetail)]) {
        [self.aDelegate performSelector:@selector(closeDetail)];
    }
}

#pragma mark - Fade

/** @ghidraAddress 0xec578 */
- (void)fadeIn:(UIView *)parent {
    fadeType = MissionDetailFadeTypeIn;
    if (fadeTimer) {
        return;
    }
    fadeTimer = [NSTimer scheduledTimerWithTimeInterval:kFadeInterval
                                                 target:self
                                               selector:@selector(timerRefresh:)
                                               userInfo:nil
                                                repeats:YES];
    [parent addSubview:self];
    parentView = parent;
}

/** @ghidraAddress 0xec670 */
- (void)fadeOut {
    fadeType = MissionDetailFadeTypeOut;
    if (fadeTimer) {
        return;
    }
    fadeTimer = [NSTimer scheduledTimerWithTimeInterval:kFadeInterval
                                                 target:self
                                               selector:@selector(timerRefresh:)
                                               userInfo:nil
                                                repeats:YES];
}

/** @ghidraAddress 0xec6fc */
- (void)fadeCancel {
    self.alpha = 0.0;
    if (fadeTimer) {
        [fadeTimer invalidate];
        fadeTimer = nil;
    }
    if (parentView) {
        [self removeFromSuperview];
        parentView = nil;
    }
}

/** @ghidraAddress 0xec7a0 */
- (void)timerRefresh:(NSTimer *)timer {
    float step = (fadeType == MissionDetailFadeTypeOut) ? -kFadeStep : kFadeStep;
    float alpha = step + (float)self.alpha;
    self.alpha = alpha;
    if (alpha < 0.0f) {
        [self removeFromSuperview];
        parentView = nil;
    } else if (alpha <= 1.0f) {
        return;
    }
    fadeType = MissionDetailFadeTypeIdle;
    [fadeTimer invalidate];
    fadeTimer = nil;
}

@end
