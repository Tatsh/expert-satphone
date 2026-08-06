/** @file
 * The store's modal progress panel.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreDialogView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, from the dyld bind at the class object's superclass slot
 * (0x34e480).
 */

#import <UIKit/UIKit.h>

#import "StoreButton.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c StoreDialogView tells its owner.
 */
@protocol StoreDialogViewDelegate <NSObject>
@optional
/**
 * @brief Sent when the abort button is pressed.
 * @param dialogView The panel whose button was pressed.
 */
- (void)storeDialogCancel:(id)dialogView;
@end

/**
 * @brief A rounded panel with a spinner, a one-line message, a progress bar and an abort button.
 *
 * The panel is built at a fixed internal layout and then switched between two modes by
 * @c -layout: , which hides or shows the bar and the button and moves the message to suit.
 */
@interface StoreDialogView : UIView

/**
 * @brief The object told when the panel is aborted.
 *
 * Weak and untyped in the metadata, so the dispatch goes through @c -respondsToSelector: rather
 * than a declared conformance.
 */
@property(nonatomic, weak) id delegate;

/**
 * @brief The spinner, at a fixed forty points square.
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicatorView;

/**
 * @brief The single-line status message.
 */
@property(nonatomic, strong, nullable) UILabel *labelMessage;

/**
 * @brief The download progress bar.
 */
@property(nonatomic, strong, nullable) UIProgressView *progressView;

/**
 * @brief The abort button.
 */
@property(nonatomic, strong, nullable) StoreButton *buttonAbort;

/**
 * @brief Builds the panel's four subviews.
 *
 * @param frame The panel's frame. Every subview's position is derived from its size.
 * @return The initialised panel.
 * @ghidraAddress 0xd6c20
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Switches the panel between its message-only and its progress modes.
 *
 * @param hidden @c YES hides the bar and the button and drops the message ten points below centre;
 * @c NO shows them and lifts the message ten points above it.
 * @ghidraAddress 0xd765c
 */
- (void)layout:(BOOL)hidden;

/**
 * @brief The abort button's action.
 * @param sender The button. Unused — the delegate is handed the panel.
 * @ghidraAddress 0xd77cc
 */
- (void)btnAbort:(id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
