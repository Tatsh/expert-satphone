#import "Md5Utilities.h"

#include <string.h>

#import <CommonCrypto/CommonDigest.h>

// The per-byte format, from the CFString at 0x2d8660.
static NSString *const kHexByteFormat = @"%02x";

// The upper-case per-byte format, from the CFString at 0x2d8680.
static NSString *const kHexByteFormatUppercase = @"%02X";

// The capacity the digest string is built with, an immediate at 0x7f1d8. It is exactly the finished
// length: sixteen digest bytes at two characters each.
static const NSUInteger kMd5HexStringCapacity = 32;

// The capacity the SHA-256 digest string is built with, the immediate 0x40 at 0x7f484. It is
// exactly the finished length: thirty-two digest bytes at two characters each.
static const NSUInteger kSha256HexStringCapacity = 64;

NSString *CreateMd5HexStringFromCString(const char *lpcszInput) {
    CC_MD5_CTX context;
    CC_MD5_Init(&context);
    CC_MD5_Update(&context, lpcszInput, (CC_LONG)strlen(lpcszInput));
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &context);

    NSMutableString *hex = [[NSMutableString alloc] initWithCapacity:kMd5HexStringCapacity];
    // The binary emits sixteen separate appendFormat: calls rather than a loop. Written as a loop
    // here because the unrolling carries no information — every iteration is identical but for the
    // digest offset, which runs 0 to 15 without a gap.
    for (int index = 0; index < CC_MD5_DIGEST_LENGTH; ++index) {
        [hex appendFormat:kHexByteFormat, digest[index]];
    }
    // An immutable copy is returned, not the mutable buffer.
    return [NSString stringWithString:hex];
}

NSData *CreateMd5DataFromCString(const char *lpcszInput) {
    CC_MD5_CTX context;
    CC_MD5_Init(&context);
    CC_MD5_Update(&context, lpcszInput, (CC_LONG)strlen(lpcszInput));
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &context);

    // +dataWithBytes:length: already autoreleases, so there is no separate retain/autorelease
    // dance here, unlike most of its siblings in this cluster.
    return [NSData dataWithBytes:digest length:sizeof(digest)];
}

bool VerifyMd5Digest(const void *pvData,
                     unsigned int cbLength,
                     const unsigned char *pbExpectedDigest) {
    CC_MD5_CTX context;
    CC_MD5_Init(&context);
    CC_MD5_Update(&context, pvData, cbLength);
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &context);

    // The binary fully unrolls sixteen byte compares that short-circuit on the first mismatch, so
    // the comparison is not constant time. memcmp keeps the same first-difference short-circuit and
    // the same non-constant-time behaviour. The compiler-emitted stack guard is omitted as an
    // artifact.
    return memcmp(pbExpectedDigest, digest, sizeof(digest)) == 0;
}

NSString *CreateMD5HexString(const void *pvData, unsigned int cbLength) {
    CC_MD5_CTX context;
    CC_MD5_Init(&context);
    CC_MD5_Update(&context, pvData, cbLength);
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &context);

    NSMutableString *hex = [[NSMutableString alloc] initWithCapacity:kMd5HexStringCapacity];
    // The binary emits sixteen separate appendFormat: calls rather than a loop; each passes the
    // digest byte as a stack vararg the decompiler renders invisibly. Written as a loop here
    // because the unrolling carries no information.
    for (int index = 0; index < CC_MD5_DIGEST_LENGTH; ++index) {
        [hex appendFormat:kHexByteFormat, digest[index]];
    }
    // An immutable copy is returned, not the mutable buffer.
    return [NSString stringWithString:hex];
}

NSString *CreateSha256HexStringFromData(NSData *data, bool uppercase) {
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    CC_SHA256_Update(&context, data.bytes, (CC_LONG)data.length);
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);

    NSMutableString *hex = [[NSMutableString alloc] initWithCapacity:kSha256HexStringCapacity];
    // The binary branches once on the flag, then runs one of two otherwise-identical unrolled
    // thirty-two-iteration loops that differ only in the per-byte format string. Written as a
    // single loop with the format chosen once, since the duplication carries no information.
    NSString *format = uppercase ? kHexByteFormatUppercase : kHexByteFormat;
    for (int index = 0; index < CC_SHA256_DIGEST_LENGTH; ++index) {
        [hex appendFormat:format, digest[index]];
    }
    // An immutable copy is returned, not the mutable buffer. The compiler-emitted stack guard is
    // omitted as an artifact.
    return [NSString stringWithString:hex];
}
