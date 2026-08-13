#import "TermsViewController.h"

#import "SettingsInquiryViewController.h"
#import "SettingsPolicyViewController.h"

// The navigation title shown above the menu table.
static NSString *const kNavigationTitle = @"各種規約について";

// The per-row cell titles (Japanese in the shipped binary), indexed by the row's menu value.
// @ghidraAddress 0x2c13ee (content), 0x2c141c (currency), 0x2c0572 (payment services),
// @ghidraAddress 0x2c1432 (minors), 0x2c1440 (specified commercial transactions), 0x2c111e
// (inquiry)
static NSString *const kTitleContent = @"「jubeat plus」コンテンツ利用規約";
static NSString *const kTitleCurrency = @"ゲーム内通貨利用規約";
static NSString *const kTitlePaymentServices = @"資金決済法について";
static NSString *const kTitleMinors = @"未成年の方へ";
static NSString *const kTitleSpecifiedCommercial = @"特定商取引法に基づく表示";
static NSString *const kTitleInquiry = @"お問い合わせ";

// The reuse-identifier format; the row's menu value is substituted for the specifier.
static NSString *const kCellIdentifierFormat = @"SettingsTableCell%d";

// The specified-commercial-transactions notice is opened in the system browser.
static NSString *const kSpecifiedCommercialURL =
    @"https://license.konami.com/TOKUSHO/license/index.html";

// The number of menu rows built into the single section.
static const int kMenuRowCount = 6;

// The menu values whose selection opens a legal document, mapped to the SettingsPolicyType the
// SettingsPolicyViewController is constructed with.
typedef enum {
    TermsMenuValueContent = 0,             // Opens SettingsPolicyTypeContent (1).
    TermsMenuValueCurrency = 1,            // Opens SettingsPolicyTypeCurrency (2).
    TermsMenuValuePaymentServices = 2,     // Opens SettingsPolicyTypePaymentServices (4).
    TermsMenuValueMinors = 3,              // Opens SettingsPolicyTypeMinors (8).
    TermsMenuValueSpecifiedCommercial = 4, // Opens the specified-commercial notice in the browser.
    TermsMenuValueInquiry = 5,             // Opens SettingsInquiryViewController.
} TermsMenuValue;

@interface TermsViewController () {
    NSArray *menuTable;     // +0x8
    NSArray *menuTypeTable; // +0x10
}
@end

@implementation TermsViewController

#pragma mark - Construction

/** @ghidraAddress 0x113094 */
- (void)createMenuTable {
    NSMutableArray *sections = [[NSMutableArray alloc] init];
    NSMutableArray *rows = [[NSMutableArray alloc] init];
    NSMutableArray *types = [[NSMutableArray alloc] init];
    for (int i = 0; i != kMenuRowCount; ++i) {
        [rows addObject:@(i)];
        [types addObject:@0];
    }
    if (rows.count != 0) {
        [sections addObject:[NSArray arrayWithArray:rows]];
        [rows removeAllObjects];
    }
    menuTable = [NSArray arrayWithArray:sections];
    menuTypeTable = [NSArray arrayWithArray:types];
}

/** @ghidraAddress 0x1132a0 */
- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        self.navigationItem.title = kNavigationTitle;
        [self createMenuTable];
    }
    return self;
}

#pragma mark - Table view data source

/** @ghidraAddress 0x11336c */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    int menuValue = [menuTable[indexPath.section][indexPath.row] intValue];
    UITableViewCellStyle cellStyle = (UITableViewCellStyle)[menuTypeTable[menuValue] intValue];
    NSString *identifier = [NSString stringWithFormat:kCellIdentifierFormat, menuValue];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:cellStyle reuseIdentifier:identifier];
    }
    // Each arm sets the same disclosure accessory and default selection style, differing only in
    // the row's title.
    switch (menuValue) {
    case TermsMenuValueContent:
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.text = kTitleContent;
        break;
    case TermsMenuValueCurrency:
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.text = kTitleCurrency;
        break;
    case TermsMenuValuePaymentServices:
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.text = kTitlePaymentServices;
        break;
    case TermsMenuValueMinors:
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.text = kTitleMinors;
        break;
    case TermsMenuValueSpecifiedCommercial:
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.text = kTitleSpecifiedCommercial;
        break;
    case TermsMenuValueInquiry:
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.text = kTitleInquiry;
        break;
    default:
        break;
    }
    return cell;
}

/** @ghidraAddress 0x11379c */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return menuTable.count;
}

/** @ghidraAddress 0x1137b4 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [menuTable[section] count];
}

#pragma mark - Table view delegate

/** @ghidraAddress 0x113810 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    int menuValue = [menuTable[indexPath.section][indexPath.row] intValue];
    switch (menuValue) {
    case TermsMenuValueContent: {
        // Content, currency, and payment-services guard on the navigation controller being present.
        if (!self.navigationController) {
            return;
        }
        SettingsPolicyViewController *controller =
            [[SettingsPolicyViewController alloc] initViewController:SettingsPolicyTypeContent];
        [self.navigationController pushViewController:controller animated:YES];
        break;
    }
    case TermsMenuValueCurrency: {
        if (!self.navigationController) {
            return;
        }
        SettingsPolicyViewController *controller =
            [[SettingsPolicyViewController alloc] initViewController:SettingsPolicyTypeCurrency];
        [self.navigationController pushViewController:controller animated:YES];
        break;
    }
    case TermsMenuValuePaymentServices: {
        if (!self.navigationController) {
            return;
        }
        SettingsPolicyViewController *controller = [[SettingsPolicyViewController alloc]
            initViewController:SettingsPolicyTypePaymentServices];
        [self.navigationController pushViewController:controller animated:YES];
        break;
    }
    case TermsMenuValueMinors: {
        // The minors arm does not guard on the navigation controller, unlike the three above.
        SettingsPolicyViewController *controller =
            [[SettingsPolicyViewController alloc] initViewController:SettingsPolicyTypeMinors];
        [self.navigationController pushViewController:controller animated:YES];
        break;
    }
    case TermsMenuValueSpecifiedCommercial: {
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:kSpecifiedCommercialURL]];
        break;
    }
    case TermsMenuValueInquiry: {
        // The inquiry arm, like the minors arm, does not guard on the navigation controller.
        SettingsInquiryViewController *controller = [[SettingsInquiryViewController alloc] init];
        [self.navigationController pushViewController:controller animated:YES];
        break;
    }
    default:
        break;
    }
}

#pragma mark - Index path mapping

/** @ghidraAddress 0x113ed0 */
- (NSIndexPath *)getTargetPath:(int)targetPath inSection:(int)section {
    int row = 0;
    for (NSNumber *value in menuTable[section]) {
        if (value.intValue == targetPath) {
            return [NSIndexPath indexPathForRow:row inSection:section];
        }
        ++row;
    }
    return nil;
}

/** @ghidraAddress 0x11405c */
- (NSIndexPath *)getTargetPath:(int)targetPath {
    int sectionCount = (int)menuTable.count;
    for (int section = 0; section < sectionCount; ++section) {
        NSIndexPath *path = [self getTargetPath:targetPath inSection:section];
        if (path) {
            return path;
        }
    }
    return nil;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x113ba8 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x113be0 */
- (void)viewDidLoad {
    [super viewDidLoad];
#ifndef ENABLE_PATCHES
    // The same iOS 5 exclusive-touch idiom the settings sheet uses, on the same shared navigation
    // bar; see -[SettingsViewController viewDidLoad] for why it no longer means what it meant.
    self.navigationController.navigationBar.exclusiveTouch = YES;
    for (UIView *subview in self.navigationController.navigationBar.subviews) {
        subview.exclusiveTouch = YES;
    }
#endif
}

/** @ghidraAddress 0x113334 */
- (void)loadView {
    [super loadView];
}

/** @ghidraAddress 0x113dc0 */
- (void)viewDidUnload {
    [super viewDidUnload];
}

/** @ghidraAddress 0x113df8 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSIndexPath *selected = self.tableView.indexPathForSelectedRow;
    if (selected) {
        [self.tableView deselectRowAtIndexPath:selected animated:animated];
    }
}

/** @ghidraAddress 0x1140f0 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x114128 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x114160 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Rotation

/** @ghidraAddress 0x114198 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait and portrait-upside-down (orientations 1 and 2), matching the mask of 6 below. The
    // binary tests (orientation - 1) as unsigned, so any other value (including 0) is refused.
    return (unsigned int)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x1141a8 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // The binary returns the literal 6, i.e. portrait and portrait-upside-down.
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x1141b0 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
