/**
 * @file
 * @brief The challenge-mode mission-sheet detail view.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeMissionSheetView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, taken from the class object's superclass slot, which the linker
 * binds at load (the same external base every other @c UIView subclass in this image points at).
 *
 * **This class is unfilled scaffolding.** Its runtime metadata declares twenty-seven ivars — a
 * background plate and image, a sixteen-slot @c ChallengeMissionSheetCell array, a title, four
 * buttons, a sheet model and its info dictionary, a downloader and its indicator, a detail window
 * with its label and button, a reward-download view, and several counters and flags — yet the class
 * implements only four methods, and every one of those is compiler-generated: the synthesised
 * @c aDelegate / @c setADelegate: accessors, the @c bDownloadEnd getter, and ARC's @c .cxx_destruct
 * . Nothing anywhere in the image writes any of those ivars; only @c .cxx_destruct reads them, to
 * release them. The download-and-display machinery the ivars imply was declared, compiled, and
 * shipped without ever being filled in, in the same way as @c TimerView .
 *
 * @c ChallengeMissionPageView still allocates the class and sends it @c -initWithFrame:sheetID: ,
 * @c -setADelegate: , @c -refreshSheetInfo , and @c -bDownloadEnd (see its
 * @c -tableView:didSelectRowAtIndexPath: at 0xad9a4). Of those, only @c -setADelegate: and
 * @c -bDownloadEnd are implemented. The @c initWithFrame:sheetID: and @c refreshSheetInfo selectors
 * exist only as the caller's selector references, appearing in no method list or category anywhere
 * in the image, so they are declared below in an @c (Unimplemented) category — visible to the
 * caller, with no @c \@ghidraAddress and no body, because there is none to reconstruct.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The challenge-mode mission sheet: a declared-but-unfilled mission-sheet detail page.
 */
@interface ChallengeMissionSheetView : UIView

/**
 * @brief The object told about display and status events. Held weakly and untyped in the metadata
 * (@c \@,W,N). Nothing this class defines reads it; @c ChallengeMissionPageView sets itself here so
 * the sheet could call it back.
 * @ghidraAddress 0x9f678 (getter), 0x9f698 (setter)
 */
@property(nonatomic, weak, nullable) id aDelegate;

/**
 * @brief Whether the sheet's resources have finished downloading. The backing @c _bDownloadEnd ivar
 * is never written, so this always reports @c NO .
 * @ghidraAddress 0x9f668 (getter)
 */
@property(nonatomic, readonly) BOOL bDownloadEnd;

@end

/**
 * @brief Selectors @c ChallengeMissionPageView sends the sheet that the shipped class never
 * implements.
 *
 * These are declared so the caller compiles and are deliberately left without a body: no method
 * list or category in the binary defines either one, so there is no routine to reconstruct.
 */
@interface ChallengeMissionSheetView (Unimplemented)

/**
 * @brief The sheet's designated initialiser as its caller spells it. Not implemented in the binary.
 * @param frame The view's frame.
 * @param sheetID The mission sheet's identifier.
 * @return The initialised view.
 */
- (instancetype)initWithFrame:(CGRect)frame sheetID:(int)sheetID;

/**
 * @brief Re-reads the stored sheet's info and refreshes the display. Not implemented in the binary.
 */
- (void)refreshSheetInfo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
