#import "StoreMusicInfo.h"

#import "StoreUtil.h"

// The wire keys, from the CFStrings at 0x2d5400, 0x2d80c0, 0x2d8100, 0x2d8c20, 0x2dae20, 0x2da920,
// 0x2d8120, 0x2daf80, 0x2d5420, 0x2d8140, 0x2d8160, 0x2d9240, and 0x2dafa0. The capitalisation is
// the server's and is inconsistent: leading capitals for the core fields, lower case for the
// extension fields, and a lower-case "i" on "iTunesURL".
static NSString *const kMusicIDKey = @"ID";
static NSString *const kNameKey = @"Name";
static NSString *const kArtistKey = @"Artist";
static NSString *const kItemURLKey = @"ItemURL";
static NSString *const kSampleURLKey = @"SampleURL";
static NSString *const kArtworkURLKey = @"ArtworkURL";
static NSString *const kItunesURLKey = @"iTunesURL";
static NSString *const kLevelKey = @"Level";
static NSString *const kExtendFlagKey = @"extendFlag";
static NSString *const kHoldFlagKey = @"holdFlag";
static NSString *const kExtendMusicIDKey = @"extID";
static NSString *const kExtendItemURLKey = @"extURL";
static NSString *const kPlayableKey = @"playable";

// The lowest track identifier the record is willing to accept, compared with `cmp w0, #1` at
// 0xcef14. Anything below it rejects the record outright.
static const int kMinimumMusicID = 1;

// The chart levels are clamped into this range. The upper test is `cmp w9, #0xb` — greater than or
// equal to eleven becomes ten, so the constant in the binary is one past the maximum.
static const int kMinimumChartLevel = 1;
static const int kMaximumChartLevel = 10;

// The number of entries "Level" must exceed before any of the three levels is read, from
// `cmp x0, #2` at 0xcf130. Two entries are not enough; three are.
static const NSUInteger kRequiredLevelCount = 2;

// What the extended chart's playability defaults to when the server omits "playable", a bare
// immediate 7 at 0xcf538.
static const int kDefaultExtendPlayable = 7;

// Clamps one chart level the way the binary does, in three identical inlined copies at 0xcf1fc,
// 0xcf224, and 0xcf258. De-inlined because the copies differ only in which ivar they read.
static int ClampChartLevel(int level) {
    if (level <= 0) {
        return kMinimumChartLevel;
    }
    if (level >= kMaximumChartLevel + 1) {
        return kMaximumChartLevel;
    }
    return level;
}

@implementation StoreMusicInfo

/** @ghidraAddress 0xceeb0 */
- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    // Checked before -init is even called, so a bad record costs nothing.
    if ([[dictionary objectForKey:kMusicIDKey] intValue] < kMinimumMusicID) {
        return nil;
    }

    self = [super init];
    if (self == nil) {
        return nil;
    }

    // -intValue is sent a second time rather than the tested value being reused.
    _musicID = [[dictionary objectForKey:kMusicIDKey] intValue];
    self.name = [dictionary objectForKey:kNameKey];
    self.artist = [dictionary objectForKey:kArtistKey];
    // Stored unconditionally, unlike the three below.
    self.itemURL = [dictionary objectForKey:kItemURLKey];

    // These three are gated: a value that does not look like a URL is dropped rather than stored,
    // so the property stays nil.
    NSString *sampleURL = [dictionary objectForKey:kSampleURLKey];
    if ([StoreUtil isValidURL:sampleURL]) {
        self.sampleURL = sampleURL;
    }
    NSString *artworkURL = [dictionary objectForKey:kArtworkURLKey];
    if ([StoreUtil isValidURL:artworkURL]) {
        self.artworkURL = artworkURL;
    }
    NSString *itunesURL = [dictionary objectForKey:kItunesURLKey];
    if ([StoreUtil isValidURL:itunesURL]) {
        self.itunesURL = itunesURL;
    }

    // All three levels or none: the count test guards the whole block, so a short array leaves them
    // at the zero -alloc gave them, which the clamp below then turns into 1.
    NSArray *levels = [dictionary objectForKey:kLevelKey];
    if (levels.count > kRequiredLevelCount) {
        _lvBas = [[levels objectAtIndex:0] intValue];
        _lvAdv = [[levels objectAtIndex:1] intValue];
        _lvExt = [[levels objectAtIndex:2] intValue];
    }
    _lvBas = ClampChartLevel(_lvBas);
    _lvAdv = ClampChartLevel(_lvAdv);
    _lvExt = ClampChartLevel(_lvExt);

    // Cleared before the optional reads below, so an absent key leaves a known value rather than
    // whatever -alloc happened to give.
    _extendMusicID = 0;
    _holdFlag = 0;
    _extendFlag = 0;
    _extendItemURL = nil;

    // Each of these is fetched twice: once to test for nil and once to convert.
    if ([dictionary objectForKey:kExtendFlagKey] != nil) {
        _extendFlag = [[dictionary objectForKey:kExtendFlagKey] unsignedIntValue];
    }
    if ([dictionary objectForKey:kHoldFlagKey] != nil) {
        _holdFlag = [[dictionary objectForKey:kHoldFlagKey] unsignedIntValue];
    }
    if ([dictionary objectForKey:kExtendMusicIDKey] != nil) {
        _extendMusicID = [[dictionary objectForKey:kExtendMusicIDKey] unsignedIntValue];
        if ([dictionary objectForKey:kExtendItemURLKey] != nil) {
            _extendItemURL = [dictionary objectForKey:kExtendItemURLKey];
        }

        // The extended chart is materialised as a track of its own, by rewriting this record rather
        // than by reading a nested one. The recursion terminates because the rewritten copy has
        // "extID" removed, so the same branch cannot be taken twice.
        if (_extendMusicID != 0) {
            NSMutableDictionary *extended = [dictionary mutableCopy];
            [extended setObject:[dictionary objectForKey:kExtendMusicIDKey] forKey:kMusicIDKey];
            [extended setObject:[dictionary objectForKey:kExtendItemURLKey] forKey:kItemURLKey];

            // "playable" becomes the extended track's "extendFlag", defaulting to 7 when absent.
            id playable = [dictionary objectForKey:kPlayableKey];
            if (playable == nil) {
                playable = @(kDefaultExtendPlayable);
            }
            [extended setObject:playable forKey:kExtendFlagKey];

            [extended removeObjectForKey:kExtendMusicIDKey];
            [extended removeObjectForKey:kExtendItemURLKey];
            [extended removeObjectForKey:kPlayableKey];

            self.extendInfo = [[StoreMusicInfo alloc] initWithDictionary:extended];
        }
    }
    return self;
}

/** @ghidraAddress 0xcf650 */
- (StoreMusicInfo *)getExtendInfo {
    // One instruction and a tail call: this is the property getter under another name.
    return self.extendInfo;
}

@end
