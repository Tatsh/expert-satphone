#import "StorePackListGenre.h"

// The initial capacity of the accumulated pack-identifier array.
static const int kPackInfoInitialCapacity = 20;

// The number of slash-separated components a valid colour string carries.
static const int kColorComponentCount = 3;

// The divisor turning a 0-255 colour byte into a normalised 0-1 component.
static const float kColorComponentScale = 255.0f;

// The alpha applied to the opaque genre border colour.
static const float kGenreColorAlpha = 1.0f;

// The alpha applied to the translucent genre backdrop colour.
static const float kGenreBGColorAlpha = 0.7f;

// The separator between the red, green, and blue bytes of a colour string.
static NSString *const kColorComponentSeparator = @"/";

// The extend-info dictionary keys.
static NSString *const kButtonImageURLKey = @"buttonImageUrl";
static NSString *const kColorKey = @"color";
static NSString *const kIntroductionKey = @"introduction";
static NSString *const kGenreImageURLKey = @"genreImageUrl";

// The genre-info dictionary key holding the description.
static NSString *const kCommentKey = @"Comment";

@implementation StorePackListGenre {
    // The accumulated boxed pack identifiers for this genre. A bare ivar in the binary, with no
    // backing property.
    NSMutableArray<StorePackInfo *> *arrayPackInfo;
}

#pragma mark - Colour parsing

/** @ghidraAddress 0x1b0418 */
- (UIColor *)getColor:(NSString *)colorString alpha:(float)alpha {
    NSArray<NSString *> *components =
        [colorString componentsSeparatedByString:kColorComponentSeparator];
    if (components.count != kColorComponentCount) {
        return nil;
    }
    float red = (float)components[0].intValue / kColorComponentScale;
    float green = (float)components[1].intValue / kColorComponentScale;
    float blue = (float)components[2].intValue / kColorComponentScale;
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x1b0594 */
- (instancetype)initWithName:(NSString *)name genreID:(NSUInteger)genreID {
    self = [super init];
    if (self) {
        arrayPackInfo = [[NSMutableArray alloc] initWithCapacity:kPackInfoInitialCapacity];
        self->_genreName = name;
        self->_genreID = genreID;
        self->_genreImageURL = nil;
        self->_genreColor = nil;
        self->_genreBGColor = nil;
        self->_packlistContinued = NO;
        self->_numFetchedPack = 0;
    }
    return self;
}

/** @ghidraAddress 0x1b06b8 */
- (instancetype)initWithName:(NSString *)name
                     genreID:(NSUInteger)genreID
                      imgURL:(NSString *)imgURL
                         col:(NSString *)col {
    self = [super init];
    if (self) {
        arrayPackInfo = [[NSMutableArray alloc] initWithCapacity:kPackInfoInitialCapacity];
        self->_genreName = name;
        self->_genreID = genreID;
        self->_genreImageURL = nil;
        self->_genreColor = nil;
        if ([self isExist:imgURL]) {
            self->_genreImageURL = imgURL;
        }
        if ([self isExist:col]) {
            self->_genreColor = [self getColor:col alpha:kGenreColorAlpha];
            self->_genreBGColor = [self getColor:col alpha:kGenreBGColorAlpha];
        }
        self->_packlistContinued = NO;
        self->_numFetchedPack = 0;
    }
    return self;
}

#pragma mark - Presence test

/** @ghidraAddress 0x1b08b4 */
- (BOOL)isExist:(NSString *)string {
    if (string == nil || [string isEqualToString:@""]) {
        return NO;
    }
    return YES;
}

#pragma mark - Extend info

/** @ghidraAddress 0x1b0910 */
- (void)setExtendInfo:(NSDictionary *)info {
    NSString *buttonImageURL = info[kButtonImageURLKey];
    if ([self isExist:buttonImageURL]) {
        self->_genreImageURL = info[kButtonImageURLKey];
    }
    NSString *color = info[kColorKey];
    if ([self isExist:color]) {
        // Both colours take an opaque alpha here, unlike -initWithName:genreID:imgURL:col:, which
        // gives the backdrop a translucent alpha.
        self->_genreColor = [self getColor:info[kColorKey] alpha:kGenreColorAlpha];
        self->_genreBGColor = [self getColor:info[kColorKey] alpha:kGenreColorAlpha];
    }
    NSString *introduction = info[kIntroductionKey];
    if ([self isExist:introduction]) {
        self->_genreComment = info[kIntroductionKey];
    }
    NSString *genreImageURL = info[kGenreImageURLKey];
    if ([self isExist:genreImageURL]) {
        self->_genreBgImageURL = info[kGenreImageURLKey];
    }
}

#pragma mark - Pack access

/** @ghidraAddress 0x1b0bc8 */
- (NSUInteger)packCount {
    return arrayPackInfo.count;
}

/** @ghidraAddress 0x1b0be0 */
- (NSArray<StorePackInfo *> *)packList {
    return arrayPackInfo;
}

/** @ghidraAddress 0x1b0bf0 */
- (StorePackInfo *)packInfoForIndex:(NSUInteger)index {
    if (index < arrayPackInfo.count) {
        return arrayPackInfo[index];
    }
    return nil;
}

#pragma mark - Page accumulation

/** @ghidraAddress 0x1b0c5c */
- (void)updateList:(NSArray<StorePackInfo *> *)list step:(NSUInteger)step hasNext:(BOOL)hasNext {
    if (list.count != 0) {
        [arrayPackInfo addObjectsFromArray:list];
    }
    self->_packlistContinued = hasNext;
    self->_numFetchedPack += step;
}

/** @ghidraAddress 0x1b0ce4 */
- (void)updateGenreInfo:(NSDictionary *)info {
    if (info != nil && info[kCommentKey] != nil) {
        self->_genreComment = info[kCommentKey];
    }
}

/** @ghidraAddress 0x1b0d80 */
- (void)copyGenreData:(StorePackListGenre *)genre {
    // The shipped binary is an empty stub that returns immediately.
}

@end
