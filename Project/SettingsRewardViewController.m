#import "SettingsRewardViewController.h"

#import "AlertViewManager.h"
#import "ApplilinkNetwork.h"
#import "EditorIDManager.h"
#import "JubeatAppDelegate.h"
#import "RewardNetwork.h"

// The ad location the settings reward area is opened at.
static NSString *const kAdLocationTop = @"ADL_TOP";

// The pad frame dimensions; on the phone the frame follows the screen bounds less a top inset.
static const CGFloat kPadWidth = 540.0;
static const CGFloat kPadHeight = 576.0;
static const CGFloat kPhoneHeightInset = -44.0;

// The loading spinner's scale-up factor.
static const float kIndicatorScale = 1.5f;

// The raw supported-orientation mask the binary returns: 6, i.e. portrait and portrait-upside-down
// (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown). Kept as the
// literal the binary uses rather than a named mask, since it is not one of the common combinations.
static const UIInterfaceOrientationMask kSupportedOrientations =
    UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;

// The informal reward ad-area view-delegate callbacks this controller implements. They are invoked
// by the reward network when the hosted advert screen loads, disappears, or fails.
@interface SettingsRewardViewController () <EditorIDManagerDelegate> {
    UIView *bgView;             // +0x8
    UIWebView *rewardView;      // +0x10
    EditorIDManager *idManager; // +0x18
    BOOL bRewardOpen;           // +0x20
}
- (void)openRewardView;
- (void)appListDidAppear;
- (void)appListDidDisappear;
- (void)appListFailLoadWithError:(nullable NSError *)error;
@end

@implementation SettingsRewardViewController

@synthesize indicatorView = _indicatorView;

#pragma mark - Construction

/** @ghidraAddress 0x20a250 */
- (instancetype)init {
    self = [super init];
    if (!self) {
        return self;
    }
    // The pad uses a fixed 540×576 area; the phone follows the screen bounds less a 44 pt top
    // inset.
    CGFloat width = kPadWidth;
    CGFloat height = kPadHeight;
    if (![JubeatAppDelegate appDelegate].isPad) {
        CGRect bounds = [UIScreen mainScreen].bounds;
        width = bounds.size.width;
        height = bounds.size.height + kPhoneHeightInset;
    }

    bgView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    bgView.backgroundColor = UIColor.grayColor;
    [self.view addSubview:bgView];

    rewardView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    [self.view addSubview:rewardView];
    bRewardOpen = NO;
    if (EditorIDManager.isExistEditorID) {
        [self openRewardView];
    } else {
        idManager = [[EditorIDManager alloc] initWithDelegate:self];
    }

    self.indicatorView = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [self.indicatorView.layer setValue:@(kIndicatorScale) forKeyPath:@"transform.scale"];
    self.indicatorView.center = bgView.center;
    [self.indicatorView startAnimating];
    [bgView addSubview:self.indicatorView];
    return self;
}

#pragma mark - Reward ad-area control

/** @ghidraAddress 0x20a67c */
- (void)openRewardView {
    rewardView.alpha = 0;
    [ApplilinkNetwork setUserId:[EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]]];
    [RewardNetwork setNavigationBarHidden:YES];
    [RewardNetwork openAdScreenWithParentView:rewardView adLocation:kAdLocationTop delegate:self];
    bRewardOpen = YES;
}

#pragma mark - Reward ad-area delegate

/** @ghidraAddress 0x20a77c */
- (void)appListDidAppear {
    [self.indicatorView stopAnimating];
    rewardView.alpha = 0;
    __weak UIWebView *weakRewardView = rewardView;
    [UIView animateWithDuration:0.5
        animations:^{
          /** @ghidraAddress 0x20a8e4 */
          weakRewardView.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x20a930 */
          self->rewardView.alpha = 1.0;
        }];
}

/** @ghidraAddress 0x20a960 */
- (void)appListDidDisappear {
    // Empty in the binary.
}

/** @ghidraAddress 0x20a964 */
- (void)appListFailLoadWithError:(NSError *)error {
    [self.indicatorView stopAnimating];
    (void)[error code]; // Yes, the binary reads the code and discards it.
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:nil
                                            msg:@"通信エラー"
                                         cancel:ok
                                        btnText:nil
                                           show:YES
                                 viewController:self];
}

#pragma mark - Editor ID download delegate

/** @ghidraAddress 0x20aaa8 */
- (void)errorIDDownload:(id)manager msgStr:(NSString *)msgStr {
    // The server-supplied msgStr is ignored; a fixed communication-error alert is shown instead.
    idManager = nil;
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:nil
                                            msg:@"通信エラー"
                                         cancel:ok
                                        btnText:nil
                                           show:YES
                                 viewController:self];
}

/** @ghidraAddress 0x20aba4 */
- (void)successIDDownload:(id)manager {
    idManager = nil;
    [self openRewardView];
}

#pragma mark - Lifecycle and rotation

/** @ghidraAddress 0x20abe0 */
- (void)viewWillDisappear:(BOOL)animated {
    if (idManager != nil) {
        [idManager cancel];
    }
    if (bRewardOpen) {
        [RewardNetwork closeAdScreen];
    }
    [[AlertViewManager sharedManager] closeAlert];
}

/** @ghidraAddress 0x20ac6c */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait and portrait-upside-down (orientations 1 and 2), matching the mask of 6. The binary
    // compares (orientation - 1) unsigned against 2, so orientation 0 (unknown) wraps to a large
    // value and is refused.
    return (NSUInteger)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x20ac7c */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return kSupportedOrientations;
}

/** @ghidraAddress 0x20ac84 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
