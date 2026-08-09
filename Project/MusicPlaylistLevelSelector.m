#import "MusicPlaylistLevelSelector.h"

#import "BFCodec.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "LabUtilities.h"
#import "StoreMusicListManager.h"
#import "StoreUtil.h"
#import "TuneInfo.h"
#import "cipher_keys.h"

// Apple's private property-list deserialiser category, as the binary calls it.
@interface NSDictionary (PropertyList)
+ (nullable NSDictionary *)dictionaryFromPropertyListData:(nullable NSData *)data;
@end

// The number of difficulty levels listed, one through ten.
static const NSInteger kLevelCount = 10;

// The reuse identifier for the level cells.
static NSString *const kLevelCellIdentifier = @"PlayListTableLevelCell";

// The user-defaults key holding the currently applied one-based playlist level filter.
static NSString *const kPrefPlayListLevelKey = @"PrefPlayListLevel";

// The archive is opened skipping this fixed-size trailing digest.
static const NSUInteger kArchiveTailLength = 16;

// The tune-info archive entries, tried newest-first.
static NSString *const kInfoV3EntryName = @"infov3";
static NSString *const kInfoV2EntryName = @"infov2";
static NSString *const kInfoEntryName = @"info";

// The four-byte header stripped from the deciphered infov3 payload.
static const NSUInteger kInfoV3HeaderLength = 4;

// The tune-info dictionary's id key.
static NSString *const kTuneInfoIDKey = @"ID";

// The purchased-tune cache keys.
static NSString *const kCacheFileSizeKey = @"filesize";
static NSString *const kCacheTimestampKey = @"timestamp";

// The row height, from the __const pool at 0x28f1f8.
static const CGFloat kLevelRowHeight = 40.0;

// The highlight colour components for the currently selected level, from the __const pool at
// 0x28f2b8 (title) and 0x28f2c0 (detail); blue and alpha come from the fmov immediate 1.0.
static const CGFloat kSelectedTitleRedGreen = 0.10000000149011612;
static const CGFloat kSelectedDetailRedGreen = 0.4000000059604645;

@implementation MusicPlaylistLevelSelector {
    NSMutableArray *numArray; // The per-level chart counts, one entry per level.
}

@synthesize delegate = _delegate;

#pragma mark - Construction

/** @ghidraAddress 0x1c2d04 */
- (instancetype)init {
    self = [super init];
    if (self) {
        self.navigationItem.title = @"LEVEL";
        self.navigationItem.backBarButtonItem.title =
            [NSBundle.mainBundle localizedStringForKey:@"Cancel" value:@"" table:nil];
        [self createNumberArray];
    }
    return self;
}

#pragma mark - View lifecycle

/** @ghidraAddress 0x1c2e5c */
- (void)loadView {
    [super loadView];
}

/** @ghidraAddress 0x1c4560 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
        (void)JubeatAppDelegate.appDelegate.isPad; // Yes, the binary reads this and discards it.
    }
}

/** @ghidraAddress 0x1c45f4 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x1c462c */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x1c4664 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Rotation

/** @ghidraAddress 0x1c469c */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    // True for the two portrait orientations, tested as the unsigned (orientation - 1) < 2.
    return (NSUInteger)(orientation - 1) < 2;
}

/** @ghidraAddress 0x1c46ac */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // Mask 6 is Portrait | PortraitUpsideDown.
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x1c46b4 */
- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - Level counts

/** @ghidraAddress 0x1c2e94 */
- (void)createNumberArray {
    NSMutableArray *tunes = [[NSMutableArray alloc] initWithCapacity:256];
    NSString *builtinPath = [NSBundle.mainBundle pathForResource:@"Music" ofType:@""];
    if (builtinPath) {
        for (NSNumber *musicID in StoreMusicListManager.sharedManager.builtinMusic) {
            NSString *archivePath = [builtinPath
                stringByAppendingPathComponent:[NSString
                                                   stringWithFormat:@"%d.jbt", musicID.intValue]];
            BOOL isDirectory = NO;
            if ([NSFileManager.defaultManager fileExistsAtPath:archivePath
                                                   isDirectory:&isDirectory] &&
                !isDirectory) {
                NSDictionary *info = [self getTuneInfo:archivePath];
                if (info) {
                    TuneInfo *tune = [[TuneInfo alloc] initWithfilePath:archivePath
                                                             dictionary:info];
                    if (tune && tune.tuneID == (unsigned int)musicID.intValue) {
                        [tunes addObject:tune];
                    }
                }
            }
        }
    }

    NSString *cachePath =
        [JubeatAppDelegate.appCachesDirectory stringByAppendingPathComponent:@"musiccache"];
    BOOL cacheIsDirectory = NO;
    NSMutableDictionary *cache = nil;
    if ([NSFileManager.defaultManager fileExistsAtPath:cachePath isDirectory:&cacheIsDirectory] &&
        !cacheIsDirectory) {
        cache = [[NSMutableDictionary alloc] initWithContentsOfFile:cachePath];
    }
    if (!cache) {
        cache = [[NSMutableDictionary alloc] initWithCapacity:64];
    }

    BOOL cacheChanged = NO;
    for (NSDictionary *entry in StoreMusicListManager.sharedManager.purchasedMusic) {
        NSNumber *musicID = entry[kTuneInfoIDKey];
        NSString *cacheKey = [NSString stringWithFormat:@"%d", musicID.unsignedIntValue];
        if (!musicID) {
            continue;
        }
        NSString *archivePath = [StoreUtil filePathForMusicID:(int)musicID.unsignedIntValue];
        BOOL isDirectory = NO;
        if (![NSFileManager.defaultManager fileExistsAtPath:archivePath isDirectory:&isDirectory] ||
            isDirectory) {
            continue;
        }
        NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:archivePath
                                                                                  error:nil];
        NSNumber *fileSize = attributes[NSFileSize];
        NSDate *modificationDate = attributes[NSFileModificationDate];

        NSDictionary *cached = cache[cacheKey];
        if (cached) {
            NSNumber *cachedSize = cached[kCacheFileSizeKey];
            NSDate *cachedDate = cached[kCacheTimestampKey];
            if ([cachedSize isEqualToNumber:fileSize] &&
                [cachedDate isEqualToDate:modificationDate]) {
                TuneInfo *tune = [[TuneInfo alloc] initWithfilePath:archivePath dictionary:cached];
                if (tune && tune.tuneID == (unsigned int)musicID.unsignedIntValue) {
                    [tunes addObject:tune];
                }
                continue;
            }
        }

        NSDictionary *info = [self getTuneInfo:archivePath];
        if (!info) {
            continue;
        }
        TuneInfo *tune = [[TuneInfo alloc] initWithfilePath:archivePath dictionary:info];
        if (tune && tune.tuneID == (unsigned int)musicID.unsignedIntValue) {
            [tunes addObject:tune];
            if (fileSize && modificationDate) {
                NSMutableDictionary *updated =
                    [[NSMutableDictionary alloc] initWithDictionary:info];
                updated[kCacheFileSizeKey] = fileSize;
                updated[kCacheTimestampKey] = modificationDate;
                cache[cacheKey] = [NSDictionary dictionaryWithDictionary:updated];
                cacheChanged = YES;
            }
        }
    }
    if (cacheChanged) {
        [cache writeToFile:cachePath atomically:YES];
    }

    [tunes sortUsingSelector:@selector(compareYomi:)];

    unsigned int counts[kLevelCount] = {0};
    for (TuneInfo *tune in tunes) {
        for (NSInteger index = 0; index < kLevelCount; ++index) {
            NSInteger level = index + 1;
            if (level == tune.lvBas) {
                ++counts[index];
            }
            if (level == tune.lvAdv && tune.lvBas != tune.lvAdv) {
                ++counts[index];
            }
            if (level == tune.lvExt && tune.lvExt != tune.lvAdv) {
                ++counts[index];
            }
        }
    }

    numArray = [[NSMutableArray alloc] init];
    for (NSInteger index = 0; index < kLevelCount; ++index) {
        [numArray addObject:@((int)counts[index])];
    }
}

#pragma mark - Tune info

/** @ghidraAddress 0x1c42d8 */
- (NSDictionary *)getTuneInfo:(NSString *)path {
    KUnzip *unzip = [[KUnzip alloc] initWithPath:path tail:kArchiveTailLength];
    if (!unzip) {
        return nil;
    }
    NSMutableData *payload = [unzip uncompress:kInfoV3EntryName];
    if (payload) {
        // The v3 payload is deciphered with the tune-info key, then its four-byte header is
        // dropped.
        BFCodec *codec = [[BFCodec alloc] init];
        [codec cipherInit:CreateTuneInfoCipherKey()];
        [codec decipher:payload];
        NSData *body = [payload subdataWithRange:NSMakeRange(kInfoV3HeaderLength,
                                                             payload.length - kInfoV3HeaderLength)];
        return [NSDictionary dictionaryFromPropertyListData:body];
    }
    NSMutableData *legacy = [unzip uncompress:kInfoV2EntryName];
    if (!legacy) {
        legacy = [unzip uncompress:kInfoEntryName];
    }
    if (!legacy) {
        return nil;
    }
    // The older payloads are deciphered with the BGM key and used whole.
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:GetBgmCipherKey()];
    [codec decipher:legacy];
    return [NSDictionary dictionaryFromPropertyListData:legacy];
}

#pragma mark - Table view data source

/** @ghidraAddress 0x1c40cc */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return kLevelCount;
}

/** @ghidraAddress 0x1c3b70 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kLevelCellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:kLevelCellIdentifier];
    }

    NSString *title = [NSString stringWithFormat:@"LEVEL %d", (int)(indexPath.row + 1)];
    NSInteger appliedLevel =
        [NSUserDefaults.standardUserDefaults integerForKey:kPrefPlayListLevelKey];
    NSInteger row = indexPath.row;
    int count = [numArray[indexPath.row] intValue];

    NSString *detail;
    if (count < 2) {
        detail = [NSString stringWithFormat:@"%d song", count];
    } else {
        detail = [NSString stringWithFormat:@"%d songs", count];
    }
    cell.detailTextLabel.text = detail;

    if (title) {
        cell.textLabel.text = title;
    }
    cell.textLabel.backgroundColor = UIColor.clearColor;

    if (appliedLevel == row + 1) {
        // The currently applied level draws in the highlight colours (component call in the
        // binary, blue and alpha from the fmov immediate 1.0).
        cell.textLabel.textColor = [UIColor colorWithRed:kSelectedTitleRedGreen
                                                   green:kSelectedTitleRedGreen
                                                    blue:1.0
                                                   alpha:1.0];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:kSelectedDetailRedGreen
                                                         green:kSelectedDetailRedGreen
                                                          blue:1.0
                                                         alpha:1.0];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (count != 0) {
        cell.textLabel.textColor = UIColor.blackColor;
        cell.detailTextLabel.textColor = UIColor.grayColor;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    } else {
        cell.textLabel.textColor = UIColor.grayColor;
        cell.detailTextLabel.textColor = UIColor.lightGrayColor;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    return cell;
}

#pragma mark - Table view delegate

/** @ghidraAddress 0x1c4554 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kLevelRowHeight;
}

/** @ghidraAddress 0x1c41b8 */
- (NSIndexPath *)tableView:(UITableView *)tableView
    willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSIndexPath *result = indexPath;
    if ([numArray[indexPath.row] integerValue] == 0) {
        result = nil;
    }
    NSInteger appliedLevel =
        [NSUserDefaults.standardUserDefaults integerForKey:kPrefPlayListLevelKey];
    if (appliedLevel == indexPath.row + 1) {
        result = nil;
    }
    return result;
}

/** @ghidraAddress 0x1c40d4 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSNumber *level = @(indexPath.row + 1);
    if ([self.delegate respondsToSelector:@selector(selectLevel:)]) {
        [self.delegate performSelector:@selector(selectLevel:) withObject:level];
    }
}

@end
