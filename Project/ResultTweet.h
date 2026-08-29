/**
 * @file
 * @brief Score-tweet composition.
 *
 * Reconstructed from Ghidra program Jubeat (class ResultTweet, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * ResultTweet composes the shareable result-tweet image. An instance is built from a play
 * @c Sequence and its @c RendererConf, given the two title images, and asked for the finished
 * plate with @c -generateTweetImage , which draws the base plate, music information, score result,
 * and player accessory into a Core Graphics image context in that order. The class methods vend
 * the frame and accessory sample images used by the customisation UI and resolve the on-disk
 * paths of the tweet decoration images. The class object is at 0x348268.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class RendererConf;
@class Sequence;

/**
 * @brief Builds the image a score tweet carries.
 */
@interface ResultTweet : NSObject

/**
 * @brief Initialises the composer with the play sequence and its renderer configuration.
 *
 * @param info The finished play @c Sequence , the source of the score and music-bar result.
 * @param conf The @c RendererConf describing the played chart's difficulty and level.
 * @return The initialised composer.
 * @ghidraAddress 0xbbf94
 */
- (instancetype)initWithInfo:(Sequence *)info conf:(RendererConf *)conf;

/**
 * @brief Sets the two title images, one drawn over a dark plate and one over a light plate.
 *
 * @param title The title image drawn when the dark base plate is used.
 * @param white The title image drawn when the light base plate is used.
 * @ghidraAddress 0xbc14c
 */
- (void)setTitle:(nullable UIImage *)title white:(nullable UIImage *)white;

/**
 * @brief Composes and returns the finished tweet image.
 *
 * @return The composed image, or nil when no image context could be produced.
 * @ghidraAddress 0xbc1c8
 */
- (nullable UIImage *)generateTweetImage;

/**
 * @brief Vends the sample image for a named tweet frame.
 *
 * @param frameName The frame's resource name, passed to
 * @c +[TweetResourceManager getResourceData:].
 * @return The decrypted frame sample image, or nil when it cannot be produced.
 * @ghidraAddress 0xbcbc8
 */
+ (nullable UIImage *)getSampleImage:(nullable NSString *)frameName;

/**
 * @brief Vends the accessory sample image.
 *
 * The argument is ignored; the accessory is taken from the current marker default.
 *
 * @param accessoryName Ignored.
 * @return The decrypted accessory sample image, or nil when it cannot be produced.
 * @ghidraAddress 0xbcce0
 */
+ (nullable UIImage *)getAccessoryImage:(nullable NSString *)accessoryName;

/**
 * @brief The on-disk path of one of the tweet decoration images.
 *
 * Resolves against the append-data directory, falling back to the @c shareData subtree when the
 * frame-specific file is absent. Callers load the result with
 * @c +[UIImage imageWithContentsOfFile:].
 *
 * @param fileName The image's file name.
 * @return The existing file's path, or nil when neither location has it.
 * @ghidraAddress 0xbd19c
 */
+ (nullable NSString *)getTwitterImagePath:(NSString *)fileName;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
