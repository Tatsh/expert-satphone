/**
 * @file
 * @brief The list of recently seen JCF owners.
 *
 * Reconstructed from Ghidra program Jubeat (class LatelyJcfListManager, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject, from the dyld bind at the class object's superclass slot
 * (0x350e60).
 *
 * Each entry is itself a two-element @c NSMutableArray — the owner's name and the date it was
 * added — rather than a dictionary or a model object.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Keeps at most twenty recently seen owners, each with the time it was recorded.
 */
@interface LatelyJcfListManager : NSObject

/**
 * @brief The shared list.
 * @return The singleton.
 * @ghidraAddress 0x1e2a08
 */
+ (instancetype)sharedManager;

/**
 * @brief Records an owner, evicting an existing entry once the list is full.
 *
 * **Two things here do not do what the name suggests**, both recorded in TYPES_PENDING.md: the
 * entry evicted when the list is full is the one with the *latest* date rather than the earliest,
 * and the duplicate check runs only on the full path and skips the first entry.
 *
 * @param owner The owner's name.
 * @ghidraAddress 0x1e2b14
 */
- (void)addJcfOwner:(nullable NSString *)owner;

/**
 * @brief Removes every entry naming an owner.
 * @param owner The owner's name.
 * @ghidraAddress 0x1e2d7c
 */
- (void)removeJcfOwner:(nullable NSString *)owner;

/**
 * @brief The list itself, not a copy.
 * @return The backing array, whose elements are two-element arrays.
 * @ghidraAddress 0x1e2e94
 */
- (nullable NSMutableArray *)getJcfOwnerList;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
