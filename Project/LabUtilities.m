#import "LabUtilities.h"

#include <string.h>

#import <CommonCrypto/CommonDigest.h>

#import "BFCodec.h"

// The passphrase the Lab key is derived from. The compiler materialises this on the stack rather
// than referencing it — a q-register store of the sixteen bytes at 0x28f9b0, then a 32-bit
// immediate 0x002e363b at the next word, which is ";6." and its terminator little-endian. The
// effect, and probably the intent, is that the passphrase does not appear in the binary as a
// contiguous string.
//
// There is a separate CreateLabUrlCipherKey at 0x7f9b0 that derives the same key. This function
// does not call it; the derivation below is open-coded but byte-for-byte identical.
static const char kLabCipherPassphrase[] = "js^_YjfYXH`_]MQM;6.";

NSMutableData *CreateLabEncryptedData(NSString *pszString) {
    if (pszString == nil) {
        return nil;
    }

    // A mutable copy is required because -encipher: works in place. The returned object is this
    // same buffer, not a copy of it, so a caller could keep mutating the ciphertext.
    NSMutableData *buffer =
        [NSMutableData dataWithData:[pszString dataUsingEncoding:NSUTF8StringEncoding]];

    BFCodec *codec = [[BFCodec alloc] init];

    // The key is the MD5 of the passphrase, hashed over strlen bytes rather than sizeof.
    CC_MD5_CTX context;
    CC_MD5_Init(&context);
    CC_MD5_Update(&context, kLabCipherPassphrase, (CC_LONG)strlen(kLabCipherPassphrase));
    unsigned char key[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(key, &context);

    [codec cipherInit:[NSData dataWithBytes:key length:sizeof(key)]];
    [codec encipher:buffer];
    return buffer;
}
