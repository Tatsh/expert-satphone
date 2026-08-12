#import "ApplilinkStore.h"

#import <UIKit/UIKit.h>

#import "ApplilinkParameters.h"

// The applilink view controller that owns the SKStoreProductViewController; not reconstructed in
// this tree yet, so it is forward-declared. See TYPES_PENDING.md.
@interface ApplilinkViewController : NSObject
- (void)showSKStore:(NSString *)appStoreId
           appParam:(ApplilinkParameters *)appParam
           delegate:(id)delegate;
- (void)productViewControllerDidFinish;
- (void)setSdkDelegate:(id)delegate;
@end

// The one and only ApplilinkStore instance and its dispatch_once tokens. File-scope rather than
// method-local, which the singleton rule would otherwise ask for, because +allocWithZone: and
// +sharedInstance share the instance and each has its own once token.
static ApplilinkStore *sSharedInstance = nil;
static dispatch_once_t sAllocOnceToken = 0;
static dispatch_once_t sSharedOnceToken = 0;

// The private serial queue -init synchronises its super call onto, created in +allocWithZone:.
static dispatch_queue_t sQueue = nil;

// The label the binary passes to dispatch_queue_create.
static const char *const kQueueLabel = "ApplilinkStore";

// The view controller presenting the store product page while one is on screen, or nil when none
// is. It survives across store requests, so it is a file-scope global rather than an instance ivar.
static ApplilinkViewController *sViewController = nil;

// The first iOS version whose SKStoreProductViewController the SDK is willing to present.
static const float kMinimumStoreSystemVersion = 6.0f;

@implementation ApplilinkStore

@synthesize sdkDelegate = _sdkDelegate;
@synthesize applilinkParams = _applilinkParams;

#pragma mark - Lifecycle

/** @ghidraAddress 0x2505c4 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    dispatch_once(&sAllocOnceToken, ^{
      /** @ghidraAddress 0x25063c */
      // The binary passes a null attribute, which makes this a serial queue, and re-tests the
      // singleton inside the once block after creating the queue.
      sQueue = dispatch_queue_create(kQueueLabel, nil);
      if (sSharedInstance == nil) {
          sSharedInstance = [super allocWithZone:zone];
      }
    });
    return sSharedInstance;
}

/** @ghidraAddress 0x2503f4 */
- (instancetype)init {
    __block ApplilinkStore *initResult = self;
    // The queue is the private serial one created in +allocWithZone:, not the main queue; syncing
    // onto the main queue here would deadlock the first main-thread +sharedInstance call.
    dispatch_sync(sQueue, ^{
      /** @ghidraAddress 0x250500 */
      initResult = [super init];
    });
    return initResult;
}

/** @ghidraAddress 0x2506c4 */
+ (instancetype)sharedInstance {
    dispatch_once(&sSharedOnceToken, ^{
      /** @ghidraAddress 0x250708 */
      sSharedInstance = [[ApplilinkStore alloc] init];
    });
    return sSharedInstance;
}

#pragma mark - Store

/** @ghidraAddress 0x250754 */
- (BOOL)showSKStore:(NSString *)appStoreId
           appParam:(ApplilinkParameters *)appParam
           delegate:(id<SdkViewDelegate>)delegate {
    if ([[UIDevice currentDevice] systemVersion].floatValue < kMinimumStoreSystemVersion) {
        return NO;
    }
    if (sViewController == nil) {
        // The binary stores both values straight into the backing ivars here; the parameters bypass
        // the copy setter, so this keeps the caller's instance rather than a copy.
        _sdkDelegate = delegate;
        _applilinkParams = appParam;
        sViewController = [[ApplilinkViewController alloc] init];
        [sViewController showSKStore:appStoreId appParam:_applilinkParams delegate:self];
    }
    return YES;
}

/** @ghidraAddress 0x2508e8 */
- (void)closeSKStore {
    if (sViewController != nil) {
        [sViewController productViewControllerDidFinish];
    }
}

#pragma mark - SdkViewDelegate

/** @ghidraAddress 0x25090c */
- (void)appStoreOpenedNoticeWithAppParam:(ApplilinkParameters *)appParam {
    if (_sdkDelegate != nil &&
        [_sdkDelegate respondsToSelector:@selector(appStoreOpenedNoticeWithAppParam:)]) {
        [_sdkDelegate appStoreOpenedNoticeWithAppParam:_applilinkParams];
    }
}

/** @ghidraAddress 0x2509cc */
- (void)appStoreCloseNoticeWithAppParam:(ApplilinkParameters *)appParam {
    if (_sdkDelegate != nil &&
        [_sdkDelegate respondsToSelector:@selector(appStoreCloseNoticeWithAppParam:)]) {
        [_sdkDelegate appStoreCloseNoticeWithAppParam:_applilinkParams];
    }
}

/** @ghidraAddress 0x250a8c */
- (void)appStoreClosedNoticeWithAppParam:(ApplilinkParameters *)appParam {
    if (sViewController != nil) {
        [sViewController setSdkDelegate:nil];
    }
    sViewController = nil;
    if (_sdkDelegate != nil) {
        if ([_sdkDelegate respondsToSelector:@selector(appStoreClosedNoticeWithAppParam:)]) {
            [_sdkDelegate appStoreClosedNoticeWithAppParam:_applilinkParams];
        }
        _sdkDelegate = nil;
    }
}

/** @ghidraAddress 0x250b88 */
- (void)appStoreFailLoadNoticeWithError:(NSError *)error appParam:(ApplilinkParameters *)appParam {
    if (sViewController != nil) {
        [sViewController setSdkDelegate:nil];
    }
    sViewController = nil;
    if (_sdkDelegate != nil) {
        if ([_sdkDelegate
                respondsToSelector:@selector(appStoreFailLoadNoticeWithError:appParam:)]) {
            // The store always reports nil as the error to the caller's delegate, keeping only the
            // request parameters.
            [_sdkDelegate appStoreFailLoadNoticeWithError:nil appParam:_applilinkParams];
        }
        _sdkDelegate = nil;
    }
}

@end
