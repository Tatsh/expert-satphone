/**
 * @file
 * The in-app-purchase view for buying cubes (the in-game currency).
 *
 * Reconstructed from Ghidra program Jubeat (class CubePurchaseView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView , from the @c objc_msgSendSuper2 @c initWithFrame: at 0x1c04c4 that
 * targets @c _OBJC_CLASS_$_UIView .
 *
 * The view lists cube products in a @c CubePurchaseListView , queries StoreKit through an
 * @c SKProductsRequest , runs the purchase through @c PurchaseManager , validates the result with
 * the server through a @c SessionDownloader , and shows policy and message overlays with a
 * @c MessageTextView . Its @c aDelegate (the challenge-mode root view in the shipped tree) is sent
 * @c closeCubePurchase , @c showPurchaseDialog: , @c hidePurchaseDialog , and @c refreshStatus ;
 * the binary dispatches these dynamically over a bare @c id ivar, modelled here as the
 * @c CubePurchaseViewDelegate protocol.
 */

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "CubePurchaseListView.h"
#import "Downloader.h"
#import "MessageTextView.h"
#import "PurchaseManager.h"

@class MessageTextView;
@class SessionDownloader;

NS_ASSUME_NONNULL_BEGIN

/**
 * What a @c CubePurchaseView tells its owner (the challenge-mode root view in the shipped
 * tree). The binary types the @c aDelegate ivar as a bare @c id and dispatches these dynamically;
 * the protocol names that implicit contract so the sends are typed.
 */
@protocol CubePurchaseViewDelegate <NSObject>
@optional
/** Dismisses the cube-purchase menu. */
- (void)closeCubePurchase;
/**
 * Shows the modal processing dialog with a message.
 * @param message The message to show in the dialog.
 */
- (void)showPurchaseDialog:(nonnull NSString *)message;
/** Hides the modal processing dialog. */
- (void)hidePurchaseDialog;
/** Refreshes the owner's cube-count and related status. */
- (void)refreshStatus;
@end

/**
 * A modal view that sells cubes: a scrollable product list backed by StoreKit, an age /
 * spend-limit gate, and SPTL and cube-policy overlays.
 */
@interface CubePurchaseView : UIView <AlertViewManagerDelegate,
                                      CubePurchaseListViewDelegate,
                                      DownloaderDelegate,
                                      PurchaseManagerDelegate,
                                      SKProductsRequestDelegate,
                                      MessageTextViewDelegate>

/**
 * Builds the whole view: the background plate, the close, SPTL, and cube-policy buttons, and
 * the (initially transparent) product list, then kicks off a signed fetch of the cube product list.
 * @param frame The view's frame.
 * @return The initialised view.
 * @ghidraAddress 0x1c04c4
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Close-button action: plays the cancel sound, cancels any live products request, and tells
 * the delegate the purchase menu closed.
 * @param sender The close button.
 * @ghidraAddress 0x1c0d18
 */
- (void)closePurchaseMenu:(nullable id)sender;

/**
 * SPTL-button action: opens the specified-commercial-transactions (TOKUSHO) page in Safari.
 * @param sender The SPTL button.
 * @ghidraAddress 0x1c0dc8
 */
- (void)tapSptl:(nullable id)sender;

/**
 * Cube-policy-button action: opens the in-game-currency policy in a @c MessageTextView
 * overlay and disables interaction on the root view behind it.
 * @param sender The cube-policy button.
 * @ghidraAddress 0x1c0e48
 */
- (void)tapCubePolicy:(nullable id)sender;

/**
 * Removes the policy / message overlay and re-enables interaction on the root view.
 * @param sender The overlay reporting that it closed.
 * @ghidraAddress 0x1c1064
 */
- (void)closeMessage:(nullable id)sender;

/**
 * Enforces the monthly-spend limit for the buyer's age band before a purchase.
 *
 * Adds the product's price (only when it is priced in @c JPY ) to the running total, compares it to
 * the limit for the stored @c PrefPurchaseLimitType , and, when the limit would be exceeded, shows
 * either the age-confirmation alert (when no age has been set) or the limit-exceeded alert.
 * @param product The product about to be bought.
 * @return @c YES when the purchase must be blocked, @c NO when it may proceed.
 * @ghidraAddress 0x1c10bc
 */
- (BOOL)checkAttainLimitPurchase:(nullable SKProduct *)product;

/**
 * Begins the StoreKit purchase of a product and shows the "processing" dialog.
 * @param product The product to buy.
 * @ghidraAddress 0x1c1438
 */
- (void)purchaseStart:(nullable SKProduct *)product;

/**
 * Product-list delegate callback: records the chosen row and, if the spend limit allows,
 * begins its purchase.
 * @param indexPath The selected row.
 * @ghidraAddress 0x1c1550
 */
- (void)selectListCell:(nullable NSIndexPath *)indexPath;

/**
 * Handles a completed signed download.
 *
 * The tag-0 response is the cube product list: it updates the running total, builds a
 * @c CubePurchaseInfo per item into @c cubeList , and fires an @c SKProductsRequest for the product
 * identifiers. The tag-1 response is the age-registration result: on success it stores the
 * spend-limit type. A stale-client status shows the server-error alert.
 * @param downloader The finished request.
 * @ghidraAddress 0x1c1654
 */
- (void)downloaderFinished:(nullable id)downloader;

/**
 * Handles a failed signed download: the tag-1 age request shows the server-error alert, the
 * tag-0 list request shows its failure text in the error label.
 * @param downloader The failed request.
 * @ghidraAddress 0x1c1dd0
 */
- (void)downloaderError:(nullable id)downloader;

/**
 * Alert delegate callback: closes the view on a completed purchase (tag 1), registers the
 * chosen age band (tag 2), or closes the challenge-mode session-error overlay (tag 9999).
 * @param info The alert result carrying @c Tag and @c btnMessage .
 * @ghidraAddress 0x1c1f78
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

/**
 * Purchase-manager callback for a successful purchase: ends interaction ignoring, shows the
 * completion alert, and asks the delegate to refresh its status.
 * @param productID The purchased product identifier.
 * @ghidraAddress 0x1c2324
 */
- (void)purchaseSucceeded:(nullable NSString *)productID;

/**
 * Purchase-manager callback for a failed purchase: ends interaction ignoring and shows the
 * server-error alert.
 * @param productID The product identifier that failed.
 * @param error The StoreKit error.
 * @ghidraAddress 0x1c24d8
 */
- (void)purchaseFailed:(nullable NSString *)productID error:(nullable NSError *)error;

/**
 * @c SKProductsRequestDelegate callback: matches the returned products to the pending list,
 * populates the product list view, and fades it in. An empty response shows the no-items text.
 * @param request The products request.
 * @param response The StoreKit response.
 * @ghidraAddress 0x1c2684
 */
- (void)productsRequest:(nullable SKProductsRequest *)request
     didReceiveResponse:(nullable SKProductsResponse *)response;

/**
 * @c SKRequestDelegate callback: drops the finished products request.
 * @param request The request that finished.
 * @ghidraAddress 0x1c2b40
 */
- (void)requestDidFinish:(nullable SKRequest *)request;

/**
 * @c SKRequestDelegate callback: drops the failed products request and shows the no-items
 * text.
 * @param request The request that failed.
 * @param error The StoreKit error.
 * @ghidraAddress 0x1c2b58
 */
- (void)request:(nullable SKRequest *)request didFailWithError:(nullable NSError *)error;

/**
 * The delegate told when the purchase menu closes and when the purchase dialog should be
 * shown, hidden, or its status refreshed. Held weakly.
 * @ghidraAddress 0x1c2ba4 (getter), 0x1c2bc4 (setter)
 */
@property(nonatomic, weak, nullable) id<CubePurchaseViewDelegate> aDelegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
