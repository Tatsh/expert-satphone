#import "StoreImageView.h"

// Above this the fetched bytes have to be re-wrapped at the screen's scale.
static const CGFloat kNonRetinaScale = 1.0;

@implementation StoreImageView

/** @ghidraAddress 0xd1c14 */
- (void)startDownloadImage {
    if (!self.imageURL) {
        return;
    }
    // The downloader is the busy flag: a second call while one is running does nothing.
    if (self.imageDownloader) {
        return;
    }

    self.imageDownloader = [[Downloader alloc] initWithURL:[NSURL URLWithString:self.imageURL]
                                                  delegate:self];
    [self.imageDownloader startDownloading];
}

/** @ghidraAddress 0xd1d74 */
- (void)unloadImage:(UIImage *)image {
    if (self.imageDownloader) {
        [self.imageDownloader cancel];
        self.imageDownloader = nil;
    }
    self.image = image;
}

/** @ghidraAddress 0xd1e24 */
- (void)downloaderFinished:(id)downloader {
    // The downloader is read back from the property rather than from the argument, even though the
    // two are the same object here.
    UIImage *image = [[UIImage alloc] initWithData:self.imageDownloader.getData];
    if (image) {
        if (UIScreen.mainScreen.scale > kNonRetinaScale) {
            // -initWithData: always decodes at scale 1, so on a Retina screen the same pixels have
            // to be re-wrapped at the real scale or they draw at twice their intended size. The
            // screen and its scale are fetched a second time to do it.
            self.image = [UIImage imageWithCGImage:image.CGImage
                                             scale:UIScreen.mainScreen.scale
                                       orientation:UIImageOrientationUp];
        } else {
            self.image = image;
        }
    }
    self.imageDownloader = nil;
}

/** @ghidraAddress 0xd1fd8 */
- (void)downloaderError:(id)downloader {
    // Yes, that is the whole body: the failure is not reported and the view keeps its old image.
    self.imageDownloader = nil;
}

/** @ghidraAddress 0xd1fe8 */
- (void)dealloc {
    // Sent unconditionally — to nil when no fetch is running, which is harmless.
    [self.imageDownloader cancel];
}

@end
