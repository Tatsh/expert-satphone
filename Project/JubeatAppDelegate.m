#import "JubeatAppDelegate.h"

#include <stdlib.h>

#include <sys/sysctl.h>

// The sysctl name the binary passes to sysctlbyname, embedded at 0x27dc6d.
static const char *const kHardwareMachineSysctlName = "hw.machine";

// The version string the binary embeds at 0x27dc66. It is a C string literal compiled into the
// text, not a value read from the bundle.
static const char *const kApplicationVersionString = "3.9.11";

// The device-type values the four idiom predicates at 0x82c0-0x8328 compare against. The binary
// names none of them, so each is named here after what its predicate proves rather than after a
// device the naming is not evidence for.
enum {
    kFirstPhoneRetinaDeviceType = 1,
    kFirst4inchDeviceType = 2,
    kPhoneRetinaDeviceTypeCount = 5,
    k4inchDeviceTypeCount = 4,
    kDeviceTypePadRetina = 7,
};

@implementation JubeatAppDelegate

#pragma mark - Identification

+ (JubeatAppDelegate *)appDelegate {
    // The binary forwards -delegate with no class check of its own.
    return (JubeatAppDelegate *)UIApplication.sharedApplication.delegate;
}

+ (NSString *)appVersion {
    return [[NSString alloc] initWithCString:kApplicationVersionString
                                    encoding:NSUTF8StringEncoding];
}

#pragma mark - Standard directories

+ (NSString *)appLibraryDirectory {
    return NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).lastObject;
}

+ (NSString *)appDocumentsDirectory {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)
        .lastObject;
}

+ (NSString *)appCachesDirectory {
    return NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
}

+ (NSString *)deviceName {
    size_t length = 0;
    sysctlbyname(kHardwareMachineSysctlName, NULL, &length, NULL, 0);
    if (length == 0) {
        return UIDevice.currentDevice.model;
    }
    char *machine = malloc(length);
    sysctlbyname(kHardwareMachineSysctlName, machine, &length, NULL, 0);
    NSString *name = [[NSString alloc] initWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    return name;
}

#pragma mark - Device idiom predicates

// Each predicate below is a set-membership test on _deviceType, written the way the binary computes
// it rather than as an equivalent range check, so the compiled form stays recognisable.

- (BOOL)isPad {
    // orr x8, x8, #1 then cmp #7: true for device types 6 and 7.
    return (_deviceType | 1) == kDeviceTypePadRetina;
}

- (BOOL)isPhoneRetina {
    // sub #1 then unsigned cmp #5: true for device types 1 to 5.
    return (NSUInteger)(_deviceType - kFirstPhoneRetinaDeviceType) < kPhoneRetinaDeviceTypeCount;
}

- (BOOL)is4inchAspect {
    // sub #2 then unsigned cmp #4: true for device types 2 to 5.
    return (NSUInteger)(_deviceType - kFirst4inchDeviceType) < k4inchDeviceTypeCount;
}

- (BOOL)isPadRetina {
    return _deviceType == kDeviceTypePadRetina;
}

#pragma mark - Download selection mutators

- (void)resetDownLoadIndex {
    _jcfDownloadID = nil;
}

- (void)resetDownloadGenreID {
    _storeGenreID = nil;
}

- (void)setDownloadGenreID:(id)genreID {
    _storeGenreID = genreID;
}

- (void)resetDownloadPackID {
    _storePackID = nil;
}

- (void)setDownloadPackID:(id)packID {
    _storePackID = packID;
}

- (void)resetCampaignID {
    _storeCampaignID = nil;
}

- (void)setCampaignID:(id)campaignID {
    _storeCampaignID = campaignID;
}

#pragma mark - Notification page mutators

- (void)setNotificationPageURL:(NSString *)pageURL updateTime:(id)updateTime {
    // A nil page URL clears the stored URL rather than building one from nil: the binary branches
    // on the argument at 0x8d04 and only reaches +[NSURL URLWithString:] on the non-nil arm.
    if (pageURL != nil) {
        _notificationURL = [NSURL URLWithString:pageURL];
    } else {
        _notificationURL = nil;
    }
    _notificationTime = updateTime;
}

#pragma mark - Option flag mutators

- (void)setRandomFlag:(BOOL)flag {
    _isRandom = flag;
}

- (void)setExtendFlag:(BOOL)flag {
    _isExtend = flag;
}

- (void)setHoldFlag:(BOOL)flag {
    _isHold = flag;
}

- (void)setSearchString:(id)searchString {
    _searchString = searchString;
}

- (void)markerDownloadComplete {
    // Latched on only. No compiled setter ever clears this flag.
    _isMarkerLegal = YES;
}

@end
