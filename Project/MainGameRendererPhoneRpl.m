#import "MainGameRendererPhoneRpl.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import "AudioManager.h"
#import "BFCodec.h"
#import "BGRipple.h"
#import "EAGLView.h"
#import "HoldMarkerRender.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "MarkerManager.h"
#import "RendererConf.h"
#import "Sequence.h"
#import "Texture2D.h"
#import "TextureLoading.h"
#import "UpperBGRipple.h"
#import "cipher_keys.h"
#import "combo_display.h"
#import "neEngineBridge.h"

// Pi as a __const literal-pool slot (not an exported global; the binary loads it inline).
static const double g_dPi = 3.141592653589793; // @ghidraAddress 0x28f278

// The animation key-time literals shared across the render family, loaded from __const.
static const float g_flKeyTime040 = 0.4f; // @ghidraAddress 0x28f3b4
static const float g_flKeyTime060 = 0.6f; // @ghidraAddress 0x28f3b8
static const float g_flKeyTime070 = 0.7f; // @ghidraAddress 0x28f3bc
static const float g_flKeyTime080 = 0.8f; // @ghidraAddress 0x28f3c0

// A 0.3 __const literal-pool slot the music bar uses to keep the cursor's own cell dim. Named to
// avoid colliding with combo_display's own fade base.
static const float kComboFadeBase = 0.3f; // @ghidraAddress 0x28e0b0 (loaded inline)

// -renderImage renders a view into a UIImage. It is a category the binary provides on UIView whose
// declaring class is not established; declared here so the partner-name label can be messaged.
@interface UIView (RenderImage)
- (nullable UIImage *)renderImage;
@end

// The high-level render states, dispatched on by -draw and -setState:.
static const unsigned int kRenderStatePreStart = 1;
static const unsigned int kRenderStateReadyGo = 2;
static const unsigned int kRenderStatePlay = 3;
static const unsigned int kRenderStateFinish = 4;
static const unsigned int kRenderStateResult = 5;
static const unsigned int kRenderStateResultWait = 6;

// The sub-state that marks the play session as finished.
static const unsigned int kMainGameEndSubState = 99;

// The 4x4 grid: each phone cell is 0x50 (80) points on a side, inset by 6, with the grid sitting
// 0xa0 (160) points below the game-area top.
static const int kGridCellSize = 0x50;
static const int kGridMarkerInset = 6;
static const int kGridTopOffset = 0xa0;

// The per-panel button-cell corner inset for the good-job/twitter/store positions, in points.
static const int kButtonCellInset = 0x28;

// The combo counter shows only above four.
static const unsigned int kComboDrawThreshold = 4;

// The clear/excellent score thresholds.
static const int kRankClearThreshold = 700000;
static const int kExcellentScore = 1000000;

// The four-inch phone applies the button margin below 0xa0, matching the base plate top.
static const int kFourInchGameTop = 0xa0;

// The one-letter difficulty code spliced into the "game_diff_%s_rpl" and "game_mbar_%s_rpl"
// resource names: basic, advanced, extreme, or the fallback code. Selected from single-character
// C strings at 0x280488..0x28048e.
static inline const char *MainGameRendererPhoneRplDiffCode(int diff) {
    switch (diff) {
    case 0:
        return "b"; // @ghidraAddress 0x280488
    case 1:
        return "a"; // @ghidraAddress 0x28048a
    case 2:
        return "e"; // @ghidraAddress 0x28048c
    default:
        return "o"; // @ghidraAddress 0x28048e
    }
}

@implementation MainGameRendererPhoneRpl

#pragma mark - Lifecycle

/** @ghidraAddress 0x147758 */
- (instancetype)init {
    if ((self = [super init])) {
        // The background ripple pool and the upper-background ripple pool, each up to 64 sprites.
        self.arrayBgRip = [[NSMutableArray alloc] initWithCapacity:0x40];
        self.arrayUpperBgRip = [[NSMutableArray alloc] initWithCapacity:0x40];
        isRetina = JubeatAppDelegate.appDelegate.isPhoneRetina;
        is4Inch = JubeatAppDelegate.appDelegate.is4inchAspect;
    }
    return self;
}

/** @ghidraAddress 0x151f94 */
- (void)dealloc {
    [self releaseTexture];
    // The superclass dealloc runs after; ARC synthesises .cxx_destruct for the strong ivars.
}

#pragma mark - Textures

/** @ghidraAddress 0x1478a4 */
- (void)loadTexure:(RendererConf *)conf artwork:(UIImage *)artwork index:(UIImage *)index {
    // The square atlas dimensions: the front atlas and every other atlas are 2048 texels.
    static const unsigned int kAtlasTexPixelSize = 0x800;

    // The clamp bounds for the configuration: difficulty 0..3, level 0..10.
    static const unsigned int kMaxDiff = 3;
    static const unsigned int kMaxLevel = 10;

    // The marker atlas layout: 24 hit frames from sprite 0 up, then four hold-direction rows of 16
    // frames each into the sprite bands the base table names.
    static const int kMarkerFrameCount = 0x18;
    static const int kMarkerHoldRowCount = 4;
    static const int kHoldFramesPerRow = 0x10;
    /** @ghidraAddress 0x293100 */
    static const int kMarkerHoldRowSpriteBase[] = {0x18, 0x28, 0x38, 0x48};

    // The hold-marker atlas layout: six rows of 16 frames (sprites 0..95), then an eight-frame
    // final row from sprite 0x60.
    static const int kHoldMarkerRowCount = 6;
    static const int kHoldMarkerLastRowFrameCount = 8;
    static const unsigned int kHoldMarkerLastRowSpriteBase = 0x60;

    // The front atlas sprite slots the difficulty, level, start/end marks, jacket artwork, index
    // image, and partner-name label are blitted into.
    static const unsigned int kFrontSpriteMusicBar = 0x1f;
    static const unsigned int kFrontSpriteLevel = 0x26;
    static const unsigned int kFrontSpriteStartMark = 0x17;
    static const unsigned int kFrontSpriteEndMark = 0x18;
    static const unsigned int kFrontSpriteArtwork = 0x20;
    static const unsigned int kFrontSpriteIndex = 0x21;
    static const unsigned int kFrontSpritePartner = 0x3a;
    static const unsigned int kComboSpriteBackground = 0;

    // The partner-name label's bold system font size, per idiom.
    static const CGFloat kPartnerNameFontSizeRetina = 20.0;
    static const CGFloat kPartnerNameFontSize = 10.0;

    // The upper-background ripple pool: 50 sprites on the four-inch phone, 40 otherwise, seeded
    // from arc4random.
    static const unsigned int kUpperBgXBase = 0x140;   // 320, the field width
    static const unsigned int kUpperBgYBias = 0x8c;    // 140
    static const unsigned int kUpperBgYMod = 0x50;     // 80
    static const float kUpperBgYPeriodDiv = 30.0f;     // An fmov immediate.
    static const float kUpperBgMagScale = 0.00390625f; // @ghidraAddress 0x292a90 (1/256)

    NSData *cipherKey = CreateTextureCipherKey();
    BFCodec *cipher = [[BFCodec alloc] init];

    if (!self.texDebugFont) {
        self.texDebugFont = CreateTexture2DFromPngResource(@"debugfont");
    }
    if (!self.texReady0) {
        [cipher cipherInit:cipherKey];
        // Retina uses the bare name; non-retina uses the "_pn" variant.
        NSString *name = isRetina ? @"game_ready_rpl_0_tex" : @"game_ready_rpl_0_tex_pn";
        self.texReady0 = CreateTexture2DFromEncryptedTexResource(name, cipher);
        self.texReady0.isScale2x = isRetina;
    }
    if (!self.texReady1) {
        [cipher cipherInit:cipherKey];
        NSString *name = isRetina ? @"game_ready_rpl_1_tex" : @"game_ready_rpl_1_tex_pn";
        self.texReady1 = CreateTexture2DFromEncryptedTexResource(name, cipher);
        self.texReady1.isScale2x = isRetina;
    }

    // Clamp the configuration into the range the atlases cover.
    if (conf.diff > kMaxDiff) {
        conf.diff = kMaxDiff;
    }
    if (conf.level > kMaxLevel) {
        conf.level = kMaxLevel;
    }

    // If the front atlas is already loaded for this exact marker, difficulty, level, and tune,
    // there is nothing to reload.
    if (self.texFront && [conf.markerID isEqualToString:self.rendererConf.markerID] &&
        conf.diff == self.rendererConf.diff && conf.level == self.rendererConf.level &&
        conf.tuneID == self.rendererConf.tuneID) {
        return;
    }
    if (self.texFront) {
        self.texFront = nil;
    }
    // The binary reads conf.diff three times here to decide the code, discarding the first two
    // reads; keep a single decode.
    const char *diffCode = MainGameRendererPhoneRplDiffCode((int)conf.diff);

    // Build the front atlas: an empty 2048-square texture whose sprite rects come from the plist,
    // then the encrypted image blitted in at the origin, followed by the difficulty, music-bar,
    // level, and start/end mark words.
    self.texFront = [[Texture2D alloc] initWithData:nullptr
                                        pixelFormat:Texture2DPixelFormatRGBA8888
                                          pixelSize:kAtlasTexPixelSize];
    NSString *frontPlist = [NSBundle.mainBundle pathForResource:@"game_front_rpl_tex_pn2"
                                                         ofType:@"plist"];
    self.texFront.sprites = [[NSArray alloc] initWithContentsOfFile:frontPlist];
    [cipher cipherInit:cipherKey];
    LoadTextureSubImageFromEncryptedTex(
        self.texFront, @"game_front_rpl_tex_pn2", cipher, CGPointMake(0.0, 0.0));
    LoadTextureSubImageFromResource(self.texFront,
                                    [NSString stringWithFormat:@"game_mbar_%s_rpl_pn2", diffCode],
                                    [self.texFront spriteAtIndex:kFrontSpriteMusicBar].origin);
    LoadTextureSubImageFromResource(self.texFront,
                                    [NSString stringWithFormat:@"game_lv_%d_rpl", (int)conf.level],
                                    [self.texFront spriteAtIndex:kFrontSpriteLevel].origin);
    LoadTextureSubImageFromResource(self.texFront,
                                    @"game_start_mark_rpl_pn2",
                                    [self.texFront spriteAtIndex:kFrontSpriteStartMark].origin);
    LoadTextureSubImageFromResource(self.texFront,
                                    @"game_end_mark_rpl_pn2",
                                    [self.texFront spriteAtIndex:kFrontSpriteEndMark].origin);

    // Build the combo atlas from its plist and one encrypted image, then re-key the cipher and blit
    // the background art from the tension-tier-0 background resource into it.
    @autoreleasepool {
        if (self.texCombo) {
            self.texCombo = nil;
        }
        self.texCombo = [[Texture2D alloc] initWithData:nullptr
                                            pixelFormat:Texture2DPixelFormatRGBA8888
                                              pixelSize:kAtlasTexPixelSize];
        NSString *comboPlist = [NSBundle.mainBundle pathForResource:@"game_combo_rpl_tex_pn2"
                                                             ofType:@"plist"];
        self.texCombo.sprites = [[NSArray alloc] initWithContentsOfFile:comboPlist];
        [cipher cipherInit:cipherKey];
        LoadTextureSubImageFromEncryptedTex(
            self.texCombo, @"game_combo_rpl_tex_pn2", cipher, CGPointMake(0.0, 0.0));
        [cipher cipherInit:cipherKey]; // Yes, the binary re-keys the cipher here.
    }

    // A colour-ripples user preference is read for effect; the binary discards the result.
    (void)[NSUserDefaults.standardUserDefaults integerForKey:@"PrefColorRipples"];
    NSString *bgPath =
        [NSBundle.mainBundle pathForResource:[NSString stringWithFormat:@"game_bg_rpl_%d", 0]
                                      ofType:@"png"];
    if (bgPath) {
        UIImage *bgImage = [[UIImage alloc] initWithContentsOfFile:bgPath];
        [self.texCombo setSubImage:bgImage
                            inRect:[self.texCombo spriteAtIndex:kComboSpriteBackground]];
    }

    // Build the marker atlas: a 2048-square texture from its own plist.
    @autoreleasepool {
        if (self.texMarker) {
            self.texMarker = nil;
        }
        self.texMarker = [[Texture2D alloc] initWithData:nullptr
                                             pixelFormat:Texture2DPixelFormatRGBA8888
                                               pixelSize:kAtlasTexPixelSize];
        NSString *markerPlist = [NSBundle.mainBundle pathForResource:@"game_marker_tex_pn2"
                                                              ofType:@"plist"];
        self.texMarker.sprites = [[NSArray alloc] initWithContentsOfFile:markerPlist];
    }

    // Blit the 24 marker hit frames (ma00..ma23) into sprites 0 upward from the marker archive.
    NSString *markerPath = [MarkerManager getMarkerPath:conf.markerID];
    KUnzip *markerZip = [[KUnzip alloc] initWithPath:markerPath];
    @autoreleasepool {
        for (unsigned int i = 0; i < kMarkerFrameCount; ++i) {
            [cipher cipherInit:cipherKey];
            NSString *entry = [NSString stringWithFormat:@"ma%02d", i];
            NSMutableData *bytes = [markerZip uncompress:entry];
            UIImage *image = CreateImageFromEncryptedData(cipher, bytes);
            if (image) {
                [self.texMarker setSubImage:image inRect:[self.texMarker spriteAtIndex:i]];
            }
        }
    }

    // Blit the four hold-direction rows (h0..h3), each 16 frames, into the marker atlas.
    for (int row = 0; row < kMarkerHoldRowCount; ++row) {
        @autoreleasepool {
            for (int i = 0; i < kHoldFramesPerRow; ++i) {
                [cipher cipherInit:cipherKey];
                NSString *entry = [NSString stringWithFormat:@"h%d%02d", row, i];
                NSMutableData *bytes = [markerZip uncompress:entry];
                UIImage *image = CreateImageFromEncryptedData(cipher, bytes);
                if (image) {
                    unsigned int idx = (unsigned int)(i + kMarkerHoldRowSpriteBase[row]);
                    [self.texMarker setSubImage:image inRect:[self.texMarker spriteAtIndex:idx]];
                }
            }
        }
    }
    self.texMarker.isScale2x = isRetina;

    // Build the hold-marker atlas and its sub-renderer.
    @autoreleasepool {
        if (self.texHoldMarker) {
            self.texHoldMarker = nil;
        }
        self.texHoldMarker = [[Texture2D alloc] initWithData:nullptr
                                                 pixelFormat:Texture2DPixelFormatRGBA8888
                                                   pixelSize:kAtlasTexPixelSize];
        NSString *holdPlist = [NSBundle.mainBundle pathForResource:@"game_hold_marker_tex"
                                                            ofType:@"plist"];
        self.texHoldMarker.sprites = [[NSArray alloc] initWithContentsOfFile:holdPlist];
        [cipher cipherInit:cipherKey];
        if (!self->holdMarkerRender) {
            // The game area is delayed on the four-inch idiom by the phone button margin.
            int gameAreaDelay = is4Inch ? self.buttonMarginForScreen40 : 0;
            self->holdMarkerRender = [[HoldMarkerRender alloc] init:self.texHoldMarker
                                                              isPad:NO
                                                      gameAreaDelay:gameAreaDelay];
        }
    }

    // Blit the hold-marker frames from hm0001.zip: six rows of 16 (m0..m5, sprites 0..95) then the
    // eight-frame final row (m6, sprites 0x60 upward).
    NSString *holdMarkerPath = [NSBundle.mainBundle pathForResource:@"hm0001" ofType:@"zip"];
    KUnzip *holdMarkerZip = [[KUnzip alloc] initWithPath:holdMarkerPath];
    for (int row = 0; row < kHoldMarkerRowCount; ++row) {
        for (int i = 0; i < kHoldFramesPerRow; ++i) {
            [cipher cipherInit:cipherKey];
            NSString *entry = [NSString stringWithFormat:@"m%d%02d", row, i];
            NSMutableData *bytes = [holdMarkerZip uncompress:entry];
            UIImage *image = CreateImageFromEncryptedData(cipher, bytes);
            if (image) {
                unsigned int idx = (unsigned int)(row * kHoldFramesPerRow + i);
                [self.texHoldMarker setSubImage:image
                                        atPoint:[self.texHoldMarker spriteAtIndex:idx].origin];
            }
        }
    }
    for (int i = 0; i < kHoldMarkerLastRowFrameCount; ++i) {
        [cipher cipherInit:cipherKey];
        NSString *entry = [NSString stringWithFormat:@"m6%02d", i];
        NSMutableData *bytes = [holdMarkerZip uncompress:entry];
        UIImage *image = CreateImageFromEncryptedData(cipher, bytes);
        if (image) {
            unsigned int idx = (unsigned int)(i + kHoldMarkerLastRowSpriteBase);
            [self.texHoldMarker setSubImage:image
                                    atPoint:[self.texHoldMarker spriteAtIndex:idx].origin];
        }
    }

    // Blit the jacket artwork and, when present, the aspect-fitted index image and partner-name
    // label into the front atlas.
    [self.texFront setSubImage:artwork inRect:[self.texFront spriteAtIndex:kFrontSpriteArtwork]];
    if (index) {
        CGRect frame = [self.texFront spriteAtIndex:kFrontSpriteIndex];
        CGSize size = index.size;
        [self.texFront setSubImage:index
                            inRect:CGRectMake(frame.origin.x,
                                              frame.origin.y,
                                              frame.size.width,
                                              (frame.size.width * size.height) / size.width)];
    }
    if (conf.partnerName) {
        UILabel *label =
            [[UILabel alloc] initWithFrame:[self.texFront spriteAtIndex:kFrontSpritePartner]];
        label.opaque = NO;
        label.backgroundColor = UIColor.clearColor; // The original used +clearColor.
        label.textColor = UIColor.blackColor;       // The original used +blackColor.
        label.textAlignment = NSTextAlignmentRight; // 2.
        label.font = [UIFont
            boldSystemFontOfSize:(isRetina ? kPartnerNameFontSizeRetina : kPartnerNameFontSize)];
        label.text = conf.partnerName;
        UIImage *labelImage = [label renderImage];
        [self.texFront setSubImage:labelImage
                           atPoint:[self.texFront spriteAtIndex:kFrontSpritePartner].origin];
    }

    self.texFront.isScale2x = isRetina;
    self.texCombo.isScale2x = isRetina;
    self.rendererConf = conf;

    // Rebuild the upper-background ripple pool with randomised motion, then depth-sort it; the
    // background ripple pool is cleared.
    [self.arrayUpperBgRip removeAllObjects];
    int upperBgCount = is4Inch ? 0x32 : 0x28;
    for (int i = 0; i < upperBgCount; ++i) {
        unsigned int yPeriod = (arc4random() % 10) * 0x1e + 0x96;
        NSUInteger sprite = (arc4random() & 3) | 0x10;
        float xSpeed = (float)(arc4random() % 10 + 3) / kUpperBgYPeriodDiv;
        int yGroundBias = is4Inch ? 0x96 : 0x7c;
        float yGround = (float)(yGroundBias + arc4random() % 0x14);
        int yAmpBias = is4Inch ? 5 : 4;
        float yAmp = (float)(yAmpBias + (arc4random() & 7));
        unsigned int yPhaseRaw = arc4random() % 0x55 + 0xf;
        unsigned int atX = arc4random() % kUpperBgXBase;
        unsigned int atY = arc4random() % kUpperBgYMod + kUpperBgYBias;
        unsigned int yCenterRaw = arc4random();
        unsigned int phase = (yPeriod != 0) ? (yCenterRaw % yPeriod) : 0;
        float mag = (float)((arc4random() & 0x3f) + 0x30) * kUpperBgMagScale;
        UpperBGRipple *ripple =
            [[UpperBGRipple alloc] initWithSprite:sprite
                                          atPoint:CGPointMake((double)atX, (double)atY)
                                           xSpeed:(float)yPeriod
                                          yGround:xSpeed
                                             yAmp:yGround
                                          yCenter:yAmp
                                          yPeriod:yPhaseRaw
                                           yPhase:phase
                                              mag:mag];
        [self.arrayUpperBgRip addObject:ripple];
    }
    [self.arrayUpperBgRip sortUsingSelector:@selector(compZ:)];
    [self.arrayBgRip removeAllObjects];
}

/** @ghidraAddress 0x149464 */
- (void)loadResultTex:(short)rank {
    // The result-screen rating (rank judgement) graphics are blitted into the front atlas by
    // -renderRating: directly; -loadResultTex: is a nine-way jump table that this build leaves with
    // no reachable body for ranks 0..7, so nothing is loaded here.
    (void)rank;
}

/** @ghidraAddress 0x1496a0 */
- (void)releaseTexture {
    self.texDebugFont = nil;
    self.texReady0 = nil;
    self.texReady1 = nil;
    self.texFront = nil;
}

#pragma mark - State

/** @ghidraAddress 0x149704 */
- (void)setState:(unsigned int)state {
    switch (state) {
    case 0:
        self->lastCombo = 0;
        self->comboCutFrame = 0;
        self->comboEffectFrame = 0;
        self->scoreDisplay = 0;
        self->shutterOpen = 0.0f;
        self->lastHakuPhase = 0.0f;
        break;
    case kRenderStateReadyGo:
        self->lastCombo = 0;
        self->comboCutFrame = 0;
        self->comboEffectFrame = 0;
        self->scoreDisplay = 0;
        self->shutterOpen = 0.0f;
        self->startMarkFrame = 0;
        if (!self.sePlayerGo) {
            NSString *path = [NSBundle.mainBundle pathForResource:@"SD_RPL_CV_GO" ofType:@"caf"];
            NSURL *url = [NSURL fileURLWithPath:path];
            self.sePlayerGo = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
            [self.sePlayerGo prepareToPlay];
        }
        break;
    case kRenderStateResult:
        [AudioManager.sharedManager loadBgmResAAC:@"SD_RPL_BGM_RESULT" inDirectory:nil];
        [AudioManager.sharedManager startBgm:YES fadeTime:0.0];
        break;
    case kRenderStateResultWait:
        // The result-wait state leaves every counter untouched and does not reset the frame.
        [super setState:state];
        return;
    default:
        break;
    }
    self->frame = 0;
    [super setState:state];
}

#pragma mark - Play lifecycle

/** @ghidraAddress 0x149a28 */
- (void)startPlay {
    [self setState:kRenderStatePlay];
    self.sePlayerGo = nil;
}

/** @ghidraAddress 0x149a64 */
- (void)endResult {
    if (self.state == kRenderStateResult) {
        self.subState = kMainGameEndSubState;
    }
}

/** @ghidraAddress 0x151fe4 */
- (void)replayEnd {
    self.replayPlaying = NO;
}

/** @ghidraAddress 0x151ff4 */
- (void)replaySelect {
    if (!self.isCustom || !self.isDownload || !self.hasMusic) {
        return;
    }
    self.replayPlaying = YES;
    // spriteAtIndex: 0x17 is read only to size the shared draw scratch; the point then read is the
    // atlas origin, so the start mark reloads at (0, 0).
    self.texFront.isScale2x = NO;
    (void)[self.texFront spriteAtIndex:0x17];
    LoadTextureSubImageFromResource(
        self.texFront, @"game_start_mark_rpl_pn2", CGPointMake(0.0, 0.0));
    self.texFront.isScale2x = YES;
    self.isTextureChange = NO;

    /** @ghidraAddress 0x28f260 */
    static const NSTimeInterval kGoodJobFadeDuration = 0.3;
    __weak UIImageView *goodJob = self.goodJobImage;
    [UIView animateWithDuration:kGoodJobFadeDuration
                     animations:^{
                       /** @ghidraAddress 0x152218 */
                       goodJob.alpha = 0.0;
                     }
                     completion:^(BOOL finished){
                         /** @ghidraAddress 0x152264 */
                     }];
}

/** @ghidraAddress 0x14d70c */
- (double)durationOfReadyGo {
    /** @ghidraAddress 0x292a08 */
    static const double kReadyGoDuration = 2.8333333333333335;
    return kReadyGoDuration;
}

#pragma mark - Layout

/** @ghidraAddress 0x150b20 */
- (double)buttonAreaOffset {
    return 0.0;
}

/** @ghidraAddress 0x150b28 */
- (double)gameAreaOffset {
    if (is4Inch) {
        return (double)(self.buttonMarginForScreen40 + kFourInchGameTop);
    }
    /** @ghidraAddress 0x28f438 */
    return 160.0;
}

#pragma mark - Buttons

/** @ghidraAddress 0x150b68 */
- (unsigned int)endButtonID {
    return 0xf;
}

/** @ghidraAddress 0x150b70 */
- (unsigned int)evaluateButtonID {
    return 0xe;
}

/** @ghidraAddress 0x150b78 */
- (unsigned int)goodJobButtonID {
    return 0xd;
}

/** @ghidraAddress 0x150b80 */
- (CGPoint)goodJobPosition {
    unsigned int buttonID = self.goodJobButtonID;
    int gameTop = is4Inch ? (self.buttonMarginForScreen40 + kFourInchGameTop) : kFourInchGameTop;
    double x = (double)((buttonID & 3) * kGridCellSize + kButtonCellInset);
    double y = (double)((buttonID >> 2) * kGridCellSize + kButtonCellInset + gameTop);
    return CGPointMake(x, y);
}

/** @ghidraAddress 0x150c20 */
- (unsigned int)twitterSendButtonID {
    return 0xe;
}

/** @ghidraAddress 0x150c28 */
- (CGPoint)twitterBtnPosition {
    unsigned int buttonID = self.twitterSendButtonID;
    int gameTop = is4Inch ? (self.buttonMarginForScreen40 + kFourInchGameTop) : kFourInchGameTop;
    double x = (double)((buttonID & 3) * kGridCellSize + kButtonCellInset);
    double y = (double)((buttonID >> 2) * kGridCellSize + kButtonCellInset + gameTop);
    return CGPointMake(x, y);
}

/** @ghidraAddress 0x150cc8 */
- (unsigned int)storeMoveButtonID {
    return 0xe;
}

/** @ghidraAddress 0x150cd0 */
- (CGPoint)storeMoveBtnPosition {
    unsigned int buttonID = self.storeMoveButtonID;
    int gameTop = is4Inch ? (self.buttonMarginForScreen40 + kFourInchGameTop) : kFourInchGameTop;
    double x = (double)((buttonID & 3) * kGridCellSize + kButtonCellInset);
    double y = (double)((buttonID >> 2) * kGridCellSize + kButtonCellInset + gameTop);
    return CGPointMake(x, y);
}

#pragma mark - Drawing

/** @ghidraAddress 0x149ab0 */
- (void)renderStartMark:(float)alpha {
    static const double kStartMarkAnchorNudge = 34.0; // @ghidraAddress 0x28f648
    static const NSUInteger kStartMarkSpriteInner = 0x1a;
    static const NSUInteger kStartMarkSpriteMid = 0x19;
    static const NSUInteger kStartMarkSpriteOuter = 0x17;

    // The four layered start-mark glyphs (texFront sprites 0x1a, 0x19, 0x1a, 0x17) animate through
    // an intro then a 30-frame steady-state pulse keyed on startMarkFrame.
    unsigned int f = self->startMarkFrame;
    float scaleInner = 0.13f; // local_a8 (draw 1 scale)
    float scaleMid;           // draw 2 has no scale, only alpha
    float scaleThird = 1.0f;  // local_a4 (draw 3 scale)
    float scaleOuter = 1.0f;  // local_ac (draw 4 scale)
    float alphaInner = 0.0f;  // fVar11 (draw 1 alpha)
    float alphaMid = 0.0f;    // fVar12 (draw 2 alpha)
    float alphaThird = 0.0f;  // fVar14 (draw 3 alpha)
    float alphaOuter = 0.13f; // fVar13 (draw 4 alpha)
    (void)scaleMid;
    if ((int)f < 0) {
        // Faithful: a negative frame counter draws nothing (every alpha stays zero).
        scaleInner = 0.0f;
        scaleThird = 1.0f;
        scaleOuter = 1.0f;
        alphaInner = 0.0f;
        alphaMid = 0.0f;
        alphaThird = 0.0f;
        alphaOuter = 0.0f;
    } else if ((int)f < 8) {
        scaleThird = 1.0f;
        scaleInner = InterpolateFloatByFrame(1.32f, 1.0f, f, 0, 8); // @0x292564
        float from;
        float to;
        unsigned int start;
        unsigned int end;
        if ((int)f < 4) {
            start = 0;
            end = 4;
            from = 0.0f;
            to = 0.22f; // @0x292ab0
        } else {
            start = 4;
            end = 8;
            from = 0.22f; // @0x292ab0
            to = 0.13f;   // @0x292a98
        }
        alphaInner = InterpolateFloatByFrame(from, to, f, start, end);
        alphaThird = 0.0f;
        alphaMid = InterpolateFloatByFrame(0.0f, g_flKeyTime080, f, 0, 8);
        scaleOuter = InterpolateFloatByFrame(1.2f, 1.0f, f, 4, 8); // @0x292aa8
        alphaOuter = InterpolateFloatByFrame(0.0f, 1.0f, f, 4, 8);
    } else {
        unsigned int p = (unsigned int)((int)(f - 8) % 0x1e);
        if ((int)p < 0xf) {
            alphaInner = InterpolateFloatByFrame(0.13f, 0.32f, p, 0, 0xf); // @0x292a98/@0x292a94
            alphaMid = InterpolateFloatByFrame(g_flKeyTime080, 0.52f, p, 0, 0xf); // @0x292a9c
            if ((int)p < 0xb) {
                scaleThird = InterpolateFloatByFrame(1.0f, 1.2f, p, 0, 0xb);        // @0x292aa8
                alphaThird = InterpolateFloatByFrame(alphaOuter, 0.07f, p, 0, 0xb); // @0x292aac
            } else {
                scaleThird =
                    InterpolateFloatByFrame(1.2f, 0.89f, p, 0xb, 0x12); // @0x292aa8/@0x292aa0
                alphaThird =
                    InterpolateFloatByFrame(0.07f, 0.33f, p, 0xb, 0x12); // @0x292aac/@0x292aa4
            }
        } else {
            alphaInner = InterpolateFloatByFrame(0.32f, 0.13f, p, 0xf, 0x1e); // @0x292a94/@0x292a98
            alphaMid = InterpolateFloatByFrame(0.52f, g_flKeyTime080, p, 0xf, 0x1e); // @0x292a9c
            if ((int)p < 0x12) {
                scaleThird = InterpolateFloatByFrame(1.2f, 0.89f, p, 0xb, 0x12);
                alphaThird = InterpolateFloatByFrame(0.07f, 0.33f, p, 0xb, 0x12);
            } else {
                scaleThird = InterpolateFloatByFrame(0.89f, 1.0f, p, 0x12, 0x1e);  // @0x292aa0
                alphaThird = InterpolateFloatByFrame(0.33f, 0.33f, p, 0x12, 0x1e); // @0x292aa4
            }
        }
        scaleInner = 1.0f;
        scaleOuter = 1.0f;
        alphaOuter = 1.0f;
    }

    int gameTop = is4Inch ? self.buttonMarginForScreen40 : 0;
    unsigned int firstMarker = self.sequence.firstMarker;
    for (unsigned int panel = 0; panel < kMainGameGridPanelCount; ++panel) {
        if (((1u << (panel & 0x1f)) & firstMarker) == 0) {
            continue;
        }
        double x = (double)(((int)(panel % 4) * kGridCellSize) | kGridMarkerInset);
        double y = (double)((((int)(panel / 4) * kGridCellSize) | kGridMarkerInset) + gameTop +
                            kGridTopOffset);
        CGPoint anchor = CGPointMake(x + kStartMarkAnchorNudge, y + kStartMarkAnchorNudge);
        [self.texFront drawSprite:kStartMarkSpriteInner
                          atPoint:CGPointMake(x, y)
                            scale:scaleInner
                           rotate:0.0f
                           anchor:anchor
                        transform:0
                            alpha:alphaInner * alpha];
        [self.texFront drawSprite:kStartMarkSpriteMid
                          atPoint:CGPointMake(x, y)
                        transform:0
                            alpha:alphaMid * alpha];
        [self.texFront drawSprite:kStartMarkSpriteInner
                          atPoint:CGPointMake(x, y)
                            scale:scaleThird
                           rotate:0.0f
                           anchor:anchor
                        transform:0
                            alpha:alphaThird * alpha];
        [self.texFront drawSprite:kStartMarkSpriteOuter
                          atPoint:CGPointMake(x, y)
                            scale:scaleOuter
                           rotate:0.0f
                           anchor:anchor
                        transform:0
                            alpha:alphaOuter * alpha];
    }
    ++self->startMarkFrame;
}

/** @ghidraAddress 0x14a008 */
- (void)renderMarker {
    static const float kMarkerFadeDivisor = 100.0f; // @ghidraAddress 0x28f4e0
    static const int kMarkerHighlightSector = 0x96; // 150
    static const int kMarkerFadeClampSectors = 100;
    static const int kMarkerDirModulo = 4;

    int sectorDelta = (int)self.sequence.firstMarkerSector - (int)self.sequence.currentSector;
    [self.sequence getMarkerState:self->markerState];

    int gameTop = is4Inch ? self.buttonMarginForScreen40 : 0;
    for (int i = 0; i < kMainGameGridPanelCount; ++i) {
        double x = (double)(((i % 4) * kGridCellSize) | kGridMarkerInset);
        double y =
            (double)((((i / 4) * kGridCellSize) | kGridMarkerInset) + gameTop + kGridTopOffset);
        unsigned int stateWord = (unsigned int)self->markerState[i];
        unsigned int phase = stateWord & 0xfff;
        unsigned int slot = (stateWord >> 0xc) & 7;
        int sprite = -1;
        if (slot == 0) {
            if (phase < 0xf0) {
                sprite = (int)(phase / 10);
            }
        } else if (phase < 0xa0 && slot < 6) {
            int candidate = (int)((phase / 10 + slot * 0x10) - 8);
            if (candidate >= 0) {
                sprite = candidate;
            }
        }
        if (sprite >= 0) {
            [self.texMarker drawSprite:(NSUInteger)sprite
                               atPoint:CGPointMake(x, y)
                             transform:(char)self->markerDir[i]
                                 alpha:1.0f];
        } else {
            self->markerDir[i] = 0;
            if (JubeatAppDelegate.appDelegate.isMarkerDirRandom) {
                self->markerDir[i] = rand() % kMarkerDirModulo;
            }
        }
    }

    [self.sequence getHoldMarkerState:self->holdState];
    if (![self.rendererConf isStealth]) {
        [self->holdMarkerRender renderHoldMarker:self->holdState];
    }
    // Once the first marker approaches within the highlight window, cue the start mark, fading it
    // in over the approach.
    if (sectorDelta > kMarkerHighlightSector) {
        int fadeSectors = sectorDelta - kMarkerHighlightSector;
        float startAlpha = 1.0f;
        if (fadeSectors < kMarkerFadeClampSectors) {
            startAlpha = (float)fadeSectors / kMarkerFadeDivisor;
        }
        [self renderStartMark:startAlpha];
    }
}

/** @ghidraAddress 0x14c2e0 */
- (void)renderTuneInfo:(CGPoint)pos artworkSize:(double)artworkSize alpha:(double)alpha {
    static const double kTitleChipXOffset = 5.0;
    static const double kTitleChipYOffset = -5.0;
    static const double kDifficultyXOffset = 8.0;
    static const double kDifficultyYOffset = 32.0; // @ghidraAddress 0x28f458
    static const double kLevelYNudgeRetina = 4.0;
    static const double kLevelYNudge = 3.0;
    static const NSUInteger kTuneInfoSpriteJacket = 0x20;
    static const NSUInteger kTuneInfoSpriteTitle = 0x21;
    static const NSUInteger kTuneInfoSpriteDiffExtreme = 0x24;
    static const NSUInteger kTuneInfoSpriteDiffAdvanced = 0x23;
    static const NSUInteger kTuneInfoSpriteDiffBasic = 0x22;
    static const NSUInteger kTuneInfoSpriteDiffDefault = 0x25;
    static const NSUInteger kTuneInfoSpriteLevel = 0x27;
    // The per-difficulty, per-retina level-word x nudge tables. Read from __const.
    static const double kLevelXNudgeExtreme[] = {90.0, 80.0};   // @ghidraAddress 0x292ff0
    static const double kLevelXNudgeAdvanced[] = {102.0, 85.0}; // @ghidraAddress 0x293000
    static const double kLevelXNudgeBasic[] = {58.0, 50.0};     // @ghidraAddress 0x293010
    static const double kLevelXNudgeDefault[] = {44.0, 34.0};   // @ghidraAddress 0x293020

    // The jacket artwork, stretched into sprite 0x20's frame at the passed size.
    [self.texFront drawSprite:kTuneInfoSpriteJacket
                       inRect:CGRectMake(pos.x, pos.y, artworkSize, artworkSize)
                    transform:0
                        alpha:(float)alpha];
    double x = pos.x + artworkSize;
    double y = pos.y + 4.0;
    [self.texFront drawSprite:kTuneInfoSpriteTitle
                      atPoint:CGPointMake(x + kTitleChipXOffset, y + kTitleChipYOffset)
                    transform:0
                        alpha:(float)alpha];
    x += kDifficultyXOffset;
    y += kDifficultyYOffset;
    int diff = (int)self.rendererConf.diff;
    NSUInteger diffSprite;
    const double *levelNudge;
    if (diff == 2) {
        diffSprite = kTuneInfoSpriteDiffExtreme;
        levelNudge = kLevelXNudgeExtreme;
    } else if (diff == 1) {
        diffSprite = kTuneInfoSpriteDiffAdvanced;
        levelNudge = kLevelXNudgeAdvanced;
    } else if (diff == 0) {
        diffSprite = kTuneInfoSpriteDiffBasic;
        levelNudge = kLevelXNudgeBasic;
    } else {
        diffSprite = kTuneInfoSpriteDiffDefault;
        levelNudge = kLevelXNudgeDefault;
    }
    [self.texFront drawSprite:diffSprite atPoint:CGPointMake(x, y) transform:0 alpha:(float)alpha];
    double levelXNudge = levelNudge[isRetina ? 0 : 1];
    double levelYNudge = isRetina ? kLevelYNudgeRetina : kLevelYNudge;
    [self.texFront drawSprite:kTuneInfoSpriteLevel
                      atPoint:CGPointMake(x + levelXNudge, y - levelYNudge)
                    transform:0
                        alpha:(float)alpha];
}

/** @ghidraAddress 0x14d12c */
- (void)renderButtons {
    static const double kFieldWidth = 320.0;      // @ghidraAddress 0x28f470
    static const double kButtonLitMirrorX = 40.0; // @ghidraAddress 0x28f1f8
    enum {
        kButtonSpriteUnlit = 0x14,
        kButtonSpriteLitOverlay = 0x15,
        kButtonSpriteLitBase = 0x16,
        kButtonSpriteFiller = 0xd,
    };

    for (unsigned int panel = 0; panel < kMainGameGridPanelCount; ++panel) {
        double panelX = (double)((int)(panel % 4) * kGridCellSize);
        int gameTop = is4Inch ? self.buttonMarginForScreen40 : 0;
        double panelY = (double)(((int)(panel / 4) * kGridCellSize) + gameTop + kFourInchGameTop);
        BOOL lit = (self.btnPress & (1 << (panel & 0x1f))) != 0;
        if (lit) {
            // A pressed panel draws the base plate, its mirrored half, then the lit overlay.
            [self.texFront drawSprite:kButtonSpriteLitBase atPoint:CGPointMake(panelX, panelY)];
            [self.texFront drawSprite:kButtonSpriteLitBase
                              atPoint:CGPointMake(panelX + kButtonLitMirrorX, panelY)
                            transform:5
                                alpha:1.0f];
            [self.texFront drawSprite:kButtonSpriteLitOverlay atPoint:CGPointMake(panelX, panelY)];
        } else {
            [self.texFront drawSprite:kButtonSpriteUnlit atPoint:CGPointMake(panelX, panelY)];
        }
    }
    if (!is4Inch) {
        return;
    }
    // The four-inch phone fills the letterbox bands above and below the grid with the filler sprite
    // (0xd), each band spanning the gap between the button margin and the upper-background height.
    double gap = (double)(self.buttonMarginForScreen40 - self.upperBgHeight40);
    double topY = (double)(self.upperBgHeight40 + kFourInchGameTop);
    [self.texFront drawSprite:kButtonSpriteFiller inRect:CGRectMake(0.0, topY, kFieldWidth, gap)];
    double bottomY = (double)(self.buttonMarginForScreen40 + 0x1e0);
    [self.texFront drawSprite:kButtonSpriteFiller
                       inRect:CGRectMake(0.0, bottomY, kFieldWidth, gap)];
}

/** @ghidraAddress 0x14ceb0 */
- (void)renderUpper {
    // The tune-info panel, jacket slightly larger on the four-inch phone.
    static const double kTuneInfoArtwork[] = {80.0, 88.0}; // @ghidraAddress 0x292770
    static const double kScoreX = 142.0;                   // @ghidraAddress 0x292e88
    static const double kScoreY = 100.0;                   // @ghidraAddress 0x28f3f0
    static const double kMusicBarY = 136.0;                // @ghidraAddress 0x28f768
    static const double kPartnerX = 194.0;                 // @ghidraAddress 0x291d10
    static const double kPartnerY = 74.0;                  // @ghidraAddress 0x28f6f8
    static const double kPartnerScale = 0.7;               // @ghidraAddress 0x291c98
    static const double kTuneInfoYDefault = 80.0;          // @ghidraAddress 0x28f3f8

    double tuneY;
    double artworkSize;
    if (is4Inch) {
        tuneY = (double)((self.upperBgHeight40 >> 2) + 0xc);
        artworkSize = kTuneInfoArtwork[1];
    } else {
        tuneY = 12.0;
        artworkSize = kTuneInfoArtwork[0];
    }
    (void)kTuneInfoYDefault;
    [self renderTuneInfo:CGPointMake(8.0, tuneY) artworkSize:artworkSize alpha:1.0];

    double barY = is4Inch ? (double)(self.upperBgHeight40 + 0x84) : kMusicBarY;
    [self renderMusicBar:CGPointMake(0.0, barY)
                timeline:(self.state == kRenderStatePlay)
                   alpha:1.0];

    unsigned int score = 0;
    if (self.sequence) {
        score = (unsigned int)self.sequence.getScore->point;
    }
    if (self.scoreBackup) {
        score = (unsigned int)self.replayBackupScore.totalPoint;
    }
    double scoreY = is4Inch ? (double)(self.upperBgHeight40 + 0x5c) : kScoreY;
    [self renderScore:score atPoint:CGPointMake(kScoreX, scoreY) alpha:1.0];

    double partnerY = is4Inch ? (double)(self.upperBgHeight40 + 0x38) : kPartnerY;
    [self renderPartnerScore:self.partnerScore
                     atPoint:CGPointMake(kPartnerX, partnerY)
                       scale:kPartnerScale
                       alpha:1.0];
}

/** @ghidraAddress 0x14d420 */
- (void)renderPreStart {
    static const double kScoreX = 142.0;                   // @ghidraAddress 0x292e88
    static const double kScoreY = 100.0;                   // @ghidraAddress 0x28f3f0
    static const double kMusicBarY = 136.0;                // @ghidraAddress 0x28f768
    static const double kPartnerX = 194.0;                 // @ghidraAddress 0x291d10
    static const double kPartnerY = 74.0;                  // @ghidraAddress 0x28f6f8
    static const double kPartnerScale = 0.7;               // @ghidraAddress 0x291c98
    static const double kTuneInfoArtwork[] = {80.0, 88.0}; // @ghidraAddress 0x292770
    static const float kSlideBase = 40.0f;                 // @ghidraAddress 0x292568

    [self renderBG];
    [self renderShutter:YES];
    [self renderUpperBG:NO];

    // The tune info fades and slides in over frames 10..20.
    float infoAlpha = InterpolateFloatByFrame(0.0f, 1.0f, self->frame, 10, 0x14);
    float infoX = InterpolateFloatByFrame(28.0f, 8.0f, self->frame, 10, 0x14);
    double tuneY;
    double artworkSize;
    if (is4Inch) {
        tuneY = (double)((self.upperBgHeight40 >> 2) + 0xc);
        artworkSize = kTuneInfoArtwork[1];
    } else {
        tuneY = 12.0;
        artworkSize = kTuneInfoArtwork[0];
    }
    [self renderTuneInfo:CGPointMake((double)infoX, tuneY)
             artworkSize:artworkSize
                   alpha:(double)infoAlpha];

    // The score and partner score fade and slide in over frames 4..14.
    float scoreAlpha = InterpolateFloatByFrame(0.0f, 1.0f, self->frame, 4, 0xe);
    float slide = InterpolateFloatByFrame(kSlideBase, 0.0f, self->frame, 4, 0xe);
    double scoreY = is4Inch ? (double)(self.upperBgHeight40 + 0x5c) : kScoreY;
    [self renderScore:0
              atPoint:CGPointMake(kScoreX - (double)slide, scoreY)
                alpha:(double)scoreAlpha];
    double partnerY = is4Inch ? (double)(self.upperBgHeight40 + 0x38) : kPartnerY;
    [self renderPartnerScore:0
                     atPoint:CGPointMake(kPartnerX - (double)slide, partnerY)
                       scale:kPartnerScale
                       alpha:(double)scoreAlpha];

    // The music bar fades in over frames 0..10.
    float barAlpha = InterpolateFloatByFrame(0.0f, 1.0f, self->frame, 0, 10);
    double barY = is4Inch ? (double)(self.upperBgHeight40 + 0x84) : kMusicBarY;
    [self renderMusicBar:CGPointMake(0.0, barY) timeline:NO alpha:(double)barAlpha];

    [self renderButtons];

    // Frame 20 plays the mute stinger and advances the sub-state.
    if (self->frame == 0x14) {
        [AudioManager.sharedManager playSeResFile:@"SD_MUON" inDirectory:nil];
        self.subState = 10;
    }
}

/** @ghidraAddress 0x151a58 */
- (void)draw {
    switch (self.state) {
    case kRenderStatePreStart:
        [self renderPreStart];
        break;
    case kRenderStateReadyGo:
        [self renderBG];
        [self renderShutter:YES];
        [self renderUpperBG:NO];
        [self renderUpper];
        [self renderStartMark:1.0f];
        [self renderButtons];
        [self renderReadyGo];
        break;
    case kRenderStatePlay:
        [self renderBG];
        [self renderShutter:YES];
        [self renderCombo:(unsigned int)self.sequence.getScore->curCombo alpha:1.0f];
        [self renderUpperBG:NO];
        [self renderUpper];
        [self renderMarker];
        [self renderButtons];
        break;
    case kRenderStateFinish:
        [self renderBG];
        [self renderShutter:YES];
        [self renderCombo:(unsigned int)self.sequence.getScore->curCombo alpha:1.0f];
        [self renderUpperBG:NO];
        [self renderUpper];
        [self renderMarker];
        [self renderButtons];
        [self renderFinish];
        break;
    case kRenderStateResult:
    case kRenderStateResultWait:
        [self renderBG];
        [self renderResult];
        break;
    default:
        [self renderBG];
        [self renderShutter:YES];
        [self renderUpperBG:NO];
        [self renderButtons];
        break;
    }
    [self.texCombo commitDraw];
    [self.texHoldMarker commitDraw];
    [self.texMarker commitDraw];
    [self.texFront commitDraw];
    [self.texReady0 commitDraw];
    [self.texReady1 commitDraw];
    ++self->frame;
}

/** @ghidraAddress 0x151e2c */
- (void)drawDebugText:(const char *)text pos:(CGPoint)pos alpha:(float)alpha {
    static const double kGlyphAdvance = 12.0;
    static const double kLineAdvance = 20.0;
    static const int kGlyphLimit = 0x200;
    static const NSUInteger kGlyphBase = 0x20; // the sprite for a leading space

    double y = pos.y;
    double x = pos.x;
    int drawn = 0;
    for (long i = 0; text[i] != '\0'; ++i) {
        char c = text[i];
        if (c == '\n') {
            y += kLineAdvance;
            x = pos.x;
            continue;
        }
        if (c > ' ' && c != '\x7f') {
            [self.texDebugFont drawSprite:(NSUInteger)((long)c - kGlyphBase)
                                  atPoint:CGPointMake(x, y)
                                transform:0
                                    alpha:alpha];
            ++drawn;
            if (drawn >= kGlyphLimit) {
                break;
            }
        }
        x += kGlyphAdvance;
    }
    if (drawn != 0) {
        [self.texDebugFont commitDraw];
    }
}

/** @ghidraAddress 0x14a3ac */
- (void)renderBG {
    static const float kBgAppearThreshold = 0.606060624f; // @ghidraAddress 0x292ab4
    static const float kBgAppearHigh = 1.1f;              // @ghidraAddress 0x292ab8
    static const float kBaseScaleNorm = 320.0f;           // @ghidraAddress 0x292734
    static const float kBaseScaleMag = 0.00390625f;       // @ghidraAddress 0x292a90 (1/256)
    static const float kBgRippleMag = -0.00048828125f;    // @ghidraAddress 0x292f94
    static const float kBgRippleMag2 = 0.001953125f;      // @ghidraAddress 0x292abc (1/512)
    static const float kBgRippleAlphaDiv = 100.0f;        // @ghidraAddress 0x28f4e0
    static const float kBasePlateYShift = 32.0f;          // @ghidraAddress 0x292f90
    static const double kBasePlateAnchorYDefault = 320.0; // @ghidraAddress 0x28f470
    static const double kBasePlateYDefault = 192.0;       // @ghidraAddress 0x28fa00
    static const double kBasePlatePointX = 32.0;          // @ghidraAddress 0x28f458
    static const double kBasePlateAnchorX = 160.0;        // @ghidraAddress 0x28f438
    enum {
        kTensionTier1 = 0x100,
        kTensionTier2 = 0x200,
        kTensionTier3 = 0x300,
        kTensionTier4 = 0x400,
    };

    // The tension picks the base-plate scale curve input; when there is no live sequence, when a
    // replay backup is active, or below the appear threshold, the plate maps the quiet group, and
    // above it the pulsing group. InterpolateFloatByPosition(input, lo, hi, valAtLo, valAtHi).
    int tension = 0;
    float haku = 0.0f;
    float input;
    float lo;
    float hi;
    float valAtLo;
    float valAtHi;
    if (self.sequence == nil) {
        input = 0.0f;
        lo = 0.0f;
        hi = kBgAppearThreshold;
        valAtLo = kBgAppearHigh;
        valAtHi = 1.0f;
    } else {
        if (self.scoreBackup) {
            return;
        }
        const ScoreData *score = self.sequence.getScore;
        haku = self.sequence.hakuPhase;
        if (score) {
            tension = score->tension;
        }
        input = haku;
        if (haku < kBgAppearThreshold) {
            lo = 0.0f;
            hi = kBgAppearThreshold;
            valAtLo = kBgAppearHigh;
            valAtHi = 1.0f;
        } else {
            lo = kBgAppearThreshold;
            hi = 1.0f;
            valAtLo = 1.0f;
            valAtHi = kBgAppearHigh;
        }
    }
    float plateScale = InterpolateFloatByPosition(input, lo, hi, valAtLo, valAtHi);
    float rippleMag = plateScale * kBaseScaleNorm * kBaseScaleMag;

    // The base plate: sprite 0 drawn at (32, plateY), scaled by the beat pulse about (160,
    // anchorY). The four-inch phone shifts the plate top and anchor down by the button margin.
    double plateY;
    double anchorY;
    if (is4Inch) {
        int margin = self.buttonMarginForScreen40;
        plateY = (double)((float)(margin + kFourInchGameTop) + kBasePlateYShift);
        anchorY = (double)(margin + 0x140);
    } else {
        plateY = kBasePlateYDefault;
        anchorY = kBasePlateAnchorYDefault;
    }
    [self.texCombo drawSprite:0
                      atPoint:CGPointMake(kBasePlatePointX, plateY)
                        scale:rippleMag
                       rotate:0.0f
                       anchor:CGPointMake(kBasePlateAnchorX, anchorY)
                    transform:0
                        alpha:1.0f];

    // Step every background ripple and drop the ones that report themselves finished, then render
    // the survivors.
    NSMutableArray *toRemove = [NSMutableArray array];
    for (BGRipple *ripple in self.arrayBgRip) {
        if ([ripple step]) {
            [toRemove addObject:ripple];
        } else {
            [ripple renderWithTexture:self.texCombo];
        }
    }
    [self.arrayBgRip removeObjectsInArray:toRemove];

    // On a beat frame (odd frame counter), maybe spawn a new ripple whose parameters come from the
    // tension tier.
    if ((self->frame & 1) != 0) {
        NSUInteger spriteBits;
        int lifetime;
        unsigned int spawnChance;
        unsigned int xRange;
        unsigned int yRange;
        if (tension < kTensionTier1) {
            spriteBits = (arc4random() & 3) + 1;
            lifetime = (int)(arc4random() % 6 + 0x1a);
            spawnChance = 0x80;
            xRange = 0x8c;
            yRange = 0x8c;
        } else if (tension < kTensionTier2) {
            spriteBits = (arc4random() & 3) + 5;
            lifetime = (int)(arc4random() % 0x11 + 0x13);
            spawnChance = 200;
            xRange = 0xbe;
            yRange = 0xbe;
        } else if (tension < kTensionTier3) {
            spriteBits = (arc4random() & 3) + 9;
            lifetime = (int)(arc4random() % 0x16 + 0xc);
            spawnChance = 0xe6;
            xRange = 0x122;
            yRange = 0x122;
        } else if (tension < kTensionTier4) {
            spriteBits = (arc4random() & 3) + 0xd;
            lifetime = (int)(arc4random() % 0x12 + 0x1a);
            spawnChance = 0x118;
            xRange = 0x14a;
            yRange = 0x136;
        } else {
            spriteBits = (arc4random() & 7) + 0x11;
            lifetime = (int)(arc4random() % 0x32 + 0x14);
            spawnChance = 0x154;
            xRange = 0x14a;
            yRange = 0xe6;
        }

        // Weighted by the tier's spawn chance (a further arc4random draw modulo 0x50 against the
        // per-tier gate).
        if (arc4random() % 0x50 < yRange) {
            unsigned int xr = arc4random();
            unsigned int cx = (spawnChance != 0) ? (xr / spawnChance) : 0;
            unsigned int yr = arc4random();
            unsigned int cy = (xRange != 0) ? (yr / xRange) : 0;
            unsigned int zr = arc4random();
            unsigned int cz = (yRange != 0) ? (zr / yRange) : 0;
            int gameTop =
                is4Inch ? (self.buttonMarginForScreen40 + kFourInchGameTop) : kFourInchGameTop;
            float baseSize = (float)(int)((xr - cx * spawnChance) + 0x80);
            float xSpeed = baseSize * kBgRippleMag;
            unsigned int life2 = arc4random() % 0x14 + 0x82;
            (void)[self.texCombo spriteAtIndex:spriteBits];
            CGPoint at =
                CGPointMake((double)((yr + 0xb9) - (cy * xRange + (xRange >> 1))),
                            (double)((0xa0 - (yRange >> 1)) + (zr - cz * yRange) + gameTop));
            BGRipple *ripple =
                [[BGRipple alloc] initWithSprite:spriteBits
                                         atPoint:at
                                          xSpeed:xSpeed
                                        lifetime:life2
                                        basesize:rippleMag
                                             mag:baseSize * kBgRippleMag2
                                           alpha:(float)lifetime / kBgRippleAlphaDiv];
            [self.arrayBgRip addObject:ripple];
        }
    }
}

/** @ghidraAddress 0x14aac0 */
- (void)renderShutter:(BOOL)drive {
    static const float kTensionScale = 0.0009765625f;  // @ghidraAddress 0x292540 (1/1024)
    static const float kShutterTensionFactor = 435.0f; // @ghidraAddress 0x292544
    static const float kShutterAmpFactor = 10.0f;      // An fmov immediate.
    static const float kShutterAmpBase = 15.0f;        // An fmov immediate.
    static const float kShutterHalf = 0.5f;
    static const float kBgAppearHigh = 1.1f;              // @ghidraAddress 0x292ab8
    static const float kShutterInterpTo = 1.7f;           // @ghidraAddress 0x292ac4
    static const float kShutterCapInterpTo = 2.79999995f; // @ghidraAddress 0x292594
    static const double kShutterXNudge = -40.0;           // @ghidraAddress 0x28e078
    static const int kShutterBarSpriteBias = 0x19;
    static const NSUInteger kShutterCapSprite0 = 0x1c;
    static const NSUInteger kShutterCapSprite1 = 0x1d;
    static const double kFieldWidth = 320.0; // @ghidraAddress 0x28f470
    static const double kCapX0 = 160.0;      // @ghidraAddress 0x28f438
    static const double kCapX1 = 240.0;      // @ghidraAddress 0x291bf0
    // The first shutter-bar group: an index list and a per-bar {x0, y0, x1, y1} float table.
    /** @ghidraAddress 0x293110 */
    static const int kShutterBarIndex0[] = {2, 0, 0, 0};
    /** @ghidraAddress 0x293120 */
    static const float kShutterBar0[] = {189.8f,
                                         243.3f,
                                         335.8f,
                                         429.6f,
                                         142.5f,
                                         247.9f,
                                         10.4f,
                                         437.1f,
                                         179.2f,
                                         66.3f,
                                         209.3f,
                                         -127.3f,
                                         98.4f,
                                         68.8f,
                                         -19.0f,
                                         -108.1f};
    // The second shutter-bar group: fourteen rows.
    /** @ghidraAddress 0x293160 */
    static const int kShutterBarIndex1[] = {0, 1, 0, 2, 0, 1, 2, 2, 0, 2, 1, 1, 0, 0};
    /** @ghidraAddress 0x293198 */
    static const float kShutterBar1[] = {
        179.6f, 212.5f, 263.3f, 390.0f, 160.8f, 96.7f,  156.7f, -70.8f, 216.3f, 164.2f,
        392.5f, 169.2f, 209.2f, 135.9f, 392.5f, 48.9f,  112.9f, 174.2f, -72.7f, 298.9f,
        147.3f, 217.2f, 123.3f, 391.4f, 192.3f, 154.9f, 391.6f, 93.8f,  190.4f, 109.6f,
        301.7f, -70.0f, 114.6f, 133.8f, -70.4f, 67.2f,  115.7f, 198.3f, -70.9f, 339.6f,
        136.0f, 148.3f, -70.0f, 9.6f,   207.3f, 192.1f, 392.5f, 283.8f, 101.7f, 156.3f,
        -71.9f, 204.8f, 128.4f, 107.2f, 11.0f,  -69.8f};

    // The beat phase drives the sinusoidal ripple applied to each bar corner.
    float tension = 0.0f;
    double sinArg = 0.0;
    if (self.sequence != nil) {
        if (self.scoreBackup) {
            return;
        }
        const ScoreData *score = self.sequence.getScore;
        float haku = self.sequence.hakuPhase;
        sinArg = (double)haku * g_dPi;
        if (score) {
            tension = (float)score->tension;
        }
    }

    // The shutter-open amount is either advanced from the tension and beat, or held.
    if (drive) {
        float target = tension * kShutterTensionFactor * kTensionScale;
        if (target > 0.0f) {
            float amp = tension * kShutterAmpFactor * kTensionScale + kShutterAmpBase;
            float wave = (float)sin(sinArg);
            target = target + (amp - amp * wave);
        }
        self->shutterOpen = (target + self->shutterOpen) * kShutterHalf;
    }

    float barInterp = InterpolateFloatByPosition(
        self->shutterOpen, 0.0f, kShutterTensionFactor, kBgAppearHigh, kShutterInterpTo);
    double sinNudge = kShutterXNudge;

    // First bar group: four rows, sinusoid-offset pairs from the shared table.
    for (int i = 0; i < 4; ++i) {
        float x0 = InterpolateFloatByPosition(self->shutterOpen,
                                              0.0f,
                                              kShutterTensionFactor,
                                              kShutterBar0[i * 4],
                                              kShutterBar0[i * 4 + 2]);
        float y0 = InterpolateFloatByPosition(self->shutterOpen,
                                              0.0f,
                                              kShutterTensionFactor,
                                              kShutterBar0[i * 4 + 1],
                                              kShutterBar0[i * 4 + 3]);
        int gameTop = is4Inch ? self.buttonMarginForScreen40 : 0;
        double bx = (double)x0;
        double by = (double)y0 + (double)(gameTop + kFourInchGameTop);
        NSUInteger sprite = (NSUInteger)(kShutterBarIndex0[i] + kShutterBarSpriteBias);
        [self.texCombo drawSprite:sprite
                          atPoint:CGPointMake(bx + sinNudge, by + sinNudge)
                            scale:barInterp
                           rotate:0.0f
                           anchor:CGPointMake(bx, by)
                        transform:0
                            alpha:1.0f];
    }

    // The two shutter caps, at fixed vertical bands, scaled by the field.
    double capY = is4Inch ? (double)(self.buttonMarginForScreen40 + 0x140) : kFieldWidth;
    float capInterp = InterpolateFloatByPosition(
        self->shutterOpen, 0.0f, kShutterTensionFactor, 1.0f, kShutterCapInterpTo);
    for (int i = 0; i < 4; ++i) {
        float spin = (float)((double)((float)i * 0.5f) * g_dPi);
        int top0 = is4Inch ? (self.buttonMarginForScreen40 + kFourInchGameTop) : kFourInchGameTop;
        [self.texCombo drawSprite:kShutterCapSprite0
                          atPoint:CGPointMake(kCapX0, (double)top0)
                            scale:capInterp
                           rotate:spin
                           anchor:CGPointMake(kCapX0, capY)
                        transform:0
                            alpha:1.0f];
        int top1 = is4Inch ? (self.buttonMarginForScreen40 + 0x118) : 0x118;
        [self.texCombo drawSprite:kShutterCapSprite1
                          atPoint:CGPointMake(kCapX1, (double)top1)
                            scale:capInterp
                           rotate:spin
                           anchor:CGPointMake(kCapX0, capY)
                        transform:0
                            alpha:1.0f];
    }

    // Second bar group: fourteen rows, sinusoid-offset from the larger table.
    for (int i = 0; i < 14; ++i) {
        float x0 = InterpolateFloatByPosition(self->shutterOpen,
                                              0.0f,
                                              kShutterTensionFactor,
                                              kShutterBar1[i * 4],
                                              kShutterBar1[i * 4 + 2]);
        float y0 = InterpolateFloatByPosition(self->shutterOpen,
                                              0.0f,
                                              kShutterTensionFactor,
                                              kShutterBar1[i * 4 + 1],
                                              kShutterBar1[i * 4 + 3]);
        int gameTop = is4Inch ? self.buttonMarginForScreen40 : 0;
        double bx = (double)x0;
        double by = (double)y0 + (double)(gameTop + kFourInchGameTop);
        NSUInteger sprite = (NSUInteger)(kShutterBarIndex1[i] + kShutterBarSpriteBias);
        [self.texCombo drawSprite:sprite
                          atPoint:CGPointMake(bx + sinNudge, by + sinNudge)
                            scale:barInterp
                           rotate:0.0f
                           anchor:CGPointMake(bx, by)
                        transform:0
                            alpha:1.0f];
    }
}

/** @ghidraAddress 0x14affc */
- (void)renderCombo:(unsigned int)combo alpha:(float)alpha {
    static const float kFadeDivisor = 100.0f;          // @ghidraAddress 0x28f4e0
    static const double kComboBurstX = 160.0;          // @ghidraAddress 0x28f438
    static const float kComboBurstMirrorX = 320.0f;    // An fmov immediate.
    static const float kComboBurstTopDefault = 360.0f; // An fmov immediate.
    static const int kComboDigitStride = 0x4e;         // 78
    static const int kComboRowWidth = 0x140;           // 320
    static const NSUInteger kComboWordSprite = 0x1e;

    if (self.scoreBackup) {
        return;
    }
    // The combo-count glyph baseline drops by the button margin on the four-inch phone.
    float comboTop = kComboBurstTopDefault;
    if (is4Inch) {
        comboTop = (float)(self.buttonMarginForScreen40 + kFourInchGameTop) + kFadeDivisor;
    }
    if (self->comboEffectFrame != 0) {
        --self->comboEffectFrame;
    }

    BOOL drawBurst = YES;
    if (combo < self->lastCombo && self->lastCombo > kComboDrawThreshold) {
        self->comboCutFrame = 8;
    } else if (self->comboCutFrame == 0) {
        drawBurst = NO;
    }
    if (drawBurst) {
        if (self.showCombo) {
            (void)[self.texCombo spriteAtIndex:0x1f];
            float scale = InterpolateFloatByFrame(2.5f, 1.0f, self->comboCutFrame, 0, 8);
            float from;
            float to;
            unsigned int start;
            unsigned int end;
            if (self->comboCutFrame < 5) {
                start = 0;
                end = 5;
                from = 0.0f;
                to = 0.13f; // @0x292a98
            } else {
                start = 5;
                end = 8;
                from = 0.13f; // @0x292a98
                to = 0.54f;   // @0x292ad4
            }
            float burstAlpha = InterpolateFloatByFrame(from, to, self->comboCutFrame, start, end);
            // The burst-scale is passed as the rect width; the alpha is the fade. Its second draw
            // mirrors it across the field.
            [self.texCombo drawSprite:0x1f
                               inRect:CGRectMake(kComboBurstX, (double)comboTop, (double)scale, 0.0)
                            transform:0
                                alpha:burstAlpha];
            [self.texCombo drawSprite:0x1f
                               inRect:CGRectMake((double)(kComboBurstMirrorX - scale),
                                                 (double)comboTop,
                                                 (double)scale,
                                                 0.0)
                            transform:5
                                alpha:burstAlpha];
        }
        --self->comboCutFrame;
    }

    if (combo > kComboDrawThreshold) {
        if (self->lastCombo < combo) {
            self->comboEffectFrame = 10;
        }
        char digits[5];
        int n = snprintf(digits, sizeof(digits), "%d", combo);
        if (n >= 1) {
            unsigned int digitCount = (n < 5) ? (unsigned int)n : 4;
            int centre = (int)digitCount * -kComboDigitStride + kComboRowWidth;
            int centreOdd = (int)digitCount * -kComboDigitStride + kComboRowWidth + 1;
            if (centre >= 0) {
                centreOdd = centre;
            }
            int step = (int)self->comboEffectFrame;
            if (self.showCombo) {
                int baseX = centreOdd >> 1;
                if (digitCount - 1 < 4) {
                    // The three narrow digit counts stagger each digit's vertical offset by frame.
                    unsigned int span =
                        (~(unsigned int)n < (unsigned int)-5) ? 0xfffffffb : (unsigned int)~n;
                    int shifted = step - (int)span;
                    int x = baseX;
                    for (int j = 0; j < (int)digitCount; ++j) {
                        int offset = 0;
                        if (shifted - 0xb == j) {
                            offset = -5;
                        } else if (shifted - 0xc == j) {
                            offset = -10;
                        } else if (shifted - 0xd == j) {
                            offset = -0xf;
                        }
                        if ((unsigned int)(j + 1) > digitCount) {
                            offset = 0;
                        }
                        [self.texCombo
                            drawSprite:(NSUInteger)((long)digits[j] - 0x10)
                               atPoint:CGPointMake((double)x, (double)(comboTop + (float)offset))
                             transform:0
                                 alpha:alpha];
                        x += kComboDigitStride;
                    }
                } else {
                    int x = baseX;
                    for (int j = 0; j < (int)digitCount; ++j) {
                        [self.texCombo drawSprite:(NSUInteger)((long)digits[j] - 0x10)
                                          atPoint:CGPointMake((double)x, (double)(comboTop + 0.0f))
                                        transform:0
                                            alpha:alpha];
                        x += kComboDigitStride;
                    }
                }
                // The trailing "combo" word chip.
                [self.texCombo
                    drawSprite:kComboWordSprite
                       atPoint:CGPointMake((double)(int)(baseX +
                                                         (int)digitCount * kComboDigitStride -
                                                         0x49),
                                           (double)(comboTop + kFadeDivisor))
                     transform:1
                         alpha:alpha];
            }
        }
    }
    self->lastCombo = combo;
}

/** @ghidraAddress 0x14b4c8 */
- (void)renderUpdatedScore:(unsigned int)score atPoint:(CGPoint)point alpha:(double)alpha {
    static const NSUInteger kScorePrefixSprite = 0x4f;

    if (score == 0 || self.scoreBackup) {
        return;
    }
    char digits[8];
    snprintf(digits, sizeof(digits), "%7d", score);
    int lastNonDigit = -1;
    // Retina packs the digits 9 points apart, non-retina 10.
    int digitPitch = isRetina ? 9 : 10;
    for (int i = 0; i < 7; ++i) {
        if ((unsigned char)(digits[i] - '0') < 10) {
            [self.texFront
                drawSprite:(NSUInteger)((long)digits[i] + 0x20)
                   atPoint:CGPointMake(point.x + (double)(digitPitch * (i + 1)) + 1.0, point.y)
                 transform:(char)(int)(float)alpha
                     alpha:0];
        } else {
            lastNonDigit = i;
        }
    }
    [self.texFront
        drawSprite:kScorePrefixSprite
           atPoint:CGPointMake(point.x + (double)(digitPitch * (lastNonDigit + 1)) + 1.0, point.y)
         transform:(char)(int)(float)alpha
             alpha:0];
}

/** @ghidraAddress 0x14b6a0 */
- (void)renderScore:(unsigned int)score atPoint:(CGPoint)point alpha:(double)alpha {
    static const unsigned int kScoreRankThreshold = 0xaae60; // 700000
    static const int kScoreDigitStride = 0x19;               // 25
    static const int kScoreRollupDivisor = 1000000;
    static const NSUInteger kScoreLabelSprite = 0x1b;
    static const NSUInteger kScoreBoardLowSprite = 0x1d;
    static const NSUInteger kScoreBoardHighSprite = 0x1e;
    static const float kScoreWidthScale4Inch = 1.3f; // An fmov immediate.

    (void)[self.texFront spriteAtIndex:0x1c];
    if (score == 0) {
        self->scoreDisplay = 0;
    } else if (self->scoreDisplay != score) {
        int step = (self->scoreDisplay < score) ? 1 : -1;
        self->scoreDisplay = self->scoreDisplay + (((int)(score - self->scoreDisplay) + step) >> 1);
    }
    char digits[8];
    snprintf(digits, sizeof(digits), "%7d", self->scoreDisplay);

    // The glyph base and rollup source depend on whether the shown score has crossed 700000.
    long glyphBias;
    if (self->scoreDisplay < kScoreRankThreshold) {
        (void)[self.texFront spriteAtIndex:kScoreBoardLowSprite];
        glyphBias = 0xb;
    } else {
        (void)[self.texFront spriteAtIndex:kScoreBoardHighSprite];
        glyphBias = 0x15;
    }
    unsigned int rollupNumer = self->scoreDisplay * ((int)alpha + 3);
    double rollupWidth = (double)(rollupNumer / kScoreRollupDivisor);
    if (alpha <= rollupWidth) {
        rollupWidth = alpha;
    }

    if (!is4Inch) {
        // The label board, the rollup region (once full), the inner board, then the digits.
        [self.texFront drawSprite:kScoreLabelSprite
                          atPoint:CGPointMake(point.x, point.y)
                        transform:(char)(int)(float)alpha
                            alpha:0];
        if (rollupNumer >= (unsigned int)kScoreRollupDivisor) {
            // The source region is measured in double-density texels on retina.
            double dstW = rollupWidth;
            double regW = alpha;
            double regX = rollupWidth; // fromRegion x; the source is offset by the shown width
            double srcW = alpha;
            if (isRetina) {
                regX += regX;
                dstW = rollupWidth; // destination stays in points
                srcW += srcW;
                regW += regW;
            }
            (void)regW;
            [self.texFront drawInRect:CGRectMake(point.x, point.y, rollupWidth, alpha)
                           fromRegion:CGRectMake(regX, point.y, srcW, alpha)
                            transform:0
                                alpha:0.0f];
            (void)dstW;
        }
        [self.texFront drawSprite:0x1c
                          atPoint:CGPointMake(point.x, point.y)
                        transform:(char)(int)(float)alpha
                            alpha:0];
        for (int i = 0; i < 7; ++i) {
            if ((unsigned char)(digits[i] - '0') < 10) {
                [self.texFront
                    drawSprite:(NSUInteger)((long)digits[i] + glyphBias)
                       atPoint:CGPointMake(point.x + (double)(i * kScoreDigitStride), point.y)
                     transform:(char)(int)(float)alpha
                         alpha:0];
            }
        }
    } else {
        // The four-inch phone stretches the run to 1.3x about the passed anchor.
        double anchorX = point.x + alpha;
        double anchorY = point.y + alpha;
        (void)anchorX;
        (void)anchorY;
        [self.texFront drawSprite:kScoreLabelSprite
                          atPoint:CGPointMake(point.x, point.y)
                            scale:1.2f
                           rotate:0.0f
                           anchor:CGPointMake(point.x + alpha, point.y + alpha)
                        transform:(char)(int)(float)alpha
                            alpha:0];
        if (rollupNumer >= (unsigned int)kScoreRollupDivisor) {
            double s = kScoreWidthScale4Inch;
            [self.texFront drawInRect:CGRectMake((point.x + alpha) - rollupWidth * s,
                                                 (point.y + alpha) - alpha * s,
                                                 rollupWidth * s,
                                                 alpha * s)
                           fromRegion:CGRectMake(rollupWidth + rollupWidth,
                                                 point.y + point.y,
                                                 alpha + alpha,
                                                 alpha + alpha)
                            transform:0
                                alpha:0.0f];
        }
        [self.texFront drawSprite:0x1c
                          atPoint:CGPointMake(point.x, point.y)
                            scale:1.2f
                           rotate:0.0f
                           anchor:CGPointMake(point.x + alpha, point.y + alpha)
                        transform:(char)(int)(float)alpha
                            alpha:0];
        for (int i = 0; i < 7; ++i) {
            if ((unsigned char)(digits[i] - '0') < 10) {
                [self.texFront
                    drawSprite:(NSUInteger)((long)digits[i] + glyphBias)
                       atPoint:CGPointMake(point.x + (double)(i * kScoreDigitStride), point.y)
                         scale:1.2f
                        rotate:0.0f
                        anchor:CGPointMake(point.x + alpha, point.y + alpha)
                     transform:(char)(int)(float)alpha
                         alpha:0];
            }
        }
    }
}

/** @ghidraAddress 0x14bbe8 */
- (void)renderPartnerScore:(unsigned int)score
                   atPoint:(CGPoint)point
                     scale:(double)scale
                     alpha:(double)alpha {
    static const unsigned int kScoreRankThreshold = 0xaae60; // 700000
    static const int kScoreDigitStride = 0x19;               // 25
    static const double kPartnerLabelDX = 1.0;
    static const double kPartnerLabelDY = -14.0;
    static const NSUInteger kScoreLabelSprite = 0x1c;
    static const NSUInteger kPartnerLabelSprite = 0x3a;

    if (!self.isSession) {
        return;
    }
    double drawAlpha = self.isConnected ? alpha : (alpha * 0.5);
    (void)[self.texFront spriteAtIndex:0x1c];
    (void)[self.texFront spriteAtIndex:0x3b];

    if (score == 0) {
        self->partnerScoreDisplay = 0;
    } else if (self->partnerScoreDisplay != score) {
        int step = (self->partnerScoreDisplay < score) ? 1 : -1;
        self->partnerScoreDisplay =
            self->partnerScoreDisplay + (((int)(score - self->partnerScoreDisplay) + step) >> 1);
    }
    char digits[8];
    snprintf(digits, sizeof(digits), "%7d", self->partnerScoreDisplay);

    // The label and board are scaled about the passed scale; the partner run uses that scale for
    // both the cell width and height.
    [self.texFront drawSprite:kScoreLabelSprite
                       inRect:CGRectMake(point.x, point.y, scale * scale, alpha * scale)
                    transform:(char)(int)(float)drawAlpha
                        alpha:0];
    [self.texFront drawSprite:0x1c
                       inRect:CGRectMake(point.x, point.y, scale * scale, alpha * scale)
                    transform:(char)(int)(float)drawAlpha
                        alpha:0];
    long glyphBias = (self->partnerScoreDisplay < kScoreRankThreshold) ? 0xb : 0x15;
    for (int i = 0; i < 7; ++i) {
        if ((unsigned char)(digits[i] - '0') < 10) {
            [self.texFront
                drawSprite:(NSUInteger)((long)digits[i] + glyphBias)
                    inRect:CGRectMake(point.x + (double)(i * kScoreDigitStride) * scale + 1.0,
                                      point.y,
                                      scale * scale,
                                      alpha * scale)
                 transform:(char)(int)(float)drawAlpha
                     alpha:0];
        }
    }
    // The partner-name chip (sprite 0x3a) sits just above and left of the run.
    [self.texFront drawSprite:kPartnerLabelSprite
                      atPoint:CGPointMake(point.x + kPartnerLabelDX, point.y + kPartnerLabelDY)
                    transform:(char)(int)(float)drawAlpha
                        alpha:0];
}

/** @ghidraAddress 0x14bf14 */
- (void)renderMusicBar:(CGPoint)pos timeline:(BOOL)timeline alpha:(double)alpha {
    static const double kCellBaseXOffset = 40.0;   // @ghidraAddress 0x28f1f8
    static const float kCursorScale = 120.0f;      // @ghidraAddress 0x291be8
    static const float kFadeEnd = 1.29999995f;     // @ghidraAddress 0x292558
    static const float kPlayHeadScale = 240.0f;    // @ghidraAddress 0x292738
    static const double kPlayHeadX = 36.0;         // @ghidraAddress 0x28f53c
    static const double kPlayHeadYDefault = 130.0; // @ghidraAddress 0x28fa38
    static const int kNoteBaseCursor = 0x5a;
    static const int kNoteBaseLit = 0x62;
    static const NSUInteger kBackdropSprite = 0x1f;
    static const NSUInteger kPlayHeadSprite = 0x28;
    // The per-bar grade-colour sprite bases, indexed by the two-bit grade (xor 2). @0x2930f0
    static const int kGradeSpriteBase[] = {0x6a, 0x5a, 0x72, 0x62};
    static const int kCellPitch = 2;
    enum { kCellCount = 0x78 };

    [self.texFront drawSprite:kBackdropSprite
                      atPoint:CGPointMake(pos.x, pos.y)
                    transform:0
                        alpha:(float)alpha];
    if (!self.sequence) {
        return;
    }
    float playPosition = self.sequence.playPosition;
    const char *bar = self.sequence.getMusicBar;
    const ScoreData *score = self.sequence.getScore;
    ScoreData backup;
    if (self.scoreBackup) {
        backup = self.replayBackupScore;
        score = &backup;
    }
    double cellBaseX = pos.x + kCellBaseXOffset;
    float cursor = playPosition * kCursorScale;
    int drawX = 0;
    for (unsigned int i = 0; i < kCellCount; ++i) {
        int byteIndex = (int)i >> 1;
        int nibbleShift = ((int)i - (byteIndex << 1)) * 4;
        unsigned int note = (unsigned int)(((bar[byteIndex] >> nibbleShift) & 0xf) - 1);
        if (note < 8) {
            int baseSprite;
            if (self.state == kRenderStateFinish || self.state == kRenderStateResult ||
                self.scoreBackup || ((float)(int)i + kFadeEnd < cursor)) {
                int gradeIdx = (int)i >> 2;
                int gradeShift = ((int)i - (gradeIdx << 2)) * 2;
                unsigned int grade =
                    ((unsigned int)(score->musicBarResult[gradeIdx] >> gradeShift) & 3) ^ 2;
                baseSprite = kGradeSpriteBase[grade];
            } else {
                baseSprite = kNoteBaseCursor;
                if ((float)(int)i + kComboFadeBase < cursor) {
                    baseSprite = kNoteBaseLit;
                }
            }
            [self.texFront drawSprite:(NSUInteger)((int)note + baseSprite)
                              atPoint:CGPointMake(cellBaseX + (double)drawX, pos.y - 1.0)
                            transform:0
                                alpha:(float)alpha];
        }
        drawX += kCellPitch;
    }
    if (timeline) {
        double headY = is4Inch ? (double)(self.upperBgHeight40 + 0x7e) : kPlayHeadYDefault;
        [self.texFront
            drawSprite:kPlayHeadSprite
               atPoint:CGPointMake((double)(playPosition * kPlayHeadScale + (float)kPlayHeadX),
                                   headY)
             transform:0
                 alpha:(float)alpha];
    }
}

/** @ghidraAddress 0x14c5d4 */
- (void)renderUpperBG:(BOOL)wipe {
    static const double kFieldWidth = 320.0;        // @ghidraAddress 0x28f470
    static const double kUpperPlateY = 120.0;       // @ghidraAddress 0x28f210
    static const double kUpperBandYDefault = 160.0; // @ghidraAddress 0x28f438
    static const double kUpperBandXDefault = 40.0;  // @ghidraAddress 0x28f1f8
    static const double kBeamX = 70.0;              // @ghidraAddress 0x28f6a0
    static const float kBounceDecay = 0.99f;        // @ghidraAddress 0x292ad8
    static const float kBouncePress = 10.0f;        // An fmov immediate.
    static const float kBounceCap = 80.0f;          // @ghidraAddress 0x28e018
    static const float kUpperBgGravity = 3.0f;      // via 0x40400000
    static const float kUpperBgResetX = 330.0f;     // @ghidraAddress 0x292f9c
    static const float kJumpBonus = 14.0f;          // An fmov immediate.
    static const NSUInteger kUpperPlateSprite = 0xc;
    static const NSUInteger kUpperBandSprite = 0xb;
    static const NSUInteger kUpperBeamSprite0 = 0xe;
    static const NSUInteger kUpperBeamSprite1 = 0xf;
    // The upper-plate top per idiom (non-four-inch, four-inch). @ghidraAddress 0x293030
    static const double kUpperPlateTop[] = {160.0, 256.0};

    // The tiled upper plate: sprite 0xc filling the header. The four-inch phone lifts its top by
    // 30 points.
    [self.texFront
        drawSprite:kUpperPlateSprite
            inRect:CGRectMake(
                       0.0, is4Inch ? -30.0 : 0.0, kFieldWidth, kUpperPlateTop[is4Inch ? 1 : 0])];
    // The header band: sprite (diff + 7, clamped to 0xa) across the top, then sprite 0xb at the
    // game-area line.
    long bandSprite = (long)self.rendererConf.diff + 7;
    if ((unsigned int)self.rendererConf.diff > 2) {
        bandSprite = 10;
    }
    [self.texFront drawSprite:(NSUInteger)bandSprite
                       inRect:CGRectMake(0.0, 0.0, kFieldWidth, kUpperPlateY)];
    (void)[self.texFront spriteAtIndex:4];
    double bandY;
    double halfSpan;
    if (is4Inch) {
        int top = self.upperBgHeight40;
        bandY = (double)(float)((double)(top + kFourInchGameTop) - (kUpperPlateY + kUpperPlateY));
        halfSpan = kUpperPlateY + kUpperPlateY;
    } else {
        bandY = (double)(float)(kUpperBandYDefault - kUpperPlateY);
        halfSpan = kUpperBandXDefault;
    }
    [self.texFront drawSprite:kUpperBandSprite
                       inRect:CGRectMake(0.0, bandY, kFieldWidth, kUpperPlateY)];

    // The beam wipe animates in over the first ten frames when requested.
    if (wipe) {
        (void)[self.texFront spriteAtIndex:0xe];
        float h0 = InterpolateFloatByFrame(0.0f, (float)halfSpan, self->frame, 0, 10);
        double regionScale = isRetina ? 2.0 : 1.0;
        [self.texFront
            drawInRect:CGRectMake(
                           kFieldWidth * -0.5 + kBeamX, bandY - (double)h0, kFieldWidth, (double)h0)
            fromRegion:CGRectMake(0.0 * regionScale,
                                  bandY,
                                  kFieldWidth * regionScale,
                                  (double)h0 * regionScale)
             transform:0
                 alpha:0.0f];
        (void)[self.texFront spriteAtIndex:0xf];
        float h1 = InterpolateFloatByFrame(0.0f, (float)h0, self->frame, 0, 10);
        [self.texFront
            drawInRect:CGRectMake(kFieldWidth * -0.5 + kBeamX, bandY, kFieldWidth, (double)h1)
            fromRegion:CGRectMake(0.0,
                                  (bandY - (double)h0) + ((double)h0 - (double)h1),
                                  kFieldWidth * regionScale,
                                  (double)h1 * regionScale)
             transform:0
                 alpha:0.0f];
        (void)kUpperBeamSprite0;
        (void)kUpperBeamSprite1;
    }

    // Outside the pre-play states, the upper sprites bounce under button presses and the beat, then
    // all upper ripples are stepped and rendered against the front atlas.
    float gravity = kComboFadeBase;
    float bounce = g_flKeyTime040;
    if (self.state != 0 && self.state != kRenderStatePreStart &&
        self.state != kRenderStateReadyGo) {
        self->bounceEnergy = self->bounceEnergy * kBounceDecay;
        if (self.btnDown != 0) {
            self->bounceEnergy = self->bounceEnergy + kBouncePress;
        }
        if (self->bounceEnergy > kBounceCap) {
            self->bounceEnergy = kBounceCap;
        }
        gravity = 0.0f;
        bounce = kUpperBgGravity;
        if (!self.sequence) {
            self->lastHakuPhase = 0.0f;
        } else {
            float prevHaku = self->lastHakuPhase;
            float haku = self.sequence.hakuPhase;
            self->lastHakuPhase = haku;
            // A beat wrap (the phase dropping) triggers a jump of every ripple.
            if (haku < prevHaku) {
                for (UpperBGRipple *ripple in self.arrayUpperBgRip) {
                    [ripple triggerJump:self->bounceEnergy + kJumpBonus];
                }
            }
        }
    }
    for (UpperBGRipple *ripple in self.arrayUpperBgRip) {
        [ripple stepFall:kUpperBgResetX gravity:bounce bounce:gravity];
        int yLimit = is4Inch ? (self.upperBgHeight40 + kFourInchGameTop) : 0x90;
        [ripple renderWithTexture:self.texFront yLimit:(float)yLimit];
    }
}

/** @ghidraAddress 0x14d718 */
- (void)renderReadyGo {
    static const float kDiscScale = 320.0f;   // @ghidraAddress 0x292734
    static const float kDiscHeight = 32.0f;   // @ghidraAddress 0x292f90
    static const float kDiscScale2 = 1.8f;    // @ghidraAddress 0x292ae8
    static const double kFieldWidth = 320.0;  // @ghidraAddress 0x28f470
    static const double kCentreX = 160.0;     // @ghidraAddress 0x28f438
    static const double kGoX0 = 118.0;        // @ghidraAddress 0x28f428
    static const double kGoX1 = 203.0;        // @ghidraAddress 0x292f40
    static const double kGoX2 = 240.0;        // @ghidraAddress 0x291bf0
    static const float kLetterBaseX = 160.0f; // @ghidraAddress 0x28e014
    static const double kBlowFirstX = 80.0;   // @ghidraAddress 0x28f3f8
    static const double kGoCentreX0 = 75.0;   // @ghidraAddress 0x28f788
    static const double kGoCentreX1 = 245.0;  // @ghidraAddress 0x292f48
    static const float kGoScaleEnd = 0.2f;    // @ghidraAddress 0x28f3c8
    // The ready-letter spread table (8 floats). @ghidraAddress 0x293288
    static const float kReadyLetterSpread[] = {80.0f, 0.0f, 0.2f, 0.1f, 0.3f, 0.2f, 0.4f, 0.3f};
    static const NSUInteger kDiscSprite = 0;
    static const NSUInteger kLetterSprite = 1;

    double centreY = is4Inch ? (double)(self.buttonMarginForScreen40 + 0x140) : kFieldWidth;
    unsigned int f = self->frame;
    // The disc's rest scale/height carried into the "GO" phase.
    double discW = 0.0;
    double discH = 0.0;

    if (f < 0x14) {
        // Phase 1: the disc swells in from the field centre.
        float discAlpha = InterpolateFloatByFrame(0.0f, 1.0f, f, 5, 0xf);
        discH = (double)(discAlpha * kDiscHeight);
        [self.texReady0 drawSprite:kDiscSprite
                            inRect:CGRectMake(0.0, centreY + discH * -0.5, kFieldWidth, discH)
                         transform:0
                             alpha:1.0f];
    } else if (f < 0x32) {
        // Phase 2: the disc holds and the "READY" letters settle in one by one.
        unsigned int p = f - 0x14;
        float discAlpha = InterpolateFloatByFrame(1.0f, 0.0f, p, 0, 0xe);
        float discScale = InterpolateFloatByFrame(1.0f, g_flKeyTime080, p, 0, 0xe);
        discW = (double)(discScale * kDiscScale);
        float discHeight = InterpolateFloatByFrame(1.0f, kDiscScale2, p, 0, 0xe);
        discH = (double)(discHeight * kDiscHeight);
        [self.texReady0
            drawSprite:kDiscSprite
                inRect:CGRectMake(kCentreX - discW * 0.5, centreY - discH * 0.5, discW, discH)
             transform:0
                 alpha:discAlpha];
        (void)[self.texReady0 spriteAtIndex:kLetterSprite];
        double halfW = discW * 0.5;
        double baseY = centreY - discH * 0.5;
        // Letters slide in staggered; each letter's slide keyframe comes from the spread table.
        for (long lv = 0; lv + 4 <= (long)(int)p; ++lv) {
            float spr = kReadyLetterSpread[lv];
            unsigned int end = (unsigned int)(lv + 0xc);
            float slide = InterpolateFloatByFrame(0.0f, spr, p, (unsigned int)(lv + 4), end);
            [self.texReady0 drawSprite:(NSUInteger)(lv + 5)
                               atPoint:CGPointMake((double)(slide + kLetterBaseX) - halfW, baseY)
                             transform:0
                                 alpha:1.0f];
            if (lv + 10 <= (long)(int)p && (long)(int)p < lv + 0x1a) {
                float from;
                float to;
                unsigned int start;
                unsigned int stop;
                if ((long)(int)p < lv + 0xc) {
                    from = 0.0f;
                    to = 1.0f;
                    start = (unsigned int)(lv + 10);
                    stop = end;
                } else {
                    from = 1.0f;
                    to = 0.0f;
                    start = end;
                    stop = (unsigned int)(lv + 0x1a);
                }
                float letterAlpha = InterpolateFloatByFrame(from, to, p, start, stop);
                (void)letterAlpha;
                [self.texReady0
                    drawSprite:(NSUInteger)(lv + 10)
                       atPoint:CGPointMake((double)(spr + kLetterBaseX) - discH * 0.5, baseY)
                     transform:0
                         alpha:letterAlpha];
            }
        }
    } else if (f < 0x36) {
        // Phase 3: the disc blows up into five mirrored copies and fades.
        (void)[self.texReady0 spriteAtIndex:kLetterSprite];
        float scale = InterpolateFloatByFrame(1.0f, kGoScaleEnd, self->frame, 0x32, 0x36);
        float alpha = InterpolateFloatByFrame(1.0f, 0.0f, self->frame, 0x32, 0x36);
        discW = (double)scale;
        double cy = centreY - discH * 0.5;
        [self.texReady0 drawSprite:kDiscSprite
                           atPoint:CGPointMake(kBlowFirstX - discW * 0.5, cy)
                             scale:scale
                            rotate:0.0f
                            anchor:CGPointMake(kCentreX, centreY)
                         transform:1
                             alpha:alpha];
        [self.texReady0 drawSprite:kDiscSprite
                           atPoint:CGPointMake(kGoX0 - discW * 0.5, cy)
                             scale:scale
                            rotate:0.0f
                            anchor:CGPointMake(kCentreX, centreY)
                         transform:2
                             alpha:alpha];
        [self.texReady0 drawSprite:kDiscSprite
                           atPoint:CGPointMake(kCentreX - discW * 0.5, cy)
                             scale:scale
                            rotate:0.0f
                            anchor:CGPointMake(kCentreX, centreY)
                         transform:3
                             alpha:alpha];
        [self.texReady0 drawSprite:kDiscSprite
                           atPoint:CGPointMake(kGoX1 - discW * 0.5, cy)
                             scale:scale
                            rotate:0.0f
                            anchor:CGPointMake(kCentreX, centreY)
                         transform:4
                             alpha:alpha];
        [self.texReady0 drawSprite:kDiscSprite
                           atPoint:CGPointMake(kGoX2 - discW * 0.5, cy)
                             scale:scale
                            rotate:0.0f
                            anchor:CGPointMake(kCentreX, centreY)
                         transform:5
                             alpha:alpha];
    }

    // The "GO" chips (texReady1) spin and fade through frames 52..82.
    (void)[self.texReady1 spriteAtIndex:0];
    unsigned int gf = self->frame;
    if (gf >= 0x34 && gf < 0x3a) {
        double gy = centreY - discH * 0.5;
        float sL = InterpolateFloatByFrame(g_flKeyTime040, 1.0f, gf, 0x34, 0x3a);
        float aL = InterpolateFloatByFrame(0.0f, 1.0f, self->frame, 0x34, 0x3a);
        [self.texReady1 drawSprite:0
                           atPoint:CGPointMake(kGoCentreX0 - discW * 0.5, gy)
                             scale:sL
                            rotate:0.0f
                            anchor:CGPointMake(kCentreX, centreY)
                         transform:0
                             alpha:aL];
        float sR = InterpolateFloatByFrame(g_flKeyTime040, 1.0f, self->frame, 0x34, 0x3a);
        float aR = InterpolateFloatByFrame(0.0f, 1.0f, self->frame, 0x34, 0x3a);
        [self.texReady1 drawSprite:1
                           atPoint:CGPointMake(kGoCentreX1 - discW * 0.5, gy)
                             scale:sR
                            rotate:0.0f
                            anchor:CGPointMake(kCentreX, centreY)
                         transform:1
                             alpha:aR];
    } else if (gf >= 0x3a && gf < 0x53) {
        double gy = centreY - discH * 0.5;
        double goX0 = kGoCentreX0 - discW * 0.5;
        float s0 = InterpolateFloatByFrame(1.0f, g_flKeyTime040, gf, 0x3a, 0x53);
        float a0 = InterpolateFloatByFrame(g_flKeyTime070, 0.0f, self->frame, 0x3a, 0x53);
        [self.texReady1 drawSprite:0
                           atPoint:CGPointMake(goX0, gy)
                             scale:s0
                            rotate:0.0f
                            anchor:CGPointMake(kCentreX, centreY)
                         transform:2
                             alpha:a0];
        float s1 = InterpolateFloatByFrame(1.0f, g_flKeyTime040, self->frame, 0x3a, 0x51);
        float a1 = InterpolateFloatByFrame(1.0f, 0.0f, self->frame, 0x3a, 0x51);
        [self.texReady1 drawSprite:0
                           atPoint:CGPointMake(goX0, gy)
                             scale:s1
                            rotate:0.0f
                            anchor:CGPointMake(kCentreX, centreY)
                         transform:0
                             alpha:a1];
        double goX1 = kGoCentreX1 - discW * 0.5;
        float s2 = InterpolateFloatByFrame(1.0f, g_flKeyTime040, self->frame, 0x3a, 0x53);
        float a2 = InterpolateFloatByFrame(g_flKeyTime070, 0.0f, self->frame, 0x3a, 0x53);
        [self.texReady1 drawSprite:1
                           atPoint:CGPointMake(goX1, gy)
                             scale:s2
                            rotate:0.0f
                            anchor:CGPointMake(kCentreX, centreY)
                         transform:3
                             alpha:a2];
        float s3 = InterpolateFloatByFrame(1.0f, g_flKeyTime040, self->frame, 0x3a, 0x51);
        float a3 = InterpolateFloatByFrame(1.0f, 0.0f, self->frame, 0x3a, 0x51);
        [self.texReady1 drawSprite:1
                           atPoint:CGPointMake(goX1, gy)
                             scale:s3
                            rotate:0.0f
                            anchor:CGPointMake(kCentreX, centreY)
                         transform:1
                             alpha:a3];
    }

    if (self->frame == 0x14) {
        [AudioManager.sharedManager playSeResFile:@"SD_RPL_CV_READY" inDirectory:nil];
    }
    if (self->frame == 0x3a) {
        [AudioManager.sharedManager playSePlayer:self.sePlayerGo];
        self.sePlayerGo = nil;
    }
    if (self->frame >= 0x55) {
        self.subState = kMainGameEndSubState;
    }
    (void)kDiscScale;
}

/** @ghidraAddress 0x14e254 */
- (void)renderFullcombo:(int)animFrame {
    static const float kCornerScaleMid = 0.9f;  // @ghidraAddress 0x28f3b0
    static const float kCornerScaleHigh = 1.4f; // @ghidraAddress 0x292af0
    static const double kFieldWidth = 200.0;    // @ghidraAddress 0x28f400
    static const double kWord0X = 130.0;        // @ghidraAddress 0x292fb4
    static const double kWord0X2 = 89.0;        // @ghidraAddress 0x292fb0
    static const double kWord0X3 = 69.0;        // @ghidraAddress 0x292fa4
    static const double kWord1X = 175.0;        // @ghidraAddress 0x292fb8
    static const double kWord1X2 = 213.0;       // @ghidraAddress 0x292b08
    static const double kWord1X3 = 228.0;       // @ghidraAddress 0x292fac
    static const double kWord2X = -52.5;        // @ghidraAddress 0x292fa0
    static const double kWord2X2 = 311.0;       // @ghidraAddress 0x292b0c
    static const double kWord2X3 = 327.5;       // @ghidraAddress 0x292fa8
    static const double kWordAY = 440.0;        // @ghidraAddress 0x292f50
    static const double kWordBX = 69.0;         // @ghidraAddress 0x292f58
    static const double kWordBY = 228.0;        // @ghidraAddress 0x292f60
    static const NSUInteger kCornerSprite = 0x2a;
    static const NSUInteger kWordSprite0 = 0x2c;
    static const NSUInteger kWordSprite1 = 0x2e;
    static const NSUInteger kWordSprite2 = 0x2b;
    static const NSUInteger kWordSprite3 = 0x2d;

    if (self.scoreBackup) {
        return;
    }
    // On frame 2, cue the clear jingle and the full-combo voice.
    if (animFrame == 2) {
        [AudioManager.sharedManager playSeResFile:@"SD_RPL_RESULT_CLEAR" inDirectory:nil];
        [AudioManager.sharedManager playSeResFile:@"SD_RPL_CV_FULLCOMBO" inDirectory:nil];
    }

    // Prime the corner and word sprite cells (their sizes feed the shared draw scratch).
    CGRect cornerRect = [self.texFront spriteAtIndex:0x2a];
    CGRect word0Rect = [self.texFront spriteAtIndex:0x2b];
    CGRect word1Rect = [self.texFront spriteAtIndex:0x2d];
    double cornerHalfH = cornerRect.size.height * 0.5;
    double cornerHalfW = cornerRect.size.width * 0.5;

    // Eight corner glyphs sweep in staggered by 6 frames each; two mirrored corners per row over
    // four grid rows.
    int cornerX = 0x28;
    int mirrorRow = 0xf;
    int animFrame = animFrame;
    for (int row = 0; row < 4; ++row) {
        if (animFrame >= 0) {
            float baseAlpha;
            unsigned int scaleStart;
            unsigned int scaleEnd;
            float scaleFrom;
            float scaleTo;
            if (animFrame < 4) {
                baseAlpha = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 0, 4);
                if (animFrame < 2) {
                    scaleStart = 0;
                    scaleEnd = 2;
                    scaleFrom = 1.0f;
                    scaleTo = kCornerScaleMid;
                } else {
                    scaleStart = 2;
                    scaleEnd = 0xc;
                    scaleFrom = kCornerScaleMid;
                    scaleTo = kCornerScaleHigh;
                }
            } else {
                baseAlpha = InterpolateFloatByFrame(1.0f, 0.0f, animFrame, 4, 0xc);
                scaleStart = 2;
                scaleEnd = 0xc;
                scaleFrom = kCornerScaleMid;
                scaleTo = kCornerScaleHigh;
            }
            float scale =
                InterpolateFloatByFrame(scaleFrom, scaleTo, animFrame, scaleStart, scaleEnd);
            int gameTop = is4Inch ? self.buttonMarginForScreen40 : 0;
            double topY = (double)((row * kGridCellSize) + gameTop + 200);
            [self.texFront drawSprite:kCornerSprite
                              atPoint:CGPointMake((double)cornerX - cornerRect.size.width * 0.5,
                                                  topY - cornerHalfH)
                                scale:scale
                               rotate:0.0f
                               anchor:CGPointMake((double)cornerX, topY)
                            transform:0
                                alpha:baseAlpha];
            int mirrorX = (mirrorRow % 4) * kGridCellSize + kButtonCellInset;
            double mirrorTop = (double)(((mirrorRow >> 2) * kGridCellSize) + gameTop + 200);
            [self.texFront drawSprite:kCornerSprite
                              atPoint:CGPointMake((double)mirrorX - cornerRect.size.width * 0.5,
                                                  mirrorTop - cornerHalfH)
                                scale:scale
                               rotate:0.0f
                               anchor:CGPointMake((double)mirrorX, mirrorTop)
                            transform:0
                                alpha:baseAlpha];
        }
        cornerX += kGridCellSize;
        mirrorRow -= 1;
        animFrame -= 6;
    }

    // The two "FULLCOMBO" word plates fly in over their own frame windows. Their x-keyframes come
    // from the shipped constant runs.
    int gameTop = is4Inch ? self.buttonMarginForScreen40 : 0;
    double wordAY = is4Inch ? (double)(gameTop + 200) : kFieldWidth;
    double wordBY = is4Inch ? (double)(gameTop + 0x1b8) : kWordAY;

    float alpha0;
    if (animFrame < 4) {
        alpha0 = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 4, 4);
    } else {
        alpha0 = InterpolateFloatByFrame(1.0f, 0.0f, animFrame, 0x55, 0x5a);
    }
    float wx0;
    if (animFrame < 4) {
        wx0 = (animFrame < 2) ?
                  InterpolateFloatByFrame((float)kWord0X, (float)kWord0X2, animFrame, 0, 2) :
                  InterpolateFloatByFrame((float)kWord0X2, (float)kWord0X3, animFrame, 2, 4);
    } else {
        wx0 = (animFrame < 0x5a) ?
                  InterpolateFloatByFrame((float)kWord0X3, -30.0f, animFrame, 0x55, 0x5a) :
                  InterpolateFloatByFrame(-30.0f, (float)kWord2X, animFrame, 0x5a, 0x5f);
    }
    float wx1;
    if (animFrame < 2) {
        wx1 = InterpolateFloatByFrame((float)kWord1X, (float)kWord1X2, animFrame, 0, 2);
    } else if (animFrame < 4) {
        wx1 = InterpolateFloatByFrame((float)kWord1X2, (float)kWord1X3, animFrame, 2, 4);
    } else if (animFrame < 0x5a) {
        wx1 = InterpolateFloatByFrame((float)kWord1X3, (float)kWord2X2, animFrame, 0x55, 0x5a);
    } else {
        wx1 = InterpolateFloatByFrame((float)kWord2X2, (float)kWord2X3, animFrame, 0x5a, 0x5f);
    }
    [self.texFront drawSprite:kWordSprite0
                      atPoint:CGPointMake((double)wx0 - word0Rect.size.width * 0.5,
                                          wordAY - word0Rect.size.height * 0.5)
                    transform:0x2c
                        alpha:alpha0];
    [self.texFront drawSprite:kWordSprite1
                      atPoint:CGPointMake((double)wx1 - word1Rect.size.width * 0.5,
                                          wordBY - word1Rect.size.height * 0.5)
                    transform:0x2e
                        alpha:alpha0];

    // The next word-plate pair, on the 6..0xc / 0x57..0x61 windows.
    float alpha1;
    if (animFrame < 0xc) {
        alpha1 = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 6, 0xc);
    } else {
        alpha1 = InterpolateFloatByFrame(1.0f, 0.0f, animFrame, 0x57, 0x61);
    }
    double word1PlateY = is4Inch ? (double)(gameTop + 0x1b8) : kWordAY;
    double word0PlateY = is4Inch ? (double)(gameTop + 200) : kFieldWidth;
    float wx2;
    float wx3;
    if (animFrame < 0xc) {
        wx2 = (animFrame < 9) ? InterpolateFloatByFrame(121.0f, 83.0f, animFrame, 6, 9) :
                                InterpolateFloatByFrame(83.0f, 69.0f, animFrame, 9, 0xc);
        wx3 = (animFrame < 9) ? InterpolateFloatByFrame(183.0f, 215.0f, animFrame, 6, 9) :
                                InterpolateFloatByFrame(215.0f, 228.0f, animFrame, 9, 0xc);
    } else if (animFrame < 0x5c) {
        wx2 = InterpolateFloatByFrame(69.0f, 152.0f, animFrame, 0x57, 0x5c);
        wx3 = InterpolateFloatByFrame(228.0f, 129.0f, animFrame, 0x57, 0x5c);
    } else {
        wx2 = InterpolateFloatByFrame(152.0f, 168.0f, animFrame, 0x5c, 0x61);
        wx3 = InterpolateFloatByFrame(129.0f, 107.0f, animFrame, 0x5c, 0x61);
    }
    [self.texFront drawSprite:kWordSprite0
                      atPoint:CGPointMake((double)wx2 - word0Rect.size.width * 0.5,
                                          word1PlateY - word0Rect.size.height * 0.5)
                    transform:0x2c
                        alpha:alpha1];
    [self.texFront drawSprite:kWordSprite1
                      atPoint:CGPointMake((double)wx3 - word1Rect.size.width * 0.5,
                                          word0PlateY - word1Rect.size.height * 0.5)
                    transform:0x2e
                        alpha:alpha1];

    // The two mirrored word plates that grow about a shared anchor, on the 5..0x2f / 6..0x34
    // windows.
    float alpha2 = (animFrame < 2) ? InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 0, 2) :
                                     InterpolateFloatByFrame(1.0f, 0.0f, animFrame, 5, 0x2f);
    float scale2 = InterpolateFloatByFrame(1.0f, 1.2f, animFrame, 5, 0x2f);
    double plate0Y = is4Inch ? (double)(gameTop + 200) : kFieldWidth;
    double plate1Y = is4Inch ? (double)(gameTop + 0x1b8) : kWordAY;
    [self.texFront drawSprite:kWordSprite2
                      atPoint:CGPointMake(kWordBX - word0Rect.size.width * 0.5,
                                          plate0Y - word0Rect.size.height * 0.5)
                        scale:scale2
                       rotate:0.0f
                       anchor:CGPointMake(kWordBX, plate0Y)
                    transform:0x2b
                        alpha:alpha2];
    [self.texFront drawSprite:kWordSprite3
                      atPoint:CGPointMake(kWordBY - word1Rect.size.width * 0.5,
                                          plate1Y - word1Rect.size.height * 0.5)
                        scale:scale2
                       rotate:0.0f
                       anchor:CGPointMake(kWordBY, plate1Y)
                    transform:0x2d
                        alpha:alpha2];

    float alpha3 = (animFrame < 8) ? InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 6, 8) :
                                     InterpolateFloatByFrame(1.0f, 0.0f, animFrame, 0xc, 0x34);
    float scale3 = InterpolateFloatByFrame(1.0f, 1.2f, animFrame, 0xc, 0x34);
    double plate2Y = is4Inch ? (double)(gameTop + 0x1b8) : kWordAY;
    double plate3Y = is4Inch ? (double)(gameTop + 200) : kFieldWidth;
    [self.texFront drawSprite:kWordSprite2
                      atPoint:CGPointMake(kWordBX - word0Rect.size.width * 0.5,
                                          plate2Y - word0Rect.size.height * 0.5)
                        scale:scale3
                       rotate:0.0f
                       anchor:CGPointMake(kWordBX, plate2Y)
                    transform:0x2b
                        alpha:alpha3];
    [self.texFront drawSprite:kWordSprite3
                      atPoint:CGPointMake(kWordBY - word1Rect.size.width * 0.5,
                                          plate3Y - word1Rect.size.height * 0.5)
                        scale:scale3
                       rotate:0.0f
                       anchor:CGPointMake(kWordBY, plate3Y)
                    transform:0x2d
                        alpha:alpha3];
    (void)cornerHalfW;
    (void)kWord1X;
    (void)kWord2X3;
}

/** @ghidraAddress 0x14ed9c */
- (void)renderFinish {
    // On finish, load the result texture in the background once the wipe has run; a full combo
    // shows the full-combo flourish first.
    __weak MainGameRendererPhoneRpl *weakSelf = self;
    void (^loadResult)(void) = ^{
      /** @ghidraAddress 0x14efa0 */
      [weakSelf loadResultTex:(short)weakSelf.sequence.rank];
      dispatch_async(dispatch_get_main_queue(), ^{
        /** @ghidraAddress 0x14f088 */
        [weakSelf setSubState:10];
      });
    };

    if (self.sequence.isFullcombo && !self.scoreBackup) {
        [self renderFullcombo:(int)self->frame];
        if (self.subState == 0 && self->frame > 99) {
            self.subState = 1;
            [self.eaglView performBlockInBackground:loadResult];
        }
    } else {
        if (self.subState == 0 && self->frame > 0x13) {
            self.subState = 1;
            [self.eaglView performBlockInBackground:loadResult];
        }
    }
}

/** @ghidraAddress 0x14feb8 */
- (void)renderRating:(unsigned int)animFrame {
    static const double kLabelXDefault = 326.0; // @ghidraAddress 0x292f70
    static const double kLabelYBase = 86.0;     // @ghidraAddress 0x28f950
    static const double kGlyphXDefault = 360.0; // @ghidraAddress 0x292918
    static const double kGlyphAnchorX = 200.0;  // @ghidraAddress 0x28f400
    static const float kRatingScaleMid = 1.16f; // @ghidraAddress 0x292b34
    static const float kRatingScaleLow = 1.6f;  // @ghidraAddress 0x292b30
    static const float kScaleReset = 0.2f;      // @ghidraAddress 0x28f3c8
    static const float kScaleMid2 = 0.9f;       // @ghidraAddress 0x28f3b0
    static const NSUInteger kLabelSprite = 0x38;
    static const NSUInteger kGlyphSprite = 0x39;

    int rank = (int)self.sequence.rank;
    double labelY = is4Inch ? (double)(self.buttonMarginForScreen40 + 0x146) : kLabelXDefault;
    double glyphY = is4Inch ? (double)(self.buttonMarginForScreen40 + 0x168) : kGlyphXDefault;
    if (rank < 5) {
        unsigned int labelEnd = (rank > 2) ? 7 : 0xe;
        unsigned int scaleEnd = (rank < 3) ? 4 : 3;
        float labelSlide = InterpolateFloatByFrame(25.0f, 0.0f, animFrame, 0, labelEnd);
        float labelAlpha = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 0, labelEnd);
        [self.texFront drawSprite:kLabelSprite
                          atPoint:CGPointMake((double)labelSlide + kLabelYBase, labelY)
                        transform:(char)(int)labelAlpha
                            alpha:0];
        (void)[self.texFront spriteAtIndex:kGlyphSprite];
        float glyphScale;
        if (animFrame < scaleEnd) {
            glyphScale = InterpolateFloatByFrame(2.0f, kRatingScaleMid, animFrame, 0, scaleEnd);
        } else {
            glyphScale =
                InterpolateFloatByFrame(kRatingScaleMid, 1.0f, animFrame, scaleEnd, scaleEnd);
        }
        [self.texFront drawSprite:kGlyphSprite
                          atPoint:CGPointMake(kGlyphAnchorX - (double)labelAlpha * 0.5,
                                              glyphY - (double)glyphScale * 0.5)
                            scale:glyphScale
                           rotate:0.0f
                           anchor:CGPointMake(kGlyphAnchorX, glyphY)
                        transform:0x39
                            alpha:0.0f];
    } else {
        float labelSlide = InterpolateFloatByFrame(25.0f, 0.0f, animFrame, 0, 0xd);
        float labelAlpha = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 0, 0xd);
        [self.texFront drawSprite:kLabelSprite
                          atPoint:CGPointMake((double)labelSlide + kLabelYBase, labelY)
                        transform:(char)(int)labelAlpha
                            alpha:0];
        (void)[self.texFront spriteAtIndex:kGlyphSprite];
        float glyphScale;
        if (animFrame < 8) {
            glyphScale = InterpolateFloatByFrame(2.0f, kRatingScaleLow, animFrame, 0, 8);
        } else if (animFrame < 0xe) {
            glyphScale = InterpolateFloatByFrame(kRatingScaleLow, kScaleMid2, animFrame, 8, 0xe);
        } else if (animFrame < 0x10) {
            glyphScale = InterpolateFloatByFrame(kScaleMid2, 1.0f, animFrame, 0xe, 0x10);
        } else {
            glyphScale = InterpolateFloatByFrame(kScaleReset, 1.0f, animFrame, 8, 0xd);
        }
        [self.texFront drawSprite:kGlyphSprite
                          atPoint:CGPointMake(kGlyphAnchorX - (double)labelAlpha * 0.5,
                                              glyphY - (double)glyphScale * 0.5)
                            scale:glyphScale
                           rotate:0.0f
                           anchor:CGPointMake(kGlyphAnchorX, glyphY)
                        transform:0x39
                            alpha:0.0f];
    }
}

/** @ghidraAddress 0x150348 */
- (BOOL)renderCleared:(unsigned int)animFrame {
    static const double kCentreX = 160.0;         // @ghidraAddress 0x28f438
    static const double kCentreXDefault = 320.0;  // @ghidraAddress 0x28f470
    static const double kWordY = 280.0;           // @ghidraAddress 0x28f658
    static const float kClearedScaleLow = 0.43f;  // @ghidraAddress 0x292b3c
    static const float kClearedScaleMid = 1.04f;  // @ghidraAddress 0x292b38
    static const float kClearedScaleHigh = 0.38f; // @ghidraAddress 0x292b40
    // The three disc-mirror angle-transform values. @ghidraAddress 0x292ac8/0x292acc/0x292ad0
    static const char kDiscTransform1 = (char)1; // 1.5707963 (pi/2) sign
    static const char kDiscTransform2 = (char)3; // 3.1415927 (pi)
    static const char kDiscTransform3 = (char)4; // 4.7123890 (3pi/2)
    static const NSUInteger kDiscSprite = 0x33;
    static const NSUInteger kWordSprite = 0x2f;

    float scale;
    unsigned int p;
    float from;
    float to;
    unsigned int start;
    unsigned int end;
    if (animFrame < 0x28) {
        if (animFrame < 6) {
            start = 0;
            end = 6;
            from = 0.0f;
            to = kClearedScaleLow;
        } else {
            start = 6;
            end = 0x28;
            from = 0.13f;
            to = kClearedScaleLow;
        }
        float base = InterpolateFloatByFrame(from, to, animFrame, start, end);
        (void)base;
        p = animFrame;
        from = kClearedScaleHigh;
        to = kClearedScaleMid;
        start = 0;
        end = 6;
    } else {
        p = (animFrame - 0x28) % 0x1e;
        if (p < 5) {
            InterpolateFloatByFrame(0.13f, g_flKeyTime040, p, 0, 5);
            from = kClearedScaleHigh;
            to = 1.0f;
            start = 0;
            end = 5;
        } else {
            InterpolateFloatByFrame(g_flKeyTime040, 0.13f, p, 6, 0x1e);
            from = 1.0f;
            to = kClearedScaleHigh;
            start = 6;
            end = 0x1e;
        }
    }
    scale = InterpolateFloatByFrame(from, to, p, start, end);

    double discY = is4Inch ? (double)(self.buttonMarginForScreen40 + 0x140) : kCentreXDefault;
    // The four-quadrant disc, mirrored about the centre.
    [self.texFront drawSprite:kDiscSprite
                      atPoint:CGPointMake(kCentreX, discY)
                        scale:scale
                       rotate:0.0f
                       anchor:CGPointMake(kCentreX, discY)
                    transform:0x33
                        alpha:0.0f];
    [self.texFront drawSprite:kDiscSprite
                      atPoint:CGPointMake(kCentreX, discY)
                        scale:scale
                       rotate:0.0f
                       anchor:CGPointMake(kCentreX, discY)
                    transform:kDiscTransform1
                        alpha:0.0f];
    [self.texFront drawSprite:kDiscSprite
                      atPoint:CGPointMake(kCentreX, discY)
                        scale:scale
                       rotate:0.0f
                       anchor:CGPointMake(kCentreX, discY)
                    transform:kDiscTransform2
                        alpha:0.0f];
    [self.texFront drawSprite:kDiscSprite
                      atPoint:CGPointMake(kCentreX, discY)
                        scale:scale
                       rotate:0.0f
                       anchor:CGPointMake(kCentreX, discY)
                    transform:kDiscTransform3
                        alpha:0.0f];

    // The "CLEARED" word plate wipes in over the first six frames.
    float wordAlpha = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 0, 6);
    float wordScale = InterpolateFloatByFrame(kComboFadeBase, 1.0f, animFrame, 0, 6);
    double wordY = is4Inch ? (double)(self.buttonMarginForScreen40 + 0x118) : kWordY;
    (void)[self.texFront spriteAtIndex:0x2f];
    [self.texFront drawSprite:kWordSprite
                      atPoint:CGPointMake(kCentreX - (double)scale * 0.5, wordY)
                        scale:wordScale
                       rotate:0.0f
                       anchor:CGPointMake(kCentreX, wordY)
                    transform:0x2f
                        alpha:wordAlpha];

    // The clear voice/jingle on frame 0, then the rating from frame 10.
    if (animFrame < 10) {
        if (animFrame == 0) {
            [AudioManager.sharedManager playSeResFile:@"SD_RPL_RESULT_CLEAR" inDirectory:nil];
            [AudioManager.sharedManager playSeResFile:@"SD_RPL_CV_CLEAR" inDirectory:nil];
        }
    } else {
        [self renderRating:animFrame - 10];
    }
    return animFrame > 0x3b;
}

/** @ghidraAddress 0x1507cc */
- (BOOL)renderFailed:(unsigned int)animFrame {
    static const double kCentreX = 160.0;            // @ghidraAddress 0x28f438
    static const double kCentreXDefault = 320.0;     // @ghidraAddress 0x28f470
    static const double kWordY = 280.0;              // @ghidraAddress 0x28f658
    static const float kFailedScaleFrom = 1.63f;     // @ghidraAddress 0x292b44
    static const float kFailedScaleTo = 2.07f;       // @ghidraAddress 0x292b48
    static const float kFailedWordScaleFrom = 0.76f; // @ghidraAddress 0x292b4c
    static const float kFailedWordDrop = 46.0f;      // @ghidraAddress 0x292b50
    static const NSUInteger kDiscSprite = 0x34;
    static const NSUInteger kWordSprite = 0x30;

    float discAlpha = InterpolateFloatByFrame(0.0f, 1.0f, animFrame, 0, 0x10);
    float discScale = InterpolateFloatByFrame(kFailedScaleFrom, kFailedScaleTo, animFrame, 0, 0x10);
    float slide;
    if (animFrame < 0x10) {
        slide = InterpolateFloatByFrame(-20.0f, 0.0f, animFrame, 0, 0x10);
    } else {
        slide = InterpolateFloatByFrame(0.0f, 10.0f, animFrame, 0x10, 0x32);
    }
    double centreY = is4Inch ? (double)(self.buttonMarginForScreen40 + 0x140) : kCentreXDefault;
    double discY = centreY + (double)slide;
    CGRect discRect = [self.texFront spriteAtIndex:0x34];
    [self.texFront drawSprite:kDiscSprite
                      atPoint:CGPointMake(kCentreX - (double)discScale * 0.5,
                                          discY - discRect.size.height * 0.5)
                        scale:discScale
                       rotate:0.0f
                       anchor:CGPointMake(kCentreX, discY)
                    transform:0x34
                        alpha:discAlpha];

    // The "FAILED" word plate scales in and drops.
    float wordScale = InterpolateFloatByFrame(kFailedWordScaleFrom, 1.0f, animFrame, 0, 0x10);
    float wordDrop = InterpolateFloatByFrame(kFailedWordDrop, 0.0f, animFrame, 0, 0x10);
    double wordY = is4Inch ? (double)(self.buttonMarginForScreen40 + 0x118) : kWordY;
    double drawWordY = wordY + (double)wordDrop;
    CGRect wordRect = [self.texFront spriteAtIndex:0x30];
    [self.texFront drawSprite:kWordSprite
                      atPoint:CGPointMake(kCentreX - (double)discScale * 0.5,
                                          drawWordY - wordRect.size.height * 0.5)
                        scale:wordScale
                       rotate:0.0f
                       anchor:CGPointMake(kCentreX, drawWordY)
                    transform:0x30
                        alpha:discAlpha];

    // The failed voice/jingle on frame 0, then the rating from frame 10.
    if (animFrame < 10) {
        if (animFrame == 0) {
            [AudioManager.sharedManager playSeResFile:@"SD_RPL_RESULT_FAILED" inDirectory:nil];
            [AudioManager.sharedManager playSeResFile:@"SD_RPL_CV_FAILED" inDirectory:nil];
        }
    } else {
        [self renderRating:animFrame - 10];
    }
    return animFrame > 0x3b;
}

/** @ghidraAddress 0x14f0e8 */
- (BOOL)renderExcellent:(unsigned int)animFrame {
    static const double kCentreX = 160.0;      // @ghidraAddress 0x28f438
    static const float kExcellentPeak = 0.1f;  // @ghidraAddress 0x28f70c
    static const float kScaleReset = 0.2f;     // @ghidraAddress 0x28f3c8
    static const float kFadeEnd = 1.29999995f; // @ghidraAddress 0x292558
    static const double kWordY = 327.0;        // @ghidraAddress 0x292f68
    static const double kChipInsetY = 120.0;   // @ghidraAddress 0x28f210
    static const double kChipInsetY2 = 40.0;   // @ghidraAddress 0x28f1f8
    static const double kFieldWidth = 320.0;   // @ghidraAddress 0x28f470
    static const double kBeamWideY = 440.0;    // @ghidraAddress 0x292f50
    static const double kFillY = 200.0;        // @ghidraAddress 0x28f400
    // The chip-ring scale keyframe table (8 floats). @ghidraAddress 0x29328c
    static const float kChipScale[] = {0.0f, 0.2f, 0.1f, 0.3f, 0.2f, 0.4f, 0.3f, 0.65f};
    static const NSUInteger kBeamSprite = 0x32;
    static const NSUInteger kChipSprite = 0x36;
    static const NSUInteger kWordSprite = 0x31;

    double centreY = is4Inch ? (double)(self.buttonMarginForScreen40 + 0x140) : kFieldWidth;

    // The main beam disc scale ramps up over the first 20 frames, holds, then blows out.
    double beamScale;
    double beamHeight = kExcellentPeak;
    if (animFrame < 0x14) {
        beamHeight = InterpolateFloatByFrame(0.0f, kExcellentPeak, animFrame, 10, 0x14);
        beamScale = (double)InterpolateFloatByFrame(g_flKeyTime080, 1.0f, animFrame, 10, 0x14);
    } else if (animFrame > 0x2e) {
        unsigned int p = animFrame - 0x2f;
        if ((int)p < 2) {
            beamHeight = InterpolateFloatByFrame(kExcellentPeak, g_flKeyTime040, p, 0, 2);
            beamScale = (double)InterpolateFloatByFrame(1.0f, g_flKeyTime080, p, 0, 2);
        } else if ((int)p < 10) {
            beamHeight = InterpolateFloatByFrame(g_flKeyTime040, g_flKeyTime060, p, 2, 10);
            beamScale = (double)InterpolateFloatByFrame(g_flKeyTime080, 1.0f, p, 2, 10);
        } else {
            beamHeight = InterpolateFloatByFrame(g_flKeyTime060, kScaleReset, p, 10, 0x28);
            beamScale = (double)InterpolateFloatByFrame(g_flKeyTime080, 1.0f, p, 2, 10);
        }
    } else {
        unsigned int p = animFrame - 0x26;
        if (animFrame < 0x26) {
            p = animFrame - 0x1d;
        }
        if (animFrame < 0x1d) {
            p = animFrame - 0x14;
        }
        if ((int)p < 3) {
            beamScale = (double)InterpolateFloatByFrame(g_flKeyTime080, 1.0f, p, 0, 3);
        } else {
            beamScale = (double)InterpolateFloatByFrame(1.0f, g_flKeyTime080, p, 3, 8);
        }
        beamHeight = kExcellentPeak;
    }

    // The four-quadrant beam disc (sprite 0x32), mirrored (transforms 0, 5, 4, 2) about the centre.
    CGRect beamRect = [self.texFront spriteAtIndex:0x32];
    double halfW = beamRect.size.width * 0.5;
    double halfH = beamRect.size.height * 0.5;
    [self.texFront drawSprite:kBeamSprite
                      atPoint:CGPointMake(kCentreX, centreY)
                        scale:(float)beamScale
                       rotate:0.0f
                       anchor:CGPointMake(kCentreX, centreY)
                    transform:0x32
                        alpha:0.0f];
    [self.texFront drawSprite:kBeamSprite
                      atPoint:CGPointMake(kCentreX - beamRect.size.width, centreY)
                        scale:(float)beamScale
                       rotate:0.0f
                       anchor:CGPointMake(kCentreX, centreY)
                    transform:0x32
                        alpha:5.0f];
    [self.texFront drawSprite:kBeamSprite
                      atPoint:CGPointMake(kCentreX, centreY - beamRect.size.height)
                        scale:(float)beamScale
                       rotate:0.0f
                       anchor:CGPointMake(kCentreX, centreY)
                    transform:0x32
                        alpha:4.0f];
    [self.texFront
        drawSprite:kBeamSprite
           atPoint:CGPointMake(kCentreX - beamRect.size.width, centreY - beamRect.size.height)
             scale:(float)beamScale
            rotate:0.0f
            anchor:CGPointMake(kCentreX, centreY)
         transform:0x32
             alpha:2.0f];
    (void)halfW;
    (void)halfH;

    // A second beam blow-out from frame 0x39.
    if (animFrame > 0x38) {
        float blowScale = InterpolateFloatByFrame(kScaleReset, 0.0f, animFrame, 0x39, 0x4d);
        float blowFade = InterpolateFloatByFrame(1.0f, kFadeEnd, animFrame, 0x39, 0x4d);
        (void)blowFade;
        [self.texFront drawSprite:kBeamSprite
                          atPoint:CGPointMake(kCentreX, centreY)
                            scale:blowScale
                           rotate:0.0f
                           anchor:CGPointMake(kCentreX, centreY)
                        transform:0x32
                            alpha:0.0f];
        [self.texFront drawSprite:kBeamSprite
                          atPoint:CGPointMake(kCentreX - beamRect.size.width, centreY)
                            scale:blowScale
                           rotate:0.0f
                           anchor:CGPointMake(kCentreX, centreY)
                        transform:0x32
                            alpha:5.0f];
        [self.texFront drawSprite:kBeamSprite
                          atPoint:CGPointMake(kCentreX, centreY - beamRect.size.height)
                            scale:blowScale
                           rotate:0.0f
                           anchor:CGPointMake(kCentreX, centreY)
                        transform:0x32
                            alpha:4.0f];
        [self.texFront
            drawSprite:kBeamSprite
               atPoint:CGPointMake(kCentreX - beamRect.size.width, centreY - beamRect.size.height)
                 scale:blowScale
                rotate:0.0f
                anchor:CGPointMake(kCentreX, centreY)
             transform:0x32
                 alpha:2.0f];
    }

    // The chip ring (sprite 0x36) sweeps into the ring positions over frames 20..46. The ring
    // positions come from the shipped {x, y} double table, four-inch offsetting the y by the button
    // margin.
    unsigned int cf = animFrame - 0x14;
    if (cf < 0x1b) {
        int count = 9;
        double firstX = kChipInsetY;
        double firstY;
        // Sub-phase selects the count and the sweep window.
        if (animFrame < 0x1d) {
            count = 9;
            firstX = kChipInsetY;
            firstY = is4Inch ? (double)(self.buttonMarginForScreen40 + 200) : 200.0;
        } else if (animFrame < 0x26) {
            count = 8;
            cf = animFrame - 0x1d;
            firstX = kFillY;
            firstY = is4Inch ? (double)(self.buttonMarginForScreen40 + 200) : 200.0;
        } else {
            count = 6;
            cf = animFrame - 0x26;
            firstX = kFillY;
            firstY = is4Inch ? (double)(self.buttonMarginForScreen40 + 0x1b8) : kBeamWideY;
        }
        float chipScale = (cf < 4) ? InterpolateFloatByFrame(0.0f, 1.0f, cf, 0, 4) :
                                     InterpolateFloatByFrame(1.0f, 0.0f, cf, 4, 8);
        float chipRing = InterpolateFloatByFrame(0.07f, 1.0f, cf, 0, 4);
        (void)[self.texFront spriteAtIndex:kChipSprite];
        double cx = firstX;
        double cy = firstY;
        for (int j = 0; j < count; ++j) {
            [self.texFront
                drawSprite:kChipSprite
                   atPoint:CGPointMake(cx - (double)chipRing * 0.5, cy - (double)chipScale * 0.5)
                     scale:chipRing
                    rotate:0.0f
                    anchor:CGPointMake(cx, cy)
                 transform:0x36
                     alpha:chipScale];
            cx += (double)kChipScale[j % 8]; // ring stride from the scale table (structural walk)
            cy += (double)kChipScale[(j + 1) % 8];
        }
    }

    // The "EXCELLENT" word plate scales/wipes in from frame 49.
    if (animFrame > 0x30) {
        unsigned int p = animFrame - 0x31;
        double wordY = is4Inch ? (double)(self.buttonMarginForScreen40 + 0x147) : kWordY;
        float wordScale;
        if ((int)p < 8) {
            wordScale = InterpolateFloatByFrame(2.0f, g_flKeyTime080, p, 0, 8);
        } else {
            wordScale = InterpolateFloatByFrame(g_flKeyTime080, 1.0f, animFrame, 8, 10);
        }
        CGRect wordRect = [self.texFront spriteAtIndex:0x31];
        [self.texFront drawSprite:kWordSprite
                          atPoint:CGPointMake(kCentreX - wordRect.size.width * 0.5,
                                              wordY - wordRect.size.height * 0.5)
                            scale:wordScale
                           rotate:0.0f
                           anchor:CGPointMake(kCentreX, wordY)
                        transform:0x31
                            alpha:0.0f];
    }

    // The per-phase voice/sound cues.
    switch (animFrame) {
    case 0x18:
    case 0x21:
    case 0x2a:
        [AudioManager.sharedManager playSeResFile:@"SD_RPL_RESULT_EXC_0" inDirectory:nil];
        break;
    case 0x39:
        [AudioManager.sharedManager playSeResFile:@"SD_RPL_RESULT_EXC" inDirectory:nil];
        [AudioManager.sharedManager playSeResFile:@"SD_RPL_CV_EXCELLENT" inDirectory:nil];
        break;
    default:
        break;
    }
    (void)beamHeight;
    (void)kChipInsetY2;
    (void)kScaleReset;
    return animFrame > 0x77;
}

/** @ghidraAddress 0x150d70 */
- (void)renderResult {
    static const double kScoreX = 142.0;                   // @ghidraAddress 0x292e88
    static const double kPartnerX = 194.0;                 // @ghidraAddress 0x291d10
    static const double kPartnerScale = 0.7;               // @ghidraAddress 0x291c98
    static const double kTuneInfoArtwork[] = {80.0, 88.0}; // @ghidraAddress 0x292770
    static const float kShutterFadeThreshold = 43.5f;      // @ghidraAddress 0x292b58
    static const float kShutterFadeRate = -43.5f;          // @ghidraAddress 0x292b54
    static const float kRecordSlideBase = 40.0f;           // @ghidraAddress 0x292568
    static const float kRecordSlideEnd = 67.0f;            // @ghidraAddress 0x292fdc
    static const float kRecordScoreDX = 142.0f;            // @ghidraAddress 0x292fe0
    static const float kRecordScoreDX2 = -46.0f;           // @ghidraAddress 0x292fe4
    static const double kMarkGlyphX = 242.0;               // @ghidraAddress 0x292f80
    static const double kVoteGlyphX = 162.0;               // @ghidraAddress 0x28fa30
    static const double kVoteGlyphXDefault = 407.0;        // @ghidraAddress 0x292f88
    static const NSUInteger kRecordBannerSprite = 0x29;
    static const NSUInteger kMarkGlyphSprite = 0x18;
    static const NSUInteger kVoteGlyphSprite = 0x17;
    // The record-banner base-X table (retina, non-retina). @ghidraAddress 0x292f78
    static const float kRecordBannerX[] = {154.0f, 142.0f};
    static const NSTimeInterval kGoodJobFadeDuration = 0.3; // @ghidraAddress 0x28f260

    const ScoreData *score = self.sequence.getScore;
    ScoreData backup;
    if (self.scoreBackup) {
        backup = self.replayBackupScore;
        score = &backup;
    }

    // The shutter closes: its open amount decays each frame while above the fade threshold.
    if (self->shutterOpen > 0.0f) {
        self->shutterOpen = (self->shutterOpen >= kShutterFadeThreshold) ?
                                (self->shutterOpen + kShutterFadeRate) :
                                0.0f;
    }
    [self renderShutter:NO];
    [self renderUpperBG:YES];

    double tuneY;
    double artworkSize;
    if (is4Inch) {
        tuneY = (double)((self.upperBgHeight40 >> 2) + 0xc);
        artworkSize = kTuneInfoArtwork[1];
    } else {
        tuneY = 12.0;
        artworkSize = kTuneInfoArtwork[0];
    }
    [self renderTuneInfo:CGPointMake(8.0, tuneY) artworkSize:artworkSize alpha:1.0];

    double barY = is4Inch ? (double)((self.upperBgHeight40 - 4) + 0x88) : (double)0x88;
    [self renderMusicBar:CGPointMake(0.0, barY) timeline:NO alpha:1.0];

    double scoreY = is4Inch ? (double)((self.upperBgHeight40 - 8) + 100) : 100.0;
    [self renderScore:(unsigned int)score->totalPoint
              atPoint:CGPointMake(kScoreX, scoreY)
                alpha:1.0];
    double partnerY = is4Inch ? (double)((self.upperBgHeight40 - 0x12) + 0x4a) : (double)0x4a;
    [self renderPartnerScore:(self.partnerFinalBonus + self.partnerScore)
                     atPoint:CGPointMake(kPartnerX, partnerY)
                       scale:kPartnerScale
                       alpha:1.0];

    // The combo counter fades out over the first ten frames.
    float comboAlpha = InterpolateFloatByFrame(1.0f, 0.0f, self->frame, 0, 10);
    [self renderCombo:(unsigned int)self.sequence.getScore->curCombo alpha:comboAlpha];
    [self renderButtons];

    // The cleared/failed/excellent graphic from frame 30, gated off during a replay backup.
    BOOL animationDone;
    if (self->frame < 0x1e || self.scoreBackup) {
        animationDone = self.scoreBackup;
    } else if (score->totalPoint == kExcellentScore) {
        animationDone = [self renderExcellent:self->frame - 0x1e];
    } else if (score->totalPoint > kRankClearThreshold - 1) {
        animationDone = [self renderCleared:self->frame - 0x1e];
    } else {
        animationDone = [self renderFailed:self->frame - 0x1e];
    }

    // The new-record banner and record score, from frame 65, scaling and bobbing in.
    if (self.isNewRecord && self->frame > 0x40 && !self.scoreBackup) {
        float bannerAlpha = InterpolateFloatByFrame(0.0f, 1.0f, self->frame, 0x41, 0x49);
        int scoreYOff = is4Inch ? (self.upperBgHeight40 - 8) : 0;
        int recordYBias = isRetina ? 0x19 : 0x17;
        double bannerY = (double)(scoreYOff + recordYBias + 100);
        float slide =
            InterpolateFloatByFrame(kRecordSlideBase, kRecordSlideEnd, self->frame, 0x41, 0x49);
        float retinaBias = isRetina ? 27.0f : 0.0f;
        float bannerBaseX = kRecordBannerX[isRetina ? 0 : 1];
        [self.texFront drawSprite:kRecordBannerSprite
                          atPoint:CGPointMake((double)(bannerBaseX + slide + retinaBias), bannerY)
                        transform:(char)(int)bannerAlpha
                            alpha:1];
        unsigned int record = self.scoreRecord;
        double digitDx = isRetina ? 26.0 : 24.0;
        double bannerYNudge = isRetina ? 0.0 : 1.0;
        double recordX =
            (double)((slide + retinaBias + kRecordScoreDX + kRecordScoreDX2) - digitDx);
        [self renderUpdatedScore:record
                         atPoint:CGPointMake(recordX, bannerY + bannerYNudge)
                           alpha:(double)bannerAlpha];
    }

    // Once the result reaches its interactive sub-state, draw the good-job / share marks and fade
    // the good-job overlay in.
    if (self.subState != 0) {
        int gameTop = is4Inch ? self.buttonMarginForScreen40 : 0;
        unsigned int elapsed = self->frame - self->subStateChangeFrame;
        float markAlpha = (elapsed < 8) ? ((float)elapsed * 0.125f) : 1.0f;
        double markY = (double)(gameTop + 0x196) + 1.0;
        [self.texFront drawSprite:kMarkGlyphSprite
                          atPoint:CGPointMake(kMarkGlyphX, markY)
                        transform:(char)(int)markAlpha
                            alpha:0];

        if (!self.replayPlaying && self.isCustom && self.isDownload && self.hasMusic) {
            if (!self.isTextureChange) {
                self.isTextureChange = YES;
                if (isRetina) {
                    self.texFront.isScale2x = NO;
                    (void)[self.texFront spriteAtIndex:0x17];
                    LoadTextureSubImageFromResource(
                        self.texFront, @"game_level_vote_rpl_pn2", CGPointMake(0.0, 0.0));
                    self.texFront.isScale2x = YES;
                } else {
                    (void)[self.texFront spriteAtIndex:0x17];
                    LoadTextureSubImageFromResource(
                        self.texFront, @"game_level_vote_rpl_pn", CGPointMake(0.0, 0.0));
                }
                if (self.goodJobImage) {
                    __weak UIImageView *goodJob = self.goodJobImage;
                    float alphaMax = self.goodJobAlphaMax;
                    [UIView animateWithDuration:kGoodJobFadeDuration
                                     animations:^{
                                       /** @ghidraAddress 0x151950 */
                                       goodJob.alpha = alphaMax;
                                     }
                                     completion:^(BOOL finished){
                                         /** @ghidraAddress 0x1519a4 */
                                     }];
                }
            }
            double voteY = is4Inch ? ((double)(gameTop + 0x196) + 1.0) : kVoteGlyphXDefault;
            [self.texFront drawSprite:kVoteGlyphSprite
                              atPoint:CGPointMake(kVoteGlyphX, voteY)
                            transform:(char)(int)markAlpha
                                alpha:0];
        }

        if (!self.isCustom && self.hasMusic && self.goodJobImage) {
            __weak UIImageView *goodJob = self.goodJobImage;
            float alphaMax = self.goodJobAlphaMax;
            [UIView animateWithDuration:kGoodJobFadeDuration
                             animations:^{
                               /** @ghidraAddress 0x1519a8 */
                               goodJob.alpha = alphaMax;
                             }
                             completion:^(BOOL finished){
                                 /** @ghidraAddress 0x1519fc */
                             }];
        }

        if (self.isSession && !self.hasMusic && self.goodJobImage) {
            __weak UIImageView *goodJob = self.goodJobImage;
            float alphaMax = self.goodJobAlphaMax;
            [UIView animateWithDuration:kGoodJobFadeDuration
                             animations:^{
                               /** @ghidraAddress 0x151a00 */
                               goodJob.alpha = alphaMax;
                             }
                             completion:^(BOOL finished){
                                 /** @ghidraAddress 0x151a54 */
                             }];
        }
    }

    // The result BGM cue on frame 0.
    if (self->frame == 0) {
        [AudioManager.sharedManager playSeResFile:@"SD_RPL_CV_RESULT" inDirectory:nil];
    }
    // Once the cleared/failed animation finishes, advance to the interactive sub-state.
    if (animationDone && self.subState == 0) {
        self.subState = 10;
        self->subStateChangeFrame = self->frame;
    }
}

@end
