#import "JcfUploader.h"

#import <Security/Security.h>
#import <UIKit/UIKit.h>

#import "EditorIDManager.h"
#import "jubeatLabAccess.h"

// The jubeatLab JSON response keys.
static NSString *const kStatusKey = @"Status";
static NSString *const kMsgUserKey = @"MsgUser";
static NSString *const kTitleKey = @"Title";
static NSString *const kEditorKey = @"Editor";
static NSString *const kCommKey = @"Comm";

// The class whose availability gates the social-framework path.
static NSString *const kSocialComposerClassName = @"SLComposeViewController";

// The response status codes: success, NG-word rejection, a user-facing error, and a retry that
// replaces the keychain first.
static const int kStatusSuccess = 0;
static const int kStatusNGWords = 0x27b0;
static const int kStatusUserError = 0x759e;
static const int kStatusReplaceKeychainRetry = 0x75da;

@implementation JcfUploader {
    NSURL *requestURL;            // +0x08
    jubeatLabAccess *seqUploader; // +0x10
    BOOL bSuccess;                // +0x18
    __weak id delegate;           // +0x20, accessed with objc_loadWeakRetained
    BOOL bEnableSocialFrameWork;  // +0x28
    EditorIDManager *eidMan;      // +0x30
    UIAlertView *eidAlert;        // +0x38
    NSData *uploadData;           // +0x40
}

#pragma mark - Keychain

/** @ghidraAddress 0x1d7df8 */
- (NSString *)getKeyString:(id)key {
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    // The first query finds the generic-password item for this account and returns its attributes.
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount : key,
        (__bridge id)kSecAttrService : bundleID,
        (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne,
        (__bridge id)kSecReturnAttributes : (__bridge id)kCFBooleanTrue,
    };
    CFTypeRef attributesRef = nullptr;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &attributesRef) != errSecSuccess) {
        return nil;
    }
    // The second query reuses the found attributes, this time asking for the item's data.
    NSMutableDictionary *dataQuery =
        [NSMutableDictionary dictionaryWithDictionary:(__bridge NSDictionary *)attributesRef];
    dataQuery[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    dataQuery[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    CFRelease(attributesRef);
    CFTypeRef dataRef = nullptr;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)dataQuery, &dataRef) != errSecSuccess) {
        return nil;
    }
    NSData *data = (__bridge NSData *)dataRef;
    return [[NSString alloc] initWithBytes:data.bytes
                                    length:data.length
                                  encoding:NSUTF8StringEncoding];
}

#pragma mark - Construction

/** @ghidraAddress 0x1d8080 */
- (instancetype)initWithData:(NSData *)data delegate:(id)delegateArg {
    self = [super init];
    if (self) {
        delegate = delegateArg;
        uploadData = [NSData dataWithData:data];
        // The social-framework path is enabled only when SLComposeViewController is present.
        bEnableSocialFrameWork = NSClassFromString(kSocialComposerClassName) != nil;
        bSuccess = YES;
    }
    return self;
}

/** @ghidraAddress 0x1d8184 */
- (void)start {
    if (EditorIDManager.isExistEditorID) {
        [EditorIDManager printKeychain];
        [self uploadStart];
        return;
    }
    // No editor id yet: provisioning one calls back to -successIDDownload:.
    eidMan = [[EditorIDManager alloc] initWithDelegate:self];
}

/** @ghidraAddress 0x1d8214 */
- (void)uploadStart {
    seqUploader = [[jubeatLabAccess alloc] initUploadApi:self seqData:uploadData];
    [seqUploader startAccess];
}

#pragma mark - Delegate relay

/** @ghidraAddress 0x1d8284 */
- (void)sendErrorDelegate:(NSString *)msg {
    if ([delegate respondsToSelector:@selector(uploadError:msgStr:)]) {
        // The binary passes the delegate itself as the sender argument, not self.
        [delegate performSelector:@selector(uploadError:msgStr:)
                       withObject:delegate
                       withObject:msg];
    }
}

#pragma mark - jubeatLabAccess callbacks

/** @ghidraAddress 0x1d832c */
- (void)jubeatLabAccessProceed:(jubeatLabAccess *)access {
}

/** @ghidraAddress 0x1d8330 */
- (void)jubeatLabAccessError:(jubeatLabAccess *)access {
    if (seqUploader == access) {
        seqUploader = nil;
        [self sendErrorDelegate:nil];
    }
}

/** @ghidraAddress 0x1d8390 */
- (void)jubeatLabAccessFinished:(jubeatLabAccess *)access {
    if (seqUploader != access) {
        return;
    }
    NSDictionary *json = access.getDataInJSON;
    seqUploader = nil;
    if (json == nil) {
        [self sendErrorDelegate:nil];
        return;
    }
    int status = [json[kStatusKey] intValue];
    switch (status) {
    case kStatusSuccess:
        if ([delegate respondsToSelector:@selector(uploadSuccess:uploadInfo:)]) {
            [delegate performSelector:@selector(uploadSuccess:uploadInfo:)
                           withObject:delegate
                           withObject:json];
        }
        break;
    case kStatusNGWords: {
        NSMutableArray *ngWords = [[NSMutableArray alloc] init];
        [ngWords addObject:json[kTitleKey]];
        [ngWords addObject:json[kEditorKey]];
        [ngWords addObject:json[kCommKey]];
        if ([delegate respondsToSelector:@selector(uploadNG:ngWords:)]) {
            [delegate performSelector:@selector(uploadNG:ngWords:)
                           withObject:delegate
                           withObject:ngWords];
        }
        break;
    }
    case kStatusReplaceKeychainRetry:
        // A stale keychain: replace it from the response and retry the upload.
        [EditorIDManager replaceKeyChain:json];
        [self uploadStart];
        break;
    case kStatusUserError:
        [self sendErrorDelegate:json[kMsgUserKey]];
        break;
    default:
        [self sendErrorDelegate:json[kMsgUserKey]];
        break;
    }
}

#pragma mark - EditorIDManager callbacks

/** @ghidraAddress 0x1d86dc */
- (void)successIDDownload:(id)sender {
    eidMan = nil;
    if (!EditorIDManager.isExistEditorID) {
        [self sendErrorDelegate:nil];
    } else {
        [self uploadStart];
    }
    eidMan = nil;
}

/** @ghidraAddress 0x1d8754 */
- (void)errorIDDownload:(id)sender msgStr:(NSString *)msg {
    eidMan = nil;
    [self sendErrorDelegate:msg];
}

@end
