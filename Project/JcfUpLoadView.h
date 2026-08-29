/**
 * @file
 * @brief The modal board that uploads one jubeatLab custom sequence (a @c .jcf chart).
 *
 * Reconstructed from Ghidra program Jubeat (class JcfUpLoadView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView: @c -initWithData:delegate:ctrl: calls @c -[super initWithFrame:]
 * with the board's own size (0x1f31b0). The view is itself the gradient-backed board —
 * @c +layerClass returns @c CAGradientLayer — shown over a dimmed parent. It is the counterpart
 * to @c JcfDownloadView : rather than downloading a chart it uploads one through an owned
 * @c JcfUploader , after a licence-agreement step (@c LicenseAgreementView ), and on success
 * reveals Twitter and Facebook share buttons. It is the uploader's delegate, implementing the three
 * @c JcfUploaderDelegate outcome selectors.
 */

#import <UIKit/UIKit.h>

#import "JcfUploader.h"

NS_ASSUME_NONNULL_BEGIN

@class JcfUpLoadView;

/**
 * @brief What a @c JcfUpLoadView tells its owner.
 *
 * The single message is dispatched with @c -performSelector: after a @c -respondsToSelector:
 * guard, so it is optional.
 */
@protocol JcfUpLoadViewDelegate <NSObject>
@optional
/**
 * @brief Sent from the Cancel/End button once the upload has finished or been dismissed.
 * @param view The modal (see the reconstruction note: the binary passes the delegate itself here).
 */
- (void)uploadEnd:(nullable JcfUpLoadView *)view;
@end

/**
 * @brief A gradient-backed board that uploads a @c .jcf chart and shares the outcome.
 */
@interface JcfUpLoadView : UIView <JcfUploaderDelegate>

/**
 * @brief The layer class backing the board: a @c CAGradientLayer .
 * @return The @c CAGradientLayer class.
 * @ghidraAddress 0x1f319c
 */
+ (Class)layerClass;

/**
 * @brief Builds the board, its label, the confirmation buttons, and the spinner, then arms the
 * owned @c JcfUploader .
 *
 * The board is @c 320 wide on a pad and @c 300 otherwise, @c 360 tall either way. The board opens
 * on a confirmation: the upload OK (@c btnUpOK ) and upload Cancel (@c btnUpCancel ) buttons flank
 * the centre and are visible, while the post-result @c btnCancel starts fully transparent. The
 * @c JcfUploader is created but not started; the upload only begins once the licence step
 * completes.
 * @param data The chart data to upload, handed to the @c JcfUploader .
 * @param delegateArg The object told the outcome; held weakly.
 * @param ctrl The controller used to present the share sheet; held strongly.
 * @return The initialised view.
 * @ghidraAddress 0x1f31b0
 */
- (instancetype)initWithData:(nullable NSData *)data
                    delegate:(nullable id<JcfUpLoadViewDelegate>)delegateArg
                        ctrl:(nullable UIViewController *)ctrl;

/**
 * @brief Cancel/End button action: ends the modal through @c -uploadEnd .
 * @param sender The button.
 * @ghidraAddress 0x1f4304
 */
- (void)pushCancel:(nullable id)sender;

/**
 * @brief Upload-OK button action: shows the spinner, swaps the confirmation buttons for the single
 * Cancel button, and begins the licence-agreement step.
 * @param sender The button.
 * @ghidraAddress 0x1f4310
 */
- (void)pushUploadOK:(nullable id)sender;

/**
 * @brief Presents the licence-agreement overlay, whose callbacks gate the upload.
 * @ghidraAddress 0x1f4468
 */
- (void)licenseStart;

/**
 * @brief Updates the label to the in-progress text and starts the owned @c JcfUploader .
 * @ghidraAddress 0x1f44d8
 */
- (void)uploadStart;

/**
 * @brief Unused entry point (an empty body in the binary).
 * @ghidraAddress 0x1f4528
 */
- (void)startUpload;

/**
 * @brief Tells the delegate @c -uploadEnd: that the modal has finished.
 * @ghidraAddress 0x1f452c
 */
- (void)uploadEnd;

/**
 * @brief @c JcfUploaderDelegate : the upload failed; shows the message and an OK button.
 * @param uploader The failed uploader.
 * @param msg The user-facing message, or @c nil to use the default failure text.
 * @ghidraAddress 0x1f45d0
 */
- (void)uploadError:(nullable JcfUploader *)uploader msgStr:(nullable NSString *)msg;

/**
 * @brief @c JcfUploaderDelegate : the upload was rejected for NG words; shows the rejection message
 * with the three offending words and an OK button.
 * @param uploader The uploader.
 * @param ngWords The three NG words (title, editor, and comment).
 * @ghidraAddress 0x1f46d8
 */
- (void)uploadNG:(nullable JcfUploader *)uploader ngWords:(nullable NSArray *)ngWords;

/**
 * @brief @c JcfUploaderDelegate : the upload succeeded; stores the sequence id and share text,
 * shows the success message, and reveals the Twitter (and, when available, Facebook) share buttons.
 * @param uploader The uploader.
 * @param uploadInfo The server's returned info, keyed by @c SeqID and @c SNSMes .
 * @ghidraAddress 0x1f48ac
 */
- (void)uploadSuccess:(nullable JcfUploader *)uploader
           uploadInfo:(nullable NSDictionary *)uploadInfo;

/**
 * @brief @c LicenseAgreementView callback: the agreement step failed; shows the message, an OK
 * button, and removes the overlay.
 * @param sender The licence view.
 * @param msg The user-facing message, or @c nil to use the default failure text.
 * @ghidraAddress 0x1f4d2c
 */
- (void)agreementError:(nullable id)sender msgStr:(nullable NSString *)msg;

/**
 * @brief @c LicenseAgreementView callback: the agreement was accepted; starts the upload and
 * removes the overlay.
 * @param sender The licence view.
 * @ghidraAddress 0x1f4e60
 */
- (void)agreementSuccess:(nullable id)sender;

/**
 * @brief @c LicenseAgreementView callback: the agreement was declined; ends the modal.
 * @param sender The licence view.
 * @ghidraAddress 0x1f4ea8
 */
- (void)agreementFailed:(nullable id)sender;

/**
 * @brief Presents the share composer for the given social service.
 * @param serviceType The @c SLServiceType to compose for.
 * @ghidraAddress 0x1f4eb4
 */
- (void)socialSend:(nullable NSString *)serviceType;

/**
 * @brief Twitter share button action: posts through @c -socialSend: with the Twitter service.
 * @param sender The button.
 * @ghidraAddress 0x1f5040
 */
- (void)uploadSendTwitter:(nullable id)sender;

/**
 * @brief Facebook share button action: posts through @c -socialSend: with the Facebook service,
 * when the Social framework is available.
 * @param sender The button.
 * @ghidraAddress 0x1f5058
 */
- (void)uploadSendFacebook:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
