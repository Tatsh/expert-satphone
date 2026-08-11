#import "MissionRewardDownloadView.h"

#import "AlertViewManager.h"
#import "AudioManager.h"
#import "ChallengeMissionReward.h"
#import "ChallengeModeRootView.h"
#import "ChallengeStatus.h"
#import "Downloader.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "MarkerManager.h"
#import "Md5Utilities.h"
#import "ScratchUtil.h"
#import "SessionDownloader.h"
#import "StoreDialogView.h"
#import "StoreDownloadManager.h"
#import "StoreDownloadTask.h"
#import "StoreMusicInfo.h"
#import "StoreMusicListManager.h"
#import "StoreUtil.h"
#import "SystemUtilities.h"

// The reward item kinds carried by ChallengeMissionReward's itemType. Music resolves to a store
// tune path, marker to a marker path, and stickers (5, 6) to the shared app-group container.
typedef enum {
    MissionRewardItemTypeImage = 0,
    MissionRewardItemTypeMusic = 3,
    MissionRewardItemTypeMarker = 4,
    MissionRewardItemTypeStickerFront = 5,
    MissionRewardItemTypeStickerAlt = 6,
} MissionRewardItemType;

// The tag stamped on each Downloader/SessionDownloader so downloaderFinished: can tell the stages
// apart: 0 is the icon image, 1 the reward metadata post, 2 the item body, 3 the music-info fetch,
// 4 the sample-info fetch, and 5 the sample audio.
typedef enum {
    MissionRewardDownloadTagIcon = 0,
    MissionRewardDownloadTagInfo = 1,
    MissionRewardDownloadTagItem = 2,
    MissionRewardDownloadTagMusicInfo = 3,
    MissionRewardDownloadTagSampleInfo = 4,
    MissionRewardDownloadTagSampleAudio = 5,
} MissionRewardDownloadTag;

// The download button's three art states: idle, disabled/greyed, and downloaded.
static NSString *const kBackgroundImageName = @"cm_reward_bg";
static NSString *const kDownloadButtonIdleImageName = @"cm_reward_btn_0";
static NSString *const kDownloadButtonDisabledImageName = @"cm_reward_btn_2";
static NSString *const kDownloadButtonDoneImageName = @"cm_reward_btn_1";
static NSString *const kCloseButtonImageName = @"scratch_btn_cancel";

// The sticker name formats used by checkItemDownload, and the marker id format shared with the
// install path.
static NSString *const kFrontStickerNameFormat = @"s%@.png";
static NSString *const kAltStickerNameFormat = @"as%@.png";
static NSString *const kMarkerIDFormat = @"mk%04d";

// The sticker install format strings: the two icon variants, the on-disk ".png" name, and the
// bare "%@_" index key.
static NSString *const kStickerIconFrontFormat = @"s%@";
static NSString *const kStickerIconAltFormat = @"as%@";
static NSString *const kStickerFileNameFormat = @"%@.png";
static NSString *const kStickerIndexKeyFormat = @"%@_";

// The marker install strings: the banner name format and the marker-info dictionary keys.
static NSString *const kMarkerBannerFormat = @"tm%@_banner";
static NSString *const kMarkerInfoVersion = @"1.0.0";
static NSString *const kMarkerIDKey = @"markerID";
static NSString *const kMarkerVersionKey = @"version";
static NSString *const kMarkerBannerNameKey = @"bannerName";

// The "%@ is downloading..." message shown in the progress dialog.
static NSString *const kDownloadingMessageFormat = @"%@をダウンロードしています...";

// The reward-metadata response keys.
static NSString *const kStatusKey = @"status";
static NSString *const kItemURLKey = @"item_url";
static NSString *const kErrorMessageKey = @"err_message";

// The post-body key carrying the reward id.
static NSString *const kRewardIDKey = @"reward_id";

// The alert echoed-tag key and the localised-string keys.
static NSString *const kAlertTagKey = @"Tag";
static NSString *const kServerErrorMessageKey = @"ServerErrorMsg";
static NSString *const kOKButtonKey = @"OK";
static NSString *const kCancelButtonKey = @"Cancel";
static NSString *const kLocalizedEmptyValue = @"";

// The item-download failure messages. The marker MD5-verification failure uses the shorter form
// (no trailing full stop) with a localised "Cancel" button; the downloader and store-manager
// failures use the form with a trailing full stop and a literal "OK" button.
static NSString *const kItemDownloadFailedMessage = @"アイテムのダウンロードに失敗しました";
static NSString *const kItemDownloadFailedMessagePeriod = @"アイテムのダウンロードに失敗しました。";

// The literal "OK" button title used by the download-failure alerts (distinct from the localised
// key looked up elsewhere).
static NSString *const kOKButtonLiteral = @"OK";

// The sound-effect resource name played as the dialog dismisses.
static NSString *const kCancelSeName = @"SD_CHALLENGE_CANCEL";

// The alert type: a plain notice with no text field.
static const int kAlertTypePlain = 0;
// The session-error alert's echoed-back tag; alertSelect: closes the session on this value.
static const int kServerErrorAlertTag = 9999;
// The alert-tag value returned by the server on a challenge-session error.
static const int kServerSessionErrorStatus = 0x18b53;

// The MD5 digest appended to a marker payload, and the marker-id substring taken from the "mk%04d"
// name.
static const NSUInteger kMd5DigestLength = 16;
static const NSUInteger kMarkerIDSubstringLocation = 2;
static const NSUInteger kMarkerIDSubstringLength = 4;

// The half-scale factor used throughout the centring maths.
static const CGFloat kHalf = 0.5;

// The description label wraps to at most three lines.
static const NSInteger kDescriptionLineCount = 3;

// The progress dialog fade duration and its animation options: a linear timing curve
// (@c 3 << 16).
static const NSTimeInterval kDialogFadeDuration = 0.3;
static const UIViewAnimationOptions kDialogFadeOptions = UIViewAnimationOptionCurveLinear;

// The sample loading delay before playback begins.
static const NSTimeInterval kSampleWaitInterval = 0.4000000059604645;

// The background-music fade time used when restoring the pushed BGM.
static const double kBgmRestoreFadeTime = 0.2;

@implementation MissionRewardDownloadView {
    UIImageView *bgView;                          // +0x8
    UIImageView *iconView;                        // +0x10
    UILabel *itemLabel;                           // +0x18
    UILabel *descriptionLabel;                    // +0x20
    SessionDownloader *infoDownloader;            // +0x28
    Downloader *itemDownloader;                   // +0x30
    UIButton *downloadBtn;                        // +0x38
    UIButton *closeBtn;                           // +0x40
    StoreDialogView *downloadDialog;              // +0x48
    ChallengeMissionReward *currentReward;        // +0x50
    UIActivityIndicatorView *indicatorView;       // +0x58
    NSString *itemURL;                            // +0x60
    StoreDownloadManager *musicDlMan;             // +0x68
    NSString *itemPath;                           // +0x70
    UIButton *sampleBtn;                          // +0x78
    UIActivityIndicatorView *sampleIndicatorView; // +0x80
    NSData *sampleData;                           // +0x88
    BOOL samplePlaying;                           // +0x90
    NSTimer *sampleTimer;                         // +0x98
}

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0x1767d0 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;

    // The background plate, centred in the view.
    UIImage *bgImage = LoadScaledPngImage(kBackgroundImageName);
    bgView = [[UIImageView alloc]
        initWithFrame:CGRectMake((frame.size.width - bgImage.size.width) * kHalf,
                                 (frame.size.height - bgImage.size.height) * kHalf,
                                 bgImage.size.width,
                                 bgImage.size.height)];
    [bgView setImage:bgImage];
    [bgView setUserInteractionEnabled:YES];
    [self addSubview:bgView];

    // The reward-item icon, and the per-idiom layout constants that follow it.
    CGFloat iconX = isPad ? 194.0 : 97.0;                 // @ghidraAddress 0x291d10 / 0x293440
    CGFloat iconY = isPad ? 109.0 : 54.0;                 // @ghidraAddress 0x293448 / 0x28f640
    CGFloat iconEdge = isPad ? 160.0 : 80.0;              // fmov 0xa0 / 0x50
    CGFloat labelYFromBottom = isPad ? 80.0 : 40.0;       // @ghidraAddress 0x28f3f8 / 0x28f1f8
    CGFloat labelWidth = isPad ? 412.0 : 204.0;           // @ghidraAddress 0x2929f8 / 0x28f5d0
    CGFloat itemLabelBottomInset = isPad ? 212.0 : 110.0; // @ghidraAddress 0x28f6d8 / 0x28f5e8
    CGFloat itemLabelHeight = isPad ? 26.0 : 20.0;        // fmov 0x403a / 0x4034
    CGFloat itemFontSize = isPad ? 18.0 : 10.0;           // fmov 0x4032 / 0x4024
    CGFloat descriptionLabelGap = isPad ? 186.0 : 93.0;   // @ghidraAddress 0x292a70 / 0x292e50
    CGFloat descriptionHeight = isPad ? 76.0 : 38.0;      // @ghidraAddress 0x292488 / 0x28f4f8
    CGFloat closeX = isPad ? 20.0 : 10.0;                 // fmov 0x4034 / 0x4024
    CGFloat closeCenterY = isPad ? 32.0 : 16.0;           // @ghidraAddress 0x28f458 / fmov 0x4030

    iconView = [[UIImageView alloc] initWithFrame:CGRectMake(iconX, iconY, iconEdge, iconEdge)];
    [bgView addSubview:iconView];

    // The icon's loading spinner, sized to half the icon edge and centred on it. The binary
    // allocates the spinner twice, initialising and framing the first before discarding it for a
    // second built directly with the frame; the reconstruction keeps both allocations.
    CGFloat iconSpinnerEdge = (CGFloat)((unsigned int)iconEdge >> 1);
    indicatorView = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [indicatorView setFrame:CGRectMake(0, 0, iconSpinnerEdge, iconSpinnerEdge)];
    indicatorView = [[UIActivityIndicatorView alloc]
        initWithFrame:CGRectMake(0, 0, iconSpinnerEdge, iconSpinnerEdge)];
    [indicatorView setCenter:CGPointMake(iconSpinnerEdge, iconSpinnerEdge)];
    [indicatorView setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [indicatorView setHidesWhenStopped:YES];
    [iconView addSubview:indicatorView];

    // The download button, centred horizontally near the plate's bottom.
    UIImage *downloadImage = LoadScaledPngImage(kDownloadButtonIdleImageName);
    downloadBtn = [[UIButton alloc]
        initWithFrame:CGRectMake((bgView.frame.size.width - downloadImage.size.width) * kHalf,
                                 bgView.frame.size.height - labelYFromBottom,
                                 downloadImage.size.width,
                                 downloadImage.size.height)];
    [downloadBtn setExclusiveTouch:YES];
    [downloadBtn addTarget:self
                    action:@selector(tapDownload)
          forControlEvents:UIControlEventTouchUpInside];
    [bgView addSubview:downloadBtn];

    // The item-name label, centred on the plate above the description.
    CGFloat labelX = (CGFloat)(int)((bgView.frame.size.width - labelWidth) * kHalf);
    itemLabel =
        [[UILabel alloc] initWithFrame:CGRectMake(labelX,
                                                  bgView.frame.size.height - itemLabelBottomInset,
                                                  labelWidth,
                                                  itemLabelHeight)];
    [itemLabel setTextAlignment:NSTextAlignmentCenter];
    [itemLabel setFont:[UIFont systemFontOfSize:itemFontSize]];
    [bgView addSubview:itemLabel];

    // The three-line description label below the name.
    descriptionLabel =
        [[UILabel alloc] initWithFrame:CGRectMake(labelX,
                                                  bgView.frame.size.height - descriptionLabelGap,
                                                  labelWidth,
                                                  descriptionHeight)];
    [descriptionLabel setTextAlignment:NSTextAlignmentCenter];
    [descriptionLabel setNumberOfLines:kDescriptionLineCount];
    [descriptionLabel setFont:[UIFont systemFontOfSize:itemFontSize]];
    [descriptionLabel setBackgroundColor:UIColor.clearColor];
    [bgView addSubview:descriptionLabel];

    // The close button, its vertical centre a fixed inset from the plate's top-left corner.
    UIImage *closeImage = LoadScaledPngImage(kCloseButtonImageName);
    closeBtn =
        [[UIButton alloc] initWithFrame:CGRectMake(closeX,
                                                   closeCenterY - closeImage.size.height * kHalf,
                                                   closeImage.size.width,
                                                   closeImage.size.height)];
    [closeBtn setBackgroundImage:closeImage forState:UIControlStateNormal];
    [closeBtn addTarget:self
                  action:@selector(tapCloseBtn:)
        forControlEvents:UIControlEventTouchUpInside];
    [closeBtn setExclusiveTouch:YES];
    [bgView addSubview:closeBtn];

    // The progress dialog, sized per idiom and centred on the plate. Its message font size also
    // differs by idiom.
    BOOL dialogIsPad = JubeatAppDelegate.appDelegate.isPad;
    downloadDialog = [StoreDialogView alloc];
    CGFloat dialogWidth;
    CGFloat dialogHeight;
    if (dialogIsPad) {
        dialogWidth = 270.0;  // @ghidraAddress 0x28f2e0
        dialogHeight = 300.0; // @ghidraAddress 0x28f2d0
        downloadDialog = [downloadDialog initWithFrame:CGRectMake(0, 0, dialogWidth, dialogHeight)];
        [downloadDialog.labelMessage setFont:[UIFont systemFontOfSize:18.0]];
    } else {
        dialogWidth = 300.0;  // @ghidraAddress 0x28f2d0
        dialogHeight = 270.0; // @ghidraAddress 0x28f2d8
        downloadDialog = [downloadDialog initWithFrame:CGRectMake(0, 0, dialogWidth, dialogHeight)];
        [downloadDialog.labelMessage setFont:[UIFont systemFontOfSize:16.0]];
    }
    [downloadDialog
        setCenter:CGPointMake(bgView.frame.size.width * kHalf, bgView.frame.size.height * kHalf)];
    [downloadDialog.progressView setProgress:0.0f];
    [downloadDialog setDelegate:self];
    [downloadDialog setAlpha:0.0f];
    [downloadDialog setHidden:YES];
    [downloadDialog layout:NO];
    [bgView addSubview:downloadDialog];

    samplePlaying = NO;
    sampleData = nil;

    // A transparent button laid over the icon that toggles sample playback.
    sampleBtn = [[UIButton alloc] initWithFrame:iconView.frame];
    [sampleBtn addTarget:self
                  action:@selector(tapSample)
        forControlEvents:UIControlEventTouchUpInside];
    [sampleBtn setExclusiveTouch:YES];
    [bgView addSubview:sampleBtn];

    // The sample-loading spinner, sized to half the close-button art and centred on the sample
    // button.
    CGFloat sampleSpinnerWidth = closeImage.size.width * kHalf;
    CGFloat sampleSpinnerHeight = closeImage.size.height * kHalf;
    sampleIndicatorView = [[UIActivityIndicatorView alloc]
        initWithFrame:CGRectMake(0, 0, sampleSpinnerWidth, sampleSpinnerHeight)];
    [sampleIndicatorView setCenter:CGPointMake(sampleBtn.frame.size.width * kHalf,
                                               sampleBtn.frame.size.height * kHalf)];
    [sampleIndicatorView setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [sampleIndicatorView setHidesWhenStopped:YES];
    [sampleBtn addSubview:sampleIndicatorView];

    return self;
}

#pragma mark - Item state

/** @ghidraAddress 0x176534 */
- (BOOL)checkItemDownload {
    switch (currentReward.itemType) {
    case MissionRewardItemTypeStickerFront:
        // The formatted sticker name is built and discarded; the binary does this too.
        [NSString stringWithFormat:kFrontStickerNameFormat, currentReward.itemID];
        return IsAppGroupContainerAvailable();
    case MissionRewardItemTypeStickerAlt:
        [NSString stringWithFormat:kAltStickerNameFormat, currentReward.itemID];
        return IsAppGroupContainerAvailable();
    case MissionRewardItemTypeMusic:
        itemPath = [StoreUtil filePathForMusicID:currentReward.itemID.intValue];
        break;
    case MissionRewardItemTypeMarker: {
        NSString *markerName =
            [NSString stringWithFormat:kMarkerIDFormat, currentReward.itemID.intValue];
        itemPath = [MarkerManager getMarkerPath:markerName];
        break;
    }
    default:
        break;
    }
    return [NSFileManager.defaultManager fileExistsAtPath:itemPath];
}

/** @ghidraAddress 0x177378 */
- (void)setMissionInfo:(ChallengeMissionReward *)reward enableDownload:(BOOL)enableDownload {
    currentReward = reward;
    [iconView setImage:nil];

    UIImage *buttonImage;
    BOOL buttonEnabled;
    if (!enableDownload) {
        buttonImage = LoadScaledPngImage(kDownloadButtonDisabledImageName);
        buttonEnabled = NO;
    } else if ([self checkItemDownload]) {
        buttonImage = LoadScaledPngImage(kDownloadButtonDoneImageName);
        buttonEnabled = NO;
    } else {
        buttonImage = LoadScaledPngImage(kDownloadButtonIdleImageName);
        buttonEnabled = YES;
    }
    [downloadBtn setBackgroundImage:buttonImage forState:UIControlStateNormal];
    [downloadBtn setEnabled:buttonEnabled];

    // Reward kinds 0, 1, and 2 have no downloadable item, so the button is force-disabled.
    int itemType = reward.itemType;
    if (itemType == 0 || itemType == 1 || itemType == 2) {
        [downloadBtn setEnabled:NO];
    }

    [itemLabel setText:reward.rewardName];
    [descriptionLabel setText:reward.rewardDescription];

    // Fetch the reward's icon image.
    NSURL *imageURL = [NSURL URLWithString:reward.rewardImageURL];
    itemDownloader = [[Downloader alloc] initWithURL:imageURL delegate:self];
    [itemDownloader setTag:MissionRewardDownloadTagIcon];
    [itemDownloader startDownloading];
    [indicatorView startAnimating];
}

#pragma mark - Buttons

/** @ghidraAddress 0x177648 */
- (void)tapCloseBtn:(id)sender {
    if (sampleTimer) {
        [sampleTimer invalidate];
        sampleTimer = nil;
    }
    if (samplePlaying) {
        [AudioManager.sharedManager popBgm];
        [AudioManager.sharedManager startBgm:YES fadeTime:kBgmRestoreFadeTime];
        samplePlaying = NO;
    }
    if (infoDownloader) {
        [infoDownloader cancel];
        infoDownloader = nil;
    }
    if (itemDownloader) {
        [itemDownloader cancel];
        itemDownloader = nil;
    }
    if ([self.aDelegate respondsToSelector:@selector(closeRewardWin:)]) {
        [self.aDelegate performSelector:@selector(closeRewardWin:) withObject:sender];
    }
}

/** @ghidraAddress 0x1777fc */
- (void)tapSample {
    if (currentReward.itemType != MissionRewardItemTypeMusic) {
        return;
    }
    if (sampleData == nil) {
        NSURL *infoURL = [StoreUtil musicInfoURL:currentReward.itemID.intValue];
        itemDownloader = [[Downloader alloc] initWithURL:infoURL delegate:self];
        [itemDownloader setTag:MissionRewardDownloadTagSampleInfo];
        [itemDownloader startDownloading];
        [sampleIndicatorView startAnimating];
    } else if (samplePlaying) {
        [AudioManager.sharedManager popBgm];
        [AudioManager.sharedManager startBgm:YES fadeTime:kBgmRestoreFadeTime];
        samplePlaying = !samplePlaying;
    } else {
        [sampleIndicatorView startAnimating];
        sampleTimer = [NSTimer scheduledTimerWithTimeInterval:kSampleWaitInterval
                                                       target:self
                                                     selector:@selector(sampleWait)
                                                     userInfo:nil
                                                      repeats:NO];
    }
}

/** @ghidraAddress 0x177a38 */
- (void)sampleWait {
    [AudioManager.sharedManager pushBgm];
    [AudioManager.sharedManager loadBgmData:sampleData];
    [AudioManager.sharedManager startBgm:YES fadeTime:0.0];
    [sampleIndicatorView stopAnimating];
    samplePlaying = !samplePlaying;
    [sampleTimer invalidate];
    sampleTimer = nil;
}

/** @ghidraAddress 0x177b4c */
- (void)tapDownload {
    NSDictionary *postDictionary = @{kRewardIDKey : @(currentReward.rewardID)};
    NSURL *url = [ScratchUtil getMissionRewardURL];
    infoDownloader = [[SessionDownloader alloc] initWithURL:url
                                             postDictionary:postDictionary
                                                   delegate:self];
    [infoDownloader setTag:MissionRewardDownloadTagInfo];
    [infoDownloader startDownloading];
    [closeBtn setUserInteractionEnabled:NO];
    [downloadBtn setUserInteractionEnabled:NO];
}

#pragma mark - Downloader delegate

/** @ghidraAddress 0x177cf8 */
- (void)downloaderFinished:(Downloader *)downloader {
    switch (downloader.tag) {
    case MissionRewardDownloadTagIcon: {
        UIImage *image = [UIImage imageWithData:[downloader getData]];
        [iconView setImage:image];
        [indicatorView stopAnimating];
        itemDownloader = nil;
        break;
    }
    case MissionRewardDownloadTagInfo: {
        NSDictionary *json = [downloader getDataInJSON];
        if ([json[kStatusKey] intValue] == 0) {
            itemURL = json[kItemURLKey];
            int itemType = currentReward.itemType;
            if ((unsigned int)(itemType - MissionRewardItemTypeMarker) < 3) {
                // Marker (4) and stickers (5, 6): fetch the item body directly.
                NSURL *url = [NSURL URLWithString:itemURL];
                itemDownloader = [[Downloader alloc] initWithURL:url delegate:self];
                [itemDownloader setTag:MissionRewardDownloadTagItem];
                [itemDownloader startDownloading];
                NSString *message =
                    [NSString stringWithFormat:kDownloadingMessageFormat, currentReward.rewardName];
                [downloadDialog setHidden:NO];
                [downloadDialog.labelMessage setText:message];
                [self showDialog];
            } else if (itemType == MissionRewardItemTypeMusic && itemURL != nil) {
                // Music (3): fetch the store music-info payload next.
                NSURL *url = [StoreUtil musicInfoURL:currentReward.itemID.intValue];
                itemDownloader = [[Downloader alloc] initWithURL:url delegate:self];
                [itemDownloader setTag:MissionRewardDownloadTagMusicInfo];
                [itemDownloader startDownloading];
            }
        } else if ([json[kStatusKey] intValue] == kServerSessionErrorStatus) {
            NSString *message = [NSBundle.mainBundle localizedStringForKey:kServerErrorMessageKey
                                                                     value:kLocalizedEmptyValue
                                                                     table:nil];
            if (json[kErrorMessageKey]) {
                message = json[kErrorMessageKey];
            }
            NSString *okButton = [NSBundle.mainBundle localizedStringForKey:kOKButtonKey
                                                                      value:kLocalizedEmptyValue
                                                                      table:nil];
            [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                             delegate:self
                                                  tag:kServerErrorAlertTag
                                                title:kLocalizedEmptyValue
                                                  msg:message
                                               cancel:okButton
                                              btnText:nil
                                                 show:YES];
            return;
        } else {
            [closeBtn setUserInteractionEnabled:YES];
            [downloadBtn setUserInteractionEnabled:YES];
        }
        break;
    }
    case MissionRewardDownloadTagItem: {
        int itemType = currentReward.itemType;
        BOOL succeeded;
        if ((unsigned int)(itemType - MissionRewardItemTypeStickerFront) < 2) {
            // Stickers (5, 6): save the icon into the shared app-group container. The two
            // "s%@"/"as%@" icon names are formatted and discarded, matching the binary.
            NSData *data = [downloader getData];
            [NSString stringWithFormat:kStickerIconFrontFormat, currentReward.itemID];
            if (currentReward.itemType == MissionRewardItemTypeStickerAlt) {
                [NSString stringWithFormat:kStickerIconAltFormat, currentReward.itemID];
            }
            NSString *fileName =
                [NSString stringWithFormat:kStickerFileNameFormat, currentReward.itemID];
            NSString *indexKey =
                [NSString stringWithFormat:kStickerIndexKeyFormat, currentReward.itemID];
            SaveStickerToAppGroupContainer(fileName, indexKey, data);
            succeeded = YES;
        } else if (itemType != MissionRewardItemTypeMarker) {
            succeeded = YES;
        } else {
            // Marker (4): verify the trailing MD5 digest, then install the marker and banner.
            NSData *data = [downloader getData];
            if (data.length <= kMd5DigestLength) {
                succeeded = NO;
            } else {
                unsigned char digest[kMd5DigestLength];
                [data getBytes:digest
                         range:NSMakeRange(data.length - kMd5DigestLength, kMd5DigestLength)];
                NSData *retained = data;
                if (!VerifyMd5Digest(retained.bytes,
                                     (unsigned long)(retained.length - kMd5DigestLength),
                                     digest)) {
                    succeeded = NO;
                } else {
                    NSString *markerID =
                        [NSString stringWithFormat:kMarkerIDFormat, currentReward.itemID.intValue];
                    NSString *savedPath = itemPath;
                    NSString *bannerName = [NSString
                        stringWithFormat:kMarkerBannerFormat,
                                         [markerID
                                             substringWithRange:NSMakeRange(
                                                                    kMarkerIDSubstringLocation,
                                                                    kMarkerIDSubstringLength)]];
                    [MarkerManager saveMarker:data markerID:markerID];
                    [MarkerManager pullOutMarkerBanner:savedPath bannerID:bannerName];
                    NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
                    info[kMarkerIDKey] = markerID;
                    info[kMarkerVersionKey] = kMarkerInfoVersion;
                    info[kMarkerBannerNameKey] = bannerName;
                    [MarkerManager setMarkerInfo:[NSDictionary dictionaryWithDictionary:info]];
                    succeeded = YES;
                }
                if (!succeeded) {
                    NSString *cancel =
                        [NSBundle.mainBundle localizedStringForKey:kCancelButtonKey
                                                             value:kLocalizedEmptyValue
                                                             table:nil];
                    [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                                     delegate:nil
                                                          tag:0
                                                        title:nil
                                                          msg:kItemDownloadFailedMessage
                                                       cancel:cancel
                                                      btnText:nil
                                                         show:YES];
                }
            }
        }
        [closeBtn setUserInteractionEnabled:YES];
        [downloadBtn setUserInteractionEnabled:YES];
        [self hideDialog];
        if (succeeded) {
            UIImage *doneImage = LoadScaledPngImage(kDownloadButtonDoneImageName);
            [downloadBtn setBackgroundImage:doneImage forState:UIControlStateNormal];
            [downloadBtn setEnabled:NO];
        }
        break;
    }
    case MissionRewardDownloadTagMusicInfo: {
        NSDictionary *response = [StoreUtil checkStoreResponse:[downloader getData]];
        if (response == nil) {
            [closeBtn setUserInteractionEnabled:YES];
            [downloadBtn setUserInteractionEnabled:YES];
            break;
        }
        StoreMusicInfo *musicInfo = [[StoreMusicInfo alloc] initWithDictionary:response];
        if (musicInfo != nil) {
            BOOL changed = [StoreMusicListManager.sharedManager addMusic:musicInfo];
            if (musicInfo.extendMusicID != 0) {
                changed = (changed |
                           [StoreMusicListManager.sharedManager addMusic:musicInfo.getExtendInfo]) &
                          1;
            }
            if (changed) {
                [StoreMusicListManager.sharedManager saveMusicList];
            }
            StoreDownloadTask *task = [[StoreDownloadTask alloc] initWithURL:musicInfo.itemURL
                                                                        path:itemPath];
            NSMutableArray *tasks = [NSMutableArray arrayWithObject:task];
            if (musicInfo.extendMusicID != 0) {
                int extendID = [musicInfo.extendItemURL intValue];
                NSString *extendPath = [StoreUtil filePathForMusicID:extendID];
                StoreDownloadTask *extendTask =
                    [[StoreDownloadTask alloc] initWithURL:musicInfo.extendItemURL path:extendPath];
                [tasks addObject:extendTask];
            }
            musicDlMan = [[StoreDownloadManager alloc] initWithTasks:tasks delegate:self];
            [musicDlMan start];
            NSString *message =
                [NSString stringWithFormat:kDownloadingMessageFormat, currentReward.rewardName];
            [downloadDialog setHidden:NO];
            [downloadDialog.labelMessage setText:message];
            [self showDialog];
        }
        break;
    }
    case MissionRewardDownloadTagSampleInfo: {
        NSDictionary *response = [StoreUtil checkStoreResponse:[downloader getData]];
        if (response != nil) {
            StoreMusicInfo *musicInfo = [[StoreMusicInfo alloc] initWithDictionary:response];
            if (musicInfo != nil) {
                itemDownloader = nil;
                NSURL *url = [NSURL URLWithString:musicInfo.sampleURL];
                itemDownloader = [[Downloader alloc] initWithURL:url delegate:self];
                [itemDownloader setTag:MissionRewardDownloadTagSampleAudio];
                [itemDownloader startDownloading];
            }
        }
        break;
    }
    case MissionRewardDownloadTagSampleAudio: {
        sampleData = [downloader getData];
        [AudioManager.sharedManager pushBgm];
        [AudioManager.sharedManager loadBgmData:sampleData];
        [AudioManager.sharedManager startBgm:YES fadeTime:0.0];
        samplePlaying = YES;
        [sampleIndicatorView stopAnimating];
        break;
    }
    default:
        break;
    }
    infoDownloader = nil;
    itemDownloader = nil;
}

/** @ghidraAddress 0x178f60 */
- (void)downloaderError:(Downloader *)downloader {
    int tag = downloader.tag;
    if ((unsigned int)(tag - MissionRewardDownloadTagSampleInfo) < 2 ||
        tag == MissionRewardDownloadTagIcon) {
        UIActivityIndicatorView *spinner =
            (tag == MissionRewardDownloadTagIcon) ? indicatorView : sampleIndicatorView;
        [spinner stopAnimating];
    } else if (tag == MissionRewardDownloadTagItem) {
        [self hideDialog];
        [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                         delegate:nil
                                              tag:0
                                            title:kLocalizedEmptyValue
                                              msg:kItemDownloadFailedMessagePeriod
                                           cancel:kOKButtonLiteral
                                          btnText:nil
                                             show:YES];
    }
    [closeBtn setUserInteractionEnabled:YES];
    [downloadBtn setUserInteractionEnabled:YES];
    infoDownloader = nil;
    itemDownloader = nil;
}

/** @ghidraAddress 0x1790a4 */
- (void)downloaderProceed:(Downloader *)downloader {
    if (downloader.tag == MissionRewardDownloadTagItem) {
        [downloadDialog.progressView setProgress:downloader.currentProgress];
    }
}

#pragma mark - Store dialog delegate

/** @ghidraAddress 0x179130 */
- (void)storeDialogCancel:(StoreDialogView *)dialogView {
    [closeBtn setUserInteractionEnabled:YES];
    [downloadBtn setUserInteractionEnabled:YES];
    if (itemDownloader) {
        [itemDownloader cancel];
        itemDownloader = nil;
    }
    if (musicDlMan) {
        [musicDlMan cancel];
        musicDlMan = nil;
    }
    [self hideDialog];
}

#pragma mark - Dialog animation

/** @ghidraAddress 0x1791e0 */
- (void)showDialog {
    [downloadDialog.indicatorView startAnimating];
    [downloadDialog.buttonAbort setEnabled:NO];
    [downloadDialog.progressView setProgress:0.0f];
    __weak StoreDialogView *weakDialog = downloadDialog;
    [UIView animateWithDuration:kDialogFadeDuration
        delay:0.0
        options:kDialogFadeOptions
        animations:^{
          /** @ghidraAddress 0x1793a0 */
          [weakDialog setAlpha:1.0f];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1793ec */
          [weakDialog.buttonAbort setEnabled:YES];
        }];
}

/** @ghidraAddress 0x179458 */
- (void)hideDialog {
    [AudioManager.sharedManager playSeResFile:kCancelSeName inDirectory:nil];
    [downloadDialog.buttonAbort setEnabled:NO];
    [downloadDialog setDelegate:nil];
    __weak StoreDialogView *weakDialog = downloadDialog;
    [UIView animateWithDuration:kDialogFadeDuration
        delay:0.0
        options:kDialogFadeOptions
        animations:^{
          /** @ghidraAddress 0x179608 */
          [weakDialog setAlpha:0.0f];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x179654 */
          [weakDialog.indicatorView stopAnimating];
        }];
}

#pragma mark - Alert delegate

/** @ghidraAddress 0x1796bc */
- (void)alertSelect:(NSDictionary *)info {
    if ([info[kAlertTagKey] intValue] == kServerErrorAlertTag) {
        [ChallengeStatus.sharedStatus.rootView closeChallengeModeSessionError];
    }
}

#pragma mark - Store download-manager delegate

/** @ghidraAddress 0x17977c */
- (void)downloadManagerStartTask:(StoreDownloadManager *)manager {
}

/** @ghidraAddress 0x179780 */
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager {
    [ChallengeStatus.sharedStatus missionRewardDownload];
    musicDlMan = nil;
    [closeBtn setUserInteractionEnabled:YES];
    [downloadBtn setUserInteractionEnabled:YES];
    [self hideDialog];
    UIImage *doneImage = LoadScaledPngImage(kDownloadButtonDoneImageName);
    [downloadBtn setBackgroundImage:doneImage forState:UIControlStateNormal];
    [downloadBtn setEnabled:NO];
}

/** @ghidraAddress 0x17987c */
- (void)downloadManagerFailed:(StoreDownloadManager *)manager {
    musicDlMan = nil;
    [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                     delegate:nil
                                          tag:0
                                        title:kLocalizedEmptyValue
                                          msg:kItemDownloadFailedMessagePeriod
                                       cancel:kOKButtonLiteral
                                      btnText:nil
                                         show:YES];
    [closeBtn setUserInteractionEnabled:YES];
    [downloadBtn setUserInteractionEnabled:YES];
    [self hideDialog];
}

/** @ghidraAddress 0x17995c */
- (void)downloadManagerProceed:(StoreDownloadManager *)manager {
    [downloadDialog.progressView setProgress:musicDlMan.overallProgress];
}

@end
