/** @file
 * A table listing the ten difficulty levels used to filter a music playlist. Each row shows a
 * level and how many charts sit at that level; picking a row tells the delegate which level was
 * chosen.
 *
 * Reconstructed from Ghidra program Jubeat (class MusicPlaylistLevelSelector, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableViewController , from the chain-up in @c -init (the dispatch to
 * @c [UITableViewController init]).
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Notified when the user picks a difficulty level from the list.
 */
@protocol MusicPlaylistLevelSelectorDelegate <NSObject>

@optional

/**
 * @brief Tells the delegate which level the user chose.
 *
 * The value is the one-based level, i.e. the selected row's index plus one, boxed as an
 * @c NSNumber . Sent with @c -performSelector:withObject: only when the delegate implements it.
 *
 * @param level The chosen level (one-based), boxed.
 */
- (void)selectLevel:(nullable NSNumber *)level;

@end

/**
 * @brief A table view controller listing difficulty levels for filtering a music playlist.
 */
@interface MusicPlaylistLevelSelector : UITableViewController

/**
 * @brief The object told which level the user picks. Held weakly.
 */
@property(nonatomic, weak, nullable) id<MusicPlaylistLevelSelectorDelegate> delegate;

/**
 * @brief Sets the navigation title, installs a Cancel back button, and builds the level counts.
 * @return The initialised controller.
 * @ghidraAddress 0x1c2d04
 */
- (nullable instancetype)init;

/**
 * @brief Loads the view by chaining up to the superclass.
 * @ghidraAddress 0x1c2e5c
 */
- (void)loadView;

/**
 * @brief Builds @c numArray : the number of charts found at each of the ten levels.
 *
 * Scans the built-in tunes and the purchased tunes, decoding each archive's info dictionary into a
 * @c TuneInfo , then tallies, for every level one through ten, how many distinct charts (basic,
 * advanced, and extreme, counting a repeated level only once) sit at that level. The purchased
 * scan caches each tune's info keyed by identifier alongside its file size and modification date,
 * so an unchanged file is not decoded again.
 *
 * @ghidraAddress 0x1c2e94
 */
- (void)createNumberArray;

/**
 * @brief Decodes a tune archive at @p path into its info dictionary.
 *
 * Opens the archive skipping its sixteen-byte digest trailer and tries the entries newest-first:
 * an @c infov3 entry is deciphered with the tune-info key and stripped of its four-byte header,
 * while an @c infov2 or @c info entry is deciphered with the BGM key and used whole.
 *
 * @param path The archive's path.
 * @return The info dictionary, or @c nil if the archive cannot be opened or holds no info entry.
 * @ghidraAddress 0x1c42d8
 */
- (nullable NSDictionary *)getTuneInfo:(nullable NSString *)path;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
