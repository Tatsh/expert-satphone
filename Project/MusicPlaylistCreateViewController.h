/**
 * @file
 * @brief The screen for naming a new music playlist: a single rounded-rect text field with a
 * navigation bar carrying a Cancel back button and a Done button that is enabled only while the
 * field holds text.
 *
 * Reconstructed from Ghidra program Jubeat (class MusicPlaylistCreateViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController , from the chain-up in @c -init (the @c objc_msgSendSuper2
 * dispatch to @c [UIViewController init]).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Receives the name entered on a @c MusicPlaylistCreateViewController .
 */
@protocol MusicPlaylistCreateViewControllerDelegate <NSObject>

@optional

/**
 * @brief Called when the user commits a non-empty playlist name.
 *
 * Sent via @c -respondsToSelector: / @c -performSelector:withObject: , so the method is optional.
 *
 * @param name The text entered in the field. This is the raw text, not the whitespace-trimmed
 * value the controller tested for emptiness.
 */
- (void)musicPlaylistCreateWithName:(nullable NSString *)name;

@end

/**
 * @brief A modal screen that asks the user to name a new music playlist.
 */
@interface MusicPlaylistCreateViewController : UIViewController <UITextFieldDelegate>

/**
 * @brief The object told which name the user entered.
 * @ghidraAddress 0x1671c4
 * @ghidraAddress 0x1671e4
 */
@property(nonatomic, weak, nullable) id<MusicPlaylistCreateViewControllerDelegate> delegate;

/**
 * @brief Builds the controller and its navigation bar.
 *
 * Sets the navigation title to the localized "New Playlist", installs a disabled system Done button
 * as the right bar button item wired to @c -tapDone: , and gives the back button the localized
 * "Cancel" title.
 *
 * @return The initialised controller.
 * @ghidraAddress 0x1667c8
 */
- (instancetype)init;

/**
 * @brief Builds the view hierarchy by hand.
 *
 * Creates the rounded-rect text field, disables autocapitalisation and autocorrection, gives it the
 * localized "Playlist Name" placeholder and a Done return key, wires its editing-changed event to
 * @c -fieldChanged: , makes the controller its delegate, and adds it to the view.
 *
 * @ghidraAddress 0x166a04
 */
- (void)loadView;

/**
 * @brief Enables the Done button only while the field is non-empty.
 * @param sender The text field that changed.
 * @ghidraAddress 0x166c40
 */
- (void)fieldChanged:(nullable id)sender;

/**
 * @brief Commits the entered name and pops the controller.
 *
 * Dismisses the keyboard, and when the whitespace-trimmed text is non-empty tells the delegate the
 * raw name, then pops back up the navigation stack.
 *
 * @param sender The Done button, or @c nil when invoked from @c -textFieldShouldReturn: .
 * @ghidraAddress 0x166cb0
 */
- (void)tapDone:(nullable id)sender;

/**
 * @brief Treats the return key as the Done button when the field is non-empty.
 * @param textField The text field. Unused.
 * @return Always @c YES .
 * @ghidraAddress 0x166e30
 */
- (BOOL)textFieldShouldReturn:(nullable UITextField *)textField;

/**
 * @brief Enforces the maximum name length and always allows a bare newline.
 * @param textField The text field being edited.
 * @param range The range being replaced.
 * @param string The replacement text.
 * @return @c YES when the change is permitted.
 * @ghidraAddress 0x166eac
 */
- (BOOL)textField:(nullable UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(nullable NSString *)string;

/**
 * @brief Lays the field out and asks the system not to extend the layout under the bars.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x166f9c
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * @brief Gives the field focus once the screen is on-screen.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x16707c
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * @brief Dismisses the keyboard as the screen leaves.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x1670d8
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * @brief Chains up to @c super only.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x167134
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * @brief Reports that only the two portrait orientations are supported.
 * @param interfaceOrientation The orientation being asked about.
 * @return @c YES for either portrait orientation.
 * @ghidraAddress 0x16716c
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @brief The orientations the screen allows.
 * @return Both portrait orientations.
 * @ghidraAddress 0x16717c
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Whether the screen rotates at all.
 * @return Always @c YES .
 * @ghidraAddress 0x167184
 */
- (BOOL)shouldAutorotate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
