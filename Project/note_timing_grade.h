/** @file
 * The note hit-timing classifier used by the gameplay renderer.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000); all @ghidraAddress values are
 * offsets relative to that image base. This is a genuine free function: it takes no object
 * receiver, touches no memory, and the binary carries no RTTI, embedded source path, or owning
 * class for it, so the reconstruction rules' search for an owning class is exhausted. The basename
 * is inferred because the shipped binary embeds no @c __FILE__ path. Called from
 * @c -[MarkerTestView draw] at 0x80fa4.
 */

#ifndef NOTE_TIMING_GRADE_H
#define NOTE_TIMING_GRADE_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Classifies a note's hit timing into a judgement grade from its frame delta.
 *
 * Each grade is an unsigned in-range test of @p nDeltaFrames plus a bias, the standard
 * "is x within [-bias, limit-bias)" idiom, applied tightest window first so the best matching
 * window wins. The windows are asymmetric and grow more so as they widen: each is one frame wider
 * on the early side, and the outermost band is markedly lopsided (115 frames early against 84
 * late), which is deliberate tuning rather than an off-by-one. The compiler emitted the whole
 * function without branches, as a chain of four @c CSEL instructions at 0x1ab524..0x1ab540.
 *
 * The two failure grades are distinct, so a caller can tell an early miss from a late one.
 *
 * @param nDeltaFrames The signed hit offset in frames; negative is early, positive is late.
 * @return The judgement grade, tightest window first:
 *         5 within [-12, +11] (best); 4 within [-24, +23]; 3 within [-48, +47];
 *         2 within [-115, +84]; 1 outside all windows and late; 0 outside all windows and early.
 * @ghidraAddress 0x1ab4fc
 */
unsigned char ClassifyNoteTimingGrade(int nDeltaFrames);

#ifdef __cplusplus
}
#endif

#endif /* NOTE_TIMING_GRADE_H */

// code: language=C
// kate: hl C;
// vim: set ft=c :
