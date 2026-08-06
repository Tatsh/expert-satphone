/** @file
 * The applilink advertising SDK's network entry points.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkNetwork, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the two members
 * @c +[JubeatAppDelegate initialize] reaches are declared.
 *
 * This is Konami's applilink SDK, the same one REFLEC BEAT plus embeds. Its full reconstruction
 * already exists in the sibling ../rbplus-src tree, where @c +initializeWithAppliId:env:callback:
 * sits at 0x248464 and @c +setUserId: at 0x2484f0. The signatures below are taken from there and
 * agree with this binary's call sites; the addresses differ because the two are different images.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The SDK's network front end.
 */
@interface ApplilinkNetwork : NSObject

/**
 * @brief Brings the SDK up.
 *
 * @c +[JubeatAppDelegate initialize] passes @c "3" and @c "0". DECLARED ONLY.
 *
 * @param appliId The applilink application identifier.
 * @param env The server environment name, or nil for production.
 * @param callback Invoked with an error, or nil on success.
 */
+ (void)initializeWithAppliId:(nullable NSString *)appliId
                          env:(nullable NSString *)env
                     callback:(nullable void (^)(NSError *_Nullable error))callback;
/**
 * @brief Sets the applilink user identifier. DECLARED ONLY.
 * @param userId The user identifier, or nil to clear it.
 */
+ (void)setUserId:(nullable NSString *)userId;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
