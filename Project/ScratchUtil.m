#import "ScratchUtil.h"

#import "JubeatAppDelegate.h"
#import "StoreMusicListManager.h"
#import "StoreUtil.h"

// The API host, from the CFString at 0x2df240. Twenty characters, read from 0x2872a1.
static NSString *const kAPIHost = @"agx11.s.konaminet.jp";

// The API root, and the only one of the four strings here that is a plain C string rather than a
// CFString: it is at 0x286cda and arrives through the "%s" below.
static const char *const kAPIRootPath = "/agx/api";

// The secure-URL wrapper format, from the CFString at 0x2da200.
static NSString *const kSecureURLFormat = @"https://%@%@";

// De-inlined: formats a path (whose leading "%s" is the API root) and wraps it in
// "https://agx11.s.konaminet.jp<path>". Every JSON endpoint builder below shares this shape.
static inline NSURL *ScratchUtilURLForPath(NSString *pathFormat) {
    NSString *path = [NSString stringWithFormat:pathFormat, kAPIRootPath];
    NSString *urlString = [NSString stringWithFormat:kSecureURLFormat, kAPIHost, path];
    return [[NSURL alloc] initWithString:urlString];
}

// De-inlined: a documents-relative cache directory, created (with intermediates) on first use and
// returning nil when creation fails. Shared by the two cache-directory accessors.
static inline NSString *ScratchUtilCacheDirectoryNamed(NSString *name) {
    NSString *directory =
        [JubeatAppDelegate.appDocumentsDirectory stringByAppendingPathComponent:name];
    NSFileManager *manager = NSFileManager.defaultManager;
    if (![manager fileExistsAtPath:directory]) {
        NSError *error = nil;
        [manager createDirectoryAtPath:directory
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:&error];
        if (error) {
            return nil;
        }
    }
    return directory;
}

@implementation ScratchUtil

/** @ghidraAddress 0x180524 */
+ (NSURL *)pushNotificationResponseURL {
    // Straight-line: no branch anywhere in the method, so the endpoint is fixed and there is no
    // staging or debug host to select between.
    return ScratchUtilURLForPath(@"%s/log/iOS/v1/PushNotificationReaction.json");
}

/** @ghidraAddress 0x180450 */
+ (NSURL *)pushNotificationIDSendURL {
    return ScratchUtilURLForPath(@"%s/common/iOS/v1/RegistPushToken.json");
}

/** @ghidraAddress 0x1805f8 */
+ (NSURL *)challengeModePolicyURL {
    return ScratchUtilURLForPath(@"%s/common/iOS/v1/FetchPolicy.json");
}

/** @ghidraAddress 0x1806cc */
+ (NSURL *)challengeSessionURL {
    return ScratchUtilURLForPath(@"%s/common/iOS/v1/BeginSession.json");
}

/** @ghidraAddress 0x1807a0 */
+ (NSURL *)challengeInitializeURL {
    return ScratchUtilURLForPath(@"%s/scratch/iOS/v1/Init.json");
}

/** @ghidraAddress 0x180874 */
+ (NSURL *)challengeSimpleInitializeURL {
    return ScratchUtilURLForPath(@"%s/scratch/iOS/v1/RefreshDisplay.json");
}

/** @ghidraAddress 0x180948 */
+ (NSURL *)challengePrevScratchURL {
    return ScratchUtilURLForPath(@"%s/scratch/iOS/v1/FetchPrevScratchInfo.json");
}

/** @ghidraAddress 0x180a1c */
+ (NSURL *)nailScratchURL {
    return ScratchUtilURLForPath(@"%s/scratch/iOS/v1/ScratchCell.json");
}

/** @ghidraAddress 0x180af0 */
+ (NSURL *)cubeScratchURL {
    return ScratchUtilURLForPath(@"%s/scratch/iOS/v1/ExchangeItem.json");
}

/** @ghidraAddress 0x180bc4 */
+ (NSURL *)musicInfoURL {
    return ScratchUtilURLForPath(@"%s/scratch/iOS/v1/FetchMusicInfo.json");
}

/** @ghidraAddress 0x180c98 */
+ (NSURL *)playMusicURL {
    return ScratchUtilURLForPath(@"%s/scratch/iOS/v1/StartPlay.json");
}

/** @ghidraAddress 0x180d6c */
+ (NSURL *)restPlayCoinURL {
    return ScratchUtilURLForPath(@"%s/scratch/iOS/v1/ExchangeItem.json");
}

/** @ghidraAddress 0x180e40 */
+ (NSURL *)sendMusicScoreURL {
    return ScratchUtilURLForPath(@"%s/scratch/iOS/v1/SendScore.json");
}

/** @ghidraAddress 0x180f14 */
+ (NSURL *)getUserNameURL {
    return ScratchUtilURLForPath(@"%s/user/iOS/v1/ChangeName.json");
}

/** @ghidraAddress 0x180fe8 */
+ (NSURL *)registRivalURL {
    return ScratchUtilURLForPath(@"%s/scratch/iOS/v1/ManageRival.json");
}

/** @ghidraAddress 0x1810bc */
+ (NSURL *)removeRivalURL {
    return ScratchUtilURLForPath(@"%s/scratch/iOS/v1/ManageRival.json");
}

/** @ghidraAddress 0x181190 */
+ (NSURL *)searchRivalURL {
    return ScratchUtilURLForPath(@"%s/user/iOS/v1/FetchNameById.json");
}

/** @ghidraAddress 0x181264 */
+ (NSURL *)rivalListURL {
    return ScratchUtilURLForPath(@"%s/scratch/iOS/v1/FetchRivalList.json");
}

/** @ghidraAddress 0x181338 */
+ (NSURL *)rankingListURL {
    return ScratchUtilURLForPath(@"%s/scratch/iOS/v1/FetchRanking.json");
}

/** @ghidraAddress 0x18140c */
+ (NSURL *)presentListURL {
    return ScratchUtilURLForPath(@"%s/scratch/iOS/v1/FetchPresentList.json");
}

/** @ghidraAddress 0x1814e0 */
+ (NSURL *)getPresentURL {
    return ScratchUtilURLForPath(@"%s/scratch/iOS/v1/FetchPresent.json");
}

/** @ghidraAddress 0x1815b4 */
+ (NSURL *)cubePurchaseListURL {
    return ScratchUtilURLForPath(@"%s/common/iOS/v1/FetchJcubeList.json");
}

/** @ghidraAddress 0x181688 */
+ (NSURL *)cubeVerifyReceiptURL {
    return ScratchUtilURLForPath(@"%s/common/iOS/v1/VerifyReceipt.json");
}

/** @ghidraAddress 0x18175c */
+ (NSURL *)registTotalPurchaseURL {
    return ScratchUtilURLForPath(@"%s/common/iOS/v1/SendSumPrice.json");
}

/** @ghidraAddress 0x181830 */
+ (NSURL *)registUserAgeURL {
    return ScratchUtilURLForPath(@"%s/log/iOS/v1/RegistAge.json");
}

/** @ghidraAddress 0x181d20 */
+ (NSURL *)getMissionListURL {
    return ScratchUtilURLForPath(@"%s/scratch/mission/iOS/v1/FetchSheetList.json");
}

/** @ghidraAddress 0x181df4 */
+ (NSURL *)getMissionSheetURL {
    return ScratchUtilURLForPath(@"%s/scratch/mission/iOS/v1/FetchMissionList.json");
}

/** @ghidraAddress 0x181ec8 */
+ (NSURL *)getMissionAchieveURL {
    return ScratchUtilURLForPath(@"%s/scratch/mission/iOS/v1/CheckAchievement.json");
}

/** @ghidraAddress 0x181f9c */
+ (NSURL *)getMissionAchieveCheckURL {
    return ScratchUtilURLForPath(@"%s/scratch/mission/iOS/v1/UpdateAchievement.json");
}

/** @ghidraAddress 0x182070 */
+ (NSURL *)openMissionAchieveURL {
    return ScratchUtilURLForPath(@"%s/scratch/mission/iOS/v1/CloseMissionAchievement.json");
}

/** @ghidraAddress 0x182144 */
+ (NSURL *)getMissionRewardListURL {
    return ScratchUtilURLForPath(@"%s/scratch/mission/iOS/v1/FetchRewardList.json");
}

/** @ghidraAddress 0x182218 */
+ (NSURL *)getMissionRewardURL {
    return ScratchUtilURLForPath(@"%s/scratch/mission/iOS/v1/FetchRewardUrl.json");
}

/** @ghidraAddress 0x1822f8 */
+ (NSURL *)getMissionSkipURL {
    return ScratchUtilURLForPath(@"%s/scratch/mission/iOS/v1/SkipMission.json");
}

/** @ghidraAddress 0x1823cc */
+ (NSURL *)getInheritOutputURL {
    return ScratchUtilURLForPath(@"%s/user/iOS/v1/FetchTransferToken.json");
}

/** @ghidraAddress 0x1824a0 */
+ (NSURL *)getInheritInputURL {
    return ScratchUtilURLForPath(@"%s/user/iOS/v1/ConfirmUserId.json");
}

/** @ghidraAddress 0x182574 */
+ (NSURL *)getInheritReplaceURL {
    return ScratchUtilURLForPath(@"%s/user/iOS/v1/FinishTransferUserId.json");
}

/** @ghidraAddress 0x182910 */
+ (NSURL *)recommendPackListURL {
    return ScratchUtilURLForPath(@"%s/common/store/iOS/v1/RecommendPack.json");
}

/** @ghidraAddress 0x1829e4 */
+ (NSURL *)getEventTypeURL {
    return ScratchUtilURLForPath(@"%s/common/iOS/v1/FetchCampaign.json");
}

/** @ghidraAddress 0x182ab8 */
+ (NSURL *)getOchazukeURL {
    return ScratchUtilURLForPath(@"%s/common/iOS/v1/FetchCampaignMap.json");
}

/** @ghidraAddress 0x182874 */
+ (NSURL *)getInquiryURL {
    // A trailing-slash endpoint built directly rather than through -scratchURLForPath:. Verified at
    // 0x182874: stringWithFormat:@"https://%@%s/info/iOS/v1/Inquiry/", host, root.
    NSString *urlString =
        [NSString stringWithFormat:@"https://%@%s/info/iOS/v1/Inquiry/", kAPIHost, kAPIRootPath];
    return [[NSURL alloc] initWithString:urlString];
}

/** @ghidraAddress 0x1822ec */
+ (NSURL *)getMissionSheetSetURL {
    return [self challengeSampleURL];
}

/** @ghidraAddress 0x180448 */
+ (NSURL *)challengeSampleURL {
    // Always nil in the shipped build.
    return nil;
}

#pragma mark - Cache directories

/** @ghidraAddress 0x181904 */
+ (NSString *)scratchImageDirectory {
    return ScratchUtilCacheDirectoryNamed(@"scImg");
}

/** @ghidraAddress 0x182648 */
+ (NSString *)unlockPanelImageDirectory {
    return ScratchUtilCacheDirectoryNamed(@"ulImg");
}

/** @ghidraAddress 0x18273c */
+ (NSString *)panelDataPath {
    NSString *directory = [self scratchImageDirectory];
    if (!directory) {
        return nil;
    }
    return [directory stringByAppendingString:@"pntmp"];
}

#pragma mark - Image and item paths

/** @ghidraAddress 0x1819f8 */
+ (NSString *)imagePathForMusicID:(unsigned int)musicID {
    // Tune 0 is the bundled placeholder button; the rest live in the scratch-image cache.
    if (musicID == 0) {
        return [NSBundle.mainBundle pathForResource:@"scratch_btn_scratch_00" ofType:@"png"];
    }
    NSString *directory = [self scratchImageDirectory];
    if (!directory) {
        return nil;
    }
    NSString *name = [[NSString alloc] initWithFormat:@"aw%09d.img", musicID];
    return [directory stringByAppendingPathComponent:name];
}

/** @ghidraAddress 0x181b24 */
+ (NSString *)itemPathForMusicID:(unsigned int)musicID {
    // Prefer the downloaded store file when the tune is a store tune and the file is present.
    if ([StoreMusicListManager.sharedManager hasMusic:musicID]) {
        NSString *storePath = [StoreUtil filePathForMusicID:musicID];
        if ([NSFileManager.defaultManager fileExistsAtPath:storePath]) {
            return storePath;
        }
    }
    NSString *directory = [self scratchImageDirectory];
    if (!directory) {
        return nil;
    }
    NSString *name = [[NSString alloc] initWithFormat:@"%09d.jbt", musicID];
    return [directory stringByAppendingPathComponent:name];
}

/** @ghidraAddress 0x1827b0 */
+ (NSString *)panelImagePathForItemID:(int)itemID {
    NSString *directory = [self scratchImageDirectory];
    if (!directory) {
        return nil;
    }
    NSString *name = [[NSString alloc] initWithFormat:@"aw%09d.img", itemID];
    return [directory stringByAppendingPathComponent:name];
}

/** @ghidraAddress 0x18286c */
+ (NSString *)checkRegularPanelImage {
    // Always nil in the shipped build.
    return nil;
}

#pragma mark - Cache management

/** @ghidraAddress 0x181c8c */
+ (void)clearScratchData {
    // Remove the scratch-image directory outright, then recreate it empty.
    [NSFileManager.defaultManager removeItemAtPath:[self scratchImageDirectory] error:nil];
    [self scratchImageDirectory];
}

@end
