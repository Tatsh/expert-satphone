#import "ChallengeMissionAchieve.h"

ChallengeMissionAchieveKey const ChallengeMissionAchieveKeyMissionID = @"mission_id";
ChallengeMissionAchieveKey const ChallengeMissionAchieveKeyMasterMissionID = @"cs_mst_mission_id";
ChallengeMissionAchieveKey const ChallengeMissionAchieveKeyAchievementID = @"achievement_id";
ChallengeMissionAchieveKey const ChallengeMissionAchieveKeyStatus = @"status";
ChallengeMissionAchieveKey const ChallengeMissionAchieveKeyData = @"data";
ChallengeMissionAchieveKey const ChallengeMissionAchieveKeyClearDate = @"clear_date";

// The three identifiers start here rather than at zero, which is what lets zero act as the
// "mission_id was absent" signal in -initWithDictionary:.
static const int kUnsetIdentifier = -1;

@implementation ChallengeMissionAchieve

/** @ghidraAddress 0x1eed9c */
- (instancetype)init {
    self = [super init];
    if (self) {
        _missionID = kUnsetIdentifier;
        _achievementID = kUnsetIdentifier;
        _missionState = kUnsetIdentifier;
        // Note that achieveDetail and termCompleteDate are left nil rather than reset.
    }
    return self;
}

/** @ghidraAddress 0x1eee00 */
- (BOOL)initWithDictionary:(NSDictionary *)dict {
    // Yes, no [super init] and no self = ... . The name says initialiser; the metadata says this
    // returns BOOL and the body just fills in the fields.
    _missionID = [[dict objectForKey:ChallengeMissionAchieveKeyMissionID] intValue];
    if (_missionID == 0) {
        // A zero identifier means the server used the master-table key instead. An absent
        // mission_id also gives zero, since -intValue on nil is zero, so both routes land here.
        _missionID = [[dict objectForKey:ChallengeMissionAchieveKeyMasterMissionID] intValue];
    }
    _achievementID = [[dict objectForKey:ChallengeMissionAchieveKeyAchievementID] intValue];
    _missionState = [[dict objectForKey:ChallengeMissionAchieveKeyStatus] intValue];
    _achieveDetail = [[dict objectForKey:ChallengeMissionAchieveKeyData] copy];
    // Retained, not copied, unlike achieveDetail above.
    _termCompleteDate = [dict objectForKey:ChallengeMissionAchieveKeyClearDate];
    return YES;
}

/** @ghidraAddress 0x1eefc0 */
- (void)updateAchieve:(NSDictionary *)dict {
    // Compared against the property rather than the ivar, which is the binary's choice.
    if ([[dict objectForKey:ChallengeMissionAchieveKeyMissionID] intValue] != self.missionID) {
        return;
    }

    // Each field is fetched once to test for presence and then fetched again to read. That is the
    // binary's shape throughout this method, not a transcription artefact.
    if ([dict objectForKey:ChallengeMissionAchieveKeyAchievementID] != nil) {
        _achievementID = [[dict objectForKey:ChallengeMissionAchieveKeyAchievementID] intValue];
    }
    if ([dict objectForKey:ChallengeMissionAchieveKeyStatus] != nil) {
        _missionState = [[dict objectForKey:ChallengeMissionAchieveKeyStatus] intValue];
        // The clear date is nested inside the status test, so a record carrying a date but no
        // status leaves the date unapplied.
        if ([dict objectForKey:ChallengeMissionAchieveKeyClearDate] != nil) {
            _termCompleteDate = [dict objectForKey:ChallengeMissionAchieveKeyClearDate];
        }
    }
    // And the detail is gated on the status key a second time, not on its own key.
    if ([dict objectForKey:ChallengeMissionAchieveKeyStatus] != nil) {
        _achieveDetail = [[dict objectForKey:ChallengeMissionAchieveKeyData] copy];
    }
}

@end
