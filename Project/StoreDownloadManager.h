/**
 * @file
 * Downloads a queue of store packs in sequence, verifying, unpacking, and registering each.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreDownloadManager, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. The class object is at
 * 0x34e4c8.
 */

#import <Foundation/Foundation.h>

@class KUnzip;
@class StoreDownloadManager;

NS_ASSUME_NONNULL_BEGIN

/**
 * Told about a store download queue's progress.
 */
@protocol StoreDownloadManagerDelegate <NSObject>
@optional
/**
 * A task has started.
 * @param manager The download manager reporting the task.
 */
- (void)downloadManagerStartTask:(nonnull StoreDownloadManager *)manager;
/**
 * The current task made progress.
 * @param manager The download manager reporting progress.
 */
- (void)downloadManagerProceed:(nonnull StoreDownloadManager *)manager;
/**
 * All tasks completed.
 * @param manager The download manager reporting completion.
 */
- (void)downloadManagerCompleted:(nonnull StoreDownloadManager *)manager;
/**
 * A task failed.
 * @param manager The download manager reporting the failure.
 */
- (void)downloadManagerFailed:(nonnull StoreDownloadManager *)manager;
@end

/**
 * Runs a list of store download tasks one after another, verifying each pack's trailing MD5
 * digest, saving it, unpacking it, and registering its tune before advancing.
 */
@interface StoreDownloadManager : NSObject

/** The index of the task currently downloading. @ghidraAddress 0xd8764 (getter) */
@property(nonatomic) unsigned int currentIndex;
/** The number of tasks. @ghidraAddress 0xd7d88 (getter) */
@property(nonatomic, readonly) unsigned int numTasks;
/** The current task's download progress, 0…1. @ghidraAddress 0xd7d08 (getter) */
@property(nonatomic, readonly) float currentProgress;
/** The progress across all tasks, 0…1. @ghidraAddress 0xd7d20 (getter) */
@property(nonatomic, readonly) float overallProgress;

/**
 * Decodes and deserialises the tune-info property list held in an unpacked archive.
 *
 * Tries the @c infov3 , @c infov2 , then @c info entries; @c infov3 is deciphered with the
 * tune-info key and has a four-byte header stripped, while the older entries are deciphered with
 * the BGM key.
 *
 * @param unzip The opened archive.
 * @return The tune-info dictionary, or nil.
 * @ghidraAddress 0xd79bc
 */
- (nullable NSDictionary *)getTuneInfoFromUnzip:(nullable KUnzip *)unzip;

/**
 * Builds the manager for a task list and a delegate.
 * @param tasks The download tasks, each a @c StoreDownloadTask .
 * @param delegate The delegate told about progress; held weakly.
 * @return The initialised manager, or nil when @p tasks is nil.
 * @ghidraAddress 0xd7c04
 */
- (instancetype)initWithTasks:(nullable NSArray *)tasks
                     delegate:(nullable id<StoreDownloadManagerDelegate>)delegate;

/**
 * Starts downloading the first task.
 * @ghidraAddress 0xd7db0
 */
- (void)start;

/**
 * Cancels the in-flight download.
 * @ghidraAddress 0xd7f5c
 */
- (void)cancel;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
