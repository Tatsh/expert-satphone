#import "Crypto.h"

#include <CommonCrypto/CommonCrypto.h>

// One byte rendered as two lower-case hexadecimal digits, from the CFString at 0x2d8660.
static NSString *const kHexByteFormat = @"%02x";

// The cipher is AES-128 with PKCS#7 padding and no initialisation vector.
static const size_t kAESKeyLength = kCCKeySizeAES128;
// The output buffer is the input's length plus one block, to leave room for the padding.
static const size_t kPaddingHeadroom = kCCBlockSizeAES128;

@implementation Crypto

/** @ghidraAddress 0x266a44 */
+ (NSData *)createHash:(NSData *)data {
    unsigned char digest[CC_SHA1_DIGEST_LENGTH] = {};
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    return [NSData dataWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
}

/** @ghidraAddress 0x266b14 */
+ (NSString *)sha1:(NSString *)string {
    // Yes, the UTF-8 bytes with the UTF-16 character count. Correct only for pure ASCII.
    NSData *data = [NSData dataWithBytes:[string cStringUsingEncoding:NSUTF8StringEncoding]
                                  length:string.length];

    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);

    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; ++i) {
        [hex appendFormat:kHexByteFormat, digest[i]];
    }
    return hex;
}

/** @ghidraAddress 0x266c9c */
+ (NSString *)sha256:(NSString *)string {
    // The same length mismatch as +sha1: above.
    NSData *data = [NSData dataWithBytes:[string cStringUsingEncoding:NSUTF8StringEncoding]
                                  length:string.length];

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);

    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; ++i) {
        [hex appendFormat:kHexByteFormat, digest[i]];
    }
    return hex;
}

/** @ghidraAddress 0x266e24 */
+ (NSData *)cryptorToData:(unsigned int)cryptor value:(NSData *)value key:(NSData *)key {
    NSMutableData *output = [NSMutableData dataWithLength:value.length + kPaddingHeadroom];

    size_t movedLength = 0;
    // The key length is the constant, not key.length — a key of any other size is truncated or
    // over-read. No initialisation vector, so this is ECB.
    CCCryptorStatus status = CCCrypt(cryptor,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     key.bytes,
                                     kAESKeyLength,
                                     nullptr,
                                     value.bytes,
                                     value.length,
                                     output.mutableBytes,
                                     output.length,
                                     &movedLength);
    if (status != kCCSuccess) {
        return nil;
    }
    return [NSData dataWithBytes:output.bytes length:movedLength];
}

@end
