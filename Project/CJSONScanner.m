#import "CJSONScanner.h"

#import <CoreFoundation/CoreFoundation.h>

// The scanner's error domain, from the CFString the routines pass to
// +errorWithDomain:code:userInfo:. TouchJSON gives the domain the "k"-prefixed name of one of its
// own code constants.
static NSString *const kErrorDomain = @"kJSONScannerErrorDomain";

// The failure codes, decoded from the immediates each error site loads. Several codes are shared by
// more than one message, and code -106 is reported both for a missing pair delimiter and for a
// missing closing brace.
enum {
    kErrorCodeCouldNotDecodeData = -12,
    kErrorCodeInvalidCharacter = -15,
    kErrorCodeDictionaryNoOpenBrace = -101,
    kErrorCodeDictionaryFailedToScanKey = -102,
    kErrorCodeDictionaryKeyNotTerminated = -103,
    kErrorCodeDictionaryFailedToScanValue = -104,
    kErrorCodeDictionaryNoDelimiter = -106,
    kErrorCodeArrayNoOpenBracket = -201,
    kErrorCodeArrayFailedToScanValue = -202,
    kErrorCodeArrayValueIsNull = -203,
    kErrorCodeArrayNoCloseBracket = -204,
    kErrorCodeStringNoOpenQuote = -301,
    kErrorCodeStringUnicodeUndecodable = -302,
    kErrorCodeStringUnknownEscape = -303,
    kErrorCodeStringNoCloseQuote = -304,
    kErrorCodeNumber = -401,
};

// The localised descriptions, verbatim from the CFStrings each error site references. The
// "no delimiter" message is the code-constant's own name rather than a sentence, which is
// TouchJSON's own text and not a reconstruction slip.
static NSString *const kMessageCouldNotDecodeData =
    @"Could not scan data. Data wasn't encoded properly?";
static NSString *const kMessageInvalidCharacter =
    @"Could not scan object. Character not a valid JSON character.";
static NSString *const kMessageDictionaryNoOpenBrace =
    @"Could not scan dictionary. Dictionary that does not start with '{' character.";
static NSString *const kMessageDictionaryFailedToScanKey =
    @"Could not scan dictionary. Failed to scan a key.";
static NSString *const kMessageDictionaryKeyNotTerminated =
    @"Could not scan dictionary. Key was not terminated with a ':' character.";
static NSString *const kMessageDictionaryFailedToScanValue =
    @"Could not scan dictionary. Failed to scan a value.";
static NSString *const kMessageDictionaryNoDelimiter =
    @"kJSONScannerErrorCode_DictionaryKeyValuePairNoDelimiter";
static NSString *const kMessageDictionaryNoCloseBrace =
    @"Could not scan dictionary. Dictionary not terminated by a '}' character.";
static NSString *const kMessageArrayNoOpenBracket =
    @"Could not scan array. Array not started by a '[' character.";
static NSString *const kMessageArrayFailedToScanValue =
    @"Could not scan array. Could not scan a value.";
static NSString *const kMessageArrayValueIsNull = @"Could not scan array. Value is NULL.";
static NSString *const kMessageArrayNoCloseBracket =
    @"Could not scan array. Array not terminated by a ']' character.";
static NSString *const kMessageStringNoOpenQuote =
    @"Could not scan string constant. String not started by a '\"' character.";
static NSString *const kMessageStringUnicodeUndecodable =
    @"Could not scan string constant. Unicode character could not be decoded.";
static NSString *const kMessageStringUnknownEscape =
    @"Could not scan string constant. Unknown escape code.";
static NSString *const kMessageStringNoCloseQuote =
    @"Could not scan string constant. No terminating double quote character.";
static NSString *const kMessageNumber = @"Could not scan number constant.";

// Bit 0 of the options keeps scanned containers mutable; bit 1 keeps scanned strings mutable.
static const NSUInteger kOptionKeepContainersMutable = 1;
static const NSUInteger kOptionKeepStringsMutable = 2;

// The boxed booleans returned for the "true" and "false" keywords, primed once by +initialize.
// @ghidraAddress 0x3540e8 (true), 0x3540f0 (false)
static NSNumber *g_trueNumber = nil;
static NSNumber *g_falseNumber = nil;

// The number of hexadecimal digits in a "\u" escape.
static const int kUnicodeEscapeDigitCount = 4;

// The value of a single hexadecimal digit, or -1 when the character is not one. Mirrors the digit
// table the binary indexes at 0x28f798.
static int JSONHexDigitValue(unichar character) {
    if (character >= '0' && character <= '9') {
        return character - '0';
    }
    if (character >= 'A' && character <= 'F') {
        return (character - 'A') + 10;
    }
    if (character >= 'a' && character <= 'f') {
        return (character - 'a') + 10;
    }
    return -1;
}

@implementation CJSONScanner

#pragma mark - Lifecycle

/** @ghidraAddress 0x650c8 */
+ (void)initialize {
    @autoreleasepool {
        if (g_trueNumber == nil) {
            g_trueNumber = [NSNumber numberWithBool:YES];
        }
        if (g_falseNumber == nil) {
            g_falseNumber = [NSNumber numberWithBool:NO];
        }
    }
}

/** @ghidraAddress 0x65168 */
- (instancetype)init {
    self = [super init];
    if (self) {
        self.strictEscapeCodes = NO;
        self.nullObject = [NSNull null];
    }
    return self;
}

#pragma mark - Input

/** @ghidraAddress 0x651f4 */
- (BOOL)setData:(NSData *)data error:(NSError *__autoreleasing *)outError {
    if (data == nil) {
        if (outError) {
            *outError = [self error:kErrorCodeCouldNotDecodeData
                        description:kMessageCouldNotDecodeData];
        }
        return NO;
    }

    // Only long enough inputs are sniffed for a byte-order mark; shorter ones are handed to the
    // superclass unchanged.
    if (data.length > 3) {
        const char *bytes = data.bytes;
        NSStringEncoding encoding;
        if (bytes[0] == 0) {
            if (bytes[2] != 0 || bytes[3] == 0) {
                encoding = NSUTF8StringEncoding;
            } else {
                encoding = (bytes[1] != 0) ? NSUTF16BigEndianStringEncoding :
                                             NSUTF32BigEndianStringEncoding;
            }
        } else if (bytes[1] == 0) {
            if (bytes[2] != 0) {
                encoding =
                    (bytes[3] != 0) ? NSUTF8StringEncoding : NSUTF16LittleEndianStringEncoding;
            } else {
                encoding =
                    (bytes[3] != 0) ? NSUTF8StringEncoding : NSUTF32LittleEndianStringEncoding;
            }
        } else {
            encoding = NSUTF8StringEncoding;
        }

        NSString *string = [[NSString alloc] initWithData:data encoding:encoding];
        if (string == nil && self.allowedEncoding != 0) {
            string = [[NSString alloc] initWithData:data encoding:self.allowedEncoding];
        }
        data = [string dataUsingEncoding:NSUTF8StringEncoding];
        if (data == nil) {
            if (outError) {
                *outError = [self error:kErrorCodeCouldNotDecodeData
                            description:kMessageCouldNotDecodeData];
            }
            return NO;
        }
    }

    [super setData:data];
    return YES;
}

/** @ghidraAddress 0x65438 */
- (void)setData:(NSData *)data {
    [self setData:data error:nil];
}

#pragma mark - Scanning

/** @ghidraAddress 0x65448 */
- (BOOL)scanJSONObject:(id __autoreleasing *)outObject error:(NSError *__autoreleasing *)outError {
    [self skipWhitespace];
    unichar character = [self currentCharacter];
    BOOL success = NO;
    id object = nil;
    switch (character) {
    case '"':
    case '\'': {
        NSString *string = nil;
        success = [self scanJSONStringConstant:&string error:outError];
        object = string;
        break;
    }
    case '-':
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9': {
        NSNumber *number = nil;
        success = [self scanJSONNumberConstant:&number error:outError];
        object = number;
        break;
    }
    case '[': {
        NSArray *array = nil;
        success = [self scanJSONArray:&array error:outError];
        object = array;
        break;
    }
    case '{': {
        NSDictionary *dictionary = nil;
        success = [self scanJSONDictionary:&dictionary error:outError];
        object = dictionary;
        break;
    }
    case 'f':
        // The keyword scan is best effort: a leading 'f' that is not "false" still reports success
        // with a nil object rather than an error.
        object = [self scanUTF8String:"false" intoString:nil] ? g_falseNumber : nil;
        success = YES;
        break;
    case 'n':
        object = [self scanUTF8String:"null" intoString:nil] ? self.nullObject : nil;
        success = YES;
        break;
    case 't':
        object = [self scanUTF8String:"true" intoString:nil] ? g_trueNumber : nil;
        success = YES;
        break;
    default:
        if (outError) {
            // The error is built twice, and the second build wins; both are identical.
            *outError = [self error:kErrorCodeInvalidCharacter
                        description:kMessageInvalidCharacter];
            NSMutableDictionary *userInfo =
                [NSMutableDictionary dictionaryWithObjectsAndKeys:kMessageInvalidCharacter,
                                                                  NSLocalizedDescriptionKey,
                                                                  nil];
            [userInfo addEntriesFromDictionary:[self userInfoForScanLocation]];
            *outError = [NSError errorWithDomain:kErrorDomain
                                            code:kErrorCodeInvalidCharacter
                                        userInfo:userInfo];
        }
        success = NO;
        object = nil;
        break;
    }

    if (outObject) {
        *outObject = object;
    }
    return success;
}

/** @ghidraAddress 0x65880 */
- (BOOL)scanJSONDictionary:(NSDictionary *__autoreleasing *)outDictionary
                     error:(NSError *__autoreleasing *)outError {
    NSUInteger startLocation = self.scanLocation;
    [self skipWhitespace];
    if (![self scanCharacter:'{']) {
        if (outError) {
            *outError = [self error:kErrorCodeDictionaryNoOpenBrace
                        description:kMessageDictionaryNoOpenBrace];
        }
        return NO;
    }

    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    while (YES) {
        if ([self currentCharacter] == '}') {
            break;
        }
        [self skipWhitespace];
        if ([self currentCharacter] == '}') {
            break;
        }

        NSString *key = nil;
        if (![self scanJSONStringConstant:&key error:outError]) {
            [self setScanLocation:startLocation];
            if (outError) {
                *outError = [self error:kErrorCodeDictionaryFailedToScanKey
                            description:kMessageDictionaryFailedToScanKey];
            }
            return NO;
        }

        [self skipWhitespace];
        if (![self scanCharacter:':']) {
            [self setScanLocation:startLocation];
            if (outError) {
                *outError = [self error:kErrorCodeDictionaryKeyNotTerminated
                            description:kMessageDictionaryKeyNotTerminated];
            }
            return NO;
        }

        id value = nil;
        if (![self scanJSONObject:&value error:outError]) {
            [self setScanLocation:startLocation];
            if (outError) {
                *outError = [self error:kErrorCodeDictionaryFailedToScanValue
                            description:kMessageDictionaryFailedToScanValue];
            }
            return NO;
        }

        // A nil value is only stored when a null substitute is configured; otherwise the pair is
        // dropped.
        if (value != nil || self.nullObject != nil) {
            [dictionary setValue:value forKey:key];
        }

        [self skipWhitespace];
        if (![self scanCharacter:',']) {
            if ([self currentCharacter] != '}') {
                [self setScanLocation:startLocation];
                if (outError) {
                    *outError = [self error:kErrorCodeDictionaryNoDelimiter
                                description:kMessageDictionaryNoDelimiter];
                }
                return NO;
            }
            break;
        }
        [self skipWhitespace];
        if ([self currentCharacter] == '}') {
            break;
        }
    }

    if (![self scanCharacter:'}']) {
        [self setScanLocation:startLocation];
        if (outError) {
            *outError = [self error:kErrorCodeDictionaryNoDelimiter
                        description:kMessageDictionaryNoCloseBrace];
        }
        return NO;
    }

    if (outDictionary) {
        *outDictionary =
            (self.options & kOptionKeepContainersMutable) ? dictionary : [dictionary copy];
    }
    return YES;
}

/** @ghidraAddress 0x65ccc */
- (BOOL)scanJSONArray:(NSArray *__autoreleasing *)outArray
                error:(NSError *__autoreleasing *)outError {
    NSUInteger startLocation = self.scanLocation;
    [self skipWhitespace];
    if (![self scanCharacter:'[']) {
        if (outError) {
            *outError = [self error:kErrorCodeArrayNoOpenBracket
                        description:kMessageArrayNoOpenBracket];
        }
        return NO;
    }

    NSMutableArray *array = [[NSMutableArray alloc] init];
    [self skipWhitespace];
    unichar character = [self currentCharacter];
    while (character != ']') {
        id value = nil;
        if (![self scanJSONObject:&value error:outError]) {
            [self setScanLocation:startLocation];
            if (outError) {
                // The error is built twice, and the second build wins; both are identical.
                *outError = [self error:kErrorCodeArrayFailedToScanValue
                            description:kMessageArrayFailedToScanValue];
                NSMutableDictionary *userInfo = [NSMutableDictionary
                    dictionaryWithObjectsAndKeys:kMessageArrayFailedToScanValue,
                                                 NSLocalizedDescriptionKey,
                                                 nil];
                [userInfo addEntriesFromDictionary:[self userInfoForScanLocation]];
                *outError = [NSError errorWithDomain:kErrorDomain
                                                code:kErrorCodeArrayFailedToScanValue
                                            userInfo:userInfo];
            }
            return NO;
        }

        if (value == nil) {
            // A nil value is silently skipped when no null substitute is set, but reported as an
            // error when one is.
            if (self.nullObject != nil) {
                if (outError) {
                    *outError = [self error:kErrorCodeArrayValueIsNull
                                description:kMessageArrayValueIsNull];
                }
                return NO;
            }
        } else {
            [array addObject:value];
        }

        [self skipWhitespace];
        BOOL scannedComma = [self scanCharacter:','];
        [self skipWhitespace];
        if (!scannedComma) {
            if ([self currentCharacter] != ']') {
                [self setScanLocation:startLocation];
                if (outError) {
                    *outError = [self error:kErrorCodeArrayNoCloseBracket
                                description:kMessageArrayNoCloseBracket];
                }
                return NO;
            }
            break;
        }
        character = [self currentCharacter];
    }

    [self skipWhitespace];
    if (![self scanCharacter:']']) {
        [self setScanLocation:startLocation];
        if (outError) {
            *outError = [self error:kErrorCodeArrayNoCloseBracket
                        description:kMessageArrayNoCloseBracket];
        }
        return NO;
    }

    if (outArray) {
        *outArray = (self.options & kOptionKeepContainersMutable) ? array : [array copy];
    }
    return YES;
}

/** @ghidraAddress 0x6611c */
- (BOOL)scanJSONStringConstant:(NSString *__autoreleasing *)outString
                         error:(NSError *__autoreleasing *)outError {
    NSUInteger startLocation = self.scanLocation;
    [self skipWhitespace];
    NSMutableString *string = [[NSMutableString alloc] init];
    if (![self scanCharacter:'"']) {
        [self setScanLocation:startLocation];
        if (outError) {
            *outError = [self error:kErrorCodeStringNoOpenQuote
                        description:kMessageStringNoOpenQuote];
        }
        return NO;
    }

    while (![self scanCharacter:'"']) {
        NSString *run = nil;
        if ([self scanNotQuoteCharactersIntoString:&run]) {
            CFStringAppend((CFMutableStringRef)string, (CFStringRef)run);
            continue;
        }

        if (![self scanCharacter:'\\']) {
            if (outError) {
                *outError = [self error:kErrorCodeStringNoCloseQuote
                            description:kMessageStringNoCloseQuote];
            }
            return NO;
        }

        unichar character = [self scanCharacter];
        switch (character) {
        case '"':
        case '/':
        case '\\':
            break;
        case 'b':
            character = '\b';
            break;
        case 'f':
            character = '\f';
            break;
        case 'n':
            character = '\n';
            break;
        case 'r':
            character = '\r';
            break;
        case 't':
            character = '\t';
            break;
        case 'u': {
            unichar value = 0;
            BOOL decoded = YES;
            for (int shift = (kUnicodeEscapeDigitCount - 1) * 4; shift >= 0; shift -= 4) {
                int nibble = JSONHexDigitValue([self scanCharacter]);
                if (nibble < 0) {
                    decoded = NO;
                    break;
                }
                value |= (unichar)(nibble << shift);
            }
            if (!decoded) {
                [self setScanLocation:startLocation];
                if (outError) {
                    *outError = [self error:kErrorCodeStringUnicodeUndecodable
                                description:kMessageStringUnicodeUndecodable];
                }
                return NO;
            }
            character = value;
            break;
        }
        default:
            // An unrecognised escape is an error only in strict mode; otherwise the character is
            // taken literally.
            if (self.strictEscapeCodes) {
                [self setScanLocation:startLocation];
                if (outError) {
                    *outError = [self error:kErrorCodeStringUnknownEscape
                                description:kMessageStringUnknownEscape];
                }
                return NO;
            }
            break;
        }
        CFStringAppendCharacters((CFMutableStringRef)string, &character, 1);
    }

    if (outString) {
        *outString = (self.options & kOptionKeepStringsMutable) ? string : [string copy];
    }
    return YES;
}

/** @ghidraAddress 0x666b4 */
- (BOOL)scanJSONNumberConstant:(NSNumber *__autoreleasing *)outNumber
                         error:(NSError *__autoreleasing *)outError {
    [self skipWhitespace];
    NSNumber *number = nil;
    if (![self scanNumber:&number]) {
        if (outError) {
            *outError = [self error:kErrorCodeNumber description:kMessageNumber];
        }
        return NO;
    }
    if (outNumber) {
        *outNumber = number;
    }
    return YES;
}

/** @ghidraAddress 0x66790 */
- (BOOL)scanNotQuoteCharactersIntoString:(NSString *__autoreleasing *)outString {
    char *start = self->current;
    char *cursor = start;
    if (cursor < self->end) {
        while (cursor < self->end) {
            if (*cursor == '"' || *cursor == '\\') {
                break;
            }
            ++cursor;
        }
        if (cursor != start) {
            if (outString) {
                *outString = [[NSString alloc] initWithBytes:self->current
                                                      length:cursor - self->current
                                                    encoding:NSUTF8StringEncoding];
            }
            self->current = cursor;
            return YES;
        }
    }
    return NO;
}

#pragma mark - Errors

/** @ghidraAddress 0x66854 */
- (NSError *)error:(NSInteger)code description:(NSString *)description {
    NSMutableDictionary *userInfo = [NSMutableDictionary
        dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, nil];
    [userInfo addEntriesFromDictionary:[self userInfoForScanLocation]];
    return [NSError errorWithDomain:kErrorDomain code:code userInfo:userInfo];
}

@end
