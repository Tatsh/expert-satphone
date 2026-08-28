/**
 * @file HostClass.h
 * @brief The per-partner host-session state carried by the share-play manager.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * A plain value object @c SharePlayManager keeps for the connected host: the downloaded music
 * data, whether it has finished loading, the partner's score and final bonus, and the full-combo
 * and finished flags. It declares no initialiser of its own, so it is a direct @c NSObject
 * subclass built with @c +alloc / @c -init.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief One discovered share-play host and the music data it offers.
 */
@interface HostClass : NSObject

/** @brief The host's downloaded music data. */
@property(nonatomic, strong, nullable) NSData *musicData;

/** @brief Whether the music data has finished loading. Encodes as @c B . */
@property(nonatomic, assign) BOOL dataLoaded;

/** @brief The host's score. Encodes as @c i . */
@property(nonatomic, assign) int score;

/** @brief The host's final bonus. Encodes as @c i . */
@property(nonatomic, assign) int finalBonus;

/** @brief Whether the host achieved a full combo. Encodes as @c B . */
@property(nonatomic, assign) BOOL fullcombo;

/** @brief Whether the host has finished the tune. Encodes as @c B . */
@property(nonatomic, assign) BOOL finished;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
