#import "SettingsRatingChipViewController.h"

#import "JubeatAppDelegate.h"

// The navigation-bar title shown on the rating-chip picker.
static NSString *const kTitle = @"RATING CHIP";

// The user-defaults key under which the picked rating-chip type is persisted.
static NSString *const kRatingChipTypeKey = @"PrefRatingChipType";

// The reuse identifier the rating-chip cells are dequeued and created under.
static NSString *const kCellIdentifier = @"SettingsRatingChipTableCell";

// The style names shown per row, indexed by the rating-chip type value: 0 none, 1 played, 2 all.
static NSString *const kChipNameNone = @"none";
static NSString *const kChipNamePlayed = @"played";
static NSString *const kChipNameAll = @"all";

// The typeface and point size used for the row labels.
static NSString *const kLabelFontName = @"Helvetica-Bold";

// The format that builds each row's background pattern image name, and the phone-only suffix. On
// the pad the suffix is empty; on the phone it selects the "_pn2" variant.
static NSString *const kImageNameFormat = @"rating_chip_%@%@";
static NSString *const kPhoneImageSuffix = @"_pn2";
static NSString *const kPadImageSuffix = @"";

// The image type looked up in the main bundle for the row backgrounds.
static NSString *const kImageType = @"png";

// The pointer-indexed C-string table backing +ratingChipType:, matching the style names above.
static const char *const kChipTypeCStrings[] = {"none", "played", "all"};

// The table has one section holding the three rating-chip rows.
static const NSInteger kSectionCount = 1;
static const NSInteger kChipRowCount = 3;

// The fixed row heights per idiom, read from the pooled doubles noted below.
static const CGFloat kRowHeightPad = 120.0;  // @ghidraAddress 0x28f210
static const CGFloat kRowHeightPhone = 60.0; // @ghidraAddress 0x28f258

// The point size of the row labels. The value reaches the code as an fmov immediate at 0x96a30.
static const CGFloat kLabelFontSize = 24.0;

// The scale applied to the phone's pattern image so its non-retina asset renders at native size.
// The value reaches the code as an fmov immediate at 0x96e2c.
static const CGFloat kPhoneImageScale = 2.0;

// The white component and alpha applied to an unselected row's label. The white component reaches
// the code as an fmov immediate at 0x96b84; the alpha is a pooled double.
static const CGFloat kUnselectedLabelWhite = 1.0;
static const CGFloat kUnselectedLabelAlpha = 0.4; // @ghidraAddress 0x28f2c0

// The raw supported-orientation mask the binary returns: 6, i.e. portrait and portrait-upside-down
// (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown). Kept as the
// literal the binary uses rather than a named mask, since it is not one of the common combinations.
static const UIInterfaceOrientationMask kSupportedOrientations =
    UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;

@interface SettingsRatingChipViewController () {
    NSUInteger selectedIndex; // The row (and rating-chip type) currently checked.
}
@end

@implementation SettingsRatingChipViewController

#pragma mark - Rating-chip type mapping

/** @ghidraAddress 0x966cc */
+ (NSString *)ratingChipType:(NSUInteger)type {
    if (type < kChipRowCount) {
        return [NSString stringWithUTF8String:kChipTypeCStrings[type]];
    }
    return @"";
}

#pragma mark - Construction

/** @ghidraAddress 0x9673c */
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (!self) {
        return self;
    }
    self.navigationItem.title = kTitle;
    selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:kRatingChipTypeKey];
    if (selectedIndex > kChipRowCount - 1) {
        selectedIndex = 0;
    }
    return self;
}

#pragma mark - View construction

/** @ghidraAddress 0x96820 */
- (void)loadView {
    [super loadView];
    self.tableView.rowHeight =
        [JubeatAppDelegate appDelegate].isPad ? kRowHeightPad : kRowHeightPhone;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

#pragma mark - Table view data source

/** @ghidraAddress 0x96920 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kSectionCount;
}

/** @ghidraAddress 0x96928 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return kChipRowCount;
}

/** @ghidraAddress 0x96930 */
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
    cell.textLabel.text =
        [SettingsRatingChipViewController ratingChipType:(NSUInteger)indexPath.row];
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

/** @ghidraAddress 0x96be8 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSString *> *names = @[ kChipNameNone, kChipNamePlayed, kChipNameAll ];
    NSString *name = names[indexPath.row];
    NSString *suffix = [JubeatAppDelegate appDelegate].isPad ? kPadImageSuffix : kPhoneImageSuffix;
    NSString *imageName = [NSString stringWithFormat:kImageNameFormat, name, suffix];
    if (!imageName) {
        return;
    }
    NSString *path = [[NSBundle mainBundle] pathForResource:imageName ofType:kImageType];
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:path];
    if (image && ![JubeatAppDelegate appDelegate].isPad) {
        // The phone loads a non-retina asset; re-wrap it at scale 2 so it draws at native size.
        image = [UIImage imageWithCGImage:image.CGImage
                                    scale:kPhoneImageScale
                              orientation:UIImageOrientationUp];
    }
    UIColor *patternColor = [[UIColor alloc] initWithPatternImage:image];
    if (patternColor) {
        cell.backgroundColor = patternColor;
        cell.textLabel.backgroundColor = UIColor.clearColor;
    }
}

/** @ghidraAddress 0x96f54 */
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
        [[NSUserDefaults standardUserDefaults] setInteger:selectedIndex forKey:kRatingChipTypeKey];
        if ([self.settingsDelegate respondsToSelector:@selector(refreshRatingChip)]) {
            [self.settingsDelegate performSelector:@selector(refreshRatingChip)];
        }
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x97248 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x97280 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x972b8 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/** @ghidraAddress 0x9732c */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Rotation

/** @ghidraAddress 0x97364 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait and portrait-upside-down (orientations 1 and 2), matching the mask of 6 below. The
    // binary tests (orientation - 1) as unsigned, so any other value (including 0) is refused.
    return (unsigned long long)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x97374 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return kSupportedOrientations;
}

/** @ghidraAddress 0x9737c */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
