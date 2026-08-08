#include "combo_display.h"

#include <cstdint>

#include <CoreGraphics/CGGeometry.h>

namespace {

constexpr int kComboScaleRowCount = 4;
constexpr int kComboScaleColumnCount = 11;
constexpr int kComboCurveKeyframeCount = 4;
constexpr int kComboScaleCurveCount = 5;
constexpr unsigned int kComboAnimGroupCount = 5;

// The two scale tables clamp the step to column 10 and the digit count to row 3 (four rows).
constexpr unsigned int kComboMaxScaleStep = 10;
constexpr unsigned int kComboMaxDigitCount = 4;

// The fade ramp holds at the base value for steps 0..2, counts its slope from step 2, and reaches
// nothing at step 8.
constexpr unsigned int kComboFadeHoldSteps = 3;
constexpr unsigned int kComboFadeRampOrigin = 2;
constexpr unsigned int kComboFadeMaxStep = 8;

// The scale ramp saturates at step 8 and is built on a unit base.
constexpr unsigned int kComboScaleFactorMaxStep = 8;
constexpr float kComboScaleFactorBase = 1.0f;

// The digit offset hits one of two exact multiples of the digit spacing.
constexpr int kComboDigitOffsetNear = -20;
constexpr int kComboDigitOffsetFar = -40;

// A frame position stored as a packed signed 16-bit x/y pair.
struct ComboAnimPoint {
    int16_t nX;
    int16_t nY;
};

// One keyframe of a piecewise-linear curve: the input threshold and the value at it.
struct ComboAnimKeyframe {
    float flX;
    float flY;
};

// @ghidraAddress 0x28e0b0
constexpr float g_flComboFadeBase = 0.3f;
// @ghidraAddress 0x28e0b4
constexpr float g_flComboFadeStep = -0.05f;
// @ghidraAddress 0x28e0b8
constexpr float g_flComboScaleStep = 0.02f;

// @ghidraAddress 0x28e0bc
constexpr float g_aflComboScaleByCount[kComboScaleRowCount][kComboScaleColumnCount] = {
    {1.0f, 0.96f, 0.92f, 0.88f, 0.84f, 0.8f, 0.76f, 0.72f, 0.68f, 0.64f, 0.6f},
    {0.8f, 1.0f, 0.96f, 0.91f, 0.87f, 0.82f, 0.78f, 0.73f, 0.69f, 0.64f, 0.6f},
    {0.73f, 0.87f, 1.0f, 0.95f, 0.9f, 0.85f, 0.8f, 0.75f, 0.7f, 0.65f, 0.6f},
    {0.7f, 0.8f, 0.9f, 1.0f, 0.94f, 0.89f, 0.83f, 0.77f, 0.71f, 0.66f, 0.6f},
};

// @ghidraAddress 0x28e16c
constexpr float g_aflComboScaleByDigit[kComboScaleRowCount][kComboScaleColumnCount] = {
    {1.0f, 0.96f, 0.92f, 0.88f, 0.84f, 0.8f, 0.76f, 0.72f, 0.68f, 0.64f, 0.6f},
    {0.6f, 0.6f, 0.6f, 1.0f, 0.94f, 0.89f, 0.83f, 0.77f, 0.71f, 0.66f, 0.6f},
    {0.6f, 0.6f, 1.0f, 0.95f, 0.9f, 0.85f, 0.8f, 0.75f, 0.7f, 0.65f, 0.6f},
    {0.6f, 1.0f, 0.96f, 0.91f, 0.87f, 0.82f, 0.78f, 0.73f, 0.69f, 0.64f, 0.6f},
};

// @ghidraAddress 0x28e21c
constexpr int g_anComboAnimFrameCounts[] = {9, 9, 18, 26, 34};

// @ghidraAddress 0x28e230
constexpr float g_aflComboAnimScale0[] = {
    2.058f, 1.728f, 1.0f, 1.788f, 1.904f, 1.0f, 1.404f, 1.0f, 1.0f};

// @ghidraAddress 0x28e254
constexpr float g_aflComboAnimScale1[] = {
    2.058f, 1.728f, 1.0f, 1.788f, 1.788f, 1.788f, 1.404f, 1.404f, 1.404f};

// @ghidraAddress 0x28e278
constexpr float g_aflComboAnimScale2[] = {1.462f,
                                          1.728f,
                                          1.0f,
                                          1.788f,
                                          1.357f,
                                          1.788f,
                                          1.404f,
                                          1.404f,
                                          1.404f,
                                          1.462f,
                                          1.728f,
                                          1.0f,
                                          1.788f,
                                          1.357f,
                                          1.788f,
                                          1.404f,
                                          1.404f,
                                          1.404f};

// @ghidraAddress 0x28e2c0
constexpr float g_aflComboAnimScale3[] = {0.923f, 1.19f,  0.462f, 1.25f,  0.818f, 1.25f, 0.865f,
                                          0.865f, 0.865f, 0.923f, 1.19f,  0.462f, 1.25f, 0.818f,
                                          1.25f,  0.865f, 1.218f, 1.172f, 0.923f, 1.19f, 0.834f,
                                          0.818f, 1.25f,  0.865f, 0.865f, 0.865f};

// @ghidraAddress 0x28e328
constexpr float g_aflComboAnimScale4[] = {
    0.875f, 1.31f,  1.31f,  0.632f, 1.19f,  0.979f, 1.19f,  0.846f, 1.31f, 1.19f,  0.581f, 1.19f,
    0.846f, 1.224f, 1.19f,  1.19f,  1.19f,  0.923f, 1.19f,  0.984f, 1.19f, 0.846f, 1.224f, 1.19f,
    1.19f,  0.923f, 1.517f, 1.19f,  0.981f, 1.19f,  0.846f, 1.224f, 1.19f, 1.19f};

// @ghidraAddress 0x28e3b0
constexpr ComboAnimPoint g_aComboAnimPos0[] = {{64, 364},
                                               {240, 334},
                                               {112, 548},
                                               {644, 374},
                                               {638, 518},
                                               {636, 384},
                                               {358, 516},
                                               {-32, 442},
                                               {278, 384}};

// @ghidraAddress 0x28e3d4
constexpr ComboAnimPoint g_aComboAnimPos1[] = {{642, 356},
                                               {496, 384},
                                               {164, 524},
                                               {660, 294},
                                               {56, 336},
                                               {148, 500},
                                               {578, 542},
                                               {176, 296},
                                               {410, 480}};

// @ghidraAddress 0x28e3f8
constexpr ComboAnimPoint g_aComboAnimPos2[] = {{640, 156},
                                               {494, 184},
                                               {162, 324},
                                               {657, 94},
                                               {53, 136},
                                               {146, 300},
                                               {576, 342},
                                               {174, 96},
                                               {408, 280},
                                               {640, 532},
                                               {494, 560},
                                               {162, 700},
                                               {658, 470},
                                               {54, 152},
                                               {146, 676},
                                               {576, 718},
                                               {174, 472},
                                               {408, 656}};

// @ghidraAddress 0x28e440
constexpr ComboAnimPoint g_aComboAnimPos3[] = {
    {588, 98},  {442, 126}, {110, 266}, {605, 36},  {1, 78},    {94, 242},  {524, 284},
    {20, 710},  {356, 222}, {588, 474}, {442, 502}, {110, 642}, {606, 412}, {2, 454},
    {94, 618},  {524, 660}, {654, 342}, {510, 632}, {383, 439}, {312, 306}, {212, 506},
    {292, 664}, {84, 186},  {642, 232}, {70, 694},  {116, 406}};

// @ghidraAddress 0x28e4a8
constexpr ComboAnimPoint g_aComboAnimPos4[] = {
    {604, 141}, {488, 93},  {324, 335}, {724, 740}, {88, 534},  {378, 452}, {569, 598},
    {124, 365}, {354, 503}, {118, 702}, {398, 554}, {415, 690}, {692, 645}, {427, 660},
    {754, 453}, {674, 667}, {184, 681}, {123, 518}, {472, 681}, {182, 230}, {394, 345},
    {686, 456}, {601, 450}, {748, 264}, {142, 96},  {662, 98},  {556, -20}, {456, 184},
    {162, 32},  {160, 150}, {692, 258}, {427, 273}, {754, 66},  {184, 294}};

// @ghidraAddress 0x28e530
constexpr ComboAnimKeyframe g_aComboAnimCurve0[][kComboCurveKeyframeCount] = {
    {{0.0f, 0.0f}, {0.6969697f, 0.52f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.3030303f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.21212122f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.45454547f, 0.6f}, {0.6363636f, 0.29f}, {1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.6969697f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.57575756f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
};

// @ghidraAddress 0x28e650
constexpr ComboAnimKeyframe g_aComboAnimCurve1[][kComboCurveKeyframeCount] = {
    {{0.0f, 0.0f}, {0.6969697f, 0.52f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.5151515f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.6060606f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.42424244f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.45454547f, 0.6f}, {0.6363636f, 0.29f}, {1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.27272728f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.57575756f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
};

// @ghidraAddress 0x28e770
constexpr ComboAnimKeyframe g_aComboAnimCurve2[][kComboCurveKeyframeCount] = {
    {{0.0f, 0.0f}, {0.6969697f, 0.52f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.5151515f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.6060606f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.42424244f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.45454547f, 0.6f}, {0.6363636f, 0.29f}, {1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.27272728f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.57575756f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.6969697f, 0.52f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.5151515f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.6060606f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.42424244f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.45454547f, 0.6f}, {0.6363636f, 0.29f}, {1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.27272728f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.57575756f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
};

// @ghidraAddress 0x28e9b0
constexpr ComboAnimKeyframe g_aComboAnimCurve3[][kComboCurveKeyframeCount] = {
    {{0.0f, 0.0f}, {0.6969697f, 0.0f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.6f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.6f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.5151515f, 0.6f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.6060606f, 0.6f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.42424244f, 0.0f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.45454547f, 0.6f}, {0.6363636f, 0.29f}, {1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.27272728f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.57575756f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.6969697f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.6f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.5151515f, 0.6f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.6060606f, 0.6f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.45454547f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.4848485f, 0.0f}, {0.6363636f, 0.29f}, {1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.27272728f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.57575756f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.6969697f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.6f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.6060606f, 0.6f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.42424244f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.45454547f, 0.6f}, {0.6363636f, 0.29f}, {1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.27272728f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.57575756f, 0.6f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
};

// @ghidraAddress 0x28ecf0
constexpr ComboAnimKeyframe g_aComboAnimCurve4[][kComboCurveKeyframeCount] = {
    {{0.0f, 0.0f}, {0.6969697f, 0.52f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.6969697f, 0.52f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.6969697f, 0.52f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.5151515f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.6969697f, 0.52f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.5151515f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.45454547f, 0.54f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.57575756f, 0.5f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.57575756f, 0.5f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.6969697f, 0.52f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.5151515f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.45454547f, 0.34f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.57575756f, 0.5f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.6969697f, 0.52f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.5151515f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.45454547f, 0.34f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
    {{0.0f, 0.5f}, {0.45454547f, 0.0f}, {1.0f, 0.5f}, {-1.0f, 0.0f}},
    {{0.0f, 0.0f}, {0.57575756f, 0.5f}, {1.0f, 0.0f}, {-1.0f, 0.0f}},
};

// @ghidraAddress 0x28f130
constexpr ComboAnimKeyframe g_aComboScaleCurves[kComboScaleCurveCount][kComboCurveKeyframeCount] = {
    {{0.0f, 1.05f}, {0.6060606f, 1.0f}, {0.8484849f, 1.0f}, {1.0f, 1.05f}},
    {{0.0f, 1.1f}, {0.6060606f, 1.0f}, {0.8484849f, 1.0f}, {1.0f, 1.1f}},
    {{0.0f, 1.1f}, {0.6060606f, 1.0f}, {0.8484849f, 1.0f}, {1.0f, 1.1f}},
    {{0.0f, 1.15f}, {0.6060606f, 1.0f}, {0.8484849f, 1.0f}, {1.0f, 1.15f}},
    {{0.0f, 1.15f}, {0.6060606f, 1.0f}, {0.8484849f, 1.0f}, {1.0f, 1.15f}},
};

// The binary dispatches the five per-group animation tables through a jump table on the group
// index; these arrays recover that dispatch as ordinary indexing.
constexpr const float *const kComboAnimScaleTables[] = {g_aflComboAnimScale0,
                                                        g_aflComboAnimScale1,
                                                        g_aflComboAnimScale2,
                                                        g_aflComboAnimScale3,
                                                        g_aflComboAnimScale4};

constexpr const ComboAnimPoint *const kComboAnimPosTables[] = {
    g_aComboAnimPos0, g_aComboAnimPos1, g_aComboAnimPos2, g_aComboAnimPos3, g_aComboAnimPos4};

constexpr const ComboAnimKeyframe (*const kComboAnimCurveTables[])[kComboCurveKeyframeCount] = {
    g_aComboAnimCurve0,
    g_aComboAnimCurve1,
    g_aComboAnimCurve2,
    g_aComboAnimCurve3,
    g_aComboAnimCurve4};

// Standard linear interpolation of a keyframe value between the two bracketing keyframes, matching
// the "((t - x_lo) * y_hi + (x_hi - t) * y_lo) / (x_hi - x_lo)" arrangement the binary emits.
inline float
interpolateKeyframe(const ComboAnimKeyframe &low, const ComboAnimKeyframe &high, float flTime) {
    return ((flTime - low.flX) * high.flY + (high.flX - flTime) * low.flY) / (high.flX - low.flX);
}

} // namespace

float GetComboScaleByCount(unsigned int dwStep, unsigned int dwDigitCount) {
    if (dwDigitCount == 0) {
        return 0.0f;
    }
    unsigned int step = dwStep > kComboMaxScaleStep ? kComboMaxScaleStep : dwStep;
    unsigned int count = dwDigitCount > kComboMaxDigitCount ? kComboMaxDigitCount : dwDigitCount;
    return g_aflComboScaleByCount[count - 1][step];
}

float GetComboScaleByDigit(unsigned int dwStep, unsigned int dwDigitCount, int nDigitIndex) {
    if (dwDigitCount - 1 >= kComboMaxDigitCount) {
        return 0.0f;
    }
    if (static_cast<unsigned int>(nDigitIndex + 1) > dwDigitCount) {
        return 0.0f;
    }
    unsigned int step = dwStep > kComboMaxScaleStep ? kComboMaxScaleStep : dwStep;
    unsigned int row = dwDigitCount - (nDigitIndex + 1);
    return g_aflComboScaleByDigit[row][step];
}

int GetComboDigitOffset(int nValue, unsigned int dwDigitCount, int nDigitIndex) {
    if (dwDigitCount - 1 >= kComboMaxDigitCount) {
        return 0;
    }
    if (static_cast<unsigned int>(nDigitIndex + 1) > dwDigitCount) {
        return 0;
    }
    int slot = static_cast<int>(dwDigitCount) - nDigitIndex;
    // The far offset takes priority over the near one; the binary's csel chain resolves it last.
    if (slot - 1 == nValue) {
        return kComboDigitOffsetFar;
    }
    if (slot == nValue) {
        return kComboDigitOffsetNear;
    }
    return 0;
}

float GetComboFadeFactor(unsigned int dwStep) {
    if (dwStep < kComboFadeHoldSteps) {
        return g_flComboFadeBase;
    }
    if (dwStep > kComboFadeMaxStep) {
        return 0.0f;
    }
    return static_cast<float>(dwStep - kComboFadeRampOrigin) * g_flComboFadeStep +
           g_flComboFadeBase;
}

float GetComboScaleFactor(unsigned int dwStep) {
    unsigned int step = dwStep > kComboScaleFactorMaxStep ? kComboScaleFactorMaxStep : dwStep;
    return static_cast<float>(step) * g_flComboScaleStep + kComboScaleFactorBase;
}

int GetComboAnimFrameCount(unsigned int dwAnimGroup) {
    if (dwAnimGroup >= kComboAnimGroupCount) {
        return 0;
    }
    return g_anComboAnimFrameCounts[dwAnimGroup];
}

float GetComboAnimScale(unsigned int dwAnimGroup, int nFrameIndex) {
    if (nFrameIndex < 0 || dwAnimGroup >= kComboAnimGroupCount ||
        nFrameIndex >= g_anComboAnimFrameCounts[dwAnimGroup]) {
        return 0.0f;
    }
    return kComboAnimScaleTables[dwAnimGroup][nFrameIndex];
}

CGPoint GetComboAnimPosition(unsigned int dwAnimGroup, int nFrameIndex) {
    if (nFrameIndex < 0 || dwAnimGroup >= kComboAnimGroupCount ||
        nFrameIndex >= g_anComboAnimFrameCounts[dwAnimGroup]) {
        return CGPointZero;
    }
    const ComboAnimPoint &point = kComboAnimPosTables[dwAnimGroup][nFrameIndex];
    return CGPointMake(static_cast<CGFloat>(point.nX), static_cast<CGFloat>(point.nY));
}

float EvalComboAnimCurve(float flTime, unsigned int dwAnimGroup, int nFrameIndex) {
    // Unlike GetComboAnimScale and GetComboAnimPosition, the binary has no negative-index guard
    // here: it uses only a signed upper-bound check, so a negative nFrameIndex is passed straight
    // through to the indexing.
    if (dwAnimGroup >= kComboAnimGroupCount ||
        nFrameIndex >= g_anComboAnimFrameCounts[dwAnimGroup]) {
        return 0.0f;
    }
    const ComboAnimKeyframe *keyframes = kComboAnimCurveTables[dwAnimGroup][nFrameIndex];
    for (int i = 0; i < kComboCurveKeyframeCount; ++i) {
        float flX = keyframes[i].flX;
        if (flX < 0.0f) {
            // A negative x is the end-of-curve sentinel, so a curve can use fewer than four slots.
            return 0.0f;
        }
        if (flX == flTime) {
            return keyframes[i].flY;
        }
        if (flX > flTime) {
            if (i == 0) {
                // flTime precedes the curve.
                return 0.0f;
            }
            return interpolateKeyframe(keyframes[i - 1], keyframes[i], flTime);
        }
    }
    // flTime is past the last keyframe.
    return 0.0f;
}

float EvalComboScaleCurve(float flTime, unsigned int dwCurveIndex) {
    if (dwCurveIndex >= static_cast<unsigned int>(kComboScaleCurveCount)) {
        return 0.0f;
    }
    const ComboAnimKeyframe *keyframes = g_aComboScaleCurves[dwCurveIndex];
    // Unlike EvalComboAnimCurve there is no negative-x sentinel: all four slots are live.
    for (int i = 0; i < kComboCurveKeyframeCount; ++i) {
        float flX = keyframes[i].flX;
        if (flX == flTime) {
            return keyframes[i].flY;
        }
        if (flX > flTime) {
            if (i == 0) {
                return 0.0f;
            }
            return interpolateKeyframe(keyframes[i - 1], keyframes[i], flTime);
        }
    }
    return 0.0f;
}
