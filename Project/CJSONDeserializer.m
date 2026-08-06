#import "CJSONDeserializer.h"

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

@end
