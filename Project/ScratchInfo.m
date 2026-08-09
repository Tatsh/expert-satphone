#import "ScratchInfo.h"

#import "ChallengeStatus.h"
// The number of difficulties and the clamps the getters apply to an out-of-range index.
static const int kScratchDifficultyCount = 4;
static const int kScratchScoreClamp = 4;
static const int kScratchFullComboClamp = 3;

// The line-up dictionary keys used to resolve a track.
static NSString *const kScratchKeyMusicID = @"music_id";
static NSString *const kScratchKeyName = @"name";
static NSString *const kScratchKeyArtist = @"artist";
static NSString *const kScratchKeyImageURL = @"image_url";
static NSString *const kScratchKeyDataURL = @"data_url";
static NSString *const kScratchKeyPackID = @"pack_id";

// The per-difficulty result keys, and the score/rank/full-combo keys within each.
static NSString *const kScratchKeyMyRank = @"my_rank";
static NSString *const kScratchKeyScore = @"score";
static NSString *const kScratchKeyRank = @"rank";
static NSString *const kScratchKeyIsFullCombo = @"is_fullcombo";

// The difficulty column keys, in order.
static NSString *const kScratchDifficultyBasic = @"BSC";
static NSString *const kScratchDifficultyAdvanced = @"ADV";
static NSString *const kScratchDifficultyExtreme = @"EXT";
static NSString *const kScratchDifficultyTotal = @"TOTAL";

@implementation ScratchInfo {
    int _musicID;                // +0x4
    int myScore[4];              // +0x8
    int myRank[4];               // +0x18
    int myIndex[4];              // +0x28
    unsigned char bFullCombo[4]; // +0x38
    NSString *_musicName;        // strong
    NSString *_artistName;       // strong
    NSString *_imgURL;           // strong
    NSString *_itemURL;          // strong
    NSInteger _packID;           // longValue
}

#pragma mark - Construction

/** @ghidraAddress 0x1ca474 */
- (instancetype)init:(NSDictionary *)dictionary {
    _musicID = 0;
    if (dictionary[kScratchKeyMusicID]) {
        _musicID = [dictionary[kScratchKeyMusicID] intValue];
    }
    if (_musicID == 0) {
        _packID = 0;
    } else {
        // Resolve the track's details from the challenge line-up by music id.
        for (NSDictionary *entry in ChallengeStatus.sharedStatus.scratchLineUp) {
            if ([entry[kScratchKeyMusicID] intValue] == _musicID) {
                _musicName = entry[kScratchKeyName];
                _artistName = entry[kScratchKeyArtist];
                _imgURL = entry[kScratchKeyImageURL];
                _itemURL = entry[kScratchKeyDataURL];
                _packID = [entry[kScratchKeyPackID] longValue];
            }
        }
    }
    // Every per-difficulty result starts empty.
    for (int i = 0; i < kScratchDifficultyCount; ++i) {
        myRank[i] = -1;
        myScore[i] = -1;
        myIndex[i] = -1;
        bFullCombo[i] = 0;
    }
    return self;
}

#pragma mark - Results

/** @ghidraAddress 0x1ca854 */
- (void)openUpdate:(NSDictionary *)dictionary {
    NSDictionary *ranks = dictionary[kScratchKeyMyRank];
    NSArray<NSString *> *columns = @[
        kScratchDifficultyBasic,
        kScratchDifficultyAdvanced,
        kScratchDifficultyExtreme,
        kScratchDifficultyTotal
    ];
    if (!ranks) {
        for (int i = 0; i < kScratchDifficultyCount; ++i) {
            myScore[i] = -1;
            myRank[i] = -1;
            bFullCombo[i] = 0;
        }
        return;
    }
    for (int i = 0; i < kScratchDifficultyCount; ++i) {
        myScore[i] = -1;
        myRank[i] = -1;
        bFullCombo[i] = 0;
        NSDictionary *entry = ranks[columns[i]];
        if (entry) {
            myScore[i] = [entry[kScratchKeyScore] intValue];
            myRank[i] = [entry[kScratchKeyRank] intValue];
            bFullCombo[i] = (unsigned char)[entry[kScratchKeyIsFullCombo] boolValue];
        }
    }
}

#pragma mark - Accessors

/** @ghidraAddress 0x1caa60 */
- (int)getMyScore:(int)difficulty {
    return myScore[difficulty < kScratchScoreClamp ? difficulty : 0];
}

/** @ghidraAddress 0x1caa80 */
- (int)getMyRank:(int)difficulty {
    return myRank[difficulty < kScratchScoreClamp ? difficulty : 0];
}

/** @ghidraAddress 0x1caaa0 */
- (int)getMyIndex:(int)difficulty {
    // The binary reads the rank array here despite the "index" name.
    return myRank[difficulty < kScratchScoreClamp ? difficulty : 0];
}

/** @ghidraAddress 0x1caac0 */
- (void)setMyRank:(int)difficulty rank:(int)rank index:(int)index {
    // The index argument is discarded; only the rank is stored, for an in-range non-negative rank.
    if (difficulty < kScratchScoreClamp && rank >= 0) {
        myRank[difficulty] = rank;
    }
}

/** @ghidraAddress 0x1caae0 */
- (BOOL)getFullCombo:(int)difficulty {
    return bFullCombo[difficulty < kScratchFullComboClamp ? difficulty : 0];
}

@end
