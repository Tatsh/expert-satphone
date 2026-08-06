/** @file
 * The archive reader for the game's packed asset files.
 *
 * Reconstructed from Ghidra program Jubeat (class KUnzip, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the two members
 * @c -[ArtworkLoader loadArtwork] sends are declared.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Reads named entries out of one packed archive.
 */
@interface KUnzip : NSObject

/**
 * @brief Opens an archive, skipping a fixed-size header.
 *
 * DECLARED ONLY. The one reconstructed caller passes a tail of 16.
 *
 * @param path The archive's path.
 * @param tail How many bytes to skip.
 * @return The opened archive, or nil.
 */
- (nullable instancetype)initWithPath:(nullable NSString *)path tail:(int)tail;

/**
 * @brief Reads one entry out of the archive.
 *
 * DECLARED ONLY. The bytes come back still enciphered — @c -[ArtworkLoader loadArtwork] runs them
 * through @c BFCodec before they are an image.
 *
 * @param name The entry's name.
 * @return The entry's bytes, or nil.
 */
- (nullable NSMutableData *)uncompress:(nullable NSString *)name;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
