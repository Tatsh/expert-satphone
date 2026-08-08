#import "CubePurchaseListView.h"

#import "AudioManager.h"
#import "CubePurchaseListViewCell.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The row plate art. The second image is loaded but its result is discarded, as in the binary.
static NSString *const kPlateImageName = @"cube_pur_plate";
static NSString *const kUnusedListBackgroundName = @"scratch_list_bg";
static NSString *const kPlateLabelImageName = @"cube_pur_plate_label";

// The digit artwork's name format and cache key for the label plate.
static NSString *const kDigitImageFormat = @"scratch_num_s0%d";
static NSString *const kPlateLabelCacheKey = @"cube_pur_plate_label";
static const int kDigitImageCount = 10;

// The reuse identifier for the list cells.
static NSString *const kCellReuseIdentifier = @"RivalListCell";

// The purchase-tap sound effect and its directory.
static NSString *const kPurchaseSoundName = @"SD_LABO_MENU";

// The row height, per idiom.
static const int kCellHeightPad = 0x60;
static const int kCellHeightPhone = 0x30;

@implementation CubePurchaseListView {
    UIImageView *listLineView; // +0x8
    UITableView *listView;     // +0x10
    NSArray *listArray;        // +0x18
    UIImage *plateBgImage0;    // +0x20
    UIImage *plateBgImage1;    // +0x28
    UIImage *plateBgPickup;    // +0x30
    int listWidth;             // +0x38
    int pickupSlot;            // +0x3c
    NSCache *numCache;         // +0x40
    int cellHeight;            // +0x48
}

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0x6480c */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }
    BOOL isPad = [JubeatAppDelegate appDelegate].isPad;
    plateBgImage0 = LoadScaledPngImage(kPlateImageName);
    (void)LoadScaledPngImage(kUnusedListBackgroundName); // Result discarded, as in the binary.

    // The table fills the whole view.
    listView =
        [[UITableView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)
                                     style:UITableViewStylePlain];
    listView.backgroundColor = UIColor.clearColor;
    listView.delegate = self;
    listView.dataSource = self;
    listView.separatorStyle = UITableViewCellSeparatorStyleNone;
    listView.bounces = NO;
    int rowHeight = isPad ? kCellHeightPad : kCellHeightPhone;
    listView.rowHeight = (CGFloat)rowHeight;
    [self addSubview:listView];
    cellHeight = rowHeight;

    // Preload the digit artwork and the label plate into a shared cache the cells draw from.
    numCache = [[NSCache alloc] init];
    for (int i = 0; i < kDigitImageCount; ++i) {
        UIImage *digit = LoadScaledPngImage([NSString stringWithFormat:kDigitImageFormat, i]);
        [numCache setObject:digit forKey:@(i)];
    }
    [numCache setObject:LoadScaledPngImage(kPlateLabelImageName) forKey:kPlateLabelCacheKey];
    return self;
}

#pragma mark - Data

/** @ghidraAddress 0x64b58 */
- (void)setListArray:(NSArray *)listArray_ {
    listArray = listArray_;
    [listView reloadData];
}

#pragma mark - Actions

/** @ghidraAddress 0x64bb4 */
- (void)tapPurchaseBtn:(UIView *)sender {
    [[AudioManager sharedManager] playSeResFile:kPurchaseSoundName inDirectory:nil];
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:sender.tag inSection:0];
    if ([self.aDelegate respondsToSelector:@selector(selectListCell:)]) {
        [self.aDelegate performSelector:@selector(selectListCell:) withObject:indexPath];
    }
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0x64d00 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"%@", kCellReuseIdentifier];
    CubePurchaseListViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[CubePurchaseListViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                               reuseIdentifier:identifier
                                                           tag:(int)indexPath.row];
    }
    cell.tag = indexPath.row;
    return cell;
}

/** @ghidraAddress 0x64f08 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0x64f10 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return listArray.count;
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0x64e38 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    [(CubePurchaseListViewCell *)cell setBgImage:plateBgImage0
                                            info:listArray[indexPath.row]
                                           cache:(NSMutableDictionary *)numCache
                                       aDelegate:self];
}

/** @ghidraAddress 0x64ef0 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return (CGFloat)cellHeight;
}

/** @ghidraAddress 0x64f28 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.aDelegate respondsToSelector:@selector(selectListCell:)]) {
        [self.aDelegate performSelector:@selector(selectListCell:) withObject:indexPath];
    }
}

@end
