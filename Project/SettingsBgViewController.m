#import "SettingsBgViewController.h"

#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The navigation-bar title shown on the background-colour picker.
static NSString *const kTitle = @"BG COLOR";

// The user-defaults keys under which the picked colour index is persisted, one per theme: the
// REFLEC BEAT plus (ripples) theme uses the first, the Knit theme the second.
static NSString *const kColorRipplesKey = @"PrefColorRipples";
static NSString *const kColorKnitKey = @"PrefColorKnit";

// The reuse identifier the colour cells are dequeued and created under.
static NSString *const kCellIdentifier = @"SettingsBgTableCell";

// The typeface used for the row labels.
static NSString *const kLabelFontName = @"Helvetica-Bold";

// The format that builds each row's background pattern image name from the row index, one per
// theme: the ripples theme uses the plain form, the Knit theme the "_knt" variant.
static NSString *const kRipplesImageNameFormat = @"bgcolor_back_%d";
static NSString *const kKnitImageNameFormat = @"bgcolor_back_%d_knt";

// The pointer-indexed C-string tables backing +ripplesColorName: and +knitColorName:. The two
// tables draw from the same string pool and differ only in that indices 0 and 1 are swapped: the
// ripples theme leads with green, the Knit theme with blue.
static const char *const kRipplesColorCStrings[] = {"green", "blue", "lemon", "dark"};
static const char *const kKnitColorCStrings[] = {"blue", "green", "lemon", "dark"};

// The table has one section holding the four colour rows.
static const NSInteger kSectionCount = 1;
static const NSInteger kColorRowCount = 4;

// The fixed row height, read from the pooled double at 0x28f758. @ghidraAddress 0x28f758
static const CGFloat kRowHeight = 42.0;

// The point size of the row labels. The value reaches the code as an fmov immediate at 0x1528d8.
static const CGFloat kLabelFontSize = 24.0;

// The white component and alpha applied to an unselected row's label. The white component reaches
// the code as an fmov immediate at 0x152ad0; the alpha is a pooled double.
static const CGFloat kUnselectedLabelWhite = 1.0;
static const CGFloat kUnselectedLabelAlpha = 0.4; // @ghidraAddress 0x28f2c0

// The raw supported-orientation mask the binary returns: 6, i.e. portrait and portrait-upside-down
// (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown). Kept as the
// literal the binary uses rather than a named mask, since it is not one of the common combinations.
static const UIInterfaceOrientationMask kSupportedOrientations =
    UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;

@interface SettingsBgViewController () {
    NSUInteger selectedIndex; // The row (and colour index) currently checked.
}
@end

@implementation SettingsBgViewController

#pragma mark - Colour-name mapping

/** @ghidraAddress 0x1524b0 */
+ (NSString *)ripplesColorName:(NSUInteger)index {
    if (index < kColorRowCount) {
        return [NSString stringWithUTF8String:kRipplesColorCStrings[index]];
    }
    return @"";
}

/** @ghidraAddress 0x152520 */
+ (NSString *)knitColorName:(NSUInteger)index {
    if (index < kColorRowCount) {
        return [NSString stringWithUTF8String:kKnitColorCStrings[index]];
    }
    return @"";
}

#pragma mark - Construction

/** @ghidraAddress 0x152590 */
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (!self) {
        return self;
    }
    self.navigationItem.title = kTitle;
    // Seed the selection from the ripples key by default; the Knit theme overrides it below.
    selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:kColorRipplesKey];
    if (selectedIndex > kColorRowCount - 1) {
        selectedIndex = 0;
    }
    if ([JubeatAppDelegate appDelegate].currentTheme == JubeatThemeKnit) {
        selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:kColorKnitKey];
        if (selectedIndex > kColorRowCount - 1) {
            selectedIndex = 0;
        }
    }
    return self;
}

#pragma mark - View construction

/** @ghidraAddress 0x152710 */
- (void)loadView {
    [super loadView];
    self.tableView.rowHeight = kRowHeight;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

#pragma mark - Table view data source

/** @ghidraAddress 0x1527c8 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kSectionCount;
}

/** @ghidraAddress 0x1527d0 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return kColorRowCount;
}

/** @ghidraAddress 0x1527d8 */
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
    cell.textLabel.font = [UIFont fontWithName:kLabelFontName size:kLabelFontSize];
    // The row's label text is the colour name for the theme in effect. The Original theme leaves
    // the label untouched, showing the row with no name.
    JubeatTheme theme = [JubeatAppDelegate appDelegate].currentTheme;
    if (theme == JubeatThemeReflecBeatPlus) {
        cell.textLabel.text = [SettingsBgViewController ripplesColorName:(NSUInteger)indexPath.row];
    } else if (theme == JubeatThemeKnit) {
        cell.textLabel.text = [SettingsBgViewController knitColorName:(NSUInteger)indexPath.row];
    }
    if ((NSUInteger)indexPath.row == selectedIndex) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.textLabel.textColor = UIColor.whiteColor;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textColor = [UIColor colorWithWhite:kUnselectedLabelWhite
                                                     alpha:kUnselectedLabelAlpha];
    }
    return cell;
}

#pragma mark - Table view delegate

/** @ghidraAddress 0x152b34 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Give the row a full-cell background patterned with the theme's colour swatch image. The
    // Original theme has no swatch image, so it returns without touching the background.
    JubeatTheme theme = [JubeatAppDelegate appDelegate].currentTheme;
    NSString *imageName;
    if (theme == JubeatThemeKnit) {
        imageName = [NSString stringWithFormat:kKnitImageNameFormat, (int)indexPath.row];
    } else if (theme == JubeatThemeReflecBeatPlus) {
        imageName = [NSString stringWithFormat:kRipplesImageNameFormat, (int)indexPath.row];
    } else {
        return;
    }
    if (!imageName) {
        return;
    }
    UIImage *image = LoadScaledPngImage(imageName);
    UIColor *patternColor = [[UIColor alloc] initWithPatternImage:image];
    if (patternColor) {
        cell.backgroundColor = patternColor;
        cell.textLabel.backgroundColor = UIColor.clearColor;
    }
}

/** @ghidraAddress 0x152d30 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ((NSUInteger)indexPath.row != selectedIndex) {
        // Move the checkmark and the highlighted label colour to the tapped row.
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.textLabel.textColor = UIColor.whiteColor;
        NSIndexPath *previous = [NSIndexPath indexPathForRow:selectedIndex inSection:0];
        UITableViewCell *previousCell = [tableView cellForRowAtIndexPath:previous];
        previousCell.accessoryType = UITableViewCellAccessoryNone;
        previousCell.textLabel.textColor = [UIColor colorWithWhite:kUnselectedLabelWhite
                                                             alpha:kUnselectedLabelAlpha];
        selectedIndex = indexPath.row;
        // Persist the choice under the theme's own key. The Original theme persists nothing.
        JubeatTheme theme = [JubeatAppDelegate appDelegate].currentTheme;
        if (theme == JubeatThemeKnit) {
            [[NSUserDefaults standardUserDefaults] setInteger:selectedIndex forKey:kColorKnitKey];
        } else if (theme == JubeatThemeReflecBeatPlus) {
            [[NSUserDefaults standardUserDefaults] setInteger:selectedIndex
                                                       forKey:kColorRipplesKey];
        }
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x153038 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x153070 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x1530a8 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/** @ghidraAddress 0x15311c */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Rotation

/** @ghidraAddress 0x153154 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait and portrait-upside-down (orientations 1 and 2), matching the mask of 6 below. The
    // binary tests (orientation - 1) as unsigned, so any other value (including 0) is refused.
    return (unsigned long long)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x153164 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return kSupportedOrientations;
}

/** @ghidraAddress 0x15316c */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
