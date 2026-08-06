#import "CJSONDeserializer.h"

// The domain and code all three entry points report for empty input. The code is the same -11
// whichever top-level type was asked for.
static NSString *const kErrorDomain = @"CJSONDeserializerErrorDomain";
enum { kEmptyInputErrorCode = -11 };

@implementation CJSONDeserializer {
    // Neither ivar carries an underscore, which is TouchJSON's convention rather than this tree's.
    CJSONScanner *scanner;
    NSUInteger options;
}

@synthesize scanner = scanner;
@synthesize options = options;

/** @ghidraAddress 0x63504 */
+ (instancetype)deserializer {
    return [[self alloc] init];
}

/** @ghidraAddress 0x6352c */
- (instancetype)init {
    // Nothing but the super call. The scanner is built lazily by its own getter.
    return [super init];
}

/** @ghidraAddress 0x63564 */
- (CJSONScanner *)scanner {
    if (!scanner) {
        scanner = [[CJSONScanner alloc] init];
    }
    return scanner;
}

/** @ghidraAddress 0x635c4 */
- (id)nullObject {
    // No storage of its own: the property is the scanner's, reached through the lazy getter, so
    // asking for it is enough to build a scanner.
    return self.scanner.nullObject;
}

/** @ghidraAddress 0x63618 */
- (void)setNullObject:(id)nullObject {
    self.scanner.nullObject = nullObject;
}

/** @ghidraAddress 0x63684 */
- (NSUInteger)allowedEncoding {
    return self.scanner.allowedEncoding;
}

/** @ghidraAddress 0x636d0 */
- (void)setAllowedEncoding:(NSUInteger)allowedEncoding {
    self.scanner.allowedEncoding = allowedEncoding;
}

/** @ghidraAddress 0x63718 */
- (id)deserialize:(NSData *)data error:(NSError *__autoreleasing *)outError {
    // Nil and empty are the same case, and both are reported as an error rather than as an empty
    // result.
    if (!data || data.length == 0) {
        // Only filled in when the caller asked for it; without an out-parameter the failure is
        // silent.
        if (outError) {
            *outError = [NSError errorWithDomain:kErrorDomain
                                            code:kEmptyInputErrorCode
                                        userInfo:nil];
        }
        return nil;
    }

    // The scanner reports its own errors through the same out-parameter, so a failure here is
    // already described by the time this returns.
    if (![self.scanner setData:data error:outError]) {
        return nil;
    }

    id object = nil;
    // The scanned object is only adopted when the scan reports success; on failure it is dropped
    // even if the scanner wrote something into it.
    if (![self.scanner scanJSONObject:&object error:outError]) {
        return nil;
    }
    return object;
}

/** @ghidraAddress 0x63870 */
- (NSDictionary *)deserializeAsDictionary:(NSData *)data
                                    error:(NSError *__autoreleasing *)outError {
    if (!data || data.length == 0) {
        if (outError) {
            *outError = [NSError errorWithDomain:kErrorDomain
                                            code:kEmptyInputErrorCode
                                        userInfo:nil];
        }
        return nil;
    }

    if (![self.scanner setData:data error:outError]) {
        return nil;
    }

    NSDictionary *dictionary = nil;
    if (![self.scanner scanJSONDictionary:&dictionary error:outError]) {
        return nil;
    }
    return dictionary;
}

/** @ghidraAddress 0x639c8 */
- (NSArray *)deserializeAsArray:(NSData *)data error:(NSError *__autoreleasing *)outError {
    if (!data || data.length == 0) {
        if (outError) {
            *outError = [NSError errorWithDomain:kErrorDomain
                                            code:kEmptyInputErrorCode
                                        userInfo:nil];
        }
        return nil;
    }

    if (![self.scanner setData:data error:outError]) {
        return nil;
    }

    NSArray *array = nil;
    if (![self.scanner scanJSONArray:&array error:outError]) {
        return nil;
    }
    return array;
}

@end
