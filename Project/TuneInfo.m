#import "TuneInfo.h"

#include <stdio.h>

#import "StoreMusicListManager.h"

// The catalogue dictionary's keys.
static NSString *const kTuneIDKey = @"ID";
static NSString *const kLvBasKey = @"LvBas";
static NSString *const kLvAdvKey = @"LvAdv";
static NSString *const kLvExtKey = @"LvExt";
static NSString *const kNameKey = @"Name";
static NSString *const kNameYomiKey = @"NameYomi";
static NSString *const kArtistKey = @"Artist";
static NSString *const kITunesURLKey = @"iTunesURL";

// The extend record's keys, all optional.
static NSString *const kExtendFlagKey = @"extendFlag";
static NSString *const kHoldFlagKey = @"holdFlag";
static NSString *const kExtendIDKey = @"extID";

// -infoDict builds at exactly the seven entries it can hold.
static const int kInfoDictCapacity = 8;

// -isLicensedTune renders the identifier as nine zero-padded decimals and reads the first one.
static const char kTuneIDFormat[] = "%09u";
enum {
    kTuneIDDigits = 10,
    kLicensedFirstDigit = '2',
    kLicensedDigitSpan = 3,
};

@implementation TuneInfo

/** @ghidraAddress 0x770bc */
- (instancetype)initWithfilePath:(NSString *)filePath dictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        self.filePath = filePath;

        self.tuneID = [[dictionary objectForKey:kTuneIDKey] intValue];
        // Each level is read as an int and then truncated to the char the property holds.
        self.lvBas = (char)[[dictionary objectForKey:kLvBasKey] intValue];
        self.lvAdv = (char)[[dictionary objectForKey:kLvAdvKey] intValue];
        self.lvExt = (char)[[dictionary objectForKey:kLvExtKey] intValue];
        self.name = [dictionary objectForKey:kNameKey];
        self.nameYomi = [dictionary objectForKey:kNameYomiKey];
        self.artist = [dictionary objectForKey:kArtistKey];

        // The store's link wins; the catalogue's is only a fallback.
        NSString *link = [StoreMusicListManager.sharedManager linkURLForID:self.tuneID];
        if (!link) {
            link = [dictionary objectForKey:kITunesURLKey];
        }

        NSDictionary *extendInfo =
            [StoreMusicListManager.sharedManager extendInfoForID:self.tuneID];
        // Cleared first, so a tune with no extend record ends up with three zeros rather than
        // whatever the allocation left.
        self.extendID = 0;
        self.extendFlag = 0;
        self.holdFlag = 0;
        if (extendInfo) {
            // Each key is fetched twice, once to test for its presence and once to read it.
            if ([extendInfo objectForKey:kExtendFlagKey]) {
                self.extendFlag = [[extendInfo objectForKey:kExtendFlagKey] unsignedIntValue];
            }
            if ([extendInfo objectForKey:kHoldFlagKey]) {
                self.holdFlag = [[extendInfo objectForKey:kHoldFlagKey] unsignedIntValue];
            }
            if ([extendInfo objectForKey:kExtendIDKey]) {
                self.extendID = [[extendInfo objectForKey:kExtendIDKey] unsignedIntValue];
            }
        }

        // Set last, after the extend block rather than where it is chosen.
        self.iTunesURL = link;
    }
    return self;
}

/** @ghidraAddress 0x775d0 */
- (NSDictionary *)infoDict {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:kInfoDictCapacity];

    [dict setObject:@(self.tuneID) forKey:kTuneIDKey];
    [dict setObject:@(self.lvBas) forKey:kLvBasKey];
    [dict setObject:@(self.lvAdv) forKey:kLvAdvKey];
    [dict setObject:@(self.lvExt) forKey:kLvExtKey];
    // No nil guard on the name, unlike the two below it.
    [dict setObject:self.name forKey:kNameKey];
    if (self.nameYomi) {
        [dict setObject:self.nameYomi forKey:kNameYomiKey];
    }
    if (self.artist) {
        [dict setObject:self.artist forKey:kArtistKey];
    }

    return [NSDictionary dictionaryWithDictionary:dict];
}

/** @ghidraAddress 0x778a0 */
- (BOOL)isLicensedTune {
    // Pre-filled with '0's, which snprintf then overwrites in full — %09u always writes exactly
    // nine digits and a terminator into these ten bytes.
    char digits[kTuneIDDigits] = "000000000";
    snprintf(digits, sizeof(digits), kTuneIDFormat, self.tuneID);

    // True for a leading digit of '2', '3' or '4', which is an identifier from 200000000 to
    // 499999999.
    return (unsigned char)(digits[0] - kLicensedFirstDigit) < kLicensedDigitSpan;
}

/** @ghidraAddress 0x77930 */
- (NSInteger)compareLicensedFirst:(TuneInfo *)other {
    BOOL selfLicensed = self.isLicensedTune;
    BOOL otherLicensed = other.isLicensedTune;

    if (selfLicensed) {
        if (!otherLicensed) {
            return NSOrderedAscending;
        }
    } else if (otherLicensed) {
        return NSOrderedDescending;
    }
    return [self compareYomi:other];
}

/** @ghidraAddress 0x779c4 */
- (NSInteger)compareYomi:(TuneInfo *)other {
    // Each reading is fetched twice, once to test and once to compare.
    if (self.nameYomi) {
        if (!other.nameYomi) {
            return NSOrderedAscending;
        }
        return [self.nameYomi localizedCaseInsensitiveCompare:other.nameYomi];
    }
    if (other.nameYomi) {
        return NSOrderedDescending;
    }

    // Neither has a reading. The fallback runs the other way round to the comparison above: the
    // higher identifier sorts first.
    if (self.tuneID > other.tuneID) {
        return NSOrderedAscending;
    }
    return (self.tuneID < other.tuneID) ? NSOrderedDescending : NSOrderedSame;
}

@end
