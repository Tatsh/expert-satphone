/**
 * @file
 * TouchJSON's low-level byte scanner.
 *
 * Reconstructed from Ghidra program Jubeat (class CDataScanner, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * This is third-party code bundled into the application, so the names are TouchJSON's rather than
 * Konami's. @c CDataScanner walks the bytes of an @c NSData with a raw @c char cursor, and is the
 * superclass of the JSON-aware @c CJSONScanner . The ivars carry no leading underscore, which is
 * TouchJSON's convention rather than this tree's.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A byte-oriented scanner over an @c NSData 's bytes.
 *
 * The scanner keeps three raw pointers into the data: @c start (the first byte), @c end (one past
 * the last byte), and @c current (the next byte to read). @c scanLocation is the cursor's byte
 * offset, @c current @c - @c start . The scan-and-advance methods move @c current forward and
 * return whether they matched.
 */
@interface CDataScanner : NSObject {
@protected
    NSData *data;      ///< The bytes being scanned; retained.
    char *start;       ///< The first byte of the input.
    char *end;         ///< One past the last byte of the input.
    char *current;     ///< The next byte the scanner will read.
    NSUInteger length; ///< The byte count of @c data .
}

/**
 * The bytes being scanned. Setting new bytes resets the cursor to the start.
 * @note The getter is at 0x61aa0 and the setter at 0x61ab0.
 */
@property(nonatomic, strong, nullable) NSData *data;

/**
 * The cursor's byte offset from the start of the data.
 * @note The getter is at 0x61a60 and the setter at 0x61bb8.
 */
@property(nonatomic) NSUInteger scanLocation;

/**
 * The number of bytes between the cursor and the end of the data.
 * @note The getter is at 0x61a80.
 */
@property(nonatomic, readonly) NSUInteger bytesRemaining;

/**
 * Whether the cursor has reached or passed the end of the data.
 * @note The getter is at 0x61bd8.
 */
@property(nonatomic, readonly) BOOL isAtEnd;

/**
 * Primes the shared character set of number-literal characters.
 * @ghidraAddress 0x61968
 */
+ (void)initialize;

/**
 * Initialises an empty scanner with no data.
 * @return The initialised scanner.
 * @ghidraAddress 0x619c8
 */
- (instancetype)init;

/**
 * Initialises the scanner and points it at some bytes.
 * @param someData The bytes to scan.
 * @return The initialised scanner.
 * @ghidraAddress 0x61a00
 */
- (instancetype)initWithData:(nullable NSData *)someData;

/**
 * The character at the cursor without consuming it.
 * @return The byte at the cursor, widened to a @c unichar .
 * @ghidraAddress 0x61c14
 */
- (unichar)currentCharacter;

/**
 * Consumes and returns the character at the cursor.
 * @return The byte at the cursor, widened to a @c unichar .
 * @ghidraAddress 0x61c28
 */
- (unichar)scanCharacter;

/**
 * Consumes the cursor character when it matches.
 * @param character The character to match.
 * @return Whether the cursor character matched and was consumed.
 * @ghidraAddress 0x61c44
 */
- (BOOL)scanCharacter:(unichar)character;

/**
 * Consumes a fixed UTF-8 run, optionally returning it as a string.
 * @param string The NUL-terminated bytes to match at the cursor.
 * @param outString Where to return the matched run, when the caller wants it.
 * @return Whether the run matched and was consumed.
 * @ghidraAddress 0x61c74
 */
- (BOOL)scanUTF8String:(const char *)string intoString:(NSString *_Nullable *_Nullable)outString;

/**
 * Consumes a fixed string, optionally returning it.
 * @param string The string to match at the cursor.
 * @param outString Where to return the matched string, when the caller wants it.
 * @return Whether the string matched and was consumed.
 * @ghidraAddress 0x61d34
 */
- (BOOL)scanString:(NSString *)string intoString:(NSString *_Nullable *_Nullable)outString;

/**
 * Consumes the run of characters that are members of a set.
 * @param set The set whose members are consumed.
 * @param outString Where to return the consumed run, when the caller wants it.
 * @return Whether any characters were consumed.
 * @ghidraAddress 0x61e34
 */
- (BOOL)scanCharactersFromSet:(NSCharacterSet *)set
                   intoString:(NSString *_Nullable *_Nullable)outString;

/**
 * Consumes everything up to the next occurrence of a string.
 * @param string The delimiter to stop before.
 * @param outString Where to return the skipped-over text, when the caller wants it.
 * @return Whether the delimiter was found.
 * @ghidraAddress 0x61f24
 */
- (BOOL)scanUpToString:(NSString *)string intoString:(NSString *_Nullable *_Nullable)outString;

/**
 * Consumes everything up to the next character that is a member of a set.
 * @param set The set whose first member stops the scan.
 * @param outString Where to return the skipped-over text, when the caller wants it.
 * @return Whether any characters were consumed.
 * @ghidraAddress 0x61ff0
 */
- (BOOL)scanUpToCharactersFromSet:(NSCharacterSet *)set
                       intoString:(NSString *_Nullable *_Nullable)outString;

/**
 * Consumes a number literal, decoding it to an integer or a decimal.
 * @param outNumber Where to return the decoded number, when the caller wants it.
 * @return Whether a number was consumed.
 * @ghidraAddress 0x620e0
 */
- (BOOL)scanNumber:(NSNumber *_Nullable *_Nullable)outNumber;

/**
 * Consumes a number literal, always decoding it to an @c NSDecimalNumber .
 * @param outNumber Where to return the decoded number, when the caller wants it.
 * @return Whether a number was consumed.
 * @ghidraAddress 0x62244
 */
- (BOOL)scanDecimalNumber:(NSDecimalNumber *_Nullable *_Nullable)outNumber;

/**
 * Consumes a fixed number of bytes, returning a pointer into the data.
 * @param scanLength The number of bytes to consume.
 * @param outPointer Where to return the pointer to the consumed bytes, when the caller wants it.
 * @return Whether enough bytes remained.
 * @ghidraAddress 0x622e4
 */
- (BOOL)scanDataOfLength:(NSUInteger)scanLength
             intoPointer:(const void *_Nullable *_Nullable)outPointer;

/**
 * Consumes a fixed number of bytes, returning them as an @c NSData .
 * @param scanLength The number of bytes to consume.
 * @param outData Where to return the consumed bytes, when the caller wants it.
 * @return Whether enough bytes remained.
 * @ghidraAddress 0x62350
 */
- (BOOL)scanDataOfLength:(NSUInteger)scanLength intoData:(NSData *_Nullable *_Nullable)outData;

/**
 * Advances the cursor past any whitespace.
 * @ghidraAddress 0x623f0
 */
- (void)skipWhitespace;

/**
 * The bytes from the cursor to the end, decoded as a UTF-8 string.
 * @return The remaining text.
 * @ghidraAddress 0x62480
 */
- (nullable NSString *)remainingString;

/**
 * The bytes from the cursor to the end.
 * @return The remaining bytes.
 * @ghidraAddress 0x62510
 */
- (NSData *)remainingData;

/**
 * Consumes a C-style block comment (slash-star to star-slash).
 * @param outComment Where to return the comment's inner text, when the caller wants it.
 * @return Whether a comment was consumed.
 * @ghidraAddress 0x62d4c
 */
- (BOOL)scanCStyleComment:(NSString *_Nullable *_Nullable)outComment;

/**
 * Consumes a C++-style @c // comment through to the end of the line.
 * @param outComment Where to return the comment's inner text, when the caller wants it.
 * @return Whether a comment was consumed.
 * @ghidraAddress 0x62eac
 */
- (BOOL)scanCPlusPlusStyleComment:(NSString *_Nullable *_Nullable)outComment;

/**
 * The one-based-ish count of line breaks before the cursor.
 * @return The number of carriage returns and newlines between the start and the cursor.
 * @ghidraAddress 0x62ff8
 */
- (NSUInteger)lineOfScanLocation;

/**
 * Diagnostic user info describing where the cursor is: its line, column, offset, and a
 * snippet marking the position.
 * @return The user-info dictionary.
 * @ghidraAddress 0x63048
 */
- (NSDictionary *)userInfoForScanLocation;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
