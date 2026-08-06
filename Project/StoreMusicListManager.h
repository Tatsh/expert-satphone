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
