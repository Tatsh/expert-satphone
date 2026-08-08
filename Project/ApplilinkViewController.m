#import "ApplilinkViewController.h"

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "ApplilinkCore.h"
#import "ApplilinkIndicator.h"
#import "ApplilinkParameters.h"
#import "ApplilinkStore.h"
#import "RotateStoreProductViewController.h"

@implementation ApplilinkViewController

@synthesize sdkDelegate = _sdkDelegate;
@synthesize applilinkParams = _applilinkParams;
@synthesize indicator = _indicator;

#pragma mark - View lifecycle

/** @ghidraAddress 0x241234 */
- (void)viewDidLoad {
    [super viewDidLoad];
}

/** @ghidraAddress 0x241270 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x2412ac */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x2412e8 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x241324 */
- (void)viewDidDisappear:(BOOL)animated {
    // The binary's body is empty here: it does not chain to super.
}

/** @ghidraAddress 0x241328 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Store presentation

/** @ghidraAddress 0x241364 */
- (void)showSKStore:(NSString *)appStoreId
           appParam:(ApplilinkParameters *)appParam
           delegate:(id<SdkViewDelegate>)delegate {
    // The binary stores both values straight into the backing ivars. The parameters are retained
    // rather than copied, so this keeps the caller's instance despite the copy attribute; the
    // delegate goes through the weak ivar's store.
    _applilinkParams = appParam;
    _sdkDelegate = delegate;

    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.backgroundColor = UIColor.clearColor;

    RotateStoreProductViewController *storeViewController =
        [[RotateStoreProductViewController alloc] init];
    [storeViewController setDelegate:self];

    self.indicator = [[ApplilinkIndicator alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.indicator];
    [self.indicator show];

    UIWindow *mainWindow = [ApplilinkCore mainWindow];
    if (mainWindow) {
        [mainWindow addSubview:self.view];
    }

    [self
        presentViewController:storeViewController
                     animated:YES
                   completion:^{
                     /** @ghidraAddress 0x241718 */
                     // Once the product sheet is on screen, ask it to load the product.
                     NSDictionary *parameters =
                         @{SKStoreProductParameterITunesItemIdentifier : appStoreId};
                     [storeViewController
                         loadProductWithParameters:parameters
                                   completionBlock:^(BOOL result, NSError *error) {
                                     /** @ghidraAddress 0x241820 */
                                     if (self.indicator) {
                                         [self.indicator removeFromSuperview];
                                     }
                                     self.indicator = nil;
                                     if (result) {
                                         if (self.sdkDelegate &&
                                             [self.sdkDelegate
                                                 respondsToSelector:
                                                     @selector(
                                                         appStoreOpenedNoticeWithAppParam:)]) {
                                             [self.sdkDelegate appStoreOpenedNoticeWithAppParam:
                                                                   self.applilinkParams];
                                         }
                                         return;
                                     }
                                     // On failure the whole overlay is removed; on success the
                                     // view stays behind to present the sheet.
                                     [self.view removeFromSuperview];
                                     if (self.sdkDelegate &&
                                         [self.sdkDelegate
                                             respondsToSelector:
                                                 @selector(
                                                     appStoreFailLoadNoticeWithError:appParam:)]) {
                                         [self.sdkDelegate
                                             appStoreFailLoadNoticeWithError:error
                                                                    appParam:self.applilinkParams];
                                     }
                                   }];
                   }];
}

#pragma mark - SKStoreProductViewControllerDelegate

/** @ghidraAddress 0x241a9c */
- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    if (self.sdkDelegate &&
        [self.sdkDelegate respondsToSelector:@selector(appStoreCloseNoticeWithAppParam:)]) {
        [self.sdkDelegate appStoreCloseNoticeWithAppParam:self.applilinkParams];
    }
    [self dismissViewControllerAnimated:YES
                             completion:^{
                               /** @ghidraAddress 0x241bac */
                               [self.view removeFromSuperview];
                               if (self.sdkDelegate &&
                                   [self.sdkDelegate
                                       respondsToSelector:@selector(
                                                              appStoreClosedNoticeWithAppParam:)]) {
                                   [self.sdkDelegate
                                       appStoreClosedNoticeWithAppParam:self.applilinkParams];
                               }
                             }];
}

/** @ghidraAddress 0x241cc0 */
- (void)productViewControllerDidFinish {
    if (self.sdkDelegate &&
        [self.sdkDelegate respondsToSelector:@selector(appStoreCloseNoticeWithAppParam:)]) {
        [self.sdkDelegate appStoreCloseNoticeWithAppParam:self.applilinkParams];
    }
    [self dismissViewControllerAnimated:NO
                             completion:^{
                               /** @ghidraAddress 0x241dd0 */
                               [self.view removeFromSuperview];
                               if (self.sdkDelegate &&
                                   [self.sdkDelegate
                                       respondsToSelector:@selector(
                                                              appStoreClosedNoticeWithAppParam:)]) {
                                   [self.sdkDelegate
                                       appStoreClosedNoticeWithAppParam:self.applilinkParams];
                               }
                             }];
}

#pragma mark - Rotation

/** @ghidraAddress 0x241ee4 */
- (BOOL)shouldAutorotate {
    return YES;
}

/** @ghidraAddress 0x241eec */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // The binary returns the raw mask 0x1e (30) = Portrait | PortraitUpsideDown | LandscapeLeft |
    // LandscapeRight, which is exactly UIInterfaceOrientationMaskAll.
    return UIInterfaceOrientationMaskAll;
}

/** @ghidraAddress 0x241ef4 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

@end
