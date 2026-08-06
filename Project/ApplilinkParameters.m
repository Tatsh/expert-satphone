#import "ApplilinkParameters.h"

@implementation ApplilinkParameters

/** @ghidraAddress 0x2688d0 */
- (void)setRequestWithAdModel:(int)adModel
                   adLocation:(NSString *)adLocation
                  requestCode:(id)requestCode {
    // Direct ivar assignment, so requestCode is retained rather than copied despite the property
    // declaring copy.
    _adModel = adModel;
    _adLocation = adLocation;
    _requestCode = requestCode;
}

/** @ghidraAddress 0x26895c */
- (void)setRequestWithAdModel:(int)adModel
                   adLocation:(NSString *)adLocation
                verticalAlign:(int)verticalAlign
                  requestCode:(id)requestCode {
    _adModel = adModel;
    _adLocation = adLocation;
    // Yes, verticalAlign is never stored. This method is otherwise identical to the three-argument
    // one, so the only reason to call it is discarded.
    _requestCode = requestCode;
}

@end
