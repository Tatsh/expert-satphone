/** @file
 * The scratch-panel resource store.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeResourceManager, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. The class object
 * is at 0x34f418.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Stores the list of scratch-panel resource descriptors and each panel's enciphered image
 * data on disk, keyed by item id.
 */
@interface ChallengeResourceManager : NSObject

/**
 * @brief The shared instance, built once.
 * @return The shared manager.
 * @ghidraAddress 0x142b58
 */
+ (instancetype)sharedManager;

/**
 * @brief The resource descriptors, each a dictionary keyed by @c item_id .
 * @ghidraAddress 0x143b00 (getter), 0x143b10 (setter)
 */
@property(nonatomic, strong, nullable) NSMutableArray *arrayResource;

/**
 * @brief Loads and deciphers the resource list from disk (or starts an empty one).
 * @ghidraAddress 0x142c10
 */
- (void)loadResourceList;

/**
 * @brief Enciphers and saves the resource list to disk with a random-nonce header.
 * @ghidraAddress 0x142f30
 */
- (void)saveResourceList;

/**
 * @brief Adds or replaces a panel resource descriptor, keyed by its item id.
 * @param info The descriptor to add.
 * @return @c NO when an identical descriptor is already stored, otherwise @c YES .
 * @ghidraAddress 0x14310c
 */
- (BOOL)addPanelResourceInfo:(nullable NSDictionary *)info;

/**
 * @brief Loads and deciphers a panel's image data, validating its item-id header.
 * @param info The descriptor whose @c item_id names the panel.
 * @return The image data, or nil when missing or mismatched (a mismatch also deletes the file).
 * @ghidraAddress 0x143608
 */
- (nullable NSData *)getPanelResourceData:(nullable NSDictionary *)info;

/**
 * @brief Enciphers and saves a panel's image data with an item-id header.
 * @param data The image data.
 * @param info The descriptor whose @c item_id names the panel.
 * @ghidraAddress 0x1437d0
 */
- (void)savePanelResourceData:(nullable NSData *)data info:(nullable NSDictionary *)info;

/**
 * @brief Deletes a panel's stored image data.
 * @param itemID The panel's item id.
 * @ghidraAddress 0x1439ec
 */
- (void)deletePanelResourceData:(int)itemID;

/**
 * @brief Marks a file URL as excluded from iCloud backup.
 * @param url The file URL.
 * @ghidraAddress 0x143a64
 */
- (void)setIgnoreSave:(nullable NSURL *)url;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
