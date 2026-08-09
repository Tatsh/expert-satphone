#include <stdlib.h>
#include <string.h>

#import "NSData+Base64.h"

// The standard Base64 alphabet, indexed by a six-bit value. From the pooled string at 0x287d97.
static const char kBase64EncodeLookup[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

// The value stored for every byte that is not a Base64 alphabet character. It is 65 rather than a
// sextet's 0..63, so it can never collide with a decoded value; a table entry equal to it marks an
// input byte to be skipped. From the 256-byte table at 0x293b78.
static const unsigned char kBase64InvalidMarker = 65;

// The inverse of the alphabet: each byte maps to its six-bit value, or to kBase64InvalidMarker.
// From the 256-byte table at 0x293b78.
static const unsigned char kBase64DecodeLookup[] = {
    65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
    65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 62, 65, 65, 65, 63,
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 65, 65, 65, 65, 65, 65, 65, 0,  1,  2,  3,  4,  5,  6,
    7,  8,  9,  10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 65, 65, 65, 65, 65,
    65, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48,
    49, 50, 51, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
    65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
    65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
    65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
    65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
    65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
};

// The number of bytes each Base64 quantum of three input bytes expands to.
enum {
    kBase64BytesPerQuantum = 3,
    kBase64CharsPerQuantum = 4,
};

char *NewBase64Encode(const void *pvBuffer, size_t cbLength, size_t *pcbOutputLength) {
    const unsigned char *inputBuffer = (const unsigned char *)pvBuffer;

    // Round the input length up to a whole number of three-byte quanta, then size the output at
    // four characters per quantum plus a trailing NUL.
    size_t quantumCount = cbLength / kBase64BytesPerQuantum;
    if (cbLength != quantumCount * kBase64BytesPerQuantum) {
        ++quantumCount;
    }
    char *outputBuffer = (char *)malloc(quantumCount * kBase64CharsPerQuantum + 1);
    if (outputBuffer == nullptr) {
        return nullptr;
    }

    size_t i = 0;
    size_t j = 0;
    // Whole quanta: three input bytes become four alphabet characters.
    for (; i + kBase64BytesPerQuantum <= cbLength; i += kBase64BytesPerQuantum) {
        unsigned char b0 = inputBuffer[i];
        unsigned char b1 = inputBuffer[i + 1];
        unsigned char b2 = inputBuffer[i + 2];
        outputBuffer[j] = kBase64EncodeLookup[b0 >> 2];
        outputBuffer[j + 1] = kBase64EncodeLookup[((b0 & 0x03) << 4) | (b1 >> 4)];
        outputBuffer[j + 2] = kBase64EncodeLookup[((b1 & 0x0F) << 2) | (b2 >> 6)];
        outputBuffer[j + 3] = kBase64EncodeLookup[b2 & 0x3F];
        j += kBase64CharsPerQuantum;
    }

    if (i + 1 < cbLength) {
        // Two bytes remain: three characters and one '=' pad.
        unsigned char b0 = inputBuffer[i];
        unsigned char b1 = inputBuffer[i + 1];
        outputBuffer[j] = kBase64EncodeLookup[b0 >> 2];
        outputBuffer[j + 1] = kBase64EncodeLookup[((b0 & 0x03) << 4) | (b1 >> 4)];
        outputBuffer[j + 2] = kBase64EncodeLookup[(b1 & 0x0F) << 2];
        outputBuffer[j + 3] = '=';
        j += kBase64CharsPerQuantum;
    } else if (i < cbLength) {
        // One byte remains: two characters and two '=' pads.
        unsigned char b0 = inputBuffer[i];
        outputBuffer[j] = kBase64EncodeLookup[b0 >> 2];
        outputBuffer[j + 1] = kBase64EncodeLookup[(b0 & 0x03) << 4];
        outputBuffer[j + 2] = '=';
        outputBuffer[j + 3] = '=';
        j += kBase64CharsPerQuantum;
    }

    outputBuffer[j] = 0;
    if (pcbOutputLength != nullptr) {
        *pcbOutputLength = j;
    }
    return outputBuffer;
}

void *NewBase64Decode(const char *pszInput, size_t cbLength, size_t *pcbOutputLength) {
    if (cbLength == (size_t)-1) {
        cbLength = strlen(pszInput);
    }

    size_t outputBufferSize =
        ((cbLength + kBase64BytesPerQuantum) / kBase64CharsPerQuantum) * kBase64BytesPerQuantum;
    unsigned char *outputBuffer = (unsigned char *)malloc(outputBufferSize);

    size_t i = 0;
    size_t j = 0;
    while (i < cbLength) {
        // Gather up to four valid sextets, skipping any byte the table marks invalid.
        unsigned char accumulated[kBase64CharsPerQuantum];
        size_t accumulateIndex = 0;
        while (i < cbLength) {
            unsigned char decoded = kBase64DecodeLookup[(unsigned char)pszInput[i++]];
            if (decoded != kBase64InvalidMarker) {
                accumulated[accumulateIndex++] = decoded;
                if (accumulateIndex == kBase64CharsPerQuantum) {
                    break;
                }
            }
        }

        // Reassemble the packed bytes from however many sextets were gathered.
        if (accumulateIndex > 1) {
            outputBuffer[j] = (unsigned char)((accumulated[0] << 2) | (accumulated[1] >> 4));
        }
        if (accumulateIndex > 2) {
            outputBuffer[j + 1] = (unsigned char)((accumulated[1] << 4) | (accumulated[2] >> 2));
        }
        if (accumulateIndex > 3) {
            outputBuffer[j + 2] = (unsigned char)((accumulated[2] << 6) | accumulated[3]);
        }
        // Upstream advances by the sextet count less one; a whole quantum of four sextets writes
        // three bytes. A trailing run of only invalid characters leaves accumulateIndex at zero and
        // wraps this subtraction, exactly as the binary's 64-bit `sVar7 + lVar9 - 1` does.
        j += accumulateIndex - 1;
    }

    if (pcbOutputLength != nullptr) {
        *pcbOutputLength = j;
    }
    return outputBuffer;
}

@implementation NSData (Base64)

+ (NSData *)dataFromBase64String:(NSString *)aString {
    NSData *encoded = [aString dataUsingEncoding:NSASCIIStringEncoding];
    size_t outputLength = 0;
    void *decoded = NewBase64Decode(encoded.bytes, encoded.length, &outputLength);
    NSData *result = [NSData dataWithBytes:decoded length:outputLength];
    free(decoded);
    return result;
}

- (NSString *)base64EncodedString {
    size_t outputLength = 0;
    char *encoded = NewBase64Encode(self.bytes, self.length, &outputLength);
    NSString *result = [[NSString alloc] initWithBytes:encoded
                                                length:outputLength
                                              encoding:NSASCIIStringEncoding];
    free(encoded);
    return result;
}

@end
