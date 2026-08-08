#import "StoreLeafletView.h"

#import "JubeatAppDelegate.h"
#import "StoreLeafletCell.h"

// The plate's inset from its container. Both axes differ between pad and phone.
static const CGFloat kLeafletInsetXPad = 40.0;
static const CGFloat kLeafletInsetXPhone = 20.0;
static const CGFloat kLeafletInsetYPad = 60.0;
static const CGFloat kLeafletInsetYPhone = 30.0;

// The plate's rounded-corner radius. @ghidraAddress constant 0x4020000000000000.
static const CGFloat kLeafletCornerRadius = 8.0;

// The alpha of the view's translucent black backing.
static const CGFloat kBackgroundAlpha = 0.5;

// Row heights. The placeholder height is shared by both idioms; the valid-row height differs.
// @ghidraAddress 0x292e30 (pad table), 0x292e40 (phone table).
static const CGFloat kRowHeightPlaceholder = 60.0;
static const CGFloat kRowHeightValidPad = 124.0;
static const CGFloat kRowHeightValidPhone = 80.0;

@implementation StoreLeafletView {
    BOOL isPad;
    UIView *leafletView;
    StoreLeafletCell *cell;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x124844 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        isPad = JubeatAppDelegate.appDelegate.isPad;
        // The original built this with colorWithWhite:0 alpha:0.5 rather than a predefined colour.
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kBackgroundAlpha];

        const CGFloat insetX = isPad ? kLeafletInsetXPad : kLeafletInsetXPhone;
        const CGFloat insetY = isPad ? kLeafletInsetYPad : kLeafletInsetYPhone;
        leafletView = [[UIView alloc] initWithFrame:CGRectMake(insetX,
                                                               insetY,
                                                               frame.size.width - insetX * 2,
                                                               frame.size.height - insetY * 2)];
        leafletView.layer.cornerRadius = kLeafletCornerRadius;
        leafletView.clipsToBounds = YES;
        leafletView.backgroundColor = UIColor.yellowColor;
        [self addSubview:leafletView];

        cell = [[StoreLeafletCell alloc] initWithFrame:leafletView.frame];
        cell.aDelegate = self;
        // The cell is added to the view itself rather than to the leaflet plate.
        [self addSubview:cell];
    }
    return self;
}

#pragma mark - Table contents

/** @ghidraAddress 0x124ac0 */
- (NSInteger)numPackRows {
    return 0;
}

/** @ghidraAddress 0x124ad0 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0x124ad8 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self numPackRows];
}

/** @ghidraAddress 0x124ac8 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Unreachable as shipped: numPackRows is 0, so no row is ever requested.
    return nil;
}

/** @ghidraAddress 0x124ae4 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    const BOOL validRow = indexPath.row < [self numPackRows];
    if (isPad) {
        return validRow ? kRowHeightValidPad : kRowHeightPlaceholder;
    }
    return validRow ? kRowHeightValidPhone : kRowHeightPlaceholder;
}

#pragma mark - Table delegate

/** @ghidraAddress 0x124b68 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    // The binary's body is a single ret.
}

/** @ghidraAddress 0x124b6c */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // The binary's body is a single ret.
}

#pragma mark - Scrolling and delegate forwarding

/** @ghidraAddress 0x124b70 */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // The binary's body is a single ret; the shipped view does nothing on scroll.
}

/** @ghidraAddress 0x124b74 */
- (void)pushOpenDetail:(id)packID {
    // The delegate is loaded from the weak slot twice, once to test and once to send to.
    if ([self.aDelegate respondsToSelector:@selector(pushOpenDetail:)]) {
        [self.aDelegate performSelector:@selector(pushOpenDetail:) withObject:packID];
    }
}

@end
