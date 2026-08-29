#pragma once

#include <cstdint>

/**
 * @file
 * @brief The interleaved sprite-quad vertex and the helper that fills a quad's texture coordinates
 * and colour.
 *
 * Reconstructed from Ghidra program Jubeat, image base 0x100000000; all @ghidraAddress values are
 * offsets relative to that base. Neither @c SpriteVertex nor @c SetQuadTexCoordsAndAlpha carries
 * RTTI or an embedded @c __FILE__ path, so the names are inferred from the sole caller
 * (@c Texture2D::drawSprite:atPoint:scale:rotate:anchor:transform:alpha:) and the field usage
 * rather than confirmed against runtime metadata.
 */

/**
 * @brief One vertex of an interleaved sprite quad: position, texture coordinate, and four 8-bit
 *        colour channels.
 *
 * The engine draws a sprite as four consecutive vertices at a stride of @c 0x18 bytes. The ivar's
 * runtime type encoding is @c ^{?=fffffCCCC}, so the colour is four separate byte channels rather
 * than one packed word.
 */
struct SpriteVertex {
    float fX; /*!< Position X, written by the caller. */           // +0x00
    float fY; /*!< Position Y, written by the caller. */           // +0x04
    float fZ; /*!< Position Z, untouched by the 2D sprite path. */ // +0x08
    float flU; /*!< Texture U coordinate. */                       // +0x0c
    float flV; /*!< Texture V coordinate. */                       // +0x10
    std::uint8_t byRed; /*!< Red channel, 0-255. */                // +0x14
    std::uint8_t byGreen; /*!< Green channel, 0-255. */            // +0x15
    std::uint8_t byBlue; /*!< Blue channel, 0-255. */              // +0x16
    std::uint8_t byAlpha; /*!< Alpha channel, 0-255. */            // +0x17
};

/**
 * @brief How a sprite quad's texture coordinates are permuted across its four vertices.
 *
 * Any value outside 0..5 is treated as @c SpriteTransformNone. The two transposing modes are the
 * pair of 90-degree rotations; which is clockwise depends on the render target's Y-axis direction
 * and so is not distinguished here.
 */
enum SpriteTransform {
    SpriteTransformNone = 0,          /*!< Identity: no rotation or mirroring. */
    SpriteTransformTranspose = 1,     /*!< Transposed (the U and V axes swapped). */
    SpriteTransformRotate180 = 2,     /*!< Rotated 180 degrees. */
    SpriteTransformTransposeFlip = 3, /*!< Transposed the other way. */
    SpriteTransformMirrorV = 4,       /*!< Mirrored in the V (vertical) texture axis. */
    SpriteTransformMirrorU = 5,       /*!< Mirrored in the U (horizontal) texture axis. */
};

/**
 * @brief Writes the texture coordinates and packed colour of one four-vertex sprite quad.
 *
 * Clamps @p flAlpha into [0, 1] (a NaN propagates, matching the binary's unordered compare),
 * lays the (@p flU0, @p flV0)-(@p flU1, @p flV1) texture rectangle across the four vertices in the
 * order dictated by @p bTransform, and broadcasts the alpha byte into every RGBA channel of each
 * vertex's colour. The vertices' positions (@c fX, @c fY, @c fZ) are left untouched.
 *
 * @param flU0 Left texture coordinate, normalised.
 * @param flV0 Top texture coordinate, normalised.
 * @param flU1 Right texture coordinate, normalised.
 * @param flV1 Bottom texture coordinate, normalised.
 * @param flAlpha Opacity, clamped to 0..1.
 * @param pQuadVerts The first of four consecutive vertices to fill.
 * @param bTransform The texture-coordinate permutation to apply.
 * @ghidraAddress 0xea2c
 */
void SetQuadTexCoordsAndAlpha(float flU0,
                              float flV0,
                              float flU1,
                              float flV1,
                              float flAlpha,
                              SpriteVertex *pQuadVerts,
                              SpriteTransform bTransform);
