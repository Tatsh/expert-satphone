#import "TextureLoading.h"

// The image extensions these loaders resolve, from the CFStrings at 0x2d8620 (png) and 0x2d8600
// (tex), and the sprite-rect plist extension at 0x2d4160.
static NSString *const kPngExtension = @"png";
static NSString *const kTexExtension = @"tex";
static NSString *const kPlistExtension = @"plist";

// Every encrypted image payload is preceded by a fixed four-byte header that the decoders drop
// before handing the bytes to UIImage.
static const NSUInteger kEncryptedImageHeaderLength = 4;

UIImage *CreateImageFromEncryptedData(BFCodec *cipher, NSMutableData *encryptedData) {
    if (![cipher decipher:encryptedData]) {
        return nil;
    }
    const uint8_t *payloadBytes =
        (const uint8_t *)encryptedData.bytes + kEncryptedImageHeaderLength;
    NSData *payload =
        [[NSData alloc] initWithBytes:payloadBytes
                               length:encryptedData.length - kEncryptedImageHeaderLength];
    return [UIImage imageWithData:payload];
}

BOOL LoadTextureSubImageFromResource(Texture2D *texture, NSString *resourceName, CGPoint point) {
    NSString *path = [NSBundle.mainBundle pathForResource:resourceName ofType:kPngExtension];
    if (path == nil) {
        return NO;
    }
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:path];
    [texture setSubImage:image atPoint:point];
    return YES;
}

BOOL LoadTextureSubImageFromEncryptedTex(Texture2D *texture,
                                         NSString *resourceName,
                                         BFCodec *cipher,
                                         CGPoint point) {
    NSString *path = [NSBundle.mainBundle pathForResource:resourceName ofType:kTexExtension];
    if (path == nil) {
        return NO;
    }
    NSMutableData *data = [[NSMutableData alloc] initWithContentsOfFile:path];
    if (![cipher decipher:data]) {
        return NO;
    }
    const uint8_t *payloadBytes = (const uint8_t *)data.bytes + kEncryptedImageHeaderLength;
    NSData *payload = [[NSData alloc] initWithBytes:payloadBytes
                                             length:data.length - kEncryptedImageHeaderLength];
    UIImage *image = [[UIImage alloc] initWithData:payload];
    if (image == nil) {
        return NO;
    }
    [texture setSubImage:image atPoint:point];
    return YES;
}

Texture2D *CreateTexture2DFromPngResource(NSString *resourceName) {
    NSString *pngPath = [NSBundle.mainBundle pathForResource:resourceName ofType:kPngExtension];
    if (pngPath == nil) {
        return nil;
    }
    Texture2D *texture =
        [[Texture2D alloc] initWithImage:[[UIImage alloc] initWithContentsOfFile:pngPath]];

    NSString *plistPath = [NSBundle.mainBundle pathForResource:resourceName ofType:kPlistExtension];
    if (plistPath == nil) {
        // A missing sprite plist fails the whole load even though the PNG decoded fine.
        return nil;
    }
    [texture setSprites:[[NSArray alloc] initWithContentsOfFile:plistPath]];
    return texture;
}

Texture2D *CreateTexture2DFromEncryptedTexResource(NSString *resourceName, BFCodec *cipher) {
    NSString *texPath = [NSBundle.mainBundle pathForResource:resourceName ofType:kTexExtension];
    if (texPath == nil) {
        return nil;
    }
    NSMutableData *data = [[NSMutableData alloc] initWithContentsOfFile:texPath];
    if (![cipher decipher:data]) {
        return nil;
    }
    const uint8_t *payloadBytes = (const uint8_t *)data.bytes + kEncryptedImageHeaderLength;
    NSData *payload = [[NSData alloc] initWithBytes:payloadBytes
                                             length:data.length - kEncryptedImageHeaderLength];
    UIImage *image = [[UIImage alloc] initWithData:payload];
    if (image == nil) {
        return nil;
    }
    Texture2D *texture = [[Texture2D alloc] initWithImage:image];

    // The sprite-rect plist is read unencrypted even though the image itself was enciphered.
    NSString *plistPath = [NSBundle.mainBundle pathForResource:resourceName ofType:kPlistExtension];
    if (plistPath == nil) {
        return nil;
    }
    [texture setSprites:[[NSArray alloc] initWithContentsOfFile:plistPath]];
    return texture;
}
