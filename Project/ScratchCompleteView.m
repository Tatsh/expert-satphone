#import "ScratchCompleteView.h"

#import <QuartzCore/QuartzCore.h>

#import "ImageCache.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "ScratchInfo.h"
#import "ScratchUtil.h"

// The reveal cascade's per-stage animation timings: the whole view scales in over 0.05s after a
// 0.3s delay, the artwork and label stages take 0.1s each, and the banner 0.2s.
static const NSTimeInterval kRevealSelfDuration = 0.05;  // @ghidraAddress 0x293378
static const NSTimeInterval kRevealSelfDelay = 0.3;      // @ghidraAddress 0x28f248
static const NSTimeInterval kRevealStageDuration = 0.1;  // @ghidraAddress 0x28f290
static const NSTimeInterval kRevealBannerDuration = 0.2; // @ghidraAddress 0x28e040

// The card's dimming backdrop alpha (colorWithWhite:0 alpha:0.5).
static const CGFloat kBackdropAlpha = 0.5;

// The card's width by idiom, and the provisional height it is built at before being shrunk to fit
// its stacked content.
static const CGFloat kCardWidthPad = 620.0;          // 0x26c
static const CGFloat kCardWidthPhone = 310.0;        // 0x136
static const CGFloat kProvisionalCardHeight = 400.0; // @ghidraAddress 0x28f2e0

// The two title labels' height and font size by idiom.
static const int kLabelHeightPad = 26;
static const int kLabelHeightPhone = 16;
static const CGFloat kLabelFontSizePad = 24.0;   // fmov 0x4038000000000000
static const CGFloat kLabelFontSizePhone = 14.0; // fmov 0x402c000000000000

// The artwork and artwork-background views are displayed at their source image width times this
// scale, squared.
static const float kImageDisplayScale = 1.5f; // fmov d11,0x3ff8000000000000

// The vertical gap inserted after the banner and after the artwork background.
static const int kStackGap = 4;

// The banner, artwork-background, and default-artwork resource names.
static NSString *const kBannerImageName = @"scratch_open";
static NSString *const kArtworkBgImageName = @"scratch_open_jbg";
static NSString *const kDefaultArtworkImageName = @"scratch_btn_scratch_00";

@implementation ScratchCompleteView {
    UIView *bgView;                                    // offset global 0x34b334
    UIImageView *completeView;                         // offset global 0x34b338
    UIImageView *artworkBg;                            // offset global 0x34b33c
    UIImageView *artworkView;                          // offset global 0x34b340
    UILabel *musicName;                                // offset global 0x34b344
    UILabel *artistName;                               // offset global 0x34b348
    UIView *touchView;                                 // offset global 0x34b34c
    __weak id<ScratchCompleteViewDelegate> _aDelegate; // offset global 0x34b350
}

/** @ghidraAddress 0x16dd6c */
- (instancetype)initWithFrame:(CGRect)frame musicInfo:(ScratchInfo *)musicInfo {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }
    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    // Originally colorWithWhite:0 alpha:0.5.
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:kBackdropAlpha];

    CGFloat cardWidth = isPad ? kCardWidthPad : kCardWidthPhone;
    int labelHeight = isPad ? kLabelHeightPad : kLabelHeightPhone;
    CGFloat labelFontSize = isPad ? kLabelFontSizePad : kLabelFontSizePhone;
    // The centre X shared by every stacked subview, from an integer halving of the card width.
    CGFloat centreX = (CGFloat)((int)cardWidth >> 1);

    // The card holder, built at a provisional height and shrunk to fit its stacked content below.
    bgView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, cardWidth, kProvisionalCardHeight)];
    [self addSubview:bgView];

    // The COMPLETE banner at the top, revealed with a vertical scale.
    UIImage *bannerImage = LoadScaledPngImage(kBannerImageName);
    completeView = [[UIImageView alloc]
        initWithFrame:CGRectMake(0, 0, bannerImage.size.width, bannerImage.size.height)];
    completeView.image = bannerImage;
    completeView.center = CGPointMake(centreX, bannerImage.size.height * 0.5);
    completeView.transform = CGAffineTransformMakeScale(1.0, 0);
    [bgView addSubview:completeView];

    // The artwork background plate below the banner.
    int bannerBottom = (int)(bannerImage.size.height + kStackGap);
    UIImage *artworkBgImage = [ImageCache.sharedCache getResPNG:kArtworkBgImageName];
    int artworkBgSize = (int)(artworkBgImage.size.width * kImageDisplayScale);
    int artworkCentreY = bannerBottom + artworkBgSize / 2;
    artworkBg = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, artworkBgSize, artworkBgSize)];
    artworkBg.center = CGPointMake(centreX, artworkCentreY);
    artworkBg.transform = CGAffineTransformMakeScale(1.0, 0);
    artworkBg.image = artworkBgImage;
    [bgView addSubview:artworkBg];

    // The scratched tune's artwork over the plate, sharing its centre. The default button image is
    // loaded only for its size; the displayed image comes from the tune's scratch-image path.
    int afterArtworkBgY = bannerBottom + artworkBgSize + kStackGap;
    UIImage *defaultArtwork = [ImageCache.sharedCache getResPNG:kDefaultArtworkImageName];
    int artworkSize = (int)(defaultArtwork.size.width * kImageDisplayScale);
    artworkView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, artworkSize, artworkSize)];
    artworkView.center = CGPointMake(centreX, artworkCentreY);
    NSString *artPath = [ScratchUtil imagePathForMusicID:musicInfo.musicID];
    artworkView.image = [UIImage imageWithContentsOfFile:artPath];
    artworkView.transform = CGAffineTransformMakeScale(1.0, 0);
    [bgView addSubview:artworkView];

    // The tune-name label under the artwork.
    musicName = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, cardWidth, labelHeight)];
    musicName.textAlignment = NSTextAlignmentCenter;
    musicName.font = [UIFont systemFontOfSize:labelFontSize];
    musicName.textColor = UIColor.whiteColor;
    musicName.text = musicInfo.musicName;
    musicName.center = CGPointMake(centreX, afterArtworkBgY + labelHeight / 2);
    musicName.transform = CGAffineTransformMakeScale(1.0, 0);
    [bgView addSubview:musicName];

    // The artist label under the tune name; the binary ORs the stack gap into the label height to
    // derive the row stride.
    int labelStride = labelHeight | kStackGap;
    int artistTopY = afterArtworkBgY + labelStride;
    artistName = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, cardWidth, labelHeight)];
    artistName.textAlignment = NSTextAlignmentCenter;
    artistName.font = [UIFont systemFontOfSize:labelFontSize];
    artistName.textColor = UIColor.whiteColor;
    artistName.text = musicInfo.artistName;
    artistName.center = CGPointMake(centreX, artistTopY + labelHeight / 2);
    artistName.transform = CGAffineTransformMakeScale(1.0, 0);
    [bgView addSubview:artistName];

    // Shrink the holder to the stacked content and re-centre it in the view.
    int contentHeight = artistTopY + labelStride;
    bgView.frame = CGRectMake(0, 0, cardWidth, contentHeight);
    bgView.center = CGPointMake(frame.size.width * 0.5, frame.size.height * 0.5);

    // The full-view invisible tap target, armed only after the reveal finishes.
    touchView = [[UIView alloc] initWithFrame:frame];
    [self addSubview:touchView];

    [self animationStart];
    return self;
}

/** @ghidraAddress 0x16e730 */
- (void)animationStart {
    // A four-stage reveal cascade: the whole view scales/fades in, then the artwork pair, then the
    // two title labels, then the COMPLETE banner, each stage a nested completion. The dismiss
    // gesture is armed only after the last stage so a tap cannot close the view early.
    __weak typeof(self) weakSelf = self;
    self.alpha = 0;
    [UIView animateWithDuration:kRevealSelfDuration
        delay:kRevealSelfDelay
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x16e870 */
          weakSelf.transform = CGAffineTransformIdentity;
          weakSelf.alpha = 1;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x16e928 */
          // Stage 2: pop the artwork pair in.
          __strong __typeof__(self) strongSelf = weakSelf;
          __weak UIImageView *weakArtworkBg = strongSelf->artworkBg;
          __weak UIImageView *weakArtworkView = strongSelf->artworkView;
          weakArtworkView.alpha = 0.0;
          [UIView animateWithDuration:kRevealStageDuration
              delay:0.0
              options:UIViewAnimationOptionCurveEaseOut
              animations:^{
                /** @ghidraAddress 0x16eabc */
                weakArtworkBg.transform = CGAffineTransformMakeScale(1.0, 1.0);
                weakArtworkBg.alpha = 1.0;
                weakArtworkView.transform = CGAffineTransformMakeScale(1.0, 1.0);
                weakArtworkView.alpha = 1.0;
              }
              completion:^(BOOL __attribute__((unused)) finished2) {
                /** @ghidraAddress 0x16ec48 */
                // Stage 3: pop the two title labels in.
                __strong __typeof__(self) strongSelf3 = weakSelf;
                __weak UILabel *weakMusicName = strongSelf3->musicName;
                __weak UILabel *weakArtistName = strongSelf3->artistName;
                weakMusicName.alpha = 0.0;
                weakArtistName.alpha = 0.0;
                [UIView animateWithDuration:kRevealStageDuration
                    delay:0.0
                    options:UIViewAnimationOptionBeginFromCurrentState |
                            UIViewAnimationOptionAllowUserInteraction
                    animations:^{
                      /** @ghidraAddress 0x16ee04 */
                      weakMusicName.transform = CGAffineTransformMakeScale(1.0, 1.0);
                      weakMusicName.alpha = 1.0;
                      weakArtistName.transform = CGAffineTransformMakeScale(1.0, 1.0);
                      weakArtistName.alpha = 1.0;
                    }
                    completion:^(BOOL __attribute__((unused)) finished3) {
                      /** @ghidraAddress 0x16ef90 */
                      // Stage 4: pop the COMPLETE banner in.
                      __strong __typeof__(self) strongSelf4 = weakSelf;
                      __weak UIImageView *weakComplete = strongSelf4->completeView;
                      weakComplete.alpha = 0.0;
                      [UIView animateWithDuration:kRevealBannerDuration
                          delay:0.0
                          options:UIViewAnimationOptionCurveEaseOut
                          animations:^{
                            /** @ghidraAddress 0x16f0dc */
                            weakComplete.transform = CGAffineTransformMakeScale(1.0, 1.0);
                            weakComplete.alpha = 1.0;
                          }
                          completion:^(BOOL __attribute__((unused)) finished4) {
                            /** @ghidraAddress 0x16f194 */
                            // The reveal is done: arm the dismiss tap.
                            __strong __typeof__(self) strongSelf5 = weakSelf;
                            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                initWithTarget:weakSelf
                                        action:@selector(closeView)];
                            [strongSelf5->touchView addGestureRecognizer:tap];
                          }];
                    }];
              }];
        }];
}

/** @ghidraAddress 0x16f244 */
- (void)closeView {
    // Verified at 0x16f244: _objc_initWeak at 0x16f260, setAlpha:1.0 at 0x16f27c (fmov d0),
    // then animateWithDuration:DAT_0x28e040 (0.2) at 0x16f244 tail, blocks at 0x16f380 and
    // 0x16f3cc which fade out and notify delegate.
    __weak typeof(self) weakSelf = self;
    self.alpha = 1.0;
    [UIView animateWithDuration:0.2
        delay:0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x16f380 */
          weakSelf.alpha = 0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x16f3cc */
          if ([weakSelf.aDelegate respondsToSelector:@selector(scratchCompleteViewDidClose:)]) {
              [weakSelf.aDelegate scratchCompleteViewDidClose:weakSelf];
          }
        }];
}

@end
