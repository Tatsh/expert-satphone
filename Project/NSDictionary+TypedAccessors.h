#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief TouchJSON's typed-accessor category over @c NSDictionary, as the binary calls it.
 *
 * The shipped binary reads its parsed JSON dictionaries through these helpers, which coerce a
 * value to a given type (returning @c nil when the key is absent or the value is the wrong kind).
 * See @c TYPES_PENDING.md.
 */
@interface NSDictionary (TypedAccessors)

/**
 * @brief The value for @p key coerced to an @c NSNumber.
 * @param key The dictionary key.
 * @return The number, or @c nil when absent or not a number.
 * @ghidraAddress 0x1ba1ec
 */
- (nullable NSNumber *)numberForKey:(nonnull id)key;

/**
 * @brief The value for @p key coerced to an @c NSString.
 * @param key The dictionary key.
 * @return The string, or @c nil when absent or not a string.
 * @ghidraAddress 0x1ba264
 */
- (nullable NSString *)stringForKey:(nonnull id)key;

/**
 * @brief The value for @p key coerced to an @c NSArray.
 * @param key The dictionary key.
 * @return The array, or @c nil when absent or not an array.
 * @ghidraAddress 0x1ba174
 */
- (nullable NSArray *)arrayForKey:(nonnull id)key;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
