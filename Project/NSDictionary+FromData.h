/**
 * @file
 * @brief The @c NSDictionary @c FromData category.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base. The runtime metadata records this as category @c FromData on
 * @c NSDictionary. The shipped binary calls @c +[NSDictionary dictionaryFromPropertyListData:] to
 * parse an @c NSData holding a serialised property list into a dictionary.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Property-list deserialisation vending a dictionary.
 */
@interface NSDictionary (FromData)

/**
 * @brief Deserialises a property-list @c NSData into a dictionary.
 * @param data The serialised property-list data.
 * @return The parsed dictionary, or @c nil when the data is not a property list whose root is a
 *         dictionary.
 * @ghidraAddress 0x1831cc
 */
+ (nullable NSDictionary *)dictionaryFromPropertyListData:(nullable NSData *)data;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
