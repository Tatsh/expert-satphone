/**
 * @file
 * The inherit-code input view — the screen that enters an inherit code to migrate an
 * account.
 *
 * Reconstructed from Ghidra program Jubeat (class InheritCodeInputView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. The class object is at
 * 0x34e2e8. The sibling @c InheritCodePayView issues codes; this view consumes them.
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The view that submits an inherit code and, on success, replaces the local account.
 */
@interface InheritCodeInputView : UIView <AlertViewManagerDelegate>

/**
 * The controller the alerts are presented from.
 * @ghidraAddress 0xd191c (getter)
 */
@property(nonatomic, weak, nullable) UIViewController *parentCtrl;

/**
 * Builds the view: a background image, a caution label, the code field, and the send button.
 * @param frame The frame.
 * @return The initialised view.
 * @ghidraAddress 0xd0140
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Validates the entered code and submits it through a @c SessionDownloader.
 * @param sender The send button.
 * @ghidraAddress 0xd06e0
 */
- (void)tapCodeInput:(nullable id)sender;

/**
 * Called when the confirmation alert closes; does nothing.
 * @param info The alert info.
 * @ghidraAddress 0xd0964
 */
- (void)alertClose:(nonnull NSDictionary *)info;

/**
 * Called when the confirmation alert is answered; on OK it submits the replace request.
 * @param info The alert info.
 * @ghidraAddress 0xd0968
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

/**
 * Called when a request finishes; drives the confirm/replace/success/error flow.
 * @param downloader The finished downloader.
 * @ghidraAddress 0xd0b90
 */
- (void)downloaderFinished:(nonnull id)downloader;

/**
 * Called when a request fails; shows the server-error alert.
 * @param downloader The failed downloader.
 * @ghidraAddress 0xd1778
 */
- (void)downloaderError:(nonnull id)downloader;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
