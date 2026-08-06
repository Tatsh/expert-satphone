/** @file
 * The application delegate for jubeat plus: owns the root view controller, exposes the device and
 * client identification the servers are told about, holds the persisted gameplay option flags, and
 * drives the application lifecycle and the local and remote notification handling.
 *
 * Reconstructed from Ghidra program Jubeat (class JubeatAppDelegate, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: this header is being built outwards from the entry point and is not yet
 * complete. The properties below are the accessors in the block at 0xb848-0xb938, every one of them
 * disassembled rather than read from the decompiler. Their names come from the ObjC ivar offset
 * globals at 0x349600-0x349678, which is the runtime metadata and therefore authoritative. The
 * remaining accessors (0xb948 onwards) and the class's ordinary methods are not declared here yet.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The application delegate for jubeat plus.
 */
@interface JubeatAppDelegate : UIResponder <UIApplicationDelegate>

/**
 * @brief The root view controller of the application.
 *
 * Backed by the @c _rootViewCtrl ivar, whose offset global lives at 0x349608. The getter loads a
 * full 64-bit word (@c ldr @c x0), so this is an object reference rather than a scalar.
 * @ghidraAddress 0xb848 (getter)
 */
@property(nonatomic, readonly) UIViewController *rootViewCtrl;
/**
 * @brief The User-Agent string sent with the game's web requests.
 *
 * Backed by @c _userAgent (offset global 0x34966c). Rebuilt by @c -refreshUserAgent at 0xa260.
 * @ghidraAddress 0xb858 (getter)
 */
@property(nonatomic, readonly) NSString *userAgent;
/**
 * @brief Whether Game Center is usable in this session.
 *
 * Backed by @c _gameCenterAvailable (offset global 0x349604). The getter is a @c ldrb, so the ivar
 * is a single byte and the type is @c BOOL rather than a wider integer.
 * @ghidraAddress 0xb868 (getter)
 */
@property(nonatomic, readonly) BOOL gameCenterAvailable;
/**
 * @brief The device model description reported to the servers.
 *
 * Backed by @c _deviceType (offset global 0x349600); the getter loads a 64-bit word, so it is an
 * object.
 * @ghidraAddress 0xb878 (getter)
 */
@property(nonatomic, readonly) NSString *deviceType;
/**
 * @brief The currently-selected interface theme.
 *
 * Backed by @c _currentTheme (offset global 0x34960c). The getter is @c ldr @c w0 — a 4-byte load —
 * so the ivar is a 32-bit integer and is spelled @c int rather than @c NSInteger.
 * @ghidraAddress 0xb888 (getter)
 */
@property(nonatomic, readonly) int currentTheme;
/**
 * @brief The identifier of the jcf content download currently in progress.
 * @ghidraAddress 0xb898 (getter)
 */
@property(nonatomic, readonly) NSString *jcfDownloadID;
/**
 * @brief The URL of the in-game notification page.
 *
 * Set together with @c notificationTime by @c -setNotificationPageURL:updateTime: at 0x8cd4.
 * @ghidraAddress 0xb8a8 (getter)
 */
@property(nonatomic, readonly) NSString *notificationURL;
/**
 * @brief The update timestamp that accompanies @c notificationURL.
 * @ghidraAddress 0xb8b8 (getter)
 */
@property(nonatomic, readonly) NSString *notificationTime;
/**
 * @brief Whether the random-note option is enabled. Written by @c -setRandomFlag: at 0x8d7c.
 * @ghidraAddress 0xb8c8 (getter)
 */
@property(nonatomic, readonly) BOOL isRandom;
/**
 * @brief Whether the installed marker set is licensed for play.
 * @ghidraAddress 0xb8d8 (getter)
 */
@property(nonatomic, readonly) BOOL isMarkerLegal;
/**
 * @brief Whether the extend option is enabled. Written by @c -setExtendFlag: at 0x8d8c.
 * @ghidraAddress 0xb8e8 (getter)
 */
@property(nonatomic, readonly) BOOL isExtend;
/**
 * @brief Whether the hold option is enabled. Written by @c -setHoldFlag: at 0x8d9c.
 * @ghidraAddress 0xb8f8 (getter)
 */
@property(nonatomic, readonly) BOOL isHold;
/**
 * @brief Whether the rectangle-wave sound option is enabled.
 *
 * Unlike the option flags above, this one has a compiled setter of its own rather than a separately
 * named mutator.
 * @ghidraAddress 0xb908 (getter)
 * @ghidraAddress 0xb918 (setter)
 */
@property(nonatomic) BOOL isRectangleWave;
/**
 * @brief Whether marker direction is randomised.
 * @ghidraAddress 0xb928 (getter)
 * @ghidraAddress 0xb938 (setter)
 */
@property(nonatomic) BOOL isMarkerDirRandom;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
