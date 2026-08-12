#import "MusicSelectBottomView.h"

#import "ImageCache.h"
#import "ImageLoading.h"
#import "InfoLabel.h"
#import "JubeatAppDelegate.h"
#import "NSDictionary+TypedLookupExtension.h"

// The playlist model consulted to name a custom playlist. Its own header is not reconstructed yet;
// only the one selector this bar sends is declared here.
@interface MusicPlaylistManager : NSObject
- (NSString *)nameOfPlaylistAtIndex:(NSInteger)index;
@end

// The store-info message-dictionary keys.
static NSString *const kStoreInfoMessageKey = @"Message";
static NSString *const kStoreInfoLinkKey = @"Link";

// The jubeat-store deep-link schemes, path segments, and dictionary keys used by -tapStoreInfo:.
static NSString *const kStoreLinkSchemeStore = @"jbtstore";
static NSString *const kStoreLinkSchemeChallenge = @"jbtchallenge";
static NSString *const kStoreLinkPackSegment = @"pack";
static NSString *const kStoreLinkGenreSegment = @"genre";
static NSString *const kStoreLinkChallengeKey = @"challenge";

// Playlist-button artwork (pad) and localisation keys / format (phone), keyed by the sentinel
// index passed to -playlistButtonChanged:.
static NSString *const kPlaylistIconAll = @"pl_icon_all_w";
static NSString *const kPlaylistIconLevel = @"pl_icon_level_w";
static NSString *const kPlaylistIconCustom = @"pl_icon_custom_w";
static NSString *const kPlaylistIconNew = @"pl_icon_new_w";
static NSString *const kPrefPlayListLevelKey = @"PrefPlayListLevel";
static NSString *const kPlaylistLevelFormat = @"Level %d";

// Button and ticker image names.
static NSString *const kPlayListButtonImageName = @"playlist_btn";
static NSString *const kJubeatLabButtonImageName = @"lab_btn";
static NSString *const kJubeatLabIconName = @"pl_icon_lab_w";
static NSString *const kNewInfoBackgroundImageName = @"news_bg_s";

// The sentinel playlist indices -playlistButtonChanged: switches over.
typedef enum : NSInteger {
    MusicPlaylistSentinelAllSongsNotHold = -12,
    MusicPlaylistSentinelAllSongsHold = -11,
    MusicPlaylistSentinelLevel = -10,
    MusicPlaylistSentinelAllSongs = -2,
    MusicPlaylistSentinelNotYetPlayed = -1,
} MusicPlaylistSentinel;

// The bar's own height, and the layout metrics that scale with the phone/pad idiom.
static const CGFloat kBarHeight = 30.0;
static const CGFloat kButtonFontSize = 15.0;
static const CGFloat kTextFontSizePhone = 12.0;
static const CGFloat kShadowOffsetY = -1.0;
static const CGFloat kTitleEdgeInsetLeft = 14.0;
static const CGFloat kTitleEdgeInsetRight = 2.0;
static const CGFloat kButtonCapInset = 45.0;
static const CGFloat kNewInfoCapInsetPhone = 40.0;
static const CGFloat kNewInfoCapInsetPad = 52.0;
static const CGFloat kNewInfoScrollX = 5.0;
static const CGFloat kNewInfoScrollTrimPhone = -1.0;
static const CGFloat kNewInfoScrollTrimPad = 4.0;
static const CGFloat kNewInfoBgTitleAlpha = 0.699999988079071;
static const CGFloat kPlayListWidthPhone = 66.0;
static const CGFloat kPlayListWidthPad = 160.0;
static const CGFloat kJubeatLabWidthPhone = 66.0;
static const CGFloat kJubeatLabWidthPad = 160.0;
static const CGFloat kNewInfoMarginPhone = 71.0;
static const CGFloat kNewInfoMarginPad = 165.0;
static const CGFloat kTextWidthScale = 4.0;

// The ticker timing: the hide timer fires every 11s, and the fade/marquee animations run for 0.6s
// after a 0.4s delay along a linear curve.
static const NSTimeInterval kHideTimerInterval = 11.0;
static const NSTimeInterval kFadeDuration = 0.6;
static const NSTimeInterval kFadeDelay = 0.4;
static const NSTimeInterval kMarqueeStepDuration = 0.6;

@interface MusicSelectBottomView () {
    // The three idiom flags, snapshotted from JubeatAppDelegate at construction.
    BOOL isPad;
    BOOL isRetina;
    BOOL isPadRetina;
    UIButton *playListBtn;
    UIScrollView *newInfoScrl;
    InfoLabel *newInfoText;
    UIImageView *newInfoBg;
    UIButton *btnNewInfo;
    NSArray *arrayStoreInfo;
    NSTimer *commentTimer;
    unsigned int indexStoreInfo;
    UIButton *btnJubeatLab;
}
@end

@implementation MusicSelectBottomView

#pragma mark - Construction

/** @ghidraAddress 0x1d5824 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        isPad = JubeatAppDelegate.appDelegate.isPad;
        isRetina = JubeatAppDelegate.appDelegate.isPhoneRetina;
        isPadRetina = JubeatAppDelegate.appDelegate.isPadRetina;

        // Playlists button (left).
        UIImage *playListImage = LoadScaledPngImage(kPlayListButtonImageName);
        if (isPad) {
            playListImage = [playListImage
                resizableImageWithCapInsets:UIEdgeInsetsMake(
                                                0, kButtonCapInset, 0, kButtonCapInset)];
        }
        playListBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        playListBtn.exclusiveTouch = YES;
        [playListBtn
            setFrame:CGRectMake(
                         0, 0, isPad ? kPlayListWidthPad : kPlayListWidthPhone, frame.size.height)];
        [playListBtn setBackgroundImage:playListImage forState:UIControlStateNormal];
        playListBtn.titleLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:kButtonFontSize];
        playListBtn.titleLabel.textColor = UIColor.whiteColor;
        playListBtn.titleLabel.shadowColor = UIColor.blackColor;
        playListBtn.titleLabel.shadowOffset = CGSizeMake(0, kShadowOffsetY);
        playListBtn.titleLabel.textAlignment = NSTextAlignmentCenter;
        playListBtn.titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [playListBtn
            setTitleEdgeInsets:UIEdgeInsetsMake(0, kTitleEdgeInsetLeft, 0, kTitleEdgeInsetRight)];
        [playListBtn addTarget:self
                        action:@selector(tapPlaylists:)
              forControlEvents:UIControlEventTouchUpInside];
        [playListBtn addTarget:self
                        action:@selector(btnTouchesBegan:)
              forControlEvents:UIControlEventTouchDown];
        [playListBtn addTarget:self
                        action:@selector(btnTouchesCancel:)
              forControlEvents:UIControlEventTouchCancel];
        [self addSubview:playListBtn];

        // jubeat Lab. button (right).
        btnJubeatLab = nil;
        UIImage *labImage = LoadScaledPngImage(kJubeatLabButtonImageName);
        if (isPad) {
            labImage =
                [labImage resizableImageWithCapInsets:UIEdgeInsetsMake(
                                                          0, kButtonCapInset, 0, kButtonCapInset)];
        }
        btnJubeatLab = [UIButton buttonWithType:UIButtonTypeCustom];
        btnJubeatLab.exclusiveTouch = YES;
        CGFloat labWidth = isPad ? kJubeatLabWidthPad : kJubeatLabWidthPhone;
        [btnJubeatLab setFrame:CGRectMake(frame.size.width - labWidth, 0, labWidth, kBarHeight)];
        [btnJubeatLab setBackgroundImage:labImage forState:UIControlStateNormal];
        btnJubeatLab.titleLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:kButtonFontSize];
        btnJubeatLab.titleLabel.textColor = UIColor.whiteColor;
        btnJubeatLab.titleLabel.shadowColor = UIColor.blackColor;
        btnJubeatLab.titleLabel.shadowOffset = CGSizeMake(0, kShadowOffsetY);
        btnJubeatLab.titleLabel.textAlignment = NSTextAlignmentCenter;
        btnJubeatLab.titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [btnJubeatLab
            setTitleEdgeInsets:UIEdgeInsetsMake(0, kTitleEdgeInsetLeft, 0, kTitleEdgeInsetRight)];
        [btnJubeatLab addTarget:self
                         action:@selector(tapJubeatLab:)
               forControlEvents:UIControlEventTouchUpInside];
        [btnJubeatLab addTarget:self
                         action:@selector(btnTouchesBegan:)
               forControlEvents:UIControlEventTouchDown];
        [btnJubeatLab addTarget:self
                         action:@selector(btnTouchesCancel:)
               forControlEvents:UIControlEventTouchCancel];
        if (isPad) {
            [btnJubeatLab setTitle:@"jubeat Lab." forState:UIControlStateNormal];
        } else {
            [btnJubeatLab setImage:[ImageCache.sharedCache getResPNG:kJubeatLabIconName]
                          forState:UIControlStateNormal];
        }

        // Store-info ticker background image (a resizable "news_bg_s"; both idiom arms take the
        // same resizable image, so the branch is present but its two paths are identical).
        UIImage *newInfoImage = LoadScaledPngImage(kNewInfoBackgroundImageName);
        if (!isRetina && !isPadRetina) {
            newInfoImage =
                [newInfoImage resizableImageWithCapInsets:UIEdgeInsetsMake(0,
                                                                           kNewInfoCapInsetPhone,
                                                                           0,
                                                                           kNewInfoCapInsetPhone)];
        } else {
            newInfoImage = [newInfoImage
                resizableImageWithCapInsets:UIEdgeInsetsMake(
                                                0, kNewInfoCapInsetPad, 0, kNewInfoCapInsetPad)];
        }

        // Ticker tap button, sitting behind the scrolling text.
        btnNewInfo = [UIButton buttonWithType:UIButtonTypeCustom];
        btnNewInfo.backgroundColor = UIColor.clearColor;
        btnNewInfo.adjustsImageWhenDisabled = NO;
        btnNewInfo.adjustsImageWhenHighlighted = NO;
        [btnNewInfo setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [btnNewInfo setTitleColor:[UIColor colorWithWhite:kNewInfoBgTitleAlpha alpha:1.0]
                         forState:UIControlStateHighlighted];
        CGFloat newInfoMargin = isPad ? kNewInfoMarginPad : kNewInfoMarginPhone;
        CGFloat newInfoWidth = frame.size.width - newInfoMargin * 2;
        [btnNewInfo setFrame:CGRectMake(newInfoMargin, 0, newInfoWidth, kBarHeight)];
        btnNewInfo.hidden = YES;
        btnNewInfo.enabled = NO;
        btnNewInfo.exclusiveTouch = YES;
        [btnNewInfo addTarget:self
                       action:@selector(tapStoreInfo:)
             forControlEvents:UIControlEventTouchUpInside];
        [btnNewInfo addTarget:self
                       action:@selector(btnTouchesBegan:)
             forControlEvents:UIControlEventTouchDown];
        [btnNewInfo addTarget:self
                       action:@selector(btnTouchesCancel:)
             forControlEvents:UIControlEventTouchCancel];

        // The button's background is drawn once into an image from a plain grey plate view.
        UIView *plate =
            [[UIView alloc] initWithFrame:CGRectMake(newInfoMargin, 0, newInfoWidth, kBarHeight)];
        // The binary builds this colour with colorWithRed:green:blue:alpha: (0, 0, 0, 0.3).
        plate.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.3];
        UIGraphicsBeginImageContext(CGSizeMake(newInfoWidth, kBarHeight));
        [plate.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *plateImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        [btnNewInfo setBackgroundImage:plateImage forState:UIControlStateHighlighted];

        // The ticker background image view spans the bar between the two buttons.
        newInfoBg = [[UIImageView alloc]
            initWithFrame:CGRectMake(labWidth, 0, frame.size.width - labWidth * 2, kBarHeight)];
        newInfoBg.image = newInfoImage;
        newInfoBg.alpha = 1.0;
        newInfoBg.hidden = YES;

        // The scroll view holding the marquee text, inset from the background by the idiom trim.
        CGFloat scrollTrim = isPad ? kNewInfoScrollTrimPad : kNewInfoScrollTrimPhone;
        newInfoScrl = [[UIScrollView alloc]
            initWithFrame:CGRectMake(kNewInfoScrollX, 0, newInfoWidth - scrollTrim, kBarHeight)];
        [newInfoScrl setContentSize:CGSizeMake(newInfoWidth - scrollTrim, kBarHeight)];

        // The label whose text scrolls; its frame is four bar-widths wide to hold long messages.
        newInfoText = [[InfoLabel alloc]
            initWithFrame:CGRectMake(0, 0, frame.size.width * kTextWidthScale, kBarHeight)];
        newInfoText.textColor = [UIColor colorWithWhite:1.0 alpha:1.0];
        newInfoText.backgroundColor = UIColor.clearColor;
        newInfoText.alpha = 0;
        if (isPad) {
            newInfoText.font = [UIFont fontWithName:@"Helvetica-Bold" size:kButtonFontSize];
        } else if (isRetina) {
            newInfoText.font = [UIFont fontWithName:@"Helvetica-Bold" size:kTextFontSizePhone];
        } else {
            newInfoText.font = [UIFont fontWithName:@"Helvetica" size:kTextFontSizePhone];
        }

        [newInfoScrl addSubview:newInfoText];
        [newInfoBg addSubview:newInfoScrl];
        [self addSubview:newInfoBg];
        [self addSubview:btnNewInfo];
        if (btnJubeatLab) {
            [self addSubview:btnJubeatLab];
        }
    }
    return self;
}

#pragma mark - Button actions

/** @ghidraAddress 0x1d672c */
- (void)tapPlaylists:(id)sender {
    if ([self.aDelegate respondsToSelector:@selector(tapPlaylists:)]) {
        [self.aDelegate tapPlaylists:sender];
    }
}

/** @ghidraAddress 0x1d67dc */
- (void)btnTouchesBegan:(id)sender {
    if ([self.aDelegate respondsToSelector:@selector(btnTouchesBegan:)]) {
        [self.aDelegate btnTouchesBegan:sender];
    }
}

/** @ghidraAddress 0x1d688c */
- (void)btnTouchesCancel:(id)sender {
    if ([self.aDelegate respondsToSelector:@selector(btnTouchesCancel:)]) {
        [self.aDelegate btnTouchesCancel:sender];
    }
}

/** @ghidraAddress 0x1d693c */
- (CGRect)getPlayListBtnRect {
    // The binary composes the returned rect from three -frame sends rather than returning
    // playListBtn.frame outright: origin.x is a literal 0, origin.y is taken from self.frame, and
    // the size comes from playListBtn.frame (its width from the first send, its height from the
    // second). Preserve that mix exactly.
    return CGRectMake(
        0, self.frame.origin.y, playListBtn.frame.size.width, playListBtn.frame.size.height);
}

/** @ghidraAddress 0x1d69ac */
- (void)playlistButtonChanged:(NSInteger)index {
    if (isPad) {
        UIImage *image = nil;
        switch (index) {
        case MusicPlaylistSentinelAllSongsNotHold:
        case MusicPlaylistSentinelAllSongsHold:
        case MusicPlaylistSentinelAllSongs:
            image = [ImageCache.sharedCache getResPNG:kPlaylistIconAll];
            break;
        case MusicPlaylistSentinelLevel:
            image = [ImageCache.sharedCache getResPNG:kPlaylistIconLevel];
            break;
        case MusicPlaylistSentinelNotYetPlayed:
            image = [ImageCache.sharedCache getResPNG:kPlaylistIconNew];
            break;
        default:
            if (index < 0) {
                image = nil;
            } else {
                image = [ImageCache.sharedCache getResPNG:kPlaylistIconCustom];
            }
            break;
        }
        [playListBtn setImage:image forState:UIControlStateNormal];
    } else {
        NSString *title = nil;
        switch (index) {
        case MusicPlaylistSentinelAllSongsNotHold:
            title = [NSBundle.mainBundle localizedStringForKey:@"All Songs(Not Hold)"
                                                         value:@""
                                                         table:nil];
            break;
        case MusicPlaylistSentinelAllSongsHold:
            title = [NSBundle.mainBundle localizedStringForKey:@"All Songs(Hold)"
                                                         value:@""
                                                         table:nil];
            break;
        case MusicPlaylistSentinelLevel: {
            NSInteger level =
                [NSUserDefaults.standardUserDefaults integerForKey:kPrefPlayListLevelKey];
            title = [NSString stringWithFormat:kPlaylistLevelFormat, (int)level];
            break;
        }
        case MusicPlaylistSentinelAllSongs:
            title = [NSBundle.mainBundle localizedStringForKey:@"All Songs" value:@"" table:nil];
            break;
        case MusicPlaylistSentinelNotYetPlayed:
            title = [NSBundle.mainBundle localizedStringForKey:@"Not Yet Played"
                                                         value:@""
                                                         table:nil];
            break;
        default:
            if (index < 0) {
                title = @"";
            } else {
                title = [self.playlistManager nameOfPlaylistAtIndex:index];
            }
            break;
        }
        [playListBtn setTitle:title forState:UIControlStateNormal];
    }
}

#pragma mark - Store-info ticker

/** @ghidraAddress 0x1d6dec */
- (void)tapStoreInfo:(id)sender {
    NSDictionary *result = nil;
    NSString *link = [arrayStoreInfo[indexStoreInfo] stringForKey:kStoreInfoLinkKey];
    if (link) {
        NSURL *url = [NSURL URLWithString:link];
        if (url) {
            if ([url.scheme isEqualToString:kStoreLinkSchemeStore]) {
                if (url.pathComponents.count == 3) {
                    if ([url.pathComponents[1] isEqualToString:kStoreLinkPackSegment]) {
                        result = @{kStoreLinkPackSegment : url.pathComponents[2]};
                    }
                    if ([url.pathComponents[1] isEqualToString:kStoreLinkGenreSegment]) {
                        result = @{kStoreLinkGenreSegment : url.pathComponents[2]};
                    }
                }
            } else if ([url.scheme isEqualToString:kStoreLinkSchemeChallenge]) {
                result = @{kStoreLinkChallengeKey : @""};
            } else {
                [UIApplication.sharedApplication openURL:url];
            }
        }
    }
    if ([self.aDelegate respondsToSelector:@selector(tapStoreInfo:)]) {
        [self.aDelegate tapStoreInfo:result];
    }
}

/** @ghidraAddress 0x1d7278 */
- (void)setCommentTable:(NSArray *)table {
    if (table.count != 0) {
        arrayStoreInfo = [[NSArray alloc] initWithArray:table];
        indexStoreInfo = (arc4random() & 0xff) % (unsigned int)table.count;
        btnNewInfo.hidden = NO;
        commentTimer = [NSTimer timerWithTimeInterval:kHideTimerInterval
                                               target:self
                                             selector:@selector(hideStoreText)
                                             userInfo:nil
                                              repeats:YES];
        [NSRunLoop.mainRunLoop addTimer:commentTimer forMode:NSRunLoopCommonModes];
        [self showNextStoreText];
    }
}

/** @ghidraAddress 0x1d7410 */
- (void)showNextStoreText {
    if (indexStoreInfo >= arrayStoreInfo.count) {
        indexStoreInfo = 0;
    }
    NSString *message = [arrayStoreInfo[indexStoreInfo] stringForKey:kStoreInfoMessageKey];
    int textWidth;
    if (message) {
        newInfoText.text = message;
        CGSize size = [message sizeWithAttributes:@{NSFontAttributeName : newInfoText.font}];
        textWidth = (int)size.width + 8;
    } else {
        newInfoText.text = @"";
        textWidth = 0;
    }

    // The marquee end x is the wider of the text width plus a margin and the current content width.
    int endX;
    if (newInfoScrl.contentSize.width <= (double)textWidth) {
        endX = textWidth + 0x10;
    } else {
        endX = (int)newInfoScrl.contentSize.width;
    }
    newInfoScrl.contentOffset = CGPointZero;

    __weak UIButton *weakBtnNewInfo = btnNewInfo;
    __weak InfoLabel *weakText = newInfoText;
    __weak UIScrollView *weakScroll = newInfoScrl;
    [UIView animateWithDuration:kFadeDuration
        delay:kFadeDelay
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x1d7778 */
          weakText.alpha = 1.0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x1d77c4 */
          weakBtnNewInfo.enabled = YES;
          int width = (int)weakScroll.contentSize.width;
          int distance = endX - width;
          int step = width / 3;
          int laps = 0;
          if (step != 0) {
              laps = distance / step;
          }
          NSTimeInterval duration = (float)(laps + 1) * (float)kMarqueeStepDuration;
          [UIView animateWithDuration:duration
                                delay:kFadeDelay
                              options:UIViewAnimationOptionCurveLinear
                           animations:^{
                             /** @ghidraAddress 0x1d791c */
                             weakScroll.contentOffset = CGPointMake(distance, 0);
                           }
                           completion:^(BOOL __attribute__((unused)) innerFinished){
                               /** @ghidraAddress 0x1d7978 */
                           }];
        }];
}

/** @ghidraAddress 0x1d79d8 */
- (void)hideStoreText {
    [btnNewInfo cancelTrackingWithEvent:nil];
    btnNewInfo.enabled = NO;
    indexStoreInfo += 1;

    __weak InfoLabel *weakText = newInfoText;
    [UIView animateWithDuration:kFadeDuration
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x1d7b34 */
          weakText.alpha = 0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x1d7b80 */
          [self showNextStoreText];
        }];
}

/** @ghidraAddress 0x1d7ba0 */
- (void)animStop {
    [btnNewInfo.titleLabel.layer removeAllAnimations];
}

/** @ghidraAddress 0x1d7c0c */
- (void)tapJubeatLab:(id)sender {
    if ([self.aDelegate respondsToSelector:@selector(tapJubeatLab:)]) {
        [self.aDelegate tapJubeatLab:sender];
    }
}

@end
