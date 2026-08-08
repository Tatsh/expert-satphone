/** @file
 * The inherit-code payment view — the screen that requests and displays an inherit code.
 *
 * Reconstructed from Ghidra program Jubeat (class InheritCodePayView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView , from the dyld bind at the class object's superclass slot
 * (0x348da8 resolves to @c _OBJC_CLASS_$_UIView ).
 *
 * The class is complete: all four hand-written members are recovered — verified against the
 * disassembly on port 8089 with the Jubeat program, not from the decompile.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The view that requests an inherit code from the server and displays it.
 */
@interface InheritCodePayView : UIView

/**
 * @brief The controller the alerts are presented from.
 * @ghidraAddress 0x349a94
 */
@property(nonatomic, weak, nullable) UIViewController *parentCtrl;

/**
 * @brief Builds the view: a background image, a caution label, and the issue button.
 * @param frame The frame.
 * @return The initialised view.
 * @ghidraAddress 0x39714
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Sends the issue request through a @c SessionDownloader with the editor identity.
 * @param sender The issue button.
 * @ghidraAddress 0x39b40
 */
- (void)tapCodeOutput:(nullable id)sender;

/**
 * @brief Called when the request finishes; on success it builds and reveals the code panel.
 * @param downloader The finished downloader.
 * @ghidraAddress 0x39d08
 */
- (void)downloaderFinished:(id)downloader;

/**
 * @brief Called when the request fails; shows the server-error alert.
 * @param downloader The failed downloader.
 * @ghidraAddress 0x3a998
 */
- (void)downloaderError:(id)downloader;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
