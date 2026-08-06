/** @file
 * The challenge subsystem's shared state object.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeStatus, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: grown outwards from its callers. The class object at 0x348150 has 116
 * cross-references, so most of it is still unrecovered. Only the members reached so far are
 * declared, and several are declared without a body — see TYPES_PENDING.md.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Shared state for the challenge mode, including the play-coin economy.
 */
@interface ChallengeStatus : NSObject

/**
 * @brief The shared instance.
 *
 * The selector is @c sharedStatus rather than the @c sharedManager this binary uses elsewhere.
 * DECLARED ONLY — the body has not been located yet.
 */
@property(class, nonatomic, readonly) ChallengeStatus *sharedStatus;

/**
 * @brief Whether the challenge state has been loaded.
 *
 * Backed by @c _bInitialized (offset global 0x34baac). @c -createCoinNotification returns
 * immediately when it is clear.
 */
@property(nonatomic, readonly) BOOL bInitialized;
/**
 * @brief The number of play coins the player currently holds. Backed by @c _coinNum (0x34bb04).
 */
@property(nonatomic, readonly) int coinNum;
/**
 * @brief The maximum number of play coins. Backed by @c _coinLim (0x34bb00).
 */
@property(nonatomic, readonly) int coinLim;
/**
 * @brief Seconds one coin takes to regenerate. Backed by @c coinRestTime (0x34bafc), a @c double.
 */
@property(nonatomic, readonly) double coinRestTime;
/**
 * @brief The moment the current coin's regeneration started.
 *
 * Read-write and @c strong, per the property metadata (@c T@"NSDate",&,N,V_coinRestDate). It was
 * declared @c readonly here on the strength of the one call site that reads it, which
 * @c rctool @c objc @c properties then contradicted — the class ships a setter.
 */
@property(nonatomic, strong, nullable) NSDate *coinRestDate;

/**
 * @brief Recomputes the coin count from elapsed time. DECLARED ONLY.
 */
- (int)restCoinNum;
/**
 * @brief Seconds remaining until the given date. DECLARED ONLY.
 */
- (double)getTimeLeft:(nullable NSDate *)date;
/**
 * @brief The date the free-scratch allowance next resets. DECLARED ONLY.
 *
 * Readwrite in the metadata, not readonly — the class ships a setter for it.
 * @ghidraAddress 0x1ce084
 */
@property(nonatomic, strong, nullable) NSDate *scratchResetDate;
/**
 * @brief Renders a second count as display text. DECLARED ONLY.
 * @ghidraAddress 0x1cd35c
 */
- (nullable NSString *)timeStringFromInterval:(double)interval;
/**
 * @brief The phone's layout scale relative to the pad's. Single precision, per the @c f encoding.
 *
 * Views that lay out in pad coordinates multiply by this on the phone and by nothing on the pad.
 * DECLARED ONLY.
 * @ghidraAddress 0x1ce234
 */
@property(nonatomic, readonly) float phoneScreenRate;

/**
 * @brief Schedules the local notification announcing that play coins have refilled.
 *
 * Called from @c -[JubeatAppDelegate applicationDidEnterBackground:], its only call site. Returns
 * without scheduling when the state is not initialised or when the coin count is not below the
 * limit.
 * @ghidraAddress 0x1cd874
 */
- (void)createCoinNotification;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
