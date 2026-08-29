/**
 * @file
 * @brief TouchJSON's @c NSDictionary @c TypedLookupExtension category.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base. The runtime metadata records this as category
 * @c TypedLookupExtension on @c NSDictionary (method list at 0x322a30). The shipped binary reads
 * its parsed JSON dictionaries through these helpers, which coerce a value to a given class,
 * returning @c nil when the key is absent or the value is not a kind of that class. Every key is a
 * JSON object key, so it is typed @c NSString *.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Class-checked value lookup over @c NSDictionary.
 */
@interface NSDictionary (TypedLookupExtension)

/**
 * @brief The value for @p key when it is a kind of @p aClass, otherwise @c nil.
 * @param key The dictionary key.
 * @param aClass The class the value must be a kind of.
 * @return The value, or @c nil when @p key is absent or its value is not a kind of @p aClass.
 * @ghidraAddress 0x1ba080
 */
- (nullable id)typedObjectForKey:(NSString *)key class:(Class)aClass;

/**
 * @brief The value for @p key coerced to an @c NSDictionary.
 * @param key The dictionary key.
 * @return The dictionary, or @c nil when absent or not a dictionary.
 * @ghidraAddress 0x1ba0fc
 */
- (nullable NSDictionary *)dictionaryForKey:(NSString *)key;

/**
 * @brief The value for @p key coerced to an @c NSArray.
 * @param key The dictionary key.
 * @return The array, or @c nil when absent or not an array.
 * @ghidraAddress 0x1ba174
 */
- (nullable NSArray *)arrayForKey:(NSString *)key;

/**
 * @brief The value for @p key coerced to an @c NSNumber.
 * @param key The dictionary key.
 * @return The number, or @c nil when absent or not a number.
 * @ghidraAddress 0x1ba1ec
 */
- (nullable NSNumber *)numberForKey:(NSString *)key;

/**
 * @brief The value for @p key coerced to an @c NSString.
 * @param key The dictionary key.
 * @return The string, or @c nil when absent or not a string.
 * @ghidraAddress 0x1ba264
 */
- (nullable NSString *)stringForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
