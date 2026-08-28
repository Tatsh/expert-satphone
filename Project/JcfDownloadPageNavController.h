/** @file
 * The navigation controller that wraps the jubeatLab custom-sequence (jcf) download web page.
 *
 * Reconstructed from Ghidra program Jubeat (class JcfDownloadPageNavController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * A @c UINavigationController that hosts a single @c JcfDownloadPageViewController showing the
 * jubeatLab custom-sequence download page. It can be opened three ways — by music id, by sequence
 * id, or by a prebuilt URL — and it builds the local test-page file URL. It sets up its own
 * navigation bar chrome and a left "Close" button that notifies the delegate.
 */

#import <UIKit/UIKit.h>

@class JcfDownloadPageNavController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c JcfDownloadPageNavController tells its owner. The delegate is messaged
 * dynamically behind @c -respondsToSelector: ; this protocol only documents the selector.
 */
@protocol JcfDownloadPageNavControllerDelegate <NSObject>
@optional
/**
 * @brief The user closed the custom-sequence web page.
 * @param controller The navigation controller sending the message.
 * @param seqIndex The sequence index the page was showing.
 */
- (void)customWebViewClose:(nullable JcfDownloadPageNavController *)controller
                  seqIndex:(nullable NSString *)seqIndex;
@end

/**
 * @brief Hosts the jubeatLab custom-sequence download web page in a navigation controller.
 */
@interface JcfDownloadPageNavController : UINavigationController

/**
 * @brief Builds the local test-page request URL used by the download web view.
 * @param sequenceIDArg Unused; present to match the binary's selector.
 * @return A request for the @c DlTestPage.html file in the app documents directory.
 * @ghidraAddress 0x1e5914
 */
- (nullable NSURLRequest *)createCustomSequenceURL:(unsigned int)sequenceIDArg;

/**
 * @brief Configures the navigation bar chrome (style, tint, and background colours).
 * @ghidraAddress 0x1e59d8
 */
- (void)initNavigationBar;

/**
 * @brief Opens the download page for a music id.
 * @param musicID The music id to download.
 * @param delegate The object told when the page closes.
 * @return The initialised navigation controller.
 * @ghidraAddress 0x1e5c20
 */
- (instancetype)initWithMusicID:(unsigned int)musicID
                       delegate:(nullable id<JcfDownloadPageNavControllerDelegate>)delegate;

/**
 * @brief Opens the download page for a sequence id.
 * @param sequenceID The sequence id to download.
 * @param delegate The object told when the page closes.
 * @return The initialised navigation controller.
 * @ghidraAddress 0x1e5e8c
 */
- (instancetype)initWithSequenceID:(nullable NSString *)sequenceID
                          delegate:(nullable id<JcfDownloadPageNavControllerDelegate>)delegate;

/**
 * @brief Opens the download page for a prebuilt URL.
 * @param url The URL string to load.
 * @param delegate The object told when the page closes.
 * @return The initialised navigation controller.
 * @ghidraAddress 0x1e6118
 */
- (instancetype)initWithURL:(nullable NSString *)url
                   delegate:(nullable id<JcfDownloadPageNavControllerDelegate>)delegate;

/**
 * @brief Left "Close" button action: persists defaults and notifies the delegate.
 * @param sender The bar button item.
 * @ghidraAddress 0x1e63a4
 */
- (void)pushClose:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
