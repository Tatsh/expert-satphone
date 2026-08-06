#import "LatelyJcfListManager.h"

// How many owners the list holds before it starts evicting.
enum { kMaxOwners = 20 };

// Each entry is a two-element array rather than a dictionary or a model object.
enum {
    kEntryOwnerIndex = 0,
    kEntryDateIndex = 1,
};

@implementation LatelyJcfListManager {
    NSMutableArray *list;
}

/** @ghidraAddress 0x1e2a08 */
+ (instancetype)sharedManager {
    static LatelyJcfListManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x1e2a4c */
      instance = [[LatelyJcfListManager alloc] init];
    });
    return instance;
}

/** @ghidraAddress 0x1e2a90 */
- (instancetype)init {
    self = [super init];
    if (self) {
        list = [[NSMutableArray alloc] init];
    }
    return self;
}

/** @ghidraAddress 0x1e2b14 */
- (void)addJcfOwner:(NSString *)owner {
    NSMutableArray *entry = [[NSMutableArray alloc] init];
    [entry addObject:owner];
    [entry addObject:[NSDate date]];

    // Below the cap the owner is appended with no duplicate check at all.
    if (list.count < kMaxOwners) {
        [list addObject:entry];
        return;
    }

    // The scan starts from the first entry's date but only visits indices 1 upwards, so entry zero
    // is never tested for being a duplicate — only for being the initial candidate.
    NSDate *chosenDate = [[list objectAtIndex:0] objectAtIndex:kEntryDateIndex];
    NSInteger chosenIndex = 0;
    for (NSInteger i = 1; i < kMaxOwners; ++i) {
        NSMutableArray *candidate = [list objectAtIndex:i];
        if ([owner isEqualToString:[candidate objectAtIndex:kEntryOwnerIndex]]) {
            return;
        }
        NSDate *candidateDate = [candidate objectAtIndex:kEntryDateIndex];
        // NSOrderedAscending means the entry held so far is *earlier*, so adopting the candidate
        // here walks towards the latest date, not the earliest. The slot overwritten below is
        // therefore the newest entry rather than the oldest.
        if ([chosenDate compare:candidateDate] == NSOrderedAscending) {
            chosenDate = candidateDate;
            chosenIndex = i;
        }
    }
    [list replaceObjectAtIndex:chosenIndex withObject:entry];
}

/** @ghidraAddress 0x1e2d7c */
- (void)removeJcfOwner:(NSString *)owner {
    // Walked backwards so a removal does not disturb the indices still to be visited.
    NSInteger index = (NSInteger)list.count;
    while (--index >= 0) {
        NSMutableArray *entry = [list objectAtIndex:index];
        if ([owner isEqualToString:[entry objectAtIndex:kEntryOwnerIndex]]) {
            [list removeObjectAtIndex:index];
        }
        // Re-tested at the bottom of each pass, which the index alone would already have handled.
        if (list.count == 0) {
            break;
        }
    }
}

/** @ghidraAddress 0x1e2e94 */
- (NSMutableArray *)getJcfOwnerList {
    // The mutable list itself, not a copy: a caller can edit it behind the manager's back.
    return list;
}

@end
