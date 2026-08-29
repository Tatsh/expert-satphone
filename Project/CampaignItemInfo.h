/**
 * @file
 * One campaign item and the rule that unlocks it.
 *
 * Reconstructed from Ghidra program Jubeat (class CampaignItemInfo, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject, from the dyld bind at the class object's superclass slot
 * (0x34c770).
 *
 * Every property is read-only, and @c -termCheck is what fills them in: it decides whether the
 * item is unlocked, whether it is already downloaded, and which button and hide states the UI
 * should use.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * The kind of item a campaign entry unlocks, as stored in @c itemType.
 */
typedef NS_ENUM(int, CampaignItemInfoItemType) {
    CampaignItemInfoItemTypeTune = 0, /*!< A tune: must be in the catalogue and present on disc. */
    CampaignItemInfoItemTypeMarker = 1, /*!< A marker: only has to be installed. */
};

/**
 * A campaign item: an unlockable tune or marker with a rule for earning it.
 */
@interface CampaignItemInfo : NSObject

/**
 * The campaign this item belongs to.
 */
@property(nonatomic, readonly) int campaignID;

/**
 * The item's display name.
 */
@property(nonatomic, readonly, strong, nullable) NSString *name;

/**
 * What the item is.
 */
@property(nonatomic, readonly, strong, nullable) NSString *itemDescription;

/**
 * How to unlock it.
 */
@property(nonatomic, readonly, strong, nullable) NSString *unlockDescription;

/**
 * The campaign banner's address.
 */
@property(nonatomic, readonly, strong, nullable) NSString *bannerURL;

/**
 * The item artwork's address.
 */
@property(nonatomic, readonly, strong, nullable) NSString *itemImageURL;

/**
 * Whether the server says this item is unlocked.
 *
 * Only consulted for the server-driven unlock rule. Written through
 * @c -replaceServerUnlock: rather than by the initialiser.
 */
@property(nonatomic, readonly) BOOL bServerUnlock;

/**
 * What kind of item this is. Values above one are never unlockable.
 */
@property(nonatomic, readonly) int itemType;

/**
 * Which tune or marker the item grants.
 */
@property(nonatomic, readonly) int itemID;

/**
 * Whether the item's data is already on the device. Set by @c -termCheck .
 */
@property(nonatomic, readonly) BOOL alreadyDownload;

/**
 * Whether the unlock rule is satisfied. Set by @c -termCheck .
 */
@property(nonatomic, readonly) BOOL bUnlock;

/**
 * Which button the UI should offer. Set by @c -termCheck .
 */
@property(nonatomic, readonly) int buttonType;

/**
 * How the UI should hide the item. Set by @c -termCheck , and only ever to zero.
 */
@property(nonatomic, readonly) int hideType;

/**
 * Where the campaign's banner leads.
 */
@property(nonatomic, readonly, strong, nullable) NSURL *linkURL;

/**
 * The item's licence text. The spelling is the binary's own.
 */
@property(nonatomic, readonly, strong, nullable) NSString *lisenceText;

/**
 * A sample of the item.
 */
@property(nonatomic, readonly, strong, nullable) NSURL *sampleURL;

/**
 * Builds an item from a campaign dictionary.
 *
 * The entry is split in two: the identifiers and the unlock rule come from the dictionary itself,
 * and everything the player reads from a nested @c v2 dictionary inside it. The initialiser ends by
 * running @c -termCheck , so an item is fully evaluated before its caller ever sees it.
 *
 * @param dictionary The campaign entry.
 * @return The initialised item.
 * @ghidraAddress 0xbca0
 */
- (instancetype)initWithDictionary:(nullable NSDictionary *)dictionary;

/**
 * Evaluates the unlock rule and sets every derived property from it.
 *
 * There are five rules, chosen by the private @c unlockType ivar: always unlocked; every named
 * application installed; every named pack bought or pending; and a server-driven flag. A rule that
 * is not satisfied still sets @c buttonType , to a value that depends on which rule it was.
 *
 * @return Whether the item came out unlocked.
 * @ghidraAddress 0xc16c
 */
- (BOOL)termCheck;

/**
 * Whether a pack list contains a pack.
 * @param packList The list, whose elements answer @c -intValue .
 * @param packID The pack to look for.
 * @return YES when it is there.
 * @ghidraAddress 0xc5bc
 */
- (BOOL)checkExistPackList:(nullable NSArray *)packList packID:(int)packID;

/**
 * Sets the server's unlock flag.
 *
 * Writes the ivar behind the read-only @c bServerUnlock property directly.
 *
 * @param serverUnlock What the server said.
 * @ghidraAddress 0xc728
 */
- (void)replaceServerUnlock:(BOOL)serverUnlock;

/**
 * Whether the item is newly available: unlocked but not yet downloaded.
 * @return YES when there is something new to fetch.
 * @ghidraAddress 0xc738
 */
- (BOOL)checkNewUnlock;

/**
 * Whether the device already holds an item's data.
 *
 * Only two item types are recognised. A tune must be both in the catalogue and present on disc; a
 * marker only has to be installed. Any other type answers NO.
 *
 * @param itemType The kind of item.
 * @param itemID Which one.
 * @return YES when the data is present.
 * @ghidraAddress 0xc778
 */
- (BOOL)hasItem:(int)itemType itemID:(int)itemID;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
