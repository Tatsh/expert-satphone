#import "ChallengeStatus.h"

#import <UIKit/UIKit.h>

#import "ChallengeMissionFileManager.h"
#import "ChallengeMissionSheet.h"
#import "ChallengeModeRootView.h"
#import "EditorIDManager.h"
#import "JubeatAppDelegate.h"
#import "ScratchInfo.h"
#import "ScratchUtil.h"
#import "SystemUtilities.h"

// The number of scratch panels the info table always holds.
static const int kScratchPanelCount = 16;

// The economy defaults set on -init and restored by -resetStatus.
static const int kDefaultConsumePlayCoin = 10;
static const int kDefaultConsumeScratchCube = 100;
static const int kDefaultConsumeRestCube = 100;
static const int kDefaultSelectedMissionSheetID = 1;

// The purchase-limit type that marks a subscription; when set, -updateServerTime: leaves it in
// place on a month rollover instead of clearing it.
static const NSInteger kPurchaseLimitTypeSubscription = 3;

// The clamps and format constants for the two interval renderers, from __const:
// 3600.0 at 0x28f890, 60.0 at 0x28f258. The "%d:%02d" / "%02d:%02d:%02d" formats live at the
// CFStrings 0x2e0de0 and 0x2e0e00.
static const double kSecondsPerHour = 3600.0; // @ghidraAddress 0x28f890
static const double kSecondsPerMinute = 60.0; // @ghidraAddress 0x28f258
static const int kMaxMinutesClamp = 200;
static const int kMaxHoursClamp = 999;

// The date-parsing format and time zone shared by the server-time and coin-time parsers.
static NSString *const kServerDateFormat = @"yyyy-MM-ddHH:mm:ss";
static NSString *const kServerMonthFormat = @"yyyyMM";
static NSString *const kServerTimeZoneAbbreviation = @"JST";

// The server-response dictionary keys, all CFStrings in __const at the addresses noted.
static NSString *const kKeyConsumePlayCoin = @"consume_play_coin";       // @ghidraAddress 0x2e0b60
static NSString *const kKeyConsumeScratchCube = @"consume_scratch_cube"; // @ghidraAddress 0x2e0b80
static NSString *const kKeyConsumeRestCoin = @"consume_rest_coin";       // @ghidraAddress 0x2e0ba0
static NSString *const kKeyPresent = @"present";                         // @ghidraAddress 0x2e...
static NSString *const kKeyScratchID = @"scratch_id";
static NSString *const kKeyHowtoURL = @"howto_url";
static NSString *const kKeyInformationURL = @"information_url";
static NSString *const kKeyPersonalInfoURL = @"personal_info_url";
static NSString *const kKeyMusicID = @"music_id";
static NSString *const kKeyScratchPanel = @"scratch_panel"; // @ghidraAddress 0x2e0c80
static NSString *const kKeyPosition = @"position";
static NSString *const kKeyMusicList = @"music_list";   // @ghidraAddress 0x2dd6e0
static NSString *const kKeyName = @"name";              // @ghidraAddress 0x2d4880
static NSString *const kKeyUserID = @"user_id";         // @ghidraAddress 0x2d4cc0
static NSString *const kKeyEnd = @"end";                // @ghidraAddress 0x2e...
static NSString *const kKeyServerTime = @"server_time"; // @ghidraAddress 0x2e0d00
static NSString *const kKeyJCube = @"jCube";            // @ghidraAddress 0x2da040
static NSString *const kKeyRecoveryTime = @"recovery_time";
static NSString *const kKeyPlayCoinLimit = @"play_coin_limit";       // @ghidraAddress 0x2e0d60
static NSString *const kKeyPlayCoin = @"play_coin";                  // @ghidraAddress 0x2e0d80
static NSString *const kKeyRecoveryBaseTime = @"recovery_base_time"; // @ghidraAddress 0x2e0da0
static NSString *const kKeyScratchNail = @"scratch_nail";            // @ghidraAddress 0x2e0dc0
static NSString *const kKeySheetList = @"sheet_list";                // @ghidraAddress 0x2d9be0
static NSString *const kKeySheetID = @"sheet_id";                    // @ghidraAddress 0x2d9c00
static NSString *const kKeySessionSeed = @"session_seed";            // @ghidraAddress 0x2d5100
static NSString *const kKeySelectSheetID = @"select_sheet_id";       // @ghidraAddress 0x2e0ea0

// The persistence keys written to / read from NSUserDefaults.
static NSString *const kPrefLastScratchID = @"PrefLastScratchID";
static NSString *const kPrefChallengeInformationURL = @"PrefChallengeInformationURL";
static NSString *const kPrefChallengePersonalInformationURL =
    @"PrefChallengePersonalInformationURL";
static NSString *const kPrefPurchaseMonth = @"PrefPurchaseMonth";
static NSString *const kPrefPurchaseLimitType = @"PrefPurchaseLimitType";
static NSString *const kPrefTotalPurchase = @"PrefTotalPurchase";

// The coin-refilled notification's text and sound, from the CFStrings at 0x2e0e20, 0x2e0e40,
// 0x2e0e80, and 0x2dc680. The two Japanese strings are stored UTF-16 in the binary and differ only
// by the trailing full-width exclamation mark: the alert body has it, the "aps" alert entry does
// not.
static NSString *const kCoinRefilledAlertText = @"プレーコインが回復しました";
static NSString *const kCoinRefilledAlertBody = @"プレーコインが回復しました！";
static NSString *const kCoinNotificationSound = @"push.caf";
static NSString *const kCoinNotificationAlertAction = @"Open";

// The URL the notification carries, from the CFString at 0x2e0e60. Note it is a different scheme
// from the "jubeatplus" one -[JubeatAppDelegate application:handleOpenURL:] matches.
static NSString *const kChallengeNotificationURL = @"jbtchallenge://";

// The notification payload keys, the same set -[JubeatAppDelegate apsDictionary:] reads back out.
static NSString *const kApsPayloadKey = @"aps";
static NSString *const kApsAlertKey = @"alert";
static NSString *const kNotificationSoundKey = @"sound";
static NSString *const kNotificationURLKey = @"url";
static NSString *const kNotificationExpireKey = @"expire";

// These four ivars carry the binary's own names, which are not underscore-prefixed and are not
// declared as properties in the runtime metadata, so they are declared directly rather than
// synthesised.
@interface ChallengeStatus () {
    int selectedMissionSheetID;       // +0x28
    double coinRestTime;              // +0x30
    NSMutableDictionary *lineupImage; // +0x38, UIImage keyed by music-id number
    BOOL scratchRefresh;              // +0x40, set when the persisted scratch id changed
}

// Redeclared readwrite for internal mutation.
@property(nonatomic, strong, readwrite, nullable) NSNumber *scratchID;
@property(nonatomic, strong, readwrite, nullable) NSString *personalInfoURL;
@property(nonatomic, strong, readwrite, nullable) NSArray *enableMissionSheets;
@property(nonatomic, assign, readwrite) BOOL bInitialized;
@property(nonatomic, assign, readwrite) int presentNum;
@property(nonatomic, assign, readwrite) BOOL bItemDownload;
@property(nonatomic, assign, readwrite) float phoneScreenRate;
@property(nonatomic, weak, readwrite, nullable) ChallengeModeRootView *rootView;

@end

@implementation ChallengeStatus

#pragma mark - Singleton

/** @ghidraAddress 0x1cac90 */
+ (ChallengeStatus *)sharedStatus {
    static ChallengeStatus *g_pChallengeStatusShared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x1cacd0 */
      g_pChallengeStatusShared = [[ChallengeStatus alloc] init];
    });
    return g_pChallengeStatusShared;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x1cad10 */
- (instancetype)init {
    self = [super init];
    if (self) {
        CGRect bounds = GetMainScreenBounds();
        self.phoneScreenRate = (float)(bounds.size.width / 320.0);
        if (JubeatAppDelegate.appDelegate.isPad) {
            self.phoneScreenRate = 1.0f;
        }
        self.howtoURL = nil;
        self.mySearchID = nil;
        self.bInitialized = NO;
        self.bItemDownload = NO;
        lineupImage = [[NSMutableDictionary alloc] init];
        self.consumePlayCoin = kDefaultConsumePlayCoin;
        self.consumeScratchCube = kDefaultConsumeScratchCube;
        self.consumeRestCube = kDefaultConsumeRestCube;
        selectedMissionSheetID = kDefaultSelectedMissionSheetID;
    }
    return self;
}

/** @ghidraAddress 0x1cae84 */
- (void)resetStatus {
    self.howtoURL = nil;
    self.bInitialized = NO;
    self.bItemDownload = NO;
    self.mySearchID = nil;
    lineupImage = nil;
    lineupImage = [[NSMutableDictionary alloc] init];
    self.consumePlayCoin = kDefaultConsumePlayCoin;
    self.consumeScratchCube = kDefaultConsumeScratchCube;
    self.consumeRestCube = kDefaultConsumeRestCube;
    self.personalInfoURL = nil;
    self.informationURL = nil;
    selectedMissionSheetID = kDefaultSelectedMissionSheetID;
}

/** @ghidraAddress 0x1caf8c */
- (void)initWithDictionary:(NSDictionary *)dictionary {
    [self updateUserInfo:dictionary];
    [self updateScratchID:dictionary];
    [self updateServerTime:dictionary];
    [self updateScratchTimeState:dictionary];
    [self updateCubeState:dictionary];
    [self updateCoinState:dictionary];
    [self updateNailState:dictionary];
    [self updateScratchLineup:dictionary];
    [self updateScratchTable:dictionary];
    [self updateScratchItemDir];
    [self updateHowtoURL:dictionary];
    [self updateInformationURL:dictionary];
    [self updatePersonalInformationURL:dictionary];
    [self updatePresentNum:dictionary];
    [self updateConsume:dictionary];
    [self updateChallengeMission:dictionary];
    self.bInitialized = YES;
}

#pragma mark - State updates

/** @ghidraAddress 0x1cb114 */
- (void)updateState:(NSDictionary *)dictionary {
    [self updateCubeState:dictionary];
    [self updateNailState:dictionary];
    [self updateCoinState:dictionary];
    [self updateScratchTable:dictionary];
    [self updateScratchLineup:dictionary];
    [self updateScratchItemDir];
    [self updateHowtoURL:dictionary];
    [self updateInformationURL:dictionary];
    [self updatePersonalInformationURL:dictionary];
    [self updatePresentNum:dictionary];
    [self updateConsume:dictionary];
    [self updateChallengeMission:dictionary];
}

/** @ghidraAddress 0x1cb238 */
- (void)updateConsume:(NSDictionary *)dictionary {
    // Each value is read with -intValue (objectForKey: then the intValue message send in the
    // disassembly), not stored as a raw pointer.
    if (dictionary[kKeyConsumePlayCoin]) {
        self.consumePlayCoin = [dictionary[kKeyConsumePlayCoin] intValue];
    }
    if (dictionary[kKeyConsumeScratchCube]) {
        self.consumeScratchCube = [dictionary[kKeyConsumeScratchCube] intValue];
    }
    if (dictionary[kKeyConsumeRestCoin]) {
        self.consumeRestCube = [dictionary[kKeyConsumeRestCoin] intValue];
    }
}

/** @ghidraAddress 0x1cb36c */
- (void)updateName:(NSString *)name {
    self.myName = name;
}

/** @ghidraAddress 0x1cb380 */
- (void)setScratchItem:(int)index dict:(NSDictionary *)dict {
    if (dict[kKeyMusicID]) {
        [self.scratchInfoTable[index] init:dict];
    }
}

/** @ghidraAddress 0x1cb43c */
- (void)updatePresentNum:(NSDictionary *)dictionary {
    if (dictionary[kKeyPresent]) {
        self.presentNum = [dictionary[kKeyPresent] intValue];
    }
}

/** @ghidraAddress 0x1cb4dc */
- (void)setPresentNum:(int)num {
    _presentNum = num;
}

/** @ghidraAddress 0x1cb4ec */
- (void)updateScratchID:(NSDictionary *)dictionary {
    NSNumber *scratchID = dictionary[kKeyScratchID];
    if (!scratchID) {
        return;
    }
    id last = [NSUserDefaults.standardUserDefaults objectForKey:kPrefLastScratchID];
    if ([scratchID isEqual:last]) {
        scratchRefresh = NO;
    } else {
        [NSUserDefaults.standardUserDefaults setValue:scratchID forKey:kPrefLastScratchID];
        scratchRefresh = YES;
    }
    // The binary compares the new value's is-zero flag (1 or 0) against the current identifier's
    // integer value, and returns without replacing when they are equal. This odd mixed comparison
    // is faithful to the shipped code.
    if (self.scratchID) {
        int newIsZero = (scratchID.intValue == 0) ? 1 : 0;
        if (newIsZero == self.scratchID.intValue) {
            return;
        }
    }
    self.scratchID = scratchID;
}

/** @ghidraAddress 0x1cb668 */
- (void)updateHowtoURL:(NSDictionary *)dictionary {
    NSString *url = dictionary[kKeyHowtoURL];
    if (url) {
        self.howtoURL = url;
    }
}

/** @ghidraAddress 0x1cb6d4 */
- (void)updateInformationURL:(NSDictionary *)dictionary {
    NSString *url = dictionary[kKeyInformationURL];
    if (url) {
        NSString *saved =
            [NSUserDefaults.standardUserDefaults objectForKey:kPrefChallengeInformationURL];
        if (!saved || ![saved isEqualToString:url]) {
            self.informationURL = url;
        }
    }
}

/** @ghidraAddress 0x1cb7b4 */
- (void)saveInformationURL {
    if (self.informationURL) {
        [NSUserDefaults.standardUserDefaults setObject:self.informationURL
                                                forKey:kPrefChallengeInformationURL];
        self.informationURL = nil;
    }
}

/** @ghidraAddress 0x1cb880 */
- (void)updatePersonalInformationURL:(NSDictionary *)dictionary {
    NSString *url = dictionary[kKeyPersonalInfoURL];
    if (url) {
        NSString *saved =
            [NSUserDefaults.standardUserDefaults objectForKey:kPrefChallengePersonalInformationURL];
        if (!saved || ![saved isEqualToString:url]) {
            self.personalInfoURL = url;
        }
    }
}

/** @ghidraAddress 0x1cb960 */
- (void)savePersionalInformationURL {
    if (self.personalInfoURL) {
        [NSUserDefaults.standardUserDefaults setObject:self.personalInfoURL
                                                forKey:kPrefChallengePersonalInformationURL];
        self.personalInfoURL = nil;
    }
}

/** @ghidraAddress 0x1cba2c */
- (void)updateScratchItemDir {
    if (scratchRefresh) {
        [ScratchUtil clearScratchData];
        scratchRefresh = NO;
    }
}

/** @ghidraAddress 0x1cba70 */
- (void)updateScratchTable:(NSDictionary *)dictionary {
    self.scratchInfoTable = nil;
    NSMutableArray<ScratchInfo *> *table = [NSMutableArray arrayWithCapacity:kScratchPanelCount];
    for (int i = 0; i < kScratchPanelCount; ++i) {
        // Allocated without a matching -init; the binary sends -setBOpen:/-setMusicID: to the
        // bare +alloc result.
        ScratchInfo *info = [ScratchInfo alloc];
        [info setBOpen:0];
        [info setMusicID:0];
        table[i] = info;
    }
    NSArray *panels = dictionary[kKeyScratchPanel];
    if (panels) {
        for (NSDictionary *panel in panels) {
            int position = [panel[kKeyPosition] intValue];
            [table[position] init:panel];
        }
    }
    self.scratchInfoTable = [NSArray arrayWithArray:table];
}

/** @ghidraAddress 0x1cbd64 */
- (void)updateScratchLineup:(NSDictionary *)dictionary {
    NSArray *list = dictionary[kKeyMusicList];
    if (list) {
        self.scratchLineUp = nil;
        if ([dictionary[kKeyMusicList] count] == 0) {
            self.scratchLineUp = [[NSArray alloc] init];
        } else {
            self.scratchLineUp = [NSArray arrayWithArray:dictionary[kKeyMusicList]];
        }
    }
}

/** @ghidraAddress 0x1cbea4 */
- (void)updateUserInfo:(NSDictionary *)dictionary {
    if (dictionary[kKeyName]) {
        self.myName = dictionary[kKeyName];
    }
    if (dictionary[kKeyUserID]) {
        self.mySearchID = dictionary[kKeyUserID];
    }
    if (!self.mySearchID) {
        self.mySearchID = [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
    }
}

/** @ghidraAddress 0x1cc00c */
- (void)updateScratchTimeState:(NSDictionary *)dictionary {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = kServerDateFormat;
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:kServerTimeZoneAbbreviation];
    if (dictionary[kKeyEnd]) {
        self.scratchResetDate = [formatter dateFromString:dictionary[kKeyEnd]];
    }
}

/** @ghidraAddress 0x1cc158 */
- (void)updateServerTime:(NSDictionary *)dictionary {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:kServerTimeZoneAbbreviation];
    formatter.dateFormat = kServerDateFormat;
    if (dictionary[kKeyServerTime]) {
        self.serverDate = [formatter dateFromString:dictionary[kKeyServerTime]];
        formatter.dateFormat = kServerMonthFormat;
        int month = [[formatter stringFromDate:self.serverDate] intValue];
        NSInteger savedMonth =
            [NSUserDefaults.standardUserDefaults integerForKey:kPrefPurchaseMonth];
        if (savedMonth < month) {
            NSInteger limitType =
                [NSUserDefaults.standardUserDefaults integerForKey:kPrefPurchaseLimitType];
            if (limitType != kPurchaseLimitTypeSubscription) {
                [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefPurchaseLimitType];
            }
            [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefTotalPurchase];
        }
        [NSUserDefaults.standardUserDefaults setInteger:month forKey:kPrefPurchaseMonth];
    }
    self.clientDate = NSDate.date;
    self.serverTimeDelay = [self.clientDate timeIntervalSinceDate:self.serverDate];
}

/** @ghidraAddress 0x1cc4b0 */
- (void)updateCubeState:(NSDictionary *)dictionary {
    if (dictionary[kKeyJCube]) {
        self.jCubeNum = [dictionary[kKeyJCube] intValue];
    }
}

/** @ghidraAddress 0x1cc550 */
- (void)updateCoinState:(NSDictionary *)dictionary {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:kServerTimeZoneAbbreviation];
    formatter.dateFormat = kServerDateFormat;
    if (dictionary[kKeyRecoveryTime]) {
        coinRestTime = (double)[dictionary[kKeyRecoveryTime] intValue];
    }
    if (dictionary[kKeyPlayCoinLimit]) {
        self.coinLim = [dictionary[kKeyPlayCoinLimit] intValue];
    }
    if (dictionary[kKeyPlayCoin]) {
        self.coinNum = [dictionary[kKeyPlayCoin] intValue];
    }
    self.coinRestDate = NSDate.date;
    if (self.coinNum < self.coinLim) {
        NSDate *base = [formatter dateFromString:dictionary[kKeyRecoveryBaseTime]];
        if (base) {
            self.coinRestDate = [base initWithTimeInterval:coinRestTime sinceDate:base];
        }
    }
}

/** @ghidraAddress 0x1cc840 */
- (void)updateNailState:(NSDictionary *)dictionary {
    if (dictionary[kKeyScratchNail]) {
        self.nailNum = [dictionary[kKeyScratchNail] intValue];
    }
}

/** @ghidraAddress 0x1cc8e0 */
- (void)restCoinNum {
    if (self.coinNum < self.coinLim) {
        double timeLeft = [self getTimeLeft:self.coinRestDate];
        while (timeLeft < 1.0) {
            if (self.coinNum < self.coinLim) {
                self.coinNum = self.coinNum + 1;
                self.coinRestDate = [self.coinRestDate dateByAddingTimeInterval:coinRestTime];
            }
            timeLeft = [self getTimeLeft:self.coinRestDate];
        }
    }
}

/** @ghidraAddress 0x1cc9d0 */
- (void)updateChallengeMission:(NSDictionary *)dictionary {
    self.enableMissionSheets = nil;
    NSDictionary *sheetList = dictionary[kKeySheetList];
    if (sheetList && sheetList.count != 0) {
        NSMutableArray<ChallengeMissionSheet *> *sheets = [[NSMutableArray alloc] init];
        NSArray *keys = [[sheetList allKeys]
            sortedArrayUsingComparator:^NSComparisonResult(id leftKey, id rightKey) {
              /** @ghidraAddress 0x1ccd1c */
              // The -intValue round trip makes the sort numeric: the keys are plist strings, so
              // a lexical compare would order "10" before "9".
              NSNumber *left = @([leftKey intValue]);
              NSNumber *right = @([rightKey intValue]);
              return [left compare:right];
            }];
        for (id key in keys) {
            NSMutableDictionary *entry = [sheetList[key] mutableCopy];
            entry[kKeySheetID] = key;
            ChallengeMissionSheet *sheet = [[ChallengeMissionSheet alloc] init];
            [sheet initWithDictionary:entry];
            // The binary evaluates -intValue on the key and every sheet accessor purely for their
            // side effects and discards the results; the built sheet is never added to the array.
            (void)[key intValue];
            (void)sheet.missionCnt;
            (void)sheet.updateTime;
            (void)sheet.isEvent;
        }
        self.enableMissionSheets = [sheets copy];
    }
}

/** @ghidraAddress 0x1cce10 */
- (void)exchangeNail:(NSDictionary *)dictionary {
    [self updateNailState:dictionary];
    [self updateCubeState:dictionary];
}

/** @ghidraAddress 0x1cce70 */
- (void)openScratch:(NSDictionary *)dictionary index:(int)index {
    [self updateNailState:dictionary];
    [self updateCubeState:dictionary];
    [self setScratchItem:index dict:dictionary];
}

/** @ghidraAddress 0x1cceec */
- (void)restPlayCoin:(NSDictionary *)dictionary {
    [self updateCoinState:dictionary];
    [self updateCubeState:dictionary];
}

/** @ghidraAddress 0x1ccf4c */
- (void)changeScratchNail:(NSDictionary *)dictionary {
    [self updateNailState:dictionary];
    [self updateCubeState:dictionary];
}

/** @ghidraAddress 0x1ccfac */
- (void)cubePurchaseSuccess:(NSDictionary *)dictionary {
    [self updateCubeState:dictionary];
}

/** @ghidraAddress 0x1ccfb8 */
- (void)openMusicDetail:(NSDictionary *)dictionary index:(int)index {
    [self.scratchInfoTable[index] openUpdate:dictionary];
    [self updateServerTime:dictionary];
}

/** @ghidraAddress 0x1cd064 */
- (void)playMusic:(NSDictionary *)dictionary {
    self.sessionSeed = dictionary[kKeySessionSeed];
    [self updateCoinState:dictionary];
}

/** @ghidraAddress 0x1cd0ec */
- (void)receivePresent:(NSDictionary *)dictionary {
    [self updateCoinState:dictionary];
    [self updateCubeState:dictionary];
    [self updateNailState:dictionary];
}

/** @ghidraAddress 0x1cd160 */
- (void)updateMusicRanking:(int)musicID diff:(int)diff rank:(int)rank index:(int)index {
    for (NSUInteger i = 0; i < self.scratchInfoTable.count; ++i) {
        ScratchInfo *info = self.scratchInfoTable[i];
        if (info.musicID == musicID) {
            [info setMyRank:diff rank:rank index:index];
            return;
        }
    }
}

#pragma mark - Derived time values

/** @ghidraAddress 0x1cd2d0 */
- (NSString *)timeStringFromInterval_Minute:(double)interval {
    int hours = (int)(interval / kSecondsPerHour);
    interval -= (double)(hours * 3600);
    int minutes = (int)(interval / kSecondsPerMinute);
    interval -= (double)(minutes * 60);
    if (hours > kMaxMinutesClamp) {
        hours = kMaxMinutesClamp;
    }
    int totalMinutes = hours * 60 + minutes;
    int seconds = (int)interval;
    return [NSString stringWithFormat:@"%d:%02d", totalMinutes, seconds];
}

/** @ghidraAddress 0x1cd35c */
- (NSString *)timeStringFromInterval:(double)interval {
    int hours = (int)(interval / kSecondsPerHour);
    interval -= (double)(hours * 3600);
    int minutes = (int)(interval / kSecondsPerMinute);
    interval -= (double)(minutes * 60);
    if (hours > kMaxHoursClamp) {
        hours = kMaxHoursClamp;
    }
    int seconds = (int)interval;
    return [NSString stringWithFormat:@"%02d:%02d:%02d", hours, minutes, seconds];
}

/** @ghidraAddress 0x1cd3e8 */
- (double)getTimeLeft:(NSDate *)date {
    NSDate *corrected = [date dateByAddingTimeInterval:self.serverTimeDelay];
    return [corrected timeIntervalSinceDate:NSDate.date];
}

/** @ghidraAddress 0x1cd47c */
- (double)getMusicEnableTime:(int)index {
    ScratchInfo *info = self.scratchInfoTable[index];
    if (info.musicID == 0) {
        return -1.0;
    }
    return [self getTimeLeft:info.endDate];
}

/** @ghidraAddress 0x1cd54c */
- (NSString *)getMusicEnableTimeString:(int)index {
    return [self timeStringFromInterval:[self getMusicEnableTime:index]];
}

#pragma mark - Line-up image cache

/** @ghidraAddress 0x1cd580 */
- (void)setLineupImage:(UIImage *)image musicID:(id)musicID {
    [lineupImage setObject:image forKey:musicID];
}

/** @ghidraAddress 0x1cd5dc */
- (UIImage *)getLineupImage:(id)musicID {
    return [lineupImage objectForKey:musicID];
}

/** @ghidraAddress 0x1cd5f4 */
- (void)clearLineupImage {
    [lineupImage removeAllObjects];
}

#pragma mark - Scratch panel counts

/** @ghidraAddress 0x1cd60c */
- (int)scratchablePanelNum {
    int count = 0;
    for (ScratchInfo *info in self.scratchInfoTable) {
        if (info.musicID == 0) {
            ++count;
        }
    }
    return count;
}

/** @ghidraAddress 0x1cd740 */
- (int)scratchOpenedPanelNum {
    int count = 0;
    for (ScratchInfo *info in self.scratchInfoTable) {
        if (info.musicID != 0) {
            ++count;
        }
    }
    return count;
}

#pragma mark - Notifications

/** @ghidraAddress 0x1cd874 */
- (void)createCoinNotification {
    if (!self.bInitialized) {
        return;
    }
    // Yes, the result is discarded. The call is kept for its side effect of refreshing the counts
    // that the comparison below reads.
    [self restCoinNum];
    if (self.coinNum >= self.coinLim) {
        return;
    }

    int coinLim = self.coinLim;
    int coinNum = self.coinNum;
    double restTime = coinRestTime;
    double secondsForCurrent = [self getTimeLeft:self.coinRestDate];

    [UIApplication.sharedApplication cancelAllLocalNotifications];

    // The expiry stamp is the current time, not the fire time.
    long now = (long)NSDate.date.timeIntervalSince1970;

    NSDictionary *aps = @{
        kApsAlertKey : kCoinRefilledAlertText,
        kNotificationSoundKey : kCoinNotificationSound,
    };
    NSDictionary *userInfo = @{
        kApsPayloadKey : aps,
        kNotificationURLKey : kChallengeNotificationURL,
        kNotificationExpireKey : @(now),
    };

    // Time for the coin regenerating now plus every coin still missing after it.
    int fireInSeconds =
        (int)secondsForCurrent + (int)(restTime * (double)((coinLim - 1) - coinNum));

    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:(double)fireInSeconds];
    notification.timeZone = NSTimeZone.systemTimeZone;
    notification.alertBody = kCoinRefilledAlertBody;
    notification.userInfo = userInfo;
    notification.alertAction = kCoinNotificationAlertAction;
    [UIApplication.sharedApplication scheduleLocalNotification:notification];
}

#pragma mark - Mission sheets

/** @ghidraAddress 0x1cdc30 */
- (void)updateMissionSheet:(NSDictionary *)dictionary {
    selectedMissionSheetID = 0;
    if (dictionary[kKeySelectSheetID]) {
        selectedMissionSheetID = [dictionary[kKeySelectSheetID] intValue];
    }
}

/** @ghidraAddress 0x1cdcdc */
- (ChallengeMissionSheet *)getSelectedMissionSheet {
    return [ChallengeMissionFileManager.sharedManager getChallengeSheet:selectedMissionSheetID];
}

/** @ghidraAddress 0x1cdd48 */
- (void)setSelectedMissionSheet:(ChallengeMissionSheet *)sheet {
    int newID = sheet.sheetID;
    NSMutableArray<ChallengeMissionSheet *> *rebuilt = [[NSMutableArray alloc] init];
    int previousID = selectedMissionSheetID;
    selectedMissionSheetID = newID;
    int insertBefore = newID;
    for (NSUInteger i = 0; i < self.enableMissionSheets.count; ++i) {
        ChallengeMissionSheet *existing = self.enableMissionSheets[i];
        if (existing.sheetID != previousID) {
            if (existing.sheetID < insertBefore) {
                [rebuilt addObject:sheet];
                insertBefore = -1;
            }
            [rebuilt addObject:existing];
        }
    }
    if (insertBefore != -1) {
        [rebuilt addObject:sheet];
    }
    self.enableMissionSheets = [rebuilt copy];
}

/** @ghidraAddress 0x1cdf68 */
- (int)getSelectedMissionSheetID {
    return selectedMissionSheetID;
}

/** @ghidraAddress 0x1cdf78 */
- (void)missionRewardDownload {
    self.bItemDownload = YES;
}

/** @ghidraAddress 0x1cdf8c */
- (void)setChallengeRootView:(ChallengeModeRootView *)rootView {
    self.rootView = rootView;
}

@end
