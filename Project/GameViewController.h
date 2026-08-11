/** @file
 * The in-game (play) top-level view controller.
 *
 * Reconstructed from Ghidra program Jubeat (class GameViewController, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController : every @c super call in the class (init, loadView, the
 * lifecycle hooks, and dealloc) targets @c UIViewController . The controller owns the OpenGL view
 * ( @c EAGLView ) and, per device idiom and current theme, one of the @c MainGameRenderer family
 * ( @c MainGameRendererPad / @c MainGameRendererPhone and their @c ...Rpl ripples and @c ...Knt
 * knit-theme variants), the note-judgement @c Sequence , the per-frame @c CADisplayLink driving
 * @c loop: , the pause overlay ( @c GamePauseView ), and the local-multiplayer session manager
 * ( @c SharePlayManager ). It records and replays touch "ghosts", uploads challenge scores, drives
 * the good-job / Twitter share buttons, and hosts the jubeat-lab pack-ID search overlay.
 */

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#import "GamePauseView.h"
#import "SharePlayManager.h"

@class CADisplayLink;
@class EAGLView;
@class MainGameRenderer;
@class NSData;
@class Sequence;
@class TuneInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The in-game play view controller.
 */
@interface GameViewController : UIViewController <UIPopoverControllerDelegate,
                                                  GamePauseViewDelegate,
                                                  SharePlayManagerDelegate>

/**
 * @brief Initialises the controller: reads the saved adjust-sector offset, resolves the device
 *        idiom, builds the screen-sized @c EAGLView , and clears the per-session flags.
 * @return The initialised controller.
 * @ghidraAddress 0xfc10
 */
- (instancetype)init;

/**
 * @brief The current BGM playback position, less the adjust-time offset, clamped to zero.
 * @return The adjusted music time in seconds.
 * @ghidraAddress 0xfe80
 */
- (double)getMusicTime;

/**
 * @brief Builds a theme-prefixed sound-effect resource name.
 * @param name The sound-effect base name.
 * @return The theme-prefixed name.
 * @ghidraAddress 0xfef8
 */
- (nullable NSString *)soundName:(nullable NSString *)name;

/**
 * @brief Installs the OpenGL view, the pause button, and the replay / replay-pause buttons.
 * @ghidraAddress 0xffe8
 */
- (void)loadView;

/**
 * @brief Builds the renderer for the current idiom and theme, decrypts the chart archive into a
 *        @c Sequence and its textures, lays out the pause and replay buttons, and prepares the
 *        pause overlay, item-chance renderer, gesture surface, and best-score baseline.
 * @ghidraAddress 0x102a4
 */
- (void)loadResources;

/**
 * @brief Tears down the renderer, sequence, framebuffer, audio, overlays, and pending network
 *        requests.
 * @ghidraAddress 0x11d94
 */
- (void)releaseResources;

/**
 * @brief Persists the play result to the score records and, in challenge mode, the item-chance
 *        state.
 * @ghidraAddress 0x121f8
 */
- (void)saveScore;

/**
 * @brief Starts the per-frame display link that drives @c loop: .
 * @ghidraAddress 0x12d64
 */
- (void)startAnimation;

/**
 * @brief Stops and releases the per-frame display link.
 * @ghidraAddress 0x12f8c
 */
- (void)stopAnimation;

/**
 * @brief BGM-finished notification: clears the playing flag and drops the observer.
 * @param notification The finish notification.
 * @ghidraAddress 0x13020
 */
- (void)finishMusic:(nullable NSNotification *)notification;

/**
 * @brief The display-link callback: reads touches, advances the sequence, drives the state machine,
 *        records or replays ghosts, and draws a frame.
 * @param displayLink The display link that fired.
 * @ghidraAddress 0x13088
 */
- (void)loop:(nullable CADisplayLink *)displayLink;

/**
 * @brief Begins a fresh play: resets the adjust offset, sequence, ghost recording, renderer state,
 *        and button-touch width.
 * @ghidraAddress 0x16264
 */
- (void)startGame;

/**
 * @brief Begins a replay of the just-finished play against the recorded ghost.
 * @ghidraAddress 0x16514
 */
- (void)replayGame;

/**
 * @brief Restarts the play from the top, or replays when already replaying.
 * @ghidraAddress 0x167b4
 */
- (void)restartGame;

/**
 * @brief Replay button: saves the score (and reports it to Game Center or the editor), then asks
 *        the root controller to replay the tune.
 * @param sender The replay button.
 * @ghidraAddress 0x16b24
 */
- (void)pushBtnReplay:(nullable id)sender;

/**
 * @brief Replay-mode pause button: plays the menu SE, stops animation and BGM, and shows the pause
 *        overlay.
 * @param sender The replay-pause button.
 * @ghidraAddress 0x16eb4
 */
- (void)pushBtnReplayPause:(nullable id)sender;

/**
 * @brief Pause button: plays the menu SE, stops animation and BGM, and shows the pause overlay.
 * @param sender The pause button.
 * @ghidraAddress 0x16ff8
 */
- (void)pushBtnPause:(nullable id)sender;

/**
 * @brief Pause-overlay restart callback: asks the root controller to restart the tune.
 * @ghidraAddress 0x1713c
 */
- (void)restartInPauseView;

/**
 * @brief Pause-overlay resume callback: resumes animation and BGM when still active.
 * @ghidraAddress 0x171a4
 */
- (void)resumeInPauseView;

/**
 * @brief Pause-overlay end callback: confirms in challenge mode, otherwise returns to music select.
 * @ghidraAddress 0x1728c
 */
- (void)endInPauseView;

/**
 * @brief Dismisses the controller, drops the BGM observer, and returns to music select.
 * @ghidraAddress 0x17488
 */
- (void)end;

/**
 * @brief Ends the local-multiplayer session, optionally showing a disconnect notice.
 * @param showAlert Whether to show the disconnect alert.
 * @ghidraAddress 0x1754c
 */
- (void)sessionDisconnect:(BOOL)showAlert;

/**
 * @brief Removes the evaluation overlay and its cover view immediately.
 * @ghidraAddress 0x17840
 */
- (void)removeEvaluate;

/**
 * @brief Fades out the evaluation overlay and its cover, removing them when the fade completes.
 * @param sender The dismiss trigger.
 * @ghidraAddress 0x178a8
 */
- (void)closeEvaluate:(nullable id)sender;

/**
 * @brief @c SharePlayManager disconnect notice: ends the session with an alert.
 * @param manager The reporting manager.
 * @ghidraAddress 0x17b00
 */
- (void)sharePlayManagerDisconnect:(nullable SharePlayManager *)manager;

/**
 * @brief @c SharePlayManager client-disconnect notice: ends the session with an alert.
 * @param manager The reporting manager.
 * @param client The disconnected client.
 * @ghidraAddress 0x17b10
 */
- (void)sharePlayManager:(nullable SharePlayManager *)manager disconnectClient:(nullable id)client;

/**
 * @brief @c SharePlayManager failure notice: ends the session with an alert.
 * @param manager The reporting manager.
 * @ghidraAddress 0x17b20
 */
- (void)sharePlayManagerFailWithError:(nullable SharePlayManager *)manager;

/**
 * @brief @c SharePlayManager all-clients-loaded notice: starts the synchronised play.
 * @param manager The reporting manager.
 * @ghidraAddress 0x17b30
 */
- (void)sharePlayManagerAllClientLoaded:(nullable SharePlayManager *)manager;

/**
 * @brief @c SharePlayManager play-start notice: schedules the renderer to enter the playing state
 *        at the agreed music time.
 * @param manager The reporting manager.
 * @param musicTime The agreed music start time.
 * @ghidraAddress 0x17b70
 */
- (void)sharePlayManager:(nullable SharePlayManager *)manager startMusicTime:(float)musicTime;

/**
 * @brief @c SharePlayManager music-start-timeout notice. The shipped body is empty.
 * @param manager The reporting manager.
 * @ghidraAddress 0x17d34
 */
- (void)sharePlayManagerMusicStartTimeOut:(nullable SharePlayManager *)manager;

/**
 * @brief @c SharePlayManager partner-score update.
 * @param manager The reporting manager.
 * @param score The partner's current score.
 * @ghidraAddress 0x17d38
 */
- (void)sharePlayManager:(nullable SharePlayManager *)manager receiveScore:(int)score;

/**
 * @brief @c SharePlayManager partner-final-result: applies the partner's final score and ends.
 * @param manager The reporting manager.
 * @param score The partner's final score.
 * @param bonus The partner's final bonus.
 * @param fullCombo Whether the partner achieved a full combo.
 * @ghidraAddress 0x17d80
 */
- (void)sharePlayManager:(nullable SharePlayManager *)manager
       receiveFinalScore:(int)score
                   bonus:(int)bonus
               fullCombo:(BOOL)fullCombo;

/**
 * @brief Suspends the play when backgrounded, stopping animation, BGM, and the session per state.
 * @ghidraAddress 0x17ea8
 */
- (void)suspend;

/**
 * @brief Resumes the play when foregrounded, restarting animation or showing the pause overlay per
 *        state.
 * @ghidraAddress 0x18038
 */
- (void)resume;

/**
 * @brief Fully stops the play: stops BGM and animation, clears the framebuffer, and resets the
 *        renderer.
 * @ghidraAddress 0x1833c
 */
- (void)terminate;

/**
 * @brief Forwards the memory warning to @c super .
 * @ghidraAddress 0x18474
 */
- (void)didReceiveMemoryWarning;

/**
 * @brief Tears down the OpenGL view and the buttons on view unload.
 * @ghidraAddress 0x184ac
 */
- (void)viewDidUnload;

/**
 * @brief Forwards to @c super .
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x186e8
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * @brief Forwards to @c super .
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x18720
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * @brief Forwards to @c super .
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x18758
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * @brief Forwards to @c super .
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x18790
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * @brief Whether the given interface orientation is a landscape one.
 * @param interfaceOrientation The candidate orientation.
 * @return @c YES for the two landscape orientations.
 * @ghidraAddress 0x187c8
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @brief The supported interface orientations (landscape only).
 * @return @c UIInterfaceOrientationMaskLandscape .
 * @ghidraAddress 0x187d8
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Whether the controller may autorotate.
 * @return Always @c YES .
 * @ghidraAddress 0x187e0
 */
- (BOOL)shouldAutorotate;

/**
 * @brief Reports a downloaded custom chart's play to the jubeat-lab play-count API.
 * @ghidraAddress 0x187e8
 */
- (void)requestAddPlayCount;

/**
 * @brief jubeat-lab access failure: clears the matching access reference.
 * @param access The failed access.
 * @ghidraAddress 0x18a0c
 */
- (void)jubeatLabAccessError:(nullable id)access;

/**
 * @brief jubeat-lab access completion: clears the matching access reference and, for the good-job
 *        commit, records the send and re-saves the chart.
 * @param access The finished access.
 * @ghidraAddress 0x18a78
 */
- (void)jubeatLabAccessFinished:(nullable id)access;

/**
 * @brief Stops animation, drops observers, disconnects the session, and tears down the overlays.
 * @ghidraAddress 0x18bf8
 */
- (void)dealloc;

/**
 * @brief Builds the good-job button and its label.
 * @ghidraAddress 0x18eb0
 */
- (void)createGoodJobBtn;

/**
 * @brief Good-job button tap: records the good-job vote and commits it through the jubeat-lab API.
 * @ghidraAddress 0x19518
 */
- (void)pushBtnGoodJob;

/**
 * @brief Builds the Twitter share button.
 * @ghidraAddress 0x19f08
 */
- (void)createTwitterBtn;

/**
 * @brief Presents the Twitter share composer with a result image and message.
 * @param image The result image to attach.
 * @param mesStr The initial tweet text.
 * @ghidraAddress 0x1a3f0
 */
- (void)sendTwitter:(nullable UIImage *)image mesStr:(nullable NSString *)mesStr;

/**
 * @brief Builds the store-move search button and the pack-ID search overlay.
 * @ghidraAddress 0x1a56c
 */
- (void)createSearchBtn;

/**
 * @brief Pack-ID search completion: downloads the matching pack.
 * @param packID The resolved pack identifier.
 * @ghidraAddress 0x1a99c
 */
- (void)packIDSearchEnd:(nullable id)packID;

/**
 * @brief Pack-ID search cancellation: tears down the search overlay.
 * @param sender The cancel trigger.
 * @ghidraAddress 0x1ad08
 */
- (void)packIDSearchCancel:(nullable id)sender;

/**
 * @brief Pack-ID download error callback: clears the ID manager.
 * @param error The error.
 * @param msgStr The error message.
 * @ghidraAddress 0x1afb8
 */
- (void)errorIDDownload:(nullable id)error msgStr:(nullable id)msgStr;

/**
 * @brief Pack-ID download success callback: clears the ID manager.
 * @param sender The success trigger.
 * @ghidraAddress 0x1afd0
 */
- (void)successIDDownload:(nullable id)sender;

/**
 * @brief @c Downloader completion: installs the downloaded pack.
 * @param downloader The finished request.
 * @ghidraAddress 0x1afe8
 */
- (void)downloaderFinished:(nullable id)downloader;

/**
 * @brief @c Downloader failure: presents a network-error alert.
 * @param downloader The failed request.
 * @ghidraAddress 0x1b50c
 */
- (void)downloaderError:(nullable id)downloader;

/**
 * @brief Removes the pack-ID search overlay and its cover view.
 * @ghidraAddress 0x1b61c
 */
- (void)releaseSearchPackView;

/**
 * @brief Builds the per-panel touch-recording tables from the debug touch and press tables.
 * @ghidraAddress 0x1b690
 */
- (void)makeTouchesData;

/**
 * @brief Reads the current frame's touches into the button-state bitmasks and returns the touch
 *        list.
 * @return The current touches.
 * @ghidraAddress 0x1bfbc
 */
- (nullable NSArray *)getTouches;

/**
 * @brief Double-tap gesture: toggles auto-play.
 * @param gesture The tap recogniser.
 * @ghidraAddress 0x1c544
 */
- (void)tapGesture:(nullable UITapGestureRecognizer *)gesture;

/**
 * @brief The replay delay in sectors between the recorded ghost and live play.
 * @return The delay in sectors.
 * @ghidraAddress 0x1c61c
 */
- (int)getDelaySector;

/**
 * @brief Appends the current frame's ghost touches into the recording table.
 * @ghidraAddress 0x1c6d0
 */
- (void)addGhostTouches;

/**
 * @brief Resolves the on-disk directory for the current tune's ghost recordings.
 * @return The ghost directory path.
 * @ghidraAddress 0x1c8fc
 */
- (nullable NSString *)getGhostDirectoryPath;

/**
 * @brief Serialises the recorded ghost touches for the just-finished play.
 * @ghidraAddress 0x1c960
 */
- (void)setReplayData;

/**
 * @brief Reads the current frame's ghost touches back for replay.
 * @return The replay touch list.
 * @ghidraAddress 0x1cdd4
 */
- (nullable NSArray *)getGhostTouches;

/**
 * @brief Uploads the challenge-mode score.
 * @ghidraAddress 0x1d0dc
 */
- (void)sendChallengeScore;

/**
 * @brief Alert button callback: on confirm, ends the play (tag 2) or uploads the challenge score
 *        (tag 1); on cancel of the challenge alert, clears the item-chance state.
 * @param info The alert result dictionary carrying @c "btnMessage" and @c "Tag".
 * @ghidraAddress 0x1d4a8
 */
- (void)alertSelect:(nullable NSDictionary *)info;

/**
 * @brief Panel-chance close: fades out BGM, returns to music select, and ends the result.
 * @ghidraAddress 0x1d5e8
 */
- (void)panelChanceClose;

/// @brief The tune being played.
@property(nonatomic, strong, nullable) TuneInfo *currentTune;
/// @brief The current difficulty.
@property(nonatomic) unsigned int currentDiff;
/// @brief The current marker resource name. Held without ownership, matching the binary.
@property(nonatomic, unsafe_unretained, nullable) NSString *currentMarker;
/// @brief The local-multiplayer session manager.
@property(nonatomic, strong, nullable) SharePlayManager *shareManager;
/// @brief The compressed music data for the current chart.
@property(nonatomic, strong, nullable) NSData *musicData;
/// @brief The OpenGL view.
@property(nonatomic, strong, nullable) EAGLView *glView;
/// @brief The gameplay renderer for the current idiom and theme.
@property(nonatomic, strong, nullable) MainGameRenderer *mainGameRenderer;
/// @brief The per-frame display link driving @c loop: .
@property(nonatomic, strong, nullable) CADisplayLink *displayLink;
/// @brief The note-judgement sequence.
@property(nonatomic, strong, nullable) Sequence *sequence;
/// @brief The pause / play button.
@property(nonatomic, strong, nullable) UIButton *btnPause;
/// @brief The store-move (pack search) button.
@property(nonatomic, strong, nullable) UIImageView *btnStoreMove;
/// @brief The good-job vote button.
@property(nonatomic, strong, nullable) UIImageView *btnGoodJob;
/// @brief The good-job button's caption image.
@property(nonatomic, strong, nullable) UIImageView *goodJobTxt;
/// @brief The Twitter share button.
@property(nonatomic, strong, nullable) UIImageView *twitterBtn;
/// @brief The pause overlay.
@property(nonatomic, strong, nullable) GamePauseView *pauseView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
