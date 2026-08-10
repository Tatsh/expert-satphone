#import "MusicDetailViewOrg.h"

#import <QuartzCore/QuartzCore.h>

@implementation MusicDetailViewOrg

/** @ghidraAddress 0x502bc */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

/** @ghidraAddress 0x5b3ec */
- (void)pushButtonEdit:(nullable id)sender {
    [self editStart];
}

/** @ghidraAddress 0x5c4fc */
- (void)scrollViewWillBeginDragging:(nullable UIScrollView *)scrollView {
}

@end
