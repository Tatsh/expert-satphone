/** @file
 * The applilink recommend SDK's advert-video host controller.
 *
 * @c ApplilinkVideoController is the SDK @c UIViewController that hosts an advert movie: it parses
 * the advert query into its many string parameters, builds a full-screen @c AppliView surface with
 * a @c VideoView player inside it, shows an @c ApplilinkIndicator while the movie loads, and on
 * the movie ending swaps in an @c ApplilinkWebView "end card". It is both the @c VideoView 's and
 * the @c ApplilinkWebView 's @c SdkViewDelegate, and it relays the movie and store lifecycle back
 * to the applilink core (analysis posts, delegate notices) and to its own @c sdkDelegate . The
 * @c ApplilinkViewManager owns and presents it.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base. This is a closed Konami applilink SDK class, recovered from
 * the jubeat binary alone.
 *
 * The @c posterUrlRect ivar/property name is the binary's own (the "poster_url_rect" query key);
 * @c movieVoiceFlg , @c installFlg , and @c movieEndViewReadyFlg likewise keep the SDK's "Flg"
 * spelling.
 */

#import <UIKit/UIKit.h>

#import "AppliView.h"
#import "ApplilinkParameters.h"
#import "ApplilinkWebView.h"
#import "VideoView.h"

@class AppliView;
@class ApplilinkIndicator;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The advert-video host controller.
 *
 * Adopts @c VideoViewDelegate (the player's callbacks) and @c SdkViewDelegate (the end-card web
 * view's callbacks); the two protocols share the ready/close/repeat/store/error selectors, which is
 * why one controller can be both.
 */
@interface ApplilinkVideoController
    : UIViewController <VideoViewDelegate, SdkViewDelegate, AppliViewDelegate>

/**
 * @brief The SDK delegate told about ready and close events.
 *
 * Weak (the metadata attribute is @c W ): the controller reports to it but does not own it.
 * @ghidraAddress 0x22664c (getter)
 */
@property(weak, nonatomic, nullable) id<SdkViewDelegate> sdkDelegate;

/**
 * @brief The black full-screen advert surface hosting the player.
 * @ghidraAddress 0x226680 (getter)
 */
@property(strong, nonatomic, nullable) AppliView *appliView;

/**
 * @brief The advert-movie player.
 * @ghidraAddress 0x2266c8 (getter)
 */
@property(strong, nonatomic, nullable) VideoView *videoView;

/**
 * @brief The end-card web view shown once the movie finishes.
 * @ghidraAddress 0x226710 (getter)
 */
@property(strong, nonatomic, nullable) ApplilinkWebView *webView;

/**
 * @brief An unused base view. Retained by the property but never assigned in the recovered code.
 * @ghidraAddress 0x226758 (getter)
 */
@property(strong, nonatomic, nullable) UIView *baseView;

/**
 * @brief The loading overlay shown while the movie prepares.
 * @ghidraAddress 0x2267a0 (getter)
 */
@property(strong, nonatomic, nullable) ApplilinkIndicator *indicator;

/**
 * @brief The applilink core delegate carried through the analysis and notice calls.
 *
 * Weak (the metadata attribute is @c W ) and untyped in the metadata, so a bare @c id .
 * @ghidraAddress 0x2267e8 (getter)
 */
@property(weak, nonatomic, nullable) id applilinkDelegate;

/**
 * @brief The advert request parameters. Copied on assignment.
 * @ghidraAddress 0x22681c (getter)
 */
@property(copy, nonatomic, nullable) ApplilinkParameters *applilinkParams;

/**
 * @brief An unused secondary base view. Retained by the property but never assigned.
 * @ghidraAddress 0x226848 (getter)
 */
@property(strong, nonatomic, nullable) UIView *videoBaseView;

/** @brief The movie URL parsed from the query. @ghidraAddress 0x226890 (getter) */
@property(strong, nonatomic, nullable) NSString *movieUrl;
/** @brief The poster-image URL parsed from the query. @ghidraAddress 0x2268d8 (getter) */
@property(strong, nonatomic, nullable) NSString *posterUrlRect;
/** @brief The store URL parsed from the query. @ghidraAddress 0x226920 (getter) */
@property(strong, nonatomic, nullable) NSString *storeUrl;
/** @brief The store identifier parsed from the query. @ghidraAddress 0x226968 (getter) */
@property(strong, nonatomic, nullable) NSString *storeId;
/** @brief The movie-end URL. @ghidraAddress 0x2269b0 (getter) */
@property(strong, nonatomic, nullable) NSString *endUrl;
/** @brief The sound flag parsed from the query. @ghidraAddress 0x2269f8 (getter) */
@property(strong, nonatomic, nullable) NSString *movieVoiceFlg;
/** @brief The advert type parsed from the query. @ghidraAddress 0x226a40 (getter) */
@property(strong, nonatomic, nullable) NSString *adType;
/** @brief The advert model parsed from the query. @ghidraAddress 0x226a88 (getter) */
@property(strong, nonatomic, nullable) NSString *adModel;
/** @brief The advert location parsed from the query. @ghidraAddress 0x226ad0 (getter) */
@property(strong, nonatomic, nullable) NSString *adLocation;
/** @brief The impression identifier parsed from the query. @ghidraAddress 0x226b18 (getter) */
@property(strong, nonatomic, nullable) NSString *impressionId;
/** @brief The destination application identifier. @ghidraAddress 0x226b60 (getter) */
@property(strong, nonatomic, nullable) NSString *appliIdTo;
/** @brief The source advert identifier. @ghidraAddress 0x226ba8 (getter) */
@property(strong, nonatomic, nullable) NSString *adIdFrom;
/** @brief The destination advert identifier. @ghidraAddress 0x226bf0 (getter) */
@property(strong, nonatomic, nullable) NSString *adIdTo;
/** @brief The creative identifier parsed from the query. @ghidraAddress 0x226c38 (getter) */
@property(strong, nonatomic, nullable) NSString *creativeId;
/** @brief The display-number parameter. @ghidraAddress 0x226c80 (getter) */
@property(strong, nonatomic, nullable) NSString *displayNumber;
/** @brief The incentive-type parameter. @ghidraAddress 0x226cc8 (getter) */
@property(strong, nonatomic, nullable) NSString *incentiveType;
/** @brief The install flag parsed from the query. @ghidraAddress 0x226d10 (getter) */
@property(strong, nonatomic, nullable) NSString *installFlg;

/**
 * @brief The caller's request code, untyped in the metadata.
 * @ghidraAddress 0x226d58 (getter)
 */
@property(strong, nonatomic, nullable) id requestCode;

/**
 * @brief Set once the end-card web view has finished loading and is ready to be shown.
 * @ghidraAddress 0x226d78 (getter)
 */
@property(nonatomic) BOOL movieEndViewReadyFlg;

/**
 * @brief Set when the controller's view is hosted directly in the parent window rather than a
 * subview, which changes the status-bar offset compensation.
 * @ghidraAddress 0x226d98 (getter)
 */
@property(nonatomic) BOOL parentWindowFlag;

/**
 * @brief Sets @c parentWindowFlag . A hand-written setter distinct from the synthesised one.
 * @param parentWindowFlag The new flag value.
 * @ghidraAddress 0x223c80
 */
- (void)parentWindowFlag:(BOOL)parentWindowFlag;

/**
 * @brief Parses the advert query and builds the player.
 *
 * Splits @p query on @c "&" into @c key=value pairs, URL-decodes each recognised value into its
 * matching parameter ivar, then builds the movie view. When @p autoPlay is set the loading
 * indicator is released on the main queue and the player is told to auto-start.
 * @param query The advert query string.
 * @param autoPlay Whether to start playback as soon as the movie is ready.
 * @param applilinkParams The request parameters (stored directly, not copied).
 * @param delegate The applilink core delegate (stored into @c applilinkDelegate ).
 * @return @c YES when @p query was non-nil and parsed, @c NO otherwise.
 * @ghidraAddress 0x223c90
 */
- (BOOL)setQuery:(nullable NSString *)query
           autoPlay:(BOOL)autoPlay
    applilinkParams:(nullable ApplilinkParameters *)applilinkParams
           delegate:(nullable id)delegate;

/**
 * @brief Called when the whole player finishes; forwards @c -closeNotice: to the SDK delegate.
 * @ghidraAddress 0x225678
 */
- (void)toucheEnded;

/**
 * @brief Called when the app-list web view appears; opens the store URL then closes the player.
 * @ghidraAddress 0x225d08
 */
- (void)appListDidAppear;

/**
 * @brief Rebuilds the movie view laid out for the given interface orientation.
 * @param interfaceOrientation The target interface orientation.
 * @param duration The rotation animation duration.
 * @ghidraAddress 0x225650
 */
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                         duration:(NSTimeInterval)duration;

/**
 * @brief Tears the player and web view down and clears every parsed parameter.
 * @ghidraAddress 0x226418
 */
- (void)viewDealloc;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
