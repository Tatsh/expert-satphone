#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The song-grid layout for the music-selection collection view.
 *
 * A @c UICollectionViewFlowLayout subclass that precomputes one
 * @c UICollectionViewLayoutAttributes per song cell in @c prepareLayout, arranging them into a
 * horizontally-paged grid whose column count, row count, cell size, inter-cell spacing, and margins
 * all vary by device idiom (@c isPad, @c is4Inch, and @c deviceType) and by the @c columnType
 * selector. It answers the content-size and attributes queries from that precomputed array, and
 * implements snap-to-page paging through the @c ignoreContentOffsetForProposedContentOffset: /
 * @c cancelIgnoreOffset machinery layered over the superclass's own paging.
 */
@interface MusicListCollectionLayout : UICollectionViewFlowLayout

/**
 * @brief The column-type selector: 0 is the three-column grid, 1 the four-column grid, and 2 the
 * five-column grid.
 * @ghidraAddress 0xd9e90
 * @ghidraAddress 0xd9ea0
 */
@property(nonatomic) int columnType;

/**
 * @brief Returns the horizontal spacing between adjacent cells for the given column type on the
 * current device idiom.
 * @param columnType The column-type selector.
 * @return The horizontal inter-cell spacing in points.
 * @ghidraAddress 0xd93c0
 */
- (int)getXSpace:(int)columnType;

/**
 * @brief Returns the vertical spacing between adjacent cell rows for the given column type on the
 * current device idiom.
 * @param columnType The column-type selector.
 * @return The vertical inter-row spacing in points.
 * @ghidraAddress 0xd943c
 */
- (int)getYSpace:(int)columnType;

/**
 * @brief Returns the leading horizontal margin for the given column type on the current device
 * idiom.
 * @param columnType The column-type selector.
 * @return The leading horizontal margin in points.
 * @ghidraAddress 0xd94e0
 */
- (int)getXMargin:(int)columnType;

/**
 * @brief Returns the leading vertical margin for the given column type on the current device idiom.
 * @param columnType The column-type selector.
 * @return The leading vertical margin in points.
 * @ghidraAddress 0xd955c
 */
- (int)getYMargin:(int)columnType;

/**
 * @brief Returns the number of items in the given section of the collection view.
 * @param section The section index.
 * @return The item count reported by the collection view's data source.
 * @ghidraAddress 0xd9b3c
 */
- (NSInteger)count:(int)section;

/**
 * @brief Records the superclass's target offset for the proposed offset and freezes it, so that the
 * next @c targetContentOffsetForProposedContentOffset: returns it verbatim.
 * @param proposedContentOffset The proposed content offset.
 * @return The frozen (dummy) content offset.
 * @ghidraAddress 0xd9da8
 */
- (CGPoint)ignoreContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset;

/**
 * @brief Clears the frozen-offset flag so paging resumes deferring to the superclass.
 * @ghidraAddress 0xd9e08
 */
- (void)cancelIgnoreOffset;

/**
 * @brief Returns the cell scale factor for the current column type.
 * @return The scale factor applied to each cell.
 * @ghidraAddress 0xd9e74
 */
- (CGFloat)frameScale;

/**
 * @brief Caches the device idiom and clears the paging state.
 * @return The initialised layout.
 * @ghidraAddress 0xd9600
 */
- (instancetype)init;

/**
 * @brief Tears the layout down.
 * @ghidraAddress 0xd9748
 */
- (void)dealloc;

/**
 * @brief Lays the grid out, filling the cached attributes and the content width.
 * @ghidraAddress 0xd97b0
 */
- (void)prepareLayout;

/**
 * @brief The laid-out content size.
 * @return The computed content width by the collection view's own height.
 * @ghidraAddress 0xd9b90
 */
- (CGSize)collectionViewContentSize;

/**
 * @brief The attributes of every cell intersecting a rectangle.
 * @param rect The rectangle to test against.
 * @return The attributes of the cells that intersect @p rect .
 * @ghidraAddress 0xd9bf4
 */
- (nullable NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:
    (CGRect)rect;

/**
 * @brief The attributes of one cell.
 * @param indexPath The cell's index path.
 * @return The cell's layout attributes.
 * @ghidraAddress 0xd9d5c
 */
- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:
    (NSIndexPath *)indexPath;

/**
 * @brief Whether a bounds change invalidates the layout.
 * @param newBounds The proposed new bounds.
 * @return Always NO; the layout does not depend on the bounds.
 * @ghidraAddress 0xd9da0
 */
- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds;

/**
 * @brief The content offset to settle on, honouring a frozen offset when one is set.
 * @param proposedContentOffset The offset the collection view proposes.
 * @return The frozen offset while one is set, otherwise the superclass's answer.
 * @ghidraAddress 0xd9e18
 */
- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
