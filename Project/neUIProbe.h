/** @file
 * Runtime UIKit diagnostics for the settings sheet's presentation and navigation.
 *
 * This code is NOT part of the original binary. Every entry point below is an empty inline unless
 * the build defines @c JBDBG (see the JBDBG CMake option and @c neDebugLog.h ), so a faithful
 * build carries none of it and no call site needs an @c \#ifdef .
 *
 * The settings screen fails in a way that reading the source cannot settle: a tap registers, the
 * transition starts, and then nothing further happens. Three different faults produce exactly that
 * and they need different fixes, so the probe is built to tell them apart in one capture:
 *
 *   1. The main thread is blocked. @c neUIProbeInstall arms a watchdog on a background queue that
 *      watches a timestamp only the main run loop updates, so a stall shows up as an explicit
 *      "main run loop idle" line rather than as an absence of lines.
 *   2. UIKit is refusing to deliver events. The heartbeat reports
 *      @c -[UIApplication isIgnoringInteractionEvents] and the key window's interaction flag every
 *      tick, so an unbalanced ignore-interaction pair is visible even while nothing is tapped.
 *   3. Something is swallowing the touch. The window's @c -sendEvent: is traced, reporting the
 *      hit-test view and its ancestor chain for every touch that begins, so a transparent cover
 *      or a stale transition view names itself.
 *
 * Capture with: @c idevicesyslog @c | @c grep @c JBPDBG
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Installs the touch tracer, the main-thread heartbeat, and the run-loop watchdog.
 *
 * Safe to call more than once; only the first call installs. Must be called on the main thread,
 * after the key window exists. Does nothing unless the build defines @c JBDBG .
 */
void neUIProbeInstall(void);

/**
 * @brief Logs one line describing where a view controller currently sits in UIKit's appearance and
 *        transition state machine.
 *
 * Reports the presented/dismissed/moving flags, whether the view is in a window, whether a
 * transition coordinator is running, and the enclosing navigation stack depth. Comparing the line
 * from a working transition with the line from a wedged one is what localises the fault.
 *
 * @param tag A short call-site label, printed verbatim.
 * @param controller The controller to describe. A @c nil controller logs a "nil" line rather than
 *        nothing, so a missing object is distinguishable from a missing call.
 */
void neUIProbeLogController(const char *tag, UIViewController *_Nullable controller);

/**
 * @brief Registers a completion on the controller's current transition coordinator.
 *
 * Call from @c -viewWillAppear: or @c -viewWillDisappear: . The completion logs when the
 * transition ends and, critically, whether it was @b cancelled -- a cancelled transition leaves a
 * navigation controller wedged while every appearance callback still looks normal, and nothing
 * else in a capture distinguishes that from a transition that simply never finished.
 *
 * Logs a line immediately when the controller has no transition coordinator, since an animated
 * transition that reports none is itself the finding.
 *
 * @param tag A short call-site label, printed verbatim.
 * @param controller The controller whose coordinator is traced.
 */
void neUIProbeTraceTransition(const char *tag, UIViewController *controller);

/**
 * @brief Logs every window and, for the key window, its view tree.
 *
 * Each view reports its class, frame, alpha, hidden and user-interaction flags, so a full-screen
 * transparent view that takes every touch is visible as a row in the dump. Bounded in depth and in
 * the number of siblings printed, because the game's own view tree is large.
 *
 * @param tag A short call-site label, printed verbatim.
 */
void neUIProbeLogWindowTree(const char *tag);

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
