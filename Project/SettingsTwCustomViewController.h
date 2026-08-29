/**
 * @file
 * The Twitter-share customisation preview screen.
 *
 * It shows the currently selected background frame with the accessory composited over it, scaled
 * to fit the device, and acts as the delegate of the @c SettingsTwFrameSelectView so a live
 * preview follows the row the user is touching. Selecting a frame persists it; merely changing the
 * highlighted row only previews it without committing.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsTwCustomViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The class object is at 0x349358.
 */

#import <UIKit/UIKit.h>

#import "SettingsTwFrameSelectView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A modal preview of the composed Twitter-share image (frame plus accessory) that doubles as
 * the frame-select view's delegate.
 */
@interface SettingsTwCustomViewController : UIViewController <SettingsTwFrameSelectViewDelegate>

/**
 * Builds the navigation item, the frame table of selectable themes, and seeds the selected
 * frame default when none is stored.
 * @return The initialised controller.
 * @ghidraAddress 0x1c47a8
 */
- (instancetype)init;

/**
 * Builds the preview: a dimmed backdrop, the frame sample image scaled to the device, and
 * the accessory image composited over it.
 * @ghidraAddress 0x1c4cc4
 */
- (void)loadView;

/**
 * Sent by the frame-select view while the user drags across rows: previews the frame without
 * persisting it, restoring the stored frame afterwards.
 * @param identifier The highlighted frame's identifier.
 * @ghidraAddress 0x1c53b0
 */
- (void)frameChange:(nullable NSString *)identifier;

/**
 * Sent by the frame-select view when a row is chosen: previews the frame and then persists
 * it as the selected frame.
 * @param identifier The chosen frame's identifier.
 * @ghidraAddress 0x1c5494
 */
- (void)frameSelected:(nullable NSString *)identifier;

/**
 * Chains to the superclass.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x1c5524
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * Chains to the superclass.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x1c555c
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * Chains to the superclass, then flushes the user defaults so the frame choice is saved.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x1c5594
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * Chains to the superclass.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x1c5608
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * Whether the controller may rotate to an interface orientation (portrait orientations
 * only).
 * @param interfaceOrientation The candidate orientation.
 * @return @c YES for portrait and portrait-upside-down.
 * @ghidraAddress 0x1c5640
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * The supported interface orientations (portrait mask).
 * @return @c UIInterfaceOrientationMaskPortrait | @c UIInterfaceOrientationMaskPortraitUpsideDown .
 * @ghidraAddress 0x1c5650
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * Whether the controller should autorotate.
 * @return Always @c YES .
 * @ghidraAddress 0x1c5658
 */
- (BOOL)shouldAutorotate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
