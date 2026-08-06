#import "SessionClass.h"

// The value -score- carries before the peer has reported one. A bare `mov w2, #0xffffffff`, which
// is -1 in the int the property metadata declares.
static const int kSessionScoreUnreported = -1;

@implementation SessionClass

/** @ghidraAddress 0xc4e50 */
- (instancetype)init {
    self = [super init];
    if (self != nil) {
        // Six of the thirteen properties are set explicitly, in this order. The other seven are
        // BOOLs left to the zero -alloc already guarantees.
        self.peerID = nil;
        self.delayTime = 0.0f;
        self.pingTryCnt = 0.0f;
        self.receiveStartTime = nil;
        self.receiveTime = 0.0f;
        self.score = kSessionScoreUnreported;
    }
    return self;
}

@end
