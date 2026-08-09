#import "SettingsTwDegreeSelectView.h"

#import "degreeTableCell.h"

// A row of the item array is a positional array; only three of its elements are read here.
enum {
    kItemArrayNameIndex = 1, // The display name, filled into the identifier's format template.
    kItemArrayIdentifierIndex = 2, // The degree identifier, used as a format template for display.
    kItemArrayCostIndex = 3        // The point cost; a positive cost means the row is locked.
};

// The button index the alert reports under "btnMessage"; 0 is the cancel button.
static const int kAlertCancelButtonIndex = 0;

// The fixed row height, read from the double at 0x28f640.
static const CGFloat kRowHeight = 54.0; // @ghidraAddress 0x28f640

// The cost below which a row is already unlocked (free).
static const int kFreeCostThreshold = 1;

// The sentinel meaning no item is pending an unlock.
static const int kNoPendingItem = -1;

// The reuse identifier of the degree rows, from the CFString at 0x2db420.
static NSString *const kCellReuseIdentifier = @"FrameSelector";

// The user-defaults key holding the currently equipped Twitter identifier, from the string at
// 0x282ca4. (The degree view reuses the accessory key verbatim in the shipped binary.)
static NSString *const kEquippedDefaultsKey = @"PrefTwitterAccessory";

// The unlock-confirmation alert's title, from the UTF-16 CFString at 0x2c11f2.
static NSString *const kUnlockAlertTitle = @"解禁"; // @ghidraAddress 0x2db460

// The unlock-confirmation prompt, from the UTF-16 CFString at 0x2c11c8.
static NSString *const kUnlockPromptFormat =
    @"%dpointで「%@」を解禁しますか？"; // @ghidraAddress 0x2db440

// The localised-string keys for the alert's two buttons.
static NSString *const kNoButtonKey = @"NO";
static NSString *const kYesButtonKey = @"YES";

@implementation SettingsTwDegreeSelectView {
    id<SettingsTwDegreeSelectViewDelegate> delegate; // The owning editor, held strongly.
    UITableView *itemTable;                          // The item list, filling the whole view.
    NSMutableArray *selectItemTable;                 // The item rows supplied by the caller.
    UIAlertView *unlockAlert;                        // The unlock alert (never assigned here).
    int unlockItemIndex; // The row pending an unlock, or kNoPendingItem.
}

#pragma mark - Construction

/** @ghidraAddress 0x123dc8 */
- (instancetype)initWithFrame:(CGRect)frame
                     delegate:(id<SettingsTwDegreeSelectViewDelegate>)delegateArg
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

/** @ghidraAddress 0x123f44 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0x123f4c */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return selectItemTable.count;
}

/** @ghidraAddress 0x123f70 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    degreeTableCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellReuseIdentifier];
    if (!cell) {
        cell = [[degreeTableCell alloc] initWithWidth:(int)self.frame.size.width];
    }
    NSArray *item = selectItemTable[indexPath.row];
    [cell setInfo:item];
    NSString *identifier = item[kItemArrayIdentifierIndex];
    NSString *equipped = [NSUserDefaults.standardUserDefaults objectForKey:kEquippedDefaultsKey];
    [cell setAccessoryType:UITableViewCellAccessoryNone];
    if ([identifier isEqualToString:equipped]) {
        [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    }
    return cell;
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0x123f64 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kRowHeight;
}

/** @ghidraAddress 0x124160 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
}

/** @ghidraAddress 0x124164 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    unlockItemIndex = (int)indexPath.row;
    NSArray *item = selectItemTable[unlockItemIndex];
    // The identifier (element 2) is itself a format template that the name (element 1) fills.
    NSString *display =
        [NSString stringWithFormat:item[kItemArrayIdentifierIndex], item[kItemArrayNameIndex]];
    int cost = [item[kItemArrayCostIndex] intValue];
    if (cost < kFreeCostThreshold) {
        if ([delegate respondsToSelector:@selector(degreeSelected:)]) {
            [delegate performSelector:@selector(degreeSelected:) withObject:display];
        }
        [tableView reloadData];
    } else {
        NSString *message = [NSString stringWithFormat:kUnlockPromptFormat, cost, display];
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
        [unlockAlert
            show]; // The binary re-shows here, but unlockAlert is never assigned (a no-op).
        if ([delegate respondsToSelector:@selector(degreeChange:)]) {
            [delegate performSelector:@selector(degreeChange:) withObject:display];
        }
    }
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0x124560 */
- (void)alertSelect:(NSDictionary *)info {
    if ([info[@"btnMessage"] intValue] != kAlertCancelButtonIndex) {
        [self unlockItem];
        return;
    }
    unlockItemIndex = kNoPendingItem;
    if ([delegate respondsToSelector:@selector(refreshDegree)]) {
        [delegate performSelector:@selector(refreshDegree)];
    }
}

#pragma mark - Unlocking

/** @ghidraAddress 0x12463c */
- (void)unlockItem {
    // The shipped implementation is empty.
}

/** @ghidraAddress 0x124640 */
- (void)unlockSuccess {
    NSMutableArray *item = selectItemTable[unlockItemIndex];
    [item replaceObjectAtIndex:kItemArrayCostIndex withObject:@(0)];
    if ([delegate respondsToSelector:@selector(degreeSelected:)]) {
        // Unlike the free-row tap, this passes the raw identifier, not the formatted display
        // string.
        [delegate performSelector:@selector(degreeSelected:)
                       withObject:item[kItemArrayIdentifierIndex]];
    }
    [itemTable reloadData];
    unlockItemIndex = kNoPendingItem;
}

/** @ghidraAddress 0x124770 */
- (void)unlockFailed {
    unlockItemIndex = kNoPendingItem;
}

#pragma mark - Orientation

/** @ghidraAddress 0x124784 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait (1) and portrait-upside-down (2): the unsigned (orientation - 1) < 2 test.
    return (NSUInteger)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x124794 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x12479c */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
