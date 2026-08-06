#import "CampaignItemInfo.h"

#import <UIKit/UIKit.h>

#import "MarkerManager.h"
#import "PurchaseManager.h"
#import "StoreMusicListManager.h"
#import "StoreUtil.h"

// The kinds of item the campaign can grant. Anything from two upwards is never unlockable.
enum {
    kCampaignItemTypeMusic = 0,
    kCampaignItemTypeMarker = 1,
    kCampaignItemTypeUnlockableCount = 2,
};

// How an item is earned, from the private unlockType ivar.
enum {
    kUnlockTypeAlways = 0,
    kUnlockTypeAppsInstalled = 1,
    kUnlockTypePacksOwned = 2,
    kUnlockTypeAppsInstalledAlt = 3,
    kUnlockTypeServer = 4,
};

// What the UI should offer. Only set here; never read.
enum {
    kButtonTypeGet = 0,
    kButtonTypeOwned = 1,
    kButtonTypeBuy = 2,
    kButtonTypeUnavailable = 3,
    kButtonTypeServerLocked = 4,
};

// A term in the app-installed rules is an application's URL scheme, tested by asking whether the
// system can open it at all.
static NSString *const kSchemeProbeFormat = @"%@://";

// A marker's data name.
static NSString *const kMarkerDataNameFormat = @"mk%04d";

@implementation CampaignItemInfo {
    // Neither of these carries an underscore in the metadata, so neither backs a property.
    NSArray *termsTable;
    int unlockType;
}

/** @ghidraAddress 0xc16c */
- (BOOL)termCheck {
    _bUnlock = NO;
    _alreadyDownload = [self hasItem:self.itemType itemID:self.itemID];

    if (_itemType >= kCampaignItemTypeUnlockableCount) {
        // Nothing above a marker can be unlocked at all, whatever the rule says.
        _buttonType = kButtonTypeUnavailable;
        return _bUnlock;
    }

    switch (unlockType) {
    case kUnlockTypeAlways:
        _bUnlock = YES;
        break;

    case kUnlockTypeAppsInstalled:
    case kUnlockTypeAppsInstalledAlt: {
        // Every named application must be installed. The test is whether its URL scheme can be
        // opened, and the count of successes has to reach the count of terms — so an empty terms
        // table leaves the item locked rather than trivially unlocking it.
        int termCount = (int)termsTable.count;
        if (termCount > 0) {
            int satisfied = 0;
            for (int i = 0; i < termCount; ++i) {
                NSString *scheme =
                    [NSString stringWithFormat:kSchemeProbeFormat, [termsTable objectAtIndex:i]];
                satisfied +=
                    [UIApplication.sharedApplication canOpenURL:[NSURL URLWithString:scheme]];
            }
            if (satisfied == termCount) {
                _bUnlock = YES;
            }
        }
        break;
    }

    case kUnlockTypePacksOwned: {
        int termCount = (int)termsTable.count;
        if (termCount > 0) {
            // Both lists are fetched once, outside the loop, from two separate sharedManager
            // calls.
            NSArray *purchased = PurchaseManager.sharedManager.purchasedPackIDs;
            NSArray *pending = PurchaseManager.sharedManager.pendingPackIDs;
            int satisfied = 0;
            for (int i = 0; i < termCount; ++i) {
                int packID = [[termsTable objectAtIndex:i] intValue];
                // A pending purchase counts, but only when the pack is not already bought.
                if ([self checkExistPackList:purchased packID:packID]) {
                    satisfied += 1;
                } else {
                    satisfied += [self checkExistPackList:pending packID:packID];
                }
            }
            if (satisfied == termCount) {
                _bUnlock = YES;
            }
        }
        break;
    }

    case kUnlockTypeServer:
        _bUnlock = _bServerUnlock;
        break;
    }

    if (_bUnlock) {
        _buttonType = kButtonTypeGet;
        _hideType = 0;
        // Read back through the accessor rather than from the ivar it just wrote.
        if (self.alreadyDownload) {
            _buttonType = kButtonTypeOwned;
        }
    } else if (unlockType == kUnlockTypeServer) {
        _buttonType = kButtonTypeServerLocked;
    } else if (unlockType == kUnlockTypePacksOwned || unlockType == kUnlockTypeAppsInstalledAlt) {
        _buttonType = kButtonTypeBuy;
    } else {
        _buttonType = kButtonTypeUnavailable;
    }

    return _bUnlock;
}

/** @ghidraAddress 0xc5bc */
- (BOOL)checkExistPackList:(NSArray *)packList packID:(int)packID {
    if (!packList) {
        return NO;
    }
    // Tested separately from the nil check, and before the enumeration rather than by it.
    if (packList.count == 0) {
        return NO;
    }
    for (id entry in packList) {
        if ([entry intValue] == packID) {
            return YES;
        }
    }
    return NO;
}

/** @ghidraAddress 0xc728 */
- (void)replaceServerUnlock:(BOOL)serverUnlock {
    // Straight to the ivar; the property is read-only and has no setter.
    _bServerUnlock = serverUnlock;
}

/** @ghidraAddress 0xc738 */
- (BOOL)checkNewUnlock {
    return self.bUnlock && !self.alreadyDownload;
}

/** @ghidraAddress 0xc778 */
- (BOOL)hasItem:(int)itemType itemID:(int)itemID {
    if (itemType == kCampaignItemTypeMarker) {
        return [MarkerManager
            checkMarkerData:[NSString stringWithFormat:kMarkerDataNameFormat, itemID]];
    }
    if (itemType != kCampaignItemTypeMusic) {
        return NO;
    }

    // A tune has to be both listed and actually on disc; being in the catalogue is not enough.
    if (![StoreMusicListManager.sharedManager hasMusic:itemID]) {
        return NO;
    }
    return [NSFileManager.defaultManager fileExistsAtPath:[StoreUtil filePathForMusicID:itemID]];
}

@end
