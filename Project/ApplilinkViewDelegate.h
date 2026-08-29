/**
 * @file
 * The applilink advert-view delegate protocol.
 *
 * The applilink SDK dispatches every advert lifecycle callback through
 * @c +[ApplilinkCore toDelegate...:delegate:], each guarded by a @c -respondsToSelector: test, so
 * every method is optional. The selectors and their argument shapes are recovered from those
 * dispatchers (see @c ApplilinkCore.m): the plain lifecycle callbacks come in a no-argument form
 * and a form taking the @c ApplilinkParameters , and each failure callback comes in an error-only
 * form and a form that also carries the @c ApplilinkParameters .
 */

#import <Foundation/Foundation.h>

@class ApplilinkParameters;

NS_ASSUME_NONNULL_BEGIN

/**
 * The advert-view lifecycle callbacks the applilink SDK reports to a host.
 *
 * Every method is optional; the SDK guards each dispatch with @c -respondsToSelector: .
 */
@protocol ApplilinkViewDelegate <NSObject>

@optional

/** The advert flow started. */
- (void)appListDidStart;
/**
 * The advert flow started, with the originating parameters.
 * @param appParam The parameters the advert was opened with.
 */
- (void)appListDidStart:(nullable ApplilinkParameters *)appParam;
/** The advert became visible. */
- (void)appListDidAppear;
/**
 * The advert became visible, with the originating parameters.
 * @param appParam The parameters the advert was opened with.
 */
- (void)appListDidAppear:(nullable ApplilinkParameters *)appParam;
/** The advert was dismissed. */
- (void)appListDidDisappear;
/**
 * The advert was dismissed, with the originating parameters.
 * @param appParam The parameters the advert was opened with.
 */
- (void)appListDidDisappear:(nullable ApplilinkParameters *)appParam;

/**
 * The advert failed to open.
 * @param error The failure.
 */
- (void)appListFailOpenWithError:(nullable NSError *)error;
/**
 * The advert failed to open, with the originating parameters.
 * @param error The failure.
 * @param appParam The parameters the advert was opened with.
 */
- (void)appListFailOpenWithError:(nullable NSError *)error
         withApplilinkParameters:(nullable ApplilinkParameters *)appParam;
/**
 * The advert failed to load.
 * @param error The failure.
 */
- (void)appListFailLoadWithError:(nullable NSError *)error;
/**
 * The advert failed to load, with the originating parameters.
 * @param error The failure.
 * @param appParam The parameters the advert was opened with.
 */
- (void)appListFailLoadWithError:(nullable NSError *)error
         withApplilinkParameters:(nullable ApplilinkParameters *)appParam;
/**
 * The advert failed.
 * @param error The failure.
 */
- (void)appListFailWithError:(nullable NSError *)error;
/**
 * The advert failed, with the originating parameters.
 * @param error The failure.
 * @param appParam The parameters the advert was opened with.
 */
- (void)appListFailWithError:(nullable NSError *)error
     withApplilinkParameters:(nullable ApplilinkParameters *)appParam;
/**
 * The advert link failed.
 * @param error The failure.
 */
- (void)appListFailLinkWithError:(nullable NSError *)error;
/**
 * The advert link failed, with the originating parameters.
 * @param error The failure.
 * @param appParam The parameters the advert was opened with.
 */
- (void)appListFailLinkWithError:(nullable NSError *)error
         withApplilinkParameters:(nullable ApplilinkParameters *)appParam;

/** The advert's sound playback started. */
- (void)appListSoundUseStart;
/** The advert's sound playback finished. */
- (void)appListSoundUseFinish;
/** The advert's movie finished. */
- (void)appListMovieFinish;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
