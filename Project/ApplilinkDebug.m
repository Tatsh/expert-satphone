#import "ApplilinkDebug.h"

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"

// The applilink SDK collaborators this facade forwards to that are not reconstructed in this tree
// yet, or whose reconstructed headers do not yet declare these members. See TYPES_PENDING.md.
@interface ApplilinkConsts (Debug)
+ (NSString *)countryCode;
+ (NSString *)categoryId;
@end

@interface ApplilinkCore (Debug)
+ (NSString *)udid_cache;
+ (NSString *)ad_udid_cache;
+ (NSString *)old_udid_cache;
+ (void)clearUDID;
+ (void)clearKeyChainOldUDID;
+ (void)clearAdUDID;
@end

@interface AnalysisNetworkCore : NSObject
+ (void)clearInitalize;
+ (void)clearDAU;
@end

@interface RewardCore : NSObject
+ (instancetype)sharedInstance;
- (void)clearSession;
- (void)clearAdStatus;
@end

@interface RecommendCore : NSObject
+ (instancetype)sharedInstance;
- (void)clearSession;
- (void)clearAdStatus;
@end

@interface RecommendAdCache : NSObject
+ (void)allClearCacheBannerImage;
@end

@interface RecommendDebug : NSObject
+ (void)debugMode:(id)debugMode;
+ (id)getDebugMode;
+ (NSMutableDictionary *)getFrequencyStatus;
+ (NSMutableDictionary *)getDisplaySpec;
@end

// The Applilink SDK version this debug build reports, combined as "<base>.<build>".
static NSString *const kSdkVersionBase = @"2.4.0";
static NSString *const kSdkVersionBuild = @"0";
static NSString *const kVersionFormat = @"%@.%@";

@implementation ApplilinkDebug

/** @ghidraAddress 0x250f60 */
+ (NSString *)countryCode {
    return [ApplilinkConsts countryCode];
}

/** @ghidraAddress 0x250f78 */
+ (NSString *)categoryId {
    return [ApplilinkConsts categoryId];
}

/** @ghidraAddress 0x250f90 */
+ (NSString *)udid {
    return [ApplilinkCore udid_cache];
}

/** @ghidraAddress 0x250fa8 */
+ (NSString *)ad_udid {
    return [ApplilinkCore ad_udid_cache];
}

/** @ghidraAddress 0x250fc0 */
+ (NSString *)old_udid {
    return [ApplilinkCore old_udid_cache];
}

/** @ghidraAddress 0x250fd8 */
+ (void)clearUDID {
    [ApplilinkCore clearUDID];
}

/** @ghidraAddress 0x250ff0 */
+ (void)clearKeyChainOldUDID {
    [ApplilinkCore clearKeyChainOldUDID];
}

/** @ghidraAddress 0x251008 */
+ (void)clearAdUDID {
    [ApplilinkCore clearAdUDID];
}

/** @ghidraAddress 0x251020 */
+ (NSString *)versionDev {
    return [NSString stringWithFormat:kVersionFormat, kSdkVersionBase, kSdkVersionBuild];
}

/** @ghidraAddress 0x25106c */
+ (void)clearSession {
    [[RewardCore sharedInstance] clearSession];
    [[RecommendCore sharedInstance] clearSession];
}

/** @ghidraAddress 0x2510f8 */
+ (void)clearAdStatus {
    [[RewardCore sharedInstance] clearAdStatus];
    [[RecommendCore sharedInstance] clearAdStatus];
}

/** @ghidraAddress 0x251184 */
+ (void)clearInitalize {
    [AnalysisNetworkCore clearInitalize];
}

/** @ghidraAddress 0x2511c0 */
+ (void)clearDAU {
    [AnalysisNetworkCore clearDAU];
}

/** @ghidraAddress 0x2511d8 */
+ (void)debugMode:(id)debugMode {
    [RecommendDebug debugMode:debugMode];
}

/** @ghidraAddress 0x2511f0 */
+ (id)getDebugMode {
    return [RecommendDebug getDebugMode];
}

/** @ghidraAddress 0x251208 */
+ (void)allClearCacheBannerImage {
    [RecommendAdCache allClearCacheBannerImage];
}

/** @ghidraAddress 0x251220 */
+ (NSMutableDictionary *)getFrequencyStatus {
    return [RecommendDebug getFrequencyStatus];
}

/** @ghidraAddress 0x251238 */
+ (NSMutableDictionary *)getDisplaySpec {
    return [RecommendDebug getDisplaySpec];
}

@end
