#import "StoreDetailHeaderViewV2.h"

#import <QuartzCore/QuartzCore.h>

#import "ImageCache.h"
#import "ImageLoading.h"
#import "StoreUtil.h"

// The background art and its uniform resizable cap inset.
static NSString *const kV2BackgroundImageName = @"store_pack_bg_0";
static const CGFloat kV2BackgroundCapInset = 4.0;

// The artwork thumbnail's fixed frame; the pooled double at 0x28f3f8 sizes both axes.
static const CGFloat kV2ArtworkOrigin = 8.0;
static const CGFloat kV2ArtworkSize = 80.0; // @ghidraAddress 0x28f3f8

// The reflection sits below the artwork: its y is the pooled double at 0x292400, its height comes
// from the fmov 30.0-slot rendered as 0x4030, and it is drawn at 40% alpha (0x28f2c0). The
// reflection image itself is the top fifth of the artwork (0x28f240 == 0.2 in -setArtwork:).
static const CGFloat kV2ReflectionY = 88.0; // @ghidraAddress 0x292400
static const CGFloat kV2ReflectionHeight = 16.0;
static const CGFloat kV2ReflectionAlpha = 0.4;         // @ghidraAddress 0x28f2c0
static const CGFloat kV2ReflectionImageFraction = 0.2; // @ghidraAddress 0x28f240

// The name label: inset right of the artwork, width shrinking with the header. From the pooled
// doubles at 0x28f908 (x), 0x292408 (width delta), and 0x28f1f8 (height).
static const CGFloat kV2NameLabelX = 96.0; // @ghidraAddress 0x28f908
static const CGFloat kV2NameLabelY = 8.0;
static const CGFloat kV2NameLabelWidthDelta = -106.0; // @ghidraAddress 0x292408
static const CGFloat kV2NameLabelHeight = 40.0;       // @ghidraAddress 0x28f1f8
static const CGFloat kV2NameFontSize = 18.0;

// The white text shadow shared by the name label and the link button. The offset is a one-point
// downward drop (0, 1), not a zero offset.
static const CGFloat kV2TextShadowWhite = 1.0;
static const CGFloat kV2TextShadowAlpha = 0.7; // @ghidraAddress 0x291c98
static const CGFloat kV2TextShadowOffsetY = 1.0;

// The purchase button: pinned to the header's right, fixed y/width/height. From the pooled doubles
// at 0x291d58 (x delta), 0x28f258 (y), and 0x28f210 (width).
static const CGFloat kV2PurchaseXDelta = -130.0; // @ghidraAddress 0x291d58
static const CGFloat kV2PurchaseY = 60.0;        // @ghidraAddress 0x28f258
static const CGFloat kV2PurchaseWidth = 120.0;   // @ghidraAddress 0x28f210
static const CGFloat kV2PurchaseHeight = 28.0;
static const CGFloat kV2PurchaseDisabledWhite = 0.6; // @ghidraAddress 0x28f230
static const CGFloat kV2PurchaseCornerRadius = 4.0;
static const CGFloat kV2PurchaseFontSize = 15.0;

// The comment label's initial layout, before -loadPackInfo: re-sizes it. From the pooled double at
// 0x292410 (y).
static const CGFloat kV2CommentLabelX = 15.0;
static const CGFloat kV2CommentLabelYInit = 102.0; // @ghidraAddress 0x292410
static const CGFloat kV2CommentLabelWidthDelta = -30.0;
static const CGFloat kV2CommentLabelHeightInit = 10.0;
static const CGFloat kV2CommentFontSize = 12.0;

// The link button's title colours and font.
static const CGFloat kV2LinkTitleWhite = 0.4;     // @ghidraAddress 0x28f2c0
static const CGFloat kV2LinkHighlightWhite = 0.1; // @ghidraAddress 0x28f2b8
static const CGFloat kV2LinkFontSize = 14.0;

// The extend-download button is placed left of the purchase button's left edge by this much.
static const CGFloat kV2ExtendXInset = -10.0;

// The sizing width for the name and comment text measurement, and the two measurement heights.
static const CGFloat kV2NameMeasureHeight = 50.0;     // @ghidraAddress 0x28f2c8
static const CGFloat kV2CommentMeasureHeight = 120.0; // @ghidraAddress 0x28f210

// The vertical paddings accumulated as the header grows to fit its content.
static const CGFloat kV2CommentGap = 104.0; // @ghidraAddress 0x28f678
static const CGFloat kV2LinkPadX = 12.0;
static const CGFloat kV2LinkPadY = 4.0;
static const CGFloat kV2LinkRightInset = -15.0;
static const CGFloat kV2LinkBottomGap = 6.0;

// The relation-tab strip: a bordered rounded view under the artwork holding the two tabs. Its x is
// the pooled double at 0x28f1f8 (the 40.0 slot the name-label height also reads) and its y at
// 0x28f400; its width shrinks with the header (0x28f468 delta) and its height is the fmov 30.0
// slot.
static const CGFloat kV2RelationViewX = 40.0;           // @ghidraAddress 0x28f1f8
static const CGFloat kV2RelationViewY = 200.0;          // @ghidraAddress 0x28f400
static const CGFloat kV2RelationViewWidthDelta = -80.0; // @ghidraAddress 0x28f468
static const CGFloat kV2RelationViewHeight = 30.0;
static const CGFloat kV2RelationViewCornerRadius = 8.0;
static const CGFloat kV2RelationViewBorderWidth = 1.2; // @ghidraAddress 0x292f38

// The relation accent colour, an opaque blue built from components (0, 0.478, 1, 1).
static const CGFloat kV2RelationAccentGreen = 0.47843137383461; // @ghidraAddress 0x293b08

// Each relation-tab button: half the strip's width, overhanging the strip by two points at the top
// and four at the bottom, with a thin border.
static const CGFloat kV2RelationButtonY = -2.0;
static const CGFloat kV2RelationButtonHeightPad = 4.0;
static const CGFloat kV2RelationButtonBorderWidth = 0.5;

// The extra height the header gains beneath the relation strip once everything is laid out.
static const CGFloat kV2HeaderGrowPad = 46.0; // @ghidraAddress 0x28f740

// The two tabs that get buttons and the third (unused) recommendation title kept in the source
// array. The binary builds a three-element array but only lays out the first two.
static NSString *const kV2RelationTitleRecordedSongs = @"収録楽曲";
static NSString *const kV2RelationTitleRecommended = @"おすすめ";
static NSString *const kV2RelationTitleAlsoBought =
    @"このパックを買った人はこんなパックも買っています";

// The number of relation-tab buttons actually laid out; the title array carries one more.
static const NSInteger kV2RelationButtonCount = 2;

// The colours -setRelationColor:selectable: paints onto the tabs.
static const CGFloat kV2RelationSelectedTextWhite = 0.9;     // @ghidraAddress 0x28f448
static const CGFloat kV2RelationDimmedBackgroundWhite = 0.6; // @ghidraAddress 0x28f288
static const CGFloat kV2RelationDimmedTextWhite = 0.8;       // @ghidraAddress 0x28e060

@implementation StoreDetailHeaderViewV2 {
    UIImageView *bgView;                // +0x8
    UIImageView *artworkView;           // +0x10
    UIImageView *reflectionArtworkView; // +0x18
    UIImageView *newMarker;             // +0x20
    NSURL *linkURL;                     // +0x28
    UIView *relationView;               // +0x30
    // _labelName, _labelComment, _buttonPurchase, _buttonExtendDownload, _buttonLink, and
    // _relationBtnArray are synthesised.
}

@synthesize labelName = _labelName;
@synthesize labelComment = _labelComment;
@synthesize buttonPurchase = _buttonPurchase;
@synthesize buttonExtendDownload = _buttonExtendDownload;
@synthesize buttonLink = _buttonLink;
@synthesize relationBtnArray = _relationBtnArray;

#pragma mark - Construction

/** @ghidraAddress 0x1a5154 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    // The stretchable background fills the header and follows its resize.
    bgView = [[UIImageView alloc] initWithFrame:self.bounds];
    UIImage *bg = [LoadScaledPngImage(kV2BackgroundImageName)
        resizableImageWithCapInsets:UIEdgeInsetsMake(kV2BackgroundCapInset,
                                                     kV2BackgroundCapInset,
                                                     kV2BackgroundCapInset,
                                                     kV2BackgroundCapInset)];
    bgView.image = bg;
    bgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:bgView];

    // The artwork and, below it, its faded reflection.
    artworkView = [[UIImageView alloc]
        initWithFrame:CGRectMake(
                          kV2ArtworkOrigin, kV2ArtworkOrigin, kV2ArtworkSize, kV2ArtworkSize)];
    artworkView.image = [ImageCache.sharedCache getResPNG:@"store_jacket_160"];
    [self addSubview:artworkView];

    reflectionArtworkView = [[UIImageView alloc]
        initWithFrame:CGRectMake(
                          kV2ArtworkOrigin, kV2ReflectionY, kV2ArtworkSize, kV2ReflectionHeight)];
    reflectionArtworkView.alpha = kV2ReflectionAlpha;
    [self addSubview:reflectionArtworkView];

    CGFloat headerWidth = self.frame.size.width;

    // The name label, two lines with a soft white drop shadow.
    self.labelName = [[UILabel alloc] initWithFrame:CGRectMake(kV2NameLabelX,
                                                               kV2NameLabelY,
                                                               headerWidth + kV2NameLabelWidthDelta,
                                                               kV2NameLabelHeight)];
    self.labelName.backgroundColor = UIColor.clearColor;
    self.labelName.numberOfLines = 2;
    self.labelName.lineBreakMode = NSLineBreakByWordWrapping;
    self.labelName.font = [UIFont boldSystemFontOfSize:kV2NameFontSize];
    self.labelName.shadowOffset = CGSizeMake(0, kV2TextShadowOffsetY);
    self.labelName.shadowColor = [UIColor colorWithWhite:kV2TextShadowWhite
                                                   alpha:kV2TextShadowAlpha];
    [self addSubview:self.labelName];

    // The purchase button, pinned to the header's right.
    self.buttonPurchase =
        [[StoreButton alloc] initWithFrame:CGRectMake(headerWidth + kV2PurchaseXDelta,
                                                      kV2PurchaseY,
                                                      kV2PurchaseWidth,
                                                      kV2PurchaseHeight)];
    self.buttonPurchase.disabledColor = [UIColor colorWithWhite:kV2PurchaseDisabledWhite alpha:1];
    self.buttonPurchase.cornerRadius = kV2PurchaseCornerRadius;
    self.buttonPurchase.exclusiveTouch = YES;
    self.buttonPurchase.titleLabel.font = [UIFont boldSystemFontOfSize:kV2PurchaseFontSize];
    [self addSubview:self.buttonPurchase];

    // The comment label, laid out fully in -loadPackInfo:.
    self.labelComment =
        [[UILabel alloc] initWithFrame:CGRectMake(kV2CommentLabelX,
                                                  kV2CommentLabelYInit,
                                                  headerWidth + kV2CommentLabelWidthDelta,
                                                  kV2CommentLabelHeightInit)];
    self.labelComment.backgroundColor = UIColor.clearColor;
    self.labelComment.numberOfLines = 0;
    self.labelComment.lineBreakMode = NSLineBreakByWordWrapping;
    self.labelComment.font = [UIFont systemFontOfSize:kV2CommentFontSize];
    [self addSubview:self.labelComment];

    // The related-site link button, sized in -loadPackInfo:.
    _buttonLink = [[StoreLinkButton alloc] initWithFrame:CGRectZero];
    _buttonLink.exclusiveTouch = YES;
    _buttonLink.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    _buttonLink.opaque = NO;
    _buttonLink.backgroundColor = UIColor.clearColor;
    _buttonLink.titleLabel.font = [UIFont boldSystemFontOfSize:kV2LinkFontSize];
    _buttonLink.titleLabel.shadowOffset = CGSizeMake(0, kV2TextShadowOffsetY);
    [_buttonLink setTitleColor:[UIColor colorWithWhite:kV2LinkTitleWhite alpha:1]
                      forState:UIControlStateNormal];
    [_buttonLink setTitleShadowColor:[UIColor colorWithWhite:kV2TextShadowWhite
                                                       alpha:kV2TextShadowAlpha]
                            forState:UIControlStateNormal];
    [_buttonLink setTitleColor:[UIColor colorWithWhite:kV2LinkHighlightWhite alpha:1]
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
        initWithFrame:CGRectMake((purchaseFrame.origin.x - extendSize.width) + kV2ExtendXInset,
                                 purchaseFrame.origin.y,
                                 extendSize.width,
                                 extendSize.height)];
    [self.buttonExtendDownload setImage:extendImage forState:UIControlStateNormal];
    self.buttonExtendDownload.exclusiveTouch = YES;
    self.buttonExtendDownload.hidden = YES;
    [self addSubview:self.buttonExtendDownload];

    // The relation-tab strip: a bordered, rounded view spanning most of the header, with the accent
    // blue as its border. Its width shrinks with the background view's width.
    UIColor *accentColor = [UIColor colorWithRed:0 green:kV2RelationAccentGreen blue:1 alpha:1];
    relationView = [[UIView alloc]
        initWithFrame:CGRectMake(kV2RelationViewX,
                                 kV2RelationViewY,
                                 bgView.frame.size.width + kV2RelationViewWidthDelta,
                                 kV2RelationViewHeight)];
    relationView.layer.cornerRadius = kV2RelationViewCornerRadius;
    relationView.clipsToBounds = YES;
    relationView.layer.borderWidth = kV2RelationViewBorderWidth;
    relationView.layer.borderColor = accentColor.CGColor;
    [self addSubview:relationView];

    // The two relation tabs, each half the strip's width and side by side. The tabs start disabled
    // and are coloured by -setRelationColor:selectable:.
    NSArray *relationTitles =
        @[ kV2RelationTitleRecordedSongs, kV2RelationTitleRecommended, kV2RelationTitleAlsoBought ];
    NSMutableArray *relationButtons = [[NSMutableArray alloc] init];
    int relationWidth = (int)relationView.frame.size.width;
    int halfWidth = relationWidth / 2;
    CGFloat buttonHeight = relationView.frame.size.height + kV2RelationButtonHeightPad;
    int buttonX = 0;
    for (NSInteger index = 0; index < kV2RelationButtonCount; ++index) {
        UIButton *button = [[UIButton alloc]
            initWithFrame:CGRectMake(buttonX, kV2RelationButtonY, halfWidth, buttonHeight)];
        [button setTitle:relationTitles[index] forState:UIControlStateNormal];
        [button setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
        button.layer.borderWidth = kV2RelationButtonBorderWidth;
        button.layer.borderColor = accentColor.CGColor;
        button.exclusiveTouch = YES;
        button.tag = index;
        button.enabled = NO;
        [relationView addSubview:button];
        [relationButtons addObject:button];
        // The binary adds each button to the strip a second time.
        [relationView addSubview:button];
        buttonX += halfWidth;
    }
    _relationBtnArray = [relationButtons copy];
    [self setRelationColor:0 selectable:NO];

    // The "new" marker at its natural size.
    newMarker = [[UIImageView alloc] initWithImage:[ImageCache.sharedCache getResPNG:@"store_new"]];
    [self addSubview:newMarker];
    return self;
}

#pragma mark - Content

/** @ghidraAddress 0x1a6370 */
- (void)loadPackInfo:(StorePackInfo *)packInfo {
    self.buttonExtendDownload.hidden = YES;

    NSString *packName = packInfo.packName;
    CGFloat headerWidth = self.frame.size.width;
    NSStringDrawingOptions options =
        NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine;

    // Size the name label to its text within the header's remaining width.
    CGFloat nameWidth = headerWidth + kV2NameLabelWidthDelta;
    NSDictionary *nameAttrs = @{NSFontAttributeName : self.labelName.font};
    CGRect nameRect = [packName boundingRectWithSize:CGSizeMake(nameWidth, kV2NameMeasureHeight)
                                             options:options
                                          attributes:nameAttrs
                                             context:nil];
    CGRect nameFrame = self.labelName.frame;
    self.labelName.frame = CGRectMake(
        nameFrame.origin.x, nameFrame.origin.y, nameRect.size.width, nameRect.size.height);
    self.labelName.text = packName;

    // The running height the header grows to fit. Without a comment the comment label is hidden and
    // the base gap is used; otherwise the comment is measured and laid out below the name.
    CGFloat contentBottom;
    if (!packInfo.comment) {
        self.labelComment.hidden = YES;
        contentBottom = kV2CommentGap;
    } else {
        CGFloat commentWidth = headerWidth + kV2CommentLabelWidthDelta;
        NSDictionary *commentAttrs = @{NSFontAttributeName : self.labelComment.font};
        CGRect commentRect =
            [packInfo.comment boundingRectWithSize:CGSizeMake(commentWidth, kV2CommentMeasureHeight)
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
        contentBottom = commentRect.size.height + kV2CommentGap;
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
        CGFloat linkWidth = linkFitFrame.size.width + kV2LinkPadX;
        CGFloat linkHeight = linkFitFrame.size.height + kV2LinkPadY;
        CGFloat linkX = (headerFrame.size.width - linkWidth) + kV2LinkRightInset;
        // The link sits directly below the comment label.
        CGRect commentFrame = self.labelComment.frame;
        CGFloat linkY = commentFrame.origin.y + commentFrame.size.height + kV2LinkPadY;
        _buttonLink.frame = CGRectMake(linkX, linkY, linkWidth, linkHeight);
        [_buttonLink setNeedsDisplay];
        _buttonLink.hidden = NO;
        contentBottom = contentBottom + (linkHeight + kV2LinkBottomGap);
        linkURL = [NSURL URLWithString:packInfo.linkURL];
    }

    // Move the relation strip to just below the laid-out content, keeping its origin x, width, and
    // height.
    CGRect relationFrame = relationView.frame;
    relationView.frame = CGRectMake(
        relationFrame.origin.x, contentBottom, relationFrame.size.width, relationFrame.size.height);

    // Grow the header to enclose everything above plus the relation strip, keeping its origin and
    // width.
    self.frame = CGRectMake(headerFrame.origin.x,
                            headerFrame.origin.y,
                            headerFrame.size.width,
                            contentBottom + kV2HeaderGrowPad);

    newMarker.hidden = !packInfo.isNew;
}

/** @ghidraAddress 0x1a6e54 */
- (void)setArtwork:(UIImage *)artwork {
    if (!artwork) {
        return;
    }
    artworkView.image = artwork;
    int reflectionHeight = (int)(artwork.size.height * kV2ReflectionImageFraction);
    reflectionArtworkView.image = CreateReflectedImage(artwork, reflectionHeight);
}

#pragma mark - Relation tabs

/** @ghidraAddress 0x1a6ffc */
- (void)setRelationColor:(int)selectedIndex selectable:(BOOL)selectable {
    UIColor *accentColor = [UIColor colorWithRed:0 green:kV2RelationAccentGreen blue:1 alpha:1];
    UIColor *selectedTextColor = [UIColor colorWithWhite:kV2RelationSelectedTextWhite alpha:1];
    UIColor *unselectedBackgroundColor = UIColor.clearColor;
    UIColor *unselectedTextColor = accentColor;
    if (!selectable) {
        unselectedBackgroundColor = [UIColor colorWithWhite:kV2RelationDimmedBackgroundWhite
                                                      alpha:1];
        unselectedTextColor = [UIColor colorWithWhite:kV2RelationDimmedTextWhite alpha:1];
    }

    UIButton *firstButton = self.relationBtnArray[0];
    UIColor *firstBackgroundColor = accentColor;
    UIColor *firstTextColor = selectedTextColor;
    if (selectedIndex != 0) {
        firstBackgroundColor = unselectedBackgroundColor;
        firstTextColor = unselectedTextColor;
    }
    firstButton.backgroundColor = firstBackgroundColor;
    [firstButton setTitleColor:firstTextColor forState:UIControlStateNormal];

    UIButton *secondButton = self.relationBtnArray[1];
    UIColor *secondBackgroundColor = accentColor;
    UIColor *secondTextColor = selectedTextColor;
    if (selectedIndex != 1) {
        secondBackgroundColor = unselectedBackgroundColor;
        secondTextColor = unselectedTextColor;
    }
    secondButton.backgroundColor = secondBackgroundColor;
    [secondButton setTitleColor:secondTextColor forState:UIControlStateNormal];
}

/** @ghidraAddress 0x1a6fec */
- (void)tapRelationButton:(id)sender {
    // The binary reads the sender's tag and discards it; the handler is otherwise empty.
    (void)[sender tag];
}

#pragma mark - Link

/** @ghidraAddress 0x1a6be0 */
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

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0x1a6f2c */
- (void)alertSelect:(NSDictionary *)info {
    if ([info[@"btnMessage"] intValue] == 1 && linkURL) {
        [UIApplication.sharedApplication openURL:linkURL];
    }
}

@end
