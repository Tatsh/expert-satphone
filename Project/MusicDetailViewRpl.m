#import "MusicDetailViewRpl.h"

#import <QuartzCore/QuartzCore.h>

@implementation MusicDetailViewRpl

/** @ghidraAddress 0x12ad40 */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

/** @ghidraAddress 0x135630 */
- (void)pushButtonEdit:(nullable id)sender {
    [self editStart];
}

/** @ghidraAddress 0x1366a0 */
- (void)scrollViewWillBeginDragging:(nullable UIScrollView *)scrollView {
}

@end
