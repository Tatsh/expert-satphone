/** @file
 * Score-tweet composition.
 *
 * Reconstructed from Ghidra program Jubeat (class ResultTweet, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the one member
 * @c -[accessoryTableCell setInfo:] reaches is declared. The class object is at 0x348268.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Builds the image a score tweet carries.
 */
@interface ResultTweet : NSObject

/**
 * @brief The on-disk path of one of the tweet decoration images.
 *
 * Callers pass a bare file name including its extension, and load the result with
 * @c +[UIImage imageWithContentsOfFile:]. DECLARED ONLY.
 *
 * @param fileName The image's file name.
 */
+ (nullable NSString *)getTwitterImagePath:(NSString *)fileName;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
