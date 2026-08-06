#import "CustomSequencePageNavViewController.h"

// The one ivar, at offset global 0x34bd78. It has no accessor pair, so it is not a property, and
// the initialiser writes it through objc_storeWeak rather than objc_storeStrong.
@interface CustomSequencePageNavViewController () {
    __weak id delegate;
}
@end

@implementation CustomSequencePageNavViewController

/** @ghidraAddress 0x1e587c */
- (instancetype)initWithStyle:(UITableViewStyle)style delegate:(id)aDelegate {
    // The style goes straight to the superclass; only the delegate is this class's own business.
    self = [super initWithStyle:style];
    if (self != nil) {
        delegate = aDelegate;
    }
    return self;
}

@end
