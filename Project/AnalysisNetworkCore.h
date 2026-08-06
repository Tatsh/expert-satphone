/** @file
 * The applilink SDK's analytics transport.
 *
 * Reconstructed from Ghidra program Jubeat (class AnalysisNetworkCore, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. The class has thirteen class
 * methods; only the three @c AnalysisNetwork forwards to are declared here. The rest are listed in
 * TYPES_PENDING.md.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The callback every analytics call answers with, carrying an error or nil.
 */
typedef void (^ApplilinkAnalysisCallback)(NSError *_Nullable error);

/**
 * @brief Performs the analytics requests, with no SDK-availability checks of its own.
 *
 * @c AnalysisNetwork is the guarded facade in front of this.
 */
@interface AnalysisNetworkCore : NSObject

/**
 * @brief Posts one analysis record. DECLARED ONLY.
 * @ghidraAddress 0x2395bc
 */
+ (void)postAnalysisDataWithResultId:(nullable NSString *)resultId
                            callback:(nullable ApplilinkAnalysisCallback)callback;

/**
 * @brief Opens an advert in the external browser. DECLARED ONLY.
 * @ghidraAddress 0x23a2fc
 */
+ (void)openExternalWebBrowserCore:(nullable NSString *)url
                               env:(nullable NSString *)env
                          callback:(nullable ApplilinkAnalysisCallback)callback;

/**
 * @brief Opens an advert for one application identifier. DECLARED ONLY.
 * @ghidraAddress 0x23b04c
 */
+ (void)openWebBrowserWithAppliIdCore:(nullable NSString *)appliId
                                  env:(nullable NSString *)env
                             callback:(nullable ApplilinkAnalysisCallback)callback;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
