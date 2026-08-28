/** @file
 * The chart-editor top-level view controller.
 *
 * Reconstructed from Ghidra program Jubeat (class EditViewController, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * @c EditViewController drives the note-chart editor: it owns the OpenGL view and its edit-mode
 * renderer, the editor button bar, the timeline scrubbing view, the audio playback loop, and the
 * persistence of edited charts through @c EditDataManager . It is the delegate for the editor
 * button popovers ( @c EditButtonViewController ), the system-menu popover
 * ( @c EditSystemMenuview ), the metadata modal ( @c EditModalView ), and the shared
 * @c AlertViewManager confirmation alerts.
 */

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "EditButtonViewController.h"
#import "EditFileListViewController.h"
#import "EditModalView.h"

@class EAGLView;
@class EditNoteRenderer;
@class EditSequence;
@class TuneInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The chart-editor top-level view controller.
 */
@interface EditViewController : UIViewController <UIPopoverPresentationControllerDelegate,
                                                  AlertViewManagerDelegate,
                                                  EditButtonViewControllerDelegate,
                                                  EditModalViewDelegate,
                                                  EditFileListViewDelegate>

/**
 * @brief Initialises the editor: reads the saved adjust-sector offset, resolves the device idiom,
 *        builds the @c EAGLView sized to the screen, and resets the editing state.
 * @return The initialised controller.
 * @ghidraAddress 0x21aa54
 */
- (instancetype)init;

/**
 * @brief Resolves (creating if needed) the on-disk directory for a tune's edit charts.
 * @param tuneID The tune identifier.
 * @return The chart directory path.
 * @ghidraAddress 0x219860
 */
- (nullable NSString *)getDirectoryPath:(unsigned int)tuneID;

/**
 * @brief Loads the note data for the current tune from @c EditDataManager into the editor state.
 * @ghidraAddress 0x219a14
 */
- (void)loadNotesData;

/**
 * @brief Imports a downloaded chart file into the editor, merging its metadata over the current
 *        editor info.
 * @param fileName The chart file to import.
 * @ghidraAddress 0x219cac
 */
- (void)importNotesData:(nullable NSString *)fileName;

/**
 * @brief Bumps the auto-save counter and saves the chart when it overflows or when forced.
 * @param force Whether to save immediately regardless of the counter.
 * @ghidraAddress 0x21a1a4
 */
- (void)autoSave:(BOOL)force;

/**
 * @brief Persists the current chart, its editor info, and its summary data to disk.
 * @ghidraAddress 0x21a1d8
 */
- (void)saveNotesData;

/**
 * @brief Resets the editor's per-session state to its defaults.
 * @ghidraAddress 0x21a94c
 */
- (void)resetEditMember;

/**
 * @brief Sets a grid button's image and frame from a division type and origin.
 * @param button The grid button to configure.
 * @param type The grid-division type.
 * @param pos The button's origin.
 * @ghidraAddress 0x21ad04
 */
- (void)setGridButton:(nullable UIButton *)button type:(int)type pos:(CGPoint)pos;

/**
 * @brief Builds and lays out the editor's OpenGL view and button bar.
 * @ghidraAddress 0x21ae3c
 */
- (void)loadView;

/**
 * @brief Loads the button images, renderer, sequence, audio, and artwork for the current chart.
 * @ghidraAddress 0x21bb44
 */
- (void)loadResources;

/**
 * @brief Tears down the renderer, sequence, framebuffer, and audio resources.
 * @ghidraAddress 0x21d38c
 */
- (void)releaseResources;

/**
 * @brief Discarded persistence stub kept for the interface.
 * @ghidraAddress 0x21d4d0
 */
- (void)saveScore;

/**
 * @brief Starts the per-frame display link that drives @c loop: .
 * @ghidraAddress 0x21d4d4
 */
- (void)startAnimation;

/**
 * @brief Stops the per-frame display link.
 * @ghidraAddress 0x21d654
 */
- (void)stopAnimation;

/**
 * @brief Handles the BGM-finished notification by clearing the playing flag.
 * @param notification The finish notification.
 * @ghidraAddress 0x21d6e8
 */
- (void)finishMusic:(nullable NSNotification *)notification;

/**
 * @brief Adds notes to the sequence at every held panel, warning when the marker limit is hit.
 * @param isSwitch Whether the add is a mode-switch add.
 * @ghidraAddress 0x21d750
 */
- (void)addNote:(BOOL)isSwitch;

/**
 * @brief Deletes notes from the sequence at every held panel.
 * @ghidraAddress 0x21d92c
 */
- (void)deleteNote;

/**
 * @brief Stops BGM playback and restores the play button image.
 * @ghidraAddress 0x21d9e0
 */
- (void)stopMusic;

/**
 * @brief Clamps playback to the sequence duration and stops music when it runs past the end.
 * @ghidraAddress 0x21daac
 */
- (void)controllMusic;

/**
 * @brief The display-link callback: reads touches, updates the sequence, and draws a frame.
 * @param displayLink The display link that fired.
 * @ghidraAddress 0x21dba8
 */
- (void)loop:(nullable CADisplayLink *)displayLink;

/**
 * @brief Plays the clap sound effect when the sequence passes a clap point.
 * @ghidraAddress 0x21fab0
 */
- (void)exeClap;

/**
 * @brief Starts play mode: re-reads the adjust offset, resets the sequence, and applies prefs.
 * @ghidraAddress 0x21fbd8
 */
- (void)startGame;

/**
 * @brief Toggles BGM playback from the pause button.
 * @param sender The pause button.
 * @ghidraAddress 0x21fdc4
 */
- (void)pushBtnPause:(nullable id)sender;

/**
 * @brief Hides the paste button.
 * @ghidraAddress 0x21ff3c
 */
- (void)deletePasteBtn;

/**
 * @brief Sets the mode button's background image from an image resource name.
 * @param imageName The image resource name.
 * @ghidraAddress 0x21ff8c
 */
- (void)changeModeImage:(nullable NSString *)imageName;

/**
 * @brief Switches to add mode.
 * @param sender The add button.
 * @ghidraAddress 0x21fff8
 */
- (void)pushBtnAdd:(nullable id)sender;

/**
 * @brief Switches to delete mode.
 * @param sender The delete button.
 * @ghidraAddress 0x220040
 */
- (void)pushBtnDelete:(nullable id)sender;

/**
 * @brief Toggles between the two edit modes.
 * @param sender The mode button.
 * @ghidraAddress 0x220088
 */
- (void)pushBtnMode:(nullable id)sender;

/**
 * @brief Presents the add/delete mode popover on a long press of the mode button.
 * @param gesture The long-press recogniser.
 * @ghidraAddress 0x220128
 */
- (void)longPressBtnMode:(nullable UILongPressGestureRecognizer *)gesture;

/**
 * @brief Applies the pinch gesture's scale to the renderer.
 * @param gesture The pinch recogniser.
 * @ghidraAddress 0x220364
 */
- (void)pinchGesture:(nullable UIPinchGestureRecognizer *)gesture;

/**
 * @brief Applies an undo and auto-saves.
 * @param sender The undo button.
 * @ghidraAddress 0x22044c
 */
- (void)pushBtnUndo:(nullable id)sender;

/**
 * @brief Applies a redo and auto-saves.
 * @param sender The redo button.
 * @ghidraAddress 0x2204f8
 */
- (void)pushBtnRedo:(nullable id)sender;

/**
 * @brief Presents the system-menu popover from the system-menu button.
 * @param sender The system-menu button.
 * @ghidraAddress 0x2205a4
 */
- (void)pushbtnSysMenu:(nullable id)sender;

/**
 * @brief Presents the grid-division popover from the grid button.
 * @param sender The grid button.
 * @ghidraAddress 0x22087c
 */
- (void)pushBtnGridChange:(nullable id)sender;

/**
 * @brief Applies a grid-division type, updating the button image and the renderer.
 * @param type The grid-division type.
 * @ghidraAddress 0x220b50
 */
- (void)selectGridType:(int)type;

/**
 * @brief Enables or disables the editor buttons and renderer panel during a long press.
 * @param enable Whether the controls are enabled.
 * @ghidraAddress 0x220ce0
 */
- (void)longPressEnable:(BOOL)enable;

/**
 * @brief Clears the current area selection.
 * @ghidraAddress 0x220f30
 */
- (void)ReleaseSelectArea;

/**
 * @brief Copies the selected area into the paste buffer.
 * @param sender The copy button.
 * @ghidraAddress 0x220fe4
 */
- (void)pushAreaCopy:(nullable id)sender;

/**
 * @brief Deletes the selected area.
 * @param sender The delete button.
 * @ghidraAddress 0x2210a0
 */
- (void)pushAreaDelete:(nullable id)sender;

/**
 * @brief Pastes the paste buffer at the paste sector, warning on conflict.
 * @param sender The paste button.
 * @ghidraAddress 0x221154
 */
- (void)pushAreaPaste:(nullable id)sender;

/**
 * @brief Pastes the paste buffer at the current sector.
 * @param sender The paste button.
 * @ghidraAddress 0x221408
 */
- (void)pushAreaPaste2:(nullable id)sender;

/**
 * @brief Toggles the clap sound effect on or off.
 * @param sender The clap button.
 * @ghidraAddress 0x2214b0
 */
- (void)pushClap:(nullable id)sender;

/**
 * @brief Presents the how-to help popover.
 * @param sender The help button.
 * @ghidraAddress 0x2215c8
 */
- (void)pushHelp:(nullable id)sender;

/**
 * @brief Rewinds playback to the current measure start.
 * @param sender The rewind button.
 * @ghidraAddress 0x221740
 */
- (void)pushRewind:(nullable id)sender;

/**
 * @brief Builds the timeline scrubbing view and its gesture recognisers.
 * @ghidraAddress 0x221840
 */
- (void)createTimeLineView;

/**
 * @brief Reads the swipe direction (result discarded).
 * @param gesture The swipe recogniser.
 * @ghidraAddress 0x221af4
 */
- (void)handleSwipe:(nullable UISwipeGestureRecognizer *)gesture;

/**
 * @brief Resets the paste selection.
 * @ghidraAddress 0x221b04
 */
- (void)resetPaste;

/**
 * @brief Resets the long-press area selection.
 * @ghidraAddress 0x221b9c
 */
- (void)resetLongPress;

/**
 * @brief Resets both the paste and long-press selections.
 * @ghidraAddress 0x221c48
 */
- (void)resetGesture;

/**
 * @brief Begins an area selection on a long press of the timeline.
 * @param gesture The long-press recogniser.
 * @ghidraAddress 0x221c7c
 */
- (void)longPressGesture:(nullable UILongPressGestureRecognizer *)gesture;

/**
 * @brief Resets the current selection on a single tap of the timeline.
 * @param gesture The tap recogniser.
 * @ghidraAddress 0x221f58
 */
- (void)tapGesture:(nullable UITapGestureRecognizer *)gesture;

/**
 * @brief Positions the paste button at the double-tapped sector.
 * @param gesture The double-tap recogniser.
 * @ghidraAddress 0x221ffc
 */
- (void)dpGesture:(nullable UITapGestureRecognizer *)gesture;

/**
 * @brief Resumes animation and BGM when returning from a paused popover.
 * @ghidraAddress 0x222298
 */
- (void)resumeInPauseView;

/**
 * @brief Ends the edit session and returns to the root controller from a paused popover.
 * @ghidraAddress 0x222380
 */
- (void)endInPauseView;

/**
 * @brief Dismisses the editor and ends the session.
 * @ghidraAddress 0x222474
 */
- (void)end;

/**
 * @brief Suspends the editor when backgrounded, saving if playing.
 * @ghidraAddress 0x2224b0
 */
- (void)suspend;

/**
 * @brief Resumes the editor's animation.
 * @ghidraAddress 0x222594
 */
- (void)resume;

/**
 * @brief Fully resets the editor to a clean state, releasing per-chart resources.
 * @ghidraAddress 0x2225a0
 */
- (void)terminate;

/**
 * @brief Releases the system-menu popover reference.
 * @ghidraAddress 0x222b4c
 */
- (void)templateRelease;

/**
 * @brief The system-menu load-slot selection callback.
 * @param slot The chosen slot number.
 * @ghidraAddress 0x222b8c
 */
- (void)selectLoadSlot:(nullable NSNumber *)slot;

/**
 * @brief The system-menu exit selection callback.
 * @ghidraAddress 0x222d78
 */
- (void)selectExit;

/**
 * @brief Presents the save-confirmation alert, warning about conflicting markers.
 * @ghidraAddress 0x222db4
 */
- (void)selectSave;

/**
 * @brief The file-list cancel callback (no-op).
 * @ghidraAddress 0x222fd4
 */
- (void)editFileListViewCancel;

/**
 * @brief The file-list decide callback (no-op).
 * @param index The chosen row.
 * @ghidraAddress 0x222fd8
 */
- (void)editFileListViewDecideItem:(int)index;

/**
 * @brief Clears the ignore-press flag when a popover is dismissed.
 * @param popoverPresentationController The dismissed popover controller.
 * @ghidraAddress 0x222fdc
 */
- (void)popoverPresentationControllerDidDismissPopover:
    (nullable UIPopoverPresentationController *)popoverPresentationController;

/**
 * @brief The editor-button popover selection callback.
 * @param controller The button popover.
 * @param info The selection info dictionary.
 * @ghidraAddress 0x222fec
 */
- (void)editBtnSelect:(nullable EditButtonViewController *)controller
                  tag:(nullable NSDictionary *)info;

/**
 * @brief The confirmation-alert button callback: routes save, load, and exit confirmations.
 * @param info The alert result dictionary.
 * @ghidraAddress 0x223144
 */
- (void)alertSelect:(nullable NSDictionary *)info;

/**
 * @brief Dismisses the metadata modal.
 * @param view The modal being closed.
 * @ghidraAddress 0x2233e0
 */
- (void)editModalViewClose:(nullable EditModalView *)view;

/**
 * @brief Saves the edited metadata after the modal reports a save.
 * @ghidraAddress 0x2233f4
 */
- (void)editModalViewDelegateSaveEditFile;

/**
 * @brief Applies the adjust-time offset, clamped to zero.
 * @param time The raw time.
 * @return The adjusted time.
 * @ghidraAddress 0x223484
 */
- (float)adjustTime:(float)time;

/**
 * @brief Removes the adjust-time offset, clamped to zero.
 * @param time The adjusted time.
 * @return The raw time.
 * @ghidraAddress 0x2234a0
 */
- (float)reverseAdjustTime:(float)time;

/// @brief The tune being edited.
@property(nonatomic, strong, nullable) TuneInfo *currentTune;
/// @brief The saved chart file name.
@property(nonatomic, strong, nullable) NSString *jcfName;
/// @brief The current difficulty.
@property(nonatomic) unsigned int currentDiff;
/// @brief The current marker resource name.
@property(nonatomic, strong, nullable) NSString *currentMarker;
/// @brief The compressed music data for the current chart.
@property(nonatomic, strong, nullable) NSData *musicData;
/// @brief The OpenGL view.
@property(nonatomic, strong, nullable) EAGLView *glView;
/// @brief The edit-mode note renderer.
@property(nonatomic, strong, nullable) EditNoteRenderer *mainGameRenderer;
/// @brief The per-frame display link driving @c loop: .
@property(nonatomic, strong, nullable) CADisplayLink *displayLink;
/// @brief The editable note sequence.
@property(nonatomic, strong, nullable) EditSequence *sequence;
/// @brief The pause / play button.
@property(nonatomic, strong, nullable) UIButton *btnPause;
/// @brief The add/delete mode button.
@property(nonatomic, strong, nullable) UIButton *btnMode;
/// @brief The system-menu button.
@property(nonatomic, strong, nullable) UIButton *btnSysMenu;
/// @brief The clap-toggle button.
@property(nonatomic, strong, nullable) UIButton *btnClap;
/// @brief The clap button's decorative image view.
@property(nonatomic, strong, nullable) UIImageView *clapBtnView;
/// @brief The rewind button.
@property(nonatomic, strong, nullable) UIButton *btnRewind;
/// @brief The help button.
@property(nonatomic, strong, nullable) UIButton *btnHelp;
/// @brief The grid-division button.
@property(nonatomic, strong, nullable) UIButton *btnSelGrid;
/// @brief The area-copy button.
@property(nonatomic, strong, nullable) UIButton *btnAreaCpy;
/// @brief The area-delete button.
@property(nonatomic, strong, nullable) UIButton *btnAreaDel;
/// @brief The area-paste button.
@property(nonatomic, strong, nullable) UIButton *btnAreaPst;
/// @brief The undo button.
@property(nonatomic, strong, nullable) UIButton *btnUndo;
/// @brief The redo button.
@property(nonatomic, strong, nullable) UIButton *btnRedo;
/// @brief The loaded sequence table for the current chart.
@property(nonatomic, strong, nullable) NSArray *editData;
/// @brief The editor metadata dictionary.
@property(nonatomic, strong, nullable) NSMutableDictionary *editorInfo;
/// @brief The summary metadata dictionary.
@property(nonatomic, strong, nullable) NSMutableDictionary *editSimpleData;
/// @brief The timeline scrubbing view.
@property(nonatomic, strong, nullable) UIView *timeLineView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
