#import "EditNoteRendererPad.h"

#import "AudioManager.h"
#import "BFCodec.h"
#import "EAGLView.h"
#import "EditRendererConf.h"
#import "EditSequence.h"
#import "KUnzip.h"
#import "MarkerManager.h"
#import "Texture2D.h"
#import "TextureLoading.h"
#import "cipher_keys.h"
#import "neEngineBridge.h"

// The engine's pi and 0.2 background constants, declared where used.
extern const double g_dPi;              // @ghidraAddress 0x28f278
extern const double g_dAnimDuration020; // @ghidraAddress 0x28f240 (0.2)

// The C standard library sine, imported for the beat pulse.
extern double sin(double);

// The state that entering triggers the result BGM, and the state that lazily loads the "go" cue.
static const unsigned int kEditRenderStateResult = 5;
static const unsigned int kEditRenderStateReady = 2;
static const unsigned int kEditRenderStatePlay = 3;
static const unsigned int kEditRenderStateFinish = 4;
static const unsigned int kEditRenderStatePreStart = 1;

// The sub-state that marks the play session as finished.
static const unsigned int kEditNoteEndSubState = 99;

// The panel grid is 4x4; each cell is 0xc0 (192) points wide/tall, and the grid sits 0x100 (256)
// points below the upper region.
static const int kEditPanelGridColumns = 4;
static const int kEditPanelGridStride = 0xc0;
static const int kEditPanelGridTop = 0x100;
static const int kEditPanelMarkerInset = 0x10;
static const int kEditPanelCount = 16;

// The marker-state word packs the animation phase in the low 12 bits and the marker slot in the
// next 3 bits.
static const unsigned int kMarkerPhaseMask = 0xfff;
static const unsigned int kMarkerSlotShift = 12;
static const unsigned int kMarkerSlotMask = 7;

// Sprite indices in the front atlas.
static const NSUInteger kSpriteBackground = 0x24;
static const NSUInteger kSpriteRailBase = 0x13; // The four side rails run 0x13..0x16.
static const NSUInteger kSpriteMeasureLine = 8; // Base-line kinds map onto sprites 8..0xb, 0x18.
static const NSUInteger kSpriteBeatLine = 9;
static const NSUInteger kSpriteBarLine = 10;
static const NSUInteger kSpriteSubdivLine = 0xb;
static const NSUInteger kSpritePasteLine = 0x18;
static const NSUInteger kSpriteMeasureZero = 0x1d; // "0" measure glyph; -1 uses 0x1e.
static const NSUInteger kSpriteMeasureBlank = 0x1e;
static const NSUInteger kSpriteMeasureDigitBase = 0xa5; // digits '0'..'9' at 0xa5..0xae.
static const NSUInteger kSpriteMusicBarBg = 6;
static const NSUInteger kSpritePlayHead = 7;
static const NSUInteger kSpriteMusicNoteBase = 0x7d;     // no conflict.
static const NSUInteger kSpriteMusicNoteConflict = 0x9d; // conflict.
static const NSUInteger kSpriteSelectFill = 0x1c;
static const NSUInteger kSpriteSelectStartHandle = 0x1a;
static const NSUInteger kSpriteSelectEndHandle = 0x1b;
static const NSUInteger kSpriteUpperBG = 0x23;
static const NSUInteger kSpriteUpperDivider = 4;
static const NSUInteger kSpriteUpperFrame = 5;
static const NSUInteger kSpriteClapIndicator = 0x1f;
static const NSUInteger kSpriteFieldLeft = 0x13; // renderSequenceChip field grid rails.
static const NSUInteger kSpriteFieldGridLine = 0xe;

// Layout constants shared by several methods.
static const float kSectorBasePos = 100.0f;     // @ghidraAddress 0x28f4e0
static const double kFieldTopY = 80.0;          // @ghidraAddress 0x28f3f8
static const double kSelectHandleInsetX = 0x15; // The handles sit 21 points left of the boundary.
static const double kMeasureLabelInsetX = 0x19; // The area handles sit 25 points left of origin.

// The clamped grid-zoom bounds for -setDbs: .
static const float kGridZoomMin = 0.2f; // @ghidraAddress 0x28f3c8
static const float kGridZoomMax = 1.0f;

@implementation EditNoteRendererPad

#pragma mark - Lifecycle

/** @ghidraAddress 0x20b214 */
- (instancetype)init {
    self = [super init];
    if (self) {
        self->baseAlpha = 1.0f;
        self->modeCnt = 0.0f;
        self.enableClap = YES;
        self->dotBySec = 1.0f;
        self->baseScale = 1.0f;
        self->pinchScaleBak = 1.0f;
    }
    return self;
}

/** @ghidraAddress 0x20e8a8 */
- (void)dealloc {
    [self releaseTexture];
    // [super dealloc] is compiler-emitted (ARC).
}

#pragma mark - Textures

/** @ghidraAddress 0x20bd90 */
- (void)releaseTexture {
    self.texDebugFont = nil;
    self.texFront = nil;
    self.texChip = nil;
}

/** @ghidraAddress 0x20b2b4 */
- (void)loadTexure:(EditRendererConf *)conf artwork:(UIImage *)artwork index:(UIImage *)index {
    NSData *cipherKey = CreateTextureCipherKey();
    BFCodec *cipher = [[BFCodec alloc] init];
    [cipher cipherInit:cipherKey];

    if (!self.texDebugFont) {
        self.texDebugFont = CreateTexture2DFromPngResource(@"debugfont");
    }

    // Clamp the configuration into the range the edit atlases cover.
    if ((unsigned int)conf.diff > 2) {
        conf.diff = 2;
    }
    if ((unsigned int)conf.level > 10) {
        conf.level = 10;
    }

    // If the front atlas is already loaded for this exact marker, difficulty, level, and tune,
    // there is nothing to reload.
    if (self.texFront && [conf.markerID isEqualToString:self.rendererConf.markerID] &&
        conf.diff == self.rendererConf.diff && conf.level == self.rendererConf.level &&
        conf.tuneID == self.rendererConf.tuneID) {
        return;
    }

    @autoreleasepool {
        if (self.texFront) {
            self.texFront = nil;
        }
        if (conf.diff != 0) {
            (void)conf.diff; // Yes, the binary re-reads diff here for effect only.
        }

        // Build the front atlas: an empty 2048-square texture whose sprite rects come from the
        // plist, then the two encrypted halves blitted in.
        Texture2D *front = [[Texture2D alloc] initWithData:nullptr
                                               pixelFormat:Texture2DPixelFormatRGBA8888
                                                 pixelSize:0x800];
        self.texFront = front;
        NSString *frontPlist = [NSBundle.mainBundle pathForResource:@"game_front_edit_tex"
                                                             ofType:@"plist"];
        self.texFront.sprites = [[NSArray alloc] initWithContentsOfFile:frontPlist];

        /** @ghidraAddress 0x2943f8 */
        static const CGFloat kFrontHalfY = 760.0;
        [cipher cipherInit:cipherKey];
        LoadTextureSubImageFromEncryptedTex(
            self.texFront, @"game_front_edit_tex_1", cipher, CGPointMake(0.0, 0.0));
        [cipher cipherInit:cipherKey];
        LoadTextureSubImageFromEncryptedTex(
            self.texFront, @"game_front_edit_tex_2", cipher, CGPointMake(0.0, kFrontHalfY));
    }

    // Blit the 24 marker frames (sprites 0x25 upward) from the marker archive.
    NSString *markerPath = [MarkerManager getMarkerPath:conf.markerID];
    KUnzip *markerZip = [[KUnzip alloc] initWithPath:markerPath];
    for (int i = 0; i < 0x18; ++i) {
        [cipher cipherInit:cipherKey];
        NSString *entry = [NSString stringWithFormat:@"ma%02d", i];
        NSMutableData *bytes = [markerZip uncompress:entry];
        UIImage *image = CreateImageFromEncryptedData(cipher, bytes);
        if (image) {
            [self.texFront setSubImage:image
                                inRect:[self.texFront spriteAtIndex:(unsigned int)(i + 0x25)]];
        }
    }

    // Blit the four hold-marker rows (h0..h3), each 16 frames, into the sprite bands the offset
    // table names.
    /** @ghidraAddress 0x294420 */
    static const int kHoldSpriteBase[] = {61, 77, 93, 109};
    for (int row = 0; row < 4; ++row) {
        @autoreleasepool {
            for (int i = 0; i < kEditPanelCount; ++i) {
                [cipher cipherInit:cipherKey];
                NSString *entry = [NSString stringWithFormat:@"h%d%02d", row, i];
                NSMutableData *bytes = [markerZip uncompress:entry];
                UIImage *image = CreateImageFromEncryptedData(cipher, bytes);
                if (image) {
                    unsigned int idx = (unsigned int)(i + kHoldSpriteBase[row]);
                    [self.texFront setSubImage:image inRect:[self.texFront spriteAtIndex:idx]];
                }
            }
        }
    }

    // Blit the music-bar strip into sprite 6.
    LoadTextureSubImageFromResource(
        self.texFront, @"edit_musicbar", [self.texFront spriteAtIndex:kSpriteMusicBarBg].origin);

    // Build the chip atlas the same way, from its own plist and one encrypted image.
    if (self.texChip) {
        self.texChip = nil;
    }
    Texture2D *chip = [[Texture2D alloc] initWithData:nullptr
                                          pixelFormat:Texture2DPixelFormatRGBA8888
                                            pixelSize:0x40];
    self.texChip = chip;
    NSString *chipPlist = [NSBundle.mainBundle pathForResource:@"game_chip_edit_tex"
                                                        ofType:@"plist"];
    self.texChip.sprites = [[NSArray alloc] initWithContentsOfFile:chipPlist];
    [cipher cipherInit:cipherKey];
    LoadTextureSubImageFromEncryptedTex(
        self.texChip, @"game_chip_edit_tex", cipher, CGPointMake(0.0, 0.0));

    self.rendererConf = conf;
}

#pragma mark - Play lifecycle

/** @ghidraAddress 0x20bde0 */
- (void)setState:(unsigned int)state {
    if (state == kEditRenderStateResult) {
        [[AudioManager sharedManager] loadBgmResAAC:@"SD_KNT_BGM_RESULT" inDirectory:nil];
        [[AudioManager sharedManager] startBgm:YES fadeTime:0.0];
    } else if (state == kEditRenderStateReady) {
        self->lastCombo = 0;
        self->shutterOpen = 0.0f;
        self->startMarkFrame = 0;
        if (!self.sePlayerGo) {
            NSString *path = [NSBundle.mainBundle pathForResource:@"SD_KNT_CV_GO" ofType:@"caf"];
            NSError *error = nil;
            self.sePlayerGo =
                [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                       error:&error];
            [self.sePlayerGo prepareToPlay];
        }
    } else if (state == 0) {
        self->lastCombo = 0;
        self->shutterOpen = 0.0f;
        self->lastHakuPhase = 0.0f;
        self->bounceEnergy = 0.0f;
        self->conflictDot = (int)((float)[self.sequence getConflictSector] / self->dotBySec);
    }
    self->frame = 0;
    [super setState:state];
}

/** @ghidraAddress 0x20c0d8 */
- (void)startPlay {
    [self setState:kEditRenderStatePlay];
    self.sePlayerGo = nil;
}

/** @ghidraAddress 0x20c114 */
- (void)endResult {
    if (self.state == kEditRenderStateResult) {
        self.subState = kEditNoteEndSubState;
    }
}

/** @ghidraAddress 0x20c160 */
- (void)resetCurrentTime {
    self->clapSector = self.currentSector;
}

/** @ghidraAddress 0x20e428 */
- (void)setDbs:(float)dbs {
    float zoom = self->baseScale / dbs;
    if (zoom <= kGridZoomMin) {
        zoom = kGridZoomMin;
    }
    if (kGridZoomMax < zoom) {
        zoom = kGridZoomMax;
    }
    self->dotBySec = zoom;
    self->conflictDot = (int)((float)[self.sequence getConflictSector] / self->dotBySec);
}

/** @ghidraAddress 0x20e4c0 */
- (void)saveBaseScale {
    self->baseScale = self->dotBySec;
}

#pragma mark - Layout

/** @ghidraAddress 0x20e8f8 */
- (CGRect)getTimeLineRect {
    /** @ghidraAddress 0x292e58 (x), 0x2929f0 (y), 0x291c30 (width), 0x291de0 (height) */
    return CGRectMake(84.0, 208.0, 600.0, 43.0);
}

/** @ghidraAddress 0x20cba8 */
- (CGRect)getAreaSelectStart {
    int x = (int)((float)(self.areaStartSector - self.currentSector) / self->dotBySec +
                  kSectorBasePos) -
            (int)kMeasureLabelInsetX;
    /** @ghidraAddress 0x294410 (y), 0x28f2c8 (size) */
    return CGRectMake((double)x, 171.0, 50.0, 50.0);
}

/** @ghidraAddress 0x20cc28 */
- (CGRect)getAreaSelectEnd {
    int x =
        (int)((float)(self.areaEndSector - self.currentSector) / self->dotBySec + kSectorBasePos) -
        (int)kMeasureLabelInsetX;
    /** @ghidraAddress 0x294410 (y), 0x28f2c8 (size) */
    return CGRectMake((double)x, 171.0, 50.0, 50.0);
}

/** @ghidraAddress 0x20e418 */
- (double)buttonAreaOffset {
    return 0.0;
}

#pragma mark - Coordinate conversion

/** @ghidraAddress 0x20caec */
- (int)dot2sector:(int)dot {
    return (int)((float)dot * self->dotBySec);
}

/** @ghidraAddress 0x20cb08 */
- (int)pos2sector:(int)pos {
    return (int)((float)self.currentSector + (float)(pos - (int)kSectorBasePos) * self->dotBySec);
}

/** @ghidraAddress 0x20cb54 */
- (int)sector2pos:(int)sector {
    return (int)((float)(sector - self.currentSector) / self->dotBySec + kSectorBasePos);
}

#pragma mark - Field rendering

/** @ghidraAddress 0x20c550 */
- (void)renderBG {
    // A beat pulse from the sequence's haku phase modulates the background scale.
    double phase = 0.0;
    if (self.sequence) {
        phase = (double)[self.sequence hakuPhase] * g_dPi;
    }
    float pulse = (float)(sin(phase) * g_dAnimDuration020);

    /** @ghidraAddress 0x28f750 (x=128), 0x292470 (y=384), 0x292550 (768), 0x292abc (1/512),
     *  0x291d80 (anchor.y=640) */
    [self.texFront drawSprite:0x22
                      atPoint:CGPointMake(128.0, 384.0)
                        scale:(pulse + 1.0f) * 768.0f * 0.00195312f
                       rotate:0.0f
                       anchor:CGPointMake(384.0, 640.0)
                    transform:0
                        alpha:self->baseAlpha];

    // The four side rails: sprites 0x13..0x16 fill four 192-wide columns from x=0, y=256, h=768.
    float railAlpha = self->baseAlpha * 0.8f; // @ghidraAddress 0x28f3c0 (0.8)
    /** @ghidraAddress 0x28e030 (256), 0x28fa00 (192), 0x292460 (768), 0x292470 (384),
     *  0x291d88 (576) */
    [self.texFront drawSprite:kSpriteRailBase
                       inRect:CGRectMake(0.0, 256.0, 192.0, 768.0)
                    transform:0
                        alpha:railAlpha];
    [self.texFront drawSprite:kSpriteRailBase + 1
                       inRect:CGRectMake(192.0, 256.0, 192.0, 768.0)
                    transform:0
                        alpha:railAlpha];
    [self.texFront drawSprite:kSpriteRailBase + 2
                       inRect:CGRectMake(384.0, 256.0, 192.0, 768.0)
                    transform:0
                        alpha:railAlpha];
    [self.texFront drawSprite:kSpriteRailBase + 3
                       inRect:CGRectMake(576.0, 256.0, 192.0, 768.0)
                    transform:0
                        alpha:railAlpha];

    /** @ghidraAddress 0x294408 (535) */
    [self.texFront drawSprite:kSpriteBackground atPoint:CGPointMake(0.0, 535.0)];
}

/** @ghidraAddress 0x20c810 */
- (void)renderShutter:(BOOL)open {
    // The pad renderer draws no shutter.
}

/** @ghidraAddress 0x20c378 */
- (void)renderMarker {
    // Snapshot every panel's animation word from the sequence.
    [self.sequence getMarkerState:self->markerState];
    for (int i = 0; i < kEditPanelCount; ++i) {
        int column = (i % kEditPanelGridColumns) * kEditPanelGridStride;
        int row = (i / kEditPanelGridColumns) * kEditPanelGridStride;
        unsigned int word = (unsigned int)self->markerState[i];
        unsigned int phase = word & kMarkerPhaseMask;
        unsigned int slot = (word >> kMarkerSlotShift) & kMarkerSlotMask;

        int sprite;
        if (slot == 0) {
            if (phase >= 0xf0) {
                continue;
            }
            sprite = (int)(phase / 10) + 0x25;
        } else if (phase < 0xa0 && slot < 6) {
            sprite = (int)(phase / 10) + (int)(slot * 0x10) + 0x1d;
        } else {
            continue;
        }

        [self.texFront
            drawSprite:(NSUInteger)sprite
               atPoint:CGPointMake((double)(column | kEditPanelMarkerInset),
                                   (double)((row | kEditPanelMarkerInset) + kEditPanelGridTop))];
        if ([self.sequence checkKeyConflict:i]) {
            [self renderButtonLight:3
                            atPoint:CGPointMake((double)column, (double)(row + kEditPanelGridTop))];
        }
    }
}

/** @ghidraAddress 0x20c814 */
- (void)renderMusicBar:(CGPoint)pos timeline:(BOOL)timeline alpha:(double)alpha {
    // The scrubber background sits 8 points left of pos.
    [self.texFront drawSprite:kSpriteMusicBarBg
                      atPoint:CGPointMake(pos.x - 8.0, pos.y)
                    transform:0
                        alpha:(float)((double)self->baseAlpha * alpha)];
    if (!self.sequence) {
        return;
    }

    float playPosition = [self.sequence playPosition];
    const char *bar = [self.sequence getMusicBar];
    const char *conflictBar = [self.sequence getConflictBar];

    /** @ghidraAddress 0x292488 (76-point inset) */
    double baseX = pos.x + 76.0;
    int step = 0;
    for (int i = 0; i < 0x78; ++i, step += 5) {
        // Two 4-bit nibbles pack per byte; read this beat's note nibble.
        int idx = i >> 1;
        int shift = (i & 1) * 4;
        unsigned int note = (((int)bar[idx] >> shift) & 0xf) - 1;
        if (note < 8) {
            int spriteBase = kSpriteMusicNoteBase;
            if ((((int)conflictBar[idx] >> shift) & 0xf) != 0) {
                spriteBase = kSpriteMusicNoteConflict;
            }
            [self.texFront drawSprite:(NSUInteger)((int)note + spriteBase)
                              atPoint:CGPointMake(baseX + (double)step, pos.y + 1.0)
                            transform:0
                                alpha:(float)((double)self->baseAlpha * alpha)];
        }
    }

    if (timeline) {
        /** @ghidraAddress 0x291c3c (600), 0x28fa28 (74), 0x28f6b0 (197) */
        [self.texFront drawSprite:kSpritePlayHead
                          atPoint:CGPointMake((double)(playPosition * 600.0f + 74.0f), 197.0)
                        transform:0
                            alpha:(float)((double)self->baseAlpha * alpha)];
    }
}

/** @ghidraAddress 0x20cca8 */
- (void)renderNoteChip:(float)posX keyIndex:(int)keyIndex uniType:(int)uniType alpha:(float)alpha {
    // The chip's cell height comes from the chip atlas's own sprite 0.
    CGRect cell = [self.texChip spriteAtIndex:0];
    double cellHeight = cell.size.height;

    // Map the 0..15 panel index to a row-major cell (columns and rows swapped from the raw index).
    int col = keyIndex % kEditPanelGridColumns;
    int row = keyIndex / kEditPanelGridColumns;
    int cellIndex = col * kEditPanelGridColumns + row;
    double y = (double)(int)((double)cellIndex * cellHeight + kFieldTopY);

    int conflict = self->conflictDot;
    int halfConflict = conflict >> 1;
    NSUInteger sprite = (uniType == 1) ? 1 : 0;

    // The under-chip (dimmed by the conflict fade) then the chip itself, both untransformed.
    /** @ghidraAddress 0x28e0b0 (g_flComboFadeBase, 0.3) */
    [self.texChip drawSprite:sprite
                      inRect:CGRectMake((double)((posX - 2.0f) - (float)halfConflict),
                                        y,
                                        (double)conflict,
                                        cellHeight)
                   transform:0
                       alpha:alpha * g_flComboFadeBase];
    [self.texChip drawSprite:sprite
                     atPoint:CGPointMake((double)(posX - 2.0f), y)
                   transform:0
                       alpha:alpha];
}

/** @ghidraAddress 0x20ce30 */
- (void)renderBaseLine:(float)posX lineType:(int)lineType alpha:(float)alpha {
    /** @ghidraAddress 0x28f5f0 (78) */
    double y = 78.0;
    NSUInteger sprite;
    switch (lineType) {
    case 0:
        posX -= 1.0f;
        sprite = kSpriteBarLine;
        break;
    case 1:
        posX -= 1.0f;
        sprite = kSpriteBeatLine;
        break;
    case 2:
        posX -= 1.0f;
        sprite = kSpriteMeasureLine;
        break;
    case 3:
        sprite = kSpriteSubdivLine;
        break;
    case 4:
        posX -= 3.0f;
        sprite = kSpritePasteLine;
        /** @ghidraAddress 0x292488 (76) */
        y = 76.0;
        break;
    default:
        sprite = kSpriteBeatLine;
        break;
    }
    [self.texFront drawSprite:sprite atPoint:CGPointMake((double)posX, y) transform:0 alpha:alpha];
}

/** @ghidraAddress 0x20cf2c */
- (void)renderMeasureNum:(int)measure posX:(float)posX alpha:(float)alpha {
    /** @ghidraAddress 0x291bd0 (180) */
    static const double kMeasureLabelY = 180.0;

    if (measure == -1) {
        CGRect glyph = [self.texFront spriteAtIndex:kSpriteMeasureBlank];
        double x = (double)posX + glyph.size.width * -0.5;
        [self.texFront drawSprite:kSpriteMeasureBlank
                          atPoint:CGPointMake(x, kMeasureLabelY)
                        transform:0
                            alpha:alpha];
        return;
    }
    if (measure == 0) {
        CGRect glyph = [self.texFront spriteAtIndex:kSpriteMeasureZero];
        double x = (double)posX + glyph.size.width * -0.5;
        [self.texFront drawSprite:kSpriteMeasureZero
                          atPoint:CGPointMake(x, kMeasureLabelY)
                        transform:0
                            alpha:alpha];
        return;
    }

    // Count the decimal digits of (measure + 1), then draw them right-to-left.
    int value = measure + 1;
    int digits;
    if ((unsigned int)(measure + 10) < 0x13) {
        digits = 1;
    } else {
        int n = value;
        int count = 0;
        do {
            n /= 10;
            ++count;
        } while ((unsigned int)(n + 9) > 0x12);
        digits = count + 2;
    }

    float x = (float)(digits * 5 - 10) + posX;
    for (int remaining = digits; remaining != 0; --remaining) {
        [self.texFront drawSprite:(NSUInteger)(value % 10 + (int)kSpriteMeasureDigitBase)
                          atPoint:CGPointMake((double)x, kMeasureLabelY)
                        transform:0
                            alpha:alpha];
        x -= 10.0f;
        value /= 10;
    }
}

/** @ghidraAddress 0x20d1b4 */
- (void)renderSelectArea:(float)alpha {
    if (self.areaStartSector < 0 || self.areaEndSector < 0) {
        return;
    }
    int startX =
        (int)((float)(self.areaStartSector - self.currentSector) / self->dotBySec + kSectorBasePos);
    int endX =
        (int)((float)(self.areaEndSector - self.currentSector) / self->dotBySec + kSectorBasePos);

    /** @ghidraAddress 0x28f3b8 (0.6), 0x28f3f8 (80), 0x28f908 (96) */
    [self.texFront drawSprite:kSpriteSelectFill
                       inRect:CGRectMake((double)startX, 80.0, (double)(endX - startX), 96.0)
                    transform:0
                        alpha:alpha * 0.6f];
    [self renderBaseLine:(float)startX lineType:4 alpha:alpha];
    [self renderBaseLine:(float)endX lineType:4 alpha:alpha];

    /** @ghidraAddress 0x291cf8 (178) */
    [self.texFront drawSprite:kSpriteSelectStartHandle
                      atPoint:CGPointMake((double)(startX - (int)kSelectHandleInsetX), 178.0)
                    transform:0
                        alpha:alpha];
    [self.texFront drawSprite:kSpriteSelectEndHandle
                      atPoint:CGPointMake((double)(endX - (int)kSelectHandleInsetX), 178.0)
                    transform:0
                        alpha:alpha];
}

/** @ghidraAddress 0x20d3d8 */
- (void)renderPastLine:(float)alpha {
    // Only when a start sector is set but no end sector is.
    if (self.areaStartSector < 0 || self.areaEndSector >= 0) {
        return;
    }
    float startX =
        (float)(int)((float)(self.areaStartSector - self.currentSector) / self->dotBySec +
                     kSectorBasePos);
    [self renderBaseLine:startX lineType:4 alpha:alpha];

    const EditSequenceEvent *paste = [self.sequence getSequencePasteTable];
    if (paste->type == EditSequenceEventTypeMeasure) {
        return;
    }
    int i = 0;
    const EditSequenceEvent *event = paste;
    do {
        float basePos = -((float)(self.areaStartSector - self.currentSector) / self->dotBySec);
        [self renderSequenceParts:i event:paste basePos:basePos uniType:1 alpha:alpha];
        ++i;
        ++event;
    } while (event->type != EditSequenceEventTypeMeasure);
}

/** @ghidraAddress 0x20d560 */
- (void)renderSequenceParts:(int)index
                      event:(const EditSequenceEvent *)event
                    basePos:(float)basePos
                    uniType:(int)uniType
                      alpha:(float)alpha {
    const EditSequenceEvent *ev = &event[index];
    if ((unsigned int)(ev->type - 1) > 3) {
        return;
    }
    float posX = ((float)ev->position / self->dotBySec + kSectorBasePos) - basePos;
    switch (ev->type) {
    case EditSequenceEventTypeNote:
        [self renderNoteChip:posX keyIndex:ev->keyIndex uniType:uniType alpha:alpha];
        return;
    case EditSequenceEventTypeMeasure:
        [self renderBaseLine:posX lineType:1 alpha:alpha];
        [self renderMeasureNum:-1 posX:posX alpha:alpha];
        return;
    case EditSequenceEventTypeBpm:
        [self renderBaseLine:posX lineType:1 alpha:alpha];
        [self renderMeasureNum:ev->measure posX:posX alpha:alpha];
        return;
    case EditSequenceEventTypeBar: {
        [self renderBaseLine:posX lineType:2 alpha:alpha];
        if (self.divMeasure < 2) {
            return;
        }
        // Subdivide the bar up to the next measure line by divMeasure equal steps.
        int i = index;
        const EditSequenceEvent *cursor = ev;
        while (true) {
            ++cursor;
            ++i;
            if (i > 1999) {
                return;
            }
            if (cursor->type == EditSequenceEventTypeMeasure) {
                return;
            }
            if (cursor->type == EditSequenceEventTypeBar) {
                int span = cursor->endPosition - ev->position;
                if (self.divMeasure < 1) {
                    return;
                }
                int accum = span;
                for (int step = 1; step <= self.divMeasure; ++step) {
                    int offset = (self.divMeasure != 0) ? accum / self.divMeasure : 0;
                    [self renderBaseLine:posX + (float)offset / self->dotBySec
                                lineType:3
                                   alpha:alpha];
                    accum += span;
                }
                return;
            }
        }
    }
    default:
        return;
    }
}

/** @ghidraAddress 0x20d838 */
- (void)renderSequenceChip:(float)alpha {
    int currentSector = self.currentSector;
    float sectorF = (float)currentSector;
    float zoom = self->dotBySec;

    int conflict = self->conflictDot;
    const EditSequenceEvent *events = [self.sequence getSequenceEventTable];

    /** @ghidraAddress 0x2934a4 (-100) */
    static const float kLeftEdgeSectors = -100.0f;
    unsigned int leftDot =
        (unsigned int)((sectorF + zoom * kLeftEdgeSectors) - zoom * (float)conflict);
    if ((int)leftDot < 0) {
        leftDot = 0;
    }

    // Find the first event at or after the left edge.
    int first = -1;
    const EditSequenceEvent *scan = events;
    unsigned int pos = events->position;
    while (pos <= leftDot) {
        if (scan->type == EditSequenceEventTypeMeasure) {
            first = 0;
            break;
        }
        ++scan;
        ++first;
        pos = scan->position;
    }

    // The four stacked field-grid bands (sprites 0x13..0x16). Each band is as wide as the eaglView
    // and as tall as four times the height of sprite 0xc; the second, third, and fourth are offset
    // by 0x50 then successive band heights.
    int bandWidth = (int)self.eaglView.frame.size.width;
    int bandHeight = (int)([self.texFront spriteAtIndex:0xc].size.height * 4.0f);
    double width = (double)bandWidth;
    double height = (double)bandHeight;
    [self.texFront drawSprite:kSpriteFieldLeft
                       inRect:CGRectMake(0.0, kFieldTopY, width, height)
                    transform:0
                        alpha:alpha];
    [self.texFront drawSprite:kSpriteFieldLeft + 1
                       inRect:CGRectMake(0.0, (double)(bandHeight + 0x50), width, height)
                    transform:0
                        alpha:alpha];
    int y3 = bandHeight + 0x50 + bandHeight;
    [self.texFront drawSprite:kSpriteFieldLeft + 2
                       inRect:CGRectMake(0.0, (double)y3, width, height)
                    transform:0
                        alpha:alpha];
    [self.texFront drawSprite:kSpriteFieldLeft + 3
                       inRect:CGRectMake(0.0, (double)(y3 + bandHeight), width, height)
                    transform:0
                        alpha:alpha];

    // Rewind first to a bar boundary if it did not land on one.
    if (events[first].type != EditSequenceEventTypeBar && first > 0) {
        int back = 0;
        const EditSequenceEvent *rev = &events[first];
        do {
            --rev;
            if (first + back < 2) {
                break;
            }
            --back;
        } while (rev->type != EditSequenceEventTypeBar);
        first += back;
    }

    float basePos = (float)(int)(sectorF / zoom);
    unsigned int rightDot =
        (unsigned int)((int)(zoom * (float)(bandWidth - 100) + zoom * (float)conflict) +
                       currentSector);

    // Draw every event whose position falls within the window.
    if (events[first].position <= rightDot) {
        int i = first;
        const EditSequenceEvent *ev = &events[first];
        while (true) {
            if (ev->type != EditSequenceEventTypeNote) {
                [self renderSequenceParts:i event:events basePos:basePos uniType:0 alpha:alpha];
                if (ev->type == EditSequenceEventTypeMeasure) {
                    break;
                }
            }
            if (ev->endPosition > rightDot) {
                break;
            }
            ++ev;
            ++i;
        }
    }

    // A second pass draws the note events (skipped by the first) up to the right edge.
    int i = first;
    const EditSequenceEvent *ev = &events[first];
    if (ev->type != EditSequenceEventTypeMeasure) {
        while (true) {
            if (ev->position > rightDot) {
                break;
            }
            if (ev->type == EditSequenceEventTypeNote) {
                [self renderSequenceParts:i event:events basePos:basePos uniType:0 alpha:alpha];
            }
            ++ev;
            ++i;
            if (ev->type == EditSequenceEventTypeMeasure) {
                break;
            }
        }
    }

    // When the left edge is before position 0, draw the zeroth measure marker there.
    if (sectorF + zoom * kLeftEdgeSectors < 0.0f) {
        float zeroX = (float)(int)((0.0f / zoom + kSectorBasePos) - basePos);
        [self renderBaseLine:zeroX lineType:1 alpha:alpha];
        [self renderMeasureNum:0 posX:zeroX alpha:alpha];
    }

    // Draw the horizontal beat grid across the whole visible width, one line per glyph width.
    CGRect gridLine = [self.texFront spriteAtIndex:kSpriteFieldGridLine];
    double lineW = gridLine.size.width;
    int lineCount = (int)(((double)bandWidth + lineW - 4.0) / lineW);
    /** @ghidraAddress 0x28f5f0 (78), 0x28e038 (176) */
    for (int n = 0; n < lineCount; ++n) {
        double x = (double)(int)(lineW * (double)n);
        [self.texFront drawSprite:kSpriteFieldGridLine
                          atPoint:CGPointMake(x, 78.0)
                        transform:0
                            alpha:alpha];
        [self.texFront drawSprite:kSpriteFieldGridLine
                          atPoint:CGPointMake(x, 176.0)
                        transform:0
                            alpha:alpha];
    }

    [self renderSelectArea:alpha];
    [self renderPastLine:alpha];
    [self renderBaseLine:kSectorBasePos lineType:0 alpha:alpha];
}

/** @ghidraAddress 0x20de50 */
- (void)renderTuneInfo:(CGPoint)pos artworkSize:(double)artworkSize alpha:(double)alpha {
    // The pad renderer draws no tune-info panel.
}

/** @ghidraAddress 0x20de54 */
- (void)renderUpperBG:(float)alpha {
    [self.texFront drawSprite:kSpriteUpperBG atPoint:CGPointZero];

    CGRect divider = [self.texFront spriteAtIndex:kSpriteUpperDivider];
    /** @ghidraAddress 0x28f5f0 (78) */
    [self.texFront drawSprite:kSpriteUpperDivider
                      atPoint:CGPointMake(0.0, 78.0 - divider.size.height)
                    transform:2
                        alpha:alpha];
    /** @ghidraAddress 0x291cf8 (178) */
    [self.texFront drawSprite:kSpriteUpperDivider
                      atPoint:CGPointMake(0.0, 178.0)
                    transform:0
                        alpha:alpha];
    [self.texFront drawSprite:kSpriteUpperFrame atPoint:CGPointZero];

    if (self.enableClap) {
        /** @ghidraAddress 0x294418 (306) */
        [self.texFront drawSprite:kSpriteClapIndicator atPoint:CGPointMake(306.0, 0.0)];
    }
}

/** @ghidraAddress 0x20e020 */
- (void)renderUpper {
    /** @ghidraAddress 0x2929f0 (208) */
    [self renderMusicBar:CGPointMake(8.0, 208.0)
                timeline:(self.state == kEditRenderStatePlay)
                   alpha:(double)self->baseAlpha];
    [self renderSequenceChip:self->baseAlpha];
}

/** @ghidraAddress 0x20e08c */
- (void)renderButtonLight:(int)lightType atPoint:(CGPoint)point {
    [self.texFront drawSprite:(NSUInteger)lightType atPoint:point];
}

/** @ghidraAddress 0x20e0ec */
- (void)renderButtons {
    for (int i = 0; i < kEditPanelCount; ++i) {
        double x = (double)((i % kEditPanelGridColumns) * kEditPanelGridStride);
        double y = (double)((i / kEditPanelGridColumns) * kEditPanelGridStride + kEditPanelGridTop);
        NSUInteger lit = 0;
        if (self.enableBtn && (self.btnPress & (1 << i)) != 0) {
            [self renderButtonLight:2 atPoint:CGPointMake(x, y)];
            lit = 1;
        }
        [self.texFront drawSprite:lit atPoint:CGPointMake(x, y)];
    }
}

/** @ghidraAddress 0x20e234 */
- (void)renderPreStart {
    [self renderBG];
    [self renderShutter:YES];

    float upperAlpha = InterpolateFloatByFrame(0.0f, 1.0f, self->frame, 0, 10);
    [self renderUpperBG:upperAlpha * self->baseAlpha];

    /** @ghidraAddress 0x292ae4 (38), 0x28f438 (160) */
    float tuneX = InterpolateFloatByFrame(38.0f, 18.0f, self->frame, 10, 0x14);
    float tuneAlpha = InterpolateFloatByFrame(0.0f, 1.0f, self->frame, 10, 0x14);
    [self renderTuneInfo:CGPointMake((double)tuneX, 25.0)
             artworkSize:160.0
                   alpha:(double)tuneAlpha * (double)self->baseAlpha];

    float barAlpha = InterpolateFloatByFrame(0.0f, 1.0f, self->frame, 0, 10);
    /** @ghidraAddress 0x2929f0 (208) */
    [self renderMusicBar:CGPointMake(8.0, 208.0)
                timeline:NO
                   alpha:(double)barAlpha * (double)self->baseAlpha];
    [self renderSequenceChip:barAlpha * self->baseAlpha];
    [self renderButtons];

    if (self->frame == 0x14) {
        [[AudioManager sharedManager] playSeResFile:@"SD_MUON" inDirectory:nil];
        self.subState = 10;
    }
}

/** @ghidraAddress 0x20e410 */
- (void)renderFullcombo:(int)combo isResult:(BOOL)isResult {
    // The pad renderer draws no full-combo effect.
}

/** @ghidraAddress 0x20e414 */
- (void)renderFinish {
    // The pad renderer draws no finish effect.
}

#pragma mark - Buttons

/** @ghidraAddress 0x20e420 */
- (unsigned int)endButtonID {
    return 0xf;
}

#pragma mark - Drawing

/** @ghidraAddress 0x20e4dc */
- (void)draw {
    // Advance the display-mode cross-fade towards its target (10 when a mode is set, 0 otherwise).
    float delta = (self.displayMode != 0) ? 1.0f : -1.0f;
    float mode = self->modeCnt + delta;
    if (10.0f < mode) {
        mode = 10.0f;
    }
    if (mode <= 0.0f) {
        mode = 0.0f;
    }
    self->modeCnt = mode;

    switch (self.state) {
    case kEditRenderStatePreStart:
        [self renderPreStart];
        break;
    case kEditRenderStateReady:
        // State 2 draws nothing; fall through to the flush.
        break;
    case kEditRenderStatePlay:
        [self renderBG];
        [self renderShutter:YES];
        [self renderUpperBG:1.0f];
        [self renderUpper];
        [self renderMarker];
        [self renderButtons];
        break;
    case kEditRenderStateFinish:
        [self renderBG];
        [self renderShutter:YES];
        [self renderUpperBG:1.0f];
        [self renderUpper];
        [self renderMarker];
        [self renderButtons];
        [self renderFinish];
        break;
    case kEditRenderStateResult:
        [self renderBG];
        break;
    default:
        [self renderBG];
        [self renderShutter:YES];
        [self renderUpperBG:0.0f];
        [self renderButtons];
        break;
    }

    [self.texFront commitDraw];
    [self.texChip commitDraw];
    ++self->frame;
}

/** @ghidraAddress 0x20e728 */
- (void)drawDebugText:(const char *)text pos:(CGPoint)pos alpha:(float)alpha {
    double x = pos.x;
    double y = pos.y;
    int drawn = 0;
    for (long i = 0;; ++i) {
        char c = text[i];
        if (c == '\0') {
            break;
        }
        if (c == '\n') {
            y += 20.0;
            x = pos.x;
            continue;
        }
        if (c <= ' ' || c == '\x7f') {
            x += 12.0;
            continue;
        }
        [self.texDebugFont drawSprite:(NSUInteger)((long)c - 0x20)
                              atPoint:CGPointMake(x, y)
                            transform:0
                                alpha:self->baseAlpha * alpha];
        ++drawn;
        x += 12.0;
        if (drawn >= 0x200) {
            break;
        }
    }
    if (drawn != 0) {
        [self.texDebugFont commitDraw];
    }
}

/** @ghidraAddress 0x20c194 */
- (void)drawClip:(int)clip
    drawPosition:(CGPoint)drawPosition
        drawArea:(CGRect)drawArea
           alpha:(float)alpha {
    // The full sprite rectangle in texels: its origin is the source texel origin, its size the
    // drawn size on screen at drawPosition.
    CGRect sprite = [self.texFront spriteAtIndex:(unsigned int)clip];
    double spriteU = sprite.origin.x;
    double spriteV = sprite.origin.y;
    double spriteW = sprite.size.width;
    double spriteH = sprite.size.height;

    double posX = drawPosition.x;
    double posY = drawPosition.y;

    // The clip area is compared at single precision (the binary rounds it through floats).
    double areaX = (double)(float)drawArea.origin.x;
    double areaY = (double)(float)drawArea.origin.y;
    double areaRight = (double)(float)(drawArea.size.width + areaX);
    double areaBottom = (double)(float)(drawArea.size.height + areaY);

    // Reject unless the sprite drawn at drawPosition overlaps the clip area on both axes.
    if (!(posX + spriteW >= areaX && posX <= areaRight && posY + spriteH >= areaY &&
          posY <= areaBottom)) {
        return;
    }

    // Trim the horizontal axis: when the draw origin is left of the area, advance the destination
    // origin, shrink the width, and slide the source U to match; then clamp the right edge.
    double destX = posX;
    double srcU = spriteU;
    double horizWidth = spriteW;
    if (posX < areaX) {
        destX = areaX;
        horizWidth = spriteW - (areaX - posX);
        srcU = spriteU + (areaX - posX);
    }
    double finalWidth = horizWidth;
    if (horizWidth + destX > areaRight) {
        finalWidth = horizWidth - ((horizWidth + destX) - areaRight);
    }

    // Trim the vertical axis. Note the binary subtracts the top-clip amount from the *width*, not
    // the height, and starts the height from the full sprite height; both are reproduced verbatim.
    double destY = posY;
    double srcV = spriteV;
    double width = finalWidth;
    if (posY < areaY) {
        destY = areaY;
        width = finalWidth - (areaY - posY); // Yes, the binary trims width by the vertical clip.
        srcV = spriteV + (areaY - posY);
    }
    double height = spriteH;
    if (spriteH + destY > areaBottom) {
        height = spriteH - ((spriteH + destY) - areaBottom);
    }

    [self.texFront drawInRect:CGRectMake(destX, destY, width, height)
                   fromRegion:CGRectMake(srcU, srcV, width, height)
                    transform:0
                        alpha:self->baseAlpha * alpha];
}

@end
