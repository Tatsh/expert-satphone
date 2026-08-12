#import "SettingsThemeViewController.h"

#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The navigation-bar title shown on the theme picker.
static NSString *const kTitle = @"THEME";

// The localised-string key for the commit button's label. The bundle resolves it to "Change
// Theme"; when there is no translation the key itself is shown.
static NSString *const kChangeThemeKey = @"Change Theme";

// The reuse identifier the theme cells are dequeued and created under.
static NSString *const kCellIdentifier = @"SettingsThemeTableCell";

// The pattern-image base names for the three theme rows, indexed by row (which equals the
// JubeatTheme value): row 0 Original, row 1 Ripples, row 2 Knit.
static NSString *const kThemeClassicImageName = @"theme_classic";
static NSString *const kThemeRipplesImageName = @"theme_ripples";
static NSString *const kThemeKnitImageName = @"theme_knit";

// The table has one section holding the three theme rows.
static const NSInteger kSectionCount = 1;
static const NSInteger kThemeRowCount = 3;

// The fixed row height, read from the pooled double at 0x28f758. @ghidraAddress 0x28f758
static const CGFloat kRowHeight = 42.0;

// The raw supported-orientation mask the binary returns: 6, i.e. portrait and portrait-upside-down
// (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown). Kept as the
// literal the binary uses rather than a named mask, since it is not one of the common combinations.
static const UIInterfaceOrientationMask kSupportedOrientations =
    UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;

@interface SettingsThemeViewController () {
    int selectedIndex; // The row (and theme value) currently checked.
}
@end

@implementation SettingsThemeViewController

#pragma mark - Construction

/** @ghidraAddress 0x144198 */
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (!self) {
        return self;
    }
    self.navigationItem.title = kTitle;
    NSString *changeTitle = [[NSBundle mainBundle] localizedStringForKey:kChangeThemeKey
                                                                   value:@""
                                                                   table:nil];
    self.changeBarBtn = [[UIBarButtonItem alloc] initWithTitle:changeTitle
                                                         style:UIBarButtonItemStyleDone
                                                        target:self
                                                        action:@selector(buttonCommitChange:)];
    self.changeBarBtn.enabled = NO;
    self.navigationItem.rightBarButtonItem = self.changeBarBtn;
    selectedIndex = (int)[JubeatAppDelegate appDelegate].currentTheme;
    return self;
}

#pragma mark - Commit

/** @ghidraAddress 0x1443b4 */
- (void)buttonCommitChange:(id)sender {
    [[JubeatAppDelegate appDelegate] changeTheme:(JubeatTheme)selectedIndex];
}

#pragma mark - View construction

/** @ghidraAddress 0x14440c */
- (void)loadView {
    [super loadView];
    self.tableView.rowHeight = kRowHeight;
}

#pragma mark - Table view data source

/** @ghidraAddress 0x144488 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kSectionCount;
}

/** @ghidraAddress 0x144490 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return kThemeRowCount;
}

/** @ghidraAddress 0x144498 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Only the single section carries rows; any other section returns nil.
    if (indexPath.section != 0) {
        return nil;
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:kCellIdentifier];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryType = indexPath.row == selectedIndex ? UITableViewCellAccessoryCheckmark :
                                                          UITableViewCellAccessoryNone;
    return cell;
}

#pragma mark - Table view delegate

/** @ghidraAddress 0x1445c8 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Give the row a full-cell background patterned with its theme's preview image.
    NSString *imageName;
    switch (indexPath.row) {
    case JubeatThemeRipples:
        imageName = kThemeRipplesImageName;
        break;
    case JubeatThemeKnit:
        imageName = kThemeKnitImageName;
        break;
    case JubeatThemeOriginal:
        imageName = kThemeClassicImageName;
        break;
    default:
        return;
    }
    UIImage *image = LoadScaledPngImage(imageName);
    cell.backgroundColor = [UIColor colorWithPatternImage:image];
}

/** @ghidraAddress 0x1446b0 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row != selectedIndex) {
        // Move the checkmark from the previously-selected row to the tapped one.
        [tableView cellForRowAtIndexPath:indexPath].accessoryType =
            UITableViewCellAccessoryCheckmark;
        NSIndexPath *previous = [NSIndexPath indexPathForRow:selectedIndex inSection:0];
        [tableView cellForRowAtIndexPath:previous].accessoryType = UITableViewCellAccessoryNone;
        selectedIndex = (int)indexPath.row;
        // Enable the commit button only when the selection now differs from the theme in effect.
        JubeatTheme currentTheme = [JubeatAppDelegate appDelegate].currentTheme;
        self.changeBarBtn.enabled = currentTheme != (JubeatTheme)selectedIndex;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x14488c */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x1448c4 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x1448fc */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x144934 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Rotation

/** @ghidraAddress 0x14496c */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait and portrait-upside-down (orientations 1 and 2), matching the mask of 6 below. The
    // binary tests (orientation - 1) as unsigned, so any other value (including 0) is refused.
    return (unsigned int)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x14497c */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return kSupportedOrientations;
}

/** @ghidraAddress 0x144984 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
