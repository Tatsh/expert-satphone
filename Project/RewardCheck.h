/**
 * @file
 * The applilink reward-check network client.
 *
 * Reconstructed from Ghidra program Jubeat (class RewardCheck, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x34f198.
 */

#import <Foundation/Foundation.h>

#import "Downloader.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Told when a reward check completes.
 */
@protocol RewardCheckDelegate <NSObject>
@optional
/**
 * Sent when the reward check finishes (successfully or not).
 * @param rewardCheck The reward check that finished.
 */
- (void)rewardCheckEnd:(nonnull id)rewardCheck;
@end

/**
 * Posts the installed-app reward check to the game server and applies the granted rewards.
 */
@interface RewardCheck : NSObject <DownloaderDelegate>

/**
 * Builds the check request for the reward list and starts nothing until @c -checkStart .
 * @param delegate The delegate told when the check ends; held unsafely.
 * @return The initialised checker.
 * @ghidraAddress 0x1256d0
 */
- (instancetype)initWithDelegate:(nullable id<RewardCheckDelegate>)delegate;

/**
 * Starts the check download.
 * @ghidraAddress 0x125d54
 */
- (void)checkStart;

/**
 * Cancels the check download.
 * @ghidraAddress 0x125d6c
 */
- (void)checkCancel;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
