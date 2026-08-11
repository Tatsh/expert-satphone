#import "ApplilinkNetworkError.h"

#import "ApplilinkBundle.h"

NSErrorDomain const ApplilinkErrorDomain = @"ApplilinkErrorDomain"; // @ghidraAddress 0x2e4a80

// The strings table looked up inside the reward bundle.
static NSString *const kApplilinkErrorStringsTable = @"Error";

// The code every unmapped code falls back to.
static const int kApplilinkErrorCodeUnexpected = 1000;

// One row of the message table: the applilink error code, the reward bundle's localisation key, and
// the built-in English fallback, used both as the localisation default and when the bundle is
// absent.
typedef struct {
    NSInteger code;
    __unsafe_unretained NSString *localizationKey;
    __unsafe_unretained NSString *fallbackMessage;
} ApplilinkErrorMessageEntry;

// The binary writes all 43 of these out in full rather than looping, which is why
// +localizedApplilinkErrorWithCode:userInfo: is 2497 instructions. The table and loop below are the
// de-inlined form; the per-entry behaviour is unchanged, including the two separate
// +[ApplilinkBundle rewardBundle] sends each entry makes.
//
// Codes 1040 to 1042 do not exist in the sibling ../rbplus-src reconstruction, which stops at 1039.
// The localisation key for 1040 really is spelled "Caache".
static const ApplilinkErrorMessageEntry kApplilinkErrorMessages[] = {
    {1000, @"ApplilinkUnexpectedError", @"Unexpected error."},
    {1001, @"ApplilinkParameterError", @"Parameter error."},
    {1002, @"ApplilinkAuthLoginError", @"Failed to log in."},
    {1003, @"ApplilinkErrorResponseEmpty", @"Response empty."},
    {1004, @"ApplilinkErrorLoginTokenGetFailed", @"Failed to get login token."},
    {1005, @"ApplilinkErrorLoginTokenRequestError", @"Login token request unexpected error."},
    {1006, @"ApplilinkErrorContentsServer", @"Contents server error occurred."},
    {1007,
     @"ApplilinkInvalidContentsServerStatus",
     @"Invalid response status from contents server."},
    {1008, @"ApplilinkErrorApplicationInstall", @"Failed to notify application install."},
    {1009, @"ApplilinkErrorApplicationNotFound", @"Application not found."},
    {1010, @"ApplilinkErrorNeedToInitialize", @"Need to initilize."},
    {1011, @"ApplilinkPasteBoardErrorStorageFull", @"Storage is full."},
    {1012, @"ApplilinkPasteBoardErrorEmptyValue", @"Not found key."},
    {1013, @"ApplilinkPasteBoardErrorInvalidField", @"Failed to get paste board index pointer."},
    {1014, @"ApplilinkPasteBoardErrorUnarchiveFailed", @"Failed to un-archive paste board data"},
    {1015, @"ApplilinkPasteBoardErrorWriteFailed", @"Failed to write paste board data."},
    {1016, @"ApplilinkPasteBoardErrorValidateError", @"Validate error."},
    {1017, @"ApplilinkPasteBoardErrorInvalidKey", @"Invalid paste board key."},
    {1018,
     @"ApplilinkPasteBoardErrorInvalidDataType",
     @"Failed to get directed paste board data type."},
    {1019, @"ApplilinkPasteBoardErrorInvalidFormat", @"Invalid data format."},
    {1020, @"ApplilinkPasteBoardErrorInvalidValue", @"Invalid value data."},
    {1021, @"ApplilinkPasteBoardErrorInvalidEntryDate", @"Invalid entry_date data."},
    {1022, @"ApplilinkPasteBoardErrorInvalidLastAccess", @"Invalid last_access data."},
    {1023, @"ApplilinkPasteBoardErrorInvalidVersion", @"Invalid version data."},
    {1024, @"ApplilinkPasteBoardErrorOldVersion", @"Old system version."},
    {1025,
     @"ApplilinkErrorSdkVersionNotSupported",
     @"Reward SDK is supported in iOS 6.1 and later."},
    {1026, @"ApplilinkErrorUdidNotFound", @"Udid not found. Please restart application."},
    {1027, @"ApplilinkErrorHTTPRequestTimeout", @"HTTP Request timeout."},
    {1028, @"ApplilinkErrorCannotGetAdvertisingId", @"Cannot get Advertising Identifier."},
    {1029, @"ApplilinkErrorAppliIdNotFound", @"AppId Not Found."},
    {1030, @"ApplilinkErrorUserIdNotFound", @"UserId Not Found."},
    {1031, @"ApplilinkErrorResponseError", @"Response Error."},
    {1032, @"ApplilinkErrorInitializingError", @"Initializing Error."},
    {1033, @"ApplilinkErrorResumeExecutingError", @"Resume executing Error."},
    {1034, @"ApplilinkErrorNoAdContent", @"No Ad Content."},
    {1035, @"ApplilinkErrorCannotOpenAdvertisement", @"can not open advertisement."},
    {1036, @"ApplilinkErrorOpenedCancel", @"Opened Cancel."},
    {1037, @"ApplilinkErrorBannerIsOff", @"Banner is off."},
    {1038, @"ApplilinkSessionError", @"Session error."},
    {1039, @"ApplilinkErrorCannotOpenMultiple", @"can not open multiple."},
    {1040, @"ApplilinkErrorCaacheData", @"cache data error."},
    {1041, @"ApplilinkErrorAdFrequencyZero", @"Ad Frequency 0%."},
    {1042, @"ApplilinkErrorUnknownAdType", @"Unknown Ad Type."},
};

// Built once on the first call and reused thereafter. The binary's global is at 0x354298.
static NSMutableDictionary *gApplilinkErrorMessages = nil;

@implementation ApplilinkNetworkError

/** @ghidraAddress 0x23f56c */
+ (NSError *)localizedApplilinkErrorWithCode:(NSInteger)code {
    return [self localizedApplilinkErrorWithCode:code userInfo:nil];
}

/** @ghidraAddress 0x23ce68 */
+ (NSError *)localizedApplilinkErrorWithCode:(NSInteger)code userInfo:(NSDictionary *)userInfo {
    if (gApplilinkErrorMessages == nil) {
        gApplilinkErrorMessages = [[NSMutableDictionary alloc] init];
        for (size_t i = 0; i < sizeof(kApplilinkErrorMessages) / sizeof(kApplilinkErrorMessages[0]);
             ++i) {
            const ApplilinkErrorMessageEntry *entry = &kApplilinkErrorMessages[i];
            NSString *message = entry->fallbackMessage;
            // Yes, rewardBundle is sent twice per entry: once to test and once to use. The binary
            // does not hoist it out of the entry, let alone out of the table.
            if (ApplilinkBundle.rewardBundle != nil) {
                message = [ApplilinkBundle.rewardBundle
                    localizedStringForKey:entry->localizationKey
                                    value:entry->fallbackMessage
                                    table:kApplilinkErrorStringsTable];
            }
            [gApplilinkErrorMessages setObject:message forKey:@(entry->code)];
        }
    }

    NSMutableDictionary *mergedUserInfo = [NSMutableDictionary dictionaryWithDictionary:userInfo];
    if (gApplilinkErrorMessages != nil) {
        // The table is keyed with numberWithInteger: when built but read with numberWithInt:, so
        // the lookup narrows the code to 32 bits. The two agree numerically for every code in the
        // table, so it works, but the asymmetry is the binary's and not a transcription slip.
        NSString *message = [gApplilinkErrorMessages objectForKey:@((int)code)];
        if (message == nil) {
            message = [gApplilinkErrorMessages objectForKey:@((int)kApplilinkErrorCodeUnexpected)];
        }
        if (message != nil) {
            [mergedUserInfo setObject:message forKey:NSLocalizedDescriptionKey];
        }
    }
    return [NSError errorWithDomain:ApplilinkErrorDomain code:code userInfo:mergedUserInfo];
}

@end
