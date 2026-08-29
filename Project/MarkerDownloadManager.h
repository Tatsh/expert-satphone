/**
 * @file
 * Downloads a queue of marker packs in sequence, verifying and installing each.
 *
 * Reconstructed from Ghidra program Jubeat (class MarkerDownloadManager, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. The class object is at
 * 0x34d4d8.
 */

#import <Foundation/Foundation.h>

#import "Downloader.h"

NS_ASSUME_NONNULL_BEGIN

@class MarkerDownloadManager;

/**
 * Told about a marker download queue's progress.
 */
@protocol MarkerDownloadManagerDelegate <NSObject>
@optional
/**
 * A task has started.
 * @param manager The download manager reporting the task.
 */
- (void)downloadManagerStartTask:(nonnull MarkerDownloadManager *)manager;
/**
 * The current task made progress.
 * @param manager The download manager reporting progress.
 */
- (void)downloadManagerProceed:(nonnull MarkerDownloadManager *)manager;
/**
 * All tasks completed.
 * @param manager The download manager reporting completion.
 */
- (void)downloadManagerCompleted:(nonnull MarkerDownloadManager *)manager;
/**
 * A task failed. The manager is @c nil when the view fails the download itself, before any
 * manager exists (the illegal-marker path).
 * @param manager The download manager reporting the failure, or nil on the illegal-marker path.
 */
- (void)downloadManagerFailed:(nullable MarkerDownloadManager *)manager;
@end

/**
 * Runs a list of marker download tasks one after another.
 */
@interface MarkerDownloadManager : NSObject <DownloaderDelegate>

/** The index of the task currently downloading. @ghidraAddress 0x87c04 (getter) */
@property(nonatomic) unsigned int currentIndex;
/** The number of tasks. @ghidraAddress 0x87240 (getter) */
@property(nonatomic, readonly) unsigned int numTasks;
/** The current task's download progress, 0…1. @ghidraAddress 0x871c0 (getter) */
@property(nonatomic, readonly) float currentProgress;
/** The progress across all tasks, 0…1. @ghidraAddress 0x871d8 (getter) */
@property(nonatomic, readonly) float overallProgress;

/**
 * Builds the manager for a task list and a delegate.
 * @param tasks The download tasks, each a dictionary with @c ItemURL / @c ID / @c Version .
 * @param delegate The delegate told about progress; held unsafely.
 * @return The initialised manager, or nil when @p tasks is nil.
 * @ghidraAddress 0x870bc
 */
- (instancetype)initWithTasks:(nullable NSArray *)tasks
                     delegate:(nullable id<MarkerDownloadManagerDelegate>)delegate;

/**
 * Starts downloading the first task.
 * @ghidraAddress 0x87268
 */
- (void)start;

/**
 * Cancels the in-flight download.
 * @ghidraAddress 0x8741c
 */
- (void)cancel;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
