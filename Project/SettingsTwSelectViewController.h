/**
 * @file
 * The Twitter share-frame selector settings screen: a paged, horizontally scrolling gallery
 * of selectable frame designs.
 *
 * Each page shows one frame sample (with an accessory composited over it) plus a set of
 * selection-cursor markers, a page control tracks the current page, two edge arrows fade in and
 * out with the scroll offset, and a reward-check button drives the reward-unlock download flow
 * through an @c EditorIDManager provisioning download.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsTwSelectViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The controller is the delegate of its own @c UIScrollView, the delegate of the reward
 * @c EditorIDManager download (through @c EditorIDManagerDelegate ), and a @c RewardCheckDelegate .
 * Its superclass is @c UIViewController (every @c super chain targets @c UIViewController ).
 */

#import <UIKit/UIKit.h>

#import "EditorIDManager.h"
#import "RewardCheck.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A modal, paged frame-select gallery for the Twitter-share background frame.
 */
// clang-format off
// One protocol per line: the packed form, which begins a continuation line with ": UIViewController
// <", is read by Doxygen as undocumented ivars named after the trailing protocols.
@interface SettingsTwSelectViewController : UIViewController <UIScrollViewDelegate,
                                                              EditorIDManagerDelegate,
                                                              RewardCheckDelegate>
// clang-format on

/**
 * Scales a rect's every component by the device scale @c fScale .
 * @param rect The unscaled rect.
 * @return The scaled rect.
 * @ghidraAddress 0x7b86c
 */
- (CGRect)makeRect:(CGRect)rect;

/**
 * Builds the navigation title and the working frame table, seeding the current page from the
 * stored selected-frame default.
 * @return The initialised controller.
 * @ghidraAddress 0x7b890
 */
- (instancetype)init;

/**
 * Builds the whole gallery: the background image, the header label, the reward-check button,
 * the paged scroll view of frame samples, the page control, the two scroll arrows, and the
 * selection-cursor markers.
 * @ghidraAddress 0x7be5c
 */
- (void)loadView;

/**
 * Fades the two scroll arrows in and out with the scroll offset.
 *
 * The misspelling @c Controll is preserved from the binary.
 * @ghidraAddress 0x7d0c0
 */
- (void)scrollBtnAlphaControll;

/**
 * Updates the selection-cursor markers: their alpha, their rotation, and (when settled on a
 * page) their per-slot lock visibility.
 *
 * The misspelling @c Controll is preserved from the binary.
 * @ghidraAddress 0x7d18c
 */
- (void)scrollCursorControll;

/**
 * The frame row whose identifier (element 1) matches the stored selected-frame default.
 * @return The matching row, or @c nil when none matches.
 * @ghidraAddress 0x7d668
 */
- (nullable NSMutableArray *)getSelectedFrame;

/**
 * Refreshes the per-slot lock images. The shipped body is empty.
 * @ghidraAddress 0x7d840
 */
- (void)refreshLockImage;

/**
 * Pushes the reward view controller when a navigation controller is present.
 * @param sender The tapping control.
 * @ghidraAddress 0x7d844
 */
- (void)pushBtnReward:(nullable id)sender;

/**
 * Reward-check button action. The shipped body is empty.
 * @param sender The tapping control.
 * @ghidraAddress 0x7d8f8
 */
- (void)pushBtnRewardCheck:(nullable id)sender;

/**
 * Scroll-arrow action: steps the current page one left or one right (by the arrow's tag) and
 * animates the scroll view to that page.
 * @param sender The tapped arrow button.
 * @ghidraAddress 0x7d8fc
 */
- (void)scrollChange:(nullable id)sender;

/**
 * Whether the frame with the given identifier is unlocked.
 * @param identifier The frame identifier to test against each row's element 1.
 * @return The slot's unlock state, or @c NO when no row matches.
 * @ghidraAddress 0x7da58
 */
- (BOOL)isUnlockFrame:(nullable NSString *)identifier;

/**
 * Whether the frame in a given slot is unlocked. Always @c YES in the shipped build.
 * @param slot The frame slot index.
 * @return Always @c YES .
 * @ghidraAddress 0x7db74
 */
- (BOOL)isUnlockFrameWithSlot:(int)slot;

/**
 * @c RewardCheckDelegate callback. The shipped body is empty.
 * @param rewardCheck The reward checker that finished.
 * @ghidraAddress 0x7db7c
 */
- (void)rewardCheckEnd:(nullable id)rewardCheck;

/**
 * @c EditorIDManagerDelegate success callback: releases the manager.
 * @param manager The manager that finished.
 * @ghidraAddress 0x7db80
 */
- (void)successIDDownload:(nullable id)manager;

/**
 * @c EditorIDManagerDelegate error callback: releases the manager.
 * @param manager The manager that failed.
 * @param msgStr The server-supplied message, or nil.
 * @ghidraAddress 0x7db98
 */
- (void)errorIDDownload:(nullable id)manager msgStr:(nullable NSString *)msgStr;

/**
 * Stops and removes the loading indicator, then fades the selection markers back to full
 * opacity.
 * @param animated Whether the indicator's stop is animated.
 * @ghidraAddress 0x7dbb0
 */
- (void)itemDisp:(BOOL)animated;

/**
 * Chains to the superclass.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x7de48
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * Chains to the superclass.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x7de80
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * Chains to the superclass, then persists the current frame if unlocked, closes any alert,
 * and flushes the user defaults.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x7deb8
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * Chains to the superclass.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x7e088
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * @c UIScrollViewDelegate scroll callback: recomputes the current page from the offset,
 * updates the page control, and refreshes the arrow alpha and the selection cursor.
 * @param scrollView The scrolling view.
 * @ghidraAddress 0x7e0c0
 */
- (void)scrollViewDidScroll:(nonnull UIScrollView *)scrollView;

/**
 * Whether the controller may rotate to an interface orientation (portrait orientations
 * only).
 * @param interfaceOrientation The candidate orientation.
 * @return @c YES for portrait and portrait-upside-down.
 * @ghidraAddress 0x7e194
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * The supported interface orientations (portrait mask).
 * @return @c UIInterfaceOrientationMaskPortrait | @c UIInterfaceOrientationMaskPortraitUpsideDown .
 * @ghidraAddress 0x7e1a4
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * Whether the controller should autorotate.
 * @return Always @c YES .
 * @ghidraAddress 0x7e1ac
 */
- (BOOL)shouldAutorotate;

/**
 * Chains to the superclass.
 * @ghidraAddress 0x7e1b4
 */
- (void)dealloc;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
