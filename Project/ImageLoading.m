#import "ImageLoading.h"

// The only extension this loader handles, from the CFString at 0x2d8620.
static NSString *const kPngExtension = @"png";

// Seeds, not defaults: GetScaledResourcePath writes both out-params on the paths that matter.
static const float kInitialScale = 2.0f;

UIImage *LoadScaledPngImage(NSString *pszBaseName) {
    BOOL fScaled = NO;
    float flScale = kInitialScale;
    NSString *path = GetScaledResourcePath(pszBaseName, &fScaled, &flScale, kPngExtension);
    if (path == nil) {
        return nil;
    }
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:path];
    // The nil test and the flag test compile to one conditional compare rather than two branches.
    if (image != nil && fScaled) {
        // This re-wrap is the whole point of the function. -initWithContentsOfFile: infers a scale
        // only from Apple's "@2x" convention, and these assets are named "_pn2"/"_pn3" instead, so
        // the image arrives claiming scale 1.0 however large it really is. Without this it would
        // draw at double or treble its intended size.
        image = [UIImage imageWithCGImage:image.CGImage
                                    scale:flScale
                              orientation:UIImageOrientationUp];
    }
    return image;
}
