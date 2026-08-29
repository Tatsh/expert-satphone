/**
 * @file
 * @brief The engine's sprite-sheet texture: a single OpenGL ES texture that batches many sprite
 * quads into one draw call.
 *
 * Reconstructed from Ghidra program Jubeat (class Texture2D, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * A @c Texture2D owns one GL texture (@c _name), a growable vertex scratch buffer, and a table of
 * sub-rectangles ("sprites") packed into the texture. Callers append quads with the @c drawSprite ,
 * @c drawInRect , and @c drawAtPoint families, then flush the whole batch with @c -commitDraw ,
 * which issues a single @c glDrawElements over the shared element-array buffer the @c EAGLView
 * binds. The interleaved vertex layout and the texture-coordinate helper live in the shared
 * @c sprite_vertex.h , used only by the implementation.
 */

#import <Foundation/Foundation.h>
#import <OpenGLES/gltypes.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The internal storage format of a texture, chosen when its pixels are uploaded.
 *
 * Backed by @c NSUInteger to match the @c Q -encoded @c pixelFormat ivar. The name is inferred
 * from the GL formats each value selects in @c -setData:pixelFormat:pixelSize:width:height: rather
 * than confirmed against runtime metadata.
 */
typedef NS_ENUM(NSUInteger, Texture2DPixelFormat) {
    Texture2DPixelFormatRGBA8888 = 1, /*!< Four bytes per pixel, uploaded as @c GL_RGBA . */
    Texture2DPixelFormatRGB888 = 2,   /*!< Three bytes per pixel, uploaded as @c GL_RGB . */
    Texture2DPixelFormatA8 = 3,       /*!< One byte per pixel, uploaded as @c GL_ALPHA . */
};

/**
 * @brief A texture that can draw any of the sprites packed into it.
 */
@interface Texture2D : NSObject

/**
 * @brief Scales a rectangle about an anchor point.
 *
 * The origin moves towards @p anchor as @p scale shrinks, and the size scales directly:
 * @c origin = anchor + (rect.origin - anchor) * scale , @c size = rect.size * scale .
 *
 * @param rect The rectangle to scale.
 * @param scale The scale factor.
 * @param anchor The fixed point the scaling is centred on.
 * @return The scaled rectangle.
 * @ghidraAddress 0xdc4c
 */
+ (CGRect)scaledRect:(CGRect)rect scale:(double)scale anchor:(CGPoint)anchor;

/**
 * @brief Initialises an empty texture with no GL name and a null clip rectangle.
 * @return The initialised texture.
 * @ghidraAddress 0xdc70
 */
- (instancetype)init;

/**
 * @brief Uploads pixel data into the texture, (re)creating its GL name.
 *
 * Deletes any existing GL texture, generates a fresh one, sets linear filtering and repeat
 * wrapping, then uploads a @p pixelSize by @p pixelSize image in @p pixelFormat . The content
 * dimensions @p width and @p height are recorded separately from the (square) texture size.
 *
 * @param data The pixel bytes.
 * @param pixelFormat The storage format.
 * @param pixelSize The square texture dimension in texels.
 * @param width The content width.
 * @param height The content height.
 * @ghidraAddress 0xdcd4
 */
- (void)setData:(nullable const void *)data
    pixelFormat:(Texture2DPixelFormat)pixelFormat
      pixelSize:(GLuint)pixelSize
          width:(int)width
         height:(int)height;

/**
 * @brief Uploads a square image, using @p pixelSize as both the texture size and the content size.
 * @param data The pixel bytes.
 * @param pixelFormat The storage format.
 * @param pixelSize The square texture dimension in texels.
 * @ghidraAddress 0xde88
 */
- (void)setData:(nullable const void *)data
    pixelFormat:(Texture2DPixelFormat)pixelFormat
      pixelSize:(GLuint)pixelSize;

/**
 * @brief Initialises a texture and uploads pixel data into it.
 * @param data The pixel bytes.
 * @param pixelFormat The storage format.
 * @param pixelSize The square texture dimension in texels.
 * @param width The content width.
 * @param height The content height.
 * @return The initialised texture.
 * @ghidraAddress 0xde9c
 */
- (instancetype)initWithData:(nullable const void *)data
                 pixelFormat:(Texture2DPixelFormat)pixelFormat
                   pixelSize:(GLuint)pixelSize
                       width:(int)width
                      height:(int)height;

/**
 * @brief Initialises a square texture, using @p pixelSize as both the texture and content size.
 * @param data The pixel bytes.
 * @param pixelFormat The storage format.
 * @param pixelSize The square texture dimension in texels.
 * @return The initialised texture.
 * @ghidraAddress 0xdf58
 */
- (instancetype)initWithData:(nullable const void *)data
                 pixelFormat:(Texture2DPixelFormat)pixelFormat
                   pixelSize:(GLuint)pixelSize;

/**
 * @brief Initialises a texture from a @c UIImage , rasterising it into a power-of-two buffer.
 *
 * Picks a storage format from the image's alpha info and colour space, rounds the larger image
 * dimension up to a power of two, and halves that (and the content dimensions) while it exceeds
 * @c GL_MAX_TEXTURE_SIZE . The image is drawn bottom-aligned into a fresh bitmap context, which is
 * then uploaded via @c -initWithData:pixelFormat:pixelSize:width:height: .
 *
 * @param image The source image.
 * @return The initialised texture, or @c nil if @p image is @c nil or rounds to a zero size.
 * @ghidraAddress 0xdf6c
 */
- (instancetype)initWithImage:(nullable UIImage *)image;

/**
 * @brief Replaces a sub-rectangle of the texture with an image's pixels.
 *
 * Rasterises @p image into a bitmap context matching the texture's pixel format, then uploads it
 * with @c glTexSubImage2D at @p rect .
 *
 * @param image The source image.
 * @param rect The destination rectangle in texels.
 * @ghidraAddress 0xe2dc
 */
- (void)setSubImage:(nullable UIImage *)image inRect:(CGRect)rect;

/**
 * @brief Replaces a sub-region of the texture with an image drawn at its own size.
 * @param image The source image.
 * @param point The destination origin in texels.
 * @ghidraAddress 0xe52c
 */
- (void)setSubImage:(nullable UIImage *)image atPoint:(CGPoint)point;

/**
 * @brief Appends a quad drawing the whole texture at @p point , scaled by @p scale .
 *
 * The quad spans @c _size * scale texels from @p point . Only the positions and texture
 * coordinates are written; the vertex colours are left as whatever the slot last held.
 *
 * @param point The top-left corner to draw at.
 * @param scale The uniform scale factor.
 * @ghidraAddress 0xe5e4
 */
- (void)drawAtPoint:(CGPoint)point scale:(double)scale;

/**
 * @brief Appends a quad drawing a texture region into a rectangle, tinted by a colour.
 *
 * @param rect The destination rectangle.
 * @param region The source region in texels.
 * @param transform The texture-coordinate orientation, 0..5.
 * @param color The tint colour; its RGBA is multiplied into the vertices.
 * @ghidraAddress 0xe694
 */
- (void)drawInRect:(CGRect)rect
        fromRegion:(CGRect)region
         transform:(char)transform
             color:(nullable UIColor *)color;

/**
 * @brief Appends a quad drawing a texture region into a rectangle at a given alpha.
 *
 * @param rect The destination rectangle.
 * @param region The source region in texels.
 * @param transform The texture-coordinate orientation, 0..5.
 * @param alpha The opacity, clamped to 0..1.
 * @ghidraAddress 0xe944
 */
- (void)drawInRect:(CGRect)rect
        fromRegion:(CGRect)region
         transform:(char)transform
             alpha:(float)alpha;

/**
 * @brief Appends a quad for one packed sprite, with a scale, a rotation about an anchor, and an
 *        alpha.
 *
 * The scale, rotation, and alpha are @c float ; @p transform is a @c char . The four corner
 * positions are produced by a translate/scale/rotate/translate affine transform about @p anchor .
 *
 * @param sprite The sprite index.
 * @param point Where to draw it.
 * @param scale The draw scale.
 * @param rotate The rotation in radians.
 * @param anchor The point to rotate about.
 * @param transform The texture-coordinate orientation, 0..5.
 * @param alpha The opacity.
 * @ghidraAddress 0xeb28
 */
- (void)drawSprite:(NSUInteger)sprite
           atPoint:(CGPoint)point
             scale:(float)scale
            rotate:(float)rotate
            anchor:(CGPoint)anchor
         transform:(char)transform
             alpha:(float)alpha;

/**
 * @brief Appends a quad for one packed sprite at a point, at its own size.
 *
 * A transposing @p transform (mode 1 or 3, a 90-degree rotation) swaps the sprite's width and
 * height to produce the draw size; any other value uses them as they are.
 *
 * @param sprite The sprite index.
 * @param point Where to draw it.
 * @param transform The texture-coordinate orientation, 0..5.
 * @param alpha The opacity.
 * @ghidraAddress 0xedb8
 */
- (void)drawSprite:(NSUInteger)sprite
           atPoint:(CGPoint)point
         transform:(char)transform
             alpha:(float)alpha;

/**
 * @brief Appends a quad for one packed sprite stretched into a rectangle.
 * @param sprite The sprite index.
 * @param rect Where to draw it.
 * @param transform The texture-coordinate orientation, 0..5.
 * @param alpha The opacity.
 * @ghidraAddress 0xee48
 */
- (void)drawSprite:(NSUInteger)sprite
            inRect:(CGRect)rect
         transform:(char)transform
             alpha:(float)alpha;

/**
 * @brief Appends a quad for one packed sprite at a point, at its own size, opaque and unrotated.
 * @param sprite The sprite index.
 * @param point Where to draw it.
 * @ghidraAddress 0xeea4
 */
- (void)drawSprite:(NSUInteger)sprite atPoint:(CGPoint)point;

/**
 * @brief Appends a quad for one packed sprite stretched into a rectangle, tinted by a colour.
 * @param sprite The sprite index.
 * @param rect Where to draw it.
 * @param color The tint colour.
 * @ghidraAddress 0xef24
 */
- (void)drawSprite:(NSUInteger)sprite inRect:(CGRect)rect color:(nullable UIColor *)color;

/**
 * @brief Appends a quad for one packed sprite stretched into a rectangle, opaque and unrotated.
 * @param sprite The sprite index.
 * @param rect Where to draw it.
 * @ghidraAddress 0xef64
 */
- (void)drawSprite:(NSUInteger)sprite inRect:(CGRect)rect;

/**
 * @brief Flushes every batched quad in one @c glDrawElements , honouring the clip rectangle.
 *
 * Points the fixed-function vertex, texture-coordinate, and colour pointers at the interleaved
 * scratch buffer, binds the texture, enables a scissor from @c _clipRect unless it is null, draws
 * @c currentPolys * 6 indices as triangles, then resets the batch.
 * @ghidraAddress 0xefc0
 */
- (void)commitDraw;

/**
 * @brief Discards every batched quad without drawing.
 * @ghidraAddress 0xf0cc
 */
- (void)resetDrawBuffer;

/**
 * @brief Replaces the sprite table from an array of four-element rectangle descriptions.
 *
 * Each element of @p sprites is itself an array of four @c NSNumber values giving the sprite's
 * @c x , @c y , @c width , and @c height in texels.
 *
 * @param sprites The sprite rectangles, as arrays of four numbers each.
 * @ghidraAddress 0xf0dc
 */
- (void)setSprites:(nullable NSArray<NSArray<NSNumber *> *> *)sprites;

/**
 * @brief Returns the rectangle of one packed sprite, halved when @c isScale2x is set.
 * @param index The sprite index.
 * @return The sprite rectangle, or @c CGRectZero if @p index is out of range.
 * @ghidraAddress 0xf3a0
 */
- (CGRect)spriteAtIndex:(unsigned int)index;

/**
 * @brief Sets the scissor clip rectangle, flipping it into GL's bottom-left coordinate space.
 *
 * The vertical flip uses the current device idiom's screen height (480 on a phone, 1024 on a pad).
 *
 * @param rect The clip rectangle in top-left UIKit coordinates.
 * @ghidraAddress 0xf40c
 */
- (void)setClipRect:(CGRect)rect;

/**
 * @brief Whether packed sprites are treated as 2x-supersampled and drawn at half size.
 * @ghidraAddress 0xf53c (getter), 0xf54c (setter)
 */
@property(nonatomic) BOOL isScale2x;

/**
 * @brief The GL texture name, or 0 when no data has been uploaded.
 * @ghidraAddress 0xf55c
 */
@property(nonatomic, readonly) GLuint name;

/**
 * @brief The content width in texels.
 * @ghidraAddress 0xf56c
 */
@property(nonatomic, readonly) NSUInteger width;

/**
 * @brief The content height in texels.
 * @ghidraAddress 0xf57c
 */
@property(nonatomic, readonly) NSUInteger height;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
