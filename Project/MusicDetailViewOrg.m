#import "MusicDetailViewOrg.h"

#import <QuartzCore/QuartzCore.h>

#import "MusicSelectViewController.h"

@implementation MusicDetailViewOrg

/** @ghidraAddress 0x502bc */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

/** @ghidraAddress 0x5b3ec */
- (void)pushButtonEdit:(nullable id)sender {
    [self editStart];
}

/** @ghidraAddress 0x5b3a8 */
- (void)pushButtonUpload:(nullable id)sender {
    if ([self checkEnableUpload]) {
        [self uploadStart];
    }
}

/** @ghidraAddress 0x5d368 */
- (void)loadListRelease {
    [self.pFileListView setDelegate:nil];
    self.pFileListView = nil;
}

/** @ghidraAddress 0x5e2b4 */
- (void)popoverPresentationControllerDidDismissPopover:
    (nullable UIPopoverPresentationController *)popoverPresentationController {
    [self loadListRelease];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x5c4fc */
- (void)scrollViewWillBeginDragging:(nullable UIScrollView *)scrollView {
}

@end
