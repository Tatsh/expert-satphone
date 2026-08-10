#import "MusicDetailViewRpl.h"

#import <QuartzCore/QuartzCore.h>

#import "MusicSelectViewController.h"

@implementation MusicDetailViewRpl

/** @ghidraAddress 0x12ad40 */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

/** @ghidraAddress 0x135630 */
- (void)pushButtonEdit:(nullable id)sender {
    [self editStart];
}

/** @ghidraAddress 0x13554c */
- (void)pushButtonUpload:(nullable id)sender {
    if ([self checkEnableUpload]) {
        [self uploadStart];
    }
}

/** @ghidraAddress 0x13752c */
- (void)loadListRelease {
    [self.pFileListView setDelegate:nil];
    self.pFileListView = nil;
}

/** @ghidraAddress 0x1384d4 */
- (void)popoverPresentationControllerDidDismissPopover:
    (nullable UIPopoverPresentationController *)popoverPresentationController {
    [self loadListRelease];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x1366a0 */
- (void)scrollViewWillBeginDragging:(nullable UIScrollView *)scrollView {
}

@end
