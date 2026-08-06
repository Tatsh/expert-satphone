/** @file
 * Server endpoint construction.
 *
 * Reconstructed from Ghidra program Jubeat (class ScratchUtil, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. The class object is at 0x3482a0.
 * Only the one member reached so far is declared.
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
 * The body at 0x180524 is straight-line code that formats a string and wraps it with
 * @c -[NSURL initWithString:]; the only path component it embeds is "/agx/api". DECLARED ONLY.
 * @ghidraAddress 0x180524
 */
@property(class, nonatomic, readonly) NSURL *pushNotificationResponseURL;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
