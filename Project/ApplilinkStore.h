/** @file
 * The applilink SDK's App Store product-page facade singleton.
 *
 * @c ApplilinkStore is created once, presents the store through an @c ApplilinkViewController
 * (which owns the @c SKStoreProductViewController), and is itself the @c SdkViewDelegate of that
 * view controller: when the view controller reports the open, close, closed, or load-failure
 * notices, the store forwards them to the caller's own @c sdkDelegate.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base. The class object is at 0x3523e8.
 */

#import <Foundation/Foundation.h>

@class ApplilinkParameters;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The delegate the SDK's advert, App Store, and web views all report back through. The
 * binary's single @c SdkViewDelegate protocol (protocol_t at 0x353fa0) declares all sixteen of
 * these methods; every one is optional and the SDK guards each dispatch with
 * @c -respondsToSelector: . Both the no-argument advert @c closeNotice and the web view's
 * @c closeNotice: are members.
 */
@protocol SdkViewDelegate <NSObject>
@optional
/** @brief The advert started. */
- (void)startedNotice;
/** @brief The advert opened. */
- (void)openedNotice;
/** @brief The advert closed. */
- (void)closeNotice;
/** @brief An @c ApplilinkWebView "close" link was followed. */
- (void)closeNotice:(nonnull id)webView;
/** @brief An @c ApplilinkWebView finished loading and is ready. */
- (void)viewReady:(nonnull id)webView;
/** @brief An @c ApplilinkWebView "repeat" link was followed. */
- (void)repeatNotice:(nonnull id)webView;
/** @brief An @c ApplilinkWebView "store" link was followed. */
- (void)storeNotice:(nonnull id)webView;
/** @brief An @c ApplilinkWebView load error occurred. */
- (void)linkErrorNotice:(nonnull id)webView error:(nonnull NSError *)error;
/** @brief An advert open failed. */
- (void)failOpenNoticeWithError:(nullable NSError *)error;
/** @brief An advert link failed. */
- (void)failLinkNoticeWithError:(nullable NSError *)error;
/** @brief The delegate cancelled an advert open. */
- (void)openCancelWithError:(nullable NSError *)error;
/** @brief The App Store product page opened. */
- (void)appStoreOpenedNoticeWithAppParam:(nullable ApplilinkParameters *)appParam;
/** @brief The App Store product page is about to close. */
- (void)appStoreCloseNoticeWithAppParam:(nullable ApplilinkParameters *)appParam;
/** @brief The App Store product page closed. */
- (void)appStoreClosedNoticeWithAppParam:(nullable ApplilinkParameters *)appParam;
/** @brief An App Store product-page load failed. */
- (void)appStoreFailLoadNoticeWithError:(nullable NSError *)error
                               appParam:(nullable ApplilinkParameters *)appParam;
/** @brief The App Store product page transitioned. */
- (void)appStoreTransitionNoticeWithAppParam:(nullable ApplilinkParameters *)appParam;
@end

/**
 * @brief The SDK's App Store product-page facade singleton.
 */
@interface ApplilinkStore : NSObject <SdkViewDelegate>

/** @brief The caller's delegate, told when the store opens/closes. Held weakly.
 *  @ghidraAddress 0x250c88 (getter), 0x250ca8 (setter) */
@property(weak, nonatomic, nullable) id<SdkViewDelegate> sdkDelegate;
/** @brief The advert request parameters for the presented store.
 *  @ghidraAddress 0x250cbc (getter), 0x250ccc (setter) */
@property(copy, nonatomic, nullable) ApplilinkParameters *applilinkParams;

/**
 * @brief The lazily-created shared singleton.
 * @return The shared @c ApplilinkStore .
 * @ghidraAddress 0x2505b8
 */
+ (instancetype)sharedInstance;

/**
 * @brief Presents the App Store product page for a product identifier.
 * @param appStoreId The App Store product identifier.
 * @param appParam The advert request parameters.
 * @param delegate The delegate told of store notices.
 * @return @c YES when the OS version supports the store product page.
 * @ghidraAddress 0x250754
 */
- (BOOL)showSKStore:(nullable NSString *)appStoreId
           appParam:(nullable ApplilinkParameters *)appParam
           delegate:(nullable id<SdkViewDelegate>)delegate;

/**
 * @brief Dismisses the presented App Store product page.
 * @ghidraAddress 0x2508e8
 */
- (void)closeSKStore;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
