#import "ApplilinkViewManager.h"

#import "ApplilinkParameters.h"
#import "ApplilinkVideoController.h"

// The one and only ApplilinkViewManager instance and its dispatch_once tokens. File-scope rather
// than method-local, which the singleton rule would otherwise ask for, because +allocWithZone: and
// +sharedInstance share the instance and each has its own once token. The binary keeps them at the
// g_p… / DAT_ globals; their names are preserved here.
static ApplilinkViewManager *g_pApplilinkViewManagerShared = nil;
static dispatch_once_t g_ApplilinkViewManagerAllocOnceToken = 0;
static dispatch_once_t g_ApplilinkViewManagerSharedOnceToken = 0;

// The private serial queue -init synchronises its super call onto, created in +allocWithZone:.
static dispatch_queue_t g_hApplilinkViewManagerQueue = nil;

// The label the binary passes to dispatch_queue_create.
static const char *const kQueueLabel = "ApplilinkViewManager";

@implementation ApplilinkViewManager {
    ApplilinkVideoController *_videoController; // strong; the on-screen player, nil if none
    __weak id<ApplilinkViewManagerSdkDelegate> _sdkDelegate; // weak; callbacks are relayed to it
    ApplilinkParameters *_applilinkParams; // strong; the last request's parameters
}

// The weak sdkDelegate property is backed by the binary's _sdkDelegate ivar.
@synthesize sdkDelegate = _sdkDelegate;

#pragma mark - Lifecycle

/** @ghidraAddress 0x247d98 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    dispatch_once(&g_ApplilinkViewManagerAllocOnceToken, ^{
      /** @ghidraAddress 0x247e10 */
      // The queue is created unconditionally, then the singleton is re-tested inside the block
      // before being allocated with a null (serial) attribute.
      g_hApplilinkViewManagerQueue = dispatch_queue_create(kQueueLabel, nil);
      if (g_pApplilinkViewManagerShared == nil) {
          g_pApplilinkViewManagerShared = [super allocWithZone:zone];
      }
    });
    return g_pApplilinkViewManagerShared;
}

/** @ghidraAddress 0x247bc8 */
- (instancetype)init {
    __block ApplilinkViewManager *initResult = self;
    // The queue is the private serial one created in +allocWithZone:, not the main queue; syncing
    // onto the main queue here would deadlock the first main-thread +sharedInstance call.
    dispatch_sync(g_hApplilinkViewManagerQueue, ^{
      /** @ghidraAddress 0x247cd4 */
      initResult = [super init];
    });
    return initResult;
}

/** @ghidraAddress 0x247e98 */
+ (instancetype)sharedInstance {
    dispatch_once(&g_ApplilinkViewManagerSharedOnceToken, ^{
      /** @ghidraAddress 0x247edc */
      g_pApplilinkViewManagerShared = [[ApplilinkViewManager alloc] init];
    });
    return g_pApplilinkViewManagerShared;
}

#pragma mark - Video player

/** @ghidraAddress 0x247f3c */
- (void)showVideoViewWithUIView:(UIView *)view
               parentWindowFlag:(BOOL)parentWindowFlag
                          query:(NSString *)query
                       autoPlay:(BOOL)autoPlay
                applilinkParams:(ApplilinkParameters *)applilinkParams
                       delegate:(id)delegate {
    if (_videoController != nil) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      /** @ghidraAddress 0x248094 */
      self->_videoController = [[ApplilinkVideoController alloc] init];
      [self->_videoController parentWindowFlag:parentWindowFlag];
      [self->_videoController.view setFrame:UIScreen.mainScreen.bounds];
      [self->_videoController setSdkDelegate:self];
      [view addSubview:self->_videoController.view];
      [self->_videoController setQuery:query
                              autoPlay:autoPlay
                       applilinkParams:applilinkParams
                              delegate:delegate];
    });
}

/** @ghidraAddress 0x2482b8 */
- (void)closeVideoView {
    dispatch_async(dispatch_get_main_queue(), ^{
      /** @ghidraAddress 0x24831c */
      // -viewDealloc runs before the view leaves the hierarchy so the controller can still reach
      // its superview during cleanup. Clearing the weak _sdkDelegate also unregisters the weak
      // reference.
      [self->_videoController viewDealloc];
      [self->_videoController.view removeFromSuperview];
      self->_videoController = nil;
      self->_sdkDelegate = nil;
    });
}

#pragma mark - Delegate relays

/** @ghidraAddress 0x2483d0 */
- (void)openNotice {
    if (_sdkDelegate != nil && [_sdkDelegate respondsToSelector:@selector(openNotice)]) {
        [_sdkDelegate openedNotice];
    }
}

/** @ghidraAddress 0x24847c */
- (void)closeNotice:(id)view {
    if (_sdkDelegate != nil && [_sdkDelegate respondsToSelector:@selector(closeNotice:)]) {
        [_sdkDelegate closeNotice:self];
    }
    if (_videoController == view) {
        [self closeVideoView];
    }
}

/** @ghidraAddress 0x24855c */
- (void)viewReady:(id)view {
    if (_sdkDelegate != nil && [_sdkDelegate respondsToSelector:@selector(viewReady:)]) {
        [_sdkDelegate viewReady:self];
    }
}

/** @ghidraAddress 0x248618 */
- (void)rotateWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                              duration:(NSTimeInterval)duration {
    if (_videoController != nil) {
        [_videoController willAnimateRotationToInterfaceOrientation:orientation duration:duration];
    }
}

@end
