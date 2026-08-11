#import "CDataScanner.h"

#include <ctype.h>
#include <stdlib.h>
#include <string.h>

// The set of characters a number literal is made of, primed once by +initialize. This is the
// DAT_ global the number scanners index.
// @ghidraAddress 0x3540e0
static NSCharacterSet *g_numberCharacterSet = nil;

// The characters that make up a number literal, matching the string +initialize builds the shared
// set from.
static NSString *const kNumberCharacters = @"0123456789eE-+.";

// The number of characters of context shown on either side of the cursor in the diagnostic
// snippet, and the marker inserted at the cursor position.
static const NSUInteger kSnippetContextLength = 20;
static NSString *const kSnippetFormat = @"%@!HERE>!%@";

// The keys of the diagnostic user-info dictionary.
static NSString *const kUserInfoKeyLine = @"line";
static NSString *const kUserInfoKeyCharacter = @"character";
static NSString *const kUserInfoKeyLocation = @"location";
static NSString *const kUserInfoKeySnippet = @"snippet";

// The exception messages the C-style comment scanner raises.
static NSString *const kMessageCommentNotTerminated =
    @"Started to scan a C style comment but it wasn't terminated.";
static NSString *const kMessageCommentNested = @"C style comments should not be nested.";
static NSString *const kMessageCommentBadEnd = @"C style comment did not end correctly.";

// The line-terminator characters the C++-style comment scanner stops at: LF, FF, CR, NEL, line
// separator, and paragraph separator.
static const unichar kLineTerminators[] = {0x0a, 0x0c, 0x0d, 0x85, 0x2028, 0x2029};

@implementation CDataScanner

@synthesize data = data;

#pragma mark - Lifecycle

/** @ghidraAddress 0x61968 */
+ (void)initialize {
    if (g_numberCharacterSet == nil) {
        g_numberCharacterSet =
            [NSCharacterSet characterSetWithCharactersInString:kNumberCharacters];
    }
}

/** @ghidraAddress 0x619c8 */
- (instancetype)init {
    self = [super init];
    return self;
}

/** @ghidraAddress 0x61a00 */
- (instancetype)initWithData:(NSData *)someData {
    self = [self init];
    if (self) {
        [self setData:someData];
    }
    return self;
}

#pragma mark - Cursor

/** @ghidraAddress 0x61a60 */
- (NSUInteger)scanLocation {
    return (NSUInteger)(current - start);
}

/** @ghidraAddress 0x61bb8 */
- (void)setScanLocation:(NSUInteger)location {
    current = start + location;
}

/** @ghidraAddress 0x61a80 */
- (NSUInteger)bytesRemaining {
    return (NSUInteger)(end - current);
}

/** @ghidraAddress 0x61bd8 */
- (BOOL)isAtEnd {
    return length <= self.scanLocation;
}

#pragma mark - Data

/** @ghidraAddress 0x61ab0 */
- (void)setData:(NSData *)newData {
    if (data != newData) {
        data = newData;
    }
    if (data == nil) {
        start = nullptr;
        end = nullptr;
        current = nullptr;
        length = 0;
    } else {
        start = (char *)data.bytes;
        end = start + data.length;
        current = start;
        length = data.length;
    }
}

#pragma mark - Scanning single characters

/** @ghidraAddress 0x61c14 */
- (unichar)currentCharacter {
    return (unichar)(unsigned char)*current;
}

/** @ghidraAddress 0x61c28 */
- (unichar)scanCharacter {
    char *scanned = current;
    current = scanned + 1;
    return (unichar)(unsigned char)*scanned;
}

/** @ghidraAddress 0x61c44 */
- (BOOL)scanCharacter:(unichar)character {
    if ((unsigned char)*current == character) {
        ++current;
        return YES;
    }
    return NO;
}

#pragma mark - Scanning strings

/** @ghidraAddress 0x61c74 */
- (BOOL)scanUTF8String:(const char *)string intoString:(NSString *__autoreleasing *)outString {
    size_t stringLength = strlen(string);
    char *cursor = current;
    if ((NSUInteger)(end - cursor) < stringLength) {
        return NO;
    }
    if (strncmp(cursor, string, stringLength) != 0) {
        return NO;
    }
    current = cursor + stringLength;
    if (outString) {
        *outString = [NSString stringWithUTF8String:string];
    }
    return YES;
}

/** @ghidraAddress 0x61d34 */
- (BOOL)scanString:(NSString *)string intoString:(NSString *__autoreleasing *)outString {
    // The comparison uses the string's character length as a byte count, which is exactly the
    // binary's behaviour.
    if ((NSUInteger)(end - current) < string.length) {
        return NO;
    }
    if (strncmp(current, string.UTF8String, string.length) != 0) {
        return NO;
    }
    current += string.length;
    if (outString) {
        *outString = string;
    }
    return YES;
}

/** @ghidraAddress 0x61e34 */
- (BOOL)scanCharactersFromSet:(NSCharacterSet *)set
                   intoString:(NSString *__autoreleasing *)outString {
    char *cursor = current;
    if (cursor < end) {
        while (cursor < end) {
            if (![set characterIsMember:(unichar)(unsigned char)*cursor]) {
                break;
            }
            ++cursor;
        }
        if (cursor != current) {
            if (outString) {
                *outString = [[NSString alloc] initWithBytes:current
                                                      length:cursor - current
                                                    encoding:NSUTF8StringEncoding];
            }
            current = cursor;
            return YES;
        }
    }
    return NO;
}

/** @ghidraAddress 0x61f24 */
- (BOOL)scanUpToString:(NSString *)string intoString:(NSString *__autoreleasing *)outString {
    char *found = strnstr(current, string.UTF8String, end - current);
    if (found == nullptr) {
        return NO;
    }
    if (outString) {
        *outString = [[NSString alloc] initWithBytes:current
                                              length:found - current
                                            encoding:NSUTF8StringEncoding];
    }
    current = found;
    return YES;
}

/** @ghidraAddress 0x61ff0 */
- (BOOL)scanUpToCharactersFromSet:(NSCharacterSet *)set
                       intoString:(NSString *__autoreleasing *)outString {
    char *cursor = current;
    if (cursor < end) {
        while (cursor < end) {
            if ([set characterIsMember:(unichar)(unsigned char)*cursor]) {
                break;
            }
            ++cursor;
        }
        if (cursor != current) {
            if (outString) {
                *outString = [[NSString alloc] initWithBytes:current
                                                      length:cursor - current
                                                    encoding:NSUTF8StringEncoding];
            }
            current = cursor;
            return YES;
        }
    }
    return NO;
}

#pragma mark - Scanning numbers

/** @ghidraAddress 0x620e0 */
- (BOOL)scanNumber:(NSNumber *__autoreleasing *)outNumber {
    NSString *digits = nil;
    if (![self scanCharactersFromSet:g_numberCharacterSet intoString:&digits]) {
        return NO;
    }

    NSNumber *number = nil;
    if ([digits rangeOfString:@"."].location != NSNotFound) {
        // A fractional part makes it a decimal.
        if (outNumber == nullptr) {
            return YES;
        }
        number = [NSDecimalNumber decimalNumberWithString:digits];
    } else if ([digits rangeOfString:@"-"].location != NSNotFound) {
        // A sign but no fractional part makes it a signed integer.
        if (outNumber == nullptr) {
            return YES;
        }
        number = [NSNumber numberWithLongLong:digits.longLongValue];
    } else {
        // No sign and no fractional part makes it an unsigned integer.
        if (outNumber == nullptr) {
            return YES;
        }
        unsigned long long value = strtoull(digits.UTF8String, nullptr, 0);
        number = [NSNumber numberWithUnsignedLongLong:value];
    }
    *outNumber = number;
    return YES;
}

/** @ghidraAddress 0x62244 */
- (BOOL)scanDecimalNumber:(NSDecimalNumber *__autoreleasing *)outNumber {
    NSString *digits = nil;
    if (![self scanCharactersFromSet:g_numberCharacterSet intoString:&digits]) {
        return NO;
    }
    if (outNumber) {
        *outNumber = [NSDecimalNumber decimalNumberWithString:digits];
    }
    return YES;
}

#pragma mark - Scanning raw data

/** @ghidraAddress 0x622e4 */
- (BOOL)scanDataOfLength:(NSUInteger)scanLength
             intoPointer:(const void *_Nullable *_Nullable)outPointer {
    if (self.bytesRemaining < scanLength) {
        return NO;
    }
    if (outPointer) {
        *outPointer = current;
    }
    current += scanLength;
    return YES;
}

/** @ghidraAddress 0x62350 */
- (BOOL)scanDataOfLength:(NSUInteger)scanLength intoData:(NSData *__autoreleasing *)outData {
    if (self.bytesRemaining < scanLength) {
        return NO;
    }
    if (outData) {
        *outData = [NSData dataWithBytes:current length:scanLength];
    }
    current += scanLength;
    return YES;
}

#pragma mark - Whitespace

/** @ghidraAddress 0x623f0 */
- (void)skipWhitespace {
    char *cursor = current;
    if (cursor < end) {
        while (isspace((unsigned char)*cursor)) {
            ++cursor;
            if (cursor >= end) {
                break;
            }
        }
    }
    current = cursor;
}

#pragma mark - Remaining input

/** @ghidraAddress 0x62480 */
- (NSString *)remainingString {
    NSData *remaining = [NSData dataWithBytes:current length:end - current];
    return [[NSString alloc] initWithData:remaining encoding:NSUTF8StringEncoding];
}

/** @ghidraAddress 0x62510 */
- (NSData *)remainingData {
    return [NSData dataWithBytes:current length:end - current];
}

#pragma mark - Comments

/** @ghidraAddress 0x62d4c */
- (BOOL)scanCStyleComment:(NSString *__autoreleasing *)outComment {
    if (![self scanString:@"/*" intoString:nil]) {
        return NO;
    }
    NSString *inner = nil;
    if (![self scanUpToString:@"*/" intoString:&inner]) {
        [NSException raise:NSGenericException format:@"%@", kMessageCommentNotTerminated];
    }
    if ([inner rangeOfString:@"/*"].location != NSNotFound) {
        [NSException raise:NSGenericException format:@"%@", kMessageCommentNested];
    }
    if (![self scanString:@"*/" intoString:nil]) {
        [NSException raise:NSGenericException format:@"%@", kMessageCommentBadEnd];
    }
    if (outComment) {
        *outComment = inner;
    }
    return YES;
}

/** @ghidraAddress 0x62eac */
- (BOOL)scanCPlusPlusStyleComment:(NSString *__autoreleasing *)outComment {
    if (![self scanString:@"//" intoString:nil]) {
        return NO;
    }
    NSString *terminators =
        [NSString stringWithCharacters:kLineTerminators
                                length:sizeof(kLineTerminators) / sizeof(kLineTerminators[0])];
    NSCharacterSet *terminatorSet = [NSCharacterSet characterSetWithCharactersInString:terminators];
    NSString *inner = nil;
    [self scanUpToCharactersFromSet:terminatorSet intoString:&inner];
    [self scanCharactersFromSet:terminatorSet intoString:nil];
    if (outComment) {
        *outComment = inner;
    }
    return YES;
}

#pragma mark - Diagnostics

/** @ghidraAddress 0x62ff8 */
- (NSUInteger)lineOfScanLocation {
    NSUInteger lines = 0;
    if (start < current) {
        char *cursor = start;
        do {
            if (*cursor == '\r' || *cursor == '\n') {
                ++lines;
            }
            ++cursor;
        } while (cursor < current);
    }
    return lines;
}

/** @ghidraAddress 0x63048 */
- (NSDictionary *)userInfoForScanLocation {
    // Count the line breaks before the cursor and track the start of the current line. The line
    // start is set one byte before each line break, which is the binary's own arithmetic.
    NSUInteger numberOfLines = 0;
    char *lineStart = start;
    char *cursor = current;
    if (start < current) {
        char *scan = start;
        do {
            if (*scan == '\r' || *scan == '\n') {
                ++numberOfLines;
                lineStart = scan - 1;
            }
            ++scan;
        } while (scan < current);
    }
    NSUInteger column = (NSUInteger)(cursor - lineStart);

    NSUInteger location = self.scanLocation;
    NSUInteger beforeStart =
        (location <= kSnippetContextLength) ? 0 : location - kSnippetContextLength;
    NSRange beforeRange =
        NSIntersectionRange(NSMakeRange(beforeStart, location), NSMakeRange(0, self.data.length));
    NSRange afterRange = NSIntersectionRange(NSMakeRange(location, kSnippetContextLength),
                                             NSMakeRange(0, self.data.length));

    NSString *before = [[NSString alloc] initWithData:[self.data subdataWithRange:beforeRange]
                                             encoding:NSUTF8StringEncoding];
    NSString *after = [[NSString alloc] initWithData:[self.data subdataWithRange:afterRange]
                                            encoding:NSUTF8StringEncoding];
    NSString *snippet = [NSString stringWithFormat:kSnippetFormat, before, after];

    return @{
        kUserInfoKeyLine : @(numberOfLines),
        kUserInfoKeyCharacter : @(column),
        kUserInfoKeyLocation : @(location),
        kUserInfoKeySnippet : snippet
    };
}

@end
