#include "packed_bit_table.h"

// Four two-bit entries per byte.
enum {
    kEntriesPerByteShift = 2, // byte index = nIndex >> 2
    kEntryIndexMask = 3,      // entry within the byte = nIndex & 3
    kBitsPerEntry = 2,        // bit shift = (nIndex & 3) * 2, via `ubfiz w9, w1, #1, #2`
};

void SetPackedTwoBitValue(unsigned char *pbTable, unsigned int nIndex, unsigned int nValue) {
    unsigned int byteIndex = nIndex >> kEntriesPerByteShift;
    unsigned int bitShift = (nIndex & kEntryIndexMask) * kBitsPerEntry;

    // Bit 0 of the value. Load once, set or clear the low bit of the entry, and store.
    unsigned char lowMask = (unsigned char)(1 << bitShift);
    unsigned char byte;
    if (nValue & 1) {
        byte = pbTable[byteIndex] | lowMask;
    } else {
        byte = pbTable[byteIndex] & (unsigned char)~lowMask;
    }
    pbTable[byteIndex] = byte;

    // Bit 1 of the value, carrying the intermediate byte forward rather than reloading.
    unsigned char highMask = (unsigned char)(2 << bitShift);
    if ((nValue >> 1) & 1) {
        pbTable[byteIndex] = byte | highMask;
    } else {
        pbTable[byteIndex] = byte & (unsigned char)~highMask;
    }
}
