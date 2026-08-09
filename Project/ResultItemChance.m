#import "ResultItemChance.h"

#import <math.h>

#import "AudioManager.h"
#import "BFCodec.h"
#import "Texture2D.h"
#import "TextureLoading.h"
#import "cipher_keys.h"

// The atlas is a 512x512 sheet built from an encrypted texture.
static const unsigned int kAtlasPixelFormat = 1;
static const unsigned int kAtlasPixelSize = 512;

// The particle field. Thirty-two sprites, indexed within the atlas from sprite 8 upwards.
static const int kParticleCount = 32;
static const int kParticleSpriteBase = 8;

// Sprite indices for the staged elements.
static const NSUInteger kSpriteItemIcon = 0;   // Doubles as the background sprite.
static const NSUInteger kSpriteTimesGlyph = 1; // The "x" between icon and number.
static const NSUInteger kSpriteBoard = 4;
static const NSUInteger kSpriteFlourish = 7;
static const unsigned int kSpriteSizeProbe = 8;

// Frame cues, in animation frames.
static const int kBackgroundStartFrame = 7;
static const int kIconStartFrame = 17;  // 0x11
static const int kBoardStartFrame = 25; // 0x19
static const int kFlourishFastPhase = 9;
static const int kFlourishSettleFrame = 32; // 0x20; the swing settles relative to this frame.
static const int kEffectStartFrame = 6;     // renderEffect measures elapsed from here.
static const int kSkipFrame = 50;           // 0x32
static const int kFinishFrame = 49; // 0x31; draw reports done once the frame counter passes it.

// Per-frame fade rates and the peaks they clamp to.
static const float kEighthPerFrame = 0.125f;   // @ghidraAddress 0x28f... (fmov 1/8)
static const float kQuarterPerFrame = 0.25f;   // fmov immediate.
static const float kBackgroundAlphaMax = 0.6f; // @ghidraAddress 0x28f3b8 (g_flKeyTime060)
static const float kFullAlpha = 1.0f;          // @ghidraAddress fmov immediate.

// Particle envelope shaping.
static const float kParticleSpread = 200.0f;     // @ghidraAddress 0x292b24
static const float kHalfTurnDegrees = 180.0f;    // @ghidraAddress 0x28f538
static const float kEnvelopeGain = 5.0f;         // @ghidraAddress fmov immediate 5.0.
static const float kEnvelopeFadeInKnee = 0.2f;   // @ghidraAddress 0x28f3c8 (s12)
static const float kEnvelopeFadeOutKnee = 0.8f;  // @ghidraAddress 0x28f3c0 (g_flKeyTime080, s13)
static const float kOddFrameFadeScale = 0.5f;    // @ghidraAddress fmov immediate 0.5.
static const float kEffectCenterOffset = -32.0f; // @ghidraAddress 0x292e98

// Particle seeding ranges.
static const int kSeedTypeCountFull = 9;    // rand() % 9 in setInfo:.
static const int kSeedTypeCountRestart = 3; // rand() % 3 in restartAnimation.
static const int kSeedAngleModulo = 360;    // 0x168
static const int kSeedLifetimeBase = 50;    // 0x32
static const int kSeedLifetimeModulo = 10;
static const int kSeedJitterStep = 5;
static const int kSeedJitterModulo = 10;
static const int kSeedJitterBias = 25; // 0x19
static const int kEffectTimeWrap = 7;  // effectTime cycles 0..8.

// Particle colour seeding: red and green are full, blue is a stepped random.
static const float kSeedColorFull = 255.0f; // @ghidraAddress 0x... (0x437f000000000000)
static const int kSeedBlueBase = 205;       // 0xcd
static const int kSeedBlueStep = 10;
static const int kSeedBlueModulo = 6;

// Layout nudges used while staging the icon, board, and flourish.
static const double kHalf = 0.5;            // @ghidraAddress fmov 0x3fe0000000000000.
static const double kBoardGap = 10.0;       // @ghidraAddress fmov 0x4024000000000000.
static const float kFlourishSwing = 10.0f;  // @ghidraAddress fmov immediates ±10.0.
static const CGFloat kColorRectSize = 64.0; // @ghidraAddress 0x28f1f0

// The sound effect played once as the item board lands.
static NSString *const kItemChanceSeName = @"SD_RESULT_ITEM";

// Resource base names loaded into the atlas.
static NSString *const kItemChanceTexName = @"item_chance_tex";
static NSString *const kItemChancePlistType = @"plist";
static NSString *const kItemIconFormat = @"chance_item_0%d";
static NSString *const kItemTimesName = @"item_chance_num_x";
static NSString *const kItemDigitFormat = @"item_chance_num_%d";

// The per-axis position jitter shared by setInfo: and restartAnimation: a stepped random offset
// biased negative.
static inline int SeedJitter(void) {
    return rand() % kSeedJitterModulo * kSeedJitterStep - kSeedJitterBias;
}

// Half of a sprite dimension in screen space at the current scale and alpha, as draw: uses it to
// centre each staged element.
static inline double ScaledHalfExtent(double dimension, float scale, float alpha) {
    return dimension * (double)scale * alpha * kHalf;
}

@implementation ResultItemChance {
    BOOL bPlaySe;                         // +0x08
    Texture2D *texEffect;                 // +0x10
    int animationFrame;                   // +0x18
    CGSize screenSize;                    // +0x20
    CGPoint screenCenter;                 // +0x30
    int effectSize;                       // +0x40
    float displayScale;                   // +0x44
    BOOL effectVisible[kParticleCount];   // +0x48
    int effectType[kParticleCount];       // +0x68
    int effectPos[kParticleCount][2];     // +0xe8
    int effectTime[kParticleCount];       // +0x1e8
    int effectEndTime[kParticleCount];    // +0x268
    float effectColor[kParticleCount][3]; // +0x2e8
}

#pragma mark - Texture lifetime

/** @ghidraAddress 0x139cac */
- (void)loadTexure {
    NSData *key = CreateTextureCipherKey();
    BFCodec *codec = [[BFCodec alloc] init];
    texEffect = [[Texture2D alloc] initWithData:nullptr
                                    pixelFormat:kAtlasPixelFormat
                                      pixelSize:kAtlasPixelSize];
    NSString *plistPath = [NSBundle.mainBundle pathForResource:kItemChanceTexName
                                                        ofType:kItemChancePlistType];
    [texEffect setSprites:[[NSArray alloc] initWithContentsOfFile:plistPath]];
    [codec cipherInit:key];
    LoadTextureSubImageFromEncryptedTex(texEffect, kItemChanceTexName, codec, CGPointZero);
    animationFrame = 0;
    for (int i = 0; i < kParticleCount; ++i) {
        effectVisible[i] = NO;
    }
    // The probe reads the size ivar from sprite 8's width. The decompiler mistakes it for the 512
    // constant loaded a few instructions earlier; the disassembly stores the sprite's own width.
    effectSize = (int)[texEffect spriteAtIndex:kSpriteSizeProbe].size.width;
}

/** @ghidraAddress 0x139e7c */
- (void)releaseTexture {
    texEffect = nil;
}

#pragma mark - Configuration

/** @ghidraAddress 0x139e94 */
- (void)setInfo:(int)itemType
        itemNum:(int)itemNum
           size:(CGSize)size
         center:(CGPoint)center
          scale:(float)scale {
    displayScale = 1.0f / scale;
    screenCenter = CGPointMake(center.x * (double)displayScale, center.y * (double)displayScale);
    screenSize = CGSizeMake(size.width * (double)displayScale, size.height * (double)displayScale);
    bPlaySe = NO;

    for (int i = 0; i < kParticleCount; ++i) {
        effectType[i] = rand() % kSeedTypeCountFull;
        effectVisible[i] = YES;
        effectTime[i] = 0;
        effectEndTime[i] = kSeedLifetimeBase - rand() % kSeedLifetimeModulo;

        float sinAngle;
        float cosAngle;
        __sincosf((float)(rand() % kSeedAngleModulo) / kHalfTurnDegrees * (float)M_PI,
                  &sinAngle,
                  &cosAngle);
        int spreadX = (int)(sinAngle * kParticleSpread) + SeedJitter();
        effectPos[i][0] = (int)(displayScale * (float)spreadX);
        int spreadY = (int)(cosAngle * kParticleSpread) + SeedJitter();
        effectPos[i][1] = (int)(displayScale * (float)spreadY);

        effectColor[i][0] = kSeedColorFull;
        effectColor[i][1] = kSeedColorFull;
        int blue = rand();
        effectColor[i][2] = (float)(blue % kSeedBlueModulo * kSeedBlueStep + kSeedBlueBase);
    }

    // Load the item icon into sprite 0. The blit point is the sprite's rect origin, which the
    // binary leaves in d0/d1 from the preceding spriteAtIndex: rather than passing explicitly.
    CGRect iconRect = [texEffect spriteAtIndex:kSpriteItemIcon];
    LoadTextureSubImageFromResource(
        texEffect, [NSString stringWithFormat:kItemIconFormat, itemType], iconRect.origin);

    if (itemNum > 1) {
        CGRect timesRect = [texEffect spriteAtIndex:kSpriteTimesGlyph];
        LoadTextureSubImageFromResource(texEffect, kItemTimesName, timesRect.origin);
        int digitCount = itemNum >= kSeedLifetimeModulo ? 2 : 1;
        NSUInteger digitSprite = (NSUInteger)(digitCount + 1);
        int remaining = itemNum;
        for (int placed = 0; placed < digitCount; ++placed) {
            NSString *digitName =
                [NSString stringWithFormat:kItemDigitFormat, remaining % kSeedLifetimeModulo];
            CGRect digitRect = [texEffect spriteAtIndex:(unsigned int)digitSprite];
            LoadTextureSubImageFromResource(texEffect, digitName, digitRect.origin);
            remaining /= kSeedLifetimeModulo;
            --digitSprite;
        }
    }

    animationFrame = 0;
}

#pragma mark - Drawing

/** @ghidraAddress 0x13a2a0 */
- (BOOL)draw {
    float backgroundAlpha =
        MIN((float)animationFrame * kEighthPerFrame * kBackgroundAlphaMax, kBackgroundAlphaMax);
    [texEffect drawSprite:kSpriteItemIcon
                   inRect:CGRectMake(0.0, 0.0, screenSize.width, screenSize.height)
                transform:6
                    alpha:backgroundAlpha];

    if (animationFrame >= kBackgroundStartFrame) {
        [self renderEffect];
        if (animationFrame >= kIconStartFrame) {
            if (!bPlaySe) {
                [AudioManager.sharedManager playSeResFile:kItemChanceSeName inDirectory:nil];
                bPlaySe = YES;
            }

            float iconAlpha =
                MIN((float)(animationFrame - (kIconStartFrame - 1)) * kEighthPerFrame, kFullAlpha);
            CGRect iconRect = [texEffect spriteAtIndex:kSpriteItemIcon];
            int iconX = (int)(screenCenter.x -
                              ScaledHalfExtent(iconRect.size.width, displayScale, iconAlpha));
            int iconY = (int)(screenCenter.y -
                              ScaledHalfExtent(iconRect.size.height, displayScale, iconAlpha));
            [texEffect drawSprite:kSpriteItemIcon
                          atPoint:CGPointMake(iconX, iconY)
                            scale:iconAlpha * displayScale
                           rotate:0.0f
                           anchor:CGPointMake(iconX, iconY)
                        transform:0
                            alpha:iconAlpha];

            if (animationFrame >= kBoardStartFrame) {
                float boardAlpha =
                    MIN((float)(animationFrame - (kBoardStartFrame - 1)) * kQuarterPerFrame,
                        kFullAlpha);
                int boardBaseY =
                    (int)(screenCenter.y +
                          ScaledHalfExtent(iconRect.size.height, displayScale, iconAlpha));
                double iconHalfWidth =
                    ScaledHalfExtent(iconRect.size.width, displayScale, iconAlpha);
                int boardBaseX = (int)(screenCenter.x + iconHalfWidth + kBoardGap);

                CGRect boardRect = [texEffect spriteAtIndex:kSpriteBoard];
                double boardHalfWidth =
                    ScaledHalfExtent(boardRect.size.width, displayScale, boardAlpha);
                int boardX = (int)((double)boardBaseX - boardHalfWidth);
                // The vertical offset omits the kHalf factor the horizontal one carries.
                int boardY = (int)((double)boardBaseY -
                                   boardRect.size.height * (double)displayScale * boardAlpha);
                [texEffect drawSprite:kSpriteBoard
                              atPoint:CGPointMake(boardX, boardY)
                                scale:boardAlpha * displayScale
                               rotate:0.0f
                               anchor:CGPointMake(boardX, boardY)
                            transform:0
                                alpha:boardAlpha];

                if (animationFrame >= kBoardStartFrame) {
                    float flourishAlpha =
                        MIN((float)(animationFrame - (kBoardStartFrame - 1)) * kEighthPerFrame,
                            kFullAlpha);
                    int flourishBaseY = (int)(boardRect.size.height + kBoardGap + (double)boardY);
                    CGRect flourishRect = [texEffect spriteAtIndex:kSpriteFlourish];
                    double flourishHalfWidth =
                        ScaledHalfExtent(flourishRect.size.width, displayScale, flourishAlpha);
                    int flourishX = (int)(screenCenter.x - flourishHalfWidth);

                    int phase = animationFrame - (kBoardStartFrame - 1);
                    float swing;
                    if (phase < kFlourishFastPhase) {
                        // For the first eight frames the flourish swings positive on a half-turn
                        // cosine of its own alpha.
                        swing = cosf(flourishAlpha * (float)M_PI) * kFlourishSwing;
                    } else {
                        // Afterwards it settles, swinging negative on a quarter-turn cosine of a
                        // separate ramp measured from frame 32.
                        float settle =
                            MIN((float)(animationFrame - kFlourishSettleFrame) * kQuarterPerFrame,
                                kFullAlpha);
                        swing = cosf(settle * (float)M_PI_2) * -kFlourishSwing;
                    }
                    int flourishY = (int)(displayScale * (float)(int)swing) + flourishBaseY;
                    [texEffect drawSprite:kSpriteFlourish
                                  atPoint:CGPointMake(flourishX, flourishY)
                                    scale:flourishAlpha * displayScale
                                   rotate:0.0f
                                   anchor:CGPointMake(flourishX, flourishY)
                                transform:0
                                    alpha:flourishAlpha];
                }
            }
        }
    }

    [texEffect commitDraw];
    int frameBefore = animationFrame;
    animationFrame = frameBefore + 1;
    return frameBefore > kFinishFrame;
}

/** @ghidraAddress 0x13a698 */
- (BOOL)enableSkip {
    return animationFrame > kSkipFrame;
}

/** @ghidraAddress 0x13a6b0 */
- (void)renderEffectParts:(int)type posX:(int)posX posY:(int)posY alpha:(float)alpha {
    [texEffect drawSprite:(NSUInteger)(type + kParticleSpriteBase)
                  atPoint:CGPointMake(posX, posY)
                    scale:displayScale
                   rotate:0.0f
                   anchor:CGPointMake(posX, posY)
                transform:0
                    alpha:alpha];
}

/** @ghidraAddress 0x13a6fc */
- (void)renderEffectParts:(int)type posX:(int)posX posY:(int)posY color:(id)color {
    [texEffect drawSprite:(NSUInteger)(type + kParticleSpriteBase)
                   inRect:CGRectMake(posX, posY, kColorRectSize, kColorRectSize)
                    color:color];
}

/** @ghidraAddress 0x13a734 */
- (void)renderEffect {
    for (int i = 0; i < kParticleCount; ++i) {
        if (!effectVisible[i]) {
            continue;
        }

        int elapsed = animationFrame - kEffectStartFrame;
        int endTime = effectEndTime[i];
        int t = MIN(elapsed, endTime);

        float envelope = sinf((float)((double)((float)t / (float)endTime) * M_PI_2));
        envelope = MIN(envelope, kFullAlpha);
        envelope = sinf((float)((double)envelope * M_PI_2));
        envelope = MIN(envelope, kFullAlpha);

        float fadeIn = envelope < kEnvelopeFadeInKnee ? envelope * kEnvelopeGain : kFullAlpha;
        float fadeOut = (kFullAlpha - envelope) * kEnvelopeGain;
        if ((t & 1) != 0) {
            fadeOut *= kOddFrameFadeScale;
        }
        float alpha = envelope <= kEnvelopeFadeOutKnee ? fadeIn : fadeOut;
        alpha = MAX(alpha, 0.0f);

        int localX = (int)(envelope * (float)effectPos[i][0] + kEffectCenterOffset);
        int localY = (int)(envelope * (float)effectPos[i][1] + kEffectCenterOffset);
        int posX = (int)((double)localX + screenCenter.x);
        int posY = (int)((double)localY + screenCenter.y);
        [self renderEffectParts:effectType[i] posX:posX posY:posY alpha:alpha];

        effectTime[i] = effectTime[i] > kEffectTimeWrap ? 0 : effectTime[i] + 1;
    }
}

#pragma mark - Restart

/** @ghidraAddress 0x13a918 */
- (void)restartAnimation {
    for (int i = 0; i < kParticleCount; ++i) {
        effectType[i] = rand() % kSeedTypeCountRestart;
        effectVisible[i] = YES;
        effectTime[i] = 0;
        effectEndTime[i] = kSeedLifetimeBase - rand() % kSeedLifetimeModulo;

        float sinAngle;
        float cosAngle;
        __sincosf((float)(rand() % kSeedAngleModulo) / kHalfTurnDegrees * (float)M_PI,
                  &sinAngle,
                  &cosAngle);
        // Unlike setInfo:, the spread is measured from effectSize and displayScale is not applied.
        effectPos[i][0] = (int)(sinAngle * kParticleSpread - (float)effectSize) + SeedJitter();
        effectPos[i][1] = (int)(cosAngle * kParticleSpread - (float)effectSize) + SeedJitter();
    }
    animationFrame = 0;
}

@end
