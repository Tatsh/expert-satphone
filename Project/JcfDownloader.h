/** @file
 * The jubeatLab custom-sequence (jcf) downloader.
 *
 * Reconstructed from Ghidra program Jubeat (class JcfDownloader, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * Downloads one shared edit chart by its custom id: it first ensures an editor id exists (minting
 * one through @c EditorIDManager when not), then runs the jubeatLab sequence-download API, decodes
 * the base64 chart, saves it through @c EditDataManager , and — for a chart not already built in —
 * follows up with the comprised-pack API to learn which pack the tune belongs to. Every outcome is
 * relayed to the delegate through the sequence-download selectors, sent only when the delegate
 * responds.
 */

#import <Foundation/Foundation.h>

#import "EditorIDManager.h"

@class JcfDownloader;
@class jubeatLabAccess;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c JcfDownloader tells its owner. The delegate is a bare @c id the binary messages
 * dynamically behind @c -respondsToSelector: ; this protocol only documents the selectors.
 */
@protocol JcfDownloaderDelegate <NSObject>
@optional
/** @brief The download failed, with an optional user-facing message. */
- (void)errorSequenceDownload:(nullable JcfDownloader *)downloader msgStr:(nullable NSString *)msg;
/** @brief The chart downloaded and saved for the given tune id. */
- (void)finishedSequenceDownload:(nullable JcfDownloader *)downloader
                          tuneID:(nullable NSString *)tuneID;
/** @brief The chart could not be saved because the edit-slot cap was reached. */
- (void)finishedSequenceOverCap:(nullable JcfDownloader *)downloader;
/** @brief The follow-up pack lookup finished and the tune is already available. */
- (void)finishedSequenceDownload:(nullable JcfDownloader *)downloader;
/** @brief The tune is not part of any purchasable pack. */
- (void)finishedSequenceNotExistPack:(nullable JcfDownloader *)downloader
                              packID:(nullable NSString *)packID;
@end

/**
 * @brief Downloads a shared edit chart by its custom id.
 */
@interface JcfDownloader : NSObject <EditorIDManagerDelegate>

/**
 * @brief The store-new-info endpoint used for the comprised-pack lookup.
 * @param customID Unused; present to match the binary's selector.
 * @ghidraAddress 0x1d4624
 */
- (nullable NSURL *)createCustomSequenceURL:(nullable id)customID;

/**
 * @brief Begins downloading the chart for a custom id, minting an editor id first if needed.
 * @param customID The shared chart's custom id.
 * @param delegate The object told the outcome.
 * @return The initialised downloader.
 * @ghidraAddress 0x1d4638
 */
- (instancetype)initWithCustomID:(nullable NSString *)customID delegate:(nullable id)delegate;

/**
 * @brief Starts the jubeatLab sequence-download API for the custom id.
 * @ghidraAddress 0x1d474c
 */
- (void)downloadStart;

/**
 * @brief jubeatLab access progress callback (a no-op).
 * @ghidraAddress 0x1d47bc
 */
- (void)jubeatLabAccessProceed:(nullable jubeatLabAccess *)access;

/**
 * @brief jubeatLab access failure callback: reports the error for the matching request.
 * @ghidraAddress 0x1d47c0
 */
- (void)jubeatLabAccessError:(nullable jubeatLabAccess *)access;

/**
 * @brief Relays a plain download failure to the delegate and drops the sequence downloader.
 * @ghidraAddress 0x1d4948
 */
- (void)downloadFailedDelegate;

/**
 * @brief Whether a built-in @c .jbt chart already exists for a tune id.
 * @param tuneID The tune id.
 * @return YES when the tune is a built-in chart or its @c .jbt file is present.
 * @ghidraAddress 0x1d49f0
 */
- (BOOL)isExistJbtFile:(unsigned int)tuneID;

/**
 * @brief jubeatLab access success callback: decodes and saves the chart, then looks up its pack.
 * @ghidraAddress 0x1d4ca4
 */
- (void)jubeatLabAccessFinished:(nullable jubeatLabAccess *)access;

/**
 * @brief @c EditorIDManager success callback: begins the download once an editor id exists.
 * @ghidraAddress 0x1d5608
 */
- (void)successIDDownload:(nullable id)sender;

/**
 * @brief @c EditorIDManager failure callback: reports the download error.
 * @ghidraAddress 0x1d568c
 */
- (void)errorIDDownload:(nullable id)sender msgStr:(nullable NSString *)msg;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
