#import "ChallengeMissionReward.h"

// The wire keys, from the CFStrings at 0x2d9c40, 0x2dcc20, 0x2d5060, 0x2d7640, 0x2d4880, 0x2d4860,
// 0x2d7b40, 0x2e1920, and 0x2d41c0. -getDictionary emits them in the order below.
static NSString *const kRewardKey = @"reward";
static NSString *const kRewardIDKey = @"reward_id";
static NSString *const kItemTypeKey = @"item_type";
static NSString *const kItemIDKey = @"item_id";
static NSString *const kNameKey = @"name";
static NSString *const kDescriptionKey = @"description";
static NSString *const kImageURLKey = @"image_url";
static NSString *const kViewEndKey = @"view_end";
static NSString *const kVersionKey = @"version";

// What itemID falls back to when the server omits it, from the empty CFString at 0x2d42e0. It is
// the only field given a fallback; the other six objects are stored as they arrive, nil included.
static NSString *const kMissingItemID = @"";

@implementation ChallengeMissionReward

/** @ghidraAddress 0x1ee324 */
- (BOOL)initWithDictionary:(NSDictionary *)dictionary {
    // Tested first, then fetched a second time to be used. Nothing is written on the failing path.
    if ([dictionary objectForKey:kRewardKey] == nil) {
        return NO;
    }
    NSDictionary *reward = [dictionary objectForKey:kRewardKey];

    _rewardID = [[reward objectForKey:kRewardIDKey] intValue];
    _itemType = [[reward objectForKey:kItemTypeKey] intValue];

    _itemID = [reward objectForKey:kItemIDKey];
    if (_itemID == nil) {
        _itemID = kMissingItemID;
    }

    _rewardName = [reward objectForKey:kNameKey];
    _rewardDescription = [reward objectForKey:kDescriptionKey];
    _rewardImageURL = [reward objectForKey:kImageURLKey];
    _endTime = [reward objectForKey:kViewEndKey];
    _version = [reward objectForKey:kVersionKey];
    return YES;
}

/** @ghidraAddress 0x1ee5a8 */
- (NSDictionary *)getDictionary {
    // Read from the stack setup before the call rather than from the decompile, which renders a
    // count-based constructor with only its first argument. Eight objects against eight keys, and
    // the count immediate is 8, so the list is exact.
    //
    // The two integers are boxed with +numberWithInt:, matching their `i` encodings.
    id objects[] = {
        @(self.rewardID),
        @(self.itemType),
        self.itemID,
        self.rewardName,
        self.rewardDescription,
        self.rewardImageURL,
        self.endTime,
        self.version,
    };
    id keys[] = {
        kRewardIDKey,
        kItemTypeKey,
        kItemIDKey,
        kNameKey,
        kDescriptionKey,
        kImageURLKey,
        kViewEndKey,
        kVersionKey,
    };
    // Flat, with no enclosing "reward" entry, so this is not the inverse of -initWithDictionary:.
    return [NSDictionary dictionaryWithObjects:objects
                                       forKeys:keys
                                         count:sizeof(keys) / sizeof(keys[0])];
}

@end
