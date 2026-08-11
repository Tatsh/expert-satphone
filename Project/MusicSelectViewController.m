#import "MusicSelectViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "AlertViewManager.h"
#import "BFCodec.h"
#import "BalloonView.h"
#import "CJSONSerializer.h"
#import "ChallengeModeRootView.h"
#import "ChallengeStatus.h"
#import "Downloader.h"
#import "EditorIDManager.h"
#import "GameNetworkUtil.h"
#import "JcfDownloadPageNavController.h"
#import "JcfDownloadView.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "LabUtilities.h"
#import "LicenseAgreementView.h"
#import "MarkerManager.h"
#import "MarkerSelectView.h"
#import "Md5Utilities.h"
#import "MusicDetailView.h"
#import "MusicDetailViewKnt.h"
#import "MusicDetailViewOrg.h"
#import "MusicDetailViewRpl.h"
#import "MusicListView.h"
#import "MusicPlaylistManager.h"
#import "MusicPlaylistViewController.h"
#import "MusicSelectBottomView.h"
#import "MusicShareView.h"
#import "MusicView.h"
#import "NSDictionary+PropertyList.h"
#import "NSDictionary+TypedAccessors.h"
#import "NotificationPageNavController.h"
#import "PurchaseManager.h"
#import "PushNotificationView.h"
#import "RecommendNetwork.h"
#import "RootViewController.h"
#import "RotatableNavigationController.h"
#import "ScoreRecord.h"
#import "ScoreRecordManager.h"
#import "ScratchUtil.h"
#import "SearchExpandEditor.h"
#import "SessionDownloader.h"
#import "SettingsNavController.h"
#import "SharePlayManager.h"
#import "StoreDialogView.h"
#import "StoreMusicListManager.h"
#import "StoreUtil.h"
#import "TuneInfo.h"
#import "cipher_keys.h"

extern const double g_dAnimDuration020; // @ghidraAddress 0x28f240 (0.2)

// Landscape-left and landscape-right make up the supported orientation mask.
static const UIInterfaceOrientationMask kSupportedOrientations =
    UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight;

// The custom-BGM selection preferences: the chosen tune's id and whether the custom BGM is on.
static NSString *const kPrefCustomBgmIDKey = @"PrefCustomBgmID";
static NSString *const kPrefCustomBgmOnKey = @"PrefCustomBgmON";

// The advert location the unread-recommendation count is queried for at startup.
static NSString *const kRecommendAdLocationTop = @"ADL_TOP";

// The selected difficulty and edit-page preferences, and whether the extend-chart tutorial overlay
// has been shown once.
static NSString *const kPrefDifficultyKey = @"PrefDifficulty";
static NSString *const kPrefEditSelectKey = @"PrefEditSelect";
static NSString *const kPrefExtendTutorialFinishKey = @"PrefExtendTutorialFinish";

// Opening a tune shows the extend-chart tutorial overlay sized to the artwork times a per-idiom
// factor (pad 3.75, phone 4.0), positioned at the difficulty's slot minus a per-theme, per-idiom
// inset from a 3x2 table; a preselected edit page counts as difficulty select.
static const CGFloat kExtendTutorialArtworkScalePad = 3.75;  // fmov, 3.75
static const CGFloat kExtendTutorialArtworkScalePhone = 4.0; // fmov, 4.0
static const int kEditSelectActive = 1;
// Opening a tune's detail panel plays this cue and fades the extend tutorial overlay in over this
// duration.
static NSString *const kMusicSelectDetailSoundSuffix = @"MUSIC_SELECT";
static const NSTimeInterval kExtendTutorialShowDuration = 0.2; // @ghidraAddress 0x28e040
// g_anExtendTutorialOffsetByThemeAndDevice at 0x28f3d0: [theme][isPad ? 0 : 1] (indexed isPad ^ 1).
static const int kExtendTutorialInsetByThemeAndDevice[][2] = {
    {14, 8},  // original: pad, phone
    {28, 10}, // ripples: pad, phone
    {22, 9},  // knit: pad, phone
};

// The not-yet-played list is built by querying score records in batches of this many tunes, with an
// initial capacity that also allows for each tune's extend-music alias. A one-off migration under
// this preference clears a stale full-combo-check flag; a store-music entry's real id lives under
// this dictionary key, and the not-played array keeps only tunes absent from the played set.
static const NSUInteger kNotYetPlayedBatchSize = 15;
static const NSUInteger kNotYetPlayedBatchCapacity = 32;
static const NSUInteger kNotYetPlayedRecordCapacity = 16;
static NSString *const kPrefFcCheckFlagV2Key = @"PrefFcCheckFlagV2";
static NSString *const kStoreMusicIDKey = @"ID";
static NSString *const kNotYetPlayedPredicateFormat = @"NOT (tuneID IN %@)";

// The music catalogue is loaded from the bundled Music folder (built-in tunes named "<id>.jbt")
// plus purchased and extend tunes on disk; a metadata cache under the caches directory records each
// purchased tune's file size and timestamp so unchanged files skip a re-parse. Search terms are
// normalised (spaces stripped, hiragana to katakana, fullwidth to halfwidth), and the playlists are
// loaded from this document. The extend-music flag marks a tune as an extend chart.
static const NSUInteger kMusicListInitialCapacity = 256;
static const NSUInteger kMusicCacheInitialCapacity = 64;
static NSString *const kBuiltinMusicResourceName = @"Music";
static NSString *const kBuiltinMusicResourceType = @"";
static NSString *const kBuiltinMusicFileFormat = @"%d.jbt";
static NSString *const kMusicIDFormat = @"%d";
static NSString *const kMusicCacheFileName = @"musiccache";
static NSString *const kMusicCacheFileSizeKey = @"filesize";
static NSString *const kMusicCacheTimestampKey = @"timestamp";
static NSString *const kMusicExtendFlagKey = @"extendFlag";
static NSString *const kPlaylistsFileName = @"playlists.plist";
static NSString *const kSearchTermSpace = @" ";
static NSString *const kSearchTermEmpty = @"";

// Tapping a push notification posts a read-response to the scratch server carrying the editor id,
// the notification's push id, and this "tapped" status, keyed under these names.
static NSString *const kPushResponseUserIDKey = @"user_id";
static NSString *const kPushResponsePushIDKey = @"push_id";
static NSString *const kPushResponseStatusKey = @"status";
static NSString *const kPushURLKey = @"url";
static NSString *const kPushIDKey = @"id";
static const int kPushResponseStatusTapped = 3;
// The notification URL's own scheme selects the store or challenge flow; a store URL path of
// /pack/<id> or /genre/<id> turns to that store target.
static NSString *const kPushSchemeStore = @"jbtstore";
static NSString *const kPushSchemeChallenge = @"jbtchallenge";
static NSString *const kPushStorePackComponent = @"pack";
static NSString *const kPushStoreGenreComponent = @"genre";
static const NSUInteger kPushStorePathComponentCount = 3;

// The menu BGM resumes with a one-fifth-second fade in when the app comes back to the foreground.
static const double kMenuBgmResumeFade = 0.2; // @ghidraAddress 0x28e040

// The extend-mode tutorial overlay fades out over this (negative, as the binary passes it)
// duration when the mode changes.
static const NSTimeInterval kExtendTutorialFadeDuration = -0.2; // @ghidraAddress 0x28e050

// The store-tap and challenge-tap sounds are looked up by these sound keys.
static NSString *const kStoreTapSoundKey = @"OK";
static NSString *const kChallengeTapSoundKey = @"MUSIC_SELECT";

// The challenge-mode root view sits on top of the menu at this layer z-position.
static const CGFloat kChallengeRootViewZPosition = 4000.0; // @ghidraAddress 0x28f238

// The challenge cover fades out over this duration.
static const NSTimeInterval kChallengeCoverFadeDuration = 0.3; // @ghidraAddress 0x28f260

// Layout constants used only while building the screen in -loadView. Several are indexed by device
// idiom (isPad) or theme.
// On the retina phone the still background image sits 44 points up.
static const double kBgImageYRetina = -44.0; // @ghidraAddress 0x28f1d0
// The music list's top inset (pad 60 / phone 55) and the height it leaves for the bottom controls.
static const double kMusicListTopPad = 60.0;   // @ghidraAddress 0x28f2f8
static const double kMusicListTopPhone = 55.0; // @ghidraAddress 0x28f2f0
// The marker-select panel and its cover: the panel is a square (pad 500 / phone 250) sitting off
// the top, at a per-idiom width table, on a very high layer.
static const double kMarkerSelectYPad = 400.0;   // @ghidraAddress 0x28f308
static const double kMarkerSelectYPhone = 200.0; // @ghidraAddress 0x28f300
static const CGFloat kMarkerZPosition = 3500.0;  // @ghidraAddress 0x28f1e8
static const double kMarkerBannerWidth = 64.0;   // @ghidraAddress 0x28f1f0
static const double kMarkerBannerHeight = 40.0;  // @ghidraAddress 0x28f1f8
// The hidden far-open helper music view: origin size per idiom and device, artwork per idiom.
static const double kFarOpenYRetina = 100.0;     // @ghidraAddress 0x28f310
static const double kFarOpenXRetina = 106.0;     // @ghidraAddress 0x28f320
static const double kFarOpenX4Inch = 101.0;      // @ghidraAddress 0x28f328
static const double kFarOpenArtworkPad = 160.0;  // @ghidraAddress 0x28f338
static const double kFarOpenArtworkPhone = 80.0; // @ghidraAddress 0x28f330
// The store "new" badge is rotated by this angle (radians).
static const CGFloat kStoreNewRotation = -0.376991110004367; // @ghidraAddress 0x28f208
// The detail-card dimming cover alpha.
static const CGFloat kCoverAlpha = 0.5;
// The playlist list-type sentinels used when no saved playlist matches.
static const NSInteger kListTypeLevel = -10;
static const NSInteger kListTypeHold = -11;
static const NSInteger kListTypeNotHold = -12;
static const NSInteger kListTypeNotPlayed = -2;
// The store-promotion balloon: width, per-idiom height, per-idiom horizontal offset from the store
// button, and its layer shadow.
static const double kBalloonWidth = 120.0;       // @ghidraAddress 0x28f210
static const double kBalloonHeightPad = 290.0;   // @ghidraAddress 0x28f348
static const double kBalloonHeightPhone = 210.0; // @ghidraAddress 0x28f340
static const double kBalloonXPad = 200.0;        // @ghidraAddress 0x28f358
static const double kBalloonXPhone = 280.0;      // @ghidraAddress 0x28f350
static const CGFloat kBalloonShadowRadius = 3.0; // fmov, 3.0
static const float kBalloonShadowOpacity = 0.9f; // @ghidraAddress 0x28f3b0
// The search bar's fixed height and pad width, and its cancel-button inset (pad 98 / phone 48).
static const double kSearchBarWidth = 670.0;  // @ghidraAddress 0x28f218
static const double kSearchBarHeight = 52.0;  // @ghidraAddress 0x28f220
static const double kSearchInsetPad = 98.0;   // @ghidraAddress 0x28f368
static const double kSearchInsetPhone = 48.0; // @ghidraAddress 0x28f360
// The search and extend tutorial overlays sit at this alpha and layer, above everything.
static const CGFloat kTutorialAlpha = 0.6;        // @ghidraAddress 0x28f230
static const CGFloat kTutorialZPosition = 4000.0; // @ghidraAddress 0x28f238
// The extend-tutorial description image sits at these fractions of the frame.
static const double kExtendDescXFraction = 0.3;  // @ghidraAddress 0x28f248
static const double kExtendDescYFraction = 0.72; // @ghidraAddress 0x28f250
// The push-token registration downloader carries this tag.
static const NSInteger kPushIDDownloaderTag = 4;
// The notification banner: per-idiom width (pad 640 / phone 320) and fixed height.
static const int kNotifyWidthPad = 640;   // 0x280
static const int kNotifyWidthPhone = 320; // 0x140
static const double kNotifyHeight = 60.0; // @ghidraAddress 0x28f258

// The challenge cover is a 40%-opaque black overlay carrying a 50-point activity indicator centred
// in it, and a one-second load-timeout timer.
static const CGFloat kChallengeCoverBackgroundAlpha = 0.4; // @ghidraAddress 0x28f2c0
static const CGFloat kChallengeIndicatorSize = 50.0;       // @ghidraAddress 0x28f2c8
static const NSTimeInterval kChallengeLoadTimeout = 1.0;   // fmov, 1.0

// The purchase-verify dialog is a fixed-size box (pad 400x300 with an 18-point message font, phone
// 300x270 with 16-point) centred over the challenge cover, its progress bar reset and its abort
// button hidden, and it fades in over the cover-fade duration.
static const CGFloat kVerifyDialogWidthPad = 400.0;     // @ghidraAddress 0x28f2e0
static const CGFloat kVerifyDialogHeightPad = 300.0;    // @ghidraAddress 0x28f2d0
static const CGFloat kVerifyDialogWidthPhone = 300.0;   // @ghidraAddress 0x28f2d0
static const CGFloat kVerifyDialogHeightPhone = 270.0;  // @ghidraAddress 0x28f2d8
static const CGFloat kVerifyDialogFontSizePad = 18.0;   // fmov, 18.0
static const CGFloat kVerifyDialogFontSizePhone = 16.0; // fmov, 16.0

// The store update-time preference records the newest seen store timestamp.
static NSString *const kPrefStoreUpdateTimeKey = @"PrefStoreUpdateTime";

// The store-new and challenge-new badges blink their opacity between these bounds over this
// duration, auto-reversing and repeating forever with a linear curve, under this animation key.
static NSString *const kStoreNewBlinkAnimationKey = @"STORE_NEW_BLINK_ANIM";
static NSString *const kStoreNewBlinkKeyPath = @"opacity";
static const NSTimeInterval kStoreNewBlinkDuration = 0.4; // @ghidraAddress 0x28f268
static const float kStoreNewBlinkFromOpacity = 0.2;       // @ghidraAddress 0x28f3c8

// The challenge-info download response carries a status code and, for the store info, an update
// time, update-text comments, and a scratch id under these keys; the challenge flow uses these
// preferences and post-body keys, and its downloader carries these api tags.
static NSString *const kChallengeUpdateTimeKey = @"UpdateTime";
static NSString *const kChallengeUpdateTextKey = @"UpdateText";
static NSString *const kChallengeScratchIDKey = @"ScratchId";
static NSString *const kPrefTotalPurchaseKey = @"PrefTotalPurchase";
static NSString *const kPrefPurchaseLimitTypeKey = @"PrefPurchaseLimitType";
static NSString *const kChallengeTotalPurchaseBodyKey = @"sum";
static NSString *const kChallengeAgeBodyKey = @"age";
static const int kChallengeDownloaderApiTagAge = 2;
static const int kChallengeDownloaderApiTagTotalPurchase = 3;

// The finished-download handler switches on the downloader's tag: the store info banner, the
// challenge initialise, the age registration, the total-purchase registration, or a push-id send.
enum {
    kDownloaderTagStoreInfo = 0,
    kDownloaderTagChallengeInit = 1,
    kDownloaderTagAgeRegist = 2,
    kDownloaderTagTotalPurchaseRegist = 3,
    kDownloaderTagPushIDSend = 4,
};

// The scratch (challenge) content update id preference; the challenge-new badge hides once the seen
// id catches up. The BGM fades out over this duration when launching challenge mode.
static NSString *const kPrefScratchUpdateIDKey = @"PrefScratchUpdateID";
static const double kChallengeBgmFadeOut = 0.5; // fmov, 0.5

// The marker button slides up out of view (or back) over this duration while the search box is
// lifted to sit above it at this z-position.
static const NSTimeInterval kButtonMarkerAnimDuration = 0.3; // @ghidraAddress 0x28f260
static const CGFloat kSearchBoxRaisedZPosition = 4000.0;     // @ghidraAddress 0x28f238

// The last-played tune id preference, used to bias the shuffle away from an immediate repeat.
static NSString *const kPrefLastPlayedIDKey = @"PrefLastPlayedID";

// The remembered playlist identifier and level-playlist flag preferences, and the new-info request
// URL query format.
static NSString *const kPrefLastPlaylistKey = @"PrefLastPlaylist";
static NSString *const kPrefPlayListLevelKey = @"PrefPlayListLevel";
static NSString *const kPrefPlayListHoldKey = @"PrefPlayListHold";
static NSString *const kNewInfoUserIDFormat = @"&userid=%@";
static NSString *const kNewInfoURLConcatFormat = @"%@%@";

// The marker-select view is a square (500 on the pad, 250 on the phone) hidden above the top of the
// screen, its width taken from a per-idiom pool value, sitting at this z-position.
static const CGFloat kMarkerSelectSizePad = 500.0;    // fmov via w, 500
static const CGFloat kMarkerSelectSizePhone = 250.0;  // fmov via w, 250
static const CGFloat kMarkerSelectWidthPad = 400.0;   // @ghidraAddress 0x28f308
static const CGFloat kMarkerSelectWidthPhone = 200.0; // @ghidraAddress 0x28f300
static const CGFloat kMarkerSelectZPosition = 3500.0; // @ghidraAddress 0x28f1e8

// Opening the marker-select overlay slides the overlay and marker button down by a per-idiom
// offset (phone 250, pad 500) while fading the cover in, over this duration; closing it reverses
// that over this shorter duration and unlocks interaction after this delay.
static const CGFloat kMarkerSelectSlideOffsetPhone = 250.0;   // @ghidraAddress 0x28f3a0
static const CGFloat kMarkerSelectSlideOffsetPad = 500.0;     // @ghidraAddress 0x28f3a8
static const NSTimeInterval kMarkerSelectOpenDuration = 0.25; // fmov, 0.25
static const NSTimeInterval kMarkerSelectCloseDuration = 0.2; // @ghidraAddress 0x28e040
static const NSTimeInterval kMarkerSelectUnlockDelay = 0.3;   // @ghidraAddress 0x28f260
static NSString *const kMarkerSelectOpenSoundSuffix = @"MUSIC_RIGHT";
static NSString *const kMarkerSelectCloseSoundSuffix = @"MUSIC_LEFT";

// Encoded strings decode as UTF-8.
static const NSStringEncoding kLabURLEncoding = NSUTF8StringEncoding;
static NSString *const kPrefJubeatLabURLKey = @"PrefjubeatLabURL";

// A received share payload appends a 16-byte MD5 digest over the preceding music data.
static const NSUInteger kShareMusicDigestLength = 16;

// The challenge-connect response carries a status code and an optional error message under these
// keys; two status codes are handled specially (an update prompt and a no-open-scratch message).
static NSString *const kChallengeStatusKey = @"status";
static NSString *const kChallengeErrorMessageKey = @"err_message";
static const int kChallengeStatusUpdateRequired = 100011;
static const int kChallengeStatusNoScratch = 205103;
static NSString *const kChallengeNoScratchMessage =
    @"現在開催されているチャレンジスクラッチは存在しません";

// The tune-info archive members, tried newest-first; the v3 payload is ciphered with the tune-info
// key and carries a four-byte header, the older members with the BGM key. Each archive skips a
// 16-byte trailer.
static NSString *const kInfoV3EntryName = @"infov3";
static NSString *const kInfoV2EntryName = @"infov2";
static NSString *const kInfoEntryName = @"info";
static const NSUInteger kTuneInfoArchiveTail = 16;
static const NSUInteger kTuneInfoV3HeaderLength = 4;

// A tune's own archive stores its BGM under this member (ciphered with the BGM key).
static NSString *const kTuneBgmEntryName = @"index";

// The join share view is a fixed size (pad 360x400, phone 300x360) centred on the screen and fades
// in over this duration.
static const CGFloat kJoinViewWidthPad = 360.0;          // @ghidraAddress 0x28f380
static const CGFloat kJoinViewHeightPad = 400.0;         // @ghidraAddress 0x28f390
static const CGFloat kJoinViewWidthPhone = 300.0;        // @ghidraAddress 0x28f388
static const CGFloat kJoinViewHeightPhone = 360.0;       // @ghidraAddress 0x28f398
static const NSTimeInterval kJoinViewFadeDuration = 0.2; // @ghidraAddress 0x28e040
static NSString *const kJoinSoundSuffix = @"MUSIC_SELECT";

// Cancelling a client share plays this cue and fades the share views out over the join duration.
static NSString *const kShareCancelSoundSuffix = @"SKIP";

// When the last-played tune sits on an earlier page, the stand-in detail music view is parked this
// many screen widths off to the left of centre so it slides in from that side.
static const CGFloat kDetailPanelOffscreenDirection = -4.0; // fmov, -4.0

// A received shared-music payload flips the detail view in over this duration and fades the BGM out
// over the detail-close fade; the connected/receiving prompts are these localised strings.
static const NSTimeInterval kShareReceiveFadeInDuration = 0.4; // @ghidraAddress 0x28f2a8
static NSString *const kShareReceivingMessageKey = @"Receiving music data";
static NSString *const kShareConnectedMessageFormatKey = @"Connected to %@";
// A received music-info dictionary carries the ciphered BGM data under this key when the client
// does not already own the tune.
static NSString *const kShareMusicInfoIndexKey = @"index";

// Closing the detail view fades the BGM out over this, flips the cover shut over this longer
// duration, restores the rank backgrounds after this delay and then the name and artist labels,
// and unlocks interaction after this final delay.
static const CGFloat kDetailCloseBgmFadeOut = 0.45;           // @ghidraAddress 0x28f280
static const NSTimeInterval kDetailCloseFlipDuration = 0.6;   // @ghidraAddress 0x28f288
static const NSTimeInterval kDetailCloseRankBgDuration = 0.1; // @ghidraAddress 0x28f290
static const NSTimeInterval kDetailCloseRankBgDelay = 0.7;    // @ghidraAddress 0x28f2a0
static const NSTimeInterval kDetailCloseLabelDuration = 0.3;  // @ghidraAddress 0x28f260
static const NSTimeInterval kDetailCloseLabelDelay = 0.3;     // @ghidraAddress 0x28f260
static const NSTimeInterval kDetailCloseUnlockDelay = 0.8;    // @ghidraAddress 0x28e060
static const NSTimeInterval kDetailCloseBgmRestartFade = 0.2; // @ghidraAddress 0x28e040

// The rating-chip display preference gates the rank-background restore: 0 restores nothing, 2 also
// restores the individual chips, any other value restores the six named backgrounds only.
static NSString *const kPrefRatingChipTypeKey = @"PrefRatingChipType";
static const int kRatingChipTypeNone = 0;
static const int kRatingChipTypeWithChips = 2;

// The shuffle animation fades the BGM out over this and plays the themed music-select cue. It runs
// as a slide (this duration) that pushes the detail view aside, then a flip whose whole duration is
// divided into thirds for the middle stage that swaps the tune data while the cover is edge-on.
static const CGFloat kShuffleBgmFadeOut = 0.075;         // @ghidraAddress 0x28f2b0
static const NSTimeInterval kShuffleSlideDuration = 0.1; // @ghidraAddress 0x28f2b8
static const CGFloat kShuffleFlipDuration = 0.1;         // fmov (float), 0.1
static const CGFloat kShuffleFlipStageDivisor = 3.0;     // fmov, 3.0
static NSString *const kShuffleSoundSuffix = @"MUSIC_SELECT";
// The detail view slides left by this many points; the pad slides 86, the phone 20.
static const int kShuffleSlideOffsetPad = 86;
static const int kShuffleSlideOffsetPhone = 20;

// The cover-flip 3D pose: a perspective m34 of -1/1000, a viewer distance that differs by idiom
// (iPhone 750, iPad 733.3333), a rotation of pi about the vertical axis for the front face and 2*pi
// for the back, and a shrink to a quarter (iPhone) or roughly a quarter (iPad).
static const CGFloat kCoverFlipPerspectiveM34 = -0.0010000000474974513; // movk, -1/1000
static const CGFloat kCoverFlipViewerDistancePhone = 750.0;             // @ghidraAddress 0x28f370
static const CGFloat kCoverFlipViewerDistancePad = 733.3333740234375;   // @ghidraAddress 0x28f378
static const CGFloat kCoverFlipScalePad = 0.2666666805744171;           // @ghidraAddress 0x28f270
static const CGFloat kCoverFlipScalePhone = 0.25;                       // fmov, 0.25
static const CGFloat g_dPi = 3.141592653589793;                         // @ghidraAddress 0x28f278
static const CGFloat g_dTwoPi = 6.283185307179586;                      // @ghidraAddress 0x28f298

// The custom-BGM archive member (ciphered with the BGM key, skipping the 16-byte trailer), the
// default menu BGM resource suffix, and the store-balloon animation key.
static NSString *const kCustomBgmEntryName = @"bgm";
static NSString *const kMenuBgmSoundSuffix = @"BGM_MENU";
static NSString *const kStoreBalloonAnimationKey = @"STORE_BALLOON_ANIM";

// The main BGM starts with this fade, and the store balloon fades out over the same duration.
static const NSTimeInterval kMainBgmStartFade = 0.3;         // @ghidraAddress 0x28f260
static const NSTimeInterval kStoreBalloonFadeDuration = 0.3; // @ghidraAddress 0x28f260

// Re-showing the store balloon nudges it down by this offset, then fades and re-runs its looping
// double-bounce hop animation over this duration.
static const CGFloat kStoreBalloonRetryDropOffset = 10.0;     // fmov, 10.0
static const NSTimeInterval kStoreBalloonRetryDuration = 0.8; // @ghidraAddress 0x28e060
static NSString *const kStoreBalloonAnimationKeyPath = @"transform.translation.y";
// The balloon rests for the first 40% of each five-second cycle, then performs two four-point
// upward hops before resting again; the animation repeats effectively forever.
static const CGFloat kStoreBalloonAnimationDuration = 5.0; // fmov, 5.0
static const CGFloat kStoreBalloonHopOffset = -4.0;        // fmov, -4.0
static const float kStoreBalloonRepeatForever = 1e30f;     // @ghidraAddress 0x28f3c4
static const CGFloat kStoreBalloonKeyTime040 = 0.4;        // @ghidraAddress 0x28f3b4
static const CGFloat kStoreBalloonKeyTime050 = 0.5;        // fmov, 0.5
static const CGFloat kStoreBalloonKeyTime060 = 0.6;        // @ghidraAddress 0x28f3b8
static const CGFloat kStoreBalloonKeyTime070 = 0.7;        // @ghidraAddress 0x28f3bc
static const CGFloat kStoreBalloonKeyTime080 = 0.8;        // @ghidraAddress 0x28f3c0

// The JCF download view and its cover fade out over this (negative, as the binary passes it)
// duration when the download completes.
static const NSTimeInterval kJcfDownloadEndFadeDuration = -0.2; // @ghidraAddress 0x28e050

// Closing the search box slides it and its cancel button up by this offset over this duration,
// playing the themed left cue.
static const NSTimeInterval kSearchBoxSlideDuration = 0.1; // @ghidraAddress 0x28f290
static const CGFloat kSearchBoxSlideOffset = -52.0;        // @ghidraAddress 0x28f228
static NSString *const kSearchBoxCloseSoundSuffix = @"MUSIC_LEFT";

// The first time the search box is opened, its tutorial overlay is shown once and this preference
// records that it has been seen.
static NSString *const kPrefSearchTutorialFinishKey = @"PrefSearchTutorialFinish";

// Completing a challenge-purchase restore records this marker under the restore-end preference and
// shows the completion alert (tag 3).
static NSString *const kRestoreCompleteMarker = @"Restore Complete";
static NSString *const kPrefChallengeRestoreEndKey = @"PrefChallengeRestoreEnd";
static const int kRestoreCompleteAlertTag = 3;

// Turning to the store while a consume receipt is pending records this verify-purchase type and
// shows the verify dialog; a completed purchase reports the shared success message. The
// challenge-info download path uses the other pending type.
static const int kVerifyPurchaseTypeStore = 2;
static const int kVerifyPurchaseTypeChallenge = 1;

// The challenge-info download reads the current marker into the client-info payload, gates on the
// challenge-policy agreement recorded under this defaults key, and requires the purchased packs to
// have been restored before it will run.
static NSString *const kPrefCurrentMarkerIDKey = @"PrefCurrentMarkerID";
static NSString *const kClientInfoMarkerIDKey = @"markerID";
static NSString *const kPrefAgreeChallengePolicyVersionKey = @"PrefAgreeChallengePolicyVersion";
static NSString *const kChallengePolicyRestoreRequiredMessage =
    @"チャレンジモードをプレイする前に、購入パックの復元を行う必要があります";

// The challenge-info request's apiTag: a full initialise before the challenge state is loaded, or a
// simple re-initialise once it already is. The downloader itself carries the challenge tag.
enum {
    kChallengeApiTagInitialize = 2,
    kChallengeApiTagSimpleInitialize = 3,
};
static const int kChallengeInfoDownloaderTag = 1;
static NSString *const kPurchaseSuccessMessage = @"購入処理が完了しました";
static NSString *const kSettingsTapSoundSuffix = @"MUSIC_RIGHT";
static NSString *const kVerifyProcessingMessage = @"処理中...";
static NSString *const kRestoreProcessingMessage = @"復元中...";

// The alert-select dictionary carries the tapped alert's tag and button index under these keys; the
// tags select the challenge-info download, the restore, the store/challenge retry, or a share
// cancel.
static NSString *const kAlertTagKey = @"Tag";
static NSString *const kAlertButtonMessageKey = @"btnMessage";
enum {
    kAlertTagShareCancel = 0,
    kAlertTagRetry = 1,
    kAlertTagRestore = 2,
    kAlertTagChallengeInfo = 3,
};

// The main BGM start voice cue, and the fixed music cues used when closing the web view or opening
// the notification (the binary hardcodes the Knit-theme resources for these).
static NSString *const kMainBgmVoiceSuffix = @"CV_MUSICSELECT";
static NSString *const kWebViewCloseSound = @"SD_KNT_MUSIC_LEFT";
static NSString *const kNotificationOpenSound = @"SD_KNT_MUSIC_RIGHT";

// The built-in playlist selections map to these sentinel indices in the playlist view controller.
enum {
    kPlaylistSelectionLevel = -10,
    kPlaylistSelectionHold = -11,
    kPlaylistSelectionNotHold = -12,
    kPlaylistSelectionNotPlayed = -1,
    kPlaylistSelectionDefault = -2,
};

// A tune matches a level when any of its three chart levels equals it, or its extend chart (looked
// up by extendID) has a matching level.
static BOOL MusicSelectTuneHasLevel(MusicSelectViewController *self, TuneInfo *tune, int level) {
    if ((int)tune.lvAdv == level || (int)tune.lvBas == level || (int)tune.lvExt == level) {
        return YES;
    }
    if (tune.extendID != 0) {
        TuneInfo *extend = self->dictAllExtendTune[@(tune.extendID)];
        if ((int)extend.lvAdv == level || (int)extend.lvBas == level ||
            (int)extend.lvExt == level) {
            return YES;
        }
    }
    return NO;
}

// A tune counts as a hold chart when its own hold flag is set or its extend chart (looked up by
// extendID) has a hold flag.
static BOOL MusicSelectTuneIsHold(MusicSelectViewController *self, TuneInfo *tune) {
    if (tune.holdFlag != 0) {
        return YES;
    }
    if (tune.extendID != 0) {
        TuneInfo *extend = self->dictAllExtendTune[@(tune.extendID)];
        if (extend.holdFlag != 0) {
            return YES;
        }
    }
    return NO;
}

// The store-new / challenge-new badges share one opacity-blink animation; build it once here.
static CABasicAnimation *MusicSelectMakeNewBadgeBlinkAnimation(void) {
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:kStoreNewBlinkKeyPath];
    animation.duration = kStoreNewBlinkDuration;
    animation.fromValue = @(kStoreNewBlinkFromOpacity);
    animation.toValue = @(1.0f);
    animation.autoreverses = YES;
    animation.repeatCount = HUGE_VALF;
    animation.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    animation.removedOnCompletion = NO;
    return animation;
}

@implementation MusicSelectViewController

@synthesize sharePlayManager = _sharePlayManager;

#pragma mark - Lifecycle

/** @ghidraAddress 0x207b4 */
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        (void)NSFileManager.defaultManager; // Yes, the binary discards this call's result.
        isPad = JubeatAppDelegate.appDelegate.isPad;
        isRetina = JubeatAppDelegate.appDelegate.isPhoneRetina;
        isPadRetina = JubeatAppDelegate.appDelegate.isPadRetina;
        willStart = NO;
        mainBgmSuspended = NO;
        bOpenDelegateCover = NO;
        bOpenModal = NO;
        bOpenMusicDetail = NO;
        bSuffleAnim = NO;
        [self musicShuffleEnable];
        NSString *searchString = JubeatAppDelegate.appDelegate.searchString ?: @"";
        searchArray = [NSMutableArray arrayWithArray:[self getSearchArray:searchString]];
        [self refreshMusicList];
        settingsNavCtrl = [[SettingsNavController alloc] init];
        [settingsNavCtrl setSettingsDelegate:self];
        jcfDLPageViewController = nil;
        notificationViewController = nil;
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserver:self
                   selector:@selector(appSuspended:)
                       name:UIApplicationDidEnterBackgroundNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(appResumed:)
                       name:UIApplicationWillEnterForegroundNotification
                     object:nil];
        [self checkLabURL];
        [JubeatAppDelegate.appDelegate setHasNewRecommendNum:0];
        [RecommendNetwork
            getUnreadCountWithAdModel:RecommendAdModelAppList
                           adLocation:kRecommendAdLocationTop
                             callback:^(NSInteger status, NSError *error) {
                               /** @ghidraAddress 0x20bf8 */
                               if (error != nil) {
                                   NSLog(@"error=%@", error);
                                   return;
                               }
                               NSLog(@"unreadCount=%d", (int)status);
                               [JubeatAppDelegate.appDelegate setHasNewRecommendNum:(int)status];
                             }];
        challengeCoverView = nil;
        checkPolicy = NO;
        missionTasks = nil;
        // The binary discards these three URL results; the calls prime the network utility.
        (void)GameNetworkUtil.scoreSendURL;
        (void)GameNetworkUtil.recommendEnableURL;
        (void)GameNetworkUtil.rewardEnableURL;
    }
    return self;
}

/** @ghidraAddress 0x22e78 */
- (void)loadView {
    JubeatTheme theme = JubeatAppDelegate.appDelegate.currentTheme;
    [super loadView];
    self.view.contentScaleFactor = UIScreen.mainScreen.scale;
    [self.view setClipsToBounds:YES];
    [self.view setAutoresizesSubviews:YES];
    [self.view
        setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    CGRect bounds = UIScreen.mainScreen.bounds;
    double boundsWidth = bounds.size.width;
    double boundsHeight = bounds.size.height;
    [JubeatAppDelegate.appDelegate moveChallengeOpenFlag];

    // The card background is theme-specific: the reflec-beat and knit themes use a full-screen
    // background image (with Naga Cora and Hinabita variants for the reflec-beat theme), while the
    // classic theme uses a device-specific texture over black.
    if (theme == JubeatThemeReflecBeatPlus) {
        [self.view setBackgroundColor:UIColor.whiteColor];
        bgImageView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(@"msel_bg_rpl")];
        if (JubeatAppDelegate.appDelegate.deviceType == JubeatDeviceTypePhoneRetina) {
            [bgImageView setFrame:CGRectMake(0.0,
                                             kBgImageYRetina,
                                             bgImageView.frame.size.width,
                                             bgImageView.frame.size.height)];
        }
    } else if (theme == JubeatThemeKnit) {
        [self.view setBackgroundColor:UIColor.whiteColor];
        bgImageView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(@"msel_bg_knt")];
        if (JubeatAppDelegate.appDelegate.isNagaCoraMode) {
            // The Naga Cora skin swaps the background for a device-specific encrypted texture.
            UIImage *nagaImage =
                (JubeatAppDelegate.appDelegate.deviceType == JubeatDeviceTypePhoneRetina) ?
                    LoadScaledEncryptedTexImage(@"select_back35") :
                    LoadScaledEncryptedTexImage(@"select_back");
            bgImageView = [[UIImageView alloc] initWithImage:nagaImage];
        }
        if (JubeatAppDelegate.appDelegate.isHinabitaMode) {
            // The Hinabita skin replaces the still background with a non-scrolling five-page strip.
            bgImageView = nil;
            scrollBg = [[UIScrollView alloc] initWithFrame:self.view.bounds];
            int pageWidth = (int)scrollBg.frame.size.width;
            NSArray *hinaNames = @[
                @"select_back_hina01",
                @"select_back_hina02",
                @"select_back_hina03",
                @"select_back_hina04",
                @"select_back_hina05"
            ];
            scrollPageNum = (int)hinaNames.count;
            for (int i = 0; i <= scrollPageNum; ++i) {
                NSString *name = hinaNames[i % scrollPageNum];
                UIImageView *page;
                if (JubeatAppDelegate.appDelegate.deviceType == JubeatDeviceTypePhoneRetina) {
                    page = [[UIImageView alloc] initWithImage:LoadScaledPngImage(name)];
                    [page setFrame:CGRectMake(0.0,
                                              kBgImageYRetina,
                                              page.frame.size.width,
                                              page.frame.size.height)];
                } else {
                    page = [[UIImageView alloc] initWithFrame:self.view.bounds];
                    [page setImage:LoadScaledPngImage(name)];
                    [page setContentMode:UIViewContentModeScaleToFill];
                }
                [page setFrame:CGRectMake((double)(i * pageWidth),
                                          page.frame.origin.y,
                                          page.frame.size.width,
                                          page.frame.size.height)];
                [scrollBg addSubview:page];
            }
            [scrollBg setContentSize:CGSizeMake((double)(pageWidth * 6), boundsHeight)];
            [scrollBg setScrollEnabled:NO];
        }
        if (bgImageView != nil &&
            JubeatAppDelegate.appDelegate.deviceType == JubeatDeviceTypePhoneRetina &&
            !JubeatAppDelegate.appDelegate.isNagaCoraMode) {
            [bgImageView setFrame:CGRectMake(0.0,
                                             kBgImageYRetina,
                                             bgImageView.frame.size.width,
                                             bgImageView.frame.size.height)];
        }
    } else {
        [self.view setBackgroundColor:UIColor.blackColor];
        BOOL wide = (JubeatAppDelegate.appDelegate.deviceType == JubeatDeviceTypePhoneRetina) ||
                    JubeatAppDelegate.appDelegate.isPad;
        if (wide) {
            bgImageView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(@"msel_bg")];
        } else {
            bgImageView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(@"msel_bg_40")];
            [bgImageView setFrame:CGRectMake(0.0,
                                             0.0,
                                             bgImageView.frame.size.width,
                                             bgImageView.frame.size.height)];
        }
    }

    // The music list fills the screen below a per-idiom top inset.
    double listWidth = boundsWidth;
    double listHeight = boundsHeight - (isPad ? 110.0 : 100.0);
    double listTop = isPad ? kMusicListTopPad : kMusicListTopPhone;
    musicListView =
        [[MusicListView alloc] initWithFrame:CGRectMake(0.0, listTop, listWidth, listHeight)];
    [musicListView setMusicViewDelegate:self];
    [musicListView setDelegate:self];

    // The marker-select panel slides down from off-screen; it is off by default.
    UIImage *markerBg = LoadScaledPngImage(@"playlist_btn");
    if (isPad) {
        markerBg = [markerBg resizableImageWithCapInsets:UIEdgeInsetsMake(0, 0, 0, 45.0)];
    }
    double markerSize = isPad ? 500.0 : 250.0;
    double markerY = isPad ? kMarkerSelectYPad : kMarkerSelectYPhone;
    markerSelectView =
        [[MarkerSelectView alloc] initWithFrame:CGRectMake(0.0, -markerSize, markerY, markerSize)];
    [markerSelectView setDelegate:self];
    [markerSelectView setHidden:YES];
    isMarkerSelectOpen = NO;
    markerSelectView.layer.zPosition = kMarkerZPosition;

    // The dimming cover behind the marker panel.
    markerSelectCover =
        [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, boundsWidth, boundsHeight)];
    [markerSelectCover setOpaque:NO];
    [markerSelectCover setBackgroundColor:UIColor.clearColor];
    [markerSelectCover setHidden:YES];

    // The marker button, carrying the current banner image.
    UIImage *markerImage = (theme == JubeatThemeReflecBeatPlus) ?
                               LoadScaledPngImage(@"menu_button_mar_rpl") :
                           (theme == JubeatThemeKnit) ? LoadScaledPngImage(@"menu_button_mar_knt") :
                                                        LoadScaledPngImage(@"menu_button_mar");
    btnMarker = [UIButton buttonWithType:UIButtonTypeCustom];
    [btnMarker setFrame:CGRectMake(0.0, 0.0, markerImage.size.width, markerImage.size.height)];
    [btnMarker setBackgroundImage:markerImage forState:UIControlStateNormal];
    [btnMarker setExclusiveTouch:YES];
    [btnMarker setAdjustsImageWhenDisabled:NO];
    [btnMarker addTarget:self
                  action:@selector(tapMarkerSelect:)
        forControlEvents:UIControlEventTouchUpInside];
    [btnMarker addTarget:self
                  action:@selector(btnTouchesBegan:)
        forControlEvents:UIControlEventTouchDown];
    [btnMarker addTarget:self
                  action:@selector(btnTouchesCancel:)
        forControlEvents:UIControlEventTouchCancel];
    btnMarkerImg = [[UIImageView alloc]
        initWithFrame:CGRectMake(6.0, 4.0, kMarkerBannerWidth, kMarkerBannerHeight)];
    [btnMarkerImg setImage:[markerSelectView getCurrentBanner]];
    [btnMarker addSubview:btnMarkerImg];
    btnMarker.layer.zPosition = kMarkerZPosition;
    if (!MarkerManager.enableMarkerSelect) {
        [btnMarker setEnabled:NO];
    }

    // A hidden helper music view used for the far-open animation.
    JubeatDeviceType farDevice = JubeatAppDelegate.appDelegate.deviceType;
    double farY = isPad ? 210.0 : kFarOpenYRetina;
    double farX =
        isPad ? 210.0 :
                (farDevice == JubeatDeviceTypePhoneRetina4Inch ? kFarOpenX4Inch : kFarOpenXRetina);
    double farArtwork = isPad ? kFarOpenArtworkPad : kFarOpenArtworkPhone;
    farOpenMusicView = [[MusicView alloc] initWithFrame:CGRectMake(0.0, 0.0, farY, farX)
                                            artworkSize:farArtwork
                                                colType:0
                                              labelDisp:YES];
    [farOpenMusicView setHidden:YES];

    // The store button, bottom-right, with a rotated "new" badge.
    UIImage *storeImage = (theme == JubeatThemeReflecBeatPlus) ?
                              LoadScaledPngImage(@"menu_button_sto_rpl") :
                          (theme == JubeatThemeKnit) ? LoadScaledPngImage(@"menu_button_sto_knt") :
                                                       LoadScaledPngImage(@"menu_button_sto");
    double storeX = (double)(int)boundsHeight - storeImage.size.width;
    btnStore = [UIButton buttonWithType:UIButtonTypeCustom];
    [btnStore setBackgroundImage:storeImage forState:UIControlStateNormal];
    [btnStore
        setFrame:CGRectMake(
                     (double)(int)storeX, 0.0, storeImage.size.width, (double)(int)boundsHeight)];
    [btnStore setExclusiveTouch:YES];
    [btnStore addTarget:self
                  action:@selector(tapStore:)
        forControlEvents:UIControlEventTouchUpInside];
    [btnStore addTarget:self
                  action:@selector(btnTouchesBegan:)
        forControlEvents:UIControlEventTouchDown];
    [btnStore addTarget:self
                  action:@selector(btnTouchesCancel:)
        forControlEvents:UIControlEventTouchCancel];

    UIImage *storeNewImage =
        (theme == JubeatThemeReflecBeatPlus) ? LoadScaledPngImage(@"word_store_new_rpl") :
        (theme == JubeatThemeKnit)           ? LoadScaledPngImage(@"word_store_new_knt") :
                                               LoadScaledPngImage(@"word_store_new");
    imgStoreNew = [[UIImageView alloc] initWithImage:storeNewImage];
    [imgStoreNew setHidden:YES];
    double storeNewX = btnStore.frame.origin.x + (isPad ? -30.0 : -20.0);
    double storeNewNudge = isPad ? 5.0 : 10.0;
    [imgStoreNew setCenter:CGPointMake(storeNewX, btnStore.frame.origin.y * 0.5 + storeNewNudge)];
    [imgStoreNew setTransform:CGAffineTransformMakeRotation(kStoreNewRotation)];
    [btnStore addSubview:imgStoreNew];

    // A second, hidden "new" badge reused for the challenge button.
    imgChallengeNew = [[UIImageView alloc] initWithImage:storeNewImage];
    [imgChallengeNew setHidden:YES];
    double challengeNewX = btnStore.frame.origin.x + (isPad ? -30.0 : -20.0);
    [imgChallengeNew
        setCenter:CGPointMake(challengeNewX, btnStore.frame.origin.y * 0.5 + storeNewNudge)];
    [imgChallengeNew setTransform:CGAffineTransformMakeRotation(kStoreNewRotation)];

    // The music detail card, built from the theme-specific subclass and hidden until a tune opens.
    double detailArtwork = musicListView.artworkSize * (isPad ? 4.0 : 3.75);
    Class detailClass = (theme == JubeatThemeReflecBeatPlus) ? [MusicDetailViewRpl class] :
                        (theme == JubeatThemeKnit)           ? [MusicDetailViewKnt class] :
                                                               [MusicDetailViewOrg class];
    musicDetailView =
        [[detailClass alloc] initWithFrame:CGRectMake(0.0, 0.0, detailArtwork, detailArtwork)];
    [musicDetailView setHidden:NO];
    musicDetailView.layer.doubleSided = NO;
    [musicDetailView setController:self];

    // The dimming cover behind the detail card; tapping it closes the card.
    coverView = [[UIView alloc] initWithFrame:self.view.bounds];
    [coverView setHidden:NO];
    [coverView setBackgroundColor:[UIColor colorWithWhite:0 alpha:kCoverAlpha]];
    [coverView setHidden:YES];
    [coverView
        addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:musicDetailView
                                                                     action:@selector(close)]];

    // The background (still or scrolling), then the list and marker button.
    if (bgImageView != nil) {
        [self.view addSubview:bgImageView];
    } else if (scrollBg != nil) {
        [self.view addSubview:scrollBg];
    }
    [self.view addSubview:musicListView];
    [self.view addSubview:btnMarker];

    // Restore the last-played playlist/level/hold selection and open it.
    NSString *lastPlaylist = [NSUserDefaults.standardUserDefaults stringForKey:@"PrefLastPlaylist"];
    NSInteger listType = [playlistManager indexOfPlaylistWithIdentifier:lastPlaylist];
    if (listType == NSIntegerMax) {
        if ([NSUserDefaults.standardUserDefaults integerForKey:@"PrefPlayListLevel"] != 0) {
            listType = kListTypeLevel;
        } else {
            NSInteger holdPref =
                [NSUserDefaults.standardUserDefaults integerForKey:@"PrefPlayListHold"];
            listType = (holdPref == 1) ? kListTypeHold :
                       (holdPref == 2) ? kListTypeNotHold :
                                         kListTypeNotPlayed;
        }
    }
    NSUInteger lastID =
        (NSUInteger)[NSUserDefaults.standardUserDefaults integerForKey:@"PrefLastPlayedID"];
    [self changeMusicListView:listType musicID:lastID isFirst:YES];

    // The bottom bar (playlist controls).
    bottomView =
        [[MusicSelectBottomView alloc] initWithFrame:CGRectMake((double)((int)boundsHeight - 30),
                                                                self.view.frame.origin.y,
                                                                30.0,
                                                                boundsWidth)];
    [bottomView setADelegate:self];
    [bottomView setPlaylistManager:playlistManager];
    [bottomView playlistButtonChanged:listType];
    [self.view addSubview:bottomView];
    [self.view addSubview:btnStore];

    // The challenge button, left of the store button, carrying the challenge "new" badge.
    UIImage *challengeImage =
        (theme == JubeatThemeReflecBeatPlus) ? LoadScaledPngImage(@"menu_button_challenge_rpl") :
        (theme == JubeatThemeKnit)           ? LoadScaledPngImage(@"menu_button_challenge_knt") :
                                               LoadScaledPngImage(@"menu_button_challenge");
    btnChallenge = [UIButton buttonWithType:UIButtonTypeCustom];
    [btnChallenge setBackgroundImage:challengeImage forState:UIControlStateNormal];
    double challengeX = (double)(int)(storeX - challengeImage.size.width);
    [btnChallenge
        setFrame:CGRectMake(
                     challengeX, 0.0, challengeImage.size.width, challengeImage.size.height)];
    [btnChallenge setExclusiveTouch:YES];
    [btnChallenge addTarget:self
                     action:@selector(tapChallengeMode:)
           forControlEvents:UIControlEventTouchUpInside];
    [btnChallenge addTarget:self
                     action:@selector(btnTouchesBegan:)
           forControlEvents:UIControlEventTouchDown];
    [btnChallenge addTarget:self
                     action:@selector(btnTouchesCancel:)
           forControlEvents:UIControlEventTouchCancel];
    [self.view addSubview:btnChallenge];
    [btnChallenge addSubview:imgChallengeNew];

    // A store-promotion balloon, shown only when the player owns no purchased music but has
    // records for built-in music.
    if ([StoreMusicListManager sharedManager].purchasedMusic.count == 0) {
        NSArray *builtin = [StoreMusicListManager sharedManager].builtinMusic;
        if ([ScoreRecord recordsForTuneIDs:builtin].count != 0) {
            double balloonHeight = isPad ? kBalloonHeightPad : kBalloonHeightPhone;
            double balloonY = challengeImage.size.height + 4.0;
            balloonView = [[BalloonView alloc]
                initWithFrame:CGRectMake(storeX - (isPad ? kBalloonXPad : kBalloonXPhone),
                                         balloonY,
                                         kBalloonWidth,
                                         balloonHeight)];
            balloonView.layer.shadowColor = UIColor.blackColor.CGColor;
            balloonView.layer.shadowRadius = kBalloonShadowRadius;
            balloonView.layer.shadowOpacity = kBalloonShadowOpacity;
            balloonView.layer.shadowOffset = CGSizeMake(0.0, 1.0);
            [balloonView setArrowDirection:0];
            [balloonView setArrowPosision:balloonHeight - (double)(int)(balloonHeight * 0.5)];
            [balloonView setArrowSize:CGSizeMake(16.0, 12.0)];
            [balloonView setContentEdgeInsets:UIEdgeInsetsMake(12.0, 12.0, 12.0, 12.0)];
            NSString *message =
                [NSString stringWithFormat:[NSBundle.mainBundle
                                               localizedStringForKey:@"StoreBalloonMessage(%@)"
                                                               value:@""
                                                               table:nil]];
            UILabel *label = [[UILabel alloc] initWithFrame:balloonView.contentRect];
            [label setOpaque:NO];
            [label setBackgroundColor:UIColor.clearColor];
            [label setTextColor:UIColor.whiteColor];
            [label setFont:[UIFont boldSystemFontOfSize:16.0]];
            [label setTextAlignment:NSTextAlignmentCenter];
            [label setNumberOfLines:0];
            if (!isPad) {
                [label setText:[message stringByReplacingOccurrencesOfString:@"\n" withString:@""]];
            } else {
                [label setText:message];
            }
            [balloonView addSubview:label];
            [balloonView addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                                  initWithTarget:self
                                                          action:@selector(hideStoreBalloon)]];
            [balloonView setUserInteractionEnabled:NO];
            [balloonView setAlpha:0.0];
            [self.view addSubview:balloonView];
        }
    }

    // The join-session button, left of the challenge button.
    UIImage *joinImage = (theme == JubeatThemeReflecBeatPlus) ?
                             LoadScaledPngImage(@"menu_button_join_rpl") :
                         (theme == JubeatThemeKnit) ? LoadScaledPngImage(@"menu_button_join_knt") :
                                                      LoadScaledPngImage(@"menu_button_join");
    btnJoinSession = [UIButton buttonWithType:UIButtonTypeCustom];
    [btnJoinSession setBackgroundImage:joinImage forState:UIControlStateNormal];
    double joinX = (double)(int)(challengeX - joinImage.size.width);
    [btnJoinSession setFrame:CGRectMake(joinX, 0.0, joinImage.size.width, joinImage.size.height)];
    [btnJoinSession setExclusiveTouch:YES];
    [btnJoinSession addTarget:self
                       action:@selector(pushBtnJoin:)
             forControlEvents:UIControlEventTouchUpInside];
    [btnJoinSession addTarget:self
                       action:@selector(btnTouchesBegan:)
             forControlEvents:UIControlEventTouchDown];
    [btnJoinSession addTarget:self
                       action:@selector(btnTouchesCancel:)
             forControlEvents:UIControlEventTouchCancel];
    [self.view addSubview:btnJoinSession];

    // The settings button, left of the join button.
    UIImage *settingsImage =
        (theme == JubeatThemeReflecBeatPlus) ? LoadScaledPngImage(@"menu_button_set_rpl") :
        (theme == JubeatThemeKnit)           ? LoadScaledPngImage(@"menu_button_set_knt") :
                                               LoadScaledPngImage(@"menu_button_set");
    btnSettings = [UIButton buttonWithType:UIButtonTypeCustom];
    [btnSettings setBackgroundImage:settingsImage forState:UIControlStateNormal];
    double settingsX = joinX - settingsImage.size.width;
    [btnSettings setFrame:CGRectMake((double)(int)settingsX,
                                     0.0,
                                     settingsImage.size.width,
                                     settingsImage.size.height)];
    [btnSettings setExclusiveTouch:YES];
    [btnSettings addTarget:self
                    action:@selector(tapSettings:)
          forControlEvents:UIControlEventTouchUpInside];
    [btnSettings addTarget:self
                    action:@selector(btnTouchesBegan:)
          forControlEvents:UIControlEventTouchDown];
    [btnSettings addTarget:self
                    action:@selector(btnTouchesCancel:)
          forControlEvents:UIControlEventTouchCancel];
    [self.view addSubview:btnSettings];

    // Up/down swipes on the whole view open and close the search box.
    UISwipeGestureRecognizer *swipeUp =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    [swipeUp setDirection:UISwipeGestureRecognizerDirectionUp];
    [self.view addGestureRecognizer:swipeUp];
    [self.view setMultipleTouchEnabled:NO];
    [self.view setExclusiveTouch:YES];
    UISwipeGestureRecognizer *swipeDown =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    [swipeDown setDirection:UISwipeGestureRecognizerDirectionDown];
    [self.view addGestureRecognizer:swipeDown];
    [self.view setMultipleTouchEnabled:NO];
    [self.view setExclusiveTouch:YES];
    arraySwipeRecognizer = @[ swipeUp, swipeDown ];

    // The search bar, sized from a stretched background image, initially slid up off-screen.
    double searchWidth = kSearchBarWidth;
    if (!isPad) {
        searchWidth = (double)(int)(boundsWidth - (isPad ? kSearchInsetPad : kSearchInsetPhone));
    }
    double searchHeight = kSearchBarHeight;
    UIImage *searchBg = [LoadScaledPngImage(@"search_bg")
        resizableImageWithCapInsets:UIEdgeInsetsMake(0, 40.0, 0, 40.0)];
    UIGraphicsBeginImageContext(CGSizeMake(searchWidth, searchHeight));
    [searchBg drawInRect:CGRectMake(0.0, 0.0, searchWidth, searchHeight)];
    UIImage *searchBarImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    searchBox = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0, 0.0, searchWidth, searchHeight)];
    [searchBox setText:@""];
    if (JubeatAppDelegate.appDelegate.searchString != nil) {
        [searchBox setText:JubeatAppDelegate.appDelegate.searchString];
    }
    [searchBox setDelegate:self];
    [searchBox setBackgroundColor:UIColor.whiteColor];
    [searchBox setBarStyle:UIBarStyleDefault];
    [searchBox setKeyboardType:UIKeyboardTypeDefault];
    [searchBox setBackgroundImage:searchBarImage];
    [searchBox setPlaceholder:[NSBundle.mainBundle localizedStringForKey:@"Music Search."
                                                                   value:@""
                                                                   table:nil]];
    backUpString = @"";

    // The search cancel button, right of the search bar.
    searchCancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [searchCancelBtn setBackgroundImage:LoadScaledPngImage(@"search_cancel_btn")
                               forState:UIControlStateNormal];
    double cancelWidth = isPad ? kSearchInsetPad : kSearchInsetPhone;
    [searchCancelBtn setFrame:CGRectMake(searchWidth, 0.0, cancelWidth, searchHeight)];
    [searchCancelBtn setExclusiveTouch:YES];
    [searchCancelBtn addTarget:self
                        action:@selector(tapSearchCancel:)
              forControlEvents:UIControlEventTouchUpInside];
    [searchCancelBtn addTarget:self
                        action:@selector(btnTouchesBegan:)
              forControlEvents:UIControlEventTouchDown];
    [searchCancelBtn addTarget:self
                        action:@selector(btnTouchesCancel:)
              forControlEvents:UIControlEventTouchCancel];
    if (searchArray.count == 0) {
        // With no active search, both are slid up out of view.
        [searchBox setTransform:CGAffineTransformMakeTranslation(0.0, g_dSlideOffsetYMinus52)];
        [searchCancelBtn
            setTransform:CGAffineTransformMakeTranslation(0.0, g_dSlideOffsetYMinus52)];
    } else {
        bOpenSearchBox = YES;
        [self showButtonMarker:NO];
    }

    // A one-time search tutorial overlay, shown when the library is large and the tutorial has not
    // yet been seen.
    searchTutorialView = nil;
    if (![NSUserDefaults.standardUserDefaults boolForKey:@"PrefSearchTutorialFinish"] &&
        (NSInteger)([musicListView currentViewsPerPage] * 2) < (NSInteger)arrayAllTune.count) {
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"PrefSearchTutorialFinish"];
        searchTutorialView =
            [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, searchWidth, searchHeight)];
        [searchTutorialView setBackgroundColor:[UIColor colorWithWhite:0 alpha:kTutorialAlpha]];
        searchTutorialView.layer.zPosition = kTutorialZPosition;
        UIImageView *arrow =
            [[UIImageView alloc] initWithImage:LoadScaledPngImage(@"search_tutorial")];
        double arrowY = (searchHeight * 3.0) / 7.0;
        [arrow setCenter:CGPointMake(searchWidth * 0.5, arrowY)];
        double mesGap =
            (JubeatAppDelegate.appDelegate.deviceType == JubeatDeviceTypePhoneRetina4Inch) ? 16.0 :
                                                                                             10.0;
        double mesY = mesGap + arrowY + arrowY * 0.5;
        [searchTutorialView addSubview:arrow];
        UIImageView *mes =
            [[UIImageView alloc] initWithImage:LoadScaledPngImage(@"search_tutorial_mes")];
        [mes setCenter:CGPointMake(searchWidth * 0.5, (double)(int)mesY + 16.0 * 0.5)];
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, 16.0, searchHeight)];
        [label setTextAlignment:NSTextAlignmentCenter];
        [label setTextColor:UIColor.whiteColor];
        [label setBackgroundColor:UIColor.clearColor];
        if (!isPad) {
            [label setFont:[UIFont systemFontOfSize:16.0]];
            [label setText:[NSString stringWithFormat:[NSBundle.mainBundle
                                                          localizedStringForKey:@"Swipe down Search"
                                                                          value:@""
                                                                          table:nil]]];
        } else {
            [label setFont:[UIFont systemFontOfSize:18.0]];
            [label setText:[NSString
                               stringWithFormat:[NSBundle.mainBundle
                                                    localizedStringForKey:@"Swipe down Search Long"
                                                                    value:@""
                                                                    table:nil]]];
        }
        [mes addSubview:label];
        [searchTutorialView addSubview:mes];
    }

    // The extend-mode tutorial overlay (hidden until the extend feature is offered).
    extendTutorialView = nil;
    extendTutorialView = [[UIView alloc] initWithFrame:self.view.bounds];
    [extendTutorialView setHidden:NO];
    [extendTutorialView setBackgroundColor:[UIColor colorWithWhite:0 alpha:g_dAnimDuration020]];
    [extendTutorialView setHidden:YES];
    [extendTutorialView setAlpha:0.0];
    extendTutorialView.layer.zPosition = kTutorialZPosition;
    UIImage *extendFrameImage = LoadScaledPngImage(@"extend_frame");
    extendTutorialFrame = [[UIButton alloc]
        initWithFrame:CGRectMake(
                          0.0, 0.0, extendFrameImage.size.width, extendFrameImage.size.height)];
    [extendTutorialFrame setBackgroundImage:extendFrameImage forState:UIControlStateNormal];
    [extendTutorialFrame setHidden:YES];
    [extendTutorialFrame setAdjustsImageWhenHighlighted:NO];
    [extendTutorialFrame setAdjustsImageWhenDisabled:NO];
    [extendTutorialFrame addTarget:self
                            action:@selector(tapChangeMode:)
                  forControlEvents:UIControlEventTouchUpInside];
    [extendTutorialView addSubview:extendTutorialFrame];
    UIImage *extendDescImage = LoadScaledPngImage(@"extend_description");
    double descX = extendTutorialFrame.frame.size.width * (isPad ? 0.5 : kExtendDescXFraction);
    double descY = extendTutorialFrame.frame.size.height * kExtendDescYFraction;
    extendTutorialDescription = [[UIImageView alloc]
        initWithFrame:CGRectMake(
                          descX, descY, extendDescImage.size.width, extendDescImage.size.height)];
    [extendTutorialDescription setImage:extendDescImage];
    [extendTutorialFrame addSubview:extendTutorialDescription];

    // Layer the interactive views above the background.
    [self.view addSubview:btnJoinSession];
    [self.view addSubview:btnSettings];
    [self.view addSubview:coverView];
    [self.view addSubview:markerSelectCover];
    [self.view addSubview:btnMarker];
    [self.view addSubview:markerSelectView];
    if (searchTutorialView != nil) {
        [self.view addSubview:searchTutorialView];
    }

    // Register this device's push token once, if an editor ID exists and it has not been sent.
    if (!JubeatAppDelegate.appDelegate.bSendPushID && [EditorIDManager isExistEditorID] &&
        JubeatAppDelegate.appDelegate.deviceToken != nil) {
        NSString *url = ScratchUtil.pushNotificationIDSendURL;
        NSString *editorID = [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
        NSDictionary *post = [NSDictionary
            dictionaryWithObjects:@[ editorID, JubeatAppDelegate.appDelegate.deviceToken ]
                          forKeys:@[ @"user_id", @"token" ]];
        SessionDownloader *downloader = [[SessionDownloader alloc] initWithURL:url
                                                                postDictionary:post
                                                                      delegate:self];
        [downloader setTag:kPushIDDownloaderTag];
        [downloader startDownloading];
    }

    // The notification banner view, centred at the top of the screen.
    int notifyWidth = isPad ? kNotifyWidthPad : kNotifyWidthPhone;
    int notifyX = ((int)boundsWidth - notifyWidth);
    if (notifyX < 0) {
        notifyX += 1;
    }
    notificationView = [[PushNotificationView alloc]
        initWithFrame:CGRectMake((double)(notifyX >> 1), 0.0, (double)notifyWidth, kNotifyHeight)
             delegate:self];
    notificationView.layer.zPosition = kTutorialZPosition;
    [self.view addSubview:notificationView];
    if (JubeatAppDelegate.appDelegate.notificationURL == nil &&
        !JubeatAppDelegate.appDelegate.bChallengeMode) {
        [notificationView startNotification];
    }

    // Enter challenge mode immediately if the app launched into it.
    bOpenChallenge = NO;
    if (JubeatAppDelegate.appDelegate.bChallengeMode) {
        bOpenChallenge = YES;
        [self downloadChallengeInfo];
    }
}

/** @ghidraAddress 0x38f04 */
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [infoDownloader cancel];
    [infoBannerTimer invalidate];
    if (challengeModeView != nil) {
        [challengeModeView removeFromSuperview];
        challengeModeView = nil;
    }
    // [super dealloc] is compiler-emitted (ARC).
}

#pragma mark - View lifecycle

/** @ghidraAddress 0x31e40 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x32ae4 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x32b1c */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self becomeFirstResponder];
}

/** @ghidraAddress 0x32b70 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x32ba8 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0x31b98 */
- (void)appSuspended:(nullable id)notification {
    [self hiddenCoverView];
    [markerSelectView pauseAnimation];
    [self stopStoreInfo];
    [bottomView animStop];
    [imgStoreNew.layer removeAllAnimations];
    [imgStoreNew setHidden:YES];
    [btnChallenge.titleLabel.layer removeAllAnimations];
    [imgChallengeNew.layer removeAllAnimations];
    [imgChallengeNew setHidden:YES];
    // A live share session is torn down: the host that has started disconnects, otherwise the
    // pending share is cancelled.
    if (self.sharePlayManager != nil) {
        if (willStart) {
            [self.sharePlayManager disconnect];
            self.sharePlayManager = nil;
        } else {
            [self cancelShare:YES];
        }
    }
}

/** @ghidraAddress 0x31da4 */
- (void)appResumed:(nullable id)notification {
    [markerSelectView resumeAnimation];
    if (mainBgmSuspended) {
        [[AudioManager sharedManager] startBgm:YES fadeTime:kMenuBgmResumeFade];
        mainBgmSuspended = NO;
    }
    [self requestNewInfo];
}

#pragma mark - Music list

/** @ghidraAddress 0x22984 */
- (void)changeMusicListView:(NSInteger)listType musicID:(NSUInteger)musicID {
    [self changeMusicListView:listType musicID:musicID isFirst:NO];
}

/** @ghidraAddress 0x22994 */
- (void)changeMusicListView:(NSInteger)listType musicID:(NSUInteger)musicID isFirst:(BOOL)isFirst {
    // Snapshot the list before the change so the add/delete diff can be computed against it.
    NSArray<TuneInfo *> *oldList = (arrayCurrentPlaylist == nil) ?
                                       [NSArray arrayWithArray:arrayAllTune] :
                                       [NSArray arrayWithArray:arrayCurrentPlaylist];
    [self preparePlaylistArray:listType];
    playListIndex = (int)listType;
    NSArray<TuneInfo *> *newList = arrayCurrentPlaylist ?: arrayAllTune;
    NSUInteger targetIndex = 0;
    if (musicID != 0 && newList.count != 0) {
        NSUInteger i = 0;
        while (i + 1 < newList.count && (unsigned int)newList[i].tuneID != musicID) {
            ++i;
        }
        targetIndex = ((unsigned int)newList[i].tuneID == musicID) ? i : 0;
    }
    arrayAddList = nil;
    arrayDeleteList = nil;
    arrayDeleteList = [[NSMutableArray alloc] init];
    arrayAddList = [[NSMutableArray alloc] init];
    if (!isFirst) {
        // Rows in the old list that are gone from the new list are deletions.
        NSInteger row = 0;
        for (TuneInfo *tune in oldList) {
            if ([newList indexOfObject:tune] == NSNotFound) {
                [arrayDeleteList addObject:[NSIndexPath indexPathForRow:row inSection:0]];
            }
            ++row;
        }
        // Rows in the new list that were absent from the old list are insertions.
        row = 0;
        for (TuneInfo *tune in newList) {
            if ([oldList indexOfObject:tune] == NSNotFound) {
                [arrayAddList addObject:[NSIndexPath indexPathForRow:row inSection:0]];
            }
            ++row;
        }
    }
    [musicListView reloadPageContainsMusicForIndex:targetIndex playlistIndex:listType];
    [musicListView updateViews];
}

/** @ghidraAddress 0x29fbc */
- (unsigned int)numberOfMusic {
    NSArray *list = arrayCurrentPlaylist ?: arrayAllTune;
    return (unsigned int)list.count;
}

/** @ghidraAddress 0x2aeec */
- (void)musicPlaylistViewControllerWillClosed:(nullable id)controller {
    if (playlistViewCtrl.listMode == MusicPlaylistListModeAddToPlaylist) {
        [musicListView hideAllPlaylistAction];
    }
    playlistViewCtrl = nil;
    playlistNavCtrl = nil;
    [self dismissViewControllerAnimated:YES
                             completion:^{
                             }];
    bOpenModal = NO;
    [self musicShuffleEnable];
}

/** @ghidraAddress 0x36cb0 */
- (void)updateMusicList {
    [self refreshMusicList];
    [musicListView updateViews];
    [markerSelectView updateMarkerList];
}

/** @ghidraAddress 0x33330 */
- (void)downloadEnd:(nullable id)sender musicID:(nullable id)musicID {
    [musicListView addDownloadMark:[musicID intValue]];
}

/** @ghidraAddress 0x329d4 */
- (void)markerSelectChanged:(nullable id)sender {
    [btnMarkerImg setImage:[markerSelectView getCurrentBanner]];
}

/** @ghidraAddress 0x2ca38 */
- (void)musicViewSelectBgmAction:(nullable id)musicView {
    // Re-tapping the current custom-BGM tune clears the preference; any other tune sets it.
    unsigned int tuneID = ((MusicView *)musicView).tuneInfo.tuneID;
    NSInteger current = [NSUserDefaults.standardUserDefaults integerForKey:kPrefCustomBgmIDKey];
    if (tuneID == current) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kPrefCustomBgmIDKey];
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kPrefCustomBgmOnKey];
    } else {
        [NSUserDefaults.standardUserDefaults setInteger:tuneID forKey:kPrefCustomBgmIDKey];
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:kPrefCustomBgmOnKey];
    }
    [NSUserDefaults.standardUserDefaults synchronize];
    [self setupMainBgm];
    [musicListView refreshTextColor];
}

/** @ghidraAddress 0x2a228 */
- (nullable id)extendMusicInfoForMusicID:(unsigned int)musicID {
    return dictAllExtendTune[@(musicID)];
}

/** @ghidraAddress 0x2a298 */
- (nullable id)addMusicArray {
    return arrayAddList;
}

/** @ghidraAddress 0x2a2a8 */
- (nullable id)removeMusicArray {
    return arrayDeleteList;
}

#pragma mark - Rotation

/** @ghidraAddress 0x32be0 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    // The two landscape orientations are UIInterfaceOrientationLandscapeLeft (1) and Right (2).
    return (orientation - 1) < 2;
}

/** @ghidraAddress 0x32bf0 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return kSupportedOrientations;
}

/** @ghidraAddress 0x32bf8 */
- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - Shake

/** @ghidraAddress 0x358d4 */
- (BOOL)canBecomeFirstResponder {
    return YES;
}

/** @ghidraAddress 0x35854 */
- (BOOL)checkShakeEvent:(nullable id)event {
    // A shake counts only while shuffle is enabled and the event is a motion-shake.
    return bEnableShuffle && ((UIEvent *)event).type == UIEventTypeMotion &&
           ((UIEvent *)event).subtype == UIEventSubtypeMotionShake;
}

/** @ghidraAddress 0x358dc */
- (void)motionBegan:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event {
    [self checkShakeEvent:event];
}

/** @ghidraAddress 0x358ec */
- (void)motionCancelled:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event {
    [self checkShakeEvent:event];
}

/** @ghidraAddress 0x358fc */
- (void)motionEnded:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event {
    if ([self checkShakeEvent:event]) {
        [self setRandomSelect];
    }
}

#pragma mark - Buttons

/** @ghidraAddress 0x3478c */
- (void)btnTouchesBegan:(nullable id)sender {
    [self setEnableGesture:NO];
}

/** @ghidraAddress 0x3479c */
- (void)btnTouchesCancel:(nullable id)sender {
    [self setEnableGesture:YES];
}

/** @ghidraAddress 0x347ac */
- (void)setEnableGesture:(BOOL)enable {
    // Gestures (and shuffle and search) stay off during a share session.
    BOOL on = (self.sharePlayManager == nil) && enable;
    bEnableShuffle = on;
    [self setSearchEnable:on];
}

/** @ghidraAddress 0x2ca20 */
- (void)musicViewPressed:(nullable id)sender {
    [musicListView hideAllPlaylistAction];
}

/** @ghidraAddress 0x2cfac */
- (NSUInteger)musicViewGetPlaylistActionType:(nullable id)musicView {
    // The not-played, level, hold, and not-hold system lists offer no add/remove action; a real
    // user playlist reports action type 1.
    id source = currentPlaylistSource;
    if (source == nil || source == arrayNotPlayedTune || source == arrayLevelList ||
        source == arrayHoldList || source == arrayNotHoldList) {
        return 0;
    }
    return 1;
}

/** @ghidraAddress 0x36c94 */
- (void)challengeModeEnable:(BOOL)enable {
    [btnChallenge setEnabled:YES];
}

#pragma mark - Play flow

/** @ghidraAddress 0x2ea0c */
- (void)resetWillStart {
    willStart = NO;
}

/** @ghidraAddress 0x2e9f8 */
- (void)willStartPlay {
    willStart = YES;
}

/** @ghidraAddress 0x34810 */
- (void)musicShuffleEnable {
    // Shuffle stays disabled while a share-play session is active.
    if (self.sharePlayManager == nil) {
        bEnableShuffle = YES;
    }
}

/** @ghidraAddress 0x3485c */
- (void)musicShuffleDisable {
    bEnableShuffle = NO;
}

/** @ghidraAddress 0x36b34 */
- (void)musicListScrollBegin {
    [searchBox resignFirstResponder];
}

/** @ghidraAddress 0x37094 */
- (void)refreshRatingChip {
    [musicListView refreshRatingChip];
}

#pragma mark - Search

/** @ghidraAddress 0x36b30 */
- (void)searchBar:(nullable UISearchBar *)searchBar
    selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
}

#pragma mark - Lab, challenge, and store

/** @ghidraAddress 0x34754 */
- (void)tapJubeatLab:(nullable id)sender {
    [self setEnableGesture:YES];
    [self JcfDownLoadTopPage];
}

/** @ghidraAddress 0x38a50 */
- (void)agreementFailed:(nullable id)sender {
    [sender removeFromSuperview];
    [self hideChallengeCoverView];
}

/** @ghidraAddress 0x382d0 */
- (void)hideVerifyDialog {
    [verifyDialog removeFromSuperview];
    verifyDialog = nil;
}

/** @ghidraAddress 0x37ee8 */
- (void)showVerifyDialog:(nullable id)message {
    CGRect viewFrame = self.view.frame;
    if (JubeatAppDelegate.appDelegate.isPad) {
        verifyDialog = [[StoreDialogView alloc]
            initWithFrame:CGRectMake(0, 0, kVerifyDialogWidthPad, kVerifyDialogHeightPad)];
        verifyDialog.labelMessage.font = [UIFont systemFontOfSize:kVerifyDialogFontSizePad];
    } else {
        verifyDialog = [[StoreDialogView alloc]
            initWithFrame:CGRectMake(0, 0, kVerifyDialogWidthPhone, kVerifyDialogHeightPhone)];
        verifyDialog.labelMessage.font = [UIFont systemFontOfSize:kVerifyDialogFontSizePhone];
    }
    verifyDialog.center = CGPointMake(viewFrame.size.width * 0.5, viewFrame.size.height * 0.5);
    [verifyDialog.progressView setProgress:0.0];
    verifyDialog.labelMessage.text = message;
    verifyDialog.buttonAbort.hidden = YES;
    [verifyDialog layout:YES];
    [challengeCoverView addSubview:verifyDialog];
    verifyDialog.alpha = 0.0;
    __weak StoreDialogView *weakDialog = verifyDialog;
    [UIView animateWithDuration:kChallengeCoverFadeDuration
                          delay:0.0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                       /** @ghidraAddress 0x38280 */
                       weakDialog.alpha = 1.0;
                     }
                     completion:nil];
}

/** @ghidraAddress 0x36d04 */
- (void)tapChallengeMode:(nullable id)sender {
    [[AudioManager sharedManager] playSeResFile:[self soundName:kChallengeTapSoundKey]
                                    inDirectory:nil];
    [self downloadChallengeInfo];
}

/** @ghidraAddress 0x27694 */
- (void)tapStoreInfo:(nullable id)info {
    [self setEnableGesture:YES];
    if (info != nil) {
        // A store-info entry that carries no challenge marker opens the store; otherwise it starts
        // the challenge download.
        if (((NSDictionary *)info)[@"challenge"] == nil) {
            [self turnToStore:info];
        } else {
            [self downloadChallengeInfo];
        }
    }
}

/** @ghidraAddress 0x32a34 */
- (void)tapStore:(nullable id)sender {
    [self setEnableGesture:YES];
    [[AudioManager sharedManager] playSeResFile:[self soundName:kStoreTapSoundKey] inDirectory:nil];
    [self turnToStore:nil];
}

/** @ghidraAddress 0x387d0 */
- (void)successIDDownload:(nullable id)sender {
    idManager = nil;
    [self downloadChallengeInfo];
}

/** @ghidraAddress 0x389e4 */
- (void)agreementSuccess:(nullable id)sender {
    checkPolicy = YES;
    [self downloadChallengeInfo];
    [sender removeFromSuperview];
}

/** @ghidraAddress 0x38a88 */
- (void)restoreFailed:(nullable id)sender {
    [self hideChallengeCoverView];
    PurchaseManager.sharedManager.delegate = nil;
    [self hideVerifyDialog];
}

/** @ghidraAddress 0x38fe8 */
- (void)scrollOffset:(float)offset {
    if (scrollBg == nil) {
        return;
    }
    int page = (scrollPageNum - 1) * (int)scrollBg.frame.size.width;
    int clamped = (offset < 0) ? 0 : (int)offset;
    int column = (page != 0) ? (clamped / page) : 0;
    [scrollBg setContentOffset:CGPointMake((double)(clamped - column * page), 0.0)];
}

#pragma mark - Notifications and challenge

/** @ghidraAddress 0x27cf8 */
- (void)pushNotificate {
    // A queued notification banner shows only when no modal, detail, settings, or challenge screen
    // is open.
    if (!bOpenChallenge && !bOpenMusicDetail && !bOpenSetting && !bOpenModal) {
        [notificationView startNotification];
    }
}

/** @ghidraAddress 0x37c24 */
- (void)loadTimeOver:(nullable id)sender {
    [indicatorTimer invalidate];
    indicatorTimer = nil;
    [indicatorChallenge startAnimating];
}

#pragma mark - Popover

/** @ghidraAddress 0x275dc */
- (BOOL)popoverPresentationControllerShouldDismissPopover:
    (nullable UIPopoverPresentationController *)popoverPresentationController {
    if (playlistViewCtrl.listMode == MusicPlaylistListModeAddToPlaylist) {
        [musicListView hideAllPlaylistAction];
    }
    return YES;
}

/** @ghidraAddress 0x27634 */
- (void)popoverPresentationControllerDidDismissPopover:
    (nullable UIPopoverPresentationController *)popoverPresentationController {
    playlistViewCtrl = nil;
    playlistNavCtrl = nil;
    [self JcfDownLoad];
    [self musicShuffleEnable];
}

#pragma mark - Cover tap and download view

/** @ghidraAddress 0x32c00 */
- (void)unenableCoverTap {
    [coverView setGestureRecognizers:nil];
    if (searchArray == nil) {
        [self showButtonMarker:NO];
    }
    [self musicShuffleDisable];
}

/** @ghidraAddress 0x32c68 */
- (void)enableCoverTap {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:musicDetailView
                                                                          action:@selector(close)];
    [coverView addGestureRecognizer:tap];
    if (searchArray == nil) {
        [self showButtonMarker:YES];
    }
    [self musicShuffleEnable];
}

/** @ghidraAddress 0x3301c */
- (void)removeDownloadView {
    [jcfDownloadView removeFromSuperview];
    jcfDownloadView = nil;
    [coverView setHidden:YES];
    [self enableCoverTap];
}

#pragma mark - Jcf download

/** @ghidraAddress 0x32fa0 */
- (void)JcfDownLoad {
    [self JcfDownLoad:JubeatAppDelegate.appDelegate.jcfDownloadID];
}

#pragma mark - Search

/** @ghidraAddress 0x36720 */
- (void)handleSwipe:(nullable UISwipeGestureRecognizer *)recognizer {
    // A downward swipe pulls the search box in; a rightward swipe pushes it away.
    if (recognizer.direction == UISwipeGestureRecognizerDirectionDown) {
        [self pullSearchBox];
    } else if (recognizer.direction == UISwipeGestureRecognizerDirectionRight) {
        [self pushSearchBox];
    }
}

/** @ghidraAddress 0x36780 */
- (void)tapSearchCancel:(nullable id)sender {
    [self setEnableGesture:YES];
    [searchBox setText:@""];
    backUpString = @"";
    [self pushSearchBox];
}

/** @ghidraAddress 0x36aa8 */
- (void)searchBarSearchButtonClicked:(nullable UISearchBar *)searchBar {
    if ([self searchStringChanged:searchBar.text]) {
        [self exeSearchPickUp];
    }
    [searchBox resignFirstResponder];
}

#pragma mark - Host select

/** @ghidraAddress 0x31b30 */
- (void)sharePlayManagerHostSelectStart:(nullable id)manager {
    willStart = YES;
    [self startPlay:musicDetailView.info];
}

#pragma mark - Share play

/** @ghidraAddress 0x2ff10 */
- (void)shareHostSelected:(nullable id)host {
    [self.sharePlayManager sendConnectRequest:host];
    [shareClientView changeClientModeConnecting];
}

/** @ghidraAddress 0x30480 */
- (void)sharePlayManagerFailedSendMusicData:(nullable id)manager {
}

/** @ghidraAddress 0x30948 */
- (void)sharePlayManagerConnectHost:(nullable id)manager {
    [shareClientView changeClientModeConnected];
}

/** @ghidraAddress 0x31818 */
- (void)sharePlayManager:(nullable id)manager receiveProgress:(float)progress {
    [musicDetailView.shareDataProgress setProgress:progress];
}

/** @ghidraAddress 0x30b6c */
- (void)sharePlayManager:(nullable id)manager findHostID:(nullable id)hostID {
    [shareClientView addHost:hostID];
}

/** @ghidraAddress 0x30b88 */
- (void)sharePlayManager:(nullable id)manager lostHostID:(nullable id)hostID {
    [shareClientView removeHostTmp:hostID];
}

/** @ghidraAddress 0x30484 */
- (void)sharePlayManagerAllClientReady:(nullable id)manager {
    [musicDetailView.labelShareMessage
        setText:[NSBundle.mainBundle localizedStringForKey:@"Ready to start" value:@"" table:nil]];
    [musicDetailView.buttonStartPlay setEnabled:YES];
    [musicDetailView setIsSharedStartable:YES];
    [musicDetailView setStartButtonEnable];
}

/** @ghidraAddress 0x31874 */
- (BOOL)sharePlayManager:(nullable id)manager musicDataReceived:(nullable id)musicData {
    // The payload carries a trailing MD5 digest over the music bytes; reject a mismatch.
    NSData *data = musicData;
    if (data.length > kShareMusicDigestLength) {
        unsigned char digest[16];
        [data getBytes:digest
                 range:NSMakeRange(data.length - kShareMusicDigestLength, kShareMusicDigestLength)];
        if (VerifyMd5Digest(data.bytes, (int)data.length - (int)kShareMusicDigestLength, digest)) {
            [musicDetailView loadContentFromPath:nil orData:data];
            shareMusicData = data;
            [musicDetailView.buttonStartPlay setEnabled:YES];
            [musicDetailView setIsSharedStartable:YES];
            [musicDetailView setStartButtonEnable];
            [musicDetailView.labelShareMessage
                setText:[NSString stringWithFormat:[NSBundle.mainBundle
                                                       localizedStringForKey:@"Connected to %@"
                                                                       value:@""
                                                                       table:nil],
                                                   self.sharePlayManager.partnerScreenName]];
            [musicDetailView showDataProgress:NO animated:YES];
            return YES;
        }
    }
    return NO;
}

/** @ghidraAddress 0x30140 */
- (void)sharePlayManagerConnectClient:(nullable id)manager {
    [musicDetailView.labelShareMessage
        setText:[NSString
                    stringWithFormat:[NSBundle.mainBundle localizedStringForKey:@"Connected to %@"
                                                                          value:@""
                                                                          table:nil],
                                     self.sharePlayManager.partnerScreenName]];
}

/** @ghidraAddress 0x30340 */
- (void)sharePlayManagerSuccessSendMusicData:(nullable id)manager {
    [musicDetailView.labelShareMessage
        setText:[NSString
                    stringWithFormat:[NSBundle.mainBundle localizedStringForKey:@"Connected to %@"
                                                                          value:@""
                                                                          table:nil],
                                     self.sharePlayManager.partnerScreenName]];
}

/** @ghidraAddress 0x2effc */
- (void)startHostShare:(nullable id)musicInfo filePath:(nullable id)filePath {
    NSString *screenName = JubeatAppDelegate.appDelegate.gameCenterName;
    [musicDetailView setIsSharedStartable:NO];
    self.sharePlayManager = [[SharePlayManager alloc] initWithScreenName:screenName];
    [self.sharePlayManager setDelegate:self];
    [self.sharePlayManager startHostModeWithMusicInfo:musicInfo filePath:filePath];
    [self musicShuffleDisable];
}

/** @ghidraAddress 0x2f17c */
- (void)cancelShare:(BOOL)disconnect {
    if (self.sharePlayManager == nil) {
        return;
    }
    if (!self.sharePlayManager.isHost) {
        [self setSearchEnable:YES];
        [[AudioManager sharedManager] playSeResFile:[self soundName:kShareCancelSoundSuffix]
                                        inDirectory:nil];
        // The cover is only faded when the marker-select overlay is not up.
        UIView *cover = isMarkerSelectOpen ? nil : coverView;
        if (shareClientView.superview == nil) {
            // A host is presenting the detail view: fade the detail view and cover out, then
            // clear and remove the detail view and hide the cover.
            if (musicDetailView.superview != nil) {
                __weak MusicDetailView *weakDetail = musicDetailView;
                [UIView animateWithDuration:kJoinViewFadeDuration
                    animations:^{
                      /** @ghidraAddress 0x2f7bc */
                      cover.alpha = 0.0;
                      weakDetail.alpha = 0.0;
                    }
                    completion:^(BOOL finished) {
                      /** @ghidraAddress 0x2f864 */
                      [weakDetail clearInfo];
                      [weakDetail removeFromSuperview];
                      cover.hidden = YES;
                    }];
            }
        } else {
            // A client is showing the share view: detach it, then fade it and the cover out and
            // remove it, hiding the cover.
            MusicShareView *shareView = shareClientView;
            [shareView setController:nil];
            shareClientView = nil;
            [UIView animateWithDuration:kJoinViewFadeDuration
                animations:^{
                  /** @ghidraAddress 0x2f6a4 */
                  cover.alpha = 0.0;
                  shareView.alpha = 0.0;
                }
                completion:^(BOOL finished) {
                  /** @ghidraAddress 0x2f730 */
                  [shareView removeFromSuperview];
                  cover.hidden = YES;
                }];
        }
        if (!isMarkerSelectOpen) {
            [self showButtonMarker:YES];
        }
        if ([[AudioManager sharedManager] popBgm]) {
            if (disconnect) {
                mainBgmSuspended = YES;
            } else {
                [[AudioManager sharedManager] startBgm:YES fadeTime:kJoinViewFadeDuration];
                mainBgmSuspended = NO;
            }
        }
    } else {
        [musicDetailView hostShareCancelled];
    }
    [self.sharePlayManager connectCancel];
    self.sharePlayManager = nil;
    shareMusicData = nil;
    if (musicDetailView != nil) {
        [musicDetailView setStartButtonEnable];
    }
    [self musicShuffleEnable];
}

/** @ghidraAddress 0x3073c */
- (void)sharePlayManager:(nullable id)manager disconnectClient:(nullable id)client {
    // A host that has started drops the session; otherwise the host is told a client disconnected.
    if (willStart) {
        [self.sharePlayManager disconnect];
        self.sharePlayManager = nil;
        return;
    }
    [[AlertViewManager sharedManager]
        makeAlert:0
         delegate:self
              tag:0
            title:[NSBundle.mainBundle localizedStringForKey:@"Error" value:@"" table:nil]
              msg:[NSBundle.mainBundle localizedStringForKey:@"SessionDisconnectedFromClientMessage"
                                                       value:@""
                                                       table:nil]
           cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
          btnText:nil
             show:YES];
}

/** @ghidraAddress 0x30960 */
- (void)sharePlayManagerDisconnect:(nullable id)manager {
    // A host that has already started simply drops the session; otherwise the client is told the
    // host disconnected.
    if (willStart) {
        [self.sharePlayManager disconnect];
        self.sharePlayManager = nil;
        return;
    }
    [[AlertViewManager sharedManager]
        makeAlert:0
         delegate:self
              tag:0
            title:[NSBundle.mainBundle localizedStringForKey:@"Error" value:@"" table:nil]
              msg:[NSBundle.mainBundle localizedStringForKey:@"SessionDisconnectedFromHostMessage"
                                                       value:@""
                                                       table:nil]
           cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
          btnText:nil
             show:YES];
}

/** @ghidraAddress 0x305a0 */
- (void)sharePlayManagerConnectFailed:(nullable id)manager {
    [[AlertViewManager sharedManager]
        makeAlert:0
         delegate:self
              tag:0
            title:[NSBundle.mainBundle localizedStringForKey:@"Error" value:@"" table:nil]
              msg:[NSBundle.mainBundle localizedStringForKey:@"SessionConnectErrorMessage"
                                                       value:@""
                                                       table:nil]
           cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
          btnText:nil
             show:YES];
}

/** @ghidraAddress 0x30280 */
- (void)sharePlayManager:(nullable id)manager receiveExistMusicData:(BOOL)exist {
    // Only when the client lacks the music does the host show the sending-data prompt.
    if (exist) {
        return;
    }
    [musicDetailView.labelShareMessage
        setText:[NSBundle.mainBundle localizedStringForKey:@"Sending music data"
                                                     value:@""
                                                     table:nil]];
}

/** @ghidraAddress 0x30ba4 */
- (BOOL)sharePlayManager:(nullable id)manager receiveMusicInfo:(nullable id)musicInfo {
    TuneInfo *received = [[TuneInfo alloc] initWithfilePath:nil dictionary:musicInfo];
    // Match the received tune against the local catalogue; when it is present the client already
    // owns the data and can start immediately.
    BOOL owned = NO;
    TuneInfo *tune = received;
    for (TuneInfo *candidate in arrayAllTune) {
        if ((unsigned int)candidate.tuneID == received.tuneID) {
            owned = YES;
            tune = candidate;
            break;
        }
    }
    ScoreRecord *record = [ScoreRecord recordForTuneID:tune.tuneID];
    [musicDetailView setInfo:tune score:record];
    [musicDetailView loadContentFromDictionary:musicInfo];
    musicDetailView.coverView.hidden = YES;
    // Flip the detail view fully around (2*pi) at the cover-flip scale, centred on the cover, so it
    // faces forward once the animation runs.
    CGFloat viewerDistance = isPad ? kCoverFlipViewerDistancePad : kCoverFlipViewerDistancePhone;
    CATransform3D perspective = CATransform3DIdentity;
    perspective.m34 = kCoverFlipPerspectiveM34;
    perspective = CATransform3DTranslate(perspective, 0, 0, viewerDistance);
    CGFloat scale = isPad ? kCoverFlipScalePad : kCoverFlipScalePhone;
    CATransform3D scaled = CATransform3DScale(perspective, scale, scale, 1.0);
    musicDetailView.layer.transform = CATransform3DRotate(scaled, g_dTwoPi, 0, 1.0, 0);
    musicDetailView.center = coverView.center;
    // Detach the client share view and fade it out, then reveal the detail view over the cover.
    MusicShareView *shareView = shareClientView;
    [shareView setController:nil];
    shareClientView = nil;
    [UIView animateWithDuration:g_dAnimDuration020
        animations:^{
          /** @ghidraAddress 0x316a4 */
          shareView.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x316c8 */
          [shareView removeFromSuperview];
        }];
    [self showButtonMarker:YES];
    [musicDetailView show:YES];
    musicDetailView.alpha = 0.0;
    [self.view insertSubview:musicDetailView aboveSubview:coverView];
    NSData *bgmData = nil;
    if (!owned) {
        // The client lacks the tune: disable start, show the receiving-data progress prompt.
        [musicDetailView.buttonStartPlay setEnabled:NO];
        [musicDetailView setIsSharedStartable:NO];
        bgmData = musicInfo[kShareMusicInfoIndexKey];
        musicDetailView.labelShareMessage.text =
            [NSBundle.mainBundle localizedStringForKey:kShareReceivingMessageKey
                                                 value:@""
                                                 table:nil];
        [musicDetailView showDataProgress:YES animated:NO];
    } else {
        // The client owns the tune: enable start, decode its BGM, and show the connected prompt.
        [musicDetailView.buttonStartPlay setEnabled:YES];
        [musicDetailView setIsSharedStartable:YES];
        [musicDetailView setStartButtonEnable];
        KUnzip *archive = [[KUnzip alloc] initWithPath:tune.filePath tail:kTuneInfoArchiveTail];
        NSMutableData *bgm = archive != nil ? [archive uncompress:kTuneBgmEntryName] : nil;
        if (bgm != nil) {
            BFCodec *codec = [[BFCodec alloc] init];
            [codec cipherInit:GetBgmCipherKey()];
            [codec decipher:bgm];
        }
        bgmData = bgm;
        NSString *connected =
            [NSString stringWithFormat:[NSBundle.mainBundle
                                           localizedStringForKey:kShareConnectedMessageFormatKey
                                                           value:@""
                                                           table:nil],
                                       self.sharePlayManager.partnerScreenName];
        musicDetailView.labelShareMessage.text = connected;
        [musicDetailView showDataProgress:NO animated:NO];
    }
    if (bgmData != nil) {
        [[AudioManager sharedManager] fadeoutBgm:kDetailCloseBgmFadeOut];
    }
    __weak MusicDetailView *weakDetail = musicDetailView;
    [UIView animateWithDuration:kShareReceiveFadeInDuration
        delay:g_dAnimDuration020
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x316e8 */
          weakDetail.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x31734 */
          if (bgmData != nil) {
              [[AudioManager sharedManager] pushBgm];
              [[AudioManager sharedManager] loadBgmData:bgmData];
              [[AudioManager sharedManager] startBgm:YES fadeTime:0.0];
          }
        }];
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:kDetailCloseRankBgDelay];
    return owned;
}

#pragma mark - BGM

/** @ghidraAddress 0x27f70 */
- (void)setupMainBgm {
    AudioManager *audio = [AudioManager sharedManager];
    int customID = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefCustomBgmIDKey];
    BOOL customOn = [NSUserDefaults.standardUserDefaults boolForKey:kPrefCustomBgmOnKey];
    BOOL loaded = NO;
    if (customID != 0 && customOn) {
        // Find the chosen custom-BGM tune and load its deciphered bgm archive member.
        TuneInfo *tune = nil;
        for (TuneInfo *candidate in arrayAllTune) {
            if ((int)candidate.tuneID == customID) {
                tune = candidate;
            }
        }
        KUnzip *archive = [[KUnzip alloc] initWithPath:tune.filePath tail:kTuneInfoArchiveTail];
        if (archive != nil) {
            NSMutableData *bgm = [archive uncompress:kCustomBgmEntryName];
            if (bgm != nil) {
                BFCodec *codec = [[BFCodec alloc] init];
                [codec cipherInit:GetBgmCipherKey()];
                [codec decipher:bgm];
                loaded = [audio loadBgmData:bgm];
            }
        }
    }
    if (!loaded) {
        [audio loadBgmResAAC:[self soundName:kMenuBgmSoundSuffix] inDirectory:nil];
    }
    [audio startBgm:YES fadeTime:kMainBgmStartFade];
}

/** @ghidraAddress 0x274f8 */
- (void)tapBgmSwitch:(nullable id)sender {
    BOOL on = [NSUserDefaults.standardUserDefaults boolForKey:kPrefCustomBgmOnKey];
    [NSUserDefaults.standardUserDefaults setBool:!on forKey:kPrefCustomBgmOnKey];
    [NSUserDefaults.standardUserDefaults synchronize];
    [self setupMainBgm];
}

/** @ghidraAddress 0x282a4 */
- (void)startMainBgm {
    if (JubeatAppDelegate.appDelegate.bChallengeMode) {
        return;
    }
    [self setupMainBgm];
    [[AudioManager sharedManager] playSeResFile:[self soundName:kMainBgmVoiceSuffix]
                                    inDirectory:nil];
}

/** @ghidraAddress 0x2838c */
- (void)checkAndRetryBgm {
    if (JubeatAppDelegate.appDelegate.bChallengeMode) {
        return;
    }
    if (![AudioManager sharedManager].bgmPlayer.isPlaying) {
        [self setupMainBgm];
    }
    if (balloonView == nil) {
        return;
    }
    balloonView.transform = CGAffineTransformMakeTranslation(0, kStoreBalloonRetryDropOffset);
    __weak BalloonView *weakBalloon = balloonView;
    [UIView animateWithDuration:kStoreBalloonRetryDuration
        animations:^{
          /** @ghidraAddress 0x2859c */
          weakBalloon.alpha = 1.0;
          weakBalloon.transform = CGAffineTransformIdentity;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x28634 */
          CAKeyframeAnimation *animation =
              [CAKeyframeAnimation animationWithKeyPath:kStoreBalloonAnimationKeyPath];
          animation.duration = kStoreBalloonAnimationDuration;
          animation.values = @[
              @(0.0f),
              @(0.0f),
              @(kStoreBalloonHopOffset),
              @(0.0f),
              @(kStoreBalloonHopOffset),
              @(0.0f),
              @(0.0f)
          ];
          animation.keyTimes = @[
              @(0.0f),
              @(kStoreBalloonKeyTime040),
              @(kStoreBalloonKeyTime050),
              @(kStoreBalloonKeyTime060),
              @(kStoreBalloonKeyTime070),
              @(kStoreBalloonKeyTime080),
              @(1.0f)
          ];
          animation.repeatCount = kStoreBalloonRepeatForever;
          animation.timingFunction =
              [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
          animation.removedOnCompletion = NO;
          [weakBalloon.layer addAnimation:animation forKey:kStoreBalloonAnimationKey];
          weakBalloon.userInteractionEnabled = YES;
        }];
}

#pragma mark - Share join

/** @ghidraAddress 0x2f930 */
- (void)pushBtnJoin:(nullable id)sender {
    [[AudioManager sharedManager] playSeResFile:[self soundName:kJoinSoundSuffix] inDirectory:nil];
    [self showButtonMarker:NO];
    [coverView setHidden:NO];
    [coverView setAlpha:0.0];
    CGFloat width = isPad ? kJoinViewWidthPad : kJoinViewWidthPhone;
    CGFloat height = isPad ? kJoinViewHeightPad : kJoinViewHeightPhone;
    shareClientView = [[MusicShareView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    [shareClientView
        setCenter:CGPointMake(self.view.frame.size.width * 0.5, self.view.frame.size.height * 0.5)];
    [shareClientView setController:self];
    [shareClientView changeClientModeSearch];
    [shareClientView setAlpha:0.0];
    [self.view insertSubview:shareClientView aboveSubview:coverView];
    self.sharePlayManager =
        [[SharePlayManager alloc] initWithScreenName:JubeatAppDelegate.appDelegate.gameCenterName];
    [self.sharePlayManager setDelegate:self];
    __weak UIView *weakCover = coverView;
    __weak MusicShareView *weakShare = shareClientView;
    __weak SharePlayManager *weakManager = self.sharePlayManager;
    [UIView animateWithDuration:kJoinViewFadeDuration
        animations:^{
          /** @ghidraAddress 0x2fdf4 */
          [weakShare setAlpha:1.0];
          [weakCover setAlpha:1.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x2fec8 */
          [weakManager startClient];
        }];
    [self musicShuffleDisable];
    [self setSearchEnable:NO];
}

#pragma mark - Sound and store navigation

/** @ghidraAddress 0x26d88 */
- (void)turnToStore {
    [notificationView stopNotification];
    id params = storeParams;
    storeParams = nil;
    if (bOpenSearchBox) {
        [searchBox setText:[NSString stringWithString:backUpString]];
        bOpenSearchBox = NO;
        [self pushSearchBox];
    }
    [self popoverClose];
    [self stopStoreInfo];
    [musicListView releaseArtworks];
    [JubeatAppDelegate.appDelegate.rootViewCtrl openStore:params];
    // Record the newest store update time seen (numeric comparison), persisting it when newer.
    if (storeUpdateTime != nil) {
        NSString *stored =
            [NSUserDefaults.standardUserDefaults stringForKey:kPrefStoreUpdateTimeKey];
        if (stored == nil || [stored compare:storeUpdateTime
                                     options:NSNumericSearch] == NSOrderedAscending) {
            [NSUserDefaults.standardUserDefaults setObject:storeUpdateTime
                                                    forKey:kPrefStoreUpdateTimeKey];
            [NSUserDefaults.standardUserDefaults synchronize];
        }
    }
}

/** @ghidraAddress 0x20c84 */
- (nullable id)soundName:(nullable id)suffix {
    // The sound-effect name carries the current theme's prefix.
    switch (JubeatAppDelegate.appDelegate.currentTheme) {
    case JubeatThemeReflecBeatPlus:
        return [NSString stringWithFormat:@"SD_RPL_%@", suffix];
    case JubeatThemeKnit:
        return [NSString stringWithFormat:@"SD_KNT_%@", suffix];
    default:
        return [NSString stringWithFormat:@"SD_%@", suffix];
    }
}

/** @ghidraAddress 0x272ac */
- (void)tapPlaylists:(nullable id)sender {
    [self setEnableGesture:YES];
    playlistViewCtrl = [[MusicPlaylistViewController alloc] initWithStyle:UITableViewStylePlain];
    [playlistViewCtrl setListMode:MusicPlaylistListModePlaylists];
    [playlistViewCtrl setPlaylistManager:playlistManager];
    [playlistViewCtrl setDelegate:self];
    playlistNavCtrl =
        [[RotatableNavigationController alloc] initWithRootViewController:playlistViewCtrl];
    if (!isPad) {
        [self presentViewController:playlistNavCtrl animated:YES completion:nil];
        bOpenModal = YES;
    } else {
        // The pad presents it as a popover pointing up from the bottom bar's playlist button.
        [playlistNavCtrl setModalPresentationStyle:UIModalPresentationPopover];
        UIPopoverPresentationController *popover = playlistNavCtrl.popoverPresentationController;
        [popover setDelegate:self];
        [popover setPermittedArrowDirections:UIPopoverArrowDirectionDown];
        [popover setSourceView:self.view];
        [popover setSourceRect:[bottomView getPlayListBtnRect]];
        [self presentViewController:playlistNavCtrl animated:YES completion:nil];
    }
    [self musicShuffleDisable];
}

/** @ghidraAddress 0x26f98 */
- (void)turnToStore:(nullable id)params {
    storeParams = params;
    // A pending consume receipt must be verified first; otherwise the store opens immediately.
    if ([[PurchaseManager sharedManager] verifyPendingConsumeReceipt]) {
        [[PurchaseManager sharedManager] setDelegate:self];
        verifyPurchaseType = kVerifyPurchaseTypeStore;
        [self showVerifyDialog:kVerifyProcessingMessage];
    } else {
        [self turnToStore];
    }
}

/** @ghidraAddress 0x26b30 */
- (void)turnToGenreOpen:(nullable id)sender {
    [self turnToStore:@{@"genre" : sender}];
}

/** @ghidraAddress 0x26bf8 */
- (void)turnToPackPurchase:(nullable id)sender {
    [self turnToStore:@{@"pack" : sender}];
}

/** @ghidraAddress 0x26cc0 */
- (void)turnToCampaignDetail:(nullable id)sender {
    [self turnToStore:@{@"campaign" : sender}];
}

/** @ghidraAddress 0x27098 */
- (void)clickPackInfomation:(nullable id)sender {
    [self dismissViewControllerAnimated:YES
                             completion:^{
                               /** @ghidraAddress 0x27188 */
                               [self turnToStore:sender];
                             }];
    bOpenModal = NO;
    bOpenInfo = NO;
    [self musicShuffleEnable];
    [self setSearchEnable:YES];
}

/** @ghidraAddress 0x2d2e0 */
- (void)tapLeaderboard:(nullable id)sender {
    [self setEnableGesture:YES];
    if (!GKLocalPlayer.localPlayer.isAuthenticated) {
        return;
    }
    [[AudioManager sharedManager] playSeResFile:[self soundName:kSettingsTapSoundSuffix]
                                    inDirectory:nil];
    GKGameCenterViewController *gc = [[GKGameCenterViewController alloc] init];
    [gc setLeaderboardIdentifier:JubeatAppDelegate.appDelegate.totalScoreLeaderboardCategory];
    [gc setGameCenterDelegate:self];
    [self presentViewController:gc animated:YES completion:nil];
    bOpenModal = YES;
    [self musicShuffleDisable];
    [self setSearchEnable:NO];
}

/** @ghidraAddress 0x34584 */
- (BOOL)checkLabURL {
    NSData *encoded = [NSUserDefaults.standardUserDefaults objectForKey:kPrefJubeatLabURLKey];
    if (encoded != nil) {
        NSMutableData *data = [NSMutableData dataWithData:encoded];
        BFCodec *codec = [[BFCodec alloc] init];
        [codec cipherInit:CreateLabUrlCipherKey()];
        [codec decipher:data];
        if (data != nil) {
            jubeatLabURL = [[NSString alloc] initWithData:data encoding:kLabURLEncoding];
            if (jubeatLabURL != nil) {
                return YES;
            }
        }
    }
    jubeatLabURL = nil;
    [NSUserDefaults.standardUserDefaults removeObjectForKey:kPrefJubeatLabURLKey];
    return NO;
}

/** @ghidraAddress 0x33374 */
- (void)moveStore:(nullable id)store packID:(nullable NSString *)packID {
    [self dismissViewControllerAnimated:YES
                             completion:^{
                               /** @ghidraAddress 0x33428 */
                               [self turnToPackPurchase:packID];
                             }];
}

#pragma mark - Playlist arrays

/** @ghidraAddress 0x1f354 */
- (void)refreshMusicList {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSMutableArray<TuneInfo *> *allTunes =
        [[NSMutableArray alloc] initWithCapacity:kMusicListInitialCapacity];
    NSMutableArray<TuneInfo *> *extendTunes = [[NSMutableArray alloc] init];
    // Built-in tunes ship in the bundle's Music folder as "<id>.jbt".
    NSString *musicDir = [NSBundle.mainBundle pathForResource:kBuiltinMusicResourceName
                                                       ofType:kBuiltinMusicResourceType];
    if (musicDir != nil) {
        for (NSNumber *musicID in StoreMusicListManager.sharedManager.builtinMusic) {
            NSString *path = [musicDir
                stringByAppendingPathComponent:[NSString stringWithFormat:kBuiltinMusicFileFormat,
                                                                          musicID.intValue]];
            BOOL isDirectory = NO;
            if ([fileManager fileExistsAtPath:path isDirectory:&isDirectory] && !isDirectory) {
                id info = [self getTuneInfo:path];
                if (info != nil) {
                    TuneInfo *tune = [[TuneInfo alloc] initWithfilePath:path dictionary:info];
                    if (tune != nil && tune.tuneID == (unsigned int)musicID.intValue) {
                        [allTunes addObject:tune];
                    }
                }
            }
        }
    }
    // Purchased and extend tunes live on disk; a metadata cache lets unchanged files skip a parse.
    NSMutableArray *storeMusic =
        [NSMutableArray arrayWithArray:StoreMusicListManager.sharedManager.purchasedMusic];
    [storeMusic addObjectsFromArray:StoreMusicListManager.sharedManager.extendMusic];
    NSArray *storeMusicList = [NSArray arrayWithArray:storeMusic];
    NSString *cachePath =
        [JubeatAppDelegate.appCachesDirectory stringByAppendingPathComponent:kMusicCacheFileName];
    NSMutableDictionary *cache = nil;
    BOOL cacheIsDirectory = NO;
    if ([fileManager fileExistsAtPath:cachePath isDirectory:&cacheIsDirectory] &&
        !cacheIsDirectory) {
        cache = [[NSMutableDictionary alloc] initWithContentsOfFile:cachePath];
    }
    if (cache == nil) {
        cache = [[NSMutableDictionary alloc] initWithCapacity:kMusicCacheInitialCapacity];
    }
    BOOL cacheDirty = NO;
    for (NSDictionary *entry in storeMusicList) {
        NSNumber *storeID = entry[kStoreMusicIDKey];
        NSString *idKey = [NSString stringWithFormat:kMusicIDFormat, storeID.unsignedIntValue];
        if (storeID == nil) {
            continue;
        }
        // Extend charts are collected separately from ordinary purchased tunes.
        NSMutableArray<TuneInfo *> *target =
            [entry[kMusicExtendFlagKey] intValue] != 0 ? extendTunes : allTunes;
        NSString *path = [StoreUtil filePathForMusicID:(int)storeID.unsignedIntValue];
        BOOL isDirectory = NO;
        if (![fileManager fileExistsAtPath:path isDirectory:&isDirectory] || isDirectory) {
            continue;
        }
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:path error:nil];
        NSNumber *fileSize = attributes[NSFileSize];
        NSDate *modificationDate = attributes[NSFileModificationDate];
        NSDictionary *cached = cache[idKey];
        if (cached != nil) {
            // A cache hit whose recorded size and timestamp still match skips re-reading the file.
            if ([cached[kMusicCacheFileSizeKey] isEqualToNumber:fileSize] &&
                [cached[kMusicCacheTimestampKey] isEqualToDate:modificationDate]) {
                TuneInfo *tune = [[TuneInfo alloc] initWithfilePath:path dictionary:cached];
                if (tune != nil && tune.tuneID == storeID.unsignedIntValue) {
                    [target addObject:tune];
                }
                continue;
            }
        }
        id info = [self getTuneInfo:path];
        if (info == nil) {
            continue;
        }
        TuneInfo *tune = [[TuneInfo alloc] initWithfilePath:path dictionary:info];
        if (tune == nil || tune.tuneID != storeID.unsignedIntValue) {
            continue;
        }
        [target addObject:tune];
        if (fileSize != nil && modificationDate != nil) {
            NSMutableDictionary *record = [[NSMutableDictionary alloc] initWithDictionary:info];
            record[kMusicCacheFileSizeKey] = fileSize;
            record[kMusicCacheTimestampKey] = modificationDate;
            cache[idKey] = [NSDictionary dictionaryWithDictionary:record];
            cacheDirty = YES;
        }
    }
    if (cacheDirty) {
        [cache writeToFile:cachePath atomically:YES];
    }
    // Index the extend tunes by id for later extend-chart lookups.
    NSMutableDictionary *extendByID =
        [[NSMutableDictionary alloc] initWithCapacity:extendTunes.count];
    for (TuneInfo *tune in extendTunes) {
        extendByID[@(tune.tuneID)] = tune;
    }
    dictAllExtendTune = [NSDictionary dictionaryWithDictionary:extendByID];
    [allTunes sortUsingSelector:@selector(compareYomi:)];
    arrayAllTune = [[NSArray alloc] initWithArray:allTunes];
    // Build the search dictionary: each tune's normalised name and artist, plus any expand-editor
    // synonyms, keyed by tune id.
    NSDictionary *expandDictionary = [[[SearchExpandEditor alloc] init] getDictionary];
    searchDictionary = [[NSMutableDictionary alloc] init];
    for (TuneInfo *tune in arrayAllTune) {
        NSMutableString *name =
            [[tune.name stringByReplacingOccurrencesOfString:kSearchTermSpace
                                                  withString:kSearchTermEmpty] mutableCopy];
        if (name == nil) {
            name = [[NSMutableString alloc] initWithString:kSearchTermEmpty];
        } else {
            CFStringTransform(
                (CFMutableStringRef)name, nullptr, kCFStringTransformHiraganaKatakana, false);
            CFStringTransform(
                (CFMutableStringRef)name, nullptr, kCFStringTransformFullwidthHalfwidth, false);
        }
        NSMutableString *artist =
            [[tune.artist stringByReplacingOccurrencesOfString:kSearchTermSpace
                                                    withString:kSearchTermEmpty] mutableCopy];
        if (artist == nil) {
            artist = [[NSMutableString alloc] initWithString:kSearchTermEmpty];
        } else {
            CFStringTransform(
                (CFMutableStringRef)artist, nullptr, kCFStringTransformHiraganaKatakana, false);
            CFStringTransform(
                (CFMutableStringRef)artist, nullptr, kCFStringTransformFullwidthHalfwidth, false);
        }
        NSMutableArray<NSString *> *terms = [[NSMutableArray alloc] init];
        [terms addObject:name];
        [terms addObject:artist];
        NSString *idKey = [NSString stringWithFormat:kMusicIDFormat, tune.tuneID];
        if (expandDictionary != nil && expandDictionary[idKey] != nil) {
            for (NSString *synonym in expandDictionary[idKey]) {
                NSMutableString *term = [synonym mutableCopy];
                CFStringTransform(
                    (CFMutableStringRef)term, nullptr, kCFStringTransformHiraganaKatakana, false);
                CFStringTransform(
                    (CFMutableStringRef)term, nullptr, kCFStringTransformFullwidthHalfwidth, false);
                [terms addObject:term];
            }
        }
        searchDictionary[@(tune.tuneID)] = terms;
    }
    [self createArrayNotYetPlayed];
    [self createArrayHold];
    [self createArrayNotHold];
    NSInteger level = [NSUserDefaults.standardUserDefaults integerForKey:kPrefPlayListLevelKey];
    [self createArrayLevel:(int)(level != 0 ? level : 1)];
    NSString *playlistsPath =
        [JubeatAppDelegate.appDocumentsDirectory stringByAppendingPathComponent:kPlaylistsFileName];
    playlistManager = [[MusicPlaylistManager alloc] initWithFile:playlistsPath];
    currentPlaylistSource = nil;
    arrayCurrentPlaylist = nil;
}

/** @ghidraAddress 0x20ff0 */
- (void)createArrayNotYetPlayed {
    arrayNotPlayedTune = [[NSMutableArray alloc] initWithArray:arrayAllTune];
    NSManagedObjectContext *context = ScoreRecordManager.sharedManager.managedObjectContext;
    NSUInteger tuneCount = arrayAllTune.count;
    NSDictionary *extendMusic = StoreMusicListManager.sharedManager.extendMusicDictionary;
    NSDictionary *originalMusic = StoreMusicListManager.sharedManager.originalMusicDictionary;
    // One-off migration: the v1 full-combo-check flag was stored per record; clear any that are
    // still set, saving each, then mark the migration done unless a record still reports it.
    if (![NSUserDefaults.standardUserDefaults boolForKey:kPrefFcCheckFlagV2Key]) {
        for (ScoreRecord *record in [ScoreRecord allRecords]) {
            if (record.fcCheck.boolValue) {
                record.fcCheck = @(NO);
                NSError *error = nil;
                if (![ScoreRecordManager.sharedManager.managedObjectContext save:&error]) {
                    NSArray *detailed = error.userInfo[NSDetailedErrorsKey];
                    if (detailed.count != 0) {
                        for (NSError *sub in detailed) {
                            (void)sub; // The binary enumerates the detailed errors without acting.
                        }
                    }
                }
            }
        }
        BOOL anyChecked = NO;
        for (ScoreRecord *record in [ScoreRecord allRecords]) {
            anyChecked |= record.fcCheck.boolValue;
        }
        if (!anyChecked) {
            [NSUserDefaults.standardUserDefaults setBool:@(YES).boolValue
                                                  forKey:kPrefFcCheckFlagV2Key];
        }
    }
    // Walk the full tune list in batches, resolving each tune's played records (plus any extend
    // alias) and removing the tunes that have a scored record from the not-played list.
    for (NSUInteger start = 0; start < tuneCount;) {
        NSUInteger batch = tuneCount - start;
        if (batch > kNotYetPlayedBatchSize) {
            batch = kNotYetPlayedBatchSize;
        }
        NSMutableArray *tuneIDs =
            [[NSMutableArray alloc] initWithCapacity:kNotYetPlayedBatchCapacity];
        for (NSUInteger i = 0; i < batch; ++i) {
            TuneInfo *tune = arrayAllTune[start + i];
            [tuneIDs addObject:@((unsigned int)tune.tuneID)];
            id aliasID = extendMusic[@((unsigned int)tune.tuneID)][kStoreMusicIDKey];
            if (aliasID != nil) {
                [tuneIDs addObject:aliasID];
            }
        }
        NSArray<ScoreRecord *> *records = [ScoreRecord recordsForTuneIDs:tuneIDs];
        if (records.count != 0) {
            // The scored tune ids in this batch, plus the original-music aliases of any that map
            // back to a different real id.
            NSMutableArray *scoredIDs =
                [[NSMutableArray alloc] initWithCapacity:kNotYetPlayedRecordCapacity];
            for (ScoreRecord *record in records) {
                if (![scoredIDs containsObject:@(record.tuneID)] &&
                    [ScoreRecord checkScore:record]) {
                    [scoredIDs addObject:@(record.tuneID)];
                }
            }
            NSMutableArray *aliasIDs = [[NSMutableArray alloc] init];
            for (NSInteger i = (NSInteger)scoredIDs.count - 1; i >= 0; --i) {
                id original = originalMusic[scoredIDs[i]];
                if (original != nil) {
                    id originalID = original[kStoreMusicIDKey];
                    if ([scoredIDs indexOfObject:originalID] == NSNotFound) {
                        [aliasIDs addObject:original[kStoreMusicIDKey]];
                    }
                }
            }
            if (aliasIDs.count != 0) {
                [scoredIDs addObjectsFromArray:aliasIDs];
            }
            if (scoredIDs.count != 0) {
                NSPredicate *predicate =
                    [NSPredicate predicateWithFormat:kNotYetPlayedPredicateFormat, scoredIDs];
                [arrayNotPlayedTune filterUsingPredicate:predicate];
            }
        }
        [context reset];
        start += batch;
    }
}

/** @ghidraAddress 0x21bbc */
- (void)createArrayLevel:(int)level {
    arrayLevelList = nil;
    arrayLevelList = [[NSMutableArray alloc] init];
    for (TuneInfo *tune in arrayAllTune) {
        if (MusicSelectTuneHasLevel(self, tune, level)) {
            [arrayLevelList addObject:tune];
        }
    }
}

/** @ghidraAddress 0x21e34 */
- (void)createArrayHold {
    if (arrayHoldList != nil) {
        arrayHoldList = nil;
    }
    arrayHoldList = [[NSMutableArray alloc] init];
    for (TuneInfo *tune in arrayAllTune) {
        if (MusicSelectTuneIsHold(self, tune)) {
            [arrayHoldList addObject:tune];
        }
    }
}

/** @ghidraAddress 0x22014 */
- (void)createArrayNotHold {
    // The binary tests arrayNotHoldList for the reset but clears arrayHoldList; kept as-is.
    if (arrayNotHoldList != nil) {
        arrayHoldList = nil;
    }
    arrayNotHoldList = [[NSMutableArray alloc] init];
    for (TuneInfo *tune in arrayAllTune) {
        if (!MusicSelectTuneIsHold(self, tune)) {
            [arrayNotHoldList addObject:tune];
        }
    }
}

/** @ghidraAddress 0x22488 */
- (void)preparePlaylistArray:(NSInteger)index {
    arrayCurrentPlaylist = nil;
    switch (index) {
    case kPlaylistSelectionNotHold:
        currentPlaylistSource = arrayNotHoldList;
        arrayCurrentPlaylist = arrayNotHoldList;
        break;
    case kPlaylistSelectionHold:
        currentPlaylistSource = arrayHoldList;
        arrayCurrentPlaylist = arrayHoldList;
        break;
    case kPlaylistSelectionLevel: {
        NSInteger level = [NSUserDefaults.standardUserDefaults integerForKey:kPrefPlayListLevelKey];
        [self createArrayLevel:(int)(level != 0 ? level : 1)];
        currentPlaylistSource = arrayLevelList;
        arrayCurrentPlaylist = arrayLevelList;
        break;
    }
    case kPlaylistSelectionNotPlayed:
        currentPlaylistSource = arrayNotPlayedTune;
        arrayCurrentPlaylist = arrayNotPlayedTune;
        break;
    case kPlaylistSelectionDefault:
        currentPlaylistSource = nil;
        arrayCurrentPlaylist = nil;
        break;
    default:
        if (index >= 0) {
            // A saved playlist: collect the full tune list's members that belong to it.
            currentPlaylistSource = [playlistManager playlistAtIndex:index];
            arrayCurrentPlaylist = [[NSMutableArray alloc] initWithCapacity:arrayAllTune.count];
            for (TuneInfo *tune in arrayAllTune) {
                if ([playlistManager containsMusic:tune.tuneID inPlaylistAtIndex:index]) {
                    [arrayCurrentPlaylist addObject:tune];
                }
            }
        }
        break;
    }
    // Apply the active search filter over whichever list was selected (or the full list when no
    // playlist filter is in force).
    if (searchArray != nil && searchArray.count != 0) {
        NSArray<TuneInfo *> *source = (arrayCurrentPlaylist == nil) ?
                                          [NSMutableArray arrayWithArray:arrayAllTune] :
                                          [NSMutableArray arrayWithArray:arrayCurrentPlaylist];
        arrayCurrentPlaylist = [[NSMutableArray alloc] initWithCapacity:arrayAllTune.count];
        for (TuneInfo *tune in source) {
            if ([self matchTitle:tune]) {
                [arrayCurrentPlaylist addObject:tune];
            }
        }
    }
}

#pragma mark - Edit and shuffle

/** @ghidraAddress 0x2ea1c */
- (void)startPlay:(nullable id)tune {
    [self stopStoreInfo];
    [musicListView releaseArtworks];
    [[AudioManager sharedManager] fadeoutBgm:1.0];
    // A non-host share client does not overwrite the last-played id.
    if (self.sharePlayManager == nil || self.sharePlayManager.isHost) {
        [NSUserDefaults.standardUserDefaults setInteger:((TuneInfo *)tune).tuneID
                                                 forKey:kPrefLastPlayedIDKey];
    }
    NSInteger editPage = [NSUserDefaults.standardUserDefaults integerForKey:kPrefEditSelectKey];
    NSInteger difficulty = [NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
    // Off the edit page and in extend mode, play the extend chart when the tune carries one for the
    // current difficulty; otherwise play the base tune.
    TuneInfo *playTune = tune;
    if (((TuneInfo *)tune).extendID != 0 && editPage != 1 &&
        JubeatAppDelegate.appDelegate.isExtend) {
        TuneInfo *extend = dictAllExtendTune[@(((TuneInfo *)tune).extendID)];
        if (extend != nil && (extend.extendFlag & (1 << difficulty)) != 0) {
            playTune = extend;
        }
    }
    [JubeatAppDelegate.appDelegate.rootViewCtrl startMainGame:playTune
                                                 shareManager:self.sharePlayManager
                                                    musicData:shareMusicData];
    self.sharePlayManager = nil;
    shareMusicData = nil;
    [self setEnableGesture:NO];
}

/** @ghidraAddress 0x2ee04 */
- (void)startEdit:(nullable id)tune {
    [self stopStoreInfo];
    [musicListView releaseArtworks];
    [[AudioManager sharedManager] fadeoutBgm:1.0];
    // A non-host share client does not overwrite the last-played id.
    if (self.sharePlayManager == nil || self.sharePlayManager.isHost) {
        [NSUserDefaults.standardUserDefaults setInteger:((TuneInfo *)tune).tuneID
                                                 forKey:kPrefLastPlayedIDKey];
    }
    [JubeatAppDelegate.appDelegate.rootViewCtrl startEditNote:tune
                                                    musicData:shareMusicData
                                                      jcfName:nil];
    self.sharePlayManager = nil;
    shareMusicData = nil;
    [self setEnableGesture:NO];
}

/** @ghidraAddress 0x35628 */
- (void)setRandomSelect {
    NSArray<TuneInfo *> *list = arrayCurrentPlaylist ?: arrayAllTune;
    if (list.count == 0 || !bEnableShuffle) {
        return;
    }
    int lastPlayed = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefLastPlayedIDKey];
    unsigned int count = (unsigned int)list.count;
    unsigned int index = arc4random() % count;
    TuneInfo *tune = list[index];
    // If the random pick repeats the last-played tune, step on by a second random offset.
    if ((int)tune.tuneID == lastPlayed) {
        index = (index + (unsigned int)rand()) % count;
        tune = list[index];
    }
    [NSUserDefaults.standardUserDefaults setInteger:tune.tuneID forKey:kPrefLastPlayedIDKey];
    if (!bOpenMusicDetail) {
        [self startOpenDetailPanel];
    } else if (list.count != 1 && !bSuffleAnim) {
        [self shuffleAnimation:tune];
    }
}

/** @ghidraAddress 0x3486c */
- (void)shuffleAnimation:(nullable id)tune {
    int slideOffset = isPad ? kShuffleSlideOffsetPad : kShuffleSlideOffsetPhone;
    bSuffleAnim = YES;
    __weak UIView *weakCover = coverView;
    __weak MusicDetailView *weakDetail = musicDetailView;
    __weak MusicView *weakSelected = selectedMusicView;
    musicDetailView.transform = CGAffineTransformMakeTranslation(0, 0);
    [[AudioManager sharedManager] fadeoutBgm:kShuffleBgmFadeOut];
    [[AudioManager sharedManager] playSeResFile:[self soundName:kShuffleSoundSuffix]
                                    inDirectory:nil];
    [UIView animateWithDuration:kShuffleSlideDuration
        delay:0.0
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          /** @ghidraAddress 0x34ba0 */
          weakDetail.transform = CGAffineTransformMakeTranslation(-slideOffset, 0);
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x34c2c */
          [self changeMusicData:tune];
          [UIView animateWithDuration:kShuffleFlipDuration / kShuffleFlipStageDivisor
              delay:0.0
              options:UIViewAnimationOptionCurveEaseIn
              animations:^{
                /** @ghidraAddress 0x34dbc */
                weakDetail.transform = CGAffineTransformMakeTranslation(0, 0);
              }
              completion:^(BOOL innerFinished) {
                /** @ghidraAddress 0x34e40 */
                CGFloat viewerDistance =
                    isPad ? kCoverFlipViewerDistancePad : kCoverFlipViewerDistancePhone;
                CATransform3D perspective = CATransform3DIdentity;
                perspective.m34 = kCoverFlipPerspectiveM34;
                perspective = CATransform3DTranslate(perspective, 0, 0, viewerDistance);
                // The selected music view's artwork flips to its front (pi about the vertical
                // axis), centred over the cover.
                UIImageView *imgView = weakSelected.imgView;
                imgView.center = weakCover.center;
                imgView.layer.transform = CATransform3DRotate(perspective, g_dPi, 0, -1.0, 0);
                // The detail view flips full-circle (2*pi) at the shrunk cover-flip scale, also
                // centred over the cover.
                CGFloat scale = isPad ? kCoverFlipScalePad : kCoverFlipScalePhone;
                CATransform3D scaled = CATransform3DScale(perspective, scale, scale, 1.0);
                weakDetail.center = weakCover.center;
                weakDetail.layer.transform = CATransform3DRotate(scaled, g_dTwoPi, 0, 1.0, 0);
                bSuffleAnim = NO;
              }];
        }];
}

#pragma mark - Search box

/** @ghidraAddress 0x35dfc */
- (void)pushSearchBox {
    if (bOpenSearchBox) {
        [searchBox setText:[NSString stringWithString:backUpString]];
        [[AudioManager sharedManager] playSeResFile:[self soundName:kSearchBoxCloseSoundSuffix]
                                        inDirectory:nil];
    }
    bOpenSearchBox = NO;
    [self showButtonMarker:YES];
    if (searchArray.count != 0) {
        [searchArray removeAllObjects];
        [self exeSearchPickUp];
    }
    [searchBox resignFirstResponder];
    __weak UISearchBar *weakSearch = searchBox;
    __weak UIButton *weakCancel = searchCancelBtn;
    [UIView animateWithDuration:kSearchBoxSlideDuration
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowAnimatedContent
                     animations:^{
                       /** @ghidraAddress 0x36068 */
                       weakSearch.transform =
                           CGAffineTransformMakeTranslation(0.0, kSearchBoxSlideOffset);
                       weakCancel.transform =
                           CGAffineTransformMakeTranslation(0.0, kSearchBoxSlideOffset);
                     }
                     completion:nil];
}

/** @ghidraAddress 0x361b4 */
- (void)pullSearchBox {
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:0.0];
    bOpenSearchBox = YES;
    if (![NSUserDefaults.standardUserDefaults boolForKey:kPrefSearchTutorialFinishKey]) {
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:kPrefSearchTutorialFinishKey];
    }
    [searchBox becomeFirstResponder];
    if (searchArray.count == 0) {
        [self showButtonMarker:NO];
        searchArray = [NSMutableArray arrayWithArray:[self getSearchArray:searchBox.text]];
        if (searchArray.count != 0) {
            [self exeSearchPickUp];
        }
        __weak UISearchBar *weakSearch = searchBox;
        __weak UIButton *weakCancel = searchCancelBtn;
        __weak UIView *weakTutorial = searchTutorialView;
        [UIView animateWithDuration:kSearchBoxSlideDuration
            delay:0.0
            options:UIViewAnimationOptionCurveLinear
            animations:^{
              /** @ghidraAddress 0x36544 */
              weakSearch.transform = CGAffineTransformMakeTranslation(0.0, 0.0);
              weakCancel.transform = CGAffineTransformMakeTranslation(0.0, 0.0);
              if (weakTutorial != nil) {
                  weakTutorial.alpha = 0.0;
              }
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x366bc */
              if (searchTutorialView != nil) {
                  [searchTutorialView removeFromSuperview];
                  searchTutorialView = nil;
              }
            }];
    }
}

#pragma mark - Button marker

/** @ghidraAddress 0x2e4fc */
- (void)showButtonMarker:(BOOL)show {
    __weak UIButton *weakMarker = btnMarker;
    // The search box is lifted above the marker button for the transition.
    searchBox.layer.zPosition = kSearchBoxRaisedZPosition;
    if (!show) {
        [btnMarker setEnabled:NO];
        [UIView animateWithDuration:kButtonMarkerAnimDuration
            animations:^{
              /** @ghidraAddress 0x2e8e0 */
              weakMarker.transform =
                  CGAffineTransformMakeTranslation(0.0, -weakMarker.frame.size.height);
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x2e994 */
              self->searchBox.layer.zPosition = 0.0;
            }];
    } else {
        [UIView animateWithDuration:kButtonMarkerAnimDuration
            animations:^{
              /** @ghidraAddress 0x2e744 */
              weakMarker.transform = CGAffineTransformIdentity;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x2e7b4 */
              self->searchBox.layer.zPosition = 0.0;
              [weakMarker setEnabled:YES];
              if (!MarkerManager.enableMarkerSelect) {
                  [weakMarker setEnabled:NO];
              }
            }];
    }
}

/** @ghidraAddress 0x31e78 */
- (void)tapMarkerSelect:(nullable id)sender {
    [self setEnableGesture:YES];
    __weak MarkerSelectView *weakMarkerSelect = markerSelectView;
    __weak UIButton *weakMarker = btnMarker;
    __weak UIView *weakCover = nil;
    if (!isMarkerSelectOpen) {
        // Open: reveal the overlay and its cover, slide the overlay and marker button in while
        // fading the cover up.
        [markerSelectView startLoadMarker:YES];
        markerSelectView.hidden = NO;
        markerSelectCover.hidden = NO;
        UIView *cover;
        if (musicDetailView.superview == nil) {
            cover = coverView;
        } else {
            [musicDetailView activateAnim:NO];
            cover = musicDetailView.coverView;
        }
        cover.hidden = NO;
        cover.alpha = 0.0;
        weakCover = cover;
        [UIView animateWithDuration:kMarkerSelectOpenDuration
                         animations:^{
                           /** @ghidraAddress 0x32864 */
                           CGFloat offset =
                               isPad ? kMarkerSelectSlideOffsetPad : kMarkerSelectSlideOffsetPhone;
                           CGAffineTransform slide = CGAffineTransformMakeTranslation(0.0, offset);
                           weakMarkerSelect.transform = slide;
                           weakMarker.transform = slide;
                           weakCover.alpha = 1.0;
                         }
                         completion:nil];
        [[AudioManager sharedManager] playSeResFile:[self soundName:kMarkerSelectOpenSoundSuffix]
                                        inDirectory:nil];
        isMarkerSelectOpen = YES;
        [searchBox resignFirstResponder];
        [self setSearchEnable:NO];
        [self musicShuffleDisable];
    } else {
        // Close: reverse the slide and fade, then re-activate the detail animation and hide the
        // overlay and covers.
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        UIView *cover = (musicDetailView.superview == nil) ? coverView : musicDetailView.coverView;
        cover.alpha = 1.0;
        weakCover = cover;
        [markerSelectView close];
        __weak MusicDetailView *weakDetail = musicDetailView;
        __weak UIView *weakMarkerCover = markerSelectCover;
        [UIView animateWithDuration:kMarkerSelectCloseDuration
            animations:^{
              /** @ghidraAddress 0x325b4 */
              weakMarkerSelect.transform = CGAffineTransformIdentity;
              weakMarker.transform = CGAffineTransformIdentity;
              weakCover.alpha = 0.0;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x326fc */
              if (weakDetail.superview != nil) {
                  [weakDetail activateAnim:YES];
              }
              weakCover.hidden = YES;
              weakMarkerSelect.hidden = YES;
              weakMarkerCover.hidden = YES;
            }];
        [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                                withObject:nil
                                                afterDelay:kMarkerSelectUnlockDelay];
        [[AudioManager sharedManager] playSeResFile:[self soundName:kMarkerSelectCloseSoundSuffix]
                                        inDirectory:nil];
        isMarkerSelectOpen = NO;
        if (self.sharePlayManager == nil) {
            [self musicShuffleEnable];
            [self setSearchEnable:YES];
        } else {
            [self musicShuffleDisable];
            [self setSearchEnable:NO];
        }
    }
}

#pragma mark - Scroll paging

/** @ghidraAddress 0x39078 */
- (void)scrollFromPageNum:(int)pageNum bAnim:(BOOL)animated {
    if (scrollBg == nil) {
        return;
    }
    int width = (int)scrollBg.frame.size.width;
    int quotient = (scrollPageNum != 0) ? pageNum / scrollPageNum : 0;
    int target = pageNum - quotient * scrollPageNum;
    int current = (int)(scrollBg.contentOffset.x / (double)width);
    // On the wrap boundary the target stays on the trailing clone page.
    int dest = (current != scrollPageNum - 1 || target != 0) ? target : scrollPageNum;
    // Jump the looped scroll view to the matching real page without animation before the animated
    // move, so paging past either end wraps seamlessly.
    if (current == scrollPageNum && dest == 1) {
        [scrollBg setContentOffset:CGPointMake(0.0, 0.0)];
    }
    if (current == 0 && dest == scrollPageNum - 1) {
        [scrollBg setContentOffset:CGPointMake((double)(scrollPageNum * width), 0.0)];
    }
    [scrollBg setContentOffset:CGPointMake((double)(dest * width), 0.0) animated:animated];
}

#pragma mark - Search

/** @ghidraAddress 0x221fc */
- (BOOL)matchTitle:(nullable id)tune {
    // Every search term must appear (case-insensitively) in at least one of the tune's search
    // strings, looked up by tune id. No terms matches everything.
    NSArray<NSString *> *strings = searchDictionary[@(((TuneInfo *)tune).tuneID)];
    for (NSString *term in searchArray) {
        BOOL matched = NO;
        for (NSString *candidate in strings) {
            if (candidate != nil &&
                [candidate rangeOfString:term options:NSCaseInsensitiveSearch].location !=
                    NSNotFound) {
                matched = YES;
            }
        }
        if (!matched) {
            return NO;
        }
    }
    return YES;
}

/** @ghidraAddress 0x35a9c */
- (BOOL)searchStringChanged:(nullable id)searchString {
    // Recompute the search terms; the query changed when the term count differs or any new term is
    // absent from the previous set.
    NSArray *previous = [NSArray arrayWithArray:searchArray];
    searchArray = [NSMutableArray arrayWithArray:[self getSearchArray:searchString]];
    if (previous.count != searchArray.count) {
        return YES;
    }
    for (id term in previous) {
        if (![searchArray containsObject:term]) {
            return YES;
        }
    }
    return NO;
}

/** @ghidraAddress 0x35cb8 */
- (void)setSearchEnable:(BOOL)enable {
    // The swipe recognisers are enabled only when a music detail is not open and the caller asks.
    BOOL on = !bOpenMusicDetail && enable;
    for (UIGestureRecognizer *recognizer in arraySwipeRecognizer) {
        [recognizer setEnabled:on];
    }
}

/** @ghidraAddress 0x35944 */
- (nullable id)getSearchArray:(nullable NSString *)searchString {
    // Normalise kana and width (twice each, matching the binary), split on spaces, de-duplicate via
    // a set, and drop empty terms.
    NSMutableString *normalised = [searchString mutableCopy];
    CFStringTransform(
        (CFMutableStringRef)normalised, NULL, kCFStringTransformHiraganaKatakana, false);
    CFStringTransform(
        (CFMutableStringRef)normalised, NULL, kCFStringTransformFullwidthHalfwidth, false);
    CFStringTransform(
        (CFMutableStringRef)normalised, NULL, kCFStringTransformHiraganaKatakana, false);
    CFStringTransform(
        (CFMutableStringRef)normalised, NULL, kCFStringTransformFullwidthHalfwidth, false);
    NSArray *terms = [normalised componentsSeparatedByString:@" "];
    NSMutableArray *unique = [NSMutableArray arrayWithArray:[NSSet setWithArray:terms].allObjects];
    [unique removeObject:@""];
    return unique;
}

/** @ghidraAddress 0x367f0 */
- (void)exeSearchPickUp {
    // The app-wide search string reflects the current query (nil when empty).
    if (searchArray.count == 0) {
        [JubeatAppDelegate.appDelegate setSearchString:nil];
    } else {
        [JubeatAppDelegate.appDelegate setSearchString:searchBox.text];
    }
    // Resolve the list selection: a remembered named playlist by index, or a built-in sentinel.
    NSUInteger listType =
        [playlistManager indexOfPlaylistWithIdentifier:[NSUserDefaults.standardUserDefaults
                                                           stringForKey:kPrefLastPlaylistKey]];
    if (listType == NSNotFound) {
        if ([NSUserDefaults.standardUserDefaults integerForKey:kPrefPlayListLevelKey] == 0) {
            listType = (playListIndex == -1) ? (NSUInteger)kPlaylistSelectionNotPlayed :
                                               (NSUInteger)kPlaylistSelectionDefault;
        } else {
            listType = (NSUInteger)kPlaylistSelectionLevel;
        }
    }
    NSUInteger lastPlayed =
        [NSUserDefaults.standardUserDefaults integerForKey:kPrefLastPlayedIDKey];
    [self changeMusicListView:(NSInteger)listType musicID:lastPlayed];
}

/** @ghidraAddress 0x369f8 */
- (void)searchBar:(nullable UISearchBar *)searchBar textDidChange:(nullable NSString *)searchText {
    backUpString = [NSString stringWithString:searchText];
    if ([self searchStringChanged:searchText]) {
        [self exeSearchPickUp];
    }
}

#pragma mark - Store info

/** @ghidraAddress 0x27d54 */
- (void)requestNewInfo {
    if (infoDownloader != nil) {
        [infoDownloader cancel];
        infoDownloader = nil;
    }
    storeUpdateTime = nil;
    NSURL *url = [StoreUtil storeNewInfoURL];
    // A logged-in editor appends its id to the request URL.
    if (EditorIDManager.isExistEditorID) {
        NSString *key = [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
        NSString *query = [NSString stringWithFormat:kNewInfoUserIDFormat, key];
        url = [NSURL
            URLWithString:[NSString
                              stringWithFormat:kNewInfoURLConcatFormat, url.absoluteString, query]];
    }
    infoDownloader = [[Downloader alloc] initWithURL:url delegate:self];
    [infoDownloader setTag:0];
    [infoDownloader startDownloading];
}

/** @ghidraAddress 0x271ec */
- (void)stopStoreInfo {
    if (infoDownloader != nil) {
        [infoDownloader cancel];
        infoDownloader = nil;
    }
    if (challengeInfoDownloader != nil) {
        [challengeInfoDownloader cancel];
        challengeInfoDownloader = nil;
    }
    if (infoBannerTimer != nil) {
        [infoBannerTimer invalidate];
        infoBannerTimer = nil;
    }
}

#pragma mark - Settings

/** @ghidraAddress 0x2d030 */
- (void)tapSettings:(nullable id)sender {
    if (notificationView.isActive) {
        [notificationView stopNotification];
    }
    [self setEnableGesture:YES];
    [[AudioManager sharedManager] playSeResFile:[self soundName:kSettingsTapSoundSuffix]
                                    inDirectory:nil];
    [self presentViewController:settingsNavCtrl animated:YES completion:nil];
    bOpenModal = YES;
    bOpenSetting = YES;
    [self musicShuffleDisable];
    [self setSearchEnable:NO];
}

/** @ghidraAddress 0x2d160 */
- (void)settingsNavViewClose:(nullable id)sender {
    [[AudioManager sharedManager] playSeResFile:[self soundName:@"MUSIC_LEFT"] inDirectory:nil];
    [self dismissViewControllerAnimated:YES completion:nil];
    bOpenModal = NO;
    bOpenSetting = NO;
    [self musicShuffleEnable];
    [self setSearchEnable:YES];
    [notificationView startNotification];
}

#pragma mark - Cover view

/** @ghidraAddress 0x2a2b8 */
- (void)showCoverView:(nullable id)appendViews addGesture:(nullable id)gesture {
    if (bOpenDelegateCover) {
        return;
    }
    bOpenDelegateCover = YES;
    if (!bOpenSearchBox) {
        [self showButtonMarker:NO];
    }
    [self setSearchEnable:NO];
    [self musicShuffleDisable];
    [coverView setHidden:NO];
    [coverView setAlpha:0.0];
    if (appendViews != nil) {
        // Tear down any previous appended cover views and add the new ones.
        if (appendCoverView != nil) {
            for (NSUInteger i = 0; i < appendCoverView.count; ++i) {
                [appendCoverView[i] removeFromSuperview];
            }
            appendCoverView = nil;
        }
        appendCoverView = appendViews;
        for (NSUInteger i = 0; i < ((NSArray *)appendViews).count; ++i) {
            [coverView addSubview:appendViews[i]];
        }
    }
    if (gesture != nil) {
        if (appendCoverGesture != nil) {
            [coverView removeGestureRecognizer:appendCoverGesture];
            appendCoverGesture = nil;
        }
        appendCoverGesture = gesture;
        [coverView addGestureRecognizer:gesture];
    }
    __weak UIView *weakCover = coverView;
    [UIView animateWithDuration:g_dAnimDuration020
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowAnimatedContent
                     animations:^{
                       /** @ghidraAddress 0x2a600 */
                       [weakCover setAlpha:1.0];
                     }
                     completion:nil];
}

/** @ghidraAddress 0x2a650 */
- (void)hiddenCoverView {
    if (!bOpenDelegateCover) {
        return;
    }
    bOpenDelegateCover = NO;
    if (!bOpenSearchBox) {
        [self showButtonMarker:YES];
    }
    [self setSearchEnable:YES];
    [self musicShuffleEnable];
    [coverView setAlpha:1.0];
    __weak UIView *weakCover = coverView;
    [UIView animateWithDuration:g_dAnimDuration020
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowAnimatedContent
        animations:^{
          /** @ghidraAddress 0x2a7fc */
          [weakCover setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x2a848 */
          [weakCover setHidden:YES];
          if (appendCoverView != nil) {
              for (NSUInteger i = 0; i < appendCoverView.count; ++i) {
                  [appendCoverView[i] removeFromSuperview];
              }
              appendCoverView = nil;
          }
        }];
}

/** @ghidraAddress 0x2af98 */
- (void)musicViewTapped:(nullable id)view {
    MusicView *musicView = view;
    searchBox.text = [NSString stringWithString:backUpString];
    [searchBox resignFirstResponder];
    [self setSearchEnable:NO];
    if (selectedMusicView != nil) {
        return;
    }
    selectedMusicView = musicView;
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [[AudioManager sharedManager] playSeResFile:[self soundName:kMusicSelectDetailSoundSuffix]
                                    inDirectory:nil];
    [musicListView hideAllPlaylistAction];
    coverView.hidden = NO;
    coverView.alpha = 1.0;
    musicDetailView.alpha = 1.0;
    musicDetailView.coverView.hidden = YES;
    // Lift the tapped tile's artwork out of the tile and onto the controller's view at the same
    // screen point, then flip it and the detail view onto the cover with the shared cover-flip
    // pose.
    UIImageView *artwork = musicView.imgView;
    artwork.userInteractionEnabled = NO;
    artwork.center = [musicView convertPoint:musicView.imgView.center toView:self.view];
    [artwork removeFromSuperview];
    [self.view addSubview:artwork];
    CGFloat scale = isPad ? kCoverFlipScalePad : kCoverFlipScalePhone;
    CATransform3D perspective = CATransform3DIdentity;
    perspective.m34 = kCoverFlipPerspectiveM34;
    CATransform3D scaled = CATransform3DScale(perspective, scale, scale, 1.0);
    musicDetailView.center = artwork.center;
    musicDetailView.layer.transform = CATransform3DRotate(scaled, g_dPi, 0, 1.0, 0);
    ScoreRecord *record = [ScoreRecord recordForTuneID:musicView.tuneInfo.tuneID];
    [musicDetailView setInfo:musicView.tuneInfo score:record];
    TuneInfo *tune = musicView.tuneInfo;
    BOOL hasExtend = NO;
    if (tune.extendID != 0 && [StoreUtil existMusicFile:(int)tune.extendID]) {
        hasExtend = YES;
        TuneInfo *extend = dictAllExtendTune[@(tune.extendID)];
        ScoreRecord *extendRecord = [ScoreRecord recordForTuneID:tune.extendID];
        [musicDetailView setExtendInfo:extend score:extendRecord];
        if (![NSUserDefaults.standardUserDefaults boolForKey:kPrefExtendTutorialFinishKey]) {
            if ([NSUserDefaults.standardUserDefaults integerForKey:kPrefEditSelectKey] ==
                kEditSelectActive) {
                [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefEditSelectKey];
            }
            NSInteger difficulty =
                [NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
            if ((extend.extendFlag & (1u << ((unsigned int)difficulty & 0x1f))) == 0) {
                // No extend chart for this difficulty: the binary reads the flag three more times
                // and discards each. Kept for fidelity.
                (void)extend.extendFlag;
                (void)extend.extendFlag;
                (void)extend.extendFlag;
            } else if ((int)difficulty >= 0) {
                extendTutorialView.alpha = 0.0;
                [NSUserDefaults.standardUserDefaults setInteger:difficulty
                                                         forKey:kPrefDifficultyKey];
                [self.view addSubview:extendTutorialView];
            }
        }
    } else {
        [musicDetailView setExtendInfo:nil score:nil];
    }
    [musicDetailView show:NO];
    [self.view insertSubview:musicDetailView aboveSubview:coverView];
    [[AudioManager sharedManager] fadeoutBgm:kDetailCloseBgmFadeOut];
    __weak UIView *weakCover = coverView;
    __weak MusicDetailView *weakDetail = musicDetailView;
    __weak MusicView *weakSelected = musicView;
    __weak UIImageView *weakArtwork = musicView.imgView;
    __weak UIView *weakTutorial = extendTutorialView;
    CGFloat listAlpha = [musicListView getMusicListAlpha];
    musicView.imgView.alpha = listAlpha;
    musicDetailView.alpha = listAlpha;
    [UIView animateWithDuration:kDetailCloseFlipDuration
        delay:0.0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x2bc9c */
          CGFloat innerScale = isPad ? kCoverFlipScalePad : kCoverFlipScalePhone;
          CGFloat viewerDistance =
              isPad ? kCoverFlipViewerDistancePad : kCoverFlipViewerDistancePhone;
          CATransform3D flip = CATransform3DIdentity;
          flip.m34 = kCoverFlipPerspectiveM34;
          flip = CATransform3DTranslate(flip, 0, 0, viewerDistance);
          weakArtwork.alpha = 1.0;
          weakArtwork.center = weakSelected.center;
          weakArtwork.layer.transform = CATransform3DRotate(flip, g_dPi, 0, -1.0, 0);
          CATransform3D scaledFlip = CATransform3DScale(flip, innerScale, innerScale, 1.0);
          weakDetail.center = weakSelected.center;
          weakDetail.layer.transform = CATransform3DRotate(scaledFlip, g_dTwoPi, 0, 1.0, 0);
          weakCover.alpha = 1.0;
          weakDetail.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x2c0b0 */
          if (hasExtend &&
              ![NSUserDefaults.standardUserDefaults boolForKey:kPrefExtendTutorialFinishKey]) {
              weakSelected.hidden = YES;
              NSInteger difficulty =
                  [NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
              weakTutorial.hidden = NO;
              CGFloat side = musicListView.artworkSize * (isPad ? kExtendTutorialArtworkScalePad :
                                                                  kExtendTutorialArtworkScalePhone);
              CGRect bounds = self.view.bounds;
              int originX = (int)((bounds.size.width - side) * 0.5);
              int originY = (int)((bounds.size.height - side) * 0.5);
              CGPoint pos = [musicDetailView getDifficultyPos:(int)difficulty];
              JubeatTheme theme = JubeatAppDelegate.appDelegate.currentTheme;
              int inset = kExtendTutorialInsetByThemeAndDevice[theme][isPad ? 0 : 1];
              CGRect frame = extendTutorialFrame.frame;
              extendTutorialFrame.frame = CGRectMake((double)originX + pos.x - inset,
                                                     (double)originY + pos.y - inset,
                                                     frame.size.width,
                                                     frame.size.height);
              [UIView animateWithDuration:kExtendTutorialShowDuration
                               animations:^{
                                 /** @ghidraAddress 0x2c5f8 */
                                 weakTutorial.alpha = 1.0;
                                 [NSUserDefaults.standardUserDefaults
                                     setBool:YES
                                      forKey:kPrefExtendTutorialFinishKey];
                               }];
          }
          // Decode and start the tune's own BGM under the pushed menu BGM.
          [[AudioManager sharedManager] pushBgm];
          KUnzip *archive = [[KUnzip alloc] initWithPath:weakSelected.tuneInfo.filePath
                                                    tail:kTuneInfoArchiveTail];
          NSMutableData *bgm = archive != nil ? [archive uncompress:kTuneBgmEntryName] : nil;
          if (bgm != nil) {
              BFCodec *codec = [[BFCodec alloc] init];
              [codec cipherInit:GetBgmCipherKey()];
              [codec decipher:bgm];
              [[AudioManager sharedManager] loadBgmData:bgm];
              [[AudioManager sharedManager] startBgm:YES fadeTime:0.0];
          }
        }];
    // The rank backgrounds fade out and the name/artist labels hide alongside the flip.
    [UIView animateWithDuration:kDetailCloseRankBgDuration
                     animations:^{
                       /** @ghidraAddress 0x2c700 */
                       weakSelected.rankBgBas.alpha = 0.0;
                       weakSelected.rankBgAdv.alpha = 0.0;
                       weakSelected.rankBgExt.alpha = 0.0;
                       for (UIView *chip in weakSelected.rankBgChipArray) {
                           chip.alpha = 0.0;
                       }
                       weakSelected.adRankBgBas.alpha = 0.0;
                       weakSelected.adRankBgAdv.alpha = 0.0;
                       weakSelected.adRankBgExt.alpha = 0.0;
                     }];
    [UIView animateWithDuration:kDetailCloseLabelDuration
                     animations:^{
                       /** @ghidraAddress 0x2c9d4 */
                       [weakSelected showNameAndArtist:NO];
                     }];
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:kDetailCloseUnlockDelay];
    bOpenMusicDetail = YES;
}

/** @ghidraAddress 0x2d5e8 */
- (void)closeDetailView {
    if (self.sharePlayManager != nil || bSuffleAnim) {
        return;
    }
    [self setEnableGesture:NO];
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    MusicView *detailMusicView = selectedMusicView;
    [detailMusicView setHidden:NO];
    [[AudioManager sharedManager] playSeResFile:[self soundName:kShareCancelSoundSuffix]
                                    inDirectory:nil];
    [[AudioManager sharedManager] fadeoutBgm:kDetailCloseBgmFadeOut];
    __weak UIView *weakView = self.view;
    __weak UIView *weakCover = coverView;
    __weak MusicDetailView *weakDetail = musicDetailView;
    [musicDetailView closePopWindow];
    selectedMusicView = nil;
    __weak UIImageView *weakImg = detailMusicView.imgView;
    CGFloat listAlpha = [musicListView getMusicListAlpha];
    musicDetailView.alpha = 1.0;
    detailMusicView.imgView.alpha = 1.0;
    // Flip the artwork back onto the music tile: the shared cover-flip pose, then fade the detail
    // view and its rank layers back to the music-list alpha, and on completion restore the tile.
    [UIView animateWithDuration:kDetailCloseFlipDuration
        delay:0.0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x2dbc0 */
          weakCover.alpha = 0.0;
          UIImageView *imgView = detailMusicView.imgView;
          imgView.center = [detailMusicView convertPoint:detailMusicView.centerArtworkImg
                                                  toView:weakView];
          CATransform3D perspective = CATransform3DIdentity;
          perspective.m34 = kCoverFlipPerspectiveM34;
          imgView.layer.transform = perspective;
          weakDetail.center = imgView.center;
          CGFloat scale = isPad ? kCoverFlipScalePad : kCoverFlipScalePhone;
          CATransform3D scaled = CATransform3DScale(perspective, scale, scale, 1.0);
          weakDetail.layer.transform = CATransform3DRotate(scaled, g_dPi, 0, 1.0, 0);
          weakDetail.alpha = listAlpha;
          weakImg.alpha = listAlpha;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x2df84 */
          weakCover.hidden = YES;
          UIImageView *imgView = detailMusicView.imgView;
          imgView.userInteractionEnabled = YES;
          [imgView removeFromSuperview];
          imgView.alpha = 1.0;
          imgView.center = detailMusicView.centerArtworkImg;
          [detailMusicView insertSubview:imgView belowSubview:detailMusicView.rankBgChipArray[0]];
          [weakDetail removeFromSuperview];
          [weakDetail clearInfo];
          [[AudioManager sharedManager] popBgm];
          [[AudioManager sharedManager] startBgm:YES fadeTime:kDetailCloseBgmRestartFade];
          bOpenMusicDetail = NO;
          [self JcfDownLoad];
          [self setEnableGesture:YES];
        }];
    // Restore the rank backgrounds after the flip, then the name and artist labels.
    [UIView animateWithDuration:kDetailCloseRankBgDuration
                          delay:kDetailCloseRankBgDelay
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                       /** @ghidraAddress 0x2e210 */
                       NSInteger chipType = [NSUserDefaults.standardUserDefaults
                           integerForKey:kPrefRatingChipTypeKey];
                       if (chipType == kRatingChipTypeNone) {
                           return;
                       }
                       detailMusicView.rankBgBas.alpha = 1.0;
                       detailMusicView.rankBgAdv.alpha = 1.0;
                       detailMusicView.rankBgExt.alpha = 1.0;
                       if (chipType == kRatingChipTypeWithChips) {
                           for (UIView *chip in detailMusicView.rankBgChipArray) {
                               chip.alpha = 1.0;
                           }
                       }
                       detailMusicView.adRankBgBas.alpha = 1.0;
                       detailMusicView.adRankBgAdv.alpha = 1.0;
                       detailMusicView.adRankBgExt.alpha = 1.0;
                     }
                     completion:nil];
    [UIView animateWithDuration:kDetailCloseLabelDuration
                          delay:kDetailCloseLabelDelay
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                       /** @ghidraAddress 0x2e4d8 */
                       [detailMusicView showNameAndArtist:YES];
                     }
                     completion:nil];
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:kDetailCloseUnlockDelay];
}

#pragma mark - Store balloon

/** @ghidraAddress 0x28ac4 */
- (void)hideStoreBalloon {
    if (balloonView == nil || balloonView.isHidden) {
        return;
    }
    [balloonView setUserInteractionEnabled:NO];
    __weak BalloonView *weakBalloon = balloonView;
    [UIView animateWithDuration:kStoreBalloonFadeDuration
        animations:^{
          /** @ghidraAddress 0x28c10 */
          [weakBalloon setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x28c5c */
          [weakBalloon.layer removeAnimationForKey:kStoreBalloonAnimationKey];
        }];
}

#pragma mark - Popover and challenge mode

/** @ghidraAddress 0x36e5c */
- (void)challengeMusicStart:(nullable id)tune diff:(int)difficulty {
    [self stopStoreInfo];
    [JubeatAppDelegate.appDelegate setChallengeMusic:((TuneInfo *)tune).tuneID diff:difficulty];
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:kStartPlayInputLockDuration];
    [musicListView releaseArtworks];
    [[AudioManager sharedManager] fadeoutBgm:1.0];
    [JubeatAppDelegate.appDelegate.rootViewCtrl startMainGame:tune
                                                 shareManager:self.sharePlayManager
                                                    musicData:shareMusicData];
    self.sharePlayManager = nil;
    shareMusicData = nil;
    [self setEnableGesture:NO];
}

/** @ghidraAddress 0x28ccc */
- (void)launchChallengeMode {
    if ([indicatorTimer isValid]) {
        [indicatorTimer invalidate];
        indicatorTimer = nil;
    }
    if (!bLaunchCMode) {
        [[AudioManager sharedManager] fadeoutBgm:kChallengeBgmFadeOut];
    }
    [challengeModeView enterChallengeView:YES];
    // Once the current scratch content id has been seen, hide the challenge-new badge.
    int scratchID = currentScratchID;
    if ([NSUserDefaults.standardUserDefaults integerForKey:kPrefScratchUpdateIDKey] < scratchID) {
        [NSUserDefaults.standardUserDefaults setInteger:scratchID forKey:kPrefScratchUpdateIDKey];
        [NSUserDefaults.standardUserDefaults synchronize];
        [imgChallengeNew setHidden:YES];
    }
    [self setEnableGesture:NO];
}

#pragma mark - URL scheme

/** @ghidraAddress 0x3348c */
- (void)schemeMoveStore {
    // Close the marker-select overlay if it is open, restoring the covered view and marker button.
    if (isMarkerSelectOpen) {
        UIView *cover = (musicDetailView.superview == nil) ? coverView : musicDetailView.coverView;
        [cover setAlpha:1.0];
        [markerSelectView close];
        markerSelectView.transform = CGAffineTransformIdentity;
        btnMarker.transform = CGAffineTransformIdentity;
        [cover setAlpha:1.0];
        if (musicDetailView.superview != nil) {
            [musicDetailView activateAnim:YES];
        }
        [cover setHidden:YES];
        [markerSelectView setHidden:YES];
        [musicDetailView setHidden:YES];
        isMarkerSelectOpen = NO;
        [self musicShuffleEnable];
        [self setSearchEnable:YES];
    }
    // Dismiss any open modal.
    if (bOpenModal) {
        [self dismissViewControllerAnimated:NO completion:nil];
        bOpenModal = NO;
        [self musicShuffleEnable];
        [self setSearchEnable:YES];
    }
    if (selectedMusicView != nil) {
        [musicDetailView closePopWindow];
    }
    // Open whichever store target the URL scheme recorded, then clear it.
    JubeatAppDelegate *appDelegate = JubeatAppDelegate.appDelegate;
    if (appDelegate.storePackID != nil) {
        [self turnToPackPurchase:appDelegate.storePackID];
        [appDelegate resetDownloadPackID];
    } else if (appDelegate.storeCampaignID != nil) {
        [self turnToCampaignDetail:appDelegate.storeCampaignID];
        [appDelegate resetCampaignID];
    } else if (appDelegate.storeGenreID != nil) {
        [self turnToGenreOpen:appDelegate.storeGenreID];
        [appDelegate resetDownloadGenreID];
    }
}

#pragma mark - Playlist actions

/** @ghidraAddress 0x2cbfc */
- (void)musicViewPlaylistAction:(nullable id)view {
    MusicView *musicView = view;
    // On a built-in playlist source, open the add-to-playlist picker; on a named playlist, remove
    // the tune from it.
    id source = currentPlaylistSource;
    if (source == nil || source == arrayNotPlayedTune || source == arrayLevelList ||
        source == arrayHoldList || source == arrayNotHoldList) {
        playlistViewCtrl =
            [[MusicPlaylistViewController alloc] initWithStyle:UITableViewStylePlain];
        [playlistViewCtrl setListMode:MusicPlaylistListModeAddToPlaylist];
        [playlistViewCtrl setSelectedMusicID:musicView.tuneInfo.tuneID];
        [playlistViewCtrl setPlaylistManager:playlistManager];
        [playlistViewCtrl setDelegate:self];
        playlistNavCtrl =
            [[RotatableNavigationController alloc] initWithRootViewController:playlistViewCtrl];
        if (!isPad) {
            [self presentViewController:playlistNavCtrl animated:YES completion:nil];
            bOpenModal = YES;
        } else {
            [playlistNavCtrl setModalPresentationStyle:UIModalPresentationPopover];
            UIPopoverPresentationController *popover =
                playlistNavCtrl.popoverPresentationController;
            [popover setDelegate:self];
            [popover setPermittedArrowDirections:UIPopoverArrowDirectionUp |
                                                 UIPopoverArrowDirectionDown];
            [popover setSourceView:musicView];
            [popover setSourceRect:musicView.btnPlaylistAction.frame];
            [self presentViewController:playlistNavCtrl animated:YES completion:nil];
        }
        [self musicShuffleDisable];
    } else {
        NSUInteger index = [playlistManager indexOfPlaylist:source];
        if (index != NSNotFound) {
            [playlistManager removeMusic:musicView.tuneInfo.tuneID fromPlaylistAtIndex:index];
            [playlistManager synchronize];
            [arrayCurrentPlaylist removeObjectIdenticalTo:musicView.tuneInfo];
            [musicListView removeMusicView:musicView];
        }
    }
}

/** @ghidraAddress 0x370ac */
- (void)makeChallengeRootView {
    if (challengeModeView != nil) {
        [challengeModeView removeFromSuperview];
        challengeModeView = nil;
    }
    challengeModeView = [[ChallengeModeRootView alloc] init];
    [challengeModeView setController:self];
    challengeModeView.layer.zPosition = kChallengeRootViewZPosition;
    [self.view addSubview:challengeModeView];
}

/** @ghidraAddress 0x3433c */
- (void)customWebViewClose:(nullable id)webView seqIndex:(nullable id)seqIndex {
    [[AudioManager sharedManager] playSeResFile:kWebViewCloseSound inDirectory:nil];
    [self dismissViewControllerAnimated:YES
                             completion:^{
                               /** @ghidraAddress 0x34428 */
                               [self JcfDownLoad];
                             }];
    bOpenModal = NO;
    [self musicShuffleEnable];
    [self setSearchEnable:YES];
}

/** @ghidraAddress 0x34448 */
- (void)notificationDisp {
    if (JubeatAppDelegate.appDelegate.notificationURL == nil) {
        return;
    }
    if (notificationViewController != nil) {
        notificationViewController = nil;
    }
    notificationViewController = [[NotificationPageNavController alloc] init:self];
    [self presentViewController:notificationViewController animated:YES completion:nil];
    bOpenInfo = YES;
    bOpenModal = YES;
    [[AudioManager sharedManager] playSeResFile:kNotificationOpenSound inDirectory:nil];
}

/** @ghidraAddress 0x27734 */
- (void)tapNotification:(nullable id)notification {
    NSString *urlString = notification[kPushURLKey];
    NSString *userID = [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
    id pushID = notification[kPushIDKey];
    NSMutableDictionary *response = [[NSMutableDictionary alloc] init];
    [response setValue:userID forKey:kPushResponseUserIDKey];
    [response setValue:pushID forKey:kPushResponsePushIDKey];
    [response setValue:@(kPushResponseStatusTapped) forKey:kPushResponseStatusKey];
    NSData *json = [[CJSONSerializer serializer] serializeDictionary:response error:nullptr];
    Downloader *downloader = [[Downloader alloc] initWithURL:ScratchUtil.pushNotificationResponseURL
                                                postJsonData:json
                                                    delegate:nil];
    [downloader startDownloading];
    if (urlString == nil) {
        return;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (url == nil) {
        return;
    }
    if ([url.scheme isEqualToString:kPushSchemeStore]) {
        NSDictionary *storeTarget = nil;
        if (url.pathComponents.count == kPushStorePathComponentCount) {
            if ([url.pathComponents[1] isEqualToString:kPushStorePackComponent]) {
                storeTarget = @{kPushStorePackComponent : url.pathComponents[2]};
            }
            if ([url.pathComponents[1] isEqualToString:kPushStoreGenreComponent]) {
                storeTarget = @{kPushStoreGenreComponent : url.pathComponents[2]};
            }
        }
        [self turnToStore:storeTarget];
    } else if ([url.scheme isEqualToString:kPushSchemeChallenge]) {
        [self downloadChallengeInfo];
    } else {
        [[UIApplication sharedApplication] openURL:url];
    }
}

/** @ghidraAddress 0x34040 */
- (void)startOpenDetailPanel {
    if (notificationView.isActive) {
        [notificationView stopNotification];
    }
    int lastPlayedID =
        (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefLastPlayedIDKey];
    MusicView *musicView = [musicListView getMusicView:lastPlayedID];
    if (musicView != nil) {
        // The last-played tune is on the current page; open its detail panel directly.
        [self musicViewTapped:musicView];
        return;
    }
    // The last-played tune is off-page: find its index in the full tune list, work out which page
    // that is, and open a stand-in music view sliding in from whichever side that page lies on.
    int currentPage = [musicListView getCurrentPage];
    TuneInfo *foundTune = nil;
    int tunePage = 0;
    int index = 0;
    for (TuneInfo *tune in arrayAllTune) {
        if (tune.tuneID == lastPlayedID) {
            foundTune = tune;
            int viewsPerPage = [musicListView currentViewsPerPage];
            tunePage = viewsPerPage != 0 ? index / viewsPerPage : 0;
            break;
        }
        ++index;
    }
    CGFloat width = self.view.frame.size.width;
    CGFloat direction = tunePage > currentPage ? 1.0 : kDetailPanelOffscreenDirection;
    farOpenMusicView.center = CGPointMake(width * 0.5 + direction * width, width * 0.5);
    [farOpenMusicView setInfo:foundTune];
    [self musicViewTapped:farOpenMusicView];
}

/** @ghidraAddress 0x338c0 */
- (void)popoverClose {
    if (isPad) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }
    if (bOpenModal) {
        if (bOpenSetting) {
            [settingsNavCtrl settingClose];
        }
        [self dismissViewControllerAnimated:NO completion:nil];
        bOpenModal = NO;
        [self musicShuffleEnable];
    }
}

/** @ghidraAddress 0x37c78 */
- (void)hideChallengeCoverView {
    if ([indicatorTimer isValid]) {
        [indicatorTimer invalidate];
        indicatorTimer = nil;
    }
    bOpenChallenge = NO;
    __weak UIView *weakCover = challengeCoverView;
    [UIView animateWithDuration:kChallengeCoverFadeDuration
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowAnimatedContent
        animations:^{
          /** @ghidraAddress 0x37df8 */
          [weakCover setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x37e44 */
          [weakCover removeFromSuperview];
          challengeCoverView = nil;
        }];
}

/** @ghidraAddress 0x37844 */
- (void)showChallengeCoverView {
    if (challengeCoverView != nil) {
        return;
    }
    bOpenChallenge = YES;
    challengeCoverView = [[UIView alloc] initWithFrame:self.view.frame];
    challengeCoverView.opaque = NO;
    // The original built this with colorWithWhite:0 alpha:0.4.
    challengeCoverView.backgroundColor = [UIColor colorWithWhite:0
                                                           alpha:kChallengeCoverBackgroundAlpha];
    [self.view addSubview:challengeCoverView];
    challengeCoverView.layer.zPosition = kChallengeRootViewZPosition;
    indicatorChallenge = [[UIActivityIndicatorView alloc]
        initWithFrame:CGRectMake(0, 0, kChallengeIndicatorSize, kChallengeIndicatorSize)];
    indicatorChallenge.center = CGPointMake(challengeCoverView.frame.size.width * 0.5,
                                            challengeCoverView.frame.size.height * 0.5);
    indicatorChallenge.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    indicatorChallenge.hidesWhenStopped = YES;
    [challengeCoverView addSubview:indicatorChallenge];
    indicatorTimer = [NSTimer scheduledTimerWithTimeInterval:kChallengeLoadTimeout
                                                      target:self
                                                    selector:@selector(loadTimeOver:)
                                                    userInfo:nil
                                                     repeats:NO];
    challengeCoverView.alpha = 0.0;
    __weak UIView *weakCover = challengeCoverView;
    [UIView animateWithDuration:kChallengeCoverFadeDuration
                          delay:0.0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                       /** @ghidraAddress 0x37bd4 */
                       weakCover.alpha = 1.0;
                     }
                     completion:nil];
}

/** @ghidraAddress 0x371a4 */
- (void)downloadChallengeInfo {
    if (notificationView.isActive) {
        [notificationView stopNotification];
    }
    bLaunchCMode = JubeatAppDelegate.appDelegate.bChallengeMode;
    [self showChallengeCoverView];
    if (!EditorIDManager.isExistEditorID) {
        idManager = [[EditorIDManager alloc] initWithDelegate:self];
        return;
    }
    if ([PurchaseManager sharedManager].verifyPendingConsumeReceipt) {
        // A consume receipt is still pending: verify it before the challenge info can be fetched.
        verifyPurchaseType = kVerifyPurchaseTypeChallenge;
        [[PurchaseManager sharedManager] setDelegate:self];
        [self showVerifyDialog:kVerifyProcessingMessage];
        return;
    }
    if (!checkPolicy) {
        // The challenge policy has not yet been agreed: present the licence agreement over the
        // cover, centred on the screen.
        CGRect bounds = UIScreen.mainScreen.bounds;
        LicenseAgreementView *agreementView =
            [[LicenseAgreementView alloc] init:self keyString:kPrefAgreeChallengePolicyVersionKey];
        agreementView.center = CGPointMake(bounds.size.width * 0.5, bounds.size.height * 0.5);
        [challengeCoverView addSubview:agreementView];
        return;
    }
    if ([NSUserDefaults.standardUserDefaults valueForKey:kPrefChallengeRestoreEndKey] == nil) {
        // The purchased packs have not been restored yet, which challenge mode requires first.
        [[AlertViewManager sharedManager]
            makeAlert:0
             delegate:self
                  tag:kAlertTagRestore
                title:@""
                  msg:kChallengePolicyRestoreRequiredMessage
               cancel:[NSBundle.mainBundle localizedStringForKey:@"Cancel" value:@"" table:nil]
              btnText:@[ [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil] ]
                 show:YES];
        return;
    }
    NSMutableDictionary *postDictionary = [JubeatAppDelegate.clientInfo mutableCopy];
    postDictionary[kClientInfoMarkerIDKey] =
        [NSUserDefaults.standardUserDefaults objectForKey:kPrefCurrentMarkerIDKey];
    NSURL *url = ScratchUtil.challengeInitializeURL;
    if (ChallengeStatus.sharedStatus.bInitialized) {
        url = ScratchUtil.challengeSimpleInitializeURL;
    }
    int apiTag = ChallengeStatus.sharedStatus.bInitialized ? kChallengeApiTagSimpleInitialize :
                                                             kChallengeApiTagInitialize;
    challengeInfoDownloader = [[SessionDownloader alloc] initWithURL:url
                                                      postDictionary:postDictionary
                                                            delegate:self];
    [challengeInfoDownloader setTag:kChallengeInfoDownloaderTag];
    challengeInfoDownloader.apiTag = apiTag;
    [challengeInfoDownloader startDownloading];
}

/** @ghidraAddress 0x36da0 */
- (void)challengeModeClose {
    [self setupMainBgm];
    [challengeModeView removeFromSuperview];
    challengeModeView = nil;
    [JubeatAppDelegate.appDelegate setChallengeMode:NO];
    [self hideChallengeCoverView];
    [self setSearchEnable:YES];
    [notificationView startNotification];
}

#pragma mark - JCF download and purchases

/** @ghidraAddress 0x33084 */
- (void)jcfDownloadEnd:(nullable id)sender {
    __weak UIView *weakCover = coverView;
    __weak JcfDownloadView *weakDownload = jcfDownloadView;
    [musicListView addDownloadMark:[jcfDownloadView getDownloadMusicID]];
    // The binary passes a negative fade duration here; kept as-is.
    [UIView animateWithDuration:kJcfDownloadEndFadeDuration
        animations:^{
          /** @ghidraAddress 0x33248 */
          [weakCover setAlpha:0.0];
          [weakDownload setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x33310 */
          [self removeDownloadView];
        }];
    [self setSearchEnable:YES];
}

/** @ghidraAddress 0x32d10 */
- (void)JcfDownLoad:(nullable id)sequenceID {
    if (sequenceID == nil) {
        return;
    }
    [JubeatAppDelegate.appDelegate resetDownLoadIndex];
    if (jcfDLPageViewController != nil) {
        jcfDLPageViewController = nil;
    }
    jcfDLPageViewController = [[JcfDownloadPageNavController alloc] initWithSequenceID:sequenceID
                                                                              delegate:self];
    [self presentViewController:jcfDLPageViewController animated:YES completion:nil];
    bOpenModal = YES;
    [self musicShuffleDisable];
    [self setSearchEnable:NO];
}

/** @ghidraAddress 0x33980 */
- (void)resumeJcfDownload {
    if (JubeatAppDelegate.appDelegate.jcfDownloadID == nil) {
        return;
    }
    if (isMarkerSelectOpen) {
        __weak MarkerSelectView *weakMarkerSelect = markerSelectView;
        __weak UIButton *weakMarker = btnMarker;
        __weak UIView *weakCover = nil;
        [markerSelectView close];
        __weak MusicDetailView *weakDetail = musicDetailView;
        __weak UIView *weakMarkerCover = markerSelectCover;
        [UIView animateWithDuration:kMenuBgmResumeFade
            animations:^{
              /** @ghidraAddress 0x33d6c */
              weakMarkerSelect.transform = CGAffineTransformIdentity;
              weakMarker.transform = CGAffineTransformIdentity;
              weakCover.alpha = 0.0;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x33eb4 */
              if (weakDetail.superview != nil) {
                  [weakDetail activateAnim:YES];
              }
              weakCover.hidden = YES;
              weakMarkerSelect.hidden = YES;
              weakMarkerCover.hidden = YES;
            }];
    }
    BOOL noDetailOpen = selectedMusicView == nil;
    if (!noDetailOpen) {
        [self closeDetailView];
    }
    if (isPad) {
        [self dismissViewControllerAnimated:NO
                                 completion:^{
                                 }];
    }
    if (bOpenModal) {
        if (bOpenSetting) {
            [settingsNavCtrl settingClose];
        }
        [self dismissViewControllerAnimated:NO
                                 completion:^{
                                   /** @ghidraAddress 0x34020 */
                                   [self JcfDownLoad];
                                 }];
        bOpenModal = NO;
        [self musicShuffleEnable];
        [self setSearchEnable:YES];
    } else if (noDetailOpen) {
        [self JcfDownLoad];
    }
}

/** @ghidraAddress 0x32e34 */
- (void)JcfDownLoadTopPage {
    if (jubeatLabURL == nil) {
        return;
    }
    [JubeatAppDelegate.appDelegate resetDownLoadIndex];
    if (jcfDLPageViewController != nil) {
        jcfDLPageViewController = nil;
    }
    jcfDLPageViewController = [[JcfDownloadPageNavController alloc] initWithURL:jubeatLabURL
                                                                       delegate:self];
    [self presentViewController:jcfDLPageViewController animated:YES completion:nil];
    bOpenModal = YES;
    [self musicShuffleDisable];
    [searchBox resignFirstResponder];
    [self setSearchEnable:NO];
    [[AudioManager sharedManager] playSeResFile:kNotificationOpenSound inDirectory:nil];
}

/** @ghidraAddress 0x2d4a8 */
- (void)gameCenterViewControllerDidFinish:(nullable id)controller {
    [[AudioManager sharedManager] playSeResFile:[self soundName:@"MUSIC_LEFT"] inDirectory:nil];
    [self dismissViewControllerAnimated:YES
                             completion:^{
                               /** @ghidraAddress 0x2d5c8 */
                               [self JcfDownLoad];
                             }];
    bOpenModal = NO;
    [self musicShuffleEnable];
    [self setSearchEnable:YES];
}

/** @ghidraAddress 0x36b4c */
- (void)tapChangeMode:(nullable id)sender {
    [musicDetailView changeExtendMode];
    __weak UIView *weakTutorial = extendTutorialView;
    // The binary passes a negative fade duration here; kept as-is.
    [UIView animateWithDuration:kExtendTutorialFadeDuration
                     animations:^{
                       /** @ghidraAddress 0x36c48 */
                       [weakTutorial setAlpha:0.0];
                     }];
}

/** @ghidraAddress 0x2ff94 */
- (void)alertSelect:(nullable id)alert {
    // Each tag selects an action performed by the shared tail; the restore and cancel paths return
    // early instead.
    int tag = [alert[kAlertTagKey] intValue];
    SEL action = @selector(downloadChallengeInfo);
    if (tag != kAlertTagChallengeInfo) {
        if (tag == kAlertTagRestore) {
            // The restore is confirmed only when the user tapped the affirmative button.
            if ([alert[kAlertButtonMessageKey] intValue] != 0) {
                [self showVerifyDialog:kRestoreProcessingMessage];
                [[PurchaseManager sharedManager] setDelegate:self];
                [[PurchaseManager sharedManager] beginRestore];
                return;
            }
            action = @selector(hideChallengeCoverView);
        } else if (tag != kAlertTagRetry) {
            [self cancelShare:NO];
            return;
        } else if (verifyPurchaseType == kVerifyPurchaseTypeStore) {
            action = @selector(turnToStore);
        } else if (verifyPurchaseType != kVerifyPurchaseTypeChallenge) {
            return;
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:action];
#pragma clang diagnostic pop
}

/** @ghidraAddress 0x28e84 */
- (void)challengeConnectError:(nullable id)response {
    int status = [response[kChallengeStatusKey] intValue];
    if (response[kChallengeStatusKey] != nil) {
        if (status == kChallengeStatusUpdateRequired) {
            [self hideChallengeCoverView];
            [[AlertViewManager sharedManager] showUpdateAlert];
            return;
        }
        if (status == kChallengeStatusNoScratch) {
            NSString *message = response[kChallengeErrorMessageKey] ?: kChallengeNoScratchMessage;
            [self hideChallengeCoverView];
            [[AlertViewManager sharedManager]
                makeAlert:0
                 delegate:nil
                      tag:0
                    title:@""
                      msg:message
                   cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
                  btnText:nil
                     show:YES];
            return;
        }
    }
    // Any other status shows the generic server-error message, overridden by the response's own.
    NSString *message = response[kChallengeErrorMessageKey] ?:
                            [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                                 value:@""
                                                                 table:nil];
    [self hideChallengeCoverView];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:@""
                                            msg:message
                                         cancel:[NSBundle.mainBundle localizedStringForKey:@"OK"
                                                                                     value:@""
                                                                                     table:nil]
                                        btnText:nil
                                           show:YES];
}

/** @ghidraAddress 0x38618 */
- (void)errorIDDownload:(nullable id)sender msgStr:(nullable NSString *)message {
    if (message == nil || [message isEqualToString:@""]) {
        message = [NSBundle.mainBundle localizedStringForKey:@"NetworkErrorMsg"
                                                       value:@""
                                                       table:nil];
    }
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:@""
                                            msg:message
                                         cancel:[NSBundle.mainBundle localizedStringForKey:@"OK"
                                                                                     value:@""
                                                                                     table:nil]
                                        btnText:nil
                                           show:YES];
    idManager = nil;
    [self hideChallengeCoverView];
}

/** @ghidraAddress 0x291f0 */
- (void)downloaderFinished:(nullable Downloader *)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    int status = json[@"status"] != nil ? [json[@"status"] intValue] : -1;
    switch (downloader.tag) {
    case kDownloaderTagStoreInfo: {
        NSString *updateTime = [json stringForKey:kChallengeUpdateTimeKey];
        NSArray *updateText = [json arrayForKey:kChallengeUpdateTextKey];
        currentScratchID = [json[kChallengeScratchIDKey] intValue];
        if (updateTime != nil) {
            storeUpdateTime = updateTime;
            NSString *seen =
                [NSUserDefaults.standardUserDefaults stringForKey:kPrefStoreUpdateTimeKey];
            if (seen == nil || [seen compare:storeUpdateTime
                                     options:NSNumericSearch] == NSOrderedAscending) {
                [imgStoreNew.layer addAnimation:MusicSelectMakeNewBadgeBlinkAnimation()
                                         forKey:kStoreNewBlinkAnimationKey];
                imgStoreNew.hidden = NO;
            }
        }
        if (currentScratchID >= 0 &&
            [NSUserDefaults.standardUserDefaults integerForKey:kPrefScratchUpdateIDKey] <
                currentScratchID) {
            [imgChallengeNew.layer addAnimation:MusicSelectMakeNewBadgeBlinkAnimation()
                                         forKey:kStoreNewBlinkAnimationKey];
            imgChallengeNew.hidden = NO;
        }
        if (updateText.count != 0) {
            NSMutableArray *comments = [[NSMutableArray alloc] init];
            for (id entry in updateText) {
                if ([entry isKindOfClass:[NSDictionary class]]) {
                    [comments addObject:entry];
                }
            }
            [bottomView setCommentTable:comments];
        }
        [self challengeModeEnable:YES];
        infoDownloader = nil;
        break;
    }
    case kDownloaderTagChallengeInit:
        if (status == 0) {
            [self makeChallengeRootView];
            [challengeModeView setChallengeData:[downloader getDataInJSON]];
            NSInteger totalPurchase =
                [NSUserDefaults.standardUserDefaults integerForKey:kPrefTotalPurchaseKey];
            if (totalPurchase < 1) {
                [self launchChallengeMode];
            } else {
                challengeInfoDownloader = nil;
                NSDictionary *body = @{kChallengeTotalPurchaseBodyKey : @((int)totalPurchase)};
                challengeInfoDownloader =
                    [[SessionDownloader alloc] initWithURL:ScratchUtil.registTotalPurchaseURL
                                            postDictionary:body
                                                  delegate:self];
                [challengeInfoDownloader setTag:kChallengeDownloaderApiTagTotalPurchase];
                [challengeInfoDownloader startDownloading];
            }
        } else {
            [self challengeConnectError:json];
        }
        challengeInfoDownloader = nil;
        break;
    case kDownloaderTagAgeRegist:
        if (status != 0) {
            [self challengeConnectError:json];
        } else {
            [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefTotalPurchaseKey];
            [self launchChallengeMode];
        }
        challengeInfoDownloader = nil;
        break;
    case kDownloaderTagTotalPurchaseRegist:
        if (status == 0) {
            challengeInfoDownloader = nil;
            NSInteger limitType =
                [NSUserDefaults.standardUserDefaults integerForKey:kPrefPurchaseLimitTypeKey];
            if (limitType == 0) {
                [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefTotalPurchaseKey];
                [self launchChallengeMode];
                challengeInfoDownloader = nil;
            } else {
                NSDictionary *body = @{kChallengeAgeBodyKey : @((int)(limitType - 1))};
                challengeInfoDownloader =
                    [[SessionDownloader alloc] initWithURL:ScratchUtil.registUserAgeURL
                                            postDictionary:body
                                                  delegate:self];
                [challengeInfoDownloader setTag:kChallengeDownloaderApiTagAge];
                [challengeInfoDownloader startDownloading];
                challengeInfoDownloader = nil;
            }
        } else {
            [self challengeConnectError:json];
            challengeInfoDownloader = nil;
        }
        break;
    case kDownloaderTagPushIDSend:
        [JubeatAppDelegate.appDelegate setBSendPushID:YES];
        break;
    }
}

/** @ghidraAddress 0x29df8 */
- (void)downloaderError:(nullable id)downloader {
    int tag = ((Downloader *)downloader).tag;
    if ((unsigned int)(tag - 1) < 3) {
        [self hideChallengeCoverView];
        [[AlertViewManager sharedManager]
            makeAlert:0
             delegate:nil
                  tag:0
                title:@""
                  msg:[NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                           value:@""
                                                           table:nil]
               cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
              btnText:nil
                 show:YES];
        return;
    }
    if (tag == 0) {
        infoDownloader = nil;
        [self challengeModeEnable:NO];
    }
}

/** @ghidraAddress 0x3880c */
- (void)agreementError:(nullable id)view msgStr:(nullable NSString *)message {
    if (message == nil || [message isEqualToString:@""]) {
        message = [NSBundle.mainBundle localizedStringForKey:@"NetworkErrorMsg"
                                                       value:@""
                                                       table:nil];
    }
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:@""
                                            msg:message
                                         cancel:[NSBundle.mainBundle localizedStringForKey:@"OK"
                                                                                     value:@""
                                                                                     table:nil]
                                        btnText:nil
                                           show:YES];
    [view removeFromSuperview];
    [self hideChallengeCoverView];
}

/** @ghidraAddress 0x38434 */
- (void)purchaseFailed:(nullable id)productID error:(nullable NSError *)error {
    [[PurchaseManager sharedManager] setDelegate:nil];
    // A network failure (code 1) shows the error and then hides the challenge cover; any other
    // failure re-requests the challenge info. Either way the verify dialog is hidden last.
    SEL action = @selector(downloadChallengeInfo);
    if (error.code == 1) {
        [[AlertViewManager sharedManager]
            makeAlert:0
             delegate:nil
                  tag:0
                title:@""
                  msg:[NSBundle.mainBundle localizedStringForKey:@"NetworkErrorMsg"
                                                           value:@""
                                                           table:nil]
               cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
              btnText:nil
                 show:YES];
        action = @selector(hideChallengeCoverView);
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:action];
#pragma clang diagnostic pop
    [self hideVerifyDialog];
}

/** @ghidraAddress 0x38af4 */
- (void)restoreNothing {
    [NSUserDefaults.standardUserDefaults setObject:kRestoreCompleteMarker
                                            forKey:kPrefChallengeRestoreEndKey];
    [[PurchaseManager sharedManager] setDelegate:nil];
    [self hideVerifyDialog];
    [[AlertViewManager sharedManager]
        makeAlert:0
         delegate:self
              tag:kRestoreCompleteAlertTag
            title:@""
              msg:[NSBundle.mainBundle localizedStringForKey:@"RestoreCompleteTitle"
                                                       value:@""
                                                       table:nil]
           cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
          btnText:nil
             show:YES];
}

/** @ghidraAddress 0x38cfc */
- (void)restoreSucceeded {
    [NSUserDefaults.standardUserDefaults setObject:kRestoreCompleteMarker
                                            forKey:kPrefChallengeRestoreEndKey];
    [[PurchaseManager sharedManager] setDelegate:nil];
    [self hideVerifyDialog];
    [[AlertViewManager sharedManager]
        makeAlert:0
         delegate:self
              tag:kRestoreCompleteAlertTag
            title:@""
              msg:[NSBundle.mainBundle localizedStringForKey:@"RestoreCompleteTitle"
                                                       value:@""
                                                       table:nil]
           cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
          btnText:nil
             show:YES];
}

/** @ghidraAddress 0x3830c */
- (void)purchaseSucceeded:(nullable id)sender {
    [[PurchaseManager sharedManager] setDelegate:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:self
                                            tag:1
                                          title:@""
                                            msg:kPurchaseSuccessMessage
                                         cancel:[NSBundle.mainBundle localizedStringForKey:@"OK"
                                                                                     value:@""
                                                                                     table:nil]
                                        btnText:nil
                                           show:YES];
}

#pragma mark - Music list

/** @ghidraAddress 0x2ae28 */
- (NSInteger)musicPlaylistViewControllerCurrentSelection:(nullable id)controller {
    // The built-in playlists map to sentinel selection indices; a manager playlist maps to its
    // index, and anything else (or none) is the default.
    id source = currentPlaylistSource;
    if (source == arrayNotPlayedTune) {
        return kPlaylistSelectionNotPlayed;
    }
    if (source == arrayHoldList) {
        return kPlaylistSelectionHold;
    }
    if (source == arrayNotHoldList) {
        return kPlaylistSelectionNotHold;
    }
    if (source == arrayLevelList) {
        return kPlaylistSelectionLevel;
    }
    if (source != nil) {
        NSUInteger index = [playlistManager indexOfPlaylist:source];
        if (index != NSNotFound) {
            return (NSInteger)index;
        }
    }
    return kPlaylistSelectionDefault;
}

/** @ghidraAddress 0x2a9e4 */
- (void)musicPlaylistViewController:(nullable id)controller
                   playlistSelected:(NSInteger)selection
                    selectedMusicID:(NSUInteger)musicID {
    // In add-to-playlist mode a real playlist index adds the music and the picker's actions hide.
    if (((MusicPlaylistViewController *)controller).listMode != MusicPlaylistListModePlaylists) {
        if (((MusicPlaylistViewController *)controller).listMode ==
            MusicPlaylistListModeAddToPlaylist) {
            if (selection >= 0 && (NSUInteger)selection < playlistManager.numberOfPlaylists) {
                [playlistManager addMusic:musicID toPlaylistAtIndex:selection];
                [playlistManager synchronize];
            }
            [musicListView hideAllPlaylistAction];
        }
        [self dismissViewControllerAnimated:YES completion:nil];
        [self musicShuffleEnable];
        [self setSearchEnable:YES];
        return;
    }

    // Browse mode: the built-in filters use sentinel indices; a real index is a saved playlist.
    BOOL builtIn =
        (selection == kPlaylistSelectionNotPlayed || selection == kPlaylistSelectionDefault ||
         selection == kPlaylistSelectionLevel || selection == kPlaylistSelectionHold ||
         selection == kPlaylistSelectionNotHold);
    if (builtIn) {
        [self changeMusicListView:selection musicID:0];
        if (selection != kPlaylistSelectionLevel) {
            [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefPlayListLevelKey];
        }
    } else {
        if (selection < 0 || (NSUInteger)selection >= playlistManager.numberOfPlaylists) {
            [self dismissViewControllerAnimated:YES completion:nil];
            [self musicShuffleEnable];
            [self setSearchEnable:YES];
            return;
        }
        [self changeMusicListView:selection musicID:0];
        [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefPlayListLevelKey];
    }

    // Record the selection: the hold filters set the hold flag, the others clear the remembered
    // playlist, and a real index stores that playlist's identifier.
    switch (selection) {
    case kPlaylistSelectionNotHold:
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kPrefLastPlaylistKey];
        [NSUserDefaults.standardUserDefaults setInteger:2 forKey:kPrefPlayListHoldKey];
        break;
    case kPlaylistSelectionHold:
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kPrefLastPlaylistKey];
        [NSUserDefaults.standardUserDefaults setInteger:1 forKey:kPrefPlayListHoldKey];
        break;
    case kPlaylistSelectionLevel:
        [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefPlayListHoldKey];
        break;
    case kPlaylistSelectionDefault:
    case kPlaylistSelectionNotPlayed:
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kPrefLastPlaylistKey];
        break;
    default:
        if (selection >= 0) {
            [NSUserDefaults.standardUserDefaults
                setObject:[playlistManager identifierOfPlaylistAtIndex:selection]
                   forKey:kPrefLastPlaylistKey];
        }
        break;
    }
    [bottomView playlistButtonChanged:selection];
    [self dismissViewControllerAnimated:YES completion:nil];
    [self musicShuffleEnable];
    [self setSearchEnable:YES];
}

/** @ghidraAddress 0x352ac */
- (BOOL)changeMusicData:(nullable id)tune {
    // Load the tune's base info and score into the detail view.
    ScoreRecord *record = [ScoreRecord recordForTuneID:((TuneInfo *)tune).tuneID];
    [musicDetailView setInfo:tune score:record];
    // Load the extend chart when the tune has one whose file is present; otherwise clear it.
    if (((TuneInfo *)tune).extendID != 0 &&
        [StoreUtil existMusicFile:((TuneInfo *)tune).extendID]) {
        TuneInfo *extend = dictAllExtendTune[@(((TuneInfo *)tune).extendID)];
        ScoreRecord *extendRecord = [ScoreRecord recordForTuneID:((TuneInfo *)tune).extendID];
        [musicDetailView setExtendInfo:extend score:extendRecord];
    } else {
        [musicDetailView setExtendInfo:nil score:nil];
    }
    [musicDetailView
        infoChange:(int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey]];
    // Load and start the tune's own BGM if its archive carries one.
    KUnzip *archive = [[KUnzip alloc] initWithPath:((TuneInfo *)tune).filePath
                                              tail:kTuneInfoArchiveTail];
    NSMutableData *bgm = [archive uncompress:kTuneBgmEntryName];
    if (bgm != nil) {
        BFCodec *codec = [[BFCodec alloc] init];
        [codec cipherInit:GetBgmCipherKey()];
        [codec decipher:bgm];
        [[AudioManager sharedManager] loadBgmData:bgm];
        [[AudioManager sharedManager] startBgm:YES fadeTime:0.0];
    }
    return YES;
}

/** @ghidraAddress 0x20d74 */
- (nullable id)getTuneInfo:(nullable id)path {
    KUnzip *archive = [[KUnzip alloc] initWithPath:path tail:kTuneInfoArchiveTail];
    if (archive == nil) {
        return nil;
    }
    // The v3 member is ciphered with the tune-info key and carries a four-byte header.
    NSMutableData *v3 = [archive uncompress:kInfoV3EntryName];
    if (v3 != nil) {
        BFCodec *codec = [[BFCodec alloc] init];
        [codec cipherInit:CreateTuneInfoCipherKey()];
        [codec decipher:v3];
        NSData *body = [v3 subdataWithRange:NSMakeRange(kTuneInfoV3HeaderLength,
                                                        v3.length - kTuneInfoV3HeaderLength)];
        return [NSDictionary dictionaryFromPropertyListData:body];
    }
    // The older members use the BGM key and no header.
    NSMutableData *legacy = [archive uncompress:kInfoV2EntryName];
    if (legacy == nil) {
        legacy = [archive uncompress:kInfoEntryName];
        if (legacy == nil) {
            return nil;
        }
    }
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:GetBgmCipherKey()];
    [codec decipher:legacy];
    return [NSDictionary dictionaryFromPropertyListData:legacy];
}

/** @ghidraAddress 0x2a0b0 */
- (int)musicIndexForTuneID:(int)tuneID {
    NSArray<TuneInfo *> *list = arrayCurrentPlaylist ?: arrayAllTune;
    for (NSUInteger i = 0; i < list.count; ++i) {
        if ((int)list[i].tuneID == tuneID) {
            return (int)i;
        }
    }
    return -1;
}

/** @ghidraAddress 0x26998 */
- (void)reloadMarkerSelectView {
    if (markerSelectView.superview != nil) {
        [markerSelectView removeFromSuperview];
    }
    markerSelectView = nil;
    CGFloat size = isPad ? kMarkerSelectSizePad : kMarkerSelectSizePhone;
    CGFloat width = isPad ? kMarkerSelectWidthPad : kMarkerSelectWidthPhone;
    markerSelectView = [[MarkerSelectView alloc] initWithFrame:CGRectMake(0, -size, width, size)];
    [markerSelectView setDelegate:self];
    [markerSelectView setHidden:YES];
    isMarkerSelectOpen = NO;
    markerSelectView.layer.zPosition = kMarkerSelectZPosition;
    [self.view insertSubview:markerSelectView aboveSubview:btnMarker];
}

/** @ghidraAddress 0x2a004 */
- (nullable id)musicInfoForIndex:(NSUInteger)index {
    // Prefer the current playlist; without one, index the full tune array.
    if (arrayCurrentPlaylist == nil) {
        if (index < arrayAllTune.count) {
            return arrayAllTune[index];
        }
    } else if (index < arrayCurrentPlaylist.count) {
        return arrayCurrentPlaylist[index];
    }
    return nil;
}

#pragma mark - Game Center

/** @ghidraAddress 0x2d260 */
- (void)gameCenterStateChanged:(nullable id)sender {
    [btnLeaderboard setEnabled:GKLocalPlayer.localPlayer.isAuthenticated];
}

@end
