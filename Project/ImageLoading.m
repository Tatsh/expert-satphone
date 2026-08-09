#import "ImageLoading.h"

#import <CoreGraphics/CoreGraphics.h>

// The only extension this loader handles, from the CFString at 0x2d8620.
static NSString *const kPngExtension = @"png";

// Seeds, not defaults: GetScaledResourcePath writes both out-params on the paths that matter.
static const float kInitialScale = 2.0f;

// The reflection mask's gradient runs from transparent black to opaque white, so the flipped copy
// fades from fully visible at the top to fully clear at the bottom. Two device-gray colours of two
// components each (gray, alpha), read as two q-registers from the four doubles at 0x28f9e0.
static const CGFloat kReflectionGradientComponents[] = {
    0.0,
    0.0, // @ghidraAddress 0x28f9e0 gray 0.0, alpha 0.0
    1.0,
    1.0, // @ghidraAddress 0x28f9f0 gray 1.0, alpha 1.0
};
static const size_t kReflectionGradientColorCount = 2;

// A UIImage carrying no explicit scale reports 1.0; the reflection is worked in pixels only when
// the source is more finely scaled than that.
static const CGFloat kUnscaled = 1.0;

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

UIImage *CreateReflectedImage(UIImage *image, int height) {
    if (image == nil || height == 0) {
        return nil;
    }

    // Work in pixels. On a scaled source the width, height, and reflection depth are all promoted
    // by the scale so the offscreen contexts are sized in real texels. The binary re-sends -scale
    // and -size for each multiply rather than caching them; the values are identical.
    CGFloat scale = image.scale;
    CGSize size = image.size;
    CGFloat imageWidth = size.width;
    CGFloat imageHeight = size.height;
    unsigned int reflectionHeight = (unsigned int)height;
    if (scale != kUnscaled) {
        imageWidth = size.width * scale;
        imageHeight = size.height * scale;
        reflectionHeight = (unsigned int)((CGFloat)height * scale);
    }

    // The reflected copy: an RGBA context only reflectionHeight rows tall, so drawing the source
    // at full height clips everything below the requested depth.
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef flippedContext = CGBitmapContextCreate(nullptr,
                                                        (size_t)imageWidth,
                                                        reflectionHeight,
                                                        8,
                                                        0,
                                                        colorSpace,
                                                        kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    if (flippedContext == nullptr) {
        return nil;
    }

    CGContextTranslateCTM(flippedContext, 0.0, (CGFloat)reflectionHeight);
    CGContextScaleCTM(flippedContext, 1.0, -1.0);
    CGContextDrawImage(flippedContext, CGRectMake(0, 0, imageWidth, imageHeight), image.CGImage);
    CGImageRef flippedImage = CGBitmapContextCreateImage(flippedContext);
    CGContextRelease(flippedContext);

    // The mask: a one-pixel-wide device-gray strip painted with the fade gradient, drawn past its
    // end location so the region below the ramp stays opaque white.
    CGColorSpaceRef grayColorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef maskContext = CGBitmapContextCreate(
        nullptr, 1, (size_t)(int)reflectionHeight, 8, 0, grayColorSpace, kCGImageAlphaNone);
    CGImageRef maskImage = nullptr;
    if (maskContext != nullptr) {
        CGGradientRef gradient = CGGradientCreateWithColorComponents(
            grayColorSpace, kReflectionGradientComponents, nullptr, kReflectionGradientColorCount);
        CGContextDrawLinearGradient(maskContext,
                                    gradient,
                                    CGPointZero,
                                    CGPointMake(0, (CGFloat)(int)reflectionHeight),
                                    kCGGradientDrawsAfterEndLocation);
        CGGradientRelease(gradient);
        maskImage = CGBitmapContextCreateImage(maskContext);
        CGContextRelease(maskContext);
    }
    CGColorSpaceRelease(grayColorSpace);

    CGImageRef maskedImage = CGImageCreateWithMask(flippedImage, maskImage);
    CGImageRelease(flippedImage);
    CGImageRelease(maskImage);

    // Re-wrap at the source's scale; the two-argument +imageWithCGImage: assumes 1.0 and would
    // double a Retina reflection's apparent size.
    UIImage *result = (image.scale == kUnscaled) ? [UIImage imageWithCGImage:maskedImage] :
                                                   [UIImage imageWithCGImage:maskedImage
                                                                       scale:image.scale
                                                                 orientation:UIImageOrientationUp];
    CGImageRelease(maskedImage);
    return result;
}
