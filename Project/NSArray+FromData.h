/**
 * @file
 * The @c NSArray @c FromData category.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base. The runtime metadata records this as category @c FromData on
 * @c NSArray. The shipped binary calls @c +[NSArray arrayFromPropertyListData:] to parse an
 * @c NSData holding a serialised property list into an array.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Property-list deserialisation vending an array.
 */
@interface NSArray (FromData)

/**
 * Deserialises a property-list @c NSData into an array.
 * @param data The serialised property-list data.
 * @return The parsed array, or @c nil when the data is not a property list whose root is an array.
 * @ghidraAddress 0x171bf8
 */
+ (nullable NSArray *)arrayFromPropertyListData:(nullable NSData *)data;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
