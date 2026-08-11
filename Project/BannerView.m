#import "BannerView.h"

@implementation BannerView {
    NSURLSessionDataTask *task;
}

/** @ghidraAddress 0x1bae8c */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.opaque = NO;
        // The plate shows through as grey until the artwork arrives.
        self.backgroundColor = UIColor.grayColor;

        // Sized from the receiver's own bounds rather than from the frame argument.
        _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        _imageView.opaque = NO;
        _imageView.backgroundColor = UIColor.clearColor;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.userInteractionEnabled = NO;
        // Aspect-fill overflows, so the clip is what keeps the artwork inside the plate.
        _imageView.clipsToBounds = YES;
        [self addSubview:_imageView];
    }
    return self;
}

/** @ghidraAddress 0x1bb028 */
- (void)setCornerRadius:(CGFloat)cornerRadius {
    // Both layers, since the image view clips to its own bounds and would otherwise square off
    // the corners the plate had just rounded.
    self.layer.cornerRadius = cornerRadius;
    _imageView.layer.cornerRadius = cornerRadius;
}

/** @ghidraAddress 0x1bb0c0 */
- (void)loadImageWithSession:(NSURLSession *)session {
    NSURL *url = [NSURL URLWithString:self.promotion.imageURL];
    if (url == nil) {
        return;
    }

    // Captured weakly, so a banner released while the fetch is in flight does not keep its image
    // view alive. The binary uses objc_initWeak here and objc_loadWeakRetained at the far end.
    __weak UIImageView *weakImageView = self.imageView;
    task = [session dataTaskWithURL:url
                  completionHandler:^(NSData *data,
                                      NSURLResponse *__attribute__((unused)) response,
                                      NSError *__attribute__((unused)) error) {
                    /** @ghidraAddress 0x1bb264 */
                    // Yes, response and error are both ignored: a failed request simply yields no
                    // image and the grey plate stays.
                    UIImage *image = [UIImage imageWithData:data scale:UIScreen.mainScreen.scale];
                    if (image != nil) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                          /** @ghidraAddress 0x1bb37c */
                          weakImageView.image = image;
                        });
                    }
                  }];
    [task resume];
}

@end
