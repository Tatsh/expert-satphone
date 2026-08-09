#import "StorePackListController.h"

#import "JubeatAppDelegate.h"
#import "StorePackListGenre.h"
#import "StorePromotion.h"
#import "StoreUtil.h"

// The typed-accessor category the store dictionaries are read through; a category on NSDictionary
// not reconstructed as its own file yet. See TYPES_PENDING.md.
@interface NSDictionary (TypedAccessors)
- (nullable NSNumber *)numberForKey:(nonnull id)key;
- (nullable NSString *)stringForKey:(nonnull id)key;
- (nullable NSArray *)arrayForKey:(nonnull id)key;
- (nullable NSDictionary *)dictionaryForKey:(nonnull id)key;
@end

// The catalogue-response dictionary keys.
static NSString *const kResponseKeyPackList = @"PackList";
static NSString *const kResponseKeyGenre = @"Genre";
static NSString *const kResponseKeyGenreMetaInfo = @"GenreMetaInfo";
static NSString *const kResponseKeyPromotion = @"Promotion";
static NSString *const kResponseKeyVersion = @"Version";
static NSString *const kResponseKeyComment = @"Comment";
static NSString *const kResponseKeyDate = @"Date";
static NSString *const kResponseKeyError = @"Error";
static NSString *const kResponseKeyHasNext = @"HasNext";

// The per-entry dictionary keys.
static NSString *const kEntryKeyID = @"ID";
static NSString *const kEntryKeyImageURL = @"ImageURL";
static NSString *const kEntryKeySampleURL = @"SampleURL";

// The product identifier prefixes distinguishing a pack promotion from a genre promotion.
static NSString *const kPackPromotionPrefix = @"p_";
static NSString *const kGenrePromotionPrefix = @"g_";

// The purchase-tracking user-defaults keys.
static NSString *const kDefaultsKeyPurchaseMonth = @"PrefPurchaseMonth";
static NSString *const kDefaultsKeyPurchaseLimitType = @"PrefPurchaseLimitType";
static NSString *const kDefaultsKeyTotalPurchase = @"PrefTotalPurchase";

// The localised alert-message keys.
static NSString *const kMessageKeyServerOldVersion = @"ServerOldVersionMsg";
static NSString *const kMessageKeyServerError = @"ServerErrorMsg";
static NSString *const kMessageKeyNetworkError = @"NetworkErrorMsg";

// The default display name for the seeded "all" genre. The binary stores this as the UTF-16
// literal すべて.
static NSString *const kAllGenreName = @"すべて";

// The placeholder display name for the transient genre used by a single-genre fetch.
static NSString *const kTemporaryGenreName = @"tmp";

// The initial capacity of the genre array.
enum { kGenreArrayInitialCapacity = 8 };

// The initial capacity of the pack-info cache.
enum { kPackInfoDictInitialCapacity = 128 };

// The number of packs requested per catalogue page.
enum { kPackFetchPageSize = 24 };

// The two-character promotion prefix stripped before parsing a pack identifier.
enum { kPromotionPrefixLength = 2 };

// The purchase-limit type indicating a subscription that must not be reset.
enum { kPurchaseLimitTypeSubscription = 3 };

// The App Store country recorded from the most recent product's price locale. A process-wide
// cache shared across every controller instance, matching the binary's file-scope global.
static NSString *_storeCountry = nil;

@implementation StorePackListController {
    // The genre models, in list order. A bare ivar in the binary, with no backing property.
    NSMutableArray<StorePackListGenre *> *arrayGenre;
    // The most recently built promotion list.
    NSArray<StorePromotion *> *arrayPromotions;
    // The genre currently being fetched into, whose pages accumulate as they arrive.
    StorePackListGenre *genreFetching;
    // The catalogue response held while its StoreKit product request is in flight.
    NSDictionary *tmpPackDict;
    // The in-flight catalogue downloader.
    Downloader *packlistDownloader;
    // The in-flight StoreKit product request.
    SKProductsRequest *productsRequest;
    // The pack-info cache, keyed by boxed pack identifier.
    NSMutableDictionary *dictPackInfo;
    // The genre-info cache. Declared in the binary but unused by the recovered members.
    NSMutableDictionary *genreInfoDict;
}

#pragma mark - Store country

/** @ghidraAddress 0xcb86c */
+ (nullable NSString *)storeCountry {
    if (_storeCountry) {
        return [NSString stringWithString:_storeCountry];
    }
    return nil;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0xcb8ac */
- (instancetype)init {
    self = [super init];
    if (self) {
        _initiallyLoaded = NO;
        arrayGenre = [[NSMutableArray alloc] initWithCapacity:kGenreArrayInitialCapacity];
        [arrayGenre addObject:[[StorePackListGenre alloc] initWithName:kAllGenreName genreID:0]];
        dictPackInfo = [[NSMutableDictionary alloc] initWithCapacity:kPackInfoDictInitialCapacity];
    }
    return self;
}

/** @ghidraAddress 0xceb28 */
- (void)dealloc {
    [packlistDownloader cancel];
    // [super dealloc] is compiler-emitted (ARC).
}

#pragma mark - Genre queries

/** @ghidraAddress 0xcb9d8 */
- (NSUInteger)numGenres {
    return arrayGenre.count;
}

/** @ghidraAddress 0xcb9f0 */
- (NSArray<NSString *> *)genreNames {
    NSMutableArray<NSString *> *names = [[NSMutableArray alloc] initWithCapacity:arrayGenre.count];
    [arrayGenre
        enumerateObjectsUsingBlock:^(StorePackListGenre *genre, NSUInteger index, BOOL *stop) {
          /** @ghidraAddress 0xcbabc */
          [names addObject:genre.genreName];
        }];
    return names;
}

/** @ghidraAddress 0xcbb20 */
- (NSArray<StorePackListGenre *> *)genreInfos {
    return [arrayGenre copy];
}

/** @ghidraAddress 0xccbb4 */
- (int)genreIndexForgenreID:(NSInteger)genreID {
    for (NSUInteger index = 0; index < arrayGenre.count; ++index) {
        if ((NSInteger)arrayGenre[index].genreID == genreID) {
            return (int)index;
        }
    }
    return 0;
}

/** @ghidraAddress 0xccc80 */
- (nullable StorePackListGenre *)packListForGenreID:(NSInteger)genreID {
    if (genreID >= 0) {
        for (NSUInteger index = 0; index < arrayGenre.count; ++index) {
            StorePackListGenre *genre = arrayGenre[index];
            if ((NSInteger)genre.genreID == genreID) {
                return genre;
            }
        }
    }
    return nil;
}

/** @ghidraAddress 0xccd44 */
- (nullable StorePackListGenre *)packListForGenreIndex:(NSUInteger)genreIndex {
    if (genreIndex < arrayGenre.count) {
        return arrayGenre[genreIndex];
    }
    return nil;
}

#pragma mark - Genre building

/** @ghidraAddress 0xcbb48 */
- (void)addGenres:(nullable NSArray *)genreList {
    if (genreList.count != 2) {
        return;
    }
    NSArray *ids = genreList[0];
    NSArray *names = genreList[1];
    if (genreList.count) {
        if (![ids isKindOfClass:[NSArray class]]) {
            return;
        }
        if (![names isKindOfClass:[NSArray class]]) {
            return;
        }
    }
    [ids enumerateObjectsUsingBlock:^(id genreIDNumber, NSUInteger index, BOOL *stop) {
      /** @ghidraAddress 0xcbcdc */
      if (index >= names.count) {
          *stop = YES;
          return;
      }
      id name = names[index];
      if ([genreIDNumber isKindOfClass:[NSNumber class]] && [name isKindOfClass:[NSString class]]) {
          StorePackListGenre *genre =
              [[StorePackListGenre alloc] initWithName:name
                                               genreID:[genreIDNumber unsignedIntegerValue]];
          [arrayGenre addObject:genre];
      }
    }];
}

/** @ghidraAddress 0xcbe80 */
- (void)addGenres:(nullable NSArray *)genreList extendList:(nullable NSDictionary *)extendList {
    if (genreList.count != 2) {
        return;
    }
    if (arrayGenre.count == 1) {
        StorePackListGenre *only = arrayGenre[0];
        NSString *key = [NSString stringWithFormat:@"%ld", (long)only.genreID];
        if ([extendList objectForKey:key]) {
            [only setExtendInfo:[extendList objectForKey:key]];
        }
    }
    NSArray *ids = genreList[0];
    NSArray *names = genreList[1];
    if (genreList.count) {
        if (![ids isKindOfClass:[NSArray class]]) {
            return;
        }
        if (![names isKindOfClass:[NSArray class]]) {
            return;
        }
    }
    [ids enumerateObjectsUsingBlock:^(id genreIDNumber, NSUInteger index, BOOL *stop) {
      /** @ghidraAddress 0xcc148 */
      if (index >= names.count) {
          *stop = YES;
          return;
      }
      id name = names[index];
      if ([genreIDNumber isKindOfClass:[NSNumber class]] && [name isKindOfClass:[NSString class]]) {
          StorePackListGenre *genre =
              [[StorePackListGenre alloc] initWithName:name
                                               genreID:[genreIDNumber unsignedIntegerValue]];
          // The key array captured at +0x28 is the enumerated ID array itself, so the lookup key
          // is the decimal-string form of this element's own ID.
          NSString *key = [NSString stringWithFormat:@"%ld", [genreIDNumber longValue]];
          if ([extendList objectForKey:key]) {
              [genre setExtendInfo:[extendList objectForKey:key]];
          }
          [arrayGenre addObject:genre];
      }
    }];
}

#pragma mark - Promotions

/** @ghidraAddress 0xcc3e8 */
- (void)addPromotions:(nullable NSArray *)promotionList
        validProducts:(nullable NSArray<SKProduct *> *)validProducts {
    if (!promotionList.count) {
        return;
    }
    NSMutableArray<StorePromotion *> *promotions =
        [[NSMutableArray alloc] initWithCapacity:promotionList.count];
    for (id entry in promotionList) {
        if (![entry isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *imageURL = [entry stringForKey:kEntryKeyImageURL];
        if (![StoreUtil isValidURL:imageURL]) {
            continue;
        }
        NSString *identifier = [entry stringForKey:kEntryKeyID];
        if ([identifier hasPrefix:kPackPromotionPrefix]) {
            int packID = [[identifier substringFromIndex:kPromotionPrefixLength] intValue];
            if (packID > 0) {
                for (SKProduct *product in validProducts) {
                    if (packID == [StoreUtil packIDForProductID:product.productIdentifier]) {
                        StorePackInfo *packInfo =
                            [[StorePackInfo alloc] initWithDictionary:@{kEntryKeyID : @(packID)}
                                                              product:product];
                        StorePromotion *promotion = [[StorePromotion alloc]
                            initWithPackInfo:packInfo
                                    imageURL:imageURL
                                   sampleURL:[entry objectForKey:kEntryKeySampleURL]];
                        [promotions addObject:promotion];
                        break;
                    }
                }
            }
        } else if ([identifier hasPrefix:kGenrePromotionPrefix]) {
            int genreID = [[identifier substringFromIndex:kPromotionPrefixLength] intValue];
            [arrayGenre enumerateObjectsUsingBlock:^(
                            StorePackListGenre *genre, NSUInteger index, BOOL *stop) {
              /** @ghidraAddress 0xccaac */
              if ((NSInteger)genreID == (NSInteger)genre.genreID) {
                  StorePromotion *promotion = [[StorePromotion alloc] initWithGenreIndex:index
                                                                                imageURL:imageURL];
                  [promotions addObject:promotion];
                  *stop = YES;
              }
            }];
        }
    }
    if (promotions.count) {
        arrayPromotions = [[NSArray alloc] initWithArray:promotions];
    }
}

/** @ghidraAddress 0xccba4 */
- (nullable NSArray<StorePromotion *> *)promotions {
    return arrayPromotions;
}

#pragma mark - Fetching

/** @ghidraAddress 0xccdb0 */
- (void)startFetchForGenreID:(NSUInteger)genreID {
    genreFetching = [[StorePackListGenre alloc] initWithName:kTemporaryGenreName genreID:genreID];
    NSURL *url = [StoreUtil packListURL:0 limit:kPackFetchPageSize genre:(unsigned int)genreID];
    packlistDownloader = [[Downloader alloc] initWithURL:url delegate:self];
    [packlistDownloader startDownloading];
}

/** @ghidraAddress 0xcce9c */
- (void)startFetchForGenreIndex:(NSUInteger)genreIndex {
    if (genreIndex < arrayGenre.count) {
        genreFetching = arrayGenre[genreIndex];
        NSURL *url = [StoreUtil packListURL:(unsigned int)genreFetching.numFetchedPack
                                      limit:kPackFetchPageSize
                                      genre:(unsigned int)genreFetching.genreID];
        packlistDownloader = [[Downloader alloc] initWithURL:url delegate:self];
        [packlistDownloader startDownloading];
    }
}

/** @ghidraAddress 0xccfd0 */
- (void)startFetchGenre:(nullable StorePackListGenre *)genre {
    NSUInteger index = [arrayGenre indexOfObjectIdenticalTo:genre];
    if (index == NSNotFound) {
        return;
    }
    [self startFetchForGenreIndex:index];
}

/** @ghidraAddress 0xcd030 */
- (void)startFetchAdditionalPack:(nullable NSNumber *)packID {
    if (packID) {
        _additionalPackID = packID;
        NSMutableSet *productIDs = [[NSMutableSet alloc] init];
        [productIDs addObject:[StoreUtil productIDForPackID:_additionalPackID.intValue]];
        productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIDs];
        productsRequest.delegate = self;
        [productsRequest start];
    }
}

/** @ghidraAddress 0xcd16c */
- (void)cancelFetching {
    if (packlistDownloader) {
        [packlistDownloader cancel];
        packlistDownloader = nil;
    }
    if (productsRequest) {
        [productsRequest cancel];
        productsRequest = nil;
    }
    _additionalPackID = nil;
}

/** @ghidraAddress 0xcd1e8 */
- (BOOL)isFetching {
    if (packlistDownloader) {
        return YES;
    }
    return productsRequest != nil;
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0xcd218 */
- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *response = [StoreUtil checkStoreResponse:[downloader getData]];
    NSArray *packList = [response arrayForKey:kResponseKeyPackList];
    NSString *serverVersion = [response stringForKey:kResponseKeyVersion];
    NSString *appVersion = JubeatAppDelegate.appVersion;
    if (genreFetching) {
        [genreFetching updateGenreInfo:response];
    }
    if ([response objectForKey:kResponseKeyComment]) {
        (void)[response objectForKey:kResponseKeyComment]; // Yes, the binary discards this fetch.
    }
    NSInteger storedMonth =
        [NSUserDefaults.standardUserDefaults integerForKey:kDefaultsKeyPurchaseMonth];
    if ([response objectForKey:kResponseKeyDate]) {
        int date = [[response objectForKey:kResponseKeyDate] intValue];
        if ((int)storedMonth < date) {
            if ([NSUserDefaults.standardUserDefaults integerForKey:kDefaultsKeyPurchaseLimitType] !=
                kPurchaseLimitTypeSubscription) {
                [NSUserDefaults.standardUserDefaults setInteger:0
                                                         forKey:kDefaultsKeyPurchaseLimitType];
            }
            [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kDefaultsKeyTotalPurchase];
        }
        [NSUserDefaults.standardUserDefaults setInteger:date forKey:kDefaultsKeyPurchaseMonth];
    }
    if (!appVersion ||
        (serverVersion && [appVersion compare:serverVersion
                                      options:NSNumericSearch] == NSOrderedAscending)) {
        NSString *message = [NSString
            stringWithFormat:[NSBundle.mainBundle localizedStringForKey:kMessageKeyServerOldVersion
                                                                  value:@""
                                                                  table:nil]];
        [self.delegate packListDownloadError:self errorMessage:message];
        return;
    }
    if (!packList.count) {
        NSString *message = [response stringForKey:kResponseKeyError];
        if (!message) {
            message = [NSBundle.mainBundle localizedStringForKey:kMessageKeyServerError
                                                           value:@""
                                                           table:nil];
        }
        [self.delegate packListDownloadError:self errorMessage:message];
        genreFetching = nil;
        packlistDownloader = nil;
        return;
    }
    NSMutableArray *resolvedPacks = [[NSMutableArray alloc] init];
    NSMutableSet *productIDs = [[NSMutableSet alloc] init];
    if (_additionalPackID) {
        [productIDs addObject:[StoreUtil productIDForPackID:_additionalPackID.intValue]];
    }
    for (id entry in packList) {
        if (![entry isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSNumber *packID = [entry numberForKey:kEntryKeyID];
        if (!packID) {
            continue;
        }
        StorePackInfo *cached = [dictPackInfo objectForKey:packID];
        if (cached) {
            [resolvedPacks addObject:cached];
        } else {
            [productIDs addObject:[StoreUtil productIDForPackID:packID.intValue]];
        }
    }
    if (!_initiallyLoaded) {
        NSArray *promotionEntries = [response arrayForKey:kResponseKeyPromotion];
        if (promotionEntries.count) {
            [promotionEntries enumerateObjectsUsingBlock:^(id entry, NSUInteger index, BOOL *stop) {
              /** @ghidraAddress 0xcdcec */
              if (![entry isKindOfClass:[NSDictionary class]]) {
                  return;
              }
              NSString *identifier = [entry stringForKey:kEntryKeyID];
              if ([identifier hasPrefix:kPackPromotionPrefix]) {
                  int packID = [[identifier substringFromIndex:kPromotionPrefixLength] intValue];
                  if (packID > 0) {
                      [productIDs addObject:[StoreUtil productIDForPackID:packID]];
                  }
              }
            }];
        }
    }
    if (!productIDs.count) {
        if (!resolvedPacks.count) {
            NSString *message = [NSBundle.mainBundle localizedStringForKey:kMessageKeyServerError
                                                                     value:@""
                                                                     table:nil];
            [self.delegate packListDownloadError:self errorMessage:message];
            genreFetching = nil;
        } else {
            BOOL hasNext = [[response numberForKey:kResponseKeyHasNext] boolValue];
            [genreFetching updateList:resolvedPacks step:kPackFetchPageSize hasNext:hasNext];
            [self.delegate packListDownloadSuccess:self isInitial:NO showPack:nil];
            genreFetching = nil;
        }
    } else {
        tmpPackDict = [[NSDictionary alloc] initWithDictionary:response];
        productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIDs];
        productsRequest.delegate = self;
        [productsRequest start];
    }
    packlistDownloader = nil;
}

/** @ghidraAddress 0xcde28 */
- (void)downloaderError:(Downloader *)downloader {
    [self.delegate
        packListDownloadError:self
                 errorMessage:[NSBundle.mainBundle localizedStringForKey:kMessageKeyNetworkError
                                                                   value:@""
                                                                   table:nil]];
    _additionalPackID = nil;
    packlistDownloader = nil;
    genreFetching = nil;
}

/** @ghidraAddress 0xcdf18 */
- (void)downloaderProceed:(Downloader *)downloader {
}

#pragma mark - SKProductsRequestDelegate

/** @ghidraAddress 0xcdf1c */
- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response {
    BOOL hasNext = [[tmpPackDict numberForKey:kResponseKeyHasNext] boolValue];
    NSMutableArray *resolvedPacks = [[NSMutableArray alloc] init];
    if (response.products.count) {
        NSString *country =
            [response.products.lastObject.priceLocale objectForKey:NSLocaleCountryCode];
        if (!_storeCountry || ![_storeCountry isEqualToString:country]) {
            _storeCountry = [[NSString alloc] initWithString:country];
        }
    }
    NSArray *packList = [tmpPackDict arrayForKey:kResponseKeyPackList];
    for (id entry in packList) {
        if (![entry isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSNumber *packID = [entry numberForKey:kEntryKeyID];
        if (!packID) {
            continue;
        }
        StorePackInfo *cached = [dictPackInfo objectForKey:packID];
        if (!cached) {
            StorePackInfo *built = nil;
            for (SKProduct *product in response.products) {
                if (packID.intValue == [StoreUtil packIDForProductID:product.productIdentifier]) {
                    built = [[StorePackInfo alloc] initWithDictionary:entry product:product];
                    if (built) {
                        [dictPackInfo setObject:built forKey:packID];
                    }
                    break;
                }
            }
            if (built) {
                [resolvedPacks addObject:built];
            }
        } else {
            [resolvedPacks addObject:cached];
        }
    }
    StorePackInfo *additionalPack = nil;
    if (_additionalPackID) {
        additionalPack = [dictPackInfo objectForKey:_additionalPackID];
        if (!additionalPack) {
            int wanted = _additionalPackID.intValue;
            for (SKProduct *product in response.products) {
                if (wanted == [StoreUtil packIDForProductID:product.productIdentifier]) {
                    additionalPack =
                        [[StorePackInfo alloc] initWithDictionary:@{kEntryKeyID : _additionalPackID}
                                                          product:product];
                    break;
                }
            }
        }
        if (!resolvedPacks.count) {
            [self.delegate additionPackInfoDownloadSuccess:self showPack:additionalPack];
        }
        _additionalPackID = nil;
    }
    BOOL isInitial = NO;
    if (!_initiallyLoaded) {
        NSArray *genreList = [tmpPackDict arrayForKey:kResponseKeyGenre];
        NSDictionary *genreMeta = [tmpPackDict dictionaryForKey:kResponseKeyGenreMetaInfo];
        [self addGenres:genreList extendList:genreMeta];
        [self addPromotions:[tmpPackDict objectForKey:kResponseKeyPromotion]
              validProducts:response.products];
        isInitial = YES;
        _initiallyLoaded = YES;
        tmpPackDict = nil;
        if (genreFetching.genreID) {
            if (!arrayGenre.count) {
                isInitial = YES;
            } else {
                for (StorePackListGenre *genre in arrayGenre) {
                    if (genre.genreID == genreFetching.genreID) {
                        genreFetching = genre;
                    }
                }
                isInitial = YES;
            }
        }
    } else {
        tmpPackDict = nil;
        isInitial = NO;
    }
    if (!resolvedPacks.count) {
        [self.delegate packListDownloadNothing:self];
    } else {
        [genreFetching updateList:resolvedPacks step:kPackFetchPageSize hasNext:hasNext];
        [self.delegate packListDownloadSuccess:self isInitial:isInitial showPack:additionalPack];
    }
    genreFetching = nil;
}

/** @ghidraAddress 0xcea08 */
- (void)requestDidFinish:(SKRequest *)request {
    productsRequest = nil;
}

/** @ghidraAddress 0xcea20 */
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    productsRequest = nil;
    tmpPackDict = nil;
    genreFetching = nil;
    _additionalPackID = nil;
    [self.delegate
        packListDownloadError:self
                 errorMessage:[NSBundle.mainBundle localizedStringForKey:kMessageKeyNetworkError
                                                                   value:@""
                                                                   table:nil]];
}

@end
