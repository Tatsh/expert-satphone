#import "ImageLoading.h"

#include <string.h>

#import <CommonCrypto/CommonDigest.h>
#import <CoreGraphics/CoreGraphics.h>

#import "BFCodec.h"
#import "TextureLoading.h"

// The only extension the PNG loader handles, from the CFString at 0x2d8620.
static NSString *const kPngExtension = @"png";

// The extension the encrypted loader resolves, from the CFString at 0x2d8600.
static NSString *const kTexExtension = @"tex";

// Seeds, not defaults: GetScaledResourcePath writes both out-params on the paths that matter.
static const float kInitialScale = 2.0f;

// The Retina variant suffixes GetScaledResourcePath appends, from the CFStrings at 0x2d8580,
// 0x2d85a0, 0x2d85c0, and 0x2d85e0. These replace Apple's "@2x"/"@3x" convention, which is why the
// loaded image has to be re-wrapped to carry its scale.
static NSString *const kSuffixPad2 = @"_pd2";
static NSString *const kSuffixPhone1 = @"_pn";
static NSString *const kSuffixPhone2 = @"_pn2";
static NSString *const kSuffixPhone3 = @"_pn3";

// Retina screen-scale thresholds and the matching variant scales written back through *pflScale.
static const CGFloat kScreenScale2x = 2.0;
static const CGFloat kScreenScale3x = 3.0;
static const float kVariantScale2x = 2.0f;
static const float kVariantScale3x = 3.0f;

// The passphrases the two cipher keys derive from. The encrypted texture loader open-codes an
// inlined copy of CreateTextureCipherKey rather than calling it — assembling the passphrase on the
// stack in three pieces so it is never contiguous in the file (16 bytes from the rodata literal at
// 0x28f980 = "copious plus kni", then "t ripple" and "s" from register immediates). The resource
// passphrase is the entire 16-byte rodata literal at 0x28f9c0; "skmpledata" is a mangled
// "sampledata" reproduced exactly as the binary stores it, and must be hashed verbatim.
static const char kTextureCipherPassphrase[] = "copious plus knit ripples";
static const char kResourceDataCipherPassphrase[] = "jubeatskmpledata";

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

NSString *GetScaledResourcePath(NSString *pszBaseName,
                                BOOL *pfScaled,
                                float *pflScale,
                                NSString *pszExtension) {
    UIUserInterfaceIdiom idiom = UIDevice.currentDevice.userInterfaceIdiom;
    CGFloat scale = UIScreen.mainScreen.scale;
    if (idiom == UIUserInterfaceIdiomPad) {
        if (scale == kScreenScale2x) {
            NSString *path = [NSBundle.mainBundle
                pathForResource:[pszBaseName stringByAppendingString:kSuffixPad2]
                         ofType:pszExtension];
            if (path == nil) {
                // "_pd2" is missing, so fall into the iPhone-style chain. The binary appends the
                // suffixes here with -stringByAppendingFormat: rather than
                // -stringByAppendingString: even though they carry no format specifiers.
                NSString *phonePath = [NSBundle.mainBundle
                    pathForResource:[pszBaseName stringByAppendingFormat:kSuffixPhone1]
                             ofType:pszExtension];
                if (phonePath != nil) {
                    // A "_pn" variant exists, yet the bare-name path is what is returned, unscaled.
                    return [NSBundle.mainBundle pathForResource:pszBaseName ofType:pszExtension];
                }
                path = [NSBundle.mainBundle
                    pathForResource:[pszBaseName stringByAppendingFormat:kSuffixPhone2]
                             ofType:pszExtension];
                if (path == nil) {
                    return [NSBundle.mainBundle pathForResource:pszBaseName ofType:pszExtension];
                }
            }
            *pfScaled = YES;
            return path;
        }
        // An iPad that is not @2x gets no Retina handling at all — just the unsuffixed name.
        return [NSBundle.mainBundle pathForResource:pszBaseName ofType:pszExtension];
    }
    if (scale == kScreenScale2x) {
        // iPhone @2x: the flag is set before the lookup, so it reads YES even when the "_pn2"
        // variant is missing and the bare name is returned.
        *pfScaled = YES;
        NSString *path =
            [NSBundle.mainBundle pathForResource:[pszBaseName stringByAppendingString:kSuffixPhone2]
                                          ofType:pszExtension];
        if (path == nil) {
            path = [NSBundle.mainBundle pathForResource:pszBaseName ofType:pszExtension];
        }
        return path;
    }
    // The scale is re-read from the main screen here, redundantly, before the @3x comparison.
    scale = UIScreen.mainScreen.scale;
    if (scale == kScreenScale3x) {
        *pfScaled = YES;
        *pflScale = kVariantScale3x;
        NSString *path =
            [NSBundle.mainBundle pathForResource:[pszBaseName stringByAppendingString:kSuffixPhone3]
                                          ofType:pszExtension];
        if (path == nil) {
            // No "_pn3": downgrade to "_pn2" and rewrite the reported scale to 2.0.
            *pfScaled = YES;
            *pflScale = kVariantScale2x;
            path = [NSBundle.mainBundle
                pathForResource:[pszBaseName stringByAppendingString:kSuffixPhone2]
                         ofType:pszExtension];
            if (path == nil) {
                path = [NSBundle.mainBundle pathForResource:pszBaseName ofType:pszExtension];
            }
        }
        return path;
    }
    // iPhone @1x, or any scale that is neither 2.0 nor 3.0: try "_pn", then the bare name. Neither
    // out-parameter is touched, so the caller's seeds survive.
    NSString *path =
        [NSBundle.mainBundle pathForResource:[pszBaseName stringByAppendingString:kSuffixPhone1]
                                      ofType:pszExtension];
    if (path == nil) {
        path = [NSBundle.mainBundle pathForResource:pszBaseName ofType:pszExtension];
    }
    return path;
}

UIImage *LoadScaledEncryptedTexImage(NSString *pszBaseName) {
    BOOL fScaled = NO;
    float flScale = kInitialScale;
    NSString *path = GetScaledResourcePath(pszBaseName, &fScaled, &flScale, kTexExtension);
    if (path == nil) {
        return nil;
    }

    BFCodec *codec = [[BFCodec alloc] init];

    // The key is an inlined copy of CreateTextureCipherKey: the MD5 of the texture passphrase over
    // strlen bytes, so the trailing NUL is excluded.
    CC_MD5_CTX context;
    CC_MD5_Init(&context);
    CC_MD5_Update(&context, kTextureCipherPassphrase, (CC_LONG)strlen(kTextureCipherPassphrase));
    unsigned char key[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(key, &context);

    NSMutableData *data = [NSMutableData dataWithContentsOfFile:path];
    [codec cipherInit:[NSData dataWithBytes:key length:sizeof(key)]];
    UIImage *image = CreateImageFromEncryptedData(codec, data);
    // Re-wrap at the resolved scale for the same reason the PNG loader does, but only when a Retina
    // variant was chosen; otherwise the decoded image is left at scale 1.0.
    if (image != nil && fScaled) {
        image = [UIImage imageWithCGImage:image.CGImage
                                    scale:flScale
                              orientation:UIImageOrientationUp];
    }
    return image;
}

NSData *CreateResourceDataCipherKey(void) {
    // MD5 of the passphrase over strlen bytes rather than sizeof, matching the cipher-key cluster.
    CC_MD5_CTX context;
    CC_MD5_Init(&context);
    CC_MD5_Update(
        &context, kResourceDataCipherPassphrase, (CC_LONG)strlen(kResourceDataCipherPassphrase));
    unsigned char key[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(key, &context);
    // +dataWithBytes:length: already autoreleases; there is no separate autorelease tail call.
    return [NSData dataWithBytes:key length:sizeof(key)];
}
