/**
 * @file
 * @brief The challenge-mode name-entry field with its commit button.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeTextInputView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. The class object is at
 * 0x34d708.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ChallengeTextInputView;

/**
 * @brief Told when the name field's edit is committed.
 */
@protocol ChallengeTextInputViewDelegate <NSObject>
@optional
/**
 * @brief The field's text was committed.
 * @param inputView The input view whose text was committed.
 */
- (void)commitText:(nonnull ChallengeTextInputView *)inputView;
@end

/**
 * @brief A single-line name-entry field paired with a commit button, clamping the entry to at most
 * 20 characters and reporting the committed text to its delegate.
 */
@interface ChallengeTextInputView : UIView <UITextFieldDelegate>

/** @brief The name-entry text field. @ghidraAddress 0x94888 (getter) */
@property(nonatomic, strong, nullable) UITextField *nameBox;
/** @brief The commit button. @ghidraAddress 0x948ac (getter) */
@property(nonatomic, strong, nullable) UIButton *changeBtn;
/** @brief The delegate told when the entry is committed. Held weakly.
 *  @ghidraAddress 0x948d0 (getter), 0x948f0 (setter) */
@property(nonatomic, weak, nullable) id<ChallengeTextInputViewDelegate> aDelegate;
/** @brief The last backed-up field text, clamped to 20 characters. @ghidraAddress 0x94904 (getter)
 */
@property(nonatomic, readonly, nullable) NSString *inputText;

/**
 * @brief Clears the field text, the backed-up text, and the button image.
 * @ghidraAddress 0x9415c
 */
- (void)resetView;

/**
 * @brief Sets the field's text and backs it up as the current input.
 * @param text The text to show.
 * @ghidraAddress 0x941e4
 */
- (void)setDefaultText:(nullable NSString *)text;

/**
 * @brief Whether a string round-trips to empty through Shift-JIS (i.e. is purely pictographic).
 * @param text The string to test.
 * @return @c YES when the Shift-JIS round-trip is empty.
 * @ghidraAddress 0x94514
 */
- (BOOL)isPictText:(nullable NSString *)text;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
