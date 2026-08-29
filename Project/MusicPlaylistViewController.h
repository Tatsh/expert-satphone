/**
 * @file
 * The music-select "playlists" screen: a table listing the built-in filter rows, a level
 * filter, and the user's playlists.
 *
 * It supports creating a new playlist, deleting one with a swipe, and picking either a filter, a
 * level, or a playlist to drive the selected music identifier.
 *
 * Reconstructed from Ghidra program Jubeat (class MusicPlaylistViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableViewController , taken from the @c -initWithStyle: chain-up and the
 * @c super dispatch in every lifecycle override.
 */

#import <UIKit/UIKit.h>

#import "MusicPlaylistCreateViewController.h"
#import "MusicPlaylistLevelSelector.h"
#import "MusicPlaylistManager.h"

@class MusicPlaylistViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * Which of the two list layouts the controller shows.
 *
 * Drives the section and row counts and the navigation title. In @c Playlists mode the table has
 * three sections (the built-in filter rows, the single level-filter row, and the playlists). In
 * @c AddToPlaylist mode the table has one section listing the playlists a song may be added to.
 */
typedef NS_ENUM(NSUInteger, MusicPlaylistListMode) {
    MusicPlaylistListModePlaylists = 0,     /*!< Browse the filters, levels, and playlists. */
    MusicPlaylistListModeAddToPlaylist = 1, /*!< Pick a playlist to add the current song to. */
};

/**
 * Receives selection and close events from a @c MusicPlaylistViewController .
 */
@protocol MusicPlaylistViewControllerDelegate <NSObject>

@optional

/**
 * Asks the delegate which selection is currently active.
 *
 * The value is either a playlist row index or one of the negative sentinels the controller compares
 * against (for example the "All Songs" and level sentinels), so the currently-selected row can be
 * checkmarked and protected from deletion. Sent only when the delegate implements it.
 *
 * @param controller The controller asking.
 * @return The active selection identifier.
 */
- (NSInteger)musicPlaylistViewControllerCurrentSelection:(MusicPlaylistViewController *)controller;

/**
 * Tells the delegate the user picked a filter, level, or playlist.
 *
 * @param controller The controller.
 * @param selection A playlist row index, or a negative sentinel for a built-in filter or the level
 * filter.
 * @param musicID The music identifier the selection applies to.
 */
- (void)musicPlaylistViewController:(MusicPlaylistViewController *)controller
                   playlistSelected:(NSInteger)selection
                    selectedMusicID:(NSUInteger)musicID;

/**
 * Tells the delegate the user tapped the Close button (phone idiom only).
 * @param controller The controller closing.
 */
- (void)musicPlaylistViewControllerWillClosed:(MusicPlaylistViewController *)controller;

@end

/**
 * A table view controller managing the user's music playlists.
 */
// clang-format off
// One protocol per line: a continuation line that begins with ": Base <" is read by Doxygen as
// undocumented ivars named after the trailing protocols. The second protocol is indented rather
// than aligned because aligning it would pass the column limit.
@interface MusicPlaylistViewController : UITableViewController <MusicPlaylistLevelSelectorDelegate,
    MusicPlaylistCreateViewControllerDelegate>
// clang-format on

/**
 * Which list layout the table shows.
 *
 * The setter also updates the navigation title.
 */
@property(nonatomic) MusicPlaylistListMode listMode;

/** The music identifier the selections apply to. */
@property(nonatomic) NSUInteger selectedMusicID;

/** The object told about selections and close events. Held weakly. */
@property(nonatomic, weak, nullable) id<MusicPlaylistViewControllerDelegate> delegate;

/**
 * The model backing the playlists list.
 *
 * The setter enables the "new playlist" bar button only while a manager is present and below the
 * playlist cap.
 */
@property(nonatomic, strong, nullable) MusicPlaylistManager *playlistManager;

/** The right-hand "new playlist" bar button item. */
@property(nonatomic, strong, nullable) UIBarButtonItem *barBtnNew;

/**
 * Builds the controller, its content size, and its navigation bar.
 *
 * Sets a fixed preferred content size, installs the localized "NewPL" right bar button wired to
 * @c -tapNewPlaylist: (tinted when the running system supports it), and on the phone idiom adds a
 * localized "Close" left bar button wired to @c -tapClose: . Starts in @c Playlists mode and seeds
 * the persisted level filter.
 *
 * @param style The table style forwarded to the superclass.
 * @return The initialised controller, or @c nil if @c [super initWithStyle:] fails.
 * @ghidraAddress 0x15ca34
 */
- (instancetype)initWithStyle:(UITableViewStyle)style;

/**
 * Height for a section's footer.
 * @param tableView The table view.
 * @param section The section index.
 * @return @c 4 for the level-filter section in @c Playlists mode, otherwise @c 0 .
 * @ghidraAddress 0x15d0a8
 */
- (CGFloat)tableView:(nonnull UITableView *)tableView heightForFooterInSection:(NSInteger)section;

/**
 * Builds a cell for a filter, level, or playlist row.
 * @param tableView The table view.
 * @param indexPath The row's index path.
 * @return The configured cell.
 * @ghidraAddress 0x15d10c
 */
- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView
                 cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * Number of sections: three in @c Playlists mode, one otherwise.
 * @param tableView The table asking.
 * @return Three in @c Playlists mode, one otherwise.
 * @ghidraAddress 0x15dcd0
 */
- (NSInteger)numberOfSectionsInTableView:(nonnull UITableView *)tableView;

/**
 * Number of rows in a section.
 * @param tableView The table asking.
 * @param section The section asked about.
 * @return The row count for that section.
 * @ghidraAddress 0x15dcfc
 */
- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section;

/**
 * Deletes a playlist when its row is swiped.
 * @param tableView The table asking.
 * @param editingStyle The editing action committed.
 * @param indexPath The row's index path.
 * @ghidraAddress 0x15dd9c
 */
- (void)tableView:(nonnull UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * Whether a row may be edited (swipe-deleted).
 *
 * Only playlist rows in @c Playlists mode are editable, and never the currently-selected playlist.
 * @param tableView The table asking.
 * @param indexPath The row's index path.
 * @return YES for an editable playlist row, NO otherwise.
 * @ghidraAddress 0x15df6c
 */
- (BOOL)tableView:(nonnull UITableView *)tableView
    canEditRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * Blocks selection of an already-active row.
 * @param tableView The table asking.
 * @param indexPath The row about to be selected.
 * @return The index path when selectable, @c nil otherwise.
 * @ghidraAddress 0x15e094
 */
- (nullable NSIndexPath *)tableView:(nonnull UITableView *)tableView
           willSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * Routes a selection: a filter or playlist notifies the delegate, the level row pushes the
 * level selector.
 * @param tableView The table sending the message.
 * @param indexPath The tapped row's index path.
 * @ghidraAddress 0x15e2ec
 */
- (void)tableView:(nonnull UITableView *)tableView
    didSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * Whitens a cell's background, tinting the level row when a level filter is active.
 * @param tableView The table asking.
 * @param cell The cell about to be drawn.
 * @param indexPath The row's index path.
 * @ghidraAddress 0x15e4fc
 */
- (void)tableView:(nonnull UITableView *)tableView
      willDisplayCell:(nonnull UITableViewCell *)cell
    forRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * Persists the chosen level and tells the delegate the level filter was picked.
 *
 * The @c MusicPlaylistLevelSelectorDelegate callback.
 *
 * @param level The chosen level (one-based), boxed.
 * @ghidraAddress 0x15e630
 */
- (void)selectLevel:(nullable NSNumber *)level;

/**
 * Pushes the create-playlist screen.
 * @param sender The bar button, unused.
 * @ghidraAddress 0x15e720
 */
- (void)tapNewPlaylist:(nullable id)sender;

/**
 * Empty action; the level filter is instead reached through row selection.
 * @ghidraAddress 0x15e7d0
 */
- (void)tapLevelSelect;

/**
 * Tells the delegate the screen should close.
 * @param sender The Close bar button, unused.
 * @ghidraAddress 0x15e7d4
 */
- (void)tapClose:(nullable id)sender;

/**
 * Adds a playlist with the entered name, persists it, and reloads.
 *
 * The @c MusicPlaylistCreateViewControllerDelegate callback.
 *
 * @param name The playlist name.
 * @ghidraAddress 0x15e880
 */
- (void)musicPlaylistCreateWithName:(nullable NSString *)name;

/**
 * Chains up to @c super .
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x15e9d8
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * Chains up to @c super .
 * @param animated Whether the appearance was animated.
 * @ghidraAddress 0x15ea10
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * Chains up to @c super .
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x15ea48
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * Chains up to @c super .
 * @param animated Whether the disappearance was animated.
 * @ghidraAddress 0x15ea80
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * Disables exclusive-touch propagation across the navigation bar's subviews.
 * @ghidraAddress 0x15eab8
 */
- (void)viewDidLoad;

/**
 * Reports that only the two portrait orientations are supported.
 * @param interfaceOrientation The orientation being asked about.
 * @return @c YES for either portrait orientation.
 * @ghidraAddress 0x15ed50
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * The orientations the screen allows.
 * @return Both portrait orientations.
 * @ghidraAddress 0x15ed60
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * Whether the screen rotates at all.
 * @return Always @c YES .
 * @ghidraAddress 0x15ed68
 */
- (BOOL)shouldAutorotate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
