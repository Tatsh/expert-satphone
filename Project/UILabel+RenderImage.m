#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>

#import "UILabel+RenderImage.h"

// Snapshots the view's layer into an offscreen bitmap and returns it as a UIImage. The binary's IMP
// (0x1255c4, reached through the objc_msgSend thunk at 0x391013) builds a raw CGBitmapContext from
// the frame's width and height truncated to integer points, at a fixed 1.0 scale (not Retina),
// flips the y axis for CoreGraphics' bottom-left origin, renders the layer, and wraps the result.
// It is a layer snapshot, so content drawn outside the layer tree is not captured. The method sits
// in a UILabel category in the runtime metadata but only touches UIView state (frame, layer).
@implementation UILabel (RenderImage)

/** @ghidraAddress 0x1255c4 */
- (nullable UIImage *)renderImage {
    CGRect frame = self.frame;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(nullptr,
                                                 (size_t)frame.size.width,
                                                 (size_t)frame.size.height,
                                                 8,
                                                 0,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    // Flip to UIKit's top-left origin before rendering the layer.
    CGContextTranslateCTM(context, 0.0, frame.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    [self.layer renderInContext:context];
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    return image;
}

@end
