#import "NSArray+FromData.h"

@implementation NSArray (FromData)

/** @ghidraAddress 0x171bf8 */
+ (NSArray *)arrayFromPropertyListData:(NSData *)data {
    CFPropertyListRef plist = CFPropertyListCreateWithData(
        kCFAllocatorDefault, (__bridge CFDataRef)data, 0, nullptr, nullptr);
    NSArray *result = nil;
    if ([(__bridge id)plist isKindOfClass:NSArray.class]) {
        result = [[NSArray alloc] initWithArray:(__bridge NSArray *)plist];
    }
    if (plist) {
        CFRelease(plist);
    }
    return result;
}

@end
