/**
 * @file
 * @brief The texture and image cache.
 *
 * Reconstructed from Ghidra program Jubeat (class ImageCache, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject, taken from the dyld bind at the class object's superclass slot
 * (0x34e200). The class object at 0x348468 has 132 cross-references.
 *
 * Note the accessor is @c sharedCache, not the @c sharedManager the rest of this tree's singletons
 * use. That is the binary's own selector.
 *
 * @c LoadScaledPngImage does no caching of its own — it hits the filesystem on every one of its
 * 479 call sites. This class is the caching layer callers reach for when they want one.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Holds decoded images so a screen change does not re-read them from disk.
 *
 * Backed by an @c NSCache capped at a hundred and twenty-eight entries, so entries may be evicted
 * under memory pressure as well as by that limit. A caller must never assume a name it fetched
 * once is still held.
 */
@interface ImageCache : NSObject

/**
 * @brief The shared instance.
 *
 * A @c dispatch_once singleton; nothing vends any other instance.
 * @ghidraAddress 0xcecc8
 */
@property(class, nonatomic, readonly) ImageCache *sharedCache;

/**
 * @brief Creates the backing cache and caps it at a hundred and twenty-eight entries.
 * @return The initialised cache.
 * @ghidraAddress 0xced48
 */
- (instancetype)init;

/**
 * @brief Returns the named image, loading and caching it on a miss.
 *
 * A nil name yields nil without touching the cache. A load that fails is **not** cached, so a
 * missing resource is retried on every call rather than remembered as absent.
 *
 * @param name The resource's base name, with no scale suffix and no extension.
 * @return The image, or nil when the name is nil or the resource is missing.
 * @ghidraAddress 0xcede0
 */
- (nullable UIImage *)getResPNG:(nullable NSString *)name;

/**
 * @brief Drops everything held.
 *
 * Sent on every screen transition except a game restart or replay, which is what keeps those two
 * fast.
 * @ghidraAddress 0xcee84
 */
- (void)clear;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
