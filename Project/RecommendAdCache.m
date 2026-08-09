#import "RecommendAdCache.h"

#import "ApplilinkConsts.h"
#import "ApplilinkFile.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkUtilities.h"

// The recommend SDK collaborators this cache reads from. Not reconstructed in this tree yet, so
// they are forward-declared. See TYPES_PENDING.md.
@interface RecommendCore : NSObject
+ (instancetype)sharedInstance;
- (void)startSessionWithCallback:(nullable void (^)(NSError *_Nullable error))callback;
@end

@interface RecommendWebAPI : NSObject
+ (void)layoutIndexWithCallback:(nullable void (^)(NSError *_Nullable error))callback;
+ (void)allAdDataWithCallBack:(nullable void (^)(NSDictionary *_Nullable data,
                                                 NSError *_Nullable error))callback;
@end

@interface RecommendAdData : NSObject
+ (int)getAdTypeWithAdModel:(int)adModel adLocation:(nullable NSString *)adLocation;
+ (nullable NSError *)lotteryInterstitialWithAdLocation:(nullable NSString *)adLocation;
+ (nullable NSArray *)getAppInterstitialList:(int)flag;
+ (nullable NSArray *)getAppIconList;
+ (nullable NSArray *)getAppBannerList;
+ (nullable NSArray *)getSelfList;
+ (nullable id)getResponseNsData;
+ (nullable NSArray *)getAdListByAdType:(int)adType;
+ (nullable NSArray *)getAdListTermForList:(nullable NSArray *)list;
+ (nullable NSArray *)getAdBannerListForList:(nullable NSArray *)list;
+ (nullable NSArray *)getInterstitialSpecPriorityList;
+ (nullable NSArray *)getInterstitialSpecCountForAdDisplaySpecList:(nullable NSArray *)list;
+ (nullable NSArray *)getInterstitialSpecInstallForAdDisplaySpecList:(nullable NSArray *)list
                                                            movieFlg:(int)movieFlg;
+ (nullable NSArray *)getAdInterstitialUrlListTermForList:(nullable NSArray *)list;
+ (nullable NSArray *)getPosterUrlList;
+ (nullable NSArray *)getMovieUrlList;
@end

#pragma mark - Advert-type identifiers

// Advert-type identifiers returned by RecommendAdData; they pick the banner list, the creative-URL
// key, and the HTML template.
typedef enum {
    RecommendAdCacheAdTypeBanner = 2,
    RecommendAdCacheAdTypeIcon = 3,
    RecommendAdCacheAdTypeInterstitial = 5,
} RecommendAdCacheAdType;

// The success value ApplilinkFile's fetch methods return when a file was freshly downloaded.
static const int kRecommendAdCacheFetchDownloaded = 1;

// The amount by which a display counter is incremented per impression.
static const int kRecommendAdCacheDisplayCountIncrement = 1;

// The initial capacity of the per-record target-URL parameter dictionary.
static const NSUInteger kRecommendAdCacheTargetParamCapacity = 13;

// The capacity of the persisted aggregated advert-data dictionary.
static const NSUInteger kRecommendAdCacheAllAdDataCapacity = 5;

// The per-surface prefetch success quotas.
static const int kRecommendAdCachePrefetchMaxBanner = 99;
static const int kRecommendAdCachePrefetchMaxInterstitial = 3;
static const int kRecommendAdCachePrefetchMaxPoster = 100;
static const int kRecommendAdCachePrefetchMaxMovie = 100;

// The JSON serialisation option used for the SDK-apps payload (pretty-printed) and the default
// (compact) used for the self and common-resource payloads.
static const NSJSONWritingOptions kRecommendAdCacheJsonPretty = NSJSONWritingPrettyPrinted;
static const NSJSONWritingOptions kRecommendAdCacheJsonCompact = 0;

// The applilink error codes reported by the cache.
static const NSInteger kRecommendAdCacheErrorCodeCacheCreate = 0x40b;
static const NSInteger kRecommendAdCacheErrorCodeInterstitialNone = 0x40a;
static const NSInteger kRecommendAdCacheErrorCodeInterstitialLottery = 0x411;
static const NSInteger kRecommendAdCacheErrorCodeNotInterstitial = 0x412;

#pragma mark - NSUserDefaults keys

static NSString *const kRecommendAdCacheAllAdDataKey = @"ApplilinkRecommend.allAdData";
static NSString *const kRecommendAdCacheAllAdDataListKey = @"ApplilinkRecommend.allAdData.list";
static NSString *const kRecommendAdCacheAllAdDataBannerDisplayStatusListKey =
    @"ApplilinkRecommend.allAdData.banner_display_status_list";
static NSString *const kRecommendAdCacheAllAdDataAdModelSettingListKey =
    @"ApplilinkRecommend.allAdData.ad_model_setting_list";
static NSString *const kRecommendAdCacheAllAdDataInterstitialSpecListKey =
    @"ApplilinkRecommend.allAdData.interstitial_spec_list";
static NSString *const kRecommendAdCacheAllAdDataSelfKey = @"ApplilinkRecommend.allAdData.self";
static NSString *const kRecommendAdCacheAdDataListKey = @"adDataList";
static NSString *const kRecommendAdCacheAdDisplayCountDailyKey = @"adDisplayCountDaily";
static NSString *const kRecommendAdCacheAdDisplayCountTotalKey = @"adDisplayCountTotal";

#pragma mark - Server response keys

static NSString *const kRecommendAdCacheResponseCategoryIdKey = @"category_id";
static NSString *const kRecommendAdCacheResponseCountryCodeKey = @"country_code";
static NSString *const kRecommendAdCacheResponseUpdateTermKey = @"update_term_format_second";
static NSString *const kRecommendAdCacheResponseAdIdKey = @"ad_id";
static NSString *const kRecommendAdCacheResponseListKey = @"list";
static NSString *const kRecommendAdCacheResponseBannerDisplayStatusListKey =
    @"banner_display_status_list";
static NSString *const kRecommendAdCacheResponseAdModelSettingListKey = @"ad_model_setting_list";
static NSString *const kRecommendAdCacheResponseInterstitialSpecListKey = @"interstitial_spec_list";
static NSString *const kRecommendAdCacheResponseSelfKey = @"self";

#pragma mark - Archived-dictionary keys

static NSString *const kRecommendAdCacheKeyAdDisplayDate = @"adDisplayDate";
static NSString *const kRecommendAdCacheKeyFileName = @"file_name";
static NSString *const kRecommendAdCacheKeyPath = @"path";
static NSString *const kRecommendAdCacheKeyUrl = @"url";
static NSString *const kRecommendAdCacheKeyAdId = @"ad_id";

#pragma mark - Target-URL parameter keys

static NSString *const kRecommendAdCacheParamAdType = @"ad_type";
static NSString *const kRecommendAdCacheParamAdModel = @"ad_model";
static NSString *const kRecommendAdCacheParamAdLocation = @"ad_location";
static NSString *const kRecommendAdCacheParamAdIdTo = @"ad_id_to";
static NSString *const kRecommendAdCacheParamAdIdFrom = @"ad_id_from";
static NSString *const kRecommendAdCacheParamAppliIdTo = @"appli_id_to";
static NSString *const kRecommendAdCacheParamAppliId = @"appli_id";
static NSString *const kRecommendAdCacheParamCreativeId = @"creative_id";
static NSString *const kRecommendAdCacheParamIncentiveType = @"incentive_type";
static NSString *const kRecommendAdCacheParamInstallFlg = @"install_flg";
static NSString *const kRecommendAdCacheParamDefaultScheme = @"default_scheme";
static NSString *const kRecommendAdCacheParamDisplayNumber = @"display_number";
static NSString *const kRecommendAdCacheParamCountryCode = @"country_code";
static NSString *const kRecommendAdCacheParamCategoryId = @"category_id";
static NSString *const kRecommendAdCacheParamTargetUrl = @"target_url";
static NSString *const kRecommendAdCacheParamBannerUrl = @"banner_url";
static NSString *const kRecommendAdCacheParamBannerIconUrl = @"banner_icon_url";
static NSString *const kRecommendAdCacheParamInterstitialBannerUrl = @"interstitial_banner_url";

// The base URL every target URL is built on.
static NSString *const kRecommendAdCacheTargetBaseUrl = @"applilink://ext-app:80/send";

#pragma mark - Template placeholders

static NSString *const kRecommendAdCachePlaceholderSdkPath = @"[[SDK_PATH]]";
static NSString *const kRecommendAdCachePlaceholderBaseUrl = @"[[BASE_URL]]";
static NSString *const kRecommendAdCachePlaceholderSdkApps = @"[[SDK_APPS]]";
// The binary spells the vertical-align placeholder "VARTICAL".
static NSString *const kRecommendAdCachePlaceholderVerticalAlign = @"[[VARTICAL_ALIGN]]";
static NSString *const kRecommendAdCachePlaceholderApplilinkEnv = @"[[APPLILINK_ENV]]";
static NSString *const kRecommendAdCachePlaceholderCountryCode = @"[[COUNTRY_CODE]]";
static NSString *const kRecommendAdCachePlaceholderImpressionId = @"[[IMPRESSION_ID]]";
static NSString *const kRecommendAdCachePlaceholderNs = @"[[NS]]";
static NSString *const kRecommendAdCachePlaceholderAdModel = @"[[AD_MODEL]]";
static NSString *const kRecommendAdCachePlaceholderAdLocation = @"[[AD_LOCATION]]";
static NSString *const kRecommendAdCachePlaceholderSelf = @"[[SELF]]";

#pragma mark - Movie-player icon resource paths

static NSString *const kRecommendAdCacheMediaPlayerBackEn = @"/img/assets/media_player/back_en.png";
static NSString *const kRecommendAdCacheMediaPlayerBackJa = @"/img/assets/media_player/back_ja.png";
static NSString *const kRecommendAdCacheMediaPlayerDlEn = @"/img/assets/media_player/dl_en.png";
static NSString *const kRecommendAdCacheMediaPlayerDlJa = @"/img/assets/media_player/dl_ja.png";
static NSString *const kRecommendAdCacheMediaPlayerPlay = @"/img/assets/media_player/play.png";
static NSString *const kRecommendAdCacheMediaPlayerStop = @"/img/assets/media_player/stop.png";
static NSString *const kRecommendAdCacheMediaPlayerSoundOff =
    @"/img/assets/media_player/sound_off.png";
static NSString *const kRecommendAdCacheMediaPlayerSoundOn =
    @"/img/assets/media_player/sound_on.png";

#pragma mark - Format strings

static NSString *const kRecommendAdCacheFormatInteger = @"%d";
static NSString *const kRecommendAdCachePathSeparator = @"/";
static NSString *const kRecommendAdCacheFormatDayOnly = @"yyyy/MM/dd";
static NSString *const kRecommendAdCacheFormatDayTime = @"yyyy-MM-dd HH:mm:ss";
static NSString *const kRecommendAdCacheFormatCountKey = @"count_%@";
static NSString *const kRecommendAdCacheFormatAdDataKey = @"%d_%@_adData";
static NSString *const kRecommendAdCacheFormatHtmlName = @"%d_%@.html";
static NSString *const kRecommendAdCacheFormatTemplateName = @"ad_type%d.html";
static NSString *const kRecommendAdCacheFormatUnknownAdType =
    @"no data. ad_model_setting_list AdModel:%d, adLocation:%@";
static NSString *const kRecommendAdCacheFormatZeroMatch =
    @"allAdDataForDisplay list. match data is zero. adType:%d";
static NSString *const kRecommendAdCacheUnknownAdTypeMessage =
    @"advertising type is unknown problem";

// The user-info keys the cache-creation errors file their strings under.
static NSString *const kRecommendAdCacheErrorUserInfoKey = @"Error";
static NSString *const kRecommendAdCacheSettingUserInfoKey = @"Setting";

// The archived advert-data expiry date. Held for the lifetime of the process rather than in
// NSUserDefaults; @c getAllAdDataInfoExpire unarchives it and @c clearAllAdDataInfoExpire drops it.
static NSData *g_pAllAdDataExpiryArchive = nil;

@implementation RecommendAdCache

#pragma mark - Advert-status refresh

+ (void)getAllAdStatus {
    NSDate *expire = [RecommendAdCache getAllAdDataInfoExpire];
    if (expire != nil && [expire compare:[NSDate date]] != NSOrderedAscending) {
        return;
    }
    [ApplilinkFile createFolder];
    [RecommendWebAPI layoutIndexWithCallback:^(NSError *_Nullable error) {
      /** @ghidraAddress 0x274e40 */
      if (error == nil) {
          [RecommendAdCache getTemplateFiles];
      }
      // The cache wipe and the fetch run even on a failed session; only getTemplateFiles is
      // guarded.
      [ApplilinkFile clearCacheBannerImage];
      [ApplilinkFile clearCacheData];
      [RecommendAdCache getAllAdDataWithCallBack:^(id _Nullable data,
                                                   NSError *_Nullable innerError) {
        /** @ghidraAddress 0x274eec */
        // The advert data has already been committed to RecommendAdData; this stage ignores it.
        (void)data;
        if (innerError == nil) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
              /** @ghidraAddress 0x274f5c */
              NSArray *bannerList = nil;
              NSArray *adList = [RecommendAdData getAdListByAdType:RecommendAdCacheAdTypeBanner];
              if (adList.count != 0) {
                  NSArray *termList = [RecommendAdData getAdListTermForList:adList];
                  if (termList.count != 0) {
                      bannerList = [RecommendAdData getAdBannerListForList:termList];
                  }
              }
              NSArray *interstitialList = nil;
              NSArray *specList = [RecommendAdData getInterstitialSpecPriorityList];
              if (specList.count != 0) {
                  NSArray *countList =
                      [RecommendAdData getInterstitialSpecCountForAdDisplaySpecList:specList];
                  if (countList.count != 0) {
                      NSArray *installList =
                          [RecommendAdData getInterstitialSpecInstallForAdDisplaySpecList:countList
                                                                                 movieFlg:0];
                      if (installList.count != 0) {
                          interstitialList =
                              [RecommendAdData getAdInterstitialUrlListTermForList:installList];
                      }
                  }
              }
              if (bannerList.count != 0) {
                  [RecommendAdCache getBannerDataWithList:bannerList
                                                      max:kRecommendAdCachePrefetchMaxBanner];
              }
              if (interstitialList.count != 0) {
                  [RecommendAdCache getBannerDataWithList:interstitialList
                                                      max:kRecommendAdCachePrefetchMaxInterstitial];
              }
              NSArray *posters = [RecommendAdData getPosterUrlList];
              if (posters.count != 0) {
                  [RecommendAdCache getBannerDataWithList:posters
                                                      max:kRecommendAdCachePrefetchMaxPoster];
              }
              NSArray *movies = [RecommendAdData getMovieUrlList];
              if (movies.count != 0) {
                  [RecommendAdCache getCacheDataWithList:movies
                                                     max:kRecommendAdCachePrefetchMaxMovie];
              }
              [RecommendAdCache getMoviePlayerIcon];
            });
        }
      }];
    }];
}

+ (void)getAllAdDataWithCallBack:(RecommendAdCacheAllAdDataCallback)callBack {
    [[RecommendCore sharedInstance] startSessionWithCallback:^(NSError *_Nullable error) {
      /** @ghidraAddress 0x275320 */
      if (error != nil) {
          callBack(nil, error);
          return;
      }
      [RecommendWebAPI allAdDataWithCallBack:^(NSDictionary *_Nullable data,
                                               NSError *_Nullable fetchError) {
        /** @ghidraAddress 0x2753c8 */
        if (fetchError != nil) {
            callBack(nil, fetchError);
            return;
        }
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
          /** @ghidraAddress 0x275498 */
          NSString *categoryId = data[kRecommendAdCacheResponseCategoryIdKey];
          NSString *countryCode = data[kRecommendAdCacheResponseCountryCodeKey];
          NSString *updateTerm = data[kRecommendAdCacheResponseUpdateTermKey];
          NSString *adId = data[kRecommendAdCacheResponseAdIdKey];
          if ([categoryId isKindOfClass:[NSString class]]) {
              [ApplilinkConsts setCategoryId:categoryId];
          }
          if ([countryCode isKindOfClass:[NSString class]]) {
              [ApplilinkConsts setCountryCode:countryCode];
          }
          if ([adId isKindOfClass:[NSString class]]) {
              [ApplilinkConsts setAdId:adId];
          }
          NSTimeInterval interval = 0.0;
          if ([updateTerm isKindOfClass:[NSString class]]) {
              interval = (double)[updateTerm intValue];
          }
          NSDate *expiry = [[NSDate date] dateByAddingTimeInterval:interval];
          g_pAllAdDataExpiryArchive = [NSKeyedArchiver archivedDataWithRootObject:expiry];
          if (adId != nil && ![adId isKindOfClass:[NSNull class]]) {
              [ApplilinkConsts setCacheAdId:adId];
          }
          id list = data[kRecommendAdCacheResponseListKey];
          id bannerDisplayStatusList = data[kRecommendAdCacheResponseBannerDisplayStatusListKey];
          id adModelSettingList = data[kRecommendAdCacheResponseAdModelSettingListKey];
          id interstitialSpecList = data[kRecommendAdCacheResponseInterstitialSpecListKey];
          id selfList = data[kRecommendAdCacheResponseSelfKey];
          NSMutableDictionary *allAdData =
              [NSMutableDictionary dictionaryWithCapacity:kRecommendAdCacheAllAdDataCapacity];
          if (list != nil) {
              allAdData[kRecommendAdCacheAllAdDataListKey] = list;
          }
          if (bannerDisplayStatusList != nil) {
              allAdData[kRecommendAdCacheAllAdDataBannerDisplayStatusListKey] =
                  bannerDisplayStatusList;
          }
          if (adModelSettingList != nil) {
              allAdData[kRecommendAdCacheAllAdDataAdModelSettingListKey] = adModelSettingList;
          }
          if (interstitialSpecList != nil) {
              allAdData[kRecommendAdCacheAllAdDataInterstitialSpecListKey] = interstitialSpecList;
          }
          if (selfList != nil) {
              allAdData[kRecommendAdCacheAllAdDataSelfKey] = selfList;
          }
          NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
          [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:allAdData]
                       forKey:kRecommendAdCacheAllAdDataKey];
          [defaults synchronize];
          callBack(nil, nil);
        });
      }];
    }];
}

+ (void)clearAllAdData {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kRecommendAdCacheAllAdDataKey];
}

+ (nullable NSDate *)getAllAdDataInfoExpire {
    if (g_pAllAdDataExpiryArchive == nil) {
        return nil;
    }
    id expire = [NSKeyedUnarchiver unarchiveObjectWithData:g_pAllAdDataExpiryArchive];
    if (![expire isKindOfClass:[NSDate class]]) {
        return nil;
    }
    return expire;
}

+ (void)clearAllAdDataInfoExpire {
    g_pAllAdDataExpiryArchive = nil;
}

#pragma mark - Banner, resource, and cache-data prefetch

+ (void)getBannerDataWithList:(NSArray *)list max:(int)max {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      /** @ghidraAddress 0x275c24 */
      int cached = 0;
      for (NSString *url in list) {
          if ([ApplilinkFile getBannerWithUrl:url] == kRecommendAdCacheFetchDownloaded) {
              ++cached;
              if (cached >= max) {
                  break;
              }
          }
      }
    });
}

+ (BOOL)getResourceDataWithList:(NSArray *)list {
    for (NSString *url in list) {
        if ([ApplilinkFile getResourceWithUrl:url] == ApplilinkFileFetchResultFailure) {
            return NO;
        }
    }
    return YES;
}

+ (void)getCacheDataWithList:(NSArray *)list max:(int)max {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      /** @ghidraAddress 0x275f54 */
      int cached = 0;
      for (NSString *url in list) {
          if ([ApplilinkFile getCacheDataWithUrl:url] == kRecommendAdCacheFetchDownloaded) {
              ++cached;
              if (cached >= max) {
                  break;
              }
          }
      }
    });
}

#pragma mark - Template files

+ (void)getTemplateFiles {
    NSArray *templateList = [ApplilinkConsts templateList];
    for (NSDictionary *entry in templateList) {
        NSString *file = entry[kRecommendAdCacheKeyFileName];
        NSString *path = entry[kRecommendAdCacheKeyPath];
        NSString *url = entry[kRecommendAdCacheKeyUrl];
        NSData *data = [ApplilinkFile getFileWithUrl:url];
        if (data != nil) {
            [RecommendAdCache saveTemplateData:data path:path file:file];
        }
    }
}

+ (void)saveTemplateData:(NSData *)data path:(NSString *)path file:(NSString *)file {
    NSString *directory = [ApplilinkFile getContentsPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *components = [path componentsSeparatedByString:kRecommendAdCachePathSeparator];
    NSError *error = nil;
    for (NSString *component in components) {
        // The final path component is the file name itself; only the directory parts are created.
        if ([component isEqualToString:file]) {
            continue;
        }
        directory = [directory stringByAppendingPathComponent:component];
        BOOL isDirectory = NO;
        // The binary tests the whole relative path here, not the accumulated directory.
        if (![fileManager fileExistsAtPath:path isDirectory:&isDirectory]) {
            [fileManager createDirectoryAtPath:directory
                   withIntermediateDirectories:YES
                                    attributes:nil
                                         error:&error];
        }
    }
    NSString *filePath = [directory stringByAppendingPathComponent:file];
    [data writeToFile:filePath atomically:YES];
}

#pragma mark - HTML rendering

+ (nullable NSError *)createHtmlWithAdModel:(int)adModel
                                 adLocation:(NSString *)adLocation
                              verticalAlign:(int)verticalAlign
                               impressionId:(NSString *)impressionId {
    int adType = [RecommendAdData getAdTypeWithAdModel:adModel adLocation:adLocation];
    NSArray *bannerList;
    switch (adType) {
    case RecommendAdCacheAdTypeInterstitial: {
        NSError *lottery = [RecommendAdData lotteryInterstitialWithAdLocation:adLocation];
        if (lottery != nil) {
            return lottery; // Faithful: the lottery result short-circuits the return.
        }
        bannerList = [RecommendAdData getAppInterstitialList:0];
        break;
    }
    case RecommendAdCacheAdTypeIcon:
        bannerList = [RecommendAdData getAppIconList];
        break;
    case RecommendAdCacheAdTypeBanner:
        bannerList = [RecommendAdData getAppBannerList];
        break;
    default: {
        NSString *message =
            [NSString stringWithFormat:kRecommendAdCacheFormatUnknownAdType, adModel, adLocation];
        NSDictionary *userInfo = @{
            kRecommendAdCacheErrorUserInfoKey : kRecommendAdCacheUnknownAdTypeMessage,
            kRecommendAdCacheSettingUserInfoKey : message,
        };
        return [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendAdCacheErrorCodeCacheCreate
                                   userInfo:userInfo];
    }
    }
    if (bannerList.count == 0) {
        NSString *message = [NSString stringWithFormat:kRecommendAdCacheFormatZeroMatch, adType];
        NSDictionary *userInfo = @{kRecommendAdCacheErrorUserInfoKey : message};
        return [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendAdCacheErrorCodeCacheCreate
                                   userInfo:userInfo];
    }
    [RecommendAdCache setTargetUrl:bannerList adType:adType adModel:adModel adLocation:adLocation];
    NSArray *selfList = [RecommendAdData getSelfList];
    id comResData = [RecommendAdData getResponseNsData];
    NSString *html = [RecommendAdCache convertHtmlWithAdModel:adModel
                                                   adLocation:adLocation
                                                       adType:adType
                                                verticalAlign:verticalAlign
                                                   bannerList:bannerList
                                                 impressionId:impressionId
                                                     selfList:selfList
                                                   comResData:comResData];
    [RecommendAdCache setHtmlAdDataWithAdModel:adModel adLocation:adLocation bannerList:bannerList];
    NSString *htmlName =
        [NSString stringWithFormat:kRecommendAdCacheFormatHtmlName, adModel, adLocation];
    NSString *htmlPath = [[ApplilinkFile getContentsPath] stringByAppendingPathComponent:htmlName];
    NSError *writeError = nil;
    [html writeToFile:htmlPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    if (adType == RecommendAdCacheAdTypeInterstitial) {
        NSString *adId = bannerList[0][kRecommendAdCacheKeyAdId];
        [RecommendAdCache setAdDisplayCountWithAdId:adId];
    }
    return nil;
}

+ (nullable NSString *)convertHtmlWithAdModel:(int)adModel
                                   adLocation:(NSString *)adLocation
                                       adType:(int)adType
                                verticalAlign:(int)verticalAlign
                                   bannerList:(id)bannerList
                                 impressionId:(NSString *)impressionId
                                     selfList:(id)selfList
                                   comResData:(id)comResData {
    NSString *templateName =
        [NSString stringWithFormat:kRecommendAdCacheFormatTemplateName, adType];
    NSString *templatePath =
        [[ApplilinkFile getContentsPath] stringByAppendingPathComponent:templateName];
    NSError *error = nil;
    NSString *html = [NSString stringWithContentsOfFile:templatePath
                                               encoding:NSUTF8StringEncoding
                                                  error:&error];
    html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderSdkPath
                                           withString:[ApplilinkFile getContentsPath]];
    html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderBaseUrl
                                           withString:[ApplilinkConsts baseUrlSsl]];
    if ([NSJSONSerialization isValidJSONObject:bannerList]) {
        NSData *json = [NSJSONSerialization dataWithJSONObject:bannerList
                                                       options:kRecommendAdCacheJsonPretty
                                                         error:&error];
        NSString *jsonString = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
        html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderSdkApps
                                               withString:jsonString];
    } else {
        html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderSdkApps
                                               withString:[bannerList description]];
    }
    NSString *verticalAlignString =
        [NSString stringWithFormat:kRecommendAdCacheFormatInteger, verticalAlign];
    html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderVerticalAlign
                                           withString:verticalAlignString];
    html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderApplilinkEnv
                                           withString:[ApplilinkConsts baseUrlSsl]];
    if ([ApplilinkConsts countryCode] != nil) {
        html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderCountryCode
                                               withString:[ApplilinkConsts countryCode]];
    }
    if (impressionId != nil) {
        html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderImpressionId
                                               withString:impressionId];
    }
    NSData *comResJson = [NSJSONSerialization dataWithJSONObject:comResData
                                                         options:kRecommendAdCacheJsonCompact
                                                           error:&error];
    NSString *comResString = [[NSString alloc] initWithData:comResJson
                                                   encoding:NSUTF8StringEncoding];
    html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderNs
                                           withString:comResString];
    NSString *adModelString = [NSString stringWithFormat:kRecommendAdCacheFormatInteger, adModel];
    html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderAdModel
                                           withString:adModelString];
    html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderAdLocation
                                           withString:adLocation];
    NSData *selfJson = [NSJSONSerialization dataWithJSONObject:selfList
                                                       options:kRecommendAdCacheJsonCompact
                                                         error:&error];
    // The binary embeds -[NSData description] of the serialised self list, not a decoded string.
    html = [html stringByReplacingOccurrencesOfString:kRecommendAdCachePlaceholderSelf
                                           withString:[selfJson description]];
    return html;
}

+ (void)setTargetUrl:(NSArray *)targetUrl
              adType:(int)adType
             adModel:(int)adModel
          adLocation:(NSString *)adLocation {
    for (NSMutableDictionary *banner in targetUrl) {
        NSMutableDictionary *parameters =
            [NSMutableDictionary dictionaryWithCapacity:kRecommendAdCacheTargetParamCapacity];
        [parameters setValue:[NSString stringWithFormat:kRecommendAdCacheFormatInteger, adType]
                      forKey:kRecommendAdCacheParamAdType];
        [parameters setValue:[NSString stringWithFormat:kRecommendAdCacheFormatInteger, adModel]
                      forKey:kRecommendAdCacheParamAdModel];
        [parameters setValue:adLocation forKey:kRecommendAdCacheParamAdLocation];
        [parameters setValue:banner[kRecommendAdCacheKeyAdId] forKey:kRecommendAdCacheParamAdIdTo];
        NSString *creativeUrl = nil;
        switch (adType) {
        case RecommendAdCacheAdTypeInterstitial:
            creativeUrl = banner[kRecommendAdCacheParamInterstitialBannerUrl];
            break;
        case RecommendAdCacheAdTypeIcon:
            creativeUrl = banner[kRecommendAdCacheParamBannerIconUrl];
            break;
        case RecommendAdCacheAdTypeBanner:
            creativeUrl = banner[kRecommendAdCacheParamBannerUrl];
            break;
        default:
            break;
        }
        if (creativeUrl != nil) {
            NSString *creativeId = [ApplilinkUtilities getFileNameFromPath:creativeUrl];
            if (creativeId != nil) {
                [parameters setValue:creativeId forKey:kRecommendAdCacheParamCreativeId];
            }
        }
        [parameters setValue:banner[kRecommendAdCacheParamIncentiveType]
                      forKey:kRecommendAdCacheParamIncentiveType];
        [parameters setValue:banner[kRecommendAdCacheParamInstallFlg]
                      forKey:kRecommendAdCacheParamInstallFlg];
        [parameters setValue:banner[kRecommendAdCacheParamDefaultScheme]
                      forKey:kRecommendAdCacheParamDefaultScheme];
        [parameters setValue:[NSString stringWithFormat:kRecommendAdCacheFormatInteger, adModel]
                      forKey:kRecommendAdCacheParamDisplayNumber];
        [parameters setValue:banner[kRecommendAdCacheParamCountryCode]
                      forKey:kRecommendAdCacheParamCountryCode];
        [parameters setValue:banner[kRecommendAdCacheParamCategoryId]
                      forKey:kRecommendAdCacheParamCategoryId];
        [parameters setValue:banner[kRecommendAdCacheParamCreativeId]
                      forKey:kRecommendAdCacheParamCreativeId];
        [parameters setValue:[ApplilinkConsts adId] forKey:kRecommendAdCacheParamAdIdFrom];
        [parameters setValue:banner[kRecommendAdCacheParamAppliId]
                      forKey:kRecommendAdCacheParamAppliIdTo];
        NSString *url = [ApplilinkUtilities appendParametersToURL:kRecommendAdCacheTargetBaseUrl
                                                       parameters:parameters];
        [banner setObject:url forKey:kRecommendAdCacheParamTargetUrl];
    }
}

#pragma mark - Display counters

+ (void)setAdDisplayCountWithAdId:(NSString *)adId {
    [RecommendAdCache setAdDisplayCountDailyWithAdId:adId];
    [RecommendAdCache setAdDisplayCountTotalWithAdId:adId];
}

+ (void)setAdDisplayCountDailyWithAdId:(NSString *)adId {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *data = [defaults dataForKey:kRecommendAdCacheAdDisplayCountDailyKey];
    NSMutableDictionary *counts;
    if (data == nil) {
        counts = [NSMutableDictionary dictionary];
    } else {
        NSInteger secondsFromGMT = [[NSTimeZone systemTimeZone] secondsFromGMT];
        NSDate *localNow = [NSDate dateWithTimeIntervalSinceNow:(double)secondsFromGMT];
        counts = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        NSDate *storedDate = counts[kRecommendAdCacheKeyAdDisplayDate];
        NSDateFormatter *dayFormatter = [[NSDateFormatter alloc] init];
        [dayFormatter setDateFormat:kRecommendAdCacheFormatDayOnly];
        NSString *storedDay = [dayFormatter stringFromDate:storedDate];
        NSString *localDay = [dayFormatter stringFromDate:localNow];
        if (![storedDay isEqualToString:localDay]) {
            counts = [NSMutableDictionary dictionary];
        }
    }
    NSString *countKey = [NSString stringWithFormat:kRecommendAdCacheFormatCountKey, adId];
    NSNumber *count = counts[countKey];
    if (count == nil) {
        count = @(0);
    }
    counts[countKey] = @([count intValue] + kRecommendAdCacheDisplayCountIncrement);
    NSInteger secondsFromGMT = [[NSTimeZone systemTimeZone] secondsFromGMT];
    NSDate *localNow = [NSDate dateWithTimeIntervalSinceNow:(double)secondsFromGMT];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:kRecommendAdCacheFormatDayTime];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    counts[kRecommendAdCacheKeyAdDisplayDate] = [dateFormatter stringFromDate:localNow];
    [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:counts]
                 forKey:kRecommendAdCacheAdDisplayCountDailyKey];
    [defaults synchronize];
}

+ (void)setAdDisplayCountTotalWithAdId:(NSString *)adId {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *data = [defaults dataForKey:kRecommendAdCacheAdDisplayCountTotalKey];
    NSMutableDictionary *counts;
    if (data == nil) {
        counts = [NSMutableDictionary dictionary];
    } else {
        counts = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    NSString *countKey = [NSString stringWithFormat:kRecommendAdCacheFormatCountKey, adId];
    NSNumber *count = counts[countKey];
    if (count == nil) {
        count = @(0);
    }
    counts[countKey] = @([count intValue] + kRecommendAdCacheDisplayCountIncrement);
    [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:counts]
                 forKey:kRecommendAdCacheAdDisplayCountTotalKey];
    [defaults synchronize];
}

+ (void)clearAdDisplayCount {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kRecommendAdCacheAdDisplayCountTotalKey];
    [defaults removeObjectForKey:kRecommendAdCacheAdDisplayCountDailyKey];
}

#pragma mark - HTML advert-data store

+ (void)setHtmlAdDataWithAdModel:(int)adModel
                      adLocation:(NSString *)adLocation
                      bannerList:(id)bannerList {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *data = [defaults dataForKey:kRecommendAdCacheAdDataListKey];
    NSMutableDictionary *adDataList;
    if (data == nil) {
        adDataList = [NSMutableDictionary dictionary];
    } else {
        adDataList = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    NSString *key =
        [NSString stringWithFormat:kRecommendAdCacheFormatAdDataKey, adModel, adLocation];
    adDataList[key] = bannerList;
    [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:adDataList]
                 forKey:kRecommendAdCacheAdDataListKey];
    [defaults synchronize];
}

+ (nullable NSArray *)getHtmlAdDataWithAdModel:(int)adModel adLocation:(NSString *)adLocation {
    NSData *data =
        [[NSUserDefaults standardUserDefaults] dataForKey:kRecommendAdCacheAdDataListKey];
    if (data == nil) {
        return nil;
    }
    NSDictionary *adDataList = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSString *key =
        [NSString stringWithFormat:kRecommendAdCacheFormatAdDataKey, adModel, adLocation];
    return adDataList[key];
}

#pragma mark - Movie surfaces

+ (BOOL)getMoviePlayerIcon {
    NSArray *urls = @[
        [ApplilinkConsts getUrl:kRecommendAdCacheMediaPlayerBackEn],
        [ApplilinkConsts getUrl:kRecommendAdCacheMediaPlayerBackJa],
        [ApplilinkConsts getUrl:kRecommendAdCacheMediaPlayerDlEn],
        [ApplilinkConsts getUrl:kRecommendAdCacheMediaPlayerDlJa],
        [ApplilinkConsts getUrl:kRecommendAdCacheMediaPlayerPlay],
        [ApplilinkConsts getUrl:kRecommendAdCacheMediaPlayerStop],
        [ApplilinkConsts getUrl:kRecommendAdCacheMediaPlayerSoundOff],
        [ApplilinkConsts getUrl:kRecommendAdCacheMediaPlayerSoundOn],
    ];
    return [RecommendAdCache getResourceDataWithList:urls];
}

+ (nullable id)getMoviewQuaryWithAdModel:(int)adModel
                              adLocation:(NSString *)adLocation
                           verticalAlign:(int)verticalAlign
                            impressionId:(NSString *)impressionId
                                errorObj:(NSError *_Nullable *_Nullable)errorObj {
    // verticalAlign and impressionId are accepted but never read.
    int adType = [RecommendAdData getAdTypeWithAdModel:adModel adLocation:adLocation];
    if (adType != RecommendAdCacheAdTypeInterstitial) {
        *errorObj = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendAdCacheErrorCodeNotInterstitial];
        return nil;
    }
    NSError *lottery = [RecommendAdData lotteryInterstitialWithAdLocation:adLocation];
    if (lottery != nil) {
        *errorObj = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendAdCacheErrorCodeInterstitialLottery];
        return nil;
    }
    NSArray *list = [RecommendAdData getAppInterstitialList:1];
    if (list.count == 0) {
        *errorObj = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendAdCacheErrorCodeInterstitialNone];
        return nil;
    }
    [RecommendAdCache setTargetUrl:list
                            adType:RecommendAdCacheAdTypeInterstitial
                           adModel:adModel
                        adLocation:adLocation];
    NSString *adId = list[0][kRecommendAdCacheKeyAdId];
    [RecommendAdCache setAdDisplayCountWithAdId:adId];
    return list[0];
}

@end
