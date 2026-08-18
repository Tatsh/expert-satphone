#import "MissionAchievementMessage.h"

#import <QuartzCore/QuartzCore.h>

#import "AudioManager.h"
#import "BalloonView.h"
#import "ChallengeMissionSheet.h"
#import "ChallengeMissionTerms.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The completion sound played as the banner enters. From the CFString at 0x2d6960.
static NSString *const kMissionGaugeSEName = @"SD_MISSION_GAUGE";

// The achievement-record keys read from each mission's record: the current progress value and the
// per-index progress detail. From the CFStrings at 0x1002d4360 (@"0") and 0x1002d6900 (@"data").
static NSString *const kMissionAchieveProgressKey = @"0";
static NSString *const kMissionAchieveDataKey = @"data";

// The rendered-line formats: a bare title for a completed mission, and a title with a
// progress/target pair otherwise. From the CFStrings at 0x1002d4360 (@"%@") and 0x1002d6920
// (@"%@(%d/%d)").
static NSString *const kMissionTitleFormat = @"%@";
static NSString *const kMissionTitleProgressFormat = @"%@(%d/%d)";

// The mission-state value that marks a mission as complete (the "status" achievement value). The
// mission types whose progress is summed across the detail array, and the single type that reads
// a per-key progress sum. Verified from the branch tests at 0x4dd68 (state == 4), 0x4db38
// (type - 4 < 2, i.e. 4 or 5), and 0x4dbf4 (type == 3).
static const int kMissionStateComplete = 4;
static const unsigned int kMissionTypeDetailFirst = 4;
static const unsigned int kMissionTypeDetailLast = 5;
static const unsigned int kMissionTypeSummedDetail = 3;

// The achievement record's completion-state key. From the CFString at 0x1002d5000 (@"status").
static NSString *const kMissionAchieveStatusKey = @"status";

// The per-entry format inside a rendered line, and the trailing flourish. From 0x2d6980 and
// 0x2d69a0.
static NSString *const kMissionEntryFormat = @" %@";
static NSString *const kMissionAchievedSuffix = @"を達成しましたよ";

// The bounding-rect measuring size: the message width by an effectively unbounded height. The width
// cap is the pooled double at 0x28f5a8 (1000.0); the temp label is 2000 tall (0x28f5b0).
static const CGFloat kMissionTextMaxWidth = 1000.0;      // @ghidraAddress 0x28f5a8
static const CGFloat kMissionTextMeasureHeight = 2000.0; // @ghidraAddress 0x28f5b0

// The banner auto-dismisses after this many seconds; the 6.0f is planted in -enterAnimationStart at
// 0x4eb2c and threaded through every entry stage as the NSTimer interval.
static const NSTimeInterval kMissionMessageDismissDelay = 6.0;

// The four entry-stage durations and the two exit-stage durations. From the pooled doubles at
// 0x28e040 (0.2), 0x28f260 (0.3), and the fmov immediate 0x4034000000000000 (20.0) for the slide.
static const NSTimeInterval kMissionMessageShortStageDuration = 0.2;  // @ghidraAddress 0x28e040
static const NSTimeInterval kMissionMessageSettleStageDuration = 0.3; // @ghidraAddress 0x28f260
static const CGFloat kMissionMessageSlideDownDistance = 20.0;         // fmov 0x4034000000000000

// The dimming background's alpha; the pooled double at 0x28f2c0.
static const CGFloat kMissionBackgroundAlpha = 0.4;

// The message view's width by idiom: the pooled doubles at 0x28f5c0 (phone) and 0x28f5c8 (pad).
static const CGFloat kMissionMessageWidthPhone = 320.0; // @ghidraAddress 0x28f5c0
static const CGFloat kMissionMessageWidthPad = 640.0;   // @ghidraAddress 0x28f5c8

// The phone-only horizontal inset added to the centred message view; the fmov 0x402c000000000000.
static const CGFloat kMissionMessagePhoneInset = 14.0;

// The completion-icon overshoot below the message view, and the label inset inside the balloon on
// every edge; both are the fmov 0x4024000000000000.
static const CGFloat kMissionIconBottomOffset = 10.0;
static const CGFloat kMissionLabelInset = 10.0;

// The label's rect is inset from the balloon by twice the corner allowance on each axis.
static const int kMissionLabelSizeInset = 20;

// The point sizes of the bold message font by idiom.
static const int kMissionFontSizePad = 20;
static const int kMissionFontSizePhone = 10;

// The completion-icon animation: two loops of the 24 frames at this duration; the pooled double at
// 0x28f240.
static const int kMissionIconRepeatCount = 2;
static const NSTimeInterval kMissionIconAnimationDuration = 0.2; // @ghidraAddress 0x28f240

// The completion-icon frame names format, and the frame-number range. The mission_con NN images run
// 18..24 then wrap to 1..17, so the loop counter 18..41 clamps values above 24 back by 24.
static NSString *const kMissionIconNameFormat = @"mission_con%02d";
static const int kMissionIconFirstFrame = 18;
static const int kMissionIconLastFrame = 41;
static const int kMissionIconWrapThreshold = 24;

@implementation MissionAchievementMessage {
    UIImageView *conImg;         // +0x08, ivar-offset global 0x349c5c
    UIView *messageView;         // +0x10, ivar-offset global 0x349c54
    BalloonView *bgView;         // +0x18, ivar-offset global 0x349c60
    int fontSize;                // +0x20, ivar-offset global 0x349c4c
    UILabel *messageText;        // +0x28, ivar-offset global 0x349c6c
    int viewHeight;              // +0x30, ivar-offset global 0x349c50
    int bgWidth;                 // +0x34, ivar-offset global 0x349c64
    int bgHeight;                // +0x38, ivar-offset global 0x349c68
    NSMutableArray *conImgTable; // +0x40, ivar-offset global 0x349c58
    NSTimer *messageTimer;       // +0x48, ivar-offset global 0x349c74
    BOOL bTap;                   // +0x50, ivar-offset global 0x349c70
    BOOL isPad;                  // +0x51, ivar-offset global 0x349c48
    // _aDelegate is weak, at +0x58 (ivar-offset global 0x349c78).
}

#pragma mark - Construction

/** @ghidraAddress 0x4e0c8 */
- (instancetype)initWithTitle:(id)title {
    self = [super initWithFrame:UIScreen.mainScreen.bounds];
    if (!self) {
        return nil;
    }
    isPad = JubeatAppDelegate.appDelegate.isPad;
    // The dimming background is opaque black at 40% alpha, but the view starts fully transparent
    // and is faded in by -enterAnimationStart.
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:kMissionBackgroundAlpha];
    self.alpha = 0;

    fontSize = isPad ? kMissionFontSizePad : kMissionFontSizePhone;
    UIFont *font = [UIFont boldSystemFontOfSize:fontSize];

    CGFloat messageWidth = isPad ? kMissionMessageWidthPad : kMissionMessageWidthPhone;
    int textHeight = [self messageHeight:title];
    viewHeight = textHeight;
    CGFloat screenWidth = self.frame.size.width;
    CGFloat inset = isPad ? 0 : kMissionMessagePhoneInset;
    int messageX = (int)(inset + (screenWidth - messageWidth) * 0.5);
    messageView = [[UIView alloc] initWithFrame:CGRectMake(messageX, 0, messageWidth, textHeight)];
    [self addSubview:messageView];

    // Build the 24 completion-icon frames in the order the binary walks them: 18..24 then 1..17.
    conImgTable = [[NSMutableArray alloc] init];
    UIImage *iconImage = nil;
    for (int frame = kMissionIconFirstFrame; frame <= kMissionIconLastFrame; ++frame) {
        int frameIndex =
            frame > kMissionIconWrapThreshold ? frame - kMissionIconWrapThreshold : frame;
        iconImage =
            LoadScaledPngImage([NSString stringWithFormat:kMissionIconNameFormat, frameIndex]);
        [conImgTable addObject:iconImage];
    }

    // The icon sits at the message view's bottom-right corner, pushed down by the overshoot.
    CGSize iconSize = iconImage.size;
    CGRect iconFrame = CGRectMake(messageWidth - iconSize.width,
                                  (viewHeight - iconSize.height) + kMissionIconBottomOffset,
                                  iconSize.width,
                                  iconSize.height);
    conImg = [[UIImageView alloc] initWithFrame:iconFrame];
    conImg.image = iconImage;
    conImg.animationImages = conImgTable;
    conImg.animationRepeatCount = kMissionIconRepeatCount;
    conImg.animationDuration = kMissionIconAnimationDuration;
    [messageView addSubview:conImg];
    conImg.userInteractionEnabled = YES;
    conImg.tag = 1;

    // The balloon fills the message view to the left of the icon.
    [self createMassageBg:CGSizeMake((int)(messageWidth - iconSize.width), viewHeight)];
    [messageView addSubview:bgView];
    bgWidth = (int)bgView.frame.size.width;
    bgHeight = (int)bgView.frame.size.height;

    // The text label is inset inside the balloon and carries the attributed achievement text.
    messageText = [[UILabel alloc] initWithFrame:CGRectMake(kMissionLabelInset,
                                                            kMissionLabelInset,
                                                            bgWidth - kMissionLabelSizeInset,
                                                            bgHeight - kMissionLabelSizeInset)];
    messageText.textColor = UIColor.whiteColor;
    messageText.font = font;
    messageText.numberOfLines = 0;
    messageText.attributedText = [self createAchiveText:title];
    [bgView addSubview:messageText];

    [self transReset];
    return self;
}

#pragma mark - Entry animation

/** @ghidraAddress 0x4ea44 */
- (void)enterAnimationStart {
    // A four-stage chain: fade the banner in, start the icon and slide the message down, settle the
    // balloon back to identity, then arm the auto-dismiss timer and unlock tapping. The 6.0s timer
    // interval is threaded through every stage's completion block.
    bTap = NO;
    [AudioManager.sharedManager playSeResFile:kMissionGaugeSEName inDirectory:nil];

    __weak MissionAchievementMessage *weakSelf = self;
    [UIView animateWithDuration:kMissionMessageShortStageDuration
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x4eba8 */
          weakSelf.alpha = 1.0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x4ebf4 */
          MissionAchievementMessage *strongSelf = weakSelf;
          [strongSelf->conImg startAnimating];
          __weak UIView *weakMessageView = strongSelf->messageView;
          [UIView animateWithDuration:kMissionMessageShortStageDuration
              delay:0
              options:UIViewAnimationOptionCurveLinear
              animations:^{
                /** @ghidraAddress 0x4ed34 */
                weakMessageView.transform =
                    CGAffineTransformMakeTranslation(0, kMissionMessageSlideDownDistance);
              }
              completion:^(BOOL __attribute__((unused)) innerFinished) {
                /** @ghidraAddress 0x4edb8 */
                __weak BalloonView *weakBgView = strongSelf->bgView;
                [UIView animateWithDuration:kMissionMessageSettleStageDuration
                    delay:0
                    options:UIViewAnimationOptionCurveLinear
                    animations:^{
                      /** @ghidraAddress 0x4eedc */
                      // The identity transform, built the long way as the binary does: translate by
                      // zero, then scale by one, undoing the collapse -createMassageBg: left.
                      weakBgView.transform =
                          CGAffineTransformScale(CGAffineTransformMakeTranslation(0, 0), 1, 1);
                    }
                    completion:^(BOOL __attribute__((unused)) settleFinished) {
                      /** @ghidraAddress 0x4efa4 */
                      // Arm the auto-dismiss timer and unlock tapping, regardless of whether the
                      // animation ran to completion, so the banner can always be dismissed.
                      strongSelf->messageTimer =
                          [NSTimer scheduledTimerWithTimeInterval:kMissionMessageDismissDelay
                                                           target:strongSelf
                                                         selector:@selector(dispEnd:)
                                                         userInfo:nil
                                                          repeats:NO];
                      strongSelf->bTap = YES;
                    }];
              }];
        }];
}

#pragma mark - Exit animation

/** @ghidraAddress 0x4f058 */
- (void)outerAnimationStart {
    // The mirror of the entry: collapse the balloon toward its arrow and slide the message up, then
    // fade the banner out and tell the delegate it has closed. Taps are locked for the whole exit.
    bTap = NO;

    // The two target transforms are computed here and baked into the animation block. The balloon
    // collapses to nothing at an offset of (bgWidth - bgWidth/4, bgHeight - bgHeight/3); the
    // message slides up by its own height.
    CGAffineTransform bgTarget = CGAffineTransformScale(
        CGAffineTransformMakeTranslation(bgWidth - bgWidth / 4, bgHeight - bgHeight / 3), 0, 0);
    CGAffineTransform messageTarget = CGAffineTransformMakeTranslation(0, -viewHeight);

    [conImg startAnimating];

    __weak MissionAchievementMessage *weakSelf = self;
    __weak BalloonView *weakBgView = bgView;
    __weak UIView *weakMessageView = messageView;
    [UIView animateWithDuration:kMissionMessageSettleStageDuration
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x4f318 */
          weakBgView.transform = bgTarget;
          weakMessageView.transform = messageTarget;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x4f418 */
          MissionAchievementMessage *strongSelf = weakSelf;
          [UIView animateWithDuration:kMissionMessageShortStageDuration
              delay:0
              options:UIViewAnimationOptionCurveLinear
              animations:^{
                /** @ghidraAddress 0x4f50c */
                weakSelf.alpha = 0;
              }
              completion:^(BOOL __attribute__((unused)) fadeFinished) {
                /** @ghidraAddress 0x4f558 */
                [strongSelf messageEnd];
              }];
        }];
}

/** @ghidraAddress 0x4f5cc */
- (void)transReset {
    // Park the balloon collapsed at its arrow offset and the message above the frame, then hide the
    // whole banner. This is the state -enterAnimationStart animates out of.
    bgView.transform = CGAffineTransformScale(
        CGAffineTransformMakeTranslation(bgWidth - bgWidth / 4, bgHeight - bgHeight / 3), 0, 0);
    messageView.transform = CGAffineTransformMakeTranslation(0, -viewHeight);
    self.alpha = 0;
}

#pragma mark - Dismissal

/** @ghidraAddress 0x4f730 */
- (void)dispEnd:(NSTimer *)timer {
    messageTimer = nil;
    [self outerAnimationStart];
}

/** @ghidraAddress 0x4f76c */
- (void)messageEnd {
    if ([self.aDelegate respondsToSelector:@selector(messageClose)]) {
        [self.aDelegate messageClose];
    }
}

#pragma mark - Touch handling

/** @ghidraAddress 0x4fcec */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    // Empty in the binary.
}

/** @ghidraAddress 0x4fcc8 */
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    // A tap while the banner is up dismisses it early; the flag guards against a second tap during
    // the exit animation.
    if (bTap) {
        bTap = NO;
        [self outerAnimationStart];
    }
}

#pragma mark - Balloon background

/** @ghidraAddress 0x4f81c */
- (void)createMassageBg:(CGSize)size {
    // A BalloonView with a soft drop shadow and a rightward arrow, inset by 12 points on each side.
    bgView = [[BalloonView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    bgView.layer.shadowColor = UIColor.blackColor.CGColor;
    bgView.layer.shadowRadius = 3;     // 0x4008000000000000
    bgView.layer.shadowOpacity = 0.9f; // 0x28f3b0
    bgView.layer.shadowOffset = CGSizeMake(0, 1);
    bgView.arrowDirection = BalloonViewArrowDirectionRight; // 3
    bgView.contentEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
    [messageView addSubview:bgView];
    bgWidth = (int)bgView.frame.size.width;
    bgHeight = (int)bgView.frame.size.height;
}

#pragma mark - Attributed text

/** @ghidraAddress 0x4fcf0 */
- (NSAttributedString *)createAchiveText:(id)title {
    // Two attribute sets, both bold at the current font size: the sheet name and line breaks are
    // white, the achieved sub-titles are orange. Verified at 0x4fd50 (orange) and 0x4fe04 (white).
    UIFont *font = [UIFont boldSystemFontOfSize:fontSize];
    NSDictionary *orangeAttributes = [NSDictionary
        dictionaryWithObjects:@[ UIColor.orangeColor, font ]
                      forKeys:@[ NSForegroundColorAttributeName, NSFontAttributeName ]];
    NSDictionary *whiteAttributes = [NSDictionary
        dictionaryWithObjects:@[ UIColor.whiteColor, font ]
                      forKeys:@[ NSForegroundColorAttributeName, NSFontAttributeName ]];

    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] init];
    if (!title) {
        return text;
    }

    // The title is an array of lines; each line is an array of segments. Segment 0 is the sheet
    // name in white; each later segment is an achieved sub-title, prefixed with a space and
    // coloured orange. A newline follows every segment. Verified at the nested enumerations from
    // 0x4fed8.
    for (NSArray *line in title) {
        NSUInteger segmentCount = line.count;
        for (NSUInteger segment = 0; segment < segmentCount; ++segment) {
            NSAttributedString *piece;
            if (segment == 0) {
                piece = [[NSAttributedString alloc] initWithString:line[segment]
                                                        attributes:whiteAttributes];
            } else {
                NSString *entry = [NSString stringWithFormat:kMissionEntryFormat, line[segment]];
                piece = [[NSAttributedString alloc] initWithString:entry
                                                        attributes:orangeAttributes];
            }
            [text appendAttributedString:piece];
            // A newline after every segment; the guard at 0x50058 only skips it past the last
            // index, which the loop never reaches.
            if (segment < segmentCount) {
                [text appendAttributedString:[[NSAttributedString alloc]
                                                 initWithString:@"\n"
                                                     attributes:whiteAttributes]];
            }
        }
        [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"
                                                                     attributes:whiteAttributes]];
    }

    // Closes the card with the achievement flourish, in white.
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:kMissionAchievedSuffix
                                                                 attributes:whiteAttributes]];
    return text;
}

/** @ghidraAddress 0x4e6fc */
- (int)messageHeight:(id)title {
    // The base line height is 40 on a pad and 20 on a phone. With no title, that base is the whole
    // answer. Verified at 0x4e748: isPad ? 0x28 : 0x14.
    int lineHeight = isPad ? 40 : 20;
    int width = (int)messageText.frame.size.width;
    if (!title) {
        return lineHeight;
    }

    // Measure the rendered text in a throwaway label sized to the message width, then take its
    // laid-out height. The font size is stored back into the ivar (10 on a phone). Verified at
    // 0x4e7c8 (boundingRectWithSize:) and 0x4e800 onwards (the temp label).
    NSAttributedString *rendered = [self createAchiveText:title];
    (void)[rendered boundingRectWithSize:CGSizeMake(width, kMissionTextMaxWidth)
                                 options:NSStringDrawingUsesLineFragmentOrigin
                                 context:nil];
    UILabel *measure =
        [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width, kMissionTextMeasureHeight)];
    fontSize = isPad ? 20 : 10;
    measure.font = [UIFont boldSystemFontOfSize:fontSize];
    measure.numberOfLines = 0;
    measure.attributedText = [self createAchiveText:title];
    [measure sizeToFit];
    int height = fontSize + (int)measure.frame.size.height + 4;

    // Count the total number of achieved entries across every line; when non-zero the height is one
    // line taller per entry. Verified at 0x4e928 onwards (the per-line intValue sum).
    int entryCount = 0;
    for (NSArray *line in title) {
        entryCount += (int)line.count;
    }
    if (entryCount != 0) {
        height = ((int)measure.frame.size.height + 4) * (entryCount + 1) + lineHeight;
    }
    return height;
}

#pragma mark - Title array

/** @ghidraAddress 0x4d790 */
+ (NSArray *)createTitleArray:(NSArray *)title achieve:(NSDictionary *)achieve {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    // The achievement records are matched in ascending numeric-key order, matching the binary's
    // sortedArrayUsingComparator: over the keys' int values.
    NSArray *sortedKeys =
        [achieve.allKeys sortedArrayUsingComparator:^NSComparisonResult(id left, id right) {
          /** @ghidraAddress 0x4dfd4 */
          return [@([left intValue]) compare:@([right intValue])];
        }];
    for (ChallengeMissionSheet *sheet in title) {
        NSMutableArray *lines = [[NSMutableArray alloc] init];
        [lines addObject:sheet.sheetName];
        for (ChallengeMissionTerms *terms in sheet.missionTable) {
            for (NSString *key in sortedKeys) {
                if (key.intValue != terms.missionID) {
                    continue;
                }
                NSString *missionTitle = terms.missionTitle;
                NSDictionary *record = achieve[key];
                // Defaults: the target is the number of condition parameters, and the progress is
                // the number of recorded data entries.
                int target = (int)terms.missionDetail.count;
                int progress = (int)[[record objectForKey:kMissionAchieveDataKey] count];
                unsigned int type = terms.missionType;
                if (type >= kMissionTypeDetailFirst && type <= kMissionTypeDetailLast) {
                    // The first condition parameter is the target; the "0" data entry is the
                    // progress.
                    NSDictionary *data = record[kMissionAchieveDataKey];
                    target = [terms.missionDetail[0] intValue];
                    progress = [data[kMissionAchieveProgressKey] intValue];
                } else if (type == kMissionTypeSummedDetail) {
                    NSDictionary *data = record[kMissionAchieveDataKey];
                    if (data) {
                        target = [terms.missionDetail[0] intValue];
                        progress = 0;
                        for (NSString *dataKey in data) {
                            progress += [data[dataKey] intValue];
                        }
                    }
                }
                int shown = progress <= target ? progress : target;
                if ([record[kMissionAchieveStatusKey] intValue] == kMissionStateComplete) {
                    [lines addObject:[NSString stringWithFormat:kMissionTitleFormat, missionTitle]];
                } else if (shown > 0) {
                    [lines addObject:[NSString stringWithFormat:kMissionTitleProgressFormat,
                                                                missionTitle,
                                                                shown,
                                                                target]];
                }
            }
        }
        // Keep the group only when it gained an entry beyond the sheet name.
        if (lines.count > 1) {
            [result addObject:[lines copy]];
        }
    }
    return [result copy];
}

/** @ghidraAddress 0x4fa3c */
- (void)setAchieveTitle:(id)title {
    // Rebuilds the balloon and text for a new title. First the running view height is reduced by
    // the old balloon's height, then the old balloon and text are torn down.
    viewHeight -= (int)bgView.frame.size.height;
    [bgView removeFromSuperview];
    bgView = nil;
    [messageText removeFromSuperview];

    BOOL wasPad = isPad;
    // The text is laid out inset 20 points inside the balloon content box.
    [messageText setFrame:CGRectMake(10, 10, bgWidth - 20, bgHeight - 20)];
    messageText.attributedText = [self createAchiveText:title];
    [messageText sizeToFit];
    CGRect textFrame = messageText.frame;

    // The new balloon height is the text height plus the font size, plus 10 on a phone only.
    int newBgHeight = (int)((wasPad ? 0 : 10.0) + textFrame.size.height + fontSize);
    bgHeight = newBgHeight;
    viewHeight += newBgHeight;

    [self createMassageBg:CGSizeMake(bgWidth, bgHeight)];
    [messageView addSubview:bgView];
    [bgView addSubview:messageText];

    // Recentre the completion icon over the resized balloon: its origin y moves to the balloon
    // height minus its own height, plus 10. Verified at 0x4fc2c onwards (four conImg.frame reads).
    CGRect iconFrame = conImg.frame;
    CGFloat iconY = (bgHeight - iconFrame.size.height) + 10;
    [conImg setFrame:CGRectMake(
                         iconFrame.origin.x, iconY, iconFrame.size.width, iconFrame.size.height)];
}

@end
