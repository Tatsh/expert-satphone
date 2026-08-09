#import "UpperBGKnit.h"

#include <math.h>
#include <stdlib.h>
#include <strings.h>

#import "JubeatAppDelegate.h"
#import "KnitColorManager.h"
#import "Texture2D.h"

// The four knit columns and the two-dimensional pulse grid over them.
enum {
    kWaveColumnCount = 4,
    kRiseGridSize = 4,
};

// Each wave table holds this many samples per column; the pulse table this many.
enum {
    kWaveTableSampleCount = 2048,
    kAddPulseSampleCount = 1024,
    kPulseTableSampleCount = 512,
};

// The rise pulse counts down from this value, and the sine that shapes it spans this range.
static const int kRiseTimerStart = 15;
static const float kRiseTimerSpan = 15.0f;

// The rise pulse is centred at drawArea.size.width/8 and stepped per row by (row*width)/4; its
// spread grows with the timer over a 20-frame span, and each contribution is scaled down by a
// third.
enum {
    kPulseCentreDivisor = 8,
    kPulseRowDivisor = 4,
};
static const float kPulseSpreadSpan = 20.0f;
static const float kPulseAmplitudeScale = 3.0f;

// A plug pulse lasts this many frames; extending one adds a few more but only while it still has
// this many frames to run.
enum {
    kPlugPulseFrames = 0x23,
    kPlugExtendFrames = 5,
    kPlugPulsePeak = 0x1e,
    kPlugExtendWindow = 0x16,
};
// The plug envelope is a sine over a half turn; the frame counter is normalised by this span.
static const float kPlugPulseNormalise = 30.0f;

// The six drawing layers, indexed into the array the caller passes in. The waves' background fill
// draws into layer 5, each line into its own layer 0 to 3, and the per-column fill into layer 4.
enum {
    kWaveBackgroundLayerIndex = 5,
    kColumnFillLayerIndex = 4,
    kLayerCount = 6,
};

// Sprite indices passed to -drawSprite:inRect:color:. The background fill and the rectangle-wave
// lines both use sprite 4; a sine-wave line uses sprite 3 for the front pair and 2 for the back.
enum {
    kFillSprite = 4,
    kRectLineSprite = 4,
    kFrontLineSprite = 3,
    kBackLineSprite = 2,
    kFrontLineCount = 2,
};

// The line sprites are drawn 2.5 points to the left; the per-column fill bar is 2.5 wide and its
// height is inset by one point.
static const double kLineDrawInsetX = -2.5;
static const double kFillBarWidth = 2.5;
static const double kFillHeightInset = 1.0;

// The rectangle wave's drawn height is pulled towards the tallest column by half the difference.
static const float kRectHeightBlend = -0.5f;

// The initial carried draw width, before the rectangle-wave lines narrow it to two.
enum {
    kInitialLineWidth = 4,
    kRectLineWidth = 2,
};

// The amplitude scale from the tilt is half the tilt magnitude plus one.
static const float kAmplitudeTiltScale = 0.5f;

// The draw area is widened by two points on the right.
static const double kDrawAreaWidthPad = 2.0;

// iPad doubles the scroll speed.
static const float kPadSpeedScale = 2.0f;
static const float kPhoneSpeedScale = 1.0f;

// Two tiny epsilons that widen the rectangle-wave clamps. The one at 0x293a80 is negative and
// biases the "at or below" comparisons down; the one at 0x293a84 is positive and forms the pulse
// floor.
static const float kRectClampEpsilon = -9.999999747378752e-05f; // @ghidraAddress 0x293a80
static const float kPulseFloorEpsilon = 9.999999747378752e-05f; // @ghidraAddress 0x293a84

// The pulse table's phase offset, negative a quarter turn.
static const double kPulsePhaseOffset = -1.5707963267948966; // @ghidraAddress 0x291c00

// The tension bias applied to the resting baseline while playing.
static const float kTensionBias = -0.0009765625f; // @ghidraAddress 0x292ac0

// The fraction of the remaining distance the baseline covers each frame while showing a result.
static const float kResultApproach = 0.10000000149011612f; // @ghidraAddress 0x28f70c

// A plug pulse only starts at or above pi/16.
static const double kPlugThreshold = 0.19634954084936207; // @ghidraAddress 0x293a78

// The plug envelope's inner sine argument scales the normalised frame by pi/2 and offsets by the
// same, so it sweeps a quarter turn to three-quarters.
static const double kPlugSinePhase = 1.5707963267948966; // @ghidraAddress 0x28f460

// Per-column factor tables at 0x293a90, laid out as {width, speed, waveAmp} triples eight bytes
// apart, and a separate rectangle-amplitude table at 0x293ac8. Each value is a 32-bit float.
// Widths and amplitudes are fractions of pi; speeds are steps per frame.
static const float kColumnWidthFactor[] = {6.599999904632568f,
                                           3.240000009536743f,
                                           2.890000104904175f,
                                           7.78000020980835f};       // @ghidraAddress 0x293a90
static const float kColumnSpeedFactor[] = {-8.0f, 8.0f, 5.0f, 5.0f}; // @ghidraAddress 0x293a94
static const float kColumnWaveAmpFactor[] = {0.23999999463558197f,
                                             0.46000000834465027f,
                                             0.12999999523162842f,
                                             0.33000001311302185f}; // @ghidraAddress 0x293a98
static const float kColumnRectAmpFactor[] = {0.10000000149011612f,
                                             0.6000000238418579f,
                                             -0.20000000298023224f,
                                             0.5f}; // @ghidraAddress 0x293ac8

@implementation UpperBGKnit {
    UIColor *bgColor;
    UIColor *waveColor;
    UIColor *lineColor;
    CGRect drawArea;
    float wavePosY;
    int waveWidth[kWaveColumnCount];
    int wavePos[kWaveColumnCount];
    int waveSpeed[kWaveColumnCount];
    int pulseWaveHeight;
    float waveTable[kWaveColumnCount][kWaveTableSampleCount];
    float addPulse[kWaveColumnCount][kAddPulseSampleCount];
    float pulseTable[kPulseTableSampleCount];
    float pulseWidth;
    BOOL risePulse[kRiseGridSize][kRiseGridSize];
    int riseTimer[kRiseGridSize][kRiseGridSize];
    int waveTopY;
    int pushWaveHeight;
    BOOL isPad_;
    float deg_;
    float accela_;
    int accela_cnt_;
    BOOL plugFlag_;
    int plugTimer_;
    int plugExtendTimer_;
    BOOL bRectangleWave;
    float largeRectHeight;
    float rectHeightArray[kWaveColumnCount];
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x193e38 */
- (instancetype)init {
    self = [super init];
    return self;
}

#pragma mark - Setup

/** @ghidraAddress 0x193e70 */
- (void)initBg:(CGRect)bg
     waveBottom:(float)waveBottom
        waveTop:(float)waveTop
    pulseHeight:(float)pulseHeight
          isPad:(BOOL)isPad {
    KnitColorManager *colors = KnitColorManager.sharedManager;
    bgColor = [colors getBaseColor];
    lineColor = [colors getLineColor];
    waveColor = [colors getWaveColor];

    drawArea =
        CGRectMake(bg.origin.x, bg.origin.y, bg.size.width + kDrawAreaWidthPad, bg.size.height);
    wavePosY = waveBottom;
    waveTopY = (int)waveTop;
    isPad_ = isPad;
    accela_ = 0;
    deg_ = 0;
    plugFlag_ = NO;
    plugTimer_ = 0;

    int width = (int)bg.size.width;
    bRectangleWave = JubeatAppDelegate.appDelegate.isRectangleWave;
    largeRectHeight = 0;

    float halfPulse = pulseHeight * 0.5f;
    for (int column = 0; column < kWaveColumnCount; ++column) {
        rectHeightArray[column] = 0;

        // The initial scroll position is randomised within the column's width; arc4random is
        // called twice, the first result discarded but for its side effect on the generator.
        arc4random();
        waveWidth[column] = (int)((double)width * ((double)kColumnWidthFactor[column] / M_PI));
        uint32_t rnd = arc4random();
        uint32_t w = (uint32_t)waveWidth[column];
        wavePos[column] = (w != 0) ? (rnd % w) : rnd;

        float speedScale = isPad_ ? kPadSpeedScale : kPhoneSpeedScale;
        waveSpeed[column] = (int)(kColumnSpeedFactor[column] * speedScale);

        int span = waveWidth[column];
        for (int i = 0; i < span; ++i) {
            float sample;
            double phase = sin(((double)i * (2.0 * M_PI)) / (double)span);
            if (!bRectangleWave) {
                float amp = kColumnWaveAmpFactor[column];
                sample = (float)((phase + 1.0) * (double)-(int)(halfPulse + halfPulse * amp));
            } else {
                int rectAmp = (int)(halfPulse + halfPulse * kColumnRectAmpFactor[column]);
                int negAmp = -rectAmp;
                sample = (float)(rectAmp * -2);
                // Flatten the top of the rectangle to zero once the sine crosses into it.
                if ((float)negAmp + kRectClampEpsilon <= (float)((phase + 1.0) * (double)negAmp)) {
                    sample = 0;
                }
                if (sample < largeRectHeight) {
                    largeRectHeight = sample;
                }
                if (sample < rectHeightArray[column]) {
                    rectHeightArray[column] = sample;
                }
            }
            waveTable[column][i] = sample;
        }
    }

    int pulseSpan = width * 2;
    pulseWidth = (float)(pulseSpan / 3);
    if (pulseSpan > 2) {
        float pulseFloor = pulseHeight + kPulseFloorEpsilon;
        for (int i = 0; (float)i < pulseWidth; ++i) {
            double phase = sin(((double)i * (2.0 * M_PI)) / (double)pulseWidth + kPulsePhaseOffset);
            float value = (float)((double)pulseHeight * (phase + 1.0));
            if (bRectangleWave) {
                float clamped =
                    (value <= pulseHeight + kRectClampEpsilon) ? value : pulseHeight + pulseHeight;
                value = (pulseFloor <= clamped) ? clamped : 0;
            }
            pulseTable[i] = value;
        }
    }

    pushWaveHeight = (int)((double)waveBottom - (drawArea.origin.y + (double)(long)waveTopY));
    wavePosY = (float)pushWaveHeight;
}

#pragma mark - Update

/** @ghidraAddress 0x1943b0 */
- (void)pulseUpdate:(int)tension isResult:(BOOL)isResult {
    bzero(addPulse, sizeof(addPulse));

    // The decompile reads drawArea + 0x10, which is size.width.
    int areaWidth = (int)drawArea.size.width;
    for (int column = 0; column < kRiseGridSize; ++column) {
        for (int row = 0; row < kRiseGridSize; ++row) {
            if (!risePulse[column][row]) {
                continue;
            }
            int timer = riseTimer[column][row];
            double envelope = sin(((double)(kRiseTimerStart - timer) * M_PI) / kRiseTimerSpan);
            // Both offsets truncate towards zero, matching the binary's arithmetic-shift idiom.
            int centreOffset = areaWidth / kPulseCentreDivisor;
            int rowOffset = (row * areaWidth) / kPulseRowDivisor;
            float pw = pulseWidth;
            int spread = (int)((float)timer * (pw / kPulseSpreadSpan));

            for (int i = 0; (float)i < pw; ++i) {
                unsigned int index =
                    (unsigned int)((float)((-centreOffset + rowOffset - spread) + i) + pw * 0.5f);
                if (index < kAddPulseSampleCount) {
                    addPulse[column][index] +=
                        ((float)envelope * pulseTable[i]) / kPulseAmplitudeScale;
                    pw = pulseWidth;
                }
            }
            for (int i = 0; (float)i < pw; ++i) {
                unsigned int index =
                    (unsigned int)((float)(-centreOffset + spread + rowOffset + i) + pw * -0.5f);
                if (index < kAddPulseSampleCount) {
                    addPulse[column][index] +=
                        ((float)envelope * pulseTable[i]) / kPulseAmplitudeScale;
                    pw = pulseWidth;
                }
            }

            int remaining = riseTimer[column][row];
            riseTimer[column][row] = remaining - 1;
            if (remaining < 1) {
                riseTimer[column][row] = 0;
                risePulse[column][row] = NO;
            }
        }
    }

    if (!isResult) {
        wavePosY =
            (((float)tension * kTensionBias + 1.0f) * (float)pushWaveHeight + wavePosY) * 0.5f;
    } else {
        wavePosY = wavePosY + ((float)pushWaveHeight - wavePosY) * kResultApproach;
    }
}

#pragma mark - Render

/** @ghidraAddress 0x19467c */
- (void)renderUpperBg:(NSArray<Texture2D *> *)layers tension:(int)tension isResult:(BOOL)isResult {
    unsigned int pixelCount = (unsigned int)drawArea.size.width;

    [self pulseUpdate:tension isResult:isResult];

    // The whole knit sits on a solid wave-coloured fill.
    [layers[kWaveBackgroundLayerIndex] drawSprite:kFillSprite inRect:drawArea color:waveColor];

    // The plug pulse scales the horizontal sampling and, near its start, swells the amplitude.
    float plugScale;
    if (!plugFlag_) {
        plugScale = 1.0f;
    } else {
        int timer = plugTimer_;
        if (timer < kPlugPulsePeak) {
            float inner = (float)((double)((float)timer / kPlugPulseNormalise) * kPlugSinePhase +
                                  kPlugSinePhase);
            float shaped = (float)sinf(inner);
            shaped = (float)sinf((float)((double)shaped * M_PI));
            plugScale = shaped + 1.0f;
        } else {
            plugScale = 1.0f;
        }
        int next = timer - 1;
        plugTimer_ = next;
        if (timer < kPlugExtendWindow && plugExtendTimer_ > 0) {
            plugTimer_ = timer + 1;
            plugExtendTimer_ -= 1;
            next = plugTimer_;
        }
        if (next == 0) {
            plugFlag_ = NO;
        }
    }

    if ((int)pixelCount > 0) {
        float centreX = (float)(drawArea.origin.x + drawArea.size.width * 0.5);
        float amplitudeScale = fabsf(deg_) * kAmplitudeTiltScale + 1.0f;
        // The line width persists across the whole double loop: a rectangle-wave column narrows it
        // to two after the first draw, and it never widens again. This matches the binary exactly.
        int lineWidth = kInitialLineWidth;

        for (unsigned int x = 0; x < pixelCount; ++x) {
            float fx = (float)(int)x;
            float distFromCentre = centreX - fx;
            unsigned int prevX = (x != 0) ? x : pixelCount;
            float fPrevX = (float)(int)(prevX - 1);
            int prevIndex = (x != 0) ? (int)(prevX - 1) : 0;
            float runningMax = 0;

            for (int column = 0; column < kWaveColumnCount; ++column) {
                int sprite = (column < kFrontLineCount) ? kFrontLineSprite : kBackLineSprite;
                int width = lineWidth;
                if (bRectangleWave) {
                    sprite = kRectLineSprite;
                    lineWidth = kRectLineWidth;
                }

                int pos = wavePos[column];
                int span = waveWidth[column];
                int sampleAt = pos + (int)(plugScale * fx);
                int sampleIdx = sampleAt - (span ? (sampleAt / span) : 0) * span;
                float sample = waveTable[column][sampleIdx];

                float currHeight;
                float prevHeight;
                int pulseIndex;
                if (!bRectangleWave) {
                    currHeight = amplitudeScale * sample + distFromCentre * deg_;
                    pulseIndex = 0;
                    prevHeight = 0;
                } else {
                    int prevSampleAt = pos + (int)(plugScale * fPrevX);
                    int prevSampleIdx = prevSampleAt - (span ? (prevSampleAt / span) : 0) * span;
                    currHeight = amplitudeScale * sample + distFromCentre * deg_;
                    pulseIndex = prevIndex;
                    prevHeight = currHeight;
                    if (x != 0) {
                        prevHeight = amplitudeScale * waveTable[column][prevSampleIdx] +
                                     (centreX - fPrevX) * deg_;
                    }
                }

                float pulseHere = addPulse[column][x];
                float y = (pulseHere <= 0.0f) ? currHeight : currHeight - pulseHere;
                if (bRectangleWave) {
                    float pulseThere = addPulse[column][pulseIndex];
                    if (pulseThere > 0.0f) {
                        prevHeight = prevHeight - pulseThere;
                    }
                }

                float baseline = wavePosY + (float)waveTopY;
                y = y + baseline;

                double drawY;
                int drawHeight;
                if (!bRectangleWave) {
                    // A sine line is a small square of side lineWidth at the wave's height.
                    drawY = (double)(y + (float)kLineDrawInsetX);
                    drawHeight = width;
                } else {
                    unsigned int barHeight = (unsigned int)((prevHeight + baseline) - y);
                    y = y + (rectHeightArray[column] - largeRectHeight) * kRectHeightBlend;
                    if (barHeight == 0) {
                        drawY = (double)(y + (float)kLineDrawInsetX);
                        drawHeight = width;
                    } else {
                        float top = y + (float)kLineDrawInsetX;
                        BOOL negative = (barHeight & 0x80000000) != 0;
                        drawY = negative ? (double)((float)(int)barHeight + top) : (double)top;
                        drawHeight = negative ? -(int)barHeight : (int)barHeight;
                    }
                }

                [layers[column] drawSprite:(NSUInteger)sprite
                                    inRect:CGRectMake((double)(fx + (float)kLineDrawInsetX),
                                                      drawY,
                                                      (double)width,
                                                      (double)drawHeight)
                                     color:lineColor];

                // The tallest of the first three columns drives the per-column fill; column three
                // is excluded from the running maximum.
                if (!(y <= runningMax || column == kWaveColumnCount - 1)) {
                    runningMax = y;
                }
            }

            // A thin fill bar under the waves, as tall as the running maximum.
            CGRect fillRect = CGRectMake((double)(int)(x - 1),
                                         0,
                                         kFillBarWidth,
                                         (double)(runningMax - (float)kFillHeightInset));
            [layers[kColumnFillLayerIndex] drawSprite:kFillSprite inRect:fillRect color:bgColor];
        }
    }

    // Advance each column's scroll position, wrapping within its width.
    for (int column = 0; column < kWaveColumnCount; ++column) {
        int pos = (int)(plugScale * (float)waveSpeed[column] + (float)wavePos[column]);
        if (pos < 0) {
            pos = waveWidth[column] + pos;
        }
        int span = waveWidth[column];
        int quotient = span ? (pos / span) : 0;
        wavePos[column] = pos - quotient * span;
    }
}

#pragma mark - Pulse control

/** @ghidraAddress 0x194d38 */
- (void)riseUp:(int)row riseColumn:(int)riseColumn {
    // The tested cell is [row][riseColumn]; when it is clear the pulse starts in all four columns.
    if (!risePulse[row][riseColumn]) {
        for (int column = 0; column < kRiseGridSize; ++column) {
            risePulse[column][riseColumn] = YES;
            riseTimer[column][riseColumn] = kRiseTimerStart;
        }
    }
}

/** @ghidraAddress 0x194f0c */
- (void)plugWave:(float)value {
    if ((double)value >= kPlugThreshold) {
        if (!plugFlag_) {
            plugTimer_ = kPlugPulseFrames;
        } else {
            plugExtendTimer_ = kPlugExtendFrames;
        }
        plugFlag_ = YES;
    }
}

#pragma mark - Commit

/** @ghidraAddress 0x194d94 */
- (void)commitBg:(NSArray<Texture2D *> *)layers {
    // Committed front to back: 5, 4, 3, 2, 1, 0.
    for (int index = kLayerCount - 1; index >= 0; --index) {
        [layers[index] commitDraw];
    }
}

#pragma mark - Accessors

/** @ghidraAddress 0x194eec */
- (void)setDeg:(float)deg {
    deg_ = deg;
}

/** @ghidraAddress 0x194efc */
- (void)addAccelerated:(float)accelerated {
    accela_ = accelerated;
}

@end
