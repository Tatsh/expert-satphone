#import "StoreDetailHeaderView.h"

#import <QuartzCore/QuartzCore.h>

#import "ImageCache.h"
#import "ImageLoading.h"
#import "StoreUtil.h"

// Builds a vertically-flipped, gradient-faded reflection of an image; a free function not
// reconstructed yet. See TYPES_PENDING.md.
FOUNDATION_EXTERN UIImage *_Nullable CreateReflectedImage(UIImage *_Nullable image, int height);

// The background art and its uniform resizable cap inset.
static NSString *const kDetailBackgroundImageName = @"store_pack_bg_0";
static const CGFloat kDetailBackgroundCapInset = 4.0;

// The artwork thumbnail's fixed frame; the pooled double at 0x28f3f8 sizes both axes.
static const CGFloat kDetailArtworkOrigin = 8.0;
static const CGFloat kDetailArtworkSize = 80.0; // @ghidraAddress 0x28f3f8

// The reflection sits below the artwork: its y is the pooled double at 0x28f400, its height at
// 0x28f1f8, and it is drawn at 40% alpha (0x28f2c0). The reflection image itself is the top tenth
// of the artwork (0x28f240 == 0.2 in -setArtwork:; the pooled 0x28f2b8 == 0.1 is unused here).
static const CGFloat kDetailReflectionY = 200.0; // @ghidraAddress 0x28f400
static const CGFloat kDetailReflectionHeight = 16.0;
static const CGFloat kDetailReflectionAlpha = 0.4;         // @ghidraAddress 0x28f2c0
static const CGFloat kDetailReflectionImageFraction = 0.2; // @ghidraAddress 0x28f240

// The name label: inset right of the artwork, width shrinking with the header. From the pooled
// double at 0x28f908 (x) and 0x28f408 (width delta).
static const CGFloat kDetailNameLabelX = 96.0; // @ghidraAddress 0x28f908
static const CGFloat kDetailNameLabelY = 8.0;
static const CGFloat kDetailNameLabelWidthDelta = -310.0; // @ghidraAddress 0x28f408
static const CGFloat kDetailNameLabelHeight = 40.0;       // @ghidraAddress 0x28f1f8
static const CGFloat kDetailNameFontSize = 18.0;

// The white text shadow shared by the name label and the link button.
static const CGFloat kDetailTextShadowWhite = 1.0;
static const CGFloat kDetailTextShadowAlpha = 0.7; // fmov 0x3fe6666660000000

// The purchase button: pinned to the header's right, fixed y/width/height. From the pooled doubles
// at 0x291d58 (x delta), 0x28f258 (y), and 0x28f210 (width).
static const CGFloat kDetailPurchaseXDelta = -130.0; // @ghidraAddress 0x291d58
static const CGFloat kDetailPurchaseY = 60.0;        // @ghidraAddress 0x28f258
static const CGFloat kDetailPurchaseWidth = 120.0;   // @ghidraAddress 0x28f210
static const CGFloat kDetailPurchaseHeight = 28.0;
static const CGFloat kDetailPurchaseDisabledWhite = 0.6; // @ghidraAddress 0x28f230
static const CGFloat kDetailPurchaseCornerRadius = 4.0;
static const CGFloat kDetailPurchaseFontSize = 15.0;

// The comment label's initial layout, before -loadPackInfo: re-sizes it. From the pooled double at
// 0x28f410 (y).
static const CGFloat kDetailCommentLabelX = 15.0;
static const CGFloat kDetailCommentLabelYInit = 310.0; // @ghidraAddress 0x28f410
static const CGFloat kDetailCommentLabelWidthDelta = -30.0;
static const CGFloat kDetailCommentLabelHeightInit = 10.0;
static const CGFloat kDetailCommentFontSize = 12.0;

// The link button's title colours and font.
static const CGFloat kDetailLinkTitleWhite = 0.4;     // fmov 0x3fd99999a0000000
static const CGFloat kDetailLinkHighlightWhite = 0.1; // fmov 0x3fb99999a0000000
static const CGFloat kDetailLinkFontSize = 14.0;

// The extend-download button is placed left of the purchase button's left edge by this much.
static const CGFloat kDetailExtendXInset = -10.0;

// The sizing width for the name and comment text measurement, and the two measurement heights.
static const CGFloat kDetailNameMeasureHeight = 50.0;     // @ghidraAddress 0x28f2c8
static const CGFloat kDetailCommentMeasureHeight = 120.0; // @ghidraAddress 0x28f210

// The vertical paddings accumulated as the header grows to fit its content.
static const CGFloat kDetailCommentGap = 110.0; // @ghidraAddress 0x28f5e8
static const CGFloat kDetailLinkPadX = 12.0;
static const CGFloat kDetailLinkPadY = 4.0;
static const CGFloat kDetailLinkRightInset = -15.0;
static const CGFloat kDetailLinkBottomGap = 6.0;

@implementation StoreDetailHeaderView {
    UIImageView *bgView;                // +0x8
    UIImageView *artworkView;           // +0x10
    UIImageView *reflectionArtworkView; // +0x18
    UIImageView *newMarker;             // +0x20
    NSURL *linkURL;                     // +0x28
    // _labelName, _labelComment, _buttonPurchase, _buttonExtendDownload, _buttonLink are
    // synthesised.
}

@synthesize labelName = _labelName;
@synthesize labelComment = _labelComment;
@synthesize buttonPurchase = _buttonPurchase;
@synthesize buttonExtendDownload = _buttonExtendDownload;
@synthesize buttonLink = _buttonLink;

#pragma mark - Construction

/** @ghidraAddress 0xf9074 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    // The stretchable background fills the header and follows its resize.
    bgView = [[UIImageView alloc] initWithFrame:self.bounds];
    UIImage *bg = [LoadScaledPngImage(kDetailBackgroundImageName)
        resizableImageWithCapInsets:UIEdgeInsetsMake(kDetailBackgroundCapInset,
                                                     kDetailBackgroundCapInset,
                                                     kDetailBackgroundCapInset,
                                                     kDetailBackgroundCapInset)];
    bgView.image = bg;
    bgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:bgView];

    // The artwork and, below it, its faded reflection.
    artworkView = [[UIImageView alloc] initWithFrame:CGRectMake(kDetailArtworkOrigin,
                                                                kDetailArtworkOrigin,
                                                                kDetailArtworkSize,
                                                                kDetailArtworkSize)];
    artworkView.image = [ImageCache.sharedCache getResPNG:@"store_jacket_160"];
    [self addSubview:artworkView];

    reflectionArtworkView = [[UIImageView alloc] initWithFrame:CGRectMake(kDetailArtworkOrigin,
                                                                          kDetailReflectionY,
                                                                          kDetailArtworkSize,
                                                                          kDetailReflectionHeight)];
    reflectionArtworkView.alpha = kDetailReflectionAlpha;
    [self addSubview:reflectionArtworkView];

    CGFloat headerWidth = self.frame.size.width;

    // The name label, two lines with a soft white shadow.
    self.labelName =
        [[UILabel alloc] initWithFrame:CGRectMake(kDetailNameLabelX,
                                                  kDetailNameLabelY,
                                                  headerWidth + kDetailNameLabelWidthDelta,
                                                  kDetailNameLabelHeight)];
    self.labelName.backgroundColor = UIColor.clearColor;
    self.labelName.numberOfLines = 2;
    self.labelName.lineBreakMode = NSLineBreakByWordWrapping;
    self.labelName.font = [UIFont boldSystemFontOfSize:kDetailNameFontSize];
    self.labelName.shadowOffset = CGSizeZero;
    self.labelName.shadowColor = [UIColor colorWithWhite:kDetailTextShadowWhite
                                                   alpha:kDetailTextShadowAlpha];
    [self addSubview:self.labelName];

    // The purchase button, pinned to the header's right.
    self.buttonPurchase =
        [[StoreButton alloc] initWithFrame:CGRectMake(headerWidth + kDetailPurchaseXDelta,
                                                      kDetailPurchaseY,
                                                      kDetailPurchaseWidth,
                                                      kDetailPurchaseHeight)];
    self.buttonPurchase.disabledColor = [UIColor colorWithWhite:kDetailPurchaseDisabledWhite
                                                          alpha:1];
    self.buttonPurchase.cornerRadius = kDetailPurchaseCornerRadius;
    self.buttonPurchase.exclusiveTouch = YES;
    self.buttonPurchase.titleLabel.font = [UIFont boldSystemFontOfSize:kDetailPurchaseFontSize];
    [self addSubview:self.buttonPurchase];

    // The comment label, laid out fully in -loadPackInfo:.
    self.labelComment =
        [[UILabel alloc] initWithFrame:CGRectMake(kDetailCommentLabelX,
                                                  kDetailCommentLabelYInit,
                                                  headerWidth + kDetailCommentLabelWidthDelta,
                                                  kDetailCommentLabelHeightInit)];
    self.labelComment.backgroundColor = UIColor.clearColor;
    self.labelComment.numberOfLines = 0;
    self.labelComment.lineBreakMode = NSLineBreakByWordWrapping;
    self.labelComment.font = [UIFont systemFontOfSize:kDetailCommentFontSize];
    [self addSubview:self.labelComment];

    // The related-site link button, sized in -loadPackInfo:.
    _buttonLink = [[StoreLinkButton alloc] initWithFrame:CGRectZero];
    _buttonLink.exclusiveTouch = YES;
    _buttonLink.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    _buttonLink.opaque = NO;
    _buttonLink.backgroundColor = UIColor.clearColor;
    _buttonLink.titleLabel.font = [UIFont boldSystemFontOfSize:kDetailLinkFontSize];
    _buttonLink.titleLabel.shadowOffset = CGSizeZero;
    [_buttonLink setTitleColor:[UIColor colorWithWhite:kDetailLinkTitleWhite alpha:1]
                      forState:UIControlStateNormal];
    [_buttonLink setTitleShadowColor:[UIColor colorWithWhite:kDetailTextShadowWhite
                                                       alpha:kDetailTextShadowAlpha]
                            forState:UIControlStateNormal];
    [_buttonLink setTitleColor:[UIColor colorWithWhite:kDetailLinkHighlightWhite alpha:1]
                      forState:UIControlStateHighlighted];
    [_buttonLink addTarget:self
                    action:@selector(handleLink:)
          forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_buttonLink];

    // The extend-download button, hidden until a pack with an extension loads. It is placed just
    // left of the purchase button.
    UIImage *extendImage = [ImageCache.sharedCache getResPNG:@"store_add_dl_btn"];
    CGRect purchaseFrame = self.buttonPurchase.frame;
    CGSize extendSize = extendImage.size;
    self.buttonExtendDownload = [[UIButton alloc]
        initWithFrame:CGRectMake((purchaseFrame.origin.x - extendSize.width) + kDetailExtendXInset,
                                 purchaseFrame.origin.y,
                                 extendSize.width,
                                 extendSize.height)];
    [self.buttonExtendDownload setImage:extendImage forState:UIControlStateNormal];
    self.buttonExtendDownload.exclusiveTouch = YES;
    self.buttonExtendDownload.hidden = YES;
    [self addSubview:self.buttonExtendDownload];

    // The "new" marker at its natural size.
    newMarker = [[UIImageView alloc] initWithImage:[ImageCache.sharedCache getResPNG:@"store_new"]];
    [self addSubview:newMarker];
    return self;
}

#pragma mark - Content

/** @ghidraAddress 0xf9dc4 */
- (void)loadPackInfo:(StorePackInfo *)packInfo {
    self.buttonExtendDownload.hidden = YES;

    CGFloat headerWidth = self.frame.size.width;
    NSStringDrawingOptions options =
        NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine;

    // Size the name label to its text within the header's remaining width.
    CGFloat nameWidth = headerWidth + kDetailNameLabelWidthDelta;
    NSDictionary *nameAttrs = @{NSFontAttributeName : self.labelName.font};
    CGRect nameRect =
        [packInfo.packName boundingRectWithSize:CGSizeMake(nameWidth, kDetailNameMeasureHeight)
                                        options:options
                                     attributes:nameAttrs
                                        context:nil];
    CGRect nameFrame = self.labelName.frame;
    self.labelName.frame = CGRectMake(
        nameFrame.origin.x, nameFrame.origin.y, nameRect.size.width, nameRect.size.height);
    self.labelName.text = packInfo.packName;

    // The running height the header grows to fit. Without a comment the comment label is hidden and
    // the base gap is used; otherwise the comment is measured and laid out below the name.
    CGFloat contentBottom;
    if (!packInfo.comment) {
        self.labelComment.hidden = YES;
        contentBottom = kDetailCommentGap;
    } else {
        CGFloat commentWidth = headerWidth + kDetailCommentLabelWidthDelta;
        NSDictionary *commentAttrs = @{NSFontAttributeName : self.labelComment.font};
        CGRect commentRect = [packInfo.comment
            boundingRectWithSize:CGSizeMake(commentWidth, kDetailCommentMeasureHeight)
                         options:options
                      attributes:commentAttrs
                         context:nil];
        CGRect commentFrame = self.labelComment.frame;
        self.labelComment.frame = CGRectMake(commentFrame.origin.x,
                                             commentFrame.origin.y,
                                             commentRect.size.width,
                                             commentRect.size.height);
        self.labelComment.text = packInfo.comment;
        self.labelComment.hidden = NO;
        contentBottom = commentRect.size.height + kDetailCommentGap;
    }

    // The header's frame is captured now, before it is regrown at the end; the link is positioned
    // relative to the comment label and the header's width.
    CGRect headerFrame = self.frame;

    // The related-site link, if the pack carries a valid URL.
    if (![StoreUtil isValidURL:packInfo.linkURL]) {
        _buttonLink.hidden = YES;
        linkURL = nil;
    } else {
        if (packInfo.linkTitle.length == 0) {
            [_buttonLink setTitle:[NSBundle.mainBundle localizedStringForKey:@"Related site"
                                                                       value:@""
                                                                       table:nil]
                         forState:UIControlStateNormal];
        } else {
            [_buttonLink setTitle:packInfo.linkTitle forState:UIControlStateNormal];
        }
        [_buttonLink sizeToFit];
        CGRect linkFitFrame = _buttonLink.frame;
        CGFloat linkWidth = linkFitFrame.size.width + kDetailLinkPadX;
        CGFloat linkHeight = linkFitFrame.size.height + kDetailLinkPadY;
        CGFloat linkX = (headerFrame.size.width - linkWidth) + kDetailLinkRightInset;
        // The link sits directly below the comment label.
        CGRect commentFrame = self.labelComment.frame;
        CGFloat linkY = commentFrame.origin.y + commentFrame.size.height + kDetailLinkPadY;
        _buttonLink.frame = CGRectMake(linkX, linkY, linkWidth, linkHeight);
        [_buttonLink setNeedsDisplay];
        _buttonLink.hidden = NO;
        contentBottom = contentBottom + (linkHeight + kDetailLinkBottomGap);
        linkURL = [NSURL URLWithString:packInfo.linkURL];
    }

    // Grow the header to enclose everything laid out above, keeping its origin and width.
    self.frame = CGRectMake(
        headerFrame.origin.x, headerFrame.origin.y, headerFrame.size.width, contentBottom);

    newMarker.hidden = !packInfo.isNew;
}

/** @ghidraAddress 0xfa5d8 */
- (void)handleLink:(id)sender {
    if (!linkURL) {
        return;
    }
    // The confirmation alert quotes the link's title into the "Open ... in Safari?" prompt.
    NSString *format = [NSBundle.mainBundle localizedStringForKey:@"Open \"%@\" in Safari?"
                                                            value:@""
                                                            table:nil];
    NSString *message =
        [NSString stringWithFormat:format, [_buttonLink titleForState:UIControlStateNormal]];
    NSString *cancel = [NSBundle.mainBundle localizedStringForKey:@"Cancel" value:@"" table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [AlertViewManager.sharedManager makeAlert:0
                                     delegate:self
                                          tag:0
                                        title:nil
                                          msg:message
                                       cancel:cancel
                                      btnText:@[ ok ]
                                         show:YES];
}

/** @ghidraAddress 0xfa84c */
- (void)setArtwork:(UIImage *)artwork {
    if (!artwork) {
        return;
    }
    artworkView.image = artwork;
    int reflectionHeight = (int)(artwork.size.height * kDetailReflectionImageFraction);
    reflectionArtworkView.image = CreateReflectedImage(artwork, reflectionHeight);
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0xfa924 */
- (void)alertSelect:(NSDictionary *)info {
    if ([info[@"btnMessage"] intValue] == 1 && linkURL) {
        [UIApplication.sharedApplication openURL:linkURL];
    }
}

@end
