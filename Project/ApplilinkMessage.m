#import "ApplilinkMessage.h"

#import "ApplilinkBundle.h"

// The strings table looked up inside the reward bundle, from the CFString at 0x2d9aa0.
static NSString *const kApplilinkMessageStringsTable = @"Message";

// The six recognised message keys, from the CFStrings at 0x2e58e0, 0x2e5900, 0x2e5940, 0x2e2d40,
// 0x2e2d60, and 0x2e59a0, tested in this order.
static NSString *const kAppListTitleKey = @"RewardNetworkAppListTitle";
static NSString *const kAppListCloseButtonKey = @"RewardNetworkAppListCloseButton";
static NSString *const kAppListBackButtonKey = @"RewardNetworkAppListBackButton";
static NSString *const kAppListErrorMessage1Key = @"RewardNetworkAppListErrorMessage1";
static NSString *const kAppListErrorMessage2Key = @"RewardNetworkAppListErrorMessage2";
static NSString *const kAppListErrorButtonKey = @"RewardNetworkAppListErrorButton";

// Their built-in English fallbacks, from the CFStrings at 0x2e5920, 0x2d9740, 0x2d9100, 0x2e5960,
// 0x2e5980, and 0x2d42e0. The two error messages are halves of one sentence, trailing space and
// all, and the close and error buttons share a single string.
static NSString *const kAppListTitleDefault = @"App List";
static NSString *const kAppListCloseButtonDefault = @"Close";
static NSString *const kAppListBackButtonDefault = @"Back";
static NSString *const kAppListErrorMessage1Default = @"An error occurred ";
static NSString *const kAppListErrorMessage2Default = @"during video playback.";
static NSString *const kEmptyDefault = @"";

@implementation ApplilinkMessage

/** @ghidraAddress 0x24fe94 */
+ (NSString *)localizedMessage:(NSString *)localizedMessage {
    NSBundle *bundle = ApplilinkBundle.rewardBundle;

    NSString *defaultValue = kEmptyDefault;
    if ([localizedMessage isEqualToString:kAppListTitleKey]) {
        defaultValue = kAppListTitleDefault;
    } else if ([localizedMessage isEqualToString:kAppListCloseButtonKey]) {
        defaultValue = kAppListCloseButtonDefault;
    } else if ([localizedMessage isEqualToString:kAppListBackButtonKey]) {
        defaultValue = kAppListBackButtonDefault;
    } else if ([localizedMessage isEqualToString:kAppListErrorMessage1Key]) {
        defaultValue = kAppListErrorMessage1Default;
    } else if ([localizedMessage isEqualToString:kAppListErrorMessage2Key]) {
        defaultValue = kAppListErrorMessage2Default;
    } else if ([localizedMessage isEqualToString:kAppListErrorButtonKey]) {
        // The same string the close button uses; the two share one CFString at 0x2d9740.
        defaultValue = kAppListCloseButtonDefault;
    }

    // Guarded, unlike the other shipped build of this class, which sends to the bundle
    // unconditionally and relies on a nil receiver returning nil. Here a missing bundle yields the
    // built-in default.
    if (bundle != nil) {
        return [bundle localizedStringForKey:localizedMessage
                                       value:defaultValue
                                       table:kApplilinkMessageStringsTable];
    }
    return defaultValue;
}

@end
