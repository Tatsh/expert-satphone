/**
 * @file
 * A helper that stores a two-bit value into a packed byte table.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000); all @ghidraAddress values are
 * offsets relative to that image base. This is a genuine free function: it takes a raw byte buffer
 * rather than an object receiver, and the binary carries no RTTI, embedded source path, or owning
 * class for it, so the reconstruction rules' search for an owning class is exhausted. The basename
 * is inferred because the shipped binary embeds no @c __FILE__ path. Called three times from
 * @c -[GameViewController saveScore] at 0x121f8, which packs per-marker state into a compact table.
 */

#ifndef PACKED_BIT_TABLE_H
#define PACKED_BIT_TABLE_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Stores a two-bit value at an entry index into a packed byte table.
 *
 * Four entries share each byte: entry @p nIndex lives at byte @c nIndex>>2 and occupies the two
 * bits at shift @c (nIndex&3)*2. The two bits are written independently, each with its own
 * test-and-mask, and the intermediate byte from the first bit is carried into the second, so there
 * is exactly one load and up to two stores rather than a read-modify-write per bit. Bits belonging
 * to neighbouring entries in the same byte are preserved. There is no bounds check: the caller
 * owns the table's size.
 *
 * @param pbTable The base of the packed byte table.
 * @param nIndex The entry index, not a byte offset.
 * @param nValue The value to store; only bits 0 and 1 are used and higher bits are ignored.
 * @ghidraAddress 0x1ab548
 */
void SetPackedTwoBitValue(unsigned char *pbTable, unsigned int nIndex, unsigned int nValue);

#ifdef __cplusplus
}
#endif

#endif /* PACKED_BIT_TABLE_H */
