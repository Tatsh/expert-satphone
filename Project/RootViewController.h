/** @file
 * The application's root view controller.
 *
 * Reconstructed from Ghidra program Jubeat (class RootViewController, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: grown outwards from its callers. Only the members reached so far are
 * declared; the class is much larger than this.
 */

#import <UIKit/UIKit.h>

@class MusicSelectViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Hosts the game's screens and owns the music-select controller it presents.
 */
@interface RootViewController : UIViewController

/**
 * @brief The presented music-select screen.
 *
 * Backed by @c musicSelectViewCtrl (offset global 0x34b78c). The concrete class is not established;
 * see TYPES_PENDING.md.
 */
@property(nonatomic, readonly, nullable) UIViewController *musicSelectViewCtrl;

/**
 * @brief Runs a named cross-fade. DECLARED ONLY.
 */
- (void)fade:(NSString *)animationName
     durationIn:(double)durationIn
    durationOut:(double)durationOut;

/**
 * @brief Dismisses the music-select screen and returns to the title under the new theme.
 *
 * Branches on @c JubeatAppDelegate.appDelegate.isPad, and the two arms differ in ordering rather
 * than in effect: the iPad arm dismisses with a nil completion and then runs the fade itself, while
 * the other arm passes a completion block that runs the identical fade. Both end up calling
 * @c -fade:durationIn:durationOut: with "AnimChangeTheme", 0.6, and 1.0.
 *
 * The 0.6 is a @c float widened to @c double — the pool holds 0x3FE3333340000000, which is 0.6f
 * promoted, not the closest double to 0.6.
 * @ghidraAddress 0x1a8a68
 */
- (void)changeThemeAndGoTitle;
/**
 * @brief Refreshes the title screen for the current theme or event.
 *
 * A single tail call to @c -fade:durationIn:durationOut: with "AnimTitleSwitch" and 1.5 for both
 * durations. Nothing is dismissed.
 * @ghidraAddress 0x1a8bb4
 */
- (void)changeTitleTheme;
/**
 * @brief Rebuilds the marker list.
 *
 * A single tail call forwarding to @c -reloadMarkerSelectView on @c musicSelectViewCtrl. Nothing
 * guards against that being nil; a nil receiver simply makes the call a no-op.
 * @ghidraAddress 0x1a8d64
 */
- (void)reloadMarkers;
/**
 * @brief Presents the notification the delegate has just queued.
 *
 * RECONSTRUCTION STATE: declared because @c -[JubeatAppDelegate
 * application:didReceiveLocalNotification:] sends it on the foreground path; the body is not
 * reconstructed yet.
 * @ghidraAddress 0x1aaaa4
 */
- (void)pushNotificate;
/**
 * @brief Reports a remote notification back to the server.
 *
 * RECONSTRUCTION STATE: declared because both remote-notification entry points send it; the body is
 * not reconstructed yet.
 *
 * The body at 0x1ab0d4 POSTs a three-entry JSON dictionary — @c "user_id" from
 * @c +[EditorIDManager getEditorIDKey], @c "push_id" from the payload's @c "id" entry, and
 * @c "status" — to @c +[ScratchUtil pushNotificationResponseURL] through @c Downloader.
 *
 * @param launchedFromNotification Whether the notification started the application rather than
 *        arriving at a running one. The @c tbz at 0x1ab1e8 tests bit 0 and turns it into the
 *        @c "status" value: 1 when set, 2 when clear.
 * @param pushInfo The notification payload, used only for its @c "id" entry.
 * @ghidraAddress 0x1ab0d4
 */
- (void)responseRemoteNotification:(BOOL)launchedFromNotification pushInfo:(NSDictionary *)pushInfo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
