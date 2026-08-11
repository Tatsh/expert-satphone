#import "EditViewController.h"

#import <AudioToolbox/AudioToolbox.h>

#import "AudioManager.h"
#import "BFCodec.h"
#import "EAGLView.h"
#import "EditDataManager.h"
#import "EditHowtoViewController.h"
#import "EditNoteRenderer.h"
#import "EditNoteRendererPad.h"
#import "EditNoteRendererPhone.h"
#import "EditRendererConf.h"
#import "EditSequence.h"
#import "EditSystemMenuview.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "LabUtilities.h"
#import "RootViewController.h"
#import "SePlayer.h"
#import "TuneInfo.h"

// The edit-mode edit_mode values, matching the mode-image index into the switch/add/delete table.
enum {
    kEditModeSwitch = 0,  // Toggle add/delete on a single mode-button tap.
    kEditModeControl = 1, // The passive control (no place/erase) mode.
    kEditModeAdd = 2,     // Place notes.
    kEditModeDelete = 3,  // Erase notes.
};

// The renderer state values read from and written to the renderer's -state.
enum {
    kRendererStateReady = 1,    // Ready to begin play.
    kRendererStateStarting = 2, // Waiting for the end state to begin play.
    kRendererStatePlaying = 3,  // Playing.
    kRendererStateEnding = 4,   // Ending; waiting to finish.
    kRendererStateEnded = 5,    // Ended; waiting to leave.
};

// The renderer sub-state sentinel that gates the state transitions in -loop:.
enum { kRendererSubStateReady = 10 };

// The alert tags echoed back through -alertSelect:.
enum {
    kAlertTagExit = 1,        // Confirm ending the edit session.
    kAlertTagSave = 2,        // Confirm saving.
    kAlertTagLoad = 3,        // Confirm loading a slot.
    kAlertTagMarkerLimit = 4, // Acknowledge the marker-limit warning.
};

// The alert button-message value that marks the positive (OK) button in -alertSelect:.
enum { kAlertButtonOK = 1 };

// The grid-division types selectable from the grid popover, indexed by button position.
static const int kGridDivideTypes[] = {1, 2, 4, 8, 3, 6, 15};

// The number of saved-chart template slots preceding the file-list entries.
enum { kTemplateSlotCount = 4 };

// The free-grid division type, which also forces the renderer's divide to 1.
enum { kGridDivideFree = 15 };

// The number of 4x4 panels tested for touches each frame.
enum { kPanelCount = 16 };

// The compressed-archive member names inside a chart's KUnzip container.
static NSString *const kArchiveSequenceMember = @"bgm";
static NSString *const kArchiveArtworkMember = @"artwork";
static NSString *const kArchiveNameMember = @"name_w";

// The chart-directory and file-name constants used when resolving a chart's on-disk location.
static NSString *const kEditDirectoryName = @"edit";
static NSString *const kChartFileNameFormat = @"%09d";
static NSString *const kClapResourceName = @"SD_HANDCLAP";
static NSString *const kClapResourceType = @"caf";
static NSString *const kPauseSePath = @"SD_LABO_MENU";

// The user-defaults keys for the play-time offset, combo display, and button-width preferences.
static NSString *const kPrefAdjustSector = @"PrefAdjustSector";
static NSString *const kPrefShowCombo = @"PrefShowCombo";
static NSString *const kPrefButtonWidth = @"PrefButtonWidth";

// The BGM-finished notification observed while a chart is playing.
static NSString *const kFinishBgmNotificationName = @"JubeatAudioManagerFinishBgmNotifacation";

// The editor button image resource base names.
static NSString *const kImagePauseBase = @"edit_btn_pbase";
static NSString *const kImagePlayButton = @"edit_btn_play";
static NSString *const kImagePauseButton = @"edit_btn_paused";
static NSString *const kImageModeSwitch = @"edit_switch_btn";
static NSString *const kImageModeAdd = @"edit_add_btn";
static NSString *const kImageModeDelete = @"edit_del_btn";
static NSString *const kImageSystemButton = @"edit_btn_system";
static NSString *const kImageUndoButton = @"btn_undo";
static NSString *const kImageRedoButton = @"btn_redo";
static NSString *const kImageRewindButton = @"btn_rew";
static NSString *const kImageGridBase = @"grid_1_1";
static NSString *const kImageGridArrow = @"grid_arrow";
static NSString *const kImageClapOn = @"btn_clap_on";
static NSString *const kImageClapOff = @"btn_clap_off";
static NSString *const kImageHelpButton = @"edit_btn_help";
static NSString *const kImageAreaCopy = @"btn_area_cpy";
static NSString *const kImageAreaDelete = @"btn_area_delete";
static NSString *const kImageAreaPasteBase = @"btn_area_paste_base";
static NSString *const kImageAreaPaste = @"btn_area_paste";
static NSString *const kGridImageFormat = @"grid_1_%d";
static NSString *const kGridFreeImageName = @"grid_free";

// The mode-button image names indexed by edit_mode, matching the binary's PTR table.
static NSString *const kModeImageNames[] = {
    @"edit_switch_btn", @"edit_prev_btn", @"edit_add_btn", @"edit_del_btn"};

// The saved-chart template display names shown in the system menu, indexed by slot.
static NSString *const kTemplateNames[] = {@"CLEAN", @"BASIC", @"ADVANCED", @"EXTREME"};

// The control names handed to the editor-button popover for the two popover kinds.
static NSString *const kModePopoverName = @"mode";
static NSString *const kGridPopoverName = @"grid";

// The editor-button and alert result dictionary keys.
static NSString *const kEditorInfoDlFlagKey = @"dlFlag";
static NSString *const kEditorInfoSequenceIDKey = @"sequenceID";
static NSString *const kEditorInfoEditorNameKey = @"editorName";
static NSString *const kEditorInfoOrgEditorNameKey = @"orgEditorName";
static NSString *const kEditorInfoOrgFumenIndexKey = @"orgFumenIndex";
static NSString *const kEditorInfoNotesNumKey = @"notesNum";
static NSString *const kEditorInfoMusicIDKey = @"musicID";
static NSString *const kEditorInfoFileNameKey = @"fileName";
static NSString *const kEditorInfoFumenNameKey = @"fumenName";
static NSString *const kSimpleDataEventNumKey = @"eventNum";
static NSString *const kSimpleDataEndSectorKey = @"endSector";
static NSString *const kSimpleDataFirstMarkerKey = @"firstMarker";
static NSString *const kSimpleDataFirstSectorKey = @"firstSector";
static NSString *const kSimpleDataMusicBarKey = @"musicBar";
static NSString *const kButtonSelectNameKey = @"name";
static NSString *const kButtonSelectSelectKey = @"select";
static NSString *const kAlertButtonMessageKey = @"btnMessage";
static NSString *const kAlertTagKey = @"Tag";
static NSString *const kEmptyLocalizedValue = @"";
static NSString *const kOkKey = @"OK";
static NSString *const kCancelKey = @"Cancel";

// The Japanese alert messages recovered from the __cfstring section.
static NSString *const kMarkerLimitMessage = @"これ以上マーカーをセットする事はできません";
static NSString *const kPasteLimitMessage = @"これ以上マーカーをセットする事はできません。";
static NSString *const kPasteAreaMessage = @"マーカーを置けないエリアが含まれています。";
static NSString *const kLoadConfirmMessage = @"編集中のデータは失われます。\nロードしますか？";
static NSString *const kSaveConfirmMessage = @"セーブしますか？";
static NSString *const kSaveConflictMessage =
    @"エフェクトの重なるマーカーが存在します。セーブしますか？";

// The play-time-to-sector conversion factor: the sequence advances 300 sectors per second.
static const float kSectorsPerSecond = 300.0f;

// The end-sector padding used to derive the playable sequence duration.
static const float kEndSectorPadding = 299.0f;

// The music-catch-up tween factor and its stop threshold, used when following without live BGM.
static const float kMusicTweenFactor = 0.25f;
static const float kMusicTweenStopThreshold = 0.001f;

// The BGM-versus-sequence duration tolerances used when clamping playback near the end.
static const double kMusicOverrunTolerance = -0.1;
static const double kMusicOverrunStep = 1.0 / 30.0;
static const double kMusicOverrunBack = -0.09;

// The clap-window sector span: a clap fires once the sequence has advanced eight sectors past it.
enum { kClapWindowSectors = 8 };

// The undo/redo history-depth threshold above which an edit forces an auto-save.
enum { kHistoryAutoSaveThreshold = 10 };

// The auto-save counter threshold: every ninth non-forced edit triggers a save.
enum { kAutoSaveCounterLimit = 8 };

// The phone-idiom 4x4 button-hit geometry: an 80pt grid pitch offset 160pt down the view.
static const float kPhoneButtonPitch = 80.0f;
static const float kPhoneButtonOffsetY = 160.0f;
static const float kPhoneButtonSizeBase = 80.0f;

// The timeline seek band: touches with y at or below 80pt or at or above 176pt end the seek.
static const double kTimelineBandTop = 80.0;
static const double kTimelineBandBottom = 176.0;

// The music-bar binary-seek span baseline, measured from the timeline area's 256pt lower edge.
static const double kSeekSpanBaseline = 256.0;

// The pad-idiom 4x4 button-hit geometry: a 192pt grid pitch inset 8pt, offset 256pt down, 176 wide.
enum { kPadButtonPitch = 0xc0, kPadButtonInset = 8 };
static const double kPadButtonOffsetY = 256.0;
static const double kPadButtonSize = 176.0;

// The paste-button horizontal nudge and its off-screen hidden position.
enum { kPasteButtonNudge = 12 };
static const double kPasteButtonHiddenX = -100.0;

// The timeline seek-column geometry: an initial 0xc0 span refined by a 0x100 window over passes.
enum { kSeekInitialSpan = 0xc0, kSeekInitialWindow = 0x100 };

// The number of binary-search refinement passes the timeline seek runs (counting 0 down to -4).
enum { kSeekRefinementPasses = 5 };

// The paste-button on-screen visibility band around the view's timeline area.
static const double kPasteVisibleMargin = 100.0;

@interface EditViewController () {
@public
    BOOL isPad;
    double music_time;
    double music_duration;
    double sequence_duration;
    int loadCounter;
    BOOL isMusicPlaying;
    float buttonTouchWidth;
    unsigned int buttonDown;
    unsigned int buttonUp;
    unsigned int buttonPress;
    unsigned int buttonPressOld;
    unsigned int draw_count;
    double past_time;
    float fps;
    CGRect mbarRect;
    int edit_mode;
    int edit_type;
    BOOL bSeekMusicBar;
    float seekDefaultPos;
    unsigned int timeLineSector;
    BOOL bSeekTimeLine;
    BOOL bEnableSeekTimeLine;
    unsigned int timeLineSeekSector;
    float targetTime;
    int divMeasureType;
    BOOL bEnableControll;
    BOOL bLongPress;
    int startIndex;
    int endIndex;
    BOOL bEnablePaste;
    int pasteSector;
    int areaStartDefaultSec;
    int areaEndDefaultSec;
    int areaSelectTouchDelay;
    int areaDefaultWidth;
    BOOL bExistCopyData;
    NSArray *arraySwipeRecognizer;
    BOOL bEnableUndoBtn;
    BOOL bEnablePanel;
    BOOL bClapReset;
    unsigned int clapID;
    int clapSector;
    BOOL bEnableClap;
    BOOL bEnableGesture;
    EditSystemMenuview *pFileListView;
    CGPoint touchPointBack;
    int selectTemplateNum;
    NSMutableDictionary *templateInfo[kTemplateSlotCount];
    NSMutableDictionary *newEditorInfo;
    BOOL isFirstPlaying;
    SePlayer *sePlayer;
    EditModalView *pEditModalView;
    EditButtonViewController *btnList;
    BOOL bLoadTemplate;
    BOOL ignorePress;
    float adjustTime;
}
@end

// Snaps the start-selection handle to the touch during a live area drag. While neither default
// sector is pinned the touch must land inside the whole handle rect to arm the drag (recording the
// touch delay); once armed, the start sector tracks the touch by its vertical band, clamped so the
// selection keeps its default width and never goes below zero.
static inline void DragAreaSelectionStart(EditViewController *self, CGPoint location) {
    if (self->areaStartDefaultSec < 0) {
        if (self->areaEndDefaultSec < 0) {
            CGRect handle = [self.mainGameRenderer getAreaSelectStart];
            if (CGRectContainsPoint(handle, location)) {
                self->areaSelectTouchDelay = (int)(location.x - handle.origin.x);
                self->areaStartDefaultSec = [self.mainGameRenderer
                    pos2sector:(int)((handle.size.width * 0.5) +
                                     (location.x - (double)self->areaSelectTouchDelay))];
            }
        }
    } else {
        CGRect handle = [self.mainGameRenderer getAreaSelectStart];
        if ((handle.origin.y < location.y) && (location.y < handle.origin.y + handle.size.height)) {
            int sector = [self.mainGameRenderer
                pos2sector:(int)((handle.size.width * 0.5) +
                                 (location.x - (double)self->areaSelectTouchDelay))];
            int startCap = (int)[self.mainGameRenderer areaEndSector] - self->areaDefaultWidth;
            if (sector > startCap) {
                sector = startCap;
            }
            if (sector < 0) {
                sector = 0;
            }
            [self.mainGameRenderer setAreaStartSector:sector];
        }
    }
}

// Snaps the end-selection handle to the touch during a live area drag, mirroring the start handle.
// The end sector is held at or above the start plus the default width, and clamped to the sequence
// end.
static inline void DragAreaSelectionEnd(EditViewController *self, CGPoint location) {
    if (self->areaEndDefaultSec < 0) {
        if (self->areaStartDefaultSec < 0) {
            CGRect handle = [self.mainGameRenderer getAreaSelectEnd];
            if (CGRectContainsPoint(handle, location)) {
                self->areaSelectTouchDelay = (int)(location.x - handle.origin.x);
                self->areaEndDefaultSec = [self.mainGameRenderer
                    pos2sector:(int)((handle.size.width * 0.5) +
                                     (location.x - (double)self->areaSelectTouchDelay))];
            }
        }
    } else {
        CGRect handle = [self.mainGameRenderer getAreaSelectEnd];
        if ((handle.origin.y < location.y) && (location.y < handle.origin.y + handle.size.height)) {
            int sector = [self.mainGameRenderer
                pos2sector:(int)((handle.size.width * 0.5) +
                                 (location.x - (double)self->areaSelectTouchDelay))];
            int endFloor = self->areaDefaultWidth + (int)[self.mainGameRenderer areaStartSector];
            if (sector < endFloor) {
                sector = endFloor;
            }
            unsigned int end = (unsigned int)sector;
            if ([self.sequence getEndSector] < end) {
                end = [self.sequence getEndSector];
            }
            [self.mainGameRenderer setAreaEndSector:end];
        }
    }
}

// Runs the music-bar timeline seek for a touch inside the bar. The seek refines the play position
// over five doubling passes, converts it through the sequence's rate/sector helpers, and drives the
// BGM position.
static inline void
RunMusicBarSeek(EditViewController *self, CGPoint location, AudioManager *audio) {
    int refine = 0;
    int lower = (int)self->mbarRect.origin.y;
    int span = (int)(kSeekSpanBaseline - self->mbarRect.origin.y);
    int window = 1;
    do {
        int upper = lower + span;
        if (((double)lower < location.y) && (location.y < (double)upper)) {
            int divisor;
            if (refine == 0) {
                self->seekDefaultPos = (float)location.x;
                divisor = 1;
            } else {
                divisor = 4;
            }
            double scale = (double)(divisor * window);
            double rate = ((double)(float)((double)self->seekDefaultPos +
                                           (location.x - (double)self->seekDefaultPos) / scale) -
                           self->mbarRect.origin.x) /
                          self->mbarRect.size.width;
            float snappedRate = [self.sequence getNearDivBeatRate:(float)rate divide:window];
            unsigned int sector = [self.sequence rate2sector:snappedRate];
            self->targetTime = (float)(sector & 0xffffffff) / kSectorsPerSecond;
            self->music_time = (double)self->targetTime;
            float back = [self reverseAdjustTime:self->targetTime];
            [audio setBgmPos:(double)back];
            self->bClapReset = YES;
        }
        span = (refine == 0) ? kSeekInitialSpan : span;
        lower = (refine == 0) ? kSeekInitialWindow : upper;
        window <<= 1;
        --refine;
    } while (refine != -kSeekRefinementPasses);
}

@implementation EditViewController

#pragma mark - Frame loop

/** @ghidraAddress 0x21dba8 */
- (void)loop:(CADisplayLink *)displayLink {
    AudioManager *audio = [AudioManager sharedManager];
    [self.glView prepareToRender];
    buttonPressOld = buttonPress;
    buttonPress = 0;
    // Collect the pressed-panel bitmask from every active touch.
    NSSet *touches = [self.glView touches];
    for (UITouch *touch in touches) {
        CGPoint location = [touch locationInView:self.glView];
        for (unsigned int panel = 0; panel < kPanelCount; ++panel) {
            int col = (int)panel % 4;
            int row = (int)panel / 4;
            CGRect panelRect;
            if (isPad) {
                panelRect.origin.x = (double)(int)(col * kPadButtonPitch | kPadButtonInset);
                panelRect.origin.y =
                    (double)(int)(row * kPadButtonPitch | kPadButtonInset) + kPadButtonOffsetY;
                panelRect.size.width = kPadButtonSize;
                panelRect.size.height = kPadButtonSize;
            } else {
                float width = buttonTouchWidth;
                panelRect.origin.x = (double)((float)(col * (int)kPhoneButtonPitch) - width);
                panelRect.origin.y =
                    (double)(((float)(row * (int)kPhoneButtonPitch) - width) + kPhoneButtonOffsetY);
                panelRect.size.width = (double)(width + width + kPhoneButtonPitch);
                panelRect.size.height = panelRect.size.width;
            }
            if ([self.mainGameRenderer state] == kRendererStateEnded) {
                panelRect.origin.y += [self.mainGameRenderer buttonAreaOffset];
            }
            if (CGRectContainsPoint(panelRect, location)) {
                buttonPress |= 1u << (panel & 0x1f);
            }
        }
    }
    buttonDown = buttonPress & ~buttonPressOld;
    buttonUp = buttonPressOld & ~buttonPress;
    [self.mainGameRenderer setBtnPress:buttonPress];
    [self.mainGameRenderer setBtnDown:buttonDown];
    timeLineSector = [self.sequence currentSector];
    [self.mainGameRenderer setCurrentSector:timeLineSector];
    [self.btnRedo setEnabled:([self.sequence enableRedo] ? bEnableUndoBtn : NO)];
    [self.btnUndo setEnabled:([self.sequence enableUndo] ? bEnableUndoBtn : NO)];

    switch ((int)[self.mainGameRenderer state]) {
    case kRendererStateReady:
        if ([self.mainGameRenderer subState] != kRendererSubStateReady) {
            break;
        }
        [self.mainGameRenderer setState:kRendererStatePlaying];
        [self.mainGameRenderer startPlay];
        [[AudioManager sharedManager] startBgm:NO fadeTime:0.0];
        [[AudioManager sharedManager] stopBgm];
        break;
    case kRendererStateStarting:
        if (![self.mainGameRenderer isEndState]) {
            break;
        }
        [audio startBgm:NO fadeTime:0.0];
        isMusicPlaying = YES;
        [self.mainGameRenderer startPlay];
        break;
    case kRendererStatePlaying:
        if (![audio interrupted]) {
            if (!isFirstPlaying) {
                [self.btnPause setEnabled:YES];
                isFirstPlaying = YES;
            }
            if (!isMusicPlaying) {
                // Tween the play position towards the target when there is no live BGM feed.
                float delta = (float)((double)targetTime - music_time);
                float step = (float)((double)targetTime - music_time) * kMusicTweenFactor;
                music_time += (double)step;
                float remaining = (float)((double)targetTime - music_time);
                if (((delta > 0.0f) && (remaining < 0.0f)) ||
                    ((delta < 0.0f) && (remaining > 0.0f))) {
                    music_time = (double)targetTime;
                }
                float absStep = (step < 0.0f) ? -step : step;
                if (absStep < kMusicTweenStopThreshold) {
                    music_time = (double)targetTime;
                }
                [self.sequence seekToTime:music_time];
            } else {
                float pos = [self adjustTime:(float)[audio bgmPos]];
                double when = (double)pos;
                if ((music_duration + kMusicOverrunTolerance) < when) {
                    if (music_duration < sequence_duration) {
                        pos = (float)(music_time + kMusicOverrunStep);
                    }
                    float back =
                        [self reverseAdjustTime:(float)(music_duration + kMusicOverrunBack)];
                    [audio setBgmPos:(double)back];
                    [self stopMusic];
                }
                targetTime = pos;
                music_time = (double)pos;
                [self.sequence seekToTime:music_time];
                [self exeClap];
                if (bClapReset) {
                    clapSector = (int)timeLineSeekSector;
                    bClapReset = NO;
                }
            }
            [self controllMusic];
            if ([touches count] == 1) {
                for (UITouch *touch in touches) {
                    CGPoint location = [touch locationInView:self.glView];
                    touchPointBack = location;
                    if ((startIndex == -1) && (endIndex == -1) && bLongPress) {
                        unsigned int sector =
                            [self.mainGameRenderer pos2sector:(unsigned int)(int)location.x];
                        startIndex = [self.sequence getFrontBeatSector:sector];
                        endIndex = [self.sequence getBackBeatSector:sector];
                        areaDefaultWidth = endIndex - startIndex;
                        [self.mainGameRenderer setAreaStartSector:startIndex];
                        [self.mainGameRenderer setAreaEndSector:endIndex];
                    }
                    if (bLongPress) {
                        DragAreaSelectionStart(self, location);
                        DragAreaSelectionEnd(self, location);
                    }
                    if (bEnablePaste && (pasteSector == -1)) {
                        unsigned int sector =
                            [self.mainGameRenderer pos2sector:(unsigned int)(int)location.x];
                        pasteSector = [self.sequence getNearDiveBeatSector:sector
                                                                    divide:divMeasureType];
                        [self.mainGameRenderer setAreaStartSector:pasteSector];
                    }
                    // Latch the timeline seek when the touch enters the music-bar rect.
                    if ((mbarRect.origin.x < location.x) &&
                        (location.x < mbarRect.origin.x + mbarRect.size.width) &&
                        (mbarRect.origin.y < location.y) &&
                        (location.y < mbarRect.origin.y + mbarRect.size.height) && !bLongPress &&
                        !bEnableSeekTimeLine) {
                        bSeekMusicBar = YES;
                    }
                    if (bSeekMusicBar) {
                        RunMusicBarSeek(self, location, audio);
                    }
                    if ((location.y <= kTimelineBandTop) || (kTimelineBandBottom <= location.y) ||
                        bSeekMusicBar) {
                        if (bSeekTimeLine) {
                            unsigned int current = [self.sequence currentSector];
                            unsigned int snapped =
                                [self.sequence getNearDiveBeatSector:current divide:divMeasureType];
                            float time = (float)(int)snapped / kSectorsPerSecond;
                            targetTime = time;
                            float back = [self reverseAdjustTime:time];
                            [audio setBgmPos:(double)back];
                            bClapReset = YES;
                        }
                        bSeekTimeLine = NO;
                    } else {
                        if (!bSeekTimeLine) {
                            bEnableSeekTimeLine = YES;
                            bSeekTimeLine = YES;
                            seekDefaultPos = (float)location.x;
                            timeLineSeekSector = [self.sequence currentSector];
                        }
                        unsigned int dot = [self.mainGameRenderer
                            dot2sector:(unsigned int)(int)(location.x - (double)seekDefaultPos)];
                        [self.sequence
                            sector2rate:(unsigned int)((int)timeLineSeekSector - (int)dot)];
                        unsigned int rate = [self.sequence rate2sector:0];
                        targetTime = (float)(rate & 0xffffffff) / kSectorsPerSecond;
                        float back = [self reverseAdjustTime:targetTime];
                        [audio setBgmPos:(double)back];
                        bClapReset = YES;
                    }
                    if ((mbarRect.size.height < location.y) && bEnablePaste) {
                        [self resetPaste];
                    }
                }
            }
        } else {
            if (bSeekTimeLine) {
                unsigned int current = [self.sequence currentSector];
                unsigned int snapped = [self.sequence getNearDiveBeatSector:current
                                                                     divide:divMeasureType];
                float time = (float)(int)snapped / kSectorsPerSecond;
                targetTime = time;
                float back = [self reverseAdjustTime:time];
                [audio setBgmPos:(double)back];
                bClapReset = YES;
            }
            bSeekMusicBar = NO;
            bSeekTimeLine = NO;
            bEnableSeekTimeLine = NO;
            if (areaStartDefaultSec >= 0) {
                unsigned int start = [self.mainGameRenderer areaStartSector];
                startIndex = [self.sequence getNearDiveBeatSector:start divide:divMeasureType];
                [self.mainGameRenderer setAreaStartSector:startIndex];
                areaStartDefaultSec = -1;
            }
            if (areaEndDefaultSec >= 0) {
                unsigned int end = [self.mainGameRenderer areaEndSector];
                endIndex = [self.sequence getNearDiveBeatSector:end divide:divMeasureType];
                [self.mainGameRenderer setAreaEndSector:endIndex];
                areaEndDefaultSec = -1;
            }
        }
        if (!bEnablePanel || bSeekMusicBar) {
            [self.mainGameRenderer setEnableBtn:NO];
        } else {
            [self.mainGameRenderer setEnableBtn:!bEnableSeekTimeLine];
        }
        if (![self.btnAreaPst isHidden]) {
            int x = (int)[self.mainGameRenderer sector2pos:pasteSector];
            CGRect glFrame = [self.glView frame];
            if ((x > -100) && ((double)x < glFrame.size.width + kPasteButtonHiddenX)) {
                CGRect frame = [self.btnAreaPst frame];
                frame.origin.x = (double)(x - kPasteButtonNudge);
                [self.btnAreaPst setFrame:frame];
            }
        }
        if ([self.mainGameRenderer enableBtn]) {
            switch (edit_mode) {
            case kEditModeDelete:
                [self deleteNote];
                break;
            case kEditModeAdd:
                [self addNote:NO];
                break;
            default:
                [self addNote:(edit_mode == kEditModeSwitch)];
                break;
            }
        }
        break;
    case kRendererStateEnding:
        if ([self.mainGameRenderer subState] == kRendererSubStateReady) {
            [self stopMusic];
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:kFinishBgmNotificationName
                                                          object:nil];
            [self.mainGameRenderer setState:kRendererStateEnded];
        }
        break;
    case kRendererStateEnded:
        if (([self.mainGameRenderer subState] == kRendererSubStateReady) &&
            ((1u << (((unsigned int)[self.mainGameRenderer endButtonID]) & 0x1f)) & buttonUp)) {
            [[AudioManager sharedManager] fadeoutBgm:1.0];
            [[[JubeatAppDelegate appDelegate] rootViewCtrl] returnFromEdit];
            [self.mainGameRenderer endResult];
        }
        break;
    default:
        break;
    }

    [self.mainGameRenderer draw];
    if ((draw_count != 0) && ((draw_count & 7) == 0)) {
        double now = (double)CFAbsoluteTimeGetCurrent();
        fps = (float)(8.0 / (now - past_time));
        past_time = now;
    }
    ++draw_count;
    [self.glView swapBuffer];
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x21aa54 */
- (instancetype)init {
    self = [super init];
    if (self) {
        float adjust = [[NSUserDefaults standardUserDefaults] floatForKey:kPrefAdjustSector];
        adjustTime = adjust / kSectorsPerSecond;
        JubeatAppDelegate *appDelegate = [JubeatAppDelegate appDelegate];
        isPad = [appDelegate isPad];
        self.glView = [[EAGLView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [self.glView setOpaque:YES];
        [self.glView setMultipleTouchEnabled:YES];
        if ([appDelegate isPadRetina] || [appDelegate isPhoneRetina]) {
            if ([self.glView respondsToSelector:@selector(contentScaleFactor)]) {
                [self.glView setContentScaleFactor:2.0];
            }
        }
        isFirstPlaying = NO;
        self.jcfName = nil;
        [self resetEditMember];
        bLoadTemplate = NO;
    }
    return self;
}

/** @ghidraAddress 0x21a94c */
- (void)resetEditMember {
    music_time = 0;
    edit_mode = kEditModeSwitch;
    edit_type = 0;
    bSeekMusicBar = NO;
    seekDefaultPos = 0;
    timeLineSector = 0;
    bSeekTimeLine = NO;
    timeLineSeekSector = 0;
    startIndex = -1;
    endIndex = -1;
    pasteSector = -1;
    areaStartDefaultSec = -1;
    areaEndDefaultSec = -1;
    bExistCopyData = NO;
    bClapReset = NO;
    targetTime = 0;
    bEnableClap = YES;
    bEnableUndoBtn = YES;
    bEnableGesture = YES;
    bEnablePanel = YES;
    bEnableControll = NO;
}

/** @ghidraAddress 0x21ad04 */
- (void)setGridButton:(UIButton *)button type:(int)type pos:(CGPoint)pos {
    NSString *imageName = [NSString stringWithFormat:kGridImageFormat, type];
    if (type == kGridDivideFree) {
        imageName = kGridFreeImageName;
    }
    UIImage *image = LoadScaledPngImage(imageName);
    [button setBackgroundImage:image forState:UIControlStateNormal];
    [button setFrame:CGRectMake(pos.x, pos.y, image.size.width, image.size.height)];
}

/** @ghidraAddress 0x21ae3c */
- (void)loadView {
    [super loadView];
    [self.view setAutoresizesSubviews:NO];
    [self.view addSubview:self.glView];

    self.btnPause = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.btnPause setExclusiveTouch:YES];
    [self.btnPause addTarget:self
                      action:@selector(pushBtnPause:)
            forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnPause];

    self.btnUndo = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.btnUndo setExclusiveTouch:YES];
    [self.btnUndo addTarget:self
                     action:@selector(pushBtnUndo:)
           forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnUndo];

    self.btnRedo = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.btnRedo setExclusiveTouch:YES];
    [self.btnRedo addTarget:self
                     action:@selector(pushBtnRedo:)
           forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnRedo];

    self.btnMode = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.btnMode setExclusiveTouch:YES];
    [self.btnMode addTarget:self
                     action:@selector(pushBtnMode:)
           forControlEvents:UIControlEventTouchUpInside];
    UILongPressGestureRecognizer *modePress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(longPressBtnMode:)];
    [self.btnMode addGestureRecognizer:modePress];
    ignorePress = NO;
    [self.view addSubview:self.btnMode];

    self.btnSysMenu = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.btnSysMenu setExclusiveTouch:YES];
    [self.btnSysMenu addTarget:self
                        action:@selector(pushbtnSysMenu:)
              forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnSysMenu];

    self.btnSelGrid = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.btnSelGrid setExclusiveTouch:YES];
    [self.btnSelGrid addTarget:self
                        action:@selector(pushBtnGridChange:)
              forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnSelGrid];

    self.btnClap = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.btnClap setExclusiveTouch:YES];
    [self.btnClap addTarget:self
                     action:@selector(pushClap:)
           forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnClap];

    self.btnHelp = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.btnHelp setExclusiveTouch:YES];
    [self.btnHelp addTarget:self
                     action:@selector(pushHelp:)
           forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnHelp];

    self.btnRewind = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.btnRewind setExclusiveTouch:YES];
    [self.btnRewind addTarget:self
                       action:@selector(pushRewind:)
             forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnRewind];

    self.btnAreaCpy = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.btnAreaCpy setExclusiveTouch:YES];
    [self.btnAreaCpy addTarget:self
                        action:@selector(pushAreaCopy:)
              forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnAreaCpy];

    self.btnAreaDel = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.btnAreaDel setExclusiveTouch:YES];
    [self.btnAreaDel addTarget:self
                        action:@selector(pushAreaDelete:)
              forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnAreaDel];

    self.btnAreaPst = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.btnAreaPst setExclusiveTouch:YES];
    [self.btnAreaPst addTarget:self
                        action:@selector(pushAreaPaste:)
              forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnAreaPst];

    [self createTimeLineView];
}

/** @ghidraAddress 0x21bb44 */
- (void)loadResources {
    EditRendererConf *conf = [[EditRendererConf alloc] init];
    [self resetEditMember];

    // The buttons stack down the right edge of the GL view. Each button's frame is
    // {x, y, imageWidth, imageHeight} with x measured from the view's right edge and y accumulating
    // down the column; the mode button splits on the device idiom.
    @autoreleasepool {
        UIImage *image = LoadScaledPngImage(kImagePauseBase);
        [self.btnPause setBackgroundImage:image forState:UIControlStateNormal];
        CGRect viewFrame = self.view.frame;
        double x = viewFrame.size.width - (double)(int)image.size.width;
        [self.btnPause setFrame:CGRectMake(x - 5.0, 5.0, image.size.width, image.size.height)];
        image = LoadScaledPngImage(kImagePauseButton);
        [self.btnPause setImage:image forState:UIControlStateNormal];
        [self.btnPause setEnabled:NO];
        isFirstPlaying = NO;
    }

    __block double columnY;
    @autoreleasepool {
        UIImage *image = LoadScaledPngImage(kImageModeSwitch);
        [self.btnMode setBackgroundImage:image forState:UIControlStateNormal];
        CGRect viewFrame = self.view.frame;
        // The mode button sits 14pt in from the view's right edge; the idiom sets its y nudge.
        double x = viewFrame.size.width - (double)(int)(image.size.width + 14.0);
        double y;
        if (!isPad) {
            x += 4.0;
            y = -4.0;
        } else {
            y = 0.0;
        }
        [self.btnMode setFrame:CGRectMake(x, y, image.size.width, image.size.height)];
        columnY = y;
    }

    @autoreleasepool {
        UIImage *image = LoadScaledPngImage(kImageSystemButton);
        [self.btnSysMenu setBackgroundImage:image forState:UIControlStateNormal];
        [self.btnSysMenu setFrame:CGRectMake(0.0, 0.0, image.size.width, image.size.height)];

        image = LoadScaledPngImage(kImageUndoButton);
        [self.btnUndo setBackgroundImage:image forState:UIControlStateNormal];
        double undoY = (double)(int)(columnY + image.size.height + 4.0);
        [self.btnUndo setFrame:CGRectMake(0.0, undoY, image.size.width, image.size.height)];

        image = LoadScaledPngImage(kImageRedoButton);
        [self.btnRedo setBackgroundImage:image forState:UIControlStateNormal];
        double redoY = (double)(int)(undoY + image.size.height + 8.0);
        [self.btnRedo setFrame:CGRectMake(0.0, redoY, image.size.width, image.size.height)];
        columnY = redoY;
    }

    @autoreleasepool {
        UIImage *image = LoadScaledPngImage(kImageRewindButton);
        [self.btnRewind setBackgroundImage:image forState:UIControlStateNormal];
        double rewindY = (double)(int)(columnY + image.size.height);
        [self.btnRewind setFrame:CGRectMake(0.0, rewindY, image.size.width, image.size.height)];

        image = LoadScaledPngImage(kImageGridBase);
        [self.btnSelGrid setBackgroundImage:image forState:UIControlStateNormal];
        double gridY = (double)(int)(rewindY + image.size.height);
        [self.btnSelGrid setFrame:CGRectMake(0.0, gridY, image.size.width, image.size.height)];
        image = LoadScaledPngImage(kImageGridArrow);
        [self.btnSelGrid setImage:image forState:UIControlStateNormal];

        image = LoadScaledPngImage(kImageClapOn);
        [self.btnClap setBackgroundImage:image forState:UIControlStateNormal];
        [self.btnClap setFrame:CGRectMake(kPasteButtonHiddenX,
                                          0.0,
                                          image.size.width,
                                          image.size.height)]; // @ghidraAddress 0x10028f1d8
        [self.btnClap setBackgroundColor:UIColor.clearColor];

        image = LoadScaledPngImage(kImageHelpButton);
        [self.btnHelp setBackgroundImage:image forState:UIControlStateNormal];
        double helpY = (double)(int)(image.size.height + 8.0 + kPasteButtonHiddenX);
        [self.btnHelp setFrame:CGRectMake(helpY, 0.0, image.size.width, image.size.height)];
        columnY = kPasteButtonHiddenX;
    }

    @autoreleasepool {
        // The area buttons overlap the clap button's -100pt hidden origin, stepping 20pt then 32pt.
        UIImage *image = LoadScaledPngImage(kImageAreaCopy);
        [self.btnAreaCpy setBackgroundImage:image forState:UIControlStateNormal];
        double copyY = (double)(int)(columnY + image.size.height + 20.0);
        [self.btnAreaCpy setFrame:CGRectMake(copyY, 0.0, image.size.width, image.size.height)];

        image = LoadScaledPngImage(kImageAreaDelete);
        [self.btnAreaDel setBackgroundImage:image forState:UIControlStateNormal];
        double delY = (double)(int)(copyY + image.size.height);
        [self.btnAreaDel setFrame:CGRectMake(delY, 0.0, image.size.width, image.size.height)];

        image = LoadScaledPngImage(kImageAreaPasteBase);
        [self.btnAreaPst setBackgroundImage:image forState:UIControlStateNormal];
        // @ghidraAddress 0x10028f1d8 (x = -100), @ghidraAddress 0x10028f458 (y = 32)
        [self.btnAreaPst
            setFrame:CGRectMake(kPasteButtonHiddenX, 32.0, image.size.width, image.size.height)];
        image = LoadScaledPngImage(kImageAreaPaste);
        [self.btnAreaPst setImage:image forState:UIControlStateNormal];

        [self.btnAreaCpy setHidden:YES];
        [self.btnAreaDel setHidden:YES];
        [self.btnAreaPst setHidden:YES];
    }

    [self.glView createFramebuffer];
    // The 2D space matches the device idiom: 768x1024 on phone, 320x480 on pad.
    if (isPad) {
        // @ghidraAddress 0x10028e098, 0x1002944a8
        [self.glView set2dSpace:CGSizeMake(320.0, 480.0)];
    } else {
        // @ghidraAddress 0x10028e090, 0x1002944a0
        [self.glView set2dSpace:CGSizeMake(768.0, 1024.0)];
    }

    self.mainGameRenderer =
        isPad ? [[EditNoteRendererPad alloc] init] : [[EditNoteRendererPhone alloc] init];
    NSString *clapPath = [NSBundle.mainBundle pathForResource:kClapResourceName
                                                       ofType:kClapResourceType];
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:clapPath], &clapID);
    [self.mainGameRenderer setEaglView:self.glView];
    [self.mainGameRenderer setState:0];
    [conf setTuneID:(unsigned int)[self.currentTune tuneID]];
    [conf setDiff:self.currentDiff];
    [conf setLevel:(unsigned int)[self.currentTune lvBas]];
    [conf setMarkerID:self.currentMarker];

    @autoreleasepool {
        [self loadNotesData];
    }

    UIImage *artwork = nil;
    UIImage *nameImage = nil;
    @autoreleasepool {
        KUnzip *unzip = [KUnzip alloc];
        if (self.musicData == nil) {
            unzip = [unzip initWithPath:[self.currentTune filePath] tail:0x10];
        } else {
            unzip = [unzip initWithData:self.musicData
                                  range:NSMakeRange(0, self.musicData.length - 0x10)];
        }
        if (unzip != nil) {
            BFCodec *codec = [[BFCodec alloc] init];
            NSData *key = GetBgmCipherKey();
            EditSequence *seq = [[EditSequence alloc] initWithData:unzip
                                                      sequenceData:self.editData];
            if (seq != nil) {
                self.sequence = seq;
                [self.sequence reset];
                [self.mainGameRenderer setSequence:self.sequence];
            }
            // Prime the four template slots with a fresh dictionary carrying the slot name and note
            // count from the sequence's template.
            for (int slot = 0; slot < kTemplateSlotCount; ++slot) {
                templateInfo[slot] = [[NSMutableDictionary alloc] init];
                NSNumber *notes =
                    [[NSNumber alloc] initWithUnsignedInt:[self.sequence getTemplateNoteNum:slot]];
                templateInfo[slot][kEditorInfoFumenNameKey] = kTemplateNames[slot];
                templateInfo[slot][kEditorInfoNotesNumKey] = notes;
            }

            NSData *bgm = [unzip uncompress:kArchiveSequenceMember];
            if (bgm != nil) {
                [codec cipherInit:key];
                [codec decipher:bgm];
                [[AudioManager sharedManager] loadBgmData:bgm];
                music_duration = [[AudioManager sharedManager] bgmDuration];
            }
            [codec cipherInit:key];
            NSData *artworkData = [unzip uncompress:kArchiveArtworkMember];
            if ((artworkData != nil) && [codec decipher:artworkData]) {
                artwork = [[UIImage alloc] initWithData:artworkData];
            }
            [codec cipherInit:key];
            NSData *nameData = [unzip uncompress:kArchiveNameMember];
            if ((nameData != nil) && [codec decipher:nameData]) {
                nameImage = [[UIImage alloc] initWithData:nameData];
            }
        }
        [self saveNotesData];
        self.musicData = nil;
        sequence_duration =
            (double)(((float)(int)[self.sequence getEndSector] + kEndSectorPadding) /
                     kSectorsPerSecond);
        [self.glView startRenderContext];
        [self.mainGameRenderer loadTexure:conf artwork:artwork index:nameImage];
    }

    [self.mainGameRenderer setState:0];
    isMusicPlaying = NO;
    bLoadTemplate = NO;
    mbarRect = [self.mainGameRenderer getTimeLineRect];
    loadCounter = 0;
    NSString *sePath = [NSBundle.mainBundle pathForResource:kClapResourceName
                                                     ofType:kClapResourceType];
    sePlayer = [[SePlayer alloc] initWithPath:sePath];
}

/** @ghidraAddress 0x21d38c */
- (void)releaseResources {
    [[AudioManager sharedManager] releaseBgm:YES];
    self.sequence = nil;
    [self.mainGameRenderer setSequence:nil];
    [self.glView startRenderContext];
    [self.mainGameRenderer releaseTexture];
    [self.glView destroyFramebuffer];
    self.mainGameRenderer = nil;
}

/** @ghidraAddress 0x21d4d0 */
- (void)saveScore {
    // Empty in the binary; kept as an interface stub.
}

#pragma mark - Note data

/** @ghidraAddress 0x219860 */
- (NSString *)getDirectoryPath:(unsigned int)tuneID {
    NSString *base = [[JubeatAppDelegate appDocumentsDirectory]
        stringByAppendingPathComponent:kEditDirectoryName];
    NSString *sub = [NSString stringWithFormat:kChartFileNameFormat, tuneID];
    NSFileManager *files = [NSFileManager defaultManager];
    NSError *error = nil;
    if (![files fileExistsAtPath:base]) {
        [files createDirectoryAtPath:base
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:&error];
    }
    NSString *path = [base stringByAppendingPathComponent:sub];
    if (![files fileExistsAtPath:path]) {
        [files createDirectoryAtPath:path
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:&error];
    }
    return path;
}

/** @ghidraAddress 0x219a14 */
- (void)loadNotesData {
    EditDataManager *manager = [EditDataManager sharedManager];
    [manager getDirectoryPath:(int)[self.currentTune tuneID]];
    newEditorInfo = nil;
    self.editData = nil;
    self.editorInfo = nil;
    self.jcfName = [manager getLastEditFileName:(int)[self.currentTune tuneID]];
    if (self.jcfName == nil) {
        newEditorInfo = [[NSMutableDictionary alloc] initWithDictionary:[manager getEditorInfo]];
    } else {
        NSString *path = [[manager getDirectoryPath:(int)[self.currentTune tuneID]]
            stringByAppendingPathComponent:self.jcfName];
        [manager loadJCF:path];
        self.editData = [manager getSequenceTable];
        self.editorInfo = [manager getEditorInfo];
        self.editSimpleData = [manager getEditSimpleData];
    }
}

/** @ghidraAddress 0x219cac */
- (void)importNotesData:(NSString *)fileName {
    EditDataManager *manager = [EditDataManager sharedManager];
    NSString *path = [[manager getDirectoryPath:(int)[self.currentTune tuneID]]
        stringByAppendingPathComponent:fileName];
    NSMutableDictionary *target = self.editorInfo;
    if (self.editorInfo == nil) {
        target = newEditorInfo;
    }
    [manager loadJCF:path];
    NSMutableDictionary *loaded =
        [NSMutableDictionary dictionaryWithDictionary:[manager getEditorInfo]];
    if ([loaded[kEditorInfoDlFlagKey] intValue] == 1) {
        if (loaded[kEditorInfoSequenceIDKey] != nil) {
            target[kEditorInfoOrgEditorNameKey] = loaded[kEditorInfoEditorNameKey];
            target[kEditorInfoOrgFumenIndexKey] = loaded[kEditorInfoSequenceIDKey];
        } else {
            target[kEditorInfoOrgEditorNameKey] = kEmptyLocalizedValue;
            target[kEditorInfoOrgFumenIndexKey] = kEmptyLocalizedValue;
        }
    } else {
        target[kEditorInfoOrgEditorNameKey] = loaded[kEditorInfoOrgEditorNameKey];
        target[kEditorInfoOrgFumenIndexKey] = loaded[kEditorInfoOrgFumenIndexKey];
    }
    [manager setBIsDownload:NO];
    target[kEditorInfoNotesNumKey] = loaded[kEditorInfoNotesNumKey];
    if (self.editorInfo == nil) {
        newEditorInfo = target;
    } else {
        self.editorInfo = target;
    }
    [manager setEditorInfo:target];
    self.editData = [manager getSequenceTable];
    [self.sequence importSequenceData:self.editData];
}

/** @ghidraAddress 0x21a1a4 */
- (void)autoSave:(BOOL)force {
    int counter = loadCounter;
    loadCounter = counter + 1;
    if ((counter > kAutoSaveCounterLimit) || force) {
        loadCounter = 0;
        [self saveNotesData];
    }
}

/** @ghidraAddress 0x21a1d8 */
- (void)saveNotesData {
    EditDataManager *manager = [EditDataManager sharedManager];
    NSString *base = [manager getDirectoryPath:(int)[self.currentTune tuneID]];
    if (self.jcfName == nil) {
        self.jcfName = [manager createJCFName];
    }
    NSString *path = [base stringByAppendingPathComponent:self.jcfName];
    NSMutableArray *events = [self.sequence getEventData];
    if (self.editorInfo == nil) {
        self.editorInfo = newEditorInfo;
        NSNumber *musicID = [[NSNumber alloc] initWithInteger:(NSInteger)[self.currentTune tuneID]];
        self.editorInfo[kEditorInfoMusicIDKey] = musicID;
    }
    NSNumber *notesNum = [[NSNumber alloc] initWithUnsignedInt:[self.sequence getNoteNum]];
    NSNumber *eventNum = [[NSNumber alloc] initWithUnsignedInt:[self.sequence getEventNum]];
    NSNumber *endSector = [[NSNumber alloc] initWithUnsignedInt:[self.sequence getEndSector]];
    NSNumber *firstMarker = [[NSNumber alloc] initWithUnsignedInt:[self.sequence getFirstMarker]];
    NSNumber *firstSector = [[NSNumber alloc] initWithUnsignedInt:[self.sequence getFirstSector]];
    if (self.editSimpleData == nil) {
        self.editSimpleData = [[NSMutableDictionary alloc] init];
    }
    self.editSimpleData[kEditorInfoNotesNumKey] = notesNum;
    self.editSimpleData[kSimpleDataEventNumKey] = eventNum;
    self.editSimpleData[kSimpleDataEndSectorKey] = endSector;
    self.editSimpleData[kSimpleDataFirstMarkerKey] = firstMarker;
    self.editSimpleData[kSimpleDataFirstSectorKey] = firstSector;
    // The 60-byte music bar is round-tripped through NSData to copy it out of the sequence buffer.
    unsigned char musicBar[60];
    NSData *bar = [[NSData alloc] initWithBytes:[self.sequence getMusicBar]
                                         length:sizeof(musicBar)];
    [bar getBytes:musicBar length:sizeof(musicBar)];
    self.editSimpleData[kSimpleDataMusicBarKey] = bar;
    [manager setEditorInfo:self.editorInfo];
    [manager setEditSimpleData:self.editSimpleData];
    [manager setSequenceTable:events];
    [manager saveJCF:path];
    [manager setLastEditFileName:(int)[self.currentTune tuneID] fileName:self.jcfName];
}

#pragma mark - Animation and music

/** @ghidraAddress 0x21d4d4 */
- (void)startAnimation {
    if (self.displayLink != nil) {
        [self.displayLink invalidate];
    }
    [self.mainGameRenderer resetCurrentTime];
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(loop:)];
    [self.displayLink setFrameInterval:2];
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

/** @ghidraAddress 0x21d654 */
- (void)stopAnimation {
    if (self.displayLink != nil) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

/** @ghidraAddress 0x21d6e8 */
- (void)finishMusic:(NSNotification *)notification {
    isMusicPlaying = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kFinishBgmNotificationName
                                                  object:nil];
}

/** @ghidraAddress 0x21d750 */
- (void)addNote:(BOOL)isSwitch {
    for (unsigned int panel = 0; panel < kPanelCount; ++panel) {
        if (buttonDown & (1u << (panel & 0x1f))) {
            if ([self.sequence addNote:panel divide:divMeasureType isSwitch:isSwitch] == 1) {
                NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOkKey
                                                                    value:kEmptyLocalizedValue
                                                                    table:nil];
                [[AlertViewManager sharedManager] makeAlert:0
                                                   delegate:self
                                                        tag:kAlertTagMarkerLimit
                                                      title:nil
                                                        msg:kMarkerLimitMessage
                                                     cancel:ok
                                                    btnText:nil
                                                       show:YES];
            }
            [self autoSave:NO];
        }
    }
}

/** @ghidraAddress 0x21d92c */
- (void)deleteNote {
    for (unsigned int panel = 0; panel < kPanelCount; ++panel) {
        if (buttonDown & (1u << (panel & 0x1f))) {
            [self.sequence deleteNote:panel];
            [self autoSave:NO];
        }
    }
}

/** @ghidraAddress 0x21d9e0 */
- (void)stopMusic {
    AudioManager *audio = [AudioManager sharedManager];
    if ([audio bgmPlaying]) {
        [audio stopBgm];
    }
    isMusicPlaying = NO;
    UIImage *image = LoadScaledPngImage(kImagePauseButton);
    [self.btnPause setImage:image forState:UIControlStateNormal];
}

/** @ghidraAddress 0x21daac */
- (void)controllMusic {
    AudioManager *audio = [AudioManager sharedManager];
    if (isMusicPlaying) {
        if (sequence_duration < (double)(float)music_time) {
            music_time = (double)(float)sequence_duration;
            [self.sequence seekToTime:music_time];
            float back = [self reverseAdjustTime:(float)music_time];
            [audio setBgmPos:(double)back];
            [self stopMusic];
        }
    }
}

/** @ghidraAddress 0x21fab0 */
- (void)exeClap {
    if (![self.sequence isClap]) {
        return;
    }
    if (bEnableClap) {
        int current = (int)[self.sequence currentSector];
        if (current < clapSector) {
            clapSector = current - kClapWindowSectors;
        }
        if ((current - clapSector) >= kClapWindowSectors) {
            [sePlayer sePlay];
            clapSector = (int)[self.sequence currentSector];
        }
    }
}

/** @ghidraAddress 0x21fbd8 */
- (void)startGame {
    float adjust = [[NSUserDefaults standardUserDefaults] floatForKey:kPrefAdjustSector];
    adjustTime = adjust / kSectorsPerSecond;
    bEnableControll = YES;
    [self.sequence reset];
    [self.sequence seekToTime:0];
    [self.mainGameRenderer setState:kRendererStateReady];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [self.mainGameRenderer setShowCombo:[defaults boolForKey:kPrefShowCombo]];
    float width = [defaults floatForKey:kPrefButtonWidth];
    // Clamp the preferred button width into [0, 1] before scaling it to touch pixels.
    if (!(width == 1.0f || (width < 1.0f))) {
        width = 1.0f;
    } else if (width < 0.0f) {
        width = 0.0f;
    }
    buttonTouchWidth = width * 20.0f;
}

#pragma mark - Button actions

/** @ghidraAddress 0x21fdc4 */
- (void)pushBtnPause:(id)sender {
    if (bEnableControll) {
        [[AudioManager sharedManager] playSeResFile:kPauseSePath inDirectory:nil];
        AudioManager *audio = [AudioManager sharedManager];
        UIImage *image;
        if (!isMusicPlaying) {
            [audio startBgm:NO fadeTime:0.0];
            isMusicPlaying = YES;
            image = LoadScaledPngImage(kImagePlayButton);
        } else {
            [audio stopBgm];
            isMusicPlaying = NO;
            image = LoadScaledPngImage(kImagePauseButton);
        }
        [self.btnPause setImage:image forState:UIControlStateNormal];
        [self resetGesture];
    }
}

/** @ghidraAddress 0x21ff3c */
- (void)deletePasteBtn {
    bEnablePaste = NO;
    [self.btnAreaPst setHidden:YES];
}

/** @ghidraAddress 0x21ff8c */
- (void)changeModeImage:(NSString *)imageName {
    UIImage *image = LoadScaledPngImage(imageName);
    [self.btnMode setBackgroundImage:image forState:UIControlStateNormal];
}

/** @ghidraAddress 0x21fff8 */
- (void)pushBtnAdd:(id)sender {
    if (bEnableControll) {
        ignorePress = NO;
        edit_mode = kEditModeAdd;
        [self changeModeImage:kImageModeAdd];
    }
}

/** @ghidraAddress 0x220040 */
- (void)pushBtnDelete:(id)sender {
    if (bEnableControll) {
        ignorePress = NO;
        edit_mode = kEditModeDelete;
        [self changeModeImage:kImageModeDelete];
    }
}

/** @ghidraAddress 0x220088 */
- (void)pushBtnMode:(id)sender {
    if (bEnableControll) {
        unsigned int mode;
        if (!ignorePress) {
            mode = (edit_mode != kEditModeControl);
            edit_mode = mode;
        } else {
            ignorePress = NO;
            mode = edit_mode;
        }
        [self changeModeImage:kModeImageNames[mode]];
    }
}

/** @ghidraAddress 0x220128 */
- (void)longPressBtnMode:(UILongPressGestureRecognizer *)gesture {
    if (bEnableControll && !ignorePress) {
        ignorePress = YES;
        btnList = nil;
        [self stopMusic];
        selectTemplateNum = -1;
        if (btnList == nil) {
            NSArray *titles = @[ kImageModeAdd, kImageModeDelete ];
            btnList = [[EditButtonViewController alloc] initWithButtonArray:titles
                                                                     selNum:-1
                                                                   delegate:self
                                                                   ctrlName:kModePopoverName];
            [btnList setModalPresentationStyle:UIModalPresentationPopover];
            UIPopoverPresentationController *popover = [btnList popoverPresentationController];
            [popover setDelegate:self];
            [popover setPermittedArrowDirections:UIPopoverArrowDirectionUp];
            [popover setSourceView:self.view];
            [popover setSourceRect:self.btnMode.frame];
            [self presentViewController:btnList animated:YES completion:nil];
        }
        [self resetGesture];
    }
}

/** @ghidraAddress 0x220364 */
- (void)pinchGesture:(UIPinchGestureRecognizer *)gesture {
    [self.mainGameRenderer setDbs:(float)gesture.scale];
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [self.mainGameRenderer saveBaseScale];
    }
}

/** @ghidraAddress 0x22044c */
- (void)pushBtnUndo:(id)sender {
    if (bEnableControll) {
        int depth = [self.sequence undoHistory];
        [self autoSave:(depth > kHistoryAutoSaveThreshold)];
        [self resetGesture];
    }
}

/** @ghidraAddress 0x2204f8 */
- (void)pushBtnRedo:(id)sender {
    if (bEnableControll) {
        int depth = [self.sequence redoHistory];
        [self autoSave:(depth > kHistoryAutoSaveThreshold)];
        [self resetGesture];
    }
}

/** @ghidraAddress 0x2205a4 */
- (void)pushbtnSysMenu:(id)sender {
    if (bEnableControll) {
        [self templateRelease];
        [self stopMusic];
        selectTemplateNum = -1;
        if (pFileListView == nil) {
            EditDataManager *manager = [EditDataManager sharedManager];
            NSMutableArray *fileList =
                [manager getFileInfoList:(unsigned int)[self.currentTune tuneID]];
            [fileList insertObject:templateInfo[0] atIndex:0];
            [fileList insertObject:templateInfo[1] atIndex:1];
            [fileList insertObject:templateInfo[2] atIndex:2];
            [fileList insertObject:templateInfo[3] atIndex:3];
            // The system menu popover is a fixed 300x400 point size. @ghidraAddress 0x10028f2d0
            pFileListView = [[EditSystemMenuview alloc] initWithSize:CGSizeMake(300.0, 400.0)];
            [pFileListView setFileList:fileList];
            [pFileListView setDelegate:self];
            [pFileListView setModalPresentationStyle:UIModalPresentationPopover];
            UIPopoverPresentationController *popover =
                [pFileListView popoverPresentationController];
            [popover setDelegate:self];
            [popover setPermittedArrowDirections:UIPopoverArrowDirectionUp];
            [popover setSourceView:self.view];
            [popover setSourceRect:self.btnSysMenu.frame];
            [self presentViewController:pFileListView animated:YES completion:nil];
        }
        [self resetGesture];
    }
}

/** @ghidraAddress 0x22087c */
- (void)pushBtnGridChange:(id)sender {
    if (bEnableControll) {
        btnList = nil;
        [self stopMusic];
        selectTemplateNum = -1;
        if (btnList == nil) {
            NSArray *titles = @[
                @"grid_1_1",
                @"grid_1_2",
                @"grid_1_4",
                @"grid_1_8",
                @"grid_1_3",
                @"grid_1_6",
                @"grid_free"
            ];
            // Map the current division type back to its selected popover index.
            int type = divMeasureType;
            int selected = (type == 2) ? 1 : 0;
            if (type == 4) {
                selected = 2;
            }
            if (type == 8) {
                selected = 3;
            }
            if (type == 3) {
                selected = 4;
            }
            if (type == 6) {
                selected = 5;
            }
            if (type == kGridDivideFree) {
                selected = 6;
            }
            btnList = [[EditButtonViewController alloc] initWithButtonArray:titles
                                                                     selNum:selected
                                                                   delegate:self
                                                                   ctrlName:kGridPopoverName];
            [btnList setModalPresentationStyle:UIModalPresentationPopover];
            UIPopoverPresentationController *popover = [btnList popoverPresentationController];
            [popover setDelegate:self];
            [popover setPermittedArrowDirections:UIPopoverArrowDirectionUp];
            [popover setSourceView:self.view];
            [popover setSourceRect:self.btnSelGrid.frame];
            [self presentViewController:btnList animated:YES completion:nil];
        }
    }
}

/** @ghidraAddress 0x220b50 */
- (void)selectGridType:(int)type {
    if (bEnableControll) {
        NSString *imageName = [NSString stringWithFormat:kGridImageFormat, type];
        if (type == kGridDivideFree) {
            imageName = kGridFreeImageName;
        }
        UIImage *image = LoadScaledPngImage(imageName);
        [self.btnSelGrid setBackgroundImage:image forState:UIControlStateNormal];
        divMeasureType = type;
        [self.mainGameRenderer setDivMeasure:type];
        if (type == kGridDivideFree) {
            [self.mainGameRenderer setDivMeasure:1];
        }
    }
}

/** @ghidraAddress 0x220ce0 */
- (void)longPressEnable:(BOOL)enable {
    if (bEnableControll) {
        [self.btnPause setEnabled:enable];
        [self.btnMode setEnabled:enable];
        [self.btnSysMenu setEnabled:enable];
        [self.btnSelGrid setEnabled:enable];
        [self.btnClap setEnabled:enable];
        [self.btnRewind setEnabled:enable];
        [self.btnHelp setEnabled:enable];
        bEnableUndoBtn = enable;
        [self.btnAreaCpy setHidden:enable];
        [self.btnAreaDel setHidden:enable];
        bEnablePanel = enable;
        [self.mainGameRenderer setEnableBtn:enable];
    }
}

#pragma mark - Area selection

/** @ghidraAddress 0x220f30 */
- (void)ReleaseSelectArea {
    bLongPress = NO;
    startIndex = -1;
    endIndex = -1;
    [self.mainGameRenderer setAreaStartSector:startIndex];
    [self.mainGameRenderer setAreaEndSector:endIndex];
}

/** @ghidraAddress 0x220fe4 */
- (void)pushAreaCopy:(id)sender {
    if (bEnableControll) {
        bExistCopyData = (BOOL)[self.sequence exeAreaCopy:startIndex endSec:endIndex];
        [self ReleaseSelectArea];
        [self longPressEnable:YES];
    }
}

/** @ghidraAddress 0x2210a0 */
- (void)pushAreaDelete:(id)sender {
    if (bEnableControll) {
        [self.sequence exeAreaDelete:startIndex endSec:endIndex];
        [self autoSave:YES];
        [self ReleaseSelectArea];
        [self longPressEnable:YES];
    }
}

/** @ghidraAddress 0x221154 */
- (void)pushAreaPaste:(id)sender {
    if (bEnableControll) {
        int result = [self.sequence exeAreaPaste:pasteSector];
        if (result == 0) {
            [self autoSave:YES];
        } else {
            NSString *message = nil;
            if (result == 2) {
                message = kPasteAreaMessage;
            } else if (result == 1) {
                message = kPasteLimitMessage;
            }
            NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOkKey
                                                                value:kEmptyLocalizedValue
                                                                table:nil];
            [[AlertViewManager sharedManager] makeAlert:0
                                               delegate:self
                                                    tag:kAlertTagMarkerLimit
                                                  title:nil
                                                    msg:message
                                                 cancel:ok
                                                btnText:nil
                                                   show:YES];
        }
        bEnablePaste = NO;
        pasteSector = -1;
        [self.mainGameRenderer setAreaStartSector:-1];
        [self.btnAreaPst setHidden:YES];
        CGRect frame = [self.btnAreaPst frame];
        frame.origin.x = kPasteButtonHiddenX; // @ghidraAddress 0x10028f1d8
        [self.btnAreaPst setFrame:frame];
    }
}

/** @ghidraAddress 0x221408 */
- (void)pushAreaPaste2:(id)sender {
    if (bEnableControll) {
        [self.sequence exeAreaPaste:[self.sequence currentSector]];
    }
}

/** @ghidraAddress 0x2214b0 */
- (void)pushClap:(id)sender {
    if (bEnableControll) {
        bEnableClap = bEnableClap ^ 1;
        [self.mainGameRenderer setEnableClap:bEnableClap];
        NSString *imageName = bEnableClap ? kImageClapOn : kImageClapOff;
        UIImage *image = LoadScaledPngImage(imageName);
        [self.btnClap setBackgroundImage:image forState:UIControlStateNormal];
        [self resetGesture];
    }
}

/** @ghidraAddress 0x2215c8 */
- (void)pushHelp:(id)sender {
    if (bEnableControll) {
        [self stopMusic];
        EditHowtoViewController *howto = [[EditHowtoViewController alloc] init];
        [howto setModalPresentationStyle:UIModalPresentationPopover];
        UIPopoverPresentationController *popover = [howto popoverPresentationController];
        [popover setDelegate:self];
        [popover setPermittedArrowDirections:UIPopoverArrowDirectionUp];
        [popover setSourceView:self.view];
        [popover setSourceRect:self.btnHelp.frame];
        [self presentViewController:howto animated:YES completion:nil];
        [self resetGesture];
    }
}

/** @ghidraAddress 0x221740 */
- (void)pushRewind:(id)sender {
    if (bEnableControll) {
        AudioManager *audio = [AudioManager sharedManager];
        float time = (float)(int)[self.sequence getRewindMeasureSector] / kSectorsPerSecond;
        targetTime = time;
        music_time = (double)time;
        float back = [self reverseAdjustTime:targetTime];
        [audio setBgmPos:(double)back];
        [self resetGesture];
    }
}

#pragma mark - Timeline and gestures

/** @ghidraAddress 0x221840 */
- (void)createTimeLineView {
    CGRect glFrame = [self.glView frame];
    // The timeline view is 80pt tall, 96pt down the GL view.
    // @ghidraAddress 0x10028f3f8, 0x10028f908
    self.timeLineView =
        [[UIView alloc] initWithFrame:CGRectMake(0.0, 80.0, glFrame.size.width, 96.0)];
    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(longPressGesture:)];
    [self.timeLineView addGestureRecognizer:longPress];
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)];
    [self.timeLineView addGestureRecognizer:tap];
    UITapGestureRecognizer *doubleTap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dpGesture:)];
    [doubleTap setNumberOfTapsRequired:2];
    [self.timeLineView addGestureRecognizer:doubleTap];
    UIPinchGestureRecognizer *pinch =
        [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchGesture:)];
    [self.timeLineView addGestureRecognizer:pinch];
    [self.glView addSubview:self.timeLineView];
}

/** @ghidraAddress 0x221af4 */
- (void)handleSwipe:(UISwipeGestureRecognizer *)gesture {
    (void)gesture.direction; // Yes, the binary reads the direction and discards it.
}

/** @ghidraAddress 0x221b04 */
- (void)resetPaste {
    bEnablePaste = NO;
    pasteSector = -1;
    [self.mainGameRenderer setAreaStartSector:-1];
    [self.btnAreaPst setHidden:YES];
}

/** @ghidraAddress 0x221b9c */
- (void)resetLongPress {
    bLongPress = NO;
    startIndex = -1;
    endIndex = -1;
    [self.mainGameRenderer setAreaStartSector:-1];
    [self.mainGameRenderer setAreaEndSector:-1];
}

/** @ghidraAddress 0x221c48 */
- (void)resetGesture {
    [self resetPaste];
    [self resetLongPress];
}

/** @ghidraAddress 0x221c7c */
- (void)longPressGesture:(UILongPressGestureRecognizer *)gesture {
    if (bEnableControll && bEnableGesture && !bLongPress) {
        unsigned int sector = [self.mainGameRenderer pos2sector:(int)touchPointBack.x];
        if (sector < [self.sequence getEndSector]) {
            if ([self.sequence getFrontBeatSector:sector] != -1) {
                if ([self.sequence getBackBeatSector:sector] != -1) {
                    bLongPress = YES;
                    [self longPressEnable:NO];
                    [self resetPaste];
                    unsigned int hit = [self.mainGameRenderer pos2sector:(int)touchPointBack.x];
                    startIndex = [self.sequence getFrontBeatSector:hit];
                    endIndex = [self.sequence getBackBeatSector:hit];
                    areaDefaultWidth = endIndex - startIndex;
                    [self.mainGameRenderer setAreaStartSector:startIndex];
                    [self.mainGameRenderer setAreaEndSector:endIndex];
                }
            }
        }
    }
}

/** @ghidraAddress 0x221f58 */
- (void)tapGesture:(UITapGestureRecognizer *)gesture {
    if (bEnableControll && bEnableGesture) {
        if (bLongPress) {
            [self resetLongPress];
            [self longPressEnable:YES];
        } else if (bEnablePaste) {
            [self resetPaste];
        }
    }
}

/** @ghidraAddress 0x221ffc */
- (void)dpGesture:(UITapGestureRecognizer *)gesture {
    if (bEnableControll && bEnableGesture && !bLongPress && bExistCopyData && !bEnablePaste) {
        unsigned int sector = [self.mainGameRenderer pos2sector:(int)touchPointBack.x];
        if (sector < [self.sequence getEndSector]) {
            pasteSector = [self.sequence getNearDiveBeatSector:sector divide:divMeasureType];
            [self.mainGameRenderer setAreaStartSector:pasteSector];
            int x = [self.mainGameRenderer sector2pos:pasteSector];
            CGRect frame = [self.btnAreaPst frame];
            frame.origin.x = (double)(x - kPasteButtonNudge);
            [self.btnAreaPst setFrame:frame];
            bEnablePaste = YES;
            [self.btnAreaPst setHidden:NO];
        }
    }
}

#pragma mark - Session lifecycle

/** @ghidraAddress 0x222298 */
- (void)resumeInPauseView {
    if ([[[JubeatAppDelegate appDelegate] rootViewCtrl] isActive]) {
        [self startAnimation];
        if (isMusicPlaying) {
            [[AudioManager sharedManager] startBgm:NO fadeTime:0.0];
        }
    }
}

/** @ghidraAddress 0x222380 */
- (void)endInPauseView {
    [[AlertViewManager sharedManager] closeAlert];
    [self saveNotesData];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kFinishBgmNotificationName
                                                  object:nil];
    [[[JubeatAppDelegate appDelegate] rootViewCtrl] returnFromEdit];
}

/** @ghidraAddress 0x222474 */
- (void)end {
    [self dismissViewControllerAnimated:YES completion:nil];
    [self endInPauseView];
}

/** @ghidraAddress 0x2224b0 */
- (void)suspend {
    switch ((int)[self.mainGameRenderer state]) {
    case kRendererStatePlaying:
        [self saveNotesData];
        [self stopAnimation];
        if (isMusicPlaying) {
            [self stopMusic];
        }
        break;
    case 0:
    case kRendererStateReady:
    case kRendererStateStarting:
    case kRendererStateEnding:
    case kRendererStateEnded:
        [self stopAnimation];
        break;
    default:
        break;
    }
}

/** @ghidraAddress 0x222594 */
- (void)resume {
    [self startAnimation];
}

/** @ghidraAddress 0x2225a0 */
- (void)terminate {
    AudioManager *audio = [AudioManager sharedManager];
    if ([audio bgmPlaying]) {
        [audio stopBgm];
    }
    [self stopAnimation];
    [self.glView prepareToRender];
    [self.glView swapBuffer];
    [self.glView resetTouches];
    [self.mainGameRenderer setState:0];
    bEnableControll = NO;
    self.jcfName = nil;
    music_time = 0;
    edit_mode = kEditModeControl;
    edit_type = 0;
    bSeekMusicBar = NO;
    seekDefaultPos = 0;
    timeLineSector = 0;
    bSeekTimeLine = NO;
    bEnableSeekTimeLine = NO;
    timeLineSeekSector = 0;
    startIndex = -1;
    endIndex = -1;
    pasteSector = -1;
    areaStartDefaultSec = -1;
    areaEndDefaultSec = -1;
    bExistCopyData = NO;
    bClapReset = NO;
    targetTime = 0;
    bEnableClap = YES;
    bEnableUndoBtn = YES;
    bEnableGesture = YES;
    bEnablePanel = YES;
    self.editData = nil;
    [self templateRelease];
    if (self.btnSelGrid != nil) {
        divMeasureType = 1;
        [self.mainGameRenderer setDivMeasure:1];
    }
    btnList = nil;
    [sePlayer terminate];
    sePlayer = nil;
}

/** @ghidraAddress 0x222b4c */
- (void)templateRelease {
    [pFileListView setDelegate:nil];
    pFileListView = nil;
}

#pragma mark - Delegate callbacks

/** @ghidraAddress 0x222b8c */
- (void)selectLoadSlot:(NSNumber *)slot {
    int index = [slot intValue];
    if (index >= 0) {
        selectTemplateNum = index;
        [self dismissViewControllerAnimated:NO completion:nil];
        NSString *cancel = [NSBundle.mainBundle localizedStringForKey:kCancelKey
                                                                value:kEmptyLocalizedValue
                                                                table:nil];
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOkKey
                                                            value:kEmptyLocalizedValue
                                                            table:nil];
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:self
                                                tag:kAlertTagLoad
                                              title:nil
                                                msg:kLoadConfirmMessage
                                             cancel:cancel
                                            btnText:@[ ok ]
                                               show:YES
                                     viewController:self];
    }
}

/** @ghidraAddress 0x222d78 */
- (void)selectExit {
    [self dismissViewControllerAnimated:YES completion:nil];
    [self endInPauseView];
}

/** @ghidraAddress 0x222db4 */
- (void)selectSave {
    // The conflict table spans 0x78 bytes; any non-zero entry means overlapping markers.
    const char *conflicts = [self.sequence getConflictBar];
    NSString *message = kSaveConfirmMessage;
    for (long i = 0; i < 0x78; ++i) {
        if (conflicts[i] != 0) {
            message = kSaveConflictMessage;
            break;
        }
    }
    NSString *cancel = [NSBundle.mainBundle localizedStringForKey:kCancelKey
                                                            value:kEmptyLocalizedValue
                                                            table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOkKey
                                                        value:kEmptyLocalizedValue
                                                        table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:self
                                            tag:kAlertTagSave
                                          title:nil
                                            msg:message
                                         cancel:cancel
                                        btnText:@[ ok ]
                                           show:YES];
}

/** @ghidraAddress 0x222fd4 */
- (void)editFileListViewCancel {
    // Empty in the binary.
}

/** @ghidraAddress 0x222fd8 */
- (void)editFileListViewDecideItem:(int)index {
    // Empty in the binary.
}

/** @ghidraAddress 0x222fdc */
- (void)popoverPresentationControllerDidDismissPopover:
    (UIPopoverPresentationController *)popoverPresentationController {
    ignorePress = NO;
}

/** @ghidraAddress 0x222fec */
- (void)editBtnSelect:(EditButtonViewController *)controller tag:(NSDictionary *)info {
    NSString *name = info[kButtonSelectNameKey];
    int select = [info[kButtonSelectSelectKey] intValue];
    if ([name isEqualToString:kGridPopoverName]) {
        [self selectGridType:kGridDivideTypes[select]];
    }
    if ([name isEqualToString:kModePopoverName]) {
        unsigned int mode = (select != 0) ? kEditModeDelete : kEditModeAdd;
        edit_mode = mode;
        [self changeModeImage:kModeImageNames[mode]];
    }
    ignorePress = NO;
    [self dismissViewControllerAnimated:YES completion:nil];
}

/** @ghidraAddress 0x223144 */
- (void)alertSelect:(NSDictionary *)info {
    int button = [info[kAlertButtonMessageKey] intValue];
    int tag = [info[kAlertTagKey] intValue];
    if (button != kAlertButtonOK) {
        return;
    }
    switch (tag) {
    case kAlertTagLoad:
        bLoadTemplate = YES;
        if (selectTemplateNum < kTemplateSlotCount) {
            [self.sequence loadTemplate:selectTemplateNum];
        } else {
            NSString *fileName =
                [pFileListView fileList][selectTemplateNum][kEditorInfoFileNameKey];
            [self importNotesData:fileName];
        }
        [self autoSave:YES];
        break;
    case kAlertTagSave:
        if (newEditorInfo != nil) {
            EditModalView *modal = [[EditModalView alloc] initWithType:1];
            [modal setEditDelegate:self];
            [self presentViewController:modal animated:YES completion:nil];
        } else {
            [self saveNotesData];
        }
        break;
    case kAlertTagExit:
        [self endInPauseView];
        break;
    default:
        break;
    }
}

/** @ghidraAddress 0x2233e0 */
- (void)editModalViewClose:(EditModalView *)view {
    [self dismissViewControllerAnimated:YES completion:nil];
}

/** @ghidraAddress 0x2233f4 */
- (void)editModalViewDelegateSaveEditFile {
    newEditorInfo = [[EditDataManager sharedManager] getEditorInfo];
    [self saveNotesData];
    newEditorInfo = nil;
}

#pragma mark - Time adjustment

/** @ghidraAddress 0x223484 */
- (float)adjustTime:(float)time {
    float result = time - adjustTime;
    if (result <= 0.0f) {
        result = 0.0f;
    }
    return result;
}

/** @ghidraAddress 0x2234a0 */
- (float)reverseAdjustTime:(float)time {
    float result = adjustTime + time;
    if (result <= 0.0f) {
        result = 0.0f;
    }
    return result;
}

#pragma mark - View lifecycle

/** @ghidraAddress 0x2228c4 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return (unsigned long long)(orientation - 1) < 2;
}

/** @ghidraAddress 0x2228d4 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x22290c */
- (void)viewDidUnload {
    [super viewDidUnload];
    [self.glView removeFromSuperview];
    self.btnPause = nil;
    self.btnMode = nil;
    self.btnSysMenu = nil;
    self.btnClap = nil;
    self.btnRewind = nil;
    self.btnSelGrid = nil;
    self.btnAreaCpy = nil;
    self.btnAreaDel = nil;
    self.btnAreaPst = nil;
    self.btnUndo = nil;
    self.btnRedo = nil;
    self.timeLineView = nil;
    [self templateRelease];
    btnList = nil;
}

/** @ghidraAddress 0x222a94 */
- (void)dealloc {
    [self setEditData:nil];
    [self stopAnimation];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kFinishBgmNotificationName
                                                  object:nil];
    AudioServicesDisposeSystemSoundID(clapID);
}

@end
