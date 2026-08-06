#import "StoreLeafletCell.h"

#import "JubeatAppDelegate.h"

// The button's frame is a constant, not derived from the row: origin and width are all the same
// pool slot, and only the height differs.
static const CGFloat kOpenButtonOriginAndWidth = 100.0; // @ghidraAddress 0x28f3f0
static const CGFloat kOpenButtonHeight = 50.0;          // @ghidraAddress 0x28f2c8

static NSString *const kOpenButtonTitle = @"open";
// The pack the button opens is a literal, not anything the row was given.
static NSString *const kHardcodedPackID = @"10001";

@implementation StoreLeafletCell {
    BOOL isPad;
    UIButton *openBtn;
}

/** @ghidraAddress 0x1c56ec */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Captured and then never read — the ivar's offset global at 0x34ba40 has exactly two
        // references in the whole binary, its ivar-list entry and this one write.
        isPad = JubeatAppDelegate.appDelegate.isPad;

        openBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        openBtn.frame = CGRectMake(kOpenButtonOriginAndWidth,
                                   kOpenButtonOriginAndWidth,
                                   kOpenButtonOriginAndWidth,
                                   kOpenButtonHeight);
        openBtn.backgroundColor = UIColor.blueColor;
        [openBtn setTitle:kOpenButtonTitle forState:UIControlStateNormal];
        [openBtn addTarget:self
                      action:@selector(opendetail)
            forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:openBtn];
    }
    return self;
}

/** @ghidraAddress 0x1c5870 */
- (void)opendetail {
    // The pack identifier is the literal above rather than anything this row holds. The delegate is
    // loaded from the weak slot twice, once to test and once to send to.
    if ([self.aDelegate respondsToSelector:@selector(pushOpenDetail:)]) {
        [self.aDelegate performSelector:@selector(pushOpenDetail:) withObject:kHardcodedPackID];
    }
}

/** @ghidraAddress 0x1c5928 */
- (void)cache:(NSCache *)cache willEvictObject:(id)obj {
    // The binary's body is a single ret. Nothing is done when the cache evicts.
}

/** @ghidraAddress 0x1c592c */
- (void)dealloc {
    // Empty in the binary too: the only instruction is the super call, and the class has a
    // .cxx_destruct (0x1c5998), so that call is what ARC emits rather than anything written here.
}

@end
