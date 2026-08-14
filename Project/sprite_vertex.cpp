#include "sprite_vertex.h"

#include <cstdint>

namespace {

// The alpha channel is stored as an 8-bit value, so the clamped opacity scales up by 255.
constexpr float kByteScale255 = 255.0f; // @ghidraAddress 0x28dff4

// A sprite quad is four consecutive vertices.
constexpr int kVerticesPerQuad = 4;

} // namespace

/** @ghidraAddress 0xea2c */
void SetQuadTexCoordsAndAlpha(float flU0,
                              float flV0,
                              float flU1,
                              float flV1,
                              float flAlpha,
                              SpriteVertex *pQuadVerts,
                              SpriteTransform bTransform) {
    // Clamp the opacity into [0, 1]. A NaN takes the "keep" branch, so it propagates unchanged,
    // exactly as the binary's unordered compares do.
    float flClampedAlpha = 0.0f;
    if (!(flAlpha < 0.0f)) {
        flClampedAlpha = (flAlpha <= 1.0f) ? flAlpha : 1.0f;
    }

    // Lay the texture rectangle across the four vertices in the order the mode selects. Vertex 0 is
    // the origin, 1 is offset in height, 2 in width, and 3 in both.
    switch (bTransform) {
    case SpriteTransformTranspose:
        pQuadVerts[0].flU = flU0;
        pQuadVerts[0].flV = flV1;
        pQuadVerts[1].flU = flU1;
        pQuadVerts[1].flV = flV1;
        pQuadVerts[2].flU = flU0;
        pQuadVerts[2].flV = flV0;
        pQuadVerts[3].flU = flU1;
        pQuadVerts[3].flV = flV0;
        break;
    case SpriteTransformRotate180:
        pQuadVerts[0].flU = flU1;
        pQuadVerts[0].flV = flV1;
        pQuadVerts[1].flU = flU1;
        pQuadVerts[1].flV = flV0;
        pQuadVerts[2].flU = flU0;
        pQuadVerts[2].flV = flV1;
        pQuadVerts[3].flU = flU0;
        pQuadVerts[3].flV = flV0;
        break;
    case SpriteTransformTransposeFlip:
        pQuadVerts[0].flU = flU1;
        pQuadVerts[0].flV = flV0;
        pQuadVerts[1].flU = flU0;
        pQuadVerts[1].flV = flV0;
        pQuadVerts[2].flU = flU1;
        pQuadVerts[2].flV = flV1;
        pQuadVerts[3].flU = flU0;
        pQuadVerts[3].flV = flV1;
        break;
    case SpriteTransformMirrorV:
        pQuadVerts[0].flU = flU0;
        pQuadVerts[0].flV = flV1;
        pQuadVerts[1].flU = flU0;
        pQuadVerts[1].flV = flV0;
        pQuadVerts[2].flU = flU1;
        pQuadVerts[2].flV = flV1;
        pQuadVerts[3].flU = flU1;
        pQuadVerts[3].flV = flV0;
        break;
    case SpriteTransformMirrorU:
        pQuadVerts[0].flU = flU1;
        pQuadVerts[0].flV = flV0;
        pQuadVerts[1].flU = flU1;
        pQuadVerts[1].flV = flV1;
        pQuadVerts[2].flU = flU0;
        pQuadVerts[2].flV = flV0;
        pQuadVerts[3].flU = flU0;
        pQuadVerts[3].flV = flV1;
        break;
    case SpriteTransformNone:
    default:
        pQuadVerts[0].flU = flU0;
        pQuadVerts[0].flV = flV0;
        pQuadVerts[1].flU = flU0;
        pQuadVerts[1].flV = flV1;
        pQuadVerts[2].flU = flU1;
        pQuadVerts[2].flV = flV0;
        pQuadVerts[3].flU = flU1;
        pQuadVerts[3].flV = flV1;
        break;
    }

    // Truncate the scaled opacity to a byte and write it into every channel of every vertex. The
    // binary multiplies by 0x01010101 and does one word store per vertex, which is clang merging
    // the four identical byte stores.
    const std::uint8_t byAlpha =
        static_cast<std::uint8_t>(static_cast<int>(flClampedAlpha * kByteScale255));
    for (int nVert = 0; nVert < kVerticesPerQuad; ++nVert) {
        pQuadVerts[nVert].byRed = byAlpha;
        pQuadVerts[nVert].byGreen = byAlpha;
        pQuadVerts[nVert].byBlue = byAlpha;
        pQuadVerts[nVert].byAlpha = byAlpha;
    }
}
