#import <UIKit/UIKit.h>

#import "NSDictionary+FromData.h"

@implementation NSDictionary (FromData)

/** @ghidraAddress 0x1831cc */
+ (NSDictionary *)dictionaryFromPropertyListData:(NSData *)data {
    (void)UIDevice.currentDevice.systemVersion; // Yes, the binary fetches this and discards it.
    CFPropertyListRef plist = CFPropertyListCreateWithData(
        kCFAllocatorDefault, (__bridge CFDataRef)data, 0, nullptr, nullptr);
    NSDictionary *result = nil;
    if ([(__bridge id)plist isKindOfClass:NSDictionary.class]) {
        result = [[NSDictionary alloc] initWithDictionary:(__bridge NSDictionary *)plist];
    }
    if (plist) {
        CFRelease(plist);
    }
    return result;
}

@end
