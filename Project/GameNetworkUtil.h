/** @file
 * Game-network URL and install-count helpers.
 *
 * Reconstructed from Ghidra program Jubeat (class GameNetworkUtil, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * A stateless utility class: the URL builders assemble the Konami "agx" endpoints from a shared
 * host and CGI path, and the install-count pair persists the reward application count in
 * @c NSUserDefaults keyed and ciphered per editor id.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Builds the game-network endpoints and tracks the reward install count.
 */
@interface GameNetworkUtil : NSObject

/**
 * @brief The reward-check endpoint.
 * @ghidraAddress 0x1a4770
 */
+ (nullable NSURL *)rewardCheckURL;

/**
 * @brief The reward-enable (startup) endpoint.
 * @ghidraAddress 0x1a4808
 */
+ (nullable NSURL *)rewardEnableURL;

/**
 * @brief The recommend-enable (startup) endpoint.
 * @ghidraAddress 0x1a48e4
 */
+ (nullable NSURL *)recommendEnableURL;

/**
 * @brief Records a new install count, persisting it only when it grows.
 * @param appNum The new install count.
 * @ghidraAddress 0x1a49c0
 */
+ (void)fillInstallAppNum:(int)appNum;

/**
 * @brief Reads the persisted reward install count for the current editor id.
 * @return The stored count, or 0 when none is stored or the record is for another editor.
 * @ghidraAddress 0x1a4c28
 */
+ (int)readInstallAppNum;

/**
 * @brief The score/play-log endpoint.
 * @ghidraAddress 0x1a4e84
 */
+ (nullable NSURL *)scoreSendURL;

/**
 * @brief The recommend-Twitter endpoint.
 * @ghidraAddress 0x1a4f58
 */
+ (nullable NSURL *)recommendTwitterURL;

/**
 * @brief The recommend-Facebook endpoint.
 * @ghidraAddress 0x1a4ff0
 */
+ (nullable NSURL *)recommendFacebookURL;

/**
 * @brief The recommended-pack search endpoint for a music id.
 * @param musicID The music id to search packs for.
 * @ghidraAddress 0x1a5088
 */
+ (nullable NSURL *)searchPackIDURL:(int)musicID;

/**
 * @brief The store target region code.
 * @return @c "JP" .
 * @ghidraAddress 0x1a5138
 */
+ (nullable NSString *)getStoreTarget;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
