#import "RecommendDebug.h"

// The interstitial display specifications, read to annotate the inspection dictionaries. Not
// reconstructed in this tree yet, so forward-declared. See TYPES_PENDING.md.
@interface RecommendAdData : NSObject
+ (nullable NSDictionary *)getInterstitialSpecList;
@end

// The Applilink sandbox test fixtures use these dictionary keys.
static NSString *const kAdModelKey = @"ad_model";
static NSString *const kAdLocationKey = @"ad_location";
static NSString *const kAdTypeKey = @"ad_type";
static NSString *const kStatusKey = @"status";
static NSString *const kAdIdKey = @"ad_id";
static NSString *const kGenreKey = @"genre";
static NSString *const kTitleKey = @"title";
static NSString *const kCountryCodeKey = @"country_code";
static NSString *const kCategoryIdKey = @"category_id";
static NSString *const kAppliIdKey = @"appli_id";
static NSString *const kInstallFlgKey = @"install_flg";
static NSString *const kTargetUrlKey = @"target_url";
static NSString *const kIconUrlKey = @"icon_url";
static NSString *const kBannerIconUrlKey = @"banner_icon_url";
static NSString *const kBannerUrlKey = @"banner_url";
static NSString *const kBannerUrlWideKey = @"banner_url_wide";
static NSString *const kInterstitialBannerUrlKey = @"interstitial_banner_url";
static NSString *const kMovieUrlKey = @"movie_url";
static NSString *const kPosterUrlRectKey = @"poster_url_rect";
static NSString *const kPosterUrlSqKey = @"poster_url_sq";
static NSString *const kMovieEndImgUrlKey = @"movie_end_img_url";
static NSString *const kDescriptionKey = @"description";
static NSString *const kIntroductionKey = @"introduction";
static NSString *const kIndicatorKey = @"indicator";
static NSString *const kCarrierKey = @"carrier";
static NSString *const kPayKey = @"pay";
static NSString *const kDefaultSchemeKey = @"default_scheme";
static NSString *const kDefaultPackageKey = @"default_package";
static NSString *const kLaunchClassKey = @"launch_class";
static NSString *const kIncentiveTypeKey = @"incentive_type";
static NSString *const kReadFlgKey = @"read_flg";
static NSString *const kExternalAdDispMngKey = @"external_ad_disp_mng";
static NSString *const kSortNoKey = @"sort_no";
static NSString *const kSpecialFrameFlgKey = @"special_frame_flg";
static NSString *const kStartDateKey = @"start_date";
static NSString *const kEndDateKey = @"end_date";
static NSString *const kIndicatorStartDateKey = @"indicator_start_date";
static NSString *const kIndicatorEndDateKey = @"indicator_end_date";
static NSString *const kIndicatorStatusKey = @"indicator_status";

static NSString *const kDebugModeDefaultsKey = @"applilink.debug.mode";
static NSString *const kFrequencyDefaultsKey = @"ApplilinkRecommend.frequency";
static NSString *const kDisplayCountDailyDefaultsKey = @"adDisplayCountDaily";
static NSString *const kDisplayCountTotalDefaultsKey = @"adDisplayCountTotal";
static NSString *const kAdLocationDisplaySpecKey = @"ad_location_display_spec";
static NSString *const kAdDisplaySpecKey = @"ad_display_spec";
static NSString *const kDailyKey = @"Daily";
static NSString *const kTotalKey = @"Total";

static NSString *const kAdLocationTop = @"ADL_TOP";
static NSString *const kRewardNone = @"REWARD_NONE";
static NSString *const kTargetUrl = @"applilink://ext-app:80/send?url";
// The shared dummy placeholder for every unset text field in the sandbox fixtures.
static NSString *const kPlaceholder = @"-";
static NSString *const kGenre = @"000";
static NSString *const kSandboxStartDate = @"2014-07-30 10:00:00";
static NSString *const kSandboxEndDate = @"2015-07-30 10:00:00";
static NSString *const kAdTypeBanner = @"2";
static NSString *const kAdTypeIcon = @"3";
static NSString *const kAdTypeMovie = @"3";

// The single movie record's sandbox media URLs.
static NSString *const kMovieUrl = @"https://sandbox.applilink.jp/img/video/wscs_2m.mp4";
static NSString *const kMoviePosterUrl = @"https://sandbox.applilink.jp/img/popup/wsc_main_bg2.png";

// Builds the six sandbox advert records that back both bannerList and iconList. The two lists are
// identical apart from the ad_type value and the type of the install-flag object, so the binary's
// two large builder methods are recovered as one parameterised helper.
static inline NSArray<NSDictionary *> *RecommendDebugAdRecordsWithAdType(NSString *adType,
                                                                         id installFlg) {
    NSString *const suffixes[] = {@"A", @"B", @"C", @"D", @"E", @"F"};
    NSString *const adIds[] = {@"10241", @"10242", @"10243", @"10244", @"10245", @"10246"};
    NSString *const appliIds[] = {@"89999", @"89997", @"89996", @"89995", @"89994", @"89993"};
    NSMutableArray<NSDictionary *> *records = [NSMutableArray arrayWithCapacity:6];
    for (NSUInteger i = 0; i < 6; ++i) {
        NSString *suffix = suffixes[i];
        NSString *appliId = appliIds[i];
        NSString *iconUrl = [NSString
            stringWithFormat:@"https://sandbox.applilink.jp/img/appli_icon/dummy_icon%lu.png",
                             (unsigned long)(i + 1)];
        NSString *bannerUrl = [NSString
            stringWithFormat:@"https://sandbox.applilink.jp/img/banner/test%@.png", suffix];
        NSString *interstitialUrl = [NSString
            stringWithFormat:
                @"https://sandbox.applilink.jp/img/interstitial/bnr_type%@_570x570.jpg", suffix];
        NSDictionary *externalAdDispMng = @{
            kSortNoKey : @0,
            kSpecialFrameFlgKey : @0,
            kIndicatorKey : kPlaceholder,
            kStartDateKey : kSandboxStartDate,
            kEndDateKey : kSandboxEndDate,
            kIndicatorStartDateKey : kSandboxStartDate,
            kIndicatorEndDateKey : kSandboxEndDate,
            kIndicatorStatusKey : @1,
        };
        [records addObject:@{
            kAdIdKey : adIds[i],
            kGenreKey : kGenre,
            kTitleKey : [@"000" stringByAppendingString:suffix],
            kCountryCodeKey : @"jp",
            kCategoryIdKey : [@"test.ios." stringByAppendingString:suffix],
            kAppliIdKey : appliId,
            kInstallFlgKey : installFlg,
            kTargetUrlKey : kTargetUrl,
            kIconUrlKey : kPlaceholder,
            kBannerIconUrlKey : iconUrl,
            kBannerUrlKey : bannerUrl,
            kBannerUrlWideKey : kPlaceholder,
            kInterstitialBannerUrlKey : interstitialUrl,
            kDescriptionKey : kPlaceholder,
            kIntroductionKey : [@"000000" stringByAppendingString:suffix],
            kIndicatorKey : kPlaceholder,
            kCarrierKey : @"ip",
            kPayKey : @0,
            kDefaultSchemeKey : [@"applilink" stringByAppendingString:appliId],
            kDefaultPackageKey : [@"jp.applilink.reward.sample" stringByAppendingString:suffix],
            kLaunchClassKey : kPlaceholder,
            kIncentiveTypeKey : kRewardNone,
            kReadFlgKey : @0,
            kExternalAdDispMngKey : externalAdDispMng,
            kAdTypeKey : adType,
        }];
    }
    return records;
}

@implementation RecommendDebug

#pragma mark - Canned lists

/** @ghidraAddress 0x248764 */
+ (NSArray<NSDictionary *> *)adModelSettingList {
    return @[
        @{kAdModelKey : @"1", kAdLocationKey : kAdLocationTop, kAdTypeKey : @"1"},
        @{kAdModelKey : @"4", kAdLocationKey : kAdLocationTop, kAdTypeKey : @"4"},
        @{kAdModelKey : @"5", kAdLocationKey : kAdLocationTop, kAdTypeKey : @"5"},
        @{kAdModelKey : @"100", kAdLocationKey : kAdLocationTop, kAdTypeKey : @"2"},
        @{kAdModelKey : @"101", kAdLocationKey : kAdLocationTop, kAdTypeKey : @"3"},
    ];
}

/** @ghidraAddress 0x2489d4 */
+ (NSArray<NSDictionary *> *)bannerDisplayStatusList {
    return @[
        @{kAdModelKey : @"1", kStatusKey : @"1"},
        @{kAdModelKey : @"4", kStatusKey : @"1"},
        @{kAdModelKey : @"5", kStatusKey : @"1"},
        @{kAdModelKey : @"100", kStatusKey : @"1"},
        @{kAdModelKey : @"101", kStatusKey : @"1"},
    ];
}

/** @ghidraAddress 0x248bdc */
+ (NSArray<NSDictionary *> *)bannerList {
    // The banner list carries the install flag as the string @"0".
    return RecommendDebugAdRecordsWithAdType(kAdTypeBanner, @"0");
}

/** @ghidraAddress 0x24a284 */
+ (NSArray<NSDictionary *> *)iconList {
    // The icon list carries the install flag as the number @0.
    return RecommendDebugAdRecordsWithAdType(kAdTypeIcon, @0);
}

/** @ghidraAddress 0x24b9e8 */
+ (NSArray<NSDictionary *> *)movieList {
    // The movie list is a single sandbox record: the banner/icon shape with the four banner image
    // keys replaced by the movie, two poster, and end-image URLs. The two posters share one URL.
    NSDictionary *externalAdDispMng = @{
        kSortNoKey : @0,
        kSpecialFrameFlgKey : @0,
        kIndicatorKey : kPlaceholder,
        kStartDateKey : kSandboxStartDate,
        kEndDateKey : kSandboxEndDate,
        kIndicatorStartDateKey : kSandboxStartDate,
        kIndicatorEndDateKey : kSandboxEndDate,
        kIndicatorStatusKey : @1,
    };
    return @[ @{
        kAdIdKey : @"99999",
        kGenreKey : kGenre,
        kTitleKey : @"000A",
        kCountryCodeKey : @"jp",
        kCategoryIdKey : @"test.ios.A",
        kAppliIdKey : @"89999",
        kInstallFlgKey : @0,
        kTargetUrlKey : kTargetUrl,
        kIconUrlKey : kPlaceholder,
        kBannerIconUrlKey : @"https://sandbox.applilink.jp/img/appli_icon/dummy_icon1.png",
        kBannerUrlKey : @"https://sandbox.applilink.jp/img/banner/testA.png",
        kBannerUrlWideKey : kPlaceholder,
        kInterstitialBannerUrlKey :
            @"https://sandbox.applilink.jp/img/interstitial/bnr_typeA_570x570.jpg",
        kDescriptionKey : kPlaceholder,
        kIntroductionKey : @"000000A",
        kIndicatorKey : kPlaceholder,
        kCarrierKey : @"ip",
        kPayKey : @0,
        kDefaultSchemeKey : @"applilink89999",
        kDefaultPackageKey : @"jp.applilink.reward.sampleA",
        kLaunchClassKey : kPlaceholder,
        kIncentiveTypeKey : kRewardNone,
        kMovieUrlKey : kMovieUrl,
        kPosterUrlRectKey : kMoviePosterUrl,
        kPosterUrlSqKey : kMoviePosterUrl,
        kMovieEndImgUrlKey : kPlaceholder,
        kReadFlgKey : @0,
        kExternalAdDispMngKey : externalAdDispMng,
        kAdTypeKey : kAdTypeMovie,
    } ];
}

#pragma mark - Debug-mode flag

/** @ghidraAddress 0x24bec8 */
+ (void)debugMode:(id)debugMode {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (debugMode == nil) {
        [defaults removeObjectForKey:kDebugModeDefaultsKey];
    } else {
        [defaults setObject:debugMode forKey:kDebugModeDefaultsKey];
        [NSUserDefaults.standardUserDefaults synchronize];
    }
}

/** @ghidraAddress 0x24bfa0 */
+ (id)getDebugMode {
    return [NSUserDefaults.standardUserDefaults objectForKey:kDebugModeDefaultsKey];
}

#pragma mark - Inspection

/** @ghidraAddress 0x24c00c */
+ (NSMutableDictionary *)getFrequencyStatus {
    NSMutableDictionary *status = [NSMutableDictionary dictionary];
    NSData *data = [NSUserDefaults.standardUserDefaults dataForKey:kFrequencyDefaultsKey];
    if (data != nil) {
        [status addEntriesFromDictionary:[NSKeyedUnarchiver unarchiveObjectWithData:data]];
    }
    NSDictionary *specList = [RecommendAdData getInterstitialSpecList];
    if (specList.count != 0) {
        status[kAdLocationDisplaySpecKey] = specList[kAdLocationDisplaySpecKey];
    }
    return status;
}

/** @ghidraAddress 0x24c190 */
+ (NSMutableDictionary *)getDisplaySpec {
    NSMutableDictionary *spec = [NSMutableDictionary dictionary];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSData *dailyData = [defaults dataForKey:kDisplayCountDailyDefaultsKey];
    if (dailyData != nil) {
        spec[kDailyKey] = [NSKeyedUnarchiver unarchiveObjectWithData:dailyData];
    }
    NSData *totalData = [defaults dataForKey:kDisplayCountTotalDefaultsKey];
    if (totalData != nil) {
        spec[kTotalKey] = [NSKeyedUnarchiver unarchiveObjectWithData:totalData];
    }
    NSDictionary *specList = [RecommendAdData getInterstitialSpecList];
    if (specList.count != 0) {
        spec[kAdDisplaySpecKey] = specList[kAdDisplaySpecKey];
    }
    return spec;
}

@end
