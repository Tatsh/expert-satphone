#include "neEngineBridge.h"

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
