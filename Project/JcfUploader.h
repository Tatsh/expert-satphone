/**
 * @file
 * @brief The jubeatLab custom-sequence (jcf) uploader.
 *
 * Reconstructed from Ghidra program Jubeat (class JcfUploader, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * Uploads one edit chart: it ensures an editor id exists (minting one through @c EditorIDManager
 * when not), then runs the jubeatLab sequence-upload API and maps the response status to the
 * upload delegate's success, NG-word, retry, and error callbacks.
 */

#import <Foundation/Foundation.h>

#import "EditorIDManager.h"
@class jubeatLabAccess;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c JcfUploader tells its owner. The delegate is a bare @c id the binary messages
 * dynamically behind @c -respondsToSelector: ; this protocol only documents the selectors.
 */
@protocol JcfUploaderDelegate <NSObject>
@optional
/**
 * @brief The upload succeeded, with the server's returned info.
 * @param sender The uploader reporting the result.
 * @param info The server's response.
 */
- (void)uploadSuccess:(nullable id)sender uploadInfo:(nullable NSDictionary *)info;
/**
 * @brief The upload was rejected for NG words (title, editor, and comment).
 * @param sender The uploader reporting the rejection.
 * @param ngWords The rejected words, in title, editor, and comment order.
 */
- (void)uploadNG:(nullable id)sender ngWords:(nullable NSArray *)ngWords;
/**
 * @brief The upload failed, with an optional user-facing message.
 * @param sender The uploader reporting the failure.
 * @param msg The message to show, or nil when there is none.
 */
- (void)uploadError:(nullable id)sender msgStr:(nullable NSString *)msg;
@end

/**
 * @brief Uploads an edit chart to jubeatLab.
 */
@interface JcfUploader : NSObject <EditorIDManagerDelegate>

/**
 * @brief Reads a keychain generic-password value for an account key.
 * @param key The account whose stored value to read.
 * @return The decoded string, or @c nil when no matching item exists.
 * @ghidraAddress 0x1d7df8
 */
- (nullable NSString *)getKeyString:(nullable id)key;

/**
 * @brief Prepares an upload of the given chart data.
 * @param data The chart data to upload.
 * @param delegate The object told the outcome.
 * @return The initialised uploader.
 * @ghidraAddress 0x1d8080
 */
- (instancetype)initWithData:(nullable NSData *)data delegate:(nullable id)delegate;

/**
 * @brief Begins the upload, minting an editor id first if needed.
 * @ghidraAddress 0x1d8184
 */
- (void)start;

/**
 * @brief Starts the jubeatLab sequence-upload API for the stored chart data.
 * @ghidraAddress 0x1d8214
 */
- (void)uploadStart;

/**
 * @brief Relays an upload error to the delegate.
 * @param msg The optional user-facing message.
 * @ghidraAddress 0x1d8284
 */
- (void)sendErrorDelegate:(nullable NSString *)msg;

/**
 * @brief jubeatLab access progress callback (a no-op).
 * @param access The access reporting progress. The binary ignores it.
 * @ghidraAddress 0x1d832c
 */
- (void)jubeatLabAccessProceed:(nullable jubeatLabAccess *)access;

/**
 * @brief jubeatLab access failure callback: reports the error for the matching request.
 * @param access The access reporting the failure.
 * @ghidraAddress 0x1d8330
 */
- (void)jubeatLabAccessError:(nullable jubeatLabAccess *)access;

/**
 * @brief jubeatLab access success callback: maps the response status to the delegate callbacks.
 * @param access The access reporting the result.
 * @ghidraAddress 0x1d8390
 */
- (void)jubeatLabAccessFinished:(nullable jubeatLabAccess *)access;

/**
 * @brief @c EditorIDManager success callback: begins the upload once an editor id exists.
 * @param sender The editor-ID manager reporting the result.
 * @ghidraAddress 0x1d86dc
 */
- (void)successIDDownload:(nullable id)sender;

/**
 * @brief @c EditorIDManager failure callback: reports the upload error.
 * @param sender The editor-ID manager reporting the failure.
 * @param msg The message to report, or nil when there is none.
 * @ghidraAddress 0x1d8754
 */
- (void)errorIDDownload:(nullable id)sender msgStr:(nullable NSString *)msg;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
