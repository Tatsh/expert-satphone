#import "ChallengeMissionFileManager.h"

#import "ChallengeMissionSheet.h"
#import "JubeatAppDelegate.h"
#import "SessionDownloader.h"

// The sheet-data directory, its file-name format, and the two affixes -loadChallengeMission uses to
// pick sheet files out of the directory and recover the id from the name.
static NSString *const kSheetDirectoryName = @"sheet";
static NSString *const kSheetFileNameFormat = @"stmps%d.dat";
static NSString *const kSheetFilePrefix = @"stmps";
static NSString *const kSheetFileSuffix = @".dat";

// The prefix and suffix are stripped to leave the id: five leading characters ("stmps") and four
// trailing ("(dot)dat"), nine in total.
static const NSInteger kSheetFilePrefixLength = 5;
static const NSInteger kSheetFileAffixLength = 9;

// The initial selected-sheet id the binary seeds in -init.
static const int kInitialSelectedSheetID = 1;
// The sentinel -init writes into currentDownloadID (no download in flight).
static const int kNoDownloadID = -1;

@implementation ChallengeMissionFileManager {
    NSMutableArray<ChallengeMissionSheet *> *missionSheetTable;
    NSMutableArray *missionDLTasks;
    SessionDownloader *sheetDownloader;
    int currentDownloadID;
    int _selectedSheetID;
}

#pragma mark - Singleton

/** @ghidraAddress 0x1bdf78 */
+ (instancetype)sharedManager {
    static ChallengeMissionFileManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x1bdfb8 */
      instance = [[ChallengeMissionFileManager alloc] init];
    });
    return instance;
}

#pragma mark - Construction

/** @ghidraAddress 0x1bdff8 */
- (instancetype)init {
    self = [super init];
    if (self) {
        _selectedSheetID = kInitialSelectedSheetID;
        missionSheetTable = [[NSMutableArray alloc] init];
        currentDownloadID = kNoDownloadID;
        missionDLTasks = nil;
        [self loadChallengeMission];
        [self printSheetData];
    }
    return self;
}

#pragma mark - Paths

/** @ghidraAddress 0x1be0d0 */
- (NSString *)sheetDataDirectoryPath {
    NSString *path = [[JubeatAppDelegate appDocumentsDirectory]
        stringByAppendingPathComponent:kSheetDirectoryName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createDirectoryAtPath:path
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:nil];
    }
    return path;
}

/** @ghidraAddress 0x1be1a4 */
- (NSString *)sheetDataFilePath:(NSString *)fileName {
    return [[self sheetDataDirectoryPath] stringByAppendingPathComponent:fileName];
}

/** @ghidraAddress 0x1be228 */
- (NSString *)sheetDataFileName:(int)sheetID {
    return [NSString stringWithFormat:kSheetFileNameFormat, sheetID];
}

#pragma mark - Persistence

/** @ghidraAddress 0x1be260 */
- (void)saveChallengeMission:(ChallengeMissionSheet *)sheet {
    NSString *path = [self sheetDataFilePath:[self sheetDataFileName:sheet.sheetID]];
    NSData *data = [sheet generateSaveData];
    if (data) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:path]) {
            [fileManager removeItemAtPath:path error:nil];
        }
        [data writeToFile:path atomically:YES];
    }
}

/** @ghidraAddress 0x1be394 */
- (void)loadChallengeMission {
    NSString *directory = [self sheetDataDirectoryPath];
    NSMutableArray<ChallengeMissionSheet *> *sheets = [[NSMutableArray alloc] init];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray<NSString *> *entries = [fileManager contentsOfDirectoryAtPath:directory error:nil];
    for (NSString *entry in entries) {
        if (![entry hasPrefix:kSheetFilePrefix] || ![entry hasSuffix:kSheetFileSuffix]) {
            continue;
        }
        NSString *path = [directory stringByAppendingPathComponent:entry];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (!data) {
            continue;
        }
        NSString *idString =
            [entry substringWithRange:NSMakeRange(kSheetFilePrefixLength,
                                                  (NSInteger)entry.length - kSheetFileAffixLength)];
        ChallengeMissionSheet *sheet = [[ChallengeMissionSheet alloc] init];
        if ([sheet initWithData:data sheetID:idString.intValue]) {
            [sheets addObject:sheet];
        } else {
            [fileManager removeItemAtPath:path error:nil];
        }
    }
    missionSheetTable = [[sheets sortedArrayUsingComparator:^NSComparisonResult(id left, id right) {
      /** @ghidraAddress 0x1be758 */
      return [@([left sheetID]) compare:@([right sheetID])];
    }] mutableCopy];
}

#pragma mark - Table operations

/** @ghidraAddress 0x1be858 */
- (void)cleanMissionSheet:(NSArray<ChallengeMissionSheet *> *)missionSheets {
    for (NSInteger index = (NSInteger)missionSheetTable.count; index > 0; --index) {
        ChallengeMissionSheet *stored = missionSheetTable[index - 1];
        BOOL found = NO;
        for (ChallengeMissionSheet *offered in missionSheets) {
            if (stored.sheetID == offered.sheetID) {
                found = YES;
                break;
            }
        }
        if (!found) {
            [self deleteMissionSheet:stored.sheetID];
        }
    }
}

/** @ghidraAddress 0x1bea70 */
- (void)deleteMissionSheet:(int)sheetID {
    NSString *path = [self sheetDataFilePath:[self sheetDataFileName:sheetID]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path]) {
        [fileManager removeItemAtPath:path error:nil];
    }
}

/** @ghidraAddress 0x1beb24 */
- (BOOL)addMissionSheet:(ChallengeMissionSheet *)sheet {
    [self saveChallengeMission:sheet];
    for (NSUInteger index = 0; index < missionSheetTable.count; ++index) {
        ChallengeMissionSheet *stored = missionSheetTable[index];
        if (sheet.sheetID < stored.sheetID) {
            [missionSheetTable insertObject:sheet atIndex:index];
            return YES;
        }
        if (stored.sheetID == sheet.sheetID) {
            [missionSheetTable replaceObjectAtIndex:index withObject:sheet];
            return YES;
        }
    }
    [missionSheetTable addObject:sheet];
    return YES;
}

/** @ghidraAddress 0x1bec98 */
- (void)confirmedMissionSheet:(int)sheetID {
    for (NSUInteger index = 0; index < missionSheetTable.count; ++index) {
        ChallengeMissionSheet *sheet = missionSheetTable[index];
        if (sheet.sheetID == sheetID) {
            if ([sheet checkMissionSheet]) {
                [self addMissionSheet:sheet];
            }
            return;
        }
    }
}

/** @ghidraAddress 0x1bed94 */
- (ChallengeMissionSheet *)getChallengeSheet:(int)sheetID {
    for (ChallengeMissionSheet *sheet in missionSheetTable) {
        if (sheet.sheetID == sheetID) {
            return sheet;
        }
    }
    return nil;
}

/** @ghidraAddress 0x1beee4 */
- (BOOL)isExistMissionSheet:(int)sheetID count:(int)count updateTime:(NSString *)updateTime {
    for (ChallengeMissionSheet *sheet in missionSheetTable) {
        if (sheet.sheetID == sheetID) {
            if ([updateTime isEqualToString:sheet.updateTime] && sheet.missionCnt == count) {
                return YES;
            }
            [missionSheetTable removeObject:sheet];
            [self deleteMissionSheet:sheetID];
            return NO;
        }
    }
    return NO;
}

/** @ghidraAddress 0x1bf0f8 */
- (BOOL)isExistEventMissionSheet {
    return NO;
}

/** @ghidraAddress 0x1bf100 */
- (void)printSheetData {
    // The shipped build's body is empty; the debug dump was compiled out.
}

@end
