#import "RankImageUtility.h"

#import "ImageCache.h"
#import "JubeatAppDelegate.h"

// Sequence is not reconstructed yet; only its score-classifying class method is needed here.
@interface Sequence : NSObject
+ (short)rankOfPoint:(unsigned int)points;
@end

// The base rank-letter resource names, indexed by rank ascending from E (worst) to EXC (best).
// From the pooled strings at 0x2803bf onwards.
static NSString *const kRankImageNames[] = {
    @"rank_word_e",
    @"rank_word_d",
    @"rank_word_c",
    @"rank_word_b",
    @"rank_word_a",
    @"rank_word_s",
    @"rank_word_ss",
    @"rank_word_sss",
    @"rank_word_exc",
};

// The highest rank rankOfPoint: can return; anything above falls through to nil. The compiled
// `cmp w0,#0x8` is unsigned, so a negative or larger rank is also rejected here.
static const short kMaxRank = 8;

// The per-theme resource-name suffixes, from the pooled strings at 0x27fcc8 and 0x27fccd.
static NSString *const kRipplesThemeSuffix = @"_rpl";
static NSString *const kKnitThemeSuffix = @"_knt";

UIImage *GetRankImageForPoint(int nPoints) {
    short rank = [Sequence rankOfPoint:(unsigned int)nPoints];
    // The compiled test is an unsigned `cmp w0,#0x8; b.hi`, so any rank outside 0..8 yields nil.
    if ((unsigned int)rank > (unsigned int)kMaxRank) {
        return nil;
    }
    NSString *name = kRankImageNames[rank];

    if (JubeatAppDelegate.appDelegate.currentTheme == JubeatThemeRipples) {
        name = [name stringByAppendingString:kRipplesThemeSuffix];
    } else if (JubeatAppDelegate.appDelegate.currentTheme == JubeatThemeKnit) {
        // The binary re-sends both appDelegate and currentTheme here rather than reusing the first
        // result. Behaviourally identical unless the theme changes between the two reads.
        name = [name stringByAppendingString:kKnitThemeSuffix];
    }

    return [ImageCache.sharedCache getResPNG:name];
}
