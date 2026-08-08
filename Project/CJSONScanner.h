/** @file
 * TouchJSON's scanner, which does the actual parsing.
 *
 * Reconstructed from Ghidra program Jubeat (class CJSONScanner, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * This is third-party code bundled into the application, so the names are TouchJSON's rather than
 * Konami's. @c CJSONScanner is a subclass of @c CDataScanner, a byte-oriented scanner that is not
 * yet reconstructed as its own file; it is forward-declared below (see TYPES_PENDING.md) with only
 * the members this class reaches for.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The byte-oriented scanner superclass; not reconstructed as its own file yet, so it is
 * forward-declared here as an @c NSObject subclass exposing only what @c CJSONScanner uses. See
 * TYPES_PENDING.md.
 *
 * The two byte-cursor ivars are named as TouchJSON names them, without an underscore, and are
 * reached directly by @c -scanNotQuoteCharactersIntoString: .
 */
@interface CDataScanner : NSObject {
@protected
    char *current; ///< The next byte the scanner will read.
    char *end;     ///< One past the last byte of the input.
}

/** @brief Points the scanner at some bytes. */
- (void)setData:(nullable NSData *)data;
/** @brief Advances past any whitespace at the cursor. */
- (void)skipWhitespace;
/** @brief The character at the cursor without consuming it. */
- (unichar)currentCharacter;
/** @brief Consumes and returns the character at the cursor. */
- (unichar)scanCharacter;
/** @brief Consumes the cursor character when it matches. */
- (BOOL)scanCharacter:(unichar)character;
/** @brief Consumes a fixed UTF-8 run, optionally returning it. */
- (BOOL)scanUTF8String:(const char *)string intoString:(NSString *_Nullable *_Nullable)outString;
/** @brief Consumes a JSON number literal. */
- (BOOL)scanNumber:(NSNumber *_Nullable *_Nullable)outNumber;
/** @brief The current byte offset. */
- (NSUInteger)scanLocation;
/** @brief Rewinds or advances the cursor to a byte offset. */
- (void)setScanLocation:(NSUInteger)location;
/** @brief Diagnostic user-info describing where the cursor is. */
- (NSDictionary *)userInfoForScanLocation;

@end

/**
 * @brief Scans JSON text into Foundation objects.
 */
@interface CJSONScanner : CDataScanner

/**
 * @brief What a JSON @c null becomes.
 */
@property(nonatomic, strong, nullable) id nullObject;

/**
 * @brief Which text encoding the input is allowed to be in, tried after the BOM sniff fails.
 */
@property(nonatomic) NSUInteger allowedEncoding;

/**
 * @brief Scanning options. Bit 0 keeps scanned containers mutable; bit 1 keeps scanned strings
 * mutable. Both are otherwise copied to immutable.
 */
@property(nonatomic) NSUInteger options;

/**
 * @brief Whether an unrecognised backslash escape is an error rather than a literal character.
 */
@property(nonatomic) BOOL strictEscapeCodes;

/**
 * @brief Primes the shared boxed @c YES and @c NO the scanner returns for @c true and @c false .
 * @ghidraAddress 0x650c8
 */
+ (void)initialize;

/**
 * @brief Builds a scanner with no null object substitution and non-strict escapes.
 * @return The initialised scanner.
 * @ghidraAddress 0x65168
 */
- (instancetype)init;

/**
 * @brief Points the scanner at some JSON text, sniffing its encoding and re-encoding it to UTF-8.
 * @param data The text.
 * @param outError Where to report a failure.
 * @return Whether the data was accepted.
 * @ghidraAddress 0x651f4
 */
- (BOOL)setData:(nullable NSData *)data error:(NSError *_Nullable *_Nullable)outError;

/**
 * @brief Points the scanner at some JSON text, discarding any encoding failure.
 * @param data The text.
 * @ghidraAddress 0x65438
 */
- (void)setData:(nullable NSData *)data;

/**
 * @brief Scans whatever the text describes, dispatching on the first non-space character.
 * @param outObject Where to put the result.
 * @param outError Where to report a failure.
 * @return Whether the scan succeeded.
 * @ghidraAddress 0x65448
 */
- (BOOL)scanJSONObject:(id _Nullable *_Nullable)outObject
                 error:(NSError *_Nullable *_Nullable)outError;

/**
 * @brief Scans, requiring a dictionary.
 * @param outDictionary Where to put the result.
 * @param outError Where to report a failure.
 * @return Whether the scan succeeded.
 * @ghidraAddress 0x65880
 */
- (BOOL)scanJSONDictionary:(NSDictionary *_Nullable *_Nullable)outDictionary
                     error:(NSError *_Nullable *_Nullable)outError;

/**
 * @brief Scans, requiring an array.
 * @param outArray Where to put the result.
 * @param outError Where to report a failure.
 * @return Whether the scan succeeded.
 * @ghidraAddress 0x65ccc
 */
- (BOOL)scanJSONArray:(NSArray *_Nullable *_Nullable)outArray
                error:(NSError *_Nullable *_Nullable)outError;

/**
 * @brief Scans a quoted JSON string, decoding its backslash escapes.
 * @param outString Where to put the result.
 * @param outError Where to report a failure.
 * @return Whether the scan succeeded.
 * @ghidraAddress 0x6611c
 */
- (BOOL)scanJSONStringConstant:(NSString *_Nullable *_Nullable)outString
                         error:(NSError *_Nullable *_Nullable)outError;

/**
 * @brief Scans a JSON number literal.
 * @param outNumber Where to put the result.
 * @param outError Where to report a failure.
 * @return Whether the scan succeeded.
 * @ghidraAddress 0x666b4
 */
- (BOOL)scanJSONNumberConstant:(NSNumber *_Nullable *_Nullable)outNumber
                         error:(NSError *_Nullable *_Nullable)outError;

/**
 * @brief Consumes the run of characters up to the next quote or backslash.
 * @param outString Where to put the run, when the caller wants it.
 * @return Whether any characters were consumed.
 * @ghidraAddress 0x66790
 */
- (BOOL)scanNotQuoteCharactersIntoString:(NSString *_Nullable *_Nullable)outString;

/**
 * @brief Builds an @c NSError in the scanner's domain, with a description and the cursor's user
 * info.
 * @param code The error code.
 * @param description The localised description.
 * @return The error.
 * @ghidraAddress 0x66854
 */
- (NSError *)error:(NSInteger)code description:(NSString *)description;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
