#import "KnitColorManager.h"

// The divisor -makeColor: applies to red, green, and blue, from the float at 0x28dff4.
static const float kKnitColorComponentScale = 255.0f;

// The two palette types that count as "not differing" from the default, from the two cmp/csel pairs
// at 0x1660f8 and 0x166104.
enum {
    kKnitColorTypeDefault = 0,
    kKnitColorTypeAlsoDefault = 5,
};

// The palette table at 0x353d78, transcribed from the binary. Five rows: the bytes immediately
// after row 4 are pointers into __DATA, not floats, so the table ends there.
//
// Row 2's wave red is 2290, which is out of range on a 0 to 255 scale and clamps to full red once
// -makeColor: divides it. That is what the binary contains; it is not a transcription error.
static const KnitColorPalette kKnitColorPalettes[] = {
    // 0: white base, black lines, amber wave.
    {{255, 255, 255, 1}, {0, 0, 0, 1}, {252, 200, 0, 1}},
    // 1: amber base, white lines, brown wave.
    {{255, 219, 0, 1}, {255, 255, 255, 1}, {163, 119, 70, 1}},
    // 2: slate base, near-black lines, out-of-range wave.
    {{138, 132, 144, 1}, {20, 20, 20, 1}, {2290, 0, 18, 1}},
    // 3: light base, teal lines, deep teal wave.
    {{240, 240, 240, 1}, {30, 180, 200, 1}, {0, 80, 100, 1}},
    // 4: pink base, white lines, brown wave.
    {{250, 183, 177, 1}, {255, 255, 255, 1}, {130, 67, 32, 1}},
};

@implementation KnitColorManager

/** @ghidraAddress 0x166098 */
- (UIColor *)makeColor:(const KnitColorComponents *)components {
    // The receiver is unused: the binary overwrites x0 with the UIColor class straight away.
    // Alpha is not scaled, only the three colour channels are.
    return [UIColor colorWithRed:components->red / kKnitColorComponentScale
                           green:components->green / kKnitColorComponentScale
                            blue:components->blue / kKnitColorComponentScale
                           alpha:components->alpha];
}

/** @ghidraAddress 0x1660d8 */
- (void)setColorWithType:(int)type {
    // Computed with two csel pairs rather than a branch: the flag is set for every type except
    // 0 and 5.
    _isKnitColorDiffer = (type != kKnitColorTypeDefault && type != kKnitColorTypeAlsoDefault);

    // No range check on type. The table has five rows, so type 5 — which the flag above singles
    // out — indexes one past the end and reads __DATA pointers as floats.
    const KnitColorPalette *palette = &kKnitColorPalettes[type];
    _baseColor = [self makeColor:&palette->base];
    _lineColor = [self makeColor:&palette->line];
    _waveColor = [self makeColor:&palette->wave];
}

@end
