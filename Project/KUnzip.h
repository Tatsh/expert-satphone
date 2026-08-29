/**
 * @file
 * The archive reader for the game's packed asset files.
 *
 * Reconstructed from Ghidra program Jubeat (class KUnzip, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * A thin Objective-C wrapper over minizip's @c unz* API. It can read an archive from a path
 * (@c -initWithPath:), from a path skipping a fixed-size trailer via a file-handle-backed I/O set
 * (@c -initWithPath:tail:), or from an in-memory @c NSData over a byte range via a memory-backed
 * I/O set (@c -initWithData:range:).
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Reads named entries out of one packed archive.
 */
@interface KUnzip : NSObject

/** The file handle a file-handle-backed archive reads through; set by its open callback. */
@property(strong, nonatomic, nullable) NSFileHandle *fileHandle;
/** The bytes a memory-backed archive reads from. */
@property(strong, nonatomic, nullable) NSData *data;
/** The current read position of a memory-backed archive within @c data. */
@property(assign, nonatomic) NSUInteger dataCurrentPos;
/** The byte range of the backing store the archive occupies. */
@property(readonly, nonatomic) NSRange dataRange;

/**
 * Opens an archive at a path.
 *
 * @param path The archive's path.
 * @return The opened archive, or nil when the archive cannot be opened.
 * @ghidraAddress 0x760a0
 */
- (instancetype)initWithPath:(nullable NSString *)path;

/**
 * Opens an archive at a path, skipping a fixed-size trailer.
 *
 * The one reconstructed caller passes a tail of 16. Reads through a file-handle-backed I/O set.
 *
 * @param path The archive's path.
 * @param tail How many trailing bytes to skip; the archive occupies the file up to that point.
 * @return The opened archive, or nil when the file is not larger than @p tail or cannot be opened.
 * @ghidraAddress 0x76150
 */
- (instancetype)initWithPath:(nullable NSString *)path tail:(NSUInteger)tail;

/**
 * Opens an archive held in memory over a byte range.
 *
 * @c -[StoreDownloadManager downloaderFinished:] passes the downloaded pack's data and its full
 * range. Reads through a memory-backed I/O set.
 *
 * @param data The archive bytes.
 * @param range The range of @p data the archive occupies.
 * @return The opened archive, or nil when @p range falls outside @p data or the archive cannot be
 *         opened.
 * @ghidraAddress 0x766cc
 */
- (instancetype)initWithData:(nullable NSData *)data range:(NSRange)range;

/**
 * Reports whether the archive contains an entry with the given name.
 *
 * @param name The entry's name; matched case-insensitively.
 * @return YES when the entry exists, NO otherwise.
 * @ghidraAddress 0x76b3c
 */
- (BOOL)fileExists:(nullable NSString *)name;

/**
 * Returns the uncompressed size of a named entry.
 *
 * @param name The entry's name; matched case-sensitively.
 * @return The entry's uncompressed size in bytes, or 0 when it is absent or its info cannot be
 *         read.
 * @ghidraAddress 0x76bbc
 */
- (NSUInteger)uncompressedSize:(nullable NSString *)name;

/**
 * Lists the names of every entry in the archive.
 *
 * @return An array of the entries' names, or nil when the archive is empty or cannot be walked.
 * @ghidraAddress 0x76c70
 */
- (nullable NSArray<NSString *> *)fileList;

/**
 * Reads one entry out of the archive.
 *
 * The bytes come back still enciphered — @c -[ArtworkLoader loadArtwork] runs them through
 * @c BFCodec before they are an image.
 *
 * @param name The entry's name; matched case-sensitively.
 * @return The entry's uncompressed bytes, or nil when it is absent, empty, or cannot be read.
 * @ghidraAddress 0x76e34
 */
- (nullable NSMutableData *)uncompress:(nullable NSString *)name;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
