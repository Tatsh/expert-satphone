#import "ResultTweet.h"

#import <stdio.h>

#import "BFCodec.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "MainGameRenderer.h"
#import "TextureLoading.h"
#import "TweetResourceManager.h"
#import "cipher_keys.h"

// The finished tweet plate size, and the base-plate rectangle, which fills it.
static const CGFloat kTweetImageWidth = 540.0;  // @ghidraAddress 0x28f900
static const CGFloat kTweetImageHeight = 380.0; // @ghidraAddress 0x28f918

// The player accessory, drawn as a square inset from the top-left corner. The origin is an fmov
// immediate at 0xbc340/0xbc3a0.
static const CGFloat kAccessoryOrigin = 22.0;
static const CGFloat kAccessorySide = 130.0; // @ghidraAddress 0x28fa38

// The title image origin.
static const CGFloat kTitleOriginX = 176.0; // @ghidraAddress 0x28e038
static const CGFloat kTitleOriginY = 60.0;  // @ghidraAddress 0x28f258

// The music-information row. The difficulty badge sits at kMusicInfoX; the "level" word and the
// level number follow it horizontally, both sharing the badge's baseline apart from the number,
// which drops slightly.
static const CGFloat kMusicInfoX = 178.0;   // @ghidraAddress 0x291cf8
static const CGFloat kMusicInfoY = 130.0;   // @ghidraAddress 0x28fa38 (shares the accessory slot)
static const CGFloat kLevelNumberY = 122.0; // @ghidraAddress 0x291d00

// The music bar: kMusicBarColumnCount dot cells laid left to right.
static const CGFloat kMusicBarY = 284.0; // @ghidraAddress 0x291d08
static const CGFloat kMusicBarStartX = 30.0;
static const CGFloat kMusicBarStepX = 4.0;
static const int kMusicBarColumnCount = 120; // 0x78

// The seven score digits, laid left to right.
static const CGFloat kScoreDigitY = 194.0;     // @ghidraAddress 0x291d10
static const CGFloat kScoreDigitFirstX = 20.0; // The binary forms this as (-322 + 342).
static const CGFloat kScoreDigitPitch = 46.0;  // 0x2e
static const int kScoreDigitCount = 7;

// The rank badge origin.
static const CGFloat kRankOriginX = 380.0; // @ghidraAddress 0x28f918 (shares the height slot)
static const CGFloat kRankOriginY = 146.0; // @ghidraAddress 0x28f910

// The full-combo / excellent stamp, anchored to its right edge and vertically centred.
static const CGFloat kFullComboRightAnchor = 343.0; // 0x157
static const CGFloat kFullComboCenterY = 252.0;     // 0xfc

// The number of cached decoded images to keep.
static const NSUInteger kCacheCountLimit = 128; // 0x80

// The resource-archive subtree the decoration images are read from.
static NSString *const kTwitterResourcesDirectory = @"twitterResources";

// The frame-independent share subtree the path helpers fall back to.
static NSString *const kShareDataDirectory = @"shareData";

// The difficulty-keyed music-bar badge letters ("mb_%c"), indexed by RendererConf.diff. These sit
// adjacent to the dot-grade letters below in the same pool run.
static const char kMusicBarDiffLetters[] = "bae"; // @ghidraAddress 0x291d18

// The dot-grade letters ("dot_%c_%d"), indexed by the 2-bit grade from ScoreData.musicBarResult.
static const char kDotGradeLetters[] = "png"; // @ghidraAddress 0x291d1b

// The play sequence: the live source of the score summary, the packed music-bar nibbles, and the
// achieved rank. Not yet reconstructed.
@interface Sequence : NSObject
- (const ScoreData *)getScore;
- (const char *)getMusicBar;
- (int)rank;
@end

// The played chart's renderer configuration: its difficulty and level. Not yet reconstructed.
@interface RendererConf : NSObject
- (int)diff;
- (int)level;
@end

// Resolves the on-disk archive path of a marker set. Not yet reconstructed.
@interface MarkerManager : NSObject
+ (nullable NSString *)getMarkerPath:(nullable NSString *)markerID;
@end

@interface ResultTweet ()
/** @ghidraAddress 0xbd034 */
+ (nullable NSString *)getTwitterImagePathOrg:(nullable NSString *)fileName;
/** @ghidraAddress 0xbd2e0 */
+ (nullable NSString *)getAppendDataDirectoryPath;
/** @ghidraAddress 0xbc250 */
- (void)drawBg;
/** @ghidraAddress 0xbc31c */
- (void)drawPlayerInfo;
/** @ghidraAddress 0xbc3d4 */
- (void)drawMusicInfo;
/** @ghidraAddress 0xbc69c */
- (void)drawResult;
/** @ghidraAddress 0xbce5c */
- (nullable UIImage *)getResPNG:(nullable NSString *)name;
/** @ghidraAddress 0xbcf0c */
- (nullable UIImage *)getImage:(nullable NSString *)name;
@end

@implementation ResultTweet {
    UIImage *basePlate;
    Sequence *sequenceData;
    UIImage *titleBImg;
    UIImage *titleWImg;
    ScoreData *scoreData;
    RendererConf *confInfo;
    NSCache *cache;
    BOOL bWhiteTitle;
    KUnzip *resourceData;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0xbbf94 */
- (instancetype)initWithInfo:(Sequence *)info conf:(RendererConf *)conf {
    self = [super init];
    if (self) {
        sequenceData = info;
        confInfo = conf;
        cache = [[NSCache alloc] init];
        cache.countLimit = kCacheCountLimit;
        bWhiteTitle = NO;
        NSString *frame = [NSUserDefaults.standardUserDefaults objectForKey:@"PrefTwitterBgFrame"];
        resourceData = [TweetResourceManager getResourceData:frame];
        if (resourceData) {
            [resourceData fileList]; // Yes, the binary discards this call's result.
        }
    }
    return self;
}

/** @ghidraAddress 0xbc14c */
- (void)setTitle:(nullable UIImage *)title white:(nullable UIImage *)white {
    titleBImg = title;
    titleWImg = white;
}

#pragma mark - Composition

/** @ghidraAddress 0xbc1c8 */
- (nullable UIImage *)generateTweetImage {
    UIGraphicsBeginImageContext(CGSizeMake(kTweetImageWidth, kTweetImageHeight));
    [self drawBg];
    [self drawMusicInfo];
    [self drawResult];
    [self drawPlayerInfo];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

/** @ghidraAddress 0xbc250 */
- (void)drawBg {
    UIImage *base = [self getImage:@"base_b"];
    if (base) {
        // The light plate carries the white title variant.
        bWhiteTitle = YES;
    } else {
        base = [self getImage:@"base"];
        if (!base) {
            return;
        }
    }
    [base drawInRect:CGRectMake(0, 0, kTweetImageWidth, kTweetImageHeight)];
}

/** @ghidraAddress 0xbc31c */
- (void)drawPlayerInfo {
    NSString *accessory =
        [NSUserDefaults.standardUserDefaults objectForKey:@"PrefTwitterAccessory"];
    UIImage *image = [ResultTweet getAccessoryImage:accessory];
    [image
        drawInRect:CGRectMake(kAccessoryOrigin, kAccessoryOrigin, kAccessorySide, kAccessorySide)];
}

/** @ghidraAddress 0xbc3d4 */
- (void)drawMusicInfo {
    UIImage *title = bWhiteTitle ? titleWImg : titleBImg;
    [title drawAtPoint:CGPointMake(kTitleOriginX, kTitleOriginY)];

    NSArray<NSString *> *diffNames = @[ @"basic", @"advanced", @"extreme" ];
    UIImage *diffImage = [self getImage:diffNames[[confInfo diff]]];
    [diffImage drawAtPoint:CGPointMake(kMusicInfoX, kMusicInfoY)];
    CGFloat x = (CGFloat)(int)(kMusicInfoX + diffImage.size.width);

    // The binary builds this name with a no-argument stringWithFormat:.
    UIImage *levelWord = [self getImage:@"level"];
    [levelWord drawAtPoint:CGPointMake(x, kMusicInfoY)];
    x = (CGFloat)(int)(x + levelWord.size.width);

    NSString *levelName = [NSString stringWithFormat:@"lv_%d", [confInfo level]];
    UIImage *levelImage = [self getImage:levelName];
    [levelImage drawAtPoint:CGPointMake(x, kLevelNumberY)];
}

/** @ghidraAddress 0xbc69c */
- (void)drawResult {
    const ScoreData *score = [sequenceData getScore];
    const char *musicBar = [sequenceData getMusicBar];

    // The music-bar base plate, keyed to the difficulty.
    NSString *barName = [NSString stringWithFormat:@"mb_%c", kMusicBarDiffLetters[[confInfo diff]]];
    [[self getResPNG:barName] drawAtPoint:CGPointMake(0, kMusicBarY)];

    // One dot cell per column. Each column reads a 4-bit dot index from the packed music bar and a
    // 2-bit grade from the score's per-bar result string.
    CGFloat dotX = kMusicBarStartX;
    for (int i = 0; i < kMusicBarColumnCount; ++i) {
        int dotIndex = (musicBar[i / 2] >> ((i & 1) * 4)) & 0xf;
        if (dotIndex >= 1 && dotIndex <= 8) {
            int grade = (score->musicBarResult[i / 4] >> ((i & 3) * 2)) & 0x3;
            NSString *dotName =
                [NSString stringWithFormat:@"dot_%c_%d", kDotGradeLetters[grade], dotIndex];
            [[self getResPNG:dotName] drawAtPoint:CGPointMake(dotX, kMusicBarY)];
        }
        dotX += kMusicBarStepX;
    }

    // The right-aligned seven-digit score, one glyph per digit character.
    char digits[8];
    snprintf(digits, sizeof(digits), "%7d", score->totalPoint);
    for (int i = 0; i < kScoreDigitCount; ++i) {
        char c = digits[i];
        if (c >= '0' && c <= '9') {
            NSString *digitName = [NSString stringWithFormat:@"score_%c", c];
            [[self getResPNG:digitName]
                drawAtPoint:CGPointMake(kScoreDigitFirstX + i * kScoreDigitPitch, kScoreDigitY)];
        }
    }

    // The rank badge.
    NSArray<NSString *> *rankLetters =
        @[ @"e", @"d", @"c", @"b", @"a", @"s", @"ss", @"sss", @"exc" ];
    NSString *rankName = [NSString stringWithFormat:@"rank_%@", rankLetters[[sequenceData rank]]];
    [[self getResPNG:rankName] drawAtPoint:CGPointMake(kRankOriginX, kRankOriginY)];

    // The full-combo or excellent stamp. All four judgement counts zero is excellent; no miss and
    // no poor (but some good or great) is a full combo; anything else draws nothing.
    NSString *stampName;
    if (score->nMiss + score->nPoor + score->nGood + score->nGreat == 0) {
        stampName = @"exc";
    } else if (score->nMiss + score->nPoor != 0) {
        return;
    } else {
        stampName = @"full";
    }
    UIImage *stamp = [self getResPNG:stampName];
    CGSize stampSize = stamp.size;
    [stamp drawAtPoint:CGPointMake(kFullComboRightAnchor - (int)stampSize.width,
                                   kFullComboCenterY - ((int)stampSize.height >> 1))];
}

#pragma mark - Resource loading

/** @ghidraAddress 0xbce5c */
- (nullable UIImage *)getResPNG:(nullable NSString *)name {
    if (!name) {
        return nil;
    }
    UIImage *image = [cache objectForKey:name];
    if (!image) {
        image = [self getImage:name];
        if (image) {
            [cache setObject:image forKey:name];
        }
    }
    return image;
}

/** @ghidraAddress 0xbcf0c */
- (nullable UIImage *)getImage:(nullable NSString *)name {
    if (!resourceData) {
        return nil;
    }
    NSString *path = [kTwitterResourcesDirectory stringByAppendingPathComponent:name];
    NSMutableData *data = [resourceData uncompress:path];
    if (!data) {
        return nil;
    }
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:CreateTextureCipherKey()];
    return CreateImageFromEncryptedData(codec, data);
}

#pragma mark - Sample images

/** @ghidraAddress 0xbcbc8 */
+ (nullable UIImage *)getSampleImage:(nullable NSString *)frameName {
    KUnzip *resource = [TweetResourceManager getResourceData:frameName];
    NSData *key = CreateTextureCipherKey();
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:key];
    NSString *path = [kTwitterResourcesDirectory stringByAppendingPathComponent:@"set"];
    NSMutableData *data = [resource uncompress:path];
    return CreateImageFromEncryptedData(codec, data);
}

/** @ghidraAddress 0xbcce0 */
+ (nullable UIImage *)getAccessoryImage:(nullable NSString *)accessoryName {
    // The argument is ignored; the accessory comes from the current marker default.
    NSString *markerID = [NSUserDefaults.standardUserDefaults objectForKey:@"PrefCurrentMarkerID"];
    NSString *path = [MarkerManager getMarkerPath:markerID];
    KUnzip *resource = [[KUnzip alloc] initWithPath:path];
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:CreateTextureCipherKey()];
    NSMutableData *data = [resource uncompress:@"ma15"];
    return CreateImageFromEncryptedData(codec, data);
}

#pragma mark - Paths

/** @ghidraAddress 0xbd034 */
+ (nullable NSString *)getTwitterImagePathOrg:(nullable NSString *)fileName {
    NSString *frame = [NSUserDefaults.standardUserDefaults objectForKey:@"PrefTwitterBgFrame"];
    NSString *directory = [ResultTweet getAppendDataDirectoryPath];
    if (!directory) {
        return nil;
    }
    NSString *relative = [NSString stringWithFormat:@"%@/twitterResources/%@", frame, fileName];
    NSString *path = [directory stringByAppendingPathComponent:relative];
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
        return nil;
    }
    return path;
}

/** @ghidraAddress 0xbd19c */
+ (nullable NSString *)getTwitterImagePath:(NSString *)fileName {
    NSString *original = [ResultTweet getTwitterImagePathOrg:fileName];
    if (original) {
        return original;
    }
    NSString *directory = [ResultTweet getAppendDataDirectoryPath];
    NSString *relative =
        [NSString stringWithFormat:@"%@/twitterResources/%@", kShareDataDirectory, fileName];
    NSString *path = [directory stringByAppendingPathComponent:relative];
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
        return nil;
    }
    return path;
}

/** @ghidraAddress 0xbd2e0 */
+ (nullable NSString *)getAppendDataDirectoryPath {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *library = JubeatAppDelegate.appLibraryDirectory;
    NSString *privateDocuments = [library stringByAppendingPathComponent:@"Private Documents"];
    // The existence check is on the library directory itself, not on Private Documents.
    if (![fileManager fileExistsAtPath:library]) {
        return nil;
    }
    NSString *appendData = [privateDocuments stringByAppendingPathComponent:@"appendData"];
    if (![fileManager fileExistsAtPath:appendData]) {
        return nil;
    }
    return appendData;
}

@end
