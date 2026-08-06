/** @file
 * Free functions and globals shared across the game engine.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * Per the project rules this header holds only genuinely free shared engine functions and globals.
 * Anything that turns out to be an instance or class method belongs in its own class's header
 * instead, and should be moved here-out rather than accumulated here.
 */

#ifndef NEENGINEBRIDGE_H
#define NEENGINEBRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Interpolates linearly between two values across a frame range.
 *
 * Fifteen instructions with no calls, so a genuine free function rather than a method whose
 * receiver was optimised away. Single precision throughout.
 *
 * @param flFrom The value at @c nStartFrame.
 * @param flTo The value at @c nEndFrame.
 * @param nCurrentFrame Where in the range to sample.
 * @param nStartFrame The range's first frame.
 * @param nEndFrame The range's last frame.
 * @return The interpolated value.
 * @ghidraAddress 0x125548
 */
float InterpolateFloatByFrame(float flFrom,
                              float flTo,
                              unsigned int nCurrentFrame,
                              unsigned int nStartFrame,
                              unsigned int nEndFrame);

#ifdef __cplusplus
}
#endif

#endif /* NEENGINEBRIDGE_H */

// code: language=C
// kate: hl C;
// vim: set ft=c :
