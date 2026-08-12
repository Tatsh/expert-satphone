#import "ChallengeMissionSheet.h"

#import "ChallengeMissionAchieve.h"
#import "ChallengeMissionPlayTerm.h"
#import "ChallengeMissionReward.h"
#import "ChallengeMissionTerms.h"
#import "cipher_keys.h"

// The Blowfish codec and the mission-data cipher key, used to persist a saved sheet. Not
// reconstructed in this tree yet, so they are forward-declared. See TYPES_PENDING.md.
@interface BFCodec : NSObject
- (void)cipherInit:(NSData *)key;
- (BOOL)decipher:(NSMutableData *)data;
- (BOOL)encipher:(NSMutableData *)data;
@end

// The server's sheet wire keys, in the order -generateMissionSheetDictionary emits them.
static NSString *const kConfirmFlagKey = @"confirm_flag";
static NSString *const kNameKey = @"name";
static NSString *const kSheetIdKey = @"sheet_id";
static NSString *const kAmountKey = @"amount";
static NSString *const kTotalKey = @"total";
static NSString *const kVersionKey = @"version";
static NSString *const kIsEventKey = @"is_event";
static NSString *const kViewStartKey = @"view_start";
static NSString *const kViewEndKey = @"view_end";
static NSString *const kRewardKey = @"reward";
static NSString *const kMissionListKey = @"mission_list";

// The empty-string default the date and version fields fall back to when the record omits them.
static NSString *const kEmptyDefault = @"";

// The mission id is formatted with this to key the achievement dictionary.
static NSString *const kMissionIdFormat = @"%d";

@implementation ChallengeMissionSheet {
    BOOL _bConfirmed;                // +0x08
    BOOL _isEvent;                   // +0x09
    BOOL _enableSave;                // +0x0a
    int _sheetID;                    // +0x0c
    int _missionCnt;                 // +0x10
    int _totalMissionCnt;            // +0x14
    NSString *_sheetName;            // +0x18
    NSString *_updateTime;           // +0x20
    NSString *_sheetStartDate;       // +0x28
    NSString *_sheetEndDate;         // +0x30
    NSString *_sheetBgURL;           // +0x38
    ChallengeMissionReward *_reward; // +0x40
    NSArray *_missionTable;          // +0x48
    NSArray *_missionAchieveTable;   // +0x50
    NSArray *_missionSimpleTable;    // +0x58
}

#pragma mark - Construction

/** @ghidraAddress 0x1f0c08 */
- (instancetype)init {
    return [super init];
}

/** @ghidraAddress 0x1f0c40 */
- (void)initWithDictionary:(NSDictionary *)dictionary {
    // The confirm flag is set from mere presence of the key, not its value, as in the binary.
    _bConfirmed = dictionary[kConfirmFlagKey] != nil;
    _enableSave = NO;
    _sheetName = dictionary[kNameKey];
    _sheetID = [dictionary[kSheetIdKey] intValue];
    _missionCnt = [dictionary[kAmountKey] intValue];
    _totalMissionCnt = [dictionary[kTotalKey] intValue];
    _updateTime = dictionary[kVersionKey];
    if (!_updateTime) {
        _updateTime = kEmptyDefault;
    }
    _isEvent = [dictionary[kIsEventKey] boolValue];
    _sheetStartDate = dictionary[kViewStartKey];
    if (!self.sheetStartDate) {
        _sheetStartDate = kEmptyDefault;
    }
    _sheetEndDate = dictionary[kViewEndKey];
    if (!self.sheetEndDate) {
        _sheetEndDate = kEmptyDefault;
    }
    if (dictionary[kRewardKey]) {
        _reward = [[ChallengeMissionReward alloc] init];
        [_reward initWithDictionary:dictionary];
    }
    if (dictionary[kMissionListKey]) {
        [self updateMissionTerms:dictionary];
    }
}

/** @ghidraAddress 0x1f0fd0 */
- (BOOL)initWithData:(NSData *)data sheetID:(int)sheetID {
    NSMutableData *buffer = [data mutableCopy];
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:CreateMissionDataCipherKey()];
    if ([codec decipher:buffer]) {
        NSDictionary *record = [NSKeyedUnarchiver unarchiveObjectWithData:buffer];
        if (record && [record[kSheetIdKey] intValue] == sheetID) {
            [self initWithDictionary:record];
            return YES;
        }
    }
    return NO;
}

#pragma mark - Table building

/** @ghidraAddress 0x1f1134 */
- (void)updateMissionTerms:(NSDictionary *)dictionary {
    NSDictionary *missionList = dictionary[kMissionListKey];
    if ((int)missionList.count <= 0) {
        return;
    }
    if (dictionary[kRewardKey]) {
        _reward = [[ChallengeMissionReward alloc] init];
        [_reward initWithDictionary:dictionary];
    }
    NSMutableArray *terms = [[NSMutableArray alloc] initWithCapacity:(int)missionList.count];
    NSArray *sortedKeys =
        [missionList.allKeys sortedArrayUsingComparator:^NSComparisonResult(id left, id right) {
          /** @ghidraAddress 0x1f1490 */
          return [@([left intValue]) compare:@([right intValue])];
        }];
    for (id key in sortedKeys) {
        ChallengeMissionTerms *term = [[ChallengeMissionTerms alloc] init];
        [term initWithDictionary:missionList[key]];
        [terms addObject:term];
    }
    // Keep the built terms only when every mission was present; a short list is discarded.
    if (_missionCnt == (int)terms.count) {
        _missionTable = [terms copy];
        _enableSave = YES;
    }
}

/** @ghidraAddress 0x1f1584 */
- (void)updateMissionAchieves:(NSDictionary *)dictionary {
    if (self.missionTable.count == 0) {
        return;
    }
    NSDictionary *achievements = [dictionary copy];
    NSMutableArray *achieveTable =
        [[NSMutableArray alloc] initWithCapacity:(int)achievements.count];
    NSMutableArray *simpleTable = [[NSMutableArray alloc] initWithCapacity:(int)achievements.count];
    for (ChallengeMissionTerms *term in self.missionTable) {
        NSString *key = [NSString stringWithFormat:kMissionIdFormat, term.missionID];
        ChallengeMissionAchieve *achieve = [[ChallengeMissionAchieve alloc] init];
        ChallengeMissionPlayTerm *playTerm = [[ChallengeMissionPlayTerm alloc] init];
        if (achievements[key]) {
            [achieve initWithDictionary:achievements[key]];
        }
        [achieveTable addObject:achieve];
        [playTerm initWithData:term achieve:achieve];
        [simpleTable addObject:playTerm];
    }
    _missionAchieveTable = nil;
    // The achievement table is kept only when it covers every mission; the play-term table always.
    if (_missionCnt == (int)achieveTable.count) {
        _missionAchieveTable = [achieveTable copy];
    }
    _missionSimpleTable = [simpleTable copy];
}

#pragma mark - Persistence

/** @ghidraAddress 0x1f1994 */
- (NSData *)generateSaveData {
    if (!self.enableSave) {
        return nil;
    }
    NSMutableData *buffer = [[NSKeyedArchiver
        archivedDataWithRootObject:[self generateMissionSheetDictionary]] mutableCopy];
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:CreateMissionDataCipherKey()];
    [codec encipher:buffer];
    return [buffer copy];
}

/** @ghidraAddress 0x1f1ac4 */
- (NSMutableDictionary *)generateMissionSheetDictionary {
    NSMutableDictionary *sheet = [[NSMutableDictionary alloc] init];
    sheet[kConfirmFlagKey] = @(self.bConfirmed);
    sheet[kNameKey] = self.sheetName;
    sheet[kSheetIdKey] = @(self.sheetID);
    sheet[kAmountKey] = @(self.missionCnt);
    sheet[kTotalKey] = @(self.totalMissionCnt);
    sheet[kVersionKey] = self.updateTime;
    sheet[kIsEventKey] = @(self.isEvent);
    sheet[kViewStartKey] = self.sheetStartDate;
    sheet[kViewEndKey] = self.sheetEndDate;
    NSDictionary *rewardDictionary = [self.reward getDictionary];
    if (rewardDictionary) {
        sheet[kRewardKey] = rewardDictionary;
    }
    NSDictionary *missionDictionary = [self generateMissionDictionary];
    if (missionDictionary) {
        sheet[kMissionListKey] = missionDictionary;
    }
    return sheet;
}

/** @ghidraAddress 0x1f1e5c */
- (NSDictionary *)generateMissionDictionary {
    if (self.missionTable.count == 0) {
        return nil;
    }
    NSMutableDictionary *missions = [[NSMutableDictionary alloc] init];
    for (ChallengeMissionTerms *term in self.missionTable) {
        missions[@(term.missionID)] = [term getDictionary];
    }
    return [missions copy];
}

#pragma mark - Confirmation

/** @ghidraAddress 0x1f2084 */
- (BOOL)checkMissionSheet {
    BOOL wasUnconfirmed = !self.bConfirmed;
    if (wasUnconfirmed) {
        _bConfirmed = YES;
    }
    return wasUnconfirmed;
}

@end
