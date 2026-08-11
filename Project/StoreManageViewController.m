#import "StoreManageViewController.h"

#import "AlertViewManager.h"
#import "Downloader.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "StoreDialogView.h"
#import "StoreDownloadManager.h"
#import "StoreDownloadTask.h"
#import "StoreManageTableViewCell.h"
#import "StoreMusicInfo.h"
#import "StoreMusicListManager.h"
#import "StoreUtil.h"
#import "UIDevice+SystemVersionCheck.h"

// The parent store view controller is not yet reconstructed; it is messaged for its modal dialog
// and to show/hide it, and it is the back button's target for -storeEnd: .
@class StoreViewController;

@interface StoreViewController : UIViewController
- (StoreDialogView *)modalDialog;
- (void)showModalDialog:(id)controller;
- (void)hideModalDialog;
- (void)storeEnd:(id)sender;
@end

// The tab image and the two per-row action icons.
static NSString *const kTabImageName = @"tab_database";
static NSString *const kDeleteIconName = @"manage_delete";
static NSString *const kDownloadIconName = @"manage_download";

// The reuse identifier for the purchased-tune rows.
static NSString *const kStoreManageCellIdentifier = @"StoreManageCell";

// The dictionary keys read out of a purchased-tune record and out of an alert-result dictionary.
static NSString *const kMusicKeyID = @"ID";
static NSString *const kMusicKeyName = @"Name";
static NSString *const kMusicKeyArtist = @"Artist";
static NSString *const kMusicKeyItemURL = @"ItemURL";
static NSString *const kMusicKeyExtendID = @"extID";
static NSString *const kMusicKeyExtendURL = @"extURL";
static NSString *const kAlertKeyButtonMessage = @"btnMessage";
static NSString *const kAlertKeyTag = @"Tag";

// The sentinel stored in working_index when no row's action is in flight.
static const unsigned int kNoWorkingRow = 0xffffffff;

// The delete-confirmation alert's tag, and the button index that confirms it.
static const int kDeleteAlertTag = 1;
static const int kConfirmButtonIndex = 1;

@implementation StoreManageViewController {
    unsigned int working_index;
    BOOL isPad;
    __weak id<StoreParentViewController> storeViewCtrl;
    UITableView *tableView;
    Downloader *infoDownloader;
    StoreDownloadManager *dlManager;
    UIImage *imgDelete;
    UIImage *imgDownload;
    NSString *musicName;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x90c58 */
- (instancetype)initWithParent:(nullable id<StoreParentViewController>)parent {
    self = [super init];
    if (self) {
        storeViewCtrl = parent;
        self.navigationItem.title = [NSBundle.mainBundle localizedStringForKey:@"Manage Library"
                                                                         value:@""
                                                                         table:nil];
        self.tabBarItem.title = [NSBundle.mainBundle localizedStringForKey:@"Manage"
                                                                     value:@""
                                                                     table:nil];
        self.tabBarItem.image = LoadScaledPngImage(kTabImageName);
        if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
            [self performSelector:@selector(setExtendedLayoutIncludesOpaqueBars:) withObject:nil];
        }
        UIBarButtonItem *backItem = [[UIBarButtonItem alloc]
            initWithTitle:[NSBundle.mainBundle localizedStringForKey:@"Back" value:@"" table:nil]
                    style:UIBarButtonItemStyleDone
                   target:storeViewCtrl
                   action:@selector(storeEnd:)];
        self.navigationItem.leftBarButtonItem = backItem;
        imgDelete = LoadScaledPngImage(kDeleteIconName);
        imgDownload = LoadScaledPngImage(kDownloadIconName);
        isPad = JubeatAppDelegate.appDelegate.isPad;
        working_index = kNoWorkingRow;
    }
    return self;
}

/** @ghidraAddress 0x90f28 */
- (void)loadView {
    [super loadView];
    self.view.autoresizesSubviews = YES;
    CGRect bounds = self.view.bounds;

    // A vertical grey gradient filling the whole view.
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = bounds;
    gradient.opaque = YES;
    UIColor *topColor = [UIColor colorWithRed:0.725 green:0.731 blue:0.737 alpha:1.0];
    UIColor *bottomColor = [UIColor colorWithRed:0.467 green:0.489 blue:0.511 alpha:1.0];
    gradient.colors = @[ (__bridge id)topColor.CGColor, (__bridge id)bottomColor.CGColor ];
    [self.view.layer addSublayer:gradient];

    // The table fills the view below the tab header and above the tab footer.
    CGFloat headerHeight = [StoreUtil storeTabHeaderHeight];
    CGFloat footerHeight = [StoreUtil storeTabFooterHeight];
    CGRect tableFrame = CGRectMake(bounds.origin.x,
                                   bounds.origin.y,
                                   bounds.size.width,
                                   bounds.size.height - headerHeight - footerHeight);
    tableView = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
    // Row height: 50 on the phone, 60 on the pad. __const array indexed by isPad at 0x28fb10.
    tableView.rowHeight = isPad ? 60.0 : 50.0;
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.allowsSelection = NO;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    if ([UIDevice.currentDevice systemVersionGreaterEqual:@"9.0"]) {
        tableView.cellLayoutMarginsFollowReadableWidth = NO;
    }
    [self.view addSubview:tableView];
}

/** @ghidraAddress 0x9320c */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x93244 */
- (void)viewDidUnload {
    [super viewDidUnload];
    tableView = nil;
}

/** @ghidraAddress 0x9329c */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x932d4 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [tableView reloadData];
    [tableView flashScrollIndicators];
}

/** @ghidraAddress 0x93340 */
- (void)viewWillDisappear:(BOOL)animated {
    [AlertViewManager.sharedManager closeAlert];
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x933c8 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0x93420 */
- (void)dealloc {
    // The binary's -dealloc only chains to super: it cancels nothing and removes no observers.
    // The strong ivars are torn down by the compiler-generated .cxx_destruct (0x93458), which is
    // not authored here. [super dealloc] is compiler-emitted (ARC).
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0x91ca8 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView {
    return 1;
}

/** @ghidraAddress 0x91b84 */
- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    return StoreMusicListManager.sharedManager.purchasedMusic.count;
}

/** @ghidraAddress 0x91358 */
- (UITableViewCell *)tableView:(UITableView *)aTableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    StoreManageTableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:kStoreManageCellIdentifier];
    if (!cell) {
        cell = [[StoreManageTableViewCell alloc] initWithPad:isPad
                                             reuseIdentifier:kStoreManageCellIdentifier];
    }

    cell.btn.tag = indexPath.row;
    cell.tag = indexPath.row;

    // fmov immediates: 20 / 17 for the title, 16 / 14 for the detail (at 0x914b4, 0x91530).
    cell.textLabel.font = [UIFont boldSystemFontOfSize:isPad ? 20.0 : 17.0];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:isPad ? 16.0 : 14.0];
    /** @ghidraAddress 0x28f248 */
    cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.3 alpha:1.0];

    // Narrow the title label to leave room for the action button on the right.
    CGRect labelFrame = cell.textLabel.frame;
    /** @ghidraAddress 0x28fb08 */
    const CGFloat kTitleWidthInset = -200.0;
    labelFrame.size.width = cell.frame.size.width + kTitleWidthInset;
    cell.textLabel.frame = labelFrame;
    cell.textLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    [cell.btn addTarget:self
                  action:@selector(pushCellButton:)
        forControlEvents:UIControlEventTouchUpInside];

    NSDictionary *info = StoreMusicListManager.sharedManager.purchasedMusic[indexPath.row];
    unsigned int musicID = [info[kMusicKeyID] unsignedIntValue];
    NSString *path = [StoreUtil filePathForMusicID:musicID];
    BOOL isDirectory = NO;
    BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory];
    if (exists && !isDirectory) {
        [cell.btn setImage:imgDelete forState:UIControlStateNormal];
        if (isPad) {
            [cell.btn setTitle:[NSBundle.mainBundle localizedStringForKey:@"DELETE"
                                                                    value:@""
                                                                    table:nil]
                      forState:UIControlStateNormal];
        }
    } else {
        [cell.btn setImage:imgDownload forState:UIControlStateNormal];
        if (isPad) {
            [cell.btn setTitle:[NSBundle.mainBundle localizedStringForKey:@"DOWNLOAD"
                                                                    value:@""
                                                                    table:nil]
                      forState:UIControlStateNormal];
        }
    }

    // Right-align the button, vertically centred, at its fitted width and a fixed height.
    [cell.btn sizeToFit];
    CGFloat buttonWidth = cell.btn.frame.size.width;
    // Button height: 36 on the phone, 40 on the pad. __const array indexed by isPad at 0x28fb20.
    CGFloat buttonHeight = isPad ? 40.0 : 36.0;
    CGRect cellFrame = cell.frame;
    // fmov immediates: -10 right inset (0x91a30), 0.5 vertical-centre factor (0x91a48).
    CGFloat buttonX = cellFrame.size.width - buttonWidth - 10.0;
    CGFloat buttonY = (cellFrame.size.height - buttonHeight) * 0.5;
    cell.btn.frame = CGRectMake(buttonX, buttonY, buttonWidth, buttonHeight);

    cell.textLabel.text = info[kMusicKeyName];
    cell.detailTextLabel.text = info[kMusicKeyArtist];
    return cell;
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0x91bfc */
- (void)tableView:(UITableView *)aTableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    UIColor *background;
    if ((indexPath.row & 1) == 0) {
        /** @ghidraAddress 0x28e080 */
        background = [UIColor colorWithWhite:0.8 alpha:1.0];
    } else {
        background = UIColor.whiteColor;
    }
    cell.backgroundColor = background;
}

#pragma mark - Row action

/** @ghidraAddress 0x91cb0 */
- (void)pushCellButton:(nullable id)sender {
    if (working_index != kNoWorkingRow) {
        return;
    }
    working_index = (unsigned int)[(UIView *)sender tag];
    NSDictionary *info = StoreMusicListManager.sharedManager.purchasedMusic[working_index];
    unsigned int musicID = [info[kMusicKeyID] unsignedIntValue];
    NSString *path = [StoreUtil filePathForMusicID:musicID];
    BOOL isDirectory = NO;
    BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory];
    if (!exists || isDirectory) {
        // Nothing on disk: (re)download it. Show the modal dialog in its progress mode.
        StoreDialogView *dialog = storeViewCtrl.modalDialog;
        [dialog layout:NO];
        musicName = info[kMusicKeyName];
        dialog.labelMessage.text = [NSString
            stringWithFormat:[NSBundle.mainBundle localizedStringForKey:@"Downloading %@ ..."
                                                                  value:@""
                                                                  table:nil],
                             musicName];
        dialog.progressView.progress = 0;
        [storeViewCtrl showModalDialog:self];

        NSURL *infoURL = [StoreUtil musicInfoURL:musicID];
        infoDownloader = [[Downloader alloc] initWithURL:infoURL delegate:self];
        [infoDownloader startDownloading];
    } else {
        // Already owned: confirm the delete.
        NSString *message = [NSString
            stringWithFormat:[NSBundle.mainBundle localizedStringForKey:@"ManageDeleteMessage (%@)"
                                                                  value:@""
                                                                  table:nil],
                             info[kMusicKeyName]];
        NSString *title = [NSBundle.mainBundle localizedStringForKey:@"DELETE SONG"
                                                               value:@""
                                                               table:nil];
        NSString *cancel = [NSBundle.mainBundle localizedStringForKey:@"NO" value:@"" table:nil];
        NSString *confirm = [NSBundle.mainBundle localizedStringForKey:@"YES" value:@"" table:nil];
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:self
                                              tag:kDeleteAlertTag
                                            title:title
                                              msg:message
                                           cancel:cancel
                                          btnText:@[ confirm ]
                                             show:YES];
    }
}

#pragma mark - Download flow

/** @ghidraAddress 0x922f4 */
- (void)startDownloadMusic {
    NSDictionary *info = StoreMusicListManager.sharedManager.purchasedMusic[working_index];
    NSString *path = [StoreUtil filePathForMusicID:[info[kMusicKeyID] unsignedIntValue]];
    StoreDownloadTask *task = [[StoreDownloadTask alloc] initWithURL:info[kMusicKeyItemURL]
                                                                path:path];
    NSMutableArray *tasks = [NSMutableArray arrayWithObject:task];

    unsigned int extendID = [info[kMusicKeyExtendID] unsignedIntValue];
    if (extendID != 0) {
        NSString *extendPath = [StoreUtil filePathForMusicID:extendID];
        StoreDownloadTask *extendTask =
            [[StoreDownloadTask alloc] initWithURL:info[kMusicKeyExtendURL] path:extendPath];
        if (extendTask) {
            [tasks addObject:extendTask];
        }
    }

    dlManager = [[StoreDownloadManager alloc] initWithTasks:[NSArray arrayWithArray:tasks]
                                                   delegate:self];
    [dlManager start];
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x92824 */
- (void)downloaderFinished:(id)downloader {
    if (infoDownloader != downloader) {
        return;
    }
    NSDictionary *response = [StoreUtil checkStoreResponse:[downloader getData]];
    StoreMusicInfo *musicInfo = [[StoreMusicInfo alloc] initWithDictionary:response];
    BOOL updated = NO;
    if (musicInfo) {
        updated = [StoreMusicListManager.sharedManager addMusic:musicInfo];
    }
    if (musicInfo.extendMusicID != 0) {
        BOOL extendUpdated =
            [StoreMusicListManager.sharedManager addMusic:[musicInfo getExtendInfo]];
        updated = (updated | extendUpdated) & 1;
    }
    if (updated) {
        [StoreMusicListManager.sharedManager saveMusicList];
    }
    infoDownloader = nil;
    [self startDownloadMusic];
}

/** @ghidraAddress 0x92a38 */
- (void)downloaderError:(id)downloader {
    if (infoDownloader == downloader) {
        infoDownloader = nil;
        [self startDownloadMusic];
    }
}

#pragma mark - StoreDialogViewDelegate

/** @ghidraAddress 0x92a94 */
- (void)storeDialogCancel:(id)dialogView {
    if (infoDownloader) {
        [infoDownloader cancel];
        infoDownloader = nil;
    }
    if (dlManager) {
        [dlManager cancel];
        dlManager = nil;
    }
    [tableView reloadData];
    [storeViewCtrl hideModalDialog];
    working_index = kNoWorkingRow;
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0x92b68 */
- (void)alertSelect:(NSDictionary *)info {
    int buttonMessage = [info[kAlertKeyButtonMessage] intValue];
    int tag = [info[kAlertKeyTag] intValue];
    if (tag == kDeleteAlertTag) {
        if (buttonMessage != kConfirmButtonIndex) {
            working_index = kNoWorkingRow;
            return;
        }
        NSDictionary *musicInfo = StoreMusicListManager.sharedManager.purchasedMusic[working_index];
        NSString *path = [StoreUtil filePathForMusicID:[musicInfo[kMusicKeyID] unsignedIntValue]];
        NSError *error = nil;
        [NSFileManager.defaultManager removeItemAtPath:path error:&error];
        unsigned int extendID = [musicInfo[kMusicKeyExtendID] unsignedIntValue];
        if (extendID != 0) {
            NSString *extendPath = [StoreUtil filePathForMusicID:extendID];
            NSError *extendError = error;
            [NSFileManager.defaultManager removeItemAtPath:extendPath error:&extendError];
        }
        [tableView reloadData];
    }
    working_index = kNoWorkingRow;
}

/** @ghidraAddress 0x92e84 */
- (void)alertClose:(NSDictionary *)info {
    working_index = kNoWorkingRow;
}

#pragma mark - StoreDownloadManagerDelegate

/** @ghidraAddress 0x9260c */
- (void)downloadManagerStartTask:(StoreDownloadManager *)manager {
    NSString *message =
        [NSString stringWithFormat:[NSBundle.mainBundle localizedStringForKey:@"Downloading %@ ..."
                                                                        value:@""
                                                                        table:nil],
                                   musicName];
    if ((int)manager.currentIndex == 1) {
        message = [NSString
            stringWithFormat:[NSBundle.mainBundle
                                 localizedStringForKey:@"Downloading %@ (addition item) ..."
                                                 value:@""
                                                 table:nil],
                             musicName];
    }
    storeViewCtrl.modalDialog.labelMessage.text = message;
}

/** @ghidraAddress 0x92e98 */
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager {
    dlManager = nil;
    [tableView reloadData];
    [storeViewCtrl hideModalDialog];
    working_index = kNoWorkingRow;
}

/** @ghidraAddress 0x92f18 */
- (void)downloadManagerFailed:(StoreDownloadManager *)manager {
    dlManager = nil;
    NSString *title = [NSBundle.mainBundle localizedStringForKey:@"Error" value:@"" table:nil];
    NSString *message = [NSBundle.mainBundle localizedStringForKey:@"DownloadErrorMsg"
                                                             value:@""
                                                             table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [AlertViewManager.sharedManager makeAlert:0
                                     delegate:nil
                                          tag:0
                                        title:title
                                          msg:message
                                       cancel:ok
                                      btnText:nil
                                         show:YES];
    [tableView reloadData];
    [storeViewCtrl hideModalDialog];
    working_index = kNoWorkingRow;
}

/** @ghidraAddress 0x9311c */
- (void)downloadManagerProceed:(StoreDownloadManager *)manager {
    storeViewCtrl.modalDialog.progressView.progress = dlManager.overallProgress;
}

#pragma mark - Alert dismissal

/** @ghidraAddress 0x931c4 */
- (void)storeClose {
    [AlertViewManager.sharedManager closeAlert];
}

#pragma mark - Rotation

/** @ghidraAddress 0x93400 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Compiled to the unsigned range test (orientation - 1) < 2: the two portrait orientations.
    return UIInterfaceOrientationIsPortrait(interfaceOrientation);
}

/** @ghidraAddress 0x93410 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x93418 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
