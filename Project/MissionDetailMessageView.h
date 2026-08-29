/**
 * @file
 * A mission-detail message overlay.
 *
 * Reconstructed from Ghidra program Jubeat (class MissionDetailMessageView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The panel shows a mission's title, explanatory text, and achievement count, an optional
 * scrollable detail text view listing the play-term conditions, and a row of pass (skip with jCube
 * cost), switch (show/hide the detail), and close buttons. It fades in and out on a repeating timer
 * and, for the skip purchase, presents a confirmation alert through @c AlertViewManager and speaks
 * to its delegate.
 *
 * The superclass was read from the class object's superclass slot, which binds to
 * @c _OBJC_CLASS_$_UIView at load time. Both initialisers chain to @c -[UIView initWithFrame:].
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "ChallengeMissionAchieve.h"
#import "ChallengeMissionPlayTerm.h"
#import "ChallengeMissionTerms.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * What a @c MissionDetailMessageView asks its owner to do.
 *
 * The delegate ivar is weak and untyped in the metadata (@c \@,W,N); every send is guarded by
 * @c -respondsToSelector:, so all three methods are effectively optional and the conformance is
 * not declared on the ivar's type.
 */
@protocol MissionDetailMessageViewDelegate <NSObject>
@optional
/** The player asked to buy jCube because the skip cost exceeds the balance. */
- (void)cubePurchase;
/** The player confirmed spending jCube to skip the mission. */
- (void)missionSkip;
/** The close button was tapped and the owner should dismiss the overlay. */
- (void)closeDetail;
@end

/**
 * A centred overlay describing one mission and offering to skip it for jCube.
 */
@interface MissionDetailMessageView : UIView <AlertViewManagerDelegate>

/**
 * The object told about skip, purchase, and close events. Held weakly.
 * @ghidraAddress 0xeccf8 (getter), 0xecd18 (setter)
 */
@property(nonatomic, weak, nullable) id<MissionDetailMessageViewDelegate> aDelegate;

/**
 * Builds the overlay and immediately covers @c coverFrame.
 *
 * Contrary to its name this initialiser ignores @c frame entirely and chains to
 * @c -[UIView initWithFrame:] with @c coverFrame; it does not run the layout in
 * @c -initWithFrame: .
 *
 * @param frame Ignored.
 * @param coverFrame The frame passed straight to the superclass.
 * @return The initialised view.
 * @ghidraAddress 0xea078
 */
- (instancetype)initWithFrame:(CGRect)frame coverFrame:(CGRect)coverFrame;

/**
 * Builds the overlay, laying out the background, three labels, the detail text view, and the
 * close, pass, and switch buttons, all sized per idiom from the background artwork.
 *
 * @param frame The area to size the panel against; the background is centred horizontally within
 *              @c frame.size.width and positioned relative to @c frame.size.height .
 * @return The initialised view.
 * @ghidraAddress 0xea0c0
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Fills the labels from the mission's terms and achievement, formats the achievement count,
 * and shows or hides the pass button according to the skip cost and achievement state.
 *
 * @param mission The mission whose title, text, detail, type, and skip cost are read.
 * @param achieve The achievement whose id, detail dictionary, and state are read.
 * @ghidraAddress 0xeacc0
 */
- (void)setMission:(nonnull ChallengeMissionTerms *)mission
           achieve:(nonnull ChallengeMissionAchieve *)achieve;

/**
 * Resolves a tune's display name by its music id within the scratch line-up.
 *
 * @param musicID The music id to look up.
 * @return The tune name, or @c nil when the id is not in the line-up.
 * @ghidraAddress 0xeb274
 */
- (nullable NSString *)getMusicName:(int)musicID;

/**
 * Formats the play-term conditions into the detail text view and enables the switch button
 * when any condition text was produced.
 *
 * @param playTerm The play-term conditions (music, level, marker, and history restrictions).
 * @ghidraAddress 0xeb40c
 */
- (void)setPlayTerm:(nullable ChallengeMissionPlayTerm *)playTerm;

/**
 * The pass button's action: confirms the jCube skip purchase, or offers to buy jCube when
 * the balance is short, through @c AlertViewManager .
 * @ghidraAddress 0xec214
 */
- (void)tapPassBtn;

/**
 * Adds the view to @c parentView and starts the fade-in timer.
 * @param parentView The view to add this overlay to.
 * @ghidraAddress 0xec578
 */
- (void)fadeIn:(nonnull UIView *)parentView;

/**
 * Starts the fade-out timer.
 * @ghidraAddress 0xec670
 */
- (void)fadeOut;

/**
 * Snaps the alpha to zero, invalidates the fade timer, and removes the view from its parent.
 * @ghidraAddress 0xec6fc
 */
- (void)fadeCancel;

/**
 * The fade timer's tick: steps the alpha towards the target and, once the endpoint is
 * reached, stops the timer (removing the view when fading out).
 * @param timer The firing timer. Unused.
 * @ghidraAddress 0xec7a0
 */
- (void)timerRefresh:(nonnull NSTimer *)timer;

/**
 * The @c AlertViewManager delegate callback: routes the skip or purchase confirmation to the
 * delegate.
 * @param info The alert result, carrying the tapped button index and the alert tag.
 * @ghidraAddress 0xec880
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

/**
 * The @c Downloader error callback: stops ignoring interaction and shows the server-error
 * alert.
 * @param downloader The downloader that failed. Unused.
 * @ghidraAddress 0xeca48
 */
- (void)downloaderError:(nullable id)downloader;

/**
 * The @c Downloader success callback. Empty in the binary.
 * @param downloader The downloader that finished. Unused.
 * @ghidraAddress 0xecbc4
 */
- (void)downloaderFinished:(nullable id)downloader;

/**
 * The switch button's action: toggles the detail text view against the mission text.
 * @ghidraAddress 0xecbc8
 */
- (void)tapSwitch;

/**
 * The close button's action: asks the delegate to dismiss the overlay.
 * @ghidraAddress 0xecc48
 */
- (void)tapCloseBtn;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
