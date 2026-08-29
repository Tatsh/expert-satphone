/**
 * @file
 * One reward offered for completing a challenge mission.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeMissionReward, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares two methods beyond the property
 * accessors and both are implemented.
 *
 * The superclass binds to @c _OBJC_CLASS_$_NSObject at load time; it is not stored in the file.
 *
 * Every property is @c readonly per the metadata, and the two methods are the whole of the class:
 * one reads the server's JSON into the object, the other writes it back out. Together they document
 * the wire format exactly, since @c -getDictionary names each key beside the property it carries.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A challenge-mission reward, as sent by the server.
 */
@interface ChallengeMissionReward : NSObject

/** The reward's identifier. Wire key @c "reward_id". */
@property(nonatomic, readonly) int rewardID;
/** What kind of item the reward is. Wire key @c "item_type". */
@property(nonatomic, readonly) int itemType;
/** The item's identifier. Wire key @c "item_id"; empty string when absent. */
@property(nonatomic, readonly, nullable) NSString *itemID;
/** The reward's display name. Wire key @c "name". */
@property(nonatomic, readonly, nullable) NSString *rewardName;
/** The reward's description. Wire key @c "description". */
@property(nonatomic, readonly, nullable) NSString *rewardDescription;
/** Where to fetch the reward's image. Wire key @c "image_url". */
@property(nonatomic, readonly, nullable) NSString *rewardImageURL;
/** When the reward stops being shown. Wire key @c "view_end". */
@property(nonatomic, readonly, nullable) NSString *endTime;
/** The record's version. Wire key @c "version". */
@property(nonatomic, readonly, nullable) NSString *version;

/**
 * Fills the object in from a server dictionary.
 *
 * Named like an initialiser but it is not one: it returns @c BOOL rather than @c instancetype and
 * never calls @c -init. It answers NO and changes nothing when the dictionary has no @c "reward"
 * entry.
 *
 * @param dictionary The server response, whose @c "reward" entry holds the fields.
 * @return YES when the @c "reward" entry was present.
 * @ghidraAddress 0x1ee324
 */
- (BOOL)initWithDictionary:(NSDictionary *)dictionary;
/**
 * Writes the object back out in the server's format.
 *
 * Note the asymmetry with @c -initWithDictionary:, which reads its fields from a nested @c "reward"
 * entry: this returns the eight fields at the top level, so the two are not inverses.
 * @ghidraAddress 0x1ee5a8
 */
- (NSDictionary *)getDictionary;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
