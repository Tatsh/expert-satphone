/**
 * @file
 * @brief The scratch completion celebration view.
 *
 * Reconstructed from Ghidra program Jubeat (class ScratchCompleteView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, from the dyld bind at the class object's superclass slot
 * (0x34fcd8 + 8) resolved to _OBJC_CLASS_$_UIView.
 *
 * The class is complete: all three hand-written members are recovered — verified against the
 * disassembly via curl on port 8089, not just the decompile.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ScratchCompleteView;
@class ScratchInfo;

/**
 * @brief Delegate for the scratch completion view.
 */
@protocol ScratchCompleteViewDelegate <NSObject>
@optional
/**
 * @brief The completion view closed.
 * @param view The view that closed.
 */
- (void)scratchCompleteViewDidClose:(ScratchCompleteView *)view;
@end

/**
 * @brief The view shown when a scratch is completed.
 */
@interface ScratchCompleteView : UIView

/**
 * @brief The delegate. The binary names the accessor pair @c aDelegate / @c setADelegate: over the
 *        @c _aDelegate ivar.
 * @ghidraAddress 0x34b350
 */
@property(nonatomic, weak, nullable) id<ScratchCompleteViewDelegate> aDelegate;

/**
 * @brief Builds the view for a completed scratch.
 * @param frame The frame.
 * @param musicInfo The tune that was scratched (provides musicID, musicName, artistName).
 * @return The initialised view.
 * @ghidraAddress 0x16dd6c
 */
- (instancetype)initWithFrame:(CGRect)frame musicInfo:(nullable ScratchInfo *)musicInfo;

/**
 * @brief Starts the reveal animation.
 * @ghidraAddress 0x16e730
 */
- (void)animationStart;

/**
 * @brief Closes the view with a fade-out.
 * @ghidraAddress 0x16f244
 */
- (void)closeView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
