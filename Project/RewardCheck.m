#import "RewardCheck.h"

#import "AlertViewManager.h"
#import "CJSONSerializer.h"
#import "Downloader.h"
#import "EditorIDManager.h"
#import "GameNetworkUtil.h"
#import "JubeatAppDelegate.h"
#import "StringUtilities.h"

// The reward-list mode passed to -makeRewardCheckData:.
static const int kRewardCheckModeList = 0x4e21;

// The reward-id range the client accepts (mode .. mode + 9999).
static const int kRewardCheckIDBase = 0x4e21;
static const int kRewardCheckIDSpan = 9999;

// The random nonce length.
static const int kRewardNonceLength = 0x10;

// The request-body keys.
static NSString *const kRewardKeyTarget = @"target";
static NSString *const kRewardKeyUserID = @"user_id";
static NSString *const kRewardKeyPasswd = @"passwd";
static NSString *const kRewardKeyRewardID = @"reward_id";
static NSString *const kRewardKeyNonce = @"nonce";
static NSString *const kRewardKeyAppliID = @"appli_id";

// The response keys.
static NSString *const kRewardKeyNonceResponse = @"Nonce";
static NSString *const kRewardKeyRewardIDList = @"RewardIDList";
static NSString *const kRewardKeyRewardID2 = @"RewardID";
static NSString *const kRewardKeyVersion = @"Version";
static NSString *const kRewardKeyRewardList = @"RewardList";
static NSString *const kRewardKeyPoint = @"Point";
static NSString *const kRewardKeyAppliIDResponse = @"AppliID";

// The persisted per-app reward dictionary keys.
static NSString *const kRewardKeyPointLower = @"point";
static NSString *const kRewardKeyAppliIDLower = @"appli_id";
static NSString *const kRewardPrefKey = @"PrefRewardApplicationList";

// The installed-app alert copy.
static NSString *const kRewardInstallAlertFormat = @"アプリが%d個インストールされました。";

@interface RewardCheck ()
- (NSDictionary *)makeRewardCheckData:(int)rewardID;
- (void)checkEnd;
- (void)downloaderError:(id)downloader;
- (void)downloaderFinished:(id)downloader;
@end

@implementation RewardCheck {
    id delegate;                 // +0x8 (assign)
    Downloader *checkDownloader; // +0x10
    int additionalAppIDNum;      // +0x18
    int totalAppIDNum;           // +0x1c
    NSMutableArray *rewardList;  // +0x20
    int currentRewardID;         // +0x28
    NSString *nonceString;       // +0x30
}

#pragma mark - Construction

/** @ghidraAddress 0x1256d0 */
- (instancetype)initWithDelegate:(id<RewardCheckDelegate>)aDelegate {
    self = [super init];
    if (self) {
        NSDictionary *body = [self makeRewardCheckData:kRewardCheckModeList];
        NSData *json = [CJSONSerializer.serializer
            serializeDictionary:[NSDictionary dictionaryWithDictionary:body]
                          error:nil];
        delegate = aDelegate;
        checkDownloader = [[Downloader alloc] initWithURL:GameNetworkUtil.rewardCheckURL
                                                 postData:json
                                                 delegate:self];
        additionalAppIDNum = 0;
        totalAppIDNum = 0;
    }
    return self;
}

/** @ghidraAddress 0x125890 */
- (NSDictionary *)makeRewardCheckData:(int)rewardID {
    currentRewardID = rewardID;
    nonceString = CreateRandomString(kRewardNonceLength);
    NSString *rewardIDString = [NSString stringWithFormat:@"%d", currentRewardID];
    NSMutableArray *appliIDs = [[NSMutableArray alloc] init];
    if (![EditorIDManager isExistEditorID]) {
        // Without a stored editor identity the body carries only the store target.
        return [NSDictionary dictionaryWithObjects:@[
            GameNetworkUtil.getStoreTarget,
            rewardIDString,
            nonceString,
            appliIDs
        ]
                                           forKeys:@[
                                               kRewardKeyTarget,
                                               kRewardKeyRewardID,
                                               kRewardKeyNonce,
                                               kRewardKeyAppliID
                                           ]];
    }
    // With an editor identity the body also carries the credentials.
    NSString *editorID = [EditorIDManager getKeyString:EditorIDManager.getEditorIDKey];
    NSString *passwd = [EditorIDManager getKeyString:EditorIDManager.getEditorPassKey];
    return [NSDictionary dictionaryWithObjects:@[
        GameNetworkUtil.getStoreTarget,
        editorID,
        passwd,
        rewardIDString,
        nonceString,
        appliIDs
    ]
                                       forKeys:@[
                                           kRewardKeyTarget,
                                           kRewardKeyUserID,
                                           kRewardKeyPasswd,
                                           kRewardKeyRewardID,
                                           kRewardKeyNonce,
                                           kRewardKeyAppliID
                                       ]];
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x125d54 */
- (void)checkStart {
    [checkDownloader startDownloading];
}

/** @ghidraAddress 0x125d6c */
- (void)checkCancel {
    [checkDownloader cancel];
    checkDownloader = nil;
}

/** @ghidraAddress 0x125b98 */
- (void)checkEnd {
    rewardList = nil;
    [GameNetworkUtil fillInstallAppNum:totalAppIDNum];
    if (additionalAppIDNum > 0) {
        NSString *message =
            [NSString stringWithFormat:kRewardInstallAlertFormat, additionalAppIDNum];
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:nil
                                              tag:0
                                            title:nil
                                              msg:message
                                           cancel:ok
                                          btnText:nil
                                             show:YES];
    }
    if ([delegate respondsToSelector:@selector(rewardCheckEnd:)]) {
        [delegate performSelector:@selector(rewardCheckEnd:) withObject:self];
    }
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x125da8 */
- (void)downloaderError:(id)downloader {
    [self checkEnd];
}

/** @ghidraAddress 0x125db4 */
- (void)downloaderFinished:(id)downloader {
    if (checkDownloader != downloader) {
        return;
    }
    NSDictionary *json = [downloader getDataInJSON];
    checkDownloader = nil;
    NSString *rewardIDString = [NSString stringWithFormat:@"%d", currentRewardID];

    // A missing body, or one whose nonce does not echo ours, ends the check.
    if (!json || ![json[kRewardKeyNonceResponse] isEqualToString:nonceString]) {
        [self checkEnd];
        return;
    }

    // The list pass collects the reward IDs newer than the installed version.
    if (currentRewardID == kRewardCheckModeList) {
        NSArray *rewardIDs = json[kRewardKeyRewardIDList];
        rewardList = [[NSMutableArray alloc] init];
        for (NSDictionary *entry in rewardIDs) {
            NSNumber *rewardIDNum = entry[kRewardKeyRewardID2];
            NSString *version = entry[kRewardKeyVersion];
            int rid = rewardIDNum.intValue;
            // A reward within range whose version is newer than the app's is queued.
            if ((unsigned int)(rid - kRewardCheckIDBase) < kRewardCheckIDSpan &&
                [JubeatAppDelegate.appVersion compare:version
                                              options:NSNumericSearch] == NSOrderedAscending) {
                [rewardList addObject:rewardIDNum];
            }
        }
        if (rewardList.count != 0) {
            [JubeatAppDelegate.appDelegate rewardEnable];
        }
    }

    // The just-processed reward ID is dropped from the queue.
    [rewardList removeObject:rewardIDString];

    // A reward payload updates the per-app accounting and the persisted reward list.
    NSArray *rewards = json[kRewardKeyRewardList];
    if (rewards.count != 0) {
        NSMutableArray *appliIDs = [[NSMutableArray alloc] init];
        NSNumber *point = rewards[0][kRewardKeyPoint];
        for (NSDictionary *reward in rewards) {
            totalAppIDNum += [reward[kRewardKeyPoint] intValue];
            [appliIDs addObject:reward[kRewardKeyAppliIDResponse]];
        }
        NSDictionary *entry = @{kRewardKeyPointLower : point, kRewardKeyAppliIDLower : appliIDs};

        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        id stored = [defaults objectForKey:kRewardPrefKey];
        NSMutableDictionary *list;
        if (!stored) {
            list = [[NSMutableDictionary alloc] init];
        } else {
            list = [NSMutableDictionary
                dictionaryWithDictionary:[NSKeyedUnarchiver unarchiveObjectWithData:stored]];
        }
        // The prior app count for this reward is remembered so only newly-added apps are counted.
        int priorCount = 0;
        NSDictionary *existing = list[rewardIDString];
        if (existing) {
            priorCount = (int)[existing[kRewardKeyAppliIDLower] count];
        }
        [list removeObjectForKey:rewardIDString];
        list[rewardIDString] = entry;
        NSData *archived = [NSKeyedArchiver
            archivedDataWithRootObject:[NSDictionary dictionaryWithDictionary:list]];
        [defaults setObject:archived forKey:kRewardPrefKey];
        [defaults synchronize];
        additionalAppIDNum += point.intValue * ((int)appliIDs.count - priorCount);
    }

    // Either finish, or fetch the next queued reward.
    if (rewardList.count == 0) {
        [self checkEnd];
    } else {
        currentRewardID = [rewardList[0] intValue];
    }
}

@end
