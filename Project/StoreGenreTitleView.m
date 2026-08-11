#import "StoreGenreTitleView.h"

#import "JubeatAppDelegate.h"

// The heading's own backdrop: white at seven tenths, behind whatever banner arrives.
static const CGFloat kBackgroundWhite = 1.0;
static const CGFloat kBackgroundAlpha = 0.7f; // @ghidraAddress 0x291c98

// Both labels share a left edge and a width.
static const CGFloat kLabelX = 10.0;
static const CGFloat kLabelWidthInset = -20.0;

// The title, which only the pad has.
static const CGFloat kTitleY = 4.0;
static const CGFloat kTitleFontSize = 20.0;
enum {
    // The title takes a share of the height left after this margin.
    kTitleHeightMargin = 12,
    kTitleDivisorPad = 2,
    kTitleDivisorPhone = 3,
    // How far below the title the comment starts.
    kCommentGap = 4,
};

// The comment, which both have.
static const CGFloat kCommentYPhone = 4.0;
static const CGFloat kCommentHeightInset = -4.0;
enum {
    kCommentLinesPad = 2,
    kCommentLinesPhone = 5,
};

// The banner fades in over this long, linearly.
static const NSTimeInterval kBannerFadeDuration = 0.2;

// The phone's comment is given this much room before -sizeToFit shrinks it back.
static const CGFloat kCommentInitialHeightPhone = 200.0; // @ghidraAddress 0x28f400

// The heading reports its own height with this much added below.
static const int kHeadingBottomPadding = 12;

@implementation StoreGenreTitleView {
    BOOL isPad;
    UIImageView *bgImageView;
    int canvasHeight;
    UILabel *title;
    UILabel *comment;
    Downloader *imgDownloader;
    NSCache *bgImageCache;
    NSString *imgURL;
}

/** @ghidraAddress 0x1b37b8 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:kBackgroundWhite alpha:kBackgroundAlpha];

        isPad = JubeatAppDelegate.appDelegate.isPad;

        // Only the pad gets a banner at all. It starts fully transparent, so the first
        // -setBannerImage: has something to fade in.
        if (isPad) {
            bgImageView = [[UIImageView alloc]
                initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
            bgImageView.alpha = 0;
            [self addSubview:bgImageView];
        }

        canvasHeight = (int)frame.size.height;

        // Both are computed here, but the divisor is only ever read inside the pad arm below — the
        // phone's value of three is worked out and discarded.
        int titleDivisor = isPad ? kTitleDivisorPad : kTitleDivisorPhone;
        int commentLines = isPad ? kCommentLinesPad : kCommentLinesPhone;

        CGFloat labelWidth = frame.size.width + kLabelWidthInset;
        CGFloat commentY;

        if (isPad) {
            int titleHeight = (canvasHeight - kTitleHeightMargin) / titleDivisor;
            title = [[UILabel alloc]
                initWithFrame:CGRectMake(kLabelX, kTitleY, labelWidth, titleHeight)];
            title.textAlignment = NSTextAlignmentCenter;
            title.font = [UIFont boldSystemFontOfSize:kTitleFontSize];
            [self addSubview:title];
            commentY = titleHeight + kCommentGap;
        } else {
            // No title label is built at all, so the phone's comment carries everything.
            commentY = kCommentYPhone;
        }

        comment = [[UILabel alloc]
            initWithFrame:CGRectMake(kLabelX,
                                     commentY,
                                     labelWidth,
                                     (frame.size.height - commentY) + kCommentHeightInset)];
        comment.textAlignment = NSTextAlignmentCenter;
        comment.numberOfLines = commentLines;
        comment.lineBreakMode = NSLineBreakByWordWrapping;
        [self addSubview:comment];

        imgDownloader = nil;
        bgImageCache = [[NSCache alloc] init];
    }
    return self;
}

/** @ghidraAddress 0x1b3b3c */
- (int)setGenreTitleInfo:(StorePackListGenre *)info {
    // Each field is fetched once to test and again to use, throughout this method.
    if (info.genreName) {
        title.text = info.genreName;
    }

    UIColor *background = info.genreBGColor;
    if (!background) {
        background = [UIColor colorWithWhite:kBackgroundWhite alpha:kBackgroundAlpha];
    }
    self.backgroundColor = background;

    if (isPad) {
        // Cleared first, so a genre with no banner does not keep the previous one.
        bgImageView.image = nil;
        imgURL = info.genreBgImageURL;
        // An empty string is rejected as well as nil.
        if (imgURL && ![imgURL isEqualToString:@""]) {
            if ([bgImageCache objectForKey:imgURL]) {
                [self setBannerImage:[bgImageCache objectForKey:imgURL]];
            } else {
                // Any fetch still running is abandoned before a new one starts, which is what
                // makes -downloaderFinished:'s identity guard meaningful.
                if (imgDownloader) {
                    [imgDownloader cancel];
                    imgDownloader = nil;
                }
                imgDownloader = [[Downloader alloc] initWithURL:[NSURL URLWithString:imgURL]
                                                       delegate:self];
                [imgDownloader startDownloading];
            }
        }
    }

    if (!isPad) {
        // Given a deliberately generous height for -sizeToFit to shrink below; the origin is kept.
        CGRect current = comment.frame;
        comment.frame = CGRectMake(current.origin.x,
                                   current.origin.y,
                                   self.frame.size.width + kLabelWidthInset,
                                   kCommentInitialHeightPhone);
    }

    if (info.genreComment) {
        comment.text = info.genreComment;
    } else {
        comment.text = @"";
    }

    CGFloat titleHeight = 0;
    if (!isPad) {
        [comment sizeToFit];
        // The only early return, and it reports no height rather than the padding.
        if (!info.genreComment) {
            return 0;
        }
        // Centred horizontally against the heading, keeping the fitted size.
        CGRect fitted = comment.frame;
        comment.frame = CGRectMake((self.frame.size.width - fitted.size.width) * 0.5,
                                   fitted.origin.y,
                                   fitted.size.width,
                                   fitted.size.height);
    } else {
        // Truncated to a whole point. The binary adds a literal zero first, which changes nothing.
        titleHeight = (int)(title.frame.size.height + 0.0);
    }

    // The heading's required height, for the caller to lay the list out with.
    return (int)(titleHeight + comment.frame.size.height) + kHeadingBottomPadding;
}

/** @ghidraAddress 0x1b3ff0 */
- (void)setBannerImage:(UIImage *)image {
    bgImageView.image = image;

    __weak UIImageView *weakBanner = bgImageView;
    // Reset to invisible first, so the fade runs from zero however many times this is called.
    bgImageView.alpha = 0;
    [UIView
        animateWithDuration:kBannerFadeDuration
                      delay:0
                    options:UIViewAnimationOptionCurveLinear
                 animations:^{
                   /** @ghidraAddress 0x1b4128 */
                   weakBanner.alpha = 1.0;
                 }
                 completion:^(BOOL __attribute__((unused)) finished){
                     /** @ghidraAddress 0x1b4174 */
                     // Empty, and a global block because of it — the binary's body is a single ret.
                 }];
}

/** @ghidraAddress 0x1b4178 */
- (void)downloaderFinished:(id)downloader {
    // Anything but the fetch this view started is ignored outright, rather than merely being
    // handled and discarded.
    if (imgDownloader != downloader) {
        return;
    }

    UIImage *image = [[UIImage alloc] initWithData:[downloader getData]];
    if (image) {
        [self setBannerImage:image];
        [bgImageCache setObject:image forKey:imgURL];
    }
    // imgDownloader is not cleared here, so the identity guard above keeps matching this same
    // downloader until something else replaces it.
}

@end
