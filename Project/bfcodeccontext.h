/**
 * @file
 * The C++ Blowfish key schedule and block cipher that @c BFCodec wraps.
 *
 * Reconstructed from Ghidra program Jubeat (class BFCodecContext, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The context is the unusual 0x2090-byte layout the binary uses: the 18-entry P-array and the four
 * 256-entry S-boxes are each stored as 64-bit slots holding a zero-extended 32-bit word, rather
 * than the 0x1048 bytes a conventional Blowfish schedule needs. The initialisation constants are
 * genuine Blowfish (the digits of pi), but the round F-function is the shipped variant --
 * @c (S1[a] + S2[b]) ^ (S3[c] + S4[d]) rather than the standard
 * @c ((S1[a] + S2[b]) ^ S3[c]) + S4[d] -- so this is not interoperable with a standard Blowfish.
 */

#pragma once

#include <cstdint>

/**
 * A Blowfish key schedule and the block cipher over it.
 */
class BFCodecContext {
public:
    /**
     * Constructs a zeroed key schedule.
     *
     * The binary's @c AllocContext is @c operator @c new plus a @c bzero of the whole 0x2090-byte
     * context, which is the compiler's lowering of this zero-initialising constructor.
     * @ghidraAddress 0x93b34
     */
    BFCodecContext();

    /**
     * Destroys the schedule.
     *
     * The binary's @c FreeContext is a null-guarded @c operator @c delete with no field cleanup, so
     * the destructor is trivial; the expanded key is left in freed memory exactly as shipped.
     * @ghidraAddress 0x93b64
     */
    ~BFCodecContext() = default;

    /**
     * Returns the whole schedule to its zero state, so it must be re-keyed before reuse.
     * @ghidraAddress 0x93b70
     */
    void clear();

    /**
     * Expands a key into the schedule.
     * @param pbKey The key material.
     * @param nKeyLength The key's length in bytes; used as a modulus, so zero divides by zero.
     * @ghidraAddress 0x93b88
     */
    void setKey(const uint8_t *pbKey, int nKeyLength);

    /**
     * Encrypts one 64-bit block in place, as two 32-bit halves.
     * @param pqwLeft The block's left half.
     * @param pqwRight The block's right half.
     * @ghidraAddress 0x93db0
     */
    void encipherBlock(uint64_t *pqwLeft, uint64_t *pqwRight) const;

    /**
     * Decrypts one 64-bit block in place, as two 32-bit halves.
     * @param pqwLeft The block's left half.
     * @param pqwRight The block's right half.
     * @ghidraAddress 0x93e28
     */
    void decipherBlock(uint64_t *pqwLeft, uint64_t *pqwRight) const;

private:
    static constexpr int kPEntries = 18;     // +0x00, 0x90 bytes
    static constexpr int kSBoxEntries = 256; // each S-box, 0x800 bytes

    // Each word is a zero-extended 32-bit value in a 64-bit slot, matching the binary's layout.
    uint64_t m_aqwP[kPEntries] = {};     // +0x0000
    uint64_t m_aqwS1[kSBoxEntries] = {}; // +0x0090
    uint64_t m_aqwS2[kSBoxEntries] = {}; // +0x0890
    uint64_t m_aqwS3[kSBoxEntries] = {}; // +0x1090
    uint64_t m_aqwS4[kSBoxEntries] = {}; // +0x1890

    // The shipped round function: two S-box sums XORed together, unlike standard Blowfish's
    // add-xor-add. Shared by the cipher and the key expansion in setKey.
    uint64_t roundFunction(uint64_t block) const;

    // One forward 16-round pass, updating (left, right) in place. Shared by encipherBlock and the
    // key expansion in setKey, which chains each output pair back in as the next input.
    void encipherHalves(uint64_t &left, uint64_t &right) const;
};
