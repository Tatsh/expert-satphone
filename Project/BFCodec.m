#import "BFCodec.h"

// Blowfish's block size, and the width of the length trailer that follows the ciphertext.
enum {
    kBlockLength = 8,
    kBlockMask = kBlockLength - 1,
};

// The chaining vector is a literal, written byte by byte by -cipherInit:length:. It does not depend
// on the key, so two buffers encrypted with the same key chain from the same place.
static const unsigned char kFixedChainVector[kBlockLength] = {
    0xe3, 0xda, 0x2c, 0x66, 0x31, 0x85, 0xa0, 0x64};

// Reads the next four plaintext bytes as a big-endian word, substituting zero once the plaintext
// runs out — which is how the final partial block gets its padding.
static inline uint64_t
TakeBigEndianWord(const unsigned char *bytes, unsigned int length, unsigned int *position) {
    uint64_t word = 0;
    for (int i = 0; i < 4; ++i) {
        word <<= 8;
        if (*position < length) {
            word |= bytes[*position];
            ++*position;
        }
    }
    return word;
}

// Writes a word back as four big-endian bytes.
static inline void PutBigEndianWord(unsigned char *bytes, uint64_t word) {
    bytes[0] = (unsigned char)(word >> 24);
    bytes[1] = (unsigned char)(word >> 16);
    bytes[2] = (unsigned char)(word >> 8);
    bytes[3] = (unsigned char)word;
}

@implementation BFCodec {
    unsigned char _iv[kBlockLength];
    BFCodecContext *_blf;
}

/** @ghidraAddress 0x94978 */
- (instancetype)init {
    self = [super init];
    if (self) {
        // Zeroed as one 64-bit store, not eight byte stores.
        *(uint64_t *)_iv = 0;
        _blf = AllocContext();
    }
    return self;
}

/** @ghidraAddress 0x949e0 */
- (void)cipherInit:(const char *)key length:(int)length {
    ClearContext(_blf);
    memcpy(_iv, kFixedChainVector, sizeof(_iv));
    SetKey(_blf, (const uint8_t *)key, length);
}

/** @ghidraAddress 0x94a58 */
- (void)cipherInit:(NSData *)key {
    // A nil key leaves the previous key and chaining vector in place rather than clearing them.
    if (!key) {
        return;
    }
    [self cipherInit:key.bytes length:(int)key.length];
}

/** @ghidraAddress 0x94aec */
- (unsigned int)encipher:(NSMutableData *)data {
    unsigned int plainLength = (unsigned int)data.length;
    // Rounded up to a block, plus one more block for the trailer.
    unsigned int paddedLength = (plainLength + kBlockLength + kBlockMask) & ~kBlockMask;
    data.length = paddedLength;

    unsigned char *bytes = data.mutableBytes;

    unsigned int offset = 0;
    if (plainLength != 0) {
        // The chain starts from the fixed vector, read big-endian as two words.
        uint64_t chainLeft =
            ((uint64_t)_iv[0] << 24) | ((uint64_t)_iv[1] << 16) | ((uint64_t)_iv[2] << 8) | _iv[3];
        uint64_t chainRight =
            ((uint64_t)_iv[4] << 24) | ((uint64_t)_iv[5] << 16) | ((uint64_t)_iv[6] << 8) | _iv[7];

        unsigned int position = 0;
        do {
            uint64_t left = TakeBigEndianWord(bytes, plainLength, &position) ^ chainLeft;
            uint64_t right = TakeBigEndianWord(bytes, plainLength, &position) ^ chainRight;

            EncipherBlock(_blf, &left, &right);

            PutBigEndianWord(bytes + offset, left);
            PutBigEndianWord(bytes + offset + 4, right);

            // The ciphertext becomes the next block's chaining value.
            chainLeft = left;
            chainRight = right;
            offset += kBlockLength;
        } while (position < plainLength);
    }

    // The trailer: the plaintext's length, then the ciphertext's, both big-endian. The second is
    // written as (plainLength + 7) with its low byte masked, which is the same rounding as above.
    PutBigEndianWord(bytes + offset, plainLength);
    PutBigEndianWord(bytes + offset + 4, (plainLength + kBlockMask) & ~kBlockMask);

    return paddedLength;
}

/** @ghidraAddress 0x9510c */
- (void)dealloc {
    // The vector is wiped before the schedule is released, so neither outlives the codec.
    *(uint64_t *)_iv = 0;
    FreeContext(_blf);
}

@end
