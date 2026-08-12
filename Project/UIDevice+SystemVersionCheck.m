#import "UIDevice+SystemVersionCheck.h"

@implementation UIDevice (SystemVersionCheck)

/** @ghidraAddress 0x1fde90 */
- (BOOL)systemVersionGreaterEqual:(NSString *)version {
    // A numeric compare so "9.10" sorts after "9.2"; greater-or-equal is "not ascending".
    return [self.systemVersion compare:version options:NSNumericSearch] != NSOrderedAscending;
}

@end
