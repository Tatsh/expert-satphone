#import "CJSONDeserializer.h"
#import "NSDictionary+JSONExtensions.h"

// UTF-8, the encoding dictionaryWithJSONString:error: uses to turn its string into JSON data
// (NSUTF8StringEncoding == 4).
static const NSStringEncoding kJSONStringEncoding = NSUTF8StringEncoding;

@implementation NSDictionary (JSONExtensions)

/** @ghidraAddress 0x633f8 */
+ (id)dictionaryWithJSONData:(NSData *)data error:(NSError **)error {
    // A fresh deserialiser per call, and the generic deserialize:error: rather than the
    // dictionary-specific entry point, so the result is not constrained to a dictionary.
    return [[CJSONDeserializer deserializer] deserialize:data error:error];
}

/** @ghidraAddress 0x63488 */
+ (id)dictionaryWithJSONString:(NSString *)string error:(NSError **)error {
    return [self dictionaryWithJSONData:[string dataUsingEncoding:kJSONStringEncoding] error:error];
}

@end
