#import "ChallengeStatus.h"

#import <UIKit/UIKit.h>

// The notification's text and sound, from the CFStrings at 0x2e0e20, 0x2e0e40, 0x2e0e80, and
// 0x2dc680. The two Japanese strings are stored UTF-16 in the binary and differ only by the
// trailing full-width exclamation mark: the alert body has it, the "aps" alert entry does not.
static NSString *const kCoinRefilledAlertText = @"プレーコインが回復しました";
static NSString *const kCoinRefilledAlertBody = @"プレーコインが回復しました！";
static NSString *const kCoinNotificationSound = @"push.caf";
static NSString *const kCoinNotificationAlertAction = @"Open";

// The URL the notification carries, from the CFString at 0x2e0e60. Note it is a different scheme
// from the "jubeatplus" one -[JubeatAppDelegate application:handleOpenURL:] matches.
static NSString *const kChallengeNotificationURL = @"jbtchallenge://";

// The payload keys, the same set -[JubeatAppDelegate apsDictionary:] reads back out.
static NSString *const kApsPayloadKey = @"aps";
static NSString *const kApsAlertKey = @"alert";
static NSString *const kNotificationSoundKey = @"sound";
static NSString *const kNotificationURLKey = @"url";
static NSString *const kNotificationExpireKey = @"expire";

@implementation ChallengeStatus

- (void)createCoinNotification {
    if (!self.bInitialized) {
        return;
    }
    // Yes, the result is discarded. The call is kept for its side effect of refreshing the counts
    // that the comparison below reads.
    (void)[self restCoinNum];
    if (self.coinLim <= self.coinNum) {
        return;
    }

    // Time for every coin still missing after the one currently regenerating.
    int missingAfterCurrent = self.coinLim - 1 - self.coinNum;
    int secondsForRemaining = (int)(self.coinRestTime * missingAfterCurrent);
    int secondsForCurrent = (int)[self getTimeLeft:self.coinRestDate];
    int fireInSeconds = secondsForCurrent + secondsForRemaining;

    [UIApplication.sharedApplication cancelAllLocalNotifications];

    // The expiry stamp is the current time, not the fire time.
    long now = (long)NSDate.date.timeIntervalSince1970;

    NSDictionary *aps = @{
        kApsAlertKey : kCoinRefilledAlertText,
        kNotificationSoundKey : kCoinNotificationSound,
    };
    NSDictionary *userInfo = @{
        kApsPayloadKey : aps,
        kNotificationURLKey : kChallengeNotificationURL,
        kNotificationExpireKey : @(now),
    };

    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:(double)fireInSeconds];
    notification.timeZone = NSTimeZone.systemTimeZone;
    notification.alertBody = kCoinRefilledAlertBody;
    notification.userInfo = userInfo;
    notification.alertAction = kCoinNotificationAlertAction;
    [UIApplication.sharedApplication scheduleLocalNotification:notification];
}

@end
