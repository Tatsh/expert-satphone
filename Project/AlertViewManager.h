/**
 * @file
 * A shared alert presenter that hides the UIAlertController/UIAlertView split behind one
 * API.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * The optional delegate of @c AlertViewManager.
 *
 * Both methods are dispatched with @c performSelector:withObject: after a @c respondsToSelector:
 * guard, so neither is required.
 */
@protocol AlertViewManagerDelegate <NSObject>
@optional
/**
 * Sent when the user taps a button in an alert built with @c makeAlert:.
 *
 * @param info A dictionary carrying @c "Tag" (the alert tag) and @c "btnMessage" (the tapped
 *             button index), and for a text-entry alert also @c "Message" (the field's text).
 */
- (void)alertSelect:(nonnull NSDictionary *)info;
/**
 * Sent when a @c UIAlertController -based alert finishes dismissing.
 *
 * @param info A dictionary carrying @c "Tag" (the alert tag).
 */
- (void)alertClose:(nonnull NSDictionary *)info;
@end

/**
 * The process-wide alert manager.
 *
 * It presents either a @c UIAlertController (when the class is available at runtime) or a
 * @c UIAlertView, exposing a single construction API for both.
 */
@interface AlertViewManager : NSObject <UIAlertViewDelegate>

/**
 * The shared singleton, created once on first access.
 *
 * @return The shared @c AlertViewManager.
 * @ghidraAddress 0xa89b4
 */
+ (instancetype)sharedManager;

/**
 * Dismisses the currently presented alert, if any.
 *
 * @ghidraAddress 0xa8b08
 */
- (void)closeAlert;

/**
 * Builds and optionally presents an alert.
 *
 * @param type The alert type; @c 1 requests a single plain-text input field.
 * @param delegate The delegate notified of button taps and close events; held weakly.
 * @param tag An identifier echoed back to the delegate.
 * @param title The alert title; an empty title is substituted when @c nil.
 * @param msg The alert message.
 * @param cancelBtnText The title of the cancel button (index @c 0).
 * @param otherButtonTitles The titles of the remaining buttons, in order.
 * @param show Whether to present the alert immediately.
 * @param viewController The controller to present a @c UIAlertController from; when @c nil the
 *                       application's root view controller is used.
 * @ghidraAddress 0xa8cfc
 */
- (void)makeAlert:(int)type
          delegate:(nullable id<AlertViewManagerDelegate>)delegate
               tag:(int)tag
             title:(nullable NSString *)title
               msg:(nullable NSString *)msg
            cancel:(nullable NSString *)cancelBtnText
           btnText:(nullable NSArray<NSString *> *)otherButtonTitles
              show:(BOOL)show
    viewController:(nullable UIViewController *)viewController;

/**
 * Builds and optionally presents an alert, presenting from the application's root view controller.
 *
 * @param type The alert type; @c 1 requests a single plain-text input field.
 * @param delegate The delegate notified of button taps and close events; held weakly.
 * @param tag An identifier echoed back to the delegate.
 * @param title The alert title; an empty title is substituted when @c nil.
 * @param msg The alert message.
 * @param cancelBtnText The title of the cancel button (index @c 0).
 * @param otherButtonTitles The titles of the remaining buttons, in order.
 * @param show Whether to present the alert immediately.
 * @ghidraAddress 0xa956c
 */
- (void)makeAlert:(int)type
         delegate:(nullable id<AlertViewManagerDelegate>)delegate
              tag:(int)tag
            title:(nullable NSString *)title
              msg:(nullable NSString *)msg
           cancel:(nullable NSString *)cancelBtnText
          btnText:(nullable NSArray<NSString *> *)otherButtonTitles
             show:(BOOL)show;

/**
 * Presents the localised "App update is required." alert, whose only button opens the App Store.
 *
 * @ghidraAddress 0xa964c
 */
- (void)showUpdateAlert;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
