/**
 * @file
 * The applilink SDK's advert-request descriptor.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkParameters, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The other binary that embeds the SDK carries the same class, and both bodies agree, including
 * that the four-argument setter never stores its @c verticalAlign argument — so that is a property
 * of the SDK rather than of one build.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Carries one advert request's model, location, alignment and caller request code.
 */
@interface ApplilinkParameters : NSObject

/**
 * The advert-model identifier. Four bytes in the metadata, so @c int.
 */
@property(nonatomic) int adModel;
/**
 * The advert-location identifier.
 */
@property(nonatomic, strong, nullable) NSString *adLocation;
/**
 * The vertical alignment. Four bytes in the metadata, so @c int.
 *
 * Nothing in this class ever writes it: the only setter that takes an alignment discards it, so it
 * holds whatever a caller assigns through this property and nothing else.
 */
@property(nonatomic) int verticalAlign;
/**
 * The caller's request code, handed back with the response.
 *
 * Untyped in the metadata, and the synthesised setter copies. Note that the two
 * @c -setRequestWith… methods assign the ivar directly and therefore do **not** copy.
 */
@property(nonatomic, copy, nullable) id requestCode;

/**
 * Populates the request with a model, a location and a request code.
 *
 * @param adModel The advert-model identifier.
 * @param adLocation The advert-location identifier.
 * @param requestCode The caller's request code.
 * @ghidraAddress 0x2688d0
 */
- (void)setRequestWithAdModel:(int)adModel
                   adLocation:(nullable NSString *)adLocation
                  requestCode:(nullable id)requestCode;

/**
 * The same, with an alignment argument that is accepted and then discarded.
 *
 * @param adModel The advert-model identifier.
 * @param adLocation The advert-location identifier.
 * @param verticalAlign Ignored. The body never reads it and never writes @c verticalAlign.
 * @param requestCode The caller's request code.
 * @ghidraAddress 0x26895c
 */
- (void)setRequestWithAdModel:(int)adModel
                   adLocation:(nullable NSString *)adLocation
                verticalAlign:(int)verticalAlign
                  requestCode:(nullable id)requestCode;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
