#import "RecommendAdData.h"

#import <UIKit/UIKit.h>

#import "ApplilinkFile.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkUtilities.h"
#import "NSStringURLEncoding.h"
#import "RecommendDebug.h"

// NSUserDefaults archive keys.
static NSString *const kAllAdDataKey = @"ApplilinkRecommend.allAdData";
static NSString *const kResponseNsDataKey = @"ApplilinkNetwork.responseNsData";
static NSString *const kFrequencyKey = @"ApplilinkRecommend.frequency";
static NSString *const kAdDisplayCountDailyKey = @"adDisplayCountDaily";
static NSString *const kAdDisplayCountTotalKey = @"adDisplayCountTotal";

// Sub-keys of the archived allAdData blob. The archive keys its entries by the fully qualified
// name, so each one repeats the defaults key it was stored under rather than being a bare sub-key.
static NSString *const kBannerDisplayStatusListKey =
    @"ApplilinkRecommend.allAdData.banner_display_status_list";
static NSString *const kAdModelSettingListKey =
    @"ApplilinkRecommend.allAdData.ad_model_setting_list";
static NSString *const kAdListKey = @"ApplilinkRecommend.allAdData.list";
static NSString *const kSelfListKey = @"ApplilinkRecommend.allAdData.self";
static NSString *const kInterstitialSpecListKey =
    @"ApplilinkRecommend.allAdData.interstitial_spec_list";

// Advert-record and display-specification field keys.
static NSString *const kAdIdKey = @"ad_id";
static NSString *const kAppliIdKey = @"appli_id";
static NSString *const kAdTypeKey = @"ad_type";
static NSString *const kAdModelKey = @"ad_model";
static NSString *const kAdLocationKey = @"ad_location";
static NSString *const kStatusKey = @"status";
static NSString *const kPrimaryFlgKey = @"primary_flg";
static NSString *const kInstallFlgKey = @"install_flg";
static NSString *const kDefaultSchemeKey = @"default_scheme";
static NSString *const kBannerUrlKey = @"banner_url";
static NSString *const kBannerUrlListKey = @"banner_url_list";
static NSString *const kBannerIconUrlKey = @"banner_icon_url";
static NSString *const kBannerIconUrlListKey = @"banner_icon_url_list";
static NSString *const kInterstitialBannerUrlKey = @"interstitial_banner_url";
static NSString *const kInterstitialBannerUrlListKey = @"interstitial_banner_url_list";
static NSString *const kMovieUrlKey = @"movie_url";
static NSString *const kMovieUrlListKey = @"movie_url_list";
static NSString *const kPosterUrlRectKey = @"poster_url_rect";
static NSString *const kPosterUrlRectListKey = @"poster_url_rect_list";
static NSString *const kCreativeIdKey = @"creative_id";
static NSString *const kPriorityKey = @"priority";
static NSString *const kPriorityKeyPath = @"priority.intValue";
static NSString *const kAdDisplaySpecKey = @"ad_display_spec";
static NSString *const kAdLocationDisplaySpecKey = @"ad_location_display_spec";
static NSString *const kAdIdToKey = @"ad_id_to";
static NSString *const kMaxDisplayCountDailyKey = @"max_display_count_daily";
static NSString *const kMaxDisplayCountTotalKey = @"max_display_count_total";
static NSString *const kInstalledAdDisplayFlgKey = @"installed_ad_display_flg";
static NSString *const kExternalAdDispMngKey = @"external_ad_disp_mng";
static NSString *const kAdContentKindKey = @"ad_content_kind";
static NSString *const kExternalAdDispMngEndDateKey = @"external_ad_disp_mng.end_date";
static NSString *const kAdDisplayDateKey = @"adDisplayDate";
static NSString *const kFrequencyNKey = @"frequency_n";
static NSString *const kFrequencyMKey = @"frequency_m";

// Format strings.
static NSString *const kIntegerFormat = @"%d";
static NSString *const kCountFormat = @"count_%@";
static NSString *const kFrequencyNFormat = @"frequency_n_%@";
static NSString *const kFrequencyMFormat = @"frequency_m_%@";

// Install-flag literal values, matched and returned as strings.
static NSString *const kInstallFlgOn = @"1";
static NSString *const kInstallFlgOff = @"0";

// The movie ad-content-kind literal, compared both as a string and as an integer.
static NSString *const kMovieContentKindString = @"2";

// Small literals.
static NSString *const kSchemeSeparator = @"://";
static NSString *const kJapanLocaleIdentifier = @"JP";
static NSString *const kJapanTimeZoneAbbreviation = @"JST";
static NSString *const kDateTimeFormat = @"yyyy-MM-dd HH:mm:ss";
static NSString *const kDateFormat = @"yyyy/MM/dd";

// The list builders escape every literal newline in a string field to a two-character backslash-n
// before storing it back in the mutable record.
static NSString *const kNewlineCharacter = @"\n";
static NSString *const kNewlineEscape = @"\\n";

// Movie-URL decoding literals used by getMovieUrlList.
static NSString *const kMovieUrlPrefix = @"applilink://ext-app:80/movie?";
static NSString *const kMovieUrlFieldPrefix = @"movie_url=";
static NSString *const kMovieUrlFieldMarker = @"movie_url";
static NSString *const kFieldSeparator = @"&";

// The user-info key each lottery-suppression message is filed under.
static NSString *const kErrorUserInfoKey = @"Error";

// Lottery-suppression messages, reported through the ApplilinkNetworkError user-info.
static NSString *const kInterstitialSpecListIsZeroMessage = @"interstitial_spec_list is zero";
static NSString *const kInterstitialSpecFrequencyIsZeroMessage =
    @"interstitial_spec_list.ad_display_spec frequency is zero";
static NSString *const kLotteryMissFormat =
    @"display lottery is miss. Indication frequency:%d/%d execute:%d/%d";

// Advert-type identifiers used by the lottery helpers.
enum {
    kRecommendAdTypeAppBanner = 1,
    kRecommendAdTypeLotteryBanner = 2,
    kRecommendAdTypeLotteryIcon = 3,
    kRecommendAdTypeInterstitial = 5,
};

// The advert-content kind that marks a playable movie creative.
enum {
    kRecommendAdContentKindMovie = 2,
};

// The maximum number of lottery icons drawn per request.
static const int kMaxLotteryIconCount = 4;

// The end-date substring length compared as a plain integer year before falling back to a date
// comparison, and the sentinel year below which the comparison is skipped.
enum {
    kEndDateYearPrefixLength = 4,
    kEndDateComparableYear = 3000,
};

// Applilink error codes surfaced by the interstitial lottery.
enum {
    kApplilinkErrorInterstitialLotteryMiss = 0x40a,
    kApplilinkErrorInterstitialSpecInvalid = 0x40b,
};

// Look up a sub-object of the archived allAdData blob by its fully qualified key.
static inline id RecommendAdDataUnarchivedAllAdDataObjectForKey(NSString *key) {
    NSData *data = [NSUserDefaults.standardUserDefaults dataForKey:kAllAdDataKey];
    if (data == nil) {
        return nil;
    }
    return [NSKeyedUnarchiver unarchiveObjectWithData:data][key];
}

// Copy a source dictionary into a mutable record, escaping literal newlines in each string value.
static inline NSMutableDictionary *
RecommendAdDataMutableRecordEscapingNewlines(NSDictionary *source) {
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithCapacity:source.count];
    for (id key in source.allKeys) {
        id value = source[key];
        if ([value isKindOfClass:NSString.class]) {
            value = [value stringByReplacingOccurrencesOfString:kNewlineCharacter
                                                     withString:kNewlineEscape];
        }
        record[key] = value;
    }
    return record;
}

@implementation RecommendAdData

#pragma mark - Archived payload accessors

+ (NSArray *)getBannerDisplayStatusList {
    if (RecommendDebug.getDebugMode) {
        return RecommendDebug.bannerDisplayStatusList;
    }
    return RecommendAdDataUnarchivedAllAdDataObjectForKey(kBannerDisplayStatusListKey);
}

+ (NSArray *)getAdModelSettingList {
    if (RecommendDebug.getDebugMode) {
        return RecommendDebug.adModelSettingList;
    }
    return RecommendAdDataUnarchivedAllAdDataObjectForKey(kAdModelSettingListKey);
}

+ (NSArray *)getAdList {
    return RecommendAdDataUnarchivedAllAdDataObjectForKey(kAdListKey);
}

+ (NSArray *)getSelfList {
    return RecommendAdDataUnarchivedAllAdDataObjectForKey(kSelfListKey);
}

+ (NSData *)getResponseNsData {
    return [NSUserDefaults.standardUserDefaults objectForKey:kResponseNsDataKey];
}

+ (NSDictionary *)getInterstitialSpecList {
    return RecommendAdDataUnarchivedAllAdDataObjectForKey(kInterstitialSpecListKey);
}

#pragma mark - Narrowed record lookups

+ (int)getAdStatusByAdModel:(int)adModel {
    NSString *model = [NSString stringWithFormat:kIntegerFormat, adModel];
    NSArray *list = [ApplilinkUtilities narrowedListWithList:[self getBannerDisplayStatusList]
                                                      object:model
                                                      forKey:kAdModelKey];
    if (list.count == 0) {
        return 0;
    }
    id status = list[0][kStatusKey];
    if (![status isKindOfClass:NSString.class]) {
        return 0;
    }
    return [status intValue];
}

+ (NSArray *)getAdDataByAdId:(int)adId {
    NSString *identifier = [NSString stringWithFormat:kIntegerFormat, adId];
    NSArray *list = [ApplilinkUtilities narrowedListWithList:[self getAdList]
                                                      object:identifier
                                                      forKey:kAdIdKey];
    if (list.count == 0) {
        return nil;
    }
    return list;
}

+ (NSDictionary *)getAdDataList:(NSArray *)list adType:(int)adType {
    NSString *type = [NSString stringWithFormat:kIntegerFormat, adType];
    for (NSDictionary *record in list) {
        if ([type isEqualToString:record[kAdTypeKey]]) {
            return record;
        }
    }
    return nil;
}

+ (NSDictionary *)getAdDataWithAppliId:(NSString *)appliId {
    NSArray *list = [ApplilinkUtilities narrowedListWithList:[self getAdList]
                                                      object:appliId
                                                      forKey:kAppliIdKey];
    for (NSDictionary *record in list) {
        if ([kInstallFlgOn isEqualToString:record[kPrimaryFlgKey]]) {
            return record;
        }
    }
    if (list.count == 0) {
        return nil;
    }
    return list[0];
}

+ (NSArray *)getAdListByAdType:(int)adType {
    NSString *type = [NSString stringWithFormat:kIntegerFormat, adType];
    return [ApplilinkUtilities narrowedListWithList:[self getAdList] object:type forKey:kAdTypeKey];
}

#pragma mark - Application list builders

+ (NSArray *)getAppBannerList {
    NSMutableArray *result = [NSMutableArray array];
    NSDictionary *bannerData = [self getLotteryBannerData];
    if (bannerData.count == 0) {
        return nil;
    }
    NSMutableDictionary *record = RecommendAdDataMutableRecordEscapingNewlines(bannerData);
    record[kInstallFlgKey] = [self getInstallFlgWithAdData:record];
    NSArray *urlList = record[kBannerUrlListKey];
    id bannerUrl = record[kBannerUrlKey];
    if (urlList.count != 0) {
        bannerUrl = urlList[arc4random() % urlList.count];
    }
    if (![ApplilinkFile getBannerWithUrl:bannerUrl]) {
        return nil;
    }
    if ([bannerUrl isKindOfClass:NSNull.class]) {
        return nil;
    }
    NSString *fileName = [ApplilinkUtilities getFileNameFromPath:bannerUrl];
    record[kBannerUrlKey] =
        [ApplilinkFile.getBannerCachePath stringByAppendingPathComponent:fileName];
    record[kCreativeIdKey] = fileName.lastPathComponent;
    [result addObject:record];
    return result;
}

+ (NSArray *)getAppIconList {
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *iconData in [self getLotteryIconData]) {
        NSMutableDictionary *record = RecommendAdDataMutableRecordEscapingNewlines(iconData);
        record[kInstallFlgKey] = [self getInstallFlgWithAdData:record];
        NSArray *urlList = record[kBannerIconUrlListKey];
        id iconUrl = record[kBannerIconUrlKey];
        if (urlList.count != 0) {
            iconUrl = urlList[arc4random() % urlList.count];
            record[kBannerIconUrlKey] = iconUrl;
        }
        if ([iconUrl isKindOfClass:NSNull.class]) {
            continue;
        }
        NSString *fileName = [ApplilinkUtilities getFileNameFromPath:iconUrl];
        record[kCreativeIdKey] = fileName.lastPathComponent;
        [result addObject:record];
    }
    return result;
}

+ (NSArray *)getAppInterstitialList:(BOOL)movieFlg {
    NSMutableArray *result = [NSMutableArray array];
    NSDictionary *interstitialData = [self getLotteryInterstitialDataForMovie:movieFlg];
    if (interstitialData.count == 0) {
        return nil;
    }
    NSMutableDictionary *record = RecommendAdDataMutableRecordEscapingNewlines(interstitialData);
    BOOL isMovie = [self checkMovieWithAdData:record];
    id creativeUrl;
    if (isMovie) {
        // The binary reads movie_url purely for effect before choosing the paired movie and poster
        // entries; its result is discarded.
        (void)record[kMovieUrlKey];
        creativeUrl = record[kPosterUrlRectKey];
        NSArray *movieList = record[kMovieUrlListKey];
        NSArray *posterList = record[kPosterUrlRectListKey];
        if (movieList.count != 0 && posterList.count != 0) {
            NSUInteger count = movieList.count;
            if (posterList.count < count) {
                count = posterList.count;
            }
            NSUInteger index = arc4random() % count;
            record[kMovieUrlKey] = movieList[index];
            creativeUrl = posterList[index];
            record[kPosterUrlRectKey] = creativeUrl;
        }
    } else {
        creativeUrl = record[kInterstitialBannerUrlKey];
        NSArray *urlList = record[kInterstitialBannerUrlListKey];
        if (urlList.count != 0) {
            creativeUrl = urlList[arc4random() % urlList.count];
            record[kInterstitialBannerUrlKey] = creativeUrl;
        }
    }
    if (![ApplilinkFile getBannerWithUrl:creativeUrl]) {
        return nil;
    }
    if ([creativeUrl isKindOfClass:NSNull.class]) {
        return nil;
    }
    NSString *fileName = [ApplilinkUtilities getFileNameFromPath:creativeUrl];
    NSString *cachePath =
        [ApplilinkFile.getBannerCachePath stringByAppendingPathComponent:fileName];
    record[isMovie ? kPosterUrlRectKey : kInterstitialBannerUrlKey] = cachePath;
    record[kCreativeIdKey] = fileName.lastPathComponent;
    record[kInstallFlgKey] = [self getInstallFlgWithAdData:record];
    [result addObject:record];
    return result;
}

#pragma mark - Lottery draws

+ (NSDictionary *)getLotteryBannerData {
    NSArray *list = [self getAdListByAdType:kRecommendAdTypeLotteryBanner];
    if (list.count == 0) {
        return nil;
    }
    list = [self getAdListTermForList:list];
    if (list.count == 0) {
        return nil;
    }
    return list[arc4random() % list.count];
}

+ (NSArray *)getLotteryIconData {
    NSArray *list = [self getAdListByAdType:kRecommendAdTypeLotteryIcon];
    if (list.count == 0) {
        return nil;
    }
    list = [self getAdListTermForList:list];
    if (list.count == 0) {
        return nil;
    }
    list = [self shuffled:list];
    NSUInteger count = list.count < kMaxLotteryIconCount ? list.count : kMaxLotteryIconCount;
    NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, count)];
    return [list objectsAtIndexes:indexes];
}

+ (NSDictionary *)getLotteryInterstitialDataForMovie:(BOOL)movieFlg {
    NSArray *list = [self getInterstitialSpecList][kAdDisplaySpecKey];
    if (list.count == 0) {
        return nil;
    }
    list = [self getInterstitialSpecCountForAdDisplaySpecList:list];
    if (list.count == 0) {
        return nil;
    }
    list = [self getInterstitialSpecInstallForAdDisplaySpecList:list movieFlg:movieFlg];
    if (list.count == 0) {
        return nil;
    }
    return [self getLotteryInterstitialDataWithList:list];
}

+ (NSDictionary *)getLotteryInterstitialDataWithList:(NSArray *)list {
    NSUInteger totalPriority = 0;
    for (NSDictionary *record in list) {
        totalPriority += [[record valueForKeyPath:kPriorityKey] integerValue];
    }
    uint32_t draw = arc4random();
    // The binary has no zero test here: its udiv/msub pair returns the draw unchanged when the
    // total is zero, because arm64 division by zero yields zero. The ternary reproduces that, since
    // the same expression in C would be undefined.
    NSUInteger target = totalPriority == 0 ? (draw + 1) : ((draw % totalPriority) + 1);
    NSUInteger cumulative = 0;
    for (NSDictionary *record in list) {
        // Yes, the second loop uses intValue where the first uses integerValue.
        cumulative += [[record valueForKeyPath:kPriorityKey] intValue];
        if (target <= cumulative) {
            return record;
        }
    }
    return nil;
}

#pragma mark - Interstitial specification filtering

+ (NSArray *)getInterstitialSpecPriorityList {
    NSArray *specs = [self getInterstitialSpecList][kAdDisplaySpecKey];
    NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:kPriorityKeyPath
                                                               ascending:NO];
    return [specs sortedArrayUsingDescriptors:@[ descriptor ]];
}

+ (NSArray *)getInterstitialSpecCountForAdDisplaySpecList:(NSArray *)list {
    NSMutableArray *result = [NSMutableArray array];
    NSDictionary *dailyCounts = [self getAdDisplayCountDailyDictionary];
    NSDictionary *totalCounts = [self getAdDisplayCountTotalDictionary];
    if (totalCounts == nil) {
        // The binary returns the unfiltered input list when there is no total-count record.
        return list;
    }
    for (NSDictionary *spec in list) {
        if (![spec isKindOfClass:NSDictionary.class]) {
            continue;
        }
        id adIdTo = spec[kAdIdToKey];
        // The binary messages -isKindOfClass: on the ad_id_to value and discards the result.
        (void)[adIdTo isKindOfClass:NSString.class];
        id maxDaily = spec[kMaxDisplayCountDailyKey];
        int maxDisplayCountDaily =
            [maxDaily isKindOfClass:NSString.class] ? [maxDaily intValue] : 0;
        id maxTotal = spec[kMaxDisplayCountTotalKey];
        int maxDisplayCountTotal =
            [maxTotal isKindOfClass:NSString.class] ? [maxTotal intValue] : 0;
        NSString *dailyKey = [NSString stringWithFormat:kCountFormat, adIdTo];
        NSString *totalKey = [NSString stringWithFormat:kCountFormat, adIdTo];
        NSNumber *daily = dailyCounts[dailyKey];
        NSNumber *total = totalCounts[totalKey];
        if (daily == nil) {
            daily = @0;
        }
        if (total == nil) {
            total = @0;
        }
        if (daily.intValue < maxDisplayCountDaily && total.intValue < maxDisplayCountTotal) {
            [result addObject:spec];
        }
    }
    return result;
}

+ (NSArray *)getInterstitialSpecInstallForAdDisplaySpecList:(NSArray *)list
                                                   movieFlg:(BOOL)movieFlg {
    NSMutableArray *result = [NSMutableArray array];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = kDateTimeFormat;
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:kJapanLocaleIdentifier];
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:kJapanTimeZoneAbbreviation];
    NSDate *now = [NSDate date];
    for (NSDictionary *spec in list) {
        if (![spec isKindOfClass:NSDictionary.class]) {
            continue;
        }
        id adIdTo = spec[kAdIdToKey];
        int adId = [adIdTo isKindOfClass:NSString.class] ? [adIdTo intValue] : 0;
        id installedFlg = spec[kInstalledAdDisplayFlgKey];
        int installed = [installedFlg isKindOfClass:NSString.class] ? [installedFlg intValue] : 0;
        NSDictionary *adData = [self getAdDataList:[self getAdDataByAdId:adId]
                                            adType:kRecommendAdTypeInterstitial];
        if (adData == nil) {
            continue;
        }
        if (movieFlg && ![self checkMovieWithAdData:adData]) {
            continue;
        }
        NSMutableDictionary *record = [NSMutableDictionary dictionaryWithCapacity:adData.count];
        for (id key in adData.allKeys) {
            record[key] = adData[key];
        }
        if (installed == 0 &&
            ![kInstallFlgOff isEqualToString:[self getInstallFlgWithAdData:adData]]) {
            continue;
        }
        NSString *endDate = [adData valueForKeyPath:kExternalAdDispMngEndDateKey];
        if ([[endDate substringToIndex:kEndDateYearPrefixLength] intValue] <
            kEndDateComparableYear) {
            NSDate *end = [formatter dateFromString:endDate];
            if ([end compare:now] == NSOrderedAscending) {
                continue;
            }
        }
        record[kPriorityKey] = spec[kPriorityKey];
        [result addObject:record];
    }
    return result;
}

#pragma mark - Movie and interstitial URL extraction

+ (BOOL)checkMovieWithAdData:(NSDictionary *)adData {
    id contentKind = adData[kExternalAdDispMngKey][kAdContentKindKey];
    if ([contentKind isKindOfClass:NSString.class]) {
        if (![contentKind isEqualToString:kMovieContentKindString]) {
            return NO;
        }
    } else if ([contentKind intValue] != kRecommendAdContentKindMovie) {
        return NO;
    }
    id movieUrl = adData[kMovieUrlKey];
    if (![movieUrl isKindOfClass:NSString.class]) {
        return NO;
    }
    return [movieUrl length] != 0;
}

+ (NSArray *)getAdInterstitialUrlListTermForAdDisplaySpecList:(NSArray *)list {
    NSMutableArray *records = [NSMutableArray array];
    for (NSDictionary *spec in list) {
        if (![spec isKindOfClass:NSDictionary.class]) {
            continue;
        }
        id adIdTo = spec[kAdIdToKey];
        int adId;
        if ([adIdTo isKindOfClass:NSString.class] || [adIdTo isKindOfClass:NSNumber.class]) {
            adId = [adIdTo intValue];
        } else {
            adId = 0;
        }
        NSDictionary *adData = [self getAdDataList:[self getAdDataByAdId:adId]
                                            adType:kRecommendAdTypeInterstitial];
        if ([adData[kInterstitialBannerUrlKey] isKindOfClass:NSString.class]) {
            NSString *bannerUrl = adData[kInterstitialBannerUrlKey];
            if (bannerUrl.length != 0) {
                [records addObject:adData];
            }
        }
    }
    return [NSMutableArray arrayWithArray:[NSSet setWithArray:records].allObjects];
}

+ (NSArray *)getPosterUrlList {
    NSMutableArray *posters = [NSMutableArray array];
    for (NSDictionary *record in [self getAdList]) {
        id contentKind = record[kExternalAdDispMngKey][kAdContentKindKey];
        BOOL isMovie;
        if ([contentKind isKindOfClass:NSString.class]) {
            isMovie = [contentKind isEqualToString:kMovieContentKindString];
        } else {
            isMovie = [contentKind intValue] == kRecommendAdContentKindMovie;
        }
        if (!isMovie) {
            continue;
        }
        for (id poster in record[kPosterUrlRectListKey]) {
            if ([poster isKindOfClass:NSString.class] && [poster length] != 0) {
                [posters addObject:poster];
            }
        }
    }
    return [NSSet setWithArray:posters].allObjects;
}

+ (NSArray *)getAdInterstitialUrlListTermForList:(NSArray *)list {
    NSMutableArray *urls = [NSMutableArray array];
    for (NSDictionary *record in list) {
        if (![record isKindOfClass:NSDictionary.class]) {
            continue;
        }
        for (NSString *bannerUrl in record[kInterstitialBannerUrlListKey]) {
            if (bannerUrl.length != 0) {
                [urls addObject:bannerUrl];
            }
        }
    }
    return [NSMutableArray arrayWithArray:[NSSet setWithArray:urls].allObjects];
}

+ (NSArray *)getMovieUrlList {
    NSMutableArray *urls = [NSMutableArray array];
    for (NSDictionary *record in [self getAdList]) {
        for (id entry in record[kMovieUrlListKey]) {
            if (![entry isKindOfClass:NSString.class]) {
                continue;
            }
            NSString *payload = entry;
            if ([payload rangeOfString:kMovieUrlPrefix].location != NSNotFound) {
                payload = [payload substringFromIndex:kMovieUrlPrefix.length];
                payload = [NSStringURLEncoding URLDecodedString:payload];
            }
            for (NSString *field in [payload componentsSeparatedByString:kFieldSeparator]) {
                if ([field rangeOfString:kMovieUrlFieldMarker].location != NSNotFound) {
                    NSString *value = [field substringFromIndex:kMovieUrlFieldPrefix.length];
                    value = [NSStringURLEncoding URLDecodedString:value];
                    if (value.length != 0) {
                        [urls addObject:value];
                    }
                }
            }
        }
    }
    return [NSSet setWithArray:urls].allObjects;
}

#pragma mark - Display-count dictionaries

+ (NSDictionary *)getAdDisplayCountDailyDictionary {
    NSData *data = [NSUserDefaults.standardUserDefaults dataForKey:kAdDisplayCountDailyKey];
    if (data == nil) {
        return nil;
    }
    NSDictionary *dictionary = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSDate *recordedDate = dictionary[kAdDisplayDateKey];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = kDateFormat;
    NSString *recordedDay = [formatter stringFromDate:recordedDate];
    NSString *today = [formatter stringFromDate:[NSDate date]];
    if ([recordedDay isEqualToString:today]) {
        return dictionary;
    }
    return nil;
}

+ (NSDictionary *)getAdDisplayCountTotalDictionary {
    NSData *data = [NSUserDefaults.standardUserDefaults dataForKey:kAdDisplayCountTotalKey];
    if (data == nil) {
        return nil;
    }
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

#pragma mark - Advert type

+ (int)getAdTypeWithAdModel:(int)adModel adLocation:(NSString *)adLocation {
    for (NSDictionary *setting in [self getAdModelSettingList]) {
        id location = setting[kAdLocationKey];
        if (![location isKindOfClass:NSString.class] || ![location isEqualToString:adLocation]) {
            continue;
        }
        id model = setting[kAdModelKey];
        if (![model isKindOfClass:NSString.class] || [model intValue] != adModel) {
            continue;
        }
        id type = setting[kAdTypeKey];
        if ([type isKindOfClass:NSString.class]) {
            return [type intValue];
        }
    }
    return kRecommendAdTypeAppBanner;
}

#pragma mark - List filters

+ (NSArray *)getAdListTermForList:(NSArray *)list {
    NSMutableArray *result = [NSMutableArray array];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = kDateTimeFormat;
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:kJapanLocaleIdentifier];
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:kJapanTimeZoneAbbreviation];
    NSDate *now = [NSDate date];
    for (NSDictionary *record in list) {
        if (![record isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSDate *end = [formatter dateFromString:record[kExternalAdDispMngEndDateKey]];
        if ([end compare:now] != NSOrderedAscending) {
            [result addObject:record];
        }
    }
    return result;
}

+ (NSArray *)getAdBannerListForList:(NSArray *)list {
    NSMutableArray *urls = [NSMutableArray array];
    for (NSDictionary *record in list) {
        if (![record isKindOfClass:NSDictionary.class]) {
            continue;
        }
        for (id bannerUrl in record[kBannerUrlListKey]) {
            if ([bannerUrl isKindOfClass:NSString.class] && [bannerUrl length] != 0) {
                [urls addObject:bannerUrl];
            }
        }
    }
    return urls;
}

+ (NSArray *)shuffled:(NSArray *)list {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:list.count];
    for (id object in list) {
        NSUInteger index = arc4random() % (result.count + 1);
        [result insertObject:object atIndex:index];
    }
    return result;
}

#pragma mark - Interstitial frequency lottery

+ (NSError *)lotteryInterstitialWithAdLocation:(NSString *)adLocation {
    NSDictionary *specList = [self getInterstitialSpecList];
    if (specList.count == 0) {
        NSDictionary *userInfo = @{kErrorUserInfoKey : kInterstitialSpecListIsZeroMessage};
        return [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorInterstitialSpecInvalid
                                   userInfo:userInfo];
    }
    int frequencyN = 0;
    int frequencyM = 0;
    for (NSDictionary *spec in specList[kAdLocationDisplaySpecKey]) {
        if ([adLocation isEqualToString:spec[kAdLocationKey]]) {
            id n = spec[kFrequencyNKey];
            id m = spec[kFrequencyMKey];
            frequencyN = n == nil ? 0 : [n intValue];
            frequencyM = m == nil ? 0 : [m intValue];
            break;
        }
    }
    if (frequencyN == 0 || frequencyM == 0) {
        NSDictionary *userInfo = @{kErrorUserInfoKey : kInterstitialSpecFrequencyIsZeroMessage};
        return [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorInterstitialSpecInvalid
                                   userInfo:userInfo];
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSData *data = [defaults dataForKey:kFrequencyKey];
    NSMutableDictionary *frequency;
    int recordedN = 0;
    int recordedM = 0;
    if (data == nil) {
        frequency = [NSMutableDictionary dictionary];
    } else {
        frequency = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        NSString *storedNKey = [NSString stringWithFormat:kFrequencyNFormat, adLocation];
        NSString *storedMKey = [NSString stringWithFormat:kFrequencyMFormat, adLocation];
        id storedN = frequency[storedNKey];
        id storedM = frequency[storedMKey];
        recordedN = storedN == nil ? 0 : [storedN intValue];
        recordedM = storedM == nil ? 0 : [storedM intValue];
    }
    if (frequencyN <= recordedN) {
        recordedN = 0;
        recordedM = 0;
    }
    int roll = arc4random() % (frequencyN - recordedN);
    int remaining = frequencyM - recordedM;
    if (roll < remaining) {
        ++recordedM;
    }
    if (frequencyN <= recordedN + 1) {
        recordedM = 0;
    }
    frequency[[NSString stringWithFormat:kFrequencyNFormat, adLocation]] = @(recordedN);
    frequency[[NSString stringWithFormat:kFrequencyMFormat, adLocation]] = @(recordedM);
    [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:frequency]
                 forKey:kFrequencyKey];
    [defaults synchronize];

    if (roll < remaining) {
        return nil;
    }
    NSString *message = [NSString
        stringWithFormat:kLotteryMissFormat, frequencyN, recordedN, frequencyM, recordedM];
    NSDictionary *userInfo = @{kErrorUserInfoKey : message};
    return [ApplilinkNetworkError
        localizedApplilinkErrorWithCode:kApplilinkErrorInterstitialLotteryMiss
                               userInfo:userInfo];
}

#pragma mark - Install flag

+ (NSString *)getInstallFlgWithAdData:(NSDictionary *)adData {
    if (adData == nil) {
        return kInstallFlgOff;
    }
    id installFlg = adData[kInstallFlgKey];
    if (![installFlg isKindOfClass:NSString.class]) {
        installFlg = kInstallFlgOff;
    }
    if ([installFlg isEqualToString:kInstallFlgOn]) {
        return kInstallFlgOn;
    }
    id scheme = adData[kDefaultSchemeKey];
    if (scheme == nil || [scheme isKindOfClass:NSNull.class]) {
        return kInstallFlgOff;
    }
    NSString *schemeString = scheme;
    if ([schemeString rangeOfString:kSchemeSeparator].location == NSNotFound) {
        schemeString = [schemeString stringByAppendingString:kSchemeSeparator];
    }
    NSURL *url = [NSURL URLWithString:schemeString];
    if ([UIApplication.sharedApplication canOpenURL:url]) {
        return kInstallFlgOn;
    }
    return kInstallFlgOff;
}

#pragma mark - Debug movie lookup

+ (NSDictionary *)getMovieAdData:(NSString *)movieUrl {
    for (NSDictionary *record in RecommendDebug.movieList) {
        id candidate = record[kMovieUrlKey];
        if (![candidate isKindOfClass:NSString.class] || ![candidate isEqualToString:movieUrl]) {
            continue;
        }
        NSMutableDictionary *result = RecommendAdDataMutableRecordEscapingNewlines(record);
        result[kInstallFlgKey] = [self getInstallFlgWithAdData:result];
        return result;
    }
    return nil;
}

@end
