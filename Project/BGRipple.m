#import "BGRipple.h"

#import "neEngineBridge.h"

// The swell runs in two stages: up to 1.2 over the first eight frames, then back to 1.0 over the
// next twelve. Past that the scale is left alone.
static const unsigned int kSwellUpEndFrame = 8;
static const unsigned int kSwellDownEndFrame = 20;
static const float kSwellPeak = 1.2f; // @ghidraAddress 0x292aa8

// The fade in occupies the same first eight frames as the swell up; the fade out the last ten
// frames of the lifetime.
static const unsigned int kFadeOutFrames = 10;

static const float kOpaque = 1.0f;
static const float kTransparent = 0.0f;

// The sprite is drawn half its base size up and left of where it is anchored.
static const float kAnchorOffsetFraction = 0.5f;

// Declared here rather than left to a bare id; the encoding is from the runtime metadata.
@interface Texture2D (BGRippleDrawing)
/** @ghidraAddress 0xeb28 */
- (void)drawSprite:(NSUInteger)sprite
           atPoint:(CGPoint)point
             scale:(float)scale
            rotate:(float)rotate
            anchor:(CGPoint)anchor
         transform:(char)transform
             alpha:(float)alpha;
@end

@implementation BGRipple {
    NSUInteger sprite;
    float xSpeed;
    CGPoint point;
    unsigned int lifetime;
    float baseSize;
    float mag;
    float baseAlpha;
    unsigned int frame;
}

/** @ghidraAddress 0x143b38 */
- (instancetype)initWithSprite:(NSUInteger)aSprite
                       atPoint:(CGPoint)aPoint
                        xSpeed:(float)anXSpeed
                      lifetime:(unsigned int)aLifetime
                      basesize:(float)basesize
                           mag:(float)aMag
                         alpha:(float)alpha {
    self = [super init];
    if (self) {
        sprite = aSprite;
        xSpeed = anXSpeed;
        point = aPoint;
        lifetime = aLifetime;
        baseSize = basesize;
        mag = aMag;
        baseAlpha = alpha;
        // Note frame is left at zero rather than assigned; a fresh instance already has it.
    }
    return self;
}

/** @ghidraAddress 0x143c0c */
- (BOOL)step {
    if (frame > lifetime) {
        return YES;
    }
    // Horizontally only — the y never moves.
    point.x += xSpeed;
    ++frame;
    return NO;
}

/** @ghidraAddress 0x143c70 */
- (void)renderWithTexture:(Texture2D *)texture {
    if (frame > lifetime) {
        return;
    }

    float alpha = baseAlpha;
    float scale = mag;

    if (frame <= kSwellUpEndFrame - 1) {
        // Fading in and swelling out together over the first eight frames.
        alpha *= InterpolateFloatByFrame(kTransparent, kOpaque, frame, 0, kSwellUpEndFrame);
        scale *= InterpolateFloatByFrame(kOpaque, kSwellPeak, frame, 0, kSwellUpEndFrame);
    } else if (frame <= kSwellDownEndFrame - 1) {
        // Settling back to its nominal scale. The opacity is left alone through this stage.
        scale *= InterpolateFloatByFrame(
            kSwellPeak, kOpaque, frame, kSwellUpEndFrame, kSwellDownEndFrame);
    }

    // The fade out is tested independently, so on a short-lived ripple it can overlap the fade in
    // and multiply the opacity twice.
    if (frame >= lifetime - kFadeOutFrames) {
        alpha *= InterpolateFloatByFrame(
            kOpaque, kTransparent, frame, lifetime - kFadeOutFrames, lifetime);
    }

    // Drawn half a base size up and left of the anchor, so the sprite grows about its centre.
    CGFloat inset = baseSize * kAnchorOffsetFraction;
    [texture drawSprite:sprite
                atPoint:CGPointMake(point.x - inset, point.y - inset)
                  scale:scale
                 rotate:0
                 anchor:point
              transform:0
                  alpha:alpha];
}

@end
