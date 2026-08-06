#import "StoreRecommendTableCell.h"

// Both tiles are this tall whichever initialiser built them.
static const CGFloat kPackViewHeight = 124.0; // @ghidraAddress 0x28f6b8

// The style-taking initialiser does not measure anything, so its tiles take this fixed width.
static const CGFloat kFixedPackViewWidth = 325.0; // @ghidraAddress 0x293338

@implementation StoreRecommendTableCell

/** @ghidraAddress 0x165bf4 */
- (instancetype)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier {
    // Note this chains to the superclass's style-taking initialiser, not to the one below, so the
    // frame's origin and height never reach anything.
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        // Truncated to a whole number before either tile is placed, so the pair can fall one point
        // short of the row on an odd width rather than overlapping.
        CGFloat packWidth = (int)(frame.size.width / 2);

        _leftPackView = [[StoreRecommendPackView alloc]
            initWithFrame:CGRectMake(0, 0, packWidth, kPackViewHeight)];
        _rightPackView = [[StoreRecommendPackView alloc]
            initWithFrame:CGRectMake(packWidth, 0, packWidth, kPackViewHeight)];

        // The content view is fetched again for the second tile rather than held in a local.
        [self.contentView addSubview:_leftPackView];
        [self.contentView addSubview:_rightPackView];
    }
    return self;
}

/** @ghidraAddress 0x165d88 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _leftPackView = [[StoreRecommendPackView alloc]
            initWithFrame:CGRectMake(0, 0, kFixedPackViewWidth, kPackViewHeight)];
        _rightPackView = [[StoreRecommendPackView alloc]
            initWithFrame:CGRectMake(kFixedPackViewWidth, 0, kFixedPackViewWidth, kPackViewHeight)];

        [self.contentView addSubview:_leftPackView];
        [self.contentView addSubview:_rightPackView];
    }
    return self;
}

/** @ghidraAddress 0x165f04 */
- (void)dealloc {
    // The tiles hold weak, unretained back-pointers to this cell, and clearing them is the whole
    // reason this method exists. ARC's own .cxx_destruct at 0x165fa0 releases the tiles
    // themselves; it cannot know to break the link first.
    _leftPackView.delegate = nil;
    _rightPackView.delegate = nil;
}

@end
