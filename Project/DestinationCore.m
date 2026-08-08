#import "DestinationCore.h"

#import "ApplilinkConsts.h"
#import "ApplilinkUtilities.h"
#import "ApplilinkWebAPI.h"

// The three parameters the registration sends, and the fixed value of the first.
static NSString *const kParameterKeySystem = @"system";
static NSString *const kParameterKeyCountryCode = @"country_code";
static NSString *const kParameterKeyReturnURL = @"rturl";
static NSString *const kSystemValue = @"ad";

static NSString *const kRegistPath = @"/destination/regist.php";
static NSString *const kHTTPMethodGet = @"GET";

// The dictionary is built at exactly the three entries it takes.
enum { kParameterCount = 3 };

static const float kRequestTimeout = 10.0f;

@implementation DestinationCore

/** @ghidraAddress 0x250d24 */
- (void)destinationRegistWithCountryCode:(NSString *)countryCode
                                     url:(NSString *)url
                                delegate:(id)delegate {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:kParameterCount];
    [parameters setValue:kSystemValue forKey:kParameterKeySystem];
    [parameters setValue:countryCode forKey:kParameterKeyCountryCode];
    [parameters setValue:url forKey:kParameterKeyReturnURL];

    NSString *query = [ApplilinkUtilities userAgentParametersJoinDictionary:parameters];

    ApplilinkWebAPI *webAPI = [[ApplilinkWebAPI alloc] init];
    NSURLRequest *request =
        [webAPI requestWithURL:[ApplilinkConsts.baseUrlSsl stringByAppendingString:kRegistPath]
                        method:kHTTPMethodGet
                    parameters:query
                       timeout:kRequestTimeout
                   cachePolicy:nil];

    // Yes, self rather than the delegate argument: x4 holds the caller's object on entry and is
    // never read, while x19 (self) is what reaches loadRequestWithRequest:delegate: at 0x250f14.
    ApplilinkURLConnection *connection = [[ApplilinkURLConnection alloc] init];
    [connection loadRequestWithRequest:request delegate:self];
}

/** @ghidraAddress 0x250f50 */
- (void)failLoadWithError:(NSError *)error {
    // The binary's body is a single ret. A failure is not reported anywhere.
}

/** @ghidraAddress 0x250f54 */
- (void)finishLoadWithResponse:(NSString *)response {
    // The binary's body is a single ret. The registration's answer is never examined. The argument
    // is the UTF-8 body string that ApplilinkURLConnection decodes.
}

/** @ghidraAddress 0x250f58 */
- (BOOL)redirectStartLoad:(NSURLRequest *)request {
    return NO;
}

@end
