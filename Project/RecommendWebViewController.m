#import "RecommendWebViewController.h"

// RecommendCore backs the recommendation routing; not reconstructed as its own file yet. See
// TYPES_PENDING.md.
@interface RecommendCore : NSObject
@property(class, nonatomic, readonly) RecommendCore *sharedInstance;
- (int)redirectViewContollerWithRequest:(NSURLRequest *)request;
- (void)showVideoViewWithQuery:(id)query;
@end

// The binary defines a -removeFromSuperview on this controller (a coincidental selector name, not
// the UIView method), verified against the metadata.
@interface RecommendWebViewController ()
- (void)removeFromSuperview;
@end

@implementation RecommendWebViewController

#pragma mark - Lifecycle

/** @ghidraAddress 0x22b7d0 */
- (void)viewDidLoad {
    [super viewDidLoad];
}

/** @ghidraAddress 0x22b80c */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x22b848 */
- (void)viewDidUnload {
    // Unusually, the view is detached from its superview before the super call.
    [self.view removeFromSuperview];
    [super viewDidUnload];
}

/** @ghidraAddress 0x22b9c4 */
- (void)dealloc {
    // [super dealloc] is compiler-emitted (ARC); the binary tail-calls the superclass dealloc.
}

#pragma mark - Recommendation routing

/** @ghidraAddress 0x22b8c4 */
- (int)redirectWithRequest:(NSURLRequest *)request {
    return [RecommendCore.sharedInstance redirectViewContollerWithRequest:request];
}

/** @ghidraAddress 0x22b948 */
- (void)showVideoViewWithQuery:(id)query {
    [RecommendCore.sharedInstance showVideoViewWithQuery:query];
}

/** @ghidraAddress 0x22b9c0 */
- (void)removeFromSuperview {
    // A deliberate no-op override.
}

@end
