#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Apple's private property-list deserialiser category, as the binary calls it.
 *
 * The shipped binary calls the undocumented @c +[NSDictionary dictionaryFromPropertyListData:]
 * class method to parse an @c NSData holding a serialised property list into a dictionary. See
 * @c TYPES_PENDING.md.
 */
@interface NSDictionary (PropertyList)

/**
 * @brief Deserialises a property-list @c NSData into a dictionary.
 * @param data The serialised property-list data.
 * @return The parsed dictionary, or @c nil on failure.
 */
+ (nullable NSDictionary *)dictionaryFromPropertyListData:(nullable NSData *)data;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
