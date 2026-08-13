#import "TitleViewControllerKnt.h"

#import <CoreMotion/CoreMotion.h>
#import <QuartzCore/QuartzCore.h>

#import "AlertViewManager.h"
#import "ApplilinkNetwork.h"
#import "AudioManager.h"
#import "BFCodec.h"
#import "EAGLView.h"
#import "EditorIDManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "KnitColorManager.h"
#import "LicenseAgreementView.h"
#import "MarkerDownloadView.h"
#import "RootViewController.h"
#import "SePlayer.h"
#import "Texture2D.h"
#import "TextureLoading.h"
#import "UpperBGKnit.h"
#import "cipher_keys.h"
#import "neDebugLog.h"
#import "neEngineBridge.h"

// The forever-repeat count handed to the blink animation, matching the sibling title screens; the
// float at 0x28f3c4 (ldr s0,[x8,#0x3c4] at 0x1869a0).
static const float kBlinkRepeatForever = 1e30f;

// The fast blink used by the transition-off animation repeats a fixed ten times.
static const float kNextSceneBlinkRepeatCount = 10.0f;

// The layer opacity key both blink animations animate, and the two keys they are attached under.
static NSString *const kOpacityKeyPath = @"opacity";
static NSString *const kAnimationBlinkKey = @"AnimationBlink";
static NSString *const kAnimationBlinkFastKey = @"AnimationBlinkFast";

// The blink animation's dim end (@c 0.1) and durations: 0.6 s while idle, 0.1 s during the
// transition off. From the doubles at 0x28f288 (0.6) and 0x28f290 (0.1) and the float at 0x28f70c.
static const float kBlinkDimOpacity = 0.1f;
static const CFTimeInterval kBlinkDuration = 0.6;
static const CFTimeInterval kNextSceneBlinkDuration = 0.1;

// The concierge sprite type forced when the app is in Hinabita mode.
static const int kConciergeTypeHinabita = 2;
// The concierge sprite type for a downloaded campaign image.
static const int kConciergeTypeCampaign = 3;
// The colour-type-to-concierge-type table read at 0x293490 for colour types 0..4; higher types
// fall through to type 3.
static const int kConciergeTypeFallback = 3;

// The Konami-code state machine's terminal "concierge unlocked" value.
static const int kKcStateConcierge = 10;

// The device-motion and accelerometer sampling interval, a double at 0x293450.
static const NSTimeInterval kMotionUpdateInterval = 0.13333334028720856;
// The tilt-change threshold (pi/8) that gates a wave pulse and a rise, a double at 0x293460.
static const double kMotionThreshold = 0.39269908169872414;
// The tilt easing factor applied to degOld each frame, a float 0x3e800000.
static const float kTiltEase = 0.25f;
// The reference-frame constant handed to -startDeviceMotionUpdatesUsingReferenceFrame: (2 ==
// CMAttitudeReferenceFrameXArbitraryCorrectedZVertical).
static const CMAttitudeReferenceFrame kMotionReferenceFrame =
    CMAttitudeReferenceFrameXArbitraryCorrectedZVertical;

// The status-bar orientation value (UIInterfaceOrientationPortraitUpsideDown) that clears the
// isPortrait flag; every other value sets it.
static const NSInteger kStatusBarUpsideDown = 2;

// The bell sound-effect resource lazily played when the concierge is tapped.
static NSString *const kBellResourceName = @"SD_KNT_BELL01";
static NSString *const kBellResourceType = @"caf";

// The concierge-swap easter-egg sound effect.
static NSString *const kConciergeSwapSE = @"SD_GRA";

// The licence sheet's NSUserDefaults key, a CFString at 0x2d60a0.
static NSString *const kChallengePolicyVersionKey = @"PrefAgreeChallengePolicyVersion";

// The default network-error alert body key and the empty-title/OK keys.
static NSString *const kNetworkErrorMsgKey = @"NetworkErrorMsg";
static NSString *const kOKKey = @"OK";

// The licence handshake's failure alert always shows this fixed body, the UTF-16 CFString at
// 0x2dd500 (48 characters); both the reporting manager and its message are discarded.
static NSString *const kAgreementErrorMsg = @"サーバに接続できません。\n"
                                            @"ネットワーク接続をご確認下さい。\n"
                                            @"初期起動時のみ通信が必須となります。";

// The wave-atlas sprite-rect plist basenames and the concierge atlas resource.
static NSString *const kWaveTexPad = @"game_wave_knt_pd2_0_tex";
static NSString *const kWaveTexPhone = @"game_wave_knt_0_tex";
static NSString *const kConciergeTexResource = @"game_concierge_knt_0_tex";
static NSString *const kPlistType = @"plist";
static NSString *const kPngType = @"png";

// The campaign and hinabita concierge overlay images blitted onto the concierge atlas.
static NSString *const kCampaignImageName = @"cpImg01";
static NSString *const kHinaTitleImageName = @"hina_title_img";

// The BGM and welcome voice played on -start.
static NSString *const kTitleBgmName = @"SD_KNT_BGM_TITLE";
static NSString *const kWelcomeSEName = @"SD_KNT_CV_WELCOME";
// The confirm sound played when transitioning off the title.
static NSString *const kConfirmSEName = @"SD_KNT_OK";

// The jubeat logo artwork per concierge type: the hinabita logo for the hinabita concierge, the
// standard knit logo otherwise. The touch prompt and copyright artwork.
static NSString *const kLogoHinabitaName = @"titlelogo_hinabita01";
static NSString *const kLogoStandardName = @"j_logo_knt";
static NSString *const kTouchPromptName = @"touch_knt";
static NSString *const kCopyrightName = @"copyright_knt";

// Layout doubles read from __const, verified from the disassembly. Both ratios are float literals
// widened to double in the pool -- 0x293458 holds 0x3FD3D70A40000000 and 0x28f230 holds
// 0x3FE3333340000000 -- so they are spelled with the f suffix to reproduce those bits.
static const CGFloat kLogoCenterYRatio = 0.31f;   // 0x293458: logo centre y = height * 0.31f.
static const CGFloat kTouchCenterYRatio = 0.6f;   // 0x28f230: touch prompt centre y.
static const CGFloat kCopyrightInsetPad = 120.0;  // 0x28f210: copyright inset from bottom, pad.
static const CGFloat kCopyrightInsetPhone = 40.0; // 0x28f1f8: copyright inset from bottom, phone.

// The GL 2D-space extent per idiom: a 768x1024 CGSize on a pad (size.width 768 from 0x292460,
// size.height 1024 from 0x28e028), the view's own frame size on a phone.
static const CGFloat kGL2DSpaceWidthPad = 768.0;
static const CGFloat kGL2DSpaceHeightPad = 1024.0;

// The knit-wave setup: a 768x1024 canvas on the pad idiom only, and -- shared by both idioms -- a
// wave baseline of the GL view's frame height times 0.48 (0x2933d0) and a 60-point wave top
// (0x28f8a0). The pad pulses 30 points, the phone 20.
static const CGFloat kPadWaveCanvasWidth = 768.0;
static const CGFloat kPadWaveCanvasHeight = 1024.0;
static const float kWaveBottomRatio = 0.47999998927116394f; // 0x2933d0.
static const float kWaveTop = 60.0f;                        // 0x28f8a0.
static const float kPadPulseHeight = 30.0f;                 // fmov 0x41f00000.
static const float kPhonePulseHeight = 20.0f;               // fmov 0x41a00000.

// The number of Texture2D wave layers built in -loadView.
static const int kWaveLayerCount = 6;
// Each wave texture is a 32-texel square, RGBA8888 format (mov w3,#0x1 at 0x185aec).
static const GLuint kWaveTexturePixelSize = 32;

// The concierge sizes, from the doubles at 0x293470 (widths: 109 phone-half? / 218) and 0x293480
// (heights: 78 / 155). Indexed by isPad.
static const CGFloat kConciergeWidthPhone = 109.0; // 0x293470[0].
static const CGFloat kConciergeWidthPad = 218.0;   // 0x293470[1].
static const CGFloat kConciergeHeightPhone = 78.0; // 0x293480[0].
static const CGFloat kConciergeHeightPad = 155.0;  // 0x293480[1].

// The concierge's per-idiom vertical offset above the copyright view, and its hit-rect inset.
static const int kConciergeOffsetPad = 0x9b;   // 155.
static const int kConciergeOffsetPhone = 0x4e; // 78.
static const int kConciergeHitInset = 10;

// renderConcierge sprite/frame constants.
static const int kTapReadoutMinTaps = 10;       // The tap readout appears once tapMax reaches 10.
static const int kConciergeDigitBaseSprite = 2; // Digit sprites start at index 2.
static const int kConciergeMoveCycle = 0x5a;    // 90-frame wander cycle.
static const int kConciergeMoveInterp = 8;      // The wander interpolation window.
static const float kConciergeShakePeriod = 360.0f; // 0x292418: shake sine period.
static const float kConciergeShakeDegrees = 15.0f; // Degrees per shake frame.
static const CGFloat kSinePeriodScale = 2.0;       // The sine argument is doubled.

// The concierge animation-frame ranges, from renderConcierge's frame maths.
static const int kConMoveWrapFrame = 0x59;   // Frame count wrap (89) for the campaign type.
static const int kConIdleSprite = 0x1c;      // The idle animation sprite value.
static const int kConStopFrameLength = 0x3c; // 60-frame stop pose.
static const int kConStopMaxFrame = 0x2c;    // 44 clamps the frame counter.
static const int kConShakeUpStep = 3;        // conShakeFrame increment while shaking up.

// The concierge tap-triggered wave-ripple shake-up length.
static const int kTapShakeUpFrames = 8;

// The maximum recorded tap count.
static const int kMaxTapCount = 0xff;

// The overlay backdrop's half-transparent black alpha, from fmov d1,0x3fe0000000000000 at
// 0x1874d4.
static const CGFloat kOverlayBackdropAlpha = 0.5;

// The logo/copyright fade-in duration, from fmov d0,0x3fe0000000000000 at 0x186f24. This is an
// 8-bit fmov immediate, not a __const pool load, so there is no pool address to record. It shares
// its value with the backdrop alpha above but is a wholly unrelated quantity.
static const NSTimeInterval kShowLogoFadeDuration = 0.5;

// The concierge slide-down animation duration, a double at 0x28f260 (0.3).
static const NSTimeInterval kConciergeSlideDuration = 0.3;

// The hidden-state's decoded arm values used by handleTap / handleSwipe.
static const int kHnStateConcierge = 9;
static const int kHnStateArmed = 8;

// The KNT title logo's two Konami-code hit regions, per idiom. Recovered from the __const doubles
// at 0x292ee0/0x292f10 (x, width, height, each striding 8 bytes for the pad/phone split) and the y
// selected by fcsel between 35 (0x28f6c8, pad) and 14 (fmov 0x402c000000000000, phone). The tapped
// point is shifted by (-5, -5) before the test (fadd d,-0x3fec000000000000). Left region: pad
// {189, 35, 88, 89}, phone {87, 14, 44, 44}. Right region: pad {401, 35, 89, 89}, phone {188, 14,
// 44, 44}.
static const CGFloat kKonamiHitShift = -5.0;
static const CGRect kKonamiLeftRectPad = {{189.0, 35.0}, {88.0, 89.0}};
static const CGRect kKonamiLeftRectPhone = {{87.0, 14.0}, {44.0, 44.0}};
static const CGRect kKonamiRightRectPad = {{401.0, 35.0}, {89.0, 89.0}};
static const CGRect kKonamiRightRectPhone = {{188.0, 14.0}, {44.0, 44.0}};

@interface TitleViewControllerKnt () {
@public
    // The runtime keeps every ivar under its bare metadata name; the header declares none, so pin
    // them here in binary order (offset globals 0x34b520..0x34b5b4).
    BOOL isPad;                            // +0x34b520.
    NSUInteger deviceType;                 // +0x34b524, encoded Q.
    BOOL is4Inch;                          // +0x34b528.
    int tapCnt;                            // +0x34b52c.
    int tapMax;                            // +0x34b530.
    EAGLView *glView;                      // +0x34b534.
    BOOL isWave;                           // +0x34b538.
    UpperBGKnit *upperBgKnt;               // +0x34b53c.
    BOOL isPortrait;                       // +0x34b540.
    CMMotionManager *motionManager;        // +0x34b544.
    float degOld;                          // +0x34b548.
    SePlayer *sePlayer;                    // +0x34b54c.
    int conType;                           // +0x34b550.
    UIImageView *jubeatLogoView;           // +0x34b554.
    UIImageView *touchView;                // +0x34b558.
    int tapDelayY;                         // +0x34b55c.
    UIImageView *copyrightView;            // +0x34b560.
    NSMutableArray *texWaveAr;             // +0x34b564.
    Texture2D *conTex;                     // +0x34b568.
    CGSize conciergeSize;                  // +0x34b56c.
    UIImage *replaceImage;                 // +0x34b570.
    MarkerDownloadView *markerView;        // +0x34b574.
    CADisplayLink *displayLink;            // +0x34b578.
    float accelaOld;                       // +0x34b57c.
    float degBak;                          // +0x34b580.
    int kcState;                           // +0x34b584.
    int hnState;                           // +0x34b588.
    NSArray *arraySwipeRecognizer;         // +0x34b58c.
    UITapGestureRecognizer *tapRecognizer; // +0x34b590.
    CGPoint conciergePos;                  // +0x34b594.
    int conShakeUpFrame;                   // +0x34b598.
    LicenseAgreementView *licenseAgree;    // +0x34b59c.
    UIView *coverView;                     // +0x34b5a0.
    EditorIDManager *idManager;            // +0x34b5a4.
    int conMoveFrame;                      // +0x34b5a8.
    CGPoint oldConPos;                     // +0x34b5ac.
    int conShakeFrame;                     // +0x34b5b0.
    int conStopFrame;                      // +0x34b5b4.
}
@end

// The base class exposes explainBtn, coBtn, and bEnableTap as protected ivars (declared in
// TitleViewController.h), so this subclass reaches them directly.

// De-inlined helper: strip every swipe recogniser off the view. Inlined identically into
// -becomeConcierge and -nextScene in the binary.
static inline void RemoveSwipeRecognizersFromTitleKnt(TitleViewControllerKnt *self,
                                                      NSArray *arraySwipeRecognizer) {
    for (UISwipeGestureRecognizer *recognizer in arraySwipeRecognizer) {
        [self.view removeGestureRecognizer:recognizer];
    }
}

// De-inlined helper: blit a fixed bundle overlay (the cpImg01 or hina_title_img) onto the concierge
// atlas at one sprite's origin, and record the concierge draw size from the overlay. Verified from
// the disassembly at 0x186040 (type 1) and 0x186184 (type 2): the overlay is drawn at the sprite's
// origin at its own pixel size, then the concierge size is the overlay size halved on a phone.
static inline void BlitConciergeOverlayOntoTex(TitleViewControllerKnt *self,
                                               Texture2D *conTex,
                                               UIImage *image,
                                               NSUInteger spriteIndex,
                                               BOOL isPad) {
    CGRect sprite = [conTex spriteAtIndex:(unsigned int)spriteIndex];
    CGSize imageSize = image.size;
    [conTex setSubImage:image
                 inRect:CGRectMake(
                            sprite.origin.x, sprite.origin.y, imageSize.width, imageSize.height)];
    CGFloat scale = isPad ? 1.0 : 2.0;
    self->conciergeSize = CGSizeMake(imageSize.width / scale, imageSize.height / scale);
}

// De-inlined helper: centre the downloaded campaign image inside the concierge atlas' first sprite
// and blit it. Recovered from the disassembly at 0x185e08–0x185f24 (the decompile's dVar aliasing
// is unreliable here): the concierge draw size is the sprite size halved on a phone, then the image
// is centred within the sprite, clamped to a non-negative origin.
static inline void BlitCampaignImageOntoTex(TitleViewControllerKnt *self,
                                            Texture2D *conTex,
                                            UIImage *image,
                                            BOOL isPad) {
    CGRect sprite = [conTex spriteAtIndex:0];
    CGFloat scale = isPad ? 1.0 : 2.0;
    self->conciergeSize = CGSizeMake(sprite.size.width / scale, sprite.size.height / scale);
    CGSize imageSize = image.size;
    CGFloat innerY = 0.0;
    CGFloat spriteHeight = sprite.size.height;
    if (sprite.size.height < imageSize.height) {
        innerY = (CGFloat)(int)(sprite.size.height - imageSize.height);
        spriteHeight = imageSize.height;
    }
    CGFloat x = sprite.origin.x + (sprite.size.width - imageSize.width) * 0.5;
    CGFloat y = innerY + sprite.origin.y + (spriteHeight - imageSize.height) * 0.5;
    if (x < 0.0) {
        x = 0.0;
    }
    if (y < 0.0) {
        y = 0.0;
    }
    [conTex setSubImage:image inRect:CGRectMake(x, y, imageSize.width, imageSize.height)];
}

@implementation TitleViewControllerKnt

#pragma mark - View lifecycle

/** @ghidraAddress 0x1853c4 */
- (void)loadView {
    [super loadView];
    conType = [self getConciergeType];

    self.view.userInteractionEnabled = YES;
    self.view.multipleTouchEnabled = NO;
    self.view.opaque = YES;
    self.view.backgroundColor = UIColor.whiteColor;
    [self.view addSubview:glView];

    JubeatAppDelegate *appDelegate = JubeatAppDelegate.appDelegate;
    CGRect frame = self.view.frame;
    CGFloat width = frame.size.width;
    CGFloat height = frame.size.height;

    // The jubeat logo: the hinabita artwork for the hinabita concierge, the standard knit logo
    // otherwise. Centred at (width/2, height * 0.31).
    NSString *logoName =
        (conType == kConciergeTypeHinabita) ? kLogoHinabitaName : kLogoStandardName;
    jubeatLogoView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(logoName)];
    jubeatLogoView.center = CGPointMake(width * 0.5, height * kLogoCenterYRatio);
    [self.view addSubview:jubeatLogoView];

    // The touch prompt, centred at (width/2, height * 0.6). For the hinabita concierge the prompt
    // is slid down by tapDelayY once the concierge appears; tapDelayY is the gap between the
    // standard centre and the stack of logo + prompt (+ a second prompt height on a 4-inch phone).
    touchView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kTouchPromptName)];
    // The binary narrows the product to single precision (fcvt s11,d0 at 0x185714) and widens it
    // back only to hand it to -setCenter: (fcvt d1,s11 at 0x1857ec), so the y the prompt is
    // centred on is float-rounded.
    float touchCenterY = (float)(height * kTouchCenterYRatio);
    if (conType == kConciergeTypeHinabita) {
        CGRect logoFrame = jubeatLogoView.frame;
        CGRect touchFrame = touchView.frame;
        int stacked = (int)(logoFrame.origin.y + logoFrame.size.height + touchFrame.size.height);
        if (!isPad && appDelegate.is4inchAspect) {
            stacked = (int)((CGFloat)stacked + touchView.frame.size.height);
        }
        tapDelayY = (int)((float)stacked - touchCenterY);
    }
    touchView.center = CGPointMake(width * 0.5, touchCenterY);
    [self.view addSubview:touchView];

    // The copyright notice, centred at (width/2, height - inset), inset 120 on a pad and 40 on a
    // phone.
    copyrightView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kCopyrightName)];
    CGFloat copyrightInset = appDelegate.isPad ? kCopyrightInsetPad : kCopyrightInsetPhone;
    copyrightView.center = CGPointMake(width * 0.5, height - copyrightInset);
    [self.view addSubview:copyrightView];

    [glView createFramebuffer];
    // The GL drawing space: a fixed 768x1024 on a pad, the view's own frame size on a phone.
    CGRect glFrame = self.view.frame;
    CGSize glSpace = isPad ? CGSizeMake(kGL2DSpaceWidthPad, kGL2DSpaceHeightPad) :
                             CGSizeMake(glFrame.size.width, glFrame.size.height);
    [glView set2dSpace:glSpace];
    [glView startRenderContext];

    // Build the six knit-wave layers from the encrypted atlas plus its sprite-rect plist.
    NSData *textureKey = CreateTextureCipherKey();
    BFCodec *codec = [[BFCodec alloc] init];
    texWaveAr = [[NSMutableArray alloc] init];
    NSString *wavePlistPath =
        appDelegate.isPadRetina ?
            [NSBundle.mainBundle pathForResource:kWaveTexPad ofType:kPlistType] :
            [NSBundle.mainBundle pathForResource:kWaveTexPhone ofType:kPlistType];
    NSArray *waveSprites = [[NSArray alloc] initWithContentsOfFile:wavePlistPath];
    for (int i = 0; i < kWaveLayerCount; ++i) {
        Texture2D *tex = [[Texture2D alloc] initWithData:nullptr
                                             pixelFormat:Texture2DPixelFormatRGBA8888
                                               pixelSize:kWaveTexturePixelSize];
        [tex setSprites:waveSprites];
        [texWaveAr addObject:tex];
        if (appDelegate.isPadRetina) {
            tex.isScale2x = YES;
        }
    }
    [codec cipherInit:textureKey];
    for (int i = 0; i < kWaveLayerCount; ++i) {
        BOOL padRetina = appDelegate.isPadRetina;
        Texture2D *tex = texWaveAr[i];
        NSString *resourceName = padRetina ? kWaveTexPad : kWaveTexPhone;
        // The 16/32 texel size the caller computes here is passed in d2/d3 but the loader ignores
        // it; the blit origin is (0, 0).
        LoadTextureSubImageFromEncryptedTex(tex, resourceName, codec, CGPointZero);
    }

    if (!conTex) {
        // The concierge draw size defaults to the per-idiom table; a downloaded or bundled overlay
        // below may replace it.
        conciergeSize = CGSizeMake(isPad ? kConciergeWidthPad : kConciergeWidthPhone,
                                   isPad ? kConciergeHeightPad : kConciergeHeightPhone);
        replaceImage = nil;
        [codec cipherInit:textureKey];
        conTex = CreateTexture2DFromEncryptedTexResource(kConciergeTexResource, codec);
        if (conType == kConciergeTypeCampaign) {
            NSString *campaignPath = appDelegate.campaignImagePath;
            if (![NSFileManager.defaultManager fileExistsAtPath:campaignPath]) {
                conType = 0;
            } else {
                NSMutableData *imageData =
                    [[NSData dataWithContentsOfFile:campaignPath] mutableCopy];
                BFCodec *imageCodec = [[BFCodec alloc] init];
                [imageCodec cipherInit:CreateResourceDataCipherKey()];
                if (![imageCodec decipher:imageData]) {
                    [NSFileManager.defaultManager removeItemAtPath:campaignPath error:nil];
                    conType = 0;
                } else {
                    replaceImage = [[UIImage alloc] initWithData:imageData];
                    BlitCampaignImageOntoTex(self, conTex, replaceImage, isPad);
                }
            }
        } else if (conType == 1) {
            NSString *path = [NSBundle.mainBundle pathForResource:kCampaignImageName
                                                           ofType:kPngType];
            if (path) {
                replaceImage = [[UIImage alloc] initWithContentsOfFile:path];
                BlitConciergeOverlayOntoTex(self, conTex, replaceImage, 0, isPad);
            } else {
                conType = 0;
            }
        } else if (conType == kConciergeTypeHinabita) {
            NSString *path = [NSBundle.mainBundle pathForResource:kHinaTitleImageName
                                                           ofType:kPngType];
            if (path) {
                replaceImage = [[UIImage alloc] initWithContentsOfFile:path];
                BlitConciergeOverlayOntoTex(self, conTex, replaceImage, 1, isPad);
            } else {
                conType = 0;
            }
        }
    }

    // Re-parent the base class's explain and corporate buttons above the GL layers, then build the
    // marker-download modal.
    [self.view addSubview:explainBtn];
    [self.view addSubview:coBtn];
    markerView = [[MarkerDownloadView alloc] init];
    [self.view addSubview:markerView];
}

#pragma mark - Concierge rendering

/**
 * @ghidraAddress 0x187a70
 * Worked from the disassembly throughout: every position is a soft-float shuffle the decompiler
 * garbles, and the frame maths threads several counters at once.
 */
- (void)renderConcierge {
    int glWidth = (int)glView.frame.size.width;

    // The tap-count readout: once the best tap streak reaches ten, print it as decimal digits from
    // the least significant, marching leftwards from the right edge. Sprites 2..11 are the digits.
    if (tapMax >= kTapReadoutMinTaps) {
        int value = tapMax > kMaxTapCount ? kMaxTapCount : tapMax;
        int digitX = glWidth - 25;
        do {
            [conTex drawSprite:(NSUInteger)(value % 10 + kConciergeDigitBaseSprite)
                       atPoint:CGPointMake((CGFloat)digitX, 25.0)];
            digitX -= 12;
            int previous = value;
            value /= 10;
            if (previous <= 9) {
                break;
            }
        } while (YES);
    }

    // The concierge wanders on a 90-frame cycle. Frame 0 picks a fresh target; frames 1..7 ease
    // from the old position to the current one; later frames sit at the current position.
    unsigned int cyclePos = (unsigned int)(conMoveFrame % kConciergeMoveCycle);
    double posX = conciergePos.x;
    double posY = conciergePos.y;
    if (cyclePos == 0) {
        double oldX = conciergePos.x;
        double oldY = conciergePos.y;

        // Pick a new x within the play area: rand mod (glWidth - concierge width - 50) + 25.
        u_int32_t r = arc4random();
        int xSpan =
            (glWidth + (isPad ? -(int)kConciergeWidthPad : -(int)kConciergeWidthPhone)) - 50;
        int newX = (int)((xSpan != 0 ? r % (unsigned int)xSpan : 0) + 25);
        // Damp an over-large horizontal jump to half its distance.
        double deltaX = (double)newX - oldX;
        if ((double)(glWidth >> 1) < fabs(deltaX)) {
            newX = (int)((double)newX + deltaX * -0.5);
        }

        // Pick a new y relative to the copyright view's top, using twice the concierge height as
        // the margin.
        r = arc4random();
        int copyrightTop = (int)copyrightView.frame.origin.y;
        int ySpan = (copyrightTop + (isPad ? -310 : -156)) - 50;
        int newY = (int)((ySpan != 0 ? r % (unsigned int)ySpan : 0) + 25);
        // Damp an over-large vertical jump likewise, against half the copyright-relative span.
        double deltaY = (double)newY - oldY;
        int yLimit = ((int)copyrightView.frame.origin.y -
                      (isPad ? kConciergeOffsetPad : kConciergeOffsetPhone)) >>
                     1;
        if (fabs(deltaY) > (double)yLimit) {
            newY = (int)((double)newY + deltaY * -0.5);
        }

        // The previous position becomes the interpolation start.
        oldConPos = CGPointMake(oldX, oldY);
        conciergePos = CGPointMake((double)newX, (double)newY);
        tapCnt = 0;
        posX = conciergePos.x;
        posY = conciergePos.y;
    }

    double drawX = posX;
    double drawY = posY;
    if (cyclePos <= 7) {
        drawX = (double)InterpolateFloatByFrame(
            (float)oldConPos.x, (float)posX, cyclePos, 0, kConciergeMoveInterp);
        drawY = (double)InterpolateFloatByFrame(
            (float)oldConPos.y, (float)posY, cyclePos, 0, kConciergeMoveInterp);
    }

    // The vertical shake bob: a doubled sine of the shake frame, scaled by the base amplitude (16
    // with a replacement image, otherwise 30), then halved on a phone.
    float baseAmplitude = replaceImage ? 16.0f : 30.0f;
    float bobAmplitude = isPad ? baseAmplitude : (baseAmplitude * 0.5f);
    float drawScale = isPad ? 1.0f : 0.5f;
    double shakePhase =
        (double)((conShakeFrame * kConciergeShakeDegrees) / kConciergeShakePeriod) * M_PI;
    double bob = sin(shakePhase * kSinePeriodScale);

    // The animation sprite for the idle wander, keyed off the full move frame.
    int moveFrame = conMoveFrame;
    BOOL idleHold;
    unsigned int sprite;
    if (moveFrame < 26) {
        if (moveFrame < 19) {
            sprite = (unsigned int)((moveFrame * 2) % 23 + 12);
        } else {
            sprite = (unsigned int)(moveFrame + 7);
        }
        idleHold = (sprite == kConIdleSprite) && (moveFrame > 19);
    } else {
        idleHold = NO;
        sprite = (unsigned int)(moveFrame % 23 + 12);
    }
    // A non-idle concierge (a campaign or hinabita overlay) always shows sprite 1 (hinabita) or 0.
    if (conType != 0) {
        sprite = (conType == kConciergeTypeHinabita) ? 1 : 0;
    }
    if (moveFrame == 25) {
        moveFrame = kConStopMaxFrame;
        conMoveFrame = kConStopMaxFrame;
    }

    // Occasionally trigger a 60-frame stop pose while idle.
    if ((int)sprite == kConIdleSprite && conStopFrame == 0 && moveFrame > kTapReadoutMinTaps &&
        cyclePos != 0 && cyclePos != (unsigned int)kConMoveWrapFrame &&
        (idleHold || arc4random() % 30 == 0)) {
        conStopFrame = kConStopFrameLength;
    }

    // The stop pose nods the concierge: a decaying, alternating vertical offset over its 20 frames.
    double stopOffset = 0.0;
    unsigned int stopFrame = (unsigned int)conStopFrame;
    if (stopFrame - 1 < 19) {
        stopOffset = (double)(drawScale * (float)(int)(20 - stopFrame) * 0.25f *
                              (float)(int)((stopFrame & 1) * 2 - 1));
    }
    double finalX = drawX + stopOffset;
    double finalY = drawY + (double)(float)(bob * (double)bobAmplitude);
    [conTex drawSprite:(NSUInteger)sprite
               atPoint:CGPointMake(finalX, finalY)
                 scale:drawScale
                rotate:0.0f
                anchor:CGPointMake(finalX, finalY)
             transform:0
                 alpha:1.0f];

    // Advance the counters: while the stop pose is running, wind it down; otherwise step the wander
    // frame (clamped at 89 for an overlay concierge) and drain any pending tap shake-up.
    if (conStopFrame < 1) {
        int frame = conMoveFrame;
        int next = frame + 1;
        if (conType != 0 && frame >= kConMoveWrapFrame) {
            next = kConMoveWrapFrame;
        }
        conMoveFrame = next;
        if (conShakeUpFrame > 0) {
            conShakeFrame += kConShakeUpStep;
            --conShakeUpFrame;
        }
    } else {
        --conStopFrame;
        conShakeUpFrame = 0;
        if (conStopFrame == 0) {
            ++conMoveFrame;
        }
    }
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x184f48 */
- (instancetype)init {
    self = [super init];
    if (!self) {
        return self;
    }
    JubeatAppDelegate *appDelegate = JubeatAppDelegate.appDelegate;
    isPad = appDelegate.isPad;
    deviceType = appDelegate.deviceType;
    is4Inch = appDelegate.is4inchAspect;
    tapCnt = 0;
    tapMax = 0;

    glView = [[EAGLView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    glView.opaque = YES;
    glView.multipleTouchEnabled = YES;
    if (appDelegate.isPhoneRetina) {
        glView.contentScaleFactor = 2.0;
    }

    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self
               selector:@selector(suspend:)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(resume:)
                   name:UIApplicationWillEnterForegroundNotification
                 object:nil];

    isWave = NO;
    upperBgKnt = [[UpperBGKnit alloc] init];
    // The knit wave differs per idiom only in its canvas and its pulse height: a fixed 768x1024
    // canvas and a 30-point pulse on a pad, the controller's own view frame and a 20-point pulse on
    // a phone. Both take a 60-point wave top and the same baseline, the GL view's frame height
    // times 0.48, which the binary computes above the idiom branch (fmul at 0x1851b0, narrowed into
    // the callee-saved v8) and hands to each arm.
    float waveBottom = (float)(glView.frame.size.height * kWaveBottomRatio);
    if (isPad) {
        [upperBgKnt initBg:CGRectMake(0, 0, kPadWaveCanvasWidth, kPadWaveCanvasHeight)
                waveBottom:waveBottom
                   waveTop:kWaveTop
               pulseHeight:kPadPulseHeight
                     isPad:YES];
    } else {
        // Yes, the phone arm takes its rectangle from the controller's own view rather than from
        // glView (0x185208 sends -view to self, 0x185224 sends -frame to the result), so touching
        // self.view here forces -loadView to run inside -init.
        [upperBgKnt initBg:self.view.frame
                waveBottom:waveBottom
                   waveTop:kWaveTop
               pulseHeight:kPhonePulseHeight
                     isPad:NO];
    }

    isPortrait = YES;
    motionManager = [[CMMotionManager alloc] init];
    if (motionManager.isDeviceMotionAvailable) {
        degOld = 0.0f;
        motionManager.deviceMotionUpdateInterval = kMotionUpdateInterval;
        [motionManager startDeviceMotionUpdates];
        [motionManager startDeviceMotionUpdatesUsingReferenceFrame:kMotionReferenceFrame];
        isPortrait = UIApplication.sharedApplication.statusBarOrientation != kStatusBarUpsideDown;
    }
    if (motionManager.isAccelerometerAvailable) {
        motionManager.accelerometerUpdateInterval = kMotionUpdateInterval;
        [motionManager startAccelerometerUpdates];
    }
    sePlayer = nil;
    return self;
}

/** @ghidraAddress 0x188158 */
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    if (texWaveAr) {
        [texWaveAr removeAllObjects];
    }
    // The binary re-arms device motion here rather than stopping it; kept faithfully.
    if (motionManager.isDeviceMotionAvailable) {
        [motionManager startDeviceMotionUpdatesUsingReferenceFrame:kMotionReferenceFrame];
    }
    if (sePlayer) {
        [sePlayer terminate];
        sePlayer = nil;
    }
}

/** @ghidraAddress 0x18798c */
- (void)viewDidUnload {
    [super viewDidUnload];
    arraySwipeRecognizer = nil;
    tapRecognizer = nil;
    jubeatLogoView = nil;
    touchView = nil;
    copyrightView = nil;
    if (texWaveAr) {
        [texWaveAr removeAllObjects];
        texWaveAr = nil;
    }
    conTex = nil;
}

#pragma mark - Title lifecycle

/** @ghidraAddress 0x18637c */
- (void)start {
    [super start];
    jubeatLogoView.alpha = 0.0;
    touchView.alpha = 0.0;
    copyrightView.alpha = 0.0;
    [AudioManager.sharedManager loadBgmResAAC:kTitleBgmName inDirectory:nil];
    [AudioManager.sharedManager startBgm:YES fadeTime:0.0];
    [AudioManager.sharedManager playSeResFile:kWelcomeSEName inDirectory:nil];
    if (!displayLink) {
        displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(loop:)];
        displayLink.frameInterval = 2;
        [displayLink addToRunLoop:NSRunLoop.currentRunLoop forMode:NSRunLoopCommonModes];
    }
}

/** @ghidraAddress 0x186e80 */
- (void)showLogo {
    __weak TitleViewControllerKnt *weakSelf = self;
    // The binary passes options 0x30000 (orr w2,wzr,#0x30000 at 0x186f2c), which is 3 << 16, the
    // linear curve, with no other option bits set.
    [UIView animateWithDuration:kShowLogoFadeDuration
        delay:0.0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x186f8c */
          // Reaches both views through the strongly-captured self.
          self->jubeatLogoView.alpha = 1.0;
          self->copyrightView.alpha = 1.0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x187000 */
          [weakSelf startMarkerCheck];
        }];
}

/**
 * @ghidraAddress 0x186570
 * The accelerometer/device-motion feeding is worked from the disassembly: the deltas arrive in
 * d0/d1 out of the soft-float shuffle the decompiler renders as pseudo-doubles.
 */
- (void)loop:(CADisplayLink *)sender {
    [glView prepareToRender];
    if (motionManager.isAccelerometerAvailable) {
        CMAcceleration acceleration = motionManager.accelerometerData.acceleration;
        float tilt;
        if (motionManager.isDeviceMotionAvailable) {
            // Feed the frame-to-frame x-acceleration change as a wave pulse when it crosses the
            // threshold, then adopt the current gravity's x as the tilt. Worked from the
            // disassembly: every component read here is acceleration.x (d0).
            double delta = acceleration.x - (double)accelaOld;
            if (kMotionThreshold < fabs(delta)) {
                [upperBgKnt plugWave:(float)fabs(acceleration.x)];
                accelaOld = (float)acceleration.x;
            }
            tilt = (float)motionManager.deviceMotion.gravity.x;
        } else {
            tilt = (float)acceleration.x;
            if (1.0f < tilt) {
                tilt = 1.0f;
            }
            if (tilt < -1.0f) {
                tilt = -1.0f;
            }
        }
        float deg = isPortrait ? tilt : -tilt;
        float previous = degBak;
        degBak = deg;
        [upperBgKnt plugWave:fabsf(deg - previous)];
        if (kMotionThreshold < (double)fabsf(deg - degOld)) {
            if (0.0f < deg) {
                [upperBgKnt riseUp:0 riseColumn:0];
            }
            if (deg < 0.0f) {
                [upperBgKnt riseUp:3 riseColumn:3];
            }
        }
        degOld += (deg - degOld) * kTiltEase;
        [upperBgKnt setDeg:degOld];
    }
    [upperBgKnt renderUpperBg:texWaveAr tension:0 isResult:NO];
    if (kcState == kKcStateConcierge) {
        [self renderConcierge];
    }
    [upperBgKnt commitBg:texWaveAr];
    [conTex commitDraw];
    [glView swapBuffer];
}

/** @ghidraAddress 0x1868ac */
- (void)blinkPrompt {
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:kOpacityKeyPath];
    anim.duration = kBlinkDuration;
    anim.fromValue = @(kBlinkDimOpacity);
    anim.toValue = @(1.0f);
    anim.autoreverses = YES;
    anim.repeatCount = kBlinkRepeatForever;
    anim.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.removedOnCompletion = NO;
    [touchView.layer addAnimation:anim forKey:kAnimationBlinkKey];
}

/** @ghidraAddress 0x186a64 */
- (void)startMarkerCheck {
    [markerView setDelegate:self];
    markerView.parentView = self.view;
    [markerView show];
}

/** @ghidraAddress 0x186aec */
- (void)startBlinkPrompt {
    [self blinkPrompt];
    kcState = 0;
    hnState = 0;

    UISwipeGestureRecognizer *swipeUp =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    [self.view addGestureRecognizer:swipeUp];
    UISwipeGestureRecognizer *swipeDown =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    [self.view addGestureRecognizer:swipeDown];
    UISwipeGestureRecognizer *swipeRight =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeRight];
    UISwipeGestureRecognizer *swipeLeft =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:swipeLeft];
    arraySwipeRecognizer = @[ swipeUp, swipeDown, swipeRight, swipeLeft ];

    tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                            action:@selector(handleTap:)];
    [self.view addGestureRecognizer:tapRecognizer];

    // Re-parent the explain and corporate buttons back above everything.
    [explainBtn removeFromSuperview];
    [self.view addSubview:explainBtn];
    [coBtn removeFromSuperview];
    [self.view addSubview:coBtn];
}

/** @ghidraAddress 0x18803c */
- (void)markerCheckEnd {
    [self startBlinkPrompt];
}

#pragma mark - Concierge

/** @ghidraAddress 0x188248 */
- (int)getConciergeType {
    int colorType = [KnitColorManager.sharedManager getColorType];
    // Colour types 0..4 map through the table at 0x293490; the bound check at 0x188290 is unsigned
    // (cmp w19,#0x4 / b.hi), so any other type -- including a negative one, which wraps high --
    // falls through to type 3 rather than indexing the table out of bounds.
    static const int kColorTypeToConciergeType[] = {0, 1, 3, 3, 2};
    int type = ((unsigned int)colorType < 5) ? kColorTypeToConciergeType[colorType] :
                                               kConciergeTypeFallback;
    // Hinabita mode forces the hinabita concierge regardless of palette.
    if (JubeatAppDelegate.appDelegate.isHinabitaMode) {
        return kConciergeTypeHinabita;
    }
    return type;
}

/**
 * @ghidraAddress 0x187048
 * The hit rect is worked from the disassembly: the origin arrives from conciergePos in d0/d1 with a
 * 10-point inset, minus the logo view's frame origin.
 */
- (CGRect)getConciergeRect {
    CGFloat x = (CGFloat)((int)conciergePos.x - kConciergeHitInset);
    CGFloat y = (CGFloat)((int)conciergePos.y - kConciergeHitInset);
    CGRect logoFrame = jubeatLogoView.frame;
    return CGRectMake(
        x - logoFrame.origin.x, y - logoFrame.origin.y, conciergeSize.width, conciergeSize.height);
}

/**
 * @ghidraAddress 0x188300
 * The concierge and old-concierge positions are worked from the disassembly (the decompile's
 * pdVar/dVar aliasing is unreliable): the concierge starts a sixth of the way across, at a
 * per-idiom offset above the copyright view.
 */
- (void)becomeConcierge {
    int glWidth = (int)glView.frame.size.width;
    kcState = kKcStateConcierge;

    RemoveSwipeRecognizersFromTitleKnt(self, arraySwipeRecognizer);

    isWave = YES;
    conMoveFrame = 1;

    // Seed both positions above the copyright view: the "old" position at the far left, the current
    // position a sixth of the way across.
    int copyrightTop = (int)copyrightView.frame.origin.y;
    int offset = isPad ? kConciergeOffsetPad : kConciergeOffsetPhone;
    oldConPos = CGPointMake((double)glWidth, (double)(copyrightTop - offset));
    conciergePos = CGPointMake((double)((float)glWidth / 6.0f), (double)(copyrightTop - offset));

    // A replacement (campaign or hinabita) image re-seeds both positions centred on the view, above
    // the copyright, using the atlas height and per-idiom baseline (0x293480).
    if (replaceImage) {
        CGFloat baseline = isPad ? kConciergeHeightPad : kConciergeHeightPhone;
        CGFloat pad = isPad ? 20.0 : 10.0;
        int drop = (int)(pad + (conciergeSize.height - baseline));
        CGRect viewFrame = self.view.frame;
        int centreX = (int)((viewFrame.size.width - conciergeSize.width) * 0.5);
        copyrightTop = (int)copyrightView.frame.origin.y;
        oldConPos = CGPointMake((double)glWidth, (double)((-offset - drop) + copyrightTop));
        conciergePos = CGPointMake((double)centreX, (double)((-offset - drop) + copyrightTop));
    }

    // Lazily build the bell SE player.
    if (!sePlayer) {
        NSString *path = [NSBundle.mainBundle pathForResource:kBellResourceName
                                                       ofType:kBellResourceType];
        sePlayer = [[SePlayer alloc] initWithPath:path];
    }

    // The campaign concierge slides the touch prompt down out of the way.
    if (conType == kConciergeTypeHinabita) {
        __weak UIImageView *weakTouch = touchView;
        [UIView animateWithDuration:kConciergeSlideDuration
                         animations:^{
                           /** @ghidraAddress 0x1887b0 */
                           // The translation is purely vertical, by the signed tapDelayY ivar.
                           weakTouch.transform =
                               CGAffineTransformMakeTranslation(0.0, (double)(long)self->tapDelayY);
                         }
                         completion:^(BOOL __attribute__((unused)) finished){
                             /** @ghidraAddress 0x18888c */
                         }];
    }
}

#pragma mark - Gestures

/**
 * @ghidraAddress 0x1870e0
 * The two Konami hit regions and their (-5, -5) point shift are worked from the disassembly.
 *
 * The two hidden branches advance DIFFERENT counters, which is what makes the order matter. Eight
 * swipes take both @c kcState and @c hnState to 8. The inner-right hot-spot then moves @c hnState
 * to 9 with no visible change, and only after that can the inner-left hot-spot see @c hnState == 9
 * and unlock hinabita. Tapping left first instead moves @c kcState to 9, so the next right tap
 * satisfies @c kcState == 9 and calls @c -becomeConcierge , which raises @c kcState to
 * @c kKcStateConcierge and closes this whole block for the rest of the visit.
 */
- (void)handleTap:(UITapGestureRecognizer *)recognizer {
    if (!bEnableTap) {
        if (NE_DBG_EVERY) {
            neDebugLog("kntTitle tap: IGNORED, bEnableTap is NO");
        }
        return;
    }
    // The hidden Konami-code and easter-egg regions are live only before the concierge is unlocked.
    if (kcState < kKcStateConcierge) {
        CGPoint touch = [recognizer locationOfTouch:0 inView:jubeatLogoView];
        CGPoint shifted = CGPointMake(touch.x + kKonamiHitShift, touch.y + kKonamiHitShift);
        CGRect leftRect = isPad ? kKonamiLeftRectPad : kKonamiLeftRectPhone;
        CGRect rightRect = isPad ? kKonamiRightRectPad : kKonamiRightRectPhone;
        if (NE_DBG_EVERY) {
            // Everything the two hidden branches test, in one line. The shifted point is what the
            // rects are actually compared against, and it is in the logo's own coordinate space, so
            // a touch outside the logo reads negative or larger than the logo's size.
            neDebugLog("kntTitle tap: pt %.1f,%.1f shifted %.1f,%.1f  kcState %d hnState %d "
                       "conType %d  inLeft %d inRight %d",
                       touch.x,
                       touch.y,
                       shifted.x,
                       shifted.y,
                       kcState,
                       hnState,
                       conType,
                       (int)CGRectContainsPoint(leftRect, shifted),
                       (int)CGRectContainsPoint(rightRect, shifted));
        }
        BOOL stateAdvanced;
        if (CGRectContainsPoint(leftRect, shifted)) {
            // Inner-left hot-spot: advance the code, and complete the hinabita entry. Despite the
            // name these are not corners -- on the 298x84 phone logo the rect spans 31% to 46% of
            // the width, and the right one 65% to 80%, both across the middle band.
            stateAdvanced = (kcState == kHnStateArmed);
            if (stateAdvanced) {
                kcState = kHnStateConcierge;
            }
            if (hnState == kHnStateConcierge && conType != kConciergeTypeHinabita) {
                if (NE_DBG_EVERY) {
                    neDebugLog("kntTitle tap: HINABITA unlocked (left corner, hnState 9)");
                }
                JubeatAppDelegate.appDelegate.isHinabitaMode = YES;
                [JubeatAppDelegate.appDelegate switchTitleEvent];
                return;
            }
        } else if (CGRectContainsPoint(rightRect, shifted)) {
            // Inner-right hot-spot: at the final code step, swap in the concierge easter egg. Note
            // -becomeConcierge sets kcState to kKcStateConcierge, which closes the whole block
            // above for the rest of the visit, so the concierge and the hinabita entry are
            // mutually exclusive: whichever hot-spot is tapped first decides which one is
            // reachable.
            stateAdvanced = (kcState == kHnStateConcierge);
            if (stateAdvanced) {
                [AudioManager.sharedManager playSeResFile:kConciergeSwapSE inDirectory:nil];
                [self becomeConcierge];
            }
            // Arm the second code path; the binary returns here (b 0x187624).
            if (hnState == kHnStateArmed && conType != kConciergeTypeHinabita) {
                if (NE_DBG_EVERY) {
                    neDebugLog("kntTitle tap: hinabita ARMED (right corner, hnState 8 -> 9); "
                               "now tap the LEFT corner");
                }
                hnState = kHnStateConcierge;
                return;
            }
        } else {
            stateAdvanced = NO;
        }
        if (stateAdvanced) {
            return;
        }
    }

    // Once the concierge is walking, a tap on it ripples the waves and bumps the tap counters.
    if (isWave) {
        CGRect conciergeRect = [self getConciergeRect];
        CGPoint touch = [recognizer locationOfTouch:0 inView:jubeatLogoView];
        if (CGRectContainsPoint(conciergeRect, touch)) {
            [sePlayer sePlay];
            int next = (tapCnt < kMaxTapCount) ? tapCnt + 1 : kMaxTapCount;
            tapCnt = next;
            if (tapMax < next) {
                tapMax = next;
            }
            for (int column = 0; column < 4; ++column) {
                [upperBgKnt riseUp:column riseColumn:(int)(arc4random() & 3)];
            }
            if (conShakeUpFrame == 0) {
                conShakeUpFrame = kTapShakeUpFrames;
            }
            return;
        }
    }

    // A tap anywhere else begins the licence/provisioning flow the first time.
    if (!licenseAgree) {
        coverView = [[UIView alloc] initWithFrame:self.view.bounds];
        coverView.opaque = NO;
        coverView.backgroundColor = [UIColor colorWithWhite:0 alpha:kOverlayBackdropAlpha];
        coverView.alpha = 0.0;
        [self.view addSubview:coverView];
        if (!EditorIDManager.isExistEditorID) {
            idManager = [[EditorIDManager alloc] initWithDelegate:self];
        } else {
            [self createPolicyView];
        }
    }
}

/** @ghidraAddress 0x187648 */
- (void)handleSwipe:(UISwipeGestureRecognizer *)recognizer {
    // The four swipe directions drive the hidden up/down/right/left code sequence. Any unexpected
    // direction leaves the state untouched.
    int state;
    int previousState = kcState;
    switch (recognizer.direction) {
    case UISwipeGestureRecognizerDirectionRight: {
        int advanced = (kcState == 5) ? 6 : 0;
        state = (kcState == 7) ? 8 : advanced;
        break;
    }
    case UISwipeGestureRecognizerDirectionLeft: {
        int advanced = (kcState == 6) ? 7 : 0;
        state = (kcState == 4) ? 5 : advanced;
        break;
    }
    case UISwipeGestureRecognizerDirectionUp:
        state = (kcState == 1) ? 2 : 1;
        break;
    case UISwipeGestureRecognizerDirectionDown:
        state = (((unsigned int)kcState & 0xfffffffe) == 2) ? kcState + 1 : 0;
        break;
    default:
        return;
    }
    kcState = state;
    hnState = state;
    if (NE_DBG_EVERY) {
        // The code is eight swipes long and a wrong one silently resets to 0, so what matters is
        // the transition, not the final value. Direction is the raw UIKit bitmask: 1 right, 2 left,
        // 4 up, 8 down.
        neDebugLog("kntTitle swipe: dir %lu  kcState %d -> %d  hnState %d",
                   (unsigned long)recognizer.direction,
                   previousState,
                   kcState,
                   hnState);
    }
}

#pragma mark - Notifications

/** @ghidraAddress 0x187744 */
- (void)suspend:(NSNotification *)notification {
    if (tapRecognizer) {
        [touchView.layer removeAllAnimations];
    }
    if (displayLink) {
        [displayLink invalidate];
        displayLink = nil;
    }
}

/** @ghidraAddress 0x1877e8 */
- (void)resume:(NSNotification *)notification {
    if (tapRecognizer) {
        [self blinkPrompt];
    }
    if (!displayLink) {
        displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(loop:)];
        displayLink.frameInterval = 2;
        [displayLink addToRunLoop:NSRunLoop.currentRunLoop forMode:NSRunLoopCommonModes];
    }
    if (motionManager.isDeviceMotionAvailable) {
        [motionManager startDeviceMotionUpdatesUsingReferenceFrame:kMotionReferenceFrame];
    }
}

/** @ghidraAddress 0x187914 */
- (void)stopAnimation {
    if (displayLink) {
        [displayLink invalidate];
        displayLink = nil;
    }
    if (motionManager.isDeviceMotionAvailable) {
        [motionManager stopDeviceMotionUpdates];
    }
}

#pragma mark - Transition off the title

/** @ghidraAddress 0x188890 */
- (void)nextScene {
    RemoveSwipeRecognizersFromTitleKnt(self, arraySwipeRecognizer);
    [self.view removeGestureRecognizer:tapRecognizer];
    tapRecognizer = nil;

    [AudioManager.sharedManager playSeResFile:kConfirmSEName inDirectory:nil];
    [AudioManager.sharedManager fadeoutBgm:1.5];

    [touchView.layer removeAnimationForKey:kAnimationBlinkKey];
    touchView.alpha = 1.0;
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:kOpacityKeyPath];
    anim.duration = kNextSceneBlinkDuration;
    anim.fromValue = @(1.0f);
    anim.toValue = @(kBlinkDimOpacity);
    anim.autoreverses = YES;
    anim.repeatCount = kNextSceneBlinkRepeatCount;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    anim.removedOnCompletion = NO;
    [touchView.layer addAnimation:anim forKey:kAnimationBlinkFastKey];

    [JubeatAppDelegate.appDelegate.rootViewCtrl endTitle];
}

#pragma mark - Licence agreement

/** @ghidraAddress 0x188ccc */
- (void)createPolicyView {
    licenseAgree = [[LicenseAgreementView alloc] init:self keyString:kChallengePolicyVersionKey];
    licenseAgree.weakCoverView = coverView;
    CGRect bounds = self.view.bounds;
    licenseAgree.center = CGPointMake(bounds.size.width * 0.5, bounds.size.height * 0.5);
    [self.view addSubview:licenseAgree];
}

/** @ghidraAddress 0x188e18 */
- (void)agreementError:(id)manager msgStr:(NSString *)msgStr {
    // A licence already agreed to (the key is present) transitions on regardless of the error.
    if ([NSUserDefaults.standardUserDefaults valueForKey:kChallengePolicyVersionKey]) {
        [self nextScene];
        return;
    }
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
    // The binary reads neither `manager` nor `msgStr`: the body is the fixed CFString at 0x2dd500,
    // loaded into x6 at 0x188f28 immediately before the makeAlert: send.
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:@"通信エラー"
                                            msg:kAgreementErrorMsg
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
    [licenseAgree removeFromSuperview];
    licenseAgree = nil;
    [coverView removeFromSuperview];
    coverView = nil;
}

/** @ghidraAddress 0x188fb8 */
- (void)agreementSuccess:(id)sender {
    [licenseAgree removeFromSuperview];
    licenseAgree = nil;
    [coverView removeFromSuperview];
    coverView = nil;
    [self nextScene];
}

/** @ghidraAddress 0x189030 */
- (void)agreementFailed:(id)sender {
    [licenseAgree removeFromSuperview];
    licenseAgree = nil;
    [coverView removeFromSuperview];
    coverView = nil;
}

#pragma mark - EditorIDManagerDelegate

/** @ghidraAddress 0x189098 */
- (void)errorIDDownload:(id)manager msgStr:(NSString *)msgStr {
    NSString *message = msgStr;
    if (message == nil || [message isEqualToString:@""]) {
        message = [NSBundle.mainBundle localizedStringForKey:kNetworkErrorMsgKey
                                                       value:@""
                                                       table:nil];
    }
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:@""
                                            msg:message
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
    idManager = nil;
}

/** @ghidraAddress 0x189240 */
- (void)successIDDownload:(id)manager {
    idManager = nil;
    NSString *userId = [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
    if (userId) {
        [ApplilinkNetwork setUserId:userId];
    }
    [self createPolicyView];
}

#pragma mark - Rotation

/** @ghidraAddress 0x188048 */
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration {
    isPortrait = YES;
    if (UIApplication.sharedApplication.statusBarOrientation == kStatusBarUpsideDown) {
        return;
    }
    isPortrait = NO;
}

/** @ghidraAddress 0x1880c0 */
- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    isPortrait = YES;
    if (UIApplication.sharedApplication.statusBarOrientation == kStatusBarUpsideDown) {
        return;
    }
    isPortrait = NO;
}

/** @ghidraAddress 0x188138 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // The binary tests (unsigned)(orientation - 1) < 2, exactly the two portrait cases:
    // UIInterfaceOrientationPortrait (1) and UIInterfaceOrientationPortraitUpsideDown (2).
    return interfaceOrientation == UIInterfaceOrientationPortrait ||
           interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown;
}

/** @ghidraAddress 0x188148 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // The binary returns 6 == UIInterfaceOrientationMaskPortrait |
    // UIInterfaceOrientationMaskPortraitUpsideDown, matching the portrait pair above (the header's
    // "landscape" prose is a documentation slip; the binary value is portrait).
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x188150 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
