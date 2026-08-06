#import "JubeatAppDelegate.h"

#include <stdlib.h>

#include <sys/sysctl.h>

// The sysctl name the binary passes to sysctlbyname, embedded at 0x27dc6d.
static const char *const kHardwareMachineSysctlName = "hw.machine";

@implementation JubeatAppDelegate

#pragma mark - Identification

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
