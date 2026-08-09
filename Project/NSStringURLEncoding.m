#import "NSStringURLEncoding.h"

// The RFC 3986 reserved set plus the percent sign and square brackets, from the CFString at
// 0x2e3760.
static NSString *const kURLEscapedCharacters = @"!*'();:@&=+$,/?%#[]";

@implementation NSStringURLEncoding

/** @ghidraAddress 0x235df4 */
+ (NSString *)URLEncodedString:(NSString *)string {
    // The retain-then-CFRelease pair around the +1 result is what CFBridgingRelease compiles to.
    return CFBridgingRelease(
        CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                (__bridge CFStringRef)string,
                                                nullptr,
                                                (__bridge CFStringRef)kURLEscapedCharacters,
                                                kCFStringEncodingUTF8));
}

/** @ghidraAddress 0x235e4c */
+ (NSString *)URLDecodedString:(NSString *)string {
    // The empty string as the leave-escaped set, so nothing is held back from decoding.
    return CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapesUsingEncoding(
        kCFAllocatorDefault, (__bridge CFStringRef)string, CFSTR(""), kCFStringEncodingUTF8));
}

@end
