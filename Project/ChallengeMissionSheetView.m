#import "ChallengeMissionSheetView.h"

#import "ChallengeMissionSheet.h"
#import "ChallengeMissionSheetCell.h"
#import "MissionDetailMessageView.h"
#import "MissionRewardDownloadView.h"
#import "SessionDownloader.h"

// The mission row cells occupy a fixed sixteen-slot array (metadata ivar encoding
// [16@"ChallengeMissionSheetCell"]).
static const NSUInteger kStampCellCount = 16;

@implementation ChallengeMissionSheetView {
    UIImageView *bgImageView;
    UIView *bgView;
    ChallengeMissionSheetCell *stampCell[kStampCellCount];
    UIImageView *missionDetailMarker;
    UILabel *title;
    UIButton *closeBtn;
    UIButton *sheetSetBtn;
    UIButton *rewardBtn;
    UIButton *missionExpBtn;
    NSDictionary *sheetInfo;
    ChallengeMissionSheet *missionSheet;
    BOOL bSheetReady;
    SessionDownloader *downloader;
    UIActivityIndicatorView *downloadIndicator;
    BOOL winDisplayON;
    int cellSize;
    int cellMargin;
    UILabel *detailText;
    UIButton *detailTextBtn;
    BOOL detailEnable;
    MissionDetailMessageView *detailWindow;
    MissionRewardDownloadView *rewardDownloadView;
    int selectedIndex;
    int clearCnt;
    int totalCnt;
    BOOL _bDownloadEnd;
}

// The metadata keeps distinctly named backing ivars for both properties, so both are synthesised
// onto those names rather than the default _propertyName.
@synthesize aDelegate = _aDelegate;
@synthesize bDownloadEnd = _bDownloadEnd;

// The shipped class implements no methods of its own: the four in its metadata are the two
// synthesised aDelegate/setADelegate: accessors (0x9f678, 0x9f698), the synthesised bDownloadEnd
// getter (0x9f668), and ARC's .cxx_destruct (0x9f6ac). Nothing writes any ivar, so there is no
// initWithFrame:sheetID: or refreshSheetInfo body to reconstruct.

@end
