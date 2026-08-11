/** @file
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
 * @brief The advert-view lifecycle callbacks the applilink SDK reports to a host.
 *
 * Every method is optional; the SDK guards each dispatch with @c -respondsToSelector: .
 */
@protocol ApplilinkViewDelegate <NSObject>

@optional

/** @brief The advert flow started. */
- (void)appListDidStart;
/** @brief The advert flow started, with the originating parameters. */
- (void)appListDidStart:(nullable ApplilinkParameters *)appParam;
/** @brief The advert became visible. */
- (void)appListDidAppear;
/** @brief The advert became visible, with the originating parameters. */
- (void)appListDidAppear:(nullable ApplilinkParameters *)appParam;
/** @brief The advert was dismissed. */
- (void)appListDidDisappear;
/** @brief The advert was dismissed, with the originating parameters. */
- (void)appListDidDisappear:(nullable ApplilinkParameters *)appParam;

/** @brief The advert failed to open. */
- (void)appListFailOpenWithError:(nullable NSError *)error;
/** @brief The advert failed to open, with the originating parameters. */
- (void)appListFailOpenWithError:(nullable NSError *)error
         withApplilinkParameters:(nullable ApplilinkParameters *)appParam;
/** @brief The advert failed to load. */
- (void)appListFailLoadWithError:(nullable NSError *)error;
/** @brief The advert failed to load, with the originating parameters. */
- (void)appListFailLoadWithError:(nullable NSError *)error
         withApplilinkParameters:(nullable ApplilinkParameters *)appParam;
/** @brief The advert failed. */
- (void)appListFailWithError:(nullable NSError *)error;
/** @brief The advert failed, with the originating parameters. */
- (void)appListFailWithError:(nullable NSError *)error
     withApplilinkParameters:(nullable ApplilinkParameters *)appParam;
/** @brief The advert link failed. */
- (void)appListFailLinkWithError:(nullable NSError *)error;
/** @brief The advert link failed, with the originating parameters. */
- (void)appListFailLinkWithError:(nullable NSError *)error
         withApplilinkParameters:(nullable ApplilinkParameters *)appParam;

/** @brief The advert's sound playback started. */
- (void)appListSoundUseStart;
/** @brief The advert's sound playback finished. */
- (void)appListSoundUseFinish;
/** @brief The advert's movie finished. */
- (void)appListMovieFinish;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
