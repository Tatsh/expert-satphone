#import "StoreTableCell.h"

// The tile geometry, the pooled doubles at 0x2932b0 and 0x28f6b8. The left tile sits at the origin
// and the right one exactly one tile-width across, so the pair tiles the row edge to edge with no
// gutter between them.
static const CGFloat kPackTileWidth = 365.0;
static const CGFloat kPackTileHeight = 124.0;

@implementation StoreTableCell

/** @ghidraAddress 0x1531ac */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        // Both properties are readonly, so these are direct ivar assignments.
        _leftPackView = [[StorePackView alloc]
            initWithFrame:CGRectMake(0.0, 0.0, kPackTileWidth, kPackTileHeight)];
        _rightPackView = [[StorePackView alloc]
            initWithFrame:CGRectMake(kPackTileWidth, 0.0, kPackTileWidth, kPackTileHeight)];

        // Added to the contentView, unlike the three lower-case cell classes, which add to the cell
        // itself. -contentView is sent twice, once per tile.
        [self.contentView addSubview:self.leftPackView];
        [self.contentView addSubview:self.rightPackView];
    }
    return self;
}

/** @ghidraAddress 0x153328 */
- (void)dealloc {
    // Both tiles are owned strongly, so they outlive nothing — but their delegate is not, and this
    // clears it before the cell goes away. Without it a tile could message a dead delegate.
    //
    // The binary's [super dealloc] at 0x153390 is not written here: under ARC the compiler emits
    // that call itself and writing it is an error.
    _leftPackView.delegate = nil;
    _rightPackView.delegate = nil;
}

@end
