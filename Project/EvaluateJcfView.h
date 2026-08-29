/**
 * @file
 * @brief The jubeatLab chart-evaluation view.
 *
 * Reconstructed from Ghidra program Jubeat (class EvaluateJcfView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The view rates a downloaded custom chart: a gradient-backed panel carrying a level slider (0–9),
 * ten numbered tick labels, a level-commit button, and a cancel button. It talks to the jubeatLab
 * server through @c jubeatLabAccess for the good-job and level votes, and reports closing back to a
 * weak delegate through @c -closeEvaluate: .
 *
 * The superclass is @c UIView . The class overrides @c +layerClass to back itself with a
 * @c CAGradientLayer .
 */

#import <UIKit/UIKit.h>

@class jubeatLabAccess;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What an @c EvaluateJcfView tells its owner. The delegate is a bare weak @c id the binary
 * messages dynamically behind @c -respondsToSelector: ; this protocol only documents the selector.
 */
@protocol EvaluateJcfViewDelegate <NSObject>
@optional
/**
 * @brief The evaluation panel finished and should be dismissed.
 * @param sender The panel sending the message.
 */
- (void)closeEvaluate:(nullable id)sender;
@end

/**
 * @brief The panel that lets the player rate a downloaded custom chart.
 */
@interface EvaluateJcfView : UIView

/**
 * @brief The layer class used to back the view.
 * @return @c CAGradientLayer .
 * @ghidraAddress 0x1fac5c
 */
+ (Class)layerClass;

/**
 * @brief Builds and configures a stray @c StoreButton .
 *
 * The button is allocated, coloured, and given a corner radius and bold font, but is never stored
 * nor added to any view — the binary discards it. Reconstructed faithfully.
 * @param sender Unused; present to match the binary's selector.
 * @ghidraAddress 0x1fac70
 */
- (void)createStoreBtn:(nullable id)sender;

/**
 * @brief Builds the evaluation panel for a downloaded chart.
 * @param seqID The sequence identifier of the chart being rated.
 * @param defaultLevel The level the slider starts at.
 * @param delegate The object told when the panel closes; held weakly.
 * @param tuneID The music (tune) identifier of the chart.
 * @return The initialised view.
 * @ghidraAddress 0x1fada8
 */
- (instancetype)initWithID:(nullable NSString *)seqID
              defaultLevel:(int)defaultLevel
                  delegate:(nullable id)delegate
                    tuneID:(int)tuneID;

/**
 * @brief Cancel-button handler: closes the panel.
 * @param sender The cancel button.
 * @ghidraAddress 0x1fba60
 */
- (void)pushCancel:(nullable id)sender;

/**
 * @brief Good-job-button handler: POSTs a good-job vote and dims the button.
 * @param sender The good-job button.
 * @ghidraAddress 0x1fba6c
 */
- (void)pushGoodJob:(nullable id)sender;

/**
 * @brief Level-commit-button handler: POSTs the chosen level and disables the button.
 * @param sender The level-commit button.
 * @ghidraAddress 0x1fbb20
 */
- (void)pushLevelCommit:(nullable id)sender;

/**
 * @brief Slider handler: snaps the slider to the nearest whole level and applies it.
 * @param sender The level slider.
 * @ghidraAddress 0x1fbbd4
 */
- (void)sliderChange:(nullable id)sender;

/**
 * @brief Applies a chosen level: records it, moves the slider, and updates the title.
 * @param level The chosen level.
 * @ghidraAddress 0x1fbc90
 */
- (void)levelChange:(int)level;

/**
 * @brief Reports the panel closing to the delegate.
 * @ghidraAddress 0x1fbd34
 */
- (void)evaluateEnd;

/**
 * @brief jubeatLab access failure callback: drops the matching request.
 * @param access The failed request.
 * @ghidraAddress 0x1fbdd8
 */
- (void)jubeatLabAccessError:(nullable jubeatLabAccess *)access;

/**
 * @brief jubeatLab access success callback: records the vote in the editor info and closes.
 * @param access The finished request.
 * @ghidraAddress 0x1fbe38
 */
- (void)jubeatLabAccessFinished:(nullable jubeatLabAccess *)access;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
