#import "MainGameRenderer.h"

#import <string.h>

// Forward declarations of collaborators not yet reconstructed as their own files.

/// The play session's note sequence; @c -getScore returns its live score summary.
@interface Sequence : NSObject
- (const ScoreData *)getScore;
@end

// The sub-state value that marks the play session as finished.
static const unsigned int kMainGameEndSubState = 99;

// The default 480-point-tall phone metrics, returned by the base as override points.
static const int kButtonMarginForScreen40 = 77;
static const int kUpperBgHeight40 = 66;

@implementation MainGameRenderer

#pragma mark - Lifecycle

/** @ghidraAddress 0xf6b4 */
- (instancetype)init {
    self = [super init];
    if (self) {
        _isTextureChange = NO;
        _goodJobImage = nil;
        _scoreBackup = NO;
    }
    return self;
}

#pragma mark - Textures

/** @ghidraAddress 0xf714 */
- (void)loadTexure:(RendererConf *)conf artwork:(UIImage *)artwork index:(UIImage *)index {
    // Override point: concrete subclasses load the idiom- and theme-appropriate textures.
}

/** @ghidraAddress 0xf718 */
- (void)releaseTexture {
    // Override point.
}

#pragma mark - State

/** @ghidraAddress 0xf72c */
- (void)setState:(unsigned int)state {
    _state = state;
    _subState = 0;
}

/** @ghidraAddress 0xf748 */
- (BOOL)isEndState {
    return self.subState == kMainGameEndSubState;
}

#pragma mark - Play lifecycle

/** @ghidraAddress 0xf7c4 */
- (double)durationOfReadyGo {
    return 0.0;
}

/** @ghidraAddress 0xf7cc */
- (void)startPlay {
    // Override point.
}

/** @ghidraAddress 0xf7d0 */
- (void)endResult {
    // Override point.
}

/** @ghidraAddress 0xf87c */
- (void)replaySelect {
    // Override point.
}

/** @ghidraAddress 0xf880 */
- (void)replayEnd {
    // Override point.
}

#pragma mark - Layout override points

/** @ghidraAddress 0xf7d4 */
- (double)buttonAreaOffset {
    return 0.0;
}

/** @ghidraAddress 0xf7dc */
- (double)gameAreaOffset {
    return 0.0;
}

/** @ghidraAddress 0xf7ec */
- (int)buttonMarginForScreen40 {
    return kButtonMarginForScreen40;
}

/** @ghidraAddress 0xf7f4 */
- (int)upperBgHeight40 {
    return kUpperBgHeight40;
}

/** @ghidraAddress 0xf7fc */
- (CGRect)getMusicBarRect {
    return CGRectZero;
}

#pragma mark - Button override points

/** @ghidraAddress 0xf76c */
- (unsigned int)endButtonID {
    return 0;
}

/** @ghidraAddress 0xf774 */
- (unsigned int)evaluateButtonID {
    return 0;
}

/** @ghidraAddress 0xf77c */
- (unsigned int)goodJobButtonID {
    return 0;
}

/** @ghidraAddress 0xf784 */
- (CGPoint)goodJobPosition {
    return CGPointZero;
}

/** @ghidraAddress 0xf794 */
- (unsigned int)twitterSendButtonID {
    return 0;
}

/** @ghidraAddress 0xf79c */
- (CGPoint)twitterBtnPosition {
    return CGPointZero;
}

/** @ghidraAddress 0xf7ac */
- (unsigned int)storeMoveButtonID {
    return 0;
}

/** @ghidraAddress 0xf7b4 */
- (CGPoint)storeMoveBtnPosition {
    return CGPointZero;
}

#pragma mark - Drawing override points

/** @ghidraAddress 0xf7e4 */
- (void)draw {
    // Override point: concrete subclasses render the play field.
}

/** @ghidraAddress 0xf7e8 */
- (void)drawDebugText:(const char *)text pos:(CGPoint)pos alpha:(float)alpha {
    // Override point.
}

#pragma mark - Score backup

/** @ghidraAddress 0xf810 */
- (void)backupScoreData {
    _scoreBackup = YES;
    memcpy(&_replayBackupScore, [self.sequence getScore], sizeof(ScoreData));
}

@end
