#import "Texture2D.h"

#import <CoreGraphics/CoreGraphics.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

#import "sprite_vertex.h"

// The vertex scratch buffer holds this many quads; -setData: allocates it as
// kMaxQuads * kVerticesPerQuad * sizeof(SpriteVertex) == 0x18000 bytes, and every draw entry
// point refuses to append once currentPolys reaches it.
static const unsigned int kMaxQuads = 1024;

// Each quad is four interleaved vertices drawn as two triangles (six indices).
static const int kVerticesPerQuad = 4;
static const int kIndicesPerQuad = 6;

// An 8-bit colour channel is the clamped component scaled by 255. Shared with the value baked into
// sprite_vertex.cpp; the game keeps one copy in read-only data.
static const float kByteScale255 = 255.0f; // @ghidraAddress 0x28dff4

// The vertical flip in -setClipRect: uses the screen height for the current device idiom: a phone
// is 480 points tall, a pad 1024. Read from the two-double table at 0x28e000.
static const CGFloat kScreenHeightPhone = 480.0; // @ghidraAddress 0x28e000
static const CGFloat kScreenHeightPad = 1024.0;  // @ghidraAddress 0x28e008

// Halving factor applied to a sprite's drawn size when the texture is treated as 2x-supersampled.
static const double kScale2xFactor = 0.5;

// The message shown when -setData:… is handed a pixel format it does not know.
static NSString *const kUnknownPixelFormatMessage =
    @"Texture2D initWithData: unknown pixel format"; // @ghidraAddress 0x2d4900

// The message shown when -initWithImage: / -setSubImage:… cannot map an image to a pixel format.
// @ghidraAddress 0x2d4920
static NSString *const kInvalidPixelFormatMessage = @"Invalid pixel format";

@implementation Texture2D {
    // Declared in the runtime metadata's order. The properties isScale2x, name, width, and height
    // synthesise the remaining ivars (_isScale2x, _name, _width, _height).
    Texture2DPixelFormat pixelFormat; // offset global 0x349714
    GLuint _size;                     // offset global 0x349708; the square texture dimension
    CGRect *spriteRect;               // offset global 0x349724; malloc'd table of numSprite rects
    int numSprite;                    // offset global 0x349720
    SpriteVertex *vertices;           // offset global 0x349718; the batched-quad scratch buffer
    unsigned int currentPolys;        // offset global 0x34971c; quads appended since the last flush
    CGRect _clipRect;                 // offset global 0x349704; GL scissor, or CGRectNull for none
}

#pragma mark - Class helpers

+ (CGRect)scaledRect:(CGRect)rect scale:(double)scale anchor:(CGPoint)anchor {
    /** @ghidraAddress 0xdc4c */
    return CGRectMake(anchor.x + (rect.origin.x - anchor.x) * scale,
                      anchor.y + (rect.origin.y - anchor.y) * scale,
                      rect.size.width * scale,
                      rect.size.height * scale);
}

#pragma mark - Initialisation

- (instancetype)init {
    /** @ghidraAddress 0xdc70 */
    self = [super init];
    if (self) {
        _name = 0;
        _clipRect = CGRectNull;
    }
    return self;
}

- (instancetype)initWithData:(const void *)data
                 pixelFormat:(Texture2DPixelFormat)aPixelFormat
                   pixelSize:(GLuint)pixelSize
                       width:(int)width
                      height:(int)height {
    /** @ghidraAddress 0xde9c */
    self = [super init];
    if (self) {
        _name = 0;
        _clipRect = CGRectNull;
        [self setData:data pixelFormat:aPixelFormat pixelSize:pixelSize width:width height:height];
    }
    return self;
}

- (instancetype)initWithData:(const void *)data
                 pixelFormat:(Texture2DPixelFormat)aPixelFormat
                   pixelSize:(GLuint)pixelSize {
    /** @ghidraAddress 0xdf58 */
    return [self initWithData:data
                  pixelFormat:aPixelFormat
                    pixelSize:pixelSize
                        width:pixelSize
                       height:pixelSize];
}

- (nullable instancetype)initWithImage:(nullable UIImage *)image {
    /** @ghidraAddress 0xdf6c */
    CGImageRef cgImage = image.CGImage;
    if (!image) {
        return nil;
    }

    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(cgImage);
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(cgImage);
    // An alpha channel present anywhere but "none" (indices 1..4) keeps four components; otherwise
    // three. A missing colour space forces the single-channel A8 format below.
    Texture2DPixelFormat colouredFormat = ((unsigned int)(alphaInfo - 1) > 3) ?
                                              Texture2DPixelFormatRGB888 :
                                              Texture2DPixelFormatRGBA8888;

    CGAffineTransform transform = CGAffineTransformIdentity;
    int imageWidth = (int)CGImageGetWidth(cgImage);
    int imageHeight = (int)CGImageGetHeight(cgImage);
    unsigned int maxDimension =
        (imageWidth < imageHeight) ? (unsigned int)imageHeight : (unsigned int)imageWidth;

    GLint maxTextureSize = 0;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);

    // Round the larger dimension up to the next power of two.
    unsigned int textureSize = 1;
    while (textureSize < maxDimension) {
        textureSize <<= 1;
    }

    Texture2DPixelFormat format = colorSpace ? colouredFormat : Texture2DPixelFormatA8;

    // Shrink by halves until the texture fits GL's maximum, scaling the content dimensions and the
    // draw transform to match.
    while ((unsigned int)maxTextureSize < textureSize) {
        textureSize >>= 1;
        imageWidth = (int)((unsigned int)imageWidth >> 1);
        imageHeight = (int)((unsigned int)imageHeight >> 1);
        transform = CGAffineTransformScale(transform, kScale2xFactor, kScale2xFactor);
    }

    if (textureSize == 0) {
        return nil;
    }

    void *buffer = nullptr;
    CGContextRef context = nullptr;
    switch (format) {
    case Texture2DPixelFormatA8:
        buffer = malloc(textureSize * textureSize);
        context = CGBitmapContextCreate(
            buffer, textureSize, textureSize, 8, textureSize, nullptr, kCGImageAlphaOnly);
        break;
    case Texture2DPixelFormatRGB888: {
        CGColorSpaceRef deviceRGB = CGColorSpaceCreateDeviceRGB();
        int bytesPerRow = textureSize * 3;
        buffer = malloc(bytesPerRow * textureSize);
        context = CGBitmapContextCreate(buffer,
                                        textureSize,
                                        textureSize,
                                        8,
                                        bytesPerRow,
                                        deviceRGB,
                                        kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(deviceRGB);
        break;
    }
    case Texture2DPixelFormatRGBA8888: {
        CGColorSpaceRef deviceRGB = CGColorSpaceCreateDeviceRGB();
        int bytesPerRow = textureSize * 4;
        buffer = malloc(bytesPerRow * textureSize);
        context = CGBitmapContextCreate(buffer,
                                        textureSize,
                                        textureSize,
                                        8,
                                        bytesPerRow,
                                        deviceRGB,
                                        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(deviceRGB);
        break;
    }
    default:
        buffer = malloc(1);
        [NSException raise:NSInternalInconsistencyException
                    format:@"%@", kInvalidPixelFormatMessage];
        break;
    }

    CGContextClearRect(context, CGRectMake(0, 0, textureSize, textureSize));
    // Bottom-align the image in the (square) texture so the used region sits at the origin GL reads
    // from.
    if ((unsigned int)(textureSize - imageHeight) != 0) {
        CGContextTranslateCTM(context, 0, (CGFloat)(textureSize - imageHeight));
    }
    if (!CGAffineTransformIsIdentity(transform)) {
        CGContextConcatCTM(context, transform);
    }
    CGContextDrawImage(
        context,
        CGRectMake(0, 0, (CGFloat)CGImageGetWidth(cgImage), (CGFloat)CGImageGetHeight(cgImage)),
        cgImage);

    self = [self initWithData:buffer
                  pixelFormat:format
                    pixelSize:textureSize
                        width:imageWidth
                       height:imageHeight];
    CGContextRelease(context);
    if (buffer) {
        free(buffer);
    }
    return self;
}

#pragma mark - Pixel upload

- (void)setData:(const void *)data
    pixelFormat:(Texture2DPixelFormat)aPixelFormat
      pixelSize:(GLuint)pixelSize
          width:(int)width
         height:(int)height {
    /** @ghidraAddress 0xdcd4 */
    if (_name != 0) {
        glDeleteTextures(1, &_name);
        _name = 0;
    }
    glGenTextures(1, &_name);
    glBindTexture(GL_TEXTURE_2D, _name);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

    switch (aPixelFormat) {
    case Texture2DPixelFormatA8:
        glTexImage2D(
            GL_TEXTURE_2D, 0, GL_ALPHA, pixelSize, pixelSize, 0, GL_ALPHA, GL_UNSIGNED_BYTE, data);
        break;
    case Texture2DPixelFormatRGB888:
        glTexImage2D(
            GL_TEXTURE_2D, 0, GL_RGB, pixelSize, pixelSize, 0, GL_RGB, GL_UNSIGNED_BYTE, data);
        break;
    case Texture2DPixelFormatRGBA8888:
        glTexImage2D(
            GL_TEXTURE_2D, 0, GL_RGBA, pixelSize, pixelSize, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
        break;
    default:
        [NSException raise:NSInternalInconsistencyException
                    format:@"%@", kUnknownPixelFormatMessage];
        break;
    }

    _size = pixelSize;
    _width = (NSUInteger)width;
    _height = (NSUInteger)height;
    pixelFormat = aPixelFormat;
    if (!vertices) {
        vertices = (SpriteVertex *)malloc(kMaxQuads * kVerticesPerQuad * sizeof(SpriteVertex));
    }
}

- (void)setData:(const void *)data
    pixelFormat:(Texture2DPixelFormat)aPixelFormat
      pixelSize:(GLuint)pixelSize {
    /** @ghidraAddress 0xde88 */
    [self setData:data
        pixelFormat:aPixelFormat
          pixelSize:pixelSize
              width:pixelSize
             height:pixelSize];
}

- (void)setSubImage:(nullable UIImage *)image inRect:(CGRect)rect {
    /** @ghidraAddress 0xe2dc */
    if (!image) {
        return;
    }
    glBindTexture(GL_TEXTURE_2D, _name);
    CGImageRef cgImage = image.CGImage;
    int width = (int)rect.size.width;
    int height = (int)rect.size.height;

    void *buffer = nullptr;
    CGContextRef context = nullptr;
    GLenum uploadFormat = GL_ALPHA;
    switch (pixelFormat) {
    case Texture2DPixelFormatA8:
        buffer = malloc(width * height);
        context =
            CGBitmapContextCreate(buffer, width, height, 8, width, nullptr, kCGImageAlphaOnly);
        uploadFormat = GL_ALPHA;
        break;
    case Texture2DPixelFormatRGB888: {
        CGColorSpaceRef deviceRGB = CGColorSpaceCreateDeviceRGB();
        buffer = malloc(height * width * 3);
        context = CGBitmapContextCreate(buffer,
                                        width,
                                        height,
                                        8,
                                        width * 3,
                                        deviceRGB,
                                        kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(deviceRGB);
        uploadFormat = GL_RGB;
        break;
    }
    case Texture2DPixelFormatRGBA8888: {
        CGColorSpaceRef deviceRGB = CGColorSpaceCreateDeviceRGB();
        buffer = malloc(height * width * 4);
        context = CGBitmapContextCreate(buffer,
                                        width,
                                        height,
                                        8,
                                        width * 4,
                                        deviceRGB,
                                        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(deviceRGB);
        uploadFormat = GL_RGBA;
        break;
    }
    default:
        buffer = malloc(1);
        [NSException raise:NSInternalInconsistencyException
                    format:@"%@", kInvalidPixelFormatMessage];
        break;
    }

    CGContextClearRect(context, CGRectMake(0, 0, (CGFloat)width, (CGFloat)height));
    CGContextDrawImage(context, CGRectMake(0, 0, (CGFloat)width, (CGFloat)height), cgImage);
    glTexSubImage2D(GL_TEXTURE_2D,
                    0,
                    (int)rect.origin.x,
                    (int)rect.origin.y,
                    width,
                    height,
                    uploadFormat,
                    GL_UNSIGNED_BYTE,
                    buffer);
    CGContextRelease(context);
    if (buffer) {
        free(buffer);
    }
}

- (void)setSubImage:(nullable UIImage *)image atPoint:(CGPoint)point {
    /** @ghidraAddress 0xe52c */
    if (!image) {
        return;
    }
    CGImageRef cgImage = image.CGImage;
    [self setSubImage:image
               inRect:CGRectMake(point.x,
                                 point.y,
                                 (CGFloat)CGImageGetWidth(cgImage),
                                 (CGFloat)CGImageGetHeight(cgImage))];
}

#pragma mark - Batched drawing

- (void)drawAtPoint:(CGPoint)point scale:(double)scale {
    /** @ghidraAddress 0xe5e4 */
    if (currentPolys >= kMaxQuads) {
        return;
    }
    SpriteVertex *quad = &vertices[currentPolys * kVerticesPerQuad];
    double span = (double)_size * scale;
    float left = (float)point.x;
    float top = (float)point.y;
    float right = (float)(point.x + span);
    float bottom = (float)(point.y + span);

    quad[0].fX = left;
    quad[0].fY = top;
    quad[1].fX = left;
    quad[1].fY = bottom;
    quad[2].fX = right;
    quad[2].fY = top;
    quad[3].fX = right;
    quad[3].fY = bottom;

    // Only positions and texture coordinates are written here; the vertex colours are left as
    // whatever the slot last held.
    quad[0].flU = 0.0f;
    quad[0].flV = 0.0f;
    quad[1].flU = 0.0f;
    quad[1].flV = 1.0f;
    quad[2].flU = 1.0f;
    quad[2].flV = 0.0f;
    quad[3].flU = 1.0f;
    quad[3].flV = 1.0f;

    ++currentPolys;
}

- (void)drawInRect:(CGRect)rect
        fromRegion:(CGRect)region
         transform:(char)transform
             color:(nullable UIColor *)color {
    /** @ghidraAddress 0xe694 */
    if (currentPolys >= kMaxQuads) {
        return;
    }
    SpriteVertex *quad = &vertices[currentPolys * kVerticesPerQuad];
    float left = (float)rect.origin.x;
    float top = (float)rect.origin.y;
    float right = (float)(rect.origin.x + rect.size.width);
    float bottom = (float)(rect.origin.y + rect.size.height);

    quad[0].fX = left;
    quad[0].fY = top;
    quad[1].fX = left;
    quad[1].fY = bottom;
    quad[2].fX = right;
    quad[2].fY = top;
    quad[3].fX = right;
    quad[3].fY = bottom;

    double texSize = (double)_size;
    CGFloat red = 0;
    CGFloat green = 0;
    CGFloat blue = 0;
    CGFloat alpha = 0;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];

    // Only the alpha is clamped; the RGB components are used as-is. A NaN alpha propagates.
    float clampedAlpha = 0.0f;
    if (!((float)alpha < 0.0f)) {
        clampedAlpha = ((float)alpha <= 1.0f) ? (float)alpha : 1.0f;
    }

    float u0 = (float)(region.origin.x / texSize);
    float v0 = (float)(region.origin.y / texSize);
    float u1 = (float)((region.origin.x + region.size.width) / texSize);
    float v1 = (float)((region.origin.y + region.size.height) / texSize);

    // The texture-coordinate permutation matches SetQuadTexCoordsAndAlpha's table exactly; this
    // path inlines it because it also writes a per-channel tint rather than a broadcast alpha.
    switch (transform) {
    case SpriteTransformTranspose:
        quad[0].flU = u0;
        quad[0].flV = v1;
        quad[1].flU = u1;
        quad[1].flV = v1;
        quad[2].flU = u0;
        quad[2].flV = v0;
        quad[3].flU = u1;
        quad[3].flV = v0;
        break;
    case SpriteTransformRotate180:
        quad[0].flU = u1;
        quad[0].flV = v1;
        quad[1].flU = u1;
        quad[1].flV = v0;
        quad[2].flU = u0;
        quad[2].flV = v1;
        quad[3].flU = u0;
        quad[3].flV = v0;
        break;
    case SpriteTransformTransposeFlip:
        quad[0].flU = u1;
        quad[0].flV = v0;
        quad[1].flU = u0;
        quad[1].flV = v0;
        quad[2].flU = u1;
        quad[2].flV = v1;
        quad[3].flU = u0;
        quad[3].flV = v1;
        break;
    case SpriteTransformMirrorV:
        quad[0].flU = u0;
        quad[0].flV = v1;
        quad[1].flU = u0;
        quad[1].flV = v0;
        quad[2].flU = u1;
        quad[2].flV = v1;
        quad[3].flU = u1;
        quad[3].flV = v0;
        break;
    case SpriteTransformMirrorU:
        quad[0].flU = u1;
        quad[0].flV = v0;
        quad[1].flU = u1;
        quad[1].flV = v1;
        quad[2].flU = u0;
        quad[2].flV = v0;
        quad[3].flU = u0;
        quad[3].flV = v1;
        break;
    default:
        quad[0].flU = u0;
        quad[0].flV = v0;
        quad[1].flU = u0;
        quad[1].flV = v1;
        quad[2].flU = u1;
        quad[2].flV = v0;
        quad[3].flU = u1;
        quad[3].flV = v1;
        break;
    }

    uint8_t redByte = (uint8_t)(int)((float)red * kByteScale255);
    uint8_t greenByte = (uint8_t)(int)((float)green * kByteScale255);
    uint8_t blueByte = (uint8_t)(int)((float)blue * kByteScale255);
    uint8_t alphaByte = (uint8_t)(int)(clampedAlpha * kByteScale255);
    uint32_t packed = (uint32_t)redByte | ((uint32_t)greenByte << 8) | ((uint32_t)blueByte << 16) |
                      ((uint32_t)alphaByte << 24);
    quad[0].dwColor = packed;
    quad[1].dwColor = packed;
    quad[2].dwColor = packed;
    quad[3].dwColor = packed;

    ++currentPolys;
}

- (void)drawInRect:(CGRect)rect
        fromRegion:(CGRect)region
         transform:(char)transform
             alpha:(float)alpha {
    /** @ghidraAddress 0xe944 */
    if (currentPolys >= kMaxQuads) {
        return;
    }
    SpriteVertex *quad = &vertices[currentPolys * kVerticesPerQuad];
    float left = (float)rect.origin.x;
    float top = (float)rect.origin.y;
    float right = (float)(rect.origin.x + rect.size.width);
    float bottom = (float)(rect.origin.y + rect.size.height);

    quad[0].fX = left;
    quad[0].fY = top;
    quad[1].fX = left;
    quad[1].fY = bottom;
    quad[2].fX = right;
    quad[2].fY = top;
    quad[3].fX = right;
    quad[3].fY = bottom;

    double texSize = (double)_size;
    SetQuadTexCoordsAndAlpha((float)(region.origin.x / texSize),
                             (float)(region.origin.y / texSize),
                             (float)((region.origin.x + region.size.width) / texSize),
                             (float)((region.origin.y + region.size.height) / texSize),
                             alpha,
                             quad,
                             (SpriteTransform)transform);
    ++currentPolys;
}

- (void)drawSprite:(NSUInteger)sprite
           atPoint:(CGPoint)point
             scale:(float)scale
            rotate:(float)rotate
            anchor:(CGPoint)anchor
         transform:(char)transform
             alpha:(float)alpha {
    /** @ghidraAddress 0xeb28 */
    if (sprite >= (NSUInteger)numSprite || currentPolys >= kMaxQuads) {
        return;
    }
    CGRect source = spriteRect[sprite];

    CGAffineTransform matrix = CGAffineTransformMakeTranslation(anchor.x, anchor.y);
    matrix = CGAffineTransformScale(matrix, (double)scale, (double)scale);
    matrix = CGAffineTransformRotate(matrix, (double)rotate);
    matrix = CGAffineTransformTranslate(matrix, -anchor.x, -anchor.y);

    double drawWidth = source.size.width;
    double drawHeight = source.size.height;
    if (_isScale2x) {
        drawWidth *= kScale2xFactor;
        drawHeight *= kScale2xFactor;
    }

    SpriteVertex *quad = &vertices[currentPolys * kVerticesPerQuad];
    CGPoint corner0 = CGPointApplyAffineTransform(CGPointMake(point.x, point.y), matrix);
    CGPoint corner1 =
        CGPointApplyAffineTransform(CGPointMake(point.x, point.y + drawHeight), matrix);
    CGPoint corner2 =
        CGPointApplyAffineTransform(CGPointMake(point.x + drawWidth, point.y), matrix);
    CGPoint corner3 =
        CGPointApplyAffineTransform(CGPointMake(point.x + drawWidth, point.y + drawHeight), matrix);
    quad[0].fX = (float)corner0.x;
    quad[0].fY = (float)corner0.y;
    quad[1].fX = (float)corner1.x;
    quad[1].fY = (float)corner1.y;
    quad[2].fX = (float)corner2.x;
    quad[2].fY = (float)corner2.y;
    quad[3].fX = (float)corner3.x;
    quad[3].fY = (float)corner3.y;

    double texSize = (double)_size;
    SetQuadTexCoordsAndAlpha((float)(source.origin.x / texSize),
                             (float)(source.origin.y / texSize),
                             (float)((source.origin.x + source.size.width) / texSize),
                             (float)((source.origin.y + source.size.height) / texSize),
                             alpha,
                             quad,
                             (SpriteTransform)transform);
    ++currentPolys;
}

- (void)drawSprite:(NSUInteger)sprite
           atPoint:(CGPoint)point
         transform:(char)transform
             alpha:(float)alpha {
    /** @ghidraAddress 0xedb8 */
    if (sprite >= (NSUInteger)numSprite) {
        return;
    }
    CGRect source = spriteRect[sprite];
    double drawWidth = source.size.width;
    double drawHeight = source.size.height;
    // A transposing transform (mode 1 or 3, a 90-degree rotation) swaps the drawn width and
    // height; any other mode keeps them.
    if ((((unsigned int)transform) | 2) == 3) {
        double swap = drawWidth;
        drawWidth = drawHeight;
        drawHeight = swap;
    }
    if (_isScale2x) {
        drawWidth *= kScale2xFactor;
        drawHeight *= kScale2xFactor;
    }
    [self drawInRect:CGRectMake(point.x, point.y, drawWidth, drawHeight)
          fromRegion:source
           transform:transform
               alpha:alpha];
}

- (void)drawSprite:(NSUInteger)sprite
            inRect:(CGRect)rect
         transform:(char)transform
             alpha:(float)alpha {
    /** @ghidraAddress 0xee48 */
    if (sprite >= (NSUInteger)numSprite) {
        return;
    }
    [self drawInRect:rect fromRegion:spriteRect[sprite] transform:transform alpha:alpha];
}

- (void)drawSprite:(NSUInteger)sprite atPoint:(CGPoint)point {
    /** @ghidraAddress 0xeea4 */
    if (sprite >= (NSUInteger)numSprite) {
        return;
    }
    CGRect source = spriteRect[sprite];
    double drawWidth = source.size.width;
    double drawHeight = source.size.height;
    if (_isScale2x) {
        drawWidth *= kScale2xFactor;
        drawHeight *= kScale2xFactor;
    }
    [self drawInRect:CGRectMake(point.x, point.y, drawWidth, drawHeight)
          fromRegion:source
           transform:SpriteTransformNone
               alpha:1.0f];
}

- (void)drawSprite:(NSUInteger)sprite inRect:(CGRect)rect color:(nullable UIColor *)color {
    /** @ghidraAddress 0xef24 */
    if (sprite >= (NSUInteger)numSprite) {
        return;
    }
    [self drawInRect:rect fromRegion:spriteRect[sprite] transform:SpriteTransformNone color:color];
}

- (void)drawSprite:(NSUInteger)sprite inRect:(CGRect)rect {
    /** @ghidraAddress 0xef64 */
    if (sprite >= (NSUInteger)numSprite) {
        return;
    }
    [self drawInRect:rect fromRegion:spriteRect[sprite] transform:SpriteTransformNone alpha:1.0f];
}

- (void)commitDraw {
    /** @ghidraAddress 0xefc0 */
    if (currentPolys == 0) {
        return;
    }
    glVertexPointer(2, GL_FLOAT, sizeof(SpriteVertex), vertices);
    glTexCoordPointer(2, GL_FLOAT, sizeof(SpriteVertex), &vertices->flU);
    glColorPointer(4, GL_UNSIGNED_BYTE, sizeof(SpriteVertex), &vertices->dwColor);
    glBindTexture(GL_TEXTURE_2D, _name);

    BOOL clipped = !CGRectIsNull(_clipRect);
    if (clipped) {
        glScissor((int)_clipRect.origin.x,
                  (int)_clipRect.origin.y,
                  (int)_clipRect.size.width,
                  (int)_clipRect.size.height);
        glEnable(GL_SCISSOR_TEST);
    }
    glDrawElements(
        GL_TRIANGLES, (GLsizei)(currentPolys * kIndicesPerQuad), GL_UNSIGNED_SHORT, nullptr);
    if (clipped) {
        glDisable(GL_SCISSOR_TEST);
    }
    currentPolys = 0;
}

- (void)resetDrawBuffer {
    /** @ghidraAddress 0xf0cc */
    currentPolys = 0;
}

#pragma mark - Sprite table

- (void)setSprites:(nullable NSArray<NSArray<NSNumber *> *> *)sprites {
    /** @ghidraAddress 0xf0dc */
    if (!sprites || sprites.count == 0) {
        return;
    }
    if (spriteRect) {
        free(spriteRect);
    }
    spriteRect = (CGRect *)malloc(sprites.count * sizeof(CGRect));

    int index = 0;
    for (NSArray<NSNumber *> *entry in sprites) {
        spriteRect[index] = CGRectMake((double)[entry[0] integerValue],
                                       (double)[entry[1] integerValue],
                                       (double)[entry[2] integerValue],
                                       (double)[entry[3] integerValue]);
        ++index;
    }
    numSprite = index;
}

- (CGRect)spriteAtIndex:(unsigned int)index {
    /** @ghidraAddress 0xf3a0 */
    if (index < (unsigned int)numSprite) {
        CGRect rect = spriteRect[index];
        if (_isScale2x) {
            rect.origin.x *= kScale2xFactor;
            rect.origin.y *= kScale2xFactor;
            rect.size.width *= kScale2xFactor;
            rect.size.height *= kScale2xFactor;
        }
        return rect;
    }
    return CGRectZero;
}

- (void)setClipRect:(CGRect)rect {
    /** @ghidraAddress 0xf40c */
    CGFloat screenHeight = (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) ?
                               kScreenHeightPad :
                               kScreenHeightPhone;
    // Flip the origin into GL's bottom-left space; the scissor's height and width are unchanged.
    _clipRect = CGRectMake(rect.origin.x,
                           screenHeight - rect.size.height - rect.origin.y,
                           rect.size.width,
                           rect.size.height);
}

#pragma mark - Teardown

- (void)dealloc {
    /** @ghidraAddress 0xf4b4 */
    if (vertices) {
        free(vertices);
    }
    if (_name != 0) {
        glDeleteTextures(1, &_name);
    }
    if (spriteRect) {
        free(spriteRect);
    }
}

@end
