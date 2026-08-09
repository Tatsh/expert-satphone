#import "MusicShareView.h"

#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import <QuartzCore/QuartzCore.h>

#import "ImageLoading.h"
#import "ShadowView.h"
#import "StoreButton.h"

// MusicSelectViewController owns this panel; it is told which host to connect to and when the
// panel is cancelled. It is not yet reconstructed, so only the selectors messaged here are
// declared.
@interface MusicSelectViewController (MusicShareViewPending)
- (void)cancelShare:(nullable id)sender;
- (void)shareHostSelected:(nonnull MCPeerID *)host;
@end

// The gradient-backed board's layer styling.
static const CGFloat kBoardCornerRadius = 6.0; // fmov immediate at 0x18338c
static const CGFloat kBoardBorderWidth = 2.0;  // fmov immediate at 0x18339c
static const CGFloat kBoardShadowRadius = 4.0; // fmov immediate at 0x183640
static const float kBoardShadowOpacity = 0.5f; // fmov immediate at 0x183670

// The three greys of the board gradient (top to bottom).
static const CGFloat kGradientWhiteTop = 0.961;    // @ghidraAddress 0x292420
static const CGFloat kGradientWhiteMiddle = 0.855; // @ghidraAddress 0x292428
static const CGFloat kGradientWhiteBottom = 0.762; // @ghidraAddress 0x292430

// The board's top header band. This single pool value (loaded once into d10) sets three things:
// the y where the host table begins, the gradient's middle stop (header/height), and the vertical
// centring base of the host icon.
static const CGFloat kBoardHeaderHeight = 40.0; // @ghidraAddress 0x28f1f8

// The host icon, added near the top-left at its intrinsic size.
static const CGFloat kHostIconX = 16.0;        // fmov immediate at 0x183720
static const CGFloat kHostIconYRounding = 1.0; // The +1 added to the centred y (0x1836f4).

// The status message label, whose width tracks the board width.
static const CGFloat kMessageLabelX = 30.0;           // fmov immediate at 0x183828
static const CGFloat kMessageLabelY = 11.0;           // fmov immediate at 0x18382c
static const CGFloat kMessageLabelWidthInset = -60.0; // @ghidraAddress 0x291bc8 (added to width)
static const CGFloat kMessageLabelHeight = 20.0;      // fmov immediate at 0x183830
static const CGFloat kMessageLabelFontSize = 15.0;    // fmov immediate at 0x1838c4

// The host table (and its inner-shadow overlay), sized from the board.
static const CGFloat kTableX = 16.0;            // fmov immediate at 0x183720 (shared d12)
static const CGFloat kTableWidthInset = -32.0;  // @ghidraAddress 0x292938 (added to board width)
static const CGFloat kTableHeightInset = -88.0; // @ghidraAddress 0x292940 (added to board height)

// The shared blue-green fill of the store-style Cancel button.
static const CGFloat kButtonFillGreen = 0.433;       // @ghidraAddress 0x292440
static const CGFloat kButtonFillBlue = 0.617;        // @ghidraAddress 0x292448
static const CGFloat kStoreButtonCornerRadius = 3.0; // fmov immediate at 0x183a94
static const CGFloat kButtonTitleFontSize = 14.0;    // fmov immediate at 0x183ad8

// The Cancel button, centred horizontally and anchored to the bottom of the board.
static const CGFloat kButtonHorizontalPadding = 24.0;   // fmov immediate at 0x183bc4
static const CGFloat kButtonCentreRatio = 0.5;          // fmov immediate at 0x183bcc
static const CGFloat kButtonBottomFirstMargin = -24.0;  // fmov immediate at 0x183bdc (added to h)
static const CGFloat kButtonBottomSecondMargin = -16.0; // fmov immediate at 0x183be4
static const CGFloat kButtonHeight = 32.0;              // @ghidraAddress 0x28f458

// The activity indicator, centred on the board. The inset is half the indicator size.
static const CGFloat kIndicatorSize = 32.0; // @ghidraAddress 0x28f458 (shared d9)
static const CGFloat kIndicatorHalfInset =
    16.0; // fmov immediate at 0x183be4 (shared -16 magnitude)

// The initial capacities of the host containers.
static const NSUInteger kHostContainerCapacity = 16;

// The fade duration when the browse UI leaves on connection.
static const NSTimeInterval kFadeDuration = 0.2; // @ghidraAddress 0x28e040

// The decorative images, added but never stored: a host icon and a bottom-right join background.
static NSString *const kHostIconImageName = @"menu_icon_host";
static NSString *const kJoinBackgroundImageName = @"menu_join_bg";

// The reuse identifier of the host rows.
static NSString *const kCellReuseIdentifier = @"MusicShareViewHostTableCell";

// The localised message keys for the three client-mode states.
static NSString *const kMessageKeySearching = @"Searching hosts";
static NSString *const kMessageKeyConnecting = @"Connecting";
static NSString *const kMessageKeyChooseHost = @"Choose a host";

// The Cancel button title key.
static NSString *const kCancelButtonKey = @"Cancel";

@implementation MusicShareView {
    NSMutableArray<MCPeerID *> *listHostID;                    // The peers, in row order.
    NSMutableDictionary<MCPeerID *, NSString *> *dictHostName; // Peer -> display name.
    UILabel *labelMessage;                                     // The status message.
    UITableView *tableViewHosts;                               // The host list.
    UIView *shadowView;                                        // The table's inner-shadow overlay.
    StoreButton *btnCancel;                                    // The Cancel button.
    UIActivityIndicatorView *indicatorView;                    // The connecting spinner.
}

@synthesize controller = _controller;

#pragma mark - Layer

/** @ghidraAddress 0x1832d8 */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

#pragma mark - Construction

/** @ghidraAddress 0x1832ec */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        CGFloat boardWidth = frame.size.width;
        CGFloat boardHeight = frame.size.height;

        CAGradientLayer *gradient = (CAGradientLayer *)self.layer;
        gradient.cornerRadius = kBoardCornerRadius;
        gradient.borderWidth = kBoardBorderWidth;
        gradient.borderColor = UIColor.lightGrayColor.CGColor;
        gradient.locations = @[ @(0.0f), @(kBoardHeaderHeight / boardHeight), @(1.0f) ];
        gradient.colors = @[
            (__bridge id)[UIColor colorWithWhite:kGradientWhiteTop alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithWhite:kGradientWhiteMiddle alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithWhite:kGradientWhiteBottom alpha:1.0].CGColor
        ];
        // The light-grey border set above is immediately replaced with grey.
        gradient.borderColor = UIColor.grayColor.CGColor;
        gradient.shadowRadius = kBoardShadowRadius;
        gradient.shadowOffset = CGSizeZero;
        gradient.shadowOpacity = kBoardShadowOpacity;

        // The host icon, added near the top-left at its intrinsic size, vertically centred within
        // the header band. The y is a signed integer divide-by-two (truncating toward zero) of the
        // remaining header space, plus one.
        UIImageView *hostIcon =
            [[UIImageView alloc] initWithImage:LoadScaledPngImage(kHostIconImageName)];
        int headerRemainder = (int)(kBoardHeaderHeight - hostIcon.frame.size.height);
        CGFloat hostIconY = (CGFloat)(headerRemainder / 2) + kHostIconYRounding;
        hostIcon.frame = CGRectMake(
            kHostIconX, hostIconY, hostIcon.frame.size.width, hostIcon.frame.size.height);
        [self addSubview:hostIcon];

        // The join background, anchored to the bottom-right corner at its intrinsic size.
        UIImageView *joinBackground =
            [[UIImageView alloc] initWithImage:LoadScaledPngImage(kJoinBackgroundImageName)];
        joinBackground.frame = CGRectMake(boardWidth - joinBackground.frame.size.width,
                                          boardHeight - joinBackground.frame.size.height,
                                          joinBackground.frame.size.width,
                                          joinBackground.frame.size.height);
        [self addSubview:joinBackground];

        labelMessage =
            [[UILabel alloc] initWithFrame:CGRectMake(kMessageLabelX,
                                                      kMessageLabelY,
                                                      boardWidth + kMessageLabelWidthInset,
                                                      kMessageLabelHeight)];
        [labelMessage setOpaque:NO];
        labelMessage.backgroundColor = UIColor.clearColor;
        labelMessage.font = [UIFont boldSystemFontOfSize:kMessageLabelFontSize];
        labelMessage.textColor = UIColor.blackColor;
        labelMessage.textAlignment = NSTextAlignmentCenter;
        [self addSubview:labelMessage];

        CGFloat tableWidth = boardWidth + kTableWidthInset;
        CGFloat tableHeight = boardHeight + kTableHeightInset;
        tableViewHosts = [[UITableView alloc]
            initWithFrame:CGRectMake(kTableX, kBoardHeaderHeight, tableWidth, tableHeight)];
        shadowView = [[ShadowView alloc]
            initWithFrame:CGRectMake(kTableX, kBoardHeaderHeight, tableWidth, tableHeight)];

        btnCancel = [[StoreButton alloc] initWithFrame:CGRectZero];
        // The original used the full component call; green and blue are non-standard components.
        btnCancel.buttonColor = [UIColor colorWithRed:0
                                                green:kButtonFillGreen
                                                 blue:kButtonFillBlue
                                                alpha:1.0];
        btnCancel.cornerRadius = kStoreButtonCornerRadius;
        [btnCancel setExclusiveTouch:YES];
        btnCancel.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonTitleFontSize];
        [btnCancel setTitle:[NSBundle.mainBundle localizedStringForKey:kCancelButtonKey
                                                                 value:@""
                                                                 table:nil]
                   forState:UIControlStateNormal];
        [btnCancel addTarget:self
                      action:@selector(pushCancel:)
            forControlEvents:UIControlEventTouchUpInside];
        [btnCancel sizeToFit];
        CGFloat buttonWidth = btnCancel.frame.size.width + kButtonHorizontalPadding;
        CGFloat buttonX = boardWidth * kButtonCentreRatio - buttonWidth * kButtonCentreRatio;
        CGFloat buttonY = boardHeight + kButtonBottomFirstMargin + kButtonBottomSecondMargin;
        btnCancel.frame = CGRectMake(buttonX, buttonY, buttonWidth, kButtonHeight);

        indicatorView = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        indicatorView.frame = CGRectMake(boardWidth * kButtonCentreRatio - kIndicatorHalfInset,
                                         boardHeight * kButtonCentreRatio - kIndicatorHalfInset,
                                         kIndicatorSize,
                                         kIndicatorSize);
        indicatorView.hidesWhenStopped = YES;

        [self addSubview:btnCancel];
        [self addSubview:indicatorView];

        listHostID = [NSMutableArray arrayWithCapacity:kHostContainerCapacity];
        dictHostName = [NSMutableDictionary dictionaryWithCapacity:kHostContainerCapacity];
    }
    return self;
}

#pragma mark - Actions

/** @ghidraAddress 0x183d6c */
- (void)pushCancel:(id)sender {
    [self.controller cancelShare:nil];
}

#pragma mark - Client-mode states

/** @ghidraAddress 0x183db0 */
- (void)changeClientModeSearch {
    labelMessage.text = [NSBundle.mainBundle localizedStringForKey:kMessageKeySearching
                                                             value:@""
                                                             table:nil];
    tableViewHosts.delegate = self;
    tableViewHosts.dataSource = self;
    tableViewHosts.allowsSelection = YES;
    [self addSubview:tableViewHosts];
    [self addSubview:shadowView];
}

/** @ghidraAddress 0x183ec0 */
- (void)changeClientModeConnecting {
    tableViewHosts.allowsSelection = NO;
    labelMessage.text = [NSBundle.mainBundle localizedStringForKey:kMessageKeyConnecting
                                                             value:@""
                                                             table:nil];
}

/** @ghidraAddress 0x183f78 */
- (void)changeClientModeConnected {
    tableViewHosts.delegate = nil;
    tableViewHosts.dataSource = nil;

    __weak UITableView *weakTable = tableViewHosts;
    __weak UIView *weakShadow = shadowView;
    [UIView animateWithDuration:kFadeDuration
        animations:^{
          /** @ghidraAddress 0x184144 */
          weakTable.alpha = 0;
          weakShadow.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x184208 */
          [weakTable removeFromSuperview];
          [weakShadow removeFromSuperview];
        }];
    // The spinner is started immediately after scheduling the animation, so it appears while the
    // table is still fading out.
    [indicatorView startAnimating];
}

#pragma mark - Host list

/** @ghidraAddress 0x1842c4 */
- (void)addHost:(MCPeerID *)host {
    if ([listHostID indexOfObject:host] == NSNotFound) {
        [listHostID addObject:host];
        dictHostName[host] = host.displayName;
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:listHostID.count - 1 inSection:0];
        [tableViewHosts beginUpdates];
        [tableViewHosts insertRowsAtIndexPaths:@[ indexPath ]
                              withRowAnimation:UITableViewRowAnimationNone];
        [tableViewHosts endUpdates];
        labelMessage.text = [NSBundle.mainBundle localizedStringForKey:kMessageKeyChooseHost
                                                                 value:@""
                                                                 table:nil];
    }
}

/** @ghidraAddress 0x1844f4 */
- (void)removeHostTmp:(MCPeerID *)host {
    NSUInteger index = [listHostID indexOfObject:host];
    if (index != NSNotFound) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
        [tableViewHosts beginUpdates];
        [tableViewHosts deleteRowsAtIndexPaths:@[ indexPath ]
                              withRowAnimation:UITableViewRowAnimationNone];
        [listHostID removeObjectAtIndex:index];
        [dictHostName removeObjectForKey:host];
        [tableViewHosts endUpdates];
        if (listHostID.count == 0) {
            labelMessage.text = [NSBundle.mainBundle localizedStringForKey:kMessageKeySearching
                                                                     value:@""
                                                                     table:nil];
        }
    }
}

/** @ghidraAddress 0x184704 */
- (void)addHost:(MCPeerID *)host name:(NSString *)name {
    if ([listHostID indexOfObject:host] == NSNotFound) {
        [listHostID addObject:host];
        dictHostName[host] = name;
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:listHostID.count - 1 inSection:0];
        [tableViewHosts beginUpdates];
        [tableViewHosts insertRowsAtIndexPaths:@[ indexPath ]
                              withRowAnimation:UITableViewRowAnimationNone];
        [tableViewHosts endUpdates];
        labelMessage.text = [NSBundle.mainBundle localizedStringForKey:kMessageKeyChooseHost
                                                                 value:@""
                                                                 table:nil];
    }
}

/** @ghidraAddress 0x18492c */
- (void)removeHost:(MCPeerID *)host {
    NSUInteger index = [listHostID indexOfObject:host];
    if (index != NSNotFound) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
        [tableViewHosts beginUpdates];
        [tableViewHosts deleteRowsAtIndexPaths:@[ indexPath ]
                              withRowAnimation:UITableViewRowAnimationNone];
        [listHostID removeObjectAtIndex:index];
        [dictHostName removeObjectForKey:host];
        [tableViewHosts endUpdates];
        if (listHostID.count == 0) {
            labelMessage.text = [NSBundle.mainBundle localizedStringForKey:kMessageKeySearching
                                                                     value:@""
                                                                     table:nil];
        }
    }
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0x184b3c */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellReuseIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:kCellReuseIdentifier];
    }
    cell.detailTextLabel.text = nil;
    cell.textLabel.text = nil;
    if (indexPath.row < (NSInteger)listHostID.count) {
        MCPeerID *host = listHostID[indexPath.row];
        cell.textLabel.text = dictHostName[host];
    }
    return cell;
}

/** @ghidraAddress 0x184d4c */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return listHostID.count;
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0x184d64 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < (NSInteger)listHostID.count) {
        MCPeerID *host = listHostID[indexPath.row];
        [self.controller shareHostSelected:host];
    }
    [tableViewHosts deselectRowAtIndexPath:indexPath animated:YES];
}

@end
