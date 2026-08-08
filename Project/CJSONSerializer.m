#import "CJSONSerializer.h"

// The shared token data for the three JSON keywords, primed once by +initialize and kept for the
// lifetime of the process (created with +initWithBytesNoCopy:length:freeWhenDone: over the string
// literals, so their backing bytes are never freed).
static NSData *g_nullData = nil;
static NSData *g_falseData = nil;
static NSData *g_trueData = nil;

@implementation CJSONSerializer

/** @ghidraAddress 0x669c4 */
+ (void)initialize {
    @autoreleasepool {
        if (g_nullData == nil) {
            g_nullData = [[NSData alloc] initWithBytesNoCopy:(void *)"null"
                                                      length:4
                                                freeWhenDone:NO];
        }
        if (g_falseData == nil) {
            g_falseData = [[NSData alloc] initWithBytesNoCopy:(void *)"false"
                                                       length:5
                                                 freeWhenDone:NO];
        }
        if (g_trueData == nil) {
            g_trueData = [[NSData alloc] initWithBytesNoCopy:(void *)"true"
                                                      length:4
                                                freeWhenDone:NO];
        }
    }
}

/** @ghidraAddress 0x66acc */
+ (instancetype)serializer {
    return [[self alloc] init];
}

@end
