#import "GameNetworkUtil.h"

#import "BFCodec.h"
#import "EditorIDManager.h"
#import "TweetResourceManager.h"
#import "cipher_keys.h"

// The Konami "agx" host and CGI path every endpoint is built from.
static NSString *const kHost = @"agx.s.konaminet.jp";
static NSString *const kCgiPath = @"/agx/main/cgi";
// The store target region.
static NSString *const kStoreTarget = @"JP";

// The endpoint format strings, verbatim from the pool. The two-step builders assemble a path with
// the region first, then prepend the scheme and host.
static NSString *const kRewardCheckFormat = @"https://%@%s/reward/check/";
static NSString *const kRecommendTwitterFormat = @"https://%@%s/recommend/twitter/";
static NSString *const kRecommendFacebookFormat = @"https://%@%s/recommend/facebook/";
static NSString *const kSearchPackFormat = @"https://%@%s/recommended_pack/?target=%s&music=%d";
static NSString *const kStartupPathFormat = @"%s/startup/?target=%s";
static NSString *const kLogPlayPathFormat = @"%s/log/play/";
static NSString *const kSchemeHostFormat = @"https://%@%@";
// The install-count record key and its ciphered-value format.
static NSString *const kInstallCountFormat = @"%@%d";
static NSString *const kInstallCountDefaultsKey = @"PrefRewardApplicationNum";

@implementation GameNetworkUtil

#pragma mark - Endpoints

/** @ghidraAddress 0x1a4770 */
+ (NSURL *)rewardCheckURL {
    NSString *string = [NSString stringWithFormat:kRewardCheckFormat, kHost, kCgiPath.UTF8String];
    return [NSURL URLWithString:string];
}

/** @ghidraAddress 0x1a4808 */
+ (NSURL *)rewardEnableURL {
    NSString *path = [NSString
        stringWithFormat:kStartupPathFormat, kCgiPath.UTF8String, kStoreTarget.UTF8String];
    NSString *string = [NSString stringWithFormat:kSchemeHostFormat, kHost, path];
    return [[NSURL alloc] initWithString:string];
}

/** @ghidraAddress 0x1a48e4 */
+ (NSURL *)recommendEnableURL {
    NSString *path = [NSString
        stringWithFormat:kStartupPathFormat, kCgiPath.UTF8String, kStoreTarget.UTF8String];
    NSString *string = [NSString stringWithFormat:kSchemeHostFormat, kHost, path];
    return [[NSURL alloc] initWithString:string];
}

/** @ghidraAddress 0x1a4e84 */
+ (NSURL *)scoreSendURL {
    NSString *path = [NSString stringWithFormat:kLogPlayPathFormat, kCgiPath.UTF8String];
    NSString *string = [NSString stringWithFormat:kSchemeHostFormat, kHost, path];
    return [[NSURL alloc] initWithString:string];
}

/** @ghidraAddress 0x1a4f58 */
+ (NSURL *)recommendTwitterURL {
    NSString *string =
        [NSString stringWithFormat:kRecommendTwitterFormat, kHost, kCgiPath.UTF8String];
    return [NSURL URLWithString:string];
}

/** @ghidraAddress 0x1a4ff0 */
+ (NSURL *)recommendFacebookURL {
    NSString *string =
        [NSString stringWithFormat:kRecommendFacebookFormat, kHost, kCgiPath.UTF8String];
    return [NSURL URLWithString:string];
}

/** @ghidraAddress 0x1a5088 */
+ (NSURL *)searchPackIDURL:(int)musicID {
    NSString *string = [NSString stringWithFormat:kSearchPackFormat,
                                                  kHost,
                                                  kCgiPath.UTF8String,
                                                  kStoreTarget.UTF8String,
                                                  musicID];
    return [NSURL URLWithString:string];
}

/** @ghidraAddress 0x1a5138 */
+ (NSString *)getStoreTarget {
    // The binary builds this from the C literal, not the NSString constant above.
    return [NSString stringWithUTF8String:"JP"];
}

#pragma mark - Install count

/** @ghidraAddress 0x1a49c0 */
+ (void)fillInstallAppNum:(int)appNum {
    int stored = [self readInstallAppNum];
    // The tweet-resource store always sees the larger of the stored and new counts.
    int effective = stored < appNum ? appNum : stored;
    [[TweetResourceManager sharedManager] setInstallApplicationNum:effective];
    // Only a genuine increase is persisted.
    if (appNum <= stored) {
        return;
    }
    NSString *keyString = [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
    NSString *record = [NSString stringWithFormat:kInstallCountFormat, keyString, appNum];
    NSMutableData *data =
        [NSMutableData dataWithData:[record dataUsingEncoding:NSUTF8StringEncoding]];
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:CreateResourceDataCipherKey()];
    [codec encipher:data];
    [NSUserDefaults.standardUserDefaults setObject:data forKey:kInstallCountDefaultsKey];
    [NSUserDefaults.standardUserDefaults synchronize];
}

/** @ghidraAddress 0x1a4c28 */
+ (int)readInstallAppNum {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (!EditorIDManager.isExistEditorID) {
        [defaults removeObjectForKey:kInstallCountDefaultsKey];
        return 0;
    }
    NSMutableData *data = [defaults objectForKey:kInstallCountDefaultsKey];
    if (data == nil) {
        return 0;
    }
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:CreateResourceDataCipherKey()];
    [codec decipher:data];
    NSString *keyString = [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
    NSString *record = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (record == nil) {
        return 0;
    }
    NSRange range = [record rangeOfString:keyString];
    if (range.location != 0) {
        // The stored record belongs to a different editor id; drop it.
        [defaults removeObjectForKey:kInstallCountDefaultsKey];
        return 0;
    }
    // The key prefix sits at the start, so the count follows it.
    return [[record substringFromIndex:range.length] intValue];
}

@end
