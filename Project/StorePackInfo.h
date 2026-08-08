/** @file
 * One purchasable pack in the store.
 *
 * Reconstructed from Ghidra program Jubeat (class StorePackInfo, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the members
 * @c StoreRecommendPackView and @c StorePackView read are declared.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A pack's identity, name, price and store flags.
 */
@interface StorePackInfo : NSObject

/**
 * @brief The pack's identifier. Four bytes in the metadata, so @c int. DECLARED ONLY.
 * @ghidraAddress 0xbe3d0
 */
@property(nonatomic, readonly) int packID;
/** @brief The pack's display name. DECLARED ONLY. @ghidraAddress 0xbe410 */
@property(nonatomic, readonly, nullable) NSString *packName;
/** @brief The pack's one-line comment. DECLARED ONLY. @ghidraAddress 0xbe430 */
@property(nonatomic, readonly, nullable) NSString *shortComment;
/** @brief Whether to show the "new" marker. DECLARED ONLY. @ghidraAddress 0xbe3e0 */
@property(nonatomic, readonly) BOOL isNew;
/** @brief Whether to show the "extend" marker. DECLARED ONLY. @ghidraAddress 0xbe3f0 */
@property(nonatomic, readonly) BOOL hasExtend;
/**
 * @brief The price, already styled for display. DECLARED ONLY.
 * @ghidraAddress 0xbd6b4
 */
@property(nonatomic, readonly, nullable) NSAttributedString *attributedPriceString;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
