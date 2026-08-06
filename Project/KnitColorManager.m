#import "KnitColorManager.h"

// The palette table the type index selects a row from. It lives at 0x353d78 in the shipped binary
// and its contents are NOT transcribed here — see TYPES_PENDING.md for why.
extern const KnitColorPalette kKnitColorPalettes[];

// The two palette types that count as "not differing" from the default, from the two cmp/csel pairs
// at 0x1660f8 and 0x166104.
enum {
    kKnitColorTypeDefault = 0,
    kKnitColorTypeAlsoDefault = 5,
};

@interface KnitColorManager ()
// Builds a UIColor from one component group. Declared here because -setColorWithType: sends it; its
// own body has not been reconstructed.
- (UIColor *)makeColor:(const KnitColorComponents *)components;
@end

@implementation KnitColorManager

- (void)setColorWithType:(int)type {
    // Computed with two csel pairs rather than a branch: the flag is set for every type except
    // 0 and 5.
    _isKnitColorDiffer = (type != kKnitColorTypeDefault && type != kKnitColorTypeAlsoDefault);

    // No range check on type; an out-of-range value reads past the end of the table.
    const KnitColorPalette *palette = &kKnitColorPalettes[type];
    _baseColor = [self makeColor:&palette->base];
    _lineColor = [self makeColor:&palette->line];
    _waveColor = [self makeColor:&palette->wave];
}

@end
