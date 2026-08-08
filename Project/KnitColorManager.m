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

/** @ghidraAddress 0x165fe0 */
+ (KnitColorManager *)sharedManager {
    static KnitColorManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x16600c */
      instance = [[KnitColorManager alloc] init];
    });
    return instance;
}

/** @ghidraAddress 0x166060 */
- (instancetype)init {
    return [super init];
}

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
- (void)setColorWithType:(unsigned int)type {
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

/** @ghidraAddress 0x1661c0 */
- (void)setColorWithArray:(NSArray *)colors {
    _isKnitColorDiffer = NO;
    if (!colors || colors.count != 9) {
        return;
    }
    // Nine integers: three groups of three, each divided by 255, alpha is fixed at 1.0.
    // Verified in disassembly: the nine objectAtIndex: calls at 0x166238, 0x166278, 0x1662a8,
    // then intValue, scvtf, fdiv against g_flByteScale255 at 0x28dff4, then colorWithRed: at
    // 0x1662ec.
    _baseColor = [UIColor colorWithRed:[colors[0] intValue] / kKnitColorComponentScale
                                 green:[colors[1] intValue] / kKnitColorComponentScale
                                  blue:[colors[2] intValue] / kKnitColorComponentScale
                                 alpha:1.0];
    _lineColor = [UIColor colorWithRed:[colors[3] intValue] / kKnitColorComponentScale
                                 green:[colors[4] intValue] / kKnitColorComponentScale
                                  blue:[colors[5] intValue] / kKnitColorComponentScale
                                 alpha:1.0];
    _waveColor = [UIColor colorWithRed:[colors[6] intValue] / kKnitColorComponentScale
                                 green:[colors[7] intValue] / kKnitColorComponentScale
                                  blue:[colors[8] intValue] / kKnitColorComponentScale
                                 alpha:1.0];
    _isKnitColorDiffer = YES;
}

/** @ghidraAddress 0x166528 */
- (int)getColorType {
    if (!_isKnitColorDiffer) {
        return 0;
    }
    // Compare against palette 1 (amber) at 0x353da8 and palette 4 (pink) at 0x353e38.
    // The disassembly at 0x1665c0–0x166640 checks isEqual: for base, line, wave against both.
    UIColor *base1 = [self makeColor:&kKnitColorPalettes[1].base];
    UIColor *line1 = [self makeColor:&kKnitColorPalettes[1].line];
    UIColor *wave1 = [self makeColor:&kKnitColorPalettes[1].wave];
    if ([base1 isEqual:_baseColor] && [line1 isEqual:_lineColor] && [wave1 isEqual:_waveColor]) {
        return 1;
    }
    UIColor *base4 = [self makeColor:&kKnitColorPalettes[4].base];
    UIColor *line4 = [self makeColor:&kKnitColorPalettes[4].line];
    UIColor *wave4 = [self makeColor:&kKnitColorPalettes[4].wave];
    if ([base4 isEqual:_baseColor] && [line4 isEqual:_lineColor] && [wave4 isEqual:_waveColor]) {
        return 4;
    }
    return 5;
}

/** @ghidraAddress 0x166744 */
- (UIColor *)getBaseColor {
    return _baseColor;
}

/** @ghidraAddress 0x166754 */
- (UIColor *)getLineColor {
    return _lineColor;
}

/** @ghidraAddress 0x166764 */
- (UIColor *)getWaveColor {
    return _waveColor;
}

@end
