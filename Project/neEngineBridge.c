#include "neEngineBridge.h"

float InterpolateFloatByFrame(float flFrom,
                              float flTo,
                              unsigned int nCurrentFrame,
                              unsigned int nStartFrame,
                              unsigned int nEndFrame) {
    // Before or at the start frame: hold at flFrom. The frame comparisons are unsigned (compiled
    // `subs`/`b.ls`), so a negative current frame passed through an int wraps huge and is treated
    // as after the window, not before it.
    if (nCurrentFrame <= nStartFrame) {
        return flFrom;
    }
    // At or after the end frame: hold at flTo.
    if (nEndFrame <= nCurrentFrame) {
        return flTo;
    }
    // Inside the window: a weighted average divided once at the end, exact at both endpoints.
    return ((float)(nCurrentFrame - nStartFrame) * flTo +
            (float)(nEndFrame - nCurrentFrame) * flFrom) /
           (float)(nEndFrame - nStartFrame);
}

float InterpolateFloatByPosition(
    float flCurrent, float flStart, float flEnd, float flFrom, float flTo) {
    // Below the window: hold at the start value. The compiled `b.mi` leaves a NaN position to
    // fall through, matching the ordered comparisons here.
    if (flCurrent < flStart) {
        return flFrom;
    }
    // Above the window: hold at the end value.
    if (flEnd < flCurrent) {
        return flTo;
    }
    // Inside the window: a weighted average divided once at the end, exact at both endpoints.
    return ((flCurrent - flStart) * flTo + (flEnd - flCurrent) * flFrom) / (flEnd - flStart);
}
