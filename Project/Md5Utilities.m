#import "Md5Utilities.h"

#include <string.h>

#import <CommonCrypto/CommonDigest.h>

// The per-byte format, from the CFString at 0x2d8660.
static NSString *const kHexByteFormat = @"%02x";

// The capacity the digest string is built with, an immediate at 0x7f1d8. It is exactly the finished
// length: sixteen digest bytes at two characters each.
static const NSUInteger kMd5HexStringCapacity = 32;

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
