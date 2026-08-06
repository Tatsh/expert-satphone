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

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Hosts the game's screens and owns the music-select controller it presents.
 *
 * The eight ivars reached so far sit at offset globals 0x34b770 to 0x34b794. Not one of them has an
 * accessor pair anywhere in the binary, so they are all declared in a class extension rather than
 * exposed here.
 */
@interface RootViewController : UIViewController

/**
 * @brief Runs a named cross-fade and hands the name to the transition dispatcher.
 *
 * Blocks input, parks both durations in ivars, builds a fresh full-screen black cover, and fades it
 * in over @p durationIn. The name is passed to @c +[UIView beginAnimations:context:] and comes back
 * to @c -fadeoutAnimStop:finished:context:, which is what decides which screens to tear down and
 * build; this method is only the visual half.
 *
 * @param animationName The transition to run once the screen is black.
 * @param durationIn How long the fade to black takes.
 * @param durationOut How long the fade back takes. Not used here — it is stored for the second
 * half.
 * @ghidraAddress 0x1a7770
 */
- (void)fade:(NSString *)animationName
     durationIn:(double)durationIn
    durationOut:(double)durationOut;
/**
 * @brief Swaps the screens for the transition just faded out, then fades back in.
 *
 * The transition dispatcher, and the largest method in the class at roughly 1.5 KB. It branches on
 * the animation name across nine transitions, tears down the outgoing screen, builds the incoming
 * one, and then starts the fade back in over @c durationOut. When @c _isActive is clear it does
 * none of that and parks the name in @c suspendedAnimID instead.
 *
 * Two things about it are worth knowing before reading the body. A game restart or replay keeps its
 * audio and textures where every other transition drops both, which is what makes those two cheap.
 * And an animation name matching none of the nine still runs the fade back in, so an unknown
 * transition leaves the screen unchanged rather than stuck black.
 *
 * @param animationID The transition name @c -fade:durationIn:durationOut: was given.
 * @param finished Never read.
 * @param context Never read.
 * @ghidraAddress 0x1a9420
 */
- (void)fadeoutAnimStop:(NSString *)animationID
               finished:(NSNumber *)finished
                context:(void *)context;
/**
 * @brief Finishes a transition once the screen has faded back in.
 *
 * Records which scene is now up, wakes the screen just revealed, tears the black cover down, runs
 * whatever the delegate parked while another screen was in front, and finally lifts the input block
 * that @c -fade:durationIn:durationOut: put in place. That last step is reached on every path,
 * including an unrecognised animation name, so input cannot be left disabled.
 *
 * @param animationID The transition that has just finished fading back in.
 * @param finished Never read.
 * @param context Never read.
 * @ghidraAddress 0x1a9fec
 */
- (void)fadeinAnimStop:(NSString *)animationID
              finished:(NSNumber *)finished
               context:(void *)context;
/**
 * @brief Builds the knit-theme title screen into @c titleViewCtrl.
 *
 * Unlike the other two themes, which allocate their controller inline, the knit theme is delegated
 * to this factory because it picks between two classes: @c TitleViewControllerNte when the delegate
 * reports @c isNagaCoraMode, and @c TitleViewControllerKnt otherwise. @c isHinabitaMode is tested
 * first and short circuits to the knit screen, so the hinabita collaboration wins when both flags
 * are set.
 * @ghidraAddress 0x1a743c
 */
- (void)createKnitTitleViewController;
/**
 * @brief Re-runs the title screen's own switch animation.
 *
 * Replaces whatever title screen is up with a @c TitleViewControllerKnt. The outgoing screen is
 * sent @c -stopAnimation only when it is a @c TitleViewControllerNte, which makes this a class test
 * rather than a nil guard, and the incoming one is always the knit screen — this transition only
 * ever switches towards it, never away.
 * @ghidraAddress 0x1a8bd0
 */
- (void)titleSwitch;

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
 * @brief Presents the notification the delegate has just queued, if the select screen is up.
 *
 * Forwards to the identically named selector on @c musicSelectViewCtrl, but only when
 * @c currentSceneID is "SceneSelect" and that controller is non-nil. A notification arriving on any
 * other screen is therefore queued by the delegate and never shown by this path.
 * @ghidraAddress 0x1aaaa4
 */
- (void)pushNotificate;
/**
 * @brief Installs the logo screen as a child and starts it.
 *
 * The last thing @c -[JubeatAppDelegate application:didFinishLaunchingWithOptions:] does to the UI.
 * Builds a @c LogoViewController, adds it as a child, adds its view, sends it @c -start, and then
 * sets @c currentSceneID to "SceneLogo".
 * @ghidraAddress 0x1a79d4
 */
- (void)startLogo;
/**
 * @brief Reports a remote notification back to the server.
 *
 * POSTs a three-entry JSON dictionary — @c "user_id" from
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
