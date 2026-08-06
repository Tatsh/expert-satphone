/** @file
 * The navigation wrapper around the in-app notification page.
 *
 * Reconstructed from Ghidra program Jubeat (class NotificationPageNavController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UINavigationController, from the dyld bind at the class object's superclass
 * slot (0x34ffb0).
 *
 * RECONSTRUCTION STATE: five of six members written. @c -init: is declared but not reconstructed;
 * see RECONSTRUCTION_STATUS.md.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c NotificationPageNavController tells its owner.
 *
 * The delegate ivar is untyped in the metadata, so the protocol is inferred from the one selector
 * the class sends and the dispatch goes through @c -respondsToSelector: .
 */
@protocol NotificationPageNavControllerDelegate <NSObject>
@optional
/**
 * @brief Sent when the notification page is dismissed.
 * @param controller The controller that closed.
 * @param seqIndex Which sequence step it closed from. Always the string @c none here.
 */
- (void)customWebViewClose:(id)controller seqIndex:(id)seqIndex;
@end

/**
 * @brief Presents the notification page and records that it has been seen.
 */
@interface NotificationPageNavController : UINavigationController

/**
 * @brief Builds the controller around a notification page.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param arg The page to present.
 * @return The initialised controller.
 * @ghidraAddress 0x182b8c
 */
- (instancetype)init:(nullable id)arg;

/**
 * @brief Dismisses the page, marks the notification as read, and tells the delegate.
 *
 * The read mark is the app delegate's own notification time written straight into user defaults;
 * the pending page is then cleared by handing the delegate two nils.
 *
 * @param sender The control that closed the page. Unused.
 * @ghidraAddress 0x182fcc
 */
- (void)pushClose:(id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
