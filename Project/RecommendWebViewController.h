/**
 * @file
 * @brief The applilink recommendation web view controller.
 *
 * Reconstructed from Ghidra program Jubeat (class RecommendWebViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. The class object
 * is at 0x351cb8. It subclasses @c RewardWebViewController (not yet reconstructed; see
 * TYPES_PENDING.md) and thins its request routing onto @c RecommendCore.
 */

#import <UIKit/UIKit.h>

#import "RewardWebViewController.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A reward web view controller specialised for applilink recommendation content.
 */
@interface RecommendWebViewController : RewardWebViewController

/**
 * @brief Routes a request to a recommendation action code via @c RecommendCore.
 * @param request The request.
 * @return The action code.
 * @ghidraAddress 0x22b8c4
 */
- (int)redirectWithRequest:(nullable NSURLRequest *)request;

/**
 * @brief Shows the recommendation video view for a query via @c RecommendCore.
 * @param query The video query.
 * @ghidraAddress 0x22b948
 */
- (void)showVideoViewWithQuery:(nullable id)query;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
