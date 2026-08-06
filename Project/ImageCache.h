/** @file
 * The texture and image cache.
 *
 * Reconstructed from Ghidra program Jubeat (class ImageCache, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. The class object at 0x348468 has
 * 132 cross-references. Only the one member reached so far is declared.
 *
 * Note the accessor is @c sharedCache, not the @c sharedManager the rest of this tree's singletons
 * use. That is the binary's own selector.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Holds decoded images so a screen change does not re-read them from disk.
 */
@interface ImageCache : NSObject

/**
 * @brief The shared instance.
 */
@property(class, nonatomic, readonly) ImageCache *sharedCache;

/**
 * @brief Drops everything held.
 *
 * Sent on every screen transition except a game restart or replay, which is what keeps those two
 * fast. DECLARED ONLY.
 */
- (void)clear;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
