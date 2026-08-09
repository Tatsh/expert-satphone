#import "ArtworkLoader.h"

#import "BFCodec.h"
#import "KUnzip.h"
#import "LabUtilities.h"

// The archives carry a fixed header before the entries proper.
enum { kArchiveHeaderLength = 16 };

// The two entries an archive holds, one per size.
static NSString *const kBigArtworkEntry = @"artwork";
static NSString *const kSmallArtworkEntry = @"artwork_s";

@implementation ArtworkLoader {
    NSString *filePath;
    CGSize _size;
    BOOL big_artwork;
}

/** @ghidraAddress 0x934f8 */
- (instancetype)initWithPath:(NSString *)path
                      tuneID:(unsigned int)tuneID
                    indexRow:(int)indexRow
                        size:(CGSize)size
                  bigArtwork:(BOOL)bigArtwork {
    self = [super init];
    if (self) {
        filePath = path;
        _tuneID = tuneID;
        _size = size;
        _indexRow = indexRow;
        big_artwork = bigArtwork;
    }
    return self;
}

/** @ghidraAddress 0x935d8 */
- (instancetype)initWithPath:(NSString *)path
                      tuneID:(unsigned int)tuneID
                        size:(CGSize)size
                  bigArtwork:(BOOL)bigArtwork {
    self = [super init];
    if (self) {
        filePath = path;
        _tuneID = tuneID;
        _size = size;
        big_artwork = bigArtwork;
        // _indexRow is not written here at all, so it keeps the zero the allocation left.
    }
    return self;
}

/** @ghidraAddress 0x936a8 */
- (UIImage *)shrinkImage:(UIImage *)image {
    CGImageRef source = image.CGImage;

    // Everything but the dimensions is copied from the source, so the redraw cannot change the
    // pixel format.
    CGContextRef context = CGBitmapContextCreate(nullptr,
                                                 (size_t)_size.width,
                                                 (size_t)_size.height,
                                                 CGImageGetBitsPerComponent(source),
                                                 CGImageGetBytesPerRow(source),
                                                 CGImageGetColorSpace(source),
                                                 CGImageGetBitmapInfo(source));
    CGContextSetInterpolationQuality(context, kCGInterpolationMedium);
    CGContextDrawImage(context, CGRectMake(0, 0, _size.width, _size.height), source);

    CGImageRef shrunk = CGBitmapContextCreateImage(context);
    CGContextRelease(context);

    UIImage *result = [UIImage imageWithCGImage:shrunk];
    CGImageRelease(shrunk);
    return result;
}

/** @ghidraAddress 0x937d8 */
- (void)loadArtwork {
    // The whole body is inside its own pool, which is what a caller running this off the main
    // thread needs.
    @autoreleasepool {
        if (!filePath) {
            return;
        }

        KUnzip *archive = [[KUnzip alloc] initWithPath:filePath tail:kArchiveHeaderLength];
        if (archive) {
            NSMutableData *data =
                [archive uncompress:(big_artwork ? kBigArtworkEntry : kSmallArtworkEntry)];
            if (data) {
                BFCodec *codec = [[BFCodec alloc] init];
                [codec cipherInit:GetBgmCipherKey()];
                // In place: the same object goes on to -initWithData: below, and the call's own
                // result is not used.
                [codec decipher:data];

                UIImage *artwork = [[UIImage alloc] initWithData:data];
                if (artwork) {
                    // Only ever shrunk, never grown: a source narrower than the requested size is
                    // used as it is.
                    if (_size.width < artwork.size.width) {
                        artwork = [self shrinkImage:artwork];
                    }
                    self.image = artwork;
                }
            }
        }

        // Reached whether or not the archive opened. What decides is whether an image came out,
        // not whether this call produced it — a loader that already had one still reports.
        if (self.image) {
            [self.delegate imageDataLoaded:self];
        }
    }
}

/** @ghidraAddress 0x93a18 */
- (void)dealloc {
    // The delegate is weak, so ARC would clear it anyway. The binary does it explicitly.
    self.delegate = nil;
}

@end
