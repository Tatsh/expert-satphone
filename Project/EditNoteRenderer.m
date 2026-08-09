#import "EditNoteRenderer.h"

// Forward declarations of collaborators not yet reconstructed as their own files. EditRendererConf
// is the edit-mode renderer configuration; EditSequence is the edit-mode note sequence.
@class EditRendererConf;
@class EditSequence;

// The sub-state value that marks the play session as finished.
static const unsigned int kEditNoteEndSubState = 99;

// The sentinel stored in an area-selection sector when no area is selected.
static const int kEditNoteNoSector = -1;

@implementation EditNoteRenderer

#pragma mark - Lifecycle

/** @ghidraAddress 0x20add0 */
- (instancetype)init {
    self = [super init];
    if (self) {
        self.enableBtn = YES;
        self.displayMode = 0;
        self.areaStartSector = kEditNoteNoSector;
        self.areaEndSector = kEditNoteNoSector;
    }
    return self;
}

#pragma mark - Textures

/** @ghidraAddress 0x20ae6c */
- (void)loadTexure:(EditRendererConf *)conf artwork:(UIImage *)artwork index:(UIImage *)index {
    // Override point: concrete subclasses load the idiom-appropriate textures.
}

/** @ghidraAddress 0x20ae70 */
- (void)releaseTexture {
    // Override point.
}

#pragma mark - State

/** @ghidraAddress 0x20ae84 */
- (void)setState:(unsigned int)state {
    _state = state;
    _subState = 0;
}

/** @ghidraAddress 0x20aea0 */
- (BOOL)isEndState {
    return self.subState == kEditNoteEndSubState;
}

#pragma mark - Play lifecycle override points

/** @ghidraAddress 0x20aedc */
- (void)startPlay {
    // Override point.
}

/** @ghidraAddress 0x20aee0 */
- (void)endResult {
    // Override point.
}

/** @ghidraAddress 0x20af48 */
- (void)resetCurrentTime {
    // Override point.
}

/** @ghidraAddress 0x20af50 */
- (void)saveBaseScale {
    // Override point.
}

#pragma mark - Layout override points

/** @ghidraAddress 0x20aee4 */
- (double)buttonAreaOffset {
    return 0.0;
}

/** @ghidraAddress 0x20aef4 */
- (CGRect)getTimeLineRect {
    return CGRectZero;
}

/** @ghidraAddress 0x20af20 */
- (CGRect)getAreaSelectStart {
    return CGRectZero;
}

/** @ghidraAddress 0x20af34 */
- (CGRect)getAreaSelectEnd {
    return CGRectZero;
}

#pragma mark - Drawing override points

/** @ghidraAddress 0x20aeec */
- (void)draw {
    // Override point: concrete subclasses render the edit field.
}

/** @ghidraAddress 0x20aef0 */
- (void)drawDebugText:(const char *)text pos:(CGPoint)pos alpha:(float)alpha {
    // Override point.
}

#pragma mark - Coordinate conversion override points

/** @ghidraAddress 0x20af08 */
- (int)pos2sector:(int)pos {
    return 0;
}

/** @ghidraAddress 0x20af10 */
- (int)sector2pos:(int)sector {
    return 0;
}

/** @ghidraAddress 0x20af18 */
- (int)dot2sector:(int)dot {
    return 0;
}

#pragma mark - Button override points

/** @ghidraAddress 0x20aec4 */
- (unsigned int)endButtonID {
    return 0;
}

/** @ghidraAddress 0x20aecc */
- (unsigned int)goodJobButtonID {
    return 0;
}

/** @ghidraAddress 0x20aed4 */
- (unsigned int)levelButtonID {
    return 0;
}

#pragma mark - Edit configuration

/** @ghidraAddress 0x20af4c */
- (void)setDbs:(float)dbs {
    // Override point.
}

@end
