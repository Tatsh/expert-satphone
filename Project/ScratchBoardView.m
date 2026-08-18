#import "ScratchBoardView.h"

#import <QuartzCore/QuartzCore.h>

#import "ChallengeStatus.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "ScratchView.h"

// The board's background art and the per-panel background art.
static NSString *const kBoardBackgroundImageName = @"scratch_sheet";
static NSString *const kBoardPanelBackgroundImageName = @"scratch_jacket_bg";

// The number of scratch panels, arranged in a four-column grid.
static const int kBoardPanelCount = 16;
static const int kBoardColumns = 4;

// The pad cell width and height, in points (the phone scales these by the phone-screen rate).
static const int kBoardCellWidthPad = 0x2d6; // 726
static const int kBoardCellHeightPad = 0xa0; // 160

// The phone panel-background square size and the pad panel-background square size; the pooled
// doubles at 0x28fa30 and 0x28fa48-region.
static const CGFloat kBoardPanelBgSizePad = 162.0; // @ghidraAddress 0x28fa30

// The pad bottom inset applied to the grid's vertical origin.
static const CGFloat kBoardGridBottomInset = -12.0;

// The message view's size by idiom.
static const CGFloat kBoardMessageWidthPad = 314.0;   // @ghidraAddress 0x28f940
static const CGFloat kBoardMessageHeightPad = 135.0;  // @ghidraAddress 0x28fa48
static const CGFloat kBoardMessageWidthPhone = 130.0; // @ghidraAddress 0x28fa38
static const CGFloat kBoardMessageHeightPhone = 82.0; // @ghidraAddress 0x28fa40

// The phone-scaling factors for the cell width (5/12 × 726), cell height (72), panel-background
// square (74), the grid width span (334), and the grid vertical origin base (90). All are floats
// multiplied by the phone-screen rate.
static const float kBoardPhoneCellWidthBase = 0.4166666567325592f; // @ghidraAddress 0x28f898
static const float kBoardPhoneCellWidthSpan = 726.0f;              // @ghidraAddress 0x28fa20
static const float kBoardPhoneCellHeight = 72.0f;                  // @ghidraAddress 0x28fa24
static const float kBoardPhonePanelBgSize = 74.0f;                 // @ghidraAddress 0x28fa28
static const float kBoardPhoneGridWidthSpan = 334.0f;              // @ghidraAddress 0x28fa2c
static const float kBoardPhoneGridOriginBase = 90.0f;              // @ghidraAddress 0x28f968

@implementation ScratchBoardView {
    UIImageView *bgImageView; // +0x8
    UIImageView *svbg[16];    // +0x10 (16 × id)
    ScratchView *sv[16];      // +0x90 (16 × id)
    ScratchMessageView *smv;  // +0x110
    // _aDelegate (weak) at +0x118 is synthesised.
}

// aDelegate/setADelegate: are the synthesised accessors; -setDelegate: forwards through
// setADelegate:.
@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0x818ac */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    float rate = ChallengeStatus.sharedStatus.phoneScreenRate;
    self.opaque = NO;
    self.layer.doubleSided = NO;

    // The board background fills its natural size, scaled to the phone.
    UIImage *bgImage = LoadScaledPngImage(kBoardBackgroundImageName);
    int bgWidth = (int)bgImage.size.width;
    int bgHeight = (int)bgImage.size.height;
    if (!isPad) {
        bgWidth = (int)(rate * (float)bgWidth);
        bgHeight = (int)(rate * (float)bgHeight);
    }
    bgImageView = [[UIImageView alloc] initWithImage:bgImage];
    bgImageView.frame = CGRectMake(0, 0, bgWidth, bgHeight);
    [self addSubview:bgImageView];

    // The cell width and height, and the derived per-cell step (cellWidth / 4).
    int cellWidth = isPad ? kBoardCellWidthPad :
                            (int)(rate * kBoardPhoneCellWidthBase * kBoardPhoneCellWidthSpan);
    int cellHeight = isPad ? kBoardCellHeightPad : (int)(rate * kBoardPhoneCellHeight);
    int step = cellWidth / kBoardColumns;
    int cellInset = step - cellHeight;
    if (cellInset < 0) {
        cellInset += 1;
    }

    // The grid's vertical origin: pushed up from the bottom on the pad, centred within the phone's
    // scaled span otherwise.
    CGFloat gridOriginY;
    if (isPad) {
        gridOriginY = (frame.size.height - (step * kBoardColumns)) + kBoardGridBottomInset;
    } else {
        gridOriginY =
            (CGFloat)(rate * kBoardPhoneGridOriginBase +
                      (rate * kBoardPhoneGridWidthSpan - (float)(step * kBoardColumns)) * 0.5f);
    }

    // The panel-background square size, and its inset within a cell.
    UIImage *panelBg = LoadScaledPngImage(kBoardPanelBackgroundImageName);
    int panelBgSize = (int)(rate * kBoardPhonePanelBgSize);
    int panelBgInset = isPad ? -1 : ((cellHeight - panelBgSize) / 2);
    CGFloat panelBgSquare = isPad ? kBoardPanelBgSizePad : (CGFloat)panelBgSize;

    for (int i = 0; i < kBoardPanelCount; ++i) {
        int cellX = (int)((cellInset / 2) + (frame.size.width - cellWidth) * 0.5 +
                          (i % kBoardColumns) * step);
        int cellY = (int)gridOriginY + (cellInset / 2) + (i / kBoardColumns) * step;

        // The panel background sits inset within the cell.
        svbg[i] = [[UIImageView alloc] initWithFrame:CGRectMake(cellX + panelBgInset,
                                                                cellY + panelBgInset,
                                                                panelBgSquare,
                                                                panelBgSquare)];
        svbg[i].image = panelBg;
        [self addSubview:svbg[i]];

        // The scratch panel fills the cell square.
        sv[i] =
            [[ScratchView alloc] initWithFrame:CGRectMake(cellX, cellY, cellHeight, cellHeight)];
        sv[i].tag = i;
        [sv[i] updateView:NO];
        [self addSubview:sv[i]];
    }

    // The message view at the board's foot.
    CGFloat messageWidth = isPad ? kBoardMessageWidthPad : kBoardMessageWidthPhone;
    CGFloat messageHeight = isPad ? kBoardMessageHeightPad : kBoardMessageHeightPhone;
    smv = [[ScratchMessageView alloc] initWithFrame:CGRectMake(0, 0, messageWidth, messageHeight)];
    [self addSubview:smv];
    return self;
}

#pragma mark - Delegate

/** @ghidraAddress 0x81e00 */
- (void)setDelegate:(id)delegate {
    [self setADelegate:delegate];
    for (int i = 0; i < kBoardPanelCount; ++i) {
        [sv[i] setADelegate:delegate];
    }
}

#pragma mark - Refresh

/** @ghidraAddress 0x81f58 */
- (void)refreshScratchCount {
    [smv setScratchCnt:ChallengeStatus.sharedStatus.nailNum];
}

/** @ghidraAddress 0x81fcc */
- (void)refreshScratchTable {
    int nailNum = ChallengeStatus.sharedStatus.nailNum;
    int scratchablePanelNum = ChallengeStatus.sharedStatus.scratchablePanelNum;
    for (int i = 0; i < kBoardPanelCount; ++i) {
        [sv[i] updateView:NO];
        // A panel is enabled only when there are scratches and scratchable panels left and it is in
        // the scratchable state (1).
        BOOL disabled = scratchablePanelNum < 1 || nailNum < 1 || [sv[i] getState] != 1;
        [sv[i] setButtonEnable:disabled];
    }
}

/** @ghidraAddress 0x820f0 */
- (void)timerUpdate {
    for (int i = 0; i < kBoardPanelCount; ++i) {
        [sv[i] timerUpdate];
    }
    [smv timerUpdate];
}

@end
