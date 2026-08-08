/** @file
 * Thin wrappers over UIKit, Core Animation, and the file system.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * These are genuine free functions: none takes a receiver argument and none belongs to a class, so
 * the reconstruction rules' search for an owning class is exhausted and they stay free functions.
 * They sit consecutively in the binary and each wraps a system framework, so they are grouped here
 * following the ImageLoading.h and Md5Utilities.h precedent. The file's name is this tree's own; no
 * embedded @c __FILE__ has been located for any of them.
 */

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Returns the main screen's bounds, in points.
 *
 * A one-liner over @c [UIScreen mainScreen].bounds . Reports the full screen bounds, ignoring
 * safe-area insets and interface orientation, so on a rotated device the width and height are not
 * swapped.
 *
 * @return The main screen's bounds, in points.
 * @ghidraAddress 0x7fd50
 */
CGRect GetMainScreenBounds(void);

/**
 * @brief Freezes a layer's animations in place, the standard Core Animation "pause layer" idiom.
 *
 * Captures the layer's current local time with @c -convertTime:fromLayer: BEFORE dropping the speed
 * to zero, because once the speed is zero the layer's local time stops advancing; the captured time
 * is then written back through @c -setTimeOffset: . The exact inverse of @c ResumeLayerAnimation .
 * The layer is not nil-checked; a nil layer makes every send a silent no-op.
 *
 * @param pLayer The layer to freeze.
 * @ghidraAddress 0x7fc24
 */
void PauseLayerAnimation(CALayer *pLayer);

/**
 * @brief Resumes a layer frozen by @c PauseLayerAnimation without the animation jumping.
 *
 * Reads back the stashed @c timeOffset , restores the speed to one, clears both @c timeOffset and
 * @c beginTime , then shifts @c beginTime forward by the wall-clock time spent paused so the
 * animation continues from where it stopped. @c -setBeginTime: is sent twice, first with zero and
 * then with the real offset, because the intervening @c -convertTime:fromLayer: reads @c beginTime
 * and it must be cleared first. Only meaningful on a layer previously passed to
 * @c PauseLayerAnimation ; the layer is not nil-checked.
 *
 * @param pLayer The layer to resume.
 * @ghidraAddress 0x7fc98
 */
void ResumeLayerAnimation(CALayer *pLayer);

/**
 * @brief Marks a file URL so that iCloud and iTunes will not back it up.
 *
 * Sets @c NSURLIsExcludedFromBackupKey to @c YES on the URL. The @c NSError out-parameter is
 * written but never examined, so a failure is silent; if the URL is not a file URL, or the file
 * does not yet exist, the attribute is simply not applied. The URL is not nil-checked. This is the
 * standard fix for the App Store rejection about storing cache data in a backed-up directory.
 *
 * @param pUrl A file URL.
 * @ghidraAddress 0x7fdcc
 */
void ExcludeUrlFromICloudBackup(NSURL *pUrl);

/**
 * @brief Reports whether the shared App Group container directory exists on disk.
 *
 * Resolves the container URL for the group identifier and tests its path with
 * @c -fileExistsAtPath: . If the app group is not provisioned the URL is nil, so the path is nil
 * and the existence test returns @c NO ; the nil chain is never checked explicitly but degrades to
 * the correct answer. Gates the sticker-sharing feature, which is backed by
 * @c SaveStickerToAppGroupContainer .
 *
 * @return @c YES if the container directory exists, @c NO otherwise.
 * @ghidraAddress 0x7fe64
 */
BOOL IsAppGroupContainerAvailable(void);

/**
 * @brief Writes sticker data into the shared App Group container and records it in the index.
 *
 * Writes @p pData into the group container under @p pszFileName, and on success adds a
 * filename-to-info mapping to the shared @c NSUserDefaults suite that the share extension reads.
 * The index is only touched when the write succeeds, so it never references a missing file. A
 * failed write is silent: the caller cannot tell the sticker was not saved. The stored index is
 * copied to an immutable dictionary before being written, because @c NSUserDefaults will not store
 * a mutable container, and @c -synchronize is called explicitly.
 *
 * @param pszFileName The path component inside the container, which is also the index key.
 * @param pInfo The value stored under that key. Must be a property-list type.
 * @param pData The payload written to disk.
 * @ghidraAddress 0x7ff10
 */
void SaveStickerToAppGroupContainer(NSString *pszFileName, id pInfo, NSData *pData);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
