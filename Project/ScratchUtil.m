#import "ScratchUtil.h"

// The API host, from the CFString at 0x2df240. Twenty characters, read from 0x2872a1.
static NSString *const kAPIHost = @"agx11.s.konaminet.jp";

// The API root, and the only one of the four strings here that is a plain C string rather than a
// CFString: it is at 0x286cda and arrives through the "%s" below.
static const char *const kAPIRootPath = "/agx/api";

// The two formats, from the CFStrings at 0x2ded20 and 0x2da200. The endpoint is built in two steps
// rather than one, which is why there are two.
static NSString *const kPushNotificationReactionPathFormat =
    @"%s/log/iOS/v1/PushNotificationReaction.json";
static NSString *const kSecureURLFormat = @"https://%@%@";

@implementation ScratchUtil

+ (NSURL *)pushNotificationResponseURL {
    NSString *path = [NSString stringWithFormat:kPushNotificationReactionPathFormat, kAPIRootPath];
    NSString *urlString = [NSString stringWithFormat:kSecureURLFormat, kAPIHost, path];
    // Straight-line: no branch anywhere in the method, so the endpoint is fixed and there is no
    // staging or debug host to select between.
    return [[NSURL alloc] initWithString:urlString];
}

@end
