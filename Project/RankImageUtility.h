/**
 * @file
 * @brief The score-to-rank-image helper.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base. This is a genuine free function: it takes no object
 * receiver and belongs to no class, operating instead across @c Sequence, @c JubeatAppDelegate, and
 * @c ImageCache, so the reconstruction rules' search for an owning class is exhausted. The basename
 * is inferred because the shipped binary embeds no @c __FILE__ path. Called from
 * @c -[MusicView setScore:] and @c -[MusicView setExtendScore:].
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Maps a score to its themed rank-letter image from the shared image cache.
 *
 * The score is classified with @c +[Sequence rankOfPoint:], which returns a rank in 0..8 ordered
 * ascending by quality (E is 0, EXC is 8). The rank selects a base resource name
 * (@c "rank_word_e" through @c "rank_word_exc"), which then takes a theme suffix from the app
 * delegate's current theme: @c "_rpl" for the ripples theme and @c "_knt" for the knit theme, with
 * the original theme leaving the name unchanged. The named PNG is fetched from the shared
 * @c ImageCache.
 *
 * @param nPoints The score to classify. It is passed straight through to @c rankOfPoint: with no
 *        arithmetic applied here.
 * @return The rank-letter image, or @c nil when @c rankOfPoint: reports a rank above 8.
 * @ghidraAddress 0x486e8
 */
UIImage *_Nullable GetRankImageForPoint(int nPoints);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
