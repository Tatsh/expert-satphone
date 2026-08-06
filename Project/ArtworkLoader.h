/** @file
 * Loads one tune's jacket artwork out of a packed, enciphered archive.
 *
 * Reconstructed from Ghidra program Jubeat (class ArtworkLoader, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject, from the dyld bind at the class object's superclass slot
 * (0x34d6c0).
 *
 * Artwork is not stored as a plain file. It is an entry inside a @c KUnzip archive whose bytes are
 * Blowfish-enciphered, so getting an image out takes an unzip, a decipher, and then a decode.
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ArtworkLoader;

/**
 * @brief What an @c ArtworkLoader tells its owner.
 *
 * The protocol's name is the binary's own, taken from the delegate ivar's encoding
 * @c \@"<ArtworkLoaderDelegate>" .
 */
@protocol ArtworkLoaderDelegate <NSObject>
@optional
/**
 * @brief Sent once the artwork is decoded and in @c image .
 * @param loader The loader that finished.
 */
- (void)imageDataLoaded:(ArtworkLoader *)loader;
@end

/**
 * @brief A one-shot loader for a single tune's artwork.
 */
@interface ArtworkLoader : NSObject

/**
 * @brief The decoded artwork, once @c -loadArtwork has run.
 * @ghidraAddress 0x93aa0 (getter)
 */
@property(nonatomic, strong, nullable) UIImage *image;

/**
 * @brief The object told when the artwork is ready.
 */
@property(nonatomic, weak, nullable) id<ArtworkLoaderDelegate> delegate;

/**
 * @brief Which tune this artwork belongs to. Carried for the delegate to read back.
 * @ghidraAddress 0x93ac4 (getter)
 */
@property(nonatomic, readonly) unsigned int tuneID;

/**
 * @brief Which row asked for it. Carried for the delegate to read back.
 * @ghidraAddress 0x93ad4 (getter)
 */
@property(nonatomic, readonly) int indexRow;

/**
 * @brief Builds a loader that remembers which row asked.
 *
 * @param path The archive's path.
 * @param tuneID The tune.
 * @param indexRow The requesting row.
 * @param size The largest size the caller wants. Anything wider is shrunk.
 * @param bigArtwork Whether to read the large entry rather than the small one.
 * @return The initialised loader.
 * @ghidraAddress 0x934f8
 */
- (instancetype)initWithPath:(nullable NSString *)path
                      tuneID:(unsigned int)tuneID
                    indexRow:(int)indexRow
                        size:(CGSize)size
                  bigArtwork:(BOOL)bigArtwork;

/**
 * @brief Builds a loader with no row.
 *
 * Identical to the longer initialiser but for the row, which it does not set at all — so
 * @c indexRow reads as zero rather than as anything meaningful.
 *
 * @param path The archive's path.
 * @param tuneID The tune.
 * @param size The largest size the caller wants.
 * @param bigArtwork Whether to read the large entry rather than the small one.
 * @return The initialised loader.
 * @ghidraAddress 0x935d8
 */
- (instancetype)initWithPath:(nullable NSString *)path
                      tuneID:(unsigned int)tuneID
                        size:(CGSize)size
                  bigArtwork:(BOOL)bigArtwork;

/**
 * @brief Redraws an image at this loader's size.
 *
 * The new context copies the source's bit depth, row stride, colour space and bitmap info, so only
 * the dimensions change.
 *
 * @param image The image to shrink.
 * @return The redrawn image.
 * @ghidraAddress 0x936a8
 */
- (nullable UIImage *)shrinkImage:(nullable UIImage *)image;

/**
 * @brief Unzips, deciphers and decodes the artwork, then tells the delegate.
 *
 * Synchronous, and wrapped in its own autorelease pool — the whole body sits between
 * @c objc_autoreleasePoolPush and @c …Pop , which is what a caller running it off the main thread
 * would need.
 *
 * @ghidraAddress 0x937d8
 */
- (void)loadArtwork;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
