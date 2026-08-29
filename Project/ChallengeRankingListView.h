/**
 * @file
 * @brief The per-tune scratch ranking list: the country/rival ranking table for one challenge
 * tune, with the difficulty and area selectors, paging controls, and the rival-add overlay.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeRankingListView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, taken from the dyld bind at the class object's superclass slot.
 */

#import <UIKit/UIKit.h>

@class ScratchInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The delegate a @c ChallengeRankingListView reports back to.
 *
 * Every selector is optional: the list only messages the delegate when it responds. The committed
 * @c ScratchMusicDetailView and @c ChallengePrevRankingView both adopt this protocol.
 */
@protocol ChallengeRankingListViewDelegate <NSObject>
@optional
/** The ranking list wants to be dismissed (close button or a returned session error). */
- (void)closeRanking;
/** The player's own ranking row was resolved, so a host that caches it can refresh. */
- (void)changeRanking;
@end

/**
 * @brief A challenge-tune ranking list built over a modal frame.
 *
 * Two initialisers construct it: one from a resolved @c ScratchInfo (the music-detail path), the
 * other from a raw line-up dictionary (the previous-event path). Both build the same chrome in
 * @c -createView and fetch the first page over a signed session request.
 */
@interface ChallengeRankingListView : UIView

/**
 * @brief The delegate, weakly held and untyped in the metadata.
 * @ghidraAddress 0x15a8c8 (getter)
 * @ghidraAddress 0x15a8e8 (setter)
 */
@property(nonatomic, weak, nullable) id<ChallengeRankingListViewDelegate> aDelegate;

/**
 * @brief Builds the list for a resolved scratch track.
 * @param frame The modal frame to lay out over.
 * @param mInfo The resolved track, whose id, name, and the player's rank seed the list.
 * @param rankType The initial area (0 = country, 1 = rival).
 * @return The initialised list view.
 * @ghidraAddress 0x156254
 */
- (instancetype)initWithFrame:(CGRect)frame
                        mInfo:(nullable ScratchInfo *)mInfo
                     rankType:(int)rankType;

/**
 * @brief Builds the list for a line-up dictionary from the previous-event listing.
 * @param frame The modal frame to lay out over.
 * @param mDict The line-up record, carrying @c name and @c music_id .
 * @param scratchID The event's scratch id, boxed for the request body.
 * @return The initialised list view.
 * @ghidraAddress 0x1564cc
 */
- (instancetype)initWithFrame:(CGRect)frame
                        mDict:(nullable NSDictionary *)mDict
                    scratchID:(int)scratchID;

/**
 * @brief Swaps the back button's image for the ranking-screen variant.
 * @ghidraAddress 0x15a440
 */
- (void)replaceBackBtnImage;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
