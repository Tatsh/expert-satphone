/** @file
 * One genre's heading record in the store's pack list.
 *
 * Reconstructed from Ghidra program Jubeat (class StorePackListGenre, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the four members
 * @c -[StoreGenreTitleView setGenreTitleInfo:] reads are declared.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What the store knows about one genre.
 */
@interface StorePackListGenre : NSObject

/**
 * @brief The genre's name. DECLARED ONLY.
 */
@property(nonatomic, readonly, nullable) NSString *genreName;

/**
 * @brief The heading's backdrop colour, or nil to fall back to a translucent white. DECLARED ONLY.
 */
@property(nonatomic, readonly, nullable) UIColor *genreBGColor;

/**
 * @brief The heading banner's address. DECLARED ONLY.
 */
@property(nonatomic, readonly, nullable) NSString *genreBgImageURL;

/**
 * @brief The genre's description. DECLARED ONLY.
 */
@property(nonatomic, readonly, nullable) NSString *genreComment;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
