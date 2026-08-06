#import "ChallengeMissionTerms.h"

// The wire keys, from the CFStrings at 0x2d46a0, 0x2e1940, 0x2d4880, 0x2d4860, 0x2d6900, and
// 0x2e1960. -getDictionary emits them in the order below. "name" and "description" are the same
// two CFStrings ChallengeMissionReward uses.
static NSString *const kMissionIDKey = @"id";
static NSString *const kConditionKey = @"condition";
static NSString *const kNameKey = @"name";
static NSString *const kDescriptionKey = @"description";
static NSString *const kDataKey = @"data";
static NSString *const kSkipFeeKey = @"fee_skip";

@implementation ChallengeMissionTerms

/** @ghidraAddress 0x1ee928 */
- (BOOL)initWithDictionary:(NSDictionary *)dictionary {
    // No guard of any kind: six keys are read straight off the top level and every path returns
    // YES. A dictionary missing all six leaves the object zeroed and still reports success.
    _missionID = [[dictionary objectForKey:kMissionIDKey] intValue];
    _missionType = [[dictionary objectForKey:kConditionKey] intValue];
    _missionTitle = [dictionary objectForKey:kNameKey];
    _missionExplain = [dictionary objectForKey:kDescriptionKey];
    _missionDetail = [dictionary objectForKey:kDataKey];
    _skipCost = [[dictionary objectForKey:kSkipFeeKey] intValue];
    return YES;
}

/** @ghidraAddress 0x1eead4 */
- (NSDictionary *)getDictionary {
    // Read from the stack setup before the call, not from the decompile. Six objects against six
    // keys, with a count immediate of 6.
    //
    // All three integers are boxed with +numberWithInt:, including missionType, which the property
    // metadata declares unsigned.
    id objects[] = {
        @(self.missionID),
        @(self.missionType),
        self.missionTitle,
        self.missionExplain,
        self.missionDetail,
        @(self.skipCost),
    };
    id keys[] = {
        kMissionIDKey,
        kConditionKey,
        kNameKey,
        kDescriptionKey,
        kDataKey,
        kSkipFeeKey,
    };
    return [NSDictionary dictionaryWithObjects:objects
                                       forKeys:keys
                                         count:sizeof(keys) / sizeof(keys[0])];
}

@end
