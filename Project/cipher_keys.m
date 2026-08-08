#import "cipher_keys.h"

#include <string.h>

#import <CommonCrypto/CommonDigest.h>

// The seven key factories share a 16-byte rodata literal at 0x28f980 and finish each passphrase
// with register immediates, so no full passphrase is contiguous in the file. Each constant below is
// the plaintext the binary's stack assembly spells; see cipher_keys.h. All are hashed over strlen
// bytes rather than sizeof, so the trailing NUL is excluded.
static const char kTextureCipherPassphrase[] = "copious plus knit ripples";
static const char kTuneInfoCipherPassphrase[] = "Konami Bemani Mobile iOS";
static const char kSaveDataCipherPassphrase[] = "js^_Yjs5ea`YUe6FQSAH;@S";
static const char kLabUrlCipherPassphrase[] = "js^_YjfYXH`_]MQM;6.";
static const char kMissionDataCipherPassphrase[] = "jubeatmissiondata";

// The binary open-codes this CC_MD5 sequence in every factory rather than sharing a helper; it is
// byte-for-byte CreateMd5DataFromCString, but kept inline here to match the disassembly.
static NSData *Md5DataOfPassphrase(const char *passphrase) {
    CC_MD5_CTX context;
    CC_MD5_Init(&context);
    CC_MD5_Update(&context, passphrase, (CC_LONG)strlen(passphrase));
    unsigned char key[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(key, &context);
    // +dataWithBytes:length: already autoreleases; there is no separate autorelease tail call.
    return [NSData dataWithBytes:key length:sizeof(key)];
}

NSData *CreateTextureCipherKey(void) {
    return Md5DataOfPassphrase(kTextureCipherPassphrase);
}

NSData *CreateTuneInfoCipherKey(void) {
    return Md5DataOfPassphrase(kTuneInfoCipherPassphrase);
}

NSData *CreateSaveDataCipherKey(void) {
    return Md5DataOfPassphrase(kSaveDataCipherPassphrase);
}

NSData *CreateLabUrlCipherKey(void) {
    return Md5DataOfPassphrase(kLabUrlCipherPassphrase);
}

NSData *CreateMissionDataCipherKey(void) {
    return Md5DataOfPassphrase(kMissionDataCipherPassphrase);
}
