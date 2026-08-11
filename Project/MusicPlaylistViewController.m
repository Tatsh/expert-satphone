#import "MusicPlaylistViewController.h"

#import "ImageCache.h"
#import "JubeatAppDelegate.h"
#import "MusicPlaylistCreateViewController.h"
#import "MusicPlaylistLevelSelector.h"

// The animation-duration constant (0.2) is reused here as a colour component, exactly as the
// binary does.
extern const double g_dAnimDuration020;

// The maximum number of playlists the user may keep. Above this the "new playlist" button disables.
static const NSUInteger kMaxPlaylists = 50;

// The one-based level count used to filter charts; the level filter row hosts a value in 1..10.
static const int kMinLevel = 1;

// Preferred content size for the popover presentation (iPad). fmov immediates at 0x15ca88/0x15ca90
// read from __const at these addresses.
static const CGFloat kPreferredContentWidth = 320.0;  // 0x10028f470
static const CGFloat kPreferredContentHeight = 400.0; // 0x10028f2e0

// Section indices in Playlists mode.
typedef enum : NSInteger {
    MusicPlaylistSectionFilters = 0,   // The "All Songs" family of filter rows.
    MusicPlaylistSectionLevel = 1,     // The single level-filter row.
    MusicPlaylistSectionPlaylists = 2, // The user's playlists.
} MusicPlaylistSection;

// Rows in the filters section.
typedef enum : NSInteger {
    MusicPlaylistFilterRowAllSongs = 0,
    MusicPlaylistFilterRowAllSongsHold = 1,
    MusicPlaylistFilterRowAllSongsNotHold = 2,
    MusicPlaylistFilterRowNotYetPlayed = 3,
} MusicPlaylistFilterRow;

// Selection sentinels the delegate reports and the controller compares against. They are negative
// so they never collide with a playlist row index.
typedef enum : NSInteger {
    MusicPlaylistSelectionNone = -65536,         // 0xffffffffffff0000
    MusicPlaylistSelectionAllSongs = -2,         // 0xfffffffffffffffe
    MusicPlaylistSelectionAllSongsHold = -11,    // 0xfffffffffffffff5
    MusicPlaylistSelectionAllSongsNotHold = -12, // 0xfffffffffffffff4
    MusicPlaylistSelectionLevel = -10,           // 0xfffffffffffffff6
    MusicPlaylistSelectionNotYetPlayed = -1,     // 0xffffffffffffffff
} MusicPlaylistSelection;

@implementation MusicPlaylistViewController {
    // The persisted level filter value (one-based), and whether the level row is highlighted.
    int openLevel;   // encoding i
    int selectLevel; // encoding i, distinct from the -selectLevel: method
    BOOL bUnEnableTap;
}

// The list mode has a hand-written getter and setter, so synthesize its backing ivar explicitly.
@synthesize listMode = _listMode;

#pragma mark - Lifecycle

/** @ghidraAddress 0x15ca34 */
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        self.preferredContentSize = CGSizeMake(kPreferredContentWidth, kPreferredContentHeight);
        NSString *title = [NSBundle.mainBundle localizedStringForKey:@"NewPL" value:@"" table:nil];
        self.barBtnNew = [[UIBarButtonItem alloc] initWithTitle:title
                                                          style:UIBarButtonItemStylePlain
                                                         target:self
                                                         action:@selector(tapNewPlaylist:)];
        if ([self.barBtnNew respondsToSelector:@selector(setTintColor:)]) {
            // Original used colorWithRed:green:blue:alpha: with (0.1, 0.6, 0.2, 1.0).
            self.barBtnNew.tintColor = [UIColor colorWithRed:0.1
                                                       green:0.6
                                                        blue:g_dAnimDuration020
                                                       alpha:1.0];
        }
        self.navigationItem.rightBarButtonItem = self.barBtnNew;
        if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
            [self performSelector:@selector(setExtendedLayoutIncludesOpaqueBars:) withObject:nil];
        }
        if (!JubeatAppDelegate.appDelegate.isPad) {
            NSString *close = [NSBundle.mainBundle localizedStringForKey:@"Close"
                                                                   value:@""
                                                                   table:nil];
            UIBarButtonItem *closeButton =
                [[UIBarButtonItem alloc] initWithTitle:close
                                                 style:UIBarButtonItemStyleDone
                                                target:self
                                                action:@selector(tapClose:)];
            self.navigationItem.leftBarButtonItem = closeButton;
        }
        self.listMode = MusicPlaylistListModePlaylists;
        openLevel = 0;
        selectLevel = (int)[NSUserDefaults.standardUserDefaults integerForKey:@"PrefPlayListLevel"];
        if (selectLevel == 0) {
            selectLevel = kMinLevel;
        }
        bUnEnableTap = NO;
    }
    return self;
}

/** @ghidraAddress 0x15eab8 */
- (void)viewDidLoad {
    [super viewDidLoad];
    for (UIView *subview in self.navigationController.navigationBar.subviews) {
        [subview setExclusiveTouch:YES];
    }
    for (UIView *subview in self.navigationController.navigationBar.subviews) {
        [subview setExclusiveTouch:YES];
    }
}

/** @ghidraAddress 0x15e9d8 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x15ea10 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x15ea48 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x15ea80 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0x15ed70 */
- (void)dealloc {
    // Clearing the manager through the setter disables the bar button as it goes.
    self.playlistManager = nil;
}

#pragma mark - Accessors

/** @ghidraAddress 0x15ce5c */
- (void)setPlaylistManager:(MusicPlaylistManager *)playlistManager {
    _playlistManager = playlistManager;
    if (self.playlistManager == nil) {
        self.barBtnNew.enabled = NO;
    } else {
        self.barBtnNew.enabled = (self.playlistManager.numberOfPlaylists < kMaxPlaylists);
    }
}

/** @ghidraAddress 0x15cf58 */
- (MusicPlaylistListMode)listMode {
    return _listMode;
}

/** @ghidraAddress 0x15cf68 */
- (void)setListMode:(MusicPlaylistListMode)listMode {
    if (listMode == MusicPlaylistListModeAddToPlaylist) {
        self.navigationItem.title = [NSBundle.mainBundle localizedStringForKey:@"Add To Playlist"
                                                                         value:@""
                                                                         table:nil];
    } else if (listMode == MusicPlaylistListModePlaylists) {
        self.navigationItem.title = [NSBundle.mainBundle localizedStringForKey:@"Playlists"
                                                                         value:@""
                                                                         table:nil];
    } else {
        return;
    }
    _listMode = listMode;
}

#pragma mark - Table data source

/** @ghidraAddress 0x15dcd0 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.listMode != MusicPlaylistListModePlaylists) {
        return 1;
    }
    return 3;
}

/** @ghidraAddress 0x15dcfc */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.listMode == MusicPlaylistListModePlaylists && section == MusicPlaylistSectionFilters) {
        return 4;
    }
    if (section == MusicPlaylistSectionLevel && self.listMode == MusicPlaylistListModePlaylists) {
        return 1;
    }
    return (NSInteger)self.playlistManager.numberOfPlaylists;
}

/** @ghidraAddress 0x15d0a8 */
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    // fmov immediate at 0x15d0f4 supplies the 4.0.
    if (self.listMode == MusicPlaylistListModePlaylists && section == MusicPlaylistSectionLevel) {
        return 4.0;
    }
    return 0.0;
}

/** @ghidraAddress 0x15d10c */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const kPlaylistCellIdentifier = @"PlaylistTableCell";
    static NSString *const kLevelCellIdentifier = @"PlayListTableLevelCell";
    NSString *identifier = kPlaylistCellIdentifier;
    if (indexPath.section == MusicPlaylistSectionLevel) {
        identifier = kLevelCellIdentifier;
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:identifier];
    }
    NSInteger currentSelection = MusicPlaylistSelectionNone;
    if ([self.delegate
            respondsToSelector:@selector(musicPlaylistViewControllerCurrentSelection:)]) {
        currentSelection = [self.delegate musicPlaylistViewControllerCurrentSelection:self];
    }
    cell.backgroundColor = UIColor.whiteColor;
    cell.detailTextLabel.text = @"";

    NSString *title = nil;
    UIImage *image = nil;
    BOOL selected = NO;
    BOOL enabled = YES;

    if (self.listMode == MusicPlaylistListModePlaylists &&
        indexPath.section == MusicPlaylistSectionFilters) {
        switch (indexPath.row) {
        case MusicPlaylistFilterRowAllSongs:
            title = [NSBundle.mainBundle localizedStringForKey:@"All Songs" value:@"" table:nil];
            image = [ImageCache.sharedCache getResPNG:@"pl_icon_all_b"];
            selected = (currentSelection == MusicPlaylistSelectionAllSongs);
            break;
        case MusicPlaylistFilterRowAllSongsHold:
            title = [NSBundle.mainBundle localizedStringForKey:@"All Songs(Hold)"
                                                         value:@""
                                                         table:nil];
            image = [ImageCache.sharedCache getResPNG:@"pl_icon_all_b"];
            selected = (currentSelection == MusicPlaylistSelectionAllSongsHold);
            break;
        case MusicPlaylistFilterRowAllSongsNotHold:
            title = [NSBundle.mainBundle localizedStringForKey:@"All Songs(Not Hold)"
                                                         value:@""
                                                         table:nil];
            image = [ImageCache.sharedCache getResPNG:@"pl_icon_all_b"];
            selected = (currentSelection == MusicPlaylistSelectionAllSongsNotHold);
            break;
        case MusicPlaylistFilterRowNotYetPlayed:
            title = [NSBundle.mainBundle localizedStringForKey:@"Not Yet Played"
                                                         value:@""
                                                         table:nil];
            image = [ImageCache.sharedCache getResPNG:@"pl_icon_new_b"];
            selected = (currentSelection == MusicPlaylistSelectionNotYetPlayed);
            break;
        default:
            break;
        }
        cell.detailTextLabel.text = nil;
    } else if (self.listMode == MusicPlaylistListModePlaylists &&
               indexPath.section == MusicPlaylistSectionLevel) {
        image = [ImageCache.sharedCache getResPNG:@"pl_icon_level_b"];
        if (currentSelection == MusicPlaylistSelectionLevel) {
            title = [NSString stringWithFormat:@"Level %d", selectLevel];
            selected = YES;
        } else {
            title = @"LEVEL";
            selected = NO;
            enabled = YES;
        }
    } else {
        NSUInteger count = [self.playlistManager numberOfMusicInPlaylistAtIndex:indexPath.row];
        title = [self.playlistManager nameOfPlaylistAtIndex:indexPath.row];
        if ((int)count < 2) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%d song", (int)count];
        } else {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%d songs", (int)count];
        }
        if (self.listMode == MusicPlaylistListModePlaylists) {
            selected = (currentSelection == indexPath.row);
        } else if (self.listMode == MusicPlaylistListModeAddToPlaylist) {
            enabled = ![self.playlistManager containsMusic:self.selectedMusicID
                                         inPlaylistAtIndex:indexPath.row];
        } else {
            selected = NO;
        }
    }

    if (title != nil) {
        cell.textLabel.text = title;
    }
    cell.imageView.image = image;
    cell.textLabel.backgroundColor = UIColor.clearColor;

    if (selected) {
        // Original used colorWithRed:green:blue:alpha: with (0.1, 0.1, 1.0, 1.0) and
        // (0.4, 0.4, 1.0, 1.0).
        cell.textLabel.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:1.0 alpha:1.0];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:1.0 alpha:1.0];
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        if (indexPath.section == MusicPlaylistSectionLevel) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (enabled) {
        cell.textLabel.textColor = UIColor.blackColor;
        cell.detailTextLabel.textColor = UIColor.grayColor;
        cell.accessoryType = UITableViewCellAccessoryNone;
        if (indexPath.section == MusicPlaylistSectionLevel) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    } else {
        cell.textLabel.textColor = UIColor.grayColor;
        cell.detailTextLabel.textColor = UIColor.lightGrayColor;
        cell.accessoryType = UITableViewCellAccessoryNone;
        if (indexPath.section == MusicPlaylistSectionLevel) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return cell;
}

#pragma mark - Table delegate

/** @ghidraAddress 0x15df6c */
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.listMode == MusicPlaylistListModePlaylists) {
        if (indexPath.section == MusicPlaylistSectionFilters ||
            indexPath.section == MusicPlaylistSectionLevel) {
            return NO;
        }
        if ([self.delegate
                respondsToSelector:@selector(musicPlaylistViewControllerCurrentSelection:)]) {
            NSInteger current = [self.delegate musicPlaylistViewControllerCurrentSelection:self];
            return indexPath.row != current;
        }
    }
    return YES;
}

/** @ghidraAddress 0x15dd9c */
- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        if ([self.playlistManager removePlaylistAtIndex:indexPath.row]) {
            [self.playlistManager synchronize];
            [tableView deleteRowsAtIndexPaths:@[ indexPath ]
                             withRowAnimation:UITableViewRowAnimationNone];
            if (self.playlistManager.numberOfPlaylists < kMaxPlaylists) {
                self.barBtnNew.enabled = YES;
            }
        }
    }
}

/** @ghidraAddress 0x15e094 */
- (NSIndexPath *)tableView:(UITableView *)tableView
    willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.listMode == MusicPlaylistListModePlaylists) {
        NSInteger currentSelection = MusicPlaylistSelectionNone;
        if ([self.delegate
                respondsToSelector:@selector(musicPlaylistViewControllerCurrentSelection:)]) {
            currentSelection = [self.delegate musicPlaylistViewControllerCurrentSelection:self];
        }
        if (indexPath.section == MusicPlaylistSectionFilters) {
            if (currentSelection == MusicPlaylistSelectionAllSongs &&
                indexPath.row == MusicPlaylistFilterRowAllSongs) {
                return nil;
            }
            if (currentSelection == MusicPlaylistSelectionNotYetPlayed &&
                indexPath.row == MusicPlaylistFilterRowNotYetPlayed) {
                return nil;
            }
            if (currentSelection == MusicPlaylistSelectionAllSongsHold &&
                indexPath.row == MusicPlaylistFilterRowAllSongsHold) {
                return nil;
            }
            if (currentSelection == MusicPlaylistSelectionAllSongsNotHold &&
                indexPath.row == MusicPlaylistFilterRowAllSongsNotHold) {
                return nil;
            }
            return indexPath;
        }
        if (indexPath.section == MusicPlaylistSectionLevel) {
            if (!bUnEnableTap) {
                return indexPath;
            }
            return nil;
        }
        if (indexPath.row == currentSelection) {
            return nil;
        }
        return indexPath;
    }
    if (self.listMode != MusicPlaylistListModeAddToPlaylist) {
        return indexPath;
    }
    if ([self.playlistManager containsMusic:self.selectedMusicID inPlaylistAtIndex:indexPath.row]) {
        return nil;
    }
    return indexPath;
}

/** @ghidraAddress 0x15e2ec */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SEL playlistSelected = @selector(musicPlaylistViewController:playlistSelected:selectedMusicID:);
    if (![self.delegate respondsToSelector:playlistSelected]) {
        return;
    }
    NSInteger selection;
    if (self.listMode == MusicPlaylistListModePlaylists &&
        indexPath.section == MusicPlaylistSectionFilters) {
        static const NSInteger filterSelections[] = {MusicPlaylistSelectionAllSongsHold,
                                                     MusicPlaylistSelectionAllSongsNotHold,
                                                     MusicPlaylistSelectionNotYetPlayed};
        // Rows 1..3 map to the three explicit sentinels; row 0 (and any other) falls to All Songs.
        // The binary tests (row - 1) as an unsigned quantity, so row 0 wraps past the table.
        if ((NSUInteger)(indexPath.row - 1) < 3) {
            selection = filterSelections[indexPath.row - 1];
        } else {
            selection = MusicPlaylistSelectionAllSongs;
        }
    } else if (self.listMode == MusicPlaylistListModePlaylists &&
               indexPath.section == MusicPlaylistSectionLevel) {
        if (bUnEnableTap) {
            return;
        }
        MusicPlaylistLevelSelector *selector = [[MusicPlaylistLevelSelector alloc] init];
        selector.preferredContentSize = self.preferredContentSize;
        selector.delegate = self;
        [self.navigationController pushViewController:selector animated:YES];
        return;
    } else {
        selection = indexPath.row;
    }
    [self.delegate musicPlaylistViewController:self
                              playlistSelected:selection
                               selectedMusicID:self.selectedMusicID];
}

/** @ghidraAddress 0x15e4fc */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.backgroundColor = UIColor.whiteColor;
    if (self.listMode == MusicPlaylistListModePlaylists &&
        indexPath.section == MusicPlaylistSectionLevel && indexPath.row == 0 && openLevel != 0) {
        // hue 0.61, saturation 0.09, brightness 0.99 from __const at 0x1002932d8/e0/e8.
        cell.backgroundColor = [UIColor colorWithHue:0.61
                                          saturation:0.09
                                          brightness:0.99
                                               alpha:1.0];
    }
}

#pragma mark - Actions and delegate callbacks

/** @ghidraAddress 0x15e630 */
- (void)selectLevel:(NSNumber *)level {
    [NSUserDefaults.standardUserDefaults setInteger:(NSInteger)level.intValue
                                             forKey:@"PrefPlayListLevel"];
    [self.delegate musicPlaylistViewController:self
                              playlistSelected:MusicPlaylistSelectionLevel
                               selectedMusicID:self.selectedMusicID];
}

/** @ghidraAddress 0x15e720 */
- (void)tapNewPlaylist:(id)sender {
    MusicPlaylistCreateViewController *create = [[MusicPlaylistCreateViewController alloc] init];
    create.preferredContentSize = self.preferredContentSize;
    create.delegate = self;
    [self.navigationController pushViewController:create animated:YES];
}

/** @ghidraAddress 0x15e7d0 */
- (void)tapLevelSelect {
}

/** @ghidraAddress 0x15e7d4 */
- (void)tapClose:(id)sender {
    if ([self.delegate respondsToSelector:@selector(musicPlaylistViewControllerWillClosed:)]) {
        [self.delegate musicPlaylistViewControllerWillClosed:self];
    }
}

/** @ghidraAddress 0x15e880 */
- (void)musicPlaylistCreateWithName:(NSString *)name {
    if ([self.playlistManager addPlaylistWithName:name]) {
        [self.playlistManager synchronize];
        if (self.playlistManager.numberOfPlaylists > kMaxPlaylists - 1) {
            self.barBtnNew.enabled = NO;
        }
        [self.tableView reloadData];
    }
}

#pragma mark - Rotation

/** @ghidraAddress 0x15ed50 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // True for the two portrait orientations, tested as the unsigned (orientation - 1) < 2.
    return (NSUInteger)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x15ed60 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x15ed68 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
