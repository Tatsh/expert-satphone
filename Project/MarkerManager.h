/**
 * @file
 * The marker (note-skin) asset manager.
 *
 * Reconstructed from Ghidra program Jubeat (class MarkerManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x3480d0.
 *
 * Maintains the process-wide marker list, resolves marker and banner file paths within the app's
 * Library tree, persists the list through @c NSUserDefaults (BFCodec-enciphered keyed archive),
 * copies and moves marker and banner items between the bundle and the installed location, and
 * builds the default marker list. It is mostly class (+) methods over process-wide state, with two
 * instance methods and three instance ivars.
 */

#import <Foundation/Foundation.h>

@class NSURL;

NS_ASSUME_NONNULL_BEGIN

/**
 * Owns the marker assets and their on-disc layout.
 */
@interface MarkerManager : NSObject

/**
 * Initialises the manager with a delegate.
 *
 * Stores @p delegate weakly and resets the current slot to zero.
 *
 * @param delegate The object told about marker events; held weakly.
 * @return The initialised instance, or nil.
 * @ghidraAddress 0x1b749c
 */
- (instancetype)initWithDelegate:(nullable id)delegate;

/**
 * Replaces the download list with a mutable copy of @p list.
 *
 * Resets the current slot to zero.
 *
 * @param list The markers queued for download.
 * @ghidraAddress 0x1b7520
 */
- (void)setDownloadList:(nullable NSArray *)list;

/**
 * The reserved marker index boundary.
 *
 * @return The constant 1000.
 * @ghidraAddress 0x1b75a8
 */
+ (int)getReservedMarkerSize;

/**
 * The number of markers in the default list.
 *
 * @return The constant 35.
 * @ghidraAddress 0x1b75b0
 */
+ (int)getDefaultMarkerSize;

/**
 * The position of a marker within the current (installed) list.
 *
 * @param markerID The marker's identifier, as stored under the @c markerID key.
 * @return The zero-based index of the first match, or zero when absent.
 * @ghidraAddress 0x1b75b8
 */
+ (int)getMarkerIndex:(nullable NSString *)markerID;

/**
 * The full persisted marker list, deciphered and unarchived.
 *
 * @return The marker list, or nil when nothing is stored.
 * @ghidraAddress 0x1b775c
 */
+ (nullable NSMutableArray<NSDictionary<NSString *, NSString *> *> *)getMarkerList;

/**
 * Archives, enciphers, and persists @p list.
 *
 * @param list The marker list to store.
 * @ghidraAddress 0x1b78b4
 */
+ (void)setMarkerList:(nullable NSArray<NSDictionary<NSString *, NSString *> *> *)list;

/**
 * The installed markers, excluding those whose version is still @c 0.0.0.
 *
 * @return A freshly built array of the installed markers.
 * @ghidraAddress 0x1b7a04
 */
+ (nullable NSMutableArray<NSDictionary<NSString *, NSString *> *> *)getCurrentMarkerList;

/**
 * The marker at @p index within the current (installed) list.
 *
 * @param index The zero-based index.
 * @return The marker's info dictionary.
 * @ghidraAddress 0x1b7bb8
 */
+ (nullable NSDictionary<NSString *, NSString *> *)getMarkerInfo:(int)index;

/**
 * Inserts or replaces a marker in the list, keeping it ordered by identifier.
 *
 * Replaces an existing entry with the same @c markerID; otherwise inserts @p info before the first
 * marker with a greater numeric identifier, or appends it. Persists the result.
 *
 * @param info The marker's info dictionary.
 * @ghidraAddress 0x1b7c1c
 */
+ (void)setMarkerInfo:(nullable NSDictionary<NSString *, NSString *> *)info;

/**
 * Whether a marker's banner data is present.
 *
 * @param name The marker's data name.
 * @return Always YES.
 * @ghidraAddress 0x1b7ef8
 */
+ (BOOL)checkMarkerBannerData:(nullable NSString *)name;

/**
 * Whether a marker's data is present on disc and passes its MD5 trailer check.
 *
 * @param name The marker's data name.
 * @return YES when the file exists and its trailing digest validates.
 * @ghidraAddress 0x1b7f00
 */
+ (BOOL)checkMarkerData:(nullable NSString *)name;

/**
 * Excludes a file URL from iCloud backup.
 *
 * @param url The file URL to flag.
 * @ghidraAddress 0x1b80a8
 */
+ (void)setIgnoreSave:(nullable NSURL *)url;

/**
 * Extracts a banner image from a downloaded marker archive, or copies the bundled banner.
 *
 * When the archive at @p path contains @c banner.png it is uncompressed and written to the banner
 * path; otherwise the bundled banner for @p bannerID is copied.
 *
 * @param path The downloaded marker archive path.
 * @param bannerID The banner's identifier.
 * @ghidraAddress 0x1b8144
 */
+ (void)pullOutMarkerBanner:(nullable NSString *)path bannerID:(nullable NSString *)bannerID;

/**
 * Writes downloaded marker data to its installed path and excludes it from backup.
 *
 * @param data The marker's file data.
 * @param markerID The marker's identifier.
 * @ghidraAddress 0x1b82ac
 */
+ (void)saveMarker:(nullable NSData *)data markerID:(nullable NSString *)markerID;

/**
 * Copies a bundled marker or banner resource into the installed marker directory.
 *
 * @param name The bundled resource's base name.
 * @param isBanner YES to copy a banner PNG into the banner subdirectory; NO for a marker ZIP.
 * @ghidraAddress 0x1b8378
 */
+ (void)copyMarkerItem:(nullable NSString *)name isBanner:(BOOL)isBanner;

/**
 * Copies a bundled marker ZIP into the installed marker directory.
 *
 * @param name The bundled marker's base name.
 * @ghidraAddress 0x1b8634
 */
+ (void)copyMarker:(nullable NSString *)name;

/**
 * Copies a bundled banner PNG into the installed banner directory.
 *
 * @param name The bundled banner's base name.
 * @ghidraAddress 0x1b8644
 */
+ (void)copyMarkerBanner:(nullable NSString *)name;

/**
 * Copies both a bundled marker and its banner into place.
 *
 * @param markerID The bundled marker's base name.
 * @param bannerID The bundled banner's base name.
 * @ghidraAddress 0x1b8654
 */
+ (void)markerMove:(nullable NSString *)markerID bannerID:(nullable NSString *)bannerID;

/**
 * The installed marker directory, creating it (and the private documents parent) as needed.
 *
 * @return The @c Library/Private\ Documents/marker path.
 * @ghidraAddress 0x1b86d0
 */
+ (nullable NSString *)getMarkerDirectoryPath;

/**
 * The installed path of a marker's ZIP data.
 *
 * @param name The marker's base name.
 * @return The @c \<markerDir\>/\<name\>.zip path.
 * @ghidraAddress 0x1b884c
 */
+ (nullable NSString *)getMarkerPath:(nullable NSString *)name;

/**
 * The installed path of a marker's banner PNG.
 *
 * @param name The banner's base name.
 * @return The @c \<markerDir\>/banner/\<name\>.png path.
 * @ghidraAddress 0x1b8910
 */
+ (nullable NSString *)getMarkerBannerPath:(nullable NSString *)name;

/**
 * Builds and persists the built-in default marker list.
 *
 * Clears the stored list, adds a marker for each of the 35 default entries, marks entry 26 as the
 * initial (@c 1.0.0) marker, and records it as the current marker.
 *
 * @return Always YES.
 * @ghidraAddress 0x1b8a04
 */
+ (BOOL)createDefaultMarkerList;

/**
 * Migrates a legacy marker-version list into the current list format.
 *
 * @return YES when every default marker's data was found, NO otherwise.
 * @ghidraAddress 0x1b8c68
 */
+ (BOOL)convertMarkerList;

/**
 * Validates the installed marker list, rebuilding it from defaults when it is missing.
 *
 * Ensures the marker and banner directories exist, resets a marker's version to @c 0.0.0 when its
 * data is missing, extracts every banner, and persists the result.
 *
 * @return YES on success, NO when no list could be produced.
 * @ghidraAddress 0x1b8fe0
 */
+ (BOOL)checkRegularMarkerData;

/**
 * Whether marker selection may be enabled.
 *
 * @return NO when an uninstalled marker has a reserved (sub-1000) identifier, YES otherwise.
 * @ghidraAddress 0x1b94ec
 */
+ (BOOL)enableMarkerSelect;

/**
 * Copies the built-in current marker into the Documents marker directory.
 *
 * @return Always YES.
 * @ghidraAddress 0x1b96f4
 */
+ (BOOL)moveMarkerDataInDoc;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
