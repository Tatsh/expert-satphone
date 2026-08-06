#import "UpperBGRipple.h"

#include <stdlib.h>

// The mass is drawn at construction rather than passed in: (rand % 24) | 32, eighths. The OR keeps
// bit 5 set, so the range is 32..55 eighths — 4.0 to 6.875 — and never lighter than 4.
enum {
    kMassSpread = 24,
    kMassFloor = 32,
};
static const float kMassUnit = 0.125f;

// A jump is only allowed from rest, and rest is a window around zero rather than exactly zero.
static const double kAtRestBound = 0.5;

// Once the sprite has drifted this far past the left edge it is put back at the caller's reset
// position.
static const double kWrapLeftEdge = -80.0; // @ghidraAddress 0x28f468

// The reflection is drawn faint and upright; the sprite itself is drawn solid and turned a quarter
// turn.
static const float kReflectionAlpha = 0.4f;       // @ghidraAddress 0x28f3b4
static const float kSpriteRotation = -1.5707964f; // @ghidraAddress 0x292f30
static const float kNoRotation = 0.0f;
static const float kFullAlpha = 1.0f;

// The engine's transform argument, a selector rather than a matrix. Always none here.
static const char kNoTransform = 0;

@implementation UpperBGRipple {
    CGPoint point;
    float x_spd;
    float y_spd;
    float weight;
    float y_amp;
    float y_ctr;
    float mag;
    unsigned int y_period;
    unsigned int y_phase;
    NSUInteger sprite;
}

@synthesize y_gnd = y_gnd;

/** @ghidraAddress 0x143dd0 */
- (instancetype)initWithSprite:(NSUInteger)aSprite
                       atPoint:(CGPoint)aPoint
                        xSpeed:(float)xSpeed
                       yGround:(float)yGround
                          yAmp:(float)yAmp
                       yCenter:(float)yCenter
                       yPeriod:(unsigned int)yPeriod
                        yPhase:(unsigned int)yPhase
                           mag:(float)aMag {
    self = [super init];
    if (self) {
        sprite = aSprite;
        point = aPoint;
        y_gnd = yGround;
        y_amp = yAmp;
        y_ctr = yCenter;
        x_spd = xSpeed;
        mag = aMag;
        y_period = yPeriod;
        y_phase = yPhase;
        // Not a parameter — every sprite gets its own mass, so a shared impulse moves each one
        // differently.
        weight = (float)((arc4random() % kMassSpread) | kMassFloor) * kMassUnit;
    }
    return self;
}

/** @ghidraAddress 0x143f18 */
- (void)triggerJump:(float)force {
    // Only from rest. An airborne sprite ignores the impulse rather than accumulating it.
    if (point.y > -kAtRestBound && point.y < kAtRestBound) {
        y_spd = force / weight;
    }
}

/** @ghidraAddress 0x143f5c */
- (void)stepFall:(float)resetX gravity:(float)gravity bounce:(float)bounce {
    double nextX = point.x - x_spd;
    point.x = (nextX < kWrapLeftEdge) ? resetX : nextX;

    point.y = point.y + y_spd;
    if (point.y > 0) {
        y_spd = y_spd - gravity;
    } else {
        // Landed. Clamp to the ground and reverse what is left of the speed.
        point.y = 0;
        y_spd = -(y_spd * bounce);
    }
}

/** @ghidraAddress 0x143fdc */
- (void)renderWithTexture:(Texture2D *)texture yLimit:(float)yLimit {
    // point.y is a height above the ground, so the reflection is below the line and the sprite is
    // above it.
    double reflectionY = y_gnd + point.y;
    if (reflectionY < yLimit) {
        // The anchor is the same point the sprite is drawn at, so it turns about itself.
        [texture drawSprite:sprite
                    atPoint:CGPointMake(point.x, reflectionY)
                      scale:mag
                     rotate:kNoRotation
                     anchor:CGPointMake(point.x, reflectionY)
                  transform:kNoTransform
                      alpha:kReflectionAlpha];
    }

    double spriteY = y_gnd - point.y;
    // The sprite is turned a quarter turn and the reflection is not, which is asymmetric but is
    // what the two calls do.
    [texture drawSprite:sprite
                atPoint:CGPointMake(point.x, spriteY)
                  scale:mag
                 rotate:kSpriteRotation
                 anchor:CGPointMake(point.x, spriteY)
              transform:kNoTransform
                  alpha:kFullAlpha];
}

/** @ghidraAddress 0x144100 */
- (NSInteger)compZ:(UpperBGRipple *)other {
    // The other sprite's ground line is fetched twice, once per comparison.
    if (y_gnd < other.y_gnd) {
        return NSOrderedAscending;
    }
    return (y_gnd > other.y_gnd) ? NSOrderedDescending : NSOrderedSame;
}

@end
