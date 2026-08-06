/** @file
 * Server endpoint construction.
 *
 * Reconstructed from Ghidra program Jubeat (class ScratchUtil, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: only the one member reached so far is recovered. The class object is at
 * 0x3482a0 and has a sibling @c +pushNotificationIDSendURL at 0x180450 that nothing reconstructed
 * reaches yet, so it is not declared.
 *
 * Class properties and bare class methods compile to the same single class method, so declaring
 * @c pushNotificationResponseURL as a class property below claims nothing the binary contradicts.
 * That is unlike an instance property, whose accessor pair is observable — see the note in
 * TYPES_PENDING.md.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Builds the URLs the application talks to.
 */
@interface ScratchUtil : NSObject

/**
 * @brief The endpoint a push-notification receipt is reported to.
 *
 * Built in two formatting steps from four separate literals, and with no branch anywhere in the
 * method — so the endpoint is fixed, with no staging or debug host to select between.
 * @ghidraAddress 0x180524
 */
@property(class, nonatomic, readonly) NSURL *pushNotificationResponseURL;

/**
 * @brief The endpoint the current event type is fetched from.
 *
 * DECLARED ONLY — the body has not been reconstructed yet. Fetched during
 * @c -[LogoViewController loadView] , so the answer is in hand by the time the splash ends.
 *
 * @return The event-type URL.
 * @ghidraAddress 0x1829e4
 */
+ (nullable NSURL *)getEventTypeURL;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
