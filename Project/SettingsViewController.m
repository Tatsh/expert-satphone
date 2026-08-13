#import "SettingsViewController.h"

#import <objc/runtime.h>

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "BFCodec.h"
#import "EditDataManager.h"
#import "ImageCache.h"
#import "JubeatAppDelegate.h"
#import "NotificationPageViewController.h"
#import "SettingsBgViewController.h"
#import "SettingsButtonAreaViewController.h"
#import "SettingsCreditsViewController.h"
#import "SettingsEditorPageViewController.h"
#import "SettingsHowtoViewController.h"
#import "SettingsMapViewController.h"
#import "SettingsRatingChipViewController.h"
#import "SettingsRecommendViewController.h"
#import "SettingsThemeViewController.h"
#import "SettingsTimingAdjustViewController.h"
#import "SettingsTwSelectViewController.h"
#import "StoreUtil.h"
#import "TermsViewController.h"
#import "cipher_keys.h"
#import "neDebugLog.h"
#import "neUIProbe.h"

// The row-type numbers stored in menuTable. menuTable groups these into sections; menuTypeTable
// stores, per type, the UITableViewCellStyle its cell is built with. The separator types are never
// added to a section — they only flush the accumulated rows into a new section.
enum {
    SettingsMenuTypeTheme = 0,
    SettingsMenuTypeBackgroundColor = 1,
    SettingsMenuTypeShowCombos = 2,
    SettingsMenuTypeRatingChip = 3,
    SettingsMenuTypeTwitter = 4,
    SettingsMenuTypeAdjustTapTiming = 5,
    SettingsMenuTypeAdjustTouchArea = 6,
    SettingsMenuTypeSeparator1 = 7,
    SettingsMenuTypeFindArcade = 8,
    SettingsMenuTypeSeparator2 = 9,
    SettingsMenuTypeTerms = 10,
    SettingsMenuTypeSeparator3 = 11,
    SettingsMenuTypeJubeatLab = 12,
    SettingsMenuTypeDeleteCustomSequence = 13,
    SettingsMenuTypeSeparator4 = 14,
    SettingsMenuTypeHowToPlay = 15,
    SettingsMenuTypeCredits = 16,
    SettingsMenuTypeNotifications = 17,
    SettingsMenuTypeRecommendedApps = 18,
    SettingsMenuTypeSeparator5 = 19,
    SettingsMenuTypeCount = 20,
};

// The tag and confirm-button index the delete-custom-sequence alert reports back to -alertSelect:.
enum {
    SettingsDeleteAlertTag = 0,
    SettingsDeleteAlertConfirmButton = 1,
};

// NSUTF8StringEncoding, as encoded in the binary.
static const NSUInteger kSettingsUTF8Encoding = 4;

static NSString *const kSettingsLabURLKey = @"PrefjubeatLabURL";
static NSString *const kSettingsShowComboKey = @"PrefShowCombo";
static NSString *const kSettingsColorRipplesKey = @"PrefColorRipples";
static NSString *const kSettingsColorKnitKey = @"PrefColorKnit";
static NSString *const kSettingsRatingChipTypeKey = @"PrefRatingChipType";
static NSString *const kSettingsInfoListURLKey = @"PrefInfoListURL";
static NSString *const kSettingsCellReuseFormat = @"SettingsTableCell%d";

@interface SettingsViewController () {
    BOOL bEnableMyPage;
    NSArray<NSArray<NSNumber *> *> *menuTable;
    NSArray<NSNumber *> *menuTypeTable;
}
@end

@implementation SettingsViewController

#pragma mark - Menu construction

/** @ghidraAddress 0xe4dbc */
- (void)createMenuTable {
    NSMutableArray<NSArray<NSNumber *> *> *sections = [[NSMutableArray alloc] init];
    JubeatTheme theme = JubeatAppDelegate.appDelegate.currentTheme;
    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    NSMutableArray<NSNumber *> *sectionRows = [[NSMutableArray alloc] init];
    NSMutableArray<NSNumber *> *cellStyles = [[NSMutableArray alloc] init];
    for (int type = 0; type < SettingsMenuTypeCount; ++type) {
        NSNumber *typeNumber = @(type);
        // Types 0, 1, and 3 present a right-aligned detail value; every other row is plain.
        UITableViewCellStyle style = UITableViewCellStyleValue1;
        if (isPad) {
            switch (type) {
            case SettingsMenuTypeTheme:
                [sectionRows addObject:typeNumber];
                break;
            case SettingsMenuTypeBackgroundColor:
                if (theme != JubeatThemeOriginal) {
                    [sectionRows addObject:typeNumber];
                }
                break;
            case SettingsMenuTypeRatingChip:
                [sectionRows addObject:typeNumber];
                break;
            case SettingsMenuTypeSeparator1:
            case SettingsMenuTypeSeparator2:
            case SettingsMenuTypeSeparator3:
            case SettingsMenuTypeSeparator4:
            case SettingsMenuTypeSeparator5:
                if (sectionRows.count != 0) {
                    [sections addObject:[NSArray arrayWithArray:sectionRows]];
                    [sectionRows removeAllObjects];
                }
                style = UITableViewCellStyleDefault;
                break;
            case SettingsMenuTypeAdjustTouchArea:
            case SettingsMenuTypeCredits:
                // Neither the touch-area nor the credits row is shown on the pad.
                style = UITableViewCellStyleDefault;
                break;
            case SettingsMenuTypeJubeatLab:
                if (bEnableMyPage) {
                    [sectionRows addObject:typeNumber];
                }
                style = UITableViewCellStyleDefault;
                break;
            default:
                [sectionRows addObject:typeNumber];
                style = UITableViewCellStyleDefault;
                break;
            }
        } else {
            switch (type) {
            case SettingsMenuTypeTheme:
                [sectionRows addObject:typeNumber];
                break;
            case SettingsMenuTypeBackgroundColor:
                if (theme != JubeatThemeOriginal) {
                    [sectionRows addObject:typeNumber];
                }
                break;
            case SettingsMenuTypeRatingChip:
                [sectionRows addObject:typeNumber];
                break;
            case SettingsMenuTypeSeparator1:
            case SettingsMenuTypeSeparator2:
            case SettingsMenuTypeSeparator3:
            case SettingsMenuTypeSeparator4:
            case SettingsMenuTypeSeparator5:
                if (sectionRows.count != 0) {
                    [sections addObject:[NSArray arrayWithArray:sectionRows]];
                    [sectionRows removeAllObjects];
                }
                style = UITableViewCellStyleDefault;
                break;
            case SettingsMenuTypeAdjustTouchArea:
                [sectionRows addObject:typeNumber];
                style = UITableViewCellStyleDefault;
                break;
            case SettingsMenuTypeJubeatLab:
            case SettingsMenuTypeCredits:
                // The phone shows neither the jubeat Lab nor the credits row.
                style = UITableViewCellStyleDefault;
                break;
            default:
                [sectionRows addObject:typeNumber];
                style = UITableViewCellStyleDefault;
                break;
            }
        }
        [cellStyles addObject:@(style)];
    }
    // The final separator (type 19) has already flushed the last section, so there is no trailing
    // flush here.
    menuTable = [NSArray arrayWithArray:sections];
    menuTypeTable = [NSArray arrayWithArray:cellStyles];
}

#pragma mark - Lifecycle

/** @ghidraAddress 0xe52b8 */
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        self.navigationItem.title = @"SETTINGS";
        bEnableMyPage = YES;
        NSData *stored = [NSUserDefaults.standardUserDefaults objectForKey:kSettingsLabURLKey];
        if (stored) {
            NSMutableData *data = [NSMutableData dataWithData:stored];
            BFCodec *codec = [[BFCodec alloc] init];
            [codec cipherInit:CreateLabUrlCipherKey()];
            [codec decipher:data];
            if (data) {
                NSString *url = [[NSString alloc] initWithData:data encoding:kSettingsUTF8Encoding];
                if (url) {
                    bEnableMyPage = NO;
                }
            }
        }
        [self createMenuTable];
    }
    return self;
}

/** @ghidraAddress 0xe5498 */
- (void)loadView {
    [super loadView];
    // The switch frame: its width is read from the pooled double; its height is an fmov immediate.
    CGFloat switchWidth = 94.0; // @ghidraAddress 0x28f420
    UISwitch *combo = [[UISwitch alloc] initWithFrame:CGRectMake(0.0, 0.0, switchWidth, 27.0)];
    self.switchCombo = combo;
    self.switchCombo.backgroundColor = UIColor.clearColor;
    [self.switchCombo addTarget:self
                         action:@selector(comboChanged:)
               forControlEvents:UIControlEventValueChanged];
    self.switchCombo.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                        UIViewAutoresizingFlexibleTopMargin |
                                        UIViewAutoresizingFlexibleBottomMargin;
    [self.switchCombo setOn:[NSUserDefaults.standardUserDefaults boolForKey:kSettingsShowComboKey]];
}

/** @ghidraAddress 0xe7268 */
- (void)viewDidLoad {
    [super viewDidLoad];
#ifndef ENABLE_PATCHES
    // The binary marks the sheet's navigation bar exclusive at 0xe7304 and every subview it had at
    // load time at 0xe73d8. The idiom dates from when a navigation bar's direct subviews were its
    // per-item button views, so it meant no two bar buttons could track a touch at once. Modern
    // UIKit gives the bar full-width private containers instead, and line 0xe7304 marks the bar
    // itself as well, so the whole bar becomes an exclusive-touch region of the window it shares
    // with the presenting screen. The controller is built once and -viewDidUnload is no longer
    // called, so the flag is set once and never re-evaluated. Every settings interaction that fails
    // is a navigation-bar tap -- the back button and the Close button -- while pushing into a
    // child, which is a table-row tap, always works.
    self.navigationController.navigationBar.exclusiveTouch = YES;
    for (UIView *subview in self.navigationController.navigationBar.subviews) {
        subview.exclusiveTouch = YES;
    }
#endif
}

/** @ghidraAddress 0xe7448 */
- (void)viewDidUnload {
    [super viewDidUnload];
    self.switchCombo = nil;
}

/** @ghidraAddress 0xe74a0 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (NE_DBG_EVERY) {
        // This method runs on the first presentation, on every pop back from a child, and on every
        // re-presentation, so its log line is the common point of all three reported failures.
        neDebugLog("settings willAppear: animated %d window %d selected %s",
                   (int)animated,
                   (int)(self.tableView.window != nil),
                   self.tableView.indexPathForSelectedRow ? "yes" : "no");
        neUIProbeLogController("settings willAppear", self);
        neUIProbeTraceTransition("settings appear", self);
    }
    NSIndexPath *selected = self.tableView.indexPathForSelectedRow;
    if (selected) {
        [self.tableView deselectRowAtIndexPath:selected animated:animated];
    }
    NSMutableArray<NSIndexPath *> *toReload = [[NSMutableArray alloc] init];
    NSIndexPath *bgPath = [self getTargetPath:SettingsMenuTypeBackgroundColor];
    if (bgPath) {
        [toReload addObject:bgPath];
    }
    NSIndexPath *recommendPath = [self getTargetPath:SettingsMenuTypeRecommendedApps];
    if (recommendPath) {
        [toReload addObject:recommendPath];
    }
    NSIndexPath *ratingPath = [self getTargetPath:SettingsMenuTypeRatingChip];
    if (ratingPath) {
        [toReload addObject:ratingPath];
    }
    if (toReload.count != 0) {
        // This reloads three rows and deliberately not a fourth. Show Combos is not among them, so
        // the one cell holding the shared switchCombo is never rebuilt here and the switch keeps
        // its single owner. A -reloadData in this place instead of this call recycles every
        // visible cell, which hands the switch's old cell to some other row while a fresh cell for
        // Show Combos is assigned the same switch -- two live cells owning one accessory view,
        // each re-parenting it away from the other for as long as the process runs. That was a
        // patch here for a while and it is what hung the sheet on every second appearance; see
        // PATCHES.md.
        [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithArray:toReload]
                              withRowAnimation:UITableViewRowAnimationNone];
    }
    if (NE_DBG_EVERY) {
        // Paired with the entry line above. Without it a capture cannot say whether the hang is
        // inside this method -- in the reload or the deselect -- or after it has returned, because
        // the navigation delegate's willShow can be called from within this call stack.
        neDebugLog("settings willAppear: done, reloaded %lu", (unsigned long)toReload.count);
    }
}

#if JBDBG
// Not in the binary. A hang that never returns to the run loop is either a deadlock or a spin, and
// a spin inside UIKit's layout pass is the most likely kind here. Counting layout passes separates
// them without a stack: a runaway layout drives this count up in bursts of hundreds, while a
// deadlock leaves it frozen at whatever it reached. Logging one line per kLayoutLogInterval keeps
// a genuine storm legible instead of drowning the capture in it.
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    static const unsigned int kLayoutLogInterval = 200;
    static unsigned int layoutPasses = 0;
    if ((++layoutPasses % kLayoutLogInterval) == 0) {
        neDebugLog("settings layout: pass %u", layoutPasses);
    }
}
#endif

/** @ghidraAddress 0xe7900 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (NE_DBG_EVERY) {
        neDebugLog("settings didAppear: animated %d window %d",
                   (int)animated,
                   (int)(self.tableView.window != nil));
        neUIProbeLogController("settings didAppear", self);
    }
}

/** @ghidraAddress 0xe7938 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (NE_DBG_EVERY) {
        neUIProbeLogController("settings willDisappear", self);
    }
}

/** @ghidraAddress 0xe7970 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (NE_DBG_EVERY) {
        neUIProbeLogController("settings didDisappear", self);
    }
}

/** @ghidraAddress 0xe7230 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0xe79c8 */
- (void)dealloc {
    // The binary's -dealloc only chains to UITableViewController, which ARC does automatically.
}

#pragma mark - Actions

/** @ghidraAddress 0xe668c */
- (void)comboChanged:(id)sender {
    [NSUserDefaults.standardUserDefaults setBool:self.switchCombo.isOn
                                          forKey:kSettingsShowComboKey];
}

/** @ghidraAddress 0xe6718 */
- (void)settingClose {
    if (NE_DBG_EVERY) {
        neDebugLog("settings settingClose: depth %lu window %d",
                   (unsigned long)self.navigationController.viewControllers.count,
                   (int)(self.tableView.window != nil));
    }
    [AlertViewManager.sharedManager closeAlert];
    [self.navigationController popToRootViewControllerAnimated:NO];
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0xe6618 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return menuTable.count;
}

/** @ghidraAddress 0xe6630 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return menuTable[section].count;
}

/** @ghidraAddress 0xe5678 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    int type = menuTable[indexPath.section][indexPath.row].intValue;
    UITableViewCellStyle style = (UITableViewCellStyle)menuTypeTable[type].intValue;
    NSString *reuseIdentifier = [NSString stringWithFormat:kSettingsCellReuseFormat, (int)style];
    JubeatTheme theme = JubeatAppDelegate.appDelegate.currentTheme;
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:reuseIdentifier];
    }
    if (NE_DBG_EVERY && type != SettingsMenuTypeShowCombos && cell.accessoryView != nil) {
        // A recycled cell arriving with an accessory view already attached is the whole fault in
        // one line: the only accessory view this table ever sets is the single shared switchCombo,
        // so two cells now own it and each will re-parent it away from the other for ever.
        neDebugLog("settings cell: type %d dequeued carrying accessoryView %s owned by %s",
                   type,
                   object_getClassName(cell.accessoryView),
                   cell.accessoryView.superview ?
                       object_getClassName(cell.accessoryView.superview) :
                       "nobody");
    }
#ifdef ENABLE_PATCHES
    // Preservation patch, not in the binary. Only one row ever sets an accessory view, and it sets
    // the same UISwitch instance every time, so a recycled cell handed to any other row keeps a
    // reference to a view that a second cell is about to claim. On the SDK this shipped against a
    // cell laid its accessory view out where it found it; modern UIKit re-parents it, so two cells
    // holding one accessory view invalidate each other's layout in turn and the layout pass never
    // converges -- an unbreakable main-thread spin inside the Core Animation commit. Clearing the
    // stale reference costs nothing and is what the binary's own -reloadRowsAtIndexPaths: achieved
    // implicitly by never rebuilding the switch's cell.
    if (type != SettingsMenuTypeShowCombos) {
        cell.accessoryView = nil;
    }
#endif
    switch (type) {
    case SettingsMenuTypeTheme:
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.text = [NSBundle.mainBundle localizedStringForKey:@"Theme"
                                                                   value:@""
                                                                   table:nil];
        if (theme == JubeatThemeRipples) {
            cell.detailTextLabel.text = @"ripples";
        } else if (theme == JubeatThemeKnit) {
            cell.detailTextLabel.text = @"knit";
        } else {
            cell.detailTextLabel.text = @"classic";
        }
        return cell;
    case SettingsMenuTypeBackgroundColor:
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.text = [NSBundle.mainBundle localizedStringForKey:@"Background Color"
                                                                   value:@""
                                                                   table:nil];
        if (theme == JubeatThemeKnit) {
            NSInteger index =
                [NSUserDefaults.standardUserDefaults integerForKey:kSettingsColorKnitKey];
            cell.detailTextLabel.text = [SettingsBgViewController knitColorName:index];
        } else if (theme == JubeatThemeRipples) {
            NSInteger index =
                [NSUserDefaults.standardUserDefaults integerForKey:kSettingsColorRipplesKey];
            cell.detailTextLabel.text = [SettingsBgViewController ripplesColorName:index];
        }
        // The original theme has no background-colour detail and leaves the cell as-is.
        return cell;
    case SettingsMenuTypeShowCombos:
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = [NSBundle.mainBundle localizedStringForKey:@"Show Combos"
                                                                   value:@""
                                                                   table:nil];
        cell.accessoryView = self.switchCombo;
        return cell;
    case SettingsMenuTypeRatingChip: {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.text = [NSBundle.mainBundle localizedStringForKey:@"Rating Chip"
                                                                   value:@""
                                                                   table:nil];
        NSInteger index =
            [NSUserDefaults.standardUserDefaults integerForKey:kSettingsRatingChipTypeKey];
        cell.detailTextLabel.text = [SettingsRatingChipViewController ratingChipType:index];
        return cell;
    }
    case SettingsMenuTypeTwitter:
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.text = [NSBundle.mainBundle localizedStringForKey:@"Twitter"
                                                                   value:@""
                                                                   table:nil];
        return cell;
    case SettingsMenuTypeAdjustTapTiming:
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.text = [NSBundle.mainBundle localizedStringForKey:@"Adjust Tap Timing"
                                                                   value:@""
                                                                   table:nil];
        return cell;
    case SettingsMenuTypeAdjustTouchArea:
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.text = [NSBundle.mainBundle localizedStringForKey:@"Adjust Touch Area"
                                                                   value:@""
                                                                   table:nil];
        return cell;
    case SettingsMenuTypeFindArcade:
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        if (JubeatAppDelegate.appDelegate.isPad) {
            cell.textLabel.text = @"jubeat 設置店舗を探す";
        } else {
            cell.textLabel.text = @"jubeat を探す";
        }
        cell.imageView.image = [ImageCache.sharedCache getResPNG:@"ac_map"];
        return cell;
    case SettingsMenuTypeTerms:
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.text = @"各種規約について";
        return cell;
    case SettingsMenuTypeJubeatLab:
        cell.textLabel.text = @"jubeat Lab.";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        return cell;
    case SettingsMenuTypeDeleteCustomSequence:
        cell.textLabel.text = @"持っていない曲のカスタム譜面を削除する";
        if (!JubeatAppDelegate.appDelegate.isPad) {
            cell.textLabel.text = @"持っていない曲の譜面を削除する";
        }
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        return cell;
    case SettingsMenuTypeHowToPlay:
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.backgroundColor = UIColor.whiteColor;
        cell.textLabel.text = @"HOW TO PLAY";
        return cell;
    case SettingsMenuTypeCredits:
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.backgroundColor = UIColor.whiteColor;
        cell.textLabel.text = @"CREDITS";
        return cell;
    case SettingsMenuTypeNotifications:
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.backgroundColor = UIColor.whiteColor;
        cell.textLabel.text = @"過去のお知らせ";
        return cell;
    case SettingsMenuTypeRecommendedApps: {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.backgroundColor = UIColor.whiteColor;
        // The recommend row is tinted; the tint component is read from the pool.
        CGFloat tint = 0.2; // @ghidraAddress 0x28f240
        cell.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:tint alpha:tint];
        cell.textLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:16.0];
        cell.textLabel.text = @"イチオシアプリ";
        if (JubeatAppDelegate.appDelegate.hasNewRecommendNum >= 1) {
            cell.backgroundColor = [UIColor colorWithRed:1.0 green:tint blue:tint alpha:tint];
        }
        return cell;
    }
    default:
        return cell;
    }
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0xe67a0 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    int type = menuTable[indexPath.section][indexPath.row].intValue;
    if (NE_DBG_EVERY) {
        neDebugLog("settings didSelectRow: type %d section %ld row %ld depth %lu",
                   type,
                   (long)indexPath.section,
                   (long)indexPath.row,
                   (unsigned long)self.navigationController.viewControllers.count);
    }
    switch (type) {
    case SettingsMenuTypeTheme:
        if (self.navigationController) {
            SettingsThemeViewController *vc =
                [[SettingsThemeViewController alloc] initWithStyle:UITableViewStyleGrouped];
            [self.navigationController pushViewController:vc animated:YES];
        }
        break;
    case SettingsMenuTypeBackgroundColor:
        if (self.navigationController) {
            SettingsBgViewController *vc =
                [[SettingsBgViewController alloc] initWithStyle:UITableViewStyleGrouped];
            [self.navigationController pushViewController:vc animated:YES];
        }
        break;
    case SettingsMenuTypeRatingChip:
        if (self.navigationController) {
            SettingsRatingChipViewController *vc =
                [[SettingsRatingChipViewController alloc] initWithStyle:UITableViewStyleGrouped];
            vc.settingsDelegate = self.settingsDelegate;
            [self.navigationController pushViewController:vc animated:YES];
        }
        break;
    case SettingsMenuTypeTwitter:
        if (self.navigationController) {
            SettingsTwSelectViewController *vc = [[SettingsTwSelectViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        }
        break;
    case SettingsMenuTypeAdjustTapTiming:
        if (self.navigationController) {
            SettingsTimingAdjustViewController *vc =
                [[SettingsTimingAdjustViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        }
        break;
    case SettingsMenuTypeAdjustTouchArea:
        if (self.navigationController) {
            SettingsButtonAreaViewController *vc = [[SettingsButtonAreaViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        }
        break;
    case SettingsMenuTypeFindArcade:
        if (self.navigationController) {
            SettingsMapViewController *vc = [[SettingsMapViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        }
        break;
    case SettingsMenuTypeTerms:
        if (self.navigationController) {
            TermsViewController *vc =
                [[TermsViewController alloc] initWithStyle:UITableViewStyleGrouped];
            [self.navigationController pushViewController:vc animated:YES];
        }
        break;
    case SettingsMenuTypeJubeatLab:
        if (self.navigationController) {
            SettingsEditorPageViewController *vc = [[SettingsEditorPageViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        }
        break;
    case SettingsMenuTypeDeleteCustomSequence: {
        if (indexPath) {
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
        AlertViewManager *manager = AlertViewManager.sharedManager;
        NSString *cancel = [NSBundle.mainBundle localizedStringForKey:@"Cancel"
                                                                value:@""
                                                                table:nil];
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
        NSArray<NSString *> *otherButtons = @[ ok ];
        // Alert type 0 is a plain (no text field) alert.
        [manager makeAlert:0
                  delegate:self
                       tag:SettingsDeleteAlertTag
                     title:nil
                       msg:@"持っていない曲のカスタム譜面を全て削除します。\nよろしいですか？"
                    cancel:cancel
                   btnText:otherButtons
                      show:YES
            viewController:self];
        break;
    }
    case SettingsMenuTypeHowToPlay:
        if (self.navigationController) {
            SettingsHowtoViewController *vc = [[SettingsHowtoViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        }
        break;
    case SettingsMenuTypeCredits:
        if (self.navigationController) {
            SettingsCreditsViewController *vc = [[SettingsCreditsViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        }
        break;
    case SettingsMenuTypeNotifications: {
        if (self.navigationController) {
            NSURL *url = nil;
            NSData *stored =
                [NSUserDefaults.standardUserDefaults objectForKey:kSettingsInfoListURLKey];
            if (stored) {
                NSMutableData *data = [NSMutableData dataWithData:stored];
                BFCodec *codec = [[BFCodec alloc] init];
                [codec cipherInit:CreateLabUrlCipherKey()];
                [codec decipher:data];
                if (data) {
                    NSString *string = [[NSString alloc] initWithData:data
                                                             encoding:kSettingsUTF8Encoding];
                    url = [NSURL URLWithString:string];
                }
            }
            if (!url) {
                url = [StoreUtil passedInfoListURL];
            }
            NotificationPageViewController *vc =
                [[NotificationPageViewController alloc] initWithURL:url
                                                           delegate:self.settingsDelegate];
            [self.navigationController pushViewController:vc animated:YES];
        }
        break;
    }
    case SettingsMenuTypeRecommendedApps:
        if (self.navigationController) {
            SettingsRecommendViewController *vc = [[SettingsRecommendViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        }
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        break;
    default:
        break;
    }
}

#pragma mark - Target-path lookup

/** @ghidraAddress 0xe76e0 */
- (NSIndexPath *)getTargetPath:(int)type inSection:(int)section {
    NSArray<NSNumber *> *rows = menuTable[section];
    NSInteger row = 0;
    for (NSNumber *rowType in rows) {
        if (rowType.intValue == type) {
            return [NSIndexPath indexPathForRow:row inSection:section];
        }
        ++row;
    }
    return nil;
}

/** @ghidraAddress 0xe786c */
- (NSIndexPath *)getTargetPath:(int)type {
    NSInteger sectionCount = menuTable.count;
    for (int section = 0; section < sectionCount; ++section) {
        NSIndexPath *path = [self getTargetPath:type inSection:section];
        if (path) {
            return path;
        }
    }
    return nil;
}

#pragma mark - AlertViewManager delegate

/** @ghidraAddress 0xe7a00 */
- (void)alertSelect:(NSDictionary *)info {
    int button = [info[@"btnMessage"] intValue];
    int tag = [info[@"Tag"] intValue];
    if (button != SettingsDeleteAlertConfirmButton || tag != SettingsDeleteAlertTag) {
        return;
    }
    [self deleteCustomSequence];
}

/** @ghidraAddress 0xe7af8 */
- (void)deleteCustomSequence {
    EditDataManager *manager = EditDataManager.sharedManager;
    NSMutableArray *directories =
        [[NSMutableArray alloc] initWithArray:[manager getCustomSequenceDirectoryList]];
    NSArray *musicIDs = [manager getMusicIDList];
    for (id musicID in musicIDs) {
        [directories removeObject:musicID];
    }
    for (id directory in directories) {
        if (directory) {
            [manager deleteCustomSequenceDirectory:directory];
        }
    }
}

#pragma mark - Rotation

/** @ghidraAddress 0xe79a8 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation == UIInterfaceOrientationPortrait ||
           interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown;
}

/** @ghidraAddress 0xe79b8 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0xe79c0 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
