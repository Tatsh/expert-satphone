/**
 * @file
 * @brief The model behind the music-select "playlists" feature: an ordered set of user playlists,
 * each a dictionary of an identifier, a display name, and a list of music identifiers, persisted
 * to a property-list file on disk.
 *
 * Reconstructed from Ghidra program Jubeat (class MusicPlaylistManager, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject , taken from the @c -initWithFile: chain-up to @c [super init] .
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Manages the user's music playlists, persisting them to a property-list file.
 *
 * Each playlist is a mutable dictionary with three keys: a stable string identifier, a display
 * name, and a mutable array of music identifiers (boxed @c NSUInteger values). The manager loads
 * the array from a file on construction and writes it back on @c -synchronize .
 */
@interface MusicPlaylistManager : NSObject

/** The playlists, each an @c NSMutableDictionary keyed by identifier, name, and music list. */
@property(nonatomic, strong, nullable) NSMutableArray *arrayPlaylist;
/** The property-list file the playlists are loaded from and written back to. */
@property(nonatomic, strong, nullable) NSString *filePath;

/**
 * @brief Initialises the manager and loads any playlists already stored at @p file.
 *
 * Seeds an empty mutable array, remembers a copy of the path, then reads the file as an array of
 * dictionaries. Each element that is a dictionary carrying all three keys is normalised into a
 * fresh mutable dictionary and appended; malformed elements are skipped.
 *
 * @param file The property-list path to load from and later synchronise to.
 * @return The initialised manager, or @c nil if @c [super init] fails.
 * @ghidraAddress 0x164804
 */
- (instancetype)initWithFile:(nonnull NSString *)file;

/**
 * @brief Writes the current playlists back to the file, atomically.
 * @ghidraAddress 0x164c00
 */
- (void)synchronize;

/**
 * @brief Returns the number of playlists.
 * @return The playlist count.
 * @ghidraAddress 0x164c74
 */
- (NSUInteger)numberOfPlaylists;

/**
 * @brief Returns the playlist dictionary at @p index, or @c nil if out of range or malformed.
 *
 * The element is returned only when it is a dictionary carrying all three keys.
 *
 * @param index The playlist index.
 * @return The playlist dictionary, or @c nil .
 * @ghidraAddress 0x164cc0
 */
- (nullable NSMutableDictionary *)playlistAtIndex:(NSUInteger)index;

/**
 * @brief Returns the index of @p playlist by identity, or @c NSNotFound .
 * @param playlist The playlist dictionary to search for.
 * @return The playlist's index, or @c NSNotFound when it is not present.
 * @ghidraAddress 0x164e4c
 */
- (NSUInteger)indexOfPlaylist:(nonnull NSDictionary *)playlist;

/**
 * @brief Returns the index of the playlist whose identifier equals @p identifier.
 * @param identifier The playlist identifier to match.
 * @return The index, or @c NSNotFound if no playlist matches or @p identifier is @c nil .
 * @ghidraAddress 0x164ec4
 */
- (NSUInteger)indexOfPlaylistWithIdentifier:(nullable NSString *)identifier;

/**
 * @brief Returns the display name of the playlist at @p index, or @c nil if out of range.
 * @param index The playlist index.
 * @return The playlist's display name, or nil when the index is out of range.
 * @ghidraAddress 0x165068
 */
- (nullable NSString *)nameOfPlaylistAtIndex:(NSUInteger)index;

/**
 * @brief Returns the identifier of the playlist at @p index, or @c nil if out of range.
 * @param index The playlist index.
 * @return The playlist's identifier, or nil when the index is out of range.
 * @ghidraAddress 0x165144
 */
- (nullable NSString *)identifierOfPlaylistAtIndex:(NSUInteger)index;

/**
 * @brief Sets the display name of the playlist at @p index.
 * @param name The new name; an empty name is rejected.
 * @param index The playlist index.
 * @return @c YES if @p name is non-empty (whether or not the index was in range), @c NO otherwise.
 * @ghidraAddress 0x165220
 */
- (BOOL)setNameOfPlaylist:(nonnull NSString *)name atIndex:(NSUInteger)index;

/**
 * @brief Appends a new, empty playlist with the given display name.
 *
 * Mints a stable identifier and stores a playlist with an empty music list.
 *
 * @param name The display name; an empty name is rejected.
 * @return @c YES if @p name is non-empty and the playlist was added, @c NO otherwise.
 * @ghidraAddress 0x1652e4
 */
- (BOOL)addPlaylistWithName:(nonnull NSString *)name;

/**
 * @brief Removes the playlist at @p index.
 * @param index The playlist index.
 * @return @c YES if the index was in range, @c NO otherwise.
 * @ghidraAddress 0x165560
 */
- (BOOL)removePlaylistAtIndex:(NSUInteger)index;

/**
 * @brief Returns the number of music entries in the playlist at @p index.
 * @param index The playlist index.
 * @return The count, or @c 0 if the index is out of range or the playlist has no music list.
 * @ghidraAddress 0x165608
 */
- (NSUInteger)numberOfMusicInPlaylistAtIndex:(NSUInteger)index;

/**
 * @brief Tests whether the music identified by @p musicIdentifier is in the playlist at @p index.
 * @param musicIdentifier The music identifier; @c 0 is treated as absent.
 * @param index The playlist index.
 * @return @c YES if present, @c NO otherwise.
 * @ghidraAddress 0x16570c
 */
- (BOOL)containsMusic:(NSUInteger)musicIdentifier inPlaylistAtIndex:(NSUInteger)index;

/**
 * @brief Adds the music identified by @p musicIdentifier to the playlist at @p index.
 *
 * Creates the music list if the playlist has none yet, and does nothing if the music is already
 * present or @p musicIdentifier is @c 0 .
 *
 * @param musicIdentifier The music identifier.
 * @param index The playlist index.
 * @ghidraAddress 0x165858
 */
- (void)addMusic:(NSUInteger)musicIdentifier toPlaylistAtIndex:(NSUInteger)index;

/**
 * @brief Removes the music identified by @p musicIdentifier from the playlist at @p index.
 * @param musicIdentifier The music identifier; @c 0 is treated as absent.
 * @param index The playlist index.
 * @return @c YES if the index was in range, @c NO otherwise.
 * @ghidraAddress 0x1659f0
 */
- (BOOL)removeMusic:(NSUInteger)musicIdentifier fromPlaylistAtIndex:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
