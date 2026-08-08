#import "StringUtilities.h"

#include <stdlib.h>

// The sixty-four-character alphabet, from the byte string at 0x2816d5. It resembles base64 but its
// last two characters are '+' and '-', matching neither RFC 4648 nor the URL-safe variant.
static const char kRandomStringCharset[] =
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-";

// The mask applied to each arc4random() value, from the "and w8,w0,#0x3f" at 0x7f048. The alphabet
// is exactly this many characters, so the mask is a bias-free index.
static const uint32_t kRandomCharsetMask = 0x3f;

// The single-character format the binary passes to -appendFormat: per character.
static NSString *const kCharacterFormat = @"%c";

NSString *CreateRandomString(NSUInteger length) {
    if (length == 0) {
        // The shared empty string constant at 0x2d42e0; this path never allocates.
        return @"";
    }

    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:length];
    for (NSUInteger index = 0; index < length; ++index) {
        char character = kRandomStringCharset[arc4random() & kRandomCharsetMask];
        [result appendFormat:kCharacterFormat, character];
    }
    // An immutable copy is returned, not the mutable buffer.
    return [NSString stringWithString:result];
}

NSString *CreateUrlEncodedString(NSString *string) {
    if (string == nil) {
        return nil;
    }
    NSCharacterSet *allowed = NSCharacterSet.alphanumericCharacterSet;
    return [string stringByAddingPercentEncodingWithAllowedCharacters:allowed];
}
