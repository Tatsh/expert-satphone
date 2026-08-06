/** @file
 * The C Blowfish implementation @c BFCodec wraps.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: declarations only. The five routines below are named in the Ghidra
 * database and reached from @c BFCodec ; none of their bodies is reconstructed.
 */

#ifndef BFCODECCONTEXT_H
#define BFCODECCONTEXT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** @brief The cipher's key schedule. Opaque; the metadata types it @c ^{T_BLOWFISH=} . */
typedef struct T_BLOWFISH BFCodecContext;

/**
 * @brief Allocates a key schedule.
 * @return The new context.
 * @ghidraAddress 0x93b34
 */
BFCodecContext *AllocContext(void);

/**
 * @brief Releases a key schedule.
 * @param pCtx The context.
 * @ghidraAddress 0x93b64
 */
void FreeContext(BFCodecContext *pCtx);

/**
 * @brief Returns a key schedule to its initial state.
 * @param pCtx The context.
 * @ghidraAddress 0x93b70
 */
void ClearContext(BFCodecContext *pCtx);

/**
 * @brief Expands a key into the schedule.
 * @param pCtx The context.
 * @param pbKey The key material.
 * @param nKeyLength The key's length in bytes.
 * @ghidraAddress 0x93b88
 */
void SetKey(BFCodecContext *pCtx, const uint8_t *pbKey, int nKeyLength);

/**
 * @brief Encrypts one 64-bit block in place, as two 32-bit halves.
 * @param pCtx The context.
 * @param pqwLeft The block's left half.
 * @param pqwRight The block's right half.
 * @ghidraAddress 0x93db0
 */
void EncipherBlock(BFCodecContext *pCtx, uint64_t *pqwLeft, uint64_t *pqwRight);

/**
 * @brief Decrypts one 64-bit block in place, as two 32-bit halves.
 * @param pCtx The context.
 * @param pqwLeft The block's left half.
 * @param pqwRight The block's right half.
 * @ghidraAddress 0x93e28
 */
void DecipherBlock(BFCodecContext *pCtx, uint64_t *pqwLeft, uint64_t *pqwRight);

#ifdef __cplusplus
}
#endif

#endif

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
