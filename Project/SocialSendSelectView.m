#import "SocialSendSelectView.h"

#import <QuartzCore/QuartzCore.h>
#import <Social/Social.h>

#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "ShadowView.h"
#import "StoreButton.h"

// The board size, chosen by device idiom.
static const CGFloat kBoardWidthPad = 320.0;    // @ghidraAddress 0x28f470
static const CGFloat kBoardWidthPhone = 300.0;  // @ghidraAddress 0x28f2d0
static const CGFloat kBoardHeightPad = 210.0;   // @ghidraAddress 0x28f200
static const CGFloat kBoardHeightPhone = 360.0; // @ghidraAddress 0x292918

// The gradient-backed board's layer styling.
static const CGFloat kBoardCornerRadius = 6.0;
static const CGFloat kBoardBorderWidth = 2.0;
static const CGFloat kBoardShadowRadius = 4.0;
static const float kBoardShadowOpacity = 0.5f;
// The board gradient runs from the top, through a stop this many points down, to the bottom.
static const CGFloat kGradientMidLocationNumerator = 40.0; // @ghidraAddress 0x28f1f8
// The three greys of the board gradient (top to bottom).
static const CGFloat kGradientWhiteTop = 0.961;    // @ghidraAddress 0x292420
static const CGFloat kGradientWhiteMiddle = 0.855; // @ghidraAddress 0x292428
static const CGFloat kGradientWhiteBottom = 0.762; // @ghidraAddress 0x292430

// The shared blue-green fill of the store-style buttons.
static const CGFloat kButtonFillGreen = 0.433; // @ghidraAddress 0x292440
static const CGFloat kButtonFillBlue = 0.617;  // @ghidraAddress 0x292448
static const CGFloat kStoreButtonCornerRadius = 3.0;
static const CGFloat kButtonTitleFontSize = 14.0;

// The discarded upload background image, framed relative to the board's own frame.
static const CGFloat kBackgroundXOffset = -106.0; // @ghidraAddress 0x292408 (added to board width)
static const CGFloat kBackgroundYOffset = -62.0;  // @ghidraAddress 0x292920 (added to board height)
static const CGFloat kBackgroundWidth = 106.0;    // @ghidraAddress 0x292928
static const CGFloat kBackgroundHeight = 62.0;    // @ghidraAddress 0x292930

// The title label, whose width tracks the board width.
static const CGFloat kMessageLabelX = 30.0;
static const CGFloat kMessageLabelY = 11.0;
static const CGFloat kMessageLabelWidthInset = -60.0; // @ghidraAddress 0x291bc8 (added to width)
static const CGFloat kMessageLabelHeight = 20.0;
static const CGFloat kMessageLabelFontSize = 15.0;

// The target table (and its inner-shadow overlay), sized from the board.
static const CGFloat kTableX = 16.0;
static const CGFloat kTableY = 40.0;
static const CGFloat kTableWidthInset = -32.0;   // @ghidraAddress 0x292938 (added to board width)
static const CGFloat kTableHeightInset = -108.0; // @ghidraAddress 0x293ca0 (added to board height)

// The two buttons, anchored to the bottom of the board and split about its centre.
static const CGFloat kButtonHeight = 32.0;              // @ghidraAddress 0x28f458
static const CGFloat kButtonHorizontalPadding = 24.0;   // Added to each sized-to-fit width.
static const CGFloat kButtonCentreGap = 10.0;           // Half-gap on each side of centre.
static const CGFloat kButtonBottomFirstMargin = -34.0;  // @ghidraAddress 0x291d78
static const CGFloat kButtonBottomSecondMargin = -16.0; // Trailing bottom subtraction.

// The reuse identifier of the target rows.
static NSString *const kCellReuseIdentifier = @"SocialSendTableCell";

// The bundle keys for the two button titles, looked up in the default table.
static NSString *const kCancelButtonKey = @"Cancel";
static NSString *const kOKButtonKey = @"OK";

// The discarded upload background image.
static NSString *const kBackgroundImageName = @"upload_bg";

// The board title, from the UTF-16 CFString at 0x2c178a.
static NSString *const kMessageText = @"使用する機能を選択してください";

// The sentinel meaning no target row has been chosen yet.
static const int kNoSelectedSlot = -1;

@implementation SocialSendSelectView {
    UITableView *listTable; // The target table.
    UIView *coverBoard;     // Declared in the metadata, unused here.
    UILabel *labelMessage;  // The board title.
    UIView *shadowView;     // The table's inner-shadow overlay.
    StoreButton *btnOK;     // The OK button, disabled until a row is chosen.
    StoreButton *btnEnd;    // The Cancel button.
    UILabel *textLabel;     // Declared in the metadata, unused here.
    __weak id<SocialSendSelectViewDelegate> delegate;
    NSArray *cellTitleTable;  // The row titles: @[@"Twitter", @"Facebook"].
    NSArray *socialTypeTable; // The row social types: @[Twitter, Facebook].
    NSString *mesString;      // The message handed back to the delegate.
    int selectSlot;           // The chosen row, or kNoSelectedSlot.
}

#pragma mark - Layer

/** @ghidraAddress 0x1bf168 */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

#pragma mark - Construction

/** @ghidraAddress 0x1bf17c */
- (void)createStoreBtn:(id)sender {
    // The button is built but neither stored nor added anywhere: the binary discards it, and the
    // sender argument is ignored.
    StoreButton *button = [[StoreButton alloc] initWithFrame:CGRectZero];
    // The original used the full component call; green and blue are non-standard components.
    button.buttonColor = [UIColor colorWithRed:0
                                         green:kButtonFillGreen
                                          blue:kButtonFillBlue
                                         alpha:1.0];
    button.cornerRadius = kStoreButtonCornerRadius;
    [button setExclusiveTouch:YES];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonTitleFontSize];
}

/** @ghidraAddress 0x1bf2b4 */
- (instancetype)initWithMessage:(NSString *)message
                       delegate:(id<SocialSendSelectViewDelegate>)delegateArg {
    selectSlot = kNoSelectedSlot;
    mesString = message;
    cellTitleTable = @[ @"Twitter", @"Facebook" ];
    socialTypeTable = @[ SLServiceTypeTwitter, SLServiceTypeFacebook ];

    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    CGFloat boardWidth = isPad ? kBoardWidthPad : kBoardWidthPhone;
    CGFloat boardHeight = isPad ? kBoardHeightPad : kBoardHeightPhone;
    self = [super initWithFrame:CGRectMake(0, 0, boardWidth, boardHeight)];
    if (self) {
        delegate = delegateArg;

        CAGradientLayer *gradient = (CAGradientLayer *)self.layer;
        gradient.cornerRadius = kBoardCornerRadius;
        gradient.borderWidth = kBoardBorderWidth;
        gradient.borderColor = UIColor.lightGrayColor.CGColor;
        gradient.locations = @[ @(0.0f), @(kGradientMidLocationNumerator / boardHeight), @(1.0f) ];
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

        // The upload background is loaded, framed against the board's own frame, and added.
        UIImageView *background =
            [[UIImageView alloc] initWithImage:LoadScaledPngImage(kBackgroundImageName)];
        background.frame = CGRectMake(self.frame.size.width + kBackgroundXOffset,
                                      self.frame.size.height + kBackgroundYOffset,
                                      kBackgroundWidth,
                                      kBackgroundHeight);
        [self addSubview:background];

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
        labelMessage.text = kMessageText;

        CGFloat tableWidth = boardWidth + kTableWidthInset;
        CGFloat tableHeight = boardHeight + kTableHeightInset;
        listTable = [[UITableView alloc]
            initWithFrame:CGRectMake(kTableX, kTableY, tableWidth, tableHeight)];
        shadowView = [[ShadowView alloc]
            initWithFrame:CGRectMake(kTableX, kTableY, tableWidth, tableHeight)];
        listTable.delegate = self;
        listTable.dataSource = self;
        listTable.allowsSelection = YES;
        [listTable setExclusiveTouch:YES];
        [self addSubview:listTable];
        [self addSubview:shadowView];

        btnOK = [[StoreButton alloc] initWithFrame:CGRectZero];
        // The original used the full component call; green and blue are non-standard components.
        btnOK.buttonColor = [UIColor colorWithRed:0
                                            green:kButtonFillGreen
                                             blue:kButtonFillBlue
                                            alpha:1.0];
        btnOK.cornerRadius = kStoreButtonCornerRadius;
        [btnOK setExclusiveTouch:YES];
        [btnOK setEnabled:NO];
        btnOK.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonTitleFontSize];
        // The OK button is first titled Cancel, then retitled OK below for both states: a faithful
        // quirk of the binary.
        [btnOK setTitle:[NSBundle.mainBundle localizedStringForKey:kCancelButtonKey
                                                             value:@""
                                                             table:nil]
               forState:UIControlStateNormal];
        [btnOK addTarget:self
                      action:@selector(pushOK:)
            forControlEvents:UIControlEventTouchUpInside];
        [btnOK sizeToFit];
        CGFloat okWidth = btnOK.frame.size.width + kButtonHorizontalPadding;
        CGFloat buttonY = boardHeight + kButtonBottomFirstMargin + kButtonBottomSecondMargin;
        btnOK.frame = CGRectMake(
            boardWidth * 0.5 - okWidth - kButtonCentreGap, buttonY, okWidth, kButtonHeight);
        [btnOK setTitle:[NSBundle.mainBundle localizedStringForKey:kOKButtonKey value:@"" table:nil]
               forState:UIControlStateNormal];
        [btnOK setTitle:[NSBundle.mainBundle localizedStringForKey:kOKButtonKey value:@"" table:nil]
               forState:UIControlStateSelected];

        btnEnd = [[StoreButton alloc] initWithFrame:CGRectZero];
        // The original used the full component call; green and blue are non-standard components.
        btnEnd.buttonColor = [UIColor colorWithRed:0
                                             green:kButtonFillGreen
                                              blue:kButtonFillBlue
                                             alpha:1.0];
        btnEnd.cornerRadius = kStoreButtonCornerRadius;
        [btnEnd setExclusiveTouch:YES];
        btnEnd.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonTitleFontSize];
        [btnEnd setTitle:[NSBundle.mainBundle localizedStringForKey:kCancelButtonKey
                                                              value:@""
                                                              table:nil]
                forState:UIControlStateNormal];
        [btnEnd addTarget:self
                      action:@selector(pushCancel:)
            forControlEvents:UIControlEventTouchUpInside];
        [btnEnd sizeToFit];
        CGFloat endWidth = btnEnd.frame.size.width + kButtonHorizontalPadding;
        btnEnd.frame =
            CGRectMake(boardWidth * 0.5 + kButtonCentreGap, buttonY, endWidth, kButtonHeight);

        [self addSubview:btnOK];
        [self addSubview:btnEnd];
    }
    return self;
}

#pragma mark - Actions

/** @ghidraAddress 0x1c00a0 */
- (void)pushOK:(id)sender {
    NSString *socialType = socialTypeTable[selectSlot];
    if ([delegate respondsToSelector:@selector(socialSelectEnd:sendText:)]) {
        [delegate performSelector:@selector(socialSelectEnd:sendText:)
                       withObject:socialType
                       withObject:mesString];
    }
}

/** @ghidraAddress 0x1c0174 */
- (void)pushCancel:(id)sender {
    if ([delegate respondsToSelector:@selector(socialSelectCancel:)]) {
        [delegate performSelector:@selector(socialSelectCancel:) withObject:self];
    }
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0x1c0218 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellReuseIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:kCellReuseIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    }
    cell.textLabel.text = cellTitleTable[indexPath.row];
    return cell;
}

/** @ghidraAddress 0x1c0374 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0x1c037c */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0x1c0384 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    selectSlot = (int)indexPath.row;
    [btnOK setEnabled:YES];
}

@end
