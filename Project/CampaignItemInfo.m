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

// The campaign entry's own keys.
static NSString *const kNestedKey = @"v2";
static NSString *const kCampaignIDKey = @"campaignId";
static NSString *const kItemIDKey = @"itemId";
static NSString *const kItemTypeKey = @"itemType";
static NSString *const kForeignURLKey = @"foreignUrl";
static NSString *const kUnlockedKey = @"unlocked";
static NSString *const kTermsTableKey = @"termsTable";
static NSString *const kUnlockTypeKey = @"unlockType";
static NSString *const kHideTypeKey = @"hideType";

// Everything the player actually sees comes out of the nested "v2" dictionary instead.
static NSString *const kBannerURLKey = @"bannerUrl";
static NSString *const kIconURLKey = @"iconUrl";
static NSString *const kCopyrightKey = @"copyright";
static NSString *const kTermsDescriptionKey = @"termsDescription";
static NSString *const kDescriptionKey = @"description";
static NSString *const kNameKey = @"name";
static NSString *const kThumbnailURLKey = @"thumbnailUrl";

@implementation CampaignItemInfo {
    // Neither of these carries an underscore in the metadata, so neither backs a property.
    NSArray *termsTable;
    int unlockType;
}

/** @ghidraAddress 0xbca0 */
- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        // Two dictionaries: the numbers and the unlock rule come from the entry itself, everything
        // the player reads from a nested one.
        NSDictionary *presentation = [dictionary objectForKey:kNestedKey];

        _campaignID = [[dictionary objectForKey:kCampaignIDKey] intValue];
        _itemID = [[dictionary objectForKey:kItemIDKey] intValue];
        _itemType = [[dictionary objectForKey:kItemTypeKey] intValue];

        // Taken with no validation at all, unlike the three URLs below it.
        _bannerURL = [presentation objectForKey:kBannerURLKey];

        NSString *foreignURL = [dictionary objectForKey:kForeignURLKey];
        // The only one of the four URL fields that is length-checked as well as validated.
        if ([StoreUtil isValidURL:foreignURL] && foreignURL.length != 0) {
            _linkURL = [NSURL URLWithString:foreignURL];
        }

        _bServerUnlock = [[dictionary objectForKey:kUnlockedKey] boolValue];
        termsTable = [dictionary objectForKey:kTermsTableKey];
        unlockType = [[dictionary objectForKey:kUnlockTypeKey] intValue];
        // Read here and then cleared again by -termCheck below, but only when the item comes out
        // unlocked — a locked item keeps whatever the entry said.
        _hideType = [[dictionary objectForKey:kHideTypeKey] intValue];

        NSString *iconURL = [presentation objectForKey:kIconURLKey];
        if ([StoreUtil isValidURL:iconURL]) {
            // Kept as text, where the other two validated URLs become NSURLs.
            _itemImageURL = iconURL;
        }

        _lisenceText = [presentation objectForKey:kCopyrightKey];
        _unlockDescription = [presentation objectForKey:kTermsDescriptionKey];
        _itemDescription = [presentation objectForKey:kDescriptionKey];
        _name = [presentation objectForKey:kNameKey];

        NSString *thumbnailURL = [presentation objectForKey:kThumbnailURLKey];
        if ([StoreUtil isValidURL:thumbnailURL]) {
            _sampleURL = [NSURL URLWithString:thumbnailURL];
        }

        // Evaluated once here, so every derived property is set before the caller sees the item.
        [self termCheck];
    }
    return self;
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
