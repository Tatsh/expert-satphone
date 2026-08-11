/** @file
 * The challenge-mode mission-sheet detail view.
 *
 * PARTIAL RECONSTRUCTION of a pending class. @c ChallengeMissionSheetView is a real @c UIView
 * subclass in the shipped binary (its selectors @c initWithFrame:sheetID: , @c refreshSheetInfo ,
 * @c setADelegate: / @c aDelegate , and @c bDownloadEnd all exist), but its implementation has not
 * been reconstructed yet. This header declares only the surface that @c ChallengeMissionPageView
 * consumes so that view compiles; the full class is still outstanding. See TYPES_PENDING.md.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeMissionSheetView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, taken from the @c initWithFrame: chain-up.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The challenge-mode mission sheet: one downloaded mission sheet's detail page.
 */
@interface ChallengeMissionSheetView : UIView

/**
 * @brief The object told about display and status events. Held weakly, untyped in the metadata
 * (@c \@,W,N); the callbacks it dispatches (@c -missionSheetDisplayEnd , @c -cubePurchase , and
 * @c -refreshStatus ) are the ones @c ChallengeMissionPageView implements.
 */
@property(nonatomic, weak, nullable) id aDelegate;

/**
 * @brief Whether the sheet's resources have finished downloading.
 * @ghidraAddress 0x9f668 (getter)
 */
@property(nonatomic, readonly) BOOL bDownloadEnd;

/**
 * @brief Builds the sheet view for one mission sheet and starts its resource download.
 * @param frame The view's frame.
 * @param sheetID The mission sheet's identifier.
 * @return The initialised view.
 */
- (instancetype)initWithFrame:(CGRect)frame sheetID:(int)sheetID;

/**
 * @brief Re-reads the stored sheet's info and refreshes the display.
 */
- (void)refreshSheetInfo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
