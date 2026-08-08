#import "StorePackInfo.h"

#import <UIKit/UIKit.h>

#import "JubeatAppDelegate.h"
#import "StoreMusicInfo.h"
#import "StoreUtil.h"

// The typed-accessor category the store dictionaries are read through; a category on NSDictionary
// not reconstructed as its own file yet. See TYPES_PENDING.md.
@interface NSDictionary (TypedAccessors)
- (nullable NSNumber *)numberForKey:(nonnull id)key;
- (nullable NSString *)stringForKey:(nonnull id)key;
- (nullable NSArray *)arrayForKey:(nonnull id)key;
@end

// The store dictionary keys.
static NSString *const kPackKeyID = @"ID";
static NSString *const kPackKeyName = @"Name";
static NSString *const kPackKeyComment = @"Comment";
static NSString *const kPackKeyShortComment = @"ShortComment";
static NSString *const kPackKeyCopyright = @"Copyright";
static NSString *const kPackKeyIsNew = @"IsNew";
static NSString *const kPackKeyExtData = @"extData";
static NSString *const kPackKeyRegularPriceJPY = @"RegularPriceJPY";
static NSString *const kPackKeyArtworkURL = @"ArtworkURL";
static NSString *const kPackKeyHDArtworkURL = @"HDArtworkURL";
static NSString *const kPackKeyArtistURL = @"ArtistURL";
static NSString *const kPackKeyArtistBannerURL = @"ArtistBannerURL";
static NSString *const kPackKeyMusicList = @"MusicList";

// The currency code for which a struck-through regular price is shown.
static NSString *const kPackCurrencyCodeJPY = @"JPY";

// The value that marks a pack as carrying an extension.
static const int kPackExtDataHasExtend = 1;

// The strike-through colour for the regular price (red 0.8, opaque); the pooled double at 0x28e080.
static const CGFloat kPackStrikeThroughRed = 0.8; // @ghidraAddress 0x28e080

// The strike-through style value applied to the regular price.
static const NSInteger kPackStrikeThroughStyle = 3;

@implementation StorePackInfo {
    BOOL _isNew;                       // +0x8
    BOOL _hasExtend;                   // +0x9
    int _packID;                       // +0xc
    NSString *_artworkURL;             // +0x10
    NSString *_packName;               // +0x18
    NSString *_comment;                // +0x20
    NSString *_shortComment;           // +0x28
    NSString *_copyright;              // +0x30
    NSString *_linkURL;                // +0x38
    NSString *_linkTitle;              // +0x40
    NSArray *_musicInfos;              // +0x48
    SKProduct *_product;               // +0x50
    NSDecimalNumber *_regularPriceJPY; // +0x58
}

@synthesize packID = _packID;
@synthesize isNew = _isNew;
@synthesize hasExtend = _hasExtend;
@synthesize artworkURL = _artworkURL;
@synthesize packName = _packName;
@synthesize comment = _comment;
@synthesize shortComment = _shortComment;
@synthesize copyright = _copyright;
@synthesize linkURL = _linkURL;
@synthesize linkTitle = _linkTitle;
@synthesize musicInfos = _musicInfos;
@synthesize product = _product;
@synthesize regularPriceJPY = _regularPriceJPY;

#pragma mark - Construction

/** @ghidraAddress 0xbd4a0 */
- (instancetype)initWithDictionary:(NSDictionary *)dictionary product:(SKProduct *)product {
    self = [super init];
    if (self) {
        if (dictionary) {
            [self setPackInfo:dictionary];
        } else if (product) {
            // Without a dictionary the pack ID is recovered from the product identifier.
            _packID = [StoreUtil packIDForProductID:product.productIdentifier];
        }
        _product = product;
    }
    return self;
}

#pragma mark - Prices

/** @ghidraAddress 0xbd5ac */
- (NSString *)priceString {
    if (!self.product) {
        return nil;
    }
    return [StoreUtil priceString:self.product.price withLocale:self.product.priceLocale];
}

/** @ghidraAddress 0xbd6b4 */
- (NSAttributedString *)attributedPriceString {
    // A struck-through regular price is shown before the discounted price, but only for yen pricing
    // where a regular price exists and the product's price is lower than it.
    BOOL isJPY = [self.product.priceLocale.objectForKey:NSLocaleCurrencyCode
                                        isEqualToString:kPackCurrencyCodeJPY];
    if (isJPY && self.regularPriceJPY &&
        [self.product.price compare:self.regularPriceJPY] == NSOrderedAscending) {
        NSString *regularString = [StoreUtil priceString:self.regularPriceJPY
                                              withLocale:self.product.priceLocale];
        NSString *combined = [NSString stringWithFormat:@"%@ %@", regularString, self.priceString];
        NSMutableAttributedString *attributed =
            [[NSMutableAttributedString alloc] initWithString:combined];
        UIColor *strikeColor = [UIColor colorWithRed:kPackStrikeThroughRed green:0 blue:0 alpha:1];
        // The regular price and its trailing space are struck through in red.
        NSDictionary *strikeAttrs = @{
            NSStrikethroughStyleAttributeName : @(kPackStrikeThroughStyle),
            NSStrikethroughColorAttributeName : strikeColor,
        };
        [attributed addAttributes:strikeAttrs range:NSMakeRange(0, regularString.length + 1)];
        // The remainder (the discounted price) is tinted the same red.
        NSDictionary *colorAttrs = @{NSForegroundColorAttributeName : strikeColor};
        [attributed addAttributes:colorAttrs
                            range:NSMakeRange(regularString.length + 1,
                                              (attributed.length - 1) - regularString.length)];
        return attributed;
    }
    return [[NSMutableAttributedString alloc] initWithString:self.priceString];
}

#pragma mark - Dictionary parsing

/** @ghidraAddress 0xbdb4c */
- (NSString *)getArtworkURL:(NSDictionary *)dictionary {
    if (JubeatAppDelegate.appDelegate.isPadRetina) {
        NSString *hd = dictionary[kPackKeyHDArtworkURL];
        if ([StoreUtil isValidURL:hd]) {
            return hd;
        }
    }
    NSString *standard = dictionary[kPackKeyArtworkURL];
    return [StoreUtil isValidURL:standard] ? standard : nil;
}

/** @ghidraAddress 0xbdca0 */
- (void)setPackInfo:(NSDictionary *)dictionary {
    if (!dictionary) {
        return;
    }
    _packID = [dictionary numberForKey:kPackKeyID].intValue;
    _artworkURL = [self getArtworkURL:dictionary];
    _packName = [dictionary stringForKey:kPackKeyName];
    _comment = [dictionary stringForKey:kPackKeyComment];
    _shortComment = [dictionary stringForKey:kPackKeyShortComment];
    _copyright = [dictionary stringForKey:kPackKeyCopyright];
    _isNew = [dictionary numberForKey:kPackKeyIsNew].boolValue;
    _hasExtend = NO;
    if ([dictionary numberForKey:kPackKeyExtData]) {
        _hasExtend = [dictionary numberForKey:kPackKeyExtData].intValue == kPackExtDataHasExtend;
    }
    NSNumber *regular = [dictionary numberForKey:kPackKeyRegularPriceJPY];
    if (!regular) {
        _regularPriceJPY = nil;
    } else {
        _regularPriceJPY = [NSDecimalNumber decimalNumberWithDecimal:regular.decimalValue];
    }
}

/** @ghidraAddress 0xbdf84 */
- (BOOL)setPackDetailInfo:(NSDictionary *)dictionary {
    if (!dictionary) {
        return NO;
    }
    // Each field is filled only if the list pass left it empty.
    if (!_artworkURL) {
        _artworkURL = [self getArtworkURL:dictionary];
    }
    if (!_packName) {
        _packName = [dictionary stringForKey:kPackKeyName];
    }
    if (!_comment) {
        _comment = [dictionary stringForKey:kPackKeyComment];
    }
    if (!_copyright) {
        _copyright = [dictionary stringForKey:kPackKeyCopyright];
    }
    if (!_linkURL) {
        _linkURL = [dictionary stringForKey:kPackKeyArtistURL];
    }
    if (!_linkTitle) {
        _linkTitle = [dictionary stringForKey:kPackKeyArtistBannerURL];
    }
    return [self setMusicInfo:[dictionary arrayForKey:kPackKeyMusicList]];
}

/** @ghidraAddress 0xbe18c */
- (BOOL)setMusicInfo:(NSArray *)musicList {
    if (_musicInfos) {
        return YES;
    }
    if (musicList.count == 0) {
        return NO;
    }
    NSMutableArray *built = [NSMutableArray arrayWithCapacity:4];
    for (NSDictionary *entry in musicList) {
        StoreMusicInfo *info = [[StoreMusicInfo alloc] initWithDictionary:entry];
        if (info) {
            [built addObject:info];
        }
    }
    if (built.count != 0) {
        _musicInfos = [[NSArray alloc] initWithArray:built];
    }
    return built.count != 0;
}

@end
