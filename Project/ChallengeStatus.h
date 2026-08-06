/** @file
 * The challenge subsystem's shared state object.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeStatus, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the members reached so far are
 * declared — the class object is referenced from 0x348150 and has 116 cross-references, so the bulk
 * of it is still unrecovered.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Shared state for the challenge mode.
 */
@interface ChallengeStatus : NSObject

/**
 * @brief The shared instance.
 *
 * The selector is @c sharedStatus rather than the @c sharedManager this binary uses elsewhere.
 */
@property(class, nonatomic, readonly) ChallengeStatus *sharedStatus;

/**
 * @brief Schedules the local notification that tells the player their coins have refilled.
 *
 * Called from @c -[JubeatAppDelegate applicationDidEnterBackground:] at 0xb714, which is its only
 * call site in the binary.
 */
- (void)createCoinNotification;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
