#include "note_timing_grade.h"

// The four judgement windows, each expressed as an unsigned in-range test of the frame delta plus
// a bias: a delta d matches when (unsigned)(d + bias) < limit, which is the range [-bias,
// limit-bias). Every window is one frame wider on the early side. The values are the immediates of
// the `add`/`cmp` pairs at 0x1ab4fc..0x1ab53c.
enum {
    kGrade5Bias = 0x0C, // Grade 5 (best): [-12, +11].
    kGrade5Limit = 0x18,
    kGrade4Bias = 0x18, // Grade 4: [-24, +23].
    kGrade4Limit = 0x30,
    kGrade3Bias = 0x30, // Grade 3: [-48, +47].
    kGrade3Limit = 0x60,
    kGrade2Bias = 0x73, // Grade 2: [-115, +84].
    kGrade2Limit = 0xC8,
};

// The grade awarded to each window, and the two distinct miss results.
enum {
    kGradeEarlyMiss = 0, // Outside every window and pressed early.
    kGradeLateMiss = 1,  // Outside every window and pressed late.
    kGrade2 = 2,
    kGrade3 = 3,
    kGrade4 = 4,
    kGrade5 = 5,
};

unsigned char ClassifyNoteTimingGrade(int nDeltaFrames) {
    // The compiler evaluates every candidate up front and selects with a CSEL chain. The base
    // case is the late/early split; each successively tighter window overrides it when it matches.
    unsigned char grade = (nDeltaFrames > 0) ? kGradeLateMiss : kGradeEarlyMiss;
    if ((unsigned int)(nDeltaFrames + kGrade2Bias) < kGrade2Limit) {
        grade = kGrade2;
    }
    if ((unsigned int)(nDeltaFrames + kGrade3Bias) < kGrade3Limit) {
        grade = kGrade3;
    }
    if ((unsigned int)(nDeltaFrames + kGrade4Bias) < kGrade4Limit) {
        grade = kGrade4;
    }
    if ((unsigned int)(nDeltaFrames + kGrade5Bias) < kGrade5Limit) {
        grade = kGrade5;
    }
    return grade;
}
