#import "JcfDownloader.h"

#import "EditDataManager.h"
#import "EditorIDManager.h"
#import "JubeatAppDelegate.h"
#import "LatelyJcfListManager.h"
#import "NSData+Base64.h"
#import "StoreMusicListManager.h"
#import "StoreUtil.h"
#import "jubeatLabAccess.h"

// The jubeatLab JSON response keys.
static NSString *const kStatusKey = @"Status";
static NSString *const kMsgUserKey = @"MsgUser";
static NSString *const kJcfDataKey = @"JcfData";
static NSString *const kMusicIDKey = @"musicID";
static NSString *const kUserTypeKey = @"UserType";
static NSString *const kSeqIDKey = @"SeqID";
static NSString *const kFileNameKey = @"fileName";
static NSString *const kPackIDKey = @"ID";

// The built-in-chart bundle resource and the saved-chart filename formats.
static NSString *const kBundleMusicResource = @"Music";
static NSString *const kBundleMusicType = @"";
static NSString *const kJbtFileFormat = @"%d.jbt";
static NSString *const kJcfFileFormat = @"%@.jcf";
static NSString *const kSeqIDFormat = @"%d";
static NSString *const kTuneIDFormat = @"%d";

// The message shown when the chart has already been downloaded, from the UTF-16 CFString at
// 0x1002e1060.
static NSString *const kAlreadyDownloadedMessage = @"この譜面は既にダウンロードされています。";

// The status value that marks a successful jubeatLab response.
static const int kStatusOK = 0;
// The number of trailing characters (".jcf") stripped before comparing a stored filename.
static const NSUInteger kJcfExtensionLength = 4;

@interface JcfDownloader () {
@public
    NSURL *requestURL;                   // +0x08
    jubeatLabAccess *seqDownloader;      // +0x10
    jubeatLabAccess *packInfoDownloader; // +0x18
    unsigned int packID;                 // +0x20
    NSString *customID;                  // +0x28
    __weak id delegate;                  // +0x30, accessed with objc_loadWeakRetained
    EditorIDManager *eidMan;             // +0x38
}
- (void)downloadFailedDelegate;
- (BOOL)isExistJbtFile:(unsigned int)tuneID;
@end

// The sequence-download arm of -jubeatLabAccessFinished:. Decodes the base64 chart, saves it, and
// either kicks off the comprised-pack lookup (new tune) or reports the save outcome. De-inlined
// from the single large binary method per the reconstruction guidelines.
static inline void JcfDownloaderHandleSequenceDownloadFinished(JcfDownloader *self,
                                                               jubeatLabAccess *access) {
    NSDictionary *json = access.getDataInJSON;
    self->seqDownloader = nil;
    if (json == nil) {
        [self downloadFailedDelegate];
        return;
    }
    if ([json[kStatusKey] intValue] != kStatusOK) {
        NSString *message = json[kMsgUserKey];
        if ([self->delegate respondsToSelector:@selector(errorSequenceDownload:msgStr:)]) {
            [self->delegate performSelector:@selector(errorSequenceDownload:msgStr:)
                                 withObject:self
                                 withObject:message];
        }
        return;
    }
    EditDataManager *editData = [EditDataManager sharedManager];
    NSData *chartData = [NSData dataFromBase64String:json[kJcfDataKey]];
    if (chartData == nil) {
        [self downloadFailedDelegate];
        return;
    }
    unsigned int tuneID =
        [[editData pickUpEditorInfoFromData:chartData][kMusicIDKey] unsignedIntValue];
    BOOL alreadyBuiltIn = [self isExistJbtFile:tuneID];
    int userType = [json[kUserTypeKey] intValue];
    NSString *seqID = json[kSeqIDKey];
    NSString *tuneIDString = [NSString stringWithFormat:kSeqIDFormat, tuneID];
    [[LatelyJcfListManager sharedManager] addJcfOwner:tuneIDString];

    if (!alreadyBuiltIn) {
        // A brand-new tune: save it and ask the pack API which pack it belongs to.
        [editData localSaveDLFile:chartData serial:seqID usrTag:userType];
        self->packInfoDownloader = [[jubeatLabAccess alloc] initComprisedPackApi:self
                                                                          tuneID:tuneID];
        [self->packInfoDownloader startAccess];
        return;
    }

    // The tune is already built in: save it into an edit slot unless a matching file exists or the
    // slot cap is reached.
    NSArray *fileInfoList = [editData getFileInfoList:tuneID];
    BOOL collision = NO;
    for (NSUInteger i = 0; i < fileInfoList.count; ++i) {
        NSString *storedName = [NSString stringWithString:fileInfoList[i][kFileNameKey]];
        NSString *stem =
            [storedName substringWithRange:NSMakeRange(0, storedName.length - kJcfExtensionLength)];
        if ([stem isEqualToString:seqID]) {
            collision = YES;
            break;
        }
    }
    if (collision) {
        if ([self->delegate respondsToSelector:@selector(errorSequenceDownload:msgStr:)]) {
            [self->delegate performSelector:@selector(errorSequenceDownload:msgStr:)
                                 withObject:self
                                 withObject:kAlreadyDownloadedMessage];
        }
        return;
    }
    if (fileInfoList.count < (NSUInteger)editData.getEditSlotLimit) {
        NSString *fileName = [NSString stringWithFormat:kJcfFileFormat, seqID];
        [editData localSaveDLFile:chartData serial:seqID usrTag:userType];
        [editData setLastEditFileName:tuneID fileName:fileName];
        if ([self->delegate respondsToSelector:@selector(finishedSequenceDownload:tuneID:)]) {
            [self->delegate performSelector:@selector(finishedSequenceDownload:tuneID:)
                                 withObject:self
                                 withObject:tuneIDString];
        }
    } else if ([self->delegate respondsToSelector:@selector(finishedSequenceOverCap:)]) {
        [self->delegate performSelector:@selector(finishedSequenceOverCap:) withObject:self];
    }
}

// The comprised-pack arm of -jubeatLabAccessFinished:. Reports whether the tune's pack exists.
static inline void JcfDownloaderHandlePackInfoFinished(JcfDownloader *self,
                                                       jubeatLabAccess *access) {
    NSDictionary *response = [StoreUtil checkStoreResponse:access.getData];
    if (response == nil) {
        if ([self->delegate respondsToSelector:@selector(finishedSequenceDownload:)]) {
            [self->delegate performSelector:@selector(finishedSequenceDownload:) withObject:self];
        }
    } else {
        self->packID = [response[kPackIDKey] intValue];
        NSString *packIDString = [NSString stringWithFormat:kTuneIDFormat, self->packID];
        if ([self->delegate respondsToSelector:@selector(finishedSequenceNotExistPack:packID:)]) {
            [self->delegate performSelector:@selector(finishedSequenceNotExistPack:packID:)
                                 withObject:self
                                 withObject:packIDString];
        }
    }
    self->packInfoDownloader = nil;
}

@implementation JcfDownloader

#pragma mark - Construction

/** @ghidraAddress 0x1d4624 */
- (NSURL *)createCustomSequenceURL:(id)customIDArg {
    return [StoreUtil storeNewInfoURL];
}

/** @ghidraAddress 0x1d4638 */
- (instancetype)initWithCustomID:(NSString *)customIDArg delegate:(id)delegateArg {
    self = [super init];
    if (self) {
        delegate = delegateArg;
        customID = customIDArg;
        if (!EditorIDManager.isExistEditorID) {
            // No editor id yet: provisioning one calls back to -successIDDownload:.
            eidMan = [[EditorIDManager alloc] initWithDelegate:self];
        } else {
            [self downloadStart];
        }
    }
    return self;
}

/** @ghidraAddress 0x1d474c */
- (void)downloadStart {
    seqDownloader = [[jubeatLabAccess alloc] initDownloadApi:self seqID:customID];
    [seqDownloader startAccess];
}

#pragma mark - jubeatLabAccess callbacks

/** @ghidraAddress 0x1d47bc */
- (void)jubeatLabAccessProceed:(jubeatLabAccess *)access {
}

/** @ghidraAddress 0x1d47c0 */
- (void)jubeatLabAccessError:(jubeatLabAccess *)access {
    if (seqDownloader == access) {
        seqDownloader = nil;
        if ([delegate respondsToSelector:@selector(errorSequenceDownload:msgStr:)]) {
            [delegate performSelector:@selector(errorSequenceDownload:msgStr:)
                           withObject:self
                           withObject:nil];
        }
    }
    if (packInfoDownloader == access) {
        if ([delegate respondsToSelector:@selector(finishedSequenceDownload:tuneID:)]) {
            // The failed pack lookup reports a sentinel tune id of -1, a literal in the binary.
            NSString *tuneID = [NSString stringWithFormat:kTuneIDFormat, -1];
            [delegate performSelector:@selector(finishedSequenceDownload:tuneID:)
                           withObject:self
                           withObject:tuneID];
        }
    }
}

/** @ghidraAddress 0x1d4948 */
- (void)downloadFailedDelegate {
    if ([delegate respondsToSelector:@selector(errorSequenceDownload:msgStr:)]) {
        [delegate performSelector:@selector(errorSequenceDownload:msgStr:)
                       withObject:self
                       withObject:nil];
    }
    seqDownloader = nil;
}

/** @ghidraAddress 0x1d49f0 */
- (BOOL)isExistJbtFile:(unsigned int)tuneID {
    // A tune with no built-in "Music" bundle resource is never built in.
    if ([NSBundle.mainBundle pathForResource:kBundleMusicResource ofType:kBundleMusicType]) {
        for (NSNumber *builtin in [StoreMusicListManager sharedManager].builtinMusic) {
            if (builtin.unsignedIntValue == tuneID) {
                return YES;
            }
        }
    }
    NSString *fileName = [[NSString alloc] initWithFormat:kJbtFileFormat, tuneID];
    NSString *path =
        [JubeatAppDelegate.appDocumentsDirectory stringByAppendingPathComponent:fileName];
    return [NSFileManager.defaultManager fileExistsAtPath:path];
}

/** @ghidraAddress 0x1d4ca4 */
- (void)jubeatLabAccessFinished:(jubeatLabAccess *)access {
    if (seqDownloader == access) {
        JcfDownloaderHandleSequenceDownloadFinished(self, access);
    }
    if (packInfoDownloader == access) {
        JcfDownloaderHandlePackInfoFinished(self, access);
    }
}

#pragma mark - EditorIDManager callbacks

/** @ghidraAddress 0x1d5608 */
- (void)successIDDownload:(id)sender {
    eidMan = nil;
    if (!EditorIDManager.isExistEditorID) {
        [self errorIDDownload:sender msgStr:nil];
    } else {
        [self downloadStart];
    }
}

/** @ghidraAddress 0x1d568c */
- (void)errorIDDownload:(id)sender msgStr:(NSString *)msg {
    eidMan = nil;
    if ([delegate respondsToSelector:@selector(errorSequenceDownload:msgStr:)]) {
        [delegate performSelector:@selector(errorSequenceDownload:msgStr:)
                       withObject:self
                       withObject:nil];
    }
}

@end
