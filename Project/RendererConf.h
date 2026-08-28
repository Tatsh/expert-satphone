/**
 * @file RendererConf.h
 * @brief Play-mode render configuration passed to the in-game note renderers.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * A plain value object the game hands to @c MainGameRenderer (and its phone/pad and per-theme
 * subclasses): the tune, marker, and difficulty the board is drawn for, the chart level, the
 * stealth-mode flag, the partner name shown in versus play, and the deciphered marker archive. It
 * declares no initialiser of its own, so it is a direct @c NSObject subclass built with
 * @c +alloc / @c -init.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The marker, sound, and display settings the gameplay renderer draws a play session with.
 */
@interface RendererConf : NSObject

/**
 * @brief The marker resource identifier for the chart being played.
 * @ghidraAddress 0xf58c
 */
@property(nonatomic, assign, nullable) NSString *markerID;

/**
 * @brief Whether stealth mode (hidden notes) is active. Encodes as @c B .
 * @ghidraAddress 0xf5ac
 */
@property(nonatomic, assign) BOOL isStealth;

/**
 * @brief The difficulty index the board is drawn for. Encodes as @c I .
 * @ghidraAddress 0xf5cc
 */
@property(nonatomic, assign) unsigned int diff;

/**
 * @brief The chart level. Encodes as @c I .
 * @ghidraAddress 0xf5ec
 */
@property(nonatomic, assign) unsigned int level;

/**
 * @brief The tune identifier. Encodes as @c I .
 * @ghidraAddress 0xf60c
 */
@property(nonatomic, assign) unsigned int tuneID;

/**
 * @brief The partner name shown in versus play.
 * @ghidraAddress 0xf62c
 */
@property(nonatomic, strong, nullable) NSString *partnerName;

/**
 * @brief The deciphered marker archive.
 * @ghidraAddress 0xf650
 */
@property(nonatomic, strong, nullable) NSData *markerData;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
