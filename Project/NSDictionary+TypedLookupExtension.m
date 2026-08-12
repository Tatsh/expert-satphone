#import "NSDictionary+TypedLookupExtension.h"

@implementation NSDictionary (TypedLookupExtension)

/** @ghidraAddress 0x1ba080 */
- (id)typedObjectForKey:(NSString *)key class:(Class)aClass {
    if (!key || !aClass) {
        return nil;
    }
    id value = self[key];
    if (![value isKindOfClass:aClass]) {
        return nil;
    }
    return value;
}

/** @ghidraAddress 0x1ba0fc */
- (NSDictionary *)dictionaryForKey:(NSString *)key {
    return [self typedObjectForKey:key class:NSDictionary.class];
}

/** @ghidraAddress 0x1ba174 */
- (NSArray *)arrayForKey:(NSString *)key {
    return [self typedObjectForKey:key class:NSArray.class];
}

/** @ghidraAddress 0x1ba1ec */
- (NSNumber *)numberForKey:(NSString *)key {
    return [self typedObjectForKey:key class:NSNumber.class];
}

/** @ghidraAddress 0x1ba264 */
- (NSString *)stringForKey:(NSString *)key {
    return [self typedObjectForKey:key class:NSString.class];
}

@end
