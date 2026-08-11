/** @file
 * The combo-number display maths helpers used by @c MainGameRenderer(Pad)::renderCombo_.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000); all @ghidraAddress values are
 * offsets relative to that image base. These are free functions: none takes an object receiver,
 * and the binary carries no RTTI, embedded source path, or owning class for them. They read a set
 * of shared read-only tables in @c __const that describe how a combo number's digits scale and
 * shift, how the combo burst animation scales and moves per frame, and the easing curves those
 * animations follow. The basename is inferred because the shipped binary embeds no @c __FILE__
 * path.
 */

#pragma once

#include <CoreGraphics/CGGeometry.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Looks up the combo-number scale factor for an animation step and digit count.
 *
 * Both inputs saturate rather than wrap: a step above 10 reuses column 10, and a count above 4
 * reuses row 3. A count of 0 short-circuits to 0.0f.
 * @param dwStep The animation or decay step, clamped to 0..10.
 * @param dwDigitCount The number of combo digits, clamped to 1..4; 0 returns 0.0f.
 * @return The scale factor, or 0.0f when @p dwDigitCount is 0.
 * @ghidraAddress 0x1db98
 */
float GetComboScaleByCount(unsigned int dwStep, unsigned int dwDigitCount);

/**
 * @brief Looks up the combo-number scale factor for one digit position.
 *
 * The row counts digits from the right: row = count - index - 1, so index 0 maps to the highest
 * row. The step saturates to 0..10, but an out-of-range count or index is rejected with 0.0f
 * rather than clamped.
 * @param dwStep The animation or decay step, clamped to 0..10.
 * @param dwDigitCount The number of combo digits; valid 1..4.
 * @param nDigitIndex The 0-based digit position.
 * @return The scale factor, or 0.0f when either index is out of range.
 * @ghidraAddress 0x1dbd4
 */
float GetComboScaleByDigit(unsigned int dwStep, unsigned int dwDigitCount, int nDigitIndex);

/**
 * @brief Returns the pixel offset applied to one combo digit, or 0 when it does not apply.
 *
 * The two non-zero results are -40 (when @p nValue matches the slot one past the digit) and -20
 * (when it matches the digit's own slot); every other case, and any out-of-range count or index,
 * yields 0.
 * @param nValue The position being tested against the digit slot.
 * @param dwDigitCount The number of combo digits; valid 1..4.
 * @param nDigitIndex The 0-based digit position.
 * @return 0, -20, or -40.
 * @ghidraAddress 0x1dc18
 */
int GetComboDigitOffset(int nValue, unsigned int dwDigitCount, int nDigitIndex);

/**
 * @brief Computes the combo fade factor for an animation step: a linear ramp from 0.3 to 0.0.
 *
 * Steps 0..2 hold at 0.3; steps 3..8 ramp down by 0.05 each to 0.0; steps above 8 return 0.0.
 * @param dwStep The animation step.
 * @return The fade factor.
 * @ghidraAddress 0x1dc54
 */
float GetComboFadeFactor(unsigned int dwStep);

/**
 * @brief Computes the combo scale factor for an animation step: a linear ramp from 1.0 to 1.16.
 *
 * The step saturates at 8, so any step at or above 8 returns 1.16.
 * @param dwStep The animation step, saturated to 0..8.
 * @return The scale factor.
 * @ghidraAddress 0x1dc94
 */
float GetComboScaleFactor(unsigned int dwStep);

/**
 * @brief Returns the number of animation frames defined for a combo animation group.
 * @param dwAnimGroup The animation group index; valid 0..4.
 * @return The frame count, or 0 when the group index is out of range.
 * @ghidraAddress 0x1dcbc
 */
int GetComboAnimFrameCount(unsigned int dwAnimGroup);

/**
 * @brief Returns the per-frame combo burst scale for one of the five animation groups.
 * @param dwAnimGroup The animation group selector; valid 0..4.
 * @param nFrameIndex The frame within the group; negative is rejected and the upper bound is the
 *   group's frame count.
 * @return The scale for that frame, or 0.0f when either index is out of range.
 * @ghidraAddress 0x1dcdc
 */
float GetComboAnimScale(unsigned int dwAnimGroup, int nFrameIndex);

/**
 * @brief Returns the screen position for one frame of a combo animation group.
 *
 * The table stores packed signed 16-bit x/y pairs that are sign-extended and converted to the
 * @c CGPoint doubles, so a negative coordinate is meaningful.
 * @param dwAnimGroup The animation group selector; valid 0..4.
 * @param nFrameIndex The frame within the group; negative is rejected and the upper bound is the
 *   group's frame count.
 * @return The frame's position, or @c CGPointZero for any out-of-range input.
 * @ghidraAddress 0x1dd80
 */
CGPoint GetComboAnimPosition(unsigned int dwAnimGroup, int nFrameIndex);

/**
 * @brief Evaluates a piecewise-linear combo animation curve at @p flTime.
 *
 * Each frame owns up to four keyframes; a keyframe with a negative x terminates the list, which is
 * how a curve uses fewer than four slots. The result is the keyframe y when x matches @p flTime
 * exactly, a linear interpolation between the bracketing keyframes otherwise, and 0.0f when
 * @p flTime falls before the first keyframe or past the last.
 * @param flTime The curve input, compared against the keyframe x values.
 * @param dwAnimGroup The curve table selector; valid 0..4.
 * @param nFrameIndex The frame's curve within the group.
 * @return The interpolated value, or 0.0f on any reject path.
 * @ghidraAddress 0x1de54
 */
float EvalComboAnimCurve(float flTime, unsigned int dwAnimGroup, int nFrameIndex);

/**
 * @brief Evaluates a four-keyframe piecewise-linear scale curve at @p flTime.
 *
 * Unlike @c EvalComboAnimCurve there is no negative-x sentinel: all four keyframe slots are always
 * live, and the function is indexed by a single curve selector rather than a group and frame.
 * @param flTime The curve input, compared against the keyframe x values.
 * @param dwCurveIndex The curve selector; valid 0..4.
 * @return The interpolated value, or 0.0f on any reject path.
 * @ghidraAddress 0x1dff0
 */
float EvalComboScaleCurve(float flTime, unsigned int dwCurveIndex);

#ifdef __cplusplus
}
#endif

// code: language=C++
// kate: hl C++;
// vim: set ft=cpp :
