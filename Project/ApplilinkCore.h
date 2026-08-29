/**
 * @file
 * @brief The KONAMI Applilink advert SDK's central core.
 *
 * @c ApplilinkCore is the Applilink SDK's stateless facade: its entire surface is class (@c +)
 * methods and the class carries no instance ivars. All mutable state lives in @c NSUserDefaults and
 * a contiguous block of file-scope statics. The core owns SDK initialisation and foreground resume,
 * the advert-screen appearance configuration (navigation-bar common appearance, device-language
 * priority, and loading-indicator tint), the store and build-toolchain flags, the SDK main window,
 * the cached UDID accessors and their keychain and pasteboard maintenance, the authentication-
 * session regeneration, the advert-delegate fan-out (including the sound and movie relays), and the
 * device-hardware information collection reported to @c AnalysisNetworkCore.
 *
 * This is Konami's applilink SDK. This build diverges from the other shipped build of the same
 * class:
 * @c initializeWithAppliId:env:resume:callback: saves the device info before anything else,
 * @c resume also closes the video view through @c ApplilinkViewManager, @c clearInitialize also
 * clears the DAU counter through @c AnalysisNetworkCore, and the SDK signature key and development
 * version differ.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkCore, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x348bd8.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkParameters.h"
#import "ApplilinkStore.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The advert-delegate callbacks the @c ApplilinkCore fan-out methods dispatch through
 * @c -respondsToSelector: .
 *
 * In the binary the delegate is an @c id conforming to the SDK's advert-view delegate protocol;
 * the selectors are gathered here so the fan-out messages type-check. Every callback is optional.
 */
@protocol ApplilinkCoreAdDelegate <NSObject>
@optional
/** @brief The advert list started. */
- (void)appListDidStart;
/**
 * @brief The advert list started, with request parameters.
 * @param appParam The parameters the request was made with.
 */
- (void)appListDidStart:(nullable ApplilinkParameters *)appParam;
/** @brief The advert list appeared. */
- (void)appListDidAppear;
/**
 * @brief The advert list appeared, with request parameters.
 * @param appParam The parameters the request was made with.
 */
- (void)appListDidAppear:(nullable ApplilinkParameters *)appParam;
/** @brief The advert list disappeared. */
- (void)appListDidDisappear;
/**
 * @brief The advert list disappeared, with request parameters.
 * @param appParam The parameters the request was made with.
 */
- (void)appListDidDisappear:(nullable ApplilinkParameters *)appParam;
/**
 * @brief The advert list failed to open.
 * @param error The failure.
 */
- (void)appListFailOpenWithError:(nullable NSError *)error;
/**
 * @brief The advert list failed to open, with request parameters.
 * @param error The failure.
 * @param appParam The parameters the request was made with.
 */
- (void)appListFailOpenWithError:(nullable NSError *)error
         withApplilinkParameters:(nullable ApplilinkParameters *)appParam;
/**
 * @brief The advert list failed to load.
 * @param error The failure.
 */
- (void)appListFailLoadWithError:(nullable NSError *)error;
/**
 * @brief The advert list failed to load, with request parameters.
 * @param error The failure.
 * @param appParam The parameters the request was made with.
 */
- (void)appListFailLoadWithError:(nullable NSError *)error
         withApplilinkParameters:(nullable ApplilinkParameters *)appParam;
/**
 * @brief The advert list failed.
 * @param error The failure.
 */
- (void)appListFailWithError:(nullable NSError *)error;
/**
 * @brief The advert list failed, with request parameters.
 * @param error The failure.
 * @param appParam The parameters the request was made with.
 */
- (void)appListFailWithError:(nullable NSError *)error
     withApplilinkParameters:(nullable ApplilinkParameters *)appParam;
/**
 * @brief The advert list failed to link.
 * @param error The failure.
 */
- (void)appListFailLinkWithError:(nullable NSError *)error;
/**
 * @brief The advert list failed to link, with request parameters.
 * @param error The failure.
 * @param appParam The parameters the request was made with.
 */
- (void)appListFailLinkWithError:(nullable NSError *)error
         withApplilinkParameters:(nullable ApplilinkParameters *)appParam;
/** @brief Advert sound use started. */
- (void)appListSoundUseStart;
/** @brief Advert sound use finished. */
- (void)appListSoundUseFinish;
/** @brief An advert movie finished. */
- (void)appListMovieFinish;
@end

/**
 * @brief The Applilink SDK's core entry point.
 */
@interface ApplilinkCore : NSObject

#pragma mark - Initialisation

/**
 * @brief Initialise the SDK core for an application and server environment.
 *
 * Saves the device info first, then guards on SDK usability, a non-nil application identifier, and
 * the in-progress latch. On the non-resume path the application and environment are persisted to
 * @c NSUserDefaults and the initialisation-status flag is set. Either path regenerates an
 * authentication session and then starts the reward core, the recommend core, and the analysis
 * post in sequence, warming the ad-status and appli-list caches at the end.
 * @param appliId The Applilink application identifier.
 * @param env The server environment name, or @c nil for the default environment.
 * @param resume @c YES when re-initialising after a foreground resume.
 * @param callback The completion block invoked with an error, or @c nil on success.
 * @ghidraAddress 0x241ff4
 */
+ (void)initializeWithAppliId:(nullable NSString *)appliId
                          env:(nullable NSString *)env
                       resume:(BOOL)resume
                     callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Resume the SDK core, closing any open store and video view and re-initialising from
 * persisted state.
 * @ghidraAddress 0x242674
 */
+ (void)resume;

/**
 * @brief Regenerate the authentication session, invoking the block once the session is valid.
 * @param block The completion block invoked with an error, or @c nil on success.
 * @ghidraAddress 0x243940
 */
+ (void)appAuthSessionRegenerateWithBlock:(nullable void (^)(NSError *_Nullable error))block;

/**
 * @brief Reset the SDK core's cached initialisation state and the DAU counter.
 * @ghidraAddress 0x243638
 */
+ (void)clearInitialize;

#pragma mark - Appearance configuration

/**
 * @brief Set whether advert screens use the common navigation-bar appearance.
 * @param navigationBarCommonAppearance @c YES to use the common appearance.
 * @ghidraAddress 0x2427b0
 */
+ (void)setNavigationBarCommonAppearance:(BOOL)navigationBarCommonAppearance;

/**
 * @brief Whether advert screens use the common navigation-bar appearance.
 * @return @c YES when the common appearance is used.
 * @ghidraAddress 0x2427c0
 */
+ (BOOL)isNavigationBarCommonAppearance;

/**
 * @brief Set whether the SDK localises using the device's preferred languages.
 * @param priorityDeviceLanguages @c YES to prioritise the device languages.
 * @ghidraAddress 0x2427d0
 */
+ (void)setPriorityDeviceLanguages:(BOOL)priorityDeviceLanguages;

/**
 * @brief Whether the SDK localises using the device's preferred languages.
 * @return @c YES when the device languages are prioritised.
 * @ghidraAddress 0x2427e0
 */
+ (BOOL)isPriorityDeviceLanguages;

/**
 * @brief Set the tint colour of the SDK's loading indicator.
 * @param indicatorColor The indicator colour.
 * @ghidraAddress 0x2427f0
 */
+ (void)setIndicatorColor:(nullable UIColor *)indicatorColor;

/**
 * @brief The tint colour of the SDK's loading indicator.
 * @return The configured indicator colour, or the white colour when unset.
 * @ghidraAddress 0x24281c
 */
+ (UIColor *)getIndicatorColor;

#pragma mark - Build and store flags

/**
 * @brief Flag the SDK as used inside the store. The selector reads @c unused, but the binary sets
 * the used-in-store flag.
 * @ghidraAddress 0x242864
 */
+ (void)unusedInStore;

/**
 * @brief Whether the SDK is currently used inside the store.
 * @return @c YES when the SDK is used inside the store.
 * @ghidraAddress 0x242878
 */
+ (BOOL)isUsedInStore;

/**
 * @brief Flag the SDK as built with the legacy pre-Xcode 6 toolchain.
 * @ghidraAddress 0x242888
 */
+ (void)buildUnderXcode6;

/**
 * @brief Whether the SDK was built with the Xcode 6 (or later) toolchain.
 * @return @c YES when not built under the legacy pre-Xcode 6 toolchain.
 * @ghidraAddress 0x24289c
 */
+ (BOOL)isBuildXcode6;

#pragma mark - Window and status

/**
 * @brief The SDK's main window, used as a fallback advert host.
 * @return The SDK main window.
 * @ghidraAddress 0x2428b4
 */
+ (nullable UIWindow *)mainWindow;

/**
 * @brief Whether the SDK's initialisation is currently in progress.
 * @return @c YES while an initialisation is running.
 * @ghidraAddress 0x242b5c
 */
+ (BOOL)isInitializingFlg;

/**
 * @brief Whether the SDK's initialisation-status flag is set.
 * @return @c YES when the SDK has finished its non-resume initialisation.
 * @ghidraAddress 0x242b6c
 */
+ (BOOL)isInitializeStatusFlg;

/**
 * @brief The Applilink application identifier stored in @c NSUserDefaults.
 * @return The stored application identifier, or @c nil.
 * @ghidraAddress 0x242b7c
 */
+ (nullable NSString *)appliId;

#pragma mark - UDID accessors

/**
 * @brief The current UDID, preferring the advertising UDID when advertising tracking is available.
 * @return The current UDID, or @c nil.
 * @ghidraAddress 0x242be8
 */
+ (nullable NSString *)currentUdid;

/**
 * @brief The cached UDID without recomputation.
 * @return The cached UDID, or @c nil.
 * @ghidraAddress 0x242c64
 */
+ (nullable NSString *)udid_cache;

/**
 * @brief The cached advertising UDID without recomputation.
 * @return The cached advertising UDID, or @c nil.
 * @ghidraAddress 0x242c74
 */
+ (nullable NSString *)ad_udid_cache;

/**
 * @brief The cached old UDID without recomputation.
 * @return The cached old UDID, or @c nil.
 * @ghidraAddress 0x242c84
 */
+ (nullable NSString *)old_udid_cache;

/**
 * @brief The UDID, computing and caching it from the pasteboard on first access.
 * @return The UDID, or @c nil.
 * @ghidraAddress 0x242c94
 */
+ (nullable NSString *)udid;

/**
 * @brief The pasteboard UDID, computing and caching it from the old pasteboard slot on first
 * access.
 * @return The pasteboard UDID, or @c nil.
 * @ghidraAddress 0x242e08
 */
+ (nullable NSString *)pasteBoard_udid;

/**
 * @brief The advertising UDID, computing and caching it on first access.
 * @return The advertising UDID, or @c nil.
 * @ghidraAddress 0x242f48
 */
+ (nullable NSString *)ad_udid;

/**
 * @brief The old UDID, computing and caching it from the keychain on first access.
 * @return The old UDID, or @c nil.
 * @ghidraAddress 0x243134
 */
+ (nullable NSString *)old_udid;

/**
 * @brief Whether either the UDID or the advertising UDID is available.
 * @return @c YES when a UDID is available.
 * @ghidraAddress 0x2431fc
 */
+ (BOOL)checkUdid;

#pragma mark - UDID maintenance

/**
 * @brief Clear the stored UDID and, outside the default environment, its keychain records.
 * @ghidraAddress 0x24326c
 */
+ (void)clearUDID;

/**
 * @brief Store the advertising UDID in the SDK core.
 * @param adUdid The advertising UDID to store.
 * @ghidraAddress 0x2433a0
 */
+ (void)setAdUdid:(nullable NSString *)adUdid;

/**
 * @brief Clear the old-UDID keychain record and, when no UDID remains, the initialisation state.
 * @ghidraAddress 0x24340c
 */
+ (void)clearKeyChainOldUDID;

/**
 * @brief Clear the advertising-UDID keychain records outside the default environment.
 * @ghidraAddress 0x243564
 */
+ (void)clearAdUDID;

/**
 * @brief Persist the cached advertising UDID to the pasteboard when a re-login is pending.
 * @ghidraAddress 0x2438b0
 */
+ (void)updatePasteBoard;

#pragma mark - Store

/**
 * @brief Present the App Store product page for an application, unless already used in the store.
 * @param appStoreId The App Store application identifier.
 * @param appParam The request parameters.
 * @param delegate The advert delegate to notify.
 * @return @c YES when the App Store page was presented.
 * @ghidraAddress 0x243768
 */
+ (BOOL)showAppStoreId:(nullable NSString *)appStoreId
              appParam:(nullable ApplilinkParameters *)appParam
              delegate:(nullable id<SdkViewDelegate>)delegate;

/**
 * @brief Close any open App Store product page.
 * @ghidraAddress 0x243860
 */
+ (void)closeAppStore;

#pragma mark - Metadata

/**
 * @brief The Applilink SDK signature key.
 * @return The signature key.
 * @ghidraAddress 0x2436f0
 */
+ (nullable NSString *)signatureKey;

/**
 * @brief The Applilink SDK development version string.
 * @return The SDK development version.
 * @ghidraAddress 0x24371c
 */
+ (nullable NSString *)versionDev;

#pragma mark - Delegate fan-out

/**
 * @brief Report that the advert did start back to a delegate.
 * @param appParam The request parameters.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x243db0
 */
+ (void)toDelegateDidStart:(nullable ApplilinkParameters *)appParam delegate:(nullable id)delegate;

/**
 * @brief Report that the advert did appear back to a delegate.
 * @param appParam The request parameters.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x243e98
 */
+ (void)toDelegateDidAppear:(nullable ApplilinkParameters *)appParam delegate:(nullable id)delegate;

/**
 * @brief Report that the advert did disappear back to a delegate.
 * @param appParam The request parameters.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x243f80
 */
+ (void)toDelegateDidDisappear:(nullable ApplilinkParameters *)appParam
                      delegate:(nullable id)delegate;

/**
 * @brief Report an open failure back to a delegate with the given error and request parameters.
 * @param error The localised failure error.
 * @param appParam The request parameters the open was attempted with.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x244068
 */
+ (void)toDelegateFailOpenWithError:(nullable NSError *)error
                           appParam:(nullable ApplilinkParameters *)appParam
                           delegate:(nullable id)delegate;

/**
 * @brief Report a load failure back to a delegate with the given error and request parameters.
 * @param error The localised failure error.
 * @param appParam The request parameters the load was attempted with.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x24419c
 */
+ (void)toDelegateFailLoadWithError:(nullable NSError *)error
                           appParam:(nullable ApplilinkParameters *)appParam
                           delegate:(nullable id)delegate;

/**
 * @brief Report a generic failure back to a delegate with the given error and request parameters.
 * @param error The localised failure error.
 * @param appParam The request parameters the operation was attempted with.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x2442d0
 */
+ (void)toDelegateFailWithError:(nullable NSError *)error
                       appParam:(nullable ApplilinkParameters *)appParam
                       delegate:(nullable id)delegate;

/**
 * @brief Report a link failure back to a delegate with the given error and request parameters.
 * @param error The localised failure error.
 * @param appParam The request parameters the link was attempted with.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x2443d8
 */
+ (void)toDelegateFailLinkWithError:(nullable NSError *)error
                           appParam:(nullable ApplilinkParameters *)appParam
                           delegate:(nullable id)delegate;

/**
 * @brief Report the start of advert sound use back to a delegate, latching the sound and movie
 * flags.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x2444e0
 */
+ (void)toDelegateSoundUseStart:(nullable id)delegate;

/**
 * @brief Report the finish of advert sound use back to a delegate, once sound use has started.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x244554
 */
+ (void)toDelegateSoundUseFinish:(nullable id)delegate;

/**
 * @brief Report the finish of an advert movie back to a delegate, once a movie is playing.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x2445d8
 */
+ (void)toDelegateMovieFinish:(nullable id)delegate;

#pragma mark - Device information

/**
 * @brief Save the device info and post it to the analytics endpoint.
 * @ghidraAddress 0x24465c
 */
+ (void)collectDeviceInfoCore;

/**
 * @brief Collect the OpenGL, memory, screen, and CPU details and persist them to @c NSUserDefaults.
 * @ghidraAddress 0x2446a4
 */
+ (void)saveDeviceInfo;

/**
 * @brief The persisted device-information dictionary.
 * @return A dictionary of the saved OpenGL, memory, screen, and CPU details.
 * @ghidraAddress 0x244c2c
 */
+ (nullable NSDictionary *)getDeviceInfo;

/**
 * @brief A hardware @c sysctl integer for a @c CTL_HW selector.
 * @param info The @c CTL_HW second-level selector (the @c HW_* constant).
 * @return The queried integer value.
 * @ghidraAddress 0x244f2c
 */
+ (int)getSysInfo:(int)info;

/**
 * @brief The CPU frequency in hertz, from the @c HW_CPU_FREQ @c sysctl.
 * @return The CPU frequency.
 * @ghidraAddress 0x244f9c
 */
+ (int)getCpuFrequency;

/**
 * @brief The number of CPUs, from the @c HW_NCPU @c sysctl.
 * @return The CPU count.
 * @ghidraAddress 0x244fe8
 */
+ (int)getNumCpus;

/**
 * @brief The physical memory size in bytes, from the @c HW_PHYSMEM @c sysctl.
 * @return The physical memory size, or @c -1 on failure.
 * @ghidraAddress 0x244ffc
 */
+ (NSInteger)hwPhysMem;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
