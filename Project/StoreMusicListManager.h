/** @file
 * The purchasable-music catalogue.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreMusicListManager, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the member
 * @c -[JubeatAppDelegate application:didFinishLaunchingWithOptions:] sends is declared. The class
 * object is at 0x348108.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Holds the list of music available in the store.
 */
@interface StoreMusicListManager : NSObject

/**
 * @brief The shared instance.
 */
@property(class, nonatomic, readonly) StoreMusicListManager *sharedManager;

/**
 * @brief The store's own purchase link for a tune, which overrides whatever the tune list carries.
 *
 * DECLARED ONLY.
 *
 * @param tuneID The tune.
 * @return The link, or nil when the store has none.
 */
- (nullable NSString *)linkURLForID:(unsigned int)tuneID;

/**
 * @brief The extend-pack record for a tune, if it belongs to one.
 *
 * DECLARED ONLY. The three keys @c -[TuneInfo initWithfilePath:dictionary:] reads out of it are
 * @c extendFlag , @c holdFlag and @c extID , each optional.
 *
 * @param tuneID The tune.
 * @return The record, or nil.
 */
- (nullable NSDictionary *)extendInfoForID:(unsigned int)tuneID;

/**
 * @brief Whether a tune is in the catalogue at all. DECLARED ONLY.
 * @param musicID The tune.
 * @return YES when the catalogue lists it.
 */
- (BOOL)hasMusic:(int)musicID;

/**
 * @brief Loads the store's music list.
 *
 * Sent at 0x9eec, immediately after the four PurchaseManager calls and before the audio session is
 * configured. DECLARED ONLY.
 */
- (void)loadMusicList;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
