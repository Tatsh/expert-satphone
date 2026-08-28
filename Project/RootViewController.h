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
 * @brief Builds the controller and its two persistent child screens.
 *
 * Allocates the game and edit view controllers once and keeps them as children for the whole
 * lifetime, registers the three application-state observers, and builds the achievement-message
 * overlay with this controller as its delegate.
 * @return The initialised controller.
 * @ghidraAddress 0x1a751c
 */
- (instancetype)init;

/**
 * @brief Runs a named cross-fade and hands the name to the transition dispatcher.
 *
 * Blocks input, parks both durations in ivars, builds a fresh full-screen black cover, and fades it
 * in over @p durationIn. The name is passed to @c +[UIView beginAnimations:context:] and comes back
 * to @c -fadeoutAnimStop:finished:context:, which is what decides which screens to tear down and
 * build; this method is only the visual half.
 *
 * @param animationName The transition to run once the screen is black.
 * @param inDuration How long the fade to black takes.
 * @param outDuration How long the fade back takes. Not used here — it is stored for the second
 * half.
 * @ghidraAddress 0x1a7770
 */
- (void)fade:(NSString *)animationName
     durationIn:(double)inDuration
    durationOut:(double)outDuration;
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
               finished:(nullable NSNumber *)finished
                context:(nullable void *)context;
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
              finished:(nullable NSNumber *)finished
               context:(nullable void *)context;
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
 * @brief Finishes the slide into the store screen.
 *
 * The store transition does not go through @c -fade:durationIn:durationOut: at all. It rotates the
 * root view's sublayer transform in 3-D and rasterises both layers for the duration, so this
 * callback restores @c CATransform3DIdentity, clears both @c shouldRasterize flags, drops the
 * music-select screen, and asks the store to load.
 *
 * @param animationID Never read.
 * @param finished Never read.
 * @param context Never read.
 * @ghidraAddress 0x1a81b4
 */
- (void)openStoreAnimStop:(NSString *)animationID
                 finished:(nullable NSNumber *)finished
                  context:(nullable void *)context;
/**
 * @brief Finishes the slide back out of the store screen.
 *
 * The mirror of @c -openStoreAnimStop:finished:context:, with two differences worth knowing: input
 * is released first here rather than last, and on the way back only a pending chart download is
 * acted on — the store and notification cases the fade-in dispatcher handles are absent.
 *
 * @param animationID Never read.
 * @param finished Never read.
 * @param context Never read.
 * @ghidraAddress 0x1a8d7c
 */
- (void)endStoreAnimStop:(NSString *)animationID
                finished:(nullable NSNumber *)finished
                 context:(nullable void *)context;

/**
 * @brief Slides the store screen in over music select with a 3-D cube-flip.
 *
 * Blocks input, marks the scene @c SceneStore , clears the image cache, fades out the BGM, and then
 * flips the store in about the Y axis while music select rotates out the far side. The rotation is
 * driven by the pre-iOS-4 begin/commit animation API; @c -openStoreAnimStop:finished:context: is
 * what finishes it.
 * @param startupParameters The parameters the store screen is opened with.
 * @ghidraAddress 0x1a7b58
 */
- (void)openStore:(nullable id)startupParameters;
/**
 * @brief Slides the store screen back out, flipping a fresh music-select screen in.
 *
 * The mirror of @c -openStore: : it does not set the scene identifier, stops the BGM outright
 * rather than fading it, and asks the store to close before the flip. @c
 * -endStoreAnimStop:finished:context: finishes it.
 * @ghidraAddress 0x1a8430
 */
- (void)endStore;

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
 * @brief Takes the logo screen back down and starts the Game Center login.
 *
 * Fades the logo out over 0.5 and back in over 1.0 through @c -fade:durationIn:durationOut: with
 * "AnimTitle", then sends @c -loginGameCenter to the delegate. Called by
 * @c -[LogoViewController end:] once the splash animation has finished or been skipped.
 * @ghidraAddress 0x1a7ad8
 */
- (void)endLogo;
/**
 * @brief Fades from the title screen into the music-select screen.
 *
 * A single @c -fade:durationIn:durationOut: with "AnimSelect", 1.5, and 0.5.
 * @ghidraAddress 0x1a7b3c
 */
- (void)endTitle;
/**
 * @brief Restarts the current tune, keeping its audio and textures.
 *
 * A single @c -fade:durationIn:durationOut: with "AnimGameRestart", 1.0, and 0.5.
 * @ghidraAddress 0x1a925c
 */
- (void)musicRestart;
/**
 * @brief Replays the current tune, keeping its audio and textures.
 *
 * A single @c -fade:durationIn:durationOut: with "AnimGameReplay", 1.0, and 0.5.
 * @ghidraAddress 0x1a9278
 */
- (void)musicReplay;
/**
 * @brief Returns from the game to the music-select screen.
 *
 * A single @c -fade:durationIn:durationOut: with "AnimReturnMusicSelect", 1.0, and 0.5.
 * @ghidraAddress 0x1a9294
 */
- (void)returnToMusicSelect;
/**
 * @brief Starts a tune on the game screen and fades into it.
 *
 * Flushes user defaults, pushes the tune, the current difficulty (@c PrefDifficulty ), and the
 * current marker (@c PrefCurrentMarkerID ) into the game screen, wires up the share manager when
 * one is supplied, sets the music data when supplied, then fades in with "AnimStartGame".
 * @param tune The tune to play.
 * @param shareManager The score-share manager, or nil.
 * @param musicData The music data, or nil.
 * @ghidraAddress 0x1a90bc
 */
- (void)startMainGame:(nullable id)tune
         shareManager:(nullable id)shareManager
            musicData:(nullable id)musicData;
/**
 * @brief Starts editing a tune on the note editor and fades into it.
 *
 * The mirror of @c -startMainGame:shareManager:musicData: without a share manager. It takes a
 * @p jcfName but never reads it, then fades in with "AnimStartEdit".
 * @param tune The tune to edit.
 * @param musicData The music data, or nil.
 * @param jcfName The custom-sequence name. Never read.
 * @ghidraAddress 0x1a92b0
 */
- (void)startEditNote:(nullable id)tune
            musicData:(nullable id)musicData
              jcfName:(nullable id)jcfName;
/**
 * @brief Shows the achievement-message overlay with the given title.
 *
 * Forwards @p title to the overlay's @c -setAchieveTitle: , resets its transform, starts its enter
 * animation, and adds it to the root view.
 * @param title The achievement title to display.
 * @ghidraAddress 0x1ab008
 */
- (void)openAchiveMessage:(nullable id)title;
/**
 * @brief Removes the achievement-message overlay.
 *
 * Resets the overlay's transform and removes it from its superview.
 * @ghidraAddress 0x1ab094
 */
- (void)messageClose;
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

/**
 * @brief Dismisses any alert and suspends the visible game or edit screen as the app deactivates.
 *
 * Closes the shared alert, clears @c _isActive so a transition arriving now parks its name rather
 * than running, and sends @c -suspend to the game and edit controllers only while their view is a
 * direct subview of the root view.
 *
 * @param notification The deactivation notification. Never read.
 * @ghidraAddress 0x1aab40
 */
- (void)appWillResignActive:(nullable NSNotification *)notification;
/**
 * @brief Resumes activity: runs any parked transition, then the three auto-move checks.
 *
 * Sets @c _isActive , runs the transition parked in @c suspendedAnimID (clearing it first), kicks
 * off the custom-sequence download and the challenge and pack auto-moves, and resumes the visible
 * game or edit screen.
 *
 * @param notification The activation notification. Never read.
 * @ghidraAddress 0x1aacc8
 */
- (void)appDidBecomeActive:(nullable NSNotification *)notification;
/**
 * @brief Flushes user defaults and terminates the game and edit screens as the app quits.
 *
 * @param notification The termination notification. Never read.
 * @ghidraAddress 0x1aae84
 */
- (void)appWillTerminate:(nullable NSNotification *)notification;

/**
 * @brief Returns from the note editor to the music-select screen.
 *
 * A single @c -fade:durationIn:durationOut: with "AnimEndEdit", 1.0, and 0.5.
 * @ghidraAddress 0x1a9404
 */
- (void)returnFromEdit;
/**
 * @brief Acts on a pending custom-sequence download for whichever screen is up.
 *
 * Returns immediately when the delegate has no @c jcfDownloadID . The logo and title screens ignore
 * it; the select screen resumes the download itself; the game and edit screens are sent @c -end ;
 * the store screen backs out through @c -endStore .
 * @ghidraAddress 0x1aa4a4
 */
- (void)downloadCustomSequence;
/**
 * @brief Consumes a queued challenge-open request for whichever screen is up.
 *
 * Returns immediately unless the delegate's @c bChallengeOpen is set. The store screen backs out
 * through @c -endStore ; the select and edit screens drop the flag; every other screen leaves it
 * set.
 * @ghidraAddress 0x1aa60c
 */
- (void)autoMoveChallenge;
/**
 * @brief Acts on a queued store pack, campaign, or genre for whichever screen is up.
 *
 * Returns immediately when the delegate has no queued store identifier. The logo and title screens
 * ignore it; the select screen forwards to the store through @c -schemeMoveStore ; the game and
 * edit screens are sent @c -end ; the store screen opens the queued item directly, preferring a
 * pack over a campaign over a genre, and clears whichever it used.
 * @ghidraAddress 0x1aa71c
 */
- (void)autoMovePackDownload;

/**
 * @brief Whether a scene is up and transitions run immediately; when clear, a transition parks its
 *        name in @c suspendedAnimID instead. Backed by the @c _isActive ivar.
 * @ghidraAddress 0x1ab3f8
 */
@property(nonatomic, readonly, getter=isActive) BOOL active;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
