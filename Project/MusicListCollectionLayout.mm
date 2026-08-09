#import "MusicListCollectionLayout.h"

#import "JubeatAppDelegate.h"
#import "music_grid_layout.h"

namespace {

// Per-device, per-column-type grid metrics, read as 32-bit integers from __const. Each table is
// indexed by the column type (0, 1, or 2). The device idiom selects which table applies: the iPad,
// the two 4.7-inch phones (device types three and four), the HD phone (device type five), and the
// remaining phones fall to their own tables. The two "phone default" margin tables coincide, so a
// single table serves both the horizontal and vertical default margins.

// Horizontal inter-cell spacing.
const int kMusicXSpacePad[] = {20, 18, 14};       // @ghidraAddress 0x3538d4
const int kMusicXSpacePhone[] = {5, 4, 3};        // @ghidraAddress 0x353904
const int kMusicXSpacePhoneHD47[] = {12, 12, 10}; // @ghidraAddress 0x353940
const int kMusicXSpacePhoneHD[] = {30, 5, 7};     // @ghidraAddress 0x353970

// Vertical inter-row spacing.
const int kMusicYSpacePad[] = {6, 16, 20};        // @ghidraAddress 0x3538e0
const int kMusicYSpacePhone[] = {5, 8, 6};        // @ghidraAddress 0x35391c
const int kMusicYSpacePhone4Inch[] = {5, 10, 10}; // @ghidraAddress 0x353910
const int kMusicYSpacePhoneHD47[] = {5, 14, 16};  // @ghidraAddress 0x35394c
const int kMusicYSpacePhoneHD[] = {17, 8, 13};    // @ghidraAddress 0x35397c

// Leading horizontal margin.
const int kMusicXMarginPad[] = {24, 20, 18};       // @ghidraAddress 0x3538ec
const int kMusicXMarginPhoneHD47[] = {20, 13, 12}; // @ghidraAddress 0x353958
const int kMusicXMarginPhoneHD[] = {12, 7, 6};     // @ghidraAddress 0x353988

// Leading vertical margin.
const int kMusicYMarginPad[] = {10, 10, 10};        // @ghidraAddress 0x3538f8
const int kMusicYMarginPhone4Inch[] = {10, 10, 10}; // @ghidraAddress 0x353934
const int kMusicYMarginPhoneHD47[] = {10, 10, 8};   // @ghidraAddress 0x353964
const int kMusicYMarginPhoneHD[] = {10, 10, 8};     // @ghidraAddress 0x353994

// Shared default margin for the remaining phones, used by both the horizontal and vertical margin.
const int kMusicMarginPhoneDefault[] = {2, 2, 2}; // @ghidraAddress 0x353928

// Base cell dimensions in points, applied before the frame scale, read as 32-bit floats from
// __const. The height depends on the idiom (iPad, or a phone selected by the 4-inch aspect flag),
// and the width on whether this is an iPad.
const float kMusicCellHeightBasePad = 210.0f;               // @ghidraAddress 0x291dc8
const float kMusicCellHeightBasePhone[] = {106.0f, 101.0f}; // @ghidraAddress 0x291dd0
const float kMusicCellWidthBase[] = {100.0f, 220.0f};       // @ghidraAddress 0x291dd8

// The cell centre sits half a stride in from the cell's leading edge. The 0.5 factor reaches the
// code as an fmov immediate at 0xd9998/0xd99a0, not as a pool load, so it carries no data address.
const float kMusicCenterHalf = 0.5f;

} // namespace

@implementation MusicListCollectionLayout {
    BOOL isPad;
    BOOL is4Inch;
    int deviceType;
    NSMutableArray<UICollectionViewLayoutAttributes *> *elementsArray;
    double contentsWidth;
    BOOL ignoreOffset;
    CGPoint dummyOffset;
}

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        ignoreOffset = NO;
        isPad = JubeatAppDelegate.appDelegate.isPad;
        deviceType = (int)JubeatAppDelegate.appDelegate.deviceType;
        is4Inch = JubeatAppDelegate.appDelegate.is4inchAspect;
        elementsArray = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc {
    [elementsArray removeAllObjects];
    elementsArray = nil;
}

#pragma mark - Device metrics

- (int)getXSpace:(int)columnType {
    if (isPad) {
        return kMusicXSpacePad[columnType];
    }
    if (deviceType == JubeatDeviceTypePhoneRetina47Inch ||
        deviceType == JubeatDeviceTypePhoneRetinaHD47Inch) {
        return kMusicXSpacePhoneHD47[columnType];
    }
    if (deviceType == JubeatDeviceTypePhoneRetinaHD) {
        return kMusicXSpacePhoneHD[columnType];
    }
    return kMusicXSpacePhone[columnType];
}

- (int)getYSpace:(int)columnType {
    if (isPad) {
        return kMusicYSpacePad[columnType];
    }
    if (deviceType == JubeatDeviceTypePhoneRetina47Inch ||
        deviceType == JubeatDeviceTypePhoneRetinaHD47Inch) {
        return kMusicYSpacePhoneHD47[columnType];
    }
    if (deviceType == JubeatDeviceTypePhoneRetinaHD) {
        return kMusicYSpacePhoneHD[columnType];
    }
    return is4Inch ? kMusicYSpacePhone4Inch[columnType] : kMusicYSpacePhone[columnType];
}

- (int)getXMargin:(int)columnType {
    if (isPad) {
        return kMusicXMarginPad[columnType];
    }
    if (deviceType == JubeatDeviceTypePhoneRetina47Inch ||
        deviceType == JubeatDeviceTypePhoneRetinaHD47Inch) {
        return kMusicXMarginPhoneHD47[columnType];
    }
    if (deviceType == JubeatDeviceTypePhoneRetinaHD) {
        return kMusicXMarginPhoneHD[columnType];
    }
    return kMusicMarginPhoneDefault[columnType];
}

- (int)getYMargin:(int)columnType {
    if (isPad) {
        return kMusicYMarginPad[columnType];
    }
    if (deviceType == JubeatDeviceTypePhoneRetina47Inch ||
        deviceType == JubeatDeviceTypePhoneRetinaHD47Inch) {
        return kMusicYMarginPhoneHD47[columnType];
    }
    if (deviceType == JubeatDeviceTypePhoneRetinaHD) {
        return kMusicYMarginPhoneHD[columnType];
    }
    return is4Inch ? kMusicYMarginPhone4Inch[columnType] : kMusicMarginPhoneDefault[columnType];
}

- (CGFloat)frameScale {
    return GetMusicCellScaleForColumnType(self.columnType);
}

#pragma mark - Data source counts

- (NSInteger)count:(int)section {
    return [self.collectionView numberOfItemsInSection:section];
}

#pragma mark - Layout

- (void)prepareLayout {
    [elementsArray removeAllObjects];
    int columns = GetMusicGridColumnCount(self.columnType);
    float scale = (float)self.frameScale;
    float heightBase;
    if (isPad) {
        heightBase = kMusicCellHeightBasePad;
    } else {
        heightBase = kMusicCellHeightBasePhone[is4Inch ? 1 : 0];
    }
    NSInteger itemCount = [self count:0];
    // The bounds width is truncated to an integer page width for the horizontal paging.
    int boundsWidth = (int)self.collectionView.bounds.size.width;
    int xSpace = [self getXSpace:self.columnType];
    int rows = GetMusicGridRowCount(self.columnType);
    int cellsPerPage = rows * columns;
    int xMargin = [self getXMargin:self.columnType];
    int yMargin = [self getYMargin:self.columnType];
    if (itemCount >= 1) {
        int cellHeight = (int)(scale * heightBase);
        int cellWidth = (int)(scale * kMusicCellWidthBase[isPad ? 1 : 0]);
        int columnStride = xSpace + cellWidth;
        float halfColumnStride = columnStride * kMusicCenterHalf;
        float halfCellHeight = cellHeight * kMusicCenterHalf;
        for (NSInteger i = 0; i < itemCount; ++i) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:0];
            UICollectionViewLayoutAttributes *attributes =
                [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
            int index = (int)i;
            int rowIndex = index / columns;
            int page = index / cellsPerPage;
            int pageRow = rowIndex / rows;
            int column = index - rowIndex * columns;
            // The binary refetches the vertical spacing on every item; kept for fidelity.
            int ySpace = [self getYSpace:self.columnType];
            int rowWithinPage = rowIndex - pageRow * rows;
            float centerX =
                halfColumnStride + (float)(xMargin + column * columnStride + page * boundsWidth);
            float centerY =
                halfCellHeight + (float)(yMargin + (ySpace + cellHeight) * rowWithinPage);
            attributes.center = CGPointMake(centerX, centerY);
            attributes.size = CGSizeMake(cellWidth, cellHeight);
            [elementsArray addObject:attributes];
        }
    }
    int pages = ((int)itemCount + cellsPerPage - 1) / cellsPerPage;
    contentsWidth = (double)(pages * boundsWidth);
}

- (CGSize)collectionViewContentSize {
    return CGSizeMake(contentsWidth, self.collectionView.bounds.size.height);
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect {
    NSInteger itemCount = [self count:0];
    NSMutableArray<UICollectionViewLayoutAttributes *> *result = [NSMutableArray array];
    for (NSInteger i = 0; i < itemCount; ++i) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:0];
        UICollectionViewLayoutAttributes *attributes =
            [self layoutAttributesForItemAtIndexPath:indexPath];
        if (CGRectIntersectsRect(rect, attributes.frame)) {
            [result addObject:attributes];
        }
    }
    return result;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    return elementsArray[indexPath.item];
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return NO;
}

#pragma mark - Paging

- (CGPoint)ignoreContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset {
    ignoreOffset = YES;
    dummyOffset = [super targetContentOffsetForProposedContentOffset:proposedContentOffset];
    return dummyOffset;
}

- (void)cancelIgnoreOffset {
    ignoreOffset = NO;
}

- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset {
    if (ignoreOffset) {
        return dummyOffset;
    }
    return [super targetContentOffsetForProposedContentOffset:proposedContentOffset];
}

@end
