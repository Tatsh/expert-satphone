#import "neUIProbe.h"

#import <objc/runtime.h>

#import <CoreFoundation/CoreFoundation.h>
#import <QuartzCore/QuartzCore.h>

#import "neDebugLog.h"

#if JBDBG

#include <stdatomic.h>
#include <stdbool.h>

// The main-thread pulse timer publishes a timestamp here; the watchdog on the background queue is
// the only reader. Milliseconds since an arbitrary monotonic origin, which is all a stall
// measurement needs.
//
// The timestamp deliberately comes from a timer rather than from a CFRunLoopObserver: an observer
// stops firing whenever the main run loop legitimately goes to sleep with nothing to do, so a
// watchdog built on one reports a stall every time the app sits idle. A timer that did not fire is
// unambiguous -- the main thread failed to service a scheduled callback -- which is exactly the
// property being measured.
static _Atomic uint64_t gLastRunLoopTickMilliseconds;

// Set once the watchdog has reported the current stall, so a long one logs a single "idle" line
// and a single "recovered" line rather than one per check.
static _Atomic bool gStallReported;

// Retained for the lifetime of the process; the probe is never uninstalled.
static dispatch_source_t gWatchdogTimer;
static NSTimer *gPulseTimer;

// The original -[UIWindow sendEvent:] implementation, called through after the trace.
static void (*gOriginalWindowSendEvent)(UIWindow *, SEL, UIEvent *);

// How often the main thread publishes its liveness timestamp, and how many of those pulses pass
// between logged heartbeats. The pulse is silent, so liveness is sampled four times a second while
// the log gains only one line a second.
static const NSTimeInterval kPulseInterval = 0.25;
static const unsigned int kPulsesPerHeartbeat = 4;

// How often the background watchdog samples that timestamp, and how far behind it must fall before
// the main thread counts as stalled. The threshold is several pulses wide so that ordinary
// scheduling jitter cannot trip it.
static const NSTimeInterval kWatchdogInterval = 0.25;
static const uint64_t kStallThresholdMilliseconds = 1500;

// Bounds on the view-tree dump, so one call cannot bury the interesting lines. The game's own
// select screen holds well over a hundred sibling tiles.
static const NSUInteger kMaxTreeDepth = 6;
static const NSUInteger kMaxSiblingsPerLevel = 12;

// How many ancestors of a touched view are named before the chain is truncated.
static const NSUInteger kMaxHitTestChain = 6;

#pragma mark - Small helpers

static const char *ProbeClassName(id object) {
    return object ? object_getClassName(object) : "nil";
}

static uint64_t ProbeNowMilliseconds(void) {
    return (uint64_t)(CACurrentMediaTime() * 1000.0);
}

// The run loop's current mode, as a plain C string valid until the next call. The mode matters
// because a transition that never completes while the loop sits in a tracking or a nested mode is
// a different fault from one that never completes in the default mode.
static const char *ProbeMainRunLoopMode(void) {
    // Thread-local: the heartbeat calls this on the main thread and the watchdog calls it on its
    // own queue, and a shared static buffer would let one garble the other's line.
    static _Thread_local char buffer[64];
    CFStringRef mode = CFRunLoopCopyCurrentMode(CFRunLoopGetMain());
    if (!mode) {
        return "idle";
    }
    if (!CFStringGetCString(mode, buffer, sizeof(buffer), kCFStringEncodingUTF8)) {
        buffer[0] = '\0';
    }
    CFRelease(mode);
    return buffer;
}

static UIWindow *ProbeKeyWindow(void) {
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window.isKeyWindow) {
            return window;
        }
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

// The deepest presented controller reachable from the window's root, which is the one UIKit is
// actually showing.
static UIViewController *ProbeTopPresentedController(void) {
    UIViewController *controller = ProbeKeyWindow().rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    return controller;
}

#pragma mark - Touch tracing

// Names the touched view and up to kMaxHitTestChain of its ancestors. A touch that lands on a
// transparent cover, on a stale transition view, or on nothing at all is identified here and
// nowhere else: the system log reports that an event was dispatched but never what received it.
static void ProbeLogTouch(UIWindow *window, UITouch *touch) {
    char chain[320];
    size_t used = 0;
    chain[0] = '\0';
    UIView *view = touch.view;
    for (NSUInteger step = 0; view && step < kMaxHitTestChain; ++step) {
        int written = snprintf(chain + used,
                               sizeof(chain) - used,
                               "%s%s",
                               (step == 0) ? "" : " < ",
                               object_getClassName(view));
        if (written <= 0 || (size_t)written >= sizeof(chain) - used) {
            break;
        }
        used += (size_t)written;
        view = view.superview;
    }
    if (used == 0) {
        snprintf(chain, sizeof(chain), "no view");
    }
    CGPoint point = [touch locationInView:window];
    neDebugLog("probe touch: phase %ld at %.1f,%.1f window %s interaction %d ignoring %d "
               "chain %s",
               (long)touch.phase,
               point.x,
               point.y,
               object_getClassName(window),
               (int)window.isUserInteractionEnabled,
               (int)UIApplication.sharedApplication.isIgnoringInteractionEvents,
               chain);
}

static void ProbeWindowSendEvent(UIWindow *window, SEL selector, UIEvent *event) {
    if (event.type == UIEventTypeTouches) {
        for (UITouch *touch in event.allTouches) {
            // Only the ends of a touch: the moves in between would flood the capture and carry no
            // information the begin has not already given.
            if (touch.phase == UITouchPhaseBegan || touch.phase == UITouchPhaseEnded ||
                touch.phase == UITouchPhaseCancelled) {
                ProbeLogTouch(window, touch);
            }
        }
    }
    gOriginalWindowSendEvent(window, selector, event);
}

#pragma mark - Liveness

static void ProbeHeartbeat(void) {
    UIWindow *window = ProbeKeyWindow();
    UIViewController *top = ProbeTopPresentedController();
    neDebugLog("probe beat: mode %s ignoring %d windows %lu key %s interaction %d top %s "
               "transitioning %d",
               ProbeMainRunLoopMode(),
               (int)UIApplication.sharedApplication.isIgnoringInteractionEvents,
               (unsigned long)UIApplication.sharedApplication.windows.count,
               ProbeClassName(window),
               (int)window.isUserInteractionEnabled,
               ProbeClassName(top),
               (int)(top.transitionCoordinator != nil));
}

// Runs on the main thread. Publishing the timestamp is the whole job most ticks; every
// kPulsesPerHeartbeat-th tick also reports the interaction state, so an unbalanced
// ignore-interaction pair shows up in the capture even while the screen is untouched.
static void ProbePulse(void) {
    atomic_store_explicit(
        &gLastRunLoopTickMilliseconds, ProbeNowMilliseconds(), memory_order_relaxed);
    static unsigned int pulse = 0;
    if ((++pulse % kPulsesPerHeartbeat) != 0) {
        return;
    }
    ProbeHeartbeat();
}

// Runs on the watchdog queue, never on the main thread, so it still reports while the main thread
// is wedged. That is the whole point: a blocked main thread otherwise shows up only as an absence
// of log lines, which is indistinguishable from the user simply not touching the screen.
static void ProbeWatchdogCheck(void) {
    uint64_t last = atomic_load_explicit(&gLastRunLoopTickMilliseconds, memory_order_relaxed);
    uint64_t now = ProbeNowMilliseconds();
    uint64_t idle = (now > last) ? (now - last) : 0;
    bool reported = atomic_load_explicit(&gStallReported, memory_order_relaxed);
    if (idle >= kStallThresholdMilliseconds) {
        if (!reported) {
            atomic_store_explicit(&gStallReported, true, memory_order_relaxed);
            neDebugLog("probe watchdog: MAIN RUN LOOP STALLED, idle %llu ms, mode %s",
                       (unsigned long long)idle,
                       ProbeMainRunLoopMode());
        }
        return;
    }
    if (reported) {
        atomic_store_explicit(&gStallReported, false, memory_order_relaxed);
        neDebugLog("probe watchdog: main run loop recovered, mode %s", ProbeMainRunLoopMode());
    }
}

#pragma mark - Public entry points

void neUIProbeInstall(void) {
    static BOOL installed = NO;
    if (installed) {
        return;
    }
    installed = YES;

    Method sendEvent = class_getInstanceMethod(UIWindow.class, @selector(sendEvent:));
    gOriginalWindowSendEvent =
        (void (*)(UIWindow *, SEL, UIEvent *))method_getImplementation(sendEvent);
    method_setImplementation(sendEvent, (IMP)ProbeWindowSendEvent);

    atomic_store_explicit(
        &gLastRunLoopTickMilliseconds, ProbeNowMilliseconds(), memory_order_relaxed);
    gPulseTimer = [NSTimer timerWithTimeInterval:kPulseInterval
                                         repeats:YES
                                           block:^(NSTimer *unusedTimer) {
                                             ProbePulse();
                                           }];
    // Common modes, so the pulse keeps going while a scroll or a transition holds the loop in a
    // tracking mode -- exactly the window in which the settings screen fails.
    [NSRunLoop.mainRunLoop addTimer:gPulseTimer forMode:NSRunLoopCommonModes];

    dispatch_queue_t queue =
        dispatch_queue_create("jp.konami.jubeatplus.probe.watchdog", DISPATCH_QUEUE_SERIAL);
    gWatchdogTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(
        gWatchdogTimer,
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kWatchdogInterval * NSEC_PER_SEC)),
        (uint64_t)(kWatchdogInterval * NSEC_PER_SEC),
        (uint64_t)(NSEC_PER_SEC / 10));
    dispatch_source_set_event_handler(gWatchdogTimer, ^{
      ProbeWatchdogCheck();
    });
    dispatch_resume(gWatchdogTimer);

    neDebugLog("probe installed: build %s", JBDBG_BUILD_SHA);
}

void neUIProbeLogController(const char *tag, UIViewController *controller) {
    if (!controller) {
        neDebugLog("probe vc %s: nil", tag);
        return;
    }
    UINavigationController *nav = controller.navigationController;
    neDebugLog("probe vc %s: %s presented %d dismissed %d toParent %d fromParent %d window %d "
               "coord %d navDepth %lu navTop %s presenting %s presentedOn %s",
               tag,
               object_getClassName(controller),
               (int)controller.isBeingPresented,
               (int)controller.isBeingDismissed,
               (int)controller.isMovingToParentViewController,
               (int)controller.isMovingFromParentViewController,
               (int)(controller.viewIfLoaded.window != nil),
               (int)(controller.transitionCoordinator != nil),
               (unsigned long)nav.viewControllers.count,
               ProbeClassName(nav.topViewController),
               ProbeClassName(controller.presentingViewController),
               ProbeClassName(controller.presentedViewController));
}

void neUIProbeTraceTransition(const char *tag, UIViewController *controller) {
    id<UIViewControllerTransitionCoordinator> coordinator = controller.transitionCoordinator;
    if (!coordinator) {
        neDebugLog("probe transition %s: no coordinator", tag);
        return;
    }
    neDebugLog("probe transition %s: begin, animated %d interactive %d duration %.3f",
               tag,
               (int)coordinator.isAnimated,
               (int)coordinator.initiallyInteractive,
               coordinator.transitionDuration);
    // Copied so the completion can name its own call site; the tag comes from a string literal in
    // every current caller, but copying keeps that from being a requirement.
    NSString *label = @(tag);
    [coordinator
        animateAlongsideTransition:nil
                        completion:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
                          neDebugLog("probe transition %s: END cancelled %d",
                                     label.UTF8String,
                                     (int)ctx.isCancelled);
                        }];
}

static void ProbeLogViewTree(UIView *view, NSUInteger depth) {
    if (depth > kMaxTreeDepth) {
        return;
    }
    CGRect frame = view.frame;
    neDebugLog("probe tree: %*s%s %.0f,%.0f %.0fx%.0f alpha %.2f hidden %d interaction %d subs %lu",
               (int)(depth * 2),
               "",
               object_getClassName(view),
               frame.origin.x,
               frame.origin.y,
               frame.size.width,
               frame.size.height,
               view.alpha,
               (int)view.isHidden,
               (int)view.isUserInteractionEnabled,
               (unsigned long)view.subviews.count);
    NSUInteger printed = 0;
    for (UIView *subview in view.subviews) {
        if (printed >= kMaxSiblingsPerLevel) {
            neDebugLog("probe tree: %*s... %lu more siblings",
                       (int)((depth + 1) * 2),
                       "",
                       (unsigned long)(view.subviews.count - printed));
            break;
        }
        ProbeLogViewTree(subview, depth + 1);
        ++printed;
    }
}

void neUIProbeLogWindowTree(const char *tag) {
    NSArray<UIWindow *> *windows = UIApplication.sharedApplication.windows;
    neDebugLog("probe windows %s: count %lu", tag, (unsigned long)windows.count);
    for (UIWindow *window in windows) {
        neDebugLog("probe window: %s level %.0f key %d hidden %d alpha %.2f interaction %d root %s",
                   object_getClassName(window),
                   (double)window.windowLevel,
                   (int)window.isKeyWindow,
                   (int)window.isHidden,
                   window.alpha,
                   (int)window.isUserInteractionEnabled,
                   ProbeClassName(window.rootViewController));
    }
    ProbeLogViewTree(ProbeKeyWindow(), 0);
}

#else

void neUIProbeInstall(void) {
}

void neUIProbeLogController(const char *tag, UIViewController *controller) {
    (void)tag;
    (void)controller;
}

void neUIProbeTraceTransition(const char *tag, UIViewController *controller) {
    (void)tag;
    (void)controller;
}

void neUIProbeLogWindowTree(const char *tag) {
    (void)tag;
}

#endif
