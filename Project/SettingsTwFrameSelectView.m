#import "SettingsTwFrameSelectView.h"

#import "frameTableCell.h"

// A row of the item array is a positional array; only three of its elements are read here.
enum {
    kItemArrayNameIndex = 1,       // The display name, shown in the unlock prompt.
    kItemArrayIdentifierIndex = 2, // The frame identifier, handed to the delegate.
    kItemArrayCostIndex = 3        // The point cost; a positive cost means the row is locked.
};

// The button index the alert reports under "btnMessage"; 0 is the cancel button.
static const int kAlertCancelButtonIndex = 0;

// The cost below which a row is already unlocked (free).
static const int kFreeCostThreshold = 1;

// The sentinel meaning no item is pending an unlock.
static const int kNoPendingItem = -1;

// The reuse identifier of the frame rows.
static NSString *const kCellReuseIdentifier = @"FrameSelector";

// The unlock-confirmation alert's title, from the UTF-16 CFString at 0x2c11f2.
static NSString *const kUnlockAlertTitle = @"解禁"; // @ghidraAddress 0x2db460

// The unlock-confirmation prompt, from the UTF-16 CFString at 0x2c11c8.
static NSString *const kUnlockPromptFormat =
    @"%dpointで「%@」を解禁しますか？"; // @ghidraAddress 0x2db440

// The localised-string keys for the alert's two buttons.
static NSString *const kNoButtonKey = @"NO";
static NSString *const kYesButtonKey = @"YES";

@implementation SettingsTwFrameSelectView {
    id<SettingsTwFrameSelectViewDelegate> delegate; // The owning editor, held strongly.
    UITableView *frameTable;                        // The frame list, filling the whole view.
    NSMutableArray *selectItemTable;                // The mutable working copy of the item rows.
    UIAlertView *unlockAlert;                       // The unlock alert (via AlertViewManager).
    int unlockItemIndex;                            // The row pending an unlock, or kNoPendingItem.
}

#pragma mark - Construction

/** @ghidraAddress 0xfe0a8 */
- (instancetype)initWithFrame:(CGRect)frame
                     delegate:(id<SettingsTwFrameSelectViewDelegate>)delegateArg
                   dataSource:(NSMutableArray *)dataSource {
    self = [super initWithFrame:frame];
    if (self) {
        delegate = delegateArg;
        frameTable = [[UITableView alloc]
            initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        frameTable.delegate = self;
        frameTable.dataSource = self;
        [self addSubview:frameTable];
        selectItemTable = [[NSMutableArray alloc] init];
        // Deep-copy each supplied row into a fresh mutable array so unlocks can rewrite costs
        // without touching the caller's data.
        for (NSUInteger i = 0; i < dataSource.count; ++i) {
            [selectItemTable addObject:[NSMutableArray arrayWithArray:dataSource[i]]];
        }
        unlockItemIndex = kNoPendingItem;
    }
    return self;
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0xfe324 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0xfe32c */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return selectItemTable.count;
}

/** @ghidraAddress 0xfe344 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    frameTableCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellReuseIdentifier];
    if (!cell) {
        cell = [[frameTableCell alloc] initWithWidth:(int)self.frame.size.width];
    }
    NSArray *item = selectItemTable[indexPath.row];
    [cell setInfo:item];
    return cell;
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0xfe46c */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
}

/** @ghidraAddress 0xfe470 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    unlockItemIndex = (int)indexPath.row;
    NSArray *item = selectItemTable[unlockItemIndex];
    int cost = [item[kItemArrayCostIndex] intValue];
    if (cost < kFreeCostThreshold) {
        if ([delegate respondsToSelector:@selector(frameSelected:)]) {
            [delegate performSelector:@selector(frameSelected:)
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
        if ([delegate respondsToSelector:@selector(frameChange:)]) {
            [delegate performSelector:@selector(frameChange:)
                           withObject:item[kItemArrayIdentifierIndex]];
        }
    }
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0xfe854 */
- (void)alertSelect:(NSDictionary *)info {
    if ([info[@"btnMessage"] intValue] != kAlertCancelButtonIndex) {
        [self unlockItem];
        return;
    }
    unlockItemIndex = kNoPendingItem;
    // The frame view reuses the accessory view's cancel callback selector verbatim.
    if ([delegate respondsToSelector:@selector(refreshAccessory)]) {
        [delegate performSelector:@selector(refreshAccessory)];
    }
}

#pragma mark - Unlocking

/** @ghidraAddress 0xfe930 */
- (void)unlockItem {
    // The shipped implementation is empty.
}

/** @ghidraAddress 0xfe934 */
- (void)unlockSuccess {
    NSMutableArray *item = selectItemTable[unlockItemIndex];
    [item replaceObjectAtIndex:kItemArrayCostIndex withObject:@(0)];
    if ([delegate respondsToSelector:@selector(frameSelected:)]) {
        [delegate performSelector:@selector(frameSelected:)
                       withObject:item[kItemArrayIdentifierIndex]];
    }
    [frameTable reloadData];
    unlockItemIndex = kNoPendingItem;
}

/** @ghidraAddress 0xfea64 */
- (void)unlockFailed {
    unlockItemIndex = kNoPendingItem;
}

#pragma mark - Orientation

/** @ghidraAddress 0xfea78 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait (1) and portrait-upside-down (2): the unsigned (orientation - 1) < 2 test.
    return (NSUInteger)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0xfea88 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0xfea90 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
