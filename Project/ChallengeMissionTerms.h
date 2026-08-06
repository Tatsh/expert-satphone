/** @file
 * The terms of one challenge mission.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeMissionTerms, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares two methods beyond the property
 * accessors and both are implemented.
 *
 * The superclass binds to @c _OBJC_CLASS_$_NSObject at load time; it is not stored in the file.
 *
 * The same shape as @c ChallengeMissionReward: one method reads the server's JSON in, the other
 * writes it back out, and between them they document the wire format exactly.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A challenge mission's identity, description, and completion condition.
 */
@interface ChallengeMissionTerms : NSObject

/** @brief The mission's identifier. Wire key @c "id". */
@property(nonatomic, readonly) int missionID;
/** @brief The mission's display name. Wire key @c "name". */
@property(nonatomic, readonly, nullable) NSString *missionTitle;
/** @brief The mission's description. Wire key @c "description". */
@property(nonatomic, readonly, nullable) NSString *missionExplain;
/**
 * @brief What kind of condition completes the mission. Wire key @c "condition".
 *
 * Unsigned per the metadata (@c TI), though @c -getDictionary boxes it with @c +numberWithInt:.
 */
@property(nonatomic, readonly) unsigned int missionType;
/** @brief The condition's parameters. Wire key @c "data". */
@property(nonatomic, readonly, nullable) NSArray *missionDetail;
/** @brief What skipping the mission costs. Wire key @c "fee_skip". */
@property(nonatomic, readonly) int skipCost;

/**
 * @brief Fills the object in from a server dictionary.
 *
 * Named like an initialiser but it is not one: it returns @c BOOL rather than @c instancetype and
 * never calls @c -init. Unlike @c -[ChallengeMissionReward initWithDictionary:] it has no failure
 * path at all — it reads six keys unconditionally and always answers YES.
 *
 * @param dictionary The server's mission record, read at the top level with no wrapper entry.
 * @return Always YES.
 * @ghidraAddress 0x1ee928
 */
- (BOOL)initWithDictionary:(NSDictionary *)dictionary;
/**
 * @brief Writes the object back out in the server's format.
 *
 * A true inverse of @c -initWithDictionary: here, unlike the reward class, since both sides work at
 * the top level.
 * @ghidraAddress 0x1eead4
 */
- (NSDictionary *)getDictionary;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
