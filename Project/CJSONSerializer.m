#import "CJSONSerializer.h"

#import <CoreFoundation/CoreFoundation.h>

// An object may opt into serialisation by vending its own JSON data; TouchJSON's extension point.
@protocol CJSONDataRepresentation <NSObject>
- (NSData *)JSONDataRepresentation;
@end

// The shared token data for the three JSON keywords, primed once by +initialize and kept for the
// lifetime of the process (created with +initWithBytesNoCopy:length:freeWhenDone: over the string
// literals, so their backing bytes are never freed).
static NSData *g_nullData = nil;
static NSData *g_falseData = nil;
static NSData *g_trueData = nil;

// The error domain and the two failure-message formats, from the CFStrings the serialiser builds.
// The user-info key is the framework's NSLocalizedDescriptionKey constant (loaded from the GOT),
// not a string literal.
static NSString *const kErrorDomain = @"CJSONSerializerErrorDomain";
static NSString *const kCannotSerializeFormat = @"Cannot serialize data of type '%@'";
static NSString *const kCouldNotSerializeFormat = @"Could not serialize object '%@'";

// The comma between array elements and dictionary pairs. -serializeString: escapes the forward
// slash only when the low bit of options is set.
static const NSUInteger kOptionEscapeSlash = 1;

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

#pragma mark - Validation

/** @ghidraAddress 0x66af4 */
- (BOOL)isValidJSONObject:(id)object {
    return [object isKindOfClass:[NSNull class]] || [object isKindOfClass:[NSNumber class]] ||
           [object isKindOfClass:[NSString class]] || [object isKindOfClass:[NSArray class]] ||
           [object isKindOfClass:[NSDictionary class]] || [object isKindOfClass:[NSData class]] ||
           [object respondsToSelector:@selector(JSONDataRepresentation)];
}

#pragma mark - Serialisation

/** @ghidraAddress 0x66c60 */
- (NSData *)serializeObject:(id)object error:(NSError **)error {
    NSData *result;
    if ([object isKindOfClass:[NSNull class]]) {
        result = [self serializeNull:object error:error];
    } else if ([object isKindOfClass:[NSNumber class]]) {
        result = [self serializeNumber:object error:error];
    } else if ([object isKindOfClass:[NSString class]]) {
        result = [self serializeString:object error:error];
    } else if ([object isKindOfClass:[NSArray class]]) {
        result = [self serializeArray:object error:error];
    } else if ([object isKindOfClass:[NSDictionary class]]) {
        result = [self serializeDictionary:object error:error];
    } else if ([object isKindOfClass:[NSData class]]) {
        // Data already holding UTF-8 JSON is decoded to a string and re-serialised as one.
        NSString *string = [[NSString alloc] initWithData:object encoding:NSUTF8StringEncoding];
        if (string == nil) {
            if (error != nil) {
                NSString *message = [NSString
                    stringWithFormat:kCannotSerializeFormat, NSStringFromClass([object class])];
                *error = [NSError errorWithDomain:kErrorDomain
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey : message}];
            }
            return nil;
        }
        result = [self serializeString:string error:error];
    } else if ([object respondsToSelector:@selector(JSONDataRepresentation)]) {
        result = [(id<CJSONDataRepresentation>)object JSONDataRepresentation];
    } else {
        if (error != nil) {
            NSString *message = [NSString
                stringWithFormat:kCannotSerializeFormat, NSStringFromClass([object class])];
            *error = [NSError errorWithDomain:kErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey : message}];
        }
        return nil;
    }
    if (result != nil) {
        return result;
    }
    if (error == nil) {
        return nil;
    }
    NSString *message = [NSString stringWithFormat:kCouldNotSerializeFormat, object];
    *error = [NSError errorWithDomain:kErrorDomain
                                 code:-1
                             userInfo:@{NSLocalizedDescriptionKey : message}];
    return nil;
}

/** @ghidraAddress 0x67118 */
- (NSData *)serializeNull:(NSNull *)null error:(NSError **)error {
    return g_nullData;
}

/** @ghidraAddress 0x67124 */
- (NSData *)serializeNumber:(NSNumber *)number error:(NSError **)error {
    // A char-typed number is a boxed BOOL: 1 is true, 0 is false, and any other char value (as well
    // as every non-char number) falls through to its decimal string.
    if (CFNumberGetType((CFNumberRef)number) == kCFNumberCharType) {
        int value = number.intValue;
        if (value == 1) {
            return g_trueData;
        }
        if (value == 0) {
            return g_falseData;
        }
    }
    return [number.stringValue dataUsingEncoding:NSUTF8StringEncoding];
}

/** @ghidraAddress 0x67220 */
- (NSData *)serializeString:(NSString *)string error:(NSError **)error {
    const char *bytes = [string UTF8String];
    // The worst case is every byte escaping to two, plus the opening and closing quotes.
    NSMutableData *data = [NSMutableData dataWithLength:strlen(bytes) * 2 + 2];
    char *out = data.mutableBytes;
    char *cursor = out;
    *cursor++ = '"';
    for (const char *in = bytes; in && *in; ++in) {
        char c = *in;
        switch (c) {
        case '\b':
            *cursor++ = '\\';
            *cursor++ = 'b';
            break;
        case '\t':
            *cursor++ = '\\';
            *cursor++ = 't';
            break;
        case '\n':
            *cursor++ = '\\';
            *cursor++ = 'n';
            break;
        case '\f':
            *cursor++ = '\\';
            *cursor++ = 'f';
            break;
        case '\r':
            *cursor++ = '\\';
            *cursor++ = 'r';
            break;
        case '"':
            *cursor++ = '\\';
            *cursor++ = '"';
            break;
        case '/':
            if (self.options & kOptionEscapeSlash) {
                *cursor++ = '\\';
                *cursor++ = '/';
            } else {
                *cursor++ = c;
            }
            break;
        case '\\':
            *cursor++ = '\\';
            *cursor++ = '\\';
            break;
        default:
            *cursor++ = c;
            break;
        }
    }
    *cursor = '"';
    // The buffer was over-allocated for the worst case; trim it to what was actually written.
    [data setLength:(cursor + 1) - out];
    return data;
}

/** @ghidraAddress 0x6743c */
- (NSData *)serializeArray:(NSArray *)array error:(NSError **)error {
    NSMutableData *data = [NSMutableData data];
    [data appendBytes:"[" length:1];
    NSUInteger index = 1;
    for (id element in array) {
        NSData *elementData = [self serializeObject:element error:error];
        if (elementData == nil) {
            return nil;
        }
        [data appendData:elementData];
        if (index < array.count) {
            [data appendBytes:"," length:1];
        }
        ++index;
    }
    [data appendBytes:"]" length:1];
    return data;
}

/** @ghidraAddress 0x67608 */
- (NSData *)serializeDictionary:(NSDictionary *)dictionary error:(NSError **)error {
    NSMutableData *data = [NSMutableData data];
    [data appendBytes:"{" length:1];
    NSArray *keys = dictionary.allKeys;
    for (id key in keys) {
        id value = dictionary[key];
        NSData *keyData = [self serializeString:key error:error];
        if (keyData == nil) {
            return nil;
        }
        NSData *valueData = [self serializeObject:value error:error];
        if (valueData == nil) {
            return nil;
        }
        [data appendData:keyData];
        [data appendBytes:":" length:1];
        [data appendData:valueData];
        if (key != keys.lastObject) {
            [data appendData:[@"," dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    [data appendBytes:"}" length:1];
    return data;
}

@end
