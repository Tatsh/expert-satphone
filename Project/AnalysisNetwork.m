#import "AnalysisNetwork.h"

#import "ApplilinkConsts.h"
#import "ApplilinkNetworkError.h"

// The code answered when the SDK cannot be used. 1025 in the table
// +[ApplilinkNetworkError localizedApplilinkErrorWithCode:userInfo:] builds, whose message names
// iOS 6.1 as the floor.
static const NSInteger kSdkVersionNotSupportedError = 1025;

@implementation AnalysisNetwork

/** @ghidraAddress 0x2410a4 */
+ (void)postAnalysisDataWithResultId:(NSString *)resultId
                            callback:(ApplilinkAnalysisCallback)callback {
    if (ApplilinkConsts.canUseApplilinkSdk) {
        [AnalysisNetworkCore postAnalysisDataWithResultId:resultId callback:callback];
        return;
    }
    // Invoked directly rather than dispatched, so the caller's callback runs synchronously on this
    // thread when the SDK is unavailable and asynchronously when it is not.
    callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kSdkVersionNotSupportedError]);
}

/** @ghidraAddress 0x24116c */
+ (void)openExternalWebBrowser:(NSString *)url env:(NSString *)env {
    // The callback is an empty global block — its invoke at 0x2411c0 is a bare `ret` — so any
    // error the core reports here is discarded.
    [AnalysisNetworkCore openExternalWebBrowserCore:url
                                                env:env
                                           callback:^(NSError *error){
                                               /** @ghidraAddress 0x2411c0 */
                                           }];
}

/** @ghidraAddress 0x2411c4 */
+ (void)openWebBrowserWithAppliId:(NSString *)appliId
                              env:(NSString *)env
                         callback:(ApplilinkAnalysisCallback)callback {
    // Yes, no canUseApplilinkSdk check. Only the first method in this class guards.
    [AnalysisNetworkCore openWebBrowserWithAppliIdCore:appliId env:env callback:callback];
}

@end
