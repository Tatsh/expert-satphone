#import "SettingsTwAccSelectView.h"

#import "accessoryTableCell.h"

// A row of the item array is a positional array; only three of its elements are read here.
enum {
    kItemArrayNameIndex = 1,       // The display name, shown in the unlock prompt.
    kItemArrayIdentifierIndex = 2, // The accessory identifier, handed to the delegate.
    kItemArrayCostIndex = 3        // The point cost; a positive cost means the row is locked.
};

// The button index the alert reports under "btnMessage"; 0 is the cancel button.
static const int kAlertCancelButtonIndex = 0;

// The fixed row height, read from the double at 0x28f258.
static const CGFloat kRowHeight = 60.0; // @ghidraAddress 0x28f258

// The cost below which a row is already unlocked (free).
static const int kFreeCostThreshold = 1;

// The sentinel meaning no item is pending an unlock.
static const int kNoPendingItem = -1;

// The reuse identifier of the accessory rows.
static NSString *const kCellReuseIdentifier = @"FrameSelector";

// The user-defaults key holding the currently equipped Twitter accessory identifier.
static NSString *const kEquippedAccessoryDefaultsKey = @"PrefTwitterAccessory";

// The unlock-confirmation alert's title, from the UTF-16 CFString at 0x2c11f2.
static NSString *const kUnlockAlertTitle = @"解禁"; // @ghidraAddress 0x2db460

// The unlock-confirmation prompt, from the UTF-16 CFString at 0x2c11c8.
static NSString *const kUnlockPromptFormat =
    @"%dpointで「%@」を解禁しますか？"; // @ghidraAddress 0x2db440

// The localised-string keys for the alert's two buttons.
static NSString *const kNoButtonKey = @"NO";
static NSString *const kYesButtonKey = @"YES";

@implementation SettingsTwAccSelectView {
    id<SettingsTwAccSelectViewDelegate> delegate; // The owning editor, held strongly.
    UITableView *itemTable;                       // The item list, filling the whole view.
    NSMutableArray *selectItemTable;              // The item rows supplied by the caller.
    UIAlertView *unlockAlert;                     // The unlock alert (managed by AlertViewManager).
    int unlockItemIndex;                          // The row pending an unlock, or kNoPendingItem.
}

#pragma mark - Construction

/** @ghidraAddress 0xe34bc */
- (instancetype)initWithFrame:(CGRect)frame
                     delegate:(id<SettingsTwAccSelectViewDelegate>)delegateArg
                   dataSource:(NSMutableArray *)dataSource {
    self = [super initWithFrame:frame];
    if (self) {
        delegate = delegateArg;
        itemTable = [[UITableView alloc]
            initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        itemTable.delegate = self;
        itemTable.dataSource = self;
        [self addSubview:itemTable];
        selectItemTable = dataSource;
        unlockItemIndex = kNoPendingItem;
    }
    return self;
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0xe3638 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0xe3640 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return selectItemTable.count;
}

/** @ghidraAddress 0xe3664 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    accessoryTableCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellReuseIdentifier];
    if (!cell) {
        cell = [[accessoryTableCell alloc] initWithWidth:(int)self.frame.size.width];
    }
    NSArray *item = selectItemTable[indexPath.row];
    [cell setInfo:item];
    NSString *identifier = item[kItemArrayIdentifierIndex];
    NSString *equipped =
        [NSUserDefaults.standardUserDefaults objectForKey:kEquippedAccessoryDefaultsKey];
    [cell setAccessoryType:UITableViewCellAccessoryNone];
    if ([identifier isEqualToString:equipped]) {
        [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    }
    return cell;
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0xe3658 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kRowHeight;
}

/** @ghidraAddress 0xe3854 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
}

/** @ghidraAddress 0xe3858 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    unlockItemIndex = (int)indexPath.row;
    NSArray *item = selectItemTable[unlockItemIndex];
    int cost = [item[kItemArrayCostIndex] intValue];
    if (cost < kFreeCostThreshold) {
        if ([delegate respondsToSelector:@selector(accessorySelected:)]) {
            [delegate performSelector:@selector(accessorySelected:)
                           withObject:item[kItemArrayIdentifierIndex]];
        }
        [tableView reloadData];
    } else {
        NSString *message =
            [NSString stringWithFormat:kUnlockPromptFormat, cost, item[kItemArrayNameIndex]];
        NSString *noTitle = [NSBundle.mainBundle localizedStringForKey:kNoButtonKey
                                                                 value:@""
                                                                 table:nil];
        NSString *yesTitle = [NSBundle.mainBundle localizedStringForKey:kYesButtonKey
                                                                  value:@""
                                                                  table:nil];
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:self
                                                tag:0
                                              title:kUnlockAlertTitle
                                                msg:message
                                             cancel:noTitle
                                            btnText:@[ yesTitle ]
                                               show:YES];
        if ([delegate respondsToSelector:@selector(accessoryChange:)]) {
            [delegate performSelector:@selector(accessoryChange:)
                           withObject:item[kItemArrayIdentifierIndex]];
        }
    }
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0xe3c3c */
- (void)alertSelect:(NSDictionary *)info {
    if ([info[@"btnMessage"] intValue] != kAlertCancelButtonIndex) {
        [self unlockItem];
        return;
    }
    unlockItemIndex = kNoPendingItem;
    if ([delegate respondsToSelector:@selector(refreshAccessory)]) {
        [delegate performSelector:@selector(refreshAccessory)];
    }
}

#pragma mark - Unlocking

/** @ghidraAddress 0xe3d18 */
- (void)unlockItem {
    // The shipped implementation is empty.
}

/** @ghidraAddress 0xe3d1c */
- (void)unlockSuccess {
    NSMutableArray *item = selectItemTable[unlockItemIndex];
    [item replaceObjectAtIndex:kItemArrayCostIndex withObject:@(0)];
    if ([delegate respondsToSelector:@selector(accessorySelected:)]) {
        [delegate performSelector:@selector(accessorySelected:)
                       withObject:item[kItemArrayIdentifierIndex]];
    }
    [itemTable reloadData];
    unlockItemIndex = kNoPendingItem;
}

/** @ghidraAddress 0xe3e4c */
- (void)unlockFailed {
    unlockItemIndex = kNoPendingItem;
}

#pragma mark - Orientation

/** @ghidraAddress 0xe3e60 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait (1) and portrait-upside-down (2): the unsigned (orientation - 1) < 2 test.
    return (NSUInteger)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0xe3e70 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0xe3e78 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
