#import "JcfManageNavController.h"

#import "JubeatAppDelegate.h"

// The wrapped downloaded-file list controller. Not reconstructed in this tree yet, so it is
// forward-declared. See TYPES_PENDING.md.
@interface EditFileListViewDeleteController : UIViewController
- (instancetype)initWithSize:(CGSize)size;
- (void)setFileList:(NSArray *)fileList;
- (void)setDelegate:(id)delegate;
- (void)setTargetFileName:(NSString *)targetFileName;
- (void)setIsShared:(BOOL)isShared;
- (void)setTuneID:(unsigned int)tuneID;
- (unsigned int)tuneID;
- (void)reloadTable;
@end

// The edit-data store; not reconstructed in this tree yet, so it is forward-declared. See
// TYPES_PENDING.md.
@interface EditDataManager : NSObject
+ (instancetype)sharedManager;
- (NSString *)getLastEditFileName:(int)tuneID;
@end

// The navigation-bar tint white components (from the __const pool). The alpha (1.0) arrives as an
// fmov immediate.
static const CGFloat kBarTintWhiteResponds = 0.6; // 0x28f230, when -setBarTintColor: exists
static const CGFloat kBarTintWhiteLegacy = 0.9;   // 0x28f448, when it does not

// The wrapped file list's size. Both components come from the __const pool.
static const CGFloat kFileListWidth = 300.0;  // 0x28f2d0
static const CGFloat kFileListHeight = 400.0; // 0x28f2e0

// The view background white component (from the __const pool). Alpha (1.0) is an fmov immediate.
static const CGFloat kViewBackgroundWhite = 0.8; // 0x28e080

// The iPad form-sheet frame decoration. The corner radius (8.0) and border width (2.0) are fmov
// immediates; the border white component comes from the __const pool.
static const CGFloat kPadBorderWhite = 0.7; // 0x291c98

@implementation JcfManageNavController {
    // The internal delegate, distinct from the public -aDelegate property. Set by the designated
    // initialiser and messaged by -pushClose:. Stored with objc_storeWeak.
    __weak id<JcfManageNavControllerDelegate> delegate; // +0x08
}

#pragma mark - Construction

/** @ghidraAddress 0x1f2284 */
- (instancetype)init:(id<JcfManageNavControllerDelegate>)delegateArg
            fileList:(NSArray *)fileList
             selName:(NSString *)selName {
    self = [super init];
    if (self) {
        delegate = delegateArg;
        self.modalPresentationStyle = UIModalPresentationFormSheet;
        self.navigationBar.barStyle = UIBarStyleBlack;
        self.navigationBar.translucent = NO;
        if ([self.navigationBar respondsToSelector:@selector(setBarTintColor:)]) {
            // The binary uses -performSelector:withObject: for -setBarTintColor: on older systems.
            [self.navigationBar performSelector:@selector(setBarTintColor:)
                                     withObject:[UIColor colorWithWhite:kBarTintWhiteResponds
                                                                  alpha:1.0]];
            self.navigationBar.tintColor = [UIColor colorWithWhite:kBarTintWhiteLegacy alpha:1.0];
        } else {
            self.navigationBar.tintColor = [UIColor colorWithWhite:kBarTintWhiteResponds alpha:1.0];
        }
        self.pFileListView = [[EditFileListViewDeleteController alloc]
            initWithSize:CGSizeMake(kFileListWidth, kFileListHeight)];
        UIBarButtonItem *closeButton = [[UIBarButtonItem alloc]
            initWithTitle:[NSBundle.mainBundle localizedStringForKey:@"Close" value:@"" table:nil]
                    style:UIBarButtonItemStyleDone
                   target:self
                   action:@selector(pushClose:)];
        self.pFileListView.navigationItem.leftBarButtonItem = closeButton;
        [self.pFileListView setFileList:fileList];
        [self.pFileListView setDelegate:delegateArg];
        [self.pFileListView setTargetFileName:selName];
        [self setViewControllers:@[ self.pFileListView ]];
    }
    return self;
}

/** @ghidraAddress 0x1f2804 */
- (instancetype)init {
    self = [super init];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationFormSheet;
        self.navigationBar.barStyle = UIBarStyleBlack;
        self.navigationBar.tintColor = [UIColor colorWithWhite:kBarTintWhiteResponds alpha:1.0];
        self.pFileListView = [[EditFileListViewDeleteController alloc]
            initWithSize:CGSizeMake(kFileListWidth, kFileListHeight)];
        UIBarButtonItem *closeButton = [[UIBarButtonItem alloc]
            initWithTitle:[NSBundle.mainBundle localizedStringForKey:@"Close" value:@"" table:nil]
                    style:UIBarButtonItemStyleDone
                   target:self
                   action:@selector(pushClose:)];
        self.pFileListView.navigationItem.leftBarButtonItem = closeButton;
        [self setViewControllers:@[ self.pFileListView ]];
    }
    return self;
}

#pragma mark - Forwarding

/** @ghidraAddress 0x1f2774 */
- (void)setShareFlg:(BOOL)shareFlg {
    [self.pFileListView setIsShared:shareFlg];
}

/** @ghidraAddress 0x1f27bc */
- (void)setTuneID:(unsigned int)tuneID {
    [self.pFileListView setTuneID:tuneID];
}

/** @ghidraAddress 0x1f2f28 */
- (void)reloadList:(NSArray *)fileList {
    if (self.pFileListView) {
        [self.pFileListView setFileList:fileList];
        [self.pFileListView
            setTargetFileName:[EditDataManager.sharedManager
                                  getLastEditFileName:(int)self.pFileListView.tuneID]];
        [self.pFileListView reloadTable];
    }
}

#pragma mark - Actions

/** @ghidraAddress 0x1f2d2c */
- (void)pushClose:(id)sender {
    // The binary messages the internal -delegate ivar here, not the public -aDelegate property.
    if ([delegate respondsToSelector:@selector(editFileListViewCancel:)]) {
        [delegate performSelector:@selector(editFileListViewCancel:) withObject:self];
    }
}

#pragma mark - View lifecycle

/** @ghidraAddress 0x1f2af4 */
- (void)loadView {
    [super loadView];
    self.view.backgroundColor = [UIColor colorWithWhite:kViewBackgroundWhite alpha:1.0];
    if (JubeatAppDelegate.appDelegate.isPad) {
        // The corner radius (8.0) and border width (2.0) are fmov immediates.
        self.view.layer.cornerRadius = 8.0;
        self.view.layer.borderWidth = 2.0;
        self.view.layer.borderColor = [UIColor colorWithWhite:kPadBorderWhite alpha:1.0].CGColor;
    }
}

/** @ghidraAddress 0x1f2dd0 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x1f2e08 */
- (void)viewDidUnload {
    [super viewDidUnload];
}

/** @ghidraAddress 0x1f2e40 */
- (BOOL)disablesAutomaticKeyboardDismissal {
    return NO;
}

/** @ghidraAddress 0x1f2e48 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x1f2e80 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x1f2eb8 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x1f2ef0 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Orientation

/** @ghidraAddress 0x1f30a0 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait or portrait-upside-down: the binary tests (orientation - 1) < 2 unsigned.
    return (unsigned)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x1f30b0 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x1f30b8 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
