/** @file
 * A one-shot sound effect, played through OpenAL.
 *
 * Reconstructed from Ghidra program Jubeat (class SePlayer, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject, taken from the dyld bind at the class object's superclass slot
 * (0x34f790).
 *
 * Each instance owns its own OpenAL device, context, buffer and source, so one is an entire audio
 * stack rather than a voice within a shared one.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Loads one audio file into an OpenAL buffer and plays it on demand.
 *
 * The class declares no properties; its five ivars are the OpenAL handles and the decoded sample
 * data, which it owns and must free through @c -terminate.
 */
@interface SePlayer : NSObject

/**
 * @brief Opens an OpenAL stack and loads the file at @c path into it.
 *
 * Note that a device that fails to open is not treated as fatal: the buffer and source are simply
 * never generated, and the load continues against handle zero.
 *
 * @param path A filesystem path, converted to a file URL before decoding.
 * @ghidraAddress 0x153b34
 */
- (instancetype)initWithPath:(nullable NSString *)path;

/**
 * @brief Plays the loaded sound from the start. Non-looping.
 * @ghidraAddress 0x153ed0
 */
- (void)sePlay;

/**
 * @brief Stops playback and tears the whole OpenAL stack down.
 *
 * Deletes the buffer and source, destroys the context, closes the device and frees the sample
 * data, then zeroes all five ivars. Must be called explicitly — the class has no @c -dealloc, so
 * an instance that is simply released leaks its device and its sample buffer.
 * @ghidraAddress 0x153ee0
 */
- (void)terminate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
