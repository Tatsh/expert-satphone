#import "neUIProbe.h"

#import <objc/runtime.h>

#import <CoreFoundation/CoreFoundation.h>
#import <QuartzCore/QuartzCore.h>

#import "neDebugLog.h"

#if JBDBG

#include <dlfcn.h>
#include <mach/mach.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <string.h>

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

// How many consecutive watchdog checks have found the main thread behind. Zero means running. The
// count is what schedules the two stack dumps, and it is reset on recovery so a later stall reports
// again.
static _Atomic unsigned int gStalledChecks;

// The main thread's mach port and the app image's load address, both captured at install so the
// watchdog can inspect the main thread and translate its frames without touching UIKit.
static thread_t gMainMachThread;
static const void *gAppImageBase;

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

// The stack is dumped on the first stalled check and again this many checks later. Two dumps two
// seconds apart is what separates a spin, whose program counter moves, from a deadlock, whose does
// not -- and no single dump can tell those apart.
static const unsigned int kSecondStackDumpCheck = 9;

// The image base every @ghidraAddress in this tree is relative to. A frame inside the app is
// reported in that space as well, so it can be looked up directly against the Ghidra program
// instead of being symbolicated first.
static const uintptr_t kGhidraImageBase = 0x100000000;

static const size_t kMaxBacktraceFrames = 48;

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

#pragma mark - Layout accounting

// Which view classes UIKit is laying out, and which are asking to be laid out again.
//
// A stack sample says where the spin is but not what it is spinning over, and the samples taken so
// far are all inside UIKit with no frame of this tree above main. Counting layout by class answers
// the remaining question directly: during a hang the count of whatever is looping runs away, and
// the delta between two samples names it.
//
// -layoutSublayersOfLayer: is the hook rather than -layoutSubviews because it is the entry point
// UIKit itself calls on every view it lays out. A UIView subclass that overrides -layoutSubviews
// without chaining to super would slip past a hook on that; almost none override this one.

enum { kLayoutTableSize = 512 };

// A class object outlives the process, so the tables hold unretained references. ARC also refuses
// an object array parameter without an explicit ownership qualifier, and this is the one that says
// what is meant: the table observes classes, it does not own them.
typedef __unsafe_unretained Class ProbeClassRef;

static ProbeClassRef gLayoutClasses[kLayoutTableSize];
static _Atomic uint64_t gLayoutCounts[kLayoutTableSize];
static uint64_t gLayoutSnapshot[kLayoutTableSize];

static ProbeClassRef gDirtyClasses[kLayoutTableSize];
static _Atomic uint64_t gDirtyCounts[kLayoutTableSize];
static uint64_t gDirtySnapshot[kLayoutTableSize];

// How many classes each report names, most active first.
static const size_t kLayoutReportRows = 10;

static void (*gOriginalLayoutSublayers)(UIView *, SEL, CALayer *);
static void (*gOriginalSetNeedsLayout)(UIView *, SEL);

// Open addressing on the class pointer. Only the main thread writes, and the watchdog only reads,
// so a torn read costs at worst one mis-named row in a diagnostic report.
static void
ProbeCountInTable(ProbeClassRef classes[], _Atomic uint64_t counts[], ProbeClassRef subject) {
    size_t home = ((uintptr_t)subject >> 4) % kLayoutTableSize;
    for (size_t probe = 0; probe < kLayoutTableSize; ++probe) {
        size_t slot = (home + probe) % kLayoutTableSize;
        ProbeClassRef occupant = classes[slot];
        if (occupant == subject || occupant == nil) {
            classes[slot] = subject;
            atomic_fetch_add_explicit(&counts[slot], 1, memory_order_relaxed);
            return;
        }
    }
}

static void ProbeLayoutSublayersOfLayer(UIView *view, SEL selector, CALayer *layer) {
    ProbeCountInTable(gLayoutClasses, gLayoutCounts, object_getClass(view));
    gOriginalLayoutSublayers(view, selector, layer);
}

static void ProbeSetNeedsLayout(UIView *view, SEL selector) {
    ProbeCountInTable(gDirtyClasses, gDirtyCounts, object_getClass(view));
    gOriginalSetNeedsLayout(view, selector);
}

static void ProbeSnapshotLayout(void) {
    for (size_t slot = 0; slot < kLayoutTableSize; ++slot) {
        gLayoutSnapshot[slot] = atomic_load_explicit(&gLayoutCounts[slot], memory_order_relaxed);
        gDirtySnapshot[slot] = atomic_load_explicit(&gDirtyCounts[slot], memory_order_relaxed);
    }
}

// Reports the classes whose counts grew most since the snapshot. A hang whose layout counts are
// all zero is a hang that is not laying anything out, which is as useful an answer as a name.
static void ProbeReportLayoutDeltas(const char *tag,
                                    const char *what,
                                    ProbeClassRef classes[],
                                    _Atomic uint64_t counts[],
                                    uint64_t snapshot[]) {
    for (size_t row = 0; row < kLayoutReportRows; ++row) {
        uint64_t best = 0;
        size_t bestSlot = kLayoutTableSize;
        for (size_t slot = 0; slot < kLayoutTableSize; ++slot) {
            if (classes[slot] == nil) {
                continue;
            }
            uint64_t now = atomic_load_explicit(&counts[slot], memory_order_relaxed);
            uint64_t delta = (now > snapshot[slot]) ? (now - snapshot[slot]) : 0;
            if (delta > best) {
                best = delta;
                bestSlot = slot;
            }
        }
        if (best == 0 || bestSlot >= kLayoutTableSize) {
            if (row == 0) {
                neDebugLog("probe %s %s: none", what, tag);
            }
            return;
        }
        neDebugLog("probe %s %s: %s x%llu",
                   what,
                   tag,
                   class_getName(classes[bestSlot]),
                   (unsigned long long)best);
        // Raising this row's snapshot to its current count consumes it, so the next pass finds the
        // next-largest instead of the same one again.
        snapshot[bestSlot] = atomic_load_explicit(&counts[bestSlot], memory_order_relaxed);
    }
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

#pragma mark - Main-thread backtrace

// Pointer authentication signs return addresses in arm64e system code, and the signature occupies
// the unused high bits, so masking them off yields the real address on arm64 and arm64e alike.
static uintptr_t ProbeStripPointer(uintptr_t address) {
    return address & 0x0000ffffffffffffULL;
}

// Copies the main thread's program counters into the caller's buffer and returns how many were
// recovered.
//
// The thread is suspended only for the copy. Symbolication happens afterwards, in
// ProbeLogBacktrace, because dladdr takes the dynamic linker's lock: resolving a symbol while the
// main thread is suspended holding that same lock would deadlock the process this is meant to
// diagnose.
static size_t ProbeCaptureMainBacktrace(uintptr_t *frames, size_t maxFrames) {
#if !defined(__arm64__)
    // The frame walk reads arm64 thread state, so a simulator build simply reports no stack rather
    // than failing to compile.
    (void)frames;
    (void)maxFrames;
    return 0;
#else
    if (gMainMachThread == MACH_PORT_NULL || maxFrames < 2) {
        return 0;
    }
    if (thread_suspend(gMainMachThread) != KERN_SUCCESS) {
        return 0;
    }
    size_t count = 0;
    arm_thread_state64_t state;
    mach_msg_type_number_t stateCount = ARM_THREAD_STATE64_COUNT;
    if (thread_get_state(
            gMainMachThread, ARM_THREAD_STATE64, (thread_state_t)&state, &stateCount) ==
        KERN_SUCCESS) {
        frames[count++] = ProbeStripPointer(__darwin_arm_thread_state64_get_pc(state));
        uintptr_t linkRegister = ProbeStripPointer(__darwin_arm_thread_state64_get_lr(state));
        if (linkRegister != 0) {
            frames[count++] = linkRegister;
        }
        uintptr_t framePointer = ProbeStripPointer(__darwin_arm_thread_state64_get_fp(state));
        // Each frame record is {saved frame pointer, return address}. The chain must climb and stay
        // aligned; anything else means the stack is exhausted or the walk has gone astray, and
        // following it further would fault inside a suspended-thread window.
        while (count < maxFrames && framePointer != 0 && (framePointer & 0xf) == 0) {
            const uintptr_t *record = (const uintptr_t *)framePointer;
            uintptr_t nextPointer = ProbeStripPointer(record[0]);
            uintptr_t returnAddress = ProbeStripPointer(record[1]);
            if (returnAddress == 0) {
                break;
            }
            frames[count++] = returnAddress;
            if (nextPointer <= framePointer) {
                break;
            }
            framePointer = nextPointer;
        }
    }
    thread_resume(gMainMachThread);
    return count;
#endif
}

static void ProbeLogBacktrace(const char *tag) {
    uintptr_t frames[kMaxBacktraceFrames];
    size_t count = ProbeCaptureMainBacktrace(frames, kMaxBacktraceFrames);
    if (count == 0) {
        neDebugLog("probe stack %s: unavailable", tag);
        return;
    }
    for (size_t index = 0; index < count; ++index) {
        Dl_info info;
        if (dladdr((const void *)frames[index], &info) == 0 || info.dli_fname == nullptr) {
            neDebugLog("probe stack %s: %2zu 0x%lx", tag, index, (unsigned long)frames[index]);
            continue;
        }
        const char *slash = strrchr(info.dli_fname, '/');
        const char *image = slash ? slash + 1 : info.dli_fname;
        uintptr_t imageOffset = frames[index] - (uintptr_t)info.dli_fbase;
        const char *symbol = info.dli_sname ? info.dli_sname : "?";
        if (info.dli_fbase == gAppImageBase) {
            neDebugLog("probe stack %s: %2zu %s +0x%lx ghidra 0x%lx %s",
                       tag,
                       index,
                       image,
                       (unsigned long)imageOffset,
                       (unsigned long)(kGhidraImageBase + imageOffset),
                       symbol);
        } else {
            neDebugLog("probe stack %s: %2zu %s +0x%lx %s",
                       tag,
                       index,
                       image,
                       (unsigned long)imageOffset,
                       symbol);
        }
    }
}

// Runs on the watchdog queue, never on the main thread, so it still reports while the main thread
// is wedged. That is the whole point: a blocked main thread otherwise shows up only as an absence
// of log lines, which is indistinguishable from the user simply not touching the screen.
static void ProbeWatchdogCheck(void) {
    uint64_t last = atomic_load_explicit(&gLastRunLoopTickMilliseconds, memory_order_relaxed);
    uint64_t now = ProbeNowMilliseconds();
    uint64_t idle = (now > last) ? (now - last) : 0;
    if (idle >= kStallThresholdMilliseconds) {
        unsigned int checks =
            atomic_fetch_add_explicit(&gStalledChecks, 1, memory_order_relaxed) + 1;
        if (checks == 1) {
            neDebugLog("probe watchdog: MAIN RUN LOOP STALLED, idle %llu ms, mode %s",
                       (unsigned long long)idle,
                       ProbeMainRunLoopMode());
            ProbeLogBacktrace("stall1");
            // The baseline for the layout report below. Taken after the first stack dump so the
            // window it measures lies wholly inside the hang.
            ProbeSnapshotLayout();
        } else if (checks == kSecondStackDumpCheck) {
            neDebugLog("probe watchdog: still stalled, idle %llu ms", (unsigned long long)idle);
            ProbeLogBacktrace("stall2");
            ProbeReportLayoutDeltas(
                "stall", "layout", gLayoutClasses, gLayoutCounts, gLayoutSnapshot);
            ProbeReportLayoutDeltas("stall", "dirty", gDirtyClasses, gDirtyCounts, gDirtySnapshot);
        }
        return;
    }
    if (atomic_exchange_explicit(&gStalledChecks, 0, memory_order_relaxed) != 0) {
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

    // Captured here because this runs on the main thread; the watchdog cannot obtain either later.
    gMainMachThread = pthread_mach_thread_np(pthread_self());
    Dl_info selfInfo;
    if (dladdr((const void *)(uintptr_t)&neUIProbeInstall, &selfInfo) != 0) {
        gAppImageBase = selfInfo.dli_fbase;
    }

    Method sendEvent = class_getInstanceMethod(UIWindow.class, @selector(sendEvent:));
    gOriginalWindowSendEvent =
        (void (*)(UIWindow *, SEL, UIEvent *))method_getImplementation(sendEvent);
    method_setImplementation(sendEvent, (IMP)ProbeWindowSendEvent);

    Method layoutSublayers =
        class_getInstanceMethod(UIView.class, @selector(layoutSublayersOfLayer:));
    gOriginalLayoutSublayers =
        (void (*)(UIView *, SEL, CALayer *))method_getImplementation(layoutSublayers);
    method_setImplementation(layoutSublayers, (IMP)ProbeLayoutSublayersOfLayer);

    Method setNeedsLayout = class_getInstanceMethod(UIView.class, @selector(setNeedsLayout));
    gOriginalSetNeedsLayout = (void (*)(UIView *, SEL))method_getImplementation(setNeedsLayout);
    method_setImplementation(setNeedsLayout, (IMP)ProbeSetNeedsLayout);

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
