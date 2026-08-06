/** @file
 * The sound engine front end.
 *
 * Reconstructed from Ghidra program Jubeat (class AudioManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. The class object at 0x348038 has
 * 357 cross-references, the most of any class reached so far, so every sound in the game goes
 * through it. Only the two members reached so far are declared.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Owns background music and sound effects.
 */
@interface AudioManager : NSObject

/**
 * @brief The shared instance.
 */
@property(class, nonatomic, readonly) AudioManager *sharedManager;

/**
 * @brief Stops every sound effect currently playing. DECLARED ONLY.
 */
- (void)stopAllSe;
/**
 * @brief Releases the background music.
 *
 * The one reconstructed caller always passes YES. What the flag selects is not established, since
 * only that one call site has been recovered. DECLARED ONLY.
 *
 * @param release The binary's own argument, passed as 1 from the screen-transition dispatcher.
 */
- (void)releaseBgm:(BOOL)release;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
