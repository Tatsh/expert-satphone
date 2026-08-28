/** @file
 * The main settings-menu screen.
 *
 * Reconstructed from Ghidra program Jubeat (class @c SettingsViewController, image base
 * @c 0x100000000). All @c \@ghidraAddress values are offsets relative to that image base. It is a
 * grouped @c UITableViewController — confirmed by the chain-up through
 * @c -[UITableViewController initWithStyle:] in @c -initWithStyle: and the @c UITableViewController
 * @c dealloc / @c viewDidLoad / @c loadView / @c viewWillAppear: forwards — that lists every
 * settings entry, one row per entry across several sections. Tapping a row pushes the matching
 * sub-settings controller; the "show combos" row hosts a @c UISwitch, and the "delete custom
 * sequence" row raises a confirmation alert whose reply is delivered to @c -alertSelect: .
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The settings-menu screen: a grouped table of settings entries, each routing to a
 *        sub-settings controller.
 *
 * The controller is its own data source and delegate, and acts as the @c AlertViewManager delegate
 * for the delete-custom-sequence confirmation (see @c -alertSelect:).
 */
// clang-format off
// One protocol per line: the packed form, which begins a continuation line with
// ": UITableViewController <", is read by Doxygen as undocumented ivars named after the trailing
// protocols.
@interface SettingsViewController : UITableViewController <UITableViewDataSource,
                                                           UITableViewDelegate,
                                                           AlertViewManagerDelegate>
// clang-format on

/**
 * @brief The object forwarded to sub-controllers that need to notify the settings owner (for
 *        example the rating-chip picker and the notification page). Held weakly.
 * @ghidraAddress 0xe7d5c (getter)
 * @ghidraAddress 0xe7d7c (setter)
 */
@property(nonatomic, weak, nullable) id settingsDelegate;

/**
 * @brief The switch hosted in the "show combos" row, toggling the combo display.
 * @ghidraAddress 0xe7d90 (getter)
 * @ghidraAddress 0xe7da0 (setter)
 */
@property(nonatomic, strong, nullable) UISwitch *switchCombo;

/**
 * @brief Builds @c menuTable (row-type numbers grouped into sections) and @c menuTypeTable (the
 *        matching cell-style numbers), gated by the current theme, the iPad idiom, and
 *        @c bEnableMyPage.
 * @ghidraAddress 0xe4dbc
 */
- (void)createMenuTable;

/**
 * @brief Sets the navigation title to "SETTINGS", seeds @c bEnableMyPage from the presence and
 *        decodability of the stored jubeat Lab URL, and builds the menu.
 * @param style The table-view style handed to @c UITableViewController.
 * @return The initialised controller.
 * @ghidraAddress 0xe52b8
 */
- (instancetype)initWithStyle:(UITableViewStyle)style;

/**
 * @brief Loads the table view and creates the combo-display switch (a 94x27 @c UISwitch wired to
 *        @c -comboChanged:), seeding it from the "PrefShowCombo" default.
 * @ghidraAddress 0xe5498
 */
- (void)loadView;

/**
 * @brief Dequeues and configures the cell for a row, keyed on the row's cell-style number.
 * @param tableView The table view requesting the cell.
 * @param indexPath The row's index path.
 * @return The configured cell.
 * @ghidraAddress 0xe5678
 */
- (UITableViewCell *)tableView:(nonnull UITableView *)tableView
         cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @brief Returns the number of sections, i.e. @c menuTable.count.
 * @param tableView The table view.
 * @return The section count.
 * @ghidraAddress 0xe6618
 */
- (NSInteger)numberOfSectionsInTableView:(nonnull UITableView *)tableView;

/**
 * @brief Returns the number of rows in a section, i.e. @c menuTable[section].count.
 * @param tableView The table view.
 * @param section The section index.
 * @return The row count.
 * @ghidraAddress 0xe6630
 */
- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section;

/**
 * @brief Action for the combo-display switch; writes its state to the "PrefShowCombo" default.
 * @param sender The switch that changed.
 * @ghidraAddress 0xe668c
 */
- (void)comboChanged:(nullable id)sender;

/**
 * @brief Closes any open alert and pops to the navigation stack root.
 * @ghidraAddress 0xe6718
 */
- (void)settingClose;

/**
 * @brief Routes a tapped row to its sub-settings controller (or the delete-sequence alert).
 * @param tableView The table view.
 * @param indexPath The tapped row's index path.
 * @ghidraAddress 0xe67a0
 */
- (void)tableView:(nonnull UITableView *)tableView
    didSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @brief Finds the index path of the first row in a section whose row-type equals @c type.
 * @param type The row-type number to locate.
 * @param section The section to search.
 * @return The matching index path, or @c nil if the section has no such row.
 * @ghidraAddress 0xe76e0
 */
- (nullable NSIndexPath *)getTargetPath:(int)type inSection:(int)section;

/**
 * @brief Finds the index path of the first row of the given row-type across all sections.
 * @param type The row-type number to locate.
 * @return The matching index path, or @c nil if none exists.
 * @ghidraAddress 0xe786c
 */
- (nullable NSIndexPath *)getTargetPath:(int)type;

/**
 * @brief Standard memory-warning forward.
 * @ghidraAddress 0xe7230
 */
- (void)didReceiveMemoryWarning;

/**
 * @brief Disables exclusive-touch propagation issues by enabling exclusive touch on the navigation
 *        bar and each of its subviews.
 * @ghidraAddress 0xe7268
 */
- (void)viewDidLoad;

/**
 * @brief Releases the combo switch on unload.
 * @ghidraAddress 0xe7448
 */
- (void)viewDidUnload;

/**
 * @brief Deselects any selected row and reloads the theme, Twitter, and rating-chip rows so their
 *        detail text refreshes.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0xe74a0
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * @brief Standard appearance forward.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0xe7900
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * @brief Standard disappearance forward.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0xe7938
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * @brief Standard disappearance forward.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0xe7970
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * @brief Permits the two portrait orientations.
 * @param interfaceOrientation The orientation to test.
 * @return @c YES for portrait and portrait-upside-down.
 * @ghidraAddress 0xe79a8
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @brief The supported orientations mask (portrait and portrait-upside-down).
 * @return @c UIInterfaceOrientationMaskPortrait @c | @c
 * UIInterfaceOrientationMaskPortraitUpsideDown.
 * @ghidraAddress 0xe79b8
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Always allows autorotation.
 * @return @c YES.
 * @ghidraAddress 0xe79c0
 */
- (BOOL)shouldAutorotate;

/**
 * @brief Chains up to @c UITableViewController.
 * @ghidraAddress 0xe79c8
 */
- (void)dealloc;

/**
 * @brief @c AlertViewManager delegate reply; deletes the custom sequences when the delete-confirm
 *        alert (tag @c 0) reports its confirmation button (index @c 1) was tapped.
 * @param info The reply dictionary carrying @c "Tag" and @c "btnMessage".
 * @ghidraAddress 0xe7a00
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

/**
 * @brief Removes every custom-sequence directory the player no longer owns music for.
 * @ghidraAddress 0xe7af8
 */
- (void)deleteCustomSequence;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
