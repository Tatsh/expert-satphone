#import "EditorIDManager.h"

#import <Security/Security.h>

@implementation EditorIDManager

/** @ghidraAddress 0x1d308c */
+ (BOOL)isExistEditorID {
    NSDictionary *idQuery = [self getKeyQuery:self.getEditorIDKey];
    NSDictionary *passQuery = [self getKeyQuery:self.getEditorPassKey];

    // Both lookups share one out-parameter and neither result is used, so this is a presence test
    // rather than a fetch. Whatever the second lookup writes overwrites the first.
    CFTypeRef found = NULL;
    OSStatus idStatus = SecItemCopyMatching((__bridge CFDictionaryRef)idQuery, &found);
    OSStatus passStatus = SecItemCopyMatching((__bridge CFDictionaryRef)passQuery, &found);

    // The binary ors the two statuses and tests for zero, so both must be errSecSuccess.
    if ((idStatus | passStatus) == errSecSuccess) {
        return YES;
    }
    // A half-provisioned device is wiped rather than left alone. The ccmp at 0x1d315c makes this
    // fire when either status is errSecItemNotFound, not only when both are.
    if (idStatus == errSecItemNotFound || passStatus == errSecItemNotFound) {
        [self deleteKeychain];
    }
    return NO;
}

/** @ghidraAddress 0x1d33c4 */
+ (NSString *)getKeyString:(id)key {
    NSDictionary *query = [self getKeyQuery:key];

    CFTypeRef attributes = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &attributes) != errSecSuccess) {
        return nil;
    }

    // The found attributes become the basis of a second query that asks for the payload, the same
    // two-step -[JubeatAppDelegate musicListKey] uses.
    NSMutableDictionary *fetch =
        [NSMutableDictionary dictionaryWithDictionary:(__bridge NSDictionary *)attributes];
    fetch[(__bridge NSString *)kSecClass] = (__bridge id)kSecClassGenericPassword;
    fetch[(__bridge NSString *)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    CFRelease(attributes);

    CFTypeRef payload = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)fetch, &payload) != errSecSuccess) {
        return nil;
    }
    NSData *bytes = (__bridge NSData *)payload;
    return [[NSString alloc] initWithBytes:bytes.bytes
                                    length:bytes.length
                                  encoding:NSUTF8StringEncoding];
}

@end
